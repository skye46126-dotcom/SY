use thiserror::Error;

pub type Result<T> = std::result::Result<T, LifeOsError>;

#[derive(Debug, Error)]
pub enum LifeOsError {
    #[error("sqlite error: {0}")]
    Sqlite(#[from] rusqlite::Error),

    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("invalid timezone: {0}")]
    InvalidTimezone(String),

    #[error("timestamp parse error: {0}")]
    Timestamp(String),
}
