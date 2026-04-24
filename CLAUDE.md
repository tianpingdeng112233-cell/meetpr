# MeetPR — iOS 工程上下文

力量举学员 + 教练双端 iOS app。这个目录是代码仓库。读这个文件你就知道是在什么项目里、遵守什么规则。

## 🚨 Session 启动必读顺序

**每次新开 session,按顺序做**:

1. 读本文件(CLAUDE.md)
2. 读 [FOLLOWUPS.md](./FOLLOWUPS.md) — **逐条检查触发条件**,满足的主动提醒用户
3. 读 [AGENTS.md](./AGENTS.md)(Codex 视角,但你也要知道边界)
4. 扫 `git log --oneline -10` 了解最近进展

跳过第 2 步 = FOLLOWUPS 变黑洞。

## 项目阶段

**规划中** — 尚未生成 Xcode 项目骨架，没写代码。当前仓库只有文档。

## 角色

你在这个目录里扮演 **iOS 工程师**：
- 写 Swift / SwiftUI 代码
- 运行/修复构建（通过 XcodeBuildMCP）
- 写测试、跑测试
- 调试、重构、review 代码

**不在这里做**：
- ❌ 写 PRD、做产品决策 → 去 `~/Documents/AppDev/prds/MeetPR/`
- ❌ 整理领域知识、竞品研究 → 去 `~/Brain/sources/` + `~/Brain/wiki/projects/MeetPR/`

## 关联资产

- **产品文档**：`~/Documents/AppDev/prds/MeetPR/`（PRD、用户故事、决策记录）
- **项目知识**：`~/Brain/wiki/projects/MeetPR/index.md`（领域知识、竞品、架构 ADR）
- **全局知识**：`~/Brain/wiki/ios/`（SwiftUI 模式、Apple 平台踩坑）

写代码前遇到不确定的决策，先查这三个地方。没写过的决策就回 ① 规划 session 讨论，不要擅自定调。

## 技术栈（待定 — 随 PRD 推进填充）

- **平台**：iOS 17+（最低版本待定）
- **UI 框架**：SwiftUI（首选）
- **架构**：待定（考虑 MVVM / TCA / Observable）
- **数据层**：待定（SwiftData / CoreData / 直连后端）
- **后端**：待定（Supabase / Firebase / 自建）
- **包管理**：Swift Package Manager
- **测试**：XCTest + 可能加 ViewInspector

## 代码规范

_（随首个 PR 沉淀）_

- Swift API Design Guidelines
- SwiftLint（配置：`.swiftlint.yml`）
- swift-format（配置：`.swift-format`，使用 Xcode 工具链内置版本）
- 每个 feature 一个 module（考虑用 SPM 拆分）

## 常用操作

### 构建 / 运行（通过 XcodeBuildMCP）

XcodeBuildMCP 已接入 Codex MCP，项目配置在 `.xcodebuildmcp/config.yaml`。

当前仅启用：

- `simulator`
- `swift-package`
- `ui-automation`

规划阶段暂无 scheme / project 默认值。一旦 Xcode 项目生成，典型流程：

1. `session_set_defaults` 记住 project + scheme + simulator
2. `build_run_sim` 构建并在模拟器跑起来
3. `test_sim` 跑测试

### Git

- 主分支：`main`
- 功能分支：`feat/xxx`、`fix/xxx`
- commit message：短句 + 动词开头（`Add ...` / `Fix ...` / `Refactor ...`）

## 约定

- **禁止**：在没有对应 PRD 条目的情况下实现新功能 — 产品决策先行
- **禁止**：一次 commit 跨多个无关改动
- **鼓励**：每写一个新决策（例如"为什么选 TCA 而不是 MVVM"）就沉淀到 `~/Brain/wiki/projects/MeetPR/decisions/` 里
