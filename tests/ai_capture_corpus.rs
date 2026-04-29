use std::fs;
use std::path::{Path, PathBuf};

use life_os_core::models::IgnoredContext;
use life_os_core::{AiParseInput, AiService, DraftStatus, ParserMode, RecordService};
use serde::Deserialize;
use tempfile::tempdir;

#[derive(Debug, Deserialize)]
struct CorpusCase {
    name: String,
    context_date: String,
    mode: String,
    raw_text: String,
    minimums: Option<CorpusMinimums>,
    #[serde(default)]
    expected_events: Vec<ExpectedEvent>,
    #[serde(default)]
    expected_notes: Vec<ExpectedNote>,
    #[serde(default)]
    expected_ignored: Vec<ExpectedIgnored>,
}

#[derive(Debug, Deserialize)]
struct CorpusMinimums {
    items: Option<usize>,
    review_notes: Option<usize>,
    ignored_context: Option<usize>,
    blocked_max: Option<usize>,
}

#[derive(Debug, Deserialize)]
struct ExpectedEvent {
    kind: Option<String>,
    title_contains: Option<String>,
    raw_text_contains: Option<String>,
    validation_status: Option<String>,
    field_equals: Option<std::collections::BTreeMap<String, String>>,
}

#[derive(Debug, Deserialize)]
struct ExpectedNote {
    note_type: Option<String>,
    title_contains: Option<String>,
    content_contains: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ExpectedIgnored {
    raw_text_contains: Option<String>,
    reason: Option<String>,
}

#[test]
fn ai_capture_corpus_cases_match_baseline_expectations() {
    let files = collect_json_files(Path::new("tests/fixtures/ai_capture_corpus"))
        .expect("collect corpus files");
    assert!(!files.is_empty(), "expected at least one corpus json file");

    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");
    let service = AiService::new(&database_path);
    let mut failures = Vec::new();

    for file in files {
        let text = fs::read_to_string(&file)
            .unwrap_or_else(|error| panic!("read corpus file {}: {error}", file.display()));
        let case: CorpusCase = serde_json::from_str(&text)
            .unwrap_or_else(|error| panic!("parse corpus file {}: {error}", file.display()));

        let result = service
            .parse_input_v2(&AiParseInput {
                user_id: user.id.clone(),
                raw_text: case.raw_text.clone(),
                context_date: Some(case.context_date.clone()),
                parser_mode_override: Some(parser_mode_from_str(&case.mode)),
            })
            .unwrap_or_else(|error| panic!("case {} parse failed: {error}", case.name));

        if let Some(minimums) = case.minimums {
            if let Some(items) = minimums.items {
                if result.items.len() < items {
                    failures.push(format!(
                        "case {} expected at least {items} items, got {}",
                        case.name,
                        result.items.len()
                    ));
                }
            }
            if let Some(notes) = minimums.review_notes {
                if result.review_notes.len() < notes {
                    failures.push(format!(
                        "case {} expected at least {notes} review_notes, got {}",
                        case.name,
                        result.review_notes.len()
                    ));
                }
            }
            if let Some(ignored) = minimums.ignored_context {
                if result.ignored_context.len() < ignored {
                    failures.push(format!(
                        "case {} expected at least {ignored} ignored_context, got {}",
                        case.name,
                        result.ignored_context.len()
                    ));
                }
            }
            if let Some(blocked_max) = minimums.blocked_max {
                let blocked = result
                    .items
                    .iter()
                    .filter(|item| item.validation.status == DraftStatus::Blocked)
                    .count();
                if blocked > blocked_max {
                    failures.push(format!(
                        "case {} expected blocked <= {blocked_max}, got {blocked}",
                        case.name
                    ));
                }
            }
        }

        for expected in case.expected_events {
            if !result
                .items
                .iter()
                .any(|item| event_matches(item, &expected))
            {
                failures.push(format!(
                    "case {} missing expected event {:?}",
                    case.name, expected
                ));
            }
        }

        for expected in case.expected_notes {
            if !result
                .review_notes
                .iter()
                .any(|note| note_matches(note, &expected))
            {
                failures.push(format!(
                    "case {} missing expected review note {:?}",
                    case.name, expected
                ));
            }
        }

        for expected in case.expected_ignored {
            if !result
                .ignored_context
                .iter()
                .any(|item| ignored_matches(item, &expected))
            {
                failures.push(format!(
                    "case {} missing expected ignored context {:?}",
                    case.name, expected
                ));
            }
        }
    }

    assert!(
        failures.is_empty(),
        "corpus expectations failed:\n{}",
        failures.join("\n")
    );
}

fn collect_json_files(root: &Path) -> std::io::Result<Vec<PathBuf>> {
    let mut files = fs::read_dir(root)?
        .filter_map(|entry| entry.ok().map(|entry| entry.path()))
        .filter(|path| path.extension().and_then(|ext| ext.to_str()) == Some("json"))
        .collect::<Vec<_>>();
    files.sort();
    Ok(files)
}

fn parser_mode_from_str(raw: &str) -> ParserMode {
    match raw.trim().to_ascii_lowercase().as_str() {
        "rule" => ParserMode::Rule,
        "fast" => ParserMode::Fast,
        "deep" => ParserMode::Deep,
        "llm" => ParserMode::Llm,
        "vcp" => ParserMode::Vcp,
        _ => ParserMode::Auto,
    }
}

fn event_matches(item: &life_os_core::ReviewableDraft, expected: &ExpectedEvent) -> bool {
    if let Some(kind) = &expected.kind
        && item.kind.as_str() != kind.trim()
    {
        return false;
    }
    if let Some(title_contains) = &expected.title_contains
        && !event_haystack(item).contains(title_contains)
    {
        return false;
    }
    if let Some(raw_text_contains) = &expected.raw_text_contains
        && !event_haystack(item).contains(raw_text_contains)
    {
        return false;
    }
    if let Some(status) = &expected.validation_status
        && item.validation.status.as_str() != status.trim()
    {
        return false;
    }
    if let Some(field_equals) = &expected.field_equals {
        for (key, value) in field_equals {
            let Some(field) = item.fields.get(key) else {
                return false;
            };
            let actual = field
                .value
                .as_ref()
                .map(field_value_to_string)
                .unwrap_or_default();
            if actual != value.trim() {
                return false;
            }
        }
    }
    true
}

fn note_matches(note: &life_os_core::ReviewNoteDraft, expected: &ExpectedNote) -> bool {
    if let Some(note_type) = &expected.note_type
        && note.note_type != note_type.trim()
    {
        return false;
    }
    if let Some(title_contains) = &expected.title_contains
        && !note_haystack(note).contains(title_contains)
    {
        return false;
    }
    if let Some(content_contains) = &expected.content_contains
        && !note_haystack(note).contains(content_contains)
    {
        return false;
    }
    true
}

fn ignored_matches(item: &IgnoredContext, expected: &ExpectedIgnored) -> bool {
    if let Some(raw_text_contains) = &expected.raw_text_contains
        && !item.raw_text.contains(raw_text_contains)
    {
        return false;
    }
    if let Some(reason) = &expected.reason
        && item.reason != reason.trim()
    {
        return false;
    }
    true
}

fn field_value_to_string(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(value) => value.clone(),
        serde_json::Value::Null => String::new(),
        other => other.to_string(),
    }
}

fn event_haystack(item: &life_os_core::ReviewableDraft) -> String {
    let mut parts = vec![
        item.raw_text.clone(),
        item.title.clone(),
        item.note.clone().unwrap_or_default(),
    ];
    parts.extend(
        item.fields
            .values()
            .filter_map(|field| field.value.as_ref())
            .map(field_value_to_string),
    );
    parts.join("\n")
}

fn note_haystack(note: &life_os_core::ReviewNoteDraft) -> String {
    [
        note.raw_text.as_str(),
        note.title.as_str(),
        note.content.as_str(),
    ]
    .join("\n")
}
