mod bind;
mod draft;
mod llm;
mod orchestrate;
mod preprocess;
mod prompt;
mod repair;
mod validate;

pub use draft::{reviewable_from_legacy_draft, reviewable_from_legacy_result};
pub use llm::{run_llm_deep_pipeline, run_llm_pipeline};
pub use orchestrate::run_rule_pipeline;
pub use preprocess::{PreprocessedInput, PreprocessedSegment, preprocess_input};
pub use prompt::{
    DEFAULT_EXTRACTION_PROMPT, LlmPromptChunk, build_cleanup_prompt, build_llm_prompt,
    build_llm_prompt_chunks,
};
pub use repair::{LlmRepairResult, extract_json_candidate};

pub(crate) use bind::links_from_legacy;
pub(crate) use validate::validate_reviewable_draft;
