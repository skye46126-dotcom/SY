use chrono::{Datelike, Duration, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;
use rusqlite::{Connection, OptionalExtension, params};

use crate::error::{LifeOsError, Result};
use crate::models::{
    CreateProjectInput, Project, ProjectDetail, ProjectOption, ProjectOverview, RecentRecordItem,
    RecordKind,
};
use crate::repositories::record_repository::{
    DimensionKind, ensure_dimension_option_exists, ensure_tags_exist, ensure_user_exists,
    normalize_occurred_at, now_string,
};

pub struct ProjectRepository;

impl ProjectRepository {
    pub fn list_project_options(
        connection: &Connection,
        user_id: &str,
        include_done: bool,
    ) -> Result<Vec<ProjectOption>> {
        ensure_user_exists(connection, user_id)?;
        let sql = if include_done {
            "SELECT id, name, status_code
             FROM projects
             WHERE user_id = ?1 AND is_deleted = 0
             ORDER BY updated_at DESC, name COLLATE NOCASE ASC"
        } else {
            "SELECT id, name, status_code
             FROM projects
             WHERE user_id = ?1 AND is_deleted = 0 AND status_code != 'done'
             ORDER BY updated_at DESC, name COLLATE NOCASE ASC"
        };
        let mut statement = connection.prepare(sql)?;
        let rows = statement.query_map([user_id], |row| {
            Ok(ProjectOption {
                id: row.get(0)?,
                name: row.get(1)?,
                status_code: row.get(2)?,
            })
        })?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn list_projects(
        connection: &Connection,
        user_id: &str,
        status_filter: Option<&str>,
    ) -> Result<Vec<ProjectOverview>> {
        ensure_user_exists(connection, user_id)?;
        let normalized_status = status_filter
            .map(str::trim)
            .filter(|value| !value.is_empty() && *value != "all")
            .map(str::to_lowercase);

        let mut statement = connection.prepare(
            "SELECT
                p.id,
                p.name,
                p.status_code,
                p.score,
                COALESCE((
                    SELECT CAST(SUM(
                        t.duration_minutes * rpl.weight_ratio / (
                            SELECT SUM(weight_ratio)
                            FROM record_project_links
                            WHERE record_kind = 'time' AND record_id = t.id
                        )
                    ) AS INTEGER)
                    FROM time_records t
                    JOIN record_project_links rpl
                      ON rpl.record_kind = 'time'
                     AND rpl.record_id = t.id
                    WHERE rpl.project_id = p.id
                      AND t.is_deleted = 0
                ), 0) AS total_time_minutes,
                COALESCE((
                    SELECT CAST(SUM(
                        i.amount_cents * rpl.weight_ratio / (
                            SELECT SUM(weight_ratio)
                            FROM record_project_links
                            WHERE record_kind = 'income' AND record_id = i.id
                        )
                    ) AS INTEGER)
                    FROM income_records i
                    JOIN record_project_links rpl
                      ON rpl.record_kind = 'income'
                     AND rpl.record_id = i.id
                    WHERE rpl.project_id = p.id
                      AND i.is_deleted = 0
                ), 0) AS total_income_cents,
                COALESCE((
                    SELECT CAST(SUM(
                        e.amount_cents * rpl.weight_ratio / (
                            SELECT SUM(weight_ratio)
                            FROM record_project_links
                            WHERE record_kind = 'expense' AND record_id = e.id
                        )
                    ) AS INTEGER)
                    FROM expense_records e
                    JOIN record_project_links rpl
                      ON rpl.record_kind = 'expense'
                     AND rpl.record_id = e.id
                    WHERE rpl.project_id = p.id
                      AND e.is_deleted = 0
                ), 0) AS total_expense_cents
             FROM projects p
             WHERE p.user_id = ?1
               AND p.is_deleted = 0
               AND (?2 IS NULL OR p.status_code = ?2)
             ORDER BY p.updated_at DESC, p.name COLLATE NOCASE ASC",
        )?;
        let rows = statement.query_map(params![user_id, normalized_status], |row| {
            Ok(ProjectOverview {
                id: row.get(0)?,
                name: row.get(1)?,
                status_code: row.get(2)?,
                score: row.get(3)?,
                total_time_minutes: row.get(4)?,
                total_income_cents: row.get(5)?,
                total_expense_cents: row.get(6)?,
            })
        })?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn get_project_detail(
        connection: &Connection,
        user_id: &str,
        project_id: &str,
        timezone: &str,
        recent_limit: usize,
    ) -> Result<Option<ProjectDetail>> {
        ensure_user_exists(connection, user_id)?;
        let base = connection
            .query_row(
                "SELECT id, name, status_code, started_on, ended_on, ai_enable_ratio, score, note
                 FROM projects
                 WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0
                 LIMIT 1",
                params![project_id, user_id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, String>(2)?,
                        row.get::<_, String>(3)?,
                        row.get::<_, Option<String>>(4)?,
                        row.get::<_, Option<i32>>(5)?,
                        row.get::<_, Option<i32>>(6)?,
                        row.get::<_, Option<String>>(7)?,
                    ))
                },
            )
            .optional()?;
        let Some((id, name, status_code, started_on, ended_on, ai_enable_ratio, score, note)) =
            base
        else {
            return Ok(None);
        };

        let total_time_minutes = scalar_long(
            connection,
            "SELECT COALESCE(CAST(SUM(
                t.duration_minutes * rpl.weight_ratio / (
                    SELECT SUM(weight_ratio)
                    FROM record_project_links
                    WHERE record_kind = 'time' AND record_id = t.id
                )
            ) AS INTEGER), 0)
             FROM time_records t
             JOIN record_project_links rpl
               ON rpl.record_kind = 'time'
              AND rpl.record_id = t.id
             WHERE rpl.project_id = ?1 AND t.is_deleted = 0",
            project_id,
        )?;
        let total_income_cents = scalar_long(
            connection,
            "SELECT COALESCE(CAST(SUM(
                i.amount_cents * rpl.weight_ratio / (
                    SELECT SUM(weight_ratio)
                    FROM record_project_links
                    WHERE record_kind = 'income' AND record_id = i.id
                )
            ) AS INTEGER), 0)
             FROM income_records i
             JOIN record_project_links rpl
               ON rpl.record_kind = 'income'
              AND rpl.record_id = i.id
             WHERE rpl.project_id = ?1 AND i.is_deleted = 0",
            project_id,
        )?;
        let direct_expense_cents = scalar_long(
            connection,
            "SELECT COALESCE(CAST(SUM(
                e.amount_cents * rpl.weight_ratio / (
                    SELECT SUM(weight_ratio)
                    FROM record_project_links
                    WHERE record_kind = 'expense' AND record_id = e.id
                )
            ) AS INTEGER), 0)
             FROM expense_records e
             JOIN record_project_links rpl
               ON rpl.record_kind = 'expense'
              AND rpl.record_id = e.id
             WHERE rpl.project_id = ?1 AND e.is_deleted = 0",
            project_id,
        )?;
        let total_learning_minutes = scalar_long(
            connection,
            "SELECT COALESCE(CAST(SUM(
                l.duration_minutes * rpl.weight_ratio / (
                    SELECT SUM(weight_ratio)
                    FROM record_project_links
                    WHERE record_kind = 'learning' AND record_id = l.id
                )
            ) AS INTEGER), 0)
             FROM learning_records l
             JOIN record_project_links rpl
               ON rpl.record_kind = 'learning'
              AND rpl.record_id = l.id
             WHERE rpl.project_id = ?1 AND l.is_deleted = 0",
            project_id,
        )?;
        let time_record_count = scalar_long(
            connection,
            "SELECT COUNT(*)
             FROM time_records t
             JOIN record_project_links rpl
               ON rpl.record_kind = 'time'
              AND rpl.record_id = t.id
             WHERE rpl.project_id = ?1 AND t.is_deleted = 0",
            project_id,
        )?;
        let income_record_count = scalar_long(
            connection,
            "SELECT COUNT(*)
             FROM income_records i
             JOIN record_project_links rpl
               ON rpl.record_kind = 'income'
              AND rpl.record_id = i.id
             WHERE rpl.project_id = ?1 AND i.is_deleted = 0",
            project_id,
        )?;
        let expense_record_count = scalar_long(
            connection,
            "SELECT COUNT(*)
             FROM expense_records e
             JOIN record_project_links rpl
               ON rpl.record_kind = 'expense'
              AND rpl.record_id = e.id
             WHERE rpl.project_id = ?1 AND e.is_deleted = 0",
            project_id,
        )?;
        let learning_record_count = scalar_long(
            connection,
            "SELECT COUNT(*)
             FROM learning_records l
             JOIN record_project_links rpl
               ON rpl.record_kind = 'learning'
              AND rpl.record_id = l.id
             WHERE rpl.project_id = ?1 AND l.is_deleted = 0",
            project_id,
        )?;
        let timezone = if timezone.trim().is_empty() {
            query_timezone(connection, user_id)?
        } else {
            timezone.trim().to_string()
        };
        let today = Utc::now()
            .with_timezone(&parse_timezone(&timezone)?)
            .date_naive();
        let activity_start = first_project_activity_date(connection, project_id, user_id)?;
        let activity_end = last_project_activity_date(connection, project_id, user_id)?;
        let configured_start =
            NaiveDate::parse_from_str(&started_on, "%Y-%m-%d").map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid project started_on: {error}"))
            })?;
        let configured_end = ended_on
            .as_deref()
            .map(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d"))
            .transpose()
            .map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid project ended_on: {error}"))
            })?;
        let analysis_start_date = configured_start
            .min(activity_start.unwrap_or(configured_start))
            .to_string();
        let mut analysis_end = configured_end.unwrap_or(today);
        if let Some(activity_end) = activity_end {
            analysis_end = analysis_end.max(activity_end);
        }
        if analysis_end < configured_start {
            analysis_end = configured_start;
        }
        let analysis_end_date = analysis_end.to_string();

        let analysis_start_utc = to_utc_start(
            NaiveDate::parse_from_str(&analysis_start_date, "%Y-%m-%d")
                .expect("validated analysis start"),
            &timezone,
        )?;
        let analysis_end_utc_exclusive = to_utc_end_exclusive(
            NaiveDate::parse_from_str(&analysis_end_date, "%Y-%m-%d")
                .expect("validated analysis end"),
            &timezone,
        )?;
        let structural_expense_window = structural_expense_for_window(
            connection,
            user_id,
            NaiveDate::parse_from_str(&analysis_start_date, "%Y-%m-%d")
                .expect("validated analysis start"),
            NaiveDate::parse_from_str(&analysis_end_date, "%Y-%m-%d")
                .expect("validated analysis end"),
        )?;
        let global_work_minutes_in_window = total_user_work_minutes(
            connection,
            user_id,
            &analysis_start_utc,
            &analysis_end_utc_exclusive,
        )?;
        let benchmark_hourly_rate_cents =
            benchmark_hourly_rate_cents(connection, user_id, &timezone)?;
        let ideal_hourly_rate_cents = scalar_user_value(
            connection,
            "SELECT COALESCE(ideal_hourly_rate_cents, 0) FROM users WHERE id = ?1 LIMIT 1",
            user_id,
        )?;
        let last_year_hourly_rate_cents =
            last_year_hourly_rate_cents(connection, user_id, &timezone)?;
        let time_cost_cents = if benchmark_hourly_rate_cents > 0 && total_time_minutes > 0 {
            benchmark_hourly_rate_cents * total_time_minutes / 60
        } else {
            0
        };
        let allocated_structural_cost_cents = if structural_expense_window > 0
            && global_work_minutes_in_window > 0
            && total_time_minutes > 0
        {
            structural_expense_window * total_time_minutes / global_work_minutes_in_window
        } else {
            0
        };
        let operating_cost_cents = direct_expense_cents + time_cost_cents;
        let operating_profit_cents = total_income_cents - operating_cost_cents;
        let operating_break_even_income_cents = operating_cost_cents;
        let fully_loaded_cost_cents = operating_cost_cents + allocated_structural_cost_cents;
        let fully_loaded_profit_cents = total_income_cents - fully_loaded_cost_cents;
        let fully_loaded_break_even_income_cents = fully_loaded_cost_cents;
        let total_cost_cents = fully_loaded_cost_cents;
        let profit_cents = fully_loaded_profit_cents;
        let break_even_income_cents = fully_loaded_break_even_income_cents;
        let hourly_rate_yuan = if total_time_minutes > 0 {
            (total_income_cents as f64 / 100.0) / (total_time_minutes as f64 / 60.0)
        } else {
            0.0
        };
        let operating_roi_perc = roi(total_income_cents, operating_cost_cents);
        let fully_loaded_roi_perc = roi(total_income_cents, fully_loaded_cost_cents);
        let roi_perc = fully_loaded_roi_perc;
        let evaluation_status = if fully_loaded_roi_perc > 0.0 || operating_roi_perc > 0.0 {
            "positive"
        } else if total_time_minutes >= 120 && total_income_cents == 0 {
            "warning"
        } else {
            "neutral"
        }
        .to_string();
        Ok(Some(ProjectDetail {
            id,
            name,
            status_code,
            started_on,
            ended_on,
            ai_enable_ratio,
            score,
            note,
            tag_ids: load_project_tag_ids(connection, project_id)?,
            analysis_start_date,
            analysis_end_date,
            total_time_minutes,
            total_income_cents,
            total_expense_cents: direct_expense_cents,
            direct_expense_cents,
            time_cost_cents,
            total_cost_cents,
            profit_cents,
            break_even_income_cents,
            allocated_structural_cost_cents,
            operating_cost_cents,
            operating_profit_cents,
            operating_break_even_income_cents,
            fully_loaded_cost_cents,
            fully_loaded_profit_cents,
            fully_loaded_break_even_income_cents,
            benchmark_hourly_rate_cents,
            last_year_hourly_rate_cents,
            ideal_hourly_rate_cents,
            hourly_rate_yuan,
            roi_perc,
            operating_roi_perc,
            fully_loaded_roi_perc,
            evaluation_status,
            total_learning_minutes,
            time_record_count,
            income_record_count,
            expense_record_count,
            learning_record_count,
            recent_records: load_project_recent_records(
                connection,
                project_id,
                &timezone,
                recent_limit,
            )?,
        }))
    }

    pub fn update_project_record(
        connection: &mut Connection,
        project_id: &str,
        input: &CreateProjectInput,
    ) -> Result<Project> {
        input.validate()?;
        ensure_user_exists(connection, &input.user_id)?;
        ensure_active_project_exists(connection, project_id, &input.user_id)?;
        ensure_tags_exist(connection, &input.user_id, &input.tag_ids)?;

        let tx = connection.transaction()?;
        ensure_dimension_option_exists(
            &tx,
            DimensionKind::ProjectStatus,
            &input.normalized_status_code(),
        )?;
        let now = now_string();
        let note = input.normalized_note();
        let ended_on = input.normalized_ended_on();
        tx.execute(
            "UPDATE projects
             SET name = ?1,
                 status_code = ?2,
                 started_on = ?3,
                 ended_on = ?4,
                 ai_enable_ratio = ?5,
                 score = ?6,
                 note = ?7,
                 updated_at = ?8
             WHERE id = ?9 AND user_id = ?10 AND is_deleted = 0",
            params![
                input.normalized_name(),
                input.normalized_status_code(),
                input.started_on,
                ended_on,
                input.ai_enable_ratio,
                input.score,
                note,
                now,
                project_id,
                input.user_id,
            ],
        )?;
        replace_project_tag_links(&tx, project_id, &input.user_id, &input.tag_ids, &now)?;
        tx.commit()?;

        Ok(Project {
            id: project_id.to_string(),
            user_id: input.user_id.clone(),
            name: input.normalized_name(),
            status_code: input.normalized_status_code(),
            started_on: input.started_on.clone(),
            ended_on,
            ai_enable_ratio: input.ai_enable_ratio,
            score: input.score,
            note,
            is_deleted: false,
            created_at: String::new(),
            updated_at: now,
        })
    }

    pub fn update_project_state(
        connection: &mut Connection,
        project_id: &str,
        user_id: &str,
        status_code: &str,
        score: Option<i32>,
        note: Option<String>,
        ended_on: Option<String>,
    ) -> Result<Project> {
        ensure_user_exists(connection, user_id)?;
        ensure_active_project_exists(connection, project_id, user_id)?;
        let normalized_status = status_code.trim().to_lowercase();
        if normalized_status.is_empty() {
            return Err(LifeOsError::InvalidInput(
                "status_code is required".to_string(),
            ));
        }
        if let Some(score) = score
            && !(1..=10).contains(&score)
        {
            return Err(LifeOsError::InvalidInput(
                "score must be between 1 and 10".to_string(),
            ));
        }
        if let Some(ref ended_on) = ended_on {
            NaiveDate::parse_from_str(ended_on, "%Y-%m-%d").map_err(|error| {
                LifeOsError::InvalidInput(format!("ended_on must be YYYY-MM-DD: {error}"))
            })?;
        }

        let tx = connection.transaction()?;
        ensure_dimension_option_exists(&tx, DimensionKind::ProjectStatus, &normalized_status)?;
        let now = now_string();
        let normalized_note = note
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string);
        tx.execute(
            "UPDATE projects
             SET status_code = ?1,
                 score = ?2,
                 note = ?3,
                 ended_on = ?4,
                 updated_at = ?5
             WHERE id = ?6 AND user_id = ?7 AND is_deleted = 0",
            params![
                normalized_status,
                score,
                normalized_note,
                ended_on,
                now,
                project_id,
                user_id,
            ],
        )?;
        let project = load_project_row(&tx, project_id, user_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("project not found after update: {project_id}"))
        })?;
        tx.commit()?;
        Ok(project)
    }

    pub fn soft_delete_project(
        connection: &mut Connection,
        user_id: &str,
        project_id: &str,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        ensure_active_project_exists(connection, project_id, user_id)?;
        connection.execute(
            "UPDATE projects
             SET is_deleted = 1,
                 updated_at = ?1
             WHERE id = ?2 AND user_id = ?3 AND is_deleted = 0",
            params![now_string(), project_id, user_id],
        )?;
        Ok(())
    }
}

fn ensure_active_project_exists(
    connection: &Connection,
    project_id: &str,
    user_id: &str,
) -> Result<()> {
    let exists = connection
        .query_row(
            "SELECT 1
             FROM projects
             WHERE id = ?1 AND user_id = ?2 AND is_deleted = 0
             LIMIT 1",
            params![project_id, user_id],
            |row| row.get::<_, i64>(0),
        )
        .optional()?;
    if exists.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "project not found: {project_id}"
        )));
    }
    Ok(())
}

fn replace_project_tag_links(
    connection: &Connection,
    project_id: &str,
    user_id: &str,
    tag_ids: &[String],
    now: &str,
) -> Result<()> {
    connection.execute(
        "DELETE FROM record_tag_links WHERE record_kind = 'project' AND record_id = ?1",
        params![project_id],
    )?;
    for tag_id in tag_ids {
        connection.execute(
            "INSERT INTO record_tag_links(record_kind, record_id, tag_id, user_id, created_at)
             VALUES ('project', ?1, ?2, ?3, ?4)",
            params![project_id, tag_id, user_id, now],
        )?;
    }
    Ok(())
}

fn load_project_tag_ids(connection: &Connection, project_id: &str) -> Result<Vec<String>> {
    let mut statement = connection.prepare(
        "SELECT tag_id
         FROM record_tag_links
         WHERE record_kind = 'project' AND record_id = ?1
         ORDER BY created_at ASC, tag_id ASC",
    )?;
    let rows = statement.query_map(params![project_id], |row| row.get::<_, String>(0))?;
    rows.collect::<std::result::Result<Vec<_>, _>>()
        .map_err(Into::into)
}

fn scalar_long(connection: &Connection, sql: &str, project_id: &str) -> Result<i64> {
    connection
        .query_row(sql, params![project_id], |row| row.get::<_, i64>(0))
        .map_err(Into::into)
}

fn scalar_user_value(connection: &Connection, sql: &str, user_id: &str) -> Result<i64> {
    connection
        .query_row(sql, params![user_id], |row| row.get::<_, i64>(0))
        .map_err(Into::into)
}

fn query_timezone(connection: &Connection, user_id: &str) -> Result<String> {
    connection
        .query_row(
            "SELECT timezone FROM users WHERE id = ?1 LIMIT 1",
            params![user_id],
            |row| row.get::<_, String>(0),
        )
        .optional()
        .map(|value| value.unwrap_or_else(|| "Asia/Shanghai".to_string()))
        .map_err(Into::into)
}

fn parse_timezone(timezone: &str) -> Result<Tz> {
    timezone
        .parse()
        .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))
}

fn to_utc_start(date: NaiveDate, timezone: &str) -> Result<String> {
    let tz = parse_timezone(timezone)?;
    let local = date
        .and_hms_opt(0, 0, 0)
        .ok_or_else(|| LifeOsError::InvalidInput("invalid local date start".to_string()))?;
    let zoned = tz
        .from_local_datetime(&local)
        .single()
        .or_else(|| tz.from_local_datetime(&local).earliest())
        .ok_or_else(|| LifeOsError::InvalidInput("failed to resolve timezone start".to_string()))?;
    Ok(zoned.to_utc().to_rfc3339())
}

fn to_utc_end_exclusive(date: NaiveDate, timezone: &str) -> Result<String> {
    to_utc_start(date + Duration::days(1), timezone)
}

fn first_project_activity_date(
    connection: &Connection,
    project_id: &str,
    user_id: &str,
) -> Result<Option<NaiveDate>> {
    let min_time = scalar_optional_string(
        connection,
        "SELECT MIN(t.started_at)
         FROM time_records t
         JOIN record_project_links rpl
           ON rpl.record_kind = 'time'
          AND rpl.record_id = t.id
         WHERE rpl.project_id = ?1 AND t.user_id = ?2 AND t.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| {
        chrono::DateTime::parse_from_rfc3339(&value)
            .ok()
            .map(|dt| dt.date_naive())
    });
    let min_income = scalar_optional_string(
        connection,
        "SELECT MIN(i.occurred_on)
         FROM income_records i
         JOIN record_project_links rpl
           ON rpl.record_kind = 'income'
          AND rpl.record_id = i.id
         WHERE rpl.project_id = ?1 AND i.user_id = ?2 AND i.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| NaiveDate::parse_from_str(&value, "%Y-%m-%d").ok());
    let min_expense = scalar_optional_string(
        connection,
        "SELECT MIN(e.occurred_on)
         FROM expense_records e
         JOIN record_project_links rpl
           ON rpl.record_kind = 'expense'
          AND rpl.record_id = e.id
         WHERE rpl.project_id = ?1 AND e.user_id = ?2 AND e.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| NaiveDate::parse_from_str(&value, "%Y-%m-%d").ok());
    let min_learning = scalar_optional_string(
        connection,
        "SELECT MIN(l.occurred_on)
         FROM learning_records l
         JOIN record_project_links rpl
           ON rpl.record_kind = 'learning'
          AND rpl.record_id = l.id
         WHERE rpl.project_id = ?1 AND l.user_id = ?2 AND l.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| NaiveDate::parse_from_str(&value, "%Y-%m-%d").ok());

    Ok([min_time, min_income, min_expense, min_learning]
        .into_iter()
        .flatten()
        .min())
}

fn last_project_activity_date(
    connection: &Connection,
    project_id: &str,
    user_id: &str,
) -> Result<Option<NaiveDate>> {
    let max_time = scalar_optional_string(
        connection,
        "SELECT MAX(t.started_at)
         FROM time_records t
         JOIN record_project_links rpl
           ON rpl.record_kind = 'time'
          AND rpl.record_id = t.id
         WHERE rpl.project_id = ?1 AND t.user_id = ?2 AND t.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| {
        chrono::DateTime::parse_from_rfc3339(&value)
            .ok()
            .map(|dt| dt.date_naive())
    });
    let max_income = scalar_optional_string(
        connection,
        "SELECT MAX(i.occurred_on)
         FROM income_records i
         JOIN record_project_links rpl
           ON rpl.record_kind = 'income'
          AND rpl.record_id = i.id
         WHERE rpl.project_id = ?1 AND i.user_id = ?2 AND i.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| NaiveDate::parse_from_str(&value, "%Y-%m-%d").ok());
    let max_expense = scalar_optional_string(
        connection,
        "SELECT MAX(e.occurred_on)
         FROM expense_records e
         JOIN record_project_links rpl
           ON rpl.record_kind = 'expense'
          AND rpl.record_id = e.id
         WHERE rpl.project_id = ?1 AND e.user_id = ?2 AND e.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| NaiveDate::parse_from_str(&value, "%Y-%m-%d").ok());
    let max_learning = scalar_optional_string(
        connection,
        "SELECT MAX(l.occurred_on)
         FROM learning_records l
         JOIN record_project_links rpl
           ON rpl.record_kind = 'learning'
          AND rpl.record_id = l.id
         WHERE rpl.project_id = ?1 AND l.user_id = ?2 AND l.is_deleted = 0",
        project_id,
        user_id,
    )?
    .and_then(|value| NaiveDate::parse_from_str(&value, "%Y-%m-%d").ok());

    Ok([max_time, max_income, max_expense, max_learning]
        .into_iter()
        .flatten()
        .max())
}

fn scalar_optional_string(
    connection: &Connection,
    sql: &str,
    project_id: &str,
    user_id: &str,
) -> Result<Option<String>> {
    connection
        .query_row(sql, params![project_id, user_id], |row| {
            row.get::<_, Option<String>>(0)
        })
        .optional()
        .map(|value| value.flatten())
        .map_err(Into::into)
}

fn total_user_work_minutes(
    connection: &Connection,
    user_id: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
) -> Result<i64> {
    connection
        .query_row(
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND category_code = 'work'
               AND started_at >= ?2
               AND started_at < ?3",
            params![user_id, start_at_utc, end_at_utc_exclusive],
            |row| row.get::<_, i64>(0),
        )
        .map_err(Into::into)
}

fn structural_expense_for_window(
    connection: &Connection,
    user_id: &str,
    start: NaiveDate,
    end: NaiveDate,
) -> Result<i64> {
    if end < start {
        return Ok(0);
    }
    let mut total = 0_i64;
    let mut cursor = NaiveDate::from_ymd_opt(start.year(), start.month(), 1).expect("valid month");
    while cursor <= end {
        let current_month = format!("{:04}-{:02}", cursor.year(), cursor.month());
        let month_start =
            NaiveDate::from_ymd_opt(cursor.year(), cursor.month(), 1).expect("valid month start");
        let (next_year, next_month) = if cursor.month() == 12 {
            (cursor.year() + 1, 1)
        } else {
            (cursor.year(), cursor.month() + 1)
        };
        let month_end = NaiveDate::from_ymd_opt(next_year, next_month, 1)
            .expect("valid next month")
            - Duration::days(1);
        let overlap_start = if start > month_start {
            start
        } else {
            month_start
        };
        let overlap_end = if end < month_end { end } else { month_end };
        if overlap_end >= overlap_start {
            let overlap_days = (overlap_end - overlap_start).num_days() + 1;
            let month_days = (month_end - month_start).num_days() + 1;
            let baseline = connection
                .query_row(
                    "SELECT COALESCE(basic_living_cents, 0) + COALESCE(fixed_subscription_cents, 0)
                     FROM expense_baseline_months
                     WHERE user_id = ?1 AND month = ?2
                     LIMIT 1",
                    params![user_id, current_month],
                    |row| row.get::<_, i64>(0),
                )
                .optional()?
                .unwrap_or(0);
            let recurring = connection.query_row(
                "SELECT COALESCE(SUM(monthly_amount_cents), 0)
                     FROM expense_recurring_rules
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND start_month <= ?2
                       AND (end_month IS NULL OR end_month = '' OR end_month >= ?2)",
                params![user_id, current_month],
                |row| row.get::<_, i64>(0),
            )?;
            let capex = connection.query_row(
                "SELECT COALESCE(SUM(monthly_amortized_cents), 0)
                     FROM expense_capex_items
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND amortization_start_month <= ?2
                       AND amortization_end_month >= ?2",
                params![user_id, current_month],
                |row| row.get::<_, i64>(0),
            )?;
            total += (baseline + recurring + capex) * overlap_days / month_days;
        }
        cursor = month_end + Duration::days(1);
    }
    Ok(total)
}

fn benchmark_hourly_rate_cents(
    connection: &Connection,
    user_id: &str,
    timezone: &str,
) -> Result<i64> {
    let last_year_rate = last_year_hourly_rate_cents(connection, user_id, timezone)?;
    if last_year_rate > 0 {
        return Ok(last_year_rate);
    }
    let ideal = scalar_user_value(
        connection,
        "SELECT COALESCE(ideal_hourly_rate_cents, 0) FROM users WHERE id = ?1 LIMIT 1",
        user_id,
    )?;
    if ideal > 0 {
        return Ok(ideal);
    }
    let total_income = scalar_user_value(
        connection,
        "SELECT COALESCE(SUM(amount_cents), 0) FROM income_records WHERE user_id = ?1 AND is_deleted = 0",
        user_id,
    )?;
    let total_work_minutes = connection.query_row(
        "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1 AND is_deleted = 0 AND category_code = 'work'",
        params![user_id],
        |row| row.get::<_, i64>(0),
    )?;
    Ok(if total_work_minutes > 0 {
        total_income * 60 / total_work_minutes
    } else {
        0
    })
}

fn last_year_hourly_rate_cents(
    connection: &Connection,
    user_id: &str,
    timezone: &str,
) -> Result<i64> {
    let year = Utc::now().with_timezone(&parse_timezone(timezone)?).year() - 1;
    let start = NaiveDate::from_ymd_opt(year, 1, 1).expect("valid last year start");
    let end = NaiveDate::from_ymd_opt(year, 12, 31).expect("valid last year end");
    let income = connection.query_row(
        "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?2 AND occurred_on <= ?3",
        params![user_id, start.to_string(), end.to_string()],
        |row| row.get::<_, i64>(0),
    )?;
    let work = total_user_work_minutes(
        connection,
        user_id,
        &to_utc_start(start, timezone)?,
        &to_utc_end_exclusive(end, timezone)?,
    )?;
    Ok(if work > 0 { income * 60 / work } else { 0 })
}

fn roi(income_cents: i64, cost_cents: i64) -> f64 {
    if cost_cents <= 0 {
        0.0
    } else {
        (income_cents - cost_cents) as f64 / cost_cents as f64 * 100.0
    }
}

fn load_project_recent_records(
    connection: &Connection,
    project_id: &str,
    timezone: &str,
    recent_limit: usize,
) -> Result<Vec<RecentRecordItem>> {
    let safe_limit = recent_limit.max(1).min(100) as i64;
    let mut statement = connection.prepare(
        "SELECT record_id, kind, occurred_at, title, detail
         FROM (
           SELECT t.id AS record_id, 'time' AS kind, t.started_at AS occurred_at, t.category_code AS title,
                  COALESCE(t.note, '') AS detail
           FROM time_records t
           JOIN record_project_links rpl
             ON rpl.record_kind = 'time' AND rpl.record_id = t.id
           WHERE rpl.project_id = ?1 AND t.is_deleted = 0
           UNION ALL
           SELECT i.id AS record_id, 'income' AS kind, i.occurred_on AS occurred_at, i.source_name AS title,
                  CAST(i.amount_cents AS TEXT) || ' cents' ||
                  CASE WHEN i.note IS NULL OR i.note = '' THEN '' ELSE ' | ' || i.note END AS detail
           FROM income_records i
           JOIN record_project_links rpl
             ON rpl.record_kind = 'income' AND rpl.record_id = i.id
           WHERE rpl.project_id = ?1 AND i.is_deleted = 0
           UNION ALL
           SELECT e.id AS record_id, 'expense' AS kind, e.occurred_on AS occurred_at, e.category_code AS title,
                  CAST(e.amount_cents AS TEXT) || ' cents' ||
                  CASE WHEN e.note IS NULL OR e.note = '' THEN '' ELSE ' | ' || e.note END AS detail
           FROM expense_records e
           JOIN record_project_links rpl
             ON rpl.record_kind = 'expense' AND rpl.record_id = e.id
           WHERE rpl.project_id = ?1 AND e.is_deleted = 0
           UNION ALL
           SELECT l.id AS record_id, 'learning' AS kind, COALESCE(l.started_at, l.occurred_on) AS occurred_at,
                  l.content AS title,
                  CAST(l.duration_minutes AS TEXT) || ' min' ||
                  CASE WHEN l.note IS NULL OR l.note = '' THEN '' ELSE ' | ' || l.note END AS detail
           FROM learning_records l
           JOIN record_project_links rpl
             ON rpl.record_kind = 'learning' AND rpl.record_id = l.id
           WHERE rpl.project_id = ?1 AND l.is_deleted = 0
         )
         ORDER BY occurred_at DESC
         LIMIT ?2",
    )?;
    let rows = statement.query_map(params![project_id, safe_limit], |row| {
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
            let kind = match kind.as_str() {
                "time" => RecordKind::Time,
                "income" => RecordKind::Income,
                "expense" => RecordKind::Expense,
                "learning" => RecordKind::Learning,
                other => {
                    return Err(LifeOsError::InvalidInput(format!(
                        "unsupported record kind: {other}"
                    )));
                }
            };
            Ok(RecentRecordItem {
                record_id,
                kind,
                occurred_at: normalize_occurred_at(occurred_at, timezone)?,
                title,
                detail,
            })
        })
        .collect()
}

fn load_project_row(
    connection: &Connection,
    project_id: &str,
    user_id: &str,
) -> Result<Option<Project>> {
    connection
        .query_row(
            "SELECT id, user_id, name, status_code, started_on, ended_on, ai_enable_ratio, score, note, is_deleted, created_at, updated_at
             FROM projects
             WHERE id = ?1 AND user_id = ?2
             LIMIT 1",
            params![project_id, user_id],
            |row| {
                Ok(Project {
                    id: row.get(0)?,
                    user_id: row.get(1)?,
                    name: row.get(2)?,
                    status_code: row.get(3)?,
                    started_on: row.get(4)?,
                    ended_on: row.get(5)?,
                    ai_enable_ratio: row.get(6)?,
                    score: row.get(7)?,
                    note: row.get(8)?,
                    is_deleted: row.get::<_, i64>(9)? == 1,
                    created_at: row.get(10)?,
                    updated_at: row.get(11)?,
                })
            },
        )
        .optional()
        .map_err(Into::into)
}
