# 卡 I2 · 095 iOS：解 PR #382 冲突 + 资料向导缩成 4 步 + 待接收页修正

先读仓根 `CONTEXT.md`，再读同目录 `AMEND-wizard-trim.md`（本卡正典：共识、存量照护、验收第 10–16 条、Out of Scope 以它为准），必要时参考 `SPEC.md`。工作目录 `MeetPR-wt-095`，分支 `feat/095-ui`（PR #382 → `release/1.0`）。

## 第 0 步：解冲突（先做，单独验证）
Opus 已在本树开始 `git merge origin/release/1.0`（未提交），唯一冲突文件是 `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`。两边的 key 都保留，按现有排序规则合并，并确认 `Localizable.xcstrings` 自动合并后 key 与 `StudentStrings` 一一对应。不要运行 git 写命令（commit、merge --continue 等由 Opus 来做）。解完后先跑 StudentKit 测试 + 主工程 build，结果写进 JOURNAL，再进入下面的改动。

## 目标
1. 资料向导只留原第 1、2、3、7 步（新序号 1–4），原第 4「训练环境」（`Step4EnvironmentSection`）、第 5「恢复能力」（`Step5RecoverySection`）、第 6「训练资料」（`Step6MaterialsSection`）从向导移除；进度/步数显示跟着变。保留步骤的字段、校验、文案逐字不变。
2. 「我的资料」（`ProfileCardsSection`、`MyProfileV3Presentation`、`OnboardingSummaryFormatter`）不再显示这三块的编辑入口和摘要。
3. 旧草稿续填（`LocalOnboardingDraftStore` / `OnboardingWizardViewModel`）：落在新 4 步里正确的位置；草稿里被移除步骤的值不再上传，也不清空服务端已有的值。
4. 待接收页三处修正（`Features/Bind/PendingBindView.swift` / `PendingBindViewModel.swift`）：右上「登出」不压标题（iPhone 17e 验）；副标题拼名（名为空→「等待教练接收」，名已含「教练」→不再追加，其余照旧；英文同理）；`student.pendingBindView.copy011`「onboarding 完整资料」→「基础资料」/「Basic profile」，繁体按 spec 094 的生成流程与覆写表出。
5. 教练端只核查不改功能：新学员这三块为空时，CoachKit 的绑定请求卡、`StudentOnboardingProfileView`、`StudentProfileSection`、`CoachOnboardingDisplay`、排计划 `PlanningIntent.equipmentFilter` 不崩、不把空值显示成 0 或默认档次；不符合时只允许改成「未填」或隐藏该行，跟该页现有空值惯例一致。

## 约束
- 不动后端（卡 B2 另一个 worktree 在做）；demo / 内存仓库按 12 项必填模拟。
- 不删 CoreModels / DTO 字段（保留、可为空）。
- 不改 tab 结构，不加依赖，不碰 095 已做好的欢迎页、首页卡、通知权限逻辑。
- 旧概念残留扫描（AMEND 验收第 15 条）：全仓 grep「训练环境」「恢复能力」「训练资料」「器械」「睡眠」「7 步」「of 7」「onboarding 完整资料」，学员端可达的清掉，结果逐条写进 JOURNAL（可达 / 不可达 / 教练端保留）。
- 模拟器只用 `iPhone 17e`。
- 不 commit、不 push。

## 验收
`AMEND-wizard-trim.md` 验收第 10–15 条中 iOS 适用的全部条目，外加 `SPEC.md` 第 5 条（老学员升级第一屏）。你负责：单测先红后绿 + 九包测试与主工程 build 绿 + swift-format / SwiftLint 干净 + iPhone 17e 上走第 10、11、13、14 条并截图，存 `docs/evidence/spec095-trim-2026-11-02/`。

## 测试 seam
- `OnboardingWizardViewModel` 测试：步数、续填（含旧草稿）、提交字段不含移除步骤。
- `MyProfileV3Presentation` / `ProfileCardsSection` 相关测试：三块不出现。
- `PendingBindViewModel` 测试：三种拼名、「基础资料」。

## 交付
JOURNAL 写 `docs/journal/2026-11-02-095-I2.md`。回报：冲突解法、改动文件、测试数字、截图路径、残留扫描结果、与 AMEND 不符或做不到的地方。
