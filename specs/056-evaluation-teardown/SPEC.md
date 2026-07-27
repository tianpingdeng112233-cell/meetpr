# 056 — 评估期全拆除（evaluation teardown，含评估总结）

- **状态**: InProgress
- **来源**: David 2026-07-17 拍板：「没有评估期」——评估期为已叫停功能，**评估总结也不留**。前置：#255（2026-07-13 封入口：accept 恒 `skipEvaluation: true`、学员 gate `evaluationSealed` 短路，当时 defer 删除）。本 spec 完成被 defer 的删除。T2 / P1。
- **backend 不动**：评估期端点/表保留为死代码（已发 TestFlight 老 build 仍会调用，硬规则活客户端兼容；schema 级清理等老 build 周期淘汰后另立项）。`skipEvaluation` 字段保留在 Bind 请求 DTO（线上 wire 契约，恒 true）。

## 卡 A — UI 面拆除（教练端 + 学员端 + demo seed）

**教练端**：
- `CoachDashboardView`：删「评估期/进行中」统计列（三列→两列：学员/活跃 + 待关注）；triage 行的 `.inEvaluation` 点色/「评估中」badge 分支删除。
- `StudentRosterView` 一族：删「评估期内」分组（降级为 活跃/异常 两组，空组既有逻辑已自动隐藏）、`.inEvaluation` 点色/副标/badge、`markStudentActive` 回调链。
- `StudentDetailView`：删 evaluation banner/failure strip/倒计时副标/路由；`StudentDetail/Evaluation/` 目录四文件（banner/编辑器及各自 VM）整体删除；`StudentOverviewSection` 的评估总结卡删除。
- `Planning`：Step0「评估期内」分组、Step1「评估期内仅 1 周」限制与 badge、`PlanningStudentHeaderView` 倒计时、`PlanningViewModel`/`PlanningValidationError`/`PlanPublishErrorMapping` 的 `.inEvaluation` 分支——全删（限制随功能消亡）。
- `BindQueueViewModel` 成功 toast 只留「已接收」。

**学员端**：
- `EvaluationPeriodView` + VM 删除；`BindGateViewModel.evaluationActive` 态与 `BindGateView` 对应渲染删除（#255 已短路，本卡删干净）。
- **评估总结不留**：`EvaluationSummaryView`/`StudentEvaluationSummaryViewModel`/`EvaluationSummaryReadStore`/`EvaluationCompletedCard`、MyProfile 评估总结卡、`NotificationCenterSheet` 评估完成条目、`StudentRootView` 相关 VM/badge——全删。
- `OnboardingWizardView` 「教练才能开始评估」文案改为不含评估措辞（如「完成后教练即可为你排课」，实装取现有文案风格）。

**Demo seed**：`CoachDemoSeed.evaluationPeriods` 删除 + `MeetPRApp` 接线删除；`InMemoryPlanRepository` 王晨曦/赵安然改 `.active`（花名册 demo 呈现 活跃 4 + 异常 1）。

## 卡 B — 类型与管线拆除

- `CoachStudentStatus.inEvaluation` case 删除（编译器驱动清全部消费点，含 `CoachStudentFormatting.statusText`、`BackendPlanRepository` 解码分支——后端仍可能对老数据返回 evaluation 态字段时解码为 `.active`，容错不崩）。
- `EvaluationRepository`/`EvaluationSummaryRepository` 契约 + Backend/InMemory 实现、`APIClient+Evaluations.swift` 五端点、`EvaluationDTOs.swift`、`CoreModels EvaluationPeriod` 实体——全删。
- `evaluationSealed` 短路旗（#255 引入）随 `evaluationActive` 态一并删除。
- 相关测试文件同步删除/改写；`skipEvaluation` 在 Bind DTO 保留恒 true + 注释注明 wire 契约缘由。

## 验收

- 两卡各自：repo swiftlint/swift-format 绿；`MeetPR` scheme sim build + StudentKit/CoachKit 测试绿；全仓 `grep -ri '评估' Modules/ MeetPR/` 仅剩 Bind DTO 注释与 onboarding 无关词（卡 B 后）。
- Demo build 模拟器亲验：花名册无「评估期内」组、今日 tab 两列统计、接收 sheet 单键接收、学员 MyProfile 无总结卡。
- 发布位：P1，随下一个内测班车；UI 减法不需要设计稿。

## 变更记录

| 日期 | 版本 | 说明 | 作者 |
|---|---|---|---|
| 2026-07-17 | 0.1 | 初稿（#255 封入口的 defer 删除 + 总结不留一并拆） | Claude |
