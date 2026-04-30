PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS time_records_unified (
    id                          TEXT PRIMARY KEY,
    user_id                     TEXT NOT NULL,
    occurred_on                 TEXT NOT NULL,
    started_at                  TEXT,
    ended_at                    TEXT,
    duration_minutes            INTEGER NOT NULL CHECK(duration_minutes >= 0),
    category_code               TEXT NOT NULL,
    content                     TEXT NOT NULL,
    application_level_code      TEXT,
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
    FOREIGN KEY (application_level_code) REFERENCES dim_learning_levels(code) ON DELETE RESTRICT,
    CHECK((started_at IS NULL AND ended_at IS NULL) OR (started_at IS NOT NULL AND ended_at IS NOT NULL AND ended_at > started_at))
);

INSERT INTO time_records_unified(
    id, user_id, occurred_on, started_at, ended_at, duration_minutes, category_code,
    content, application_level_code, efficiency_score, value_score, state_score,
    ai_assist_ratio, note, source, parse_confidence, is_public_pool, is_deleted,
    created_at, updated_at
)
SELECT
    id,
    user_id,
    COALESCE(date(started_at), substr(started_at, 1, 10), date(created_at), substr(created_at, 1, 10)),
    started_at,
    ended_at,
    duration_minutes,
    category_code,
    COALESCE(NULLIF(TRIM(note), ''), category_code),
    NULL,
    efficiency_score,
    value_score,
    state_score,
    ai_assist_ratio,
    note,
    source,
    parse_confidence,
    is_public_pool,
    is_deleted,
    created_at,
    updated_at
FROM time_records;

CREATE TABLE IF NOT EXISTS legacy_learning_record_map (
    legacy_learning_record_id   TEXT PRIMARY KEY,
    new_time_record_id          TEXT NOT NULL UNIQUE
);

INSERT OR IGNORE INTO legacy_learning_record_map(legacy_learning_record_id, new_time_record_id)
SELECT
    l.id,
    CASE
        WHEN EXISTS (SELECT 1 FROM time_records_unified t WHERE t.id = l.id)
        THEN 'learning_' || l.id
        ELSE l.id
    END
FROM learning_records l;

INSERT INTO time_records_unified(
    id, user_id, occurred_on, started_at, ended_at, duration_minutes, category_code,
    content, application_level_code, efficiency_score, value_score, state_score,
    ai_assist_ratio, note, source, parse_confidence, is_public_pool, is_deleted,
    created_at, updated_at
)
SELECT
    m.new_time_record_id,
    l.user_id,
    l.occurred_on,
    l.started_at,
    l.ended_at,
    l.duration_minutes,
    'learning',
    l.content,
    l.application_level_code,
    l.efficiency_score,
    NULL,
    NULL,
    l.ai_assist_ratio,
    l.note,
    l.source,
    l.parse_confidence,
    l.is_public_pool,
    l.is_deleted,
    l.created_at,
    l.updated_at
FROM learning_records l
JOIN legacy_learning_record_map m ON m.legacy_learning_record_id = l.id;

CREATE TABLE record_project_links_unified (
    record_kind                 TEXT NOT NULL CHECK(record_kind IN ('time', 'income', 'expense')),
    record_id                   TEXT NOT NULL,
    project_id                  TEXT NOT NULL,
    user_id                     TEXT NOT NULL,
    weight_ratio                REAL NOT NULL DEFAULT 1.0 CHECK(weight_ratio > 0),
    created_at                  TEXT NOT NULL,
    PRIMARY KEY (record_kind, record_id, project_id),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO record_project_links_unified(record_kind, record_id, project_id, user_id, weight_ratio, created_at)
SELECT
    CASE WHEN rpl.record_kind = 'learning' THEN 'time' ELSE rpl.record_kind END,
    COALESCE(m.new_time_record_id, rpl.record_id),
    rpl.project_id,
    rpl.user_id,
    rpl.weight_ratio,
    rpl.created_at
FROM record_project_links rpl
LEFT JOIN legacy_learning_record_map m
  ON rpl.record_kind = 'learning'
 AND rpl.record_id = m.legacy_learning_record_id
WHERE rpl.record_kind IN ('time', 'income', 'expense', 'learning');

CREATE TABLE record_tag_links_unified (
    record_kind                 TEXT NOT NULL CHECK(record_kind IN ('project', 'time', 'income', 'expense')),
    record_id                   TEXT NOT NULL,
    tag_id                      TEXT NOT NULL,
    user_id                     TEXT NOT NULL,
    created_at                  TEXT NOT NULL,
    PRIMARY KEY (record_kind, record_id, tag_id),
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO record_tag_links_unified(record_kind, record_id, tag_id, user_id, created_at)
SELECT
    CASE WHEN rtl.record_kind = 'learning' THEN 'time' ELSE rtl.record_kind END,
    COALESCE(m.new_time_record_id, rtl.record_id),
    rtl.tag_id,
    rtl.user_id,
    rtl.created_at
FROM record_tag_links rtl
LEFT JOIN legacy_learning_record_map m
  ON rtl.record_kind = 'learning'
 AND rtl.record_id = m.legacy_learning_record_id
WHERE rtl.record_kind IN ('project', 'time', 'income', 'expense', 'learning');

CREATE TABLE review_notes_unified (
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
    linked_record_kind          TEXT CHECK(linked_record_kind IN ('time', 'income', 'expense')),
    linked_record_id            TEXT,
    created_at                  TEXT NOT NULL,
    updated_at                  TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT INTO review_notes_unified(
    id, user_id, occurred_on, note_type, title, content, source, visibility,
    confidence, raw_text, linked_record_kind, linked_record_id, created_at, updated_at
)
SELECT
    rn.id,
    rn.user_id,
    rn.occurred_on,
    rn.note_type,
    rn.title,
    rn.content,
    rn.source,
    rn.visibility,
    rn.confidence,
    rn.raw_text,
    CASE WHEN rn.linked_record_kind = 'learning' THEN 'time' ELSE rn.linked_record_kind END,
    COALESCE(m.new_time_record_id, rn.linked_record_id),
    rn.created_at,
    rn.updated_at
FROM review_notes rn
LEFT JOIN legacy_learning_record_map m
  ON rn.linked_record_kind = 'learning'
 AND rn.linked_record_id = m.legacy_learning_record_id;

DROP TABLE record_project_links;
ALTER TABLE record_project_links_unified RENAME TO record_project_links;

DROP TABLE record_tag_links;
ALTER TABLE record_tag_links_unified RENAME TO record_tag_links;

DROP TABLE review_notes;
ALTER TABLE review_notes_unified RENAME TO review_notes;

DROP TABLE time_records;
ALTER TABLE time_records_unified RENAME TO time_records;

DROP TABLE learning_records;

CREATE INDEX IF NOT EXISTS idx_time_records_user_started
    ON time_records(user_id, is_deleted, started_at);
CREATE INDEX IF NOT EXISTS idx_time_records_user_date
    ON time_records(user_id, is_deleted, occurred_on);
CREATE INDEX IF NOT EXISTS idx_time_records_user_category
    ON time_records(user_id, is_deleted, category_code);
CREATE INDEX IF NOT EXISTS idx_record_project_links_project
    ON record_project_links(project_id, record_kind);
CREATE INDEX IF NOT EXISTS idx_record_tag_links_tag
    ON record_tag_links(tag_id, record_kind);
CREATE INDEX IF NOT EXISTS idx_review_notes_user_date
    ON review_notes(user_id, occurred_on, visibility, note_type);
CREATE INDEX IF NOT EXISTS idx_review_notes_linked_record
    ON review_notes(user_id, linked_record_kind, linked_record_id);

PRAGMA foreign_keys = ON;
