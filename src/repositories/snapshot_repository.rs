use chrono::{Datelike, Duration, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;
use rusqlite::{Connection, OptionalExtension, params};
use uuid::Uuid;

use crate::error::{LifeOsError, Result};
use crate::models::{MetricSnapshotSummary, ProjectMetricSnapshotSummary, SnapshotWindow};
use crate::repositories::record_repository::ensure_user_exists;

pub struct SnapshotRepository;

impl SnapshotRepository {
    pub fn recompute_snapshot(
        connection: &mut Connection,
        user_id: &str,
        snapshot_date: &str,
        window: SnapshotWindow,
    ) -> Result<MetricSnapshotSummary> {
        ensure_user_exists(connection, user_id)?;
        let anchor_date =
            NaiveDate::parse_from_str(snapshot_date.trim(), "%Y-%m-%d").map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid snapshot_date: {error}"))
            })?;
        let timezone = query_timezone(connection, user_id)?;
        let (start_date, end_date) = compute_window_dates(anchor_date, window);
        let start_utc = to_utc_start(start_date, &timezone)?;
        let end_utc_exclusive = to_utc_end_exclusive(end_date, &timezone)?;

        let total_income_cents = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?2 AND occurred_on <= ?3",
            params![user_id, start_date.to_string(), end_date.to_string()],
        )?;
        let total_expense_direct = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM expense_records
             WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?2 AND occurred_on <= ?3",
            params![user_id, start_date.to_string(), end_date.to_string()],
        )?;
        let structural_expense =
            structural_expense_for_window(connection, user_id, start_date, end_date, false)?;
        let total_expense_cents = total_expense_direct + structural_expense;
        let passive_income_cents = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1 AND is_deleted = 0 AND is_passive = 1 AND occurred_on >= ?2 AND occurred_on <= ?3",
            params![user_id, start_date.to_string(), end_date.to_string()],
        )?;
        let necessary_expense_direct = scalar_long(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM expense_records
             WHERE user_id = ?1 AND is_deleted = 0 AND category_code = 'necessary' AND occurred_on >= ?2 AND occurred_on <= ?3",
            params![user_id, start_date.to_string(), end_date.to_string()],
        )?;
        let necessary_structural_expense =
            structural_expense_for_window(connection, user_id, start_date, end_date, true)?;
        let necessary_expense_cents = necessary_expense_direct + necessary_structural_expense;
        let total_work_minutes = scalar_long(
            connection,
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1 AND is_deleted = 0 AND category_code = 'work' AND started_at >= ?2 AND started_at < ?3",
            params![user_id, start_utc, end_utc_exclusive],
        )?;
        let ideal_hourly_rate_cents = scalar_long(
            connection,
            "SELECT COALESCE(ideal_hourly_rate_cents, 0)
             FROM users
             WHERE id = ?1
             LIMIT 1",
            params![user_id],
        )?;
        let hourly_rate_cents = if total_work_minutes > 0 {
            Some((total_income_cents * 60) / total_work_minutes)
        } else {
            None
        };
        let time_debt_cents = hourly_rate_cents.map(|actual| ideal_hourly_rate_cents - actual);
        let passive_cover_ratio = if necessary_expense_cents > 0 {
            Some(passive_income_cents as f64 / necessary_expense_cents as f64)
        } else {
            None
        };
        let freedom_cents = Some(passive_income_cents - necessary_expense_cents);

        let snapshot_id = Uuid::now_v7().to_string();
        let generated_at = chrono::Utc::now().to_rfc3339();
        let tx = connection.transaction()?;
        tx.execute(
            "INSERT INTO metric_snapshots(
                id, user_id, snapshot_date, window_type, hourly_rate_cents, time_debt_cents,
                passive_cover_ratio, freedom_cents, total_income_cents, total_expense_cents,
                total_work_minutes, generated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
             ON CONFLICT(user_id, snapshot_date, window_type) DO UPDATE SET
                id = excluded.id,
                hourly_rate_cents = excluded.hourly_rate_cents,
                time_debt_cents = excluded.time_debt_cents,
                passive_cover_ratio = excluded.passive_cover_ratio,
                freedom_cents = excluded.freedom_cents,
                total_income_cents = excluded.total_income_cents,
                total_expense_cents = excluded.total_expense_cents,
                total_work_minutes = excluded.total_work_minutes,
                generated_at = excluded.generated_at",
            params![
                snapshot_id,
                user_id,
                snapshot_date,
                window.as_str(),
                hourly_rate_cents,
                time_debt_cents,
                passive_cover_ratio,
                freedom_cents,
                Some(total_income_cents),
                Some(total_expense_cents),
                Some(total_work_minutes),
                generated_at,
            ],
        )?;

        let persisted_snapshot_id = tx.query_row(
            "SELECT id
                 FROM metric_snapshots
                 WHERE user_id = ?1 AND snapshot_date = ?2 AND window_type = ?3
                 LIMIT 1",
            params![user_id, snapshot_date, window.as_str()],
            |row| row.get::<_, String>(0),
        )?;
        tx.execute(
            "DELETE FROM metric_snapshot_projects WHERE metric_snapshot_id = ?1",
            params![persisted_snapshot_id],
        )?;

        let project_rows = collect_project_snapshots(
            &tx,
            user_id,
            &persisted_snapshot_id,
            start_date,
            end_date,
            &start_utc,
            &end_utc_exclusive,
            total_work_minutes,
            &timezone,
        )?;
        for project in project_rows {
            tx.execute(
                "INSERT INTO metric_snapshot_projects(
                    metric_snapshot_id, project_id, income_cents, direct_expense_cents,
                    structural_cost_cents, operating_cost_cents, total_cost_cents, profit_cents,
                    invested_minutes, roi_ratio, break_even_cents, created_at
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
                params![
                    project.metric_snapshot_id,
                    project.project_id,
                    project.income_cents,
                    project.direct_expense_cents,
                    project.structural_cost_cents,
                    project.operating_cost_cents,
                    project.total_cost_cents,
                    project.profit_cents,
                    project.invested_minutes,
                    project.roi_ratio,
                    project.break_even_cents,
                    generated_at,
                ],
            )?;
        }
        tx.commit()?;

        Self::get_snapshot(connection, user_id, snapshot_date, window)?.ok_or_else(|| {
            LifeOsError::InvalidInput("snapshot missing after recompute".to_string())
        })
    }

    pub fn get_snapshot(
        connection: &Connection,
        user_id: &str,
        snapshot_date: &str,
        window: SnapshotWindow,
    ) -> Result<Option<MetricSnapshotSummary>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, snapshot_date, window_type, hourly_rate_cents, time_debt_cents,
                        passive_cover_ratio, freedom_cents, total_income_cents, total_expense_cents,
                        total_work_minutes, generated_at
                 FROM metric_snapshots
                 WHERE user_id = ?1 AND snapshot_date = ?2 AND window_type = ?3
                 LIMIT 1",
                params![user_id, snapshot_date, window.as_str()],
                |row| {
                    Ok(MetricSnapshotSummary {
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

    pub fn get_latest_snapshot(
        connection: &Connection,
        user_id: &str,
        window: SnapshotWindow,
    ) -> Result<Option<MetricSnapshotSummary>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, snapshot_date, window_type, hourly_rate_cents, time_debt_cents,
                        passive_cover_ratio, freedom_cents, total_income_cents, total_expense_cents,
                        total_work_minutes, generated_at
                 FROM metric_snapshots
                 WHERE user_id = ?1 AND window_type = ?2
                 ORDER BY snapshot_date DESC
                 LIMIT 1",
                params![user_id, window.as_str()],
                |row| {
                    Ok(MetricSnapshotSummary {
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

    pub fn list_project_snapshots(
        connection: &Connection,
        user_id: &str,
        metric_snapshot_id: &str,
    ) -> Result<Vec<ProjectMetricSnapshotSummary>> {
        ensure_user_exists(connection, user_id)?;
        let snapshot_owner_exists = connection
            .query_row(
                "SELECT 1
                 FROM metric_snapshots
                 WHERE id = ?1 AND user_id = ?2
                 LIMIT 1",
                params![metric_snapshot_id, user_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()?;
        if snapshot_owner_exists.is_none() {
            return Err(LifeOsError::InvalidInput(format!(
                "snapshot not found: {metric_snapshot_id}"
            )));
        }
        let mut statement = connection.prepare(
            "SELECT metric_snapshot_id, project_id, income_cents, direct_expense_cents,
                    structural_cost_cents, operating_cost_cents, total_cost_cents, profit_cents,
                    invested_minutes, roi_ratio, break_even_cents
             FROM metric_snapshot_projects
             WHERE metric_snapshot_id = ?1
             ORDER BY income_cents DESC, invested_minutes DESC, project_id ASC",
        )?;
        let rows = statement.query_map(params![metric_snapshot_id], |row| {
            Ok(ProjectMetricSnapshotSummary {
                metric_snapshot_id: row.get(0)?,
                project_id: row.get(1)?,
                income_cents: row.get(2)?,
                direct_expense_cents: row.get(3)?,
                structural_cost_cents: row.get(4)?,
                operating_cost_cents: row.get(5)?,
                total_cost_cents: row.get(6)?,
                profit_cents: row.get(7)?,
                invested_minutes: row.get(8)?,
                roi_ratio: row.get(9)?,
                break_even_cents: row.get(10)?,
            })
        })?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }
}

fn collect_project_snapshots(
    connection: &Connection,
    user_id: &str,
    metric_snapshot_id: &str,
    start_date: NaiveDate,
    end_date: NaiveDate,
    start_utc: &str,
    end_utc_exclusive: &str,
    total_work_minutes: i64,
    timezone: &str,
) -> Result<Vec<ProjectMetricSnapshotSummary>> {
    let structural_expense_total =
        structural_expense_for_window(connection, user_id, start_date, end_date, false)?;
    let benchmark_hourly_rate_cents = benchmark_hourly_rate_cents(connection, user_id, timezone)?;
    let mut statement = connection.prepare(
        "SELECT p.id,
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
                      ON rpl.record_kind = 'time' AND rpl.record_id = t.id
                    WHERE rpl.project_id = p.id AND t.is_deleted = 0 AND t.started_at >= ?1 AND t.started_at < ?2
                ), 0) AS invested_minutes,
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
                      ON rpl.record_kind = 'income' AND rpl.record_id = i.id
                    WHERE rpl.project_id = p.id AND i.is_deleted = 0 AND i.occurred_on >= ?3 AND i.occurred_on <= ?4
                ), 0) AS income_cents,
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
                      ON rpl.record_kind = 'expense' AND rpl.record_id = e.id
                    WHERE rpl.project_id = p.id AND e.is_deleted = 0 AND e.occurred_on >= ?3 AND e.occurred_on <= ?4
                ), 0) AS direct_expense_cents
         FROM projects p
         WHERE p.user_id = ?5 AND p.is_deleted = 0
         ORDER BY p.id ASC",
    )?;
    let rows = statement.query_map(
        params![
            start_utc,
            end_utc_exclusive,
            start_date.to_string(),
            end_date.to_string(),
            user_id
        ],
        |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, i64>(2)?,
                row.get::<_, i64>(3)?,
            ))
        },
    )?;
    let raw_rows = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    Ok(raw_rows
        .into_iter()
        .filter(
            |(_, invested_minutes, income_cents, direct_expense_cents)| {
                *invested_minutes > 0 || *income_cents > 0 || *direct_expense_cents > 0
            },
        )
        .map(
            |(project_id, invested_minutes, income_cents, direct_expense_cents)| {
                let structural_cost_cents = if structural_expense_total > 0
                    && total_work_minutes > 0
                    && invested_minutes > 0
                {
                    structural_expense_total * invested_minutes / total_work_minutes
                } else {
                    0
                };
                let time_cost_cents = if benchmark_hourly_rate_cents > 0 && invested_minutes > 0 {
                    benchmark_hourly_rate_cents * invested_minutes / 60
                } else {
                    0
                };
                let operating_cost_cents = direct_expense_cents + time_cost_cents;
                let total_cost_cents = operating_cost_cents + structural_cost_cents;
                let profit_cents = income_cents - total_cost_cents;
                let break_even_cents = total_cost_cents;
                let roi_ratio = if total_cost_cents > 0 {
                    (income_cents - total_cost_cents) as f64 / total_cost_cents as f64
                } else {
                    0.0
                };
                ProjectMetricSnapshotSummary {
                    metric_snapshot_id: metric_snapshot_id.to_string(),
                    project_id,
                    income_cents,
                    direct_expense_cents,
                    structural_cost_cents,
                    operating_cost_cents,
                    total_cost_cents,
                    profit_cents,
                    invested_minutes,
                    roi_ratio,
                    break_even_cents,
                }
            },
        )
        .collect())
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
            let recurring = if necessary_only {
                connection.query_row(
                    "SELECT COALESCE(SUM(monthly_amount_cents), 0)
                     FROM expense_recurring_rules
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND is_necessary = 1
                       AND start_month <= ?2
                       AND (end_month IS NULL OR end_month = '' OR end_month >= ?2)",
                    params![user_id, current_month],
                    |row| row.get::<_, i64>(0),
                )?
            } else {
                connection.query_row(
                    "SELECT COALESCE(SUM(monthly_amount_cents), 0)
                     FROM expense_recurring_rules
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND start_month <= ?2
                       AND (end_month IS NULL OR end_month = '' OR end_month >= ?2)",
                    params![user_id, current_month],
                    |row| row.get::<_, i64>(0),
                )?
            };
            let capex = if necessary_only {
                0
            } else {
                connection.query_row(
                    "SELECT COALESCE(SUM(monthly_amortized_cents), 0)
                     FROM expense_capex_items
                     WHERE user_id = ?1
                       AND is_active = 1
                       AND amortization_start_month <= ?2
                       AND amortization_end_month >= ?2",
                    params![user_id, current_month],
                    |row| row.get::<_, i64>(0),
                )?
            };
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

fn compute_window_dates(anchor_date: NaiveDate, window: SnapshotWindow) -> (NaiveDate, NaiveDate) {
    match window {
        SnapshotWindow::Day => (anchor_date, anchor_date),
        SnapshotWindow::Week => (anchor_date - Duration::days(6), anchor_date),
        SnapshotWindow::Month => {
            let start = NaiveDate::from_ymd_opt(anchor_date.year(), anchor_date.month(), 1)
                .expect("valid month start");
            let (next_year, next_month) = if anchor_date.month() == 12 {
                (anchor_date.year() + 1, 1)
            } else {
                (anchor_date.year(), anchor_date.month() + 1)
            };
            let end = NaiveDate::from_ymd_opt(next_year, next_month, 1).expect("valid next month")
                - Duration::days(1);
            (start, end)
        }
        SnapshotWindow::Year => (
            NaiveDate::from_ymd_opt(anchor_date.year(), 1, 1).expect("valid year start"),
            NaiveDate::from_ymd_opt(anchor_date.year(), 12, 31).expect("valid year end"),
        ),
    }
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
        .ok_or_else(|| {
            LifeOsError::InvalidInput("failed to resolve snapshot timezone".to_string())
        })?;
    Ok(zoned.to_utc().to_rfc3339())
}

fn to_utc_end_exclusive(date: NaiveDate, timezone: &str) -> Result<String> {
    to_utc_start(date + Duration::days(1), timezone)
}

fn scalar_long(connection: &Connection, sql: &str, params: impl rusqlite::Params) -> Result<i64> {
    connection
        .query_row(sql, params, |row| row.get::<_, i64>(0))
        .map_err(Into::into)
}

fn total_user_work_minutes(
    connection: &Connection,
    user_id: &str,
    start_utc: &str,
    end_utc_exclusive: &str,
) -> Result<i64> {
    scalar_long(
        connection,
        "SELECT COALESCE(SUM(duration_minutes), 0)
         FROM time_records
         WHERE user_id = ?1 AND is_deleted = 0 AND category_code = 'work' AND started_at >= ?2 AND started_at < ?3",
        params![user_id, start_utc, end_utc_exclusive],
    )
}
