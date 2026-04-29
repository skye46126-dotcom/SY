use std::collections::BTreeMap;

use chrono::Local;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::error::{LifeOsError, Result};
use crate::models::{
    IgnoredContext, ReviewNote, ReviewNoteDraft, normalize_code, normalize_optional_string,
    normalize_required_string, parse_date,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum AiProvider {
    Custom,
    Deepseek,
    Siliconflow,
}

impl AiProvider {
    pub fn from_str(value: &str) -> Result<Self> {
        let normalized = normalize_code("provider", value)?;
        match normalized.as_str() {
            "custom" => Ok(Self::Custom),
            "deepseek" => Ok(Self::Deepseek),
            "siliconflow" => Ok(Self::Siliconflow),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported AI provider: {other}"
            ))),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Custom => "custom",
            Self::Deepseek => "deepseek",
            Self::Siliconflow => "siliconflow",
        }
    }

    pub fn default_base_url(&self) -> Option<&'static str> {
        match self {
            Self::Custom => None,
            Self::Deepseek => Some("https://api.deepseek.com"),
            Self::Siliconflow => Some("https://api.siliconflow.cn/v1"),
        }
    }

    pub fn default_model(&self) -> &'static str {
        match self {
            Self::Custom => "gpt-4o-mini",
            Self::Deepseek => "deepseek-chat",
            Self::Siliconflow => "deepseek-ai/DeepSeek-V3",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ParserMode {
    Auto,
    Rule,
    Llm,
    Fast,
    Deep,
    Vcp,
}

impl ParserMode {
    pub fn from_str(value: &str) -> Result<Self> {
        let normalized = normalize_code("parser_mode", value)?;
        match normalized.as_str() {
            "auto" => Ok(Self::Auto),
            "rule" => Ok(Self::Rule),
            "llm" => Ok(Self::Llm),
            "fast" | "quick" => Ok(Self::Fast),
            "deep" => Ok(Self::Deep),
            "vcp" => Ok(Self::Vcp),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported parser_mode: {other}"
            ))),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::Rule => "rule",
            Self::Llm => "llm",
            Self::Fast => "fast",
            Self::Deep => "deep",
            Self::Vcp => "vcp",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AiDraftKind {
    #[serde(alias = "Time")]
    Time,
    #[serde(alias = "Income")]
    Income,
    #[serde(alias = "Expense")]
    Expense,
    #[serde(alias = "Learning")]
    Learning,
    #[serde(alias = "Unknown")]
    Unknown,
}

impl AiDraftKind {
    pub fn from_str(value: &str) -> Result<Self> {
        let normalized = normalize_code("draft_kind", value)?;
        match normalized.as_str() {
            "time" | "time_log" | "time_record" => Ok(Self::Time),
            "income" | "income_record" => Ok(Self::Income),
            "expense" | "expense_record" => Ok(Self::Expense),
            "learning" | "learning_record" => Ok(Self::Learning),
            "unknown" => Ok(Self::Unknown),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported draft kind: {other}"
            ))),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Time => "time",
            Self::Income => "income",
            Self::Expense => "expense",
            Self::Learning => "learning",
            Self::Unknown => "unknown",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiServiceConfig {
    pub id: String,
    pub user_id: String,
    pub provider: String,
    pub base_url: Option<String>,
    pub api_key_encrypted: Option<String>,
    pub model: Option<String>,
    pub system_prompt: Option<String>,
    pub parser_mode: ParserMode,
    pub temperature_milli: Option<i32>,
    pub is_active: bool,
    pub last_validated_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

impl AiServiceConfig {
    pub fn provider_enum(&self) -> Result<AiProvider> {
        AiProvider::from_str(&self.provider)
    }

    pub fn resolved_base_url(&self) -> Result<Option<String>> {
        Ok(match normalize_optional_string(&self.base_url) {
            Some(value) => Some(value),
            None => self
                .provider_enum()?
                .default_base_url()
                .map(ToString::to_string),
        })
    }

    pub fn resolved_model(&self) -> Result<String> {
        Ok(match normalize_optional_string(&self.model) {
            Some(value) => value,
            None => self.provider_enum()?.default_model().to_string(),
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateAiServiceConfigInput {
    pub user_id: String,
    pub provider: String,
    pub base_url: Option<String>,
    pub api_key_encrypted: Option<String>,
    pub model: Option<String>,
    pub system_prompt: Option<String>,
    pub parser_mode: Option<ParserMode>,
    pub temperature_milli: Option<i32>,
    pub is_active: bool,
}

impl CreateAiServiceConfigInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        let _ = AiProvider::from_str(&self.provider)?;
        if let Some(temperature_milli) = self.temperature_milli
            && !(-5000..=5000).contains(&temperature_milli)
        {
            return Err(LifeOsError::InvalidInput(
                "temperature_milli must be between -5000 and 5000".to_string(),
            ));
        }
        Ok(())
    }

    pub fn normalized_provider(&self) -> Result<String> {
        Ok(AiProvider::from_str(&self.provider)?.as_str().to_string())
    }

    pub fn normalized_base_url(&self) -> Option<String> {
        normalize_optional_string(&self.base_url)
    }

    pub fn normalized_api_key_encrypted(&self) -> Option<String> {
        normalize_optional_string(&self.api_key_encrypted)
    }

    pub fn normalized_model(&self) -> Option<String> {
        normalize_optional_string(&self.model)
    }

    pub fn normalized_system_prompt(&self) -> Option<String> {
        normalize_optional_string(&self.system_prompt)
    }

    pub fn resolved_parser_mode(&self) -> ParserMode {
        self.parser_mode.clone().unwrap_or(ParserMode::Auto)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiParseInput {
    pub user_id: String,
    pub raw_text: String,
    pub context_date: Option<String>,
    pub parser_mode_override: Option<ParserMode>,
}

impl AiParseInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("raw_text", &self.raw_text)?;
        if let Some(context_date) = &self.context_date {
            parse_date("context_date", context_date)?;
        }
        Ok(())
    }

    pub fn resolved_context_date(&self) -> String {
        self.context_date
            .as_deref()
            .and_then(|value| {
                parse_date("context_date", value)
                    .ok()
                    .map(|_| value.trim().to_string())
            })
            .unwrap_or_else(|| Local::now().date_naive().to_string())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ParseContext {
    pub category_codes: Vec<String>,
    pub project_names: Vec<String>,
    pub tag_names: Vec<String>,
    pub rule_hints: Vec<AiParseDraft>,
}

impl ParseContext {
    pub fn add_rule_hint(&mut self, draft: AiParseDraft) {
        self.rule_hints.push(draft);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DraftIntent {
    Record,
    Config,
    Management,
    Reference,
    Unknown,
}

impl DraftIntent {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Record => "record",
            Self::Config => "config",
            Self::Management => "management",
            Self::Reference => "reference",
            Self::Unknown => "unknown",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TypedDraftKind {
    TimeRecord,
    IncomeRecord,
    ExpenseRecord,
    LearningRecord,
    MonthlyCostBaseline,
    RecurringExpenseRule,
    CapexCost,
    OperatingSettings,
    Project,
    Tag,
    DimensionOption,
    TimeMarker,
    ReferenceNote,
    Unknown,
}

impl TypedDraftKind {
    pub fn intent(&self) -> DraftIntent {
        match self {
            Self::TimeRecord | Self::IncomeRecord | Self::ExpenseRecord | Self::LearningRecord => {
                DraftIntent::Record
            }
            Self::MonthlyCostBaseline
            | Self::RecurringExpenseRule
            | Self::CapexCost
            | Self::OperatingSettings => DraftIntent::Config,
            Self::Project | Self::Tag | Self::DimensionOption => DraftIntent::Management,
            Self::TimeMarker | Self::ReferenceNote => DraftIntent::Reference,
            Self::Unknown => DraftIntent::Unknown,
        }
    }

    pub fn legacy_kind(&self) -> AiDraftKind {
        match self {
            Self::TimeRecord => AiDraftKind::Time,
            Self::IncomeRecord => AiDraftKind::Income,
            Self::ExpenseRecord => AiDraftKind::Expense,
            Self::LearningRecord => AiDraftKind::Learning,
            _ => AiDraftKind::Unknown,
        }
    }

    pub fn from_legacy(kind: &AiDraftKind) -> Self {
        match kind {
            AiDraftKind::Time => Self::TimeRecord,
            AiDraftKind::Income => Self::IncomeRecord,
            AiDraftKind::Expense => Self::ExpenseRecord,
            AiDraftKind::Learning => Self::LearningRecord,
            AiDraftKind::Unknown => Self::Unknown,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::TimeRecord => "time_record",
            Self::IncomeRecord => "income_record",
            Self::ExpenseRecord => "expense_record",
            Self::LearningRecord => "learning_record",
            Self::MonthlyCostBaseline => "monthly_cost_baseline",
            Self::RecurringExpenseRule => "recurring_expense_rule",
            Self::CapexCost => "capex_cost",
            Self::OperatingSettings => "operating_settings",
            Self::Project => "project",
            Self::Tag => "tag",
            Self::DimensionOption => "dimension_option",
            Self::TimeMarker => "time_marker",
            Self::ReferenceNote => "reference_note",
            Self::Unknown => "unknown",
        }
    }

    pub fn reference_only(&self) -> bool {
        matches!(self, Self::TimeMarker | Self::ReferenceNote)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DraftStatus {
    CommitReady,
    NeedsReview,
    Blocked,
    ReferenceOnly,
}

impl DraftStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::CommitReady => "commit_ready",
            Self::NeedsReview => "needs_review",
            Self::Blocked => "blocked",
            Self::ReferenceOnly => "reference_only",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DraftFieldSource {
    Ai,
    Rule,
    Default,
    User,
    Legacy,
}

impl DraftFieldSource {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Ai => "ai",
            Self::Rule => "rule",
            Self::Default => "default",
            Self::User => "user",
            Self::Legacy => "legacy",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DraftField {
    pub value: Option<Value>,
    pub raw: Option<String>,
    pub source: DraftFieldSource,
    pub required: bool,
    pub editable: bool,
    pub confidence: Option<f64>,
    pub warnings: Vec<String>,
}

impl DraftField {
    pub fn new(value: Option<Value>, source: DraftFieldSource) -> Self {
        Self {
            value,
            raw: None,
            source,
            required: false,
            editable: true,
            confidence: None,
            warnings: Vec::new(),
        }
    }

    pub fn from_string(value: impl Into<String>, source: DraftFieldSource) -> Self {
        let value = value.into();
        Self {
            raw: Some(value.clone()),
            value: Some(Value::String(value)),
            source,
            required: false,
            editable: true,
            confidence: None,
            warnings: Vec::new(),
        }
    }

    pub fn required(mut self) -> Self {
        self.required = true;
        self
    }

    pub fn with_confidence(mut self, confidence: f64) -> Self {
        self.confidence = Some(confidence.clamp(0.0, 1.0));
        self
    }

    pub fn with_warning(mut self, warning: impl Into<String>) -> Self {
        let warning = warning.into();
        if !warning.trim().is_empty() {
            self.warnings.push(warning);
        }
        self
    }

    pub fn is_missing_required(&self) -> bool {
        if !self.required {
            return false;
        }
        match &self.value {
            None | Some(Value::Null) => true,
            Some(Value::String(value)) => value.trim().is_empty(),
            _ => false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DraftProjectLink {
    pub project_id: Option<String>,
    pub name: String,
    pub weight_ratio: f64,
    pub source: DraftFieldSource,
    pub resolution_status: String,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DraftTagLink {
    pub tag_id: Option<String>,
    pub name: String,
    pub scope: Option<String>,
    pub source: DraftFieldSource,
    pub resolution_status: String,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DraftDimensionBinding {
    pub kind: String,
    pub code: Option<String>,
    pub label: Option<String>,
    pub source: DraftFieldSource,
    pub resolution_status: String,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct DraftLinks {
    pub projects: Vec<DraftProjectLink>,
    pub tags: Vec<DraftTagLink>,
    pub dimensions: Vec<DraftDimensionBinding>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DraftValidation {
    pub status: DraftStatus,
    pub missing_required: Vec<String>,
    pub blocking_errors: Vec<String>,
    pub warnings: Vec<String>,
}

impl DraftValidation {
    pub fn ready(warnings: Vec<String>) -> Self {
        Self {
            status: if warnings.is_empty() {
                DraftStatus::CommitReady
            } else {
                DraftStatus::NeedsReview
            },
            missing_required: Vec::new(),
            blocking_errors: Vec::new(),
            warnings,
        }
    }

    pub fn from_issues(
        missing_required: Vec<String>,
        blocking_errors: Vec<String>,
        warnings: Vec<String>,
    ) -> Self {
        let status = if !blocking_errors.is_empty() {
            DraftStatus::Blocked
        } else if !missing_required.is_empty() || !warnings.is_empty() {
            DraftStatus::NeedsReview
        } else {
            DraftStatus::CommitReady
        };
        Self {
            status,
            missing_required,
            blocking_errors,
            warnings,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReviewableDraft {
    pub draft_id: String,
    pub intent: DraftIntent,
    pub kind: TypedDraftKind,
    pub raw_text: String,
    pub title: String,
    pub note: Option<String>,
    pub unmapped_text: Option<String>,
    pub fields: BTreeMap<String, DraftField>,
    pub links: DraftLinks,
    pub validation: DraftValidation,
    pub confidence: f64,
    pub source: String,
}

impl ReviewableDraft {
    pub fn new(kind: TypedDraftKind, source: impl Into<String>) -> Self {
        Self {
            draft_id: Uuid::now_v7().to_string(),
            intent: kind.intent(),
            kind,
            raw_text: String::new(),
            title: String::new(),
            note: None,
            unmapped_text: None,
            fields: BTreeMap::new(),
            links: DraftLinks::default(),
            validation: DraftValidation::ready(Vec::new()),
            confidence: 0.0,
            source: source.into(),
        }
    }

    pub fn commit_ready(&self) -> bool {
        self.validation.status == DraftStatus::CommitReady
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ParsePipelineResult {
    pub request_id: String,
    pub parser_used: String,
    pub items: Vec<ReviewableDraft>,
    pub review_notes: Vec<ReviewNoteDraft>,
    pub ignored_context: Vec<IgnoredContext>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CommitReviewableDraftInput {
    #[serde(flatten)]
    pub draft: ReviewableDraft,
    #[serde(default)]
    pub user_confirmed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CommitCaptureDraftEnvelopeInput {
    pub user_id: String,
    pub inbox_id: Option<String>,
    pub request_id: Option<String>,
    pub context_date: Option<String>,
    pub items: Vec<CommitReviewableDraftInput>,
    pub review_notes: Vec<ReviewNoteDraft>,
    pub options: AiCommitOptions,
}

impl CommitCaptureDraftEnvelopeInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        if let Some(context_date) = &self.context_date {
            parse_date("context_date", context_date)?;
        }
        let _ = self.options.normalized_source()?;
        for note in &self.review_notes {
            note.validate()?;
        }
        if self.items.is_empty() && self.review_notes.is_empty() {
            return Err(LifeOsError::InvalidInput(
                "items or review_notes must not be empty".to_string(),
            ));
        }
        Ok(())
    }

    pub fn resolved_request_id(&self) -> String {
        self.request_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
            .unwrap_or_else(|| Uuid::now_v7().to_string())
    }

    pub fn resolved_context_date(&self) -> String {
        self.context_date
            .as_deref()
            .and_then(|value| {
                parse_date("context_date", value)
                    .ok()
                    .map(|_| value.trim().to_string())
            })
            .unwrap_or_else(|| Local::now().date_naive().to_string())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiParseDraft {
    pub draft_id: String,
    pub kind: AiDraftKind,
    pub payload: BTreeMap<String, String>,
    pub confidence: f64,
    pub source: String,
    pub warning: Option<String>,
}

impl AiParseDraft {
    pub fn new(
        kind: AiDraftKind,
        payload: BTreeMap<String, String>,
        confidence: f64,
        source: impl Into<String>,
        warning: Option<String>,
    ) -> Self {
        Self {
            draft_id: Uuid::now_v7().to_string(),
            kind,
            payload,
            confidence: confidence.clamp(0.0, 1.0),
            source: source.into(),
            warning: normalize_optional_string(&warning),
        }
    }

    pub fn signature(&self) -> String {
        let mut signature = self.kind.as_str().to_string();
        signature.push('|');
        for (key, value) in &self.payload {
            signature.push_str(key);
            signature.push('=');
            signature.push_str(value);
            signature.push(';');
        }
        signature
    }

    pub fn payload_value(&self, key: &str) -> Option<&str> {
        self.payload
            .get(key)
            .map(String::as_str)
            .filter(|value| !value.trim().is_empty())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiParseResult {
    pub request_id: String,
    pub items: Vec<AiParseDraft>,
    pub warnings: Vec<String>,
    pub parser_used: String,
}

impl AiParseResult {
    pub fn empty(parser_used: impl Into<String>, warning: Option<String>) -> Self {
        let warnings = warning
            .and_then(|value| normalize_optional_string(&Some(value)))
            .into_iter()
            .collect();
        Self {
            request_id: Uuid::now_v7().to_string(),
            items: Vec::new(),
            warnings,
            parser_used: parser_used.into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCommitOptions {
    pub source: Option<String>,
    pub auto_create_tags: bool,
    pub strict_reference_resolution: bool,
}

impl Default for AiCommitOptions {
    fn default() -> Self {
        Self {
            source: Some("external".to_string()),
            auto_create_tags: false,
            strict_reference_resolution: false,
        }
    }
}

impl AiCommitOptions {
    pub fn normalized_source(&self) -> Result<String> {
        let source = self
            .source
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .unwrap_or("external")
            .to_lowercase();
        if matches!(source.as_str(), "manual" | "external" | "import" | "system") {
            Ok(source)
        } else {
            Err(LifeOsError::InvalidInput(format!(
                "unsupported AI commit source: {source}"
            )))
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCommitInput {
    pub user_id: String,
    pub request_id: Option<String>,
    pub context_date: Option<String>,
    pub drafts: Vec<AiParseDraft>,
    pub options: AiCommitOptions,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCaptureCommitInput {
    pub user_id: String,
    pub request_id: Option<String>,
    pub context_date: Option<String>,
    pub drafts: Vec<AiParseDraft>,
    pub review_notes: Vec<ReviewNoteDraft>,
    pub options: AiCommitOptions,
}

impl AiCaptureCommitInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        if let Some(context_date) = &self.context_date {
            parse_date("context_date", context_date)?;
        }
        let _ = self.options.normalized_source()?;
        for note in &self.review_notes {
            note.validate()?;
        }
        if self.drafts.is_empty() && self.review_notes.is_empty() {
            return Err(LifeOsError::InvalidInput(
                "drafts or review_notes must not be empty".to_string(),
            ));
        }
        Ok(())
    }

    pub fn resolved_request_id(&self) -> String {
        self.request_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
            .unwrap_or_else(|| Uuid::now_v7().to_string())
    }

    pub fn resolved_context_date(&self) -> String {
        self.context_date
            .as_deref()
            .and_then(|value| {
                parse_date("context_date", value)
                    .ok()
                    .map(|_| value.trim().to_string())
            })
            .unwrap_or_else(|| Local::now().date_naive().to_string())
    }
}

impl AiCommitInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        if let Some(context_date) = &self.context_date {
            parse_date("context_date", context_date)?;
        }
        if self.drafts.is_empty() {
            return Err(LifeOsError::InvalidInput(
                "drafts must not be empty".to_string(),
            ));
        }
        let _ = self.options.normalized_source()?;
        Ok(())
    }

    pub fn resolved_request_id(&self) -> String {
        self.request_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
            .unwrap_or_else(|| Uuid::now_v7().to_string())
    }

    pub fn resolved_context_date(&self) -> String {
        self.context_date
            .as_deref()
            .and_then(|value| {
                parse_date("context_date", value)
                    .ok()
                    .map(|_| value.trim().to_string())
            })
            .unwrap_or_else(|| Local::now().date_naive().to_string())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCommittedRecord {
    pub draft_id: String,
    pub kind: AiDraftKind,
    pub record_id: String,
    pub occurred_at: String,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCommitFailure {
    pub draft_id: String,
    pub kind: AiDraftKind,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCommitResult {
    pub request_id: String,
    pub committed: Vec<AiCommittedRecord>,
    pub failures: Vec<AiCommitFailure>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiCaptureCommitResult {
    pub request_id: String,
    pub committed: Vec<AiCommittedRecord>,
    pub committed_notes: Vec<ReviewNote>,
    pub failures: Vec<AiCommitFailure>,
    pub note_failures: Vec<AiCommitFailure>,
    pub skipped: usize,
    pub warnings: Vec<String>,
}
