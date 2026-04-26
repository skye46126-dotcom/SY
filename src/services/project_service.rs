use std::path::Path;

use crate::db::Database;
use crate::error::Result;
use crate::models::{CreateProjectInput, Project, ProjectDetail, ProjectOption, ProjectOverview};
use crate::repositories::project_repository::ProjectRepository;
use crate::repositories::record_repository::RecordRepository;

#[derive(Debug, Clone)]
pub struct ProjectService {
    database: Database,
}

impl ProjectService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn create_project(&self, input: &CreateProjectInput) -> Result<Project> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::create_project(&mut connection, input)
    }

    pub fn update_project_record(
        &self,
        project_id: &str,
        input: &CreateProjectInput,
    ) -> Result<Project> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        ProjectRepository::update_project_record(&mut connection, project_id, input)
    }

    pub fn update_project_state(
        &self,
        project_id: &str,
        user_id: &str,
        status_code: &str,
        score: Option<i32>,
        note: Option<String>,
        ended_on: Option<String>,
    ) -> Result<Project> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        ProjectRepository::update_project_state(
            &mut connection,
            project_id,
            user_id,
            status_code,
            score,
            note,
            ended_on,
        )
    }

    pub fn delete_project(&self, user_id: &str, project_id: &str) -> Result<()> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        ProjectRepository::soft_delete_project(&mut connection, user_id, project_id)
    }

    pub fn get_project_options(
        &self,
        user_id: &str,
        include_done: bool,
    ) -> Result<Vec<ProjectOption>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ProjectRepository::list_project_options(&connection, user_id, include_done)
    }

    pub fn list_projects(
        &self,
        user_id: &str,
        status_filter: Option<&str>,
    ) -> Result<Vec<ProjectOverview>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ProjectRepository::list_projects(&connection, user_id, status_filter)
    }

    pub fn get_project_detail(
        &self,
        user_id: &str,
        project_id: &str,
        timezone: &str,
        recent_limit: usize,
    ) -> Result<Option<ProjectDetail>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ProjectRepository::get_project_detail(
            &connection,
            user_id,
            project_id,
            timezone,
            recent_limit,
        )
    }
}
