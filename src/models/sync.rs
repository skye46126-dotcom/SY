use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{normalize_code, normalize_optional_string, normalize_required_string};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum BackupType {
    DailyIncremental,
    WeeklyFull,
    MonthlyArchive,
    Manual,
}

impl BackupType {
    pub fn from_str(value: &str) -> Result<Self> {
        let normalized = normalize_code("backup_type", value)?;
        match normalized.as_str() {
            "daily_incremental" => Ok(Self::DailyIncremental),
            "weekly_full" => Ok(Self::WeeklyFull),
            "monthly_archive" => Ok(Self::MonthlyArchive),
            "manual" => Ok(Self::Manual),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported backup_type: {other}"
            ))),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::DailyIncremental => "daily_incremental",
            Self::WeeklyFull => "weekly_full",
            Self::MonthlyArchive => "monthly_archive",
            Self::Manual => "manual",
        }
    }

    pub fn folder_name(&self) -> &'static str {
        match self {
            Self::DailyIncremental => "daily",
            Self::WeeklyFull => "weekly",
            Self::MonthlyArchive => "monthly",
            Self::Manual => "manual",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BackupRecord {
    pub id: String,
    pub user_id: String,
    pub backup_type: String,
    pub file_path: String,
    pub file_size_bytes: Option<i64>,
    pub checksum: Option<String>,
    pub status: String,
    pub error_message: Option<String>,
    pub created_at: String,
}

impl BackupRecord {
    pub fn is_success(&self) -> bool {
        self.status == "success"
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RestoreRecord {
    pub id: String,
    pub user_id: String,
    pub backup_record_id: Option<String>,
    pub status: String,
    pub error_message: Option<String>,
    pub restored_at: String,
}

impl RestoreRecord {
    pub fn is_success(&self) -> bool {
        self.status == "success"
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BackupResult {
    pub id: String,
    pub backup_type: String,
    pub file_path: String,
    pub file_size_bytes: i64,
    pub checksum: Option<String>,
    pub success: bool,
    pub error_message: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RestoreResult {
    pub id: String,
    pub backup_record_id: String,
    pub success: bool,
    pub error_message: Option<String>,
    pub restored_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CloudSyncConfig {
    pub id: String,
    pub user_id: String,
    pub provider: String,
    pub endpoint_url: Option<String>,
    pub bucket_name: Option<String>,
    pub region: Option<String>,
    pub root_path: Option<String>,
    pub access_key_id: Option<String>,
    pub secret_encrypted: Option<String>,
    pub is_active: bool,
    pub last_sync_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

impl CloudSyncConfig {
    pub fn normalized_provider(&self) -> Result<String> {
        normalize_cloud_provider(&self.provider)
    }

    pub fn normalized_endpoint_url(&self) -> Result<String> {
        normalize_required_string(
            "endpoint_url",
            self.endpoint_url.as_deref().unwrap_or_default(),
        )
    }

    pub fn resolved_device_id(&self) -> String {
        normalize_optional_string(&self.access_key_id).unwrap_or_else(|| "desktop".to_string())
    }

    pub fn resolved_api_key(&self) -> Result<String> {
        normalize_required_string(
            "secret_encrypted",
            self.secret_encrypted.as_deref().unwrap_or_default(),
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateCloudSyncConfigInput {
    pub user_id: String,
    pub provider: String,
    pub endpoint_url: String,
    pub bucket_name: Option<String>,
    pub region: Option<String>,
    pub root_path: Option<String>,
    pub device_id: String,
    pub api_key_encrypted: String,
    pub is_active: bool,
}

impl CreateCloudSyncConfigInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        let _ = normalize_cloud_provider(&self.provider)?;
        normalize_required_string("endpoint_url", &self.endpoint_url)?;
        normalize_required_string("device_id", &self.device_id)?;
        normalize_required_string("api_key_encrypted", &self.api_key_encrypted)?;
        Ok(())
    }

    pub fn normalized_provider(&self) -> Result<String> {
        normalize_cloud_provider(&self.provider)
    }

    pub fn normalized_endpoint_url(&self) -> String {
        self.endpoint_url.trim().trim_end_matches('/').to_string()
    }

    pub fn normalized_bucket_name(&self) -> Option<String> {
        normalize_optional_string(&self.bucket_name)
    }

    pub fn normalized_region(&self) -> Option<String> {
        normalize_optional_string(&self.region)
    }

    pub fn normalized_root_path(&self) -> Option<String> {
        normalize_optional_string(&self.root_path)
    }

    pub fn normalized_device_id(&self) -> String {
        self.device_id.trim().to_string()
    }

    pub fn normalized_api_key_encrypted(&self) -> String {
        self.api_key_encrypted.trim().to_string()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RemoteBackupFile {
    pub filename: String,
    pub size_bytes: i64,
    pub modified_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RemoteUploadResult {
    pub filename: String,
    pub size_bytes: i64,
    pub checksum: Option<String>,
    pub uploaded_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RemoteDownloadResult {
    pub file_path: String,
    pub size_bytes: i64,
}

pub fn normalize_cloud_provider(value: &str) -> Result<String> {
    let normalized = normalize_code("provider", value)?;
    match normalized.as_str() {
        "lifeos_http" | "generic_http" => Ok(normalized),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported cloud sync provider: {other}"
        ))),
    }
}
