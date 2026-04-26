use life_os_core::ffi::invoke_json;
use serde::Deserialize;
use serde_json::{Value, json};
use tempfile::tempdir;

#[derive(Debug, Deserialize)]
struct BridgeError {
    code: String,
    message: String,
}

#[derive(Debug, Deserialize)]
struct BridgeResponse<T> {
    ok: bool,
    data: Option<T>,
    error: Option<BridgeError>,
}

fn bridge_call(database_path: &str, method: &str, payload: Value) -> Value {
    let response: BridgeResponse<Value> = serde_json::from_str(&invoke_json(
        database_path,
        method,
        &payload.to_string(),
    ))
    .expect("bridge response should be valid JSON");

    if !response.ok {
        let error = response.error.expect("error response should include error");
        panic!(
            "bridge call failed for method `{method}` [{}]: {}",
            error.code, error.message
        );
    }

    response.data.expect("bridge success response should include data")
}

#[test]
fn ffi_bridge_can_initialize_write_and_read_today_data() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let database_path = database_path.to_string_lossy().to_string();

    let user = bridge_call(&database_path, "init_database", json!({}));
    let user_id = user["id"].as_str().expect("user id").to_string();

    bridge_call(
        &database_path,
        "create_time_record",
        json!({
            "user_id": user_id,
            "started_at": "2026-04-25T01:00:00Z",
            "ended_at": "2026-04-25T03:30:00Z",
            "category_code": "work",
            "efficiency_score": 8,
            "value_score": 9,
            "state_score": 7,
            "ai_assist_ratio": 45,
            "note": "ffi today flow",
            "source": "manual",
            "is_public_pool": false,
            "project_allocations": [],
            "tag_ids": [],
        }),
    );

    bridge_call(
        &database_path,
        "create_income_record",
        json!({
            "user_id": user_id,
            "occurred_on": "2026-04-25",
            "source_name": "Client A",
            "type_code": "project",
            "amount_cents": 80000,
            "is_passive": false,
            "ai_assist_ratio": 20,
            "note": "ffi income",
            "source": "manual",
            "is_public_pool": false,
            "project_allocations": [],
            "tag_ids": [],
        }),
    );

    bridge_call(
        &database_path,
        "create_expense_record",
        json!({
            "user_id": user_id,
            "occurred_on": "2026-04-25",
            "category_code": "necessary",
            "amount_cents": 12000,
            "ai_assist_ratio": 5,
            "note": "ffi expense",
            "source": "manual",
            "project_allocations": [],
            "tag_ids": [],
        }),
    );

    bridge_call(
        &database_path,
        "create_learning_record",
        json!({
            "user_id": user_id,
            "occurred_on": "2026-04-25",
            "started_at": "2026-04-25T10:00:00Z",
            "ended_at": "2026-04-25T11:00:00Z",
            "content": "Read Rust docs",
            "duration_minutes": 60,
            "application_level_code": "input",
            "efficiency_score": 7,
            "ai_assist_ratio": 30,
            "note": "ffi learning",
            "source": "manual",
            "is_public_pool": false,
            "project_allocations": [],
            "tag_ids": [],
        }),
    );

    let overview = bridge_call(
        &database_path,
        "get_today_overview",
        json!({
            "user_id": user_id,
            "anchor_date": "2026-04-25",
            "timezone": "Asia/Shanghai",
        }),
    );

    assert_eq!(overview["total_income_cents"].as_i64(), Some(80_000));
    assert_eq!(overview["total_expense_cents"].as_i64(), Some(12_000));
    assert_eq!(overview["net_income_cents"].as_i64(), Some(68_000));
    assert_eq!(overview["total_work_minutes"].as_i64(), Some(150));
    assert_eq!(overview["total_learning_minutes"].as_i64(), Some(60));

    let recent = bridge_call(
        &database_path,
        "get_recent_records",
        json!({
            "user_id": user_id,
            "timezone": "Asia/Shanghai",
            "limit": 10,
        }),
    );

    assert_eq!(recent.as_array().map(Vec::len), Some(4));
}

#[test]
fn ffi_bridge_can_query_projects_tags_and_reviews() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let database_path = database_path.to_string_lossy().to_string();

    let user = bridge_call(&database_path, "init_database", json!({}));
    let user_id = user["id"].as_str().expect("user id").to_string();

    let tag = bridge_call(
        &database_path,
        "create_tag",
        json!({
            "user_id": user_id,
            "name": "Work",
            "emoji": "💼",
            "tag_group": "focus",
            "scope": "time",
            "parent_tag_id": null,
            "level": 1,
            "status": "active",
            "sort_order": 10,
        }),
    );
    let tag_id = tag["id"].as_str().expect("tag id").to_string();

    let project = bridge_call(
        &database_path,
        "create_project",
        json!({
            "user_id": user_id,
            "name": "SkyeOS Rust Refactor",
            "status_code": "active",
            "started_on": "2026-04-01",
            "ended_on": null,
            "ai_enable_ratio": 60,
            "score": 8,
            "note": "ffi project flow",
            "tag_ids": [tag_id],
        }),
    );
    let project_id = project["id"].as_str().expect("project id").to_string();

    let allocation = json!([{ "project_id": project_id, "weight_ratio": 1.0 }]);

    bridge_call(
        &database_path,
        "create_time_record",
        json!({
            "user_id": user_id,
            "started_at": "2026-04-25T09:00:00Z",
            "ended_at": "2026-04-25T11:00:00Z",
            "category_code": "work",
            "efficiency_score": 8,
            "value_score": 9,
            "state_score": 8,
            "ai_assist_ratio": 50,
            "note": "project time",
            "source": "manual",
            "is_public_pool": false,
            "project_allocations": allocation,
            "tag_ids": [],
        }),
    );

    bridge_call(
        &database_path,
        "create_income_record",
        json!({
            "user_id": user_id,
            "occurred_on": "2026-04-25",
            "source_name": "Freelance",
            "type_code": "project",
            "amount_cents": 150000,
            "is_passive": false,
            "ai_assist_ratio": 20,
            "note": "project income",
            "source": "manual",
            "is_public_pool": false,
            "project_allocations": allocation,
            "tag_ids": [],
        }),
    );

    bridge_call(
        &database_path,
        "create_expense_record",
        json!({
            "user_id": user_id,
            "occurred_on": "2026-04-25",
            "category_code": "software",
            "amount_cents": 9999,
            "ai_assist_ratio": 5,
            "note": "project expense",
            "source": "manual",
            "project_allocations": allocation,
            "tag_ids": [],
        }),
    );

    bridge_call(
        &database_path,
        "create_learning_record",
        json!({
            "user_id": user_id,
            "occurred_on": "2026-04-25",
            "started_at": "2026-04-25T12:00:00Z",
            "ended_at": "2026-04-25T13:00:00Z",
            "content": "Read rusqlite docs",
            "duration_minutes": 60,
            "application_level_code": "applied",
            "efficiency_score": 7,
            "ai_assist_ratio": 30,
            "note": "project learning",
            "source": "manual",
            "is_public_pool": false,
            "project_allocations": allocation,
            "tag_ids": [],
        }),
    );

    let tags = bridge_call(
        &database_path,
        "list_tags",
        json!({
            "user_id": user_id,
        }),
    );
    assert_eq!(tags.as_array().map(Vec::len), Some(1));

    let projects = bridge_call(
        &database_path,
        "list_projects",
        json!({
            "user_id": user_id,
            "status_filter": "active",
        }),
    );
    assert_eq!(projects.as_array().map(Vec::len), Some(1));

    let detail = bridge_call(
        &database_path,
        "get_project_detail",
        json!({
            "user_id": user_id,
            "project_id": project_id,
            "timezone": "Asia/Shanghai",
            "recent_limit": 10,
        }),
    );
    assert_eq!(detail["name"].as_str(), Some("SkyeOS Rust Refactor"));
    assert_eq!(detail["income_record_count"].as_i64(), Some(1));
    assert_eq!(detail["expense_record_count"].as_i64(), Some(1));
    assert_eq!(detail["time_record_count"].as_i64(), Some(1));
    assert_eq!(detail["learning_record_count"].as_i64(), Some(1));

    let review = bridge_call(
        &database_path,
        "get_review_report",
        json!({
            "user_id": user_id,
            "kind": "day",
            "anchor_date": "2026-04-25",
            "timezone": "Asia/Shanghai",
        }),
    );
    assert_eq!(review["total_income_cents"].as_i64(), Some(150_000));
    assert_eq!(review["total_expense_cents"].as_i64(), Some(9_999));
    assert_eq!(review["total_work_minutes"].as_i64(), Some(120));
}
