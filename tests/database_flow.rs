use chrono::{Datelike, Local};
use life_os_core::{
    AiCaptureCommitInput, AiCommitInput, AiCommitOptions, AiDraftKind, AiParseDraft, AiParseInput,
    AiService, BackupService, BackupType, CapexCostInput, CostService, CreateAiServiceConfigInput,
    CreateCloudSyncConfigInput, CreateExpenseRecordInput, CreateIncomeRecordInput,
    CreateLearningRecordInput, CreateProjectInput, CreateTagInput, CreateTimeRecordInput, Database,
    DemoDataService, DimensionOptionInput, MonthlyCostBaselineInput, ProjectAllocation,
    ProjectService, RecordKind, RecordService, RecurringCostRuleInput, RemoteBackupFile,
    RemoteDownloadResult, RemoteUploadResult, ReviewNoteDraft, ReviewService, SnapshotService,
    SnapshotWindow, cloud::CloudSyncTransport,
};
use rusqlite::params;
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tempfile::tempdir;

#[test]
fn migrations_seed_dimensions_and_default_user() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let database = Database::new(&database_path);

    database.initialize().expect("initialize database");
    let connection = database.connect().expect("connect database");

    let count: i64 = connection
        .query_row("SELECT COUNT(*) FROM dim_time_categories", [], |row| {
            row.get(0)
        })
        .expect("count categories");
    assert!(count >= 6);

    let user_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM users", [], |row| row.get(0))
        .expect("count users");
    assert_eq!(user_count, 1);

    let extra_tables = [
        "user_sessions",
        "ai_service_configs",
        "cloud_sync_configs",
        "review_snapshots",
        "review_notes",
        "dimension_options",
        "metric_snapshot_projects",
    ];
    for table_name in extra_tables {
        let exists: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?1",
                [table_name],
                |row| row.get(0),
            )
            .expect("check table exists");
        assert_eq!(exists, 1, "missing table {table_name}");
    }
}

#[test]
fn ai_capture_commit_persists_records_and_review_notes() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), "2026-04-29".to_string());
    payload.insert("description".to_string(), "优化代码功能开发".to_string());
    payload.insert("category".to_string(), "work".to_string());
    payload.insert("start_time".to_string(), "17:00".to_string());
    payload.insert("end_time".to_string(), "21:00".to_string());
    payload.insert("ai_ratio".to_string(), "40".to_string());
    payload.insert("efficiency_score".to_string(), "8".to_string());
    let draft = AiParseDraft::new(AiDraftKind::Time, payload, 0.86, "test", None);
    let mut note = ReviewNoteDraft::new(
        "GPT 辅助确实很顺",
        "GPT 辅助感受",
        "ai_usage",
        "GPT 辅助确实很顺",
        "ai_capture",
        Some(0.8),
    );
    note.occurred_on = Some("2026-04-29".to_string());

    let result = AiService::new(&database_path)
        .commit_capture(&AiCaptureCommitInput {
            user_id: user.id.clone(),
            request_id: None,
            context_date: Some("2026-04-29".to_string()),
            drafts: vec![draft],
            review_notes: vec![note],
            options: AiCommitOptions::default(),
        })
        .expect("commit ai capture");

    assert_eq!(result.committed.len(), 1);
    assert_eq!(result.committed_notes.len(), 1);
    assert!(result.failures.is_empty());
    assert!(result.note_failures.is_empty());

    let report = ReviewService::new(&database_path)
        .get_daily_review(&user.id, "2026-04-29", "Asia/Shanghai")
        .expect("daily review");
    assert_eq!(report.total_work_minutes, 240);
    assert_eq!(report.review_notes.len(), 1);
    assert_eq!(report.review_notes[0].note_type, "ai_usage");
}

#[test]
fn seed_demo_data_succeeds() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let service = DemoDataService::new(&database_path);
    let result = service.seed_demo_data(&user.id).expect("seed demo data");

    assert_eq!(result.user_id, user.id);
}

#[test]
fn create_time_record_and_load_today_overview() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let service = RecordService::new(&database_path);
    let user = service.init_database().expect("init database");

    let input = CreateTimeRecordInput {
        user_id: user.id.clone(),
        started_at: "2026-04-25T01:00:00Z".to_string(),
        ended_at: "2026-04-25T03:30:00Z".to_string(),
        category_code: "work".to_string(),
        efficiency_score: Some(8),
        value_score: Some(9),
        state_score: Some(7),
        ai_assist_ratio: Some(45),
        note: Some("database refactor".to_string()),
        source: None,
        is_public_pool: false,
        project_allocations: Vec::<ProjectAllocation>::new(),
        tag_ids: Vec::new(),
    };

    let created = service
        .create_time_record(&input)
        .expect("create time record");
    assert_eq!(created.duration_minutes, 150);

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect database");
    connection
        .execute(
            "INSERT INTO income_records(
                id, user_id, occurred_on, source_name, type_code, amount_cents, is_passive,
                source, is_public_pool, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, '2026-04-25', 'Client A', 'project', 80000, 0, 'manual', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
            params!["income-1", user.id],
        )
        .expect("insert income");
    connection
        .execute(
            "INSERT INTO expense_records(
                id, user_id, occurred_on, category_code, amount_cents, source, is_deleted, created_at, updated_at
             ) VALUES (?1, ?2, '2026-04-25', 'necessary', 12000, 'manual', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
            params!["expense-1", user.id],
        )
        .expect("insert expense");
    connection
        .execute(
            "INSERT INTO learning_records(
                id, user_id, occurred_on, started_at, ended_at, content, duration_minutes, application_level_code,
                source, is_public_pool, is_deleted, created_at, updated_at
             ) VALUES (
                ?1, ?2, '2026-04-25', '2026-04-25T10:00:00Z', '2026-04-25T11:00:00Z',
                'Read Rust docs', 60, 'input', 'manual', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
             )",
            params!["learning-1", user.id],
        )
        .expect("insert learning");

    let overview = service
        .get_today_overview(&user.id, "2026-04-25", "Asia/Shanghai")
        .expect("get today overview");

    assert_eq!(overview.total_income_cents, 80_000);
    assert_eq!(overview.total_expense_cents, 12_000);
    assert_eq!(overview.net_income_cents, 68_000);
    assert_eq!(overview.total_time_minutes, 150);
    assert_eq!(overview.total_work_minutes, 150);
    assert_eq!(overview.total_learning_minutes, 60);
}

#[test]
fn create_full_domain_entities_and_links() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let service = RecordService::new(&database_path);
    let user = service.init_database().expect("init database");

    let root_tag = service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "Work".to_string(),
            emoji: Some("💼".to_string()),
            tag_group: Some("focus".to_string()),
            scope: Some("time".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(10),
        })
        .expect("create root tag");

    let project = service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "SkyeOS Rust Refactor".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-04-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(60),
            score: Some(8),
            note: Some("Core data migration".to_string()),
            tag_ids: vec![root_tag.id.clone()],
        })
        .expect("create project");

    let child_tag = service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "SQLite".to_string(),
            emoji: Some("🗄️".to_string()),
            tag_group: Some("tech".to_string()),
            scope: Some("global".to_string()),
            parent_tag_id: Some(root_tag.id.clone()),
            level: Some(2),
            status: Some("active".to_string()),
            sort_order: Some(20),
        })
        .expect("create child tag");

    let allocation = ProjectAllocation {
        project_id: project.id.clone(),
        weight_ratio: 1.0,
    };

    service
        .save_dimension_option(
            &user.id,
            "time_category",
            &DimensionOptionInput {
                code: "deep_work".to_string(),
                display_name: "Deep Work".to_string(),
                is_active: true,
            },
        )
        .expect("save time dimension");
    service
        .save_dimension_option(
            &user.id,
            "expense_category",
            &DimensionOptionInput {
                code: "software".to_string(),
                display_name: "Software".to_string(),
                is_active: true,
            },
        )
        .expect("save expense dimension");

    let time_record = service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-04-25T09:00:00Z".to_string(),
            ended_at: "2026-04-25T11:00:00Z".to_string(),
            category_code: "deep_work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(9),
            state_score: Some(8),
            ai_assist_ratio: Some(50),
            note: Some("Schema work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![child_tag.id.clone()],
        })
        .expect("create time record");
    assert_eq!(time_record.category_code, "deep_work");

    let income = service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-25".to_string(),
            source_name: "Freelance".to_string(),
            type_code: "project".to_string(),
            amount_cents: 150_000,
            is_passive: false,
            ai_assist_ratio: Some(20),
            note: Some("Milestone payment".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![root_tag.id.clone()],
        })
        .expect("create income");

    let expense = service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-25".to_string(),
            category_code: "software".to_string(),
            amount_cents: 9_999,
            ai_assist_ratio: Some(5),
            note: Some("DB browser subscription".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![child_tag.id.clone()],
        })
        .expect("create expense");

    let learning = service
        .create_learning_record(&CreateLearningRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-25".to_string(),
            started_at: Some("2026-04-25T12:00:00Z".to_string()),
            ended_at: Some("2026-04-25T13:00:00Z".to_string()),
            content: "Read rusqlite docs".to_string(),
            duration_minutes: 60,
            application_level_code: "applied".to_string(),
            efficiency_score: Some(7),
            ai_assist_ratio: Some(30),
            note: Some("Migration API study".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation],
            tag_ids: vec![child_tag.id.clone()],
        })
        .expect("create learning");

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect database");

    let custom_time_category_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM dim_time_categories WHERE code = 'deep_work'",
            [],
            |row| row.get(0),
        )
        .expect("count custom time category");
    assert_eq!(custom_time_category_count, 1);

    let custom_expense_category_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM dim_expense_categories WHERE code = 'software'",
            [],
            |row| row.get(0),
        )
        .expect("count custom expense category");
    assert_eq!(custom_expense_category_count, 1);

    let project_link_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM record_project_links", [], |row| {
            row.get(0)
        })
        .expect("count project links");
    assert_eq!(project_link_count, 4);

    let tag_link_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM record_tag_links", [], |row| {
            row.get(0)
        })
        .expect("count tag links");
    assert_eq!(tag_link_count, 5);

    let project_member_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM project_members", [], |row| row.get(0))
        .expect("count project members");
    assert_eq!(project_member_count, 1);

    let overview = service
        .get_today_overview(&user.id, "2026-04-25", "Asia/Shanghai")
        .expect("overview");
    assert_eq!(overview.total_income_cents, income.amount_cents);
    assert_eq!(overview.total_expense_cents, expense.amount_cents);
    assert_eq!(overview.total_learning_minutes, learning.duration_minutes);
}

#[test]
fn update_delete_and_query_record_system() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let service = RecordService::new(&database_path);
    let user = service.init_database().expect("init database");

    let tag = service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "Focus".to_string(),
            emoji: None,
            tag_group: Some("energy".to_string()),
            scope: Some("global".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(1),
        })
        .expect("create tag");

    let project = service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Record System".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-04-20".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(40),
            score: Some(7),
            note: Some("record module".to_string()),
            tag_ids: vec![tag.id.clone()],
        })
        .expect("create project");

    let allocation = ProjectAllocation {
        project_id: project.id.clone(),
        weight_ratio: 1.0,
    };

    let time_record = service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-04-26T01:00:00Z".to_string(),
            ended_at: "2026-04-26T02:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(6),
            value_score: Some(7),
            state_score: Some(6),
            ai_assist_ratio: Some(10),
            note: Some("initial".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag.id.clone()],
        })
        .expect("create time");

    let updated_time = service
        .update_time_record(
            &time_record.id,
            &CreateTimeRecordInput {
                user_id: user.id.clone(),
                started_at: "2026-04-26T03:00:00Z".to_string(),
                ended_at: "2026-04-26T05:30:00Z".to_string(),
                category_code: "work".to_string(),
                efficiency_score: Some(9),
                value_score: Some(8),
                state_score: Some(8),
                ai_assist_ratio: Some(55),
                note: Some("updated".to_string()),
                source: Some("manual".to_string()),
                is_public_pool: false,
                project_allocations: vec![allocation.clone()],
                tag_ids: vec![tag.id.clone()],
            },
        )
        .expect("update time");
    assert_eq!(updated_time.duration_minutes, 150);

    let time_snapshot = service
        .get_time_record_snapshot(&user.id, &time_record.id)
        .expect("time snapshot")
        .expect("time snapshot exists");
    assert_eq!(time_snapshot.note.as_deref(), Some("updated"));
    assert_eq!(time_snapshot.project_allocations.len(), 1);
    assert_eq!(time_snapshot.tag_ids, vec![tag.id.clone()]);

    let income = service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-26".to_string(),
            source_name: "Client B".to_string(),
            type_code: "project".to_string(),
            amount_cents: 50_000,
            is_passive: false,
            ai_assist_ratio: Some(15),
            note: Some("before".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag.id.clone()],
        })
        .expect("create income");

    service
        .update_income_record(
            &income.id,
            &CreateIncomeRecordInput {
                user_id: user.id.clone(),
                occurred_on: "2026-04-26".to_string(),
                source_name: "Client B+".to_string(),
                type_code: "project".to_string(),
                amount_cents: 75_000,
                is_passive: true,
                ai_assist_ratio: Some(25),
                note: Some("after".to_string()),
                source: Some("manual".to_string()),
                is_public_pool: false,
                project_allocations: vec![allocation.clone()],
                tag_ids: vec![tag.id.clone()],
            },
        )
        .expect("update income");
    let income_snapshot = service
        .get_income_record_snapshot(&user.id, &income.id)
        .expect("income snapshot")
        .expect("income snapshot exists");
    assert_eq!(income_snapshot.amount_cents, 75_000);
    assert!(income_snapshot.is_passive);

    let expense = service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-26".to_string(),
            category_code: "necessary".to_string(),
            amount_cents: 2_000,
            ai_assist_ratio: Some(0),
            note: Some("coffee".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag.id.clone()],
        })
        .expect("create expense");

    service
        .update_expense_record(
            &expense.id,
            &CreateExpenseRecordInput {
                user_id: user.id.clone(),
                occurred_on: "2026-04-26".to_string(),
                category_code: "subscription".to_string(),
                amount_cents: 8_000,
                ai_assist_ratio: Some(3),
                note: Some("tool".to_string()),
                source: Some("manual".to_string()),
                project_allocations: vec![allocation.clone()],
                tag_ids: vec![tag.id.clone()],
            },
        )
        .expect("update expense");
    let expense_snapshot = service
        .get_expense_record_snapshot(&user.id, &expense.id)
        .expect("expense snapshot")
        .expect("expense snapshot exists");
    assert_eq!(expense_snapshot.category_code, "subscription");
    assert_eq!(expense_snapshot.amount_cents, 8_000);

    let learning = service
        .create_learning_record(&CreateLearningRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-26".to_string(),
            started_at: Some("2026-04-26T06:00:00Z".to_string()),
            ended_at: Some("2026-04-26T07:00:00Z".to_string()),
            content: "Before update".to_string(),
            duration_minutes: 60,
            application_level_code: "input".to_string(),
            efficiency_score: Some(6),
            ai_assist_ratio: Some(20),
            note: Some("draft".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag.id.clone()],
        })
        .expect("create learning");

    service
        .update_learning_record(
            &learning.id,
            &CreateLearningRecordInput {
                user_id: user.id.clone(),
                occurred_on: "2026-04-26".to_string(),
                started_at: Some("2026-04-26T06:00:00Z".to_string()),
                ended_at: Some("2026-04-26T07:30:00Z".to_string()),
                content: "After update".to_string(),
                duration_minutes: 90,
                application_level_code: "applied".to_string(),
                efficiency_score: Some(8),
                ai_assist_ratio: Some(35),
                note: Some("final".to_string()),
                source: Some("manual".to_string()),
                is_public_pool: false,
                project_allocations: vec![allocation.clone()],
                tag_ids: vec![tag.id.clone()],
            },
        )
        .expect("update learning");
    let learning_snapshot = service
        .get_learning_record_snapshot(&user.id, &learning.id)
        .expect("learning snapshot")
        .expect("learning snapshot exists");
    assert_eq!(learning_snapshot.duration_minutes, 90);
    assert_eq!(learning_snapshot.application_level_code, "applied");

    let recent_records = service
        .get_recent_records(&user.id, "Asia/Shanghai", 20)
        .expect("recent records");
    assert_eq!(recent_records.len(), 4);

    let records_for_date = service
        .get_records_for_date(&user.id, "2026-04-26", "Asia/Shanghai", 20)
        .expect("records for date");
    assert_eq!(records_for_date.len(), 4);

    service
        .delete_record(RecordKind::Expense, &user.id, &expense.id)
        .expect("delete expense");
    let deleted_expense_snapshot = service
        .get_expense_record_snapshot(&user.id, &expense.id)
        .expect("deleted expense snapshot");
    assert!(deleted_expense_snapshot.is_none());

    let recent_after_delete = service
        .get_recent_records(&user.id, "Asia/Shanghai", 20)
        .expect("recent after delete");
    assert_eq!(recent_after_delete.len(), 3);
}

#[test]
fn project_system_list_detail_update_and_delete() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let project_service = ProjectService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let tag_active = record_service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "Main".to_string(),
            emoji: None,
            tag_group: Some("project".to_string()),
            scope: Some("project".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(1),
        })
        .expect("create active tag");

    let tag_secondary = record_service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "Secondary".to_string(),
            emoji: None,
            tag_group: Some("project".to_string()),
            scope: Some("project".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(2),
        })
        .expect("create secondary tag");

    let active_project = project_service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Core Upgrade".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-05-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(30),
            score: Some(7),
            note: Some("phase 1".to_string()),
            tag_ids: vec![tag_active.id.clone()],
        })
        .expect("create active project");

    let done_project = project_service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Done Upgrade".to_string(),
            status_code: "done".to_string(),
            started_on: "2026-04-01".to_string(),
            ended_on: Some("2026-04-30".to_string()),
            ai_enable_ratio: Some(10),
            score: Some(6),
            note: Some("done".to_string()),
            tag_ids: vec![tag_secondary.id.clone()],
        })
        .expect("create done project");

    let allocation = ProjectAllocation {
        project_id: active_project.id.clone(),
        weight_ratio: 1.0,
    };
    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-05-02T01:00:00Z".to_string(),
            ended_at: "2026-05-02T03:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(8),
            state_score: Some(7),
            ai_assist_ratio: Some(20),
            note: Some("project work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag_active.id.clone()],
        })
        .expect("create project time record");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-05-02".to_string(),
            source_name: "Client".to_string(),
            type_code: "project".to_string(),
            amount_cents: 120_000,
            is_passive: false,
            ai_assist_ratio: Some(0),
            note: Some("invoice".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag_active.id.clone()],
        })
        .expect("create project income");
    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-05-02".to_string(),
            category_code: "subscription".to_string(),
            amount_cents: 15_000,
            ai_assist_ratio: Some(0),
            note: Some("software".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![tag_active.id.clone()],
        })
        .expect("create project expense");
    record_service
        .create_learning_record(&CreateLearningRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-05-02".to_string(),
            started_at: Some("2026-05-02T04:00:00Z".to_string()),
            ended_at: Some("2026-05-02T05:00:00Z".to_string()),
            content: "Domain study".to_string(),
            duration_minutes: 60,
            application_level_code: "applied".to_string(),
            efficiency_score: Some(7),
            ai_assist_ratio: Some(25),
            note: Some("study".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation],
            tag_ids: vec![tag_active.id.clone()],
        })
        .expect("create project learning");

    let options_without_done = project_service
        .get_project_options(&user.id, false)
        .expect("project options without done");
    assert_eq!(options_without_done.len(), 1);
    assert_eq!(options_without_done[0].id, active_project.id);

    let options_with_done = project_service
        .get_project_options(&user.id, true)
        .expect("project options with done");
    assert_eq!(options_with_done.len(), 2);

    let overview_all = project_service
        .list_projects(&user.id, None)
        .expect("list projects");
    assert_eq!(overview_all.len(), 2);
    let active_overview = overview_all
        .iter()
        .find(|item| item.id == active_project.id)
        .expect("active project overview");
    assert_eq!(active_overview.total_time_minutes, 120);
    assert_eq!(active_overview.total_income_cents, 120_000);
    assert_eq!(active_overview.total_expense_cents, 15_000);

    let detail = project_service
        .get_project_detail(&user.id, &active_project.id, "Asia/Shanghai", 20)
        .expect("project detail")
        .expect("project detail exists");
    assert_eq!(detail.total_time_minutes, 120);
    assert_eq!(detail.total_income_cents, 120_000);
    assert_eq!(detail.total_expense_cents, 15_000);
    assert_eq!(detail.direct_expense_cents, 15_000);
    assert_eq!(detail.total_learning_minutes, 60);
    assert_eq!(detail.time_record_count, 1);
    assert_eq!(detail.income_record_count, 1);
    assert_eq!(detail.expense_record_count, 1);
    assert_eq!(detail.learning_record_count, 1);
    assert_eq!(detail.tag_ids, vec![tag_active.id.clone()]);
    assert_eq!(detail.recent_records.len(), 4);
    assert_eq!(detail.analysis_start_date, "2026-05-01");
    assert!(detail.analysis_end_date >= "2026-05-02".to_string());
    assert!(detail.benchmark_hourly_rate_cents >= 0);
    assert!(detail.time_cost_cents >= 0);
    assert!(detail.allocated_structural_cost_cents >= 0);
    assert_eq!(
        detail.operating_cost_cents,
        detail.direct_expense_cents + detail.time_cost_cents
    );
    assert_eq!(
        detail.fully_loaded_cost_cents,
        detail.operating_cost_cents + detail.allocated_structural_cost_cents
    );
    assert_eq!(detail.total_cost_cents, detail.fully_loaded_cost_cents);
    assert_eq!(detail.profit_cents, detail.fully_loaded_profit_cents);
    assert_eq!(
        detail.break_even_income_cents,
        detail.fully_loaded_break_even_income_cents
    );
    assert_eq!(
        detail.operating_profit_cents,
        detail.total_income_cents - detail.operating_cost_cents
    );
    assert_eq!(
        detail.fully_loaded_profit_cents,
        detail.total_income_cents - detail.fully_loaded_cost_cents
    );
    assert!(detail.roi_perc >= detail.fully_loaded_roi_perc - f64::EPSILON);
    assert!(matches!(
        detail.evaluation_status.as_str(),
        "positive" | "neutral" | "warning"
    ));

    let updated_project = project_service
        .update_project_record(
            &active_project.id,
            &CreateProjectInput {
                user_id: user.id.clone(),
                name: "Core Upgrade Updated".to_string(),
                status_code: "paused".to_string(),
                started_on: "2026-05-01".to_string(),
                ended_on: None,
                ai_enable_ratio: Some(45),
                score: Some(9),
                note: Some("phase 2".to_string()),
                tag_ids: vec![tag_secondary.id.clone()],
            },
        )
        .expect("update project record");
    assert_eq!(updated_project.name, "Core Upgrade Updated");
    assert_eq!(updated_project.status_code, "paused");

    let state_updated = project_service
        .update_project_state(
            &active_project.id,
            &user.id,
            "done",
            Some(10),
            Some("finished".to_string()),
            Some("2026-05-31".to_string()),
        )
        .expect("update project state");
    assert_eq!(state_updated.status_code, "done");
    assert_eq!(state_updated.ended_on.as_deref(), Some("2026-05-31"));

    let updated_detail = project_service
        .get_project_detail(&user.id, &active_project.id, "Asia/Shanghai", 20)
        .expect("updated detail")
        .expect("updated detail exists");
    assert_eq!(updated_detail.name, "Core Upgrade Updated");
    assert_eq!(updated_detail.status_code, "done");
    assert_eq!(updated_detail.tag_ids, vec![tag_secondary.id.clone()]);
    assert!(updated_detail.fully_loaded_cost_cents >= updated_detail.operating_cost_cents);

    project_service
        .delete_project(&user.id, &done_project.id)
        .expect("delete project");
    let final_list = project_service
        .list_projects(&user.id, None)
        .expect("final project list");
    assert_eq!(final_list.len(), 1);
    assert_eq!(final_list[0].id, active_project.id);
}

#[test]
fn cost_system_crud_and_rate_comparison() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let cost_service = CostService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    cost_service
        .set_ideal_hourly_rate_cents(&user.id, 12_000)
        .expect("set ideal rate");
    let ideal_rate = cost_service
        .get_ideal_hourly_rate_cents(&user.id)
        .expect("get ideal rate");
    assert_eq!(ideal_rate, 12_000);

    let current_month = {
        let now = Local::now().date_naive();
        format!("{:04}-{:02}", now.year(), now.month())
    };
    let current_month_basic_before = cost_service
        .get_current_month_basic_living_cents(&user.id)
        .expect("get current basic");
    assert_eq!(current_month_basic_before, 0);

    let baseline = cost_service
        .upsert_monthly_baseline(
            &user.id,
            &MonthlyCostBaselineInput {
                month: current_month.clone(),
                basic_living_cents: 200_000,
                fixed_subscription_cents: 30_000,
                note: Some("baseline".to_string()),
            },
        )
        .expect("upsert baseline");
    assert_eq!(baseline.basic_living_cents, 200_000);
    assert_eq!(baseline.fixed_subscription_cents, 30_000);

    let current_month_basic = cost_service
        .get_current_month_basic_living_cents(&user.id)
        .expect("get current basic after set");
    assert_eq!(current_month_basic, 200_000);
    let current_month_fixed = cost_service
        .get_current_month_fixed_subscription_cents(&user.id)
        .expect("get current fixed after set");
    assert_eq!(current_month_fixed, 30_000);

    let updated_current_basic = cost_service
        .set_current_month_basic_living_cents(&user.id, 220_000)
        .expect("set current basic");
    assert_eq!(updated_current_basic.basic_living_cents, 220_000);
    let updated_current_fixed = cost_service
        .set_current_month_fixed_subscription_cents(&user.id, 35_000)
        .expect("set current fixed");
    assert_eq!(updated_current_fixed.fixed_subscription_cents, 35_000);

    let recurring = cost_service
        .create_recurring_cost_rule(
            &user.id,
            &RecurringCostRuleInput {
                name: "Server".to_string(),
                category_code: "subscription".to_string(),
                monthly_amount_cents: 9_900,
                is_necessary: true,
                start_month: current_month.clone(),
                end_month: None,
                note: Some("infra".to_string()),
            },
        )
        .expect("create recurring rule");
    assert_eq!(recurring.monthly_amount_cents, 9_900);

    let recurring_list = cost_service
        .list_recurring_cost_rules(&user.id)
        .expect("list recurring rules");
    assert_eq!(recurring_list.len(), 1);

    let updated_recurring = cost_service
        .update_recurring_cost_rule(
            &user.id,
            &recurring.id,
            &RecurringCostRuleInput {
                name: "Server Plus".to_string(),
                category_code: "subscription".to_string(),
                monthly_amount_cents: 12_000,
                is_necessary: true,
                start_month: current_month.clone(),
                end_month: None,
                note: Some("infra+".to_string()),
            },
        )
        .expect("update recurring rule");
    assert_eq!(updated_recurring.name, "Server Plus");
    assert_eq!(updated_recurring.monthly_amount_cents, 12_000);

    let capex = cost_service
        .create_capex_cost(
            &user.id,
            &CapexCostInput {
                name: "Laptop".to_string(),
                purchase_date: "2026-04-01".to_string(),
                purchase_amount_cents: 120_000,
                useful_months: 12,
                residual_rate_bps: 1000,
                note: Some("device".to_string()),
            },
        )
        .expect("create capex");
    assert_eq!(capex.monthly_amortized_cents, 9_000);

    let capex_list = cost_service.list_capex_costs(&user.id).expect("list capex");
    assert_eq!(capex_list.len(), 1);

    let updated_capex = cost_service
        .update_capex_cost(
            &user.id,
            &capex.id,
            &CapexCostInput {
                name: "Laptop Pro".to_string(),
                purchase_date: "2026-04-01".to_string(),
                purchase_amount_cents: 120_000,
                useful_months: 10,
                residual_rate_bps: 500,
                note: Some("device+".to_string()),
            },
        )
        .expect("update capex");
    assert_eq!(updated_capex.name, "Laptop Pro");
    assert_eq!(updated_capex.monthly_amortized_cents, 11_400);

    let anchor_date = "2026-06-15";
    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-06-10T01:00:00Z".to_string(),
            ended_at: "2026-06-10T03:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(8),
            state_score: Some(8),
            ai_assist_ratio: Some(10),
            note: Some("current year work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create current year work");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-10".to_string(),
            source_name: "June Client".to_string(),
            type_code: "project".to_string(),
            amount_cents: 30_000,
            is_passive: false,
            ai_assist_ratio: Some(0),
            note: Some("june income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create current income");
    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2025-03-10T01:00:00Z".to_string(),
            ended_at: "2025-03-10T11:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(7),
            value_score: Some(7),
            state_score: Some(7),
            ai_assist_ratio: Some(10),
            note: Some("previous year work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create previous year work");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2025-03-10".to_string(),
            source_name: "Past Client".to_string(),
            type_code: "project".to_string(),
            amount_cents: 120_000,
            is_passive: false,
            ai_assist_ratio: Some(0),
            note: Some("past income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create previous income");

    let comparison = cost_service
        .get_rate_comparison(&user.id, anchor_date, "month")
        .expect("rate comparison");
    assert_eq!(comparison.ideal_hourly_rate_cents, 12_000);
    assert_eq!(comparison.current_income_cents, 30_000);
    assert_eq!(comparison.current_work_minutes, 120);
    assert_eq!(comparison.actual_hourly_rate_cents, Some(15_000));
    assert_eq!(comparison.previous_year_income_cents, 120_000);
    assert_eq!(comparison.previous_year_work_minutes, 600);
    assert_eq!(
        comparison.previous_year_average_hourly_rate_cents,
        Some(12_000)
    );

    cost_service
        .delete_recurring_cost_rule(&user.id, &recurring.id)
        .expect("delete recurring rule");
    cost_service
        .delete_capex_cost(&user.id, &capex.id)
        .expect("delete capex");
    assert_eq!(
        cost_service
            .list_recurring_cost_rules(&user.id)
            .expect("list recurring after delete")
            .len(),
        0
    );
    assert_eq!(
        cost_service
            .list_capex_costs(&user.id)
            .expect("list capex after delete")
            .len(),
        0
    );
}

#[test]
fn review_system_report_and_tag_detail() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let project_service = ProjectService::new(&database_path);
    let cost_service = CostService::new(&database_path);
    let review_service = ReviewService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    cost_service
        .set_ideal_hourly_rate_cents(&user.id, 10_000)
        .expect("set ideal hourly rate");
    cost_service
        .upsert_monthly_baseline(
            &user.id,
            &MonthlyCostBaselineInput {
                month: "2026-06".to_string(),
                basic_living_cents: 300_000,
                fixed_subscription_cents: 20_000,
                note: Some("june baseline".to_string()),
            },
        )
        .expect("upsert june baseline");
    cost_service
        .create_recurring_cost_rule(
            &user.id,
            &RecurringCostRuleInput {
                name: "Internet".to_string(),
                category_code: "subscription".to_string(),
                monthly_amount_cents: 10_000,
                is_necessary: true,
                start_month: "2026-06".to_string(),
                end_month: None,
                note: Some("net".to_string()),
            },
        )
        .expect("create recurring");

    let project_tag = record_service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "ProjectTag".to_string(),
            emoji: Some("🚀".to_string()),
            tag_group: Some("project".to_string()),
            scope: Some("project".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(1),
        })
        .expect("create project tag");
    let time_tag = record_service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "FocusTime".to_string(),
            emoji: Some("⏱️".to_string()),
            tag_group: Some("time".to_string()),
            scope: Some("time".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(2),
        })
        .expect("create time tag");
    let expense_tag = record_service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "InfraExpense".to_string(),
            emoji: Some("💸".to_string()),
            tag_group: Some("expense".to_string()),
            scope: Some("expense".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(3),
        })
        .expect("create expense tag");

    let project = project_service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Review Project".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-06-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(20),
            score: Some(8),
            note: Some("review scope".to_string()),
            tag_ids: vec![project_tag.id.clone()],
        })
        .expect("create project");
    let allocation = ProjectAllocation {
        project_id: project.id.clone(),
        weight_ratio: 1.0,
    };

    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-06-14T02:00:00Z".to_string(),
            ended_at: "2026-06-14T04:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(9),
            state_score: Some(8),
            ai_assist_ratio: Some(50),
            note: Some("feature work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![time_tag.id.clone()],
        })
        .expect("create current time");
    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-06-14T05:00:00Z".to_string(),
            ended_at: "2026-06-14T06:00:00Z".to_string(),
            category_code: "life".to_string(),
            efficiency_score: None,
            value_score: None,
            state_score: None,
            ai_assist_ratio: Some(0),
            note: Some("life note".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: true,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create life time");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-14".to_string(),
            source_name: "Client June".to_string(),
            type_code: "project".to_string(),
            amount_cents: 50_000,
            is_passive: false,
            ai_assist_ratio: Some(0),
            note: Some("current income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![],
        })
        .expect("create current income");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-14".to_string(),
            source_name: "Passive June".to_string(),
            type_code: "investment".to_string(),
            amount_cents: 5_000,
            is_passive: true,
            ai_assist_ratio: Some(0),
            note: Some("passive".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create passive income");
    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-14".to_string(),
            category_code: "necessary".to_string(),
            amount_cents: 3_000,
            ai_assist_ratio: Some(0),
            note: Some("lunch".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![],
            tag_ids: vec![expense_tag.id.clone()],
        })
        .expect("create necessary expense");
    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-14".to_string(),
            category_code: "subscription".to_string(),
            amount_cents: 9_000,
            ai_assist_ratio: Some(0),
            note: Some("tooling".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![allocation.clone()],
            tag_ids: vec![expense_tag.id.clone()],
        })
        .expect("create subscription expense");
    record_service
        .create_learning_record(&CreateLearningRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-14".to_string(),
            started_at: Some("2026-06-14T06:00:00Z".to_string()),
            ended_at: Some("2026-06-14T07:00:00Z".to_string()),
            content: "Read docs".to_string(),
            duration_minutes: 60,
            application_level_code: "applied".to_string(),
            efficiency_score: Some(7),
            ai_assist_ratio: Some(30),
            note: Some("learning".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![allocation],
            tag_ids: vec![],
        })
        .expect("create learning");

    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-06-13T02:00:00Z".to_string(),
            ended_at: "2026-06-13T03:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(5),
            value_score: Some(5),
            state_score: Some(5),
            ai_assist_ratio: Some(0),
            note: Some("previous work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![time_tag.id.clone()],
        })
        .expect("create previous day work");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-13".to_string(),
            source_name: "Previous Client".to_string(),
            type_code: "project".to_string(),
            amount_cents: 20_000,
            is_passive: false,
            ai_assist_ratio: Some(0),
            note: Some("previous income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create previous income");
    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-06-13".to_string(),
            category_code: "necessary".to_string(),
            amount_cents: 1_000,
            ai_assist_ratio: Some(0),
            note: Some("previous expense".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![],
            tag_ids: vec![expense_tag.id.clone()],
        })
        .expect("create previous expense");

    let daily_review = review_service
        .get_daily_review(&user.id, "2026-06-14", "Asia/Shanghai")
        .expect("daily review");
    assert_eq!(
        daily_review.window.kind,
        life_os_core::ReviewWindowKind::Day
    );
    assert_eq!(daily_review.total_time_minutes, 180);
    assert_eq!(daily_review.total_work_minutes, 120);
    assert_eq!(daily_review.total_income_cents, 55_000);
    assert_eq!(daily_review.previous_income_cents, 20_000);
    assert_eq!(daily_review.previous_work_minutes, 60);
    assert!(daily_review.total_expense_cents > 12_000);
    assert_eq!(daily_review.actual_hourly_rate_cents, Some(27_500));
    assert_eq!(daily_review.ideal_hourly_rate_cents, 10_000);
    assert_eq!(daily_review.time_debt_cents, Some(-17_500));
    assert!(daily_review.passive_cover_ratio.is_some());
    assert!(daily_review.ai_assist_rate.is_some());
    assert_eq!(daily_review.time_allocations.len(), 2);
    assert_eq!(daily_review.top_projects.len(), 1);
    assert_eq!(daily_review.sinkhole_projects.len(), 0);
    assert!(!daily_review.key_events.is_empty());
    assert_eq!(daily_review.income_history.len(), 2);
    assert_eq!(daily_review.history_records.len(), 7);
    assert_eq!(daily_review.time_tag_metrics.len(), 1);
    assert_eq!(daily_review.expense_tag_metrics.len(), 1);

    let weekly_review = review_service
        .get_weekly_review(&user.id, "2026-06-14", "Asia/Shanghai")
        .expect("weekly review");
    assert!(weekly_review.total_income_cents >= daily_review.total_income_cents);
    assert!(weekly_review.history_records.len() >= daily_review.history_records.len());

    let range_review = review_service
        .get_range_review(&user.id, "2026-06-13", "2026-06-14", "Asia/Shanghai")
        .expect("range review");
    assert_eq!(range_review.total_income_cents, 75_000);
    assert_eq!(range_review.total_work_minutes, 180);

    let time_tag_details = review_service
        .get_tag_detail_records(
            &user.id,
            "time",
            "FocusTime",
            "2026-06-13",
            "2026-06-14",
            "Asia/Shanghai",
            20,
        )
        .expect("time tag details");
    assert_eq!(time_tag_details.len(), 2);
    assert!(
        time_tag_details
            .iter()
            .all(|item| item.kind == RecordKind::Time)
    );

    let expense_tag_details = review_service
        .get_tag_detail_records(
            &user.id,
            "expense",
            "InfraExpense",
            "2026-06-13",
            "2026-06-14",
            "Asia/Shanghai",
            20,
        )
        .expect("expense tag details");
    assert_eq!(expense_tag_details.len(), 3);
    assert!(
        expense_tag_details
            .iter()
            .all(|item| item.kind == RecordKind::Expense)
    );
}

#[test]
fn snapshot_system_recompute_and_project_details() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let project_service = ProjectService::new(&database_path);
    let cost_service = CostService::new(&database_path);
    let snapshot_service = SnapshotService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    cost_service
        .set_ideal_hourly_rate_cents(&user.id, 12_000)
        .expect("set ideal rate");
    cost_service
        .upsert_monthly_baseline(
            &user.id,
            &MonthlyCostBaselineInput {
                month: "2026-07".to_string(),
                basic_living_cents: 240_000,
                fixed_subscription_cents: 10_000,
                note: Some("july baseline".to_string()),
            },
        )
        .expect("upsert baseline");
    cost_service
        .create_recurring_cost_rule(
            &user.id,
            &RecurringCostRuleInput {
                name: "Hosting".to_string(),
                category_code: "subscription".to_string(),
                monthly_amount_cents: 12_000,
                is_necessary: true,
                start_month: "2026-07".to_string(),
                end_month: None,
                note: Some("infra".to_string()),
            },
        )
        .expect("create recurring rule");

    let project_a = project_service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Snapshot A".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-07-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(30),
            score: Some(8),
            note: Some("snapshot project a".to_string()),
            tag_ids: vec![],
        })
        .expect("create project a");
    let project_b = project_service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Snapshot B".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-07-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(20),
            score: Some(6),
            note: Some("snapshot project b".to_string()),
            tag_ids: vec![],
        })
        .expect("create project b");

    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-07-15T01:00:00Z".to_string(),
            ended_at: "2026-07-15T03:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(8),
            state_score: Some(8),
            ai_assist_ratio: Some(10),
            note: Some("project a work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![ProjectAllocation {
                project_id: project_a.id.clone(),
                weight_ratio: 1.0,
            }],
            tag_ids: vec![],
        })
        .expect("create project a time");
    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-07-16T01:00:00Z".to_string(),
            ended_at: "2026-07-16T02:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(7),
            value_score: Some(7),
            state_score: Some(7),
            ai_assist_ratio: Some(0),
            note: Some("project b work".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![ProjectAllocation {
                project_id: project_b.id.clone(),
                weight_ratio: 1.0,
            }],
            tag_ids: vec![],
        })
        .expect("create project b time");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-07-15".to_string(),
            source_name: "July Client".to_string(),
            type_code: "project".to_string(),
            amount_cents: 60_000,
            is_passive: false,
            ai_assist_ratio: Some(0),
            note: Some("project a income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![ProjectAllocation {
                project_id: project_a.id.clone(),
                weight_ratio: 1.0,
            }],
            tag_ids: vec![],
        })
        .expect("create project a income");
    record_service
        .create_income_record(&CreateIncomeRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-07-20".to_string(),
            source_name: "Passive July".to_string(),
            type_code: "investment".to_string(),
            amount_cents: 8_000,
            is_passive: true,
            ai_assist_ratio: Some(0),
            note: Some("passive income".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create passive income");
    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-07-16".to_string(),
            category_code: "necessary".to_string(),
            amount_cents: 4_000,
            ai_assist_ratio: Some(0),
            note: Some("lunch".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![],
            tag_ids: vec![],
        })
        .expect("create necessary expense");
    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-07-15".to_string(),
            category_code: "subscription".to_string(),
            amount_cents: 10_000,
            ai_assist_ratio: Some(0),
            note: Some("project a tooling".to_string()),
            source: Some("manual".to_string()),
            project_allocations: vec![ProjectAllocation {
                project_id: project_a.id.clone(),
                weight_ratio: 1.0,
            }],
            tag_ids: vec![],
        })
        .expect("create project a expense");

    let snapshot = snapshot_service
        .recompute_snapshot(&user.id, "2026-07-20", SnapshotWindow::Month)
        .expect("recompute snapshot");
    assert_eq!(snapshot.snapshot_date, "2026-07-20");
    assert_eq!(snapshot.window_type, "month");
    assert_eq!(snapshot.total_income_cents, Some(68_000));
    assert!(snapshot.total_expense_cents.expect("total expense") > 14_000);
    assert_eq!(snapshot.total_work_minutes, Some(180));
    assert_eq!(snapshot.hourly_rate_cents, Some(22_666));
    assert_eq!(snapshot.time_debt_cents, Some(-10_666));
    assert!(snapshot.passive_cover_ratio.is_some());
    assert!(snapshot.freedom_cents.is_some());

    let fetched = snapshot_service
        .get_snapshot(&user.id, "2026-07-20", SnapshotWindow::Month)
        .expect("get snapshot")
        .expect("snapshot exists");
    assert_eq!(fetched.id, snapshot.id);

    let latest = snapshot_service
        .get_latest_snapshot(&user.id, SnapshotWindow::Month)
        .expect("latest snapshot")
        .expect("latest snapshot exists");
    assert_eq!(latest.id, snapshot.id);

    let project_snapshots = snapshot_service
        .list_project_snapshots(&user.id, &snapshot.id)
        .expect("list project snapshots");
    assert_eq!(project_snapshots.len(), 2);

    let project_a_snapshot = project_snapshots
        .iter()
        .find(|item| item.project_id == project_a.id)
        .expect("project a snapshot");
    assert_eq!(project_a_snapshot.income_cents, 60_000);
    assert_eq!(project_a_snapshot.direct_expense_cents, 10_000);
    assert_eq!(project_a_snapshot.invested_minutes, 120);
    assert_eq!(
        project_a_snapshot.total_cost_cents,
        project_a_snapshot.operating_cost_cents + project_a_snapshot.structural_cost_cents
    );
    assert_eq!(
        project_a_snapshot.profit_cents,
        project_a_snapshot.income_cents - project_a_snapshot.total_cost_cents
    );
    assert_eq!(
        project_a_snapshot.break_even_cents,
        project_a_snapshot.total_cost_cents
    );

    let project_b_snapshot = project_snapshots
        .iter()
        .find(|item| item.project_id == project_b.id)
        .expect("project b snapshot");
    assert_eq!(project_b_snapshot.income_cents, 0);
    assert_eq!(project_b_snapshot.direct_expense_cents, 0);
    assert_eq!(project_b_snapshot.invested_minutes, 60);
    assert!(project_b_snapshot.total_cost_cents >= project_b_snapshot.structural_cost_cents);
}

#[test]
fn ai_service_rule_parse_config_and_commit_flow() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os_ai.db");
    let record_service = RecordService::new(&database_path);
    let ai_service = AiService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let tag = record_service
        .create_tag(&CreateTagInput {
            user_id: user.id.clone(),
            name: "Rust".to_string(),
            emoji: None,
            tag_group: Some("tech".to_string()),
            scope: Some("global".to_string()),
            parent_tag_id: None,
            level: Some(1),
            status: Some("active".to_string()),
            sort_order: Some(10),
        })
        .expect("create tag");
    let project = record_service
        .create_project(&CreateProjectInput {
            user_id: user.id.clone(),
            name: "Core Upgrade".to_string(),
            status_code: "active".to_string(),
            started_on: "2026-04-01".to_string(),
            ended_on: None,
            ai_enable_ratio: Some(50),
            score: Some(8),
            note: Some("Rust core".to_string()),
            tag_ids: vec![tag.id.clone()],
        })
        .expect("create project");

    let inactive = ai_service
        .create_service_config(&CreateAiServiceConfigInput {
            user_id: user.id.clone(),
            provider: "custom".to_string(),
            base_url: Some("https://example.invalid".to_string()),
            api_key_encrypted: Some("key-1".to_string()),
            model: Some("gpt-4o-mini".to_string()),
            system_prompt: Some("draft only".to_string()),
            parser_mode: Some(life_os_core::ParserMode::Rule),
            temperature_milli: Some(200),
            is_active: false,
        })
        .expect("create inactive config");
    let active = ai_service
        .create_service_config(&CreateAiServiceConfigInput {
            user_id: user.id.clone(),
            provider: "deepseek".to_string(),
            base_url: None,
            api_key_encrypted: Some("key-2".to_string()),
            model: None,
            system_prompt: Some("structured parse".to_string()),
            parser_mode: Some(life_os_core::ParserMode::Auto),
            temperature_milli: Some(0),
            is_active: true,
        })
        .expect("create active config");

    let configs = ai_service
        .list_service_configs(&user.id)
        .expect("list configs");
    assert_eq!(configs.len(), 2);
    assert_eq!(configs[0].id, active.id);
    assert!(
        !configs
            .iter()
            .any(|config| config.id == inactive.id && config.is_active)
    );
    assert_eq!(
        ai_service
            .get_active_service_config(&user.id)
            .expect("active config")
            .expect("existing active")
            .id,
        active.id
    );

    let parse_result = ai_service
        .parse_input(&AiParseInput {
            user_id: user.id.clone(),
            raw_text: "2026-04-25 09:00-11:00 Core Upgrade Rust 工作 AI 30 效率 8 价值 9 状态 7\n今天收入 Core Upgrade 回款 1200元 AI 10 Rust\n晚上学习 Rust FFI 1.5小时 AI 40 效率 8".to_string(),
            context_date: Some("2026-04-25".to_string()),
            parser_mode_override: Some(life_os_core::ParserMode::Rule),
        })
        .expect("parse input");

    assert_eq!(parse_result.items.len(), 3);
    assert!(
        parse_result
            .items
            .iter()
            .any(|item| item.kind == AiDraftKind::Time)
    );
    assert!(
        parse_result
            .items
            .iter()
            .any(|item| item.kind == AiDraftKind::Income)
    );
    assert!(
        parse_result
            .items
            .iter()
            .any(|item| item.kind == AiDraftKind::Learning)
    );

    let parse_v2 = ai_service
        .parse_input_v2(&AiParseInput {
            user_id: user.id.clone(),
            raw_text: "2026-04-25 09:00-11:00 Core Upgrade Rust 工作 AI 30 效率 8 价值 9 状态 7"
                .to_string(),
            context_date: Some("2026-04-25".to_string()),
            parser_mode_override: Some(life_os_core::ParserMode::Rule),
        })
        .expect("parse input v2");
    assert_eq!(parse_v2.items.len(), 1);
    let draft = &parse_v2.items[0];
    assert_eq!(draft.kind, life_os_core::TypedDraftKind::TimeRecord);
    assert_eq!(draft.intent, life_os_core::DraftIntent::Record);
    assert!(draft.fields.contains_key("duration_minutes"));
    assert!(
        draft
            .note
            .as_deref()
            .is_some_and(|note| note.contains("Core Upgrade"))
    );
    assert!(
        matches!(
            draft.validation.status,
            life_os_core::DraftStatus::CommitReady | life_os_core::DraftStatus::NeedsReview
        ),
        "unexpected v2 draft status: {:?}",
        draft.validation.status
    );

    let commit_result = ai_service
        .commit_drafts(&AiCommitInput {
            user_id: user.id.clone(),
            request_id: Some(parse_result.request_id.clone()),
            context_date: Some("2026-04-25".to_string()),
            drafts: parse_result.items.clone(),
            options: AiCommitOptions::default(),
        })
        .expect("commit drafts");

    assert_eq!(commit_result.failures.len(), 0);
    assert_eq!(commit_result.committed.len(), 3);

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect database");

    let time_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM time_records WHERE user_id = ?1 AND source = 'external' AND parse_confidence IS NOT NULL",
            [user.id.as_str()],
            |row| row.get(0),
        )
        .expect("count time");
    let income_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM income_records WHERE user_id = ?1 AND source = 'external' AND parse_confidence IS NOT NULL",
            [user.id.as_str()],
            |row| row.get(0),
        )
        .expect("count income");
    let learning_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM learning_records WHERE user_id = ?1 AND source = 'external' AND parse_confidence IS NOT NULL",
            [user.id.as_str()],
            |row| row.get(0),
        )
        .expect("count learning");
    assert_eq!(time_count, 1);
    assert_eq!(income_count, 1);
    assert_eq!(learning_count, 1);

    let linked_projects: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM record_project_links WHERE project_id = ?1",
            [project.id.as_str()],
            |row| row.get(0),
        )
        .expect("count project links");
    let linked_tags: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM record_tag_links WHERE tag_id = ?1",
            [tag.id.as_str()],
            |row| row.get(0),
        )
        .expect("count tag links");
    assert!(linked_projects >= 2);
    assert!(linked_tags >= 2);
}

#[test]
fn ai_commit_auto_create_tags_and_partial_failures() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os_ai_partial.db");
    let ai_service = AiService::new(&database_path);
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let valid_expense = AiParseDraft::new(
        AiDraftKind::Expense,
        BTreeMap::from([
            ("date".to_string(), "2026-04-25".to_string()),
            ("category".to_string(), "subscription".to_string()),
            ("amount".to_string(), "25.5".to_string()),
            ("note".to_string(), "Bought API plan".to_string()),
            ("tag_names".to_string(), "AIOps".to_string()),
        ]),
        0.91,
        "rule",
        None,
    );
    let invalid_income = AiParseDraft::new(
        AiDraftKind::Income,
        BTreeMap::from([
            ("date".to_string(), "2026-04-25".to_string()),
            ("source".to_string(), "Broken Entry".to_string()),
            ("amount".to_string(), "not-a-number".to_string()),
        ]),
        0.3,
        "external",
        Some("bad amount".to_string()),
    );

    let commit_result = ai_service
        .commit_drafts(&AiCommitInput {
            user_id: user.id.clone(),
            request_id: Some("req-partial".to_string()),
            context_date: Some("2026-04-25".to_string()),
            drafts: vec![valid_expense.clone(), invalid_income.clone()],
            options: AiCommitOptions {
                source: Some("external".to_string()),
                auto_create_tags: true,
                strict_reference_resolution: false,
            },
        })
        .expect("commit partial drafts");

    assert_eq!(commit_result.committed.len(), 1);
    assert_eq!(commit_result.failures.len(), 1);
    assert_eq!(commit_result.committed[0].draft_id, valid_expense.draft_id);
    assert_eq!(commit_result.failures[0].draft_id, invalid_income.draft_id);

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect database");
    let created_tag_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM tags WHERE user_id = ?1 AND name = 'AIOps'",
            [user.id.as_str()],
            |row| row.get(0),
        )
        .expect("count auto-created tag");
    let expense_count: i64 = connection
        .query_row(
            "SELECT COUNT(*) FROM expense_records WHERE user_id = ?1 AND source = 'external'",
            [user.id.as_str()],
            |row| row.get(0),
        )
        .expect("count committed expense");
    assert_eq!(created_tag_count, 1);
    assert_eq!(expense_count, 1);
}

#[derive(Clone)]
struct MockCloudSyncTransport {
    remote_root: PathBuf,
}

impl MockCloudSyncTransport {
    fn new(remote_root: PathBuf) -> Self {
        Self { remote_root }
    }
}

impl CloudSyncTransport for MockCloudSyncTransport {
    fn upload_backup(
        &self,
        _config: &life_os_core::CloudSyncConfig,
        backup_file: &Path,
        _backup_type: BackupType,
    ) -> life_os_core::Result<RemoteUploadResult> {
        fs::create_dir_all(&self.remote_root)?;
        let filename = backup_file
            .file_name()
            .and_then(|value| value.to_str())
            .expect("backup filename");
        let target = self.remote_root.join(filename);
        fs::copy(backup_file, &target)?;
        let size_bytes = fs::metadata(&target)?.len() as i64;
        Ok(RemoteUploadResult {
            filename: filename.to_string(),
            size_bytes,
            checksum: Some(format!("mock-{size_bytes}")),
            uploaded_at: Some("2026-04-25T00:00:00Z".to_string()),
        })
    }

    fn list_backups(
        &self,
        _config: &life_os_core::CloudSyncConfig,
        limit: usize,
    ) -> life_os_core::Result<Vec<RemoteBackupFile>> {
        if !self.remote_root.exists() {
            return Ok(Vec::new());
        }
        let mut files = Vec::new();
        for entry in fs::read_dir(&self.remote_root)? {
            let entry = entry?;
            let metadata = entry.metadata()?;
            if !metadata.is_file() {
                continue;
            }
            files.push(RemoteBackupFile {
                filename: entry.file_name().to_string_lossy().to_string(),
                size_bytes: metadata.len() as i64,
                modified_at: "2026-04-25T00:00:00Z".to_string(),
            });
        }
        files.sort_by(|left, right| left.filename.cmp(&right.filename));
        files.truncate(limit);
        Ok(files)
    }

    fn download_backup(
        &self,
        _config: &life_os_core::CloudSyncConfig,
        filename: &str,
        target_file: &Path,
    ) -> life_os_core::Result<RemoteDownloadResult> {
        let source = self.remote_root.join(filename);
        if !source.exists() {
            return Err(life_os_core::LifeOsError::InvalidInput(format!(
                "remote file not found: {filename}"
            )));
        }
        if let Some(parent) = target_file.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::copy(&source, target_file)?;
        Ok(RemoteDownloadResult {
            file_path: target_file.display().to_string(),
            size_bytes: fs::metadata(target_file)?.len() as i64,
        })
    }

    fn delete_backup(
        &self,
        _config: &life_os_core::CloudSyncConfig,
        filename: &str,
    ) -> life_os_core::Result<()> {
        let target = self.remote_root.join(filename);
        if target.exists() {
            fs::remove_file(target)?;
        }
        Ok(())
    }
}

#[test]
fn backup_service_local_backup_and_restore() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os_backup.db");
    let record_service = RecordService::new(&database_path);
    let backup_service = BackupService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-04-25T01:00:00Z".to_string(),
            ended_at: "2026-04-25T02:00:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(8),
            value_score: Some(8),
            state_score: Some(7),
            ai_assist_ratio: Some(20),
            note: Some("before backup".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: Vec::new(),
            tag_ids: Vec::new(),
        })
        .expect("create time record");

    let backup = backup_service
        .create_backup(&user.id, "manual")
        .expect("create backup");
    assert!(backup.success);
    assert!(Path::new(&backup.file_path).exists());

    record_service
        .create_expense_record(&CreateExpenseRecordInput {
            user_id: user.id.clone(),
            occurred_on: "2026-04-25".to_string(),
            category_code: "necessary".to_string(),
            amount_cents: 8_800,
            ai_assist_ratio: Some(0),
            note: Some("after backup".to_string()),
            source: Some("manual".to_string()),
            project_allocations: Vec::new(),
            tag_ids: Vec::new(),
        })
        .expect("create expense after backup");

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect before restore");
    let expense_count_before: i64 = connection
        .query_row("SELECT COUNT(*) FROM expense_records", [], |row| row.get(0))
        .expect("count expense before restore");
    assert_eq!(expense_count_before, 1);
    drop(connection);

    let restore = backup_service
        .restore_from_backup_record(&user.id, &backup.id)
        .expect("restore backup");
    assert!(restore.success);

    let connection = database.connect().expect("connect after restore");
    let expense_count_after: i64 = connection
        .query_row("SELECT COUNT(*) FROM expense_records", [], |row| row.get(0))
        .expect("count expense after restore");
    let time_count_after: i64 = connection
        .query_row("SELECT COUNT(*) FROM time_records", [], |row| row.get(0))
        .expect("count time after restore");
    let restore_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM restore_records", [], |row| row.get(0))
        .expect("count restore records");
    assert_eq!(expense_count_after, 0);
    assert_eq!(time_count_after, 1);
    assert_eq!(restore_count, 1);
}

#[test]
fn backup_service_cloud_sync_roundtrip_with_mock_transport() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os_cloud.db");
    let backup_root = directory.path().join("local_backups");
    let remote_root = directory.path().join("remote_backups");
    let backup_service = BackupService::with_transport(
        &database_path,
        &backup_root,
        Arc::new(MockCloudSyncTransport::new(remote_root.clone())),
    );
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    backup_service
        .create_cloud_sync_config(&CreateCloudSyncConfigInput {
            user_id: user.id.clone(),
            provider: "lifeos_http".to_string(),
            endpoint_url: "https://sync.example.com".to_string(),
            bucket_name: None,
            region: None,
            root_path: None,
            device_id: "macbook".to_string(),
            api_key_encrypted: "token".to_string(),
            is_active: true,
        })
        .expect("create cloud config");

    record_service
        .create_time_record(&CreateTimeRecordInput {
            user_id: user.id.clone(),
            started_at: "2026-04-25T03:00:00Z".to_string(),
            ended_at: "2026-04-25T04:30:00Z".to_string(),
            category_code: "work".to_string(),
            efficiency_score: Some(7),
            value_score: Some(8),
            state_score: Some(7),
            ai_assist_ratio: Some(10),
            note: Some("sync candidate".to_string()),
            source: Some("manual".to_string()),
            is_public_pool: false,
            project_allocations: Vec::new(),
            tag_ids: Vec::new(),
        })
        .expect("create time");

    let backup = backup_service
        .create_backup(&user.id, "manual")
        .expect("create backup");
    let upload = backup_service
        .upload_backup_to_cloud(&user.id, &backup.id)
        .expect("upload backup");
    assert!(remote_root.join(&upload.filename).exists());

    let remote_files = backup_service
        .list_remote_backups(&user.id, 20)
        .expect("list remote backups");
    assert_eq!(remote_files.len(), 1);
    assert_eq!(remote_files[0].filename, upload.filename);

    let downloaded = backup_service
        .download_backup_from_cloud(&user.id, &upload.filename, "manual")
        .expect("download backup");
    assert!(downloaded.success);
    assert!(downloaded.file_path.contains("downloaded"));

    backup_service
        .delete_remote_backup(&user.id, &upload.filename)
        .expect("delete remote backup");
    let remote_files_after_delete = backup_service
        .list_remote_backups(&user.id, 20)
        .expect("list remote after delete");
    assert_eq!(remote_files_after_delete.len(), 0);

    let configs = backup_service
        .list_cloud_sync_configs(&user.id)
        .expect("list cloud configs");
    assert_eq!(configs.len(), 1);
    assert!(configs[0].last_sync_at.is_some());

    let backup_records = backup_service
        .list_backup_records(&user.id, 20)
        .expect("list backup records");
    assert_eq!(backup_records.len(), 2);
}
