use chrono::{Datelike, Duration, Local, NaiveDate, TimeZone};
use chrono_tz::Tz;
use rusqlite::{Connection, OptionalExtension, params};
use uuid::Uuid;

use crate::error::{LifeOsError, Result};
use crate::models::{
    CapexCostInput, CapexCostSummary, MonthlyCostBaseline, MonthlyCostBaselineInput,
    RateComparisonSummary, RecurringCostRuleInput, RecurringCostRuleSummary, parse_month,
};
use crate::repositories::record_repository::{
    DimensionKind, ensure_user_exists, now_string, upsert_dimension_code,
};

pub struct CostRepository;

impl CostRepository {
    pub fn get_ideal_hourly_rate_cents(connection: &Connection, user_id: &str) -> Result<i64> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT COALESCE(ideal_hourly_rate_cents, 0) FROM users WHERE id = ?1 LIMIT 1",
                [user_id],
                |row| row.get::<_, i64>(0),
            )
            .map_err(Into::into)
    }

    pub fn set_ideal_hourly_rate_cents(
        connection: &Connection,
        user_id: &str,
        cents: i64,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        connection.execute(
            "UPDATE users
             SET ideal_hourly_rate_cents = ?1,
                 updated_at = ?2
             WHERE id = ?3",
            params![cents.max(0), now_string(), user_id],
        )?;
        Ok(())
    }

    pub fn get_current_month_basic_living_cents(
        connection: &Connection,
        user_id: &str,
    ) -> Result<i64> {
        let baseline = Self::get_monthly_baseline(connection, user_id, &current_month())?;
        Ok(baseline.basic_living_cents)
    }

    pub fn set_current_month_basic_living_cents(
        connection: &Connection,
        user_id: &str,
        cents: i64,
    ) -> Result<MonthlyCostBaseline> {
        let current = Self::get_monthly_baseline(connection, user_id, &current_month())?;
        Self::upsert_monthly_baseline(
            connection,
            user_id,
            &MonthlyCostBaselineInput {
                month: current.month,
                basic_living_cents: cents.max(0),
                fixed_subscription_cents: current.fixed_subscription_cents,
                note: None,
            },
        )
    }

    pub fn get_current_month_fixed_subscription_cents(
        connection: &Connection,
        user_id: &str,
    ) -> Result<i64> {
        let baseline = Self::get_monthly_baseline(connection, user_id, &current_month())?;
        Ok(baseline.fixed_subscription_cents)
    }

    pub fn set_current_month_fixed_subscription_cents(
        connection: &Connection,
        user_id: &str,
        cents: i64,
    ) -> Result<MonthlyCostBaseline> {
        let current = Self::get_monthly_baseline(connection, user_id, &current_month())?;
        Self::upsert_monthly_baseline(
            connection,
            user_id,
            &MonthlyCostBaselineInput {
                month: current.month,
                basic_living_cents: current.basic_living_cents,
                fixed_subscription_cents: cents.max(0),
                note: None,
            },
        )
    }

    pub fn get_monthly_baseline(
        connection: &Connection,
        user_id: &str,
        month: &str,
    ) -> Result<MonthlyCostBaseline> {
        ensure_user_exists(connection, user_id)?;
        let month = month.trim().to_string();
        parse_month(&month)?;
        let raw = connection
            .query_row(
                "SELECT COALESCE(basic_living_cents, 0), COALESCE(fixed_subscription_cents, 0)
                 FROM expense_baseline_months
                 WHERE user_id = ?1 AND month = ?2
                 LIMIT 1",
                params![user_id, month],
                |row| Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?)),
            )
            .optional()?;
        let (basic_living_cents, fixed_subscription_cents) = raw.unwrap_or((0, 0));
        Ok(MonthlyCostBaseline {
            month,
            basic_living_cents,
            fixed_subscription_cents,
        })
    }

    pub fn upsert_monthly_baseline(
        connection: &Connection,
        user_id: &str,
        input: &MonthlyCostBaselineInput,
    ) -> Result<MonthlyCostBaseline> {
        ensure_user_exists(connection, user_id)?;
        input.validate()?;
        let now = now_string();
        connection.execute(
            "INSERT INTO expense_baseline_months(
                user_id, month, basic_living_cents, fixed_subscription_cents, note, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)
             ON CONFLICT(user_id, month) DO UPDATE SET
                basic_living_cents = excluded.basic_living_cents,
                fixed_subscription_cents = excluded.fixed_subscription_cents,
                note = excluded.note,
                updated_at = excluded.updated_at",
            params![
                user_id,
                input.month,
                input.basic_living_cents.max(0),
                input.fixed_subscription_cents.max(0),
                input.normalized_note(),
                now,
            ],
        )?;
        Self::get_monthly_baseline(connection, user_id, &input.month)
    }

    pub fn list_recurring_cost_rules(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Vec<RecurringCostRuleSummary>> {
        ensure_user_exists(connection, user_id)?;
        let mut statement = connection.prepare(
            "SELECT id, name, category_code, monthly_amount_cents, is_necessary,
                    start_month, end_month, is_active, note
             FROM expense_recurring_rules
             WHERE user_id = ?1
             ORDER BY is_active DESC, start_month DESC, updated_at DESC",
        )?;
        let rows = statement.query_map([user_id], |row| {
            Ok(RecurringCostRuleSummary {
                id: row.get(0)?,
                name: row.get(1)?,
                category_code: row.get(2)?,
                monthly_amount_cents: row.get(3)?,
                is_necessary: row.get::<_, i64>(4)? == 1,
                start_month: row.get(5)?,
                end_month: row.get(6)?,
                is_active: row.get::<_, i64>(7)? == 1,
                note: row.get(8)?,
            })
        })?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn create_recurring_cost_rule(
        connection: &Connection,
        user_id: &str,
        input: &RecurringCostRuleInput,
    ) -> Result<RecurringCostRuleSummary> {
        ensure_user_exists(connection, user_id)?;
        input.validate()?;
        upsert_dimension_code(
            connection,
            DimensionKind::ExpenseCategory,
            &input.normalized_category_code(),
        )?;
        let id = Uuid::now_v7().to_string();
        let now = now_string();
        connection.execute(
            "INSERT INTO expense_recurring_rules(
                id, user_id, name, category_code, monthly_amount_cents, is_necessary,
                start_month, end_month, is_active, note, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 1, ?9, ?10, ?10)",
            params![
                id,
                user_id,
                input.normalized_name(),
                input.normalized_category_code(),
                input.monthly_amount_cents.max(0),
                input.is_necessary as i32,
                input.start_month,
                input.normalized_end_month(),
                input.normalized_note(),
                now,
            ],
        )?;
        Self::get_recurring_cost_rule(connection, user_id, &id)?
            .ok_or_else(|| LifeOsError::InvalidInput("created recurring rule missing".to_string()))
    }

    pub fn update_recurring_cost_rule(
        connection: &Connection,
        user_id: &str,
        rule_id: &str,
        input: &RecurringCostRuleInput,
    ) -> Result<RecurringCostRuleSummary> {
        ensure_user_exists(connection, user_id)?;
        input.validate()?;
        ensure_recurring_rule_exists(connection, user_id, rule_id)?;
        upsert_dimension_code(
            connection,
            DimensionKind::ExpenseCategory,
            &input.normalized_category_code(),
        )?;
        connection.execute(
            "UPDATE expense_recurring_rules
             SET name = ?1,
                 category_code = ?2,
                 monthly_amount_cents = ?3,
                 is_necessary = ?4,
                 start_month = ?5,
                 end_month = ?6,
                 note = ?7,
                 updated_at = ?8
             WHERE id = ?9 AND user_id = ?10",
            params![
                input.normalized_name(),
                input.normalized_category_code(),
                input.monthly_amount_cents.max(0),
                input.is_necessary as i32,
                input.start_month,
                input.normalized_end_month(),
                input.normalized_note(),
                now_string(),
                rule_id,
                user_id,
            ],
        )?;
        Self::get_recurring_cost_rule(connection, user_id, rule_id)?
            .ok_or_else(|| LifeOsError::InvalidInput("updated recurring rule missing".to_string()))
    }

    pub fn delete_recurring_cost_rule(
        connection: &Connection,
        user_id: &str,
        rule_id: &str,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        ensure_recurring_rule_exists(connection, user_id, rule_id)?;
        connection.execute(
            "DELETE FROM expense_recurring_rules WHERE id = ?1 AND user_id = ?2",
            params![rule_id, user_id],
        )?;
        Ok(())
    }

    pub fn list_capex_costs(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Vec<CapexCostSummary>> {
        ensure_user_exists(connection, user_id)?;
        let mut statement = connection.prepare(
            "SELECT id, name, purchase_date, purchase_amount_cents, useful_months,
                    residual_rate_bps, monthly_amortized_cents, amortization_start_month,
                    amortization_end_month, is_active, note
             FROM expense_capex_items
             WHERE user_id = ?1
             ORDER BY is_active DESC, purchase_date DESC, updated_at DESC",
        )?;
        let rows = statement.query_map([user_id], |row| {
            Ok(CapexCostSummary {
                id: row.get(0)?,
                name: row.get(1)?,
                purchase_date: row.get(2)?,
                purchase_amount_cents: row.get(3)?,
                useful_months: row.get(4)?,
                residual_rate_bps: row.get(5)?,
                monthly_amortized_cents: row.get(6)?,
                amortization_start_month: row.get(7)?,
                amortization_end_month: row.get(8)?,
                is_active: row.get::<_, i64>(9)? == 1,
                note: row.get(10)?,
            })
        })?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn create_capex_cost(
        connection: &Connection,
        user_id: &str,
        input: &CapexCostInput,
    ) -> Result<CapexCostSummary> {
        ensure_user_exists(connection, user_id)?;
        input.validate()?;
        let (monthly_amortized_cents, start_month, end_month) = compute_capex_fields(input)?;
        let id = Uuid::now_v7().to_string();
        let now = now_string();
        connection.execute(
            "INSERT INTO expense_capex_items(
                id, user_id, name, purchase_date, purchase_amount_cents, residual_rate_bps,
                useful_months, monthly_amortized_cents, amortization_start_month,
                amortization_end_month, is_active, note, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 1, ?11, ?12, ?12)",
            params![
                id,
                user_id,
                input.normalized_name(),
                input.purchase_date,
                input.purchase_amount_cents.max(0),
                input.residual_rate_bps,
                input.useful_months,
                monthly_amortized_cents,
                start_month,
                end_month,
                input.normalized_note(),
                now,
            ],
        )?;
        Self::get_capex_cost(connection, user_id, &id)?
            .ok_or_else(|| LifeOsError::InvalidInput("created capex item missing".to_string()))
    }

    pub fn update_capex_cost(
        connection: &Connection,
        user_id: &str,
        capex_id: &str,
        input: &CapexCostInput,
    ) -> Result<CapexCostSummary> {
        ensure_user_exists(connection, user_id)?;
        input.validate()?;
        ensure_capex_exists(connection, user_id, capex_id)?;
        let (monthly_amortized_cents, start_month, end_month) = compute_capex_fields(input)?;
        connection.execute(
            "UPDATE expense_capex_items
             SET name = ?1,
                 purchase_date = ?2,
                 purchase_amount_cents = ?3,
                 residual_rate_bps = ?4,
                 useful_months = ?5,
                 monthly_amortized_cents = ?6,
                 amortization_start_month = ?7,
                 amortization_end_month = ?8,
                 note = ?9,
                 updated_at = ?10
             WHERE id = ?11 AND user_id = ?12",
            params![
                input.normalized_name(),
                input.purchase_date,
                input.purchase_amount_cents.max(0),
                input.residual_rate_bps,
                input.useful_months,
                monthly_amortized_cents,
                start_month,
                end_month,
                input.normalized_note(),
                now_string(),
                capex_id,
                user_id,
            ],
        )?;
        Self::get_capex_cost(connection, user_id, capex_id)?
            .ok_or_else(|| LifeOsError::InvalidInput("updated capex item missing".to_string()))
    }

    pub fn delete_capex_cost(connection: &Connection, user_id: &str, capex_id: &str) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        ensure_capex_exists(connection, user_id, capex_id)?;
        connection.execute(
            "DELETE FROM expense_capex_items WHERE id = ?1 AND user_id = ?2",
            params![capex_id, user_id],
        )?;
        Ok(())
    }

    pub fn get_rate_comparison(
        connection: &Connection,
        user_id: &str,
        anchor_date: &str,
        window_type: &str,
    ) -> Result<RateComparisonSummary> {
        ensure_user_exists(connection, user_id)?;
        let anchor_date =
            NaiveDate::parse_from_str(anchor_date.trim(), "%Y-%m-%d").map_err(|error| {
                LifeOsError::InvalidInput(format!("anchor_date must be YYYY-MM-DD: {error}"))
            })?;
        let window_type = normalize_window_type(window_type)?;
        let timezone = query_timezone(connection, user_id)?;
        let (start_date, end_date) = compute_window_dates(anchor_date, &window_type);
        let start_utc = to_utc_start(start_date, &timezone)?;
        let end_utc_exclusive = to_utc_end_exclusive(end_date, &timezone)?;

        let current_income_cents = scalar_long_by_dates(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?2 AND occurred_on <= ?3",
            user_id,
            &start_date.to_string(),
            &end_date.to_string(),
        )?;
        let current_work_minutes = scalar_long_by_dates(
            connection,
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1 AND is_deleted = 0 AND category_code = 'work' AND started_at >= ?2 AND started_at < ?3",
            user_id,
            &start_utc,
            &end_utc_exclusive,
        )?;
        let actual_hourly_rate_cents = if current_work_minutes > 0 {
            Some((current_income_cents * 60) / current_work_minutes)
        } else {
            None
        };

        let previous_year = anchor_date.year() - 1;
        let previous_year_start = NaiveDate::from_ymd_opt(previous_year, 1, 1)
            .ok_or_else(|| LifeOsError::InvalidInput("invalid previous year start".to_string()))?;
        let previous_year_end = NaiveDate::from_ymd_opt(previous_year, 12, 31)
            .ok_or_else(|| LifeOsError::InvalidInput("invalid previous year end".to_string()))?;
        let previous_year_start_utc = to_utc_start(previous_year_start, &timezone)?;
        let previous_year_end_utc_exclusive = to_utc_end_exclusive(previous_year_end, &timezone)?;

        let previous_year_income_cents = scalar_long_by_dates(
            connection,
            "SELECT COALESCE(SUM(amount_cents), 0)
             FROM income_records
             WHERE user_id = ?1 AND is_deleted = 0 AND occurred_on >= ?2 AND occurred_on <= ?3",
            user_id,
            &previous_year_start.to_string(),
            &previous_year_end.to_string(),
        )?;
        let previous_year_work_minutes = scalar_long_by_dates(
            connection,
            "SELECT COALESCE(SUM(duration_minutes), 0)
             FROM time_records
             WHERE user_id = ?1 AND is_deleted = 0 AND category_code = 'work' AND started_at >= ?2 AND started_at < ?3",
            user_id,
            &previous_year_start_utc,
            &previous_year_end_utc_exclusive,
        )?;
        let previous_year_average_hourly_rate_cents = if previous_year_work_minutes > 0 {
            Some((previous_year_income_cents * 60) / previous_year_work_minutes)
        } else {
            None
        };

        Ok(RateComparisonSummary {
            anchor_date: anchor_date.to_string(),
            window_type,
            ideal_hourly_rate_cents: Self::get_ideal_hourly_rate_cents(connection, user_id)?,
            previous_year_average_hourly_rate_cents,
            actual_hourly_rate_cents,
            previous_year_income_cents,
            previous_year_work_minutes,
            current_income_cents,
            current_work_minutes,
        })
    }

    fn get_recurring_cost_rule(
        connection: &Connection,
        user_id: &str,
        rule_id: &str,
    ) -> Result<Option<RecurringCostRuleSummary>> {
        connection
            .query_row(
                "SELECT id, name, category_code, monthly_amount_cents, is_necessary,
                        start_month, end_month, is_active, note
                 FROM expense_recurring_rules
                 WHERE id = ?1 AND user_id = ?2
                 LIMIT 1",
                params![rule_id, user_id],
                |row| {
                    Ok(RecurringCostRuleSummary {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        category_code: row.get(2)?,
                        monthly_amount_cents: row.get(3)?,
                        is_necessary: row.get::<_, i64>(4)? == 1,
                        start_month: row.get(5)?,
                        end_month: row.get(6)?,
                        is_active: row.get::<_, i64>(7)? == 1,
                        note: row.get(8)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
    }

    fn get_capex_cost(
        connection: &Connection,
        user_id: &str,
        capex_id: &str,
    ) -> Result<Option<CapexCostSummary>> {
        connection
            .query_row(
                "SELECT id, name, purchase_date, purchase_amount_cents, useful_months,
                        residual_rate_bps, monthly_amortized_cents, amortization_start_month,
                        amortization_end_month, is_active, note
                 FROM expense_capex_items
                 WHERE id = ?1 AND user_id = ?2
                 LIMIT 1",
                params![capex_id, user_id],
                |row| {
                    Ok(CapexCostSummary {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        purchase_date: row.get(2)?,
                        purchase_amount_cents: row.get(3)?,
                        useful_months: row.get(4)?,
                        residual_rate_bps: row.get(5)?,
                        monthly_amortized_cents: row.get(6)?,
                        amortization_start_month: row.get(7)?,
                        amortization_end_month: row.get(8)?,
                        is_active: row.get::<_, i64>(9)? == 1,
                        note: row.get(10)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
    }
}

fn ensure_recurring_rule_exists(
    connection: &Connection,
    user_id: &str,
    rule_id: &str,
) -> Result<()> {
    let exists = connection
        .query_row(
            "SELECT 1 FROM expense_recurring_rules WHERE id = ?1 AND user_id = ?2 LIMIT 1",
            params![rule_id, user_id],
            |row| row.get::<_, i64>(0),
        )
        .optional()?;
    if exists.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "recurring cost rule not found: {rule_id}"
        )));
    }
    Ok(())
}

fn ensure_capex_exists(connection: &Connection, user_id: &str, capex_id: &str) -> Result<()> {
    let exists = connection
        .query_row(
            "SELECT 1 FROM expense_capex_items WHERE id = ?1 AND user_id = ?2 LIMIT 1",
            params![capex_id, user_id],
            |row| row.get::<_, i64>(0),
        )
        .optional()?;
    if exists.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "capex item not found: {capex_id}"
        )));
    }
    Ok(())
}

fn compute_capex_fields(input: &CapexCostInput) -> Result<(i64, String, String)> {
    let purchase_date =
        NaiveDate::parse_from_str(&input.purchase_date, "%Y-%m-%d").map_err(|error| {
            LifeOsError::InvalidInput(format!("purchase_date must be YYYY-MM-DD: {error}"))
        })?;
    let residual_cents = ((input.purchase_amount_cents.max(0) as f64)
        * (input.residual_rate_bps as f64 / 10000.0))
        .round() as i64;
    let amortizable_cents = (input.purchase_amount_cents.max(0) - residual_cents).max(0);
    let monthly_amortized_cents =
        (amortizable_cents as f64 / input.useful_months as f64).round() as i64;
    let start_month = format!("{:04}-{:02}", purchase_date.year(), purchase_date.month());
    let mut end_year = purchase_date.year();
    let mut end_month = purchase_date.month() as i32 + input.useful_months - 1;
    while end_month > 12 {
        end_year += 1;
        end_month -= 12;
    }
    let end_month = format!("{:04}-{:02}", end_year, end_month);
    Ok((monthly_amortized_cents, start_month, end_month))
}

fn normalize_window_type(window_type: &str) -> Result<String> {
    let normalized = window_type.trim().to_lowercase();
    if matches!(normalized.as_str(), "day" | "week" | "month" | "year") {
        Ok(normalized)
    } else {
        Err(LifeOsError::InvalidInput(format!(
            "unsupported window_type: {window_type}"
        )))
    }
}

fn compute_window_dates(anchor_date: NaiveDate, window_type: &str) -> (NaiveDate, NaiveDate) {
    match window_type {
        "day" => (anchor_date, anchor_date),
        "week" => (anchor_date - Duration::days(6), anchor_date),
        "month" => {
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
        "year" => (
            NaiveDate::from_ymd_opt(anchor_date.year(), 1, 1).expect("valid year start"),
            NaiveDate::from_ymd_opt(anchor_date.year(), 12, 31).expect("valid year end"),
        ),
        _ => unreachable!(),
    }
}

fn query_timezone(connection: &Connection, user_id: &str) -> Result<String> {
    connection
        .query_row(
            "SELECT timezone FROM users WHERE id = ?1 LIMIT 1",
            [user_id],
            |row| row.get::<_, String>(0),
        )
        .optional()
        .map(|value| value.unwrap_or_else(|| "Asia/Shanghai".to_string()))
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
        .ok_or_else(|| LifeOsError::InvalidInput("failed to resolve timezone start".to_string()))?;
    Ok(zoned.to_utc().to_rfc3339())
}

fn to_utc_end_exclusive(date: NaiveDate, timezone: &str) -> Result<String> {
    to_utc_start(date + Duration::days(1), timezone)
}

fn scalar_long_by_dates(
    connection: &Connection,
    sql: &str,
    user_id: &str,
    start: &str,
    end: &str,
) -> Result<i64> {
    connection
        .query_row(sql, params![user_id, start, end], |row| {
            row.get::<_, i64>(0)
        })
        .map_err(Into::into)
}

fn current_month() -> String {
    let today = Local::now().date_naive();
    format!("{:04}-{:02}", today.year(), today.month())
}
