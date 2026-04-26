use rusqlite::{Connection, OptionalExtension, params};

use crate::error::{LifeOsError, Result};
use crate::models::{
    BackupRecord, CloudSyncConfig, CreateCloudSyncConfigInput, RestoreRecord,
    normalize_optional_string,
};
use crate::repositories::record_repository::{ensure_user_exists, new_id, now_string};

pub struct SyncRepository;

impl SyncRepository {
    pub fn create_cloud_sync_config(
        connection: &mut Connection,
        input: &CreateCloudSyncConfigInput,
    ) -> Result<CloudSyncConfig> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        if input.is_active {
            deactivate_other_configs(&tx, &input.user_id, None)?;
        }
        let id = new_id();
        let now = now_string();
        tx.execute(
            "INSERT INTO cloud_sync_configs(
                id, user_id, provider, endpoint_url, bucket_name, region, root_path,
                access_key_id, secret_encrypted, is_active, last_sync_at, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, NULL, ?11, ?11)",
            params![
                id,
                input.user_id,
                input.normalized_provider()?,
                input.normalized_endpoint_url(),
                input.normalized_bucket_name(),
                input.normalized_region(),
                input.normalized_root_path(),
                input.normalized_device_id(),
                input.normalized_api_key_encrypted(),
                input.is_active as i32,
                now,
            ],
        )?;
        tx.commit()?;
        Ok(CloudSyncConfig {
            id,
            user_id: input.user_id.clone(),
            provider: input.normalized_provider()?,
            endpoint_url: Some(input.normalized_endpoint_url()),
            bucket_name: input.normalized_bucket_name(),
            region: input.normalized_region(),
            root_path: input.normalized_root_path(),
            access_key_id: Some(input.normalized_device_id()),
            secret_encrypted: Some(input.normalized_api_key_encrypted()),
            is_active: input.is_active,
            last_sync_at: None,
            created_at: now.clone(),
            updated_at: now,
        })
    }

    pub fn update_cloud_sync_config(
        connection: &mut Connection,
        config_id: &str,
        input: &CreateCloudSyncConfigInput,
    ) -> Result<CloudSyncConfig> {
        input.validate()?;
        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        let existing =
            load_cloud_sync_config(&tx, &input.user_id, config_id)?.ok_or_else(|| {
                LifeOsError::InvalidInput(format!("cloud sync config not found: {config_id}"))
            })?;
        if input.is_active {
            deactivate_other_configs(&tx, &input.user_id, Some(config_id))?;
        }
        let now = now_string();
        tx.execute(
            "UPDATE cloud_sync_configs
             SET provider = ?3,
                 endpoint_url = ?4,
                 bucket_name = ?5,
                 region = ?6,
                 root_path = ?7,
                 access_key_id = ?8,
                 secret_encrypted = ?9,
                 is_active = ?10,
                 updated_at = ?11
             WHERE id = ?1 AND user_id = ?2",
            params![
                config_id,
                input.user_id,
                input.normalized_provider()?,
                input.normalized_endpoint_url(),
                input.normalized_bucket_name(),
                input.normalized_region(),
                input.normalized_root_path(),
                input.normalized_device_id(),
                input.normalized_api_key_encrypted(),
                input.is_active as i32,
                now,
            ],
        )?;
        tx.commit()?;
        Ok(CloudSyncConfig {
            id: existing.id,
            user_id: input.user_id.clone(),
            provider: input.normalized_provider()?,
            endpoint_url: Some(input.normalized_endpoint_url()),
            bucket_name: input.normalized_bucket_name(),
            region: input.normalized_region(),
            root_path: input.normalized_root_path(),
            access_key_id: Some(input.normalized_device_id()),
            secret_encrypted: Some(input.normalized_api_key_encrypted()),
            is_active: input.is_active,
            last_sync_at: existing.last_sync_at,
            created_at: existing.created_at,
            updated_at: now,
        })
    }

    pub fn delete_cloud_sync_config(
        connection: &mut Connection,
        user_id: &str,
        config_id: &str,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        let deleted = connection.execute(
            "DELETE FROM cloud_sync_configs WHERE id = ?1 AND user_id = ?2",
            params![config_id, user_id],
        )?;
        if deleted == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "cloud sync config not found: {config_id}"
            )));
        }
        Ok(())
    }

    pub fn list_cloud_sync_configs(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Vec<CloudSyncConfig>> {
        ensure_user_exists(connection, user_id)?;
        let mut statement = connection.prepare(
            "SELECT id, user_id, provider, endpoint_url, bucket_name, region, root_path,
                    access_key_id, secret_encrypted, is_active, last_sync_at, created_at, updated_at
             FROM cloud_sync_configs
             WHERE user_id = ?1
             ORDER BY is_active DESC, updated_at DESC, created_at DESC",
        )?;
        let rows = statement.query_map([user_id], map_cloud_sync_config_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn get_active_cloud_sync_config(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Option<CloudSyncConfig>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, provider, endpoint_url, bucket_name, region, root_path,
                        access_key_id, secret_encrypted, is_active, last_sync_at, created_at, updated_at
                 FROM cloud_sync_configs
                 WHERE user_id = ?1 AND is_active = 1
                 ORDER BY updated_at DESC
                 LIMIT 1",
                [user_id],
                map_cloud_sync_config_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn mark_cloud_sync_success(
        connection: &Connection,
        user_id: &str,
        config_id: &str,
        synced_at: &str,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        connection.execute(
            "UPDATE cloud_sync_configs
             SET last_sync_at = ?3, updated_at = ?3
             WHERE id = ?1 AND user_id = ?2",
            params![config_id, user_id, synced_at],
        )?;
        Ok(())
    }

    pub fn insert_backup_record(
        connection: &Connection,
        user_id: &str,
        backup_type: &str,
        file_path: &str,
        file_size_bytes: i64,
        checksum: Option<&str>,
        status: &str,
        error_message: Option<&str>,
        created_at: &str,
    ) -> Result<BackupRecord> {
        ensure_user_exists(connection, user_id)?;
        let id = new_id();
        connection.execute(
            "INSERT INTO backup_records(
                id, user_id, backup_type, file_path, file_size_bytes, checksum,
                status, error_message, created_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                id,
                user_id,
                backup_type,
                file_path,
                file_size_bytes,
                normalize_optional_string(&checksum.map(ToString::to_string)),
                status,
                normalize_optional_string(&error_message.map(ToString::to_string)),
                created_at,
            ],
        )?;
        Ok(BackupRecord {
            id,
            user_id: user_id.to_string(),
            backup_type: backup_type.to_string(),
            file_path: file_path.to_string(),
            file_size_bytes: Some(file_size_bytes),
            checksum: normalize_optional_string(&checksum.map(ToString::to_string)),
            status: status.to_string(),
            error_message: normalize_optional_string(&error_message.map(ToString::to_string)),
            created_at: created_at.to_string(),
        })
    }

    pub fn upsert_backup_record_copy(connection: &Connection, record: &BackupRecord) -> Result<()> {
        ensure_user_exists(connection, &record.user_id)?;
        connection.execute(
            "INSERT OR IGNORE INTO backup_records(
                id, user_id, backup_type, file_path, file_size_bytes, checksum,
                status, error_message, created_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                record.id,
                record.user_id,
                record.backup_type,
                record.file_path,
                record.file_size_bytes,
                record.checksum,
                record.status,
                record.error_message,
                record.created_at,
            ],
        )?;
        Ok(())
    }

    pub fn get_backup_record(
        connection: &Connection,
        user_id: &str,
        backup_record_id: &str,
    ) -> Result<Option<BackupRecord>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, backup_type, file_path, file_size_bytes, checksum,
                        status, error_message, created_at
                 FROM backup_records
                 WHERE id = ?1 AND user_id = ?2
                 LIMIT 1",
                params![backup_record_id, user_id],
                map_backup_record_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn get_latest_backup(
        connection: &Connection,
        user_id: &str,
        backup_type: &str,
    ) -> Result<Option<BackupRecord>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, backup_type, file_path, file_size_bytes, checksum,
                        status, error_message, created_at
                 FROM backup_records
                 WHERE user_id = ?1 AND backup_type = ?2
                 ORDER BY created_at DESC
                 LIMIT 1",
                params![user_id, backup_type],
                map_backup_record_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn list_backup_records(
        connection: &Connection,
        user_id: &str,
        limit: usize,
    ) -> Result<Vec<BackupRecord>> {
        ensure_user_exists(connection, user_id)?;
        let limit = limit.clamp(1, 500) as i64;
        let mut statement = connection.prepare(
            "SELECT id, user_id, backup_type, file_path, file_size_bytes, checksum,
                    status, error_message, created_at
             FROM backup_records
             WHERE user_id = ?1
             ORDER BY created_at DESC
             LIMIT ?2",
        )?;
        let rows = statement.query_map(params![user_id, limit], map_backup_record_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn insert_restore_record(
        connection: &Connection,
        user_id: &str,
        backup_record_id: Option<&str>,
        status: &str,
        error_message: Option<&str>,
        restored_at: &str,
    ) -> Result<RestoreRecord> {
        ensure_user_exists(connection, user_id)?;
        let id = new_id();
        connection.execute(
            "INSERT INTO restore_records(
                id, user_id, backup_record_id, status, error_message, restored_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                id,
                user_id,
                normalize_optional_string(&backup_record_id.map(ToString::to_string)),
                status,
                normalize_optional_string(&error_message.map(ToString::to_string)),
                restored_at,
            ],
        )?;
        Ok(RestoreRecord {
            id,
            user_id: user_id.to_string(),
            backup_record_id: normalize_optional_string(&backup_record_id.map(ToString::to_string)),
            status: status.to_string(),
            error_message: normalize_optional_string(&error_message.map(ToString::to_string)),
            restored_at: restored_at.to_string(),
        })
    }

    pub fn list_restore_records(
        connection: &Connection,
        user_id: &str,
        limit: usize,
    ) -> Result<Vec<RestoreRecord>> {
        ensure_user_exists(connection, user_id)?;
        let limit = limit.clamp(1, 500) as i64;
        let mut statement = connection.prepare(
            "SELECT id, user_id, backup_record_id, status, error_message, restored_at
             FROM restore_records
             WHERE user_id = ?1
             ORDER BY restored_at DESC
             LIMIT ?2",
        )?;
        let rows = statement.query_map(params![user_id, limit], map_restore_record_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }
}

fn deactivate_other_configs(
    connection: &Connection,
    user_id: &str,
    except_id: Option<&str>,
) -> Result<()> {
    match except_id {
        Some(except_id) => {
            connection.execute(
                "UPDATE cloud_sync_configs SET is_active = 0 WHERE user_id = ?1 AND id != ?2",
                params![user_id, except_id],
            )?;
        }
        None => {
            connection.execute(
                "UPDATE cloud_sync_configs SET is_active = 0 WHERE user_id = ?1",
                [user_id],
            )?;
        }
    }
    Ok(())
}

fn load_cloud_sync_config(
    connection: &Connection,
    user_id: &str,
    config_id: &str,
) -> Result<Option<CloudSyncConfig>> {
    connection
        .query_row(
            "SELECT id, user_id, provider, endpoint_url, bucket_name, region, root_path,
                    access_key_id, secret_encrypted, is_active, last_sync_at, created_at, updated_at
             FROM cloud_sync_configs
             WHERE id = ?1 AND user_id = ?2
             LIMIT 1",
            params![config_id, user_id],
            map_cloud_sync_config_row,
        )
        .optional()
        .map_err(Into::into)
}

fn map_cloud_sync_config_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<CloudSyncConfig> {
    Ok(CloudSyncConfig {
        id: row.get(0)?,
        user_id: row.get(1)?,
        provider: row.get(2)?,
        endpoint_url: row.get(3)?,
        bucket_name: row.get(4)?,
        region: row.get(5)?,
        root_path: row.get(6)?,
        access_key_id: row.get(7)?,
        secret_encrypted: row.get(8)?,
        is_active: row.get::<_, i64>(9)? == 1,
        last_sync_at: row.get(10)?,
        created_at: row.get(11)?,
        updated_at: row.get(12)?,
    })
}

fn map_backup_record_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<BackupRecord> {
    Ok(BackupRecord {
        id: row.get(0)?,
        user_id: row.get(1)?,
        backup_type: row.get(2)?,
        file_path: row.get(3)?,
        file_size_bytes: row.get(4)?,
        checksum: row.get(5)?,
        status: row.get(6)?,
        error_message: row.get(7)?,
        created_at: row.get(8)?,
    })
}

fn map_restore_record_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<RestoreRecord> {
    Ok(RestoreRecord {
        id: row.get(0)?,
        user_id: row.get(1)?,
        backup_record_id: row.get(2)?,
        status: row.get(3)?,
        error_message: row.get(4)?,
        restored_at: row.get(5)?,
    })
}
