use std::path::Path;
use std::process::Command;

use serde::Deserialize;

use crate::error::{LifeOsError, Result};
use crate::models::{
    BackupType, CloudSyncConfig, RemoteBackupFile, RemoteDownloadResult, RemoteUploadResult,
};

pub trait CloudSyncTransport: Send + Sync {
    fn upload_backup(
        &self,
        config: &CloudSyncConfig,
        backup_file: &Path,
        backup_type: BackupType,
    ) -> Result<RemoteUploadResult>;

    fn list_backups(&self, config: &CloudSyncConfig, limit: usize)
    -> Result<Vec<RemoteBackupFile>>;

    fn download_backup(
        &self,
        config: &CloudSyncConfig,
        filename: &str,
        target_file: &Path,
    ) -> Result<RemoteDownloadResult>;

    fn delete_backup(&self, config: &CloudSyncConfig, filename: &str) -> Result<()>;
}

#[derive(Debug, Clone, Default)]
pub struct CurlCloudSyncTransport;

impl CloudSyncTransport for CurlCloudSyncTransport {
    fn upload_backup(
        &self,
        config: &CloudSyncConfig,
        backup_file: &Path,
        backup_type: BackupType,
    ) -> Result<RemoteUploadResult> {
        if !backup_file.exists() {
            return Err(LifeOsError::InvalidInput(format!(
                "backup file not found: {}",
                backup_file.display()
            )));
        }
        let url = format!(
            "{}/api/v1/backups/upload?device_id={}&backup_type={}",
            normalize_base_url(&config.normalized_endpoint_url()?),
            percent_encode(&config.resolved_device_id()),
            percent_encode(backup_type.as_str()),
        );
        let response = run_curl(
            Command::new("curl")
                .arg("-fsS")
                .arg("-X")
                .arg("POST")
                .arg("-H")
                .arg(format!("x-api-key: {}", config.resolved_api_key()?))
                .arg("-F")
                .arg(format!("file=@{}", backup_file.display()))
                .arg(url),
        )?;
        let payload: UploadPayload = serde_json::from_slice(&response).map_err(|error| {
            LifeOsError::InvalidInput(format!("invalid upload response: {error}"))
        })?;
        Ok(RemoteUploadResult {
            filename: payload.filename,
            size_bytes: payload.size_bytes,
            checksum: payload.sha256,
            uploaded_at: payload.uploaded_at,
        })
    }

    fn list_backups(
        &self,
        config: &CloudSyncConfig,
        limit: usize,
    ) -> Result<Vec<RemoteBackupFile>> {
        let safe_limit = limit.clamp(1, 200);
        let url = format!(
            "{}/api/v1/backups/list?limit={safe_limit}",
            normalize_base_url(&config.normalized_endpoint_url()?),
        );
        let response = run_curl(
            Command::new("curl")
                .arg("-fsS")
                .arg("-H")
                .arg(format!("x-api-key: {}", config.resolved_api_key()?))
                .arg(url),
        )?;
        let payload: Vec<ListPayload> = serde_json::from_slice(&response).map_err(|error| {
            LifeOsError::InvalidInput(format!("invalid list response: {error}"))
        })?;
        Ok(payload
            .into_iter()
            .map(|item| RemoteBackupFile {
                filename: item.filename,
                size_bytes: item.size_bytes,
                modified_at: item.modified_at,
            })
            .collect())
    }

    fn download_backup(
        &self,
        config: &CloudSyncConfig,
        filename: &str,
        target_file: &Path,
    ) -> Result<RemoteDownloadResult> {
        let url = format!(
            "{}/api/v1/backups/download/{}",
            normalize_base_url(&config.normalized_endpoint_url()?),
            percent_encode(filename),
        );
        if let Some(parent) = target_file.parent() {
            std::fs::create_dir_all(parent)?;
        }
        run_curl(
            Command::new("curl")
                .arg("-fsS")
                .arg("-H")
                .arg(format!("x-api-key: {}", config.resolved_api_key()?))
                .arg("-o")
                .arg(target_file)
                .arg(url),
        )?;
        let metadata = std::fs::metadata(target_file)?;
        Ok(RemoteDownloadResult {
            file_path: target_file.display().to_string(),
            size_bytes: metadata.len() as i64,
        })
    }

    fn delete_backup(&self, config: &CloudSyncConfig, filename: &str) -> Result<()> {
        let url = format!(
            "{}/api/v1/backups/delete/{}",
            normalize_base_url(&config.normalized_endpoint_url()?),
            percent_encode(filename),
        );
        run_curl(
            Command::new("curl")
                .arg("-fsS")
                .arg("-X")
                .arg("DELETE")
                .arg("-H")
                .arg(format!("x-api-key: {}", config.resolved_api_key()?))
                .arg(url),
        )?;
        Ok(())
    }
}

#[derive(Debug, Deserialize)]
struct UploadPayload {
    filename: String,
    size_bytes: i64,
    #[serde(default)]
    sha256: Option<String>,
    #[serde(default)]
    uploaded_at: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ListPayload {
    filename: String,
    size_bytes: i64,
    modified_at: String,
}

fn run_curl(command: &mut Command) -> Result<Vec<u8>> {
    let output = command.output()?;
    if output.status.success() {
        Ok(output.stdout)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Err(LifeOsError::InvalidInput(format!(
            "cloud sync command failed: {}{}",
            stderr,
            if stdout.is_empty() {
                String::new()
            } else {
                format!(" | {stdout}")
            }
        )))
    }
}

fn normalize_base_url(value: &str) -> String {
    value.trim().trim_end_matches('/').to_string()
}

fn percent_encode(value: &str) -> String {
    let mut encoded = String::new();
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'~') {
            encoded.push(byte as char);
        } else {
            encoded.push('%');
            encoded.push_str(&format!("{byte:02X}"));
        }
    }
    encoded
}
