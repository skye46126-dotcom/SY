mod connection;
mod migration;
pub mod schema;

use std::path::{Path, PathBuf};

use rusqlite::Connection;
use uuid::Uuid;

use crate::error::Result;
use crate::models::UserProfile;

pub use connection::open_connection;

#[derive(Debug, Clone)]
pub struct Database {
    path: PathBuf,
}

impl Database {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn connect(&self) -> Result<Connection> {
        connection::open_connection(&self.path)
    }

    pub fn initialize(&self) -> Result<()> {
        let mut connection = self.connect()?;
        migration::run_migrations(&mut connection)?;
        self.ensure_default_user(&mut connection)?;
        Ok(())
    }

    pub fn ensure_default_user(&self, connection: &mut Connection) -> Result<UserProfile> {
        if let Some(existing) = schema::load_default_user(connection)? {
            return Ok(existing);
        }

        let user = UserProfile {
            id: Uuid::now_v7().to_string(),
            username: schema::DEFAULT_USERNAME.to_string(),
            display_name: schema::DEFAULT_DISPLAY_NAME.to_string(),
            timezone: schema::DEFAULT_TIMEZONE.to_string(),
            currency_code: schema::DEFAULT_CURRENCY_CODE.to_string(),
            ideal_hourly_rate_cents: 0,
            status: schema::DEFAULT_USER_STATUS.to_string(),
        };

        schema::insert_default_user(connection, &user)?;
        Ok(user)
    }
}
