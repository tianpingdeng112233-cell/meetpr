# MeetPR — iOS 工程上下文

力量举学员 + 教练双端 iOS app。这个目录是代码仓库。读这个文件你就知道是在什么项目里、遵守什么规则。

## ⛔ 发版路标(2026-07-10 拍板,凡涉发包先读这段)

- **发版线 = `release/1.0`**(1.0(7) 基底小步直推),worktree 在 `~/Projects/apps/MeetPR-release`;
  规则权威 = 该分支 `AGENTS.md` §发版直推流(P0–P2 尺/捞回队列/失效保护)。
- **main 不是发版线**:严禁在 main 打 `beta/*` tag、切包、跑 prep-beta。`beta/1.0-8` 已打在
  release/1.0(build 8 已占用)。main = 下个大包的**待分诊库存**(coached 学员端形态正典 = 1.0(7),
  main 的形态批次被否;已批准项按捞回队列在 7 基底重做,不 cherry-pick)。
- 本文件下方的 V0 时代内容(deadline/冻结清单等)多数已过时,待 neat-freak 整体重写;
  与本路标或 release 线 AGENTS.md 冲突时,以后者为准。

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

**Stage 2 Engineering Build 进行中**(详见 [[lifecycle-stages|lifecycle-stages.md]] §3,Week 0-12)。

### 🎯 V0 TestFlight north star — hard deadline **2026-06-20** / soft target **2026-05-20**

- **Hard 6/20**:真 ship deadline,40 天 buffer 不变,W23-25 release engineering 周表是这条路径的节奏(详见下表)
- **Soft 5/20**(2026-05-11 加):内部努力把 W23-25 压到 9 天加速窗口里跑完;Apple 审核 24-48h~7d 不可控,达不到则回 hard deadline 节奏,**不是 ship gate**

**所有 spec 决策按"是否在 V0 路径上"裁剪。** V0 路径 = `启动 → 登录 → 教练规划 Step 0-7(周卡片横滑) → 本机 DraftStore 保存`,**不接 backend,不开学员端**。详见 [[~/Brain/wiki/projects/MeetPR/roadmap|roadmap.md]]。

### 当前完成态(2026-05-13)

- **8 SPM module + 14 atomic 组件** foundation 就位
- **已完整实装 + 合并 spec**(12 个):
  - [001 bootstrap](./specs/001-bootstrap) / [002 CoreModels identity](./specs/002-core-models-identity) / [003 design system](./specs/003-design-system-foundation) / [004 training plan domain](./specs/004-core-models-training-plan)
  - [005 coach planning step 0-3](./specs/005-coach-planning-step-0-3) / [006 step 4 accessories](./specs/006-coach-planning-step-4-accessories) / [**007 step 5-7 week-card-swipe**](./specs/007-coach-planning-step-5-7-week-card-swipe) — coach 规划 UI **0-7 步全可点**(close-out 2026-05-10,impl PR #37)
  - [011 auth UI flow](./specs/011-auth-ui-flow) — 登录 / 注册 / role-routed root
  - [**020 V0 demo orchestration**](./specs/020-v0-demo-orchestration) — SPEC + impl 全合 main 2026-05-10(spec PR #39 + impl PR #41);DemoAuthRepository / DemoTokenStore / DEMO_MODE build config 全就位
  - [**021 Apple readiness assets + signing**](./specs/021-apple-readiness-assets-and-signing) — AppIcon / LaunchScreen / PrivacyInfo.xcprivacy / signing build settings / archive 前置物就位
  - [**022 exercise library v2 import**](./specs/022-exercise-library-v2-import) — 动作库 v2 catalog 已导入(435 imported + 3 synthetic = 438),CoachKit bundle resource + enum schema 已同步
  - [**023 planning numeric input**](./specs/023-planning-numeric-input) — Step 5 内 4 处数字栏(组数/次数/次数上限/RPE)换为 `PlanningCountPicker` iOS 转盘 + inline 展开;Step 6 内 2 处(weekly increment / custom 周值)换为 `PlanningNumberField` `[-][TextField][+]` sandwich(impl PR #54)
- **Backend**: auth + coach planning CRUD 已合 staging(❄️ **FROZEN**,详见 [`MeetPR-backend/CLAUDE.md`](~/Projects/apps/MeetPR-backend/CLAUDE.md) 顶部 callout)
- **核心 ADR**(8 个):[ADR-003](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md) 双端架构 / [ADR-004](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md) 后端选型 / [ADR-005](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) iOS 架构 / [ADR-006](~/Brain/wiki/projects/MeetPR/decisions/006-macro-aggregation-api.md) macro API / [ADR-007](~/Brain/wiki/projects/MeetPR/decisions/007-web-framework-selection.md) 网页框架 / [ADR-009](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) SwiftData 例外

## 下一步(按 V0 roadmap 严格执行)

权威源:[[~/Brain/wiki/projects/MeetPR/roadmap|roadmap.md]] §V0 周计划。

| 周 | 关键路径 | Status |
|---|---|---|
| W20(5/11-5/17,提前 5/9-5/10 完成)| spec 007 implementation(W1 强度 + 周卡片横滑)| ✅ DONE(impl PR #37 + finalize PR #38)|
| W21(5/18-5/24,实际 5/10 起步并完成)| spec 020 V0 demo orchestration | ✅ DONE(spec PR #39 + impl PR #41,Demo build 启动直接 CoachRootView)|
| **W22**(5/25-5/31,提前 5/10 完成)| spec 021 Apple readiness assets + signing | ✅ DONE(AppIcon / LaunchScreen / PrivacyInfo / automatic signing / archive path ready) |
| W23-25(6/1-6/20)| Release engineering: archive export → App Store Connect upload → TestFlight → Apple 审核 → ship | ⏭ NEXT |

### ❄️ 硬冻结(本 session 不要尝试)

- ❌ **新 backend feature**:除非 iOS 有具体 spec 必须调某 endpoint。详见 [`MeetPR-backend/CLAUDE.md`](~/Projects/apps/MeetPR-backend/CLAUDE.md) 顶部
- ❌ **meetcard 新功能**:V1 已 ship xty,post-V1 仅修 P0 bug,等 iOS V0 ship 再启动。详见 `~/Projects/apps/meetcard/README.md` 顶部
- ❌ **网页端教练后台**:Stage 4 hard gate,V0 完全无关
- ❌ **学员端 view**:V0.1 起;V0 = 教练 demo only
- ❌ **不在 V0 路径上的 refactor / cleanup**:V0 ship 后再清
- ❌ **Apple Developer membership / Stage A-I release engineering**:User 2026-05-12 决策"还剩一周再开",自动提醒走 [F-026](./FOLLOWUPS.md);本 session 不要主动 propose Stage A 任何环节

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

## PR Codex review pass(Claude 写的代码类 PR merge 前必经 Codex 互审;纯文档免跑)

**触发(2026-07-27 收窄,范围权威 = [`review-loop` SKILL.md §何时跑](~/.claude/skills/review-loop/SKILL.md))**:**只有代码类产物**(`*.swift` / `Package.swift` / `*.ts` / `*.tsx` / `*.py` / `*.sql` 迁移 / 行为性 `*.json` / `project.pbxproj`)由 Claude 起草后,**开 PR 前必须先经 `/review-loop` 本地 Codex 互审收敛**(这就是真 gate);loop 收敛后 PR 级 Codex review pass **默认免跑**(见下方程序第 4 步)。**spec / ADR / `CLAUDE.md` / `AGENTS.md` / README / 其他纯文档一律免跑**——文档 = Claude 起草 + David 终审,不再烧互审轮次(2026-07-12 拍板 code-only,2026-07-27 明确文档全免)。

> **背景**:CLAUDE.md §角色 已规定 Claude 写 Swift 代码(过去 default 走 Codex,Codex 限额触顶 Claude 接管 code 实装)。无论谁写,另一方必 review = 双向 second-pair-of-eyes。本节定义 Claude 写 → Codex review 这一向;反向(Codex 写 → Claude review)是既有流程,无需新规则。

**Claude 的程序**(开任意 PR 时):
1. **开 PR 前先跑 `/review-loop`**(这是真 gate):对工作区未提交改动发起本地 Claude↔Codex 多轮互审 + 对质,收敛(`VERDICT: CLEAN` 且无悬而未决分歧)后才开 PR。Claude 通过 `codex exec`(read-only)发起,Codex 审未提交 diff 按输出契约逐条回 finding(BLOCKER 用 `## ⚠️ BLOCKER` 起头、末行 `VERDICT: CLEAN|BLOCKERS`),Claude 逐条处置(认同就在工作区改 / BLOCKER 分歧进对质,Codex 回 `CONCEDE|HOLD` / nit 不认同记 transcript 一行理由);最多 3 轮,谈不拢用 AskUserQuestion 升级 David 裁决。**全程 Codex read-only,只有 Claude 改文件**,零手动 paste。完整循环与命令契约见 [`review-loop` skill](~/ClaudeConfig/skills/review-loop/SKILL.md)(机制权威以它为准);设计决策见 [design doc](~/ClaudeConfig/docs/specs/2026-05-22-claude-codex-review-loop-design.md)(设计期文档,其中 `codex review --uncommitted` 等命令细节已被实现期 findings 取代)。
2. **开一个干净 PR**(同既有流程,用 enforce_admins 套路 / 普通 push):草稿已本地洗过,PR 只含收敛后的最终改动。
3. **PR body 附「Pre-PR review loop 摘要」**:总轮数 / blocker 找到+解决数 / David 裁决记录 + 全文 transcript 链接(`~/Brain/wiki/projects/MeetPR/reviews/YYYY-MM-DD-<topic>.md`)。
4. **PR 级 Codex review pass = 可选(`/review-loop` 收敛后默认免跑)**:`/review-loop` 已是真 gate——它对**进 PR 的同一份代码**审到了 `VERDICT: CLEAN`(过程中还复跑测试 + build),PR 级再让同一个 Codex 审一遍同样的代码是冗余的纸面 gate。所以 **loop 收敛 `VERDICT: CLEAN` 且收敛后无语义改动时,PR 级 gate 免跑**(收敛后只有 swift-format / lint 自动修、commit message 这类**非语义**变更不算改动);loop 的 transcript 链接即审查留痕,直接进合并流程。
   - **仍必须跑 PR 级 gate 的情况**:① **代码类改动**没跑 `/review-loop`(走了下方 §例外 的免 loop 情形;纯文档 PR 本就不触发,不算此项);② 收敛后 PR 里有**语义改动**(改了逻辑 / 接口 / 行为,非纯排版)——这部分没被 loop 审过;③ 想在 GitHub PR 上额外留一条 Codex review comment 作审计。
   - 跑的话仍按既有流程:`gh pr review --comment`(same-account 下 `--approve` / `--request-changes` 被 GitHub 拒,详见 §例外 与 [`AGENTS.md` §PR review pass](./AGENTS.md));报 blocker 则 Claude 在 PR 内修,该修复属 finding 内容**必须再过一次 gate**;只有纯 typo / metadata / commit message / 不动 body 的小修按 §例外 免 re-review。

**review 重点 by PR 类型**:

| PR 类型 | 让 Codex 找的 |
|---|---|
| **Doc / spec / ADR / *.md**(默认不触发,仅 David 显式点名要 Codex 审某份文档时) | factual errors / scope ambiguity / 缺细节 / contradictions / unsafe assumptions |
| **Code(*.swift / Package.swift / config)** | 上面 + Swift API Design Guidelines / 现有 codebase 风格契合度 / Sendable + Actor 隔离 / force unwrap / type 错误 / 测试覆盖洞 / `swift test` + `xcodebuild` 是否能跑(快速 sanity) |
| **JSON / fixture(数据)** | schema 跟 Codable model 对齐 / row count / id namespace 不冲突 / encode round-trip |
| **`project.pbxproj` / build config** | INFOPLIST_KEY 是否 dead / signing setup / scheme 一致 |

**为什么这条规则**:
2026-05-13 加。spec 022 由 Claude 写,Codex impl 时 catch 到事实错误(catalog 总条数 SPEC 写 436 实际 xlsx 是 435)+ 补 PlanningDisplay 中文映射(SPEC 漏)。**前置 Codex review 能 catch 这类问题,省一次 amendment cycle**。同日扩 Claude 也写 code(Codex 限额 fallback)— 同样需要双向 review。规则本身经 Codex review(meta:PR #53)采纳了 3 个 wording fix(same-account `--approve` 限制 / re-review 触发 / 跟 CHALLENGE 边界)。

2026-07-12 / 2026-07-27 两次收窄:先拍板「只有代码类产物跑 review-loop」,后明确 spec / ADR / 纯文档一律免跑(文档 = Claude 起草 + David 终审);触发范围权威落 [`review-loop` SKILL.md §何时跑](~/.claude/skills/review-loop/SKILL.md),本节与之冲突时以 SKILL.md 为准。

**例外**(免 Codex review):
- **spec / ADR / 纯文档类 PR**(2026-07-27 拍板,见上方触发;文档 = Claude 起草 + David 终审)
- 修字符 typo / 链接 dead URL / 单纯 frontmatter 字段填值(无语义改动)
- 已经经 Codex review 过的 PR 的**小修** follow-up commit(force-push 同 PR 内 + 改的不是 finding 内容)
- 紧急 hotfix(Apple 审核拒回 / production blocker / CI red 阻塞)— merge 后补 review
- 由 Codex 起草的 PR(它写它自己 review 不算 second-pair;Claude 接管 review,这是既有流程)

**跟 CHALLENGE.md 的边界**(per Codex review PR #53 finding P2a):
- **PR review pass**(本节)= pre-merge tactical 反馈,可在 PR 内 amend 解决(factual / scope / 缺细节)
- **CHALLENGE.md**(详 [`AGENTS.md` §文档质疑权](./AGENTS.md))= strategic 反对,需要重 spec / 重 ADR(SPEC 设计本身 fundamental 错 / 接口不可实现 / 跟 ADR 反向)
- 简单判断:同 PR amend 能解决就走 review pass;不能就 CHALLENGE

详细 Codex 端职责见 [`AGENTS.md` §PR review pass](./AGENTS.md)。
