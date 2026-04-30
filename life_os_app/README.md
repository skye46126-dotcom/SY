# life_os_app

Flutter UI shell for SkyeOS, rebuilt from `重构.md`.

Current direction:

- no mock cards
- no fake dashboard numbers
- all pages are structured around real service contracts
- each page handles `loading / empty / unavailable / error / data`
- page tree follows the reconstruction document
- real data chain is `Flutter -> dart:ffi -> Rust JSON bridge -> Service -> Repository -> SQLite`

Implemented structure:

- `Today`
  - status hero
  - core metrics
  - goal progress slot
  - recent records
  - snapshot slot
- `Capture`
  - type selector
  - modular form shell
  - AI capture confirmation flow
- `Management`
  - grouped entry layout
- `Review`
  - summary
  - core trends
  - deep dive slot
- secondary pages
  - projects list
  - project detail
  - day detail
  - time management
  - ledger management
  - cost management
  - settings
  - tag manage
  - backup
  - AI chat

Important constraints in the current workspace:

- `flutter` is not installed
- `dart` is not installed
- Flutter side cannot be run in this environment, but the Rust FFI bridge is now wired in code

Because of that, the app is written as a real Flutter structure but has not been executed locally in this environment.

Current bridge files:

- Rust bridge: `src/ffi.rs`
- Flutter native adapter: `lib/services/native_rust_api.dart`

Current bridged methods:

- `init_database`
- `get_today_overview`
- `get_recent_records`
- `get_records_for_date`
- `create_time_record`
- `create_income_record`
- `create_expense_record`
- `create_project`
- `create_tag`
- `list_tags`
- `list_projects`
- `get_project_detail`
- `get_review_report`
- `get_tag_detail_records`
- `parse_ai_input`
- `commit_ai_drafts`

Next recommended steps:

1. Install Flutter and run `flutter create .` inside `life_os_app` only if you want the tool-managed files.
2. Replace `UnimplementedRustApi` with a real FFI adapter.
3. Bind Capture form fields to typed payload builders.
4. Add per-page tests once Flutter is available.
