# SY（SkyeOS / Life OS）

## 项目名称
SY（SkyeOS / Life OS）

## 项目简介
SY 是一个以「生活-项目-复盘」为核心的数据系统，采用 `Flutter + Rust + SQLite` 架构。

- Flutter 负责界面与交互
- Rust 负责核心业务、数据处理、AI 解析、导出与备份
- SQLite 负责本地持久化
- Flutter 通过 `dart:ffi` 调用 Rust 的统一 JSON Bridge

## 功能特性
- 今日总览：收入、支出、净收益、时间投入、提醒、目标进度
- 记录管理：时间记录、收入记录、支出记录、学习记录
- 项目与标签：项目状态、项目详情、记录关联项目与标签
- AI 解析：自然语言输入解析草稿、提交为结构化记录
- 复盘分析：按日/周/月/年/区间生成复盘报告
- 成本模块：月基线、周期规则、CapEx 摊销、费率对比
- 快照系统：按窗口生成指标快照与项目快照
- 导出能力：JSON/CSV/ZIP 数据包导出与预览
- 备份能力：本地备份、恢复、云端上传/下载/回滚

## 技术栈
- Rust `edition = 2024`
- Flutter `>=3.4`（Dart `>=3.4.0 <4.0.0`）
- SQLite（`rusqlite` bundled）
- FFI（`cdylib` + `dart:ffi`）
- HTTP（`reqwest`，用于 AI/云同步相关能力）
- 测试：Rust `cargo test` + Flutter `flutter_test`

## 项目结构
```text
.
├── src/                    # Rust 核心（service/repository/model/ffi/db）
├── migrations/             # SQLite 迁移脚本（0001~0004）
├── tests/                  # Rust 集成测试与样例语料
├── life_os_app/            # Flutter 客户端
│   ├── lib/
│   │   ├── features/       # 页面功能模块
│   │   ├── services/       # Rust API 适配、导出、分享
│   │   └── models/         # Flutter 侧模型
│   └── test/               # Flutter 测试
└── Cargo.toml              # Rust 包配置（life_os_core）
```

## 快速开始
1. 安装依赖
- Rust（建议 stable 最新版）
- Flutter SDK（满足 `pubspec.yaml` 约束）

2. 拉起 Rust 核心
```bash
cargo test
```

3. 生成演示数据库（可选）
```bash
cargo run --bin seed_demo_db ./tmp/life_os_demo.db
```

4. 运行 Flutter 客户端
```bash
cd life_os_app
flutter pub get
flutter run
```

## 环境变量
当前核心运行不强依赖环境变量，主要配置存储在数据库（如 AI 配置、云同步配置）。

仅测试场景可选变量：
- `LIFE_OS_TEST_AI_API_KEY`：FFI AI 测试使用的 API Key
- `LIFE_OS_TEST_AI_RAW_TEXT`：FFI AI 测试使用的原始文本语料

## 使用方式
- Rust 侧直接调用 `service` 层（如 `RecordService`、`AiService`）
- Flutter 侧通过 `NativeRustApi` 调用桥接方法
- 统一入口：
  - Rust JSON 调用入口：`invoke_json(database_path, method, payload_json)`
  - C ABI 导出入口：`life_os_invoke(...)`

Flutter 默认数据库路径（见 `life_os_app/lib/main.dart`）：
- Android: `/data/user/0/com.example.life_os_app/files/life_os.db`
- macOS: `$HOME/Library/Application Support/life_os.db`
- iOS: `life_os.db`

## 核心流程
1. 应用启动调用 `init_database`
2. Rust 执行 migration 并确保默认用户存在
3. 前端发起增删改查请求到 FFI Bridge
4. Bridge 分发到各 Service（记录/项目/复盘/成本/AI/备份）
5. Service 调用 Repository 落库到 SQLite
6. 需要导出、备份或 AI 解析时进入对应子流程

## API 文档
Bridge 方法定义集中在 `src/ffi.rs`，响应统一结构：
- 成功：`{ "ok": true, "data": ... }`
- 失败：`{ "ok": false, "error": { "code": "...", "message": "..." } }`

主要方法分组：
- 初始化与演示：`init_database`、`seed_demo_data`
- 今日与记录：`get_today_overview`、`get_recent_records`、`create_*_record`
- 项目与标签：`list_projects`、`get_project_detail`、`create_project`、`create_tag`
- 复盘：`get_review_report`、`chat_review`、`get_tag_detail_records`
- AI：`parse_ai_input`、`parse_ai_input_v2`、`commit_ai_drafts`、`commit_ai_capture`
- 导出：`export_seed_data`、`preview_data_package_export`、`export_data_package`
- 备份与云同步：`create_backup`、`restore_from_backup_record`、`upload_*`、`download_*`
- 成本与快照：`get_monthly_baseline`、`list_capex_costs`、`recompute_snapshot`

## 数据模型
核心实体（部分）：
- 用户：`users`
- 项目：`projects`
- 标签：`tags`
- 记录：`time_records`、`income_records`、`expense_records`、`learning_records`
- 关联：`record_project_links`、`record_tag_links`
- 复盘：`daily_reviews`、`review_snapshots`、`review_notes`
- 指标快照：`metric_snapshots`、`metric_snapshot_projects`
- 成本：`expense_baseline_months`、`expense_recurring_rules`、`expense_capex_items`
- 同步与备份：`backup_records`、`restore_records`、`cloud_sync_configs`
- AI 配置：`ai_service_configs`

完整模型与约束见 `migrations/0001_init_core.sql` ~ `0004_review_notes.sql`。

## 开发说明
- Rust 核心在 `src/services`，保持 service -> repository -> db 分层
- FFI 新增方法时需同步：
  - `src/ffi.rs` 方法分发
  - Flutter `RustApi` 抽象
  - Flutter `NativeRustApi` 实现
- 推荐每次改动后执行：
```bash
cargo test
```

## 部署说明
- Rust 产物为 `cdylib`，用于 Flutter 原生侧加载
- Android/Linux 通常使用 `liblife_os_core.so`
- macOS 使用 `liblife_os_core.dylib`
- Windows 使用 `life_os_core.dll`
- iOS 通常通过 `DynamicLibrary.process()` 方式集成

发布前建议检查：
- 目标平台动态库是否已正确打包
- 首次启动是否可成功 `init_database`
- 关键桥接方法（记录写入、读取、导出）是否可用

## 常见问题
Q: 为什么应用启动后显示桥接未实现？
A: 说明动态库未被正确加载，Flutter 会回退到 `UnimplementedRustApi`。

Q: 运行后数据库文件在哪里？
A: 见“使用方式”中的平台默认路径。

Q: AI 配置一定要写环境变量吗？
A: 不需要，当前设计是将 AI 服务配置持久化到数据库。

Q: 如何快速得到可调试数据？
A: 使用 `seed_demo_data` 或运行 `seed_demo_db` 生成演示库。

## Roadmap
- 完善 FFI 方法在 Flutter 侧的全量接入与页面联调
- 增加更多端到端测试（Flutter + Rust Bridge）
- 增强 AI 解析策略与失败回退可观测性
- 丰富导出模板与分享能力
- 补充 CI（多平台构建与测试）

## License
当前仓库未显式提供许可证文件（如 `LICENSE`）。
如需开源发布，建议补充许可证后再分发。
