use std::path::Path;

use crate::ai::AiParseOrchestrator;
use crate::db::Database;
use crate::error::Result;
use crate::models::{
    AiCommitInput, AiCommitResult, AiParseInput, AiParseResult, AiServiceConfig,
    CreateAiServiceConfigInput,
};
use crate::repositories::ai_repository::AiRepository;

#[derive(Clone)]
pub struct AiService {
    database: Database,
    orchestrator: AiParseOrchestrator,
}

impl AiService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
            orchestrator: AiParseOrchestrator::default(),
        }
    }

    pub fn with_orchestrator(
        database_path: impl Into<std::path::PathBuf>,
        orchestrator: AiParseOrchestrator,
    ) -> Self {
        Self {
            database: Database::new(database_path),
            orchestrator,
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn create_service_config(
        &self,
        input: &CreateAiServiceConfigInput,
    ) -> Result<AiServiceConfig> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::create_service_config(&mut connection, input)
    }

    pub fn update_service_config(
        &self,
        config_id: &str,
        input: &CreateAiServiceConfigInput,
    ) -> Result<AiServiceConfig> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::update_service_config(&mut connection, config_id, input)
    }

    pub fn delete_service_config(&self, user_id: &str, config_id: &str) -> Result<()> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::delete_service_config(&mut connection, user_id, config_id)
    }

    pub fn list_service_configs(&self, user_id: &str) -> Result<Vec<AiServiceConfig>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        AiRepository::list_service_configs(&connection, user_id)
    }

    pub fn get_active_service_config(&self, user_id: &str) -> Result<Option<AiServiceConfig>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        AiRepository::get_active_service_config(&connection, user_id)
    }

    pub fn parse_input(&self, input: &AiParseInput) -> Result<AiParseResult> {
        self.database.initialize()?;
        input.validate()?;
        let connection = self.database.connect()?;
        let config = AiRepository::get_active_service_config(&connection, &input.user_id)?;
        let context = AiRepository::load_parse_context(&connection, &input.user_id)?;
        let parser_mode = input
            .parser_mode_override
            .clone()
            .or_else(|| config.as_ref().map(|config| config.parser_mode.clone()))
            .unwrap_or(crate::models::ParserMode::Auto);
        Ok(self
            .orchestrator
            .parse(input, &context, config.as_ref(), parser_mode))
    }

    pub fn commit_drafts(&self, input: &AiCommitInput) -> Result<AiCommitResult> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::commit_drafts(&mut connection, input)
    }
}
