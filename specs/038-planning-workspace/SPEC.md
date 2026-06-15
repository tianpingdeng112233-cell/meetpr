# 038 — 排计划工作台(教练端)

- **状态**:Ready
- **PR**:TBD
- **来源**:[[coach-dashboard-wave]](~/Brain/wiki/projects/MeetPR/coach-dashboard-wave.md)。office hour 2026-06-15:D2=B(排计划 tab 从一个按钮 → 工作台)。
- **上游/复用**:
  - `Modules/CoachKit/Sources/CoachKit/CoachPlanningHomeView.swift`(当前 = "教练端" 标题 + 「排新计划」PrimaryButton → `PlanningCoordinatorView` via fullScreenCover)
  - `Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift`(`loadDraft(traineeID:)` 按学员取草稿;**无"列全部"API** → 遍历花名册学员逐个 loadDraft)
  - `repository: any PlanRepository`(已发布计划查询)、`detailContext.profiles`(学员名)、`rosterViewModel` 的学员列表(遍历草稿/计划用)
  - `StudentPlanView` 投影(plan.startDate / planWeeks → 算计划是否快结束/已结束)

## 目标
把排计划 tab 从"一个孤零零的按钮"变成**计划工作台**:教练点进去能看到手头的活——没排完的草稿、最近发的计划、谁该排计划了——而不是只有"新建"。

落地后教练看到啥:
```
排计划                                  (tab)
[ + 排新计划 ]                          ← 保留 CTA
进行中草稿
  王五 · 力量块 第2周 编到一半   继续 ›
谁需要排计划
  张三 · 计划本周结束            排 ›
  赵六 · 暂无在跑计划            排 ›
最近发布
  李四 · 力量块 4周 · 6月10发    查看 ›
```

## 范围
### 做什么
- **保留** 顶部「排新计划」CTA(开 `PlanningCoordinatorView`,行为不变)。
- **进行中草稿** section:遍历花名册学员 `DraftStore.loadDraft(traineeID:)`,有草稿的列出(学员名 + 进度概要)→ 点「继续」直接进 `PlanningCoordinatorView` 续编该学员草稿。
- **谁需要排计划** section:遍历学员的已发布计划,列出「计划本周内结束」或「无在跑计划」的 → 点「排」进新建并预选该学员。判定 = `startDate + planWeeks*7` 相对今天。
- **最近发布** section:最近发布的计划(按发布时间倒序,取前 N)= 学员名 + 计划概要(kind/周数)+ 发布日 → 点进去查看(只读,复用现有计划查看路径;无则跳过该 section)。
- 各 section 空则不显示;整页空(新教练)回落到只有 CTA 的当前态。

### 不做
- 计划编辑/删除的复杂菜单(MSB workout action menu 那种)——本期只"继续草稿 / 新建 / 查看"。
- 跨学员宏观(归 web)。
- 「谁需要排计划」与 037 分诊条职责不同(那个=需关注 没练/待回复;这个=需要新计划),别合并。

## 技术要求
- 全 CoachKit;数据从 DraftStore + repository + 已 fetch 的 studentPlans **iOS 端聚合,零后端**优先。
- DraftStore 无列举 API → 用花名册学员集合逐个 `loadDraft`(教练带 10–30 人,可接受);若要"列全部草稿"更干净可加一个 `listDraftTraineeIDs()`,implementer 酌情(加了写单测)。
- 「计划快结束/无计划」判定 = 纯函数 + 单测(startDate+planWeeks vs today:本周结束 / 已结束 / 在跑;无计划)。
- CoachKit ⊥ StudentKit 边界;SwiftLint strict(文件≤400 → 各 section 可拆子视图);`xcrun swift-format --strict` 干净。

## 验收
- [ ] 排计划 tab:CTA + 进行中草稿 + 谁需要排计划 + 最近发布,各 section 有数据才显示
- [ ] 草稿「继续」进续编;「谁需要排计划」的「排」进新建并预选该学员;「最近发布」点进查看
- [ ] 计划结束判定纯函数单测(本周结束/已结束/在跑/无计划)
- [ ] 新教练(无草稿无计划)回落到当前"仅 CTA"态,不崩
- [ ] CoachKit build + 测试;swiftlint/swift-format strict 双绿;`MeetPR-Demo` 模拟器手测工作台
- [ ] 不动 学员/我的 tab;与 037 合并顺序 037→038

## 风险
1. DraftStore 按 traineeID 取、无列举 → 遍历花名册;学员多时注意别在 body 里同步 IO(VM 预载)。
2. 与 037 都改 CoachKit;CoachRootView 排计划 tab 行只 038 动。
