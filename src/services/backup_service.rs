use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use chrono::{SecondsFormat, Utc};

use crate::cloud::{CloudSyncTransport, CurlCloudSyncTransport};
use crate::db::Database;
use crate::error::{LifeOsError, Result};
use crate::models::{
    BackupRecord, BackupResult, BackupType, CloudSyncConfig, CreateCloudSyncConfigInput,
    RemoteBackupFile, RemoteUploadResult, RestoreRecord, RestoreResult,
};
use crate::repositories::sync_repository::SyncRepository;

#[derive(Clone)]
pub struct BackupService {
    database: Database,
    backup_root: PathBuf,
    transport: Arc<dyn CloudSyncTransport>,
}

impl BackupService {
    pub fn new(database_path: impl Into<PathBuf>) -> Self {
        let database_path = database_path.into();
        Self {
            backup_root: default_backup_root(&database_path),
            database: Database::new(database_path),
            transport: Arc::new(CurlCloudSyncTransport),
        }
    }

    pub fn with_transport(
        database_path: impl Into<PathBuf>,
        backup_root: impl Into<PathBuf>,
        transport: Arc<dyn CloudSyncTransport>,
    ) -> Self {
        Self {
            database: Database::new(database_path.into()),
            backup_root: backup_root.into(),
            transport,
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn backup_root(&self) -> &Path {
        &self.backup_root
    }

    pub fn create_cloud_sync_config(
        &self,
        input: &CreateCloudSyncConfigInput,
    ) -> Result<CloudSyncConfig> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        SyncRepository::create_cloud_sync_config(&mut connection, input)
    }

    pub fn update_cloud_sync_config(
        &self,
        config_id: &str,
        input: &CreateCloudSyncConfigInput,
    ) -> Result<CloudSyncConfig> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        SyncRepository::update_cloud_sync_config(&mut connection, config_id, input)
    }

    pub fn delete_cloud_sync_config(&self, user_id: &str, config_id: &str) -> Result<()> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        SyncRepository::delete_cloud_sync_config(&mut connection, user_id, config_id)
    }

    pub fn list_cloud_sync_configs(&self, user_id: &str) -> Result<Vec<CloudSyncConfig>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SyncRepository::list_cloud_sync_configs(&connection, user_id)
    }

    pub fn get_active_cloud_sync_config(&self, user_id: &str) -> Result<Option<CloudSyncConfig>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SyncRepository::get_active_cloud_sync_config(&connection, user_id)
    }

    pub fn create_backup(&self, user_id: &str, backup_type: &str) -> Result<BackupResult> {
        self.database.initialize()?;
        let backup_type = BackupType::from_str(backup_type)?;
        let created_at = now_string();
        let backup_path = self.create_backup_path(&backup_type, &created_at)?;

        let copy_result = (|| -> Result<(i64, String)> {
            {
                let connection = self.database.connect()?;
                connection.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;
            }
            fs::copy(self.database.path(), &backup_path)?;
            let size = fs::metadata(&backup_path)?.len() as i64;
            let checksum = compute_blake3(&backup_path)?;
            Ok((size, checksum))
        })();

        let connection = self.database.connect()?;
        match copy_result {
            Ok((file_size_bytes, checksum)) => {
                let record = SyncRepository::insert_backup_record(
                    &connection,
                    user_id,
                    backup_type.as_str(),
                    &backup_path.display().to_string(),
                    file_size_bytes,
                    Some(&checksum),
                    "success",
                    None,
                    &created_at,
                )?;
                Ok(to_backup_result(record))
            }
            Err(error) => {
                let record = SyncRepository::insert_backup_record(
                    &connection,
                    user_id,
                    backup_type.as_str(),
                    &backup_path.display().to_string(),
                    0,
                    None,
                    "failed",
                    Some(&error.to_string()),
                    &created_at,
                )?;
                Ok(to_backup_result(record))
            }
        }
    }

    pub fn register_external_backup(
        &self,
        user_id: &str,
        file_path: &str,
        backup_type: &str,
        file_size_bytes: i64,
        checksum: Option<&str>,
    ) -> Result<BackupResult> {
        self.database.initialize()?;
        let backup_type = BackupType::from_str(backup_type)?;
        let connection = self.database.connect()?;
        let record = SyncRepository::insert_backup_record(
            &connection,
            user_id,
            backup_type.as_str(),
            file_path,
            file_size_bytes.max(0),
            checksum,
            "success",
            None,
            &now_string(),
        )?;
        Ok(to_backup_result(record))
    }

    pub fn get_latest_backup(
        &self,
        user_id: &str,
        backup_type: &str,
    ) -> Result<Option<BackupResult>> {
        self.database.initialize()?;
        let backup_type = BackupType::from_str(backup_type)?;
        let connection = self.database.connect()?;
        Ok(
            SyncRepository::get_latest_backup(&connection, user_id, backup_type.as_str())?
                .map(to_backup_result),
        )
    }

    pub fn list_backup_records(&self, user_id: &str, limit: usize) -> Result<Vec<BackupRecord>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SyncRepository::list_backup_records(&connection, user_id, limit)
    }

    pub fn list_restore_records(&self, user_id: &str, limit: usize) -> Result<Vec<RestoreRecord>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        SyncRepository::list_restore_records(&connection, user_id, limit)
    }

    pub fn restore_from_backup_record(
        &self,
        user_id: &str,
        backup_record_id: &str,
    ) -> Result<RestoreResult> {
        self.database.initialize()?;
        let record = {
            let connection = self.database.connect()?;
            SyncRepository::get_backup_record(&connection, user_id, backup_record_id)?
        };
        let restored_at = now_string();
        let Some(record) = record else {
            let connection = self.database.connect()?;
            let restore_record = SyncRepository::insert_restore_record(
                &connection,
                user_id,
                None,
                "failed",
                Some("backup record not found or invalid"),
                &restored_at,
            )?;
            return Ok(to_restore_result(
                restore_record,
                backup_record_id.to_string(),
            ));
        };
        if !record.is_success() || record.file_path.trim().is_empty() {
            let connection = self.database.connect()?;
            let restore_record = SyncRepository::insert_restore_record(
                &connection,
                user_id,
                None,
                "failed",
                Some("backup record not found or invalid"),
                &restored_at,
            )?;
            return Ok(to_restore_result(
                restore_record,
                backup_record_id.to_string(),
            ));
        }

        let restore_attempt = (|| -> Result<()> {
            let source = PathBuf::from(&record.file_path);
            if !source.exists() {
                return Err(LifeOsError::InvalidInput(format!(
                    "backup file not found: {}",
                    source.display()
                )));
            }
            fs::copy(&source, self.database.path())?;
            remove_sqlite_sidecars(self.database.path())?;
            self.database.initialize()?;
            Ok(())
        })();

        let connection = self.database.connect()?;
        match restore_attempt {
            Ok(()) => {
                SyncRepository::upsert_backup_record_copy(&connection, &record)?;
                let restore_record = SyncRepository::insert_restore_record(
                    &connection,
                    user_id,
                    Some(backup_record_id),
                    "success",
                    None,
                    &restored_at,
                )?;
                Ok(to_restore_result(
                    restore_record,
                    backup_record_id.to_string(),
                ))
            }
            Err(error) => {
                let restore_record = SyncRepository::insert_restore_record(
                    &connection,
                    user_id,
                    Some(backup_record_id),
                    "failed",
                    Some(&error.to_string()),
                    &restored_at,
                )?;
                Ok(to_restore_result(
                    restore_record,
                    backup_record_id.to_string(),
                ))
            }
        }
    }

    pub fn upload_backup_to_cloud(
        &self,
        user_id: &str,
        backup_record_id: &str,
    ) -> Result<RemoteUploadResult> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        let config = SyncRepository::get_active_cloud_sync_config(&connection, user_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput("active cloud sync config not found".to_string())
            })?;
        let record = SyncRepository::get_backup_record(&connection, user_id, backup_record_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput(format!("backup record not found: {backup_record_id}"))
            })?;
        drop(connection);

        let backup_type = BackupType::from_str(&record.backup_type)?;
        let result =
            self.transport
                .upload_backup(&config, Path::new(&record.file_path), backup_type)?;

        let connection = self.database.connect()?;
        SyncRepository::mark_cloud_sync_success(&connection, user_id, &config.id, &now_string())?;
        Ok(result)
    }

    pub fn upload_latest_backup_to_cloud(
        &self,
        user_id: &str,
        backup_type: &str,
    ) -> Result<RemoteUploadResult> {
        let latest = self
            .get_latest_backup(user_id, backup_type)?
            .ok_or_else(|| LifeOsError::InvalidInput("latest backup not found".to_string()))?;
        self.upload_backup_to_cloud(user_id, &latest.id)
    }

    pub fn list_remote_backups(
        &self,
        user_id: &str,
        limit: usize,
    ) -> Result<Vec<RemoteBackupFile>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        let config = SyncRepository::get_active_cloud_sync_config(&connection, user_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput("active cloud sync config not found".to_string())
            })?;
        drop(connection);
        self.transport.list_backups(&config, limit)
    }

    pub fn download_backup_from_cloud(
        &self,
        user_id: &str,
        filename: &str,
        backup_type: &str,
    ) -> Result<BackupResult> {
        self.database.initialize()?;
        let backup_type = BackupType::from_str(backup_type)?;
        let connection = self.database.connect()?;
        let config = SyncRepository::get_active_cloud_sync_config(&connection, user_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput("active cloud sync config not found".to_string())
            })?;
        drop(connection);

        let target_path = self.download_target_path(&backup_type, filename)?;
        let download_result = self
            .transport
            .download_backup(&config, filename, &target_path)?;
        let checksum = compute_blake3(&target_path)?;
        let connection = self.database.connect()?;
        let record = SyncRepository::insert_backup_record(
            &connection,
            user_id,
            backup_type.as_str(),
            &download_result.file_path,
            download_result.size_bytes,
            Some(&checksum),
            "success",
            None,
            &now_string(),
        )?;
        SyncRepository::mark_cloud_sync_success(&connection, user_id, &config.id, &now_string())?;
        Ok(to_backup_result(record))
    }

    pub fn download_and_restore_from_cloud(
        &self,
        user_id: &str,
        filename: &str,
        backup_type: &str,
    ) -> Result<RestoreResult> {
        let backup = self.download_backup_from_cloud(user_id, filename, backup_type)?;
        self.restore_from_backup_record(user_id, &backup.id)
    }

    pub fn delete_remote_backup(&self, user_id: &str, filename: &str) -> Result<()> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        let config = SyncRepository::get_active_cloud_sync_config(&connection, user_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput("active cloud sync config not found".to_string())
            })?;
        drop(connection);
        self.transport.delete_backup(&config, filename)?;
        let connection = self.database.connect()?;
        SyncRepository::mark_cloud_sync_success(&connection, user_id, &config.id, &now_string())?;
        Ok(())
    }

    fn create_backup_path(&self, backup_type: &BackupType, created_at: &str) -> Result<PathBuf> {
        let directory = self.backup_root.join(backup_type.folder_name());
        fs::create_dir_all(&directory)?;
        let timestamp = chrono::DateTime::parse_from_rfc3339(created_at)
            .map_err(|error| LifeOsError::Timestamp(error.to_string()))?
            .with_timezone(&Utc)
            .format("%Y%m%d_%H%M%S")
            .to_string();
        Ok(directory.join(format!("lifeos_{}_{}.db", backup_type.as_str(), timestamp)))
    }

    fn download_target_path(&self, backup_type: &BackupType, filename: &str) -> Result<PathBuf> {
        let directory = self
            .backup_root
            .join("downloaded")
            .join(backup_type.folder_name());
        fs::create_dir_all(&directory)?;
        let safe_name = sanitize_filename(filename);
        Ok(directory.join(safe_name))
    }
}

fn default_backup_root(database_path: &Path) -> PathBuf {
    database_path
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .join("lifeos_backups")
}

fn compute_blake3(path: &Path) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = blake3::Hasher::new();
    let mut buffer = [0_u8; 8192];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(hasher.finalize().to_hex().to_string())
}

fn remove_sqlite_sidecars(database_path: &Path) -> Result<()> {
    let wal_path = PathBuf::from(format!("{}-wal", database_path.display()));
    if wal_path.exists() {
        fs::remove_file(wal_path)?;
    }
    let shm_path = PathBuf::from(format!("{}-shm", database_path.display()));
    if shm_path.exists() {
        fs::remove_file(shm_path)?;
    }
    Ok(())
}

fn sanitize_filename(value: &str) -> String {
    let mut sanitized = String::new();
    for ch in value.trim().chars() {
        if ch.is_ascii_alphanumeric() || matches!(ch, '.' | '_' | '-') {
            sanitized.push(ch);
        } else {
            sanitized.push('_');
        }
    }
    if sanitized.is_empty() {
        "backup.db".to_string()
    } else {
        sanitized
    }
}

fn to_backup_result(record: BackupRecord) -> BackupResult {
    BackupResult {
        id: record.id,
        backup_type: record.backup_type,
        file_path: record.file_path,
        file_size_bytes: record.file_size_bytes.unwrap_or(0),
        checksum: record.checksum,
        success: record.status == "success",
        error_message: record.error_message,
        created_at: record.created_at,
    }
}

fn to_restore_result(record: RestoreRecord, backup_record_id: String) -> RestoreResult {
    RestoreResult {
        id: record.id,
        backup_record_id,
        success: record.status == "success",
        error_message: record.error_message,
        restored_at: record.restored_at,
    }
}

fn now_string() -> String {
    Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true)
}
