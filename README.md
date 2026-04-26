# SkyeOS

> Local-first Life OS built with Flutter, Rust, and SQLite.  
> 基于 Flutter、Rust 与 SQLite 的本地优先个人 Life OS。

<p align="left">
  <img src="https://img.shields.io/badge/Flutter-App%20Shell-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Rust-Core%20%2B%20FFI-000000?style=flat-square&logo=rust&logoColor=white" alt="Rust" />
  <img src="https://img.shields.io/badge/SQLite-Local%20First-003B57?style=flat-square&logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/Status-Active%20Rebuild-7C3AED?style=flat-square" alt="Status" />
  <img src="https://img.shields.io/badge/PRs-Welcome-16A34A?style=flat-square" alt="PRs Welcome" />
</p>

## Language

- [English](README.en.md)
- [简体中文](README.zh-CN.md)

## Overview

SkyeOS unifies daily capture, projects, reviews, AI-assisted parsing, and backup workflows into one local-first data pipeline.

SkyeOS 将日常记录、项目管理、复盘、AI 辅助解析与备份能力整合到一条本地优先的数据链路中。

## Repository Layout

- `life_os_app`: Flutter application shell
- `src`: Rust core library
- `tests`: Rust integration and FFI tests
- `migrations`: database migrations

## Architecture

```mermaid
flowchart TB
    A["Flutter App
    life_os_app/lib"] --> A1["App / Router / Shell"]
    A1 --> A2["Feature Pages + Controllers
    today / capture / management / review / projects / settings"]
    A2 --> A3["AppService"]
    A3 --> A4["RustApi Interface / 接口"]
    A4 --> A5["NativeRustApi
    dart:ffi"]

    A5 --> B["Rust Core Dynamic Library
    life_os_core (cdylib)"]
    B --> B1["FFI Bridge
    src/ffi.rs"]
    B1 --> B2["Service Layer
    Record / Project / Review / Snapshot / Cost / AI / Backup"]

    B2 --> C["Repository Layer
    record_repository
    project_repository
    review_repository
    snapshot_repository
    cost_repository
    ai_repository
    sync_repository"]

    C --> D["DB Layer
    connection / migration / schema"]
    D --> E[("Local SQLite Database / 本地 SQLite 数据库")]

    B2 --> F["AI Orchestrator
    rule parser / llm / vcp"]
    B2 --> G["Cloud Sync / Backup
    curl transport"]
    G --> H["Remote Backup API / 远端备份接口"]
```

## Quick Start

```bash
cargo test
cd life_os_app
flutter pub get
flutter run
```

For full documentation, use the language-specific files above.  
完整文档请查看上方的中英文版本。
