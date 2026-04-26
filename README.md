# MeetPR

力量举学员 + 教练双端 iOS app。

## 本仓库

代码仓库。规划阶段，暂无 Xcode 项目。

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
