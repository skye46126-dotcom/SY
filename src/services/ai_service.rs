use std::path::Path;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::ai::{AiParseOrchestrator, run_llm_deep_pipeline, run_llm_pipeline, run_rule_pipeline};
use crate::db::Database;
use crate::error::{LifeOsError, Result};
use crate::models::{
    AiCaptureCommitInput, AiCaptureCommitResult, AiCommitFailure, AiCommitInput, AiCommitResult,
    AiDraftKind, AiParseInput, AiParseResult, AiServiceConfig, CreateAiServiceConfigInput,
    ParsePipelineResult,
};
use crate::repositories::ai_repository::AiRepository;
use crate::repositories::review_note_repository::ReviewNoteRepository;

#[derive(Debug, Serialize)]
struct ChatRequest {
    model: String,
    messages: Vec<ChatMessage>,
    temperature: f64,
    max_tokens: u32,
}

#[derive(Debug, Serialize)]
struct ChatMessage {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct ChatResponse {
    choices: Vec<ChatChoice>,
}

#[derive(Debug, Deserialize)]
struct ChatChoice {
    message: ChatChoiceMessage,
}

#[derive(Debug, Deserialize)]
struct ChatChoiceMessage {
    content: String,
}

#[derive(Clone)]
pub struct AiService {
    database: Database,
    orchestrator: AiParseOrchestrator,
}

impl AiService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
            orchestrator: AiParseOrchestrator::default(),
        }
    }

    pub fn with_orchestrator(
        database_path: impl Into<std::path::PathBuf>,
        orchestrator: AiParseOrchestrator,
    ) -> Self {
        Self {
            database: Database::new(database_path),
            orchestrator,
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn create_service_config(
        &self,
        input: &CreateAiServiceConfigInput,
    ) -> Result<AiServiceConfig> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::create_service_config(&mut connection, input)
    }

    pub fn update_service_config(
        &self,
        config_id: &str,
        input: &CreateAiServiceConfigInput,
    ) -> Result<AiServiceConfig> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::update_service_config(&mut connection, config_id, input)
    }

    pub fn delete_service_config(&self, user_id: &str, config_id: &str) -> Result<()> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::delete_service_config(&mut connection, user_id, config_id)
    }

    pub fn list_service_configs(&self, user_id: &str) -> Result<Vec<AiServiceConfig>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        AiRepository::list_service_configs(&connection, user_id)
    }

    pub fn get_active_service_config(&self, user_id: &str) -> Result<Option<AiServiceConfig>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        AiRepository::get_active_service_config(&connection, user_id)
    }

    pub fn parse_input(&self, input: &AiParseInput) -> Result<AiParseResult> {
        self.database.initialize()?;
        input.validate()?;
        let connection = self.database.connect()?;
        let config = AiRepository::get_active_service_config(&connection, &input.user_id)?;
        let context = AiRepository::load_parse_context(&connection, &input.user_id)?;
        let parser_mode = input
            .parser_mode_override
            .clone()
            .or_else(|| config.as_ref().map(|config| config.parser_mode.clone()))
            .unwrap_or(crate::models::ParserMode::Auto);
        Ok(self
            .orchestrator
            .parse(input, &context, config.as_ref(), parser_mode))
    }

    pub fn parse_input_v2(&self, input: &AiParseInput) -> Result<ParsePipelineResult> {
        self.database.initialize()?;
        input.validate()?;
        let connection = self.database.connect()?;
        let config = AiRepository::get_active_service_config(&connection, &input.user_id)?;
        let context = AiRepository::load_parse_context(&connection, &input.user_id)?;
        let parser_mode = input
            .parser_mode_override
            .clone()
            .or_else(|| config.as_ref().map(|config| config.parser_mode.clone()))
            .unwrap_or(crate::models::ParserMode::Auto);
        match parser_mode {
            crate::models::ParserMode::Rule => run_rule_pipeline(input, &context),
            crate::models::ParserMode::Deep => {
                self.run_pipeline_with_llm_fallback(input, &context, config.as_ref(), true)
            }
            crate::models::ParserMode::Auto if should_route_deep(input) => {
                self.run_pipeline_with_llm_fallback(input, &context, config.as_ref(), true)
            }
            crate::models::ParserMode::Auto
            | crate::models::ParserMode::Llm
            | crate::models::ParserMode::Fast
            | crate::models::ParserMode::Vcp => {
                self.run_pipeline_with_llm_fallback(input, &context, config.as_ref(), false)
            }
        }
    }

    fn run_pipeline_with_llm_fallback(
        &self,
        input: &AiParseInput,
        context: &crate::models::ParseContext,
        config: Option<&AiServiceConfig>,
        deep: bool,
    ) -> Result<ParsePipelineResult> {
        if let Some(config) = config {
            let result = if deep {
                run_llm_deep_pipeline(input, context, config)
            } else {
                run_llm_pipeline(input, context, config)
            };
            match result {
                Ok(result) if !result.items.is_empty() => return Ok(result),
                Ok(_) => {
                    let mut fallback = run_rule_pipeline(input, context)?;
                    fallback.warnings.push(format!(
                        "{} returned empty result, fallback to rule parser",
                        if deep { "llm_deep" } else { "llm" }
                    ));
                    return Ok(fallback);
                }
                Err(error) => {
                    let mut fallback = run_rule_pipeline(input, context)?;
                    fallback.warnings.push(format!(
                        "{} failed, fallback to rule parser: {error}",
                        if deep { "llm_deep" } else { "llm" }
                    ));
                    return Ok(fallback);
                }
            }
        }
        let mut fallback = run_rule_pipeline(input, context)?;
        fallback
            .warnings
            .push("no active AI config, fallback to rule parser".to_string());
        Ok(fallback)
    }

    pub fn commit_drafts(&self, input: &AiCommitInput) -> Result<AiCommitResult> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        AiRepository::commit_drafts(&mut connection, input)
    }

    pub fn commit_capture(&self, input: &AiCaptureCommitInput) -> Result<AiCaptureCommitResult> {
        self.database.initialize()?;
        input.validate()?;
        let mut connection = self.database.connect()?;
        let request_id = input.resolved_request_id();
        let context_date = input.resolved_context_date();
        let mut committed = Vec::new();
        let mut failures = Vec::new();
        let mut warnings = Vec::new();
        if !input.drafts.is_empty() {
            let result = AiRepository::commit_drafts(
                &mut connection,
                &AiCommitInput {
                    user_id: input.user_id.clone(),
                    request_id: Some(request_id.clone()),
                    context_date: Some(context_date.clone()),
                    drafts: input.drafts.clone(),
                    options: input.options.clone(),
                },
            )?;
            committed = result.committed;
            failures = result.failures;
            warnings = result.warnings;
        }

        let mut committed_notes = Vec::new();
        let mut note_failures = Vec::new();
        for note in &input.review_notes {
            match note
                .to_create_input(&input.user_id, &context_date)
                .and_then(|input| ReviewNoteRepository::create(&mut connection, &input))
            {
                Ok(note) => committed_notes.push(note),
                Err(error) => note_failures.push(AiCommitFailure {
                    draft_id: note.draft_id.clone(),
                    kind: AiDraftKind::Unknown,
                    message: error.to_string(),
                }),
            }
        }

        Ok(AiCaptureCommitResult {
            request_id,
            committed,
            committed_notes,
            failures,
            note_failures,
            skipped: 0,
            warnings,
        })
    }

    pub fn test_service_config(&self, input: &CreateAiServiceConfigInput) -> Result<Value> {
        input.validate()?;
        let config = AiServiceConfig {
            id: "connection_test".to_string(),
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
            created_at: String::new(),
            updated_at: String::new(),
        };
        let content = send_chat_completion(
            &config,
            "请只回复 OK，用于测试 API 连接。",
            16,
            Duration::from_secs(20),
        )?;
        Ok(json!({
            "ok": true,
            "provider": config.provider,
            "model": config.resolved_model()?,
            "message": content,
        }))
    }

    pub fn chat_review(
        &self,
        user_id: &str,
        question: &str,
        review_context_json: &str,
    ) -> Result<Value> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        let config = AiRepository::get_active_service_config(&connection, user_id)?
            .ok_or_else(|| LifeOsError::InvalidInput("no active AI config".to_string()))?;
        let context = review_context_json.chars().take(10_000).collect::<String>();
        let prompt = format!(
            "你是 SkyeOS 的复盘聊天助手。只能基于给定复盘数据回答，不要写数据录入草稿，不要要求用户确认入库。\n\
             回答要直接、具体、可执行；如果数据不足，说明缺口。\n\n\
             复盘数据 JSON:\n{context}\n\n\
             用户问题:\n{question}"
        );
        let answer = send_chat_completion(&config, &prompt, 900, Duration::from_secs(45))?;
        Ok(json!({
            "answer": answer,
            "model": config.resolved_model()?,
        }))
    }
}

fn send_chat_completion(
    config: &AiServiceConfig,
    prompt: &str,
    max_tokens: u32,
    timeout: Duration,
) -> Result<String> {
    let api_key = config
        .api_key_encrypted
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| LifeOsError::InvalidInput("AI config has no api key".to_string()))?;
    let model = config.resolved_model()?;
    let endpoint = chat_completions_endpoint(config)?;
    let temperature = f64::from(config.temperature_milli.unwrap_or(0)) / 1000.0;
    let request = ChatRequest {
        model,
        temperature,
        max_tokens,
        messages: vec![ChatMessage {
            role: "user".to_string(),
            content: prompt.to_string(),
        }],
    };
    let client = reqwest::blocking::Client::builder()
        .timeout(timeout)
        .build()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm client init failed: {error}")))?;
    let response = client
        .post(&endpoint)
        .bearer_auth(api_key)
        .json(&request)
        .send()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm request failed: {error}")))?;
    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().unwrap_or_default();
        return Err(LifeOsError::InvalidInput(format!(
            "llm request failed with {status}: {}",
            body.chars().take(300).collect::<String>()
        )));
    }
    let response: ChatResponse = response
        .json()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm response json failed: {error}")))?;
    response
        .choices
        .first()
        .map(|choice| choice.message.content.trim().to_string())
        .filter(|content| !content.is_empty())
        .ok_or_else(|| LifeOsError::InvalidInput("llm response is empty".to_string()))
}

fn chat_completions_endpoint(config: &AiServiceConfig) -> Result<String> {
    let base = config
        .resolved_base_url()?
        .ok_or_else(|| LifeOsError::InvalidInput("AI base_url is required".to_string()))?;
    let trimmed = base.trim().trim_end_matches('/');
    if trimmed.ends_with("/chat/completions") {
        Ok(trimmed.to_string())
    } else {
        Ok(format!("{trimmed}/chat/completions"))
    }
}

fn should_route_deep(input: &AiParseInput) -> bool {
    let lines = input
        .raw_text
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>();
    if input.raw_text.chars().count() >= 900 && lines.len() >= 8 {
        return true;
    }
    let standalone_time_lines = lines
        .iter()
        .filter(|line| looks_like_standalone_time_line(line))
        .count();
    if standalone_time_lines >= 2 {
        return true;
    }
    let short_fragment_lines = lines
        .iter()
        .filter(|line| {
            line.chars().count() <= 12 && !line.chars().any(|ch| ch == '元' || ch == '块')
        })
        .count();
    lines.len() >= 8 && short_fragment_lines * 2 >= lines.len()
}

fn looks_like_standalone_time_line(line: &str) -> bool {
    let trimmed = line.trim();
    if trimmed.is_empty() || trimmed.chars().count() > 24 {
        return false;
    }
    let has_digit = trimmed.chars().any(|ch| ch.is_ascii_digit());
    let has_time_marker = [':', '：', '.', '-', '~', '～', '到', '至', '点', '时']
        .iter()
        .any(|marker| trimmed.contains(*marker));
    let has_action = [
        "工作", "开发", "优化", "写", "做", "学习", "看", "答疑", "洗澡", "课程", "作业", "玩",
        "睡", "吃", "买", "出", "下课", "上课", "冥想", "锻炼",
    ]
    .iter()
    .any(|keyword| trimmed.contains(keyword));
    has_digit && has_time_marker && !has_action
}
