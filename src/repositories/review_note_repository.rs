use rusqlite::{Connection, OptionalExtension, params};

use crate::error::{LifeOsError, Result};
use crate::models::{CreateReviewNoteInput, ReviewNote, UpdateReviewNoteInput};
use crate::repositories::record_repository::{ensure_user_exists, new_id, now_string};

pub struct ReviewNoteRepository;

impl ReviewNoteRepository {
    pub fn create(
        connection: &mut Connection,
        input: &CreateReviewNoteInput,
    ) -> Result<ReviewNote> {
        input.validate()?;
        ensure_user_exists(connection, &input.user_id)?;
        let id = new_id();
        let now = now_string();
        let note = ReviewNote {
            id: id.clone(),
            user_id: input.user_id.clone(),
            occurred_on: input.occurred_on.clone(),
            note_type: input.normalized_note_type()?,
            title: input.normalized_title(),
            content: input.normalized_content(),
            source: input.normalized_source()?,
            visibility: input.normalized_visibility()?,
            confidence: input.confidence.map(|value| value.clamp(0.0, 1.0)),
            raw_text: input.normalized_raw_text(),
            linked_record_kind: input.normalized_linked_record_kind()?,
            linked_record_id: input.normalized_linked_record_id(),
            created_at: now.clone(),
            updated_at: now.clone(),
        };
        connection.execute(
            "INSERT INTO review_notes(
                id, user_id, occurred_on, note_type, title, content, source, visibility,
                confidence, raw_text, linked_record_kind, linked_record_id, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?13)",
            params![
                note.id,
                note.user_id,
                note.occurred_on,
                note.note_type,
                note.title,
                note.content,
                note.source,
                note.visibility,
                note.confidence,
                note.raw_text,
                note.linked_record_kind,
                note.linked_record_id,
                note.created_at,
            ],
        )?;
        load_by_id(connection, &id, &input.user_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("failed to load created review note: {id}"))
        })
    }

    pub fn list_for_date(
        connection: &Connection,
        user_id: &str,
        occurred_on: &str,
    ) -> Result<Vec<ReviewNote>> {
        ensure_user_exists(connection, user_id)?;
        crate::models::parse_date("occurred_on", occurred_on)?;
        let mut statement = connection.prepare(
            "SELECT id, user_id, occurred_on, note_type, title, content, source, visibility,
                    confidence, raw_text, linked_record_kind, linked_record_id, created_at, updated_at
             FROM review_notes
             WHERE user_id = ?1
               AND occurred_on = ?2
               AND visibility <> 'hidden'
             ORDER BY created_at ASC, id ASC",
        )?;
        let rows = statement.query_map(params![user_id, occurred_on], map_review_note_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn update(
        connection: &mut Connection,
        note_id: &str,
        input: &UpdateReviewNoteInput,
    ) -> Result<ReviewNote> {
        input.validate()?;
        ensure_user_exists(connection, &input.user_id)?;
        ensure_note_exists(connection, note_id, &input.user_id)?;
        let now = now_string();
        connection.execute(
            "UPDATE review_notes
             SET occurred_on = ?1,
                 note_type = ?2,
                 title = ?3,
                 content = ?4,
                 visibility = ?5,
                 confidence = ?6,
                 raw_text = ?7,
                 linked_record_kind = ?8,
                 linked_record_id = ?9,
                 updated_at = ?10
             WHERE id = ?11
               AND user_id = ?12",
            params![
                input.occurred_on,
                input.normalized_note_type()?,
                input.normalized_title(),
                input.normalized_content(),
                input.normalized_visibility()?,
                input.confidence.map(|value| value.clamp(0.0, 1.0)),
                input.normalized_raw_text(),
                input.normalized_linked_record_kind()?,
                input.normalized_linked_record_id(),
                now,
                note_id,
                input.user_id,
            ],
        )?;
        load_by_id(connection, note_id, &input.user_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("failed to load updated review note: {note_id}"))
        })
    }

    pub fn hide(connection: &mut Connection, user_id: &str, note_id: &str) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        ensure_note_exists(connection, note_id, user_id)?;
        connection.execute(
            "UPDATE review_notes
             SET visibility = 'hidden',
                 updated_at = ?1
             WHERE id = ?2
               AND user_id = ?3",
            params![now_string(), note_id, user_id],
        )?;
        Ok(())
    }

    pub fn list_for_range(
        connection: &Connection,
        user_id: &str,
        start_date: &str,
        end_date: &str,
    ) -> Result<Vec<ReviewNote>> {
        ensure_user_exists(connection, user_id)?;
        crate::models::parse_date("start_date", start_date)?;
        crate::models::parse_date("end_date", end_date)?;
        let mut statement = connection.prepare(
            "SELECT id, user_id, occurred_on, note_type, title, content, source, visibility,
                    confidence, raw_text, linked_record_kind, linked_record_id, created_at, updated_at
             FROM review_notes
             WHERE user_id = ?1
               AND occurred_on >= ?2
               AND occurred_on <= ?3
               AND visibility <> 'hidden'
             ORDER BY occurred_on ASC, created_at ASC, id ASC",
        )?;
        let rows =
            statement.query_map(params![user_id, start_date, end_date], map_review_note_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }
}

fn ensure_note_exists(connection: &Connection, id: &str, user_id: &str) -> Result<()> {
    if load_by_id(connection, id, user_id)?.is_none() {
        return Err(LifeOsError::InvalidInput(format!(
            "review note not found: {id}"
        )));
    }
    Ok(())
}

fn load_by_id(connection: &Connection, id: &str, user_id: &str) -> Result<Option<ReviewNote>> {
    connection
        .query_row(
            "SELECT id, user_id, occurred_on, note_type, title, content, source, visibility,
                    confidence, raw_text, linked_record_kind, linked_record_id, created_at, updated_at
             FROM review_notes
             WHERE id = ?1 AND user_id = ?2",
            params![id, user_id],
            map_review_note_row,
        )
        .optional()
        .map_err(Into::into)
}

fn map_review_note_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<ReviewNote> {
    Ok(ReviewNote {
        id: row.get(0)?,
        user_id: row.get(1)?,
        occurred_on: row.get(2)?,
        note_type: row.get(3)?,
        title: row.get(4)?,
        content: row.get(5)?,
        source: row.get(6)?,
        visibility: row.get(7)?,
        confidence: row.get(8)?,
        raw_text: row.get(9)?,
        linked_record_kind: row.get(10)?,
        linked_record_id: row.get(11)?,
        created_at: row.get(12)?,
        updated_at: row.get(13)?,
    })
}
