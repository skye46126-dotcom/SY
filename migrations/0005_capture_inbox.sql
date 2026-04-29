PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS capture_inbox (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    source                      TEXT NOT NULL,
    entry_point                 TEXT NOT NULL,
    raw_text                    TEXT NOT NULL,
    context_date                TEXT,
    route_hint                  TEXT,
    record_type_hint            TEXT,
    mode_hint                   TEXT,
    parser_mode_hint            TEXT,
    device_context_json         TEXT,
    status                      TEXT NOT NULL CHECK(status IN ('queued', 'parsing', 'draft_ready', 'committed', 'failed', 'archived')),
    request_id                  TEXT,
    draft_envelope_json         TEXT,
    warnings_json               TEXT NOT NULL DEFAULT '[]',
    error_message               TEXT,
    processed_at                TEXT,
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_capture_inbox_user_status_updated
    ON capture_inbox(user_id, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_capture_inbox_user_created
    ON capture_inbox(user_id, created_at DESC);
