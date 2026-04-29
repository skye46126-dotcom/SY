use rusqlite::{Connection, OptionalExtension, params};
use serde_json::Value;

use crate::error::{LifeOsError, Result};
use crate::models::{
    CaptureInboxEntry, CaptureInboxStatus, CreateCaptureInboxEntryInput, ParsePipelineResult,
    ParserMode,
};
use crate::repositories::record_repository::{ensure_user_exists, new_id, now_string};

pub struct CaptureInboxRepository;

impl CaptureInboxRepository {
    pub fn enqueue(
        connection: &mut Connection,
        input: &CreateCaptureInboxEntryInput,
    ) -> Result<CaptureInboxEntry> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        let id = new_id();
        let now = now_string();
        let entry = CaptureInboxEntry {
            id: id.clone(),
            user_id: input.user_id.clone(),
            source: input.normalized_source()?,
            entry_point: input.normalized_entry_point()?,
            raw_text: input.raw_text.trim().to_string(),
            context_date: input.context_date.clone(),
            route_hint: input.normalized_route_hint(),
            record_type_hint: input.normalized_record_type_hint(),
            mode_hint: input.normalized_mode_hint(),
            parser_mode_hint: input.parser_mode_hint.clone(),
            device_context: input.device_context.clone(),
            status: CaptureInboxStatus::Queued,
            request_id: None,
            draft_envelope: None,
            warnings: Vec::new(),
            error_message: None,
            processed_at: None,
            created_at: now.clone(),
            updated_at: now.clone(),
        };
        tx.execute(
            "INSERT INTO capture_inbox(
                id, user_id, source, entry_point, raw_text, context_date, route_hint,
                record_type_hint, mode_hint, parser_mode_hint, device_context_json, status,
                request_id, draft_envelope_json, warnings_json, error_message, processed_at,
                created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, NULL, NULL, '[]', NULL, NULL, ?13, ?13)",
            params![
                entry.id,
                entry.user_id,
                entry.source,
                entry.entry_point,
                entry.raw_text,
                entry.context_date,
                entry.route_hint,
                entry.record_type_hint,
                entry.mode_hint,
                entry.parser_mode_hint.as_ref().map(ParserMode::as_str),
                serialize_optional_value(&entry.device_context)?,
                entry.status.as_str(),
                entry.created_at,
            ],
        )?;
        tx.commit()?;
        Ok(entry)
    }

    pub fn list(
        connection: &Connection,
        user_id: &str,
        status_filter: Option<CaptureInboxStatus>,
        limit: usize,
    ) -> Result<Vec<CaptureInboxEntry>> {
        ensure_user_exists(connection, user_id)?;
        let limit = limit.clamp(1, 200);
        let mut statement = if status_filter.is_some() {
            connection.prepare(
                "SELECT id, user_id, source, entry_point, raw_text, context_date, route_hint,
                        record_type_hint, mode_hint, parser_mode_hint, device_context_json, status,
                        request_id, draft_envelope_json, warnings_json, error_message, processed_at,
                        created_at, updated_at
                 FROM capture_inbox
                 WHERE user_id = ?1 AND status = ?2
                 ORDER BY created_at DESC
                 LIMIT ?3",
            )?
        } else {
            connection.prepare(
                "SELECT id, user_id, source, entry_point, raw_text, context_date, route_hint,
                        record_type_hint, mode_hint, parser_mode_hint, device_context_json, status,
                        request_id, draft_envelope_json, warnings_json, error_message, processed_at,
                        created_at, updated_at
                 FROM capture_inbox
                 WHERE user_id = ?1
                 ORDER BY created_at DESC
                 LIMIT ?2",
            )?
        };
        let rows = match status_filter {
            Some(status) => {
                statement.query_map(params![user_id, status.as_str(), limit], map_row)?
            }
            None => statement.query_map(params![user_id, limit], map_row)?,
        };
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn get(
        connection: &Connection,
        user_id: &str,
        inbox_id: &str,
    ) -> Result<Option<CaptureInboxEntry>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, source, entry_point, raw_text, context_date, route_hint,
                        record_type_hint, mode_hint, parser_mode_hint, device_context_json, status,
                        request_id, draft_envelope_json, warnings_json, error_message, processed_at,
                        created_at, updated_at
                 FROM capture_inbox
                 WHERE user_id = ?1 AND id = ?2
                 LIMIT 1",
                params![user_id, inbox_id],
                map_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn mark_parsing(connection: &mut Connection, user_id: &str, inbox_id: &str) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        let updated = connection.execute(
            "UPDATE capture_inbox
             SET status = 'parsing',
                 error_message = NULL,
                 updated_at = ?3
             WHERE user_id = ?1 AND id = ?2",
            params![user_id, inbox_id, now_string()],
        )?;
        if updated == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "capture inbox entry not found: {inbox_id}"
            )));
        }
        Ok(())
    }

    pub fn save_process_success(
        connection: &mut Connection,
        user_id: &str,
        inbox_id: &str,
        result: &ParsePipelineResult,
    ) -> Result<CaptureInboxEntry> {
        ensure_user_exists(connection, user_id)?;
        let now = now_string();
        let draft_json = serde_json::to_string(result).map_err(|error| {
            LifeOsError::InvalidInput(format!("serialize draft envelope: {error}"))
        })?;
        let warnings_json = serde_json::to_string(&result.warnings)
            .map_err(|error| LifeOsError::InvalidInput(format!("serialize warnings: {error}")))?;
        let updated = connection.execute(
            "UPDATE capture_inbox
             SET status = 'draft_ready',
                 request_id = ?3,
                 draft_envelope_json = ?4,
                 warnings_json = ?5,
                 error_message = NULL,
                 processed_at = ?6,
                 updated_at = ?6
             WHERE user_id = ?1 AND id = ?2",
            params![
                user_id,
                inbox_id,
                result.request_id,
                draft_json,
                warnings_json,
                now
            ],
        )?;
        if updated == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "capture inbox entry not found: {inbox_id}"
            )));
        }
        Self::get(connection, user_id, inbox_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("capture inbox entry not found: {inbox_id}"))
        })
    }

    pub fn save_process_failure(
        connection: &mut Connection,
        user_id: &str,
        inbox_id: &str,
        error_message: &str,
    ) -> Result<CaptureInboxEntry> {
        ensure_user_exists(connection, user_id)?;
        let now = now_string();
        let updated = connection.execute(
            "UPDATE capture_inbox
             SET status = 'failed',
                 error_message = ?3,
                 processed_at = ?4,
                 updated_at = ?4
             WHERE user_id = ?1 AND id = ?2",
            params![user_id, inbox_id, error_message.trim(), now],
        )?;
        if updated == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "capture inbox entry not found: {inbox_id}"
            )));
        }
        Self::get(connection, user_id, inbox_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("capture inbox entry not found: {inbox_id}"))
        })
    }
}

fn map_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CaptureInboxEntry> {
    let parser_mode_hint: Option<String> = row.get(9)?;
    let device_context_json: Option<String> = row.get(10)?;
    let status: String = row.get(11)?;
    let draft_envelope_json: Option<String> = row.get(13)?;
    let warnings_json: String = row.get(14)?;
    Ok(CaptureInboxEntry {
        id: row.get(0)?,
        user_id: row.get(1)?,
        source: row.get(2)?,
        entry_point: row.get(3)?,
        raw_text: row.get(4)?,
        context_date: row.get(5)?,
        route_hint: row.get(6)?,
        record_type_hint: row.get(7)?,
        mode_hint: row.get(8)?,
        parser_mode_hint: parser_mode_hint
            .map(|value| ParserMode::from_str(&value))
            .transpose()
            .map_err(to_sql_error)?,
        device_context: parse_optional_value(device_context_json).map_err(to_sql_error)?,
        status: CaptureInboxStatus::from_str(&status).map_err(to_sql_error)?,
        request_id: row.get(12)?,
        draft_envelope: parse_optional_value(draft_envelope_json).map_err(to_sql_error)?,
        warnings: parse_string_vec(&warnings_json).map_err(to_sql_error)?,
        error_message: row.get(15)?,
        processed_at: row.get(16)?,
        created_at: row.get(17)?,
        updated_at: row.get(18)?,
    })
}

fn serialize_optional_value(value: &Option<Value>) -> Result<Option<String>> {
    value
        .as_ref()
        .map(|value| {
            serde_json::to_string(value).map_err(|error| {
                LifeOsError::InvalidInput(format!("serialize capture inbox value: {error}"))
            })
        })
        .transpose()
}

fn parse_optional_value(value: Option<String>) -> Result<Option<Value>> {
    value
        .as_deref()
        .map(|value| {
            serde_json::from_str(value).map_err(|error| {
                LifeOsError::InvalidInput(format!("parse capture inbox JSON payload: {error}"))
            })
        })
        .transpose()
}

fn parse_string_vec(value: &str) -> Result<Vec<String>> {
    serde_json::from_str(value).map_err(|error| {
        LifeOsError::InvalidInput(format!("parse capture inbox warnings JSON: {error}"))
    })
}

fn to_sql_error(error: LifeOsError) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(error))
}
