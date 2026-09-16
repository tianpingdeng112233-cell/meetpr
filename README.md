# MeetPR

力量举学员 + 教练双端 iOS app。

## 本仓库

iOS 17+、SwiftUI 与 Swift Package Manager 工程。App 入口在 `MeetPR/`，业务与共享模块在 `Modules/`，Xcode 项目为 [`MeetPR.xcodeproj`](MeetPR.xcodeproj)。

共享 scheme 包括 `MeetPR`、`MeetPR-Global`、`MeetPR-Demo` 和 `MeetPR-DemoStudent`。构建、测试和模拟器运行使用已安装的 XcodeBuildMCP skill；选择目标工作树、scheme 与对应 configuration 后运行。Demo 用于界面演示，联网和持久化验证使用正式配置。

发版线为 `release/1.0`，任务工作树可以位于基于它的独立分支。已发版本见 [RELEASES.md](RELEASES.md)，候选及跨端依赖见 [NEXT-RELEASE.md](NEXT-RELEASE.md)。Archive/Upload 由 David 完成。

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

> **2026-04-25 重构**：产品与领域正典迁入 Brain Obsidian vault，工程规范、spec 和发布账本留在本仓。之前 `~/Documents/AppDev/prds/MeetPR/` 已废弃。
