PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS user_sessions (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    token_hash                   TEXT NOT NULL UNIQUE,
    device_id                    TEXT,
    user_agent                   TEXT,
    issued_at                    TEXT NOT NULL,
    expires_at                   TEXT NOT NULL,
    revoked_at                   TEXT,
    last_seen_at                 TEXT,
    created_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS metric_snapshot_projects (
    metric_snapshot_id           TEXT NOT NULL,
    project_id                   TEXT NOT NULL,
    income_cents                 INTEGER,
    direct_expense_cents         INTEGER,
    structural_cost_cents        INTEGER,
    operating_cost_cents         INTEGER,
    total_cost_cents             INTEGER,
    profit_cents                 INTEGER,
    invested_minutes             INTEGER,
    roi_ratio                    REAL,
    break_even_cents             INTEGER,
    created_at                   TEXT NOT NULL,
    PRIMARY KEY (metric_snapshot_id, project_id),
    FOREIGN KEY (metric_snapshot_id) REFERENCES metric_snapshots(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS ai_service_configs (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    provider                     TEXT NOT NULL,
    base_url                     TEXT,
    api_key_encrypted            TEXT,
    model                        TEXT,
    system_prompt                TEXT,
    parser_mode                  TEXT NOT NULL DEFAULT 'auto' CHECK(parser_mode IN ('auto', 'rule', 'llm', 'vcp')),
    temperature_milli            INTEGER,
    is_active                    INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    last_validated_at            TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cloud_sync_configs (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    provider                     TEXT NOT NULL,
    endpoint_url                 TEXT,
    bucket_name                  TEXT,
    region                       TEXT,
    root_path                    TEXT,
    access_key_id                TEXT,
    secret_encrypted             TEXT,
    is_active                    INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    last_sync_at                 TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS review_snapshots (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    window_type                  TEXT NOT NULL CHECK(window_type IN ('day', 'week', 'month', 'year', 'range')),
    anchor_date                  TEXT,
    range_start                  TEXT,
    range_end                    TEXT,
    summary_json                 TEXT NOT NULL,
    metrics_json                 TEXT,
    trend_json                   TEXT,
    generated_at                 TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS dimension_options (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT,
    dimension_kind               TEXT NOT NULL,
    code                         TEXT NOT NULL,
    display_name                 TEXT NOT NULL,
    sort_order                   INTEGER NOT NULL DEFAULT 0,
    is_active                    INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    is_system                    INTEGER NOT NULL DEFAULT 0 CHECK(is_system IN (0, 1)),
    metadata_json                TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, dimension_kind, code)
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user
    ON user_sessions(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_metric_snapshot_projects_project
    ON metric_snapshot_projects(project_id, metric_snapshot_id);
CREATE INDEX IF NOT EXISTS idx_ai_service_configs_user_active
    ON ai_service_configs(user_id, is_active, provider);
CREATE INDEX IF NOT EXISTS idx_cloud_sync_configs_user_active
    ON cloud_sync_configs(user_id, is_active, provider);
CREATE INDEX IF NOT EXISTS idx_review_snapshots_user_window
    ON review_snapshots(user_id, window_type, generated_at);
CREATE INDEX IF NOT EXISTS idx_dimension_options_lookup
    ON dimension_options(user_id, dimension_kind, is_active, sort_order);
