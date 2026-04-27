use std::path::Path;

use chrono::{Duration, Local};
use rusqlite::params;
use serde::Serialize;

use crate::db::Database;
use crate::error::Result;
use crate::models::{
    CapexCostInput, CreateAiServiceConfigInput, CreateCloudSyncConfigInput,
    CreateExpenseRecordInput, CreateIncomeRecordInput, CreateLearningRecordInput,
    CreateProjectInput, CreateTagInput, CreateTimeRecordInput, DimensionOptionInput,
    MonthlyCostBaselineInput, ParserMode, ProjectAllocation, RecurringCostRuleInput,
};
use crate::services::{
    AiService, BackupService, CostService, ProjectService, RecordService, SnapshotService,
};

#[derive(Debug, Clone, Serialize)]
pub struct DemoDataResult {
    pub user_id: String,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct DemoDataService {
    database: Database,
}

impl DemoDataService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn clear_demo_data(&self, user_id: &str) -> Result<DemoDataResult> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        connection.execute("DELETE FROM metric_snapshot_projects", [])?;
        connection.execute("DELETE FROM metric_snapshots WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM restore_records WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM backup_records WHERE user_id = ?1", [user_id])?;
        connection.execute(
            "DELETE FROM cloud_sync_configs WHERE user_id = ?1",
            [user_id],
        )?;
        connection.execute(
            "DELETE FROM ai_service_configs WHERE user_id = ?1",
            [user_id],
        )?;
        connection.execute(
            "DELETE FROM expense_capex_items WHERE user_id = ?1",
            [user_id],
        )?;
        connection.execute(
            "DELETE FROM expense_recurring_rules WHERE user_id = ?1",
            [user_id],
        )?;
        connection.execute(
            "DELETE FROM expense_baseline_months WHERE user_id = ?1",
            [user_id],
        )?;
        connection.execute("DELETE FROM daily_reviews WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM audit_logs WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM record_tag_links WHERE user_id = ?1", [user_id])?;
        connection.execute(
            "DELETE FROM record_project_links WHERE user_id = ?1",
            [user_id],
        )?;
        connection.execute("DELETE FROM learning_records WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM expense_records WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM income_records WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM time_records WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM project_members WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM projects WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM tags WHERE user_id = ?1", [user_id])?;
        connection.execute("DELETE FROM settings WHERE user_id = ?1", [user_id])?;
        connection.execute(
            "UPDATE users SET ideal_hourly_rate_cents = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?1",
            [user_id],
        )?;
        Ok(DemoDataResult {
            user_id: user_id.to_string(),
            message: "demo data cleared".to_string(),
        })
    }

    pub fn seed_demo_data(&self, user_id: &str) -> Result<DemoDataResult> {
        self.clear_demo_data(user_id)?;

        let record_service = RecordService::new(self.database.path());
        let project_service = ProjectService::new(self.database.path());
        let cost_service = CostService::new(self.database.path());
        let ai_service = AiService::new(self.database.path());
        let backup_service = BackupService::new(self.database.path());
        let snapshot_service = SnapshotService::new(self.database.path());

        record_service.init_database()?;
        self.write_setting(user_id, "today_work_target_minutes", "240")?;
        self.write_setting(user_id, "today_learning_target_minutes", "90")?;
        cost_service.set_ideal_hourly_rate_cents(user_id, 35_000)?;
        record_service.save_dimension_option(
            user_id,
            "income_type",
            &DimensionOptionInput {
                code: "passive".to_string(),
                display_name: "Passive".to_string(),
                is_active: true,
            },
        )?;
        record_service.save_dimension_option(
            user_id,
            "expense_category",
            &DimensionOptionInput {
                code: "software".to_string(),
                display_name: "Software".to_string(),
                is_active: true,
            },
        )?;

        let work_tag = record_service.create_tag(&CreateTagInput {
            user_id: user_id.to_string(),
            name: "工作".to_string(),
            emoji: Some("💼".to_string()),
            tag_group: Some("focus".to_string()),
            scope: Some("time".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(10),
        })?;
        let health_tag = record_service.create_tag(&CreateTagInput {
            user_id: user_id.to_string(),
            name: "健康".to_string(),
            emoji: Some("🏃".to_string()),
            tag_group: Some("life".to_string()),
            scope: Some("global".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(20),
        })?;
        let ai_tag = record_service.create_tag(&CreateTagInput {
            user_id: user_id.to_string(),
            name: "AI".to_string(),
            emoji: Some("🤖".to_string()),
            tag_group: Some("tech".to_string()),
            scope: Some("global".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(30),
        })?;

        let product_project = project_service.create_project(&CreateProjectInput {
            user_id: user_id.to_string(),
            name: "SkyeOS".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-04-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(65),
            score: Some(8),
            note: Some("个人经营分析系统".to_string()),
            tag_ids: vec![work_tag.id.clone(), ai_tag.id.clone()],
        })?;
        let client_project = project_service.create_project(&CreateProjectInput {
            user_id: user_id.to_string(),
            name: "Client Work".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-03-10".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(35),
            score: Some(7),
            note: Some("自由职业收入来源".to_string()),
            tag_ids: vec![work_tag.id.clone()],
        })?;
        let learning_project = project_service.create_project(&CreateProjectInput {
            user_id: user_id.to_string(),
            name: "Long-term Learning".to_string(),
            status_code: "paused".to_string(),
            started_on: "2026-02-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(50),
            score: Some(6),
            note: Some("长期技能积累".to_string()),
            tag_ids: vec![health_tag.id.clone()],
        })?;

        let today = Local::now().date_naive();
        let yesterday = today - Duration::days(1);
        let this_month = today.format("%Y-%m").to_string();

        cost_service.upsert_monthly_baseline(
            user_id,
            &MonthlyCostBaselineInput {
                month: this_month.clone(),
                basic_living_cents: 680_000,
                fixed_subscription_cents: 120_000,
                note: Some("demo baseline".to_string()),
            },
        )?;
        cost_service.create_recurring_cost_rule(
            user_id,
            &RecurringCostRuleInput {
                name: "房租".to_string(),
                category_code: "necessary".to_string(),
                monthly_amount_cents: 420_000,
                is_necessary: true,
                start_month: this_month.clone(),
                end_month: None,
                note: Some("demo recurring".to_string()),
            },
        )?;
        cost_service.create_recurring_cost_rule(
            user_id,
            &RecurringCostRuleInput {
                name: "软件订阅".to_string(),
                category_code: "subscription".to_string(),
                monthly_amount_cents: 79_00,
                is_necessary: false,
                start_month: this_month.clone(),
                end_month: None,
                note: Some("demo recurring".to_string()),
            },
        )?;
        cost_service.create_capex_cost(
            user_id,
            &CapexCostInput {
                name: "MacBook".to_string(),
                purchase_date: format!("{today}"),
                purchase_amount_cents: 12_999_00,
                useful_months: 24,
                residual_rate_bps: 2000,
                note: Some("demo capex".to_string()),
            },
        )?;

        ai_service.create_service_config(&CreateAiServiceConfigInput {
            user_id: user_id.to_string(),
            provider: "deepseek".to_string(),
            base_url: Some("https://api.deepseek.com".to_string()),
            api_key_encrypted: Some("demo-key".to_string()),
            model: Some("deepseek-chat".to_string()),
            system_prompt: Some("demo".to_string()),
            parser_mode: Some(ParserMode::Auto),
            temperature_milli: Some(200),
            is_active: true,
        })?;
        backup_service.create_cloud_sync_config(&CreateCloudSyncConfigInput {
            user_id: user_id.to_string(),
            provider: "lifeos_http".to_string(),
            endpoint_url: "https://example.com".to_string(),
            bucket_name: Some("demo-bucket".to_string()),
            region: Some("cn-demo".to_string()),
            root_path: Some("/lifeos".to_string()),
            device_id: "android-demo".to_string(),
            api_key_encrypted: "demo-token".to_string(),
            is_active: true,
        })?;

        let product_alloc = vec![ProjectAllocation {
            project_id: product_project.id.clone(),
            weight_ratio: 1.0,
        }];
        let client_alloc = vec![ProjectAllocation {
            project_id: client_project.id.clone(),
            weight_ratio: 1.0,
        }];
        let learning_alloc = vec![ProjectAllocation {
            project_id: learning_project.id.clone(),
            weight_ratio: 1.0,
        }];

        record_service.create_time_record(&CreateTimeRecordInput {
            user_id: user_id.to_string(),
            started_at: format!("{today}T01:00:00Z"),
            ended_at: format!("{today}T03:30:00Z"),
            category_code: "work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(9),
            state_score: Some(8),
            ai_assist_ratio: Some(35),
            note: Some("推进 SkyeOS 首页与数据链路".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: product_alloc.clone(),
            tag_ids: vec![work_tag.id.clone(), ai_tag.id.clone()],
        })?;
        record_service.create_time_record(&CreateTimeRecordInput {
            user_id: user_id.to_string(),
            started_at: format!("{today}T05:00:00Z"),
            ended_at: format!("{today}T06:00:00Z"),
            category_code: "learning".to_string(),
            efficiency_score: Some(7),
            value_score: Some(7),
            state_score: Some(7),
            ai_assist_ratio: Some(50),
            note: Some("研究 Rust 与 Flutter FFI".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: learning_alloc.clone(),
            tag_ids: vec![ai_tag.id.clone()],
        })?;
        record_service.create_income_record(&CreateIncomeRecordInput {
            user_id: user_id.to_string(),
            occurred_on: today.to_string(),
            source_name: "Client A".to_string(),
            type_code: "project".to_string(),
            amount_cents: 128_000,
            is_passive: false,
            ai_assist_ratio: Some(20),
            note: Some("demo income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: client_alloc.clone(),
            tag_ids: vec![work_tag.id.clone()],
        })?;
        record_service.create_income_record(&CreateIncomeRecordInput {
            user_id: user_id.to_string(),
            occurred_on: today.to_string(),
            source_name: "Subscription".to_string(),
            type_code: "passive".to_string(),
            amount_cents: 26_000,
            is_passive: true,
            ai_assist_ratio: Some(0),
            note: Some("demo passive income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: Vec::new(),
            tag_ids: vec![ai_tag.id.clone()],
        })?;
        record_service.create_expense_record(&CreateExpenseRecordInput {
            user_id: user_id.to_string(),
            occurred_on: today.to_string(),
            category_code: "necessary".to_string(),
            amount_cents: 32_000,
            ai_assist_ratio: Some(0),
            note: Some("demo necessary expense".to_string()),
            source: Some("manual".to_string()),
            project_allocations: Vec::new(),
            tag_ids: vec![health_tag.id.clone()],
        })?;
        record_service.create_expense_record(&CreateExpenseRecordInput {
            user_id: user_id.to_string(),
            occurred_on: today.to_string(),
            category_code: "software".to_string(),
            amount_cents: 5_900,
            ai_assist_ratio: Some(0),
            note: Some("demo software expense".to_string()),
            source: Some("manual".to_string()),
            project_allocations: product_alloc.clone(),
            tag_ids: vec![ai_tag.id.clone()],
        })?;
        record_service.create_learning_record(&CreateLearningRecordInput {
            user_id: user_id.to_string(),
            occurred_on: today.to_string(),
            started_at: Some(format!("{today}T08:00:00Z")),
            ended_at: Some(format!("{today}T09:10:00Z")),
            content: "Read Flutter rendering docs".to_string(),
            duration_minutes: 70,
            application_level_code: "applied".to_string(),
            efficiency_score: Some(8),
            ai_assist_ratio: Some(40),
            note: Some("demo learning".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: learning_alloc.clone(),
            tag_ids: vec![ai_tag.id.clone()],
        })?;

        record_service.create_time_record(&CreateTimeRecordInput {
            user_id: user_id.to_string(),
            started_at: format!("{yesterday}T01:00:00Z"),
            ended_at: format!("{yesterday}T02:30:00Z"),
            category_code: "work".to_string(),
            efficiency_score: Some(6),
            value_score: Some(7),
            state_score: Some(6),
            ai_assist_ratio: Some(25),
            note: Some("yesterday work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: client_alloc.clone(),
            tag_ids: vec![work_tag.id.clone()],
        })?;
        record_service.create_income_record(&CreateIncomeRecordInput {
            user_id: user_id.to_string(),
            occurred_on: yesterday.to_string(),
            source_name: "Client B".to_string(),
            type_code: "project".to_string(),
            amount_cents: 88_000,
            is_passive: false,
            ai_assist_ratio: Some(10),
            note: Some("yesterday income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: client_alloc,
            tag_ids: vec![work_tag.id.clone()],
        })?;

        let backup = backup_service.create_backup(user_id, "manual")?;
        let _ = backup_service.restore_from_backup_record(user_id, &backup.id)?;

        snapshot_service.recompute_snapshot(
            user_id,
            &today.to_string(),
            crate::models::SnapshotWindow::Day,
        )?;
        snapshot_service.recompute_snapshot(
            user_id,
            &today.to_string(),
            crate::models::SnapshotWindow::Month,
        )?;

        Ok(DemoDataResult {
            user_id: user_id.to_string(),
            message: "demo data seeded".to_string(),
        })
    }

    fn write_setting(&self, user_id: &str, key: &str, value_json: &str) -> Result<()> {
        let connection = self.database.connect()?;
        connection.execute(
            "INSERT INTO settings(user_id, key, value_json, updated_at)
             VALUES (?1, ?2, ?3, CURRENT_TIMESTAMP)
             ON CONFLICT(user_id, key) DO UPDATE SET
               value_json = excluded.value_json,
               updated_at = excluded.updated_at",
            params![user_id, key, value_json],
        )?;
        Ok(())
    }
}
