# Spec 087 · iOS 卡（第一步）：Progress 改为列表入口

开工先读仓内 `CONTEXT.md`、`AGENTS.md`、`specs/085-090-android-parity/README.md`（共同约定，全部适用）、本目录 `SPEC.md` 的「现状」「已拍板口径」§1–§4、「存量与升级」第一步、「测试 seam」第一步、「验收清单」第一步、「屏幕稿」板 1–4。

- 级别／节奏：T2 / P1。分支 `feat/087-progress-menu`，**叠在 `feat/085-today-final-walkthrough` 上**，工作树 `../MeetPR-wt-085`（085 收货提交后在同一棵树切出本分支）。
- **不 commit、不 push**；交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。
- **只做第一步**：入口页四行（e1RM、Training history、Coach feedback、Intensity metrics）+ e1RM 页 + 历史记录页顶部三格 + 强度指标页。`SPEC.md` §5 体重页、入口页第 4 行 `Body weight`、测试 seam 6–8、验收 14–21 **不做**，也不留空壳行。

## 目标

Progress 页从「一整页往下滚」改成列表入口，图表与统计各归各页，行为与安卓一致：

1. 入口页：页头 + 四张行卡片，每行 图标 + 名称 + 右侧当前值 + 箭头，入口页不再有任何图表与统计格。
2. e1RM 页：四段切换 `Total / Squat / Bench / Deadlift`，默认 Total；三段内容就是现有 e1RM 卡；新增 Total 序列与 Total 段；对比两格只在 Total 段。
3. 历史记录页顶部加三格（训练次数 / 周数 / 总容量）。
4. 强度指标页：现有「每周训练量柱 + 平均 RPE 线」原样搬入。

## iOS 落点（以现场为准）

- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/`：`TrainingHistoryView.swift`（现在的 Progress 根页，含 `GrowthComparisonCard`、`GrowthHistoryStatsCard`、`GrowthNavigationCard`）、`GrowthScreenPresentation.swift`、`GrowthE1RMCard.swift`、`GrowthE1RMDetail*.swift`、`GrowthEmptyStates.swift`、`GrowthWindowSparseTrendState.swift`、`ProgressMetrics.swift`、`ProgressDashboardView.swift`、`VolumeIntensityChart.swift`、`AllHistoryScreen.swift`、`HistoryEntriesView.swift`、`TrainingHistoryViewModel.swift`。
- 教练反馈行的去向：现有反馈页（`Features/FeedbackInbox/`，Today 反馈卡进的同一页）。Progress 里只有文字的旧反馈入口移除。
- **列表行组件做成通用的**（建议 `Features/Shared/`）：圆角浅灰底方块里的图标 + 名称 + 右侧等宽灰色值 + 箭头；名称单行不截断不收缩；名称与值一行放不下时，值**整体**落到名称下一行、左对齐，不在词中间断开、不截断。088 的首屏五行直接复用它。

## iOS 上要注意的地方

- Total 序列的口径照 `SPEC.md` §2「Total 段」逐句实现，含 10/09 修订：大号数字 = 三段大号数字之和（现有合计格那个数），曲线 = 三项每日最佳主线点沿用求和，回落期两者可以不相等。iOS 现有三段的「大号当前值」与「曲线」取法不改。
- 三段的四种状态、点节点看来源组的弹层（`GrowthE1RMDetailSheet`）、提示文案全部照旧，只是从三张卡变成一张卡里切换。零数据态的「去 Today」按钮三段都出现（仅零训练时）。
- 时间范围四段共用、切段不重置；每次进 e1RM 页回到 Total。
- 历史记录页从训练页 `Training history` 进来是同一页，也带三格。
- 行右侧值的复数（`1 session` / `{n} sessions`、`{n} new`）用 xcstrings 复数变体；中文取安卓目录。
- 二级页用现有 `NavigationStack` 推入，是否盖住 Tab 栏沿用 iOS 现有历史页的做法。

## 测试 seam（先红后绿，只在这些边界）

1. `GrowthScreenPresentation` / `ProgressMetrics` 的现有测试旁：Total 序列纯函数——三项未齐返回空；齐的那天起出点；某项没更新沿用上一次；同一天两项更新只出一个点；最后一点等于三项主线各自最新点之和；低置信度点不参与；用由打卡记录建出的曲线验证每个更新日都出点。Total 段大号数字等于现有合计值。
2. 同处：入口页每行右侧值的派生——Total 有 / 无；`1 session` / `{n} sessions` / 零训练；反馈未读 / 全已读 / 无；最近一周平均 RPE 有 / 无 / 未解锁。
3. Progress 根页的 presentation 或 view model 测试（沿用现有挂载方式）：四行、顺序与名称、没有图表；加载中与失败时行仍在且可点。
4. e1RM 页状态：默认 Total；切段后范围不重置；Total 段有对比两格、没有「点选节点」提示。
5. 现有 e1RM 历史点、导入基线、来源详情相关测试不改断言而保持通过。

## 验收

`SPEC.md`「验收清单」第一步第 1–12 项逐项成立，替换如下：

- 第 12 项的屏幕与字号按共同约定换成 iPhone SE + `accessibility-large`（含中文界面与四位数 Total）。
- 第 13 项换成：`swift test --package-path Modules/StudentKit` 及其他动到的包全量通过；`swift-format` 与 `swiftlint` 严格模式 0 违规；`MeetPR-DemoStudent` 能在模拟器构建运行。
- 第 11 项「老用户升级第一屏」：有多周训练、有未读反馈的 Demo 学员，入口页四行的值与改前页面上对应的数一致（改前的数在动手前先截图或记进 JOURNAL）；零训练形态四行里三个为 `—`。

## 文件范围

`Modules/StudentKit`（TrainingHistory、Shared、Resources、对应 Tests）；确有需要时 `Modules/DesignSystem`。不动 e1RM 算法、主线与低置信度判定、来源弹层内容、训练历史列表本身、反馈页本身、Tab 名称与顺序、`CoachKit`。
