use std::fs;
use std::path::{Path, PathBuf};

use life_os_core::{AiParseInput, AiService, Database, ParserMode, RecordService};
use tempfile::tempdir;

#[test]
#[ignore = "set LIFE_OS_RECORD_CORPUS_DIR to run against a private local record corpus"]
fn rule_v4_parses_external_record_corpus_without_committing() {
    let corpus_dir = std::env::var("LIFE_OS_RECORD_CORPUS_DIR")
        .expect("LIFE_OS_RECORD_CORPUS_DIR must point to the record corpus");
    let mut files = collect_record_files(Path::new(&corpus_dir)).expect("collect record files");
    files.sort();
    files.truncate(12);
    assert!(!files.is_empty(), "expected at least one .md or .txt file");

    let directory = tempdir().expect("tempdir");
    let database_path = directory.path().join("life_os.db");
    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database().expect("init database");
    let service = AiService::new(&database_path);

    for file in files {
        let raw_text = fs::read_to_string(&file).expect("read record file");
        if raw_text.trim().is_empty() {
            continue;
        }
        let result = service
            .parse_input_v2(&AiParseInput {
                user_id: user.id.clone(),
                raw_text,
                context_date: Some("2026-09-17".to_string()),
                parser_mode_override: Some(ParserMode::Rule),
            })
            .unwrap_or_else(|error| panic!("parse failed for {}: {error}", file.display()));

        assert!(
            !result.items.is_empty(),
            "expected parse items for {}",
            file.display()
        );
    }

    let database = Database::new(&database_path);
    let connection = database.connect().expect("connect database");
    let time_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM time_records", [], |row| row.get(0))
        .expect("count time records");
    let expense_count: i64 = connection
        .query_row("SELECT COUNT(*) FROM expense_records", [], |row| row.get(0))
        .expect("count expense records");
    assert_eq!(
        time_count + expense_count,
        0,
        "parse must not commit records"
    );
}

fn collect_record_files(root: &Path) -> std::io::Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    collect_record_files_inner(root, &mut files)?;
    Ok(files)
}

fn collect_record_files_inner(root: &Path, files: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(root)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            collect_record_files_inner(&path, files)?;
            continue;
        }
        if path
            .extension()
            .and_then(|extension| extension.to_str())
            .is_some_and(|extension| {
                matches!(extension.to_ascii_lowercase().as_str(), "md" | "txt")
            })
        {
            files.push(path);
        }
    }
    Ok(())
}
