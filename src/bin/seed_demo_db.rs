use std::env;
use std::path::PathBuf;

use life_os_core::{DemoDataService, RecordService};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let database_path = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("life_os_demo.db"));

    if let Some(parent) = database_path.parent()
        && !parent.as_os_str().is_empty()
    {
        std::fs::create_dir_all(parent)?;
    }
    if database_path.exists() {
        std::fs::remove_file(&database_path)?;
    }

    let record_service = RecordService::new(&database_path);
    let user = record_service.init_database()?;

    let demo_service = DemoDataService::new(&database_path);
    let result = demo_service.seed_demo_data(&user.id)?;

    println!(
        "seeded demo database at {} for user {}",
        database_path.display(),
        result.user_id
    );
    Ok(())
}
