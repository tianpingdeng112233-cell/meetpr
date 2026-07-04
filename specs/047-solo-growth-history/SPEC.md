# SPEC 047 — solo 成长/训练页适配(wave A5)

- **状态**: Draft
- **来源**: 自己练 Free 档 wave 泳道 A5;设计文档条款「成长 tab 全部按 exercise_id 直取,不再必须经计划——solo 与 coached 同等完整;训练 tab solo 形态 = 历史会话列表」。依赖 B2 口径统一(spec 050,已 ship)。
- **侦察(2026-07-04)**:三个 solo 断点源码实锤:
  1. `DashboardE1RMTrendViewModel.load`:家族解析 `MainLiftExerciseFamilyResolver.exerciseIDsByFamily(in: plan)` 走计划树 → solo plan nil → e1RM 点无法归桶 → 成长页三大项曲线恒空(即便 e1RM 点存在)。
  2. `BackendStudentTrainingLogRepository.fetchLogs(studentID:in:)` 硬编码 `scope: .plan` → TrainingHistoryViewModel 的范围取数拿不到 adhoc 组;scope=all 的 API/缓存/契约(U2/U6 已铺)没有消费者。
  3. 训练 tab solo 仍渲染纯 coached 的 TodayWorkoutView(无计划 → 空态/报错),设计定义的 solo 形态=历史会话列表未实现。

## 1. 家族解析:catalog 兜底(曲线归桶)

- `MainLiftExerciseFamilyResolver` 增 catalog 路径:`exerciseIDsByFamily(catalog: [Exercise])`(按 `exerciseType == .mainLift` + `mainLiftFamily` 归桶,与 SoloSessionViewModel.exerciseFamilies 同源做法收敛为一处)。
- `DashboardE1RMTrendViewModel` 增可选 `catalog: [Exercise] = []`:plan 树归桶(coached 主路径,含自编动作)**并集** catalog 归桶(solo 主路径);同 family 并集去重。coached 传空 catalog 零变化;solo 由 StudentRootView 传 soloCatalog。
- **`GrowthCurveViewModel`(我的页成长曲线)同样走 `exerciseIDsByFamily(in: plan)`——同法加 catalog 参数**(侦察补充:第 4 个消费者)。
- TrainingHistoryView 的 `familyForExercise`(PR 行标题/反馈标题用)同样加 catalog 兜底。
- SoloSessionViewModel.exerciseFamilies 的内联字典构造挪进 resolver 新方法,三处同源(收敛)。

## 2. 历史数据:scope=all + 无计划分组

- `TrainingHistoryViewModel` 增 `mode: TrainingMode = .coached`:
  - solo:跳过 plan/cycleDays 取数;`fetchLogs(scope: .all)` 取滚动 **180 天** 窗口(logged_date 口径,复用 U6 训练日窗);分组=**按月**(「2026 年 7 月」sections,内按日卡片倒序)——没有计划周,自然历替代;HistoryWeek 结构复用(id=YYYYMM,days 由 logs 合成伪 StudentPlanDay?**不**——新建轻量 `HistoryDaySession`(date + 动作摘要 + 组数 + 当日最佳 e1RM),不硬套 plan 类型)。
  - coached:零变化。
- 统计行 solo 变体:训练次数(有完成组的天数)/ 三大项合计(同 trend rows)/ 本月次数(替代「训练周」——无计划周概念)。
- 日回顾回显(051 reviewsByDay)对 solo 同样生效(logs 范围驱动 fetch,已实现)。
- 开放项:>180 天分页(数据永在承诺的完整回看)→ F-030 族记一条,V1 窗口先行。

## 3. 训练 tab solo 形态 = 历史会话列表

- StudentRootView solo 分支:`.training` tab 从 TodayWorkoutView 换成 `SoloHistoryView`(§2 的月分组日卡片列表,tab 标题「历史」+ systemImage clock);coached 分支零变化。
- 日卡片:日期/星期 + 动作名摘要 + 组数 + 当日最佳 e1RM(有则显)+ 当日回顾一句话;点开 = 当日明细(复用 set 行只读渲染)。
- 今天的会话编辑始终在「今天」tab(SoloTodayView),历史 tab 只读——扫视态 vs 编辑态分离(platform 决策既有 split 纪律)。

## 非目标

Dashboard(coached 今日页)不动;plan 周分组语义不动;>180 天分页;成长页信息架构重排(仅数据源适配)。

## 测试

- 家族解析:catalog 归桶(蹲/卧/拉各断言)+ plan∪catalog 并集去重;coached 空 catalog 回归。
- TrainingHistoryViewModel solo:scope=all 调用断言(fake repo 记录 scope)+ 月分组正确 + 统计三值;coached 路径回归零变化。
- SoloHistoryView 摘要:日卡片聚合(多动作/组数/当日最佳)。

## 验收

1. solo 记录若干组后:成长页三大项曲线有线、历史明细可见、统计非零;coached 各页零变化。
2. 训练 tab(solo)= 历史列表可浏览可点开明细;今天 tab 编辑动线不变。
3. 全流程零「计划/教练」字样(solo)。
