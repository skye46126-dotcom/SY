use std::path::Path;

use crate::db::Database;
use crate::error::Result;
use crate::models::{
    CapexCostInput, CapexCostSummary, MonthlyCostBaseline, MonthlyCostBaselineInput,
    RateComparisonSummary, RecurringCostRuleInput, RecurringCostRuleSummary,
};
use crate::repositories::cost_repository::CostRepository;

#[derive(Debug, Clone)]
pub struct CostService {
    database: Database,
}

impl CostService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn get_ideal_hourly_rate_cents(&self, user_id: &str) -> Result<i64> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::get_ideal_hourly_rate_cents(&connection, user_id)
    }

    pub fn set_ideal_hourly_rate_cents(&self, user_id: &str, cents: i64) -> Result<()> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::set_ideal_hourly_rate_cents(&connection, user_id, cents)
    }

    pub fn get_current_month_basic_living_cents(&self, user_id: &str) -> Result<i64> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::get_current_month_basic_living_cents(&connection, user_id)
    }

    pub fn set_current_month_basic_living_cents(
        &self,
        user_id: &str,
        cents: i64,
    ) -> Result<MonthlyCostBaseline> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::set_current_month_basic_living_cents(&connection, user_id, cents)
    }

    pub fn get_current_month_fixed_subscription_cents(&self, user_id: &str) -> Result<i64> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::get_current_month_fixed_subscription_cents(&connection, user_id)
    }

    pub fn set_current_month_fixed_subscription_cents(
        &self,
        user_id: &str,
        cents: i64,
    ) -> Result<MonthlyCostBaseline> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::set_current_month_fixed_subscription_cents(&connection, user_id, cents)
    }

    pub fn get_monthly_baseline(&self, user_id: &str, month: &str) -> Result<MonthlyCostBaseline> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::get_monthly_baseline(&connection, user_id, month)
    }

    pub fn upsert_monthly_baseline(
        &self,
        user_id: &str,
        input: &MonthlyCostBaselineInput,
    ) -> Result<MonthlyCostBaseline> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::upsert_monthly_baseline(&connection, user_id, input)
    }

    pub fn list_recurring_cost_rules(
        &self,
        user_id: &str,
    ) -> Result<Vec<RecurringCostRuleSummary>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::list_recurring_cost_rules(&connection, user_id)
    }

    pub fn create_recurring_cost_rule(
        &self,
        user_id: &str,
        input: &RecurringCostRuleInput,
    ) -> Result<RecurringCostRuleSummary> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::create_recurring_cost_rule(&connection, user_id, input)
    }

    pub fn update_recurring_cost_rule(
        &self,
        user_id: &str,
        rule_id: &str,
        input: &RecurringCostRuleInput,
    ) -> Result<RecurringCostRuleSummary> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::update_recurring_cost_rule(&connection, user_id, rule_id, input)
    }

    pub fn delete_recurring_cost_rule(&self, user_id: &str, rule_id: &str) -> Result<()> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::delete_recurring_cost_rule(&connection, user_id, rule_id)
    }

    pub fn list_capex_costs(&self, user_id: &str) -> Result<Vec<CapexCostSummary>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::list_capex_costs(&connection, user_id)
    }

    pub fn create_capex_cost(
        &self,
        user_id: &str,
        input: &CapexCostInput,
    ) -> Result<CapexCostSummary> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::create_capex_cost(&connection, user_id, input)
    }

    pub fn update_capex_cost(
        &self,
        user_id: &str,
        capex_id: &str,
        input: &CapexCostInput,
    ) -> Result<CapexCostSummary> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::update_capex_cost(&connection, user_id, capex_id, input)
    }

    pub fn delete_capex_cost(&self, user_id: &str, capex_id: &str) -> Result<()> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::delete_capex_cost(&connection, user_id, capex_id)
    }

    pub fn get_rate_comparison(
        &self,
        user_id: &str,
        anchor_date: &str,
        window_type: &str,
    ) -> Result<RateComparisonSummary> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CostRepository::get_rate_comparison(&connection, user_id, anchor_date, window_type)
    }
}
