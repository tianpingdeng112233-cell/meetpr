# Spec 089 · iOS 卡：辅助项快速记录

开工先读仓内 `CONTEXT.md`（「辅助项」「主项标记」两个词条）、`AGENTS.md`、`specs/085-090-android-parity/README.md`（共同约定，全部适用）、本目录 `SPEC.md` 全文。

- 级别／节奏：T2 / P1。分支 `feat/089-accessory-quick-log`，**叠在 `feat/086-training-strip-coach-note` 上**，工作树 `../MeetPR-wt-086`。
- **不 commit、不 push**；交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。

## 目标

训练页轮到辅助项时，hero 卡变成行内表格，做一组点一个 ✓，行为与安卓一致：

1. 辅助项记录卡：组号｜上次｜重量｜次数｜RPE｜✓ 六列；提示行；「全部按计划完成」。
2. 逐组 ✓ 写入普通记录；再点一次 ✓ 取消（写回未完成）；改数字后再 ✓ 覆盖；点组号进现有完整录入页。
3. 辅助项休息时长：教练设的 → 学员的「辅助项休息」设置 → 默认 60 秒；设置页新增一段。

## iOS 落点（以现场为准）

- 判定：`CoreModels` 的 `Exercise.exerciseType == .accessory`（已有 `isAccessory` 一类的派生）。动作类型从动作库取；解析不到类型的动作按**非辅助项**处理。与计划里的主项标记无关。
- hero 卡与写入：`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/` 的 `TodayWorkoutScreen.swift`、`TodayWorkoutPresentation.swift`、`TodayWorkoutTypes.swift`、`TodayWorkoutViewModel.swift`、`TodayWorkoutViewModel+DraftBuilding.swift`、`SetEntryValue.swift`。写入走现有记录一组的同一条路径（同一种记录、同一个接口）。
- 休息：`RestTimerPolicy.swift`、`Features/MyProfile/StudentRestTimerSettings.swift`、`RestTimerSettingsView.swift`、`RestTimerPreferenceRow.swift`、`RestTimerExplanation*.swift`。
- 与 spec 081 的补记（`QuickLogSheet` / `QuickLogPlan`）是两件事，补记一行不动。

## iOS 上要注意的地方

- **取消一组**要向后端显式写回 `completed: false`、`failed: false`、重量次数保留。先核实 iOS 现有写入路径能不能发出这种请求体（安卓是显式传一个取消动作）；发不出就在现有路径上补，不另开接口。带视频的组不能取消，点 ✓ 时提示先到完整录入页处理视频。
- RPE 没填时请求里不带 RPE 值，不替学员写教练预设；处方是 RIR 时占位显示 `RIR n`，写入的仍是 RPE，换算与完整录入页一致。
- 重量 / 次数 / RPE 的校验沿用现有规则，辅助项重量下限 0；单位跟随单位偏好，磅的换算沿用现有精度。自重组显示 `BW`、不可填、按 0 记录。
- 键盘：数字键盘没有收起键，要有键盘工具条的完成按钮或点空白收起；键盘弹出时当前行不被遮住。
- 休息计时的界面、锁屏实时活动（Live Activity，锁屏与灵动岛上的倒计时卡片）、+30 / −30 / Skip 全部沿用现状，只是时长来源多了辅助项这一支；「全部按计划完成」与该动作最后一个未记录组不起计时；「休息时间跟 RPE 走」的首次说明弹层只在主项场景出现。
- **存储**：在现有休息计时偏好（`UserDefaults`）里追加一个字段；**旧用户没有这个字段时按 60 秒**，现有的主项设置原样保留；切换「自动 / 自定义」模式时保留辅助项时长。存储键不变。
- 设置页底部说明文字随 `SPEC.md` 屏幕稿板 3 改成复数写法；中文取安卓目录。
- 下方的分动作组表维持现状。只读预览、已完成详情不出现记录卡。

## 测试 seam（先红后绿，只在这些边界）

1. 辅助项判定（纯函数，新）：三种类型、未知类型、解析不到 → 是否辅助项。
2. 记录卡行模型（纯函数，新）：由处方、已有记录、上次记录生成每行的预填、占位、能否 ✓、是否自重；「全部按计划完成」选出哪些行、跳过哪些行。
3. 休息时长（`RestTimerPolicy` / `StudentRestTimerSettings` 的现有测试）：辅助项三级优先级；旧偏好缺字段时为 60（用一份改前格式的已存数据解出来验证）；主项结果不变；切模式保留辅助项时长。
4. 写入（`TodayWorkoutViewModel` 的现有测试方式，假仓库）：点 ✓ 发出的请求；取消发出 `completed:false`；RPE 没填时不带值；带视频的组不能取消；「全部完成」的逐条提交与部分失败（已写的保留、未写的可重试）。
5. 渲染层 presentation：辅助项出现记录卡、主项不出现；全部记完后切到下一个动作。
6. 现有记录一组、结算、补记、聊天引用组、休息计时相关测试不改断言而保持通过。

## 验收

`SPEC.md`「验收清单」第 1–12 项逐项成立，替换如下：

- 第 12 项的屏幕与字号按共同约定换成 iPhone SE + `accessibility-large`（六列不溢出、输入框不截字、键盘不遮当前行、磅单位换算正确）。
- 第 13 项换成：`swift test --package-path Modules/StudentKit`、`Modules/CoreModels` 及其他动到的包全量通过；`swift-format` 与 `swiftlint` 严格模式 0 违规；`MeetPR-DemoStudent` 能在模拟器构建运行。
- 第 10 项「老用户升级第一屏」：训练到一半（主项记完、辅助项记了一组、其中一组带视频）与从未改过休息设置两种形态。Demo 到不了时按共同约定加启动参数开关的场景；休息设置的旧格式用单测覆盖。
- 第 3、5 项里「教练端看到的记录」在教练 Demo 或假仓库断言里确认，不改 `CoachKit` 代码。

## 文件范围

`Modules/StudentKit`（TodayWorkout、MyProfile 的休息设置、Resources、对应 Tests、必要时 Demo）；`Modules/CoreModels` 只加不改；写入路径确需时 `Modules/Networking` / `RepositoryContracts`（不改线上形状，只补能发出的字段）。不动补记、训练日结算与撤销、e1RM、`CoachKit`、`Widgets`。
