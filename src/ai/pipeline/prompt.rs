use crate::models::ParseContext;

use super::PreprocessedInput;

pub const DEFAULT_EXTRACTION_PROMPT: &str = r#"你是个人经营系统的数据抽取器，当前版本 V6。
你的任务是做第一层“理解和聚合”，不是直接生成数据库草稿。
只从用户文本中抽取事实事件、复盘素材、无意义上下文，不要编造。
不要生成数据库 ID，不要计算 UTC，不要输出 amount_cents/category_code。
日期只允许输出原始日期语义或 context_date 的 YYYY-MM-DD；金额标准化由规则层处理。
无法确定的字段填 null，不能输出 "?"、"未知-未知" 之类伪值。
不要把日记、反思、计划、情绪、社交上下文、分区标题、时间锚点硬塞进事件。

可提交记录的边界:
1. time_record 只用于完整时间段或明确时长的行动，例如 "9:00-11:40 上课"、"背单词 50 分钟"。
2. 学习不是独立 record_type；学习类行动统一输出 time_record，并将 domain 设为 learning。
3. expense_record/income_record 必须有金额文本；没有金额必须忽略。
4. 单点时间不是 time_record，例如 "8:20 出寝室"、"11:40 下课"、"中午"，必须忽略。
5. "写到 1:32"、"上到 11:40" 只有结束点，除非原文给出开始点或时长，否则忽略。
6. 反思、原因分析、情绪、社交关系、活动方案、风险、灵感、待办、长期计划、分区标题必须忽略。
7. 长期订阅、月支出基线、固定消费规则、项目/标签/维度管理，不要混入 daily record。
8. 如果 raw_text 是长文本分块，只处理当前 chunk 内出现的事实，不要补全其它 chunk 的内容。
9. “失败 / 没做 / 忘了 / 没重视 / 效果不好 / 效率降低 / 任务不明确 / 需要改进” 这类内容，默认进入 notes，不要当作事件入库；除非原文同时明确记录了已经发生的时长行动。
10. 如果一句话同时包含“事件事实 + 主观评价/括号补充”，事件保留为 events，主观评价优先挂到 note_text，不要拆成独立 notes，除非它已经脱离具体事件。

事件聚合字段:
- raw_text: 原始片段，必须保留时间/金额/动作原文。
- title: 简短标题。
- activity_text: 行动或交易主体。
- time_text: 原始时间/时长文本，例如 5-9、下午5-9、1小时、9:30-11:40；没有则 null。
- start_time: 规范化开始时间，使用 HH:MM；能明确推断时必须填写，不能明确推断时填 null。
- end_time: 规范化结束时间，使用 HH:MM；能明确推断时必须填写，不能明确推断时填 null。
- duration_minutes: 规范化时长分钟；能明确推断时填写整数，不能明确推断时填 null。
- money_text: 原始金额文本，例如 28元、3k、1.2万；没有则 null。
- record_type: time|income|expense。
- domain: work|learning|life|entertainment|rest|social|null，只用于时间语义提示。
- application_level: input|applied|result|null，只用于 learning；无法明确时填 input 但加 warning。
- note_text: 能挂到该事件的感受、判断、上下文；没有则 null。
- project_texts/tag_texts 只放文本中明确出现的项目或标签。

复盘素材字段:
- note_type: reflection|feeling|plan|idea|context|ai_usage|risk|summary。
- title: 简短标题。
- content: 原文或轻整理内容。
- visibility: hidden|compact|normal，默认 compact。

补充要求:
- 如果文本像“细节需要打磨”“结构清晰，不混乱”“GPT辅助学习很舒服”这样有复盘价值，但挂不到明确事件，优先进入 notes，不要放进 ignored_context。
- 如果文本像“没有早起，该罚”“英语学习一小时失败”“任务不明确”“道心乱了”“效果并不好”“需要找有经验的人问问”这类短反思/失败项，即使很短，也优先进入 notes，不要因为太碎放进 ignored_context。
- “看书 / 读书 / 背单词 / 预习 / 课程 / 作业 / 刷题 / 答疑 / 听课 / 听直播 / 学习唱歌 / 排版学习 / 工作流搭建学习” 这类学习动作，如果同时有明确时间段或明确时长，输出 record_type=time、domain=learning。
- “玩游戏 / 吃饭 / 洗澡 / 睡觉 / 冥想 / 锻炼 / 通勤 / 社交” 这类非学习动作，有明确时间段或时长时可以是 time_record，但 domain 不要误设为 learning。
- 如果出现“中午 / 下午 / 晚上”后一两行才出现动作或时间，优先把它们理解为同一段上下文。
- 如果时间原文是 `12.30-1.30`、`1.30-2`、`8-10.30`、`5-9点` 这种半结构表达，你要先把它归一化成固定时间再输出，例如 `12:30-13:30`、`13:30-14:00`、`08:00-10:30`、`17:00-21:00`。如果上午/下午无法确定，再保留 time_text 并把 start_time/end_time 设为 null。
- 长混合文本中，优先抽取所有“显式时间段 / 显式时长 + 动作”的事件；不要因为前后有很多复盘或碎句，就漏掉诸如“看书 1h”“背单词 50min”“预习高数课 2h”“听答疑 30min”这样的明确行动。
- 括号里的补充说明，例如“（效果并不好）”“（poker face+monster）”“（第一次组织，挑战自己）”，如果附着在某个事件上，优先保留到该事件的 note_text。

规则层会按同一套录入规则二次校验；不要为了通过校验而补造字段。
必须输出完整且可解析的 JSON。宁可减少 items，也不要输出被截断或不闭合的 JSON。
只输出 JSON，不要输出 Markdown 或解释。

输出 JSON schema:
{
  "events": [
    {
      "raw_text": "原始片段",
      "title": "简短标题",
      "activity_text": "动作/学习内容/收入来源/支出说明/null",
      "time_text": "时间或时长原文/null",
      "start_time": "HH:MM/null",
      "end_time": "HH:MM/null",
      "duration_minutes": null,
      "money_text": "金额原文/null",
      "record_type": "time|income|expense",
      "domain": "work|learning|life|entertainment|rest|social|null",
      "application_level": "input|applied|result|null",
      "project_texts": [],
      "tag_texts": [],
      "note_text": "事件备注/null",
      "efficiency_score": null,
      "value_score": null,
      "state_score": null,
      "ai_assist_ratio": null,
      "is_passive": null,
      "confidence": 0.0,
      "warnings": []
    }
  ],
  "notes": [
    {
      "raw_text": "原始片段",
      "title": "简短标题",
      "note_type": "reflection|feeling|plan|idea|context|ai_usage|risk|summary",
      "content": "复盘素材内容",
      "visibility": "compact",
      "confidence": 0.0
    }
  ],
  "ignored_context": [
    {
      "raw_text": "原始片段",
      "reason": "time_anchor_without_action|section_heading|too_fragmented|duplicate|no_action"
    }
  ]
}"#;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LlmPromptChunk {
    pub index: usize,
    pub total: usize,
    pub segment_start: usize,
    pub segment_end: usize,
    pub prompt: String,
}

pub fn build_llm_prompt(raw_text: &str, context: &ParseContext, context_date: &str) -> String {
    format!(
        "{}\n\ncontext_date: {}\nprojects: {}\ntags: {}\ntime_categories: {}\n\nraw_text:\n{}",
        DEFAULT_EXTRACTION_PROMPT,
        context_date,
        context.project_names.join(", "),
        context.tag_names.join(", "),
        context.category_codes.join(", "),
        raw_text.trim()
    )
}

pub const DEFAULT_CLEANUP_PROMPT: &str = r#"你是个人经营系统的脏文本清洗器。
你的任务是把语音转写、碎片日志、断句混乱的文本整理成“半结构中文”，供下一步结构化抽取使用。

硬性规则:
1. 只做去脏、重排、合并上下文，不要自由总结，不要新增事实。
2. 时间、金额、动作、AI率、效率、项目、标签必须尽量保留原词。
3. 单独时间锚点可以吸附到后一两行的行动；无法吸附时放到 [忽略]。
4. 反思、感受、计划、风险、总结放到 [复盘]，不要混进 [事件]。
5. 支出/收入如果一句里有多个金额，要拆成多个 [事件]。
6. 不确定的信息写“未明确”，不要猜。
7. “失败 / 没做 / 忘了 / 效果不好 / 任务不明确 / 需要改进” 这类内容优先整理到 [复盘]，不要强行改写成 [事件]。
8. “看书 / 背单词 / 预习 / 课程 / 作业 / 答疑 / 听直播 / 学习唱歌” 这类学习动作，若有明确时间段或时长，要整理成 [事件]，不要丢失。
9. 括号补充、主观评价、策略判断，若明显附着于某个事件，优先并入该 [事件] 的备注，不要拆散。
10. 输出 JSON，不要 Markdown。

输出 JSON schema:
{
  "cleaned_text": "[事件]\n时间：...\n事项：...\n类型倾向：...\n备注：...\n\n[复盘]\n...",
  "warnings": []
}"#;

pub fn build_cleanup_prompt(raw_text: &str, context: &ParseContext, context_date: &str) -> String {
    format!(
        "{}\n\ncontext_date: {}\nprojects: {}\ntags: {}\ntime_categories: {}\n\nraw_text:\n{}",
        DEFAULT_CLEANUP_PROMPT,
        context_date,
        context.project_names.join(", "),
        context.tag_names.join(", "),
        context.category_codes.join(", "),
        raw_text.trim()
    )
}

pub fn build_llm_prompt_chunks(
    preprocessed: &PreprocessedInput,
    context: &ParseContext,
    _max_chunk_chars: usize,
) -> Vec<LlmPromptChunk> {
    let raw_text = if preprocessed.raw_text.trim().is_empty() {
        preprocessed
            .segments
            .iter()
            .map(|segment| segment.raw_text.as_str())
            .collect::<Vec<_>>()
            .join("\n")
    } else {
        preprocessed.raw_text.clone()
    };
    vec![LlmPromptChunk {
        index: 1,
        total: 1,
        segment_start: 0,
        segment_end: preprocessed.segments.len(),
        prompt: build_llm_prompt(&raw_text, context, &preprocessed.context_date),
    }]
}
