# Spec 084 · 卡 A（iOS）：序号、可点卡片、去横幅、提醒默认日

开工先读仓内 `CONTEXT.md`（如存在）、`AGENTS.md`、`specs/084-walkthrough-polish/SPEC.md` 的 §2、§3、§5、§6 与「存量数据与升级」「测试 seam」「验收清单」。

- 级别／节奏：T2 / P1。base = 发版线 `release/1.0`（`bcabd9a4`），分支 `feat/084a-walkthrough-behaviors`，目标 1.0(24) 候选（落线不等于进包）。
- 这是 Opus 派的任务卡，走 feature 分支 + PR，**不是** `AGENTS.md` §发版直推流里的"David 直驱小修"：那一节的开工自检（当前分支必须是发版线）不适用，就在当前分支实装；发版线正被别的 worktree 占着，也切不过去。直推流里与分支无关的纪律（lint、测试、模拟器）照守。
- **不 commit、不 push**。不改 `NEXT-RELEASE.md`、`RELEASES.md`、build 号；只在 `docs/CODEX-JOURNAL.md` 末尾追加本卡一节。本仓已公开，不写账号、密钥、内网细节。

## 要做的四项（行为定义以 SPEC 为准，这里只补 iOS 落点）

### §2 W#D# 的 D 改为"本周第几练"

现状的落点（`release/1.0`）：
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardTodayPresentation.swift`：`"W\(day.weekNumber)D\(day.dayOfWeek)"`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`：`weekCode` 与 `weekday` 两处同样的拼接
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCalendarView.swift`：`Text("D\(item.day.dayOfWeek)")`
- 以及全仓其他把 `dayOfWeek` 当作 D 序号展示的位置（训练历史、补录、聊天训练卡、教练端学员详情等）——自行 grep 找全，在 JOURNAL 列出清单。

要求：新增**一个**序号计算入口（放在已有的序列逻辑旁，如 `TrainingSequenceLayout` / `TrainingCalendarLogic`），输入一周的训练日，输出每天的 1 起序号，顺序沿用现有序列排序（`dayOfWeek`、再排序字段）；所有展示点都走它。`dayOfWeek` 字段、排序、推荐日期、完成推进一律不动。教练端排课界面的 `DAY n` 标签不在范围内。

### §3 Today 的 Meetday 卡与体重卡可点

落点：`Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardProfileMetricsView.swift`（四个卡片视图：体重占位 / 体重 / 比赛 / 比赛占位）及其所在的 Today 页。要求：四种状态都可点；Meetday → 现有的 Meet / notes 编辑页（`ProfileCardsSection` 的 `.competition`）；体重 → Basic information 编辑页（`.basics`）；保存或取消后回 Today 并刷新。复用现有编辑页与保存路径，不新建编辑界面；补按压反馈（沿用全局 `PressScaleButtonStyle`）与按钮的无障碍语义。

### §5 删除训练页的 e1RM 祝贺横幅

落点：`TodayWorkoutViewModel` 的 `pendingPRBanner` 及其在训练页的展示。要求：不再展示横幅；原本会展示的未确认 PR 事件在同一时机静默确认；PR 的记录、Progress 的曲线与记录点不变。删掉因此不再使用的视图与文案键。

### §6 训练提醒默认日取教练计划

落点：`Modules/StudentKit/Sources/StudentKit/Features/MyProfile/TrainingReminderSettings.swift`（现有默认：档案训练日，回落一三五）与其 ViewModel。要求：从未保存过自定义星期的用户，首次默认 = 当前这一周各训练日的教练推荐日期所在星期；无已发布计划回落档案训练日；再回落一三五。已保存的设置不动。

## 约束

- 不改后端契约与本地持久化结构；不加依赖。
- 存量照护：老用户升级后已完成进度、当前训练日、休息计时、草稿、已保存的提醒设置都不变（只有 W#D# 的显示从槽位变序号）。
- 守仓内 `.swiftlint.yml` 与 `swift-format --strict`（唯一事实源是仓内配置）。

## 测试 seam（先红后绿，只在这些边界）

1. 序号计算函数 + `DashboardTodayPresentation` 与训练页 presentation 的标签输出。
2. Today 卡片点击 → 进入对应编辑页的导航断言。
3. `TodayWorkoutViewModel` 的 PR 事件处理：不出横幅、事件被确认。
4. `TrainingReminderSettings` 的默认星期推导（三级回落 + 已保存不动）。

## 验收清单（Opus 收货，逐项核）

- [ ] 训练日在星期二/四/六/日的一周，各处显示 D1–D4；补加一个更早的训练日后重排为 D1–D5；教练端与学员端对同一天显示同一序号。
- [ ] 推荐日期、完成推进、补录归日与修改前一致。
- [ ] 两张卡在空态与有值态都可点，进入正确的编辑页；保存后回 Today 即时更新；取消不写。
- [ ] 触发一次 e1RM 提升后训练页无横幅；Progress 出现对应点；该事件下次进入不再触发任何提示。
- [ ] 新用户首次打开提醒的默认星期符合三级回落；已保存设置升级后不变。
- [ ] 九个包的 `swift test`、主工程测试、`swiftlint lint --strict`、`swift-format lint --strict` 通过。
- [ ] DemoStudent / Demo 两个配置在模拟器上亲眼看：Today、训练页、提醒设置页，Light / Dark。

模拟器实屏由 Opus 收货时做；沙箱里跑不了模拟器就如实写"未做设备验证"。

## Out of Scope

SPEC §1、§4、§7–§10（另两张卡）；`dayOfWeek` 的数据语义；Progress 页；推送；build 号、tag、`NEXT-RELEASE.md`、Archive / Upload。

## 返修第 1 轮（Opus 收货，2026-10-02）

四项的自动测试复跑通过（CoreModels 158 / StudentKit 907 / CoachKit 443，SwiftLint 与 swift-format 严格模式 0 违规），DemoStudent 实屏通过：Today 与训练页显示 W1D3、周条 D1–D4（训练日在周二至周五）；体重卡与 Meetday 卡进入对应编辑页，保存后回 Today 即时更新；提醒页默认星期取到计划的周二至周五（档案训练日是一三五六）。只有一处返修：

1. `StudentPlanSequence.dayNumbers(inWeek:)` 用了 `Dictionary(uniqueKeysWithValues:)`，传入的数组里一旦出现重复的训练日 id 会直接崩溃，而这个入口现在被 Today、训练页、教练端学员详情等多处展示代码调用，调用方传的是各自拼出来的数组（如 `model.cycleDays`、`viewModel.plan?.days`），不能假定无重复。改成不会陷入崩溃的构造（同一 id 取首次出现的序号），并在序号函数的现有测试里加一条"重复 id 不崩溃、序号稳定"。不改其他行为。

返修后重跑 CoreModels、StudentKit、CoachKit 的测试与两个 lint，JOURNAL 本卡一节追加一行。仍不 commit、不 push。
