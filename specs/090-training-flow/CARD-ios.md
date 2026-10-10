# Spec 090 · iOS 卡：做完的动作上收、组进度分段条、完成按钮吸底、录入页压矮

开工先读仓内 `CONTEXT.md`、`AGENTS.md`、`specs/085-090-android-parity/README.md`（共同约定，全部适用）、本目录 `SPEC.md` 全文。

- 级别／节奏：T2 / P1。分支 `feat/090-training-flow`，**叠在 `feat/089-accessory-quick-log` 上**（其下是 086），工作树 `../MeetPR-wt-086`。
- **不 commit、不 push**；交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。

## 目标

训练页记录过程有前进感，行为与安卓一致：

1. 做完的动作收成一行、排到 hero 卡上方并标已完成；下一个动作顶进 hero；取消一组则退回。
2. 主项 / 变式的 hero 卡加一排组进度分段条；辅助项记录卡不加。
3. 当天全部做完：hero 卡消失，「长按 · 完成今日训练」吸在 Tab 栏上方；没全部做完时维持现状。
4. 组录入页：顺序不变，压矮「重量」「次数」两行，让拍摄行首屏可见。

## iOS 落点（以现场为准）

- 分区与 hero：`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/` 的 `TodayWorkoutScreen.swift`、`TodayWorkoutView.swift`、`TodayWorkoutPresentation.swift`、`TodayWorkoutExerciseSection.swift`、`TodayWorkoutTypes.swift`、`TodayWorkoutViewModel.swift`。「做完的动作」「正在做的动作」的定义照 `SPEC.md`「术语」，对应 iOS 现有的「该组已有结果」与「系统代填」判定；找不到等价判定先停下来问。
- 完成按钮：`HoldToCompleteButton`（在 `TodayWorkoutScreen.swift`）、`HoldToCompleteGestureState.swift`、`WorkoutCompletionPresentation.swift`、`TodayWorkoutView.swift` 现有的底部安全区内嵌。长按的行为、触感、进度、结算与庆祝页不变；全页只有一颗按钮。
- 录入页：`SetEntrySheet.swift`、`SetEntryPlateLoadout.swift`、`SetEntryRPEScale.swift`、`SetEntryValue.swift`。

## iOS 上要注意的地方

- 上收后的滚动：滚到「刚收上去的那一行」贴近可视区顶部，让它和紧随其后的 hero 卡同屏可见（`SPEC.md` §1 的 10/10 修订）；学员正在手动滚动或键盘开着时不抢滚动。
- 上收与顶替各一次短过渡，属反馈类动效；系统「减少动态效果」开启时直接切换；升级后首次进页不播动效。
- 吸底按钮带与页面背景一致的底衬与顶部细分隔线，列表底部留等高空白；与休息计时条同时出现时按钮在计时条上方，不重叠。
- 做完的一行在浅色下的文字用主文字色、深色下用现有的浅绿色 token（安卓收货时接受的对比度处理），就近取 `DesignSystem` token。
- 分段条对读屏隐藏，`Set 2 of 3 · exercise 1 / 5` 那行小字保留。
- **录入页的目标机型**：安卓以 David 的手机为准。iOS 以 iPhone 17 Pro 模拟器、竖屏、默认字号为准——按现有呈现方式打开录入页，不滑动能完整看到 Record / Photos 那一行；iPhone SE 允许仍需少量下滑；大字号不保证。可点控件命中高度不低于 44。
- 数字键盘、长按连加、配片图随重量变化、已选视频的状态显示全部不变。
- 纯展示层：不读写新字段，不动本地存储键。

## 测试 seam（先红后绿，只在这些边界）

- **S1 分区**（新纯函数，在 `TodayWorkoutPresentation` 的测试旁）：全没做、做到一半、跳着做、部分记录、含失败组、含系统代填、全部做完、做完后取消一组，各一条断言，输出「做完的 / 正在做的 / 其余」三段。
- **S2 分段条模型**（新纯函数）：0/3、1/3、含失败、全部完成。
- **S3 完成按钮形态**：扩展现有完成可用性的判定（`WorkoutCompletionPresentation` 一带），原有断言不改，新增「全部记完 → 吸底且无剩余提示」「差一组 → 不吸底」。
- **S4 页面层**（现有训练页 view model / presentation 测试的同一 seam）：做完第一个动作后它排在 hero 之前并带已完成标记；全部做完后没有 hero、有吸底按钮；取消一组后恢复。
- 录入页压矮是纯样式，不加快照测试，由模拟器验收。

## 验收

`SPEC.md`「验收清单」第 1–14 项逐项成立，替换如下：

- 第 13 项换成上面「录入页的目标机型」的口径。
- 第 14 项：深色、中文、磅单位各看一遍第 1–3、8、13 项。
- 第 15 项换成：`swift test --package-path Modules/StudentKit` 及其他动到的包全量通过；`swift-format` 与 `swiftlint` 严格模式 0 违规；`MeetPR-DemoStudent` 能在模拟器构建运行；既有测试的断言不删不改（确需改的逐条在 JOURNAL 说明）。
- 第 11 项「老用户升级第一屏」：当天已记 5 组的训练，打开即是正确分区，无动效、无跳动。Demo 到不了时按共同约定加启动参数开关的场景。

## 已知的安卓侧遗留（不要带过来，也不用修）

安卓收货时发现一个既有问题：结算当天训练后回训练页，页头以下空白、拖一下才出现（与 090 无关，安卓待排查）。iOS 实装后请在 JOURNAL 写一句「结算后回训练页是否正常」的实测结果。

## 文件范围

`Modules/StudentKit`（TodayWorkout、Resources、对应 Tests、必要时 Demo）；确有需要时 `Modules/DesignSystem`。不动 Today 页、未开始时的汇总卡、只读预览、已结算详情、辅助项记录卡内部（089 已定）、录入页各段的顺序与功能、休息计时、`CoachKit`、`Widgets`。
