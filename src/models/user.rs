use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct UserProfile {
    pub id: String,
    pub username: String,
    pub display_name: String,
    pub timezone: String,
    pub currency_code: String,
    pub ideal_hourly_rate_cents: i64,
    pub status: String,
}
