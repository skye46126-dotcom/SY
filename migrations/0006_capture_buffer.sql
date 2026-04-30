PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS capture_buffer_sessions (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    source                      TEXT NOT NULL,
    entry_point                 TEXT NOT NULL,
    context_date                TEXT,
    route_hint                  TEXT,
    mode_hint                   TEXT,
    parser_mode_hint            TEXT,
    status                      TEXT NOT NULL CHECK(status IN ('active', 'processed', 'committed', 'archived')),
    item_count                  INTEGER NOT NULL DEFAULT 0,
    latest_combined_text        TEXT,
    latest_inbox_id             TEXT,
    processed_at                TEXT,
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_capture_buffer_sessions_user_status_updated
    ON capture_buffer_sessions(user_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS capture_buffer_items (
    id                          TEXT PRIMARY KEY,
    session_id                  TEXT NOT NULL,
    user_id                     TEXT NOT NULL,
    sequence_no                 INTEGER NOT NULL,
    raw_text                    TEXT NOT NULL,
    source                      TEXT NOT NULL,
    input_kind                  TEXT NOT NULL CHECK(input_kind IN ('text', 'voice')),
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES capture_buffer_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_capture_buffer_items_session_sequence
    ON capture_buffer_items(session_id, sequence_no, created_at);
