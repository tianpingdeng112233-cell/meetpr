# MeetPR

力量举学员 + 教练双端 iOS app。

## 本仓库

iOS 代码仓库。单一 Xcode 工程（`MeetPR.xcodeproj`）+ `Modules/` 下 SPM 多模块（AppShell / CoachKit / CoreModels / DesignSystem / Networking / RepositoryContracts / StudentKit）。app-target 代码在 `MeetPR/`，测试在 `MeetPRTests/` 与各 `Modules/<X>/Tests/`。

**已上 TestFlight 内测**（App id 6783772277）。日常发版流程与发布史另见仓库根 `RELEASES.md`（发布史）/ `NEXT-RELEASE.md`（进行中版本）——⚠️ 这两个文件随 PR #197 进 main，在 #197 合并前本仓库根尚无此二文件，故此处不加链接。

## 本地开发前置

第一次克隆下来要跑一遍:

```bash
brew install pre-commit swiftlint
pre-commit install
```

- `pre-commit`:commit 前自动跑 hook(yaml 校验、去尾空格、swift-format、swiftlint)
- `swiftlint`:Swift 静态检查
- `swift-format`:已随 Xcode 工具链提供,无需单独装

## 相关

- 知识库 / 产品文档（统一入口）：`~/Brain/wiki/projects/MeetPR/index.md`
  - PRD: `~/Brain/wiki/projects/MeetPR/prd.md`
  - 团队治理: `~/Brain/wiki/projects/MeetPR/team-governance.md`
  - 技术 ADR: `~/Brain/wiki/projects/MeetPR/decisions/`
  - 产品 PD: `~/Brain/wiki/projects/MeetPR/product-decisions/`
- 工程上下文：[CLAUDE.md](./CLAUDE.md)
- Codex 规范：[AGENTS.md](./AGENTS.md)

> **2026-04-25 重构**：所有非代码 markdown 已统一进入 Brain Obsidian vault。之前 `~/Documents/AppDev/prds/MeetPR/` 已废弃。
