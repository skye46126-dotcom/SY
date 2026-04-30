use rusqlite::{Connection, OptionalExtension, params};

use crate::error::{LifeOsError, Result};
use crate::models::{
    CaptureBufferItem, CaptureBufferSession, CaptureBufferSessionStatus,
    CreateCaptureBufferSessionInput, ParserMode, normalize_optional_string,
};
use crate::repositories::record_repository::{ensure_user_exists, new_id, now_string};

pub struct CaptureBufferRepository;

impl CaptureBufferRepository {
    pub fn get_active_session(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Option<CaptureBufferSession>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, source, entry_point, context_date, route_hint, mode_hint,
                        parser_mode_hint, status, item_count, latest_combined_text, latest_inbox_id,
                        processed_at, created_at, updated_at
                 FROM capture_buffer_sessions
                 WHERE user_id = ?1 AND status = 'active'
                 ORDER BY updated_at DESC
                 LIMIT 1",
                [user_id],
                map_session_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn create_session(
        connection: &mut Connection,
        input: &CreateCaptureBufferSessionInput,
    ) -> Result<CaptureBufferSession> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        let id = new_id();
        let now = now_string();
        let session = CaptureBufferSession {
            id: id.clone(),
            user_id: input.user_id.clone(),
            source: input.normalized_source()?,
            entry_point: input.normalized_entry_point()?,
            context_date: input.context_date.clone(),
            route_hint: normalize_optional_string(&input.route_hint),
            mode_hint: normalize_optional_string(&input.mode_hint)
                .map(|value| value.to_lowercase()),
            parser_mode_hint: input.parser_mode_hint.clone(),
            status: CaptureBufferSessionStatus::Active,
            item_count: 0,
            latest_combined_text: None,
            latest_inbox_id: None,
            processed_at: None,
            created_at: now.clone(),
            updated_at: now.clone(),
        };
        tx.execute(
            "INSERT INTO capture_buffer_sessions(
                id, user_id, source, entry_point, context_date, route_hint, mode_hint,
                parser_mode_hint, status, item_count, latest_combined_text, latest_inbox_id,
                processed_at, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 0, NULL, NULL, NULL, ?10, ?10)",
            params![
                session.id,
                session.user_id,
                session.source,
                session.entry_point,
                session.context_date,
                session.route_hint,
                session.mode_hint,
                session.parser_mode_hint.as_ref().map(ParserMode::as_str),
                session.status.as_str(),
                session.created_at,
            ],
        )?;
        tx.commit()?;
        Ok(session)
    }

    pub fn get_session(
        connection: &Connection,
        user_id: &str,
        session_id: &str,
    ) -> Result<Option<CaptureBufferSession>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, source, entry_point, context_date, route_hint, mode_hint,
                        parser_mode_hint, status, item_count, latest_combined_text, latest_inbox_id,
                        processed_at, created_at, updated_at
                 FROM capture_buffer_sessions
                 WHERE user_id = ?1 AND id = ?2
                 LIMIT 1",
                params![user_id, session_id],
                map_session_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn append_item(
        connection: &mut Connection,
        session: &CaptureBufferSession,
        raw_text: &str,
        source: &str,
        input_kind: &str,
    ) -> Result<CaptureBufferItem> {
        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &session.user_id)?;
        let sequence_no: i64 = tx.query_row(
            "SELECT COALESCE(MAX(sequence_no), 0) + 1
             FROM capture_buffer_items
             WHERE session_id = ?1",
            [session.id.as_str()],
            |row| row.get(0),
        )?;
        let id = new_id();
        let now = now_string();
        let item = CaptureBufferItem {
            id: id.clone(),
            session_id: session.id.clone(),
            user_id: session.user_id.clone(),
            sequence_no,
            raw_text: raw_text.trim().to_string(),
            source: source.to_string(),
            input_kind: input_kind.to_string(),
            created_at: now.clone(),
            updated_at: now.clone(),
        };
        tx.execute(
            "INSERT INTO capture_buffer_items(
                id, session_id, user_id, sequence_no, raw_text, source, input_kind, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8)",
            params![
                item.id,
                item.session_id,
                item.user_id,
                item.sequence_no,
                item.raw_text,
                item.source,
                item.input_kind,
                item.created_at,
            ],
        )?;
        tx.execute(
            "UPDATE capture_buffer_sessions
             SET item_count = item_count + 1,
                 updated_at = ?2
             WHERE id = ?1",
            params![session.id, now],
        )?;
        tx.commit()?;
        Ok(item)
    }

    pub fn list_items(
        connection: &Connection,
        user_id: &str,
        session_id: &str,
    ) -> Result<Vec<CaptureBufferItem>> {
        ensure_user_exists(connection, user_id)?;
        let mut statement = connection.prepare(
            "SELECT id, session_id, user_id, sequence_no, raw_text, source, input_kind, created_at, updated_at
             FROM capture_buffer_items
             WHERE user_id = ?1 AND session_id = ?2
             ORDER BY sequence_no ASC, created_at ASC",
        )?;
        let rows = statement.query_map(params![user_id, session_id], map_item_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn delete_item(
        connection: &mut Connection,
        user_id: &str,
        session_id: &str,
        item_id: &str,
    ) -> Result<()> {
        let tx = connection.transaction()?;
        ensure_user_exists(&tx, user_id)?;
        let deleted = tx.execute(
            "DELETE FROM capture_buffer_items
             WHERE id = ?1 AND session_id = ?2 AND user_id = ?3",
            params![item_id, session_id, user_id],
        )?;
        if deleted == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "capture buffer item not found: {item_id}"
            )));
        }
        tx.execute(
            "UPDATE capture_buffer_sessions
             SET item_count = (SELECT COUNT(*) FROM capture_buffer_items WHERE session_id = ?1),
                 updated_at = ?2
             WHERE id = ?1 AND user_id = ?3",
            params![session_id, now_string(), user_id],
        )?;
        tx.commit()?;
        Ok(())
    }

    pub fn mark_processed(
        connection: &mut Connection,
        user_id: &str,
        session_id: &str,
        latest_combined_text: &str,
        latest_inbox_id: &str,
        committed: bool,
    ) -> Result<CaptureBufferSession> {
        ensure_user_exists(connection, user_id)?;
        let now = now_string();
        let status = if committed { "committed" } else { "processed" };
        let updated = connection.execute(
            "UPDATE capture_buffer_sessions
             SET status = ?3,
                 latest_combined_text = ?4,
                 latest_inbox_id = ?5,
                 processed_at = ?6,
                 updated_at = ?6
             WHERE id = ?1 AND user_id = ?2",
            params![
                session_id,
                user_id,
                status,
                latest_combined_text,
                latest_inbox_id,
                now
            ],
        )?;
        if updated == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "capture buffer session not found: {session_id}"
            )));
        }
        Self::get_session(connection, user_id, session_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("capture buffer session not found: {session_id}"))
        })
    }
}

fn map_session_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CaptureBufferSession> {
    let parser_mode_hint: Option<String> = row.get(7)?;
    let status: String = row.get(8)?;
    Ok(CaptureBufferSession {
        id: row.get(0)?,
        user_id: row.get(1)?,
        source: row.get(2)?,
        entry_point: row.get(3)?,
        context_date: row.get(4)?,
        route_hint: row.get(5)?,
        mode_hint: row.get(6)?,
        parser_mode_hint: parser_mode_hint
            .map(|value| ParserMode::from_str(&value))
            .transpose()
            .map_err(to_sql_error)?,
        status: CaptureBufferSessionStatus::from_str(&status).map_err(to_sql_error)?,
        item_count: row.get::<_, i64>(9)? as usize,
        latest_combined_text: row.get(10)?,
        latest_inbox_id: row.get(11)?,
        processed_at: row.get(12)?,
        created_at: row.get(13)?,
        updated_at: row.get(14)?,
    })
}

fn map_item_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CaptureBufferItem> {
    Ok(CaptureBufferItem {
        id: row.get(0)?,
        session_id: row.get(1)?,
        user_id: row.get(2)?,
        sequence_no: row.get(3)?,
        raw_text: row.get(4)?,
        source: row.get(5)?,
        input_kind: row.get(6)?,
        created_at: row.get(7)?,
        updated_at: row.get(8)?,
    })
}

fn to_sql_error(error: LifeOsError) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(error))
}
