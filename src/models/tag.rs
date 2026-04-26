use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{normalize_code, normalize_optional_string, normalize_required_string};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateTagInput {
    pub user_id: String,
    pub name: String,
    pub emoji: Option<String>,
    pub tag_group: Option<String>,
    pub scope: Option<String>,
    pub parent_tag_id: Option<String>,
    pub level: Option<i32>,
    pub status: Option<String>,
    pub sort_order: Option<i32>,
}

impl CreateTagInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("name", &self.name)?;
        if let Some(level) = self.level
            && level < 1
        {
            return Err(LifeOsError::InvalidInput(
                "level must be greater than or equal to 1".to_string(),
            ));
        }
        if let Some(sort_order) = self.sort_order
            && sort_order < 0
        {
            return Err(LifeOsError::InvalidInput(
                "sort_order must be zero or positive".to_string(),
            ));
        }
        let status = self.normalized_status();
        if !matches!(status.as_str(), "active" | "inactive" | "archived") {
            return Err(LifeOsError::InvalidInput(
                "status must be active, inactive or archived".to_string(),
            ));
        }
        let _ = self.normalized_scope()?;
        let _ = self.normalized_tag_group()?;
        Ok(())
    }

    pub fn normalized_name(&self) -> String {
        self.name.trim().to_string()
    }

    pub fn normalized_emoji(&self) -> Option<String> {
        normalize_optional_string(&self.emoji)
    }

    pub fn normalized_tag_group(&self) -> Result<String> {
        Ok(self
            .tag_group
            .as_deref()
            .map(|value| normalize_code("tag_group", value))
            .transpose()?
            .unwrap_or_else(|| "custom".to_string()))
    }

    pub fn normalized_scope(&self) -> Result<String> {
        Ok(self
            .scope
            .as_deref()
            .map(|value| normalize_code("scope", value))
            .transpose()?
            .unwrap_or_else(|| "global".to_string()))
    }

    pub fn normalized_parent_tag_id(&self) -> Option<String> {
        normalize_optional_string(&self.parent_tag_id)
    }

    pub fn normalized_status(&self) -> String {
        self.status
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_lowercase)
            .unwrap_or_else(|| "active".to_string())
    }

    pub fn resolved_level(&self) -> i32 {
        self.level.unwrap_or(1)
    }

    pub fn resolved_sort_order(&self) -> i32 {
        self.sort_order.unwrap_or(0)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Tag {
    pub id: String,
    pub user_id: String,
    pub name: String,
    pub emoji: Option<String>,
    pub tag_group: String,
    pub scope: String,
    pub parent_tag_id: Option<String>,
    pub level: i32,
    pub status: String,
    pub sort_order: i32,
    pub is_system: bool,
    pub created_at: String,
    pub updated_at: String,
}
