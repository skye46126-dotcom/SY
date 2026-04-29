use std::path::Path;

use crate::db::Database;
use crate::error::{LifeOsError, Result};
use crate::models::{
    AiParseInput, CaptureInboxEntry, CaptureInboxProcessResult, CaptureInboxStatus,
    CreateCaptureInboxEntryInput, ProcessCaptureInboxInput,
};
use crate::repositories::capture_inbox_repository::CaptureInboxRepository;
use crate::services::ai_service::AiService;

#[derive(Debug, Clone)]
pub struct CaptureService {
    database: Database,
}

impl CaptureService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn enqueue_capture_inbox(
        &self,
        input: &CreateCaptureInboxEntryInput,
    ) -> Result<CaptureInboxEntry> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        CaptureInboxRepository::enqueue(&mut connection, input)
    }

    pub fn list_capture_inbox(
        &self,
        user_id: &str,
        status_filter: Option<CaptureInboxStatus>,
        limit: usize,
    ) -> Result<Vec<CaptureInboxEntry>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CaptureInboxRepository::list(&connection, user_id, status_filter, limit)
    }

    pub fn get_capture_inbox(
        &self,
        user_id: &str,
        inbox_id: &str,
    ) -> Result<Option<CaptureInboxEntry>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CaptureInboxRepository::get(&connection, user_id, inbox_id)
    }

    pub fn process_capture_inbox(
        &self,
        input: &ProcessCaptureInboxInput,
    ) -> Result<CaptureInboxProcessResult> {
        self.database.initialize()?;
        input.validate()?;

        let mut connection = self.database.connect()?;
        let entry = CaptureInboxRepository::get(&connection, &input.user_id, &input.inbox_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput(format!(
                    "capture inbox entry not found: {}",
                    input.inbox_id
                ))
            })?;
        CaptureInboxRepository::mark_parsing(&mut connection, &input.user_id, &input.inbox_id)?;
        drop(connection);

        let parse_result = AiService::new(self.database.path()).parse_input_v2(&AiParseInput {
            user_id: input.user_id.clone(),
            raw_text: entry.raw_text.clone(),
            context_date: entry.context_date.clone(),
            parser_mode_override: input
                .parser_mode_override
                .clone()
                .or(entry.parser_mode_hint.clone()),
        });

        match parse_result {
            Ok(draft_envelope) => {
                let mut connection = self.database.connect()?;
                let updated_entry = CaptureInboxRepository::save_process_success(
                    &mut connection,
                    &input.user_id,
                    &input.inbox_id,
                    &draft_envelope,
                )?;
                Ok(CaptureInboxProcessResult {
                    entry: updated_entry,
                    draft_envelope,
                })
            }
            Err(error) => {
                let mut connection = self.database.connect()?;
                let _ = CaptureInboxRepository::save_process_failure(
                    &mut connection,
                    &input.user_id,
                    &input.inbox_id,
                    &error.to_string(),
                );
                Err(error)
            }
        }
    }
}
