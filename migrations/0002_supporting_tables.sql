PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS expense_baseline_months (
    user_id                      TEXT NOT NULL,
    month                        TEXT NOT NULL,
    basic_living_cents           INTEGER NOT NULL DEFAULT 0 CHECK(basic_living_cents >= 0),
    fixed_subscription_cents     INTEGER NOT NULL DEFAULT 0 CHECK(fixed_subscription_cents >= 0),
    note                         TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    PRIMARY KEY (user_id, month),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS expense_recurring_rules (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    name                         TEXT NOT NULL,
    category_code                TEXT NOT NULL,
    monthly_amount_cents         INTEGER NOT NULL CHECK(monthly_amount_cents >= 0),
    is_necessary                 INTEGER NOT NULL DEFAULT 1 CHECK(is_necessary IN (0, 1)),
    start_month                  TEXT NOT NULL,
    end_month                    TEXT,
    is_active                    INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    note                         TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_code) REFERENCES dim_expense_categories(code) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS expense_capex_items (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    name                         TEXT NOT NULL,
    purchase_date                TEXT NOT NULL,
    purchase_amount_cents        INTEGER NOT NULL CHECK(purchase_amount_cents >= 0),
    residual_rate_bps            INTEGER NOT NULL DEFAULT 0 CHECK(residual_rate_bps >= 0 AND residual_rate_bps <= 10000),
    useful_months                INTEGER NOT NULL CHECK(useful_months > 0),
    monthly_amortized_cents      INTEGER NOT NULL CHECK(monthly_amortized_cents >= 0),
    amortization_start_month     TEXT NOT NULL,
    amortization_end_month       TEXT NOT NULL,
    is_active                    INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    note                         TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS daily_reviews (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    review_date                  TEXT NOT NULL,
    most_important_thing         TEXT,
    most_valuable_time           TEXT,
    biggest_waste                TEXT,
    state_score                  INTEGER CHECK(state_score BETWEEN 1 AND 10),
    note                         TEXT,
    created_at                   TEXT NOT NULL,
    updated_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, review_date)
);

CREATE TABLE IF NOT EXISTS metric_snapshots (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    snapshot_date                TEXT NOT NULL,
    window_type                  TEXT NOT NULL CHECK(window_type IN ('day', 'week', 'month', 'year', 'range')),
    hourly_rate_cents            INTEGER,
    time_debt_cents              INTEGER,
    passive_cover_ratio          REAL,
    freedom_cents                INTEGER,
    total_income_cents           INTEGER,
    total_expense_cents          INTEGER,
    total_work_minutes           INTEGER,
    generated_at                 TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, snapshot_date, window_type)
);

CREATE TABLE IF NOT EXISTS backup_records (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    backup_type                  TEXT NOT NULL CHECK(backup_type IN ('daily_incremental', 'weekly_full', 'monthly_archive', 'manual')),
    file_path                    TEXT NOT NULL,
    file_size_bytes              INTEGER,
    checksum                     TEXT,
    status                       TEXT NOT NULL CHECK(status IN ('success', 'failed')),
    error_message                TEXT,
    created_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS restore_records (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    backup_record_id             TEXT,
    status                       TEXT NOT NULL CHECK(status IN ('success', 'failed')),
    error_message                TEXT,
    restored_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (backup_record_id) REFERENCES backup_records(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id                           TEXT PRIMARY KEY,
    user_id                      TEXT NOT NULL,
    entity_type                  TEXT NOT NULL,
    entity_id                    TEXT NOT NULL,
    action                       TEXT NOT NULL CHECK(action IN ('insert', 'update', 'delete', 'restore')),
    source                       TEXT NOT NULL CHECK(source IN ('manual', 'external', 'system', 'import')),
    before_json                  TEXT,
    after_json                   TEXT,
    created_at                   TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_projects_user_status
    ON projects(user_id, is_deleted, status_code, started_on);
CREATE INDEX IF NOT EXISTS idx_tags_user_scope_status
    ON tags(user_id, scope, status, sort_order);
CREATE INDEX IF NOT EXISTS idx_time_records_user_started
    ON time_records(user_id, is_deleted, started_at);
CREATE INDEX IF NOT EXISTS idx_time_records_user_category_started
    ON time_records(user_id, is_deleted, category_code, started_at);
CREATE INDEX IF NOT EXISTS idx_income_records_user_date
    ON income_records(user_id, is_deleted, occurred_on);
CREATE INDEX IF NOT EXISTS idx_income_records_user_type_date
    ON income_records(user_id, is_deleted, type_code, occurred_on);
CREATE INDEX IF NOT EXISTS idx_expense_records_user_date
    ON expense_records(user_id, is_deleted, occurred_on);
CREATE INDEX IF NOT EXISTS idx_expense_records_user_category_date
    ON expense_records(user_id, is_deleted, category_code, occurred_on);
CREATE INDEX IF NOT EXISTS idx_learning_records_user_date
    ON learning_records(user_id, is_deleted, occurred_on);
CREATE INDEX IF NOT EXISTS idx_record_project_links_project
    ON record_project_links(project_id, record_kind, record_id);
CREATE INDEX IF NOT EXISTS idx_record_project_links_user
    ON record_project_links(user_id, record_kind, created_at);
CREATE INDEX IF NOT EXISTS idx_record_tag_links_tag
    ON record_tag_links(tag_id, record_kind, record_id);
CREATE INDEX IF NOT EXISTS idx_record_tag_links_user
    ON record_tag_links(user_id, record_kind, created_at);
CREATE INDEX IF NOT EXISTS idx_expense_baseline_months_user_month
    ON expense_baseline_months(user_id, month);
CREATE INDEX IF NOT EXISTS idx_expense_recurring_rules_user_active
    ON expense_recurring_rules(user_id, is_active, start_month, end_month);
CREATE INDEX IF NOT EXISTS idx_expense_capex_items_user_active
    ON expense_capex_items(user_id, is_active, amortization_start_month, amortization_end_month);
CREATE INDEX IF NOT EXISTS idx_metric_snapshots_user_date
    ON metric_snapshots(user_id, snapshot_date, window_type);
CREATE INDEX IF NOT EXISTS idx_backup_records_user_created
    ON backup_records(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_entity
    ON audit_logs(user_id, entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created
    ON audit_logs(user_id, created_at);
