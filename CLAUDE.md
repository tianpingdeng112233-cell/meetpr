# MeetPR — iOS 工程上下文

力量举学员 + 教练双端 iOS app。这个目录是代码仓库。读这个文件你就知道是在什么项目里、遵守什么规则。

## 🚨 Session 启动必读顺序

**每次新开 session,按顺序做**:

1. 读本文件(CLAUDE.md)
2. 读 [FOLLOWUPS.md](./FOLLOWUPS.md) — **逐条检查触发条件**,满足的主动提醒用户
3. 读 [AGENTS.md](./AGENTS.md)(Codex 视角,但你也要知道边界)
4. 扫 `git log --oneline -10` 了解最近进展

跳过第 2 步 = FOLLOWUPS 变黑洞。

## ⚠️ Recent design changes (2026-04-28)

Coach planning 4 周宏观视图设计经历重大 pivot。**任何后续 coach planning 相关 spec 必须按新方向写**：

- iPhone 7b = **周卡片横滑** (`TabView(.page)`，4 张卡片 W1↔W2↔W3↔W4)，**不是** v4.3 设计的 4 周扫视态
- iPhone 7c = **学员历史 cycle 列表入口**（数据回查），**不是** drill-down 编辑态
- iPhone **不做** 4 周宏观视图、跨 cycle 视觉对比、多学员 dashboard——全部在网页端
- **网页端教练后台**（V1.x defer，[PD-007](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md)）承担所有宏观能力，hard gate 在 lifecycle Stage 4 Week 22-24

**权威源**（按这个顺序读）：
1. `~/Brain/wiki/projects/MeetPR/coach-planning.md` §7b/7c/7d **v4.4**
2. `~/Brain/wiki/projects/MeetPR/decisions/006-macro-aggregation-api.md`（iPhone 不再消费 macro endpoint，但 API 设计仍 valid）
3. `~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md`（pivot 完整记录 + 7 议题处置表）

**已废弃**（不要参考）：
- v4.3 §7b 4 周扫视态设计（波形 + 变式矩阵 + 密度条）
- v4.2 §7b Excel grid 仅作为 web V1.0 layout reference 保留，**不是** iPhone 实装目标

**对昨天 (2026-04-27) 已合并代码的影响**：零冲突。bootstrap (#14) / CoreModels identity (#17) / DesignSystem 14 atomic 组件 (#18) 全部基础设施级，与 coach planning UI 无交集。可放心继续基于这些写下游 spec。

## 项目阶段

**Stage 2 Engineering Build 进行中**(详见 [[lifecycle-stages|lifecycle-stages.md]] §3,Week 0-12)。foundation 全就位:

- **6 个 SPM module 落地**:AppShell / CoachKit / CoreModels / DesignSystem / Networking / StudentKit
- **CoreModels Phase 1**:identity + onboarding domain types(User / CoachProfile / StudentProfile / InviteCode / BindRequest + 10 enums)
- **DesignSystem foundation**:5 token(Typography / Motion / Spacing / Radius / Colors)+ 14 atomic 组件(Button×4 / Card×2 / Badge×2 / Input×3 / Label×2 / List×1)
- **Backend scaffold**:Node.js + auth spec 进行中(backend repo PR #1 OPEN)
- **核心 ADR 落地**:[ADR-003](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md) 双端架构 / [ADR-004](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md) 后端选型 / [ADR-005](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) iOS 架构 / [ADR-006](~/Brain/wiki/projects/MeetPR/decisions/006-macro-aggregation-api.md) macro 聚合 API(2026-04-28)

**已合并 spec**:[001 bootstrap](./specs/001-bootstrap) / [002 CoreModels identity](./specs/002-core-models-identity) / [003 design system foundation](./specs/003-design-system-foundation)。

**当前阻塞**:coach planning UI 的实装 spec 还没起——PRD §5 P0 教练端 + §4 使用场景需要按 [v4.4 pivot](#%EF%B8%8F-recent-design-changes-2026-04-28) 同步更新后,才能向 spec 004+ 拆解。

## 下一步(给新 session 的入口)

**明确的下一轮工作**,按顺序:

1. **Backend spec 001-auth review + merge**(repo `MeetPR-backend` PR #1 OPEN)
   阻塞 backend 后续 spec 的起步。Claude review → 通过 merge / 不通过写 REVIEW.md

2. **PRD coach planning 章节按 v4.4 同步**
   `coach-planning.md` Step 1-9 现在 v4.4(2026-04-28 pivot 后),但 PRD §5 P0 教练端 + §4 使用场景 1-2 描述仍是旧版。建议从最痛的开始:
   - §4 场景 1(教练周日晚排计划)→ 改成"周卡片横滑 + 单周编辑"叙事
   - §5 P0 教练端 → 删除"4 周宏观预览"条目,改为"周卡片横滑 + 学员历史 cycle 列表"

3. **写第一组 coach planning 实装 spec**(预计 spec 004 起步)
   依赖:#2 完成 + coach-planning.md Step 1-3 单步细节确认
   建议拆分:
   - spec 004 = Step 0-2 教练首页 / 选学员 / 选计划长度
   - spec 005 = Step 3-4 选主项 + 添加辅助动作(三标签 facets)
   - spec 006 = Step 5-7 W1 强度填写 / 规则配置 / 周卡片横滑预览
   - spec 007 = Step 8-9 发布 + 模板保存
   - **必读** [F-015](./FOLLOWUPS.md)——任何 coach planning spec 必须按 v4.4 写,不要参考已废弃的 v4.3 4 周扫视态

4. **网页端教练后台 spec**(独立工作流,Stage 4 Week 22-24 hard gate)
   不阻塞 iPhone spec,但需在 Stage 4 中段前 ship。框架选型(Next.js / SvelteKit)需先开 ADR-007。

**不要跳过 1/2 直接做 3**:没 spec 输入的实装 = 凭感觉编码,违反 AGENTS.md 第一条。

## 角色

你在这个目录里扮演 **iOS 工程师**：
- 写 Swift / SwiftUI 代码
- 运行/修复构建（通过 XcodeBuildMCP）
- 写测试、跑测试
- 调试、重构、review 代码

**不在这里做**：
- ❌ 写 PRD、做产品决策 → 去 `~/Brain/wiki/projects/MeetPR/`
- ❌ 整理领域知识、竞品研究 → 去 `~/Brain/sources/` + `~/Brain/wiki/projects/MeetPR/`

## 关联资产

- **统一入口**：`~/Brain/wiki/projects/MeetPR/index.md` — Brain Obsidian vault 内 MeetPR 主页
  - PRD: `~/Brain/wiki/projects/MeetPR/prd.md`
  - 团队治理: `~/Brain/wiki/projects/MeetPR/team-governance.md`
  - 技术 ADR: `~/Brain/wiki/projects/MeetPR/decisions/`
  - 产品 PD: `~/Brain/wiki/projects/MeetPR/product-decisions/`
  - 用户研究 / 竞品 / 领域: `~/Brain/wiki/projects/MeetPR/{user-research.md,competitors/,domain/}`
- **全局知识**：`~/Brain/wiki/ios/`（SwiftUI 模式、Apple 平台踩坑）

> 2026-04-25 重构：所有 MeetPR 非代码 markdown 已统一进 Brain vault。原 `~/Documents/AppDev/prds/MeetPR/` 已废弃。

写代码前遇到不确定的决策，先查这三个地方。没写过的决策就回 ① 规划 session 讨论，不要擅自定调。

## 技术栈

- **平台**：iOS 17+
- **UI 框架**：SwiftUI
- **架构**：MVVM + Repository(per [ADR-005](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md));ViewModel 用 `@Observable`(Swift 5.9+ macro,普通 class 属性变化自动驱动 SwiftUI view 重绘)
- **数据层**:**默认**走 Repository → backend HTTP API(`Networking` module);**唯一例外**:CoachKit 编排器的 in-progress 计划草稿用 SwiftData 本地持久化(per [ADR-009](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md)),app 杀掉后能恢复;**仅限 `Modules/CoachKit/Sources/CoachKit/Planning/Drafts/` 子目录**,AppShell 等其他 module 严禁引 SwiftData
- **后端**:自建 Node.js + Aliyun(RDS PostgreSQL),不走 Supabase / Firebase(per [ADR-004](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md))
- **包管理**：Swift Package Manager
- **测试**：Swift Testing(`@Test` / `#expect` 语法,Xcode 16+ 苹果新测试框架,替代 XCTest)+ ViewInspector(开源库,在单元测试里渲染 SwiftUI view 并 assert 子节点,按需加)

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
