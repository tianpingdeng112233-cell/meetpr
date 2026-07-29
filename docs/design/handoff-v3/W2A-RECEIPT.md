# W2a 回执 — 今日屏卡（学员端黑金 UI v3）

## 交付范围

- 重做 `DashboardView` 为 v3 今日屏，数据继续来自既有
  `WeekOverviewViewModel`、`FeedbackInboxViewModel`、
  `DashboardE1RMTrendViewModel`、`DashboardProfileMetricsViewModel` 和
  `StudentNotificationsCoordinator`。
- 使用 W1 的 `GoldCTA`、`HeaderChatButton`、`Sparkline` 与 v3 token；
  本卡新增页面不再引用 `LegacyColors`。
- 删除全仓无调用的 `E1RMMiniTrendCard.swift`。
- `StudentDemoSeed.competitionDate` 改为运行当天加 3 天。
- 日期修真按最小范围调整 `PlanCalendarDayIdentity`、
  `PlanDayShiftLogic` 和 `WeekOverviewViewModel`；未修改 repository
  endpoint、网络契约、训练/成长/我的页实现、ChatUI、CoachKit、AppShell、
  `CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。
- **允许项连带**：`ProfileSummaryFormatterTests` 读取同一个
  `StudentDemoSeed.makeOnboardingProfile`。competition date 改为动态 seed 后，
  原测试固定断言 `2026-07-25` 必然失真，因此同步改为断言 profile 的实际日期；
  只改测试期望，未修改“我的”页实现。

## 样机 DOM → SwiftUI 映射

唯一视觉标准：
`docs/design/handoff-v3/MeetPR 学员端.dc.html` 今日屏 DOM 82–166 行及
`renderVals` 的 `weekCells`、`weekBars`、`selLifts`、`dayLabel`、
`ctaActive`、`ctaPostponed` 等派生逻辑。

| 样机 DOM | SwiftUI 结构 | 映射内容 |
|---|---|---|
| 82–91 | `DashboardHeader` | MEETPR 描边字标（尾 R `-.13em` 内收）、UTC 日期、按训练日累计的 WnDn/休息日标题、`headlineEmboss` 主题层、协调器存在时的 44pt 聊天气泡、danger badge、训练周三态进度条 |
| 92–113 | `DashboardFeedbackCard` | 最新反馈预览、未读胶囊、两层堆叠假卡、展开/收起控制、内联反馈列表 |
| 114–122 | `DashboardWeekCalendar` | 周一至周日七格、S/B/D 三槽、选中金底 12% 与 1.5pt 金描边、该日有/无图例 |
| 123–126 | `DashboardProfileMetricsView` | 体重卡、金渐变距比赛卡、旗帜/火焰 SVG、金字发光 |
| 127–145 | `DashboardE1RMRail` | 横滑 rail、分页圆点、90 天 E1RM、面积渐变、白色折线、末端金点 |
| 146–148 | `DashboardRestDayCard` | 休息日/无计划缺失态；今日无计划时补下一次训练日期 |
| 149–158 | `DashboardPrimaryAction` | `GoldCTA` 主 CTA、动态“蹲·推·拉”副标、播放 SVG、shimmer、顺延入口 |
| 159–163 | `DashboardPostponedState` | 绿色确认条、“今日休息”卡、下划线“撤销顺延” |

## 动效

- CTA 按压蓄力直接复用 W1 `GoldCTA` 的 mold-held 参数。
- 反馈预览先以 50ms 淡出。
- 容器使用 380ms overshoot timing curve，峰值约 2–3px。
- 前四条反馈分别以 20/50/80/110ms 延迟，从 `translateY(-8)` 进入 0。
- 箭头以 260ms 旋转 180°。
- 所有上述动效都读取 `accessibilityReduceMotion`；开启后立即切换状态。
- CTA → 训练页 morph 转场未实现，按 W5 边界继续走既有 tab 切换。

## 两处记录在案的交互偏离

1. 反馈条目点击当前进入既有 `FeedbackDetailView`；样机进入聊天，等待聊天合流卡。
2. `StudentNotificationsCoordinator` 存在时，顶栏气泡打开既有
   `NotificationCenterSheet`；协调器不存在时不提供入口。样机直开聊天的合流
   仍等待聊天黑金卡。

## WnDn 口径决定

- `D` 不是周一位置偏移，而是样机 `WEEK.slice(0, selDay + 1)` 中截至选中日
  （含当天）的训练日累计数。
- 周五种子日因此显示 `W1D4`，并补周日为训练日时继续累计的覆盖。
- 选中休息日只显示 `Wn`，旁边保留“休息日”胶囊。
- 本改动只影响今日屏头条；计划 `day_of_week` / 投影排程语义未修改。

## 日期口径（混合契约，与仓内 `PlanCalendarDayIdentity` 及训练页一致）

- **「今天」/选中日/可见周 = 设备日历**（`Calendar.current`），与训练页同契约；
  Header 的选中日日期与星期用设备分量格式化。
- **计划锚定日期 = UTC 分量**：计划日匹配走 `PlanCalendarDayIdentity.matches`
  （planDate UTC 分量 vs selectedDate 设备分量）；下一训练/休息卡等计划日期文本用
  UTC 分量格式化（`monthDayText` 默认 UTC，设备日期显式传 `.current`）；顺延态的
  「明天」标签（设备概念）用设备日历计算并格式化。
- **顺延 = mutation 契约（UTC）**：spec 054 的 `POST /plans/:id/shift` 无日期参数、
  服务端锚 UTC 今天，因此 proposal 按 UTC 解析目标日；入口在设备日与 UTC 日分叉窗口
  （UTC+8 的 00:00–08:00）内**隐藏**（`shiftTargetsSelectedDay` 守卫），避免
  「弹窗描述 A 日、服务端顺延 B 日」。**真解法 = shift 接口带目标日期参数，属后端
  跟进项，不在本波**。当天撤销窗口沿用既有 UTC 行为。
- `WeekOverviewViewModel` 仍给本周 UI 返回当周切片，同时最小保留完整周期
  `cycleDays`，仅供休息日查找 `date > 今天` 的最近训练；网络层未改。
- 边界覆盖：上海 00:30（页面解析 local 日、顺延入口隐藏、proposal 按 UTC 解析前一日，
  三者各自锁死）、UTC 周日 23:30（仍在正确周）、周日休息后跨周一的下一训练。
- 未引入 gym-day 04:00 截断；该项仍属于独立残办。


## Preview 覆盖

`DashboardV3Previews.swift` 提供以下五种状态的暗色/亮色成对 Preview，共 10 个：

- 正常训练日
- 休息日/无计划（含下一次训练时间）
- 已顺延（Preview 通过 `InMemoryStudentPlanRepository.shiftPlan` 生成真实顺延投影）
- 反馈展开
- 无反馈（“暂无新反馈”）

## 验证

环境：iPhone 17 Simulator，最新可用 iOS runtime。

| 检查 | 结果 |
|---|---|
| StudentKit Swift Testing | 485 passed，0 failed，0 skipped |
| 全部 9 个 SPM packages | 1274 passed，0 failed，0 skipped |
| W2a presentation tests | 11 passed |
| `swiftlint lint --strict --quiet --config .swiftlint.yml`（全仓） | 通过，零输出 |
| `swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` | 通过，零输出 |
| `git diff --check` | 通过，零输出 |
| W2a 页面 `LegacyColors`/旧 token grep | 0 命中 |
| `MeetPR` / `Debug` iOS Simulator build | succeeded，0 warning |
| `MeetPR-Demo` / `Demo` iOS Simulator build | succeeded，0 warning |
| `MeetPR-DemoStudent` / `DemoStudent` iOS Simulator build | succeeded，0 warning |
| DemoStudent 暗色周日训练态 | 已在模拟器核验 `W1D3`、Header 层次与气泡入口 |
| DemoStudent 暗色反馈展开态 | 已点击展开/收起并核验内联 3 条反馈 |
| DemoStudent 真实顺延态 | 已实际确认顺延；核验 `W1 + 休息日`、跨周下次训练、确认条/今日休息/撤销三段式 |

说明：最终一轮 XcodeBuildMCP 的 9 包测试与三套 App build 均返回零 warning /
零 error。首次增量编译曾重报未触碰测试 support 的既有 Swift 6 `NSLock`
诊断；修正本轮唯一编译错误（WeekOverview 测试漏 `CoreModels` import）后，
完整复跑结果全绿。

## 未执行

- 未 commit。
- 未 push。
