# 034 — 锻炼 tab 重设计(周/月日历 + JAI 卡片执行 + Last/Best)

- **状态**:Ready
- **PR**:TBD
- **来源**:[[student-experience-redesign-wave]](~/Brain/wiki/projects/MeetPR/student-experience-redesign-wave.md) — David 2026-06-14 dogfooding "锻炼 tab 太简陋";单日训练界面照 Juggernaut AI,日历照 My Strength Book。
- **上游**:
  - spec 024 + 030:`TodayWorkoutView` / `TodayWorkoutViewModel` / `ExerciseExecutionView` / `SetEntrySheet` / `PlateMathSheet` / `RestTimerOverlay` / `SlideToCompleteButton` / `SessionSummaryView` / `PRBanner` / `ReadinessCheckinViewModel` 现结构(全部复用)
  - `StudentPlanRepository.fetchCycleDays` / `fetchDay`;`StudentTrainingLogRepository.fetchLogsForExercise`
  - ADR-001:不算分、不自动调计划

## 目标

把学员「锻炼」tab 从"只能看今天单页"升级为 **MSB 式日历导航 + JAI 式逐组执行**:顶部默认展示最近一周、可展开整月;选任意训练日 → 该日 JAI 卡片(阶段/周/天头 + 逐动作卡 + 每组 重量/次数/RPE + **Last/Best 参考**);执行件全部复用现有。

落地后学员看到啥:

```
[ 锻炼 tab ]
  顶部:6月 ▾   [一15][二16][(三17)][四18][五19][六20][日21]   ← 默认本周条,训练日下方标红点
        ↳ tap "月"→ 展开整月网格(训练日标点);tap 某天 → 切到那天
  ↓ 选中日(默认今天)
  阶段头:力量块 · 第2周 · 周三 · 深蹲日
  ┌─ 深蹲 (高杠) ────────────────┐
  │ 5 组 × 5 次 @ 80%             │
  │ 1  150kg   ✓ 150×5 @7         │
  │ 2  150kg   [记录]             │
  │    上次 5×145 · 最佳 5×152.5  │ ← 新增 Last/Best
  │ + 加组   ⚖配片  ✎备注  🎥视频 │
  └──────────────────────────────┘
  …(更多动作卡)
  [滑动完成今日训练]
  休息日 / 无计划日 → 现有 .rest 空态("今日休息")
```

## 范围

### 做什么

#### 1. 锻炼 tab 顶部日历(默认周 · 展开月)

新增 `TrainingCalendarView`(`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCalendarView.swift`):
- 数据源:`StudentPlanRepository.fetchCycleDays(studentID:)`(plan 全部天)+ 当前 logs(判完成态)。
- **默认态 = 周条**:最近一周 7 日(周一→周日,跟随 `Calendar.current.firstWeekday`),可左右翻周(`‹ ›`)。日格显示 星期 + 日号 + 完成点(红=未练有计划 / 绿=全完成 / 灰=无计划),复用 Dashboard `DayChip` 的点色逻辑(抽到共享或对齐)。
- **展开月**:顶部 `周/月` 分段;选"月"→ 整月网格(7 列),训练日标点,非本月/无计划日淡化。月可 `‹ ›` 翻月。
- **选中日**:tap 任一日 → 高亮 + 驱动下方加载该日。**今天默认选中**;切到没计划的天 → 下方走现有 `.rest` 空态(文案保持"今日休息";非今天可显示"这天休息")。
- 不做:在日历上编辑/移动/删除训练(MSB 的 workout action menu)——只读导航。

#### 2. `TodayWorkoutView` 日期从固定参数 → `@State selectedDate`

- 现 `date: Date`(init 固定)改为 `@State private var selectedDate: Date`(init 默认传入值或 `Date()`)。
- `TrainingCalendarView` 的选择 binding 改 `selectedDate`;`.onChange(of: selectedDate)` → `await viewModel.load(date: selectedDate, studentID:)`。
- readiness gate 规则不变(仅 `Calendar.isDateInToday(selectedDate)` 且非空计划才自动弹)。
- 导航标题:由"今天"改为"锻炼"(tab 名一致);阶段头承载日期信息。

#### 3. JAI 式阶段/周/天头

替换现 `header(for:)`(只有 星期+日月):
- 行 1:`{planKind 中文} · 第{weekIndex}周 · {星期}`(planKind/weekIndex 取自 `StudentPlanView`;ViewModel 需把 plan 的 `weekIndex`/`planKind`/`startDate` 透出,或 day 已含 week 信息 → 由 implementer 选最小改动路径,见技术要求)。
- 行 2(可选):该日主项概括(如"深蹲日",取该日第一个主项动作名;无则省略)。
- 训前 readiness 状态小徽标(已签到 ✓ / 未签到)就近显示(现 toolbar 心形图标保留亦可,二选一,implementer 对齐 mockup)。

#### 4. 每组 Last/Best 参考(新增,**零后端 · 真跨计划**)

每个**未记录**的组行下方显示一行 `上次 {reps}×{weight}kg · 最佳 {reps}×{weight}kg`(已记录组不显示,避免噪音):
- **数据源 = `E1RMRepository.fetchHistory(studentId:, exerciseId:)`(已存在、已持久化、TodayWorkoutView 已注入 e1rm repo)**。
  - `StudentSetLog` **只有 `planExerciseID`、无 catalog `exerciseID`**,且 spec 008 每周 materialize 独立 planExercise id → 按 planExerciseID 查历史几乎永远空,**不可用**。
  - `E1RMHistoryPoint` 带 catalog `exerciseId` + `sourceWeightKg` + `sourceReps` + `sourceRPE` + `computedAt`,正是 Last/Best 所需,且跨所有计划。**不新增任何 repo 方法、不动后端。**
- 当日每个 exercise 的 catalog id 取自 `day.exercises[].exercise.id`(`StudentPlanExercise.exercise.id`)。
- **Last** = `fetchHistory` 结果中 `computedAt` 最近(且不晚于今日开始)的一点 → 显示其 `sourceReps × sourceWeightKg`。
- **Best** = `fetchHistory` 结果中 `e1RMKg` 最大的一点 → 显示其 `sourceReps × sourceWeightKg`。
- 无历史点 → 不显示该行(不显示"暂无")。
- 计算放 `TodayWorkoutViewModel.load`:为当日每个 exercise 并发(TaskGroup)预取 `fetchHistory`,算好 `lastSet`/`bestSet` 存进 `[exerciseID(catalog): ExerciseReference]` map,UI 只读。**不在 view 里发请求。**

### 不做什么

- AI 评分(per-lift Daily Readiness Ratings 数字)、AI 自动调重/组间自动调整(ADR-001 红线)
- 自动热身(+Warmup auto-ramp)、动作交换(swap)、动作技术详情(info)——本 wave 砍
- 超级组/Combo 分组、10RM/RIR 处方模式
- 日历上编辑/移动/删除训练(只读导航)
- 训后小结难度评分(整个训后难度功能 = Wave B;本 spec 不碰小结)

## 技术要求

- 模块:全部 `Modules/StudentKit/`(纯视图/VM 改动,**不新增 repo 协议方法**)。
- `StudentPlanView` 透出:确认 `weekIndex`/`planKind`/`startDate` 可达(spec 008 publish 链路已建投影);ViewModel `load` 时一并持有以渲染阶段头。
- 日历选择**不重建 ViewModel**:复用同一 `TodayWorkoutViewModel.load(date:studentID:)`,切日 = 重新 load。
- Last/Best 每个 exercise 一次 `e1rm.fetchHistory`,`load` 内并发预取(TaskGroup),避免 N 次串行(对齐 plan 链路已知的跨境延迟教训:别在关键路径串行 N 请求)。
- 复用现有执行件,**不重写** SetEntry/PlateMath/RestTimer/PRBanner/SlideToComplete/SessionSummary/ExerciseExecutionView(仅在 ExerciseExecutionView 的组行下插 Last/Best 行,或在其 row 渲染处加)。
- SwiftLint:文件 ≤400 行(日历单独文件)、函数体 ≤50 行、参数 ≤5、`isEmpty`、无多尾随闭包。
- swift-format:push 前 docker `swift:6.1-jammy` 验。
- iOS 17+,纯 SwiftUI,`Color.MeetPR.*` / `MeetPRSpacing` token。

### Backend

- **零后端改动**。日历用 `fetchCycleDays`(已有);Last/Best 用 `E1RMRepository.fetchHistory`(已有);阶段头用 `StudentPlanView` 已投影的 `weekIndex`/`planKind`/`startDate`。全部走现有端点。

## 验收清单

- [ ] 锻炼 tab 顶部周条默认显示本周,今天高亮;训练日标点(完成态色正确)
- [ ] "月"切换 → 整月网格,训练日标点;翻周/翻月正常
- [ ] 选任意训练日 → 下方加载该日 JAI 卡片;选休息/无计划日 → 休息空态
- [ ] 阶段头显示 `{planKind} · 第N周 · 星期(· 主项日)`
- [ ] 未记录组行下显示 `上次 …· 最佳 …`;已记录组不显示;无历史不显示
- [ ] Last = e1rm history 最近一点;Best = e1rm history e1RM 最高点(单测覆盖从 [E1RMHistoryPoint] 选 last/best 的纯函数)
- [ ] 复用件全部照常工作:记录组(SetEntry)、配片、组间计时、PR 横幅、滑动完成、训后小结、readiness 自动弹(仅今日非空)
- [ ] Last/Best 取自 `E1RMRepository.fetchHistory`(零后端、零新 repo 方法);无历史不显示
- [ ] 切日不重建 VM、不串行 N 请求(TaskGroup 并发预取)
- [ ] SwiftLint/swift-format 双过;StudentKit 单测全绿
- [ ] 双 sim 手测:coach 发布多周计划 → student 锻炼 tab 周/月切换 + 选不同天 + 看 Last/Best + 记一组

## 风险 / implementer 关注

1. **Last/Best 必须走 `E1RMRepository.fetchHistory`(catalog 键、跨计划),不要用 `fetchLogsForExercise`(planExerciseID 键,每周独立 id → 永远空)。** e1rm 点只在完成边沿记录,正是想要的"完成组参考"。
2. **零后端**:34 全程不动后端,纯 StudentKit + 现有 repo。
3. 日历点色逻辑与 Dashboard `DayChip` 重复 → 抽共享小工具或对齐常量,别两处漂移。
4. 切日 race:快速连点不同天,后到的 load 要覆盖前一个(VM 已是单状态机,确认 load 幂等)。
5. readiness 自动弹只在 `isDateInToday(selectedDate)` 且非空 —— 切到历史日不能弹。

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-14 | 0.1 | 起草。日历(周默认/月展开)+ 阶段头 + Last/Best;复用全部现有执行件;零后端优先,Last/Best 跨计划需核 StudentSetLog catalog id | Claude |
