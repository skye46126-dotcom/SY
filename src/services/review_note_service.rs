use std::path::Path;

use crate::db::Database;
use crate::error::Result;
use crate::models::{CreateReviewNoteInput, ReviewNote};
use crate::repositories::review_note_repository::ReviewNoteRepository;

#[derive(Debug, Clone)]
pub struct ReviewNoteService {
    database: Database,
}

impl ReviewNoteService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn create_note(&self, input: &CreateReviewNoteInput) -> Result<ReviewNote> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        ReviewNoteRepository::create(&mut connection, input)
    }

    pub fn list_notes_for_date(&self, user_id: &str, occurred_on: &str) -> Result<Vec<ReviewNote>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ReviewNoteRepository::list_for_date(&connection, user_id, occurred_on)
    }

    pub fn list_notes_for_range(
        &self,
        user_id: &str,
        start_date: &str,
        end_date: &str,
    ) -> Result<Vec<ReviewNote>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ReviewNoteRepository::list_for_range(&connection, user_id, start_date, end_date)
    }
}
