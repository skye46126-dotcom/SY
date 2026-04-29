# AI 解析与录入管线重构规划

## 目标

把自然语言录入、手动录入、长期规则配置和管理类变更统一纳入 Rust 数据管线。前端只负责 UI、交互、用户审核和提交动作；Rust 负责解析、规则兜底、字段补全、绑定解析、必填检查、最终入库。

本规划保留现有 `parse_ai_input` / `commit_ai_drafts` 兼容接口，新增 typed draft 和 v2 pipeline 能力后，再逐步切换前端。

## 总体原则

- AI 只做语义抽取，不做确定性计算。
- Rust 做所有确定性处理：时间、金额、时长、默认值、项目/标签/类别绑定、必填检查、入库校验。
- note 是一等字段，所有未结构化但有业务意义的信息都必须可追踪。
- 高频事实记录和长期配置/管理变更分开建模、分开审核、分开提交。
- LLM 输出不可信，必须有 JSON 修复和规则解析兜底。
- 前端不拼数据库 payload，只渲染 Rust 返回的 typed draft，并把用户修改后的 draft 交回 Rust。

## 解析状态图

```text
原始输入 raw_text
  ↓
1 输入预处理层
  - trim / normalize
  - 按换行、标点、连接词切段
  - 解析 context_date
  - 加载项目、标签、维度、默认值、成本规则
  ↓
2 意图分类层
  - 高频事实记录
  - 长期成本/规则配置
  - 项目/标签/维度管理
  - unknown
  ↓
3 AI 解析层
  - 构造系统提示词和上下文
  - 调 LLM/VCP/规则引擎
  - 只抽取语义字段，不生成 ID，不算 UTC
  ↓
4 LLM 输出修复层
  - strict JSON parse
  - code block JSON extract
  - first object/array extract
  - repair 失败时回到 raw_text 走 rule parser
  ↓
5 标准草稿层
  - 转成 typed draft
  - 保留 raw_text、note、unmapped_text、field source
  ↓
6 规则补全层
  - 日期、时间、时长、金额、单位、默认类别
  - 生成 warnings，不静默脑补
  ↓
7 绑定解析层
  - 项目名/ID -> project_id
  - 标签名/ID -> tag_id
  - 类别/维度名 -> code
  - 记录 unresolved refs
  ↓
8 必填检查层
  - commit_ready
  - needs_review
  - blocked
  ↓
9 用户审核回流层
  - 前端展示字段、来源、警告、缺失项
  - 用户修改字段/选择绑定/补 note
  ↓
10 Commit 入库层
  - Rust 再次校验
  - 按 draft kind 写不同表
  - 返回 committed/failures/warnings
```

## 层级职责

| 层级 | 名称 | 核心职责 | Rust 输出 |
| --- | --- | --- | --- |
| 1 | 输入预处理层 | 整理原始输入和上下文，加载用户可选项 | `PreprocessedInput` |
| 2 | 意图分类层 | 判断是事实记录、长期规则、管理变更还是 unknown | `CaptureIntent` |
| 3 | AI 解析层 | 理解文本，抽取语义字段 | `AiExtraction` |
| 4 | LLM 修复/规则兜底层 | 处理不正规 JSON，必要时回到规则解析 | `ExtractionResult` |
| 5 | 标准草稿层 | 转成系统内部 typed draft | `ReviewableDraft` |
| 6 | 规则补全层 | 做确定性转换和补全 | `DraftField.source = rule/default` |
| 7 | 绑定解析层 | 项目、标签、类别、维度绑定 | `DraftLinks` |
| 8 | 必填检查层 | 判断缺什么、能不能提交 | `DraftValidation` |
| 9 | 用户审核回流层 | 返回 UI 可编辑状态，让用户确认/修改/补齐 | `ParsePipelineResult` |
| 10 | Commit 入库层 | 最终校验并写入数据库 | `AiCommitResult` / v2 commit result |

## Draft 分类

### 高频事实记录

这些用于快速录入、当天补记和复盘补录。

- `time_record`：每天做了什么、花了多少时间、效率、价值、状态、AI 占比。
- `income_record`：收入、回款、工资、分成、被动收入。
- `expense_record`：一次性支出、当天消费、项目支出。
- `learning_record`：学习内容、时长、学习等级、效率、AI 占比。

### 长期配置和低频规则

这些不应该和每日事实记录混在同一表单中。

- `monthly_cost_baseline`：月基础生活成本、月固定订阅成本。
- `recurring_expense_rule`：长期订阅、固定月支出、必要/非必要周期成本。
- `capex_cost`：一次性大额支出、设备、长期资产、摊销。
- `operating_settings`：理想时薪、每日工作目标、每日学习目标、时区、币种。

### 管理类变更

- `project`：创建项目、改状态、补评分、改 AI 启用比例。
- `tag`：新增标签、标签 scope、层级、状态。
- `dimension_option`：新增或修改时间类别、收入类型、支出类别、学习等级、项目状态。

## note 规则

所有 draft 都必须带：

- `raw_text`：原始片段。
- `title`：给用户看的摘要。
- `note`：最终入库备注。
- `unmapped_text`：没有被结构化字段消费掉的文本。

推荐合成规则：

```text
note = 明确备注 + 未消费文本 + 低置信度补充信息
```

示例：

```text
输入：下午做 SkyeOS 规则重构 2 小时，效率 8，主要卡在 note 设计

结构化：
kind = time_record
project = SkyeOS
duration = 120
efficiency_score = 8
note = 规则重构；主要卡在 note 设计
```

## LLM 提示词策略

### 系统提示词

```text
你是个人经营系统的数据抽取器。
只从用户文本中抽取事实，不要编造。
不要计算 UTC，不要生成数据库 ID。
金额保持原始单位，时间保持用户表达。
无法确定的字段填 null。
只输出 JSON，不要输出 Markdown 或解释。
```

### 输出 schema

```json
{
  "items": [
    {
      "intent": "record | config | management | unknown",
      "kind": "time_record | income_record | expense_record | learning_record | recurring_expense_rule | monthly_cost_baseline | capex_cost | project | tag | dimension_option | operating_settings | unknown",
      "raw_text": "原始片段",
      "title": "给用户看的简短标题",
      "date_text": "今天/昨天/2026-04-28/null",
      "time_range_text": "14:00-16:00/null",
      "duration_text": "2小时/null",
      "amount_text": "3000元/null",
      "category_text": "工作/必要支出/null",
      "source_text": "客户A/null",
      "content_text": "学习 Rust/null",
      "project_texts": ["SkyeOS"],
      "tag_texts": ["AI"],
      "note_text": "备注/null",
      "unmapped_text": "未消费文本/null",
      "efficiency_score": 8,
      "value_score": null,
      "state_score": null,
      "ai_assist_ratio": 30,
      "is_passive": null,
      "confidence": 0.82,
      "warnings": []
    }
  ]
}
```

## 规则兜底策略

```text
LLM response
  -> strict JSON parse
      成功：标准草稿层
      失败：提取 ```json code block
          成功：标准草稿层，warning = llm_json_repaired
          失败：提取第一个 JSON object/array
              成功：标准草稿层，warning = llm_json_repaired
              失败：使用 rule parser 基于 raw_text 重新解析
```

关键约束：

- 规则兜底永远使用原始 `raw_text`，不使用坏掉的 LLM 输出。
- 规则解析无法识别时，生成 `unknown` draft，保留 raw_text 和 note。
- 修复成功的 LLM 结果也必须进入规则补全、绑定解析、必填检查。

## 字段与计算边界

### 时间

- AI 抽：日期文本、时间范围文本、时长文本。
- Rust 算：`occurred_on`、`started_at`、`ended_at`、`duration_minutes`、UTC。
- 缺开始时间但有时长：可以默认 09:00，但必须 warning。
- 跨天时间：Rust 计算时允许 end <= start 后加一天。

### 金钱

- AI 抽：金额原文和单位。
- Rust 算：`amount_cents`。
- 支持：元、块、分、千、k、万、w、人民币符号。
- 外币暂不自动换算，先进入 `needs_review`。

### 效率

- 字段：`efficiency_score`、`value_score`、`state_score`、`ai_assist_ratio`。
- Rust 校验：评分 1-10，百分比 0-100。
- 复盘计算：按 `duration_minutes` 加权平均。

### 项目绑定

所有事实记录都支持项目绑定。

```text
record_project_links:
  record_kind
  record_id
  project_id
  weight_ratio
```

分摊公式：

```text
项目分摊值 = 记录值 * 当前项目 weight_ratio / 当前记录所有项目 weight_ratio 总和
```

适用：

- 时间 -> 项目投入时间。
- 收入 -> 项目收入。
- 支出 -> 项目直接成本。
- 学习 -> 学习服务的项目，先绑定留痕，后续可纳入项目能力投入分析。

### 标签绑定

所有事实记录都支持标签绑定。

```text
record_tag_links:
  record_kind
  record_id
  tag_id
```

标签用于横向分析和筛选，不改变金额、时长和项目成本分摊。

### 类别/维度绑定

- 时间类别决定工作/学习/生活/休息等时间口径。
- 收入类型决定收入结构。
- 支出类别决定必要支出、订阅、投资、体验等财务口径。
- 学习等级决定 input/applied/result。
- 项目状态决定项目管理视图。

## 必填检查规则

| Draft kind | 必填 | 可默认 | 阻塞条件 |
| --- | --- | --- | --- |
| time_record | 日期、类别、时间段或时长 | 类别默认 work，缺开始时间可默认 09:00 | 无时间段且无时长 |
| income_record | 日期、来源、类型、金额 | 类型默认 other，来源可默认未命名收入 | 金额缺失或非法 |
| expense_record | 日期、类别、金额 | 类别默认 necessary | 金额缺失或非法 |
| learning_record | 日期、内容、时长、学习等级 | 学习等级默认 input，时长可默认 60 | 内容缺失 |
| recurring_expense_rule | 名称、月金额、开始月 | 类别默认 subscription，必要性默认 false | 金额缺失 |
| monthly_cost_baseline | 月份、基础生活/固定订阅至少一个 | 缺项默认 0 | 两个金额都缺 |
| capex_cost | 名称、购买金额、使用月数、摊销开始月 | 残值率默认 0 | 金额或使用月数缺 |
| project | 名称、状态、开始日期 | 状态默认 active，开始日期默认 context_date | 名称缺失 |
| tag | 名称、scope | scope 默认 global | 名称缺失 |
| dimension_option | kind、code/display_name | code 可从 display_name 规范化 | kind 缺失 |
| operating_settings | 至少一个设置项 | 无 | 所有设置项都缺 |

## 前端职责

前端只处理：

- 输入 raw_text。
- 展示 draft 列表。
- 展示字段值、字段来源、必填缺失、warnings。
- 用户修改字段。
- 用户选择 unresolved 项目/标签/类别。
- 点击提交。

前端不处理：

- 金额换算。
- 本地时间转 UTC。
- 默认类别选择逻辑。
- 项目/标签 ID 解析。
- 数据库 payload 组装。

## 落地顺序

### 阶段 1：完整模块边界

完成标准：

- Rust 有 typed draft / field / link / validation 模型。
- Rust 有独立模块：preprocess、prompt、repair、draft、normalize、bind、validate、orchestrate。
- 旧 `parse_ai_input` 和 `commit_ai_drafts` 不破坏。
- 新增 `parse_ai_input_v2`，返回 typed draft。
- 规则解析结果可以转换成 typed draft。
- 单元测试覆盖 preprocess、repair、v2 FFI。

### 阶段 2：规则补全产品化

完成标准：

- 时间补全：
  - 日期文本转 `occurred_on`。
  - 时间范围转本地时间。
  - 本地时间转 UTC。
  - 时长和时间段互相校验。
  - 跨天处理。
- 金额补全：
  - 元、块、分、千、k、万、w 转 `amount_cents`。
  - 外币进入 `needs_review`。
- 效率补全：
  - 评分范围 1-10。
  - AI 占比 0-100。
- note 补全：
  - explicit note、unmapped_text、raw_text 差异合并。
- 所有补全必须标记 `source = rule/default` 和 warning。

### 阶段 3：绑定解析产品化

完成标准：

- 项目绑定：
  - 支持 ID、精确名称、大小写匹配。
  - 支持 unresolved refs 返回前端。
  - 支持 weight_ratio。
- 标签绑定：
  - 支持 ID、名称、scope。
  - 支持 auto_create_tags 作为明确 commit option。
- 维度绑定：
  - 类别名/code -> 维度 code。
  - 找不到时阻塞或 needs_review，不能静默落默认。
- 绑定结果统一进入 `DraftLinks`。

### 阶段 4：必填检查和用户回流产品化

完成标准：

- 每种 Draft kind 有独立 required field spec。
- Draft 状态稳定为：
  - `commit_ready`
  - `needs_review`
  - `blocked`
- 前端能基于返回结构渲染：
  - 必填缺失
  - 字段来源
  - 警告
  - 未解析项目/标签/类别
  - 可编辑字段

### 阶段 5：Commit v2

完成标准：

- 新增 `commit_drafts_v2`。
- Commit 不接受前端拼正式表 payload。
- Commit 从 typed draft 生成：
  - `CreateTimeRecordInput`
  - `CreateIncomeRecordInput`
  - `CreateExpenseRecordInput`
  - `CreateLearningRecordInput`
  - 成本规则/项目/标签/维度管理 input。
- Commit 前再跑一次 normalize/bind/validate。
- 事务写入和 partial failure 行为明确。

### 阶段 6：前端迁移

完成标准：

- 快速录入页使用 `parse_ai_input_v2`。
- AI Chat 页使用 typed draft editor。
- 手动录入逐步改为提交 draft，而不是前端组装数据库 payload。
- 高频事实记录和低频配置/管理分入口展示。

### 阶段 7：LLM 引擎接入

完成标准：

- 使用 `ai_service_configs` 中的 provider/base_url/model/api_key/system_prompt。
- LLM response 先走 repair。
- repair 失败则 rule parser 基于 raw_text 兜底。
- LLM 输出和 rule hints 合并，但所有结果仍必须走 normalize/bind/validate。

### 阶段 8：长期配置和管理类 Draft

完成标准：

- 支持 `monthly_cost_baseline`。
- 支持 `recurring_expense_rule`。
- 支持 `capex_cost`。
- 支持 `operating_settings`。
- 支持 `project`。
- 支持 `tag`。
- 支持 `dimension_option`。

这些 Draft 和高频事实记录共享解析入口，但前端分流到不同审核 UI。
