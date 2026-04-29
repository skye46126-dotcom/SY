use crate::models::{
    AiParseDraft, DraftFieldSource, DraftLinks, DraftProjectLink, DraftTagLink, ParseContext,
};

pub fn links_from_legacy(legacy: &AiParseDraft, context: &ParseContext) -> DraftLinks {
    let projects = first_payload_value(
        legacy,
        &[
            "project_allocations",
            "project_names",
            "projects",
            "project",
        ],
    )
    .map(|value| parse_multi_values(&value))
    .unwrap_or_default()
    .into_iter()
    .map(|name| {
        let name_exists = context
            .project_names
            .iter()
            .any(|candidate| candidate.eq_ignore_ascii_case(&name));
        DraftProjectLink {
            project_id: None,
            name,
            weight_ratio: 1.0,
            source: DraftFieldSource::Legacy,
            resolution_status: if name_exists {
                "name_matched".to_string()
            } else {
                "unresolved".to_string()
            },
            warnings: if name_exists {
                Vec::new()
            } else {
                vec!["project reference is not resolved to an id".to_string()]
            },
        }
    })
    .collect();

    let tags = first_payload_value(legacy, &["tag_ids", "tag_names", "tags", "tag"])
        .map(|value| parse_multi_values(&value))
        .unwrap_or_default()
        .into_iter()
        .map(|name| {
            let name_exists = context
                .tag_names
                .iter()
                .any(|candidate| candidate.eq_ignore_ascii_case(&name));
            DraftTagLink {
                tag_id: None,
                name,
                scope: Some(legacy.kind.as_str().to_string()),
                source: DraftFieldSource::Legacy,
                resolution_status: if name_exists {
                    "name_matched".to_string()
                } else {
                    "unresolved".to_string()
                },
                warnings: if name_exists {
                    Vec::new()
                } else {
                    vec!["tag reference is not resolved to an id".to_string()]
                },
            }
        })
        .collect();

    DraftLinks {
        projects,
        tags,
        dimensions: Vec::new(),
    }
}

fn first_payload_value(legacy: &AiParseDraft, keys: &[&str]) -> Option<String> {
    keys.iter()
        .find_map(|key| legacy.payload.get(*key))
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn parse_multi_values(raw: &str) -> Vec<String> {
    raw.trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .replace(['"', '\''], "")
        .split([',', '，', '、', ';', '；', '\n', '|'])
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
        .collect()
}
