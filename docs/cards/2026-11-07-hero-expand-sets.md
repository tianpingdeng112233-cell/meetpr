# 卡：今日训练 hero 动作行可点开看逐组（iOS）

先读仓根 CONTEXT.md（有则读）与 CLAUDE.md。工作目录 = 本 worktree `/Users/david/Projects/apps/MeetPR-wt-hero-expand`（分支 `feat/hero-expand-sets`，基于 `origin/release/1.0`）。级别 T1。模拟器只用 `iPhone 17e`。

## 现状
开练前的今日训练 hero（`TodayWorkoutScreen.swift` 里的 `TodayWorkoutActionSummary` / `TodayWorkoutActionSummaryRow`，`TrainingDayPreview.swift` 也复用）每个动作一行，只给一句摘要：
- 新式处方且各组一致 →「140kg × 3 @RPE8 · 5 组」；各组不一致 → 只剩「N 组」，看不到任何重量；
- 旧式处方（pre-072）→ 只拿 `rows.first` 显示第一组重量×次数×组数，后面组的重量被吞。
行本身不可点。

## 目标
动作行做成和完成后回顾卡（`CompletedDayOverviewCard.swift` 的 `CompletedDayExerciseRow`）一样：点一下展开逐组、再点收起。
- 收起态：保持现有摘要文案不变，右侧加与回顾卡同款 chevron（`chevron.right` / `chevron.down`），默认全部收起；展开状态是视图内 `@State`，不持久化。
- 展开态：在行内下方逐组列出**处方组**（`prescribedRows`，不含 extra / 学员自加组），每行「组号 + 该组处方」。组号用现有显示组号口径（与训练中一致）；处方文本新式用 `StudentFormatting.prescribed(_:percentageOutcome:)` 逐组渲染（百分比组带解算出的重量），旧式用该组 record 的重量 kg × 次数（无重量显示「—」）。
- 字号/颜色/间距/点击区/无障碍（accessibilityValue 展开/收起、minHeight 命中区）照抄 `CompletedDayExerciseRow`；不带视频按钮。
- `TrainingDayPreview` 里复用的同一行一起获得此行为。

## 不做（Out of Scope）
不改回顾卡、训练中记录流、教练端、后端；不新增或改动文案 key（组号与处方复用现有字符串）；不改摘要逻辑本身。

## 测试 seam（先红后绿）
1. Presentation 层：在 `TodayWorkoutPresentation.Exercise` 上加一个产出逐组行（组号 + 文本）的计算属性，在 `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/` 新增 Swift Testing 用例：各组不一致的新式处方逐组出不同重量；旧式处方第 2 组以后的重量也出现；extra/学员自加组不出现；百分比组带解算重量。
2. 视图层若仓里已有 ViewInspector 先例就补一条「点击行后出现逐组行」，没有就不新引依赖。

## 验收
- 上面的新测试先红后绿；StudentKit 全量测试绿；`iPhone 17e` 上 app 编译通过。
- 模拟器截图两张放 `docs/evidence/2026-11-07-hero-expand/`：收起态、展开一个各组重量不同的动作。
- JOURNAL 写 `docs/journal/2026-11-07-hero-expand-ios.md`（改了哪些文件、测试命令与结果、截图路径、遗留）。
- 不 commit、不 push、不开 PR（Opus 收货时做）。
