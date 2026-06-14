# 035 — 仪表盘厚化(e1RM/PR 迷你趋势 + 比赛倒计时 + 通知铃 + 体重只读卡)

- **状态**:InReview
- **PR**:TBD
- **来源**:[[student-experience-redesign-wave]](~/Brain/wiki/projects/MeetPR/student-experience-redesign-wave.md) — David 2026-06-14;仪表盘照 My Strength Book 厚化,但只留力量举相关模块。
- **上游/复用**:
  - `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardView.swift`(现有:`TodayWorkoutCard` / `WeekStrip` / `RecentFeedback` / `DashboardSection` / `DashboardCard` / `EvaluationCompletedCard`)
  - `E1RMRepository`(`fetchHistory(studentId:exerciseIds:) -> [UUID:[E1RMHistoryPoint]]`、`unacknowledgedPRs`)
  - `GrowthCurveViewModel`(family squat/bench/deadlift → catalog exerciseId 解析 + `GrowthCurveView` 成长曲线,在 MyProfile/)
  - `OnboardingProfileReading.fetchProfile` → `OnboardingProfile`(`isCompeting`/`competitionDate` "yyyy-MM-dd"/`weightKg`)
  - `FeedbackInboxViewModel.unreadCount`、`StudentEvaluationSummaryViewModel.unreadBadgeCount`(通知聚合)

## 目标

把过于稀疏的仪表盘(现仅 今日卡 + 本周条 + 教练反馈)厚化成"今日入口 + 信号墙":加 **e1RM/PR 迷你趋势**、**比赛倒计时**、**通知铃**、**体重只读卡**。纯 iOS、**零后端**。

落地后学员看到啥(自上而下):
```
仪表盘                              🔔(有未读红点)
[今日训练 · 深蹲日 / 0/14 组]  开始训练   ← 现有,保留
本周 [一15][二16][(三17)]…                ← 现有,保留(点跳锻炼)
[三大项 e1RM ⌃趋势  最新 PR 深蹲190kg]     ← 新,整卡点进成长曲线
[体重 76.0kg]   [距全国赛 168天]           ← 新两小卡(体重只读 / 倒计时)
教练反馈  查看全部
  · 周四把硬拉降到 RPE8…                    ← 现有,保留
```

## 范围

### 做什么

#### 1. 通知铃(顶栏,纯聚合 · 无 APNs)
- `DashboardView` `NavigationStack` toolbar 右上加 `bell`(有未读 → `bell.badge` + 红点)。
- 未读 = `feedbackVM.unreadCount > 0` || `evaluationSummaryVM.unreadBadgeCount > 0` || 有"未看新计划"。
- tap → `NotificationCenterSheet`(新文件):列出
  - 「教练发布了新计划」(若检测到 plan 较上次查看更新 —— V1 可简化为"当前有已发布计划且未被标记看过";检测不到就不列)
  - 「N 条未读反馈」→ 点跳反馈 tab
  - 「评估已完成」(若 `unreadBadgeCount>0`)→ 点开评估总结
- **纯本地聚合现有 VM 状态**,不新增端点、不请求 APNs 权限。"新计划已看"标记用 UserDefaults(key 含 studentId + planId/最近发布时间)。
- 若聚合逻辑稍重,抽 `DashboardNotificationsViewModel`(@Observable @MainActor)。

#### 2. e1RM/PR 迷你趋势卡
- 一张 `DashboardCard`:标题「三大项 e1RM」+ 右上「最新 PR · {family} {value}kg」(若有)。
- 内容:深蹲/卧推/硬拉三条迷你 sparkline(各取该 family 的 `[E1RMHistoryPoint]`,画 e1RMKg 随时间)。复用 `GrowthCurveViewModel` 的 **family→catalog exerciseId 解析**(别重写;若解析逻辑私有,抽成共享小工具或在 VM 暴露)。
- 数据:`E1RMRepository.fetchHistory(studentId:exerciseIds:[3 个 catalog id])`。
- 「最新 PR」:`unacknowledgedPRs` 里最近一条;无则取三 family 当前 e1RM 最大值标「最佳」。
- 整卡 tap → 现有 `GrowthCurveView`(成长曲线)。(注:wave 终态要点进 036「历史/进度」;036 落地后把目标 repoint 到进度页,本 spec 先连成长曲线。)
- 无任何 e1RM 历史 → 卡显示空态「练几次就有趋势了」,不崩。

#### 3. 比赛倒计时卡
- `OnboardingProfileReading.fetchProfile`:`isCompeting == true && competitionDate` 有效 → 小卡「距比赛 {N} 天」+ 日期;`N = competitionDate(yyyy-MM-dd, 本地日) − 今天`。
- 不备赛 / 无日期 / 已过期(N<0)→ **不显示该卡**(不占位)。

#### 4. 体重只读卡
- `OnboardingProfile.weightKg` → 小卡「体重 {x} kg」**只读**(无"+记录";每日记录 = Wave B)。无值 → 不显示。
- 与比赛倒计时卡并排一行(两个 1/2 宽小卡;只有一个时单独成行)。

#### 保留不动
今日训练卡、本周条(点跳锻炼)、教练反馈、评估完成卡、下拉刷新。

### 不做什么
- 每日体重**记录**(Wave B 后端)、聊天图标、APNs 推送通知、营养/健康瓦片(砍)。
- 重写 e1RM 图表(复用 GrowthCurve)。

## 技术要求
- 模块:`Modules/StudentKit/`。`DashboardView` init 增 `onboarding: any OnboardingProfileReading` + `e1rm: any E1RMRepository`(`StudentRootView` 已持有两者,透传;两个 init 都改)。
- family→catalog 解析:**复用** `GrowthCurveViewModel`,勿在仪表盘重写一份映射(漂移风险)。
- 迷你 sparkline 用 Swift Charts 或轻量 `Path`,对齐成长曲线视觉;`Color.MeetPR.*` token。
- 倒计时天数差:用 `Calendar` 在本地日历日计算,复用既有 date-only 解析(competitionDate 是 "yyyy-MM-dd" 字符串)。
- 拆文件控 SwiftLint ≤400 行/文件:`NotificationCenterSheet.swift`、`E1RMMiniTrendCard.swift` 等独立。func body ≤50、params ≤5、isEmpty、无多尾随闭包。
- swift-format:push 前 docker `swift:6.1-jammy` 验。零后端。

## 验收清单
- [ ] 顶栏通知铃:有未读显红点;tap 出 sheet 列新计划/未读反馈/评估完成;各行点进对应目的地
- [ ] e1RM 迷你趋势卡:三 family sparkline + 最新 PR;整卡点进成长曲线;无历史空态不崩
- [ ] 比赛倒计时:备赛且有日期→「距比赛 N 天」;不备赛/无日期/过期→不显示
- [ ] 体重只读卡显示 onboarding 体重;无值不显示
- [ ] 今日卡/本周条/反馈/评估卡 全部照常
- [ ] family→catalog 解析复用 GrowthCurveViewModel(无重复映射)
- [ ] 通知"新计划已看"标记持久化(UserDefaults),看过不再红点
- [ ] 倒计时天数差单测(跨时区本地日;过期返负→不显示)
- [ ] SwiftLint/swift-format 双过;StudentKit 单测全绿
- [ ] 双 sim 手测:学员仪表盘四新模块齐显示且可点

## 风险 / implementer 关注
1. **family→catalog 解析必复用** `GrowthCurveViewModel`,别在仪表盘再写一份 squat/bench/deadlift→exerciseId 映射。
2. 「最新 PR」数据源:优先 `unacknowledgedPRs`;无则 family 当前 e1RM 最大值,文案改「最佳」。
3. 通知铃 V1 是**聚合现有信号**,不引 APNs、不建后端通知表(那是 Wave B 教练聊天一起做)。"新计划"检测不到就别硬列。
4. `DashboardView` 新增两个 init 参数 → 改 `StudentRootView` 两处调用 + 透传;注意 demo init 也要给(用现有 InMemory*)。
5. 这条与 034 都改 `StudentRootView`,但各自 tab 行不同 → 合并按 wave 顺序(034→035→036),冲突预期可自动解。

## 修订记录
| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-14 | 0.1 | 起草。通知铃(聚合)+ e1RM/PR 迷你趋势(复用 GrowthCurve)+ 比赛倒计时(onboarding)+ 体重只读卡;零后端 | Claude |
