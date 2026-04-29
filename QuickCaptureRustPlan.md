# Quick Capture Rust 方案

目标：让所有快捷入口只负责采集，真正的快录能力统一沉到 Rust，UI 只负责展示、确认和少量编辑。

## 总体链路

`launcher / tile / card / voice / share`
-> `UI 采集文本或语音转写`
-> `Rust capture_inbox 暂存`
-> `Rust 统一解析与规则补全`
-> `UI 审核草稿`
-> `Rust commit_ai_capture 入库`

## 阶段划分

### 第一阶段：后端快录底座

目标：把所有外部入口先汇聚成同一条 Rust 队列。

Rust 模块：
- `capture_inbox` 表
- `CaptureInboxEntry` / `CreateCaptureInboxEntryInput`
- `CaptureService::enqueue_capture_inbox`
- `CaptureService::list_capture_inbox`
- `CaptureService::get_capture_inbox`
- `CaptureService::process_capture_inbox`
- FFI 桥接方法

结果：
- UI 或原生入口都可以先把原始文本扔进 inbox
- Rust 负责记录来源、模式、类型 hint、解析结果和错误状态

### 第二阶段：快录编排层

目标：让 UI 不必自己拼 AI 解析和状态管理。

Rust 模块：
- `process_capture_inbox_and_commit`
- 默认项目 / 标签 / 时间规则补全
- 最近项目、最近标签、默认 parser mode 策略
- 失败重试与幂等处理

结果：
- UI 只需要调用“处理 inbox”并展示草稿
- 复杂规则沉到 Rust

### 第三阶段：系统级快录

目标：支持语音、服务卡片、控制中心快捷开关等高频入口。

Rust 模块：
- 统一入口 profile
- 语音转写结果入 inbox
- 快录模板与偏好
- 后台处理状态与恢复
- 草稿确认后的快速提交接口

结果：
- 所有入口最终都变成“采集 -> inbox -> parse -> confirm -> commit”

## 模块边界

Rust 负责：
- 数据结构
- 队列状态
- AI 解析调用
- 规则补全
- 入库提交
- 错误恢复

UI 负责：
- 文本输入
- 语音录制和转写触发
- 草稿展示与编辑
- 用户确认
- 入口态反馈

## 当前落地顺序

1. 完成 `capture_inbox` migration、model、repository、service、ffi
2. 让 Flutter / 原生入口改为先写 inbox，再请求解析
3. 增加 inbox -> draft -> commit 的编排接口
4. 再接服务卡片、快捷开关、语音快录
