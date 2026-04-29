PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS review_notes (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    occurred_on                 TEXT NOT NULL,
    note_type                   TEXT NOT NULL CHECK(note_type IN ('reflection', 'feeling', 'plan', 'idea', 'context', 'ai_usage', 'risk', 'summary')),
    title                       TEXT NOT NULL,
    content                     TEXT NOT NULL,
    source                      TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual', 'ai_capture', 'import')),
    visibility                  TEXT NOT NULL DEFAULT 'compact' CHECK(visibility IN ('hidden', 'compact', 'normal')),
    confidence                  REAL CHECK(confidence >= 0.0 AND confidence <= 1.0),
    raw_text                    TEXT,
    linked_record_kind          TEXT CHECK(linked_record_kind IN ('time', 'income', 'expense', 'learning')),
    linked_record_id            TEXT,
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_review_notes_user_date
    ON review_notes(user_id, occurred_on, visibility, note_type);

CREATE INDEX IF NOT EXISTS idx_review_notes_linked_record
    ON review_notes(user_id, linked_record_kind, linked_record_id);
