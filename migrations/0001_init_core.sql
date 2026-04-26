PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id                          TEXT PRIMARY KEY,
    username                    TEXT NOT NULL UNIQUE,
    display_name                TEXT NOT NULL,
    timezone                    TEXT NOT NULL DEFAULT 'Asia/Shanghai',
    currency_code               TEXT NOT NULL DEFAULT 'CNY',
    ideal_hourly_rate_cents     INTEGER NOT NULL DEFAULT 0 CHECK(ideal_hourly_rate_cents >= 0),
    status                      TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'disabled')),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
    user_id                     TEXT NOT NULL,
    key                         TEXT NOT NULL,
    value_json                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    PRIMARY KEY (user_id, key),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS dim_project_status (
    code                        TEXT PRIMARY KEY,
    display_name                TEXT NOT NULL,
    sort_order                  INTEGER NOT NULL DEFAULT 0,
    is_active                   INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    is_system                   INTEGER NOT NULL DEFAULT 1 CHECK(is_system IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_time_categories (
    code                        TEXT PRIMARY KEY,
    display_name                TEXT NOT NULL,
    sort_order                  INTEGER NOT NULL DEFAULT 0,
    is_active                   INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    is_system                   INTEGER NOT NULL DEFAULT 1 CHECK(is_system IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_income_types (
    code                        TEXT PRIMARY KEY,
    display_name                TEXT NOT NULL,
    sort_order                  INTEGER NOT NULL DEFAULT 0,
    is_active                   INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    is_system                   INTEGER NOT NULL DEFAULT 1 CHECK(is_system IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_expense_categories (
    code                        TEXT PRIMARY KEY,
    display_name                TEXT NOT NULL,
    sort_order                  INTEGER NOT NULL DEFAULT 0,
    is_active                   INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    is_system                   INTEGER NOT NULL DEFAULT 1 CHECK(is_system IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_learning_levels (
    code                        TEXT PRIMARY KEY,
    display_name                TEXT NOT NULL,
    sort_order                  INTEGER NOT NULL DEFAULT 0,
    is_active                   INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    is_system                   INTEGER NOT NULL DEFAULT 1 CHECK(is_system IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS projects (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    name                        TEXT NOT NULL,
    status_code                 TEXT NOT NULL,
    started_on                  TEXT NOT NULL,
    ended_on                    TEXT,
    ai_enable_ratio             INTEGER CHECK(ai_enable_ratio BETWEEN 0 AND 100),
    score                       INTEGER CHECK(score BETWEEN 1 AND 10),
    note                        TEXT,
    is_deleted                  INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (status_code) REFERENCES dim_project_status(code) ON DELETE RESTRICT,
    UNIQUE(user_id, name)
);

CREATE TABLE IF NOT EXISTS project_members (
    project_id                   TEXT NOT NULL,
    user_id                      TEXT NOT NULL,
    role                         TEXT NOT NULL CHECK(role IN ('owner', 'member')),
    created_at                   TEXT NOT NULL,
    PRIMARY KEY (project_id, user_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tags (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    name                        TEXT NOT NULL,
    emoji                       TEXT,
    tag_group                   TEXT NOT NULL DEFAULT 'custom',
    scope                       TEXT NOT NULL DEFAULT 'global',
    parent_tag_id               TEXT,
    level                       INTEGER NOT NULL DEFAULT 1 CHECK(level >= 1),
    status                      TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'inactive', 'archived')),
    sort_order                  INTEGER NOT NULL DEFAULT 0,
    is_system                   INTEGER NOT NULL DEFAULT 0 CHECK(is_system IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_tag_id) REFERENCES tags(id) ON DELETE SET NULL,
    UNIQUE(user_id, scope, name)
);

CREATE TABLE IF NOT EXISTS time_records (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    started_at                  TEXT NOT NULL,
    ended_at                    TEXT NOT NULL,
    duration_minutes            INTEGER NOT NULL CHECK(duration_minutes > 0),
    category_code               TEXT NOT NULL,
    efficiency_score            INTEGER CHECK(efficiency_score BETWEEN 1 AND 10),
    value_score                 INTEGER CHECK(value_score BETWEEN 1 AND 10),
    state_score                 INTEGER CHECK(state_score BETWEEN 1 AND 10),
    ai_assist_ratio             INTEGER CHECK(ai_assist_ratio BETWEEN 0 AND 100),
    note                        TEXT,
    source                      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual', 'external', 'import', 'system')),
    parse_confidence            REAL CHECK(parse_confidence >= 0.0 AND parse_confidence <= 1.0),
    is_public_pool              INTEGER NOT NULL DEFAULT 0 CHECK(is_public_pool IN (0, 1)),
    is_deleted                  INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_code) REFERENCES dim_time_categories(code) ON DELETE RESTRICT,
    CHECK(ended_at > started_at)
);

CREATE TABLE IF NOT EXISTS income_records (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    occurred_on                 TEXT NOT NULL,
    source_name                 TEXT NOT NULL,
    type_code                   TEXT NOT NULL,
    amount_cents                INTEGER NOT NULL CHECK(amount_cents >= 0),
    is_passive                  INTEGER NOT NULL DEFAULT 0 CHECK(is_passive IN (0, 1)),
    ai_assist_ratio             INTEGER CHECK(ai_assist_ratio BETWEEN 0 AND 100),
    note                        TEXT,
    source                      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual', 'external', 'import', 'system')),
    parse_confidence            REAL CHECK(parse_confidence >= 0.0 AND parse_confidence <= 1.0),
    is_public_pool              INTEGER NOT NULL DEFAULT 0 CHECK(is_public_pool IN (0, 1)),
    is_deleted                  INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (type_code) REFERENCES dim_income_types(code) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS expense_records (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    occurred_on                 TEXT NOT NULL,
    category_code               TEXT NOT NULL,
    amount_cents                INTEGER NOT NULL CHECK(amount_cents >= 0),
    ai_assist_ratio             INTEGER CHECK(ai_assist_ratio BETWEEN 0 AND 100),
    note                        TEXT,
    source                      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual', 'external', 'import', 'system')),
    parse_confidence            REAL CHECK(parse_confidence >= 0.0 AND parse_confidence <= 1.0),
    is_deleted                  INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_code) REFERENCES dim_expense_categories(code) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS learning_records (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    occurred_on                 TEXT NOT NULL,
    started_at                  TEXT,
    ended_at                    TEXT,
    content                     TEXT NOT NULL,
    duration_minutes            INTEGER NOT NULL CHECK(duration_minutes >= 0),
    application_level_code      TEXT NOT NULL,
    efficiency_score            INTEGER CHECK(efficiency_score BETWEEN 1 AND 10),
    ai_assist_ratio             INTEGER CHECK(ai_assist_ratio BETWEEN 0 AND 100),
    note                        TEXT,
    source                      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual', 'external', 'import', 'system')),
    parse_confidence            REAL CHECK(parse_confidence >= 0.0 AND parse_confidence <= 1.0),
    is_public_pool              INTEGER NOT NULL DEFAULT 0 CHECK(is_public_pool IN (0, 1)),
    is_deleted                  INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1)),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (application_level_code) REFERENCES dim_learning_levels(code) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS record_project_links (
    record_kind                 TEXT NOT NULL CHECK(record_kind IN ('time', 'income', 'expense', 'learning')),
    record_id                   TEXT NOT NULL,
    project_id                  TEXT NOT NULL,
    user_id                     TEXT NOT NULL,
    weight_ratio                REAL NOT NULL DEFAULT 1.0 CHECK(weight_ratio > 0),
    created_at                  TEXT NOT NULL,
    PRIMARY KEY (record_kind, record_id, project_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS record_tag_links (
    record_kind                 TEXT NOT NULL CHECK(record_kind IN ('project', 'time', 'income', 'expense', 'learning')),
    record_id                   TEXT NOT NULL,
    tag_id                      TEXT NOT NULL,
    user_id                     TEXT NOT NULL,
    created_at                  TEXT NOT NULL,
    PRIMARY KEY (record_kind, record_id, tag_id),
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO dim_project_status(code, display_name, sort_order, is_active, is_system, created_at, updated_at)
VALUES
    ('active', 'Active', 10, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('paused', 'Paused', 20, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('done', 'Done', 30, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT OR IGNORE INTO dim_time_categories(code, display_name, sort_order, is_active, is_system, created_at, updated_at)
VALUES
    ('work', 'Work', 10, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('learning', 'Learning', 20, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('life', 'Life', 30, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('entertainment', 'Entertainment', 40, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('rest', 'Rest', 50, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('social', 'Social', 60, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT OR IGNORE INTO dim_income_types(code, display_name, sort_order, is_active, is_system, created_at, updated_at)
VALUES
    ('salary', 'Salary', 10, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('project', 'Project', 20, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('investment', 'Investment', 30, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('system', 'System', 40, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('other', 'Other', 50, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT OR IGNORE INTO dim_expense_categories(code, display_name, sort_order, is_active, is_system, created_at, updated_at)
VALUES
    ('necessary', 'Necessary', 10, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('experience', 'Experience', 20, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('subscription', 'Subscription', 30, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('investment', 'Investment', 40, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT OR IGNORE INTO dim_learning_levels(code, display_name, sort_order, is_active, is_system, created_at, updated_at)
VALUES
    ('input', 'Input', 10, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('applied', 'Applied', 20, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('result', 'Result', 30, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
