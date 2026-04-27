# 数据库与 UI 数据流梳理

本文按 `SQLite schema -> Rust repository/service -> FFI -> Flutter model/controller/page` 的链路，梳理当前项目里数据库、计算逻辑、数据关系，以及最终在 UI 上展示的数据。

## 1. 总体结构

当前项目的数据流分成 5 层：

1. `migrations/*.sql`
   定义 SQLite 表、索引、默认维度值。
2. `src/repositories/*.rs`
   真正执行查询、聚合、口径计算。
3. `src/services/*.rs`
   对 repository 做服务封装。
4. `src/ffi.rs`
   暴露 Flutter 可调用的方法名。
5. `life_os_app/lib/features/**`
   Flutter controller 取数，page/widget 展示。

可以把它理解为：

`事实表 + 关系表 + 成本表 + 快照表` -> `聚合计算` -> `JSON` -> `Flutter Model` -> `页面卡片`

---

## 2. 数据库主干

### 2.1 核心身份与配置

- `users`
  用户主表。关键字段：
  - `timezone`
  - `currency_code`
  - `ideal_hourly_rate_cents`
- `settings`
  用户级 key-value 配置。当前主要承载：
  - `today_work_target_minutes`
  - `today_learning_target_minutes`
- `user_sessions`
  会话信息。

### 2.2 维度表

- `dim_project_status`
- `dim_time_categories`
- `dim_income_types`
- `dim_expense_categories`
- `dim_learning_levels`
- `dimension_options`

说明：

- 当前业务实际查询主要还是直接使用 `dim_*` 表。
- `save_dimension_option` 会直接写回对应的 `dim_*` 表。
- 录入时如果传入新的 code，Rust 会自动补齐维度项。

### 2.3 核心事实表

- `projects`
- `tags`
- `time_records`
- `income_records`
- `expense_records`
- `learning_records`

这 4 张记录表是所有经营分析的核心来源：

- 时间投入：`time_records`
- 收入：`income_records`
- 支出：`expense_records`
- 学习投入：`learning_records`

### 2.4 关系表

- `record_project_links`
  把 `time/income/expense/learning` 记录关联到项目。
- `record_tag_links`
  把 `project/time/income/expense/learning` 关联到标签。

关键点：

- 多项目关联通过 `weight_ratio` 做分摊。
- 一个记录如果关联多个项目，项目统计不会整条重复计入，而是按：

`记录值 * 当前项目 weight_ratio / 该记录所有 weight_ratio 之和`

### 2.5 成本与经营分析表

- `expense_baseline_months`
  每月固定基线，包含：
  - `basic_living_cents`
  - `fixed_subscription_cents`
- `expense_recurring_rules`
  周期性成本规则。
- `expense_capex_items`
  CAPEX 及摊销。
- `metric_snapshots`
  日/周/月/年窗口的总快照。
- `metric_snapshot_projects`
  快照下每个项目的经营分解。
- `daily_reviews`
  每日复盘文本。
- `review_snapshots`
  预留的复盘快照表，目前 Review 页面主要还是实时计算。

### 2.6 系统与同步

- `ai_service_configs`
- `cloud_sync_configs`
- `backup_records`
- `restore_records`
- `audit_logs`
- `schema_migrations`

---

## 3. 核心关系

### 3.1 用户到业务数据

- `users.id` -> 所有业务表 `user_id`

### 3.2 项目与记录

- `projects.id` <- `record_project_links.project_id`
- `record_project_links.record_kind + record_id`
  指向 4 张事实表之一

### 3.3 标签与记录/项目

- `tags.id` <- `record_tag_links.tag_id`
- `record_tag_links.record_kind`
  允许绑定：
  - `project`
  - `time`
  - `income`
  - `expense`
  - `learning`

### 3.4 快照与项目快照

- `metric_snapshots.id` -> `metric_snapshot_projects.metric_snapshot_id`

---

## 4. 关键计算口径

## 4.1 Today 页面

对应 Rust：

- `get_today_overview`
- `get_today_goal_progress`
- `get_today_alerts`
- `get_today_summary`
- `get_snapshot(window=day)`

### TodayOverview

字段来源：

- `total_income_cents`
  当天 `income_records.amount_cents` 求和
- `total_expense_cents`
  当天 `expense_records.amount_cents` 求和
- `net_income_cents`
  `income - expense`
- `total_learning_minutes`
  当天 `learning_records.duration_minutes` 求和
- `total_time_minutes`
  从 `time_records` 取与当天有交集的记录，按真实重叠分钟数计算
- `total_work_minutes`
  同上，但只统计 `category_code = 'work'`

说明：

- Today 的时间统计不是简单看 `started_at` 落在哪天，而是按与当天窗口的重叠时间算。

### TodayGoalProgress

来源：

- `settings.today_work_target_minutes`
- `settings.today_learning_target_minutes`

计算：

- `completed_value` 直接来自 `TodayOverview`
- `progress_ratio_bps = completed / target * 10000`
- `status`
  - `done`
  - `missing`
  - `in_progress`

### TodayAlerts

告警规则：

- 没有工作和学习记录
- 有工作投入但净收入未转正
- 工作目标未达标
- 学习目标未达标
- 日快照里 `time_debt_cents > 0`
- 日快照里 `passive_cover_ratio < 1`

### TodaySummary

组合来源：

- `TodayOverview`
- `TodayAlerts`
- `metric_snapshots(day)`
- `users.ideal_hourly_rate_cents`

字段计算：

- `actual_hourly_rate_cents = total_income_cents * 60 / total_work_minutes`
- `finance_status`
  - `positive / negative / neutral`
- `work_status`
  - 用 `today_work_target_minutes` 判断
- `learning_status`
  - 用 `today_learning_target_minutes` 判断
- `freedom_cents`
  来自日快照
- `passive_cover_ratio_bps`
  来自日快照的 `passive_cover_ratio * 10000`

### Today Snapshot

日快照来自 `metric_snapshots`，其 `total_expense_cents` 不是纯支出流水，而是：

`直接支出 + 结构成本`

---

## 4.2 Snapshot 快照

对应 Rust：

- `recompute_snapshot`
- `get_snapshot`
- `get_latest_snapshot`
- `list_project_snapshots`

### 窗口

- `day`
- `week`
- `month`
- `year`

### 总快照口径

- `total_income_cents`
  窗口内收入总和
- `total_expense_cents`
  `直接支出 + 结构成本`
- `passive_income_cents`
  `income_records.is_passive = 1` 的收入
- `necessary_expense_cents`
  `necessary` 类别直接支出 + 必要结构成本
- `total_work_minutes`
  窗口内 `category_code = 'work'` 的时间记录分钟总和
- `hourly_rate_cents`
  `total_income * 60 / total_work_minutes`
- `time_debt_cents`
  `ideal_hourly_rate_cents - hourly_rate_cents`
- `passive_cover_ratio`
  `passive_income / necessary_expense`
- `freedom_cents`
  `passive_income - necessary_expense`

### 项目快照口径

项目快照来自 `metric_snapshot_projects`，核心字段：

- `income_cents`
- `direct_expense_cents`
- `structural_cost_cents`
- `operating_cost_cents`
- `total_cost_cents`
- `profit_cents`
- `invested_minutes`
- `roi_ratio`
- `break_even_cents`

计算逻辑：

- 项目收入/支出/投入时长，均按 `weight_ratio` 分摊
- `structural_cost_cents`
  按项目投入工时占窗口总工作时长比例分摊
- `time_cost_cents`
  按 benchmark 时薪折算
- `operating_cost_cents = direct_expense + time_cost`
- `total_cost_cents = operating_cost + structural_cost`
- `profit_cents = income - total_cost`
- `roi_ratio = (income - total_cost) / total_cost`

### benchmark 时薪回退顺序

1. 去年平均时薪
2. `users.ideal_hourly_rate_cents`
3. 全历史平均时薪

---

## 4.3 Project 页面

对应 Rust：

- `list_projects`
- `get_project_detail`

### ProjectOverview

页面列表只显示：

- 项目名
- 状态
- 分摊后的总时间
- 分摊后的总收入
- 分摊后的总支出

这三项都来自 `record_project_links.weight_ratio` 分摊结果。

### ProjectDetail

项目详情会先确定分析区间：

- 起点：`started_on` 与最早实际活动日期取更小值
- 终点：`ended_on`、今天、最后实际活动日期取合理边界

然后计算：

- `total_time_minutes`
- `total_income_cents`
- `direct_expense_cents`
- `total_learning_minutes`
- 各类记录数
- `time_cost_cents`
  = `benchmark_hourly_rate_cents * total_time_minutes / 60`
- `allocated_structural_cost_cents`
  = 项目时长占整个分析窗口总工作时长的比例分摊结构成本
- `operating_cost_cents = direct_expense + time_cost`
- `fully_loaded_cost_cents = operating_cost + allocated_structural_cost`
- `profit_cents = income - fully_loaded_cost`
- `break_even_income_cents = fully_loaded_cost`
- `hourly_rate_yuan = income / 工时`
- `operating_roi_perc`
- `fully_loaded_roi_perc`
- `evaluation_status`
  - `positive`
  - `warning`
  - `neutral`

此外还会返回：

- `tag_ids`
- `recent_records`

---

## 4.4 Review 页面

对应 Rust：

- `get_review_report`

Review 是实时窗口计算，不依赖 `review_snapshots`。

### 核心窗口数据

- `total_time_minutes`
  按时间类别聚合后的总和
- `total_work_minutes`
  work 类时间总和
- `total_income_cents`
  本期收入
- `total_expense_cents`
  本期直接支出 + 结构成本
- `previous_income_cents`
- `previous_expense_cents`
- `previous_work_minutes`

### 对比指标

- `income_change_ratio`
- `expense_change_ratio`
- `work_change_ratio`

### 效率与经营指标

- `actual_hourly_rate_cents`
- `ideal_hourly_rate_cents`
- `time_debt_cents`
- `passive_cover_ratio`
- `ai_assist_rate`
  = 所有时间记录的 `duration * ai_assist_ratio / 总时长`
- `work_efficiency_avg`
  = work 时间记录按 `duration_minutes` 加权的效率均分
- `learning_efficiency_avg`
  = learning 记录按 `duration_minutes` 加权的效率均分

### 时间分配

- `time_allocations`
  `time_records` 按 `category_code` 聚合

### 项目复盘

- `top_projects`
- `sinkhole_projects`

来源：

- 项目窗口内分摊后的时间、收入、直接支出
- 再分摊结构成本
- 计算 ROI 和 `evaluation_status`

### 标签分析

- `time_tag_metrics`
  标签关联到时间记录后，按分钟数聚合
- `expense_tag_metrics`
  标签关联到支出记录后，按金额聚合

### 历史记录

- `key_events`
  取本期最大支出和最长时间记录
- `income_history`
  收入流水
- `history_records`
  本期所有 time/income/expense/learning 合并流水

---

## 4.5 Cost 页面

对应 Rust：

- `get_monthly_baseline`
- `list_recurring_cost_rules`
- `list_capex_costs`
- `get_rate_comparison`

### 月基线

来自 `expense_baseline_months`：

- `basic_living_cents`
- `fixed_subscription_cents`

### 周期性成本

来自 `expense_recurring_rules`：

- `name`
- `category_code`
- `monthly_amount_cents`
- `is_necessary`
- `start_month`
- `end_month`
- `is_active`

### CAPEX

来自 `expense_capex_items`：

- `purchase_amount_cents`
- `residual_rate_bps`
- `useful_months`
- `monthly_amortized_cents`
- `amortization_start_month`
- `amortization_end_month`

CAPEX 摊销计算：

- `residual_cents = purchase_amount * residual_rate`
- `amortizable_cents = purchase_amount - residual_cents`
- `monthly_amortized_cents = amortizable_cents / useful_months`

### 结构成本窗口计算

在 Snapshot / Project / Review 里都会复用同一套思想：

`baseline + recurring + capex`

如果窗口不是整月，会按窗口覆盖天数做比例折算。

`necessary_only = true` 时：

- baseline 保留
- recurring 只算 `is_necessary = 1`
- capex 不计入

### 时薪比较

`get_rate_comparison` 返回：

- 理想时薪
- 本期实际时薪
- 去年平均时薪
- 去年收入
- 去年工作时长
- 本期收入
- 本期工作时长

---

## 4.6 Capture 录入页

对应 Rust：

- `get_capture_metadata`
- `create_*`
- `commit_ai_drafts`

`CaptureMetadata` 由以下数据拼成：

- `project_options`
- `tags`
- `time_categories`
- `income_types`
- `expense_categories`
- `learning_levels`
- `project_statuses`
- `income_source_suggestions`
- `defaults`

其中 `defaults` 的来源很关键：

- 时间类别：取最近一次时间记录的 `category_code`
- 收入类型：取最近一次收入记录的 `type_code`
- 支出类别：取最近一次支出记录的 `category_code`
- 学习等级：取最近一次学习记录的 `application_level_code`
- 项目状态：固定默认 `active`

---

## 5. UI 页面和数据来源映射

## 5.1 Today

页面：`life_os_app/lib/features/today/today_page.dart`

取数链路：

- `TodayController.load`
  - `getTodayOverview`
  - `getRecentRecords`
  - `getTodaySummary`
  - `getTodayGoalProgress`
  - `getTodayAlerts`
  - `getSnapshot(day)`，无则 `recomputeSnapshot(day)`

卡片与字段：

- `核心摘要`
  - 收入
  - 净收入
  - 总时长 / 工作 / 学习
  - 被动覆盖率
  - 自由度
  - 实际时薪 / 目标时薪
- `KPI Strip`
  - 收入
  - 时长
  - 效率
- `今日现金流`
  - 收入 / 支出 / 结余
  - 实际时薪
  - 自由度
- `今日时间结构`
  - 工作 / 学习 / 其他
- `今日目标进度`
  - 工作目标
  - 学习目标
- `经营健康度`
  - 净收入
  - 实际时薪
  - 被动覆盖率
- `今日提醒`
  - 告警列表
- `最近记录`
  - `RecentRecordItem`
  - 支持编辑 / 复制 / 删除

## 5.2 Review

页面：`life_os_app/lib/features/review/review_page.dart`

取数链路：

- `ReviewController.load`
  - `getReviewReport`
  - 对 `day/week/month/year` 再取 `getSnapshot`

卡片与字段：

- `周期总结`
  - `ai_summary` + 派生文案
- `周期总览`
  - 收入 / 支出 / 结余 / 工作时长 / AI 占比 / 效率
- `趋势分析`
  - 本期 vs 上期
- `时间分析`
  - `time_allocations`
  - `time_tag_metrics`
- `AI 与效率`
  - AI 占比
  - 工作效率
  - 学习效率
  - 单位收入耗时
- `项目复盘`
  - `top_projects`
  - `sinkhole_projects`
- `历史流水`
  - `key_events + income_history + history_records`

## 5.3 Projects

页面：

- `projects_page.dart`
- `project_detail_page.dart`

列表显示：

- 项目名
- 状态
- 时间
- 收入
- 支出

详情显示：

- 判断卡：状态、评估、ROI、经营 ROI
- 项目经营指标：收入、支出、总成本、利润、时长、学习
- 最近月度项目快照：收入、总成本、利润、投入、ROI
- 最近记录

## 5.4 Management

页面：`management_page.dart`

当前本身不展示数据库指标，只是导航入口：

- 收入流水
- 支出流水
- 时间记录
- 项目管理
- 成本管理
- 经营参数
- 标签管理
- 维度管理
- 设置

## 5.5 Day Detail / Time / Ledger

数据来源统一是：

- `getRecordsForDate`

展示内容：

- `RecentRecordItem.title`
- `RecentRecordItem.detail`
- `RecentRecordItem.occurredAt`

## 5.6 Cost Management

页面：`cost_management_page.dart`

展示：

- 月基线
- 理想时薪 / 本期实际时薪 / 上年平均时薪
- 活跃 / 非活跃周期规则
- 活跃 / 非活跃 CAPEX

## 5.7 Operating Settings

页面：`operating_settings_page.dart`

展示和编辑：

- `users.timezone`
- `users.currency_code`
- `users.ideal_hourly_rate_cents`
- `settings.today_work_target_minutes`
- `settings.today_learning_target_minutes`
- 当月 `expense_baseline_months`

## 5.8 Tag / Dimension / AI / Cloud / Backup / Settings

这些页面主要对应配置类表：

- `TagManagePage` -> `tags`
- `DimensionManagePage` -> `dim_*`
- `AiServiceConfigsPage` -> `ai_service_configs`
- `CloudSyncConfigsPage` -> `cloud_sync_configs`
- `BackupPage` -> `backup_records / restore_records`
- `SettingsPage`
  - 当前用户资料
  - 当前激活 AI 配置
  - 当前激活云同步配置
  - 导出中心入口

## 5.9 图片导出 / 导出中心

当前图片导出走的是一条独立于数据库写入链路的 UI 输出链：

- Flutter Page
  - `TodayPage`
  - `ReviewPage`
  - `ProjectDetailPage`
  - `CostManagementPage`
  - `ExportCenterPage`
  - `DayDetailPage`
- 当前 controller 已加载的数据
  - `TodayPageData`
  - `ReviewPageData`
- `AppleDashboardPage(exportBoundaryKey)`
- `ModulePage(exportBoundaryKey)`
  提供统一的导出边界。
- `ImageExportService`
  - 把当前 dashboard 渲染成 PNG
  - 同时写出一份 JSON 元数据文档
  - 维护本地 `export_index.json`
  - 提供导出历史列表与删除能力
- `export_metadata_builders.dart`
  统一生成 Today / Review / Project / Cost / Day Detail 的 JSON 元数据
- 本地文件系统
  - 桌面端优先写到 `Downloads/SkyeOS/exports`
  - 移动端回退到应用文档目录

这条链路的特点是：

- 图片本身来自当前 UI 画面
- 元数据来自已经通过 Rust 取回并绑定到 controller 的聚合结果
- 不新增数据库表，也不额外引入 Rust 导出接口
- `ExportCenterPage` 负责汇总导出入口、备份入口、导出目录说明
- `ExportCenterPage` 还负责回看最近导出、预览图片文档、删除旧导出

---

## 6. RecentRecordItem 的统一格式

多个页面复用 `RecentRecordItem`。

来源表与显示格式：

- `time_records`
  - `title = category_code`
  - `detail = note`
- `income_records`
  - `title = source_name`
  - `detail = "{amount_cents} cents | note"`
- `expense_records`
  - `title = category_code`
  - `detail = "{amount_cents} cents | note"`
- `learning_records`
  - `title = content`
  - `detail = "{duration_minutes} min | note"`

它用于：

- Today 最近记录
- Day Detail
- 时间管理 / 流水管理
- Project 最近记录
- Review 历史流水

---

## 7. 需要特别注意的口径差异

这部分最关键，后续如果要改 UI 或统一报表，优先处理。

### 7.1 Today 的时间统计和明细列表口径不一致

- `get_today_overview`
  对跨天时间记录按“重叠分钟”计算。
- `get_records_for_date`
  只取 `started_at` 落在当天的记录。

结果：

- 一条跨午夜的时间记录，可能会计入 Today 总时长，但不出现在当天明细列表里。

### 7.2 Today 的支出口径和 Snapshot / Review 的支出口径不一致

- Today `total_expense_cents`
  只算 `expense_records`
- Snapshot / Review `total_expense_cents`
  算 `expense_records + 结构成本`

结果：

- Today 的“结余/支出”是现金流口径。
- Review / Snapshot 的“支出/结余”更接近经营口径。

UI 上如果都叫“支出”或“结余”，用户容易误解。

### 7.3 Review / Project / Snapshot 的项目 ROI 口径目前已经基本对齐

当前代码中的 `ReviewRepository::load_project_buckets` 已经采用：

- `time_cost_cents = benchmark_hourly_rate_cents * time_spent_minutes / 60`
- `operating_cost_cents = direct_expense_cents + time_cost_cents`
- `fully_loaded_cost_cents = operating_cost_cents + allocated_structural_cost_cents`

这和 `ProjectDetail`、`Snapshot` 的时间成本与结构成本思路已经一致。

因此现阶段更值得注意的是：

- UI 上要明确区分 `operating` 与 `fully loaded`
- 文档不要继续沿用旧口径说明

### 7.4 `time_debt_cents` 的语义更像“时薪差额”，不是严格意义上的金额债务

当前公式：

`time_debt_cents = ideal_hourly_rate_cents - hourly_rate_cents`

这本质上是“目标时薪 - 实际时薪”的差值，不是某个时间窗口累计出来的债务金额。

### 7.5 项目分摊求和有整数截断

项目统计大量使用：

`CAST(SUM(...)) AS INTEGER`

这会导致：

- 单项目显示没问题
- 但多个项目加总时，可能和全局总数存在几分钱/几分钟误差

---

## 8. 当前最值得继续做的事

如果后续要继续收敛数据口径，建议按这个顺序：

1. 统一“现金流口径”和“经营口径”的命名
   - Today 显示为“现金支出/现金结余”
   - Review / Snapshot 显示为“经营支出/经营结余”
2. 统一跨天时间记录的日归属规则
   - 汇总、明细、复盘至少要一致
3. 继续把 `time_debt_cents` 的 UI 命名收敛为“时薪差额”一类表达
   - 底层字段先不强制重命名，避免牵一发而动全身
4. 把图片导出做成独立模块
   - 统一使用 dashboard 导出边界
   - 输出 `png + json metadata`
   - 再逐步扩到 Project / Cost / Day Detail
5. 视查询性能情况决定是否把 `review_snapshots` 真正用起来
   - 避免大窗口实时聚合过重

---

## 9. 一句话结论

当前系统已经形成了比较清晰的“记录事实表 + 项目/标签关系表 + 成本表 + 快照表 + UI 聚合页”结构；真正需要后续统一的，不是表设计本身，而是不同页面之间对“时间归属、支出口径、项目 ROI、时间债”这几类指标的计算口径。
