# UI-REFRESH 实装任务卡 — 黑金设计系统一比一还原

> 给「只拿到这个 worktree 和这张卡」的编码代理。开工前先读 `CLAUDE.md`（仓库身份卡）与 `AGENTS.md`（行为规约、发版直推流），本卡与它们冲突的地方在 §4 显式标注。
> 分支：`feat/black-gold-ui-r10`，基底 `release/1.0`（`b50e079`，即 TestFlight 1.0(14) 的发版线）。
> 本卡涉及的所有路径都是**仓库内相对路径**。

---

## 1. 目标

设计师交付了一套全新的「黑金」设计系统，源文件已在树内 `docs/design/meetpr-design-skill/`。本波要把 MeetPR iOS（学员端 + 教练端 + 登录注册）从现有的「红色 brandRed + 系统字体」外观，**一比一换皮**成黑金系统：结构、间距、层级、色值、字号、圆角一比一，**动效也一比一还原**。

一句话边界：**只动视觉与动效，不动功能。** 导航结构、tab 集合、路由、业务逻辑、数据流、BindGate / 评估封存逻辑一律不碰。

**像素基准 = 暗色学员端样机** `docs/design/meetpr-design-skill/reference/MeetPR 学员端.dc.html`；教练端基准 = `docs/design/meetpr-design-skill/reference/MeetPR 教练端.dc.html`。亮色样机（`… 亮色.dc.html`）本波只用于抄令牌，不做主题切换。

开工必读（全部读完再动手）：

- `docs/design/meetpr-design-skill/README.md` — 设计总纲（内容基本面 / 视觉基本面 / 图标 / 目录索引）
- `docs/design/meetpr-design-skill/SKILL.md`
- `docs/design/meetpr-design-skill/tokens/{colors,typography,spacing,effects,fonts}.css` — 令牌权威
- `docs/design/meetpr-design-skill/guidelines/*.html` — 11 张规范卡（色彩 / 字体 / 间距 / 圆角 / CTA 解剖 / 动效表）
- `docs/design/meetpr-design-skill/components/core/*.{jsx,d.ts,prompt.md}` — 6 个参考组件（Button / Badge / Card / DayChip / SetTable / TabBar）
- `docs/design/meetpr-design-skill/reference/*.dc.html` — 5 个整页可交互样机（重点读内联 style 与 `<script type="text/x-dc">` 里的动效代码）

样机 HTML 很大（学员端 1134 行、约 33k token），**不要一次性整读**，按屏分段读；动效常量集中在文件尾部的 `class Component extends DCLogic` 里。

---

## 2. 现状基线（已侦察核实，2026-07-25）

### 2.1 工程骨架

- iOS 17+ / SwiftUI / MVVM + Repository / SPM 多模块。测试用 Swift Testing（`@Test` / `#expect`）。
- 9 个 SPM 模块在 `Modules/`：`DesignSystem` `CoreModels` `Networking` `RepositoryContracts` `Analytics` `ChatUI` `StudentKit` `CoachKit` `AppShell`。依赖方向：`AppShell → {CoachKit, StudentKit, ChatUI, DesignSystem, …}`，`StudentKit / CoachKit / ChatUI → DesignSystem`。
- App target 目录 `MeetPR/`，工程文件 `MeetPR.xcodeproj`（`objectVersion = 77`）。
- **关键 gotcha：工程用 `PBXFileSystemSynchronizedRootGroup`（Xcode 16 同步文件夹），`path = MeetPR`。** 只要把文件放进 `MeetPR/` 目录，Xcode 自动纳入 target，**不需要改 pbxproj、不需要 ruby xcodeproj gem**。当前 membership 例外只有 `DEMO.md` / `Info.plist` / `README.md`（见 `MeetPR.xcodeproj/project.pbxproj:44-54`）。
- Scheme / configuration：`MeetPR`（Debug/Release，真后端）、`MeetPR-Demo`（configuration `Demo` = 教练端 demo）、`MeetPR-DemoStudent`（configuration `DemoStudent` = 学员端 demo）。demo 用户由 `#if DEMO_USER_STUDENT` 在 app target 里选，见 `MeetPR/Sources/MeetPRApp.swift:110-114`。
- 全 app 锁深色，唯一一处：`MeetPR/Sources/MeetPRApp.swift:286` 的 `.preferredColorScheme(.dark)`（`WindowGroup` 内根级）。`Info.plist` **没有** `UIUserInterfaceStyle`，pbxproj 也没有 `INFOPLIST_KEY_UIUserInterfaceStyle`。
- `MeetPR/Info.plist` 手工维护（`GENERATE_INFOPLIST_FILE = NO`，四个 configuration 都指向它）。**当前没有 `UIAppFonts` 键**，全仓库零命中。
- `MeetPR/Assets.xcassets/` 只有 `AccentColor.colorset`（sRGB 0.898/0.133/0.118 ≈ `#E52220` 品牌红，暗色变体同值）与 `AppIcon.appiconset`。没有其他 colorset / imageset。
- `MeetPR/Resources/Localizable.xcstrings` 是空壳（`"strings": {}`），界面中文字串全部是代码里的内联字面量 —— 本波不涉及本地化。
- 全仓库 **零 `Font.custom`、零 `CTFontManager`、零 `UIAppFonts`**；字体全部走 `Font.system(...)`。

### 2.2 DesignSystem 现状

`Modules/DesignSystem/Sources/DesignSystem/`：

| 目录 | 文件 |
|---|---|
| `Tokens/` | `Colors.swift`（`Color.MeetPR.*`，brandRed `#E5221E` 红色系 + 中性灰阶，含 `Color(light:dark:)` 双态构造）、`Typography.swift`（`MeetPRFontMetrics` 十档字号 44/34/28/20/17/13/11/12/60/24 + `Font.MeetPR` 11 个 token，**全是 `Font.system`**）、`Spacing.swift`（`MeetPRSpacing` 4/8/12/16/24/32/48/64）、`Radius.swift`（`MeetPRRadius` 4/8/12/16/999）、`Motion.swift`（`MeetPRMotion.easeIOS` = timingCurve(0.32,0.72,0,1)，duration 0.20/0.24/0.28） |
| `Components/` | Buttons：`PrimaryButton` `BrandPrimaryButton` `SecondaryButton` `DangerButton` `IconButton`（共用 `MeetPRPressOpacityButtonStyle`，见 `Components/Buttons/PrimaryButton.swift:3-11`，**只有 opacity 0.6，没有 scale**）；Cards：`Card` `ElevatedCard`；Badges：`StatusBadge` `PRBadge`；Charts：`E1RMChart` `Sparkline` `ProgressSegments`；Inputs：`MeetPRTextField` `NumericInput` `RPESlider`；Labels：`Eyebrow` `LargeTitleBar` `StatBlock`；Lists：`MeetPRListRow`；Sets：`SetReadOnlyCell`；Avatars：`InitialAvatar`；Brand：`MeetPRMark` `PlateLoadout` |
| `Demo/` | `DesignSystemDemo.swift`（令牌 + 组件目录页，带 System/Light/Dark 切换） |
| `Extensions/` | `View+NavigationBar.swift`（`hideNavigationBar()`） |
| `Tests/` | `ColorsTests`(218L，逐色断言 RGB) `TypographyTests` `SpacingTests` `RadiusTests` `MotionTests` `ComponentsSmokeTests` `DesignSystemDemoTests` `PlateLoadoutAccessibilityTests` |

`Modules/DesignSystem/Package.swift` **没有 `resources:` 声明**（`StudentKit` / `CoachKit` / `ChatUI` 有 `resources: [.process("Resources")]`）。

### 2.3 学员端（`Modules/StudentKit/`）

**Tab 结构 = 4 个，与样机完全一致，无条件 tab、无 feature flag。** 定义在 `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift:175-262`，枚举 `StudentTab` 在 `StudentNotificationRouting.swift:1`：

| 序 | case | 标签 | SF Symbol | 根视图 | 徽章 |
|---|---|---|---|---|---|
| 1 | `.today` | 今日 | `house` | `DashboardView` | — |
| 2 | `.training` | 训练 | `dumbbell.fill` | `TodayWorkoutView` | — |
| 3 | `.growth` | 成长 | `chart.line.uptrend.xyaxis` | `TrainingHistoryView` | — |
| 4 | `.profile` | 我的 | `person` | `MyProfileView` | `.badge(pendingPRCount + unreadBadgeCount)`（L261） |

容器修饰：`.tint(Color.MeetPR.brandRed)`（L312）—— 这是必换的第一处颜色。
⚠️ 代码注释里多处仍写「5 tabs」（`BindGateView.swift` / `EvaluationPeriodView.swift` / `BindGateViewModel.swift`），**实际是 4 个**（反馈 tab 已并入成长，仪表盘并入今日）。不要被注释误导。

主要屏幕（路径相对 `Modules/StudentKit/Sources/StudentKit/`）：

- **今日**：`Features/Dashboard/DashboardView.swift`(788L) · `Dashboard/StudentNotificationComponents.swift`(通知铃 `StudentNotificationBell` + `MyCoachCard` + `StudentUnreadBadge`) · `Dashboard/NotificationCenterSheet.swift` · `Dashboard/EvaluationCompletedCard.swift` · `Dashboard/DashboardProfileMetricsView.swift`(体重/比赛指标卡) · `Dashboard/E1RMTrendRow+Sparkline.swift` · 顺延弹窗在 `DashboardView.swift:154-180`（`.alert(item: $dayShiftAlert)`，文案由 `Features/TodayWorkout/PlanDayShiftLogic.swift` 生成） · 休息日态在 `DashboardView` 的 `startButtonPrimary(.noPlan)`
- **训练执行**：`Features/TodayWorkout/TodayWorkoutView.swift`(951L，全模块最大) · `TrainingCalendarView.swift`(横向日期条) · `CoachNoteDisplay.swift` · `RestTimerOverlay.swift` · `RestTimerExplanationView.swift` · `SetVideoUploadIndicator.swift` · `Features/Readiness/ReadinessCheckinSheet.swift`
- **组记录**：`Features/TodayWorkout/SetEntrySheet.swift`(506L) · `SetEntryRPEScale.swift` · `SlideToCompleteButton.swift`（滑动完成） · `Features/VideoUpload/VideoAttachmentSection.swift`(350L) · `VideoUpload/CameraVideoPicker.swift` · `VideoUpload/VideoTrimmerView.swift`
- **完成 / 回顾**：`Features/TodayWorkout/SessionSummaryView.swift`(239L，`navigationTitle("训练回顾")`) · `DayCompletionBanner.swift` · `PRBanner.swift`
- **成长**：`Features/TrainingHistory/TrainingHistoryView.swift`(597L，含私有 `AllHistoryScreen`) · `TrainingHistory/VolumeIntensityChart.swift` · `TrainingHistory/HistoryEntriesView.swift` · `Features/MyProfile/GrowthCurveView.swift`
- **反馈**：`Features/FeedbackInbox/FeedbackInboxView.swift` · `FeedbackDetailView.swift` · `StudentFeedbackVideoPlayerView.swift`
- **我的**：`Features/MyProfile/MyProfileView.swift`(442L) · `ProfileCardsSection.swift`(其中 `ProfileCardEditView` 在用) · `RestTimerPreferenceRow.swift` · `RestTimerSettingsView.swift`（**全模块唯一不 import DesignSystem 的 view**） · `AccountSecuritySheets.swift`(318L) · `ExportDataSheet.swift` · `Features/Evaluation/EvaluationSummaryView.swift`
- **绑定 / 向导（tab 之外）**：`Features/Bind/BindGateView.swift` · `EnterCodeView.swift` · `PendingBindView.swift` · `Features/Onboarding/OnboardingWizardView.swift` + `Onboarding/Steps/Step1…Step7*.swift` + `Onboarding/OnboardingFieldComponents.swift` · `Features/Evaluation/EvaluationPeriodView.swift`（**休眠**）

**已确认零调用点的死视图**（本波不还原、不删除，只登记）：`E1RMMiniTrendCard` · `DashboardComponents.DashboardSection` · `ProgressDashboardView` · `TrainingHistory/DayDetailView` · `TodayWorkout/ExerciseExecutionView`（连带 `SetRecordRow`） · `TodayWorkout/PlateMathSheet` · `TodayWorkout/WorkoutDayHeader` · `MyProfile/ProfileCardsSection` 的 section struct。合计约 1200 行，不计入还原预算。

### 2.4 教练端（`Modules/CoachKit/`）

**Tab 结构 = 5 个，与教练端样机完全一致，无条件 tab。** 定义在 `Modules/CoachKit/Sources/CoachKit/CoachRootView.swift:123-200`，枚举 `CoachTab` 在同文件 L221-227：

| 序 | case | 标签 | SF Symbol | 根视图 | 徽章 |
|---|---|---|---|---|---|
| 1 | `.today` | 今日 | `house` | `CoachDashboardView` | — |
| 2 | `.students` | 学员 | `person.2` | `StudentRosterView` | `rosterViewModel.pendingAttentionCount`(L149) |
| 3 | `.planning` | 编排 | `calendar.badge.plus` | `CoachPlanningHomeView` | — |
| 4 | `.receiving` | 接收 | `tray` | `CoachReceivingView` | `CoachReceivingBadge.total(...)`(L171-177) |
| 5 | `.profile` | 我的 | `person` | `CoachMyProfileView` | — |

容器 `.tint(Color.MeetPR.brandRed)`（L211）。

主要屏幕（相对 `Modules/CoachKit/Sources/CoachKit/`）：

- 今日 `Features/Dashboard/CoachDashboardView.swift`(432L)
- 学员 `Features/StudentRoster/StudentRosterView.swift`(388L) + `StudentRosterRow.swift` + `TriageStripSection.swift`
- 学员详情 `Features/StudentDetail/StudentDetailView.swift`(474L，内层是 segmented `Picker` 不是 tab，L291-309)，五段：`Overview/StudentOverviewSection.swift`(概览) · `Execution/StudentExecutionView.swift`(执行) · `Videos/StudentVideoGridView.swift`(视频) · `Growth/StudentGrowthView.swift`(成长) · `Feedback/CoachFeedbackHistoryView.swift`(反馈)；下钻 `Execution/CoachDayDetailView.swift` · `Videos/CoachVideoPlayerView.swift` · `Feedback/FeedbackComposerView.swift` · `Evaluation/EvaluationStatusBanner.swift`（休眠） · `Evaluation/EvaluationSummaryEditorView.swift`（休眠）
- 编排 `Features/PlanningWorkspace/CoachPlanningHomeView.swift`(423L) + `PlanningWorkspaceSections.swift`；向导 `Planning/Views/PlanningCoordinatorView.swift` + `Step0…Step7*.swift` + `WeekCardView.swift` `ExerciseSetEditorCard.swift`(294L) `ProgressionRuleEditorCard.swift`(540L) `PlanningCountPicker.swift` `PlanningNumberField.swift` `WeightEntryPanel.swift` 等约 19 个原子件；导入相关 `Planning/Import/Views/*`（`PlanImportCapability.isEnabled == false`，冻结中）
- 接收 `Features/Receiving/CoachReceivingView.swift`(562L，三段 segmented：新学员 / 训练视频 / 消息) + `StudentPendingVideosView.swift` + `VideoFeedbackDetailView.swift`；`Features/BindQueue/BindRequestCard.swift` + `StudentOnboardingProfileView.swift` + `AcceptBindRequestSheet.swift`
- 我的 `Features/MyProfile/CoachMyProfileView.swift`(235L) + `Features/InviteCodes/InviteCodesView.swift`(296L)
- 聊天 `Features/Chat/CoachChatHeaderButton.swift` + `ConversationListView.swift` + `CoachChatContext.swift`

### 2.5 登录 / 注册（`Modules/AppShell/`）与聊天（`Modules/ChatUI/`）

- **AppShell 只有登录、注册和根路由**：`Sources/AppShell/AuthFlowView.swift`(12L，`NavigationStack { LoginView() }`) · `Auth/LoginView.swift`(127L，**手机号 + 密码**，含禁用的「使用 Apple ID 登录 / 即将开放」占位) · `Auth/SignupView.swift`(177L，「选择你的角色」+ `RoleCard`) · `Auth/AuthSecureField.swift` · `Auth/AuthFormViewModel.swift` · `RootView.swift`(360L，会话态与角色路由：coach → `CoachRootView`；coachedStudent → `E1RMCompetitionLiftGate` → `BindGateView` → `StudentRootView`；selfTrainStudent → 跳过 BindGate)。
- ⚠️ **全仓库没有短信验证码屏**（`sms` / `verificationCode` / `短信` 零非测试命中）。BindGate 与 7 步向导在 **StudentKit**，不在 AppShell。
- **评估封存开关**：`Modules/StudentKit/Sources/StudentKit/Features/Bind/BindGateViewModel.swift:134` `private static let evaluationSealed = true`；教练侧 `Modules/CoachKit/Sources/CoachKit/Features/BindQueue/AcceptBindRequestSheet.swift:60` 恒走 skip 分支。**一个字都不许碰。**
- **ChatUI 已全量接线**（不是死模块）：`Sources/ChatUI/` 有 `ConversationView` `ConversationListSection` `ChatEntryButton`(含 `ChatUnreadBadge`) `ConversationMessageRows` `ChatComposer` + VM/协调器。教练侧入口 = 5 个 tab 根视图各挂一个 `CoachChatHeaderButton`（`CoachDashboardView.swift:78` 等）+ 接收 tab 的「消息」段 + 学员详情工具栏按钮；学员侧入口 = 通知中心（`StudentNotificationComponents.swift:54` 推 `ConversationView`），可见控件是 `StudentNotificationBell`（`bell` / `bell.badge`）。

### 2.6 令牌落地率（决定工作量）

| 维度 | 现状 |
|---|---|
| 颜色 | 已充分令牌化。StudentKit 只有 9 处裸色（`StudentFeedbackVideoPlayerView`×3、`PlateMathSheet`×5、`SetEntryRPEScale`×1 等） |
| 字体 | **最大缺口**：StudentKit 约 192 处裸 `.font(.system(...))` / `.font(.headline)` vs 175 处 `Font.MeetPR.*`；教练端 5 个 tab 大标题全是裸 `.font(.system(size: 36, weight: .heavy))`（`CoachDashboardView:74` `StudentRosterView:57` `CoachMyProfileView:42` `CoachPlanningHomeView:100`，`CoachReceivingView:166` 用 34）。**只改令牌不足以换字体，必须逐屏改到令牌** |
| 间距 / 圆角 | 四个学员端 tab 主屏几乎零令牌（`DashboardView` / `TrainingHistoryView` / `MyProfileView` 的 `MeetPRSpacing` 与 `MeetPRRadius` 命中数均为 0；`TodayWorkoutView` 各 1 / 0），全是裸数字 |
| 动效 | StudentKit `MeetPRMotion` 命中 **0**；全模块只有 11 处手写动画（spring 0.35 / 0.3、`.contentTransition(.numericText())`、两处 `.transition(.move)`、`withAnimation {}`）。零 `PhaseAnimator` / `matchedGeometryEffect` / `KeyframeAnimator` / `.symbolEffect` |
| DS 组件使用率 | 21 个组件里 StudentKit 只用了 9 个；`BrandPrimaryButton` `DangerButton` `IconButton` `ElevatedCard` `MeetPRListRow` `MeetPRMark` `StatBlock` `LargeTitleBar` `SetReadOnlyCell` `InitialAvatar` `PRBadge` `StatusBadge` `NumericInput` `RPESlider` 无人使用 |

### 2.7 字体素材（`docs/design/fonts-staging/`）

已就位、**尚未接入任何 target 或 SPM 资源声明**：

| 文件 | 实测 name / fvar |
|---|---|
| `Archivo-VF.ttf`(643 KB) | 变量字体，轴 `wght` 100–900（默认 600）、`wdth` 62–125（默认 100）。**name(1) family = `Archivo SemiBold`**，typographic family(16) = `Archivo`。9 个 named instance，PostScript 名前缀是 **`ArchivoRoman-`**：`ArchivoRoman-Thin/ExtraLight/Light/Regular/Medium/SemiBold/Bold/ExtraBold/Black` |
| `IBMPlexSans-VF.ttf`(525 KB) | 变量字体，`wght` 100–**700**（无 800/900）、`wdth` 75–100。family = `IBM Plex Sans`，named instance PS 名 `IBMPlexSans-Thin…Bold` |
| `IBMPlexMono-{Regular,Medium,SemiBold,Bold}.ttf` | 四档 static。PS 名 `IBMPlexMono-Regular` / `-Medium` / `-SemiBold` / `-Bold` |

⚠️ 与口头描述不符：Archivo 的 named instance PostScript 名是 `ArchivoRoman-ExtraBold` / `ArchivoRoman-Black`，**不是** `Archivo-ExtraBold` / `Archivo-Black`。以实测为准。

---

## 3. 实施范围与分层

五层顺序执行，每层跑通再进下一层。**每层结束都把新发现的冲突追加进 `docs/design/UI-REFRESH-CONFLICTS.md`**。

### W0 — 令牌与字体基建

**目标**：换掉调色板、装上真字体、把动效常量变成可复用令牌，并让 DesignSystem 测试改跟新基准。

改动文件：

- `Modules/DesignSystem/Sources/DesignSystem/Tokens/Colors.swift` — 重写。保留 `Color(light:dark:)` 构造器。`Color.MeetPR` 命名空间改为黑金令牌（下表），旧的 `brandRed` / `brandRedPress` / `brandRedSoft` / `surface1-3` / `fgPrimary-Disabled` 等**保留为 deprecated 别名指向新令牌**，避免 W0 一提交就全仓库红。等 W2–W4 逐屏迁完，最后一层再删别名。
- `Modules/DesignSystem/Sources/DesignSystem/Tokens/Typography.swift` — 重写。字号阶梯 + `Font.MeetPR` 三族（display / mono / body）改走 `Font.custom(_:size:)`。
- 新增 `Modules/DesignSystem/Sources/DesignSystem/Tokens/MeetPRFontFamily.swift` — 集中放 PostScript 名常量 + 取字体的兜底逻辑（自定义字体取不到时回退 `Font.system`，保证 SPM preview / `swift test` 不炸）。
- `Modules/DesignSystem/Sources/DesignSystem/Tokens/Spacing.swift` / `Radius.swift` — 改成设计系统的四档圆角与 4pt 基准间距。
- `Modules/DesignSystem/Sources/DesignSystem/Tokens/Motion.swift` — 重写为动效令牌全集（见 §附录 A.0）。
- 字体文件：把 `docs/design/fonts-staging/*.ttf` **移动**到 `MeetPR/Resources/Fonts/`（git mv，别复制留两份）。同步文件夹机制会自动纳入 target，**不需要改 pbxproj**。
- `MeetPR/Info.plist` — 新增 `UIAppFonts` 数组，列出 6 个文件名（`Fonts/Archivo-VF.ttf` 这类带子目录的路径在 iOS 上不可靠，**用纯文件名**，Xcode 会把资源平铺进 bundle 根；构建后用 `xcrun simctl` 或运行时 `UIFont.familyNames` 自检一次）。
- 测试：`Modules/DesignSystem/Tests/DesignSystemTests/{ColorsTests,TypographyTests,SpacingTests,RadiusTests,MotionTests}.swift` 全部改跟新令牌基准；新增一条「自定义字体已注册」的运行时断言（`UIFont(name:size:) != nil`，`#if os(iOS)` 包起来，注意 SPM 单测跑在 macOS host，iOS-only 断言会静默跳过 —— 这条断言放进 `MeetPRTests/` 的 xcodebuild 测试里更靠谱）。

颜色令牌对照（暗色 = 默认；亮色作用域一并落库但本波不接入口）：

| 语义 | 暗色 | 亮色 |
|---|---|---|
| `goldCTA` | `#FFB800` | `#FFB800` |
| `gold500`（点缀 / 进行中 / 图标） | `#F5A623` | `#D97706` |
| `gold400` / `gold300` / `gold200` / `gold700` | `#FBBF3E` / `#FFD27A` / `#FFE28E` / `#B87814` | `#F59E0B` / — / `#FEF3C7` / — |
| `goldGradient`（进度条，左→右） | `#E08F0F → #FFC93C` | `#D97706 → #F5B93C` |
| `bgBase` / `bgInset` / `bgStack` | `#0A0A0C` / `#101014` / `#121217` | `#F5F6F8` / `#F3F4F6` / `#EEF0F3` |
| `surfaceCard` / `surfaceElevated` / `surfaceKey` | `#141416` / `#161618` / `#1C1C20` | `#FFFFFF` / `#FFFFFF` / `#F3F4F6` |
| `borderHairline` / `borderSubtle` / `borderDefault` / `borderStrong` | `#17171A` / `#1E1E22` / `#262629` / `#2E2E32` | `#E9EBEE` / `#E5E7EB` / `#E5E7EB` / `#D1D5DB` |
| `textPrimary` / `Secondary` / `Tertiary` / `Muted` / `Faint` / `Disabled` | `#FFFFFF` / `#B8B8BE` / `#A1A1A6` / `#8A8A90` / `#7A7A80` / `#55555C` | `#111827` / `#4B5563` / `#6B7280` / `#6B7280` / `#9CA3AF` / `#9CA3AF` |
| `success` / `danger` / `chartLine` | `#5E9E78` / `#E5484D` / `#DCE3EA` | `#15803D` / `#E5484D` / `#9AA4B0` |
| `inkOnGold` | `#141414` | `#141414` |
| `ctaBg` / `ctaText` | `goldCTA` / `inkOnGold` | `#111827` / `#FFFFFF` |

字体族映射：

| 用途 | 族 | iOS 取法 |
|---|---|---|
| display（标题、大数字，800/900） | Archivo | `Font.custom("ArchivoRoman-ExtraBold", size:)` / `"ArchivoRoman-Black"` |
| mono（数据、标签、时间戳） | IBM Plex Mono | `"IBMPlexMono-Regular" / "-Medium" / "-SemiBold" / "-Bold"` |
| body 西文 | IBM Plex Sans | `"IBMPlexSans-Regular" / "-Medium" / "-SemiBold" / "-Bold"`（VF named instance） |
| **中文（全部）** | **系统苹方 PingFang SC** | 不打包中文字体；`Font.custom(...)` 对中文字形会自动回退到系统中文字体，验收时逐屏确认中文没有变形/回退成宋体 |

变量字体取值策略：**先试 named instance 的 PostScript 名**（上表）。若真机/模拟器上 `UIFont(name:size:)` 返回 nil 或拿到的是默认实例（Archivo 默认是 SemiBold 600，肉眼比 800 细），再用 `fonttools` 抽 static 实例落地：

```bash
pip install fonttools
fonttools varLib.instancer MeetPR/Resources/Fonts/Archivo-VF.ttf wght=800 wdth=100 -o Archivo-ExtraBold.ttf
fonttools varLib.instancer MeetPR/Resources/Fonts/Archivo-VF.ttf wght=900 wdth=100 -o Archivo-Black.ttf
```

抽出来的 static 文件替换掉 VF 进 bundle，并把 PostScript 名同步改到 `MeetPRFontFamily.swift`。**走到这一步要在 CONFLICTS 里记一条**，说明为什么换了打包形态。

### W1 — DesignSystem 组件与动效修饰器

新增（建议放 `Modules/DesignSystem/Sources/DesignSystem/Motion/`）：

- `PressScaleButtonStyle.swift` — 替换现有 `MeetPRPressOpacityButtonStyle`：`scaleEffect(isPressed ? 0.97 : 1)` + `opacity(isPressed ? 0.9 : 1)`，`.animation(.easeInOut(duration: 0.12), value:)`。**全 app 所有可点元素统一用它**。
- `RiseInModifier.swift` — 错峰上浮：子项 `opacity 0→1` + `offset y 72→0` + `scaleEffect(y: 0.88→1, anchor: .top)`，`duration 0.5` easeOutCubic（`.timingCurve(0.215, 0.61, 0.355, 1)` 或 `.easeOut` 近似均可，**视觉结果一致即可**），起始延迟 20ms，逐项 stagger 40ms（收纳药丸态入场用 340ms / translateY -9 / scaleY 0.62→1）。
- `GoldGlowModifier.swift` — 呼吸发光：4.2s 循环，`shadow` 在 `(radius 8, opacity .24) ↔ (radius 11.5, opacity .32)` 之间脉动 + 1px 金描边 `.5 ↔ .62`。只给「进行中」元素。建议 `PhaseAnimator` 或 `.repeatForever(autoreverses: true)`。
- `ShimmerOverlay.swift` — 光泽扫过：宽度 55% 的斜向亮带（`skewX -12°`，用 `.rotationEffect` + `.scaleEffect` 或 `LinearGradient` + `.mask` 实现），`x: -160% → 340%`，4.5s 循环，`ease-in-out`，其中 0→30% 走完位移、30%→100% 停在终点。**只给页面最高层级 CTA**（开始训练 / 开始第一组 / 完成·回到今日 / 查看详细报告 / ＋排新计划）。
- `RollUpCollapse.swift` — 收纳卷折（动作完成后收成一行）：980ms，`perspective(820)` + `rotateX` 在 `0 → -34 → -7 → -38 → -11 → -44 → -74` 度之间抖动，`translateY 0 → -72%`，`scaleY 1 → 0`，容器高度同时 `h → 48pt`（`cubic-bezier(.36,.05,.3,1)`），触觉序列 `[8,60,8,60,10,60,14]` ms。SwiftUI 用 `KeyframeAnimator` 最贴近。
- `CelebrationEffects.swift` — 完成庆祝三件套（bloom / 盖章 / 火花），参数见 §附录 A.6。

改造现有组件（`Modules/DesignSystem/Sources/DesignSystem/Components/`）：

- Buttons：`BrandPrimaryButton` 改成样机的金色实体 CTA（`#FFB800` 底 + `#141414` 字 + 顶部内高光 + 底部暗金收边 + 金投影 + 可选 shimmer + 可选副行）；`PrimaryButton` / `SecondaryButton` 改成暗色描边卡片按钮；`DangerButton` 走 `danger`；`IconButton` 改成 40/44pt 圆形 `surfaceCard` 底。全部换 `PressScaleButtonStyle`。
- Cards：`Card` → `surfaceCard` `#141416` + `radiusCard 16`，**无阴影靠层级**；新增 `accent`（左侧 3pt 金色纵条）与 `inset`（`bgInset` `#101014` + `radiusChip 10`，用于卡中卡「教练备注」）两种变体；`ElevatedCard` 走 `surfaceElevated`。
- Badges：`StatusBadge` 改成 mono 11px/700、`radiusPill`、四种 tone（gold / success / danger / neutral），对齐 `components/core/Badge.d.ts`；`PRBadge` 改成 10px mono + 金描边胶囊。
- Charts：`E1RMChart` 改成白色 2.5px 折线 + 金色面积渐变（`#F5A623` 0.22 → 0.04 → 0）+ 金色端点 r=4.5（描边 `surfaceCard` 1.5）+ 9.5px mono 轴标；`Sparkline` 同色系简化版；`ProgressSegments` 改 `goldGradient`。新增容量/强度双轴图所需的柱 + 线样式（见 §附录 A.5）。
- Inputs：`MeetPRTextField` / `NumericInput` / `RPESlider` 按 §附录 A.4 的组记录页规格改（±48pt 圆钮、54pt 数值区、RPE 11 档刻度条）。
- Labels / Lists / Sets / Avatars / Brand：`Eyebrow` 走 mono 11–12px + `letterSpacing .05em`；`MeetPRListRow` 改成 `surfaceCard` 分组卡内的 14×16 行 + 1px `borderSubtle` 分隔 + 灰 chevron；`SetReadOnlyCell` 对齐 `components/core/SetTable.d.ts` 的五列（`# / 重量 / 次数 / RPE / 状态`）；`MeetPRMark` 改成 Archivo 900、`letter-spacing -0.11em`、描边+实心叠字的 MEETPR 字标。
- `Demo/DesignSystemDemo.swift` 同步更新（它有测试守着）。

参考实现契约在 `docs/design/meetpr-design-skill/components/core/*.d.ts` 与 `*.prompt.md`，**照着 props 语义做，不用照抄 React 结构**。

### W2 — 学员端逐屏

按屏对照 §附录 A 施工。文件（相对 `Modules/StudentKit/Sources/StudentKit/`）：

1. `StudentRootView.swift` — tab bar（83pt 高、顶边 1px `borderHairline`、`bgBase` 底、图标 24pt、标签 11pt、选中 `gold500` 未选中 `#7A7A80`）、`.tint` 换金色。
2. `Features/Dashboard/DashboardView.swift` + `StudentNotificationComponents.swift` + `NotificationCenterSheet.swift` + `EvaluationCompletedCard.swift` + `DashboardProfileMetricsView.swift` + `E1RMTrendRow+Sparkline.swift`
3. `Features/TodayWorkout/TodayWorkoutView.swift` + `TrainingCalendarView.swift` + `CoachNoteDisplay.swift` + `RestTimerOverlay.swift` + `RestTimerExplanationView.swift` + `SetVideoUploadIndicator.swift` + `DayCompletionBanner.swift` + `PRBanner.swift` + `SlideToCompleteButton.swift`
4. `Features/TodayWorkout/SetEntrySheet.swift` + `SetEntryRPEScale.swift` + `Features/VideoUpload/VideoAttachmentSection.swift`
5. `Features/TodayWorkout/SessionSummaryView.swift`（训练回顾）
6. `Features/TrainingHistory/TrainingHistoryView.swift` + `VolumeIntensityChart.swift` + `HistoryEntriesView.swift` + `Features/MyProfile/GrowthCurveView.swift`
7. `Features/FeedbackInbox/{FeedbackInboxView,FeedbackDetailView,StudentFeedbackVideoPlayerView}.swift`
8. `Features/MyProfile/MyProfileView.swift` + `ProfileCardsSection.swift`(仅 `ProfileCardEditView`) + `RestTimerPreferenceRow.swift` + `RestTimerSettingsView.swift`（要先 `import DesignSystem`） + `AccountSecuritySheets.swift` + `ExportDataSheet.swift`
9. `Features/Readiness/ReadinessCheckinSheet.swift`（无样机，令牌套用）

### W3 — 教练端逐屏

1. `CoachRootView.swift`（5 tab bar，同上规格，图标 23pt、标签 10pt、宽 60pt）
2. `Features/Dashboard/CoachDashboardView.swift`
3. `Features/StudentRoster/{StudentRosterView,StudentRosterRow,TriageStripSection}.swift`
4. `Features/StudentDetail/StudentDetailView.swift` + `Overview/` `Execution/` `Videos/` `Growth/` `Feedback/` 各段 + `CoachDayDetailView` + `CoachVideoPlayerView` + `FeedbackComposerView`
5. `Features/PlanningWorkspace/{CoachPlanningHomeView,PlanningWorkspaceSections}.swift`
6. `Features/Receiving/{CoachReceivingView,StudentPendingVideosView,VideoFeedbackDetailView}.swift` + `Features/BindQueue/{BindRequestCard,StudentOnboardingProfileView,AcceptBindRequestSheet}.swift`
7. `Features/MyProfile/CoachMyProfileView.swift` + `Features/InviteCodes/InviteCodesView.swift`
8. `Planning/Views/*`（向导 19 个原子件，**无样机，令牌套用**：把 `Card` / 按钮 / 输入件换成新 DS 组件即可，不重排版式）
9. `Features/Chat/*` + `Modules/ChatUI/Sources/ChatUI/*`（聊天气泡按 §附录 A.7）

### W4 — AppShell（登录 / 注册）

- `Modules/AppShell/Sources/AppShell/Auth/LoginView.swift` · `SignupView.swift` · `AuthSecureField.swift` · `AuthFlowView.swift`
- `Modules/AppShell/Sources/AppShell/RootView.swift` 的 `.authenticating` 加载态（「正在验证会话…」）
- `Modules/AppShell/Sources/AppShell/AnalyticsPrivacyNotice.swift`
- 连带 StudentKit 的入场前屏（无样机，令牌套用）：`Features/Bind/{BindGateView,EnterCodeView,PendingBindView}.swift` · `Features/Onboarding/*`

⚠️ **样机里没有登录/注册页**。W4 只做「令牌套用 + 组件替换」：黑金底、Archivo 大标题、金色主 CTA、`surfaceCard` 输入框、`borderDefault` 描边。**不臆造新版式、不改字段、不改流程**。

---

## 4. 约束与红线

1. **一比一还原，动效也要还原。** 以暗色样机为像素基准：结构 / 间距 / 层级 / 色值 / 字号 / 圆角一比一。动效全套还原：按压 `scale(.97)` 120ms、进场错峰上浮 500ms easeOutCubic（stagger 40–90ms）、金色 glow 呼吸 4.2s、主 CTA 光泽扫过 4.5s、完成庆祝（bloom + 盖章 + 火花粒子）、收纳卷折。本卡给了 SwiftUI 实现建议（`ButtonStyle` + `scaleEffect`、`PhaseAnimator`、`KeyframeAnimator`、`withAnimation`），**允许换等效实现，但视觉结果必须一致**。
2. **只还原视觉与动效，不改功能。** 导航与 tab 结构不动（学员 4 tab、教练 5 tab，见 §2.3 / §2.4，已核实与样机一致）。业务逻辑、数据流、Repository、ViewModel 行为、BindGate 与评估封存逻辑（`BindGateViewModel.swift:134` / `AcceptBindRequestSheet.swift:60`）一律不碰。不新增/删除屏幕，不改路由。
3. **本波只做暗色主题。** 亮色令牌一并落进 `Colors.swift`（用现有 `Color(light:dark:)` 双态构造，作用域预留），但**不做主题切换入口**，`MeetPR/Sources/MeetPRApp.swift:286` 的 `.preferredColorScheme(.dark)` 保持不动。
4. **严禁伪造数据。** 样机里出现、但当前分支没有数据源的内容（聊天泡未读数、实时训练状态、连续训练次数等），**不造假数据、不硬编码占位文案**。处理方式：跳过该元素，并在 `docs/design/UI-REFRESH-CONFLICTS.md` 逐条登记。遇到任何「一比一还原 vs 现有功能」的新冲突同样**只记录不擅决**。
5. **CONFLICTS 文件格式**（Codex 负责创建并持续追加，模板见 §附录 B）：

   ```markdown
   ### C-NN 一句话标题
   - **样机位置**：文件名 + 屏名 + 行号区间
   - **样机内容**：客观描述（含色值/字号/文案）
   - **现状缺口**：代码里对应的位置与缺什么（数据源 / 组件 / 交互形态）
   - **建议选项**：A / B / C，各写一句代价
   - **状态**：待 David 拍板 | 已跳过 | 已还原
   ```

6. **工程纪律**
   - `swiftlint --strict` 零告警（配置 `.swiftlint.yml`，line_length warning 100 / error 120，`sorted_imports` 开着）。
   - 现有测试全绿：每个 `Modules/*` 跑 `swift test --package-path`，加 `xcodebuild -scheme MeetPR test`。
   - DesignSystem 相关测试同步更新为新令牌基准（`ColorsTests` 218 行是逐色 RGB 断言，必然要重写）。
   - **不 commit、不 push**，做完停在工作区改动态。
   - 改 `MeetPR.xcodeproj` 结构须用 ruby `xcodeproj` gem，**别手改 pbxproj 复杂结构**。本波大概率不需要动它（同步文件夹机制，见 §2.1）；`Info.plist` 是纯 XML 文本，可以直接编辑。
   - 遵守 `AGENTS.md` §Swift & SwiftUI 实操约定：`foregroundStyle` 不是 `foregroundColor`、`clipShape(.rect(cornerRadius:))` 不是 `cornerRadius()`、`onChange` 必须两参或零参、拆 view 用独立 `struct` 不用 computed property、禁 `AnyView`、禁 `UIScreen.main.bounds`、SwiftUI 里不用 `UIColor`。
7. **与 `AGENTS.md` 的一处已知张力**：该文件 §SwiftUI 约定写「不硬编码字号，用 Dynamic Type；不硬编码 padding / stack spacing」。本波要求像素级还原，二者冲突。**本卡的裁决：所有数字集中进 `Modules/DesignSystem/.../Tokens/`，视图侧只引令牌，不散落字面量**；Dynamic Type 缩放本波按样机固定值处理。这条要作为可访问性欠账写进 CONFLICTS（C-06），等 David 拍板是否补 `@ScaledMetric`。
8. **无样机的屏幕只做令牌套用**（见 §附录 B C-07 清单），**不臆造版式**。

---

## 5. 验收标准

### 5.1 机器闸门

```bash
# 1. 每个 SPM 包单测（CI 同款循环）
for package in Modules/*; do
  [ -f "$package/Package.swift" ] || continue
  if [ -d "$package/Tests" ]; then swift test --package-path "$package" --parallel; \
  else swift build --package-path "$package"; fi
done

# 2. 模拟器 Debug build + 全量单测
xcodebuild -project MeetPR.xcodeproj -scheme MeetPR \
  -destination "platform=iOS Simulator,name=iPhone 17" test

# 3. Lint（CI 用 docker 镜像跑，本地有 swiftlint 直接跑）
swiftlint --strict
```

三条全绿才算完。

### 5.2 逐屏对照走查（人工，模拟器）

Demo 构建**必须显式指定 configuration**：学员端 = `MeetPR-DemoStudent`（configuration `DemoStudent`），教练端 = `MeetPR-Demo`（configuration `Demo`）。

把样机 HTML 在浏览器里打开（需要同目录的 `support.js`），左右对照：

| # | App 屏幕 | 样机对照位置 |
|---|---|---|
| S-1 | 学员「今日」tab（`DashboardView`） | `MeetPR 学员端.dc.html` L48-132（`isToday`），含顺延后态 L125-129 |
| S-2 | 学员「训练」tab 头部 + 日历（`TodayWorkoutView` + `TrainingCalendarView`） | 同上 L134-173（`isTraining` 顶部 + 周/月日历） |
| S-3 | 学员「训练」焦点卡 + 动作表（hero card / SetTable） | 同上 L174-279 |
| S-4 | 学员「训练」完成按钮 | 同上 L281-287（长按进度条） |
| S-5 | 组记录页（`SetEntrySheet`） | 同上 L440-515（含杠铃片、±钮、RPE 刻度、视频区、底部双按钮） |
| S-6 | 数字键盘弹层（`SetEntrySheet` 数值输入） | 同上 L516-531 |
| S-7 | 完成庆祝（`DayCompletionBanner` / 完成态） | 同上 L581-605 |
| S-8 | 训练回顾（`SessionSummaryView`） | 同上 L534-579 |
| S-9 | 学员「成长」tab（`TrainingHistoryView`） | 同上 L291-384 |
| S-10 | 学员「我的」tab（`MyProfileView`） | 同上 L386-429 |
| S-11 | 学员 tab bar | 同上 L433-438 |
| S-12 | 反馈归档页（`FeedbackInboxView`） | 同上 L617-639 |
| S-13 | 聊天页（`ChatUI.ConversationView`） | 同上 L641-661 |
| S-14 | 顺延确认弹窗 | 同上 L607-615 |
| C-1 | 教练「今日」tab（`CoachDashboardView`） | `MeetPR 教练端.dc.html` L40-70 |
| C-2 | 教练「学员」tab（`StudentRosterView`） | 同上 L72-92 |
| C-3 | 教练「编排」tab（`CoachPlanningHomeView`） | 同上 L94-107 |
| C-4 | 教练「接收」tab 三段（`CoachReceivingView`） | 同上 L109-151 |
| C-5 | 教练「我的」tab（`CoachMyProfileView`） | 同上 L153-167 |
| C-6 | 教练学员详情五段（`StudentDetailView`） | 同上 L169-217 |
| C-7 | 教练 tab bar | 同上 L221-228 |
| A-1 | 登录页（`LoginView`） | **无样机** — 只验令牌套用是否统一（黑金底 / Archivo 标题 / 金色 CTA / 卡片输入框） |
| A-2 | 注册页（`SignupView`） | **无样机** — 同上 |

走查每屏至少确认：底色层级、卡片圆角、主标题字体与字号、mono 数据字体、金色只出现在「行动 / 进行中」、状态点颜色语义（绿=完成 / 金=进行中 / 红=未完成）、按压有 scale 反馈、进场有错峰上浮。

### 5.3 交付物

- `docs/design/UI-REFRESH-CONFLICTS.md` **存在**，且完整列出所有跳过项与冲突项（附录 B 的初稿条目全部落进去，加上施工中新发现的）。
- 工作区改动未 commit、未 push；交付时给出 `git status --short` + 分层改动摘要。

---

## 附录 A — 从样机提炼的屏幕级视觉规格

单位：样机是 CSS px，iOS 一律按 **1px = 1pt** 对应（样机画布 390×844 = iPhone 14/15/16 逻辑尺寸）。

### A.0 全局

**画布**：390×844，底色 `#0A0A0C`。状态栏 44pt（系统绘制，App 不管）。tab bar 83pt。

**页面内边距**：主 tab 屏 `padding: 6pt 20pt 28pt`，纵向 `gap` 13–15pt（今日 15、训练 13、成长 14、我的 14）。组记录页 `12pt 16pt`。聊天/归档页 `16–18pt`。
⚠️ 令牌 `--page-x: 16px` 与主 tab 实测 20pt 不符 —— **以样机实测为准**（见 C-05）。

**字号阶梯（实测全集，令牌里都要有）**：10 / 11 / 12 / 13 / 14 / 15 / 16 / 17 / 18 / 19 / 20 / 21 / 22 / 24 / 26 / 27 / 28 / 30 / 32 / 34 / 38 / 46 / 54。
设计令牌文件 `tokens/typography.css` 只列了 14 档（10–54），样机实际还用到 17/19/20/21/24/26/28/32/38，**缺的必须补**。

**圆角**：10（chip / 卡中卡） · 12（控件、内表、列表行、键盘键） · 16（卡片） · 20（弹窗、底部弹层） · 999（CTA、标签、日期胶囊）。

**间距**：4 / 8 / 12 / 16 / 20 / 24。卡片内边距 14–16，卡片间距 12–14，分组间距 8。最小触区 44pt。

**边框**：暗色 1px `#1E1E22`–`#262629`；选中态 1.5px 金描边 `#F5A623`；hairline `#17171A`。

**金色 CTA 解剖**（`guidelines/cta-anatomy.html`）：底 `#FFB800`，字 `#141414` 800 weight，
`box-shadow: inset 0 1.5px 0 rgba(255,255,255,.55), inset 0 -2px 3px rgba(120,60,0,.25), 0 8px 26px rgba(245,166,35,.38)`。
副行用 mono 12pt/700，色 `rgba(20,20,20,.72)`，`letter-spacing .06em`。

**动效令牌全集**（源：`tokens/effects.css` + 样机 `<script>`）：

| 名称 | 参数 |
|---|---|
| 按压 `.pb` | `scale(.97)` + `opacity .9`，120ms ease |
| tab 按压 `.tb` | `scale(.9)` |
| 屏切换 `.scrn` | `opacity 0→1` + `translateY 8→0`，280ms `cubic-bezier(.2,.7,.2,1)` |
| 遮罩淡入 `.ov` | `opacity 0→1`，200ms ease |
| 底部弹层 `.sh` | `translateY 100%→0`，340ms `cubic-bezier(.2,.8,.2,1)` |
| 错峰上浮 `riseIn` | 每个子项：`opacity 0→1` + `translateY 72→0` + `scaleY .88→1`，500ms easeOutCubic（`1-(1-p)³`），起始 20ms，stagger 40ms |
| 药丸入场 `pillIn` | 340ms easeOutCubic，`translateY -9→0` + `scaleY .62→1` |
| 收纳卷折 `rollUp` | 980ms；`perspective(820)` `rotateX: 0/-34/-7/-38/-11/-44/-74°` @ offset 0/.15/.32/.5/.67/.84/1；`translateY: 0/-3/-17/-31/-46/-60/-72%`；`scaleY: 1/.9/.72/.52/.33/.16/0`；`opacity 1→.9@.84→0`；容器高度 `h→48pt`，`cubic-bezier(.36,.05,.3,1)`；触觉 `[8,60,8,60,10,60,14]` |
| 呼吸发光 `glow` | 4.2s ease-in-out 无限循环；`0 0 0 1px rgba(245,166,35,.5), 0 0 16px 2px rgba(245,166,35,.24)` ↔ `0 0 0 1px rgba(245,166,35,.62), 0 0 23px 3px rgba(245,166,35,.32)`。变体 `glow2` 描边 2px；`glow-w` 叠加 CTA 内高光 |
| 光泽扫过 `shimmer` | 4.5s ease-in-out 无限；带宽 55%，`linear-gradient(90deg, transparent, rgba(255,224,160,.42), transparent)`，`skewX(-12°)`，`translateX: -160% → 340% @30% → 停到 100%` |
| E1RM 指示点 | `width` / `background` 0.25s ease |

### A.1 学员「今日」（样机 L48-132）

自上而下（纵向 gap 15）：

1. **品牌行**：MEETPR 字标（Archivo 900 / 16pt / `letter-spacing -0.11em` / 描边 5px 白 + 实心 `#141414` 叠字，`R` 额外 `margin-left: -0.13em`）+ 日期 mono 12pt `#8A8A90` `letter-spacing .06em`，gap 10。
2. **大标题行**：`W1D4` 类日标签 Archivo 800 / **54pt** / `line-height .9` / 色 `#f3f3f6`，`text-shadow: 0 2px 0 #000, 0 3px 3px rgba(0,0,0,.55), 0 -1px 0 rgba(255,255,255,.22)`。休息日态：`W1` 用 `#6A6A70` + 右侧「休息日」胶囊（底 `#1B1B1E`，边 1px `#2A2A2E`，字 mono 12/700 `#9A9AA0`，`padding 5×11`，`radius 999`）。
   右侧 **44×44 圆形按钮**（底 `#141416`），内 21pt 消息气泡 stroke 图标 `#EDEDED` 2px；右上角红点徽章 `#FF3B30`，`min-width 15`，`height 15`，`radius 8`，字 11pt/700 白，mono。
3. **本周进度条**：4 段，`height 4`，`radius 2`，gap 5，flex-grow 按完成度。
4. **教练反馈卡**（可折叠）：`surfaceCard #141416`，**左边框 3pt `#F5A623`**，`radius 12`，`padding 14×16`。折叠态背后有两层堆叠影（`#101014`/边 `#1C1C20` 与 `#121217`/边 `#202024`，分别下偏 11/5pt）。头部：7pt 金圆点 + 「教练反馈」13/700 + 「N 条未读」胶囊（底 `#F5A623`，字 `#141414` mono 10/700，`padding 1×6`）+ 「· 周日」12pt `#7A7A80`。正文 14pt/1.55 `#E4E4E6`，两行截断。底部「展开全部 N 条反馈」12pt `#8A8A90` + 13pt chevron。
   展开动效：预览文字 50ms 淡出 → 逐条 `stagger 30ms × 200ms`（`translateY -8→0`）→ 箭头 260ms 旋 180° → 容器高度 380ms easeOutCubic **带 3pt 正弦回弹**（进度 62% 之后）。收起 280ms。
5. **本周行**：左「本周」mono 13pt `#B8B8BE`；右图例 mono 11pt `#8A8A90`：「深蹲·卧推·硬拉」`#6A6A70` + 1×9 分隔条 `#2A2A2E` + 实心 6pt 金点「该日有」+ 空心 6pt（1px `rgba(245,166,35,.5)`）「该日无」。
6. **周历 7 格**：未选中 `#141416` / `radius 12` / `padding 9pt 0`；选中 `rgba(245,166,35,.12)` + **1.5px `#F5A623`** + `radius 999` / `padding 8pt 0`。星期文字 11pt（选中白，未选中 `#8A8A90`），下方 3 个 6pt 状态点（gap 3，高度槽 7pt，`margin-top 5`）。
7. **两张指标卡**（gap 11）：
   - 体重卡：`#141416` / `radius 16` / `padding 14×16`；标题 11pt 白 + 13pt 图标；数值 Archivo 800 / 24pt，单位 13pt/600 `#8A8A90`。
   - 距比赛卡：底 `linear-gradient(155deg, rgba(245,166,35,.13), #141416 62%)` + `inset 0 0 0 1px rgba(245,166,35,.3)`；数值 24pt Archivo 800 `#F5A623` + `text-shadow 0 0 14px rgba(245,166,35,.45)`。
8. **E1RM 卡片轨**（横向 snap，gap 10，每张 100% 宽）：卡 `#141416` / `radius 16` / `padding 14×15`。标题 mono 12pt（动作名 `#B8B8BE`/600，其余 `#8A8A90`）。数值 Archivo 800 / **30pt** / `line-height .9`，单位 13pt `#8A8A90`；右侧 delta mono 14/700 `#F5A623`。折线图 `viewBox 0 0 320 70`，高 48pt：面积渐变 `#F5A623` 透明度 .28→.06@55%→0，折线 **白色 2.5px** round cap，末点 `circle r=3.5 #F5A623`。下方页码点：宽度可变（当前更宽）、高 6pt、`radius 999`。
9. **主 CTA**：`#FFB800` / `radius 999` / `padding 13×17`，两行居中（gap 4）。首行 16pt/800 `#141414` + 13pt 播放三角；副行 mono 12pt/700 `rgba(20,20,20,.72)` `letter-spacing .06em`（内容 = 当日主项，如「蹲 · 推 · 拉」）。带 `shimmer`。
   **按下态**（130ms）：`scale(.97)` + `brightness(1.06)` + 阴影换成 `inset 0 1.5px 0 rgba(255,255,255,.55), inset 0 -2px 3px rgba(120,60,0,.25), 0 0 0 1.5px rgba(255,210,110,.9), 0 0 36px 9px rgba(245,166,35,.6), 0 0 74px 16px rgba(245,166,35,.28)`；首行文字 opacity .6、副行 .45；触觉 10ms。
   **松手转场 `morphLaunch`**：触觉 `[16,40,26]` → 当前屏 200ms 二次曲线 `translateY +26` + 淡出 → 生成一个金描边幽灵矩形（底 `rgba(15,15,18,.97)`，边 1px `rgba(245,166,35,.8)`，`shadow 0 0 26px rgba(245,166,35,.18)`，`radius 28`）→ 140ms 后切屏 → 幽灵 420ms easeOutCubic 从 CTA 位形变到训练页 hero 卡位、`radius 28→16` → 新屏 280ms 淡入 → hero 卡子项 `stagger 55ms × 220ms`（`translateY 9→0`）→ 幽灵 200ms 淡出移除。
10. **文字链**「顺延一天」13pt `#9A9AA0` + 13pt chevron，居中。
11. **顺延后态**：绿色提示条（底 `rgba(94,158,120,.1)`，边 1px `rgba(94,158,120,.32)`，`radius 16`，`padding 13×15`，18pt 对勾 `#5E9E78`，文字 13pt `#CDE9D3`/1.45，粗体部分 `#EDEDED`）+ 「今日休息」卡（`#141416` / `radius 16` / `padding 17` / 16pt 700 `#8A8A90` 居中）+ 「撤销顺延」13pt `#8A8A90` 下划线。
12. **休息日无训练**：`#141416` / `radius 16` / `padding 20` / 14pt 600 `#8A8A90` 居中「休息日 · 无训练安排」。

### A.2 学员「训练」（样机 L134-289）

- 顶部 MEETPR 字标 15pt；`W1D4` Archivo 800 / **20pt**；右侧两个 40×40 圆钮（`#141416`）：18pt 重置图标 `#C8C8CC`、18pt 消息图标 + 红徽章（16×16，9pt 字）。
- **日历折叠条**（滚动收起时）：`position: sticky`，`#141416` + 1px `#202024` + `radius 12` + `padding 11×14` + `shadow 0 6px 16px rgba(0,0,0,.35)`；左 mono 13pt `#EDEDED`，右 11pt `#6A6A70`「上滑到顶展开」+ 13pt 上箭头。收起阈值：滚动 > 56pt 且可滚动余量 > 200pt 时收，滚动 < 6pt 时展开。
- **周视图 7 格**：每格 `#141416` / `radius 12` / **高 44pt**；星期 10pt，日期 mono 13/700；右上 5pt 状态点（绿 `#5E9E78` / 金 `#F5A623` / 红 `#E5484D`）；今日格 `#1B1B1E` + 1.5px `#F5A623`；非训练日文字降到 `#55555C`/`#6A6A70`。
- **月视图**：7 列网格 gap 5，格高 46pt，`radius 10`，表头 mono 10pt `#6A6A70`；图例行 mono 10pt（已完成 / 进行中 / 未完成 三个 6pt 点）。
- **Hero 焦点卡**：`#0F0F12`，边 1px `#2A2A2E`（**左边不描边**），`radius 0 16 16 0`，`padding 16`；左侧 3pt 竖条 `linear-gradient(180deg,#FFD470,#FBBF3E,#F5A623)`。
  - 列表态（未开始）：标题「今日训练」Archivo 800 / 22pt；副行 mono 12pt `#A1A1A6`「共 N 个动作 · M 组」；动作行 `#141416` + 1px `#1E1E22` + `radius 12` + `padding 11×13`：序号方块 22×22 `radius 7` 底 `rgba(245,166,35,.12)` 字 mono 11/700 `#F5A623`，名称 14/700 白，右侧计划 mono 12pt `#A1A1A6`；底部「开始第一组」金 CTA（`radius 999` / `padding 15` / 16pt 800，带 shimmer）。
  - 记录态：动作名 Archivo 800 / 22pt；`上次…·最佳…` mono 12pt `#A1A1A6`；状态胶囊「当前」mono 11/700 底 `rgba(245,166,35,.16)` 字 `#F5A623` `padding 3×11`（完成态换 `rgba(94,158,120,.16)` / `#5E9E78`）；重量 Archivo 800 / **54pt** / `line-height .85` + `KG` mono 16/700 `#8A8A90` + 右侧 `×N` 20pt/700；目标 RPE 行：mono 11pt `#7A7A80` + Archivo 800 20pt + `/ 10` 12pt；教练备注卡 `#101014` / `radius 10` / `padding 10×12`（标签 mono 11pt `#7A7A80`，正文 12pt `#C4C4C8`/1.5）；按钮行：金 CTA「记录此组」(flex 1, `radius 999`, `padding 15`, 15pt/800) + 52pt 宽方形副钮（`#141416` + 1px `#2E2E32` + `radius 12` + 22pt 摄像机图标 `#A1A1A6`）。
  - 「开始第一组」转场：卡内子项 160ms 二次曲线淡出 + `translateY -10` → 卡高度 320ms easeOutCubic 过渡到新高度，新子项从进度 25% 起 `translateY 14→0` 淡入。
- **动作块**（每个动作一块，gap 13）：
  - 展开态：标题 Archivo 800 / 18pt；副行 mono 12pt `#A1A1A6`；右侧统计 mono 11pt（按状态着色）。表格容器 `#141416` / `radius 12`；表头 mono 10pt `#6A6A70` `letter-spacing .04em` `padding 9×15`，列宽 `# 24pt / 重量 flex1 / 次数 flex1 居中 / RPE flex1 居中 / 状态 70pt`；数据行 `padding 12×15` + 顶边 1px `#1E1E22`，序号 mono 13/700，重量 mono 15/700，次数与 RPE mono 15pt；状态区 gap 13：完成 17pt 对勾 `#5E9E78` 2.5px / 失败 16pt 叉 `#E5484D` 2.6px / 未记录 15pt 空心圆（1.5px `#4A4A50`）；摄像机 21pt（已传绿 `#5E9E78` / 失败红 / 未传 `#5E5E64`）。
  - 折叠药丸态：`#101014` + 1px `#1C1C20` + `radius 12` + `padding 12×14`：22pt 绿对勾圆底（`rgba(94,158,120,.14)`）+ 名称 14/700 `#C8C8CC` + 摘要 mono 11pt `#7A7A80` + 15pt chevron `#5A5A60`。展开→折叠走 `rollUp`（见 A.0）。
- **剩余提示**：虚线胶囊 1px dashed `#2A2A2E` + `radius 999` + `padding 16` + 15pt 时钟图标 + 14pt/600 `#6A6A70`。
- **长按完成按钮**（全部记录完后）：底 `#17120A`，边 1px `rgba(245,166,35,.5)`，`radius 999`，`padding 17`，`shadow 0 4px 20px rgba(245,166,35,.15)`，带 shimmer；内容 17pt 时钟 + 16pt/800 白字「长按 · 完成今日训练」+ `text-shadow 0 1px 2px rgba(0,0,0,.45)`。
  **进度填充**：绝对定位左起，宽度 0→100%，底 `linear-gradient(90deg,#E0951C,#FBBF3E)` + `shadow 0 0 22px rgba(245,166,35,.55)`；**按住 1100ms 完成**；按下瞬间 `scale(.96)` + 触觉 12ms；完成触觉 `[70,30,110]`；中途松手宽度 300ms `cubic-bezier(.4,0,.2,1)` 回 0。
  ⚠️ 现状是 `SlideToCompleteButton`（滑动完成）—— 交互形态不同，见 C-13。

### A.3 学员「成长」（样机 L291-384）

- 大标题「成长」Archivo 800 / **34pt** / `line-height .95`；说明 12pt `#7A7A80`/1.5。
- **每个主项一张 E1RM 卡**：`#141416` / `radius 16` / `padding 16`。头行：mono 12pt 标题 + 右侧区间选择胶囊（底 `#1B1B1E`，边 1px `#2E2E32`，`radius 999`，`padding 3 5 3 10`，mono 11pt `#D8D8DC` + 12pt 金 chevron）。数值 Archivo 800 / **38pt**，单位 15pt；delta mono 13/700 `#F5A623`。
  图 `viewBox 0 0 320 118`：Y 轴线 `x=46, y 18→84` `#3A3A40` 1px；X 轴线 `y=84, x 46→304`；中位虚线 `#1E1E22` `dasharray 3 4`；刻度文字 9.5pt mono（顶/底 `#A1A1A6`，中 `#6A6A70`）；面积渐变 `#F5A623` .22→.04@72%→0；折线白 2.5px；最佳点竖虚线 `#F5A623` 1px `dasharray 2 3` opacity .6 + `circle r=4.5` 填 `#F5A623` 描边 `#141416` 1.5px；轴名 8.5pt `#9A9AA0`（「重量 / kg」旋转 -90°、「日期」）；PR 标注 10pt/700 `#F5A623`。
- **E1RM vs 训练 1RM 卡**：`#141416` / `radius 16` / `padding 16` / 内 gap 15。顶行两组数值 Archivo 800 / 28pt（右侧一组 `#9A9AA0`），中间 1×34 分隔 `#2A2A2E`。每个主项一行：名称 13/600 `#EDEDED` + 数值 mono 12pt `#A1A1A6`；进度槽 高 8pt 底 `#101014` `radius 4`，填充 `linear-gradient(90deg,#A9731C,#F5A623)`；突破提示 mono 10pt `#5E9E78` + 10pt 对勾。
- **区块小标题**统一：mono 13pt `#B8B8BE`，`margin-top 8`。
- **入口卡**（全部教练反馈 / 全部训练历史）：`#141416` / `radius 16` / `padding 14-15×15-16`，左侧 38–40pt 方图标底 `#232327` `radius 10-12` + 19–20pt 金图标；标题 15/700，副 12pt `#8A8A90`；右 17pt chevron `#6A6A70`。
- **全部历史统计条**：三等分，标签 11pt `#8A8A90`，数值 Archivo 800 / **30pt**。
- **容量 / 强度双轴图**：`#141416` / `radius 16` / `padding 15 14 12`；`viewBox 0 0 320 172`。三条横网格线 y=18/82（`#242428`）与 y=146（`#333333`）。容量柱 `linear-gradient(180deg,#FBBF3E, #A9731C@28%透明)`。RPE 线画两遍：先 `#0A0A0B` 3px 描底，再 `#DCE3EA` 1.2px + `drop-shadow(0 0 3px rgba(220,227,234,.45))`；点 `r=2.6` 填 `#DCE3EA` 描边 `#0A0A0B` 1.2px。左轴刻度 mono 9pt `#8A8A90`，右轴 `#AEB6BE`，X 轴日期 8.5pt。图例：9pt 方块（金，`radius 2`）「训练容量 kg」+ 9pt 圆点（`#DCE3EA`）「平均 RPE」，mono 11pt `#8A8A90`。

### A.4 学员「组记录」页（样机 L440-531）

**全屏覆盖**（不是 sheet），底 `#0A0A0C`，从底部滑入 340ms。

- 顶栏：`padding 6 16 12`，底边 1px `#262626`；居中标题 17pt/600（绝对定位居中，不参与布局）；左「‹ 返回」18pt 图标 + 17pt 文字。
- **杠铃图**：高 148pt，`filter: drop-shadow(0 6px 8px rgba(0,0,0,.5))`。左端套筒 58×9 `radius 5 0 0 5`；卡箍 11×37；杠铃片按 IPF 配色与实际尺寸（25kg 红 11×135 / 20kg 蓝 8×135 / 15kg 黄 8×120 / 10kg 绿 8×98 / 5kg 白 8×68 / 2.5kg 黑 6×57 / 1.25kg 银 5×48，`radius 5`，`shadow 2px 0 5px rgba(0,0,0,.5), inset 1px 0 1.5px rgba(255,255,255,.16), inset -1.5px 0 2.5px rgba(0,0,0,.45)`，间距 1.5pt）；可选赛扣；右端杠身 92×17。
- 配重文字：mono 13/600 白（如「25kg × 1 · 10kg × 1 · 空杠 20kg」）；右侧「上赛扣」勾选（17pt 图标，选中金 `#F5A623`）。
- **重量 / 次数控件**：标签行 mono 12pt/500 `#8A8A90` `letter-spacing .96px` + 右侧步长 mono 10pt。控件行 gap 12：左右各一个 **48×48 圆钮**（底 `rgba(245,166,35,.12)`，边 1px `rgba(245,166,35,.3)`，20pt 加减图标 `#F5A623` 2.4px）；中间 **54pt 高** 数值区（`#141416` / `radius 16`），数值 mono **34pt/800** 白 + 单位 14pt/700 `#8A8A90`，点击开数字键盘。
- **RPE**：容器 `#141416` / `radius 16` / `padding 13×14`。顶行：数值 mono **32pt/800** + 右侧 RIR 文案 13pt/500 `#8A8A90`（「还能多做 2 次」等 11 档）。刻度条：11 根（5.0→10.0 step .5），高度槽 48pt，柱宽 6pt `radius 3`；高度：选中 32 / 整数 22 / 半档 13；颜色：选中 `#F5A623`、已点亮 `#8A8A8E`、未亮 `#2C2C2E`；标签只在整数显示，mono 12/600（高亮白 `#FFFFFF`，否则 `#525252`）。
- **视频区**：`#141416` / `radius 16` / `padding 11×14`；标题 16pt/500；两个按钮（透明底，边 1px `rgba(245,166,35,.24)`，`radius 12`，`padding 8×15`，20pt 图标 + 15pt/600 文字，色 `rgba(245,166,35,.72)`）：拍摄 / 相册。
- **底栏**：`padding 12 16 20`，顶边 1px `#262626`。主按钮 52pt 高、`radius 999`、金底、20pt 对勾 + 16pt/800「完成本组」。下方文字链「未完成 / 失败」13pt `#666666` + 14pt 叉。
- **数字键盘弹层**：遮罩 `rgba(0,0,0,.55)`；面板 `#141416` / `radius 20 20 0 0` / 顶边 1px `#262629` / `padding 14 16 22`。标题行：左 mono 12pt `#8A8A90` `letter-spacing .06em`，右当前值 mono **30pt/800** + 单位 13pt/700。键盘 3 列 gap 8，键 **高 52pt** / `radius 12` / 底 `#1C1C20` / mono **21pt/700** 白（退格键 19pt，`.` 在次数场景 opacity .25 且禁用）。底部两钮高 46pt：取消（`radius 12` + 1px `#2A2A2E` + 15pt/600 `#B8B8BE`，flex 1）/ 确定（`linear-gradient(180deg,#FBBF3E,#F5A623)` + `#141414` + 15pt/800，flex 2）。

### A.5 学员「训练回顾」（样机 L534-579）

- 顶栏：标题「训练回顾」Archivo 800 / 17pt + 副行 mono 11pt `#8A8A90`；右侧「已通知教练」胶囊 mono 11/700 底 `rgba(94,158,120,.16)` 字 `#5E9E78` `padding 4×12` `radius 999`；底边 1px `#17171A`。
- **总容量卡**：`linear-gradient(180deg,#17120A,#141416)` + 1px `rgba(245,166,35,.25)` + `radius 16` + `padding 18 16 15`。标签 mono 11pt/600 `#B8935A` `letter-spacing .08em`；数值 Archivo 800 / **46pt** / `line-height .9` + `kg` 14/700 `#8A8A90` + 右侧对比 mono 12pt `#5E9E78`。四格统计：`rgba(0,0,0,.35)` / `radius 12` / `padding 9×4` 居中，数值 Archivo 800 / 19pt，标签 10pt `#8A8A90`。
- **PR 条**：底 `rgba(245,166,35,.1)` + 1px `rgba(245,166,35,.35)` + `radius 12` + `padding 11×14` + 18pt 皇冠 + 13/700 `#F5A623`。
- **分节标题**：mono 11pt `#8A8A90` + 右侧 1px 横线 `#1E1E22`。
- **动作表现列表**：`#141416` / `radius 16`；行 `padding 13×15` + 顶边 1px `#1E1E22`；名称 14/700，副 mono 11pt `#7A7A80`；PR 标签 mono 10/700 `#F5A623` + 1px `rgba(245,166,35,.4)` + `radius 999` + `padding 2×8`；右侧统计 mono 11pt。
- **训练反思**：`#141416` / `radius 16` / `padding 4×15`；每段 `padding 11 0 12` + 底边 1px `#1E1E22`；小标题 13/700 `#EDEDED`；输入区 13pt `#C8C8CC`/1.5，placeholder 三条固定文案。分节标题右侧带锁图标 + 10pt「仅自己可见 · 保存在本机」。
- 底栏金 CTA「完成 · 回到今日」`radius 999` / `padding 15` / 16pt/800，带 shimmer。

### A.6 学员「完成庆祝」（样机 L581-605）

全屏 `#0A0A0C` 居中。

- **底光**：绝对定位 `left/right -20%`、`bottom -10%`、高 70%，`radial-gradient(ellipse at 50% 100%, rgba(245,166,35,.2), rgba(245,166,35,.06) 48%, transparent 72%)`。
- **bloom**：130×130 圆，`radial-gradient(circle, rgba(255,220,140,.55), rgba(245,166,35,.16) 55%, transparent 74%)`；动画 750ms easeOutCubic，`scale .2 → 8.7`，透明度前 20% 冲到 .9 再线性衰减到 0。
- **奖牌盖章**：96×104 SVG（金渐变 `#FFE28E→#F5A623→#C98A18`，内圆 `#17120A` opacity .92 + `rgba(255,226,142,.35)` 描边，对勾 `#FBBF3E` 5px），`filter: drop-shadow(0 0 26px rgba(245,166,35,.45))`；动画 520ms：`scale 1.5 → .9(@55%) → 1.05(@78%) → 1`，透明度在前 40% 线性到 1。
- **火花**：18 颗，`3 + i%3` pt 圆点，颜色 `i%3==0 ? #FFE9A8 : #F5A623`，`box-shadow 0 0 7px rgba(245,166,35,.85)`；角度 `(i/18)*2π + (i%3)*0.35`，半径 `66 + (i%4)*24`；延迟 `(i%6)*18ms`；800ms easeOutCubic 飞出并 `scale 1→0.2`，透明度 70% 后线性归零。
- 标题「今日训练完成」Archivo 800 / **26pt** 白，`margin-top 22`，延迟 140ms 后 450ms 淡入。
- 教练确认行（22pt 圆头像 `linear-gradient(135deg,#3A3A42,#1C1C20)` + 1px `rgba(245,166,35,.4)` + 10/700 `#F5A623` 的「教」字 + 12pt `#B8B8BE` 文案），延迟 240ms。
- 两列数据（最大宽 300pt，中间 1pt 分隔 `#232327`）：数值 Archivo 800 / **34pt** `#F5A623`，标签 mono 11pt `#8A8A90`；组数那格带滚动计数器（470ms 后 900ms easeOutQuart 从 0 滚到目标）。逐项 `340 + i*130ms` 延迟 + 460ms easeOutCubic `translateY 26→0`。
- 元信息 mono 12pt `#8A8A90`；连续训练胶囊（底 `rgba(245,166,35,.1)` + 1px `rgba(245,166,35,.3)` + `radius 999` + `padding 6×14` + 12pt 火焰 + 12/700 `#F5A623`）。
- 底部：金 CTA「查看详细报告」`padding 15×52` + shimmer（延迟 820ms 淡入）；文字链「完成」13pt `#8A8A90`。

### A.7 学员「聊天 / 反馈归档」（样机 L617-661）

- 顶栏：40×40 圆返回钮（`#141416` + 20pt chevron `#EDEDED`）+ 标题 16/700 + 副行 11pt（`#8A8A90` 或在线态 `#5E9E78` 的「● 在线」）；底边 1px `#17171A`。
- **气泡**：对方 `#1B1B1E` / `radius 16 16 16 5` / `padding 11×14` / 14pt/1.45，最大宽 76%；自己 `#E7E7E9` 黑字 / `radius 16 16 5 16` / 14pt/500。
- **计划卡片消息**：`#141416` + 1px `#2A2A2E` + `radius 16 16 16 5` + `padding 13×14`，最大宽 88%；40pt 方图标（`#232327` `radius 12`）+「新计划」mono 9pt/700 胶囊（底 `rgba(230,190,85,.14)` 字 `#F5A623` `letter-spacing .1em`）+ 标题 14.5/700 + 副 12pt `#8A8A90` + chevron。
- **反馈卡片消息**：`#141416` + **左边框 3pt `#F5A623`** + `radius 5 16 16 5` + `padding 12×13`；头部 7pt 金点 + 13/700「教练反馈」+ 右侧「未读」（金底黑字 mono 9/700）或「已读」（金字 + 11pt 对勾）；视频缩略 150pt 高 `radius 12` 底 `linear-gradient(135deg,#2A2A30,#141416)`，中央 42pt 圆播放钮（`rgba(0,0,0,.45)` + 1.5px `rgba(255,255,255,.75)`），左上角标题标签 / 右下角时长标签（`rgba(0,0,0,.5-.6)` + `radius 5`）；正文 14pt/1.5 `#E4E4E6`。
- **输入栏**：`#141416` + 1px `#2A2A2E` + `radius 20` + `padding 0 6 0 16`；输入 14pt；发送 34pt 圆钮 `#2E2E32` + 18pt 箭头。
- **反馈归档页**：卡片 `#141416` + 左 3pt accent + `radius 12` + `padding 13×15`；回放条 `#101014` / `radius 10` / `padding 8×11` + 30pt 方图标 + 13pt `#C8C8CC` + 右侧时长 mono 11pt。

### A.8 学员「我的」（样机 L386-429）

- 大标题「我的资料」Archivo 800 / **34pt**；分组小标题 mono 11pt `#7A7A80` `letter-spacing .04em`。
- **当前 1RM 卡**：`#141416` / `radius 16` / `padding 16`。头行「当前 1RM」13/600 `#B8B8BE` + 14pt info 图标 + 右侧 15pt 锁图标 `#6A6A70`。说明气泡（展开时）：`#101014` / `radius 10` / `padding 9×11` / 11pt `#9A9AA0`/1.5。三项数值 Archivo 800 / **26pt** + 单位 11pt。SBD 总和行：顶边 1px `#232327`，标签 mono 12/600 `#B8B8BE`，数值 Archivo 800 / **24pt** `#F5A623`。锁定提示 11pt `#6A6A70` + 11pt 锁图标。
- **通知教练卡**（恢复评估 / 伤病记录）：`#141416` / `radius 16` / `padding 14×16`；标题 14/600 + 「通知教练」小标签（10pt `#F5A623`，底 `rgba(245,166,35,.12)`，边 1px `rgba(245,166,35,.35)`，`radius 5`，`padding 1×7`）；值 chip 12pt `#C8C8CC` 底 `#1E1E22` `radius 6` `padding 3×9`，中间 1×11 分隔；伤病 chip 用红系（字 `#FF6B66`，底 `rgba(229,72,77,.1)`，边 1px `rgba(229,72,77,.4)`，`radius 7`）。
- **分组列表卡**：`#141416` / `radius 16` / `overflow hidden`；行 `padding 14×16`，行间 1px `#1E1E22`；小标签 11pt `#8A8A90`，值 16pt/600（金色高亮部分用 `#F5A623`），右 18pt chevron `#6A6A70`。
- **退出登录**：`#141416` + 1px `#2A2A2E` + `radius 16` + `padding 14` 居中，17pt 图标 + 14/600，色 `#C86A6A`。

### A.9 学员 tab bar（样机 L433-438）

高 **83pt**，顶边 1px `#17171A`，底 `#0A0A0C`，`padding-top 9`，四项等距，每项宽 64pt、gap 4。图标 **24pt** stroke（选中 `#F5A623`，未选中 `#7A7A80`），标签 **11pt** 同色。按压 `scale(.9)`。

### A.10 教练端各屏（样机 `MeetPR 教练端.dc.html`）

结构与色彩语言与学员端一致，差异点：

- **今日 L40-70**：日期 mono 12pt `#8A8A90` + 大标题「今日」Archivo 800 / **38pt** `line-height .95`；右上 44pt 圆消息钮 + 红徽章（`#E5484D`，18×18，10pt）。新学员请求卡 `#141416` + 1px `#262629` + `radius 16` + `padding 15×17`：7pt 红点 + mono 11pt `#8A8A90` `letter-spacing .06em`「新学员请求 // 01」+ 17/700 标题 + 13pt `#8A8A90` 「查看接收队列 →」。三格统计卡：标签 11pt/600（活跃金 `#F5A623` / 评估期 `#8A8A90` / 待关注 `#E5484D`），数值 Archivo 800 / **30pt** + 单位 12/600；1pt 分隔 `#26262A`。学员列表卡：行 `padding 14×16` + 顶边 1px `#1E1E22` + 9pt 状态点 + 名称 16/700 + 副 12pt `#8A8A90` + 17pt chevron `#5A5A60`。
- **学员 L72-92**：大标题 Archivo 800 / **34pt** + 右上 40pt 圆消息钮。搜索框 `#141416` + 1px `#262629` + `radius 12` + `padding 0 14` + 17pt 放大镜 `#6A6A70` + 14pt 输入。分组标题 mono 12pt（异常组用 `#E5484D`）。行右侧计划标签（11pt `#8A8A90` + 1px `#262629` + `radius 999` + `padding 3×9`）或告警标签（`#E5484D` + `rgba(229,72,77,.14)` + 600）。
- **编排 L94-107**：eyebrow mono 11pt/600 `#F5A623`「计划编排」+ 大标题「编排」34pt + 说明 13pt `#8A8A90`。金 CTA「＋ 排新计划」`radius 999` `padding 16` 16/800 带 shimmer；次级「导入计划 (.xlsx)」1px `#262629` + `radius 999` + `padding 15` + 15/600 `#C8C8CC`（**注意：导入能力当前 `PlanImportCapability.isEnabled == false`，见 C-14**）。需排计划行：`#141416` / `radius 12` / `padding 12×14` + 38pt 圆头像（`#1C1C20` + 14/700 `#B8B8BE` 首字）+ 名称 15/700 + 副 12pt + 「排」按钮（1px `#2E2E32` + `radius 12` + `padding 8×16` + 14/600）。
- **接收 L109-151**：eyebrow「收件箱」+ 大标题「接收」34pt。分段控件：容器 `#141416` / `radius 12` / `padding 4` / gap 4；段 `padding 9pt 0` / `radius 10` / 13pt/600，选中态底色变亮。新学员卡：姓名 Archivo 800 / **20pt** + 等待时长 11pt；档案 13pt `#C8C8CC`；SBD 行 mono 14/700 `letter-spacing .02em`；1pt 分隔 `#1C1C20`；多行档案 13pt `#9A9AA0`/1.7；按钮行：金「接收」(flex1, `radius 999`, `padding 13`, 14/800) + 「查看资料」(1px `#2E2E32`) + 48pt 宽关闭钮。空态：52pt 圆图标 + 15/600 + 12pt `#7A7A80`。视频行：72×56 缩略（`#101014` + 1px `#262629` + `radius 10` + 22pt 播放三角）+ 名称 15/700 + 副 12pt + 计数标签。消息行：名称 15/700 + 摘要 12pt + 右侧日期 11pt + 8pt 红点。
- **我的 L153-167**：身份卡 48pt 圆头像 + 「教练」17/700 + mono 11pt `#F5A623` 版本行。邀请码卡：标签 12pt/600 `#F5A623` + 码 mono **26pt/700** `letter-spacing .14em` + 使用次数 12pt + 「复制」钮（1px `#2E2E32` / `radius 10` / `padding 6×14` / 12/600）。
- **学员详情 L169-217**：返回行（20pt chevron + 14pt `#B8B8BE`）+ 38pt 圆消息钮。姓名 Archivo 800 / **32pt** + 状态胶囊（11pt `#5E9E78` + 1px `rgba(94,158,120,.35)` + `radius 999` + `padding 3×10`）。评估期卡（**当前休眠**）：标题 14/700 + 12pt 副 + 6pt 进度槽（`#26262A` / `radius 3` / 填充 `#5E9E78`）+ 三按钮行。分段 chips 横滑：`padding 8×15` / `radius 12` / 13/600。各段卡片沿用 `#141416` / `radius 16` / `padding 15`；E1RM 小图 `viewBox 0 0 300 50` 金折线 2.5px。反馈输入条：`#141416` + 1px `#262629` + `radius 16` + `padding 6 6 6 14` + 金色「发送」钮（`radius 999` / `padding 9×16` / 13/800）。
- **教练 tab bar L221-228**：高 83pt，每项宽 **60pt**，图标 **23pt**，标签 **10pt**；接收 tab 带红徽章（16×16，`radius 8`，9pt mono，`top -4 right 8`）。

---

## 附录 B — 已知冲突清单初稿

**Codex 开工第一件事**：创建 `docs/design/UI-REFRESH-CONFLICTS.md`，把下面 16 条按 §4.5 的格式抄进去作为初稿，施工中新发现的继续追加编号。**任何一条都不许自行拍板**。

| 编号 | 一句话 | 类型 |
|---|---|---|
| C-01 | **tab 结构：已核实无冲突。** 学员端代码 4 tab（今日/训练/成长/我的）与学员样机完全一致；教练端代码 5 tab（今日/学员/编排/接收/我的）与教练样机完全一致。开卡时预设的「样机 4 tab vs 现状不同」不成立，登记为「已核实、无需处置」防止后续复活。 | 已澄清 |
| C-02 | **顶部聊天泡**：样机学员端右上角是 44pt 圆形**消息气泡**图标 + 红底数字徽章「3」；现状是 `StudentNotificationBell`（`bell` / `bell.badge` + 未读圆点），聊天折在通知中心里（`Features/Dashboard/StudentNotificationComponents.swift:54` 推 `ConversationView`）。**数据源存在**（ChatUI 全量接线，教练端 `ChatEntryButton` 已展示 `chat.inbox.totalUnread`），冲突在**图标形态**与**计数口径**（样机的 3 = 聊天未读？还是通知总数？）。选项 A 只换视觉、保留 bell 语义；B 换成消息气泡并绑 `totalUnread`；C 双入口。 | 待拍板 |
| C-03 | **亮色主题**：令牌一并落库但不做切换入口，App 保持 `.preferredColorScheme(.dark)`（`MeetPR/Sources/MeetPRApp.swift:286`）。已按拍板执行，登记备查。 | 已定 |
| C-04 | **无数据源元素清单**（逐个跳过 + 登记，施工中逐条核实是否真的无源）：今日页「距比赛 N 天」金卡、「体重 83 kg」卡（`DashboardProfileMetricsView` 可能已有源，先核实）；完成页「连续第 12 次训练」streak（**未见数据源**）；完成页「教练已收到你的训练日志」与回顾页「已通知教练」胶囊；成长页「E1RM vs 训练 1RM」对比条与「已突破训练 1RM · N%」；成长页「训练次数 / 训练周 / 训练总容量」三格；教练端「已等待 2 小时 6 分」；教练端邀请码「已使用 23 次」。 | 待拍板 |
| C-05 | **页面横向内边距不一致**：令牌 `--page-x: 16px`，但样机主 tab 屏实测 `padding: 6px 20px 28px`（20pt）。一比一以样机为准，令牌注释需说明。 | 待拍板（建议：以样机为准） |
| C-06 | **`AGENTS.md` §SwiftUI 约定「不硬编码字号 / 用 Dynamic Type / 不硬编码 padding」与「像素级一比一」直接冲突。** 本卡裁决：数字集中进 DesignSystem 令牌、视图侧只引令牌；Dynamic Type 本波按固定值处理。**可访问性欠账**（大字号用户会被截断）需 David 决定是否补 `@ScaledMetric` 或在设置里给字号档。 | 待拍板 |
| C-07 | **无样机的屏幕**（只做令牌套用、不臆造版式）：登录 `LoginView`、注册 `SignupView`、`AuthSecureField`、`BindGateView` / `EnterCodeView` / `PendingBindView`、7 步 `OnboardingWizardView` 及 `Steps/*`、`ReadinessCheckinSheet`、`RestTimerOverlay` / `RestTimerExplanationView` / `RestTimerSettingsView`、`VideoAttachmentSection` / `CameraVideoPicker` / `VideoTrimmerView`、教练 `Planning/Views/*` 全部 19 个向导原子件、`InviteCodesView` 的创建码 sheet、`AccountSecuritySheets`、`ExportDataSheet`、`HistoryEntriesView`、`GrowthCurveView`、评估相关全部屏。 | 已定（登记范围） |
| C-08 | **字体安放位置**：按拍板走「app 资源 + `UIAppFonts`」。副作用——`Modules/DesignSystem/Package.swift` 没有 `resources:` 声明，DS 的 SwiftUI preview 与 `swift test` **看不到自定义字体**，只能回退系统字体。备选 B：字体入 DesignSystem 包资源 + `CTFontManagerRegisterGraphicsFont` 运行时注册（preview / 单测都能看到真字体，app 侧不必配 `UIAppFonts`）。需确认是否接受 preview 回退。 | 待拍板 |
| C-09 | **Archivo named instance 名与描述不符**：实测 PostScript 名是 `ArchivoRoman-ExtraBold` / `ArchivoRoman-Black`（不是 `Archivo-ExtraBold` / `Archivo-Black`），且 `name(1)` family = `Archivo SemiBold`（VF 默认实例 wght=600）。按实测名接入；若 iOS 取不到 named instance，改用 `fonttools varLib.instancer` 抽 static 并在此条追记。 | 已定（登记事实） |
| C-10 | **中文字重天花板**：样机标题是 Archivo 800/900，但中文一律走系统苹方 PingFang SC，最重只到 `.semibold`/`.bold`，中西文混排时字重不齐（如「今日训练」「训练回顾」「W1D4」同一行）。无解方案下需接受视觉差，或改用中文字体（违背「不打包中文字体」的拍板）。 | 待拍板 |
| C-11 | **死视图不还原**：`E1RMMiniTrendCard` / `DashboardComponents.DashboardSection` / `ProgressDashboardView` / `TrainingHistory/DayDetailView` / `TodayWorkout/ExerciseExecutionView` / `TodayWorkout/SetRecordRow` / `TodayWorkout/PlateMathSheet` / `TodayWorkout/WorkoutDayHeader` / `MyProfile/ProfileCardsSection`（section struct）零调用点，约 1200 行。本波不还原、不删除，登记待清。 | 待拍板（清理时机） |
| C-12 | **训练页日历「周 / 月」切换**：样机有周视图与月视图两态 + 切换控件；现状 `TrainingCalendarView` 只有横向日期条，没有月视图。一比一还原会带出新功能 → 本波只还原周视图视觉，月视图跳过。 | 待拍板 |
| C-13 | **完成今日训练的交互形态不同**：样机是「长按 1100ms + 金色进度填充 + 三段触觉」；现状是 `SlideToCompleteButton`（拖拽滑动确认）。这属于交互改动不是纯视觉。选项 A 只换 slide 按钮的视觉皮肤保留拖拽；B 改成长按（要动 `SlideToCompleteButton` 的行为与其测试）。 | 待拍板 |
| C-14 | **样机里出现但当前被冻结/休眠的能力**：教练编排页「导入计划 (.xlsx)」按钮（`PlanImportCapability.isEnabled == false`）；教练今日页「评估期 1 进行中」统计与学员详情「评估期 · 还剩 4 天」进度条（`BindGateViewModel.swift:134` `evaluationSealed = true`，全链路休眠）。还原这些控件等于放出被封存的功能 → 跳过。 | 已定（跳过） |
| C-15 | **「我的」页字段逐项核对**：样机列出「恢复评估 / 伤病记录 / 想增强肌群 / 组间休息 / 比赛日期 / 身高·体重 / 训练背景 / 训练环境 / 成长曲线 / 改密码 / 导出训练数据 / 退出登录」；现状 `MyProfileView` 分组与字段需逐项比对，多出或缺失的都登记，不擅自增删条目。 | 待拍板（逐项） |
| C-16 | **今日页主 CTA 副行「蹲 · 推 · 拉」= 当日主项列表**，现状 CTA 是否有这一行、数据是否可得，需在 W2 施工时核实；无源则跳过副行并登记。 | 待核实 |

---

## 附录 C — 开工顺序速查

```
读 CLAUDE.md / AGENTS.md
  → 读 docs/design/meetpr-design-skill/{README.md,SKILL.md,tokens/*,guidelines/*,components/core/*}
  → 分段读 reference/MeetPR 学员端.dc.html + MeetPR 教练端.dc.html
  → 建 docs/design/UI-REFRESH-CONFLICTS.md（抄附录 B 初稿）
  → W0 令牌 + 字体 + 测试   → swift test DesignSystem 绿
  → W1 DS 组件 + 动效修饰器 → swift test DesignSystem 绿 + Demo 页目视
  → W2 学员端逐屏           → MeetPR-DemoStudent 模拟器逐屏对照
  → W3 教练端逐屏           → MeetPR-Demo 模拟器逐屏对照
  → W4 AppShell 登录注册    → 全量 build + test + swiftlint --strict
  → 停在工作区改动态，不 commit 不 push，交付 git status --short + 分层摘要 + CONFLICTS 全文
```
