# 037 — 学员 tab 今日分诊条(教练端)

- **状态**:Ready
- **PR**:TBD
- **来源**:[[coach-dashboard-wave]](~/Brain/wiki/projects/MeetPR/coach-dashboard-wave.md) + [[coach-cockpit]] 愿景 §3.1。office hour 2026-06-15:D1=B(分诊条放学员 tab 顶,不加 tab)/ D3=A(只两个便宜信号)。
- **上游/复用**:
  - `Modules/CoachKit/Sources/CoachKit/CoachRootView.swift`(学员 tab = `StudentRosterView`,badge = `rosterViewModel.pendingAttentionCount + queueViewModel.pendingCount`)
  - `Modules/CoachKit/Sources/CoachKit/Features/StudentRoster/StudentRosterView.swift` / `StudentRosterViewModel.swift`(`needsAttention` 规则在 ~line 209:`hasRecentLog && !hasNewFeedback`;`pendingAttentionCount`)
  - `StudentRosterRow`(花名册行,`row.needsAttention`)
  - `detailContext`(plans/logs/feedback → 算信号)

## 目标
学员 tab 顶部加一条**「今天 N 个需要你」分诊条**:把需要教练看一眼的学员提到最前(每人一句话原因 + 点进现有学员详情),下方保留现有完整花名册。让教练打开 app 一眼知道今天管谁。

落地后教练看到啥:
```
学员                                    (tab)
┌ 今天 2 个需要你 ────────────────────┐
│ ● 王五   3 天没练                  › │
│ ● 李四   有新记录待你回复            › │
└────────────────────────────────────┘
本周花名册
  张三  本周 3/4  …            (现有 029 花名册,保留)
  …
```

## 范围
### 做什么
- **信号模型**(为助理层预留,愿景 §3.2:事件/数据模型,非临时 UI 状态):新增 `TriageSignal`(枚举/结构):`.notTrained(daysMissed)` 没练 / `.awaitingReply` 待回复。每个 roster 学员算出 `[TriageSignal]`。
  - **待回复** = 现有 `needsAttention` 规则(`hasRecentLog && !hasNewFeedback`)——直接复用/升级成信号。
  - **没练** = 该学员近期有"应训练但无 log"的天(plan 当日有动作、当天/近 N 天无对应 log)。用 detailContext.plans + logs 算;阈值(如连续 ≥2 个训练日缺 log)放一个常量,**保守取值**(信号质量是愿景第 1 红线,宁可少报不可误报)。
- **分诊条 UI**:`StudentRosterView` 顶部插一个 section(在花名册上方):标题「今天 N 个需要你」;每行 = 学员名 + 一句话原因(没练 X 天 / 有新记录待回复)+ chevron;tap → 现有 `StudentDetailView`(复用花名册行的导航)。N=0 时整条不显示(不留空)。
- `pendingAttentionCount` 改为由信号驱动(待回复 + 没练 去重);badge 口径同步。

### 不做
- 破 PR 道喜 / RPE 异常等聪明信号(愿景 D-a / 缓)。
- 把分诊提成独立 tab(D1=B 否决)。
- 跨学员趋势(归 web)。

## 技术要求
- 全 CoachKit;数据从 `detailContext`(coach 已 fetch 的 plans/logs/feedback)**iOS 端聚合,零后端**优先;若按学员逐个算性能差,批量在 VM 一次算。
- 信号算法 = 纯函数 + 单测(给定 plan 天 + logs + feedback → 信号集;覆盖 没练阈值边界 / 待回复 / 无信号 / 跨学员隔离)。
- 别动 CoachKit ⊥ StudentKit 边界(只用 CoreModels/RepositoryContracts 跨界)。
- SwiftLint strict(文件≤400/函数体≤50/参数≤5/isEmpty/无多尾随闭包/sorted_imports);`xcrun swift-format --strict` 干净。

## 验收
- [ ] 学员 tab 顶部分诊条:N>0 显示需关注学员 + 一句话原因;点进学员详情
- [ ] 没练 + 待回复两信号正确;无信号学员不进分诊条;N=0 整条隐藏
- [ ] 信号纯函数单测(阈值边界/两信号/无信号/隔离)
- [ ] badge 计数与分诊条一致
- [ ] 现有花名册 + 详情 + queue 照常
- [ ] CoachKit build + 测试;swiftlint/swift-format strict 双绿;`MeetPR-Demo`(教练 demo)模拟器手测分诊条渲染

## 风险
1. **信号质量是生死线**(愿景红线):没练阈值保守,宁可漏不可误报;demo seed 造几个明确案例验证。
2. 与 038 都改 CoachKit/CoachRootView 不同处 → 顺序合(037→038)。
