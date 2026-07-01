# MeetPR — iOS 工程上下文

力量举学员 + 教练双端 iOS app。这个目录是代码仓库。读这个文件你就知道是在什么项目里、遵守什么规则。

## 🚨 Session 启动必读顺序

**每次新开 session,按顺序做**:

1. 读本文件(CLAUDE.md)
2. 读 [FOLLOWUPS.md](./FOLLOWUPS.md) — **逐条检查触发条件**,满足的主动提醒用户
3. 读 [AGENTS.md](./AGENTS.md)(Codex 视角,但你也要知道边界)
4. 扫 `git log --oneline -10` 了解最近进展

跳过第 2 步 = FOLLOWUPS 变黑洞。

## 项目阶段(2026-07 · TestFlight 内测中)

**双端 app 已实装并上 TestFlight 内测。** 学员端 + 教练端全套功能落地,backend 在阿里云 SAE 运行,1.0 系列 build 持续迭代。旧的 V0 节奏(「教练 demo only、不接 backend、不开学员端」)已完全走完 —— **别再按它裁剪 spec**。

- **发布状态**:1.0(5) 已 archive + 上传 App Store Connect,待内测组生效([PR #197](https://github.com/tianpingdeng112233-cell/meetpr/pull/197));1.0(6) 在备。App id `6783772277`,内测组 **Neice**(内部组免审)/ **Ceshi**(外部组需审)。发布史见 ship 分支 [RELEASES.md](./RELEASES.md),进行中版本见 [NEXT-RELEASE.md](./NEXT-RELEASE.md)。
- **已实装(两端全套)**:
  - **学员端**:仪表盘 / 锻炼周月日历 / 进度中心 / 逐组记录(弹窗录入 + 杠铃配重图)/ e1RM 成长曲线 / 训练视频反馈(spec 034-039、042)
  - **教练端**:分诊 strip + 规划工作区(spec 037/038)/ 训练视频反馈 inbox(042)/ 卧推配重计算器 / 每组休息计时(040)/ 失败·未完成组记录(039)/ Excel 存量计划导入(043)
  - 全 UI 按设计包 **1:1 重做**(#180),系统中文动作名(#198)
- **backend**:auth + 教练规划 CRUD + spec 043 导入 + analytics 数据层,跑在阿里云 SAE staging(**非 frozen**,随 iOS spec 演进;当前固定入口 `http://121.40.160.241:3000`,TLS/域名收敛见 backend `FOLLOWUPS.md`)
- **核心 ADR**:双端架构 / 后端选型 / iOS 架构 / macro API / 网页框架 / SwiftData 例外 —— 全在 `~/Brain/wiki/projects/MeetPR/decisions/`

> **发版铁律**:archive + 上传 App Store Connect 始终 **David 手动**,从含改动的 **ship worktree** 出包(build 号 `CURRENT_PROJECT_VERSION` 必须严格递增,否则 Apple 拒)。别从落后 `origin/main` 的 worktree 打包。每完成一个改动主动问 David 要不要进下一个内测包。

## iPhone vs 网页端边界(仍有效的架构约束)

- iPhone **不做** 4 周宏观视图、跨 cycle 视觉对比、多学员 dashboard —— 这些全在网页端教练后台([PD-007](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md),V1.x defer,hard gate 在后期)
- iPhone 侧聚焦单学员规划(周卡片横滑 + 历史 cycle 回查)+ 执行;教练宏观分析能力 defer 到网页端
- 完整设计 pivot 记录见 `~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md`

### 仍在 defer(动工前先回规划 session 确认,别擅自开)

- **网页端教练宏观后台**:PD-007,后期 hard gate
- **教练驾驶舱净增量**:V0.2 defer(今日分诊 + 聪明信号 + 助理层),权威在 wiki `coach-cockpit.md`(教练地板 + 今日 tab 已 ship,别重做)
- **meetcard 新功能**:V1 已 ship xty,post-V1 仅修 P0 bug

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

项目已就位(scheme `MeetPR`;另有 `Demo` configuration 带 `-D DEMO_MODE`,跑 Demo build 时 XcodeBuildMCP 必须**显式** `configuration=Demo`,否则默认 Debug 无 DEMO_MODE 会撞真 backend)。典型流程：

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

## PR Codex review pass(Claude 写的任何 PR merge 前必经 Codex 互审)

**触发**: 任何 PR(doc 或 code,`specs/NN/SPEC.md` / ADR / `CLAUDE.md` / `AGENTS.md` / `FOLLOWUPS.md` / README / 其他 `*.md` / `*.swift` / `Package.swift` / `*.json` / `*.py` / `project.pbxproj` 等)由 Claude 起草后,**开 PR 前必须先经 `/review-loop` 本地 Codex 互审收敛**(这就是真 gate);loop 收敛后 PR 级 Codex review pass **默认免跑**(见下方程序第 4 步)。

> **背景**:CLAUDE.md §角色 已规定 Claude 写 Swift 代码(过去 default 走 Codex,Codex 限额触顶 Claude 接管 code 实装)。无论谁写,另一方必 review = 双向 second-pair-of-eyes。本节定义 Claude 写 → Codex review 这一向;反向(Codex 写 → Claude review)是既有流程,无需新规则。

**Claude 的程序**(开任意 PR 时):
1. **开 PR 前先跑 `/review-loop`**(这是真 gate):对工作区未提交改动发起本地 Claude↔Codex 多轮互审 + 对质,收敛(`VERDICT: CLEAN` 且无悬而未决分歧)后才开 PR。Claude 通过 `codex exec`(read-only)发起,Codex 审未提交 diff 按输出契约逐条回 finding(BLOCKER 用 `## ⚠️ BLOCKER` 起头、末行 `VERDICT: CLEAN|BLOCKERS`),Claude 逐条处置(认同就在工作区改 / BLOCKER 分歧进对质,Codex 回 `CONCEDE|HOLD` / nit 不认同记 transcript 一行理由);最多 3 轮,谈不拢用 AskUserQuestion 升级 David 裁决。**全程 Codex read-only,只有 Claude 改文件**,零手动 paste。完整循环与命令契约见 [`review-loop` skill](~/ClaudeConfig/skills/review-loop/SKILL.md)(机制权威以它为准);设计决策见 [design doc](~/ClaudeConfig/docs/specs/2026-05-22-claude-codex-review-loop-design.md)(设计期文档,其中 `codex review --uncommitted` 等命令细节已被实现期 findings 取代)。
2. **开一个干净 PR**(同既有流程,用 enforce_admins 套路 / 普通 push):草稿已本地洗过,PR 只含收敛后的最终改动。
3. **PR body 附「Pre-PR review loop 摘要」**:总轮数 / blocker 找到+解决数 / David 裁决记录 + 全文 transcript 链接(`~/Brain/wiki/projects/MeetPR/reviews/YYYY-MM-DD-<topic>.md`)。
4. **PR 级 Codex review pass = 可选(`/review-loop` 收敛后默认免跑)**:`/review-loop` 已是真 gate——它对**进 PR 的同一份代码**审到了 `VERDICT: CLEAN`(过程中还复跑测试 + build),PR 级再让同一个 Codex 审一遍同样的代码是冗余的纸面 gate。所以 **loop 收敛 `VERDICT: CLEAN` 且收敛后无语义改动时,PR 级 gate 免跑**(收敛后只有 swift-format / lint 自动修、commit message 这类**非语义**变更不算改动);loop 的 transcript 链接即审查留痕,直接进合并流程。
   - **仍必须跑 PR 级 gate 的情况**:① `/review-loop` 没跑(走了下方 §例外 的免 loop 情形);② 收敛后 PR 里有**语义改动**(改了逻辑 / 接口 / 行为,非纯排版)——这部分没被 loop 审过;③ 想在 GitHub PR 上额外留一条 Codex review comment 作审计。
   - 跑的话仍按既有流程:`gh pr review --comment`(same-account 下 `--approve` / `--request-changes` 被 GitHub 拒,详见 §例外 与 [`AGENTS.md` §PR review pass](./AGENTS.md));报 blocker 则 Claude 在 PR 内修,该修复属 finding 内容**必须再过一次 gate**;只有纯 typo / metadata / commit message / 不动 body 的小修按 §例外 免 re-review。

**review 重点 by PR 类型**:

| PR 类型 | 让 Codex 找的 |
|---|---|
| **Doc / spec / ADR / *.md** | factual errors / scope ambiguity / 缺细节 / contradictions / unsafe assumptions |
| **Code(*.swift / Package.swift / config)** | 上面 + Swift API Design Guidelines / 现有 codebase 风格契合度 / Sendable + Actor 隔离 / force unwrap / type 错误 / 测试覆盖洞 / `swift test` + `xcodebuild` 是否能跑(快速 sanity) |
| **JSON / fixture(数据)** | schema 跟 Codable model 对齐 / row count / id namespace 不冲突 / encode round-trip |
| **`project.pbxproj` / build config** | INFOPLIST_KEY 是否 dead / signing setup / scheme 一致 |

**为什么这条规则**:
2026-05-13 加。spec 022 由 Claude 写,Codex impl 时 catch 到事实错误(catalog 总条数 SPEC 写 436 实际 xlsx 是 435)+ 补 PlanningDisplay 中文映射(SPEC 漏)。**前置 Codex review 能 catch 这类问题,省一次 amendment cycle**。同日扩 Claude 也写 code(Codex 限额 fallback)— 同样需要双向 review。规则本身经 Codex review(meta:PR #53)采纳了 3 个 wording fix(same-account `--approve` 限制 / re-review 触发 / 跟 CHALLENGE 边界)。

**例外**(免 Codex review):
- 修字符 typo / 链接 dead URL / 单纯 frontmatter 字段填值(无语义改动)
- 已经经 Codex review 过的 PR 的**小修** follow-up commit(force-push 同 PR 内 + 改的不是 finding 内容)
- 紧急 hotfix(Apple 审核拒回 / production blocker / CI red 阻塞)— merge 后补 review
- 由 Codex 起草的 PR(它写它自己 review 不算 second-pair;Claude 接管 review,这是既有流程)

**跟 CHALLENGE.md 的边界**(per Codex review PR #53 finding P2a):
- **PR review pass**(本节)= pre-merge tactical 反馈,可在 PR 内 amend 解决(factual / scope / 缺细节)
- **CHALLENGE.md**(详 [`AGENTS.md` §文档质疑权](./AGENTS.md))= strategic 反对,需要重 spec / 重 ADR(SPEC 设计本身 fundamental 错 / 接口不可实现 / 跟 ADR 反向)
- 简单判断:同 PR amend 能解决就走 review pass;不能就 CHALLENGE

详细 Codex 端职责见 [`AGENTS.md` §PR review pass](./AGENTS.md)。
