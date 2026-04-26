use chrono::{DateTime, Days, LocalResult, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;
use rusqlite::{Connection, OptionalExtension, params};
use serde_json::Value;
use uuid::Uuid;

use crate::error::{LifeOsError, Result};
use crate::models::{
    CreateExpenseRecordInput, CreateIncomeRecordInput, CreateLearningRecordInput,
    CreateProjectInput, CreateTagInput, CreateTimeRecordInput, ExpenseRecord,
    ExpenseRecordSnapshot, IncomeRecord, IncomeRecordSnapshot, LearningRecord,
    LearningRecordSnapshot, Project, ProjectAllocation, RecentRecordItem, RecordKind, Tag,
    TimeRecord, TimeRecordSnapshot, TodayAlert, TodayAlerts, TodayGoalProgress,
    TodayGoalProgressItem, TodayOverview, TodaySummary, normalize_optional_string,
    parse_rfc3339_utc, to_utc_string,
};

pub struct RecordRepository;

impl RecordRepository {
    pub fn create_time_record(
        connection: &mut Connection,
        input: &CreateTimeRecordInput,
    ) -> Result<TimeRecord> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::TimeCategory,
            &input.normalized_category_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let id = new_id();
        let now = now_string();
        let duration_minutes = input.duration_minutes()?;
        let started_at = to_utc_string(input.started_at()?);
        let ended_at = to_utc_string(input.ended_at()?);
        let source = input.normalized_source();
        let note = input.normalized_note();

        tx.execute(
            "INSERT INTO time_records(
                id, user_id, started_at, ended_at, duration_minutes, category_code,
                efficiency_score, value_score, state_score, ai_assist_ratio, note, source,
                is_public_pool, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, 0, ?14, ?14)",
            params![
                id,
                input.user_id,
                started_at,
                ended_at,
                duration_minutes,
                input.normalized_category_code(),
                input.efficiency_score,
                input.value_score,
                input.state_score,
                input.ai_assist_ratio,
                note,
                source,
                input.is_public_pool as i32,
                now,
            ],
        )?;

        insert_project_links(
            &tx,
            "time",
            &id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        insert_tag_links(&tx, "time", &id, &input.user_id, &input.tag_ids, &now)?;

        tx.commit()?;

        Ok(TimeRecord {
            id,
            user_id: input.user_id.clone(),
            started_at,
            ended_at,
            duration_minutes,
            category_code: input.normalized_category_code(),
            efficiency_score: input.efficiency_score,
            value_score: input.value_score,
            state_score: input.state_score,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            is_public_pool: input.is_public_pool,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn create_income_record(
        connection: &mut Connection,
        input: &CreateIncomeRecordInput,
    ) -> Result<IncomeRecord> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::IncomeType,
            &input.normalized_type_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let id = new_id();
        let now = now_string();
        let source = input.normalized_source();
        let note = input.normalized_note();

        tx.execute(
            "INSERT INTO income_records(
                id, user_id, occurred_on, source_name, type_code, amount_cents, is_passive,
                ai_assist_ratio, note, source, is_public_pool, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, 0, ?12, ?12)",
            params![
                id,
                input.user_id,
                input.occurred_on,
                input.source_name.trim(),
                input.normalized_type_code(),
                input.amount_cents,
                input.is_passive as i32,
                input.ai_assist_ratio,
                note,
                source,
                input.is_public_pool as i32,
                now,
            ],
        )?;

        insert_project_links(
            &tx,
            "income",
            &id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        insert_tag_links(&tx, "income", &id, &input.user_id, &input.tag_ids, &now)?;
        tx.commit()?;

        Ok(IncomeRecord {
            id,
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            source_name: input.source_name.trim().to_string(),
            type_code: input.normalized_type_code(),
            amount_cents: input.amount_cents,
            is_passive: input.is_passive,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            is_public_pool: input.is_public_pool,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn create_expense_record(
        connection: &mut Connection,
        input: &CreateExpenseRecordInput,
    ) -> Result<ExpenseRecord> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::ExpenseCategory,
            &input.normalized_category_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let id = new_id();
        let now = now_string();
        let source = input.normalized_source();
        let note = input.normalized_note();

        tx.execute(
            "INSERT INTO expense_records(
                id, user_id, occurred_on, category_code, amount_cents, ai_assist_ratio,
                note, source, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 0, ?9, ?9)",
            params![
                id,
                input.user_id,
                input.occurred_on,
                input.normalized_category_code(),
                input.amount_cents,
                input.ai_assist_ratio,
                note,
                source,
                now,
            ],
        )?;

        insert_project_links(
            &tx,
            "expense",
            &id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        insert_tag_links(&tx, "expense", &id, &input.user_id, &input.tag_ids, &now)?;
        tx.commit()?;

        Ok(ExpenseRecord {
            id,
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            category_code: input.normalized_category_code(),
            amount_cents: input.amount_cents,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn create_learning_record(
        connection: &mut Connection,
        input: &CreateLearningRecordInput,
    ) -> Result<LearningRecord> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::LearningLevel,
            &input.normalized_application_level_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let id = new_id();
        let now = now_string();
        let source = input.normalized_source();
        let note = input.normalized_note();
        let started_at = normalize_optional_string(&input.started_at);
        let ended_at = normalize_optional_string(&input.ended_at);

        tx.execute(
            "INSERT INTO learning_records(
                id, user_id, occurred_on, started_at, ended_at, content, duration_minutes,
                application_level_code, efficiency_score, ai_assist_ratio, note, source,
                is_public_pool, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, 0, ?14, ?14)",
            params![
                id,
                input.user_id,
                input.occurred_on,
                started_at,
                ended_at,
                input.content.trim(),
                input.duration_minutes,
                input.normalized_application_level_code(),
                input.efficiency_score,
                input.ai_assist_ratio,
                note,
                source,
                input.is_public_pool as i32,
                now,
            ],
        )?;

        insert_project_links(
            &tx,
            "learning",
            &id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        insert_tag_links(&tx, "learning", &id, &input.user_id, &input.tag_ids, &now)?;
        tx.commit()?;

        Ok(LearningRecord {
            id,
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            started_at: normalize_optional_string(&input.started_at),
            ended_at: normalize_optional_string(&input.ended_at),
            content: input.content.trim().to_string(),
            duration_minutes: input.duration_minutes,
            application_level_code: input.normalized_application_level_code(),
            efficiency_score: input.efficiency_score,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            is_public_pool: input.is_public_pool,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn create_project(
        connection: &mut Connection,
        input: &CreateProjectInput,
    ) -> Result<Project> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::ProjectStatus,
            &input.normalized_status_code(),
        )?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let id = new_id();
        let now = now_string();
        let note = input.normalized_note();
        let ended_on = input.normalized_ended_on();

        tx.execute(
            "INSERT INTO projects(
                id, user_id, name, status_code, started_on, ended_on, ai_enable_ratio,
                score, note, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 0, ?10, ?10)",
            params![
                id,
                input.user_id,
                input.normalized_name(),
                input.normalized_status_code(),
                input.started_on,
                ended_on,
                input.ai_enable_ratio,
                input.score,
                note,
                now,
            ],
        )?;

        tx.execute(
            "INSERT INTO project_members(project_id, user_id, role, created_at)
             VALUES (?1, ?2, 'owner', ?3)",
            params![id, input.user_id, now],
        )?;
        insert_tag_links(&tx, "project", &id, &input.user_id, &input.tag_ids, &now)?;
        tx.commit()?;

        Ok(Project {
            id,
            user_id: input.user_id.clone(),
            name: input.normalized_name(),
            status_code: input.normalized_status_code(),
            started_on: input.started_on.clone(),
            ended_on,
            ai_enable_ratio: input.ai_enable_ratio,
            score: input.score,
            note,
            is_deleted: false,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn create_tag(connection: &mut Connection, input: &CreateTagInput) -> Result<Tag> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        if let Some(parent_tag_id) = input.normalized_parent_tag_id() {
            ensure_tag_exists(&tx, &input.user_id, &parent_tag_id)?;
        }

        let id = new_id();
        let now = now_string();
        let emoji = input.normalized_emoji();
        let tag_group = input.normalized_tag_group()?;
        let scope = input.normalized_scope()?;
        let parent_tag_id = input.normalized_parent_tag_id();
        let status = input.normalized_status();
        let level = input.resolved_level();
        let sort_order = input.resolved_sort_order();

        tx.execute(
            "INSERT INTO tags(
                id, user_id, name, emoji, tag_group, scope, parent_tag_id, level,
                status, sort_order, is_system, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 0, ?11, ?11)",
            params![
                id,
                input.user_id,
                input.normalized_name(),
                emoji,
                tag_group,
                scope,
                parent_tag_id,
                level,
                status,
                sort_order,
                now,
            ],
        )?;
        tx.commit()?;

        Ok(Tag {
            id,
            user_id: input.user_id.clone(),
            name: input.normalized_name(),
            emoji,
            tag_group,
            scope,
            parent_tag_id,
            level,
            status,
            sort_order,
            is_system: false,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn list_tags(connection: &Connection, user_id: &str) -> Result<Vec<Tag>> {
        ensure_user_exists(connection, user_id)?;

        let mut statement = connection.prepare(
            "SELECT id, user_id, name, emoji, tag_group, scope, parent_tag_id, level,
                    status, sort_order, is_system, created_at, updated_at
             FROM tags
             WHERE user_id = ?1
             ORDER BY sort_order ASC, level ASC, name COLLATE NOCASE ASC",
        )?;

        let rows = statement.query_map([user_id], |row| {
            Ok(Tag {
                id: row.get(0)?,
                user_id: row.get(1)?,
                name: row.get(2)?,
                emoji: row.get(3)?,
                tag_group: row.get(4)?,
                scope: row.get(5)?,
                parent_tag_id: row.get(6)?,
                level: row.get(7)?,
                status: row.get(8)?,
                sort_order: row.get(9)?,
                is_system: row.get(10)?,
                created_at: row.get(11)?,
                updated_at: row.get(12)?,
            })
        })?;

        let mut result = Vec::new();
        for row in rows {
            result.push(row?);
        }
        Ok(result)
    }

    pub fn update_tag(connection: &mut Connection, tag_id: &str, input: &CreateTagInput) -> Result<Tag> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        let existing = tx
            .query_row(
                "SELECT is_system, created_at
                 FROM tags
                 WHERE id = ?1 AND user_id = ?2
                 LIMIT 1",
                params![tag_id, input.user_id],
                |row| Ok((row.get::<_, i64>(0)? == 1, row.get::<_, String>(1)?)),
            )
            .optional()?
            .ok_or_else(|| LifeOsError::InvalidInput(format!("tag not found: {tag_id}")))?;
        if let Some(parent_tag_id) = input.normalized_parent_tag_id() {
            if parent_tag_id == tag_id {
                return Err(LifeOsError::InvalidInput(
                    "parent_tag_id cannot be the same as tag_id".to_string(),
                ));
            }
            ensure_tag_exists(&tx, &input.user_id, &parent_tag_id)?;
        }

        let now = now_string();
        let emoji = input.normalized_emoji();
        let tag_group = input.normalized_tag_group()?;
        let scope = input.normalized_scope()?;
        let parent_tag_id = input.normalized_parent_tag_id();
        let status = input.normalized_status();
        let level = input.resolved_level();
        let sort_order = input.resolved_sort_order();
        let name = input.normalized_name();

        tx.execute(
            "UPDATE tags
             SET name = ?3,
                 emoji = ?4,
                 tag_group = ?5,
                 scope = ?6,
                 parent_tag_id = ?7,
                 level = ?8,
                 status = ?9,
                 sort_order = ?10,
                 updated_at = ?11
             WHERE id = ?1 AND user_id = ?2",
            params![
                tag_id,
                input.user_id,
                name,
                emoji,
                tag_group,
                scope,
                parent_tag_id,
                level,
                status,
                sort_order,
                now,
            ],
        )?;
        tx.commit()?;

        Ok(Tag {
            id: tag_id.to_string(),
            user_id: input.user_id.clone(),
            name,
            emoji,
            tag_group,
            scope,
            parent_tag_id,
            level,
            status,
            sort_order,
            is_system: existing.0,
            created_at: existing.1,
            updated_at: now,
        })
    }

    pub fn delete_tag(connection: &mut Connection, user_id: &str, tag_id: &str) -> Result<()> {
        let tx = connection.transaction()?;
        ensure_user_exists(&tx, user_id)?;
        ensure_tag_exists(&tx, user_id, tag_id)?;

        let in_use = tx
            .query_row(
                "SELECT EXISTS(
                    SELECT 1 FROM record_tag_links
                    WHERE tag_id = ?1 AND user_id = ?2
                    LIMIT 1
                 )",
                params![tag_id, user_id],
                |row| row.get::<_, i64>(0),
            )?;
        if in_use == 1 {
            return Err(LifeOsError::InvalidInput(
                "tag is still referenced by records and cannot be deleted".to_string(),
            ));
        }

        tx.execute(
            "UPDATE tags SET parent_tag_id = NULL WHERE parent_tag_id = ?1 AND user_id = ?2",
            params![tag_id, user_id],
        )?;
        tx.execute(
            "DELETE FROM tags WHERE id = ?1 AND user_id = ?2",
            params![tag_id, user_id],
        )?;
        tx.commit()?;
        Ok(())
    }

    pub fn get_today_overview(
        connection: &Connection,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodayOverview> {
        ensure_user_exists(connection, user_id)?;
        let date = NaiveDate::parse_from_str(anchor_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid anchor_date: {error}")))?;
        let tz: Tz = timezone
            .parse()
            .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))?;

        let start_local = date
            .and_hms_opt(0, 0, 0)
            .ok_or_else(|| LifeOsError::InvalidInput("invalid start of day".to_string()))?;
        let end_local = date
            .checked_add_days(Days::new(1))
            .and_then(|next| next.and_hms_opt(0, 0, 0))
            .ok_or_else(|| LifeOsError::InvalidInput("invalid end of day".to_string()))?;

        let start_utc = local_to_utc(&tz, start_local)?;
        let end_utc = local_to_utc(&tz, end_local)?;

        let mut total_time_minutes = 0_i64;
        let mut total_work_minutes = 0_i64;

        let mut statement = connection.prepare(
            "SELECT started_at, ended_at, category_code
             FROM time_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND started_at < ?2
               AND ended_at > ?3",
        )?;
        let rows = statement.query_map(
            params![user_id, to_utc_string(end_utc), to_utc_string(start_utc)],
            |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                ))
            },
        )?;

        for row in rows {
            let (started_at, ended_at, category_code) = row?;
            let started_at = parse_rfc3339_utc(&started_at)?;
            let ended_at = parse_rfc3339_utc(&ended_at)?;
            let overlap = overlap_minutes(started_at, ended_at, start_utc, end_utc);
            total_time_minutes += overlap;
            if category_code == "work" {
                total_work_minutes += overlap;
            }
        }

        let total_learning_minutes = connection.query_row(
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM learning_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on = ?2",
            params![user_id, anchor_date],
            |row| row.get::<_, i64>(0),
        )?;

        let total_income_cents = connection.query_row(
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on = ?2",
            params![user_id, anchor_date],
            |row| row.get::<_, i64>(0),
        )?;

        let total_expense_cents = connection.query_row(
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM expense_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on = ?2",
            params![user_id, anchor_date],
            |row| row.get::<_, i64>(0),
        )?;

        Ok(TodayOverview {
            user_id: user_id.to_string(),
            anchor_date: anchor_date.to_string(),
            timezone: timezone.to_string(),
            total_income_cents,
            total_expense_cents,
            net_income_cents: total_income_cents - total_expense_cents,
            total_time_minutes,
            total_work_minutes,
            total_learning_minutes,
        })
    }

    pub fn get_today_goal_progress(
        connection: &Connection,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodayGoalProgress> {
        let overview = Self::get_today_overview(connection, user_id, anchor_date, timezone)?;
        let work_target = load_int_setting(connection, user_id, "today_work_target_minutes", 180)?;
        let learning_target =
            load_int_setting(connection, user_id, "today_learning_target_minutes", 60)?;

        Ok(TodayGoalProgress {
            user_id: user_id.to_string(),
            anchor_date: anchor_date.to_string(),
            items: vec![
                TodayGoalProgressItem {
                    key: "work_minutes".to_string(),
                    title: "工作目标".to_string(),
                    unit: "分钟".to_string(),
                    target_value: work_target,
                    completed_value: overview.total_work_minutes,
                    progress_ratio_bps: progress_bps(overview.total_work_minutes, work_target),
                    status: progress_status(overview.total_work_minutes, work_target),
                },
                TodayGoalProgressItem {
                    key: "learning_minutes".to_string(),
                    title: "学习目标".to_string(),
                    unit: "分钟".to_string(),
                    target_value: learning_target,
                    completed_value: overview.total_learning_minutes,
                    progress_ratio_bps: progress_bps(
                        overview.total_learning_minutes,
                        learning_target,
                    ),
                    status: progress_status(overview.total_learning_minutes, learning_target),
                },
            ],
        })
    }

    pub fn get_today_alerts(
        connection: &Connection,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodayAlerts> {
        let overview = Self::get_today_overview(connection, user_id, anchor_date, timezone)?;
        let work_target = load_int_setting(connection, user_id, "today_work_target_minutes", 180)?;
        let learning_target =
            load_int_setting(connection, user_id, "today_learning_target_minutes", 60)?;
        let snapshot = load_today_snapshot(connection, user_id, anchor_date)?;

        let mut items = Vec::new();
        if overview.total_work_minutes == 0 && overview.total_learning_minutes == 0 {
            items.push(TodayAlert {
                code: "no_focus_records".to_string(),
                title: "缺少有效投入记录".to_string(),
                message: "今天还没有工作或学习记录，数据可能不足以判断经营状态。".to_string(),
                severity: "warning".to_string(),
            });
        }
        if overview.total_work_minutes > 0 && overview.net_income_cents <= 0 {
            items.push(TodayAlert {
                code: "work_without_positive_income".to_string(),
                title: "有投入但净收入未转正".to_string(),
                message: "今天已有工作投入，但净收入仍未转正，建议检查回款或支出口径。".to_string(),
                severity: "warning".to_string(),
            });
        }
        if overview.total_work_minutes < work_target {
            items.push(TodayAlert {
                code: "work_target_behind".to_string(),
                title: "工作目标未达标".to_string(),
                message: format!(
                    "当前工作 {} 分钟，距离目标 {} 分钟还有差距。",
                    overview.total_work_minutes, work_target
                ),
                severity: if overview.total_work_minutes == 0 {
                    "critical".to_string()
                } else {
                    "info".to_string()
                },
            });
        }
        if overview.total_learning_minutes < learning_target {
            items.push(TodayAlert {
                code: "learning_target_behind".to_string(),
                title: "学习目标未达标".to_string(),
                message: format!(
                    "当前学习 {} 分钟，距离目标 {} 分钟还有差距。",
                    overview.total_learning_minutes, learning_target
                ),
                severity: "info".to_string(),
            });
        }
        if let Some(snapshot) = snapshot {
            if let Some(time_debt_cents) = snapshot.time_debt_cents
                && time_debt_cents > 0
            {
                items.push(TodayAlert {
                    code: "time_debt_positive".to_string(),
                    title: "时间债仍为正".to_string(),
                    message: format!(
                        "当前时间债约 ¥{:.2}，今天的时薪尚未追平目标。",
                        time_debt_cents as f64 / 100.0
                    ),
                    severity: "warning".to_string(),
                });
            }
            if let Some(passive_cover_ratio) = snapshot.passive_cover_ratio
                && passive_cover_ratio < 1.0
            {
                items.push(TodayAlert {
                    code: "passive_cover_below_one".to_string(),
                    title: "被动覆盖率不足".to_string(),
                    message: format!(
                        "当前被动覆盖率 {:.1}%，仍未覆盖必要支出。",
                        passive_cover_ratio * 100.0
                    ),
                    severity: "info".to_string(),
                });
            }
        }

        Ok(TodayAlerts {
            user_id: user_id.to_string(),
            anchor_date: anchor_date.to_string(),
            items,
        })
    }

    pub fn get_today_summary(
        connection: &Connection,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodaySummary> {
        let overview = Self::get_today_overview(connection, user_id, anchor_date, timezone)?;
        let alerts = Self::get_today_alerts(connection, user_id, anchor_date, timezone)?;
        let snapshot = load_today_snapshot(connection, user_id, anchor_date)?;
        let ideal_hourly_rate_cents = connection.query_row(
            "SELECT COALESCE(ideal_hourly_rate_cents, 0)
             FROM users
             WHERE id = ?1
             LIMIT 1",
            [user_id],
            |row| row.get::<_, i64>(0),
        )?;
        let actual_hourly_rate_cents = if overview.total_work_minutes > 0 {
            Some((overview.total_income_cents * 60) / overview.total_work_minutes)
        } else {
            None
        };
        let finance_status = if overview.net_income_cents > 0 {
            "positive".to_string()
        } else if overview.net_income_cents < 0 {
            "negative".to_string()
        } else {
            "neutral".to_string()
        };
        let work_status = if overview.total_work_minutes >= load_int_setting(
            connection,
            user_id,
            "today_work_target_minutes",
            180,
        )? {
            "on_track".to_string()
        } else if overview.total_work_minutes == 0 {
            "missing".to_string()
        } else {
            "behind".to_string()
        };
        let learning_status = if overview.total_learning_minutes >= load_int_setting(
            connection,
            user_id,
            "today_learning_target_minutes",
            60,
        )? {
            "on_track".to_string()
        } else if overview.total_learning_minutes == 0 {
            "missing".to_string()
        } else {
            "behind".to_string()
        };

        let should_review = !alerts.items.is_empty()
            || overview.net_income_cents < 0
            || overview.total_work_minutes == 0
            || overview.total_learning_minutes == 0;
        let freedom_cents = snapshot.as_ref().and_then(|item| item.freedom_cents);
        let passive_cover_ratio_bps = snapshot
            .as_ref()
            .and_then(|item| item.passive_cover_ratio.map(|value| (value * 10_000.0).round() as i64));

        let headline = build_today_headline(
            &finance_status,
            &work_status,
            &learning_status,
            overview.net_income_cents,
            overview.total_work_minutes,
            overview.total_learning_minutes,
            freedom_cents,
            passive_cover_ratio_bps,
        );

        Ok(TodaySummary {
            user_id: user_id.to_string(),
            anchor_date: anchor_date.to_string(),
            headline,
            finance_status,
            work_status,
            learning_status,
            should_review,
            actual_hourly_rate_cents,
            ideal_hourly_rate_cents,
            freedom_cents,
            passive_cover_ratio_bps,
            alerts: alerts.items,
        })
    }

    pub fn update_time_record(
        connection: &mut Connection,
        record_id: &str,
        input: &CreateTimeRecordInput,
    ) -> Result<TimeRecord> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_active_record_exists(&tx, RecordKind::Time, record_id, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::TimeCategory,
            &input.normalized_category_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let now = now_string();
        let started_at = to_utc_string(input.started_at()?);
        let ended_at = to_utc_string(input.ended_at()?);
        let duration_minutes = input.duration_minutes()?;
        let source = input.normalized_source();
        let note = input.normalized_note();

        tx.execute(
            "UPDATE time_records
             SET started_at = ?1,
                 ended_at = ?2,
                 duration_minutes = ?3,
                 category_code = ?4,
                 efficiency_score = ?5,
                 value_score = ?6,
                 state_score = ?7,
                 ai_assist_ratio = ?8,
                 note = ?9,
                 source = ?10,
                 is_public_pool = ?11,
                 updated_at = ?12
             WHERE id = ?13
               AND user_id = ?14
               AND is_deleted = 0",
            params![
                started_at,
                ended_at,
                duration_minutes,
                input.normalized_category_code(),
                input.efficiency_score,
                input.value_score,
                input.state_score,
                input.ai_assist_ratio,
                note,
                source,
                input.is_public_pool as i32,
                now,
                record_id,
                input.user_id,
            ],
        )?;

        replace_project_links(
            &tx,
            RecordKind::Time,
            record_id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        replace_tag_links(
            &tx,
            RecordKind::Time,
            record_id,
            &input.user_id,
            &input.tag_ids,
            &now,
        )?;
        tx.commit()?;

        Ok(TimeRecord {
            id: record_id.to_string(),
            user_id: input.user_id.clone(),
            started_at,
            ended_at,
            duration_minutes,
            category_code: input.normalized_category_code(),
            efficiency_score: input.efficiency_score,
            value_score: input.value_score,
            state_score: input.state_score,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            is_public_pool: input.is_public_pool,
            created_at: String::new(),
            updated_at: now,
        })
    }

    pub fn update_income_record(
        connection: &mut Connection,
        record_id: &str,
        input: &CreateIncomeRecordInput,
    ) -> Result<IncomeRecord> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_active_record_exists(&tx, RecordKind::Income, record_id, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::IncomeType,
            &input.normalized_type_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let now = now_string();
        let source = input.normalized_source();
        let note = input.normalized_note();
        tx.execute(
            "UPDATE income_records
             SET occurred_on = ?1,
                 source_name = ?2,
                 type_code = ?3,
                 amount_cents = ?4,
                 is_passive = ?5,
                 ai_assist_ratio = ?6,
                 note = ?7,
                 source = ?8,
                 is_public_pool = ?9,
                 updated_at = ?10
             WHERE id = ?11
               AND user_id = ?12
               AND is_deleted = 0",
            params![
                input.occurred_on,
                input.source_name.trim(),
                input.normalized_type_code(),
                input.amount_cents,
                input.is_passive as i32,
                input.ai_assist_ratio,
                note,
                source,
                input.is_public_pool as i32,
                now,
                record_id,
                input.user_id,
            ],
        )?;
        replace_project_links(
            &tx,
            RecordKind::Income,
            record_id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        replace_tag_links(
            &tx,
            RecordKind::Income,
            record_id,
            &input.user_id,
            &input.tag_ids,
            &now,
        )?;
        tx.commit()?;

        Ok(IncomeRecord {
            id: record_id.to_string(),
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            source_name: input.source_name.trim().to_string(),
            type_code: input.normalized_type_code(),
            amount_cents: input.amount_cents,
            is_passive: input.is_passive,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            is_public_pool: input.is_public_pool,
            created_at: String::new(),
            updated_at: now,
        })
    }

    pub fn update_expense_record(
        connection: &mut Connection,
        record_id: &str,
        input: &CreateExpenseRecordInput,
    ) -> Result<ExpenseRecord> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_active_record_exists(&tx, RecordKind::Expense, record_id, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::ExpenseCategory,
            &input.normalized_category_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let now = now_string();
        let source = input.normalized_source();
        let note = input.normalized_note();
        tx.execute(
            "UPDATE expense_records
             SET occurred_on = ?1,
                 category_code = ?2,
                 amount_cents = ?3,
                 ai_assist_ratio = ?4,
                 note = ?5,
                 source = ?6,
                 updated_at = ?7
             WHERE id = ?8
               AND user_id = ?9
               AND is_deleted = 0",
            params![
                input.occurred_on,
                input.normalized_category_code(),
                input.amount_cents,
                input.ai_assist_ratio,
                note,
                source,
                now,
                record_id,
                input.user_id,
            ],
        )?;
        replace_project_links(
            &tx,
            RecordKind::Expense,
            record_id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        replace_tag_links(
            &tx,
            RecordKind::Expense,
            record_id,
            &input.user_id,
            &input.tag_ids,
            &now,
        )?;
        tx.commit()?;

        Ok(ExpenseRecord {
            id: record_id.to_string(),
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            category_code: input.normalized_category_code(),
            amount_cents: input.amount_cents,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            created_at: String::new(),
            updated_at: now,
        })
    }

    pub fn update_learning_record(
        connection: &mut Connection,
        record_id: &str,
        input: &CreateLearningRecordInput,
    ) -> Result<LearningRecord> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_active_record_exists(&tx, RecordKind::Learning, record_id, &input.user_id)?;
        upsert_dimension_code(
            &tx,
            DimensionKind::LearningLevel,
            &input.normalized_application_level_code(),
        )?;
        ensure_project_allocations_exist(&tx, &input.user_id, &input.project_allocations)?;
        ensure_tags_exist(&tx, &input.user_id, &input.tag_ids)?;

        let now = now_string();
        let source = input.normalized_source();
        let note = input.normalized_note();
        let started_at = normalize_optional_string(&input.started_at);
        let ended_at = normalize_optional_string(&input.ended_at);
        tx.execute(
            "UPDATE learning_records
             SET occurred_on = ?1,
                 started_at = ?2,
                 ended_at = ?3,
                 content = ?4,
                 duration_minutes = ?5,
                 application_level_code = ?6,
                 efficiency_score = ?7,
                 ai_assist_ratio = ?8,
                 note = ?9,
                 source = ?10,
                 is_public_pool = ?11,
                 updated_at = ?12
             WHERE id = ?13
               AND user_id = ?14
               AND is_deleted = 0",
            params![
                input.occurred_on,
                started_at,
                ended_at,
                input.content.trim(),
                input.duration_minutes,
                input.normalized_application_level_code(),
                input.efficiency_score,
                input.ai_assist_ratio,
                note,
                source,
                input.is_public_pool as i32,
                now,
                record_id,
                input.user_id,
            ],
        )?;
        replace_project_links(
            &tx,
            RecordKind::Learning,
            record_id,
            &input.user_id,
            &input.project_allocations,
            &now,
        )?;
        replace_tag_links(
            &tx,
            RecordKind::Learning,
            record_id,
            &input.user_id,
            &input.tag_ids,
            &now,
        )?;
        tx.commit()?;

        Ok(LearningRecord {
            id: record_id.to_string(),
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            started_at: normalize_optional_string(&input.started_at),
            ended_at: normalize_optional_string(&input.ended_at),
            content: input.content.trim().to_string(),
            duration_minutes: input.duration_minutes,
            application_level_code: input.normalized_application_level_code(),
            efficiency_score: input.efficiency_score,
            ai_assist_ratio: input.ai_assist_ratio,
            note,
            source,
            is_public_pool: input.is_public_pool,
            created_at: String::new(),
            updated_at: now,
        })
    }

    pub fn soft_delete_record(
        connection: &mut Connection,
        kind: RecordKind,
        user_id: &str,
        record_id: &str,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        ensure_active_record_exists(connection, kind, record_id, user_id)?;
        let sql = format!(
            "UPDATE {}
             SET is_deleted = 1,
                 updated_at = ?1
             WHERE id = ?2
               AND user_id = ?3
               AND is_deleted = 0",
            kind.table_name()
        );
        connection.execute(&sql, params![now_string(), record_id, user_id])?;
        Ok(())
    }

    pub fn get_recent_records(
        connection: &Connection,
        user_id: &str,
        timezone: &str,
        limit: usize,
    ) -> Result<Vec<RecentRecordItem>> {
        ensure_user_exists(connection, user_id)?;
        let safe_limit = limit.max(1).min(200) as i64;
        let mut statement = connection.prepare(
            "SELECT record_id, kind, occurred_at, title, detail
             FROM (
               SELECT id AS record_id, 'time' AS kind, started_at AS occurred_at, category_code AS title,
                      COALESCE(note, '') AS detail
               FROM time_records
               WHERE user_id = ?1 AND is_deleted = 0
               UNION ALL
               SELECT id AS record_id, 'income' AS kind, occurred_on AS occurred_at, source_name AS title,
                      CAST(amount_cents AS TEXT) || ' cents' ||
                      CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
               FROM income_records
               WHERE user_id = ?1 AND is_deleted = 0
               UNION ALL
               SELECT id AS record_id, 'expense' AS kind, occurred_on AS occurred_at, category_code AS title,
                      CAST(amount_cents AS TEXT) || ' cents' ||
                      CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
               FROM expense_records
               WHERE user_id = ?1 AND is_deleted = 0
               UNION ALL
               SELECT id AS record_id, 'learning' AS kind, COALESCE(started_at, occurred_on) AS occurred_at, content AS title,
                      CAST(duration_minutes AS TEXT) || ' min' ||
                      CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
               FROM learning_records
               WHERE user_id = ?1 AND is_deleted = 0
             )
             ORDER BY occurred_at DESC
             LIMIT ?2",
        )?;
        let rows = statement.query_map(params![user_id, safe_limit], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
            ))
        })?;
        let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
        raw_rows
            .into_iter()
            .map(|(record_id, kind, occurred_at, title, detail)| {
                Ok(RecentRecordItem {
                    record_id,
                    kind: parse_record_kind(&kind)?,
                    occurred_at: normalize_occurred_at(occurred_at, timezone)?,
                    title,
                    detail,
                })
            })
            .collect()
    }

    pub fn get_records_for_date(
        connection: &Connection,
        user_id: &str,
        date: &str,
        timezone: &str,
        limit: usize,
    ) -> Result<Vec<RecentRecordItem>> {
        ensure_user_exists(connection, user_id)?;
        let date = NaiveDate::parse_from_str(date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid date: {error}")))?;
        let tz: Tz = timezone
            .parse()
            .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))?;
        let start_local = date
            .and_hms_opt(0, 0, 0)
            .ok_or_else(|| LifeOsError::InvalidInput("invalid start of day".to_string()))?;
        let end_local = date
            .checked_add_days(Days::new(1))
            .and_then(|next| next.and_hms_opt(0, 0, 0))
            .ok_or_else(|| LifeOsError::InvalidInput("invalid end of day".to_string()))?;
        let start_utc = to_utc_string(local_to_utc(&tz, start_local)?);
        let end_utc = to_utc_string(local_to_utc(&tz, end_local)?);
        let safe_limit = limit.max(1).min(200) as i64;

        let mut statement = connection.prepare(
            "SELECT record_id, kind, occurred_at, title, detail
             FROM (
               SELECT id AS record_id, 'time' AS kind, started_at AS occurred_at, category_code AS title,
                      COALESCE(note, '') AS detail
               FROM time_records
               WHERE user_id = ?1 AND is_deleted = 0 AND started_at >= ?2 AND started_at < ?3
               UNION ALL
               SELECT id AS record_id, 'income' AS kind, occurred_on AS occurred_at, source_name AS title,
                      CAST(amount_cents AS TEXT) || ' cents' ||
                      CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
               FROM income_records
               WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on = ?4
               UNION ALL
               SELECT id AS record_id, 'expense' AS kind, occurred_on AS occurred_at, category_code AS title,
                      CAST(amount_cents AS TEXT) || ' cents' ||
                      CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
               FROM expense_records
               WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on = ?4
               UNION ALL
               SELECT id AS record_id, 'learning' AS kind, COALESCE(started_at, occurred_on) AS occurred_at, content AS title,
                      CAST(duration_minutes AS TEXT) || ' min' ||
                      CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
               FROM learning_records
               WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on = ?4
             )
             ORDER BY occurred_at DESC
             LIMIT ?5",
        )?;

        let rows = statement.query_map(
            params![user_id, start_utc, end_utc, date.to_string(), safe_limit],
            |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, String>(4)?,
                ))
            },
        )?;
        let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
        raw_rows
            .into_iter()
            .map(|(record_id, kind, occurred_at, title, detail)| {
                Ok(RecentRecordItem {
                    record_id,
                    kind: parse_record_kind(&kind)?,
                    occurred_at: normalize_occurred_at(occurred_at, timezone)?,
                    title,
                    detail,
                })
            })
            .collect()
    }

    pub fn get_time_record_snapshot(
        connection: &Connection,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<TimeRecordSnapshot>> {
        ensure_user_exists(connection, user_id)?;
        let raw = connection
            .query_row(
                "SELECT started_at, ended_at, category_code, efficiency_score, value_score,
                        state_score, ai_assist_ratio, note
                 FROM time_records
                 WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0
                 LIMIT 1",
                params![record_id, user_id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, String>(2)?,
                        row.get::<_, Option<i32>>(3)?,
                        row.get::<_, Option<i32>>(4)?,
                        row.get::<_, Option<i32>>(5)?,
                        row.get::<_, Option<i32>>(6)?,
                        row.get::<_, Option<String>>(7)?,
                    ))
                },
            )
            .optional()?;
        raw.map(
            |(
                started_at,
                ended_at,
                category_code,
                efficiency_score,
                value_score,
                state_score,
                ai_assist_ratio,
                note,
            )| {
                Ok(TimeRecordSnapshot {
                    record_id: record_id.to_string(),
                    started_at,
                    ended_at,
                    category_code,
                    efficiency_score,
                    value_score,
                    state_score,
                    ai_assist_ratio,
                    note,
                    project_allocations: load_project_allocations(
                        connection,
                        RecordKind::Time,
                        record_id,
                    )?,
                    tag_ids: load_tag_ids(connection, RecordKind::Time, record_id)?,
                })
            },
        )
        .transpose()
    }

    pub fn get_income_record_snapshot(
        connection: &Connection,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<IncomeRecordSnapshot>> {
        ensure_user_exists(connection, user_id)?;
        let raw = connection
            .query_row(
                "SELECT occurred_on, source_name, type_code, amount_cents, is_passive,
                        ai_assist_ratio, note, is_public_pool
                 FROM income_records
                 WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0
                 LIMIT 1",
                params![record_id, user_id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, String>(2)?,
                        row.get::<_, i64>(3)?,
                        row.get::<_, i64>(4)?,
                        row.get::<_, Option<i32>>(5)?,
                        row.get::<_, Option<String>>(6)?,
                        row.get::<_, i64>(7)?,
                    ))
                },
            )
            .optional()?;
        raw.map(
            |(
                occurred_on,
                source_name,
                type_code,
                amount_cents,
                is_passive,
                ai_assist_ratio,
                note,
                is_public_pool,
            )| {
                Ok(IncomeRecordSnapshot {
                    record_id: record_id.to_string(),
                    occurred_on,
                    source_name,
                    type_code,
                    amount_cents,
                    is_passive: is_passive == 1,
                    ai_assist_ratio,
                    note,
                    is_public_pool: is_public_pool == 1,
                    project_allocations: load_project_allocations(
                        connection,
                        RecordKind::Income,
                        record_id,
                    )?,
                    tag_ids: load_tag_ids(connection, RecordKind::Income, record_id)?,
                })
            },
        )
        .transpose()
    }

    pub fn get_expense_record_snapshot(
        connection: &Connection,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<ExpenseRecordSnapshot>> {
        ensure_user_exists(connection, user_id)?;
        let raw = connection
            .query_row(
                "SELECT occurred_on, category_code, amount_cents, ai_assist_ratio, note
                 FROM expense_records
                 WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0
                 LIMIT 1",
                params![record_id, user_id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, i64>(2)?,
                        row.get::<_, Option<i32>>(3)?,
                        row.get::<_, Option<String>>(4)?,
                    ))
                },
            )
            .optional()?;
        raw.map(
            |(occurred_on, category_code, amount_cents, ai_assist_ratio, note)| {
                Ok(ExpenseRecordSnapshot {
                    record_id: record_id.to_string(),
                    occurred_on,
                    category_code,
                    amount_cents,
                    ai_assist_ratio,
                    note,
                    project_allocations: load_project_allocations(
                        connection,
                        RecordKind::Expense,
                        record_id,
                    )?,
                    tag_ids: load_tag_ids(connection, RecordKind::Expense, record_id)?,
                })
            },
        )
        .transpose()
    }

    pub fn get_learning_record_snapshot(
        connection: &Connection,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<LearningRecordSnapshot>> {
        ensure_user_exists(connection, user_id)?;
        let raw = connection
            .query_row(
                "SELECT occurred_on, started_at, ended_at, content, duration_minutes,
                        application_level_code, efficiency_score, ai_assist_ratio, note, is_public_pool
                 FROM learning_records
                 WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0
                 LIMIT 1",
                params![record_id, user_id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, Option<String>>(1)?,
                        row.get::<_, Option<String>>(2)?,
                        row.get::<_, String>(3)?,
                        row.get::<_, i64>(4)?,
                        row.get::<_, String>(5)?,
                        row.get::<_, Option<i32>>(6)?,
                        row.get::<_, Option<i32>>(7)?,
                        row.get::<_, Option<String>>(8)?,
                        row.get::<_, i64>(9)?,
                    ))
                },
            )
            .optional()?;
        raw.map(
            |(
                occurred_on,
                started_at,
                ended_at,
                content,
                duration_minutes,
                application_level_code,
                efficiency_score,
                ai_assist_ratio,
                note,
                is_public_pool,
            )| {
                Ok(LearningRecordSnapshot {
                    record_id: record_id.to_string(),
                    occurred_on,
                    started_at,
                    ended_at,
                    content,
                    duration_minutes,
                    application_level_code,
                    efficiency_score,
                    ai_assist_ratio,
                    note,
                    is_public_pool: is_public_pool == 1,
                    project_allocations: load_project_allocations(
                        connection,
                        RecordKind::Learning,
                        record_id,
                    )?,
                    tag_ids: load_tag_ids(connection, RecordKind::Learning, record_id)?,
                })
            },
        )
        .transpose()
    }
}

#[derive(Copy, Clone)]
pub(crate) enum DimensionKind {
    ProjectStatus,
    TimeCategory,
    IncomeType,
    ExpenseCategory,
    LearningLevel,
}

impl DimensionKind {
    fn table_name(self) -> &'static str {
        match self {
            Self::ProjectStatus => "dim_project_status",
            Self::TimeCategory => "dim_time_categories",
            Self::IncomeType => "dim_income_types",
            Self::ExpenseCategory => "dim_expense_categories",
            Self::LearningLevel => "dim_learning_levels",
        }
    }
}

pub(crate) fn ensure_user_exists(connection: &Connection, user_id: &str) -> Result<()> {
    let exists = connection
        .query_row(
            "SELECT 1 FROM users WHERE id = ?1 LIMIT 1",
            [user_id],
            |row| row.get::<_, i64>(0),
        )
        .optional()?;

    if exists.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "user not found: {user_id}"
        )));
    }

    Ok(())
}

fn ensure_active_record_exists(
    connection: &Connection,
    kind: RecordKind,
    record_id: &str,
    user_id: &str,
) -> Result<()> {
    let sql = format!(
        "SELECT 1 FROM {} WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0 LIMIT 1",
        kind.table_name()
    );
    let exists = connection
        .query_row(&sql, params![record_id, user_id], |row| {
            row.get::<_, i64>(0)
        })
        .optional()?;
    if exists.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "{} record not found: {}",
            kind.as_str(),
            record_id
        )));
    }
    Ok(())
}

pub(crate) fn ensure_project_allocations_exist(
    connection: &Connection,
    user_id: &str,
    allocations: &[ProjectAllocation],
) -> Result<()> {
    for allocation in allocations {
        let exists = connection
            .query_row(
                "SELECT 1
                 FROM projects
                 WHERE id = ?1
                   AND user_id = ?2
                   AND is_deleted = 0
                 LIMIT 1",
                params![allocation.project_id, user_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()?;

        if exists.is_none() {
            return Err(LifeOsError::InvalidInput(format!(
                "project not found for allocation: {}",
                allocation.project_id
            )));
        }
    }
    Ok(())
}

pub(crate) fn ensure_tags_exist(
    connection: &Connection,
    user_id: &str,
    tag_ids: &[String],
) -> Result<()> {
    for tag_id in tag_ids {
        ensure_tag_exists(connection, user_id, tag_id)?;
    }
    Ok(())
}

pub(crate) fn ensure_tag_exists(
    connection: &Connection,
    user_id: &str,
    tag_id: &str,
) -> Result<()> {
    let exists = connection
        .query_row(
            "SELECT 1
             FROM tags
             WHERE id = ?1
               AND user_id = ?2
             LIMIT 1",
            params![tag_id, user_id],
            |row| row.get::<_, i64>(0),
        )
        .optional()?;

    if exists.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "tag not found: {tag_id}"
        )));
    }

    Ok(())
}

pub(crate) fn insert_project_links(
    connection: &Connection,
    record_kind: &str,
    record_id: &str,
    user_id: &str,
    allocations: &[ProjectAllocation],
    now: &str,
) -> Result<()> {
    for allocation in allocations {
        connection.execute(
            "INSERT INTO record_project_links(
                record_kind, record_id, project_id, user_id, weight_ratio, created_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                record_kind,
                record_id,
                allocation.project_id,
                user_id,
                allocation.weight_ratio,
                now,
            ],
        )?;
    }
    Ok(())
}

fn replace_project_links(
    connection: &Connection,
    kind: RecordKind,
    record_id: &str,
    user_id: &str,
    allocations: &[ProjectAllocation],
    now: &str,
) -> Result<()> {
    connection.execute(
        "DELETE FROM record_project_links WHERE record_kind = ?1 AND record_id = ?2",
        params![kind.as_str(), record_id],
    )?;
    insert_project_links(
        connection,
        kind.as_str(),
        record_id,
        user_id,
        allocations,
        now,
    )
}

pub(crate) fn insert_tag_links(
    connection: &Connection,
    record_kind: &str,
    record_id: &str,
    user_id: &str,
    tag_ids: &[String],
    now: &str,
) -> Result<()> {
    for tag_id in tag_ids {
        connection.execute(
            "INSERT INTO record_tag_links(
                record_kind, record_id, tag_id, user_id, created_at
             ) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![record_kind, record_id, tag_id, user_id, now],
        )?;
    }
    Ok(())
}

pub(crate) fn replace_tag_links(
    connection: &Connection,
    kind: RecordKind,
    record_id: &str,
    user_id: &str,
    tag_ids: &[String],
    now: &str,
) -> Result<()> {
    connection.execute(
        "DELETE FROM record_tag_links WHERE record_kind = ?1 AND record_id = ?2",
        params![kind.as_str(), record_id],
    )?;
    insert_tag_links(connection, kind.as_str(), record_id, user_id, tag_ids, now)
}

fn load_project_allocations(
    connection: &Connection,
    kind: RecordKind,
    record_id: &str,
) -> Result<Vec<ProjectAllocation>> {
    let mut statement = connection.prepare(
        "SELECT project_id, weight_ratio
         FROM record_project_links
         WHERE record_kind = ?1 AND record_id = ?2
         ORDER BY created_at ASC, project_id ASC",
    )?;
    let rows = statement.query_map(params![kind.as_str(), record_id], |row| {
        Ok(ProjectAllocation {
            project_id: row.get(0)?,
            weight_ratio: row.get(1)?,
        })
    })?;
    rows.collect::<std::result::Result<Vec<_>, _>>()
        .map_err(Into::into)
}

pub(crate) fn load_tag_ids(
    connection: &Connection,
    kind: RecordKind,
    record_id: &str,
) -> Result<Vec<String>> {
    let mut statement = connection.prepare(
        "SELECT tag_id
         FROM record_tag_links
         WHERE record_kind = ?1 AND record_id = ?2
         ORDER BY created_at ASC, tag_id ASC",
    )?;
    let rows = statement.query_map(params![kind.as_str(), record_id], |row| {
        row.get::<_, String>(0)
    })?;
    rows.collect::<std::result::Result<Vec<_>, _>>()
        .map_err(Into::into)
}

pub(crate) fn upsert_dimension_code(
    connection: &Connection,
    dimension_kind: DimensionKind,
    code: &str,
) -> Result<()> {
    let sql = format!(
        "SELECT 1 FROM {} WHERE code = ?1 LIMIT 1",
        dimension_kind.table_name()
    );
    let exists = connection
        .query_row(&sql, [code], |row| row.get::<_, i64>(0))
        .optional()?;

    if exists.is_some() {
        return Ok(());
    }

    let sql = format!(
        "INSERT INTO {}(
            code, display_name, sort_order, is_active, is_system, created_at, updated_at
         ) VALUES (?1, ?2, 1000, 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        dimension_kind.table_name()
    );
    connection.execute(&sql, params![code, humanize_code(code)])?;
    Ok(())
}

fn load_int_setting(
    connection: &Connection,
    user_id: &str,
    key: &str,
    default_value: i64,
) -> Result<i64> {
    let raw = connection
        .query_row(
            "SELECT value_json FROM settings WHERE user_id = ?1 AND key = ?2 LIMIT 1",
            params![user_id, key],
            |row| row.get::<_, String>(0),
        )
        .optional()?;
    let Some(raw) = raw else {
        return Ok(default_value);
    };
    let parsed: Value = serde_json::from_str(&raw).unwrap_or(Value::String(raw));
    Ok(match parsed {
        Value::Number(number) => number.as_i64().unwrap_or(default_value),
        Value::String(value) => value.trim().parse::<i64>().unwrap_or(default_value),
        Value::Object(map) => map
            .get("value")
            .and_then(Value::as_i64)
            .unwrap_or(default_value),
        _ => default_value,
    })
}

fn progress_bps(completed_value: i64, target_value: i64) -> i64 {
    if target_value <= 0 {
        return 0;
    }
    ((completed_value.max(0) as f64 / target_value as f64) * 10_000.0)
        .round()
        .clamp(0.0, 20_000.0) as i64
}

fn progress_status(completed_value: i64, target_value: i64) -> String {
    if target_value <= 0 {
        return "not_set".to_string();
    }
    if completed_value >= target_value {
        "done".to_string()
    } else if completed_value == 0 {
        "missing".to_string()
    } else {
        "in_progress".to_string()
    }
}

fn load_today_snapshot(
    connection: &Connection,
    user_id: &str,
    anchor_date: &str,
) -> Result<Option<crate::models::MetricSnapshotSummary>> {
    connection
        .query_row(
            "SELECT id, snapshot_date, window_type, hourly_rate_cents, time_debt_cents,
                    passive_cover_ratio, freedom_cents, total_income_cents, total_expense_cents,
                    total_work_minutes, generated_at
             FROM metric_snapshots
             WHERE user_id = ?1 AND snapshot_date = ?2 AND window_type = 'day'
             LIMIT 1",
            params![user_id, anchor_date],
            |row| {
                Ok(crate::models::MetricSnapshotSummary {
                    id: row.get(0)?,
                    snapshot_date: row.get(1)?,
                    window_type: row.get(2)?,
                    hourly_rate_cents: row.get(3)?,
                    time_debt_cents: row.get(4)?,
                    passive_cover_ratio: row.get(5)?,
                    freedom_cents: row.get(6)?,
                    total_income_cents: row.get(7)?,
                    total_expense_cents: row.get(8)?,
                    total_work_minutes: row.get(9)?,
                    generated_at: row.get(10)?,
                })
            },
        )
        .optional()
        .map_err(Into::into)
}

fn build_today_headline(
    finance_status: &str,
    work_status: &str,
    learning_status: &str,
    net_income_cents: i64,
    total_work_minutes: i64,
    total_learning_minutes: i64,
    freedom_cents: Option<i64>,
    passive_cover_ratio_bps: Option<i64>,
) -> String {
    let finance_line = match finance_status {
        "positive" => format!("净收入为正，约 ¥{:.2}", net_income_cents as f64 / 100.0),
        "negative" => format!("净收入为负，约 ¥{:.2}", net_income_cents as f64 / 100.0),
        _ => "收支持平".to_string(),
    };
    let work_line = match work_status {
        "on_track" => format!("工作 {} 分钟，节奏达标", total_work_minutes),
        "missing" => "今天还没有工作记录".to_string(),
        _ => format!("工作 {} 分钟，仍低于目标", total_work_minutes),
    };
    let learning_line = match learning_status {
        "on_track" => format!("学习 {} 分钟，投入稳定", total_learning_minutes),
        "missing" => "今天还没有学习记录".to_string(),
        _ => format!("学习 {} 分钟，仍低于目标", total_learning_minutes),
    };
    let freedom_line =
        freedom_cents.map(|value| format!("自由度金额 ¥{:.2}", value as f64 / 100.0));
    let cover_line =
        passive_cover_ratio_bps.map(|value| format!("被动覆盖率 {:.1}%", value as f64 / 100.0));

    [
        finance_line,
        work_line,
        learning_line,
        freedom_line.unwrap_or_default(),
        cover_line.unwrap_or_default(),
    ]
    .into_iter()
    .filter(|item| !item.trim().is_empty())
    .collect::<Vec<_>>()
    .join("，")
}

fn humanize_code(code: &str) -> String {
    code.split('_')
        .filter(|segment| !segment.is_empty())
        .map(|segment| {
            let mut chars = segment.chars();
            match chars.next() {
                Some(first) => format!("{}{}", first.to_uppercase(), chars.as_str()),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn parse_record_kind(value: &str) -> Result<RecordKind> {
    match value {
        "time" => Ok(RecordKind::Time),
        "income" => Ok(RecordKind::Income),
        "expense" => Ok(RecordKind::Expense),
        "learning" => Ok(RecordKind::Learning),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported record kind: {other}"
        ))),
    }
}

pub(crate) fn normalize_occurred_at(value: String, timezone: &str) -> Result<String> {
    if let Ok(parsed) = parse_rfc3339_utc(&value) {
        let tz: Tz = timezone
            .parse()
            .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))?;
        return Ok(parsed
            .with_timezone(&tz)
            .to_rfc3339_opts(chrono::SecondsFormat::Secs, true));
    }
    Ok(value)
}

fn local_to_utc(tz: &Tz, value: chrono::NaiveDateTime) -> Result<DateTime<Utc>> {
    match tz.from_local_datetime(&value) {
        LocalResult::Single(value) => Ok(value.with_timezone(&Utc)),
        LocalResult::Ambiguous(first, _) => Ok(first.with_timezone(&Utc)),
        LocalResult::None => Err(LifeOsError::InvalidInput(
            "failed to convert local time to UTC".to_string(),
        )),
    }
}

fn overlap_minutes(
    record_start: DateTime<Utc>,
    record_end: DateTime<Utc>,
    window_start: DateTime<Utc>,
    window_end: DateTime<Utc>,
) -> i64 {
    let start = record_start.max(window_start);
    let end = record_end.min(window_end);
    if end <= start {
        return 0;
    }
    (end - start).num_minutes()
}

pub(crate) fn now_string() -> String {
    Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
}

pub(crate) fn new_id() -> String {
    Uuid::now_v7().to_string()
}
