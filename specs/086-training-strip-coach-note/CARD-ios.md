# Spec 086 · iOS 卡：训练页周条落后状态、周条压矮、教练备注上移

开工先读仓内 `CONTEXT.md`、`AGENTS.md`、`specs/085-090-android-parity/README.md`（共同约定，全部适用）、本目录 `SPEC.md` 全文。

- 级别／节奏：T2 / P1。base = `release/1.0`，分支 `feat/086-training-strip-coach-note`，工作树 `../MeetPR-wt-086`。
- **不 commit、不 push**；交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。

## 目标

把 `SPEC.md` 的 §1–§3 与「状态圆点大小」做进 iOS 训练页，行为与安卓一致：

1. 周条格子：训练日格 = 星期 / 状态图形 / 第三行（教练推荐日期，或已落后时写 `Behind`）；不再写 D 序号；休息格不写日期。
2. 落后天数：当前周的状态胶囊在落后时由 `Current week` 换成 `{n} days behind`。
3. 版式 2B：周次、胶囊、进度并进 `Training history` 那一行；换周箭头放格子两端；删周数小点。
4. hero 卡：教练的动作备注上移到动作名正下方的淡金块；组级 `coach_note` 留在原处的小灰字块。
5. 周条状态圆点 8、对勾 12。

## 与 iOS spec 071 的关系

071 定过「推荐日期已过照实显示、不催促、无漏课态」。David 10/09 在安卓修订、10/10 定 iOS 同口径：出现「已落后」字样与天数，只是状态说明——不用红色、不拦任何操作、不发提醒、不改推进规则。`CONTEXT.md` 的「推荐日期」词条不改。

## iOS 落点（以现场为准）

- 周条：`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/` 的 `TrainingWeekStrip.swift`、`TrainingWeekCalendarRow.swift`、`TrainingSequenceCalendarCell.swift`、`TrainingCalendarLogic.swift`、`TrainingDayPreview.swift`（只读预览里的「Coach recommends {日期}」一行）、`TodayWorkoutView.swift`（页头下那一行与 `Training history` 入口）。
- 「今天」：用现有 `WorkoutDatePolicy.gymDayToday`（凌晨 4 点前算前一天），与安卓同口径。教练后移后的日期取现有的推荐日期派生，不另算。
- 备注：`CoachNoteDisplay.swift`、`TodayWorkoutScreen.swift` 的 hero 卡、`TodayWorkoutPresentation.swift`。
- 应用回到前台或跨过日界线后重算落后：挂在训练页现有的前台刷新触发上。

## iOS 上要注意的地方

- 胶囊、`Behind`、读屏文字的中英文取安卓目录；复数（`1 day behind` / `{n} days behind`）用 xcstrings 的复数变体。
- 格子与箭头的命中高度不低于 44；一周跨度超过 7 天时仍可横向滚动。
- 只读态（已完成详情等）的备注块保持改前行为：组级备注，没有才显示动作备注。
- 翻周、`Back to today`、选中框与当前训练日两种标记、未来训练日只读预览全部不动。

## 测试 seam（先红后绿，只在这些边界）

1. `TrainingCalendarLogic` 的现有测试文件：新增「是否已落后」派生（入参带今天）——已完成不算；推荐日期等于今天不算；早于今天且未完成算；凌晨 4 点前按前一天；教练后移按后移后的日期。同处「落后天数」：当前训练日落后 0 / 1 / 18 天、全部练完时为 0。
2. 周条的 presentation（新增或扩展现有周条测试）：训练日格没有 `D{n}`；第三行三种情况各一例；胶囊在落后 / 不落后 / 非当前周三种情况下的文字；休息格无日期；读屏文字符合 §1。
3. hero 卡备注取值（纯函数，`CoachNoteDisplay` 的测试）：动作备注有 / 无 / 纯空白 → 淡金块内容；组级 `coach_note` 有 / 无 → 小灰字块是否出现；两者互不影响；只读态行为不变。
4. 现有训练页相关测试不改断言而保持通过。

## 验收

`SPEC.md`「验收清单」第 1–10 项逐项成立，替换如下：

- 第 10 项的屏幕与字号按共同约定换成 iPhone SE + `accessibility-large`（`Behind` / 「已落后」在最窄格里完整显示；周次行不换行不截字，含三位数天数）。
- 第 11 项换成：`swift test --package-path Modules/StudentKit` 及其他动到的包全量通过；`swift-format` 与 `swiftlint` 严格模式 0 违规；`MeetPR-DemoStudent` 能在模拟器构建运行。
- 第 9 项「老用户升级第一屏」：需要一个落后两周以上的形态与一个进度正常的形态。现有 Demo 到不了落后形态时，按共同约定加启动参数开关的 Demo 场景。

## 文件范围

`Modules/StudentKit`（TodayWorkout、Resources、对应 Tests、必要时 Demo）；确有需要时 `Modules/DesignSystem`。不动 `Dashboard`（Today 周条是否同口径另行拍板，不在本卡）、`CoachKit`、`Widgets`。

## 修订一（2026-10-10，Opus 裁定 Codex 开工核对的阻塞）

现状：iOS 训练页 hero 卡只显示动作备注，可编辑态与只读态都一样，从不读组级 `coachNote`（证据见 `docs/CODEX-JOURNAL.md`「spec 086 iOS（开工核对）」）。安卓 SPEC 里「只读态保持改前行为：组级备注，没有才显示动作备注」描述的是安卓的改前行为，不是 iOS 的。裁定取 A：

- **只读态**（已完成的训练日、只读预览）：保持 **iOS 现在的行为**，一处不改。本卡「iOS 上要注意的地方」里那句「只读态……组级备注，没有才显示动作备注」作废。
- **可编辑态的 hero 卡**：动作备注上移到动作名正下方的淡金块（SPEC §3）；原来卡片下方那块灰色的动作备注不再出现（已上移）。该组有组级 `coachNote` 时，在 SPEC 说的位置（上次成绩之后）新增一块小灰字显示它——这在 iOS 是新增展示，目的是与安卓同屏内容一致；没有组级备注时不出现。
- 测试 seam 3 相应改为：动作备注有 / 无 / 纯空白 → 淡金块；组级 `coachNote` 有 / 无 → 小灰字块；两者互不影响；只读态的取值与改前 iOS 相同。
- 其余各项照卡执行。
