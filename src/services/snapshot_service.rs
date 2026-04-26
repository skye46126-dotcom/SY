use std::path::Path;

use crate::db::Database;
use crate::error::Result;
use crate::models::{MetricSnapshotSummary, ProjectMetricSnapshotSummary, SnapshotWindow};
use crate::repositories::snapshot_repository::SnapshotRepository;

#[derive(Debug, Clone)]
pub struct SnapshotService {
    database: Database,
}

impl SnapshotService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn recompute_snapshot(
        &self,
        user_id: &str,
        snapshot_date: &str,
        window: SnapshotWindow,
    ) -> Result<MetricSnapshotSummary> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        SnapshotRepository::recompute_snapshot(&mut connection, user_id, snapshot_date, window)
    }

    pub fn get_snapshot(
        &self,
        user_id: &str,
        snapshot_date: &str,
        window: SnapshotWindow,
    ) -> Result<Option<MetricSnapshotSummary>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SnapshotRepository::get_snapshot(&connection, user_id, snapshot_date, window)
    }

    pub fn get_latest_snapshot(
        &self,
        user_id: &str,
        window: SnapshotWindow,
    ) -> Result<Option<MetricSnapshotSummary>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SnapshotRepository::get_latest_snapshot(&connection, user_id, window)
    }

    pub fn list_project_snapshots(
        &self,
        user_id: &str,
        metric_snapshot_id: &str,
    ) -> Result<Vec<ProjectMetricSnapshotSummary>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SnapshotRepository::list_project_snapshots(&connection, user_id, metric_snapshot_id)
    }
}
