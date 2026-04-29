use chrono::{Datelike, Duration, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;
use rusqlite::{Connection, params};

use crate::error::{LifeOsError, Result};
use crate::models::{
    ProjectProgressItem, RecentRecordItem, RecordKind, ReviewReport, ReviewTagMetric, ReviewWindow,
    TimeCategoryAllocation,
};
use crate::repositories::record_repository::ensure_user_exists;
use crate::repositories::review_note_repository::ReviewNoteRepository;

pub struct ReviewRepository;

impl ReviewRepository {
    pub fn build_report(
        connection: &Connection,
        user_id: &str,
        window: &ReviewWindow,
        timezone: &str,
    ) -> Result<ReviewReport> {
        ensure_user_exists(connection, user_id)?;
        window.validate()?;

        let start = NaiveDate::parse_from_str(&window.start_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid start_date: {error}")))?;
        let end = NaiveDate::parse_from_str(&window.end_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid end_date: {error}")))?;
        let prev_start = NaiveDate::parse_from_str(&window.previous_start_date, "%Y-%m-%d")
            .map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid previous_start_date: {error}"))
            })?;
        let prev_end =
            NaiveDate::parse_from_str(&window.previous_end_date, "%Y-%m-%d").map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid previous_end_date: {error}"))
            })?;

        let start_at_utc = to_utc_start(start, timezone)?;
        let end_at_utc_exclusive = to_utc_end_exclusive(end, timezone)?;
        let prev_start_at_utc = to_utc_start(prev_start, timezone)?;
        let prev_end_at_utc_exclusive = to_utc_end_exclusive(prev_end, timezone)?;

        let time_allocations =
            load_time_allocations(connection, user_id, &start_at_utc, &end_at_utc_exclusive)?;
        let total_time_minutes = time_allocations
            .iter()
            .map(|item| item.minutes)
            .sum::<i64>();
        let total_work_minutes = scalar_long(
            connection,
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND category_code = 'work'
               AND started_at >= ?2
               AND started_at < ?3",
            params![user_id, start_at_utc, end_at_utc_exclusive],
        )?;
        let total_income_cents = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on >= ?2
               AND occurred_on <= ?3",
            params![user_id, window.start_date, window.end_date],
        )?;
        let total_expense_direct = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM expense_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on >= ?2
               AND occurred_on <= ?3",
            params![user_id, window.start_date, window.end_date],
        )?;
        let total_expense_cents = total_expense_direct
            + structural_expense_for_window(connection, user_id, start, end, false)?;

        let previous_income_cents = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on >= ?2
               AND occurred_on <= ?3",
            params![
                user_id,
                window.previous_start_date,
                window.previous_end_date
            ],
        )?;
        let previous_expense_direct = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM expense_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND occurred_on >= ?2
               AND occurred_on <= ?3",
            params![
                user_id,
                window.previous_start_date,
                window.previous_end_date
            ],
        )?;
        let previous_expense_cents = previous_expense_direct
            + structural_expense_for_window(connection, user_id, prev_start, prev_end, false)?;
        let previous_work_minutes = scalar_long(
            connection,
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND category_code = 'work'
               AND started_at >= ?2
               AND started_at < ?3",
            params![user_id, prev_start_at_utc, prev_end_at_utc_exclusive],
        )?;

        let ideal_hourly_rate_cents = scalar_long(
            connection,
            "SELECT COALESCE(ideal_hourly_rate_cents, 0)
             FROM users
             WHERE id = ?1
             LIMIT 1",
            params![user_id],
        )?;
        let actual_hourly_rate_cents = if total_work_minutes > 0 {
            Some((total_income_cents * 60) / total_work_minutes)
        } else {
            None
        };
        let time_debt_cents =
            actual_hourly_rate_cents.map(|actual| ideal_hourly_rate_cents - actual);

        let passive_income_cents = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND is_passive = 1
               AND occurred_on >= ?2
               AND occurred_on <= ?3",
            params![user_id, window.start_date, window.end_date],
        )?;
        let necessary_direct_expense_cents = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM expense_records
             WHERE user_id = ?1
               AND is_deleted = 0
               AND category_code = 'necessary'
               AND occurred_on >= ?2
               AND occurred_on <= ?3",
            params![user_id, window.start_date, window.end_date],
        )?;
        let necessary_expense_cents = necessary_direct_expense_cents
            + structural_expense_for_window(connection, user_id, start, end, true)?;
        let passive_cover_ratio = if necessary_expense_cents > 0 {
            Some(passive_income_cents as f64 / necessary_expense_cents as f64)
        } else {
            None
        };

        let ai_assist_rate = load_ai_assist_rate(
            connection,
            user_id,
            &start_at_utc,
            &end_at_utc_exclusive,
            total_time_minutes,
        )?;
        let work_efficiency_avg = load_weighted_time_efficiency(
            connection,
            user_id,
            &start_at_utc,
            &end_at_utc_exclusive,
            "work",
        )?;
        let learning_efficiency_avg =
            load_learning_efficiency(connection, user_id, &window.start_date, &window.end_date)?;

        let time_tag_metrics =
            load_time_tag_metrics(connection, user_id, &start_at_utc, &end_at_utc_exclusive)?;
        let expense_tag_metrics =
            load_expense_tag_metrics(connection, user_id, &window.start_date, &window.end_date)?;
        let (top_projects, sinkhole_projects) = load_project_buckets(
            connection,
            user_id,
            &window.start_date,
            &window.end_date,
            &start_at_utc,
            &end_at_utc_exclusive,
            total_work_minutes,
            timezone,
        )?;
        let key_events = load_key_events(
            connection,
            user_id,
            &window.start_date,
            &window.end_date,
            &start_at_utc,
            &end_at_utc_exclusive,
            timezone,
        )?;
        let income_history = load_income_history(
            connection,
            user_id,
            &window.start_date,
            &window.end_date,
            timezone,
        )?;
        let history_records = load_history_records(
            connection,
            user_id,
            &window.start_date,
            &window.end_date,
            &start_at_utc,
            &end_at_utc_exclusive,
            timezone,
        )?;
        let review_notes = ReviewNoteRepository::list_for_range(
            connection,
            user_id,
            &window.start_date,
            &window.end_date,
        )?;

        Ok(ReviewReport {
            window: window.clone(),
            ai_summary: build_summary(
                total_time_minutes,
                total_income_cents,
                total_expense_cents,
                ai_assist_rate,
                work_efficiency_avg,
                learning_efficiency_avg,
            ),
            total_time_minutes,
            total_work_minutes,
            total_income_cents,
            total_expense_cents,
            previous_income_cents,
            previous_expense_cents,
            previous_work_minutes,
            income_change_ratio: ratio_change(total_income_cents, previous_income_cents),
            expense_change_ratio: ratio_change(total_expense_cents, previous_expense_cents),
            work_change_ratio: ratio_change(total_work_minutes, previous_work_minutes),
            actual_hourly_rate_cents,
            ideal_hourly_rate_cents,
            time_debt_cents,
            passive_cover_ratio,
            ai_assist_rate,
            work_efficiency_avg,
            learning_efficiency_avg,
            time_allocations,
            top_projects,
            sinkhole_projects,
            key_events,
            income_history,
            history_records,
            review_notes,
            time_tag_metrics,
            expense_tag_metrics,
        })
    }

    pub fn get_tag_detail_records(
        connection: &Connection,
        user_id: &str,
        scope: &str,
        tag_name: &str,
        start_date: &str,
        end_date: &str,
        timezone: &str,
        limit: usize,
    ) -> Result<Vec<RecentRecordItem>> {
        ensure_user_exists(connection, user_id)?;
        let scope = scope.trim().to_lowercase();
        let tag_name = tag_name.trim();
        if tag_name.is_empty() {
            return Ok(Vec::new());
        }
        let start = NaiveDate::parse_from_str(start_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid start_date: {error}")))?;
        let end = NaiveDate::parse_from_str(end_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid end_date: {error}")))?;
        let (start, end) = if end < start {
            (end, start)
        } else {
            (start, end)
        };
        let start_at_utc = to_utc_start(start, timezone)?;
        let end_at_utc_exclusive = to_utc_end_exclusive(end, timezone)?;
        let row_limit = limit.max(1).min(200) as i64;

        match scope.as_str() {
            "time" => load_tag_detail_time_records(
                connection,
                user_id,
                tag_name,
                &start_at_utc,
                &end_at_utc_exclusive,
                timezone,
                row_limit,
            ),
            "expense" => load_tag_detail_expense_records(
                connection,
                user_id,
                tag_name,
                &start.to_string(),
                &end.to_string(),
                timezone,
                row_limit,
            ),
            "income" => load_tag_detail_income_records(
                connection,
                user_id,
                tag_name,
                &start.to_string(),
                &end.to_string(),
                timezone,
                row_limit,
            ),
            "learning" => load_tag_detail_learning_records(
                connection,
                user_id,
                tag_name,
                &start.to_string(),
                &end.to_string(),
                timezone,
                row_limit,
            ),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported tag detail scope: {other}"
            ))),
        }
    }
}

fn load_time_allocations(
    connection: &Connection,
    user_id: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
) -> Result<Vec<TimeCategoryAllocation>> {
    let mut statement = connection.prepare(
        "SELECT category_code, SUM(duration_minutes) AS minutes
         FROM time_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND started_at >= ?2
           AND started_at < ?3
         GROUP BY category_code
         ORDER BY minutes DESC",
    )?;
    let rows = statement.query_map(
        params![user_id, start_at_utc, end_at_utc_exclusive],
        |row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?)),
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    let total = raw_rows.iter().map(|(_, minutes)| *minutes).sum::<i64>();
    Ok(raw_rows
        .into_iter()
        .map(|(category_name, minutes)| TimeCategoryAllocation {
            category_name,
            minutes,
            percentage: if total > 0 {
                minutes as f64 * 100.0 / total as f64
            } else {
                0.0
            },
        })
        .collect())
}

fn load_ai_assist_rate(
    connection: &Connection,
    user_id: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
    total_time_minutes: i64,
) -> Result<Option<f64>> {
    let weighted_minutes = connection.query_row(
        "SELECT COALESCE(SUM((duration_minutes * COALESCE(ai_assist_ratio, 0)) / 100.0), 0.0)
         FROM time_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND started_at >= ?2
           AND started_at < ?3",
        params![user_id, start_at_utc, end_at_utc_exclusive],
        |row| row.get::<_, f64>(0),
    )?;
    Ok(if total_time_minutes > 0 {
        Some(weighted_minutes / total_time_minutes as f64)
    } else {
        None
    })
}

fn load_weighted_time_efficiency(
    connection: &Connection,
    user_id: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
    category_code: &str,
) -> Result<Option<f64>> {
    let numerator = connection.query_row(
        "SELECT COALESCE(SUM(duration_minutes * efficiency_score), 0.0)
         FROM time_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND category_code = ?2
           AND efficiency_score IS NOT NULL
           AND started_at >= ?3
           AND started_at < ?4",
        params![user_id, category_code, start_at_utc, end_at_utc_exclusive],
        |row| row.get::<_, f64>(0),
    )?;
    let denominator = connection.query_row(
        "SELECT COALESCE(SUM(duration_minutes), 0)
         FROM time_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND category_code = ?2
           AND efficiency_score IS NOT NULL
           AND started_at >= ?3
           AND started_at < ?4",
        params![user_id, category_code, start_at_utc, end_at_utc_exclusive],
        |row| row.get::<_, i64>(0),
    )?;
    Ok(if denominator > 0 {
        Some(numerator / denominator as f64)
    } else {
        None
    })
}

fn load_learning_efficiency(
    connection: &Connection,
    user_id: &str,
    start_date: &str,
    end_date: &str,
) -> Result<Option<f64>> {
    let numerator = connection.query_row(
        "SELECT COALESCE(SUM(duration_minutes * efficiency_score), 0.0)
         FROM learning_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND efficiency_score IS NOT NULL
           AND occurred_on >= ?2
           AND occurred_on <= ?3",
        params![user_id, start_date, end_date],
        |row| row.get::<_, f64>(0),
    )?;
    let denominator = connection.query_row(
        "SELECT COALESCE(SUM(duration_minutes), 0)
         FROM learning_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND efficiency_score IS NOT NULL
           AND occurred_on >= ?2
           AND occurred_on <= ?3",
        params![user_id, start_date, end_date],
        |row| row.get::<_, i64>(0),
    )?;
    Ok(if denominator > 0 {
        Some(numerator / denominator as f64)
    } else {
        None
    })
}

fn load_project_buckets(
    connection: &Connection,
    user_id: &str,
    start_date: &str,
    end_date: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
    total_work_minutes: i64,
    timezone: &str,
) -> Result<(Vec<ProjectProgressItem>, Vec<ProjectProgressItem>)> {
    let structural_cost_total = structural_expense_for_window(
        connection,
        user_id,
        NaiveDate::parse_from_str(start_date, "%Y-%m-%d").expect("validated start date"),
        NaiveDate::parse_from_str(end_date, "%Y-%m-%d").expect("validated end date"),
        false,
    )?;
    let benchmark_hourly_rate_cents = benchmark_hourly_rate_cents(connection, user_id, timezone)?;
    let mut statement = connection.prepare(
        "SELECT p.id, p.name,
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
                      AND t.started_at >= ?1
                      AND t.started_at < ?2
                ), 0) AS project_time_minutes,
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
                      AND i.occurred_on >= ?3
                      AND i.occurred_on <= ?4
                ), 0) AS project_income_cents,
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
                      AND e.occurred_on >= ?3
                      AND e.occurred_on <= ?4
                ), 0) AS project_expense_cents
         FROM projects p
         WHERE p.user_id = ?5 AND p.is_deleted = 0
         ORDER BY project_income_cents DESC, project_time_minutes DESC",
    )?;
    let rows = statement.query_map(
        params![
            start_at_utc,
            end_at_utc_exclusive,
            start_date,
            end_date,
            user_id
        ],
        |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i64>(2)?,
                row.get::<_, i64>(3)?,
                row.get::<_, i64>(4)?,
            ))
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    let mut top = Vec::new();
    let mut sinkhole = Vec::new();
    for (project_id, project_name, time_spent_minutes, income_earned_cents, direct_expense_cents) in
        raw_rows
    {
        if time_spent_minutes <= 0 && income_earned_cents <= 0 && direct_expense_cents <= 0 {
            continue;
        }
        let allocated_structural_cost_cents = if structural_cost_total > 0 && total_work_minutes > 0
        {
            structural_cost_total * time_spent_minutes / total_work_minutes
        } else {
            0
        };
        let time_cost_cents = if benchmark_hourly_rate_cents > 0 && time_spent_minutes > 0 {
            benchmark_hourly_rate_cents * time_spent_minutes / 60
        } else {
            0
        };
        let operating_cost_cents = direct_expense_cents + time_cost_cents;
        let fully_loaded_cost_cents =
            direct_expense_cents + time_cost_cents + allocated_structural_cost_cents;
        let hourly_rate_yuan = if time_spent_minutes > 0 {
            (income_earned_cents as f64 / 100.0) / (time_spent_minutes as f64 / 60.0)
        } else {
            0.0
        };
        let operating_roi_perc = roi(income_earned_cents, operating_cost_cents);
        let fully_loaded_roi_perc = roi(income_earned_cents, fully_loaded_cost_cents);
        let evaluation_status = if fully_loaded_roi_perc > 0.0 || operating_roi_perc > 0.0 {
            "positive"
        } else if time_spent_minutes >= 120 && income_earned_cents == 0 {
            "warning"
        } else {
            "neutral"
        };
        let item = ProjectProgressItem {
            project_id,
            project_name,
            time_spent_minutes,
            income_earned_cents,
            direct_expense_cents,
            time_cost_cents,
            allocated_structural_cost_cents,
            operating_cost_cents,
            fully_loaded_cost_cents,
            hourly_rate_yuan,
            operating_roi_perc,
            fully_loaded_roi_perc,
            evaluation_status: evaluation_status.to_string(),
        };
        if evaluation_status == "warning" {
            sinkhole.push(item);
        } else {
            top.push(item);
        }
    }
    Ok((top, sinkhole))
}

fn load_key_events(
    connection: &Connection,
    user_id: &str,
    start_date: &str,
    end_date: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
    timezone: &str,
) -> Result<Vec<RecentRecordItem>> {
    let mut events = Vec::new();

    let mut expense_statement = connection.prepare(
        "SELECT amount_cents, category_code, occurred_on, COALESCE(note, '')
         FROM expense_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND occurred_on >= ?2
           AND occurred_on <= ?3
         ORDER BY amount_cents DESC
         LIMIT 2",
    )?;
    let expense_rows =
        expense_statement.query_map(params![user_id, start_date, end_date], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
            ))
        })?;
    for row in expense_rows {
        let (amount_cents, category_code, occurred_on, note) = row?;
        events.push(RecentRecordItem {
            record_id: String::new(),
            kind: RecordKind::Expense,
            occurred_at: normalize_occurrence(occurred_on, timezone)?,
            title: format!("Big Expense: {:.2}", amount_cents as f64 / 100.0),
            detail: append_note(category_code, note),
        });
    }

    let mut time_statement = connection.prepare(
        "SELECT duration_minutes, category_code, started_at, COALESCE(note, '')
         FROM time_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND started_at >= ?2
           AND started_at < ?3
         ORDER BY duration_minutes DESC
         LIMIT 2",
    )?;
    let time_rows = time_statement.query_map(
        params![user_id, start_at_utc, end_at_utc_exclusive],
        |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
            ))
        },
    )?;
    for row in time_rows {
        let (duration_minutes, category_code, started_at, note) = row?;
        events.push(RecentRecordItem {
            record_id: String::new(),
            kind: RecordKind::Time,
            occurred_at: normalize_occurrence(started_at, timezone)?,
            title: format!("Deep Work: {duration_minutes}m"),
            detail: append_note(category_code, note),
        });
    }
    Ok(events)
}

fn load_income_history(
    connection: &Connection,
    user_id: &str,
    start_date: &str,
    end_date: &str,
    timezone: &str,
) -> Result<Vec<RecentRecordItem>> {
    let mut statement = connection.prepare(
        "SELECT id, occurred_on, source_name, amount_cents, type_code, COALESCE(note, '')
         FROM income_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND occurred_on >= ?2
           AND occurred_on <= ?3
         ORDER BY occurred_on DESC, created_at DESC
         LIMIT 120",
    )?;
    let rows = statement.query_map(params![user_id, start_date, end_date], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
            row.get::<_, i64>(3)?,
            row.get::<_, String>(4)?,
            row.get::<_, String>(5)?,
        ))
    })?;
    let mut result = Vec::new();
    for row in rows {
        let (record_id, occurred_on, source_name, amount_cents, type_code, note) = row?;
        result.push(RecentRecordItem {
            record_id,
            kind: RecordKind::Income,
            occurred_at: normalize_occurrence(occurred_on, timezone)?,
            title: source_name,
            detail: append_note(format!("{amount_cents} cents | {type_code}"), note),
        });
    }
    Ok(result)
}

fn load_history_records(
    connection: &Connection,
    user_id: &str,
    start_date: &str,
    end_date: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
    timezone: &str,
) -> Result<Vec<RecentRecordItem>> {
    let mut statement = connection.prepare(
        "SELECT record_id, kind, occurred_at, title, detail
         FROM (
           SELECT id AS record_id, 'time' AS kind, started_at AS occurred_at, category_code AS title, COALESCE(note, '') AS detail
           FROM time_records
           WHERE user_id = ?1 AND is_deleted = 0 AND started_at >= ?2 AND started_at < ?3
           UNION ALL
           SELECT id AS record_id, 'income' AS kind, occurred_on AS occurred_at, source_name AS title,
                  CAST(amount_cents AS TEXT) || ' cents' || CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
           FROM income_records
           WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?4 AND occurred_on <= ?5
           UNION ALL
           SELECT id AS record_id, 'expense' AS kind, occurred_on AS occurred_at, category_code AS title,
                  CAST(amount_cents AS TEXT) || ' cents' || CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
           FROM expense_records
           WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?4 AND occurred_on <= ?5
           UNION ALL
           SELECT id AS record_id, 'learning' AS kind, COALESCE(started_at, occurred_on) AS occurred_at, content AS title,
                  CAST(duration_minutes AS TEXT) || ' min' || CASE WHEN note IS NULL OR note = '' THEN '' ELSE ' | ' || note END AS detail
           FROM learning_records
           WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?4 AND occurred_on <= ?5
         )
         ORDER BY occurred_at DESC
         LIMIT 200",
    )?;
    let rows = statement.query_map(
        params![
            user_id,
            start_at_utc,
            end_at_utc_exclusive,
            start_date,
            end_date
        ],
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
                kind: parse_kind(&kind)?,
                occurred_at: normalize_occurrence(occurred_at, timezone)?,
                title,
                detail,
            })
        })
        .collect()
}

fn load_time_tag_metrics(
    connection: &Connection,
    user_id: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
) -> Result<Vec<ReviewTagMetric>> {
    let mut statement = connection.prepare(
        "SELECT tg.name, tg.emoji, SUM(t.duration_minutes) AS total_minutes
         FROM record_tag_links rtl
         JOIN time_records t
           ON rtl.record_kind = 'time'
          AND rtl.record_id = t.id
         JOIN tags tg
           ON tg.id = rtl.tag_id
         WHERE t.user_id = ?1
           AND t.is_deleted = 0
           AND t.started_at >= ?2
           AND t.started_at < ?3
           AND tg.status = 'active'
         GROUP BY tg.id, tg.name, tg.emoji
         ORDER BY total_minutes DESC
         LIMIT 8",
    )?;
    let rows = statement.query_map(
        params![user_id, start_at_utc, end_at_utc_exclusive],
        |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, i64>(2)?,
            ))
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    collect_tag_metrics(raw_rows)
}

fn load_expense_tag_metrics(
    connection: &Connection,
    user_id: &str,
    start_date: &str,
    end_date: &str,
) -> Result<Vec<ReviewTagMetric>> {
    let mut statement = connection.prepare(
        "SELECT tg.name, tg.emoji, SUM(e.amount_cents) AS total_cents
         FROM record_tag_links rtl
         JOIN expense_records e
           ON rtl.record_kind = 'expense'
          AND rtl.record_id = e.id
         JOIN tags tg
           ON tg.id = rtl.tag_id
         WHERE e.user_id = ?1
           AND e.is_deleted = 0
           AND e.occurred_on >= ?2
           AND e.occurred_on <= ?3
           AND tg.status = 'active'
         GROUP BY tg.id, tg.name, tg.emoji
         ORDER BY total_cents DESC
         LIMIT 8",
    )?;
    let rows = statement.query_map(params![user_id, start_date, end_date], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, Option<String>>(1)?,
            row.get::<_, i64>(2)?,
        ))
    })?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    collect_tag_metrics(raw_rows)
}

fn collect_tag_metrics(
    raw_rows: Vec<(String, Option<String>, i64)>,
) -> Result<Vec<ReviewTagMetric>> {
    let total = raw_rows.iter().map(|(_, _, value)| *value).sum::<i64>();
    Ok(raw_rows
        .into_iter()
        .map(|(tag_name, emoji, value)| ReviewTagMetric {
            tag_name,
            emoji,
            value,
            percentage: if total > 0 {
                value as f64 * 100.0 / total as f64
            } else {
                0.0
            },
        })
        .collect())
}

fn load_tag_detail_time_records(
    connection: &Connection,
    user_id: &str,
    tag_name: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
    timezone: &str,
    limit: i64,
) -> Result<Vec<RecentRecordItem>> {
    let mut statement = connection.prepare(
        "SELECT t.id, t.started_at, t.category_code, t.duration_minutes, COALESCE(t.note, '')
         FROM record_tag_links rtl
         JOIN time_records t
           ON rtl.record_kind = 'time'
          AND rtl.record_id = t.id
         JOIN tags tg
           ON tg.id = rtl.tag_id
         WHERE t.user_id = ?1
           AND t.is_deleted = 0
           AND tg.name = ?2
           AND t.started_at >= ?3
           AND t.started_at < ?4
         ORDER BY t.started_at DESC
         LIMIT ?5",
    )?;
    let rows = statement.query_map(
        params![user_id, tag_name, start_at_utc, end_at_utc_exclusive, limit],
        |row| {
            Ok(RecentRecordItem {
                record_id: row.get(0)?,
                kind: RecordKind::Time,
                occurred_at: row.get(1)?,
                title: row.get(2)?,
                detail: format!(
                    "{} min{}",
                    row.get::<_, i64>(3)?,
                    note_suffix(&row.get::<_, String>(4)?)
                ),
            })
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    normalize_recent_rows(raw_rows, timezone)
}

fn load_tag_detail_expense_records(
    connection: &Connection,
    user_id: &str,
    tag_name: &str,
    start_date: &str,
    end_date: &str,
    timezone: &str,
    limit: i64,
) -> Result<Vec<RecentRecordItem>> {
    let mut statement = connection.prepare(
        "SELECT e.id, e.occurred_on, e.category_code, e.amount_cents, COALESCE(e.note, '')
         FROM record_tag_links rtl
         JOIN expense_records e
           ON rtl.record_kind = 'expense'
          AND rtl.record_id = e.id
         JOIN tags tg
           ON tg.id = rtl.tag_id
         WHERE e.user_id = ?1
           AND e.is_deleted = 0
           AND tg.name = ?2
           AND e.occurred_on >= ?3
           AND e.occurred_on <= ?4
         ORDER BY e.occurred_on DESC, e.created_at DESC
         LIMIT ?5",
    )?;
    let rows = statement.query_map(
        params![user_id, tag_name, start_date, end_date, limit],
        |row| {
            Ok(RecentRecordItem {
                record_id: row.get(0)?,
                kind: RecordKind::Expense,
                occurred_at: row.get(1)?,
                title: row.get(2)?,
                detail: format!(
                    "{} cents{}",
                    row.get::<_, i64>(3)?,
                    note_suffix(&row.get::<_, String>(4)?)
                ),
            })
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    normalize_recent_rows(raw_rows, timezone)
}

fn load_tag_detail_income_records(
    connection: &Connection,
    user_id: &str,
    tag_name: &str,
    start_date: &str,
    end_date: &str,
    timezone: &str,
    limit: i64,
) -> Result<Vec<RecentRecordItem>> {
    let mut statement = connection.prepare(
        "SELECT i.id, i.occurred_on, i.source_name, i.amount_cents, COALESCE(i.note, '')
         FROM record_tag_links rtl
         JOIN income_records i
           ON rtl.record_kind = 'income'
          AND rtl.record_id = i.id
         JOIN tags tg
           ON tg.id = rtl.tag_id
         WHERE i.user_id = ?1
           AND i.is_deleted = 0
           AND tg.name = ?2
           AND i.occurred_on >= ?3
           AND i.occurred_on <= ?4
         ORDER BY i.occurred_on DESC, i.created_at DESC
         LIMIT ?5",
    )?;
    let rows = statement.query_map(
        params![user_id, tag_name, start_date, end_date, limit],
        |row| {
            Ok(RecentRecordItem {
                record_id: row.get(0)?,
                kind: RecordKind::Income,
                occurred_at: row.get(1)?,
                title: row.get(2)?,
                detail: format!(
                    "{} cents{}",
                    row.get::<_, i64>(3)?,
                    note_suffix(&row.get::<_, String>(4)?)
                ),
            })
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    normalize_recent_rows(raw_rows, timezone)
}

fn load_tag_detail_learning_records(
    connection: &Connection,
    user_id: &str,
    tag_name: &str,
    start_date: &str,
    end_date: &str,
    timezone: &str,
    limit: i64,
) -> Result<Vec<RecentRecordItem>> {
    let mut statement = connection.prepare(
        "SELECT l.id, COALESCE(l.started_at, l.occurred_on), l.content, l.duration_minutes, COALESCE(l.note, '')
         FROM record_tag_links rtl
         JOIN learning_records l
           ON rtl.record_kind = 'learning'
          AND rtl.record_id = l.id
         JOIN tags tg
           ON tg.id = rtl.tag_id
         WHERE l.user_id = ?1
           AND l.is_deleted = 0
           AND tg.name = ?2
           AND l.occurred_on >= ?3
           AND l.occurred_on <= ?4
         ORDER BY COALESCE(l.started_at, l.occurred_on) DESC, l.created_at DESC
         LIMIT ?5",
    )?;
    let rows = statement.query_map(
        params![user_id, tag_name, start_date, end_date, limit],
        |row| {
            Ok(RecentRecordItem {
                record_id: row.get(0)?,
                kind: RecordKind::Learning,
                occurred_at: row.get(1)?,
                title: row.get(2)?,
                detail: format!(
                    "{} min{}",
                    row.get::<_, i64>(3)?,
                    note_suffix(&row.get::<_, String>(4)?)
                ),
            })
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    normalize_recent_rows(raw_rows, timezone)
}

fn normalize_recent_rows(
    raw_rows: Vec<RecentRecordItem>,
    timezone: &str,
) -> Result<Vec<RecentRecordItem>> {
    raw_rows
        .into_iter()
        .map(|mut item| {
            item.occurred_at = normalize_occurrence(item.occurred_at, timezone)?;
            Ok(item)
        })
        .collect()
}

fn structural_expense_for_window(
    connection: &Connection,
    user_id: &str,
    start: NaiveDate,
    end: NaiveDate,
    necessary_only: bool,
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
            let baseline = scalar_long(
                connection,
                "SELECT COALESCE((
                    SELECT COALESCE(basic_living_cents, 0) + COALESCE(fixed_subscription_cents, 0)
                    FROM expense_baseline_months
                    WHERE user_id = ?1 AND month = ?2
                    LIMIT 1
                 ), 0)",
                params![user_id, current_month],
            )?;
            let recurring = if necessary_only {
                scalar_long(
                    connection,
                    "SELECT COALESCE(SUM(monthly_amount_cents), 0)
                     FROM expense_recurring_rules
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND is_necessary = 1
                       AND start_month <= ?2
                       AND (end_month IS NULL OR end_month = '' OR end_month >= ?2)",
                    params![user_id, current_month],
                )?
            } else {
                scalar_long(
                    connection,
                    "SELECT COALESCE(SUM(monthly_amount_cents), 0)
                     FROM expense_recurring_rules
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND start_month <= ?2
                       AND (end_month IS NULL OR end_month = '' OR end_month >= ?2)",
                    params![user_id, current_month],
                )?
            };
            let capex = if necessary_only {
                0
            } else {
                scalar_long(
                    connection,
                    "SELECT COALESCE(SUM(monthly_amortized_cents), 0)
                     FROM expense_capex_items
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND amortization_start_month <= ?2
                       AND amortization_end_month >= ?2",
                    params![user_id, current_month],
                )?
            };
            total += (baseline + recurring + capex) * overlap_days / month_days;
        }
        cursor = month_end + Duration::days(1);
    }
    Ok(total)
}

fn scalar_long(connection: &Connection, sql: &str, params: impl rusqlite::Params) -> Result<i64> {
    connection
        .query_row(sql, params, |row| row.get::<_, i64>(0))
        .map_err(Into::into)
}

fn to_utc_start(date: NaiveDate, timezone: &str) -> Result<String> {
    let tz: Tz = timezone
        .parse()
        .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))?;
    let local = date
        .and_hms_opt(0, 0, 0)
        .ok_or_else(|| LifeOsError::InvalidInput("invalid local date start".to_string()))?;
    let zoned = tz
        .from_local_datetime(&local)
        .single()
        .or_else(|| tz.from_local_datetime(&local).earliest())
        .ok_or_else(|| {
            LifeOsError::InvalidInput("failed to resolve review timezone".to_string())
        })?;
    Ok(zoned.to_utc().to_rfc3339())
}

fn to_utc_end_exclusive(date: NaiveDate, timezone: &str) -> Result<String> {
    to_utc_start(date + Duration::days(1), timezone)
}

fn normalize_occurrence(value: String, timezone: &str) -> Result<String> {
    if let Ok(parsed) = chrono::DateTime::parse_from_rfc3339(&value) {
        let tz: Tz = timezone
            .parse()
            .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))?;
        return Ok(parsed
            .with_timezone(&tz)
            .to_rfc3339_opts(chrono::SecondsFormat::Secs, true));
    }
    Ok(value)
}

fn parse_kind(value: &str) -> Result<RecordKind> {
    match value {
        "time" => Ok(RecordKind::Time),
        "income" => Ok(RecordKind::Income),
        "expense" => Ok(RecordKind::Expense),
        "learning" => Ok(RecordKind::Learning),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported review record kind: {other}"
        ))),
    }
}

fn ratio_change(current: i64, previous: i64) -> Option<f64> {
    if previous <= 0 {
        None
    } else {
        Some((current as f64 - previous as f64) / previous as f64)
    }
}

fn roi(income_cents: i64, cost_cents: i64) -> f64 {
    if cost_cents <= 0 {
        0.0
    } else {
        (income_cents - cost_cents) as f64 / cost_cents as f64 * 100.0
    }
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
    let ideal = scalar_long(
        connection,
        "SELECT COALESCE(ideal_hourly_rate_cents, 0)
         FROM users
         WHERE id = ?1
         LIMIT 1",
        params![user_id],
    )?;
    if ideal > 0 {
        return Ok(ideal);
    }
    let total_income = scalar_long(
        connection,
        "SELECT COALESCE(SUM(amount_cents), 0)
         FROM income_records
         WHERE user_id = ?1 AND is_deleted = 0",
        params![user_id],
    )?;
    let total_work_minutes = total_user_work_minutes(
        connection,
        user_id,
        "1970-01-01T00:00:00+00:00",
        "2100-01-01T00:00:00+00:00",
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
    let income = scalar_long(
        connection,
        "SELECT COALESCE(SUM(amount_cents), 0)
         FROM income_records
         WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?2 AND occurred_on <= ?3",
        params![user_id, start.to_string(), end.to_string()],
    )?;
    let work = total_user_work_minutes(
        connection,
        user_id,
        &to_utc_start(start, timezone)?,
        &to_utc_end_exclusive(end, timezone)?,
    )?;
    Ok(if work > 0 { income * 60 / work } else { 0 })
}

fn total_user_work_minutes(
    connection: &Connection,
    user_id: &str,
    start_at_utc: &str,
    end_at_utc_exclusive: &str,
) -> Result<i64> {
    scalar_long(
        connection,
        "SELECT COALESCE(SUM(duration_minutes), 0)
         FROM time_records
         WHERE user_id = ?1
           AND is_deleted = 0
           AND category_code = 'work'
           AND started_at >= ?2
           AND started_at < ?3",
        params![user_id, start_at_utc, end_at_utc_exclusive],
    )
}

fn parse_timezone(timezone: &str) -> Result<Tz> {
    timezone
        .parse()
        .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))
}

fn build_summary(
    total_time_minutes: i64,
    total_income_cents: i64,
    total_expense_cents: i64,
    ai_assist_rate: Option<f64>,
    work_efficiency_avg: Option<f64>,
    learning_efficiency_avg: Option<f64>,
) -> String {
    if total_time_minutes <= 0 && total_income_cents <= 0 && total_expense_cents <= 0 {
        return "本期暂无有效记录。".to_string();
    }
    let mut summary = format!(
        "本期投入 {} 小时，收入 {:.2}，支出 {:.2}。",
        total_time_minutes / 60,
        total_income_cents as f64 / 100.0,
        total_expense_cents as f64 / 100.0
    );
    if let Some(ai_assist_rate) = ai_assist_rate {
        summary.push_str(&format!(" AI辅助率 {:.1}%。", ai_assist_rate * 100.0));
    }
    if let Some(work_efficiency_avg) = work_efficiency_avg {
        summary.push_str(&format!(" 工作效率均分 {:.2}/10。", work_efficiency_avg));
    }
    if let Some(learning_efficiency_avg) = learning_efficiency_avg {
        summary.push_str(&format!(
            " 学习效率均分 {:.2}/10。",
            learning_efficiency_avg
        ));
    }
    summary
}

fn note_suffix(note: &str) -> String {
    if note.trim().is_empty() {
        String::new()
    } else {
        format!(" | {}", note.trim())
    }
}

fn append_note<T: Into<String>>(base: T, note: String) -> String {
    format!("{}{}", base.into(), note_suffix(&note))
}
