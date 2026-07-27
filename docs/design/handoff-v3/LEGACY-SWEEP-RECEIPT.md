# 黑金 v3 学员端旧界面清扫回执

日期：2026-07-27
分支：`feat/black-gold-ui-v3`
执行边界：仅 StudentKit 学员端视觉与对应视觉契约测试；未改业务逻辑、文案或页面结构；未 commit / push。

## 文件与改动摘要

### Dashboard

- `Features/Dashboard/DashboardComponents.swift`
  - 区标题切换 Archivo display；动作入口文字改动态 goldText；卡面/边框改 surfaceCard/borderDefault。

### FeedbackInbox

- `Features/FeedbackInbox/FeedbackDetailView.swift`
  - 教练头像和视频入口图标保留 gold500；正文、日期和卡片切换 v3 字体、文字、表面与边框；播放链接失败文字改 dangerMuted。
- `Features/FeedbackInbox/StudentFeedbackVideoPlayerView.swift`
  - 倍速数字改 IBM Plex Mono；播放失败使用 danger；重试按钮改 ctaBackground/ctaText 胶囊。

### MyProfile

- `Features/MyProfile/ProfileCardsSection.swift`
  - 资料行改 v3 正文/弱化层级和 surfaceCard；保存错误文字改 dangerMuted；保存改 GoldCTA；编辑页底改 bgBase。
- `Features/MyProfile/GrowthCurveView.swift`
  - 图表卡改 surfaceCard；详情标题改 display；指标和值改 mono；e1RM 强调文字改动态 goldText；sheet 底改 bgBase。
- `Features/MyProfile/ExportDataSheet.swift`
  - 失败文字改 dangerMuted、重试文字改 goldText、成功改 success；说明文字改 v3 body；分享按钮改主 CTA 胶囊；页面底改 bgBase。
- `Features/MyProfile/AccountSecuritySheets.swift`
  - toast、说明和错误文字迁移 v3 body；改密主操作改 GoldCTA；永久删除保留 danger 语义；sheet 底改 bgBase。

### Onboarding 与资料编辑共用控件

- `Features/Onboarding/OnboardingFieldComponents.swift`
  - 单选卡、复选 chip、1–5 刻度统一为 goldText 文字 + goldRGB 12% 底 + goldRGB 40% 描边；未选统一 surfaceCard/borderDefault/textMuted。
  - 校验标题文字改 dangerMuted，输入框错误描边保留 danger；数字输入与刻度数字改 IBM Plex Mono；正文输入改 v3 body。
- `Features/Onboarding/OnboardingWizardView.swift`
  - 页面底、进度条、标题、状态文案迁移 v3；主操作统一 GoldCTA；提交成功使用 success、提交失败文字使用 dangerMuted。
- `Features/Onboarding/Steps/Step2BackgroundSection.swift`
  - 训练年限 slider 改 gold500；年限数字改 mono；辅助文案改 textMuted。
- `Features/Onboarding/Steps/Step3StrengthSection.swift`
  - 估算器卡、标题、RPE slider、估算数字迁移 v3；填入估算值改 GoldCTA。
- `Features/Onboarding/Steps/Step4EnvironmentSection.swift`
  - 场馆选中标题改 goldText，选中勾保留 gold500；未选卡改 surfaceCard/borderDefault/textMuted。
- `Features/Onboarding/Steps/Step6MaterialsSection.swift`
  - 未开放上传卡改 surfaceCard/borderDefault；禁用说明与图标改 textMuted。
- Step 1、5、7 无独立旧 token；视觉通过上述共用控件自动同步。注册「自己练」空壳逻辑未动。

### Readiness

- `Features/Readiness/ReadinessCheckinSheet.swift`
  - 评分点保留 gold500，疲劳 chip 选中文字改 goldText，下一步/完成 CTA 统一金色体系；失败文字改 dangerMuted；页面/卡片/文字迁移 v3。

### Shared / TodayWorkout

- `Features/Shared/E1RMCompetitionLiftGate.swift`
  - 校准失败标题改 display、失败说明文字改 dangerMuted、重试改 GoldCTA、底色改 bgBase。
- `Features/TodayWorkout/CoachNoteDisplay.swift`
  - 教练备注改 v3 mono/body、surfaceCard/surfaceElevated、borderDefault。
- `Features/TodayWorkout/SetVideoUploadIndicator.swift`
  - 未附视频改 textMuted；上传扫色改 gold500；成功改 success；失败改 danger。
- `Features/TodayWorkout/PRBanner.swift`
  - PR 成功条改 success；标题改 body，数据行改 mono。
- `Features/TodayWorkout/RestTimerOverlay.swift`
  - 清除最后一个旧字体别名；“跳过”文字改 goldText，timer 图标与 progress tint 保留 gold500。
- `Tests/StudentKitTests/Features/TodayWorkout/SetVideoUploadIndicatorStyleTests.swift`
  - 同步三条视觉契约断言到 textMuted/success/danger。

### TrainingHistory

- `Features/TrainingHistory/DayDetailView.swift`
  - 页面底/卡面/边框迁移 v3；动作标题改 display；组号、重量、次数、RPE 改 mono；完成改 success。
- `Features/TrainingHistory/HistoryEntriesView.swift`
  - 周标题、日期、组数据和筛选器迁移 display/mono/body；筛选选中值与进行中计数文字改 goldText，完成计数使用 success；卡片改 surfaceCard。
- `Features/TrainingHistory/ProgressDashboardView.swift`
  - 二级面板标题改 display/textPrimary。

## 浅色对比度 BLOCKER 返修（评审第 1 轮）

结论：本卡 24 文件已逐一复扫文字角色。所有选中 chip 标签、选中值、金色强调数字与金色文字操作均使用动态 `goldText`；所有错误/危险小号文字均使用动态 `dangerMuted`。浅色下，`goldText` 在本卡表面上的对比度为 5.13–6.26:1，`dangerMuted` 为 5.96–6.45:1；暗色下保持样机金色/危险色语义并通过模拟器目检。

纯 `gold500` 仅保留给 slider/progress tint、进度填充、选中圆点、描边、头像/播放/计时/勾选/上传 glyph 等非文字角色。纯 `danger` 仅保留给播放失败大图标、输入错误描边、上传失败描边等非文字语义角色。

### 逐文件清单

| # | 文件 | 文字角色复扫结论 |
|---:|---|---|
| 1 | `Dashboard/DashboardComponents.swift` | ✅ 区动作文字 → goldText |
| 2 | `FeedbackInbox/FeedbackDetailView.swift` | ✅ 播放错误 → dangerMuted；gold500 仅头像/视频图标 |
| 3 | `FeedbackInbox/StudentFeedbackVideoPlayerView.swift` | ✅ 无纯色危险文字；danger 仅失败大图标 |
| 4 | `MyProfile/AccountSecuritySheets.swift` | ✅ 注销、校验、提交错误均为 dangerMuted |
| 5 | `MyProfile/ExportDataSheet.swift` | ✅ 错误 → dangerMuted；重试 → goldText |
| 6 | `MyProfile/GrowthCurveView.swift` | ✅ 详情 e1RM 强调值 → goldText |
| 7 | `MyProfile/ProfileCardsSection.swift` | ✅ 保存错误 → dangerMuted |
| 8 | `Onboarding/OnboardingFieldComponents.swift` | ✅ 选中 option/chip/notch → goldText；错误标题 → dangerMuted |
| 9 | `Onboarding/OnboardingWizardView.swift` | ✅ handoff 错误 → dangerMuted；gold500 仅图标/进度 |
| 10 | `Onboarding/Steps/Step2BackgroundSection.swift` | ✅ gold500 仅 slider tint |
| 11 | `Onboarding/Steps/Step3StrengthSection.swift` | ✅ gold500 仅 RPE slider tint |
| 12 | `Onboarding/Steps/Step4EnvironmentSection.swift` | ✅ 场馆选中标题 → goldText；gold500 仅勾图标 |
| 13 | `Onboarding/Steps/Step6MaterialsSection.swift` | ✅ 无 gold500/danger 文字角色 |
| 14 | `Readiness/ReadinessCheckinSheet.swift` | ✅ 疲劳 chip → goldText；提交错误 → dangerMuted；gold500 仅评分点 |
| 15 | `Shared/E1RMCompetitionLiftGate.swift` | ✅ 校准失败说明 → dangerMuted |
| 16 | `TodayWorkout/CoachNoteDisplay.swift` | ✅ 无 gold500/danger 文字角色 |
| 17 | `TodayWorkout/PRBanner.swift` | ✅ 无 gold500/danger 文字角色 |
| 18 | `TodayWorkout/RestTimerOverlay.swift` | ✅ “跳过” → goldText；gold500 仅 timer 图标/progress |
| 19 | `TodayWorkout/SetVideoUploadIndicator.swift` | ✅ gold500/danger 仅上传/失败 glyph 描边 |
| 20 | `TrainingHistory/DayDetailView.swift` | ✅ 无 gold500/danger 文字角色 |
| 21 | `TrainingHistory/HistoryEntriesView.swift` | ✅ 筛选选中值、进行中计数 → goldText |
| 22 | `TrainingHistory/ProgressDashboardView.swift` | ✅ 无 gold500/danger 文字角色 |
| 23 | `SetVideoUploadIndicatorStyleTests.swift` | ✅ danger 断言仅覆盖失败描边 |
| 24 | `LEGACY-SWEEP-RECEIPT.md` | ✅ 浅色结论、保留角色与逐文件证据已补齐 |

## Bind / Evaluation 封存面

以下 6 个文件保持零 diff，共保留 41 处 LegacyColors 引用：

1. `Features/Bind/BindGateView.swift`
2. `Features/Bind/EnterCodeView.swift`
3. `Features/Bind/PendingBindView.swift`
4. `Features/Evaluation/EvaluationPeriodView.swift`
5. `Features/Evaluation/EvaluationSummaryView.swift`
6. `Features/Dashboard/EvaluationCompletedCard.swift`

除上述 6 个封存文件外，StudentKit Sources 中 LegacyColors 引用为 0。

## LegacyColors 遗留消费者统计

统计口径：`MeetPR` 与 `Modules` 下 Swift 源码，排除 `.build` 和 `LegacyColors.swift` 定义文件；“引用”按实际 token occurrence 计。

| 区域 | 引用数 | 文件数 | 处置 |
|---|---:|---:|---|
| AppShell | 36 | 5 | auth / shell 旧体系，本卡不动 |
| ChatUI | 29 | 5 | 非本卡范围，本卡零 diff |
| CoachKit | 507 | 53 | 教练端旧体系，本卡不动 |
| DesignSystem demo | 47 | 1 | 旧 palette 展示/兼容页，不删 |
| StudentKit | 41 | 6 | 全部位于上方 Bind/Evaluation 封存清单 |
| **合计** | **660** | **70** | LegacyColors 仍不可删除 |

按 token：

| token | 引用数 | 文件数 |
|---|---:|---:|
| `brandRed` | 70 | 39 |
| `brandRedPress` | 1 | 1 |
| `brandRedSoft` | 6 | 5 |
| `green` | 13 | 11 |
| `greenSoft` | 2 | 2 |
| `amber` | 23 | 16 |
| `amberSoft` | 6 | 5 |
| `bg` | 55 | 45 |
| `surface1` | 41 | 23 |
| `surface2` | 36 | 29 |
| `surface3` | 4 | 3 |
| `border` | 51 | 23 |
| `fgPrimary` | 165 | 60 |
| `fgSecondary` | 109 | 51 |
| `fgTertiary` | 76 | 41 |
| `fgDisabled` | 2 | 2 |

### 可删候选

- 全仓可删候选：**0**。16 个 LegacyColors token 均仍有实际消费者。
- StudentKit 非封存区已清空；下列 9 个 token 在 StudentKit 已无引用，但仍被 CoachKit/AppShell/ChatUI/DesignSystem demo 消费，故本卡不删：
  `brandRedPress`、`brandRedSoft`、`greenSoft`、`amber`、`amberSoft`、`surface1`、`surface3`、`border`、`fgDisabled`。

## 自检

- `xcrun swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules`：通过。
- `swiftlint lint --strict --config .swiftlint.yml`：通过。
- StudentKit 全量测试：526 passed，0 failed，0 skipped。
- `MeetPR-DemoStudent`（DemoStudent configuration，iPhone 17 Pro / iOS 26.5）：build + run 通过；仅 Xcode `appintentsmetadataprocessor` 的 “No AppIntents.framework dependency found” 跳过提示，无源码编译 warning。
- 浅色模拟器目检：Dashboard、资料页、训练环境、伤病编辑、恢复评分/疲劳 chip、成长曲线、教练反馈详情通过；选中 chip/卡片/值文字清晰，无亮金低对比小字。
- 暗色模拟器目检：资料页、训练环境、伤病编辑、成长曲线、教练反馈详情、导出成功态通过；动态 goldText/dangerMuted 与黑金视觉一致。
- Demo seed 无稳定失败入口；错误态由逐文件 token 复扫确认全部落到 dangerMuted，纯 danger 仅剩非文字角色。
- `git diff --check`：通过。
- 禁区 diff：CoachKit / ChatUI / auth / Bind / Evaluation 为 0。
- Git：未 commit，未 push。
