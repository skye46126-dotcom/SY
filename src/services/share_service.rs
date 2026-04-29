use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};

#[derive(Debug, Deserialize)]
pub struct ShareTargetInput {
    pub file_path: String,
    pub title: Option<String>,
    pub mime_type: Option<String>,
    pub text: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ShareTarget {
    pub file_path: String,
    pub file_name: String,
    pub mime_type: String,
    pub title: String,
    pub text: String,
    pub file_size_bytes: u64,
}

pub struct ShareService;

impl ShareService {
    pub fn prepare_target(input: ShareTargetInput) -> Result<ShareTarget> {
        let path = PathBuf::from(input.file_path.trim());
        if path.as_os_str().is_empty() {
            return Err(LifeOsError::InvalidInput(
                "share file_path is required".to_string(),
            ));
        }
        if !path.exists() {
            return Err(LifeOsError::InvalidInput(format!(
                "share file does not exist: {}",
                path.display()
            )));
        }
        if !path.is_file() {
            return Err(LifeOsError::InvalidInput(format!(
                "share target is not a file: {}",
                path.display()
            )));
        }
        let metadata = fs::metadata(&path)?;
        let file_name = path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("export")
            .to_string();
        let mime_type = input
            .mime_type
            .and_then(|value| non_empty(value))
            .unwrap_or_else(|| infer_mime_type(&path));
        let title = input
            .title
            .and_then(non_empty)
            .unwrap_or_else(|| file_name.clone());
        let text = input
            .text
            .and_then(non_empty)
            .unwrap_or_else(|| format!("SkyeOS export: {file_name}"));

        Ok(ShareTarget {
            file_path: path.to_string_lossy().to_string(),
            file_name,
            mime_type,
            title,
            text,
            file_size_bytes: metadata.len(),
        })
    }
}

fn non_empty(value: String) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn infer_mime_type(path: &Path) -> String {
    match path
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "svg" => "image/svg+xml",
        "json" => "application/json",
        "csv" => "text/csv",
        "md" | "markdown" => "text/markdown",
        "txt" => "text/plain",
        "pdf" => "application/pdf",
        "zip" => "application/zip",
        "sqlite" | "db" => "application/vnd.sqlite3",
        _ => "application/octet-stream",
    }
    .to_string()
}
