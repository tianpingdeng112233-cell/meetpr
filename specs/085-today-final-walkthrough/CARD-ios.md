# Spec 085 · iOS 卡：Today 走查四项

开工先读仓内 `CONTEXT.md`、`AGENTS.md`、`specs/085-090-android-parity/README.md`（共同约定，全部适用）、本目录 `SPEC.md` 全文（含「存量数据与升级」「验收清单」「屏幕稿」）。

- 级别／节奏：T2 / P1。base = `release/1.0`，分支 `feat/085-today-final-walkthrough`，工作树 `../MeetPR-wt-085`。
- **不 commit、不 push**；交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。

## 目标

把 `SPEC.md` 的 §1–§4 做进 iOS 学员端，行为与安卓一致：

1. Today 周条：选中框跟随点选，与「当前训练日」标记分开；周条下一张可点的概览卡，点卡进训练页并选中同一天。
2. 体重：Today 体重卡进入只含一个体重输入框的页面；全端体重显示固定两位小数；输入最多两位小数；英制换算存两位。
3. Meet：编辑页改为日期 + 赛事方 + 级别（三项必填），按 `IPF · 83 kg` 的固定格式写进现有 `target_weight_class`；`Remove meet`；Profile 的 `Meet / notes` 拆成 `Meet` 与 `Note to coach` 两行；新用户引导第 7 步同步改。
4. Today 营养占位卡（纯展示）。

## iOS 落点（以现场为准，自行 grep 找全，JOURNAL 列清单）

- 周条与概览卡：`Modules/StudentKit/Sources/StudentKit/Features/Dashboard/` 的 `DashboardWeekCalendar.swift`、`DashboardTodayPresentation.swift`、`DashboardTodayScreen.swift`、`DashboardView.swift`、`DashboardPrimaryAction.swift`。两种标记的画法照训练页周条现有写法（spec 084 §4，`Features/TodayWorkout/TrainingWeekStrip.swift` 一带）。把所选日交给训练页：复用现有的指定训练日入口（`TodayWorkoutPlanHandoff` / `TodayWorkoutSelectionResolver` 一带），不新建第二条路。
- 体重与 Meet 两张卡、编辑入口：`DashboardProfileMetrics.swift`、`DashboardProfileMetricsView.swift`、`DashboardProfileEditor.swift`；编辑页在 `Features/MyProfile/ProfileCardsSection.swift` 一带。
- Profile 行与摘要：`Features/MyProfile/MyProfileView.swift`、`MyProfileV3Presentation.swift`、`OnboardingSummaryFormatter.swift`。本卡只把那一行拆成两行并接上各自的编辑页，Profile 的整体版式不动（088 才改）。
- 引导：`Features/Onboarding/Steps/Step7ExtrasSection.swift`、`Step1BasicsSection.swift`、`OnboardingDraft.swift`、`OnboardingWizardViewModel.swift`、`UnitDisplay.swift`。
- 级别表与格式：新建纯逻辑（建议放 `StudentKit` 的 `Features/Shared/`），对应安卓 `src/domain/meet/weight-class.ts`。
- 体重格式化与输入过滤：现有 `StudentFormatting` 旁新增，对应安卓的 `formatBodyWeightKg` 与输入过滤。

## iOS 上要注意的地方

- 概览卡状态小标、`Selected day · e1RM chart` 小标题、`Previously entered: …`、营养卡各词条的中英文都取安卓目录。
- 体重输入用 `decimalPad`；系统地区的小数分隔符是逗号时，输入与显示按该地区处理，存储口径不变（两位小数的 kg）。
- 日期滚轮沿用现有 Meet 编辑页的控件与范围（今天起至十年后）。
- 赛事方块、级别网格的选中态：深色底白字 / 未选描边，用 `DesignSystem` 现有可选块样式，没有就按现有 token 新建一个通用的小组件，087、088 还会复用。
- 教练端不改代码：它原样显示 `target_weight_class`，验收时在教练 Demo 里确认能看到新格式文字即可。
- 安卓 spec 的「老用户」五种情况（手填级别、从未回答、有日期、无日期、体重一位小数）在 iOS 的存量数据里同样存在，逐条都要成立。
- 引导草稿的本地存储结构不变（`LocalOnboardingDraftStore`）。

## 测试 seam（先红后绿，只在这些边界）

1. 级别表与格式（新测试文件）：`format` / `parse` 往返（含 `120+`、`67.5`）；旧手填值、只有赛事方代码、级别不在该赛事方表内都判为不识别；四家 × 两性别的表与 `SPEC.md` 逐格一致。
2. `Features/Onboarding/OnboardingDraftTests.swift`（已有）：保存 → `is_competing=true` + 日期 + 格式化级别；缺赛事方或级别校验不过；移除 → 三字段清空；第 7 步不展开不报错且 `is_competing=false`，展开后缺项报错；体重两位小数的输入过滤与英制换算精度（含读回值再保存 kg 不变）。
3. `Features/Dashboard/DashboardProfileMetricsTests.swift`（已有）：体重显示两位小数（`83` → `83.00`、`83.5` → `83.50`）；Meetday 卡带出 `target_weight_class` 一行，没有就不出。
4. `Features/MyProfile/ProfileSummaryFormatterTests.swift`（已有）：`Meet` 行与 `Note to coach` 行各自的值；原留言原样出现。
5. Today 周条与概览卡的 presentation（在现有 Dashboard presentation 测试旁新增）：点选后选中跟随、当前训练日标记不动；概览卡对所选日给出名称、状态小标、动作数与组数、按计划顺序的一行动作名；离开再回来选中重置。

样式不写断言，由模拟器验收。

## 验收

`SPEC.md`「验收清单」第 1a–5 项逐项成立，替换如下：

- 第 5 项的屏幕与字号按共同约定换成 iPhone SE + `accessibility-large`。
- 第 6 项换成：`swift test --package-path Modules/StudentKit` 及其他动到的包全量通过；`swift-format lint --strict` 与 `swiftlint lint --strict` 0 违规；`MeetPR-DemoStudent` 能在模拟器构建运行。`PARITY.md` 一句不适用。
- 第 4 项「老用户升级第一屏」用 Demo 场景或单测里的存量档案形态覆盖三个账号形态，JOURNAL 写明各用哪种方式覆盖。

## 文件范围

`Modules/StudentKit`（Dashboard、MyProfile、Onboarding、Shared、Resources、对应 Tests）；确有需要时 `Modules/DesignSystem`（通用可选块）与 `Modules/CoreModels`（只加不改）。不动 `CoachKit`、`Networking` 的线上形状、`Widgets`、工程文件里的版本号。
