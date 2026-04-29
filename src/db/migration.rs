use blake3::Hasher;
use chrono::{SecondsFormat, Utc};
use rusqlite::{Connection, OptionalExtension, params};

use crate::error::Result;

struct Migration {
    version: i64,
    name: &'static str,
    sql: &'static str,
}

const MIGRATIONS: &[Migration] = &[
    Migration {
        version: 1,
        name: "init_core_schema",
        sql: include_str!("../../migrations/0001_init_core.sql"),
    },
    Migration {
        version: 2,
        name: "supporting_tables_and_indexes",
        sql: include_str!("../../migrations/0002_supporting_tables.sql"),
    },
    Migration {
        version: 3,
        name: "full_domain_design_support",
        sql: include_str!("../../migrations/0003_full_domain_design.sql"),
    },
    Migration {
        version: 4,
        name: "review_notes",
        sql: include_str!("../../migrations/0004_review_notes.sql"),
    },
];

pub fn run_migrations(connection: &mut Connection) -> Result<()> {
    connection.execute_batch(
        "CREATE TABLE IF NOT EXISTS schema_migrations (
            version     INTEGER PRIMARY KEY,
            name        TEXT NOT NULL,
            checksum    TEXT NOT NULL,
            applied_at  TEXT NOT NULL
        );",
    )?;

    let tx = connection.transaction()?;
    for migration in MIGRATIONS {
        let applied: Option<String> = tx
            .query_row(
                "SELECT checksum FROM schema_migrations WHERE version = ?1",
                [migration.version],
                |row| row.get(0),
            )
            .optional()?;

        let checksum = checksum(migration.sql);
        match applied {
            Some(existing) if existing == checksum => continue,
            Some(_) => {
                return Err(crate::error::LifeOsError::InvalidInput(format!(
                    "migration {} checksum mismatch",
                    migration.version
                )));
            }
            None => {}
        }

        tx.execute_batch(migration.sql)?;
        tx.execute(
            "INSERT INTO schema_migrations(version, name, checksum, applied_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![
                migration.version,
                migration.name,
                checksum,
                Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true),
            ],
        )?;
    }
    tx.commit()?;

    Ok(())
}

fn checksum(sql: &str) -> String {
    let mut hasher = Hasher::new();
    hasher.update(sql.as_bytes());
    hasher.finalize().to_hex().to_string()
}
