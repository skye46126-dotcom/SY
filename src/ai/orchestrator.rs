use std::collections::HashSet;
use std::sync::Arc;

use crate::error::Result;
use crate::models::{AiParseInput, AiParseResult, AiServiceConfig, ParseContext, ParserMode};

use super::rule_parser::RuleParserEngine;

pub trait ParserEngine: Send + Sync {
    fn parse(
        &self,
        input: &AiParseInput,
        context: &ParseContext,
        config: Option<&AiServiceConfig>,
    ) -> Result<AiParseResult>;
}

#[derive(Debug)]
pub struct UnsupportedParserEngine {
    parser_name: &'static str,
}

impl UnsupportedParserEngine {
    pub fn new(parser_name: &'static str) -> Self {
        Self { parser_name }
    }
}

impl ParserEngine for UnsupportedParserEngine {
    fn parse(
        &self,
        _input: &AiParseInput,
        _context: &ParseContext,
        _config: Option<&AiServiceConfig>,
    ) -> Result<AiParseResult> {
        Err(crate::error::LifeOsError::InvalidInput(format!(
            "{} parser engine is not configured",
            self.parser_name
        )))
    }
}

#[derive(Clone)]
pub struct AiParseOrchestrator {
    llm_engine: Arc<dyn ParserEngine>,
    vcp_engine: Arc<dyn ParserEngine>,
    rule_engine: Arc<dyn ParserEngine>,
}

impl Default for AiParseOrchestrator {
    fn default() -> Self {
        Self {
            llm_engine: Arc::new(UnsupportedParserEngine::new("llm")),
            vcp_engine: Arc::new(UnsupportedParserEngine::new("vcp")),
            rule_engine: Arc::new(RuleParserEngine),
        }
    }
}

impl AiParseOrchestrator {
    pub fn with_engines(
        llm_engine: Arc<dyn ParserEngine>,
        vcp_engine: Arc<dyn ParserEngine>,
        rule_engine: Arc<dyn ParserEngine>,
    ) -> Self {
        Self {
            llm_engine,
            vcp_engine,
            rule_engine,
        }
    }

    pub fn parse(
        &self,
        input: &AiParseInput,
        context: &ParseContext,
        config: Option<&AiServiceConfig>,
        parser_mode: ParserMode,
    ) -> AiParseResult {
        let result = match parser_mode {
            ParserMode::Rule => self.rule_engine.parse(input, context, config),
            ParserMode::Llm => self.llm_engine.parse(input, context, config),
            ParserMode::Vcp => self.vcp_engine.parse(input, context, config),
            ParserMode::Auto => self.parse_auto(input, context, config),
        };

        result.unwrap_or_else(|error| AiParseResult::empty("orchestrator", Some(error.to_string())))
    }

    fn parse_auto(
        &self,
        input: &AiParseInput,
        context: &ParseContext,
        config: Option<&AiServiceConfig>,
    ) -> Result<AiParseResult> {
        let rule_result = self.rule_engine.parse(input, context, config).ok();
        let mut llm_context = context.clone();
        if let Some(rule_result) = &rule_result {
            for item in &rule_result.items {
                if item.kind != crate::models::AiDraftKind::Unknown {
                    llm_context.add_rule_hint(item.clone());
                }
            }
        }

        match self.llm_engine.parse(input, &llm_context, config) {
            Ok(llm_result) => match rule_result {
                Some(rule_result) if !rule_result.items.is_empty() => {
                    Ok(merge_parse_results(llm_result, rule_result, "auto_merge"))
                }
                _ => Ok(llm_result),
            },
            Err(llm_error) => match rule_result {
                Some(mut fallback) => {
                    fallback
                        .warnings
                        .push(format!("fallback to rule parser: {llm_error}"));
                    Ok(fallback)
                }
                None => self
                    .rule_engine
                    .parse(input, context, config)
                    .map_err(|rule_error| {
                        crate::error::LifeOsError::InvalidInput(format!(
                            "llm failed: {llm_error}; rule failed: {rule_error}"
                        ))
                    }),
            },
        }
    }
}

pub fn merge_parse_results(
    primary: AiParseResult,
    secondary: AiParseResult,
    parser_used: &str,
) -> AiParseResult {
    let mut seen = HashSet::new();
    let mut items = Vec::new();
    for item in primary.items.into_iter().chain(secondary.items) {
        let signature = item.signature();
        if seen.insert(signature) {
            items.push(item);
        }
    }

    let mut warnings = primary.warnings;
    warnings.extend(secondary.warnings);
    warnings.push("auto merge: llm + rule".to_string());

    AiParseResult {
        request_id: primary.request_id,
        items,
        warnings,
        parser_used: parser_used.to_string(),
    }
}
