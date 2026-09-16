# spec 080 — 学员端消费教练后移（推荐日期叠加后移 + 推送刷新）

- **状态**: Done（iOS 随 #344 于 2026-09-16 落线，配套后端部署/APNs 验收仍待；原批准：David 2026-09-02 grill 拍板：1A 2不做 3A 4赞同 5同意 6进；契约以 backend 045 为准）
- **级别 / 节奏**: T1（单端 StudentKit + CoreModels 路由，≤5 文件）；P1，目标 1.0(22) 班车（发版线 `release/1.0`）。
- **对应 backend**: `045-coach-plan-shift`（契约权威）；**基线**: `feat/plan-refresh`（`plan_updated` 路由 + 前台/切 tab 重拉）合入 release/1.0 之后再切分支。
- **先读**: 仓根 `CONTEXT.md`（游标日 / 推荐日期 / 后移）。

## 问题

教练在网页端把某日起的训练后移 N 天后，学员手机要「自动更新」：推荐日期显示新日期，并收到一条推送。现状 071 把 `shiftedToDate` 改为「读入但不消费」，学员看到的仍是原排期。

## 对 spec 071 拍板 2 的修订（⚖️2026-09-02）

「推荐日期不再叠加 `shiftedToDate` 覆盖」修订为：**推荐日期 = `shiftedToDate ?? scheduledDate`**（即现有 `StudentPlanDay.date`）。理由同 backend 045：后移现在是教练显式动作，忠实教练排期反而要求叠加。游标、可写日、完成判定**一概不变**——推进制不受影响。071 §顺延 UI 下线 的删除清单不复活。

## 改动

### 1. 推荐日期口径（StudentKit）

所有学员面向「推荐日期」的展示改用 `day.date`（不再直接读 `scheduledDate`）：

- `DashboardTodayPresentation`：`recommendedDate`、`planDate`、`recommendedDateText` 输入。
- `DashboardPrimaryAction` 副标「教练推荐 M月D日」。
- `DashboardView` 周区间（约 L343）。
- `TodayWorkoutView` / 训练 tab 周列表行的推荐日期灰字。
- `TodaySetRefSharingSource.dayDate`（set-ref 卡片上的日期）。
- **不改**：Demo seeds（`loggedAt` 造数）、`DashboardEmptyStatePresentation` 的反馈日期匹配（按教练原排期匹配反馈，保持）、日志拉取窗口（全周期 pad 1 天，`scheduledDate` 与 `date` 都落在窗内；若 pad 不够改为按 `date` 取最值）。
- `StudentPlanDay.date` 上的注释「Student sequence surfaces must use scheduledDate」删除，改为指向本 spec。
- 缓存：`StudentPlanCache.fileVersion` **不 bump**（`shiftedToDate` 早已在缓存投影里，先返缓存后台重拉即可拿到新值）。

### 2. 推送路由（CoreModels + StudentKit，基于 feat/plan-refresh）

- `PushNotificationKind` 新增 `planShifted = "plan_shifted"`、`planShiftUndone = "plan_shift_undone"`；路由与 `.planUpdated` 同形（`studentID` + `planID`），`StudentNotificationRouting` / `StudentRootView` 里与 `.planUpdated, .planPublished` 同一分支：触发 `StudentTrainingPlanRefreshTrigger` 重拉并落到训练 tab（与 `plan_updated` 同路由 `.plan`，⚖️2026-09-02 review 修订：原文误写 Dashboard）。
- `CoachRootView` 对这两种 kind 与 `.planShift` 同分支（教练端不处理）。
- 老包不认识新 kind：`PushPayloadParser.route` 返回 nil，按现有 unknown 处理，不崩。

### 3. 教练端徽标（CoachKit，仅文案）

`StudentDetailViewModel.planShiftBadgeText` 的「已顺延 %lld 天」→「已后移 %lld 天」；xcstrings zh/en 同步。不加新 UI。

## 验收 / 回归矩阵

- 后端造一批 3 天后移 → 冷启（有缓存）Dashboard 先显示旧推荐日期、后台重拉后变新日期；下拉刷新立即变。
- 推送 `plan_shifted` 到达 → 前台点开落训练 tab（同 `plan_updated`）且已重拉；后台收到后回前台自动重拉（feat/plan-refresh 既有行为）。
- 游标日、CTA、可写日、完成/撤销完成：与后移前完全一致（回归矩阵沿 071 §验收）。
- 存量带学员 V2 顺延数据的计划：推荐日期显示叠加后的日期（与 071 拍板 2 验收项**相反**，本 spec 明示替换该项）。
- 教练端「已后移 N 天」徽标读 `totalShiftDays` 新口径正常。

## 测试 seam

- `DashboardTodayPresentationTests`：`shiftedToDate` 非空时 `recommendedDate`/副标用它；nil 时回落 `scheduledDate`；游标不受 `shiftedToDate` 影响（同一 fixture 断言 cursor 不变）。
- `PushNotificationRoutingTests`：两种新 kind 解析为路由意图；未知 kind 仍 nil。
- `TodayWorkoutRefreshTests`（feat/plan-refresh 已有）：新 kind 触发 refresh revision +1。

## Out of Scope

- 学员端任何后移/撤销入口（Q2 拍板不做）；「已后移」提示条或红点（只靠推送 + 日期本身）。
- 教练 iOS 端发起后移。
- 顺延 V1/V2 代码复活；main 线残留的 V1 UI 分诊另议。
