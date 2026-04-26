use chrono::{SecondsFormat, Utc};
use rusqlite::{Connection, OptionalExtension, params};

use crate::error::Result;
use crate::models::UserProfile;

pub const DEFAULT_USERNAME: &str = "owner";
pub const DEFAULT_DISPLAY_NAME: &str = "Owner";
pub const DEFAULT_TIMEZONE: &str = "Asia/Shanghai";
pub const DEFAULT_CURRENCY_CODE: &str = "CNY";
pub const DEFAULT_USER_STATUS: &str = "active";

pub fn load_default_user(connection: &Connection) -> Result<Option<UserProfile>> {
    connection
        .query_row(
            "SELECT id, username, display_name, timezone, currency_code, ideal_hourly_rate_cents, status
             FROM users
             ORDER BY created_at ASC
             LIMIT 1",
            [],
            |row| {
                Ok(UserProfile {
                    id: row.get(0)?,
                    username: row.get(1)?,
                    display_name: row.get(2)?,
                    timezone: row.get(3)?,
                    currency_code: row.get(4)?,
                    ideal_hourly_rate_cents: row.get(5)?,
                    status: row.get(6)?,
                })
            },
        )
        .optional()
        .map_err(Into::into)
}

pub fn insert_default_user(connection: &Connection, user: &UserProfile) -> Result<()> {
    let now = Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true);
    connection.execute(
        "INSERT INTO users(
            id, username, display_name, timezone, currency_code,
            ideal_hourly_rate_cents, status, created_at, updated_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8)",
        params![
            user.id,
            user.username,
            user.display_name,
            user.timezone,
            user.currency_code,
            user.ideal_hourly_rate_cents,
            user.status,
            now,
        ],
    )?;
    Ok(())
}
