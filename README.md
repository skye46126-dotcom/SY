# SY（SkyeOS / Life OS）

## 项目名称
SY（SkyeOS / Life OS）

## 项目简介
SY 是一个面向“自我经营”的个人操作系统。  
它把每天的时间、项目、学习和资金流整合到一个统一工作流中，帮助你从“记录事实”走向“持续复盘与优化决策”。

我们相信：真正长期有效的成长，不是靠一时冲刺，而是靠可追踪、可复盘、可迭代的系统。

## 功能特性
- 一站式记录：时间、收入、支出、学习记录统一管理
- 项目化管理：将碎片行动挂靠到项目，追踪投入与产出
- 智能解析：自然语言输入自动解析成结构化草稿
- 周期复盘：支持日/周/月/年/区间维度复盘分析
- 成本洞察：固定成本、周期支出、CapEx 摊销与费率对比
- 快照机制：关键指标按时间窗口沉淀，支持趋势观察
- 导出与分享：数据包导出（JSON/CSV/ZIP）与跨端分享
- 备份与恢复：本地备份 + 云端同步，降低数据风险

## 技术栈
- 客户端：Flutter
- 核心引擎：Rust
- 数据存储：SQLite
- 桥接层：`dart:ffi` + Rust `cdylib`
- 通信与扩展：`reqwest`（用于 AI/云同步能力）

## 项目结构
```text
.
├── life_os_app/            # Flutter 应用层（界面、交互、路由）
├── src/                    # Rust 核心层（业务、服务、FFI、数据访问）
├── migrations/             # 数据库迁移脚本
├── tests/                  # Rust 集成测试与测试语料
└── Cargo.toml              # Rust 包配置
```

## 快速开始
1. 准备环境
- Rust（stable）
- Flutter SDK（满足 `life_os_app/pubspec.yaml`）

2. 运行核心测试
```bash
cargo test
```

3. 启动 Flutter 客户端
```bash
cd life_os_app
flutter pub get
flutter run
```

4. 生成演示数据（可选）
```bash
cargo run --bin seed_demo_db ./tmp/life_os_demo.db
```

## 环境变量
项目默认不依赖必填环境变量，核心配置（如 AI 服务、云同步配置）可通过系统内配置写入数据库。

测试时可选：
- `LIFE_OS_TEST_AI_API_KEY`
- `LIFE_OS_TEST_AI_RAW_TEXT`

## 使用方式
- 普通用户：通过 Flutter 客户端进行记录、复盘、导出、备份
- 开发者：通过 Rust Service 层或 FFI Bridge 调用核心能力
- 统一桥接入口：
  - `invoke_json(database_path, method, payload_json)`
  - `life_os_invoke(...)`

## 核心流程
1. 初始化数据库与默认用户
2. 采集记录（手动输入或 AI 解析）
3. 记录关联项目与标签
4. 聚合生成今日状态与周期复盘
5. 沉淀快照并支持导出/备份/恢复

## API 文档
FFI Bridge 在 `src/ffi.rs` 统一管理，响应格式为：

- 成功：`{ "ok": true, "data": ... }`
- 失败：`{ "ok": false, "error": { "code": "...", "message": "..." } }`

核心方法族：
- 初始化与演示：`init_database`、`seed_demo_data`
- 记录与总览：`create_*_record`、`get_today_overview`、`get_recent_records`
- 项目与标签：`create_project`、`list_projects`、`create_tag`
- 复盘分析：`get_review_report`、`chat_review`
- AI：`parse_ai_input`、`parse_ai_input_v2`、`commit_ai_capture`
- 导出与备份：`export_data_package`、`create_backup`、`restore_from_backup_record`

## 数据模型
核心领域模型覆盖：
- 用户与设置
- 项目与标签体系
- 四类记录（时间/收入/支出/学习）
- 记录与项目/标签关联
- 周期复盘与指标快照
- 成本基线、周期规则、CapEx
- AI 服务配置与云同步配置
- 备份与恢复记录

详细表结构见 `migrations/` 目录下 SQL 文件。

## 开发说明
- 推荐分层：`service -> repository -> db`
- 新增 FFI 能力时请同步更新：
  - Rust `src/ffi.rs`
  - Flutter `RustApi` 抽象
  - Flutter `NativeRustApi` 实现
- 提交前建议执行：
```bash
cargo test
```

## 部署说明
- Rust 核心编译为动态库供 Flutter 加载
- 常见产物：
  - Android/Linux：`liblife_os_core.so`
  - macOS：`liblife_os_core.dylib`
  - Windows：`life_os_core.dll`
- 建议发布前完成：启动可用性、核心流程可用性、导出备份可用性验证

## 常见问题
Q: 启动后提示 Rust bridge 未接入？  
A: 动态库未正确加载，应用会回退到占位实现，请检查平台打包与库文件路径。

Q: AI 配置是否必须通过环境变量？  
A: 不必须，当前推荐在系统内配置后持久化到数据库。

Q: 如何快速体验完整流程？  
A: 建议先执行 `seed_demo_db` 生成演示数据，再进入客户端联调。

## Roadmap
- 全量打通 Flutter 页面与 Rust Bridge 的双向能力
- 强化 AI 解析质量与可解释回退链路
- 增加跨平台自动化测试与发布流水线
- 增强导出模板、分享体验与协作场景
- 补充公开示例与开发文档体系

## License
当前仓库尚未附带正式 `LICENSE` 文件。  
如用于公开发布，建议先补充许可证声明。
