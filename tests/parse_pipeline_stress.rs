use life_os_core::{
    AiCaptureCommitInput, AiCommitOptions, AiDraftKind, AiParseDraft, AiParseInput, AiService,
    Database, DraftStatus, ParseContext, ParserMode, RecordService, TypedDraftKind,
};
use std::collections::BTreeMap;
use tempfile::tempdir;

const RECORD_0917: &str = include_str!("fixtures/record_0917.txt");

#[test]
fn preprocesses_long_daily_log_without_losing_segments() {
    let input = AiParseInput {
        user_id: "stress-user".to_string(),
        raw_text: RECORD_0917.to_string(),
        context_date: Some("2026-09-17".to_string()),
        parser_mode_override: Some(ParserMode::Rule),
    };

    let preprocessed = life_os_core::ai::preprocess_input(&input);

    assert_eq!(preprocessed.context_date, "2026-09-17");
    assert!(
        preprocessed.segments.len() >= 35,
        "expected many diary segments, got {}",
        preprocessed.segments.len()
    );
    assert!(
        preprocessed
            .segments
            .iter()
            .any(|segment| segment.raw_text.contains("背单词50分钟"))
    );
    assert!(
        preprocessed
            .segments
            .iter()
            .any(|segment| segment.raw_text.contains("桃子湖"))
    );
}

#[test]
fn rule_v2_pipeline_stress_parses_long_daily_log_into_reviewable_drafts() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let service = AiService::new(&database_path);
    let result = service
        .parse_input_v2(&AiParseInput {
            user_id: user.id,
            raw_text: RECORD_0917.to_string(),
            context_date: Some("2026-09-17".to_string()),
            parser_mode_override: Some(ParserMode::Rule),
        })
        .expect("parse long daily log");

    assert!(
        result.items.len() >= 3,
        "expected factual drafts, got {}",
        result.items.len()
    );
    assert!(
        result.review_notes.len() + result.ignored_context.len() >= 10,
        "long diary should preserve non-record context outside the main draft list"
    );
    assert!(
        result.items.iter().any(|item| {
            item.kind == TypedDraftKind::TimeRecord
                && item
                    .fields
                    .get("duration_minutes")
                    .and_then(|field| field.value.as_ref())
                    .and_then(|value| value.as_str())
                    == Some("50")
        }),
        "expected at least one duration-based time draft"
    );
    assert!(
        result
            .review_notes
            .iter()
            .any(|note| note.content.contains("桃子湖") || note.content.contains("活动"))
            || result
                .ignored_context
                .iter()
                .any(|item| item.raw_text.contains("桃子湖") || item.raw_text.contains("活动")),
        "planning/context text should not be mixed into the main commit list"
    );
    assert!(result.items.iter().all(|item| {
        matches!(
            item.validation.status,
            DraftStatus::CommitReady | DraftStatus::NeedsReview | DraftStatus::Blocked
        )
    }));

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect database");
    let time_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM time_records", [], |row| row.get(0))
        .expect("count time records");
    assert_eq!(
        time_count, 0,
        "parse stress test must not commit records without explicit user review"
    );
}

#[test]
fn rule_v4_keeps_single_time_anchors_as_time_markers() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let service = AiService::new(&database_path);
    let result = service
        .parse_input_v2(&AiParseInput {
            user_id: user.id,
            raw_text: "8:20左右出寝室买早餐\n11点40下课\n背单词50分钟".to_string(),
            context_date: Some("2026-09-17".to_string()),
            parser_mode_override: Some(ParserMode::Rule),
        })
        .expect("parse anchors");

    let marker_count = result
        .ignored_context
        .iter()
        .filter(|item| item.reason == "reference_or_time_anchor")
        .count();
    assert_eq!(
        marker_count, 2,
        "single time anchors must not become time records"
    );
    assert!(
        result
            .items
            .iter()
            .all(|item| item.kind != TypedDraftKind::TimeMarker)
    );
    assert!(result.items.iter().any(|item| {
        item.kind == TypedDraftKind::TimeRecord
            && item
                .fields
                .get("duration_minutes")
                .and_then(|field| field.value.as_ref())
                .and_then(|value| value.as_str())
                == Some("50")
    }));
}

#[test]
fn rule_v2_pipeline_splits_pure_notes_from_commit_drafts() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let service = AiService::new(&database_path);
    let result = service
        .parse_input_v2(&AiParseInput {
            user_id: user.id,
            raw_text: "工作：17-21 优化代码功能开发，AI40，效率8\n复盘：GPT 辅助确实很顺\n中午"
                .to_string(),
            context_date: Some("2026-04-29".to_string()),
            parser_mode_override: Some(ParserMode::Rule),
        })
        .expect("parse notes");

    assert!(
        result
            .items
            .iter()
            .any(|item| item.kind == TypedDraftKind::TimeRecord)
    );
    assert!(
        result
            .review_notes
            .iter()
            .any(|note| note.note_type == "ai_usage" && note.content.contains("GPT"))
    );
    assert!(
        result
            .review_notes
            .iter()
            .any(|note| note.content.contains("中午"))
            || result
                .ignored_context
                .iter()
                .any(|item| item.raw_text.contains("中午"))
    );
}

#[test]
fn rule_v2_pipeline_merges_period_heads_and_parses_dot_time_ranges() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");

    let service = AiService::new(&database_path);
    let result = service
        .parse_input_v2(&AiParseInput {
            user_id: user.id,
            raw_text: "中午\n12.30-14.30\n王者\n\n下午\n5-9点\n做UI优化和功能增加".to_string(),
            context_date: Some("2026-04-29".to_string()),
            parser_mode_override: Some(ParserMode::Rule),
        })
        .expect("parse merged time blocks");

    assert!(
        result.items.iter().any(|item| {
            item.kind == TypedDraftKind::TimeRecord
                && item
                    .fields
                    .get("start_time")
                    .and_then(|field| field.value.as_ref())
                    .and_then(|value| value.as_str())
                    == Some("12:30")
        }),
        "dot time ranges should be parsed into start_time/end_time"
    );
    assert!(
        result.items.iter().any(|item| {
            item.kind == TypedDraftKind::TimeRecord && item.raw_text.contains("做UI优化和功能增加")
        }),
        "period heading and standalone time line should merge with following action text"
    );
}

#[test]
fn llm_v5_prompt_sends_full_text_without_chunking() {
    let input = AiParseInput {
        user_id: "stress-user".to_string(),
        raw_text: [RECORD_0917, RECORD_0917, RECORD_0917].join("\n"),
        context_date: Some("2026-09-17".to_string()),
        parser_mode_override: Some(ParserMode::Rule),
    };
    let preprocessed = life_os_core::ai::preprocess_input(&input);
    let context = ParseContext {
        category_codes: Vec::new(),
        project_names: Vec::new(),
        tag_names: Vec::new(),
        rule_hints: Vec::new(),
    };
    let chunks = life_os_core::ai::build_llm_prompt_chunks(&preprocessed, &context, 1_500);

    assert!(
        chunks.len() == 1,
        "llm prompt should send the whole text without chunking"
    );
    assert_eq!(chunks[0].total, 1);
    assert_eq!(chunks[0].index, 1);
    assert_eq!(chunks[0].segment_start, 0);
    assert_eq!(chunks[0].segment_end, preprocessed.segments.len());
    assert!(
        chunks
            .iter()
            .all(|chunk| !chunk.prompt.contains("chunk_index"))
    );
    assert!(
        chunks
            .iter()
            .all(|chunk| chunk.prompt.contains("必须输出完整且可解析的 JSON"))
    );
    assert!(
        chunks
            .iter()
            .all(|chunk| chunk.prompt.contains("失败 / 没做 / 忘了"))
    );
    assert!(
        chunks
            .iter()
            .all(|chunk| chunk.prompt.contains("看书 / 读书 / 背单词 / 预习"))
    );
    assert!(chunks[0].prompt.contains(RECORD_0917));
}

#[test]
fn ai_capture_commit_rejects_time_defaults_without_explicit_window() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");
    let service = AiService::new(&database_path);

    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), "2026-04-29".to_string());
    payload.insert("category".to_string(), "work".to_string());
    payload.insert("description".to_string(), "优化代码".to_string());
    payload.insert("duration_minutes".to_string(), "120".to_string());

    let result = service
        .commit_capture(&AiCaptureCommitInput {
            user_id: user.id,
            request_id: None,
            context_date: Some("2026-04-29".to_string()),
            drafts: vec![AiParseDraft::new(
                AiDraftKind::Time,
                payload,
                0.9,
                "test",
                None,
            )],
            review_notes: Vec::new(),
            options: AiCommitOptions::default(),
        })
        .expect("commit should return item failure");

    assert!(result.committed.is_empty());
    assert_eq!(result.failures.len(), 1);
    assert!(
        result.failures[0]
            .message
            .contains("explicit start_time and end_time")
    );
}

#[test]
fn ai_capture_commit_rejects_learning_default_duration() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");
    let service = AiService::new(&database_path);

    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), "2026-04-29".to_string());
    payload.insert("content".to_string(), "学习唱歌".to_string());
    payload.insert("application_level".to_string(), "input".to_string());

    let result = service
        .commit_capture(&AiCaptureCommitInput {
            user_id: user.id,
            request_id: None,
            context_date: Some("2026-04-29".to_string()),
            drafts: vec![AiParseDraft::new(
                AiDraftKind::Learning,
                payload,
                0.9,
                "test",
                None,
            )],
            review_notes: Vec::new(),
            options: AiCommitOptions::default(),
        })
        .expect("commit should return item failure");

    assert!(result.committed.is_empty());
    assert_eq!(result.failures.len(), 1);
    assert!(
        result.failures[0]
            .message
            .contains("explicit duration or complete time window")
    );
}

#[test]
fn ai_draft_kind_accepts_snake_case_and_legacy_pascal_case() {
    let lower: life_os_core::AiCaptureCommitInput = serde_json::from_value(serde_json::json!({
        "user_id": "u1",
        "context_date": "2026-04-29",
        "drafts": [{
            "draft_id": "d1",
            "kind": "time",
            "payload": {"date": "2026-04-29"},
            "confidence": 0.5,
            "source": "test",
            "warning": null
        }],
        "review_notes": [],
        "options": {
            "source": "external",
            "auto_create_tags": false,
            "strict_reference_resolution": false
        }
    }))
    .expect("snake_case kind should parse");
    assert_eq!(lower.drafts[0].kind.as_str(), "time");

    let upper: life_os_core::AiCaptureCommitInput = serde_json::from_value(serde_json::json!({
        "user_id": "u1",
        "context_date": "2026-04-29",
        "drafts": [{
            "draft_id": "d1",
            "kind": "Time",
            "payload": {"date": "2026-04-29"},
            "confidence": 0.5,
            "source": "test",
            "warning": null
        }],
        "review_notes": [],
        "options": {
            "source": "external",
            "auto_create_tags": false,
            "strict_reference_resolution": false
        }
    }))
    .expect("legacy PascalCase kind should parse");
    assert_eq!(upper.drafts[0].kind.as_str(), "time");
}

#[test]
fn ai_capture_commit_accepts_snake_case_time_kind_at_backend_boundary() {
    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");
    let service = AiService::new(&database_path);

    let payload = serde_json::json!({
        "user_id": user.id,
        "context_date": "2026-04-29",
        "drafts": [{
            "draft_id": "d1",
            "kind": "time",
            "payload": {
                "date": "2026-04-29",
                "category": "work",
                "description": "协议边界测试"
            },
            "confidence": 0.5,
            "source": "test",
            "warning": null
        }],
        "review_notes": [],
        "options": {
            "source": "external",
            "auto_create_tags": false,
            "strict_reference_resolution": false
        }
    });

    let input: life_os_core::AiCaptureCommitInput =
        serde_json::from_value(payload).expect("snake_case kind should parse at backend boundary");

    let result = service
        .commit_capture(&input)
        .expect("commit should reach business layer instead of serde failing");

    assert!(result.committed.is_empty());
    assert_eq!(result.failures.len(), 1);
    assert!(
        result.failures[0]
            .message
            .contains("explicit start_time and end_time")
    );
}
