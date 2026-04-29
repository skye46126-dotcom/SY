use life_os_core::ffi::invoke_json;
use serde::Deserialize;
use serde_json::{Value, json};
use std::env;
use std::fs;
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
    let response: BridgeResponse<Value> =
        serde_json::from_str(&invoke_json(database_path, method, &payload.to_string()))
            .expect("bridge response should be valid JSON");

    if !response.ok {
        let error = response.error.expect("error response should include error");
        panic!(
            "bridge call failed for method `{method}` [{}]: {}",
            error.code, error.message
        );
    }

    response
        .data
        .expect("bridge success response should include data")
}

fn test_ai_api_key() -> Option<String> {
    env::var("LIFE_OS_TEST_AI_API_KEY")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn test_ai_raw_text() -> String {
    env::var("LIFE_OS_TEST_AI_RAW_TEXT")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| {
            r#"3-12点睡觉

中午12.30-3.50 改skyeos UI，完善数据导出和海报导出
codex与chat版本聊天，商讨方案

4-5.30 实验

5.30-10点 开发skyos，优化规则层面
启发是提示词和部分细节不可以交给AI处理，效果很不好
拟订了第二方案，还需要时间执行
note记录和数据处理

11.30-12.30
优化boke论坛，效率较低，需要单独拿出来进行单元测试，去本地开发
开发agent数模，增加vsearch，设置按键
skyos解析数据，方案讨论

很久没有看书，很久没有健身，很久没有去打扮，学习穿搭，很多想要做的事都被放在脑后，难道我很难去多项并行事情吗

文本2中午
12-1点 修skyos

下午
5-9点
做UI的优化和功能增加
加入数据导出和图片分享导出功能，海报类似，但是没有做完，估计还需要一天时间，更改UI适配了很久很久，还有细节需要打磨
把boke和VCP结合，制作中间层聚合数据，方便管理

9点-12点
写数学作业和电路作业

使用GPT辅助，真的很不错
学习需要一直到处结果，看是否匹配，是否可以被消费，API使用 [REDACTED_API_KEY]"#
                .to_string()
        })
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
fn ffi_bridge_can_return_v2_parse_drafts() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let database_path = database_path.to_string_lossy().to_string();

    let user = bridge_call(&database_path, "init_database", json!({}));
    let user_id = user["id"].as_str().expect("user id").to_string();

    let parsed = bridge_call(
        &database_path,
        "parse_ai_input_v2",
        json!({
            "user_id": user_id,
            "raw_text": "今天学习 Rust FFI 1小时，效率 8，AI 30，note 是准备重构解析",
            "context_date": "2026-04-25",
            "parser_mode_override": "Rule",
        }),
    );

    let items = parsed["items"].as_array().expect("v2 items");
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["kind"].as_str(), Some("learning_record"));
    assert_eq!(items[0]["intent"].as_str(), Some("record"));
    assert!(items[0]["fields"]["duration_minutes"]["value"].is_string());
    assert!(
        items[0]["note"]
            .as_str()
            .is_some_and(|note| note.contains("Rust FFI"))
    );
}

#[test]
fn ffi_bridge_exports_data_package_files_from_rust() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let database_path = database_path.to_string_lossy().to_string();
    let output_dir = directory.path().join("exports");

    let user = bridge_call(&database_path, "init_database", json!({}));
    let user_id = user["id"].as_str().expect("user id").to_string();

    let preview = bridge_call(
        &database_path,
        "preview_data_package_export",
        json!({ "user_id": user_id }),
    );
    assert!(preview["projects"].as_u64().is_some());

    let result = bridge_call(
        &database_path,
        "export_data_package",
        json!({
            "user_id": user_id,
            "format": "zip",
            "output_dir": output_dir,
            "title": "data-package-test",
            "module": "data_package",
        }),
    );

    let artifacts = result["artifacts"].as_array().expect("artifacts");
    assert_eq!(artifacts.len(), 1);
    assert_eq!(artifacts[0]["type"].as_str(), Some("data_package"));
    assert_eq!(artifacts[0]["format"].as_str(), Some("zip"));
    let file_path = artifacts[0]["file_path"].as_str().expect("file path");
    let bytes = fs::read(file_path).expect("exported zip should exist");
    assert!(bytes.starts_with(b"PK\x03\x04"));
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
        "save_dimension_option",
        json!({
            "user_id": user_id,
            "kind": "expense_category",
            "input": {
                "code": "software",
                "display_name": "Software",
                "is_active": true
            }
        }),
    );

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

#[test]
fn ffi_bridge_can_run_live_llm_capture_chain() {
    let Some(api_key) = test_ai_api_key() else {
        eprintln!("skip live llm capture test: LIFE_OS_TEST_AI_API_KEY is not set");
        return;
    };

    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let database_path = database_path.to_string_lossy().to_string();

    let user = bridge_call(&database_path, "init_database", json!({}));
    let user_id = user["id"].as_str().expect("user id").to_string();

    bridge_call(
        &database_path,
        "create_ai_service_config",
        json!({
            "input": {
                "user_id": user_id,
                "provider": "deepseek",
                "api_key_encrypted": api_key,
                "model": "deepseek-chat",
                "system_prompt": null,
                "parser_mode": "Llm",
                "temperature_milli": 0,
                "is_active": true
            }
        }),
    );

    let raw_text = test_ai_raw_text();

    let parsed = bridge_call(
        &database_path,
        "parse_ai_input_v2",
        json!({
            "user_id": user_id,
            "raw_text": raw_text,
            "context_date": "2026-04-29",
            "parser_mode_override": "Llm",
        }),
    );

    let items = parsed["items"].as_array().expect("items");
    let review_notes = parsed["review_notes"].as_array().expect("review_notes");
    let ignored_context = parsed["ignored_context"]
        .as_array()
        .expect("ignored_context");
    let commit_ready = items
        .iter()
        .filter(|item| item["validation"]["status"].as_str() == Some("commit_ready"))
        .cloned()
        .collect::<Vec<_>>();

    eprintln!(
        "live llm parse summary: parser={} items={} commit_ready={} review_notes={} ignored={}",
        parsed["parser_used"].as_str().unwrap_or("unknown"),
        items.len(),
        commit_ready.len(),
        review_notes.len(),
        ignored_context.len(),
    );
    eprintln!("live llm parse warnings: {}", parsed["warnings"]);

    assert!(
        !items.is_empty() || !review_notes.is_empty(),
        "llm chain should return events or review notes"
    );

    if !commit_ready.is_empty() || !review_notes.is_empty() {
        let committed = bridge_call(
            &database_path,
            "commit_ai_capture",
            json!({
                "user_id": user["id"].as_str().expect("user id"),
                "request_id": parsed["request_id"].as_str(),
                "context_date": "2026-04-29",
                "drafts": commit_ready
                    .iter()
                    .map(|item| {
                        let kind = match item["kind"].as_str().unwrap_or("unknown") {
                            "time_record" => "Time",
                            "income_record" => "Income",
                            "expense_record" => "Expense",
                            "learning_record" => "Learning",
                            _ => "Unknown",
                        };
                        let mut payload = serde_json::Map::new();
                        if let Some(fields) = item["fields"].as_object() {
                            for (key, field) in fields {
                                if let Some(value) = field.get("value")
                                    && !value.is_null()
                                {
                                    let serialized = match value {
                                        Value::String(value) => Value::String(value.clone()),
                                        Value::Number(value) => {
                                            Value::String(value.to_string())
                                        }
                                        Value::Bool(value) => {
                                            Value::String(value.to_string())
                                        }
                                        _ => continue,
                                    };
                                    payload.insert(key.clone(), serialized);
                                }
                            }
                        }
                        if let Some(raw_text) = item["raw_text"].as_str() {
                            payload.insert("raw".to_string(), Value::String(raw_text.to_string()));
                        }
                        json!({
                            "draft_id": item["draft_id"].as_str().unwrap_or_default(),
                            "kind": kind,
                            "payload": payload,
                            "confidence": item["confidence"].as_f64().unwrap_or(0.0),
                            "source": item["source"].as_str().unwrap_or("llm"),
                            "warning": Value::Null,
                        })
                    })
                    .collect::<Vec<_>>(),
                "review_notes": review_notes,
                "options": {
                    "source": "external",
                    "auto_create_tags": false,
                    "strict_reference_resolution": false,
                }
            }),
        );

        eprintln!(
            "live llm commit summary: committed={} committed_notes={} failures={} note_failures={}",
            committed["committed"].as_array().map(Vec::len).unwrap_or(0),
            committed["committed_notes"]
                .as_array()
                .map(Vec::len)
                .unwrap_or(0),
            committed["failures"].as_array().map(Vec::len).unwrap_or(0),
            committed["note_failures"]
                .as_array()
                .map(Vec::len)
                .unwrap_or(0),
        );

        let review = bridge_call(
            &database_path,
            "get_review_report",
            json!({
                "user_id": user["id"].as_str().expect("user id"),
                "kind": "day",
                "anchor_date": "2026-04-29",
                "timezone": "Asia/Shanghai",
            }),
        );
        eprintln!(
            "live llm review summary: work_minutes={} review_notes={}",
            review["total_work_minutes"].as_i64().unwrap_or(0),
            review["review_notes"].as_array().map(Vec::len).unwrap_or(0),
        );
    }
}
