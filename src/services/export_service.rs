use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

use rusqlite::types::ValueRef;
use rusqlite::{Connection, ToSql};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};

use crate::db::Database;
use crate::error::{LifeOsError, Result};

#[derive(Debug, Deserialize)]
pub struct DataPackageExportInput {
    pub user_id: String,
    pub format: String,
    pub output_dir: String,
    pub title: String,
    pub module: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ExportArtifactOutput {
    pub id: String,
    #[serde(rename = "type")]
    pub artifact_type: String,
    pub format: String,
    pub module: String,
    pub title: String,
    pub file_path: String,
    pub metadata_path: String,
    pub preview_path: Option<String>,
    pub created_at: String,
    pub metadata: Value,
}

#[derive(Debug, Serialize)]
pub struct ExportResultOutput {
    pub artifacts: Vec<ExportArtifactOutput>,
    pub message: String,
}

pub struct ExportService {
    database: Database,
}

impl ExportService {
    pub fn new(database_path: impl Into<PathBuf>) -> Self {
        Self {
            database: Database::new(database_path.into()),
        }
    }

    pub fn export_seed_data(&self, user_id: &str) -> Result<Value> {
        self.database.initialize()?;
        let connection = self.database.connect()?;

        Ok(json!({
            "user_id": user_id,
            "generated_at": chrono::Utc::now().to_rfc3339(),
            "profile": query_one_as_json(
                &connection,
                "SELECT * FROM users WHERE id = ?1 LIMIT 1",
                &[&user_id],
            )?,
            "settings": query_rows_as_json(
                &connection,
                "SELECT * FROM settings WHERE user_id = ?1 ORDER BY key",
                &[&user_id],
            )?,
            "projects": query_rows_as_json(
                &connection,
                "SELECT * FROM projects WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "tags": query_rows_as_json(
                &connection,
                "SELECT * FROM tags WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "time_records": query_rows_as_json(
                &connection,
                "SELECT * FROM time_records WHERE user_id = ?1 ORDER BY occurred_on, started_at, created_at",
                &[&user_id],
            )?,
            "income_records": query_rows_as_json(
                &connection,
                "SELECT * FROM income_records WHERE user_id = ?1 ORDER BY occurred_on, created_at",
                &[&user_id],
            )?,
            "expense_records": query_rows_as_json(
                &connection,
                "SELECT * FROM expense_records WHERE user_id = ?1 ORDER BY occurred_on, created_at",
                &[&user_id],
            )?,
            "record_project_links": query_rows_as_json(
                &connection,
                "SELECT * FROM record_project_links WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "record_tag_links": query_rows_as_json(
                &connection,
                "SELECT * FROM record_tag_links WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "expense_baseline_months": query_rows_as_json(
                &connection,
                "SELECT * FROM expense_baseline_months WHERE user_id = ?1 ORDER BY month",
                &[&user_id],
            )?,
            "expense_recurring_rules": query_rows_as_json(
                &connection,
                "SELECT * FROM expense_recurring_rules WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "expense_capex_items": query_rows_as_json(
                &connection,
                "SELECT * FROM expense_capex_items WHERE user_id = ?1 ORDER BY purchase_date, created_at",
                &[&user_id],
            )?,
            "daily_reviews": query_rows_as_json(
                &connection,
                "SELECT * FROM daily_reviews WHERE user_id = ?1 ORDER BY review_date",
                &[&user_id],
            )?,
            "metric_snapshots": query_rows_as_json(
                &connection,
                "SELECT * FROM metric_snapshots WHERE user_id = ?1 ORDER BY snapshot_date, generated_at",
                &[&user_id],
            )?,
            "metric_snapshot_projects": query_rows_as_json(
                &connection,
                concat!(
                    "SELECT msp.* FROM metric_snapshot_projects msp ",
                    "JOIN metric_snapshots ms ON ms.id = msp.metric_snapshot_id ",
                    "WHERE ms.user_id = ?1 ",
                    "ORDER BY ms.snapshot_date, msp.project_id"
                ),
                &[&user_id],
            )?,
            "backup_records": query_rows_as_json(
                &connection,
                "SELECT * FROM backup_records WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "restore_records": query_rows_as_json(
                &connection,
                "SELECT * FROM restore_records WHERE user_id = ?1 ORDER BY restored_at",
                &[&user_id],
            )?,
            "ai_service_configs": query_rows_as_json(
                &connection,
                "SELECT * FROM ai_service_configs WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "cloud_sync_configs": query_rows_as_json(
                &connection,
                "SELECT * FROM cloud_sync_configs WHERE user_id = ?1 ORDER BY created_at",
                &[&user_id],
            )?,
            "review_snapshots": query_rows_as_json(
                &connection,
                "SELECT * FROM review_snapshots WHERE user_id = ?1 ORDER BY generated_at",
                &[&user_id],
            )?,
            "dimension_options": query_rows_as_json(
                &connection,
                "SELECT * FROM dimension_options WHERE user_id = ?1 OR user_id IS NULL ORDER BY dimension_kind, sort_order, code",
                &[&user_id],
            )?,
            "dimension_tables": {
                "project_status": query_rows_as_json(
                    &connection,
                    "SELECT * FROM dim_project_status ORDER BY sort_order, code",
                    &[],
                )?,
                "time_categories": query_rows_as_json(
                    &connection,
                    "SELECT * FROM dim_time_categories ORDER BY sort_order, code",
                    &[],
                )?,
                "income_types": query_rows_as_json(
                    &connection,
                    "SELECT * FROM dim_income_types ORDER BY sort_order, code",
                    &[],
                )?,
                "expense_categories": query_rows_as_json(
                    &connection,
                    "SELECT * FROM dim_expense_categories ORDER BY sort_order, code",
                    &[],
                )?,
                "learning_levels": query_rows_as_json(
                    &connection,
                    "SELECT * FROM dim_learning_levels ORDER BY sort_order, code",
                    &[],
                )?,
            }
        }))
    }

    pub fn export_data_package(
        &self,
        input: &DataPackageExportInput,
    ) -> Result<ExportResultOutput> {
        let data = self.export_seed_data(&input.user_id)?;
        let output_dir = PathBuf::from(input.output_dir.trim());
        if output_dir.as_os_str().is_empty() {
            return Err(LifeOsError::InvalidInput(
                "data package output_dir is required".to_string(),
            ));
        }
        fs::create_dir_all(&output_dir)?;

        let module = input
            .module
            .as_deref()
            .map(slug)
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| "data_package".to_string());
        let base_name = file_safe_name(&input.title);

        match input.format.trim().to_ascii_lowercase().as_str() {
            "json" => {
                self.export_data_package_json(&data, &output_dir, &base_name, &input.title, &module)
            }
            "csv" => {
                self.export_data_package_csv(&data, &output_dir, &base_name, &input.title, &module)
            }
            "zip" => {
                self.export_data_package_zip(&data, &output_dir, &base_name, &input.title, &module)
            }
            format => Err(LifeOsError::InvalidInput(format!(
                "unsupported data package export format: {format}"
            ))),
        }
    }

    pub fn preview_data_package(&self, user_id: &str) -> Result<Value> {
        let data = self.export_seed_data(user_id)?;
        Ok(table_counts(&data))
    }

    fn export_data_package_json(
        &self,
        data: &Value,
        output_dir: &Path,
        base_name: &str,
        title: &str,
        module: &str,
    ) -> Result<ExportResultOutput> {
        let file_path = output_dir.join(format!("{base_name}.json"));
        fs::write(&file_path, pretty_json(data)?)?;
        let artifact = data_package_artifact(
            &file_path,
            "json",
            module,
            title,
            json!({ "tables": table_counts(data) }),
        );
        Ok(ExportResultOutput {
            artifacts: vec![artifact],
            message: "data package json exported".to_string(),
        })
    }

    fn export_data_package_csv(
        &self,
        data: &Value,
        output_dir: &Path,
        base_name: &str,
        title: &str,
        module: &str,
    ) -> Result<ExportResultOutput> {
        let csv_dir = output_dir.join(format!("{base_name}-csv"));
        fs::create_dir_all(&csv_dir)?;
        let mut artifacts = Vec::new();
        for (table_name, rows) in export_tables(data) {
            if rows.is_empty() {
                continue;
            }
            let file_path = csv_dir.join(format!("{}.csv", slug(&table_name)));
            fs::write(&file_path, rows_to_csv(&rows))?;
            artifacts.push(data_package_artifact(
                &file_path,
                "csv",
                &format!("{}_{}", module, slug(&table_name)),
                &format!("{title} · {table_name}"),
                json!({
                    "table": table_name,
                    "row_count": rows.len(),
                }),
            ));
        }
        Ok(ExportResultOutput {
            artifacts,
            message: "data package csv exported".to_string(),
        })
    }

    fn export_data_package_zip(
        &self,
        data: &Value,
        output_dir: &Path,
        base_name: &str,
        title: &str,
        module: &str,
    ) -> Result<ExportResultOutput> {
        let generated_at = chrono::Utc::now().to_rfc3339();
        let manifest = json!({
            "title": title,
            "generated_at": generated_at,
            "tables": table_counts(data),
        });
        let mut zip = ZipStoreBuilder::new();
        zip.add_file(format!("{base_name}.json"), pretty_json(data)?.into_bytes())?;
        zip.add_file("manifest.json", pretty_json(&manifest)?.into_bytes())?;
        for (table_name, rows) in export_tables(data) {
            if rows.is_empty() {
                continue;
            }
            zip.add_file(
                format!("csv/{}.csv", slug(&table_name)),
                rows_to_csv(&rows).into_bytes(),
            )?;
        }

        let file_path = output_dir.join(format!("{base_name}.zip"));
        fs::write(&file_path, zip.finish()?)?;
        let artifact = data_package_artifact(&file_path, "zip", module, title, manifest);
        Ok(ExportResultOutput {
            artifacts: vec![artifact],
            message: "data package zip exported".to_string(),
        })
    }
}

fn query_one_as_json(connection: &Connection, sql: &str, params: &[&dyn ToSql]) -> Result<Value> {
    let rows = query_rows_as_json(connection, sql, params)?;
    Ok(rows.into_iter().next().unwrap_or(Value::Null))
}

fn query_rows_as_json(
    connection: &Connection,
    sql: &str,
    params: &[&dyn ToSql],
) -> Result<Vec<Value>> {
    let mut statement = connection.prepare(sql)?;
    let column_names = statement
        .column_names()
        .into_iter()
        .map(|name| name.to_string())
        .collect::<Vec<_>>();
    let mut rows = statement.query(params)?;
    let mut items = Vec::new();
    while let Some(row) = rows.next()? {
        let mut object = Map::new();
        for (index, name) in column_names.iter().enumerate() {
            let value = match row.get_ref(index)? {
                ValueRef::Null => Value::Null,
                ValueRef::Integer(v) => Value::from(v),
                ValueRef::Real(v) => Value::from(v),
                ValueRef::Text(v) => Value::from(String::from_utf8_lossy(v).to_string()),
                ValueRef::Blob(v) => Value::from(hex_bytes(v)),
            };
            object.insert(name.clone(), value);
        }
        items.push(Value::Object(object));
    }
    Ok(items)
}

fn hex_bytes(bytes: &[u8]) -> String {
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        use std::fmt::Write as _;
        let _ = write!(&mut output, "{byte:02x}");
    }
    output
}

fn data_package_artifact(
    file_path: &Path,
    format: &str,
    module: &str,
    title: &str,
    metadata: Value,
) -> ExportArtifactOutput {
    let path = file_path.to_string_lossy().to_string();
    ExportArtifactOutput {
        id: path.clone(),
        artifact_type: "data_package".to_string(),
        format: format.to_string(),
        module: module.to_string(),
        title: title.to_string(),
        file_path: path,
        metadata_path: String::new(),
        preview_path: None,
        created_at: chrono::Utc::now().to_rfc3339(),
        metadata,
    }
}

fn pretty_json(value: &Value) -> Result<String> {
    serde_json::to_string_pretty(value).map_err(|error| {
        LifeOsError::InvalidInput(format!("failed to serialize export json: {error}"))
    })
}

fn export_tables(data: &Value) -> Vec<(String, Vec<Map<String, Value>>)> {
    let mut tables = Vec::new();
    let Some(object) = data.as_object() else {
        return tables;
    };

    for (key, value) in object {
        if let Some(rows) = json_rows(value) {
            tables.push((key.clone(), rows));
        } else if key == "dimension_tables" {
            if let Some(dimensions) = value.as_object() {
                for (dimension_key, dimension_value) in dimensions {
                    if let Some(rows) = json_rows(dimension_value) {
                        tables.push((format!("dimension_tables_{dimension_key}"), rows));
                    }
                }
            }
        }
    }
    tables
}

fn json_rows(value: &Value) -> Option<Vec<Map<String, Value>>> {
    let rows = value
        .as_array()?
        .iter()
        .filter_map(|item| item.as_object().cloned())
        .collect::<Vec<_>>();
    Some(rows)
}

fn table_counts(data: &Value) -> Value {
    let mut counts = Map::new();
    let Some(object) = data.as_object() else {
        return Value::Object(counts);
    };

    for (key, value) in object {
        if let Some(rows) = value.as_array() {
            counts.insert(key.clone(), Value::from(rows.len()));
        } else if key == "dimension_tables" {
            if let Some(dimensions) = value.as_object() {
                for (dimension_key, dimension_value) in dimensions {
                    if let Some(rows) = dimension_value.as_array() {
                        counts.insert(
                            format!("dimension_tables.{dimension_key}"),
                            Value::from(rows.len()),
                        );
                    }
                }
            }
        }
    }
    Value::Object(counts)
}

fn rows_to_csv(rows: &[Map<String, Value>]) -> String {
    let mut columns = BTreeSet::new();
    for row in rows {
        columns.extend(row.keys().cloned());
    }
    let ordered_columns = columns.into_iter().collect::<Vec<_>>();
    let mut output = String::new();
    output.push_str(
        &ordered_columns
            .iter()
            .map(|column| csv_cell(&Value::from(column.clone())))
            .collect::<Vec<_>>()
            .join(","),
    );
    output.push('\n');
    for row in rows {
        output.push_str(
            &ordered_columns
                .iter()
                .map(|column| csv_cell(row.get(column).unwrap_or(&Value::Null)))
                .collect::<Vec<_>>()
                .join(","),
        );
        output.push('\n');
    }
    output
}

fn csv_cell(value: &Value) -> String {
    let text = match value {
        Value::Null => String::new(),
        Value::String(value) => value.clone(),
        Value::Bool(value) => value.to_string(),
        Value::Number(value) => value.to_string(),
        Value::Array(_) | Value::Object(_) => value.to_string(),
    }
    .replace('"', "\"\"");
    format!("\"{text}\"")
}

fn file_safe_name(value: &str) -> String {
    let timestamp = chrono::Utc::now().to_rfc3339().replace(':', "-");
    let base = slug(value);
    format!(
        "{}_{}",
        if base.is_empty() {
            "data_package"
        } else {
            &base
        },
        timestamp
    )
}

fn slug(value: &str) -> String {
    let mut output = String::new();
    let mut previous_underscore = false;
    for character in value.trim().to_lowercase().chars() {
        let keep =
            character.is_ascii_alphanumeric() || ('\u{4e00}'..='\u{9fa5}').contains(&character);
        if keep {
            output.push(character);
            previous_underscore = false;
        } else if !previous_underscore && !output.is_empty() {
            output.push('_');
            previous_underscore = true;
        }
    }
    while output.ends_with('_') {
        output.pop();
    }
    output
}

struct ZipStoreEntry {
    name: String,
    data: Vec<u8>,
    crc32: u32,
    offset: u32,
}

struct ZipStoreBuilder {
    entries: Vec<ZipStoreEntry>,
    bytes: Vec<u8>,
}

impl ZipStoreBuilder {
    fn new() -> Self {
        Self {
            entries: Vec::new(),
            bytes: Vec::new(),
        }
    }

    fn add_file(&mut self, name: impl Into<String>, data: Vec<u8>) -> Result<()> {
        let name = name.into();
        let name_bytes = name.as_bytes();
        let data_len = checked_u32(data.len(), "zip file is too large")?;
        let name_len = checked_u16(name_bytes.len(), "zip file name is too long")?;
        let offset = checked_u32(self.bytes.len(), "zip archive is too large")?;
        let crc32 = crc32(&data);

        write_u32(&mut self.bytes, 0x0403_4b50);
        write_u16(&mut self.bytes, 20);
        write_u16(&mut self.bytes, 0);
        write_u16(&mut self.bytes, 0);
        write_u16(&mut self.bytes, 0);
        write_u16(&mut self.bytes, 0);
        write_u32(&mut self.bytes, crc32);
        write_u32(&mut self.bytes, data_len);
        write_u32(&mut self.bytes, data_len);
        write_u16(&mut self.bytes, name_len);
        write_u16(&mut self.bytes, 0);
        self.bytes.extend_from_slice(name_bytes);
        self.bytes.extend_from_slice(&data);

        self.entries.push(ZipStoreEntry {
            name,
            data,
            crc32,
            offset,
        });
        Ok(())
    }

    fn finish(mut self) -> Result<Vec<u8>> {
        let central_directory_offset = checked_u32(self.bytes.len(), "zip archive is too large")?;
        for entry in &self.entries {
            let name_bytes = entry.name.as_bytes();
            let name_len = checked_u16(name_bytes.len(), "zip file name is too long")?;
            let data_len = checked_u32(entry.data.len(), "zip file is too large")?;
            write_u32(&mut self.bytes, 0x0201_4b50);
            write_u16(&mut self.bytes, 20);
            write_u16(&mut self.bytes, 20);
            write_u16(&mut self.bytes, 0);
            write_u16(&mut self.bytes, 0);
            write_u16(&mut self.bytes, 0);
            write_u16(&mut self.bytes, 0);
            write_u32(&mut self.bytes, entry.crc32);
            write_u32(&mut self.bytes, data_len);
            write_u32(&mut self.bytes, data_len);
            write_u16(&mut self.bytes, name_len);
            write_u16(&mut self.bytes, 0);
            write_u16(&mut self.bytes, 0);
            write_u16(&mut self.bytes, 0);
            write_u16(&mut self.bytes, 0);
            write_u32(&mut self.bytes, 0);
            write_u32(&mut self.bytes, entry.offset);
            self.bytes.extend_from_slice(name_bytes);
        }
        let central_directory_size = checked_u32(
            self.bytes.len() - central_directory_offset as usize,
            "zip archive is too large",
        )?;
        let entry_count = checked_u16(self.entries.len(), "zip archive has too many files")?;
        write_u32(&mut self.bytes, 0x0605_4b50);
        write_u16(&mut self.bytes, 0);
        write_u16(&mut self.bytes, 0);
        write_u16(&mut self.bytes, entry_count);
        write_u16(&mut self.bytes, entry_count);
        write_u32(&mut self.bytes, central_directory_size);
        write_u32(&mut self.bytes, central_directory_offset);
        write_u16(&mut self.bytes, 0);
        Ok(self.bytes)
    }
}

fn checked_u16(value: usize, message: &str) -> Result<u16> {
    u16::try_from(value).map_err(|_| LifeOsError::InvalidInput(message.to_string()))
}

fn checked_u32(value: usize, message: &str) -> Result<u32> {
    u32::try_from(value).map_err(|_| LifeOsError::InvalidInput(message.to_string()))
}

fn write_u16(bytes: &mut Vec<u8>, value: u16) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

fn write_u32(bytes: &mut Vec<u8>, value: u32) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

fn crc32(bytes: &[u8]) -> u32 {
    let mut crc = 0xffff_ffffu32;
    for byte in bytes {
        crc ^= u32::from(*byte);
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xedb8_8320 & mask);
        }
    }
    !crc
}
