# W2c 回执 — 成长 + 我的屏卡（黑金 UI v3）

## 交付范围

- `TrainingHistoryView` 按黑金 v3 重做为成长主屏，保留现有
  `GrowthCurveViewModel`、训练日志、反馈和历史详情链路。
- `MyProfileView` 按黑金 v3 重做为我的资料主屏，保留现有 onboarding、
  readiness、资料编辑、休息偏好、账号安全和退出登录链路。
- 新增纯 presentation 派生：
  `GrowthScreenPresentation`、`GrowthComparisonPresentation`、
  `MyProfileV3Presentation`。
- `GrowthCurveViewModel.TimeWindow`、默认窗口与 imported-history 自动扩展
  保持 spec 053 既有公开契约且源码/测试相对 `HEAD` 零 diff。W2c 以局部
  `GrowthTimeRange` 提供 `30天 / 90天 / 1年 / 历史总览`，在 presentation
  层映射到既有 `TimeWindow` 语义；三项主项各自保存范围。
- 未改后端、Repository 协议、网络层、今日/训练两屏、ChatUI、CoachKit、
  AppShell、`CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。

## 样机 DOM → SwiftUI 映射

唯一视觉标准：
`docs/design/handoff-v3/MeetPR 学员端.dc.html` 成长 DOM 280–373、
我的 DOM 375–418，以及 `renderVals` 的 `growthLifts`、`cmpLifts`、
`volBars`、`rpePts`、`rangeSeries` 派生语义。

| 样机 DOM / JS | SwiftUI 结构 | 映射内容 |
|---|---|---|
| 280–284 | `GrowthScreenHeader` | MEETPR 描边字标、34pt「成长」、E1RM 白话注释 |
| 285–310 + JS `rangeSeries` | `GrowthE1RMCard` + `GrowthScreenPresentation.snapshot` | 三张独立大卡；38pt Mono 数字、gold delta、四档范围胶囊；轴、虚线网格、面积渐变和语义 `chartLine`；金点与垂直虚线锚定真实 `latestRecordPoint`，三枚日期标签按 DOM 306–308 分别锚定窗口起点、时间中点和轴右端 PR 日期 |
| 313–327 | `GrowthComparisonCard` + `GrowthComparisonPresentation` | E1RM / onboarding 训练 1RM 三项合计、三条 `goldBarDeep → gold500` 进度条、突破绿勾 |
| 329–334 | `GrowthNavigationCard` → `FeedbackInboxView` | 既有反馈列表/详情入口、动态反馈条数 |
| 336–341 | `GrowthHistoryStatsCard` + `GrowthScreenPresentation.historyStats` | 完成训练次数、训练周、训练总容量三列 |
| 343–347 | `GrowthNavigationCard` → `AllHistoryScreen` | 既有训练历史入口与每组详情 |
| 349–371 | `VolumeIntensityChart` + `GrowthScreenPresentation.chartBuckets` | 最近六周容量圆顶渐变柱、RPE 双描边折线/圆点、左右双轴、日期和图例 |
| 375–379 | `MyProfileHeader` | MEETPR 描边字标、34pt「我的资料」、Mono eyebrow |
| 380–389 | `MyProfileOneRMCard` | onboarding 三项 1RM、SBD 总和金字、锁行、info 弹注 |
| 391–393 | `MyProfileRecoveryCard` | 今日 readiness（缺失时 onboarding 恢复基线）、伤病 chip、通知教练角标；接既有 readiness sheet / 伤病编辑 |
| 395–401 | `MyProfileGroupCard` + `MyProfileValueRow` | 想增强肌群、组间休息、比赛日期、身高体重；接既有编辑页 |
| 402–406 | `MyProfileGroupCard` | 训练背景与训练环境；接既有编辑页 |
| 407–410 | `growthEntry` | 成长曲线入口；Student shell 内切换到成长 tab，独立使用时回退到既有 `GrowthCurveView` |
| 411–415 | `AccountSecuritySection` | 既有改密码和导出训练数据功能，主屏不展示删除账号 |
| 416 | `GoldCTA(variant: .danger)` | 卡面、borderStrong、dangerMuted 图标与文字的退出登录 |

## 数据源与派生口径

| UI 数据 | 现有数据源 | W2c 派生 |
|---|---|---|
| 三项 E1RM 曲线 | `E1RMRepository` + `GrowthCurveViewModel` | 按 lift family 分组；W2c 局部 range 映射既有 4 周/3 月/全部语义，1 年在 presentation 层裁取；当前值、首尾 delta、真实最后纪录点/日期、`rawEligible` low-confidence 散点、轴范围与日期标签 |
| 训练 1RM | `OnboardingProfileReading` | squat / bench / deadlift onboarding 1RM；完整三项才显示合计 |
| 对比条 | E1RM snapshot + onboarding 1RM | `min(E1RM / 训练1RM, 1)`；百分比达到 100% 显示突破行 |
| 反馈 | 既有 `FeedbackInboxViewModel` | 当前列表条数；继续进入既有列表和详情 |
| 全部历史统计 | `StudentTrainingLogRepository` | 只计 `completed && !assumed`；按完成日去重训练次数、ISO 周去重训练周、`weight × reps` 求总容量 |
| 容量 / 强度 | `ProgressMetrics.weeklyVolumeIntensity` | 取最近六个周桶；容量柱与平均 RPE 共享周日期标签 |
| 当前 1RM / 资料 | `OnboardingProfileReading` | `MyProfileV3Presentation` 统一格式化 SBD、肌群、比赛、身高体重、训练背景和环境 |
| 恢复评估 | `ReadinessRepository` + onboarding | 优先当天 readiness 的睡眠/状态/压力；当天未填写时回退 onboarding 日常强度/压力/恢复速度 |
| 伤病记录 | onboarding injury areas | 映射为 danger chip；空值显示「无伤病记录」 |
| 组间休息 | `StudentRestTimerSettingsStoring` | 自动 RPE 或固定分钟/秒文案；继续使用既有设置 sheet |

`TrainingHistoryViewModel` 的日志读取范围扩为从 2000-01-01 至今天，以保证
“全部历史”和趋势不是只统计当前计划周期；Repository 协议与后端均未改变。

## 裁剪与空态

1. E1RM lift 没有记录时，该卡显示 README §7 的
   `完成 3 次训练后解锁趋势`，不制造样机假数据。
2. 容量 / 强度只有达到三个不同的已完成训练日才解锁；不足三次时同样显示
   `完成 3 次训练后解锁趋势`。
3. 反馈 VM 未注入时保留同尺寸卡，显示「暂无反馈数据」，不伪造可点击目的地。
4. onboarding 资料缺失时显示「完成资料填写后解锁」；加载失败显示可重试卡，
   仅保留已有休息偏好和退出能力。
5. `AccountSecurityRepository` 或日志 Repository 未注入时，账号与安全组整体裁剪；
   Student shell 已注入两者，因此正式学员路径显示改密码和导出。
6. 样机未列“注销账号”。既有删除账号能力仍留在可复用
   `AccountSecuritySection` 的默认形态，W2c 我的主屏传
   `showsDeleteAccount: false`，没有删除功能或改后端。
7. 样机外的旧“我的教练 / 评估摘要”不进入 W2c 主屏；readiness 与伤病的已有
   编辑入口保留在样机对应卡内。
8. 全部训练历史详情继续受现有 plan Repository 可提供的计划周范围约束；
   顶部统计和容量趋势则使用全部日志。未为此扩后端协议。
9. W2c 范围属于明确的数据裁剪：`30天` 映射既有 `.fourWeeks`（28 天），
   `90天` 映射 `.threeMonths`，`历史总览` 映射 `.all`；`1年` 先按 `.all`
   取数，再在 presentation 层裁到最近 365 天，并把窗口前最后纪录延续到窗口
   起点。low-confidence `rawEligible` 散点按同一当前范围裁取，未在范围之外
   额外丢弃数据。

## Preview 覆盖

`GrowthProfileV3Previews.swift` 提供 6 个 Preview：

- 成长有数据：Dark / Light
- 成长空态：Dark / Light
- 我的资料：Dark / Light

App 根仍强制暗色，属于本卡范围外；亮色通过成对 Preview 的同一 SwiftUI
实现与 DesignSystem 动态 token 编译验证。

## 视觉与无障碍核验

- iPhone 17 Simulator（iOS 26.5）暗色实跑核验了成长页头、三张 E1RM 卡、
  对比条、反馈、历史统计/入口、趋势空态，以及我的页全部组卡和 danger 退出。
- 实际 demo 深蹲纪录日为 `6/3`、曲线尾线延伸到今天 `7/27`；目视确认金点、
  垂直虚线锚在真实 `6/3`，日期轴显示 `5/10 → 6/18 → 6/3`：左标签 start
  锚定窗口起点，中标签 middle 锚定窗口时间中点，金色 PR 日期 end 锚定轴右端。
  另临时注入 `6/17 · 146kg ·
  imported/.low` 验证弱化菱形散点可见，核验后已撤销临时 seed，
  `StudentDemoSeed.swift` 最终零 diff。
- E1RM 主折线已从暗色语境字面 `.white` 改为与 W2a 今日卡一致的
  `Color.MeetPR.chartLine`；容量 / 强度图的 RPE 折线、圆点、右轴和图例逐项
  复查后确认本来已统一使用同一 token，没有遗留字面白色。
- 为双主题实跑容量 / 强度的有数据形态，临时注入六周 QA 桶并分别在 Dark /
  Light 核验 RPE 折线可见；核验后已撤销 QA 桶和临时亮色根主题，正式 demo
  数据不足三日时仍按原契约显示解锁空态。
- 最终实跑中 demo 既有历史早于 VM 默认四周窗口，W2c 三张卡均自动显示
  `历史总览`，确认局部四档 UI 没有绕过 spec 053 的默认窗口扩展。
- 我的页目视确认恢复三 chip 间两条竖分隔线、伤病 chip 警告三角，以及比赛行
  仅日期 `2026-07-30` 为金色，`备赛:` 与 `· IPF 83kg` 保持主文字色。
- UI 语义快照确认范围胶囊、反馈/历史入口、资料编辑、info、改密码、导出和退出
  均为 Button / NavigationLink，可点击目标不小于 44pt。
- E1RM 范围切换和 info 展开在 Reduce Motion 下禁用动画，其他情况使用
  `MeetPRMotion`。
- 卡片统一使用 `MeetPRRadius.card` / `MeetPRRadius.control` 正典；重量、delta、
  轴、统计和资料大数均使用 Mono / Archivo 数字字体。

## 验证

环境：iPhone 17 Simulator，iOS 26.5。

| 检查 | 结果 |
|---|---|
| StudentKit Swift Testing | 508 passed，0 failed，0 skipped |
| 全部 9 个 SPM packages | 1297 passed，0 failed，0 skipped |
| W2c 新增 presentation 测试 | 8 passed：对比条、历史统计、最近六周、三次解锁门、四档到既有 `TimeWindow` 映射、真实纪录锚与 low-confidence 散点、readiness 优先与 onboarding 回退 |
| `swiftlint lint --strict --quiet --config .swiftlint.yml` | 通过，零输出 |
| `swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` | 通过，零输出 |
| 成长 / 我的屏 `LegacyColors` 与旧色 token grep | 0 命中 |
| 范围红线 grep（今日/训练、ChatUI、CoachKit、AppShell、网络、pbxproj、发版台账） | 0 命中 |
| `MeetPR` / `Debug` iOS Simulator build | succeeded，0 warning |
| `MeetPR-Demo` / `Demo` iOS Simulator build | succeeded，0 warning |
| `MeetPR-DemoStudent` / `DemoStudent` iOS Simulator build | succeeded，0 warning |
| W2c Preview | 6 个，成长有数据/空态与我的均覆盖 Dark / Light |

## 定向返修第 2 轮（像素闸门最终轮）

1. E1RM 卡 x 轴三标签严格按样机 DOM 306–308：
   `start = 窗口起点`、`middle = 窗口时间中点`、`end = 金色 PR 日期`。
   PR 金点和垂直虚线仍停在真实纪录 x；只把 PR 日期标签移到轴右端。
2. 成长卡 E1RM 主折线改用动态 `chartLine`，暗色为浅线、亮色为深线。
   容量 / 强度图的 RPE 折线同查，现有实现已覆盖主线、圆点、右轴和图例，
   无需额外源码变更。

`swift test` 仍会报告本卡前已存在的 warning：
`TodayWorkoutViewModel` 的未变变量，以及 `BindTestSupport` /
`OnboardingTestSupport` 的 Swift 6 async `NSLock` 提示；W2c 改动文件未新增
warning，三套 app build 均为 0 warning。

## 未执行

- 未写 `CODEX-JOURNAL.md`。
- 未写 `NEXT-RELEASE.md`。
- 未 commit。
- 未 push。
