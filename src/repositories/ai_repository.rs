use std::collections::{HashMap, HashSet};

use chrono::{Datelike, Duration, NaiveDate, NaiveDateTime, NaiveTime, TimeZone, Utc};
use chrono_tz::Tz;
use rusqlite::{Connection, OptionalExtension, params};

use crate::error::{LifeOsError, Result};
use crate::models::{
    AiCommitFailure, AiCommitInput, AiCommitResult, AiCommittedRecord, AiDraftKind, AiParseDraft,
    AiServiceConfig, CreateAiServiceConfigInput, CreateExpenseRecordInput, CreateIncomeRecordInput,
    CreateLearningRecordInput, CreateTagInput, CreateTimeRecordInput, ParseContext, ParserMode,
    ProjectAllocation, normalize_optional_string,
};
use crate::repositories::record_repository::{
    DimensionKind, ensure_project_allocations_exist, ensure_tags_exist, ensure_user_exists,
    insert_project_links, insert_tag_links, new_id, now_string, upsert_dimension_code,
};

pub struct AiRepository;

impl AiRepository {
    pub fn create_service_config(
        connection: &mut Connection,
        input: &CreateAiServiceConfigInput,
    ) -> Result<AiServiceConfig> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        if input.is_active {
            deactivate_other_configs(&tx, &input.user_id, None)?;
        }

        let id = new_id();
        let now = now_string();
        let config = AiServiceConfig {
            id: id.clone(),
            user_id: input.user_id.clone(),
            provider: input.normalized_provider()?,
            base_url: input.normalized_base_url(),
            api_key_encrypted: input.normalized_api_key_encrypted(),
            model: input.normalized_model(),
            system_prompt: input.normalized_system_prompt(),
            parser_mode: input.resolved_parser_mode(),
            temperature_milli: input.temperature_milli,
            is_active: input.is_active,
            last_validated_at: None,
            created_at: now.clone(),
            updated_at: now.clone(),
        };

        tx.execute(
            "INSERT INTO ai_service_configs(
                id, user_id, provider, base_url, api_key_encrypted, model, system_prompt,
                parser_mode, temperature_milli, is_active, last_validated_at, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, NULL, ?11, ?11)",
            params![
                config.id,
                config.user_id,
                config.provider,
                config.base_url,
                config.api_key_encrypted,
                config.model,
                config.system_prompt,
                config.parser_mode.as_str(),
                config.temperature_milli,
                config.is_active as i32,
                config.created_at,
            ],
        )?;

        tx.commit()?;
        Ok(config)
    }

    pub fn update_service_config(
        connection: &mut Connection,
        config_id: &str,
        input: &CreateAiServiceConfigInput,
    ) -> Result<AiServiceConfig> {
        input.validate()?;

        let tx = connection.transaction()?;
        ensure_user_exists(&tx, &input.user_id)?;
        let existing = load_service_config(&tx, config_id, &input.user_id)?.ok_or_else(|| {
            LifeOsError::InvalidInput(format!("AI service config not found: {config_id}"))
        })?;
        if input.is_active {
            deactivate_other_configs(&tx, &input.user_id, Some(config_id))?;
        }
        let now = now_string();
        tx.execute(
            "UPDATE ai_service_configs
             SET provider = ?3,
                 base_url = ?4,
                 api_key_encrypted = ?5,
                 model = ?6,
                 system_prompt = ?7,
                 parser_mode = ?8,
                 temperature_milli = ?9,
                 is_active = ?10,
                 updated_at = ?11
             WHERE id = ?1 AND user_id = ?2",
            params![
                config_id,
                input.user_id,
                input.normalized_provider()?,
                input.normalized_base_url(),
                input.normalized_api_key_encrypted(),
                input.normalized_model(),
                input.normalized_system_prompt(),
                input.resolved_parser_mode().as_str(),
                input.temperature_milli,
                input.is_active as i32,
                now,
            ],
        )?;
        tx.commit()?;

        Ok(AiServiceConfig {
            id: existing.id,
            user_id: input.user_id.clone(),
            provider: input.normalized_provider()?,
            base_url: input.normalized_base_url(),
            api_key_encrypted: input.normalized_api_key_encrypted(),
            model: input.normalized_model(),
            system_prompt: input.normalized_system_prompt(),
            parser_mode: input.resolved_parser_mode(),
            temperature_milli: input.temperature_milli,
            is_active: input.is_active,
            last_validated_at: existing.last_validated_at,
            created_at: existing.created_at,
            updated_at: now,
        })
    }

    pub fn delete_service_config(
        connection: &mut Connection,
        user_id: &str,
        config_id: &str,
    ) -> Result<()> {
        ensure_user_exists(connection, user_id)?;
        let deleted = connection.execute(
            "DELETE FROM ai_service_configs WHERE id = ?1 AND user_id = ?2",
            params![config_id, user_id],
        )?;
        if deleted == 0 {
            return Err(LifeOsError::InvalidInput(format!(
                "AI service config not found: {config_id}"
            )));
        }
        Ok(())
    }

    pub fn list_service_configs(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Vec<AiServiceConfig>> {
        ensure_user_exists(connection, user_id)?;
        let mut statement = connection.prepare(
            "SELECT id, user_id, provider, base_url, api_key_encrypted, model, system_prompt,
                    parser_mode, temperature_milli, is_active, last_validated_at, created_at, updated_at
             FROM ai_service_configs
             WHERE user_id = ?1
             ORDER BY is_active DESC, updated_at DESC, created_at DESC",
        )?;
        let rows = statement.query_map([user_id], map_ai_service_config_row)?;
        rows.collect::<std::result::Result<Vec<_>, _>>()
            .map_err(Into::into)
    }

    pub fn get_active_service_config(
        connection: &Connection,
        user_id: &str,
    ) -> Result<Option<AiServiceConfig>> {
        ensure_user_exists(connection, user_id)?;
        connection
            .query_row(
                "SELECT id, user_id, provider, base_url, api_key_encrypted, model, system_prompt,
                        parser_mode, temperature_milli, is_active, last_validated_at, created_at, updated_at
                 FROM ai_service_configs
                 WHERE user_id = ?1 AND is_active = 1
                 ORDER BY updated_at DESC
                 LIMIT 1",
                [user_id],
                map_ai_service_config_row,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn load_parse_context(connection: &Connection, user_id: &str) -> Result<ParseContext> {
        ensure_user_exists(connection, user_id)?;
        let category_codes = load_dimension_codes(connection, "dim_time_categories")?;
        let project_names = load_named_values(
            connection,
            "SELECT name FROM projects WHERE user_id = ?1 AND is_deleted = 0 ORDER BY updated_at DESC, name COLLATE NOCASE ASC",
            user_id,
        )?;
        let tag_names = load_named_values(
            connection,
            "SELECT name FROM tags WHERE user_id = ?1 AND status = 'active' ORDER BY sort_order ASC, name COLLATE NOCASE ASC",
            user_id,
        )?;
        Ok(ParseContext {
            category_codes,
            project_names,
            tag_names,
            rule_hints: Vec::new(),
        })
    }

    pub fn commit_drafts(
        connection: &mut Connection,
        input: &AiCommitInput,
    ) -> Result<AiCommitResult> {
        input.validate()?;
        ensure_user_exists(connection, &input.user_id)?;

        let request_id = input.resolved_request_id();
        let context_date = input.resolved_context_date();
        let source = input.options.normalized_source()?;
        let mut committed = Vec::new();
        let mut failures = Vec::new();
        let mut warnings = Vec::new();

        for draft in &input.drafts {
            if draft.kind == AiDraftKind::Unknown {
                failures.push(AiCommitFailure {
                    draft_id: draft.draft_id.clone(),
                    kind: draft.kind.clone(),
                    message: "unknown draft cannot be committed".to_string(),
                });
                continue;
            }

            match commit_one_draft(
                connection,
                &input.user_id,
                &context_date,
                draft,
                &input.options,
                &source,
            ) {
                Ok(record) => {
                    warnings.extend(record.warnings.clone());
                    committed.push(record);
                }
                Err(error) => failures.push(AiCommitFailure {
                    draft_id: draft.draft_id.clone(),
                    kind: draft.kind.clone(),
                    message: error.to_string(),
                }),
            }
        }

        Ok(AiCommitResult {
            request_id,
            committed,
            failures,
            warnings,
        })
    }
}

fn commit_one_draft(
    connection: &mut Connection,
    user_id: &str,
    context_date: &str,
    draft: &AiParseDraft,
    options: &crate::models::AiCommitOptions,
    source: &str,
) -> Result<AiCommittedRecord> {
    match draft.kind {
        AiDraftKind::Time => {
            commit_time_draft(connection, user_id, context_date, draft, options, source)
        }
        AiDraftKind::Income => {
            commit_income_draft(connection, user_id, context_date, draft, options, source)
        }
        AiDraftKind::Expense => {
            commit_expense_draft(connection, user_id, context_date, draft, options, source)
        }
        AiDraftKind::Learning => {
            commit_learning_draft(connection, user_id, context_date, draft, options, source)
        }
        AiDraftKind::Unknown => Err(LifeOsError::InvalidInput(
            "unknown draft cannot be committed".to_string(),
        )),
    }
}

fn commit_time_draft(
    connection: &mut Connection,
    user_id: &str,
    context_date: &str,
    draft: &AiParseDraft,
    options: &crate::models::AiCommitOptions,
    source: &str,
) -> Result<AiCommittedRecord> {
    let occurred_on = resolve_item_date(draft, context_date)?;
    let duration_minutes = resolve_duration_minutes(draft, 60)?;
    let (started_at, ended_at, resolved_duration) =
        resolve_time_window(draft, &occurred_on, duration_minutes, "Asia/Shanghai")?;
    let input = CreateTimeRecordInput {
        user_id: user_id.to_string(),
        started_at,
        ended_at,
        category_code: normalize_time_category(
            first_value(draft, &["category", "category_code"]).unwrap_or("work"),
        ),
        efficiency_score: parse_optional_i32(first_value(draft, &["efficiency_score"])),
        value_score: parse_optional_i32(first_value(draft, &["value_score"])),
        state_score: parse_optional_i32(first_value(draft, &["state_score"])),
        ai_assist_ratio: parse_optional_i32(first_value(draft, &["ai_ratio", "ai_assist_ratio"])),
        note: normalize_optional_string(
            &first_value(draft, &["description", "note"]).map(ToString::to_string),
        ),
        source: Some(source.to_string()),
        is_public_pool: false,
        project_allocations: Vec::new(),
        tag_ids: Vec::new(),
    };
    input.validate()?;
    let (project_allocations, tag_ids, warnings) =
        resolve_links_for_draft(connection, user_id, draft, options, "time")?;

    let tx = connection.transaction()?;
    ensure_user_exists(&tx, user_id)?;
    upsert_dimension_code(
        &tx,
        DimensionKind::TimeCategory,
        &input.normalized_category_code(),
    )?;
    ensure_project_allocations_exist(&tx, user_id, &project_allocations)?;
    ensure_tags_exist(&tx, user_id, &tag_ids)?;
    let id = new_id();
    let now = now_string();
    tx.execute(
        "INSERT INTO time_records(
            id, user_id, started_at, ended_at, duration_minutes, category_code,
            efficiency_score, value_score, state_score, ai_assist_ratio, note, source,
            parse_confidence, is_public_pool, is_deleted, created_at, updated_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, 0, 0, ?14, ?14)",
        params![
            id,
            user_id,
            input.started_at,
            input.ended_at,
            resolved_duration,
            input.normalized_category_code(),
            input.efficiency_score,
            input.value_score,
            input.state_score,
            input.ai_assist_ratio,
            input.normalized_note(),
            source,
            draft.confidence.clamp(0.0, 1.0),
            now,
        ],
    )?;
    insert_project_links(&tx, "time", &id, user_id, &project_allocations, &now)?;
    insert_tag_links(&tx, "time", &id, user_id, &tag_ids, &now)?;
    tx.commit()?;

    Ok(AiCommittedRecord {
        draft_id: draft.draft_id.clone(),
        kind: draft.kind.clone(),
        record_id: id,
        occurred_at: occurred_on,
        warnings,
    })
}

fn commit_income_draft(
    connection: &mut Connection,
    user_id: &str,
    context_date: &str,
    draft: &AiParseDraft,
    options: &crate::models::AiCommitOptions,
    source: &str,
) -> Result<AiCommittedRecord> {
    let occurred_on = resolve_item_date(draft, context_date)?;
    let input = CreateIncomeRecordInput {
        user_id: user_id.to_string(),
        occurred_on: occurred_on.clone(),
        source_name: first_value(draft, &["source", "source_name"])
            .unwrap_or("AI Parse")
            .to_string(),
        type_code: normalize_income_type(
            first_value(draft, &["type", "type_code"]).unwrap_or("other"),
        ),
        amount_cents: parse_amount_cents(draft)?,
        is_passive: parse_bool(first_value(draft, &["is_passive"]).unwrap_or("false")),
        ai_assist_ratio: parse_optional_i32(first_value(draft, &["ai_ratio", "ai_assist_ratio"])),
        note: normalize_optional_string(&first_value(draft, &["note"]).map(ToString::to_string)),
        source: Some(source.to_string()),
        is_public_pool: false,
        project_allocations: Vec::new(),
        tag_ids: Vec::new(),
    };
    input.validate()?;
    let (project_allocations, tag_ids, warnings) =
        resolve_links_for_draft(connection, user_id, draft, options, "income")?;

    let tx = connection.transaction()?;
    ensure_user_exists(&tx, user_id)?;
    upsert_dimension_code(
        &tx,
        DimensionKind::IncomeType,
        &input.normalized_type_code(),
    )?;
    ensure_project_allocations_exist(&tx, user_id, &project_allocations)?;
    ensure_tags_exist(&tx, user_id, &tag_ids)?;
    let id = new_id();
    let now = now_string();
    tx.execute(
        "INSERT INTO income_records(
            id, user_id, occurred_on, source_name, type_code, amount_cents, is_passive,
            ai_assist_ratio, note, source, parse_confidence, is_public_pool, is_deleted, created_at, updated_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, 0, 0, ?12, ?12)",
        params![
            id,
            user_id,
            input.occurred_on,
            input.source_name.trim(),
            input.normalized_type_code(),
            input.amount_cents,
            input.is_passive as i32,
            input.ai_assist_ratio,
            input.normalized_note(),
            source,
            draft.confidence.clamp(0.0, 1.0),
            now,
        ],
    )?;
    insert_project_links(&tx, "income", &id, user_id, &project_allocations, &now)?;
    insert_tag_links(&tx, "income", &id, user_id, &tag_ids, &now)?;
    tx.commit()?;

    Ok(AiCommittedRecord {
        draft_id: draft.draft_id.clone(),
        kind: draft.kind.clone(),
        record_id: id,
        occurred_at: occurred_on,
        warnings,
    })
}

fn commit_expense_draft(
    connection: &mut Connection,
    user_id: &str,
    context_date: &str,
    draft: &AiParseDraft,
    options: &crate::models::AiCommitOptions,
    source: &str,
) -> Result<AiCommittedRecord> {
    let occurred_on = resolve_item_date(draft, context_date)?;
    let input = CreateExpenseRecordInput {
        user_id: user_id.to_string(),
        occurred_on: occurred_on.clone(),
        category_code: normalize_expense_category(
            first_value(draft, &["category", "category_code"]).unwrap_or("necessary"),
        ),
        amount_cents: parse_amount_cents(draft)?,
        ai_assist_ratio: parse_optional_i32(first_value(draft, &["ai_ratio", "ai_assist_ratio"])),
        note: normalize_optional_string(&first_value(draft, &["note"]).map(ToString::to_string)),
        source: Some(source.to_string()),
        project_allocations: Vec::new(),
        tag_ids: Vec::new(),
    };
    input.validate()?;
    let (project_allocations, tag_ids, warnings) =
        resolve_links_for_draft(connection, user_id, draft, options, "expense")?;

    let tx = connection.transaction()?;
    ensure_user_exists(&tx, user_id)?;
    upsert_dimension_code(
        &tx,
        DimensionKind::ExpenseCategory,
        &input.normalized_category_code(),
    )?;
    ensure_project_allocations_exist(&tx, user_id, &project_allocations)?;
    ensure_tags_exist(&tx, user_id, &tag_ids)?;
    let id = new_id();
    let now = now_string();
    tx.execute(
        "INSERT INTO expense_records(
            id, user_id, occurred_on, category_code, amount_cents, ai_assist_ratio,
            note, source, parse_confidence, is_deleted, created_at, updated_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 0, ?10, ?10)",
        params![
            id,
            user_id,
            input.occurred_on,
            input.normalized_category_code(),
            input.amount_cents,
            input.ai_assist_ratio,
            input.normalized_note(),
            source,
            draft.confidence.clamp(0.0, 1.0),
            now,
        ],
    )?;
    insert_project_links(&tx, "expense", &id, user_id, &project_allocations, &now)?;
    insert_tag_links(&tx, "expense", &id, user_id, &tag_ids, &now)?;
    tx.commit()?;

    Ok(AiCommittedRecord {
        draft_id: draft.draft_id.clone(),
        kind: draft.kind.clone(),
        record_id: id,
        occurred_at: occurred_on,
        warnings,
    })
}

fn commit_learning_draft(
    connection: &mut Connection,
    user_id: &str,
    context_date: &str,
    draft: &AiParseDraft,
    options: &crate::models::AiCommitOptions,
    source: &str,
) -> Result<AiCommittedRecord> {
    let occurred_on = resolve_item_date(draft, context_date)?;
    let duration_minutes = resolve_duration_minutes(draft, 60)?;
    let (started_at, ended_at, resolved_duration) =
        resolve_optional_time_window(draft, &occurred_on, duration_minutes, "Asia/Shanghai")?;
    let input = CreateLearningRecordInput {
        user_id: user_id.to_string(),
        occurred_on: occurred_on.clone(),
        started_at,
        ended_at,
        content: first_value(draft, &["content", "description"])
            .unwrap_or("Learning")
            .to_string(),
        duration_minutes: resolved_duration,
        application_level_code: normalize_learning_level(
            first_value(draft, &["application_level", "application_level_code"]).unwrap_or("input"),
        ),
        efficiency_score: parse_optional_i32(first_value(draft, &["efficiency_score"])),
        ai_assist_ratio: parse_optional_i32(first_value(draft, &["ai_ratio", "ai_assist_ratio"])),
        note: normalize_optional_string(&first_value(draft, &["note"]).map(ToString::to_string)),
        source: Some(source.to_string()),
        is_public_pool: false,
        project_allocations: Vec::new(),
        tag_ids: Vec::new(),
    };
    input.validate()?;
    let (project_allocations, tag_ids, warnings) =
        resolve_links_for_draft(connection, user_id, draft, options, "learning")?;

    let tx = connection.transaction()?;
    ensure_user_exists(&tx, user_id)?;
    upsert_dimension_code(
        &tx,
        DimensionKind::LearningLevel,
        &input.normalized_application_level_code(),
    )?;
    ensure_project_allocations_exist(&tx, user_id, &project_allocations)?;
    ensure_tags_exist(&tx, user_id, &tag_ids)?;
    let id = new_id();
    let now = now_string();
    tx.execute(
        "INSERT INTO learning_records(
            id, user_id, occurred_on, started_at, ended_at, content, duration_minutes,
            application_level_code, efficiency_score, ai_assist_ratio, note, source, parse_confidence,
            is_public_pool, is_deleted, created_at, updated_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, 0, 0, ?14, ?14)",
        params![
            id,
            user_id,
            input.occurred_on,
            input.started_at,
            input.ended_at,
            input.content.trim(),
            input.duration_minutes,
            input.normalized_application_level_code(),
            input.efficiency_score,
            input.ai_assist_ratio,
            input.normalized_note(),
            source,
            draft.confidence.clamp(0.0, 1.0),
            now,
        ],
    )?;
    insert_project_links(&tx, "learning", &id, user_id, &project_allocations, &now)?;
    insert_tag_links(&tx, "learning", &id, user_id, &tag_ids, &now)?;
    tx.commit()?;

    Ok(AiCommittedRecord {
        draft_id: draft.draft_id.clone(),
        kind: draft.kind.clone(),
        record_id: id,
        occurred_at: occurred_on,
        warnings,
    })
}

fn resolve_links_for_draft(
    connection: &mut Connection,
    user_id: &str,
    draft: &AiParseDraft,
    options: &crate::models::AiCommitOptions,
    tag_scope: &str,
) -> Result<(Vec<ProjectAllocation>, Vec<String>, Vec<String>)> {
    let project_refs = first_value(
        draft,
        &[
            "project_allocations",
            "project_names",
            "projects",
            "project",
        ],
    )
    .map(parse_multi_values)
    .unwrap_or_default();
    let tag_refs = first_value(draft, &["tag_ids", "tag_names", "tags", "tag"])
        .map(parse_multi_values)
        .unwrap_or_default();

    let (project_allocations, mut warnings) = resolve_project_allocations(
        connection,
        user_id,
        &project_refs,
        options.strict_reference_resolution,
    )?;
    let (tag_ids, tag_warnings) =
        resolve_tag_ids(connection, user_id, &tag_refs, tag_scope, options)?;
    warnings.extend(tag_warnings);
    Ok((project_allocations, tag_ids, warnings))
}

fn resolve_project_allocations(
    connection: &Connection,
    user_id: &str,
    refs: &[String],
    strict: bool,
) -> Result<(Vec<ProjectAllocation>, Vec<String>)> {
    if refs.is_empty() {
        return Ok((Vec::new(), Vec::new()));
    }

    let mut statement = connection.prepare(
        "SELECT id, name FROM projects WHERE user_id = ?1 AND is_deleted = 0 ORDER BY updated_at DESC",
    )?;
    let rows = statement.query_map([user_id], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
    })?;
    let entries = rows.collect::<std::result::Result<Vec<_>, _>>()?;
    let id_set: HashSet<String> = entries.iter().map(|(id, _)| id.clone()).collect();
    let mut name_map = HashMap::new();
    for (id, name) in entries {
        name_map.insert(name.to_lowercase(), id);
    }

    let mut allocations = Vec::new();
    let mut warnings = Vec::new();
    for item in refs {
        let (raw_ref, weight_ratio) = split_weight(item);
        let project_id = if id_set.contains(&raw_ref) {
            Some(raw_ref.clone())
        } else {
            name_map.get(&raw_ref.to_lowercase()).cloned()
        };
        match project_id {
            Some(project_id) => allocations.push(ProjectAllocation {
                project_id,
                weight_ratio,
            }),
            None if strict => {
                return Err(LifeOsError::InvalidInput(format!(
                    "project reference not found: {raw_ref}"
                )));
            }
            None => warnings.push(format!("project skipped: {raw_ref}")),
        }
    }

    Ok((allocations, warnings))
}

fn resolve_tag_ids(
    connection: &mut Connection,
    user_id: &str,
    refs: &[String],
    tag_scope: &str,
    options: &crate::models::AiCommitOptions,
) -> Result<(Vec<String>, Vec<String>)> {
    if refs.is_empty() {
        return Ok((Vec::new(), Vec::new()));
    }

    let entries = {
        let mut statement = connection.prepare(
            "SELECT id, name FROM tags WHERE user_id = ?1 ORDER BY sort_order ASC, name COLLATE NOCASE ASC",
        )?;
        let rows = statement.query_map([user_id], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        rows.collect::<std::result::Result<Vec<_>, _>>()?
    };
    let id_set: HashSet<String> = entries.iter().map(|(id, _)| id.clone()).collect();
    let mut name_map = HashMap::new();
    for (id, name) in entries {
        name_map.insert(name.to_lowercase(), id);
    }

    let mut tag_ids = Vec::new();
    let mut warnings = Vec::new();
    for raw_ref in refs {
        if let Some(tag_id) = if id_set.contains(raw_ref) {
            Some(raw_ref.clone())
        } else {
            name_map.get(&raw_ref.to_lowercase()).cloned()
        } {
            tag_ids.push(tag_id);
            continue;
        }

        if options.auto_create_tags {
            let created = create_missing_tag(connection, user_id, raw_ref, tag_scope)?;
            name_map.insert(raw_ref.to_lowercase(), created.id.clone());
            tag_ids.push(created.id);
            continue;
        }

        if options.strict_reference_resolution {
            return Err(LifeOsError::InvalidInput(format!(
                "tag reference not found: {raw_ref}"
            )));
        }
        warnings.push(format!("tag skipped: {raw_ref}"));
    }
    Ok((tag_ids, warnings))
}

fn create_missing_tag(
    connection: &mut Connection,
    user_id: &str,
    name: &str,
    scope: &str,
) -> Result<crate::models::Tag> {
    let input = CreateTagInput {
        user_id: user_id.to_string(),
        name: name.trim().to_string(),
        emoji: None,
        tag_group: Some("ai".to_string()),
        scope: Some(scope.to_string()),
        parent_tag_id: None,
        level: Some(1),
        status: Some("active".to_string()),
        sort_order: Some(1000),
    };
    input.validate()?;
    let tx = connection.transaction()?;
    ensure_user_exists(&tx, user_id)?;
    let id = new_id();
    let now = now_string();
    tx.execute(
        "INSERT INTO tags(
            id, user_id, name, emoji, tag_group, scope, parent_tag_id, level,
            status, sort_order, is_system, created_at, updated_at
         ) VALUES (?1, ?2, ?3, NULL, ?4, ?5, NULL, ?6, ?7, ?8, 0, ?9, ?9)",
        params![
            id,
            user_id,
            input.normalized_name(),
            input.normalized_tag_group()?,
            input.normalized_scope()?,
            input.resolved_level(),
            input.normalized_status(),
            input.resolved_sort_order(),
            now,
        ],
    )?;
    tx.commit()?;
    Ok(crate::models::Tag {
        id,
        user_id: user_id.to_string(),
        name: input.normalized_name(),
        emoji: None,
        tag_group: input.normalized_tag_group()?,
        scope: input.normalized_scope()?,
        parent_tag_id: None,
        level: input.resolved_level(),
        status: input.normalized_status(),
        sort_order: input.resolved_sort_order(),
        is_system: false,
        created_at: now.clone(),
        updated_at: now,
    })
}

fn first_value<'a>(draft: &'a AiParseDraft, keys: &[&str]) -> Option<&'a str> {
    keys.iter().find_map(|key| draft.payload_value(key))
}

fn resolve_item_date(draft: &AiParseDraft, context_date: &str) -> Result<String> {
    let value = first_value(draft, &["date", "occurred_on"]).unwrap_or(context_date);
    NaiveDate::parse_from_str(value.trim(), "%Y-%m-%d")
        .map(|value| value.to_string())
        .map_err(|error| LifeOsError::InvalidInput(format!("invalid draft date: {error}")))
}

fn parse_optional_i32(value: Option<&str>) -> Option<i32> {
    value.and_then(|value| value.trim().parse::<i32>().ok())
}

fn parse_bool(value: &str) -> bool {
    matches!(
        value.trim().to_lowercase().as_str(),
        "1" | "true" | "yes" | "y" | "是"
    )
}

fn parse_amount_cents(draft: &AiParseDraft) -> Result<i64> {
    if let Some(value) = first_value(draft, &["amount_cents"]) {
        return value
            .trim()
            .parse::<i64>()
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid amount_cents: {error}")));
    }

    let raw = first_value(draft, &["amount", "amount_yuan", "money"])
        .ok_or_else(|| LifeOsError::InvalidInput("draft amount is required".to_string()))?;
    let lower = raw.to_lowercase();
    let numeric = extract_first_decimal(raw)
        .ok_or_else(|| LifeOsError::InvalidInput(format!("invalid amount value: {raw}")))?;
    let mut amount = numeric;
    if lower.contains("万") || lower.split_whitespace().any(|value| value == "w") {
        amount *= 10_000.0;
    } else if lower.contains("千") || lower.split_whitespace().any(|value| value == "k") {
        amount *= 1_000.0;
    } else if lower.contains("分") && !lower.contains("元") && !lower.contains("块") {
        return Ok(amount.round() as i64);
    }
    Ok((amount * 100.0).round() as i64)
}

fn extract_first_decimal(value: &str) -> Option<f64> {
    let mut number = String::new();
    let mut found = false;
    for ch in value.chars() {
        if ch.is_ascii_digit() || ch == '.' {
            found = true;
            number.push(ch);
        } else if found {
            break;
        }
    }
    number.parse().ok()
}

fn resolve_duration_minutes(draft: &AiParseDraft, fallback_minutes: i64) -> Result<i64> {
    if let Some(value) = first_value(draft, &["duration_minutes", "duration", "minutes"]) {
        if let Some(parsed) = parse_duration_text_minutes(value) {
            return Ok(parsed.max(1));
        }
    }
    if let Some(value) = first_value(draft, &["duration_hours", "hours"]) {
        if let Some(parsed) = extract_first_decimal(value) {
            return Ok((parsed * 60.0).round() as i64);
        }
    }
    Ok(fallback_minutes.max(1))
}

fn parse_duration_text_minutes(value: &str) -> Option<i64> {
    let lower = value.to_lowercase();
    let number = extract_first_decimal(value)?;
    if lower.contains("小时")
        || lower.contains("hour")
        || lower.split_whitespace().any(|token| token == "h")
    {
        return Some((number * 60.0).round() as i64);
    }
    if lower.contains("分钟")
        || lower.contains("min")
        || lower.split_whitespace().any(|token| token == "m")
    {
        return Some(number.round() as i64);
    }
    if value.contains('.') && number <= 12.0 {
        return Some((number * 60.0).round() as i64);
    }
    Some(number.round() as i64)
}

fn resolve_time_window(
    draft: &AiParseDraft,
    item_date: &str,
    fallback_duration_minutes: i64,
    timezone: &str,
) -> Result<(String, String, i64)> {
    let tz: Tz = timezone
        .parse()
        .map_err(|_| LifeOsError::InvalidTimezone(timezone.to_string()))?;
    let base_date = NaiveDate::parse_from_str(item_date, "%Y-%m-%d")
        .map_err(|error| LifeOsError::InvalidInput(format!("invalid item_date: {error}")))?;

    let start = parse_date_time_value(
        first_value(draft, &["started_at", "start_at", "start_time", "start"]),
        base_date,
        &tz,
    )?;
    let end = parse_date_time_value(
        first_value(draft, &["ended_at", "end_at", "end_time", "end"]),
        base_date,
        &tz,
    )?;

    let default_start = tz
        .with_ymd_and_hms(
            base_date.year(),
            base_date.month(),
            base_date.day(),
            9,
            0,
            0,
        )
        .single()
        .ok_or_else(|| LifeOsError::InvalidInput("failed to construct local start".to_string()))?;
    let start = start.unwrap_or(default_start);
    let mut end = end.unwrap_or_else(|| start + Duration::minutes(fallback_duration_minutes));
    if end <= start {
        end += Duration::days(1);
    }
    let duration_minutes = (end - start).num_minutes().max(1);
    Ok((
        start
            .with_timezone(&Utc)
            .to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
        end.with_timezone(&Utc)
            .to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
        duration_minutes,
    ))
}

fn resolve_optional_time_window(
    draft: &AiParseDraft,
    item_date: &str,
    fallback_duration_minutes: i64,
    timezone: &str,
) -> Result<(Option<String>, Option<String>, i64)> {
    let has_explicit_time = first_value(draft, &["started_at", "start_at", "start_time", "start"])
        .is_some()
        || first_value(draft, &["ended_at", "end_at", "end_time", "end"]).is_some();
    if !has_explicit_time {
        return Ok((None, None, fallback_duration_minutes.max(1)));
    }
    let (started_at, ended_at, duration_minutes) =
        resolve_time_window(draft, item_date, fallback_duration_minutes, timezone)?;
    Ok((Some(started_at), Some(ended_at), duration_minutes))
}

fn parse_date_time_value(
    raw: Option<&str>,
    fallback_date: NaiveDate,
    timezone: &Tz,
) -> Result<Option<chrono::DateTime<chrono_tz::Tz>>> {
    let Some(raw) = raw.map(str::trim).filter(|value| !value.is_empty()) else {
        return Ok(None);
    };

    if let Ok(parsed) = chrono::DateTime::parse_from_rfc3339(raw) {
        return Ok(Some(parsed.with_timezone(timezone)));
    }

    let parsed_time = parse_clock(raw)
        .ok_or_else(|| LifeOsError::InvalidInput(format!("invalid draft time value: {raw}")))?;
    let naive = NaiveDateTime::new(fallback_date, parsed_time);
    timezone
        .from_local_datetime(&naive)
        .single()
        .or_else(|| timezone.from_local_datetime(&naive).earliest())
        .map(Some)
        .ok_or_else(|| LifeOsError::InvalidInput(format!("invalid local datetime: {raw}")))
}

fn parse_clock(raw: &str) -> Option<NaiveTime> {
    let trimmed = raw.trim().to_lowercase();
    if let Ok(time) = NaiveTime::parse_from_str(&trimmed, "%H:%M") {
        return Some(time);
    }
    let period = ["上午", "早上", "中午", "下午", "晚上", "凌晨", "傍晚"]
        .iter()
        .find(|period| trimmed.starts_with(**period))
        .copied();
    let normalized = trimmed
        .replace("上午", "")
        .replace("早上", "")
        .replace("中午", "")
        .replace("下午", "")
        .replace("晚上", "")
        .replace("凌晨", "")
        .replace("傍晚", "")
        .replace('点', ":")
        .replace('时', ":")
        .replace("分", "")
        .replace("半", "30")
        .trim()
        .trim_end_matches(':')
        .to_string();
    let mut parts = normalized.split(':');
    let hour = parts.next()?.trim().parse::<u32>().ok()?;
    let minute = parts
        .next()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .and_then(|value| value.parse::<u32>().ok())
        .unwrap_or(0);
    let hour = match period.unwrap_or_default() {
        "下午" | "晚上" | "傍晚" if hour < 12 => hour + 12,
        "中午" if hour < 11 => hour + 12,
        "凌晨" | "上午" | "早上" if hour == 12 => 0,
        _ => hour,
    };
    NaiveTime::from_hms_opt(hour, minute, 0)
}

fn normalize_time_category(value: &str) -> String {
    let lower = value.trim().to_lowercase();
    if lower.contains("learn") || lower.contains("学习") || lower.contains("阅读") {
        "learning".to_string()
    } else if lower.contains("life")
        || lower.contains("生活")
        || lower.contains("家务")
        || lower.contains("通勤")
    {
        "life".to_string()
    } else if lower.contains("entertain")
        || lower.contains("娱乐")
        || lower.contains("电影")
        || lower.contains("游戏")
    {
        "entertainment".to_string()
    } else if lower.contains("rest") || lower.contains("休息") || lower.contains("睡") {
        "rest".to_string()
    } else if lower.contains("social")
        || lower.contains("社交")
        || lower.contains("朋友")
        || lower.contains("聚会")
    {
        "social".to_string()
    } else {
        lower
    }
}

fn normalize_income_type(value: &str) -> String {
    let lower = value.trim().to_lowercase();
    if lower.contains("salary") || lower.contains("工资") || lower.contains("薪") {
        "salary".to_string()
    } else if lower.contains("project")
        || lower.contains("项目")
        || lower.contains("回款")
        || lower.contains("外包")
    {
        "project".to_string()
    } else if lower.contains("invest") || lower.contains("投资") || lower.contains("分红") {
        "investment".to_string()
    } else if lower.contains("system") || lower.contains("系统") || lower.contains("补贴") {
        "system".to_string()
    } else {
        "other".to_string()
    }
}

fn normalize_expense_category(value: &str) -> String {
    let lower = value.trim().to_lowercase();
    if lower.contains("subscription") || lower.contains("订阅") || lower.contains("会员") {
        "subscription".to_string()
    } else if lower.contains("invest") || lower.contains("投资") {
        "investment".to_string()
    } else if lower.contains("experience")
        || lower.contains("娱乐")
        || lower.contains("旅游")
        || lower.contains("聚餐")
    {
        "experience".to_string()
    } else {
        "necessary".to_string()
    }
}

fn normalize_learning_level(value: &str) -> String {
    let lower = value.trim().to_lowercase();
    if lower.contains("result") || lower.contains("成果") || lower.contains("产出") {
        "result".to_string()
    } else if lower.contains("apply")
        || lower.contains("applied")
        || lower.contains("实践")
        || lower.contains("应用")
        || lower.contains("落地")
    {
        "applied".to_string()
    } else {
        "input".to_string()
    }
}

fn parse_multi_values(raw: &str) -> Vec<String> {
    let normalized = raw
        .trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .replace('"', "")
        .replace('\'', "");
    normalized
        .split([',', '，', '、', ';', '；', '\n', '|'])
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
        .collect()
}

fn split_weight(raw: &str) -> (String, f64) {
    for separator in [':', '=', '@'] {
        if let Some((left, right)) = raw.split_once(separator) {
            let left = left.trim().to_string();
            let right = right.trim();
            if let Ok(mut weight) = right.trim_end_matches('%').parse::<f64>() {
                if right.ends_with('%') {
                    weight /= 100.0;
                }
                return (left, weight.max(0.0001));
            }
        }
    }
    (raw.trim().to_string(), 1.0)
}

fn deactivate_other_configs(
    connection: &Connection,
    user_id: &str,
    except_id: Option<&str>,
) -> Result<()> {
    if let Some(except_id) = except_id {
        connection.execute(
            "UPDATE ai_service_configs SET is_active = 0 WHERE user_id = ?1 AND id != ?2",
            params![user_id, except_id],
        )?;
    } else {
        connection.execute(
            "UPDATE ai_service_configs SET is_active = 0 WHERE user_id = ?1",
            [user_id],
        )?;
    }
    Ok(())
}

fn load_dimension_codes(connection: &Connection, table_name: &str) -> Result<Vec<String>> {
    let sql = format!("SELECT code FROM {table_name} ORDER BY sort_order ASC, code ASC");
    let mut statement = connection.prepare(&sql)?;
    let rows = statement.query_map([], |row| row.get::<_, String>(0))?;
    rows.collect::<std::result::Result<Vec<_>, _>>()
        .map_err(Into::into)
}

fn load_named_values(connection: &Connection, sql: &str, user_id: &str) -> Result<Vec<String>> {
    let mut statement = connection.prepare(sql)?;
    let rows = statement.query_map([user_id], |row| row.get::<_, String>(0))?;
    rows.collect::<std::result::Result<Vec<_>, _>>()
        .map_err(Into::into)
}

fn map_ai_service_config_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<AiServiceConfig> {
    let parser_mode: String = row.get(7)?;
    Ok(AiServiceConfig {
        id: row.get(0)?,
        user_id: row.get(1)?,
        provider: row.get(2)?,
        base_url: row.get(3)?,
        api_key_encrypted: row.get(4)?,
        model: row.get(5)?,
        system_prompt: row.get(6)?,
        parser_mode: ParserMode::from_str(&parser_mode)
            .map_err(|error| rusqlite::Error::ToSqlConversionFailure(Box::new(error)))?,
        temperature_milli: row.get(8)?,
        is_active: row.get::<_, i64>(9)? == 1,
        last_validated_at: row.get(10)?,
        created_at: row.get(11)?,
        updated_at: row.get(12)?,
    })
}

fn load_service_config(
    connection: &Connection,
    config_id: &str,
    user_id: &str,
) -> Result<Option<AiServiceConfig>> {
    connection
        .query_row(
            "SELECT id, user_id, provider, base_url, api_key_encrypted, model, system_prompt,
                    parser_mode, temperature_milli, is_active, last_validated_at, created_at, updated_at
             FROM ai_service_configs
             WHERE id = ?1 AND user_id = ?2
             LIMIT 1",
            params![config_id, user_id],
            map_ai_service_config_row,
        )
        .optional()
        .map_err(Into::into)
}
