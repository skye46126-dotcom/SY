#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LlmRepairResult {
    pub json_text: String,
    pub repaired: bool,
    pub warning: Option<String>,
}

pub fn extract_json_candidate(raw: &str) -> Option<LlmRepairResult> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    if looks_like_json(trimmed) {
        return Some(LlmRepairResult {
            json_text: trimmed.to_string(),
            repaired: false,
            warning: None,
        });
    }
    if let Some(json_text) = extract_fenced_json(trimmed) {
        return Some(LlmRepairResult {
            json_text,
            repaired: true,
            warning: Some("llm_json_extracted_from_code_block".to_string()),
        });
    }
    extract_balanced_json(trimmed).map(|json_text| LlmRepairResult {
        json_text,
        repaired: true,
        warning: Some("llm_json_extracted_from_text".to_string()),
    })
}

fn looks_like_json(value: &str) -> bool {
    (value.starts_with('{') && value.ends_with('}'))
        || (value.starts_with('[') && value.ends_with(']'))
}

fn extract_fenced_json(value: &str) -> Option<String> {
    let fence_start = value.find("```")?;
    let after_start = &value[fence_start + 3..];
    let content_start = after_start
        .strip_prefix("json")
        .or_else(|| after_start.strip_prefix("JSON"))
        .unwrap_or(after_start)
        .trim_start_matches(['\n', '\r', ' ']);
    let fence_end = content_start.find("```")?;
    let candidate = content_start[..fence_end].trim();
    looks_like_json(candidate).then(|| candidate.to_string())
}

fn extract_balanced_json(value: &str) -> Option<String> {
    let start = value
        .char_indices()
        .find_map(|(index, ch)| matches!(ch, '{' | '[').then_some((index, ch)))?;
    let close = if start.1 == '{' { '}' } else { ']' };
    let mut depth = 0_i32;
    let mut in_string = false;
    let mut escaped = false;
    for (offset, ch) in value[start.0..].char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        if ch == '\\' && in_string {
            escaped = true;
            continue;
        }
        if ch == '"' {
            in_string = !in_string;
            continue;
        }
        if in_string {
            continue;
        }
        if ch == start.1 {
            depth += 1;
        } else if ch == close {
            depth -= 1;
            if depth == 0 {
                let end = start.0 + offset + ch.len_utf8();
                return Some(value[start.0..end].trim().to_string());
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::extract_json_candidate;

    #[test]
    fn extracts_strict_json_without_warning() {
        let result = extract_json_candidate(r#"{"items":[]}"#).expect("candidate");
        assert_eq!(result.json_text, r#"{"items":[]}"#);
        assert!(!result.repaired);
        assert!(result.warning.is_none());
    }

    #[test]
    fn extracts_json_from_markdown_fence() {
        let result = extract_json_candidate("```json\n{\"items\":[]}\n```").expect("candidate");
        assert_eq!(result.json_text, r#"{"items":[]}"#);
        assert!(result.repaired);
    }

    #[test]
    fn extracts_first_balanced_json_from_text() {
        let result =
            extract_json_candidate("结果如下：{\"items\":[1]}，请确认").expect("candidate");
        assert_eq!(result.json_text, r#"{"items":[1]}"#);
        assert!(result.repaired);
    }
}
