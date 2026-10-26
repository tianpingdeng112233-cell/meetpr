# 卡 I · 095 iOS（apps/MeetPR）绑定后首次体验

先读仓根 `CONTEXT.md`（「一次绑定」「第一份计划」两条），再读同目录 `SPEC.md`（口径、验收、Out of Scope 以它为准）与 `DESIGN.md`（定稿屏幕稿转写，结构与文案照它做）。

## 目标
CN 与 Global 两轨都做：待接收页 30 秒轮询与「教练接受后提醒我」、欢迎页（含「教练发计划时提醒我」）、新学员版等计划卡、第一份计划卡、学员角色通知权限时机改动、`bind_accepted` 推送点开路由、埋点、三语文案。

## 文件范围
- `Modules/StudentKit/Sources/StudentKit/Features/Bind/`：`BindGateViewModel.swift`、`BindGateView.swift`、`PendingBindView.swift`、`PendingBindViewModel.swift`，新增欢迎页视图
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/`：`DashboardTodayScreen.swift`、`DashboardPlanWaitingState.swift`、`DashboardTodayPresentation.swift`、`DashboardPrimaryAction.swift`（计划卡显示期间隐藏底部「开始训练」）
- `Modules/AppShell/Sources/AppShell/PushRegistrationStateMachine.swift`、`PushRegistrar.swift`（学员角色「未决定」时不再自动请求；新增按需请求入口）
- `Modules/CoreModels/Sources/CoreModels/PushNotificationRouting.swift`（`bind_accepted` → 打开 App 并刷新绑定状态）
- 本地「已看过/已关闭」记录，键 = 学员 id + bind_request id；沿用现有本地存储做法（参考 `DashboardNotificationsViewModel` 的 seen store）
- 文案目录（简体、英文；繁体按 spec 094 生成流程与覆写表）与对应测试

## 约束
- 判定口径严格按 SPEC「判定口径」；现有出参判断不了时在 JOURNAL 写明并回报，不改用别的口径。
- 教练角色与自主训练学员的通知权限时机不变；已允许的学员照旧注册设备令牌。
- 老学员（本次绑定已有结算过的训练日）首页与现状逐字一致；两周之间的原等计划卡逐字不变。
- 评估期封存（`evaluationSealed`）不动；不改 tab 结构、不加依赖。
- 不 commit、不 push（Opus 收货后提交）。

## 验收
SPEC「验收清单」全部九条中 iOS 适用部分。你负责：单测先红后绿 + 两轨 Xcode 编译 + 全量单测绿 + 模拟器上第 1、2、3、5 条截图（存 `docs/evidence/spec095-<日期>/`）。第 4 条真推送依赖后端 PR #338 部署，Opus 后验。

## 测试 seam
- `BindGateViewModelTests`：欢迎页判定、轮询、accepted 后进欢迎页。
- `DashboardTodayPresentationTests`：新/老两种等计划卡、第一份计划卡出现与关闭、底部按钮隐藏。
- `PushRegistrationStateMachineTests`：学员「未决定」不自动请求、按需请求、已允许照旧注册、教练不变。

## 交付
JOURNAL 写 `docs/journal/2026-10-26-095-I.md`（一卡一文件）。最后回报：改动文件列表、测试数字、截图路径、与 SPEC/DESIGN 不符或做不到的地方。
