# 028 — e1RM 折线 + PR 自动推送(每次训练后本地算 + 突破历史最高 → in-app banner)

- **状态**: Draft
- **PR**: TBD
- **来源**:
  - [PRD §5 #16 成长曲线 + e1RM 推送(v0.7 PR 重塑)](~/Brain/wiki/projects/MeetPR/prd.md) — 1RM 锁定不动 / e1RM 每次训练后自动重算 / 突破历史 → 仅推学员不推教练 / 每动作含 variation 独立 PR 检测
  - [ADR-002(状态:Superseded by PRD §5)](~/Brain/wiki/projects/MeetPR/decisions/002-rpe-tracking-metrics.md) — RPE 计算公式 reference
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — Domain 跨 role 共享 = e1RM 数学(候选 extract,本 spec 仍放 StudentKit,Stage 3 边界再 extract 到 `EvaluationDomain` 之外的纯逻辑 module)
  - 上游 [spec 024 学员端 P0](../024-student-p0-views/SPEC.md) — `StudentSetLog` schema 已含 `weightKg / reps / rpe / completed: Bool`,e1RM 直接读
  - 不依赖 026 backend(全本地算,backend 0 改动)

## 目标

学员每打勾完成一组,系统**本地**自动算这组的 e1RM(估算 1RM),持久化为该动作 `(student, exercise, date)` 的一个数据点;Tab "我的"(本 spec 新增)下进 "成长曲线" 看三大项 折线;若某动作本次训练算出的 e1RM **突破该动作的历史最大**,在 app 内弹 banner "今天你的 squat e1RM 突破!"。

**关键设计 per PRD §5 #16**:
- **1RM 字段锁定不动** — onboarding 填的 1RM 或教练改的 1RM,**不会** 因为训练日 PR 自动更新
- e1RM 是基于训练数据的**估算**,每次训练后系统算,落数据库,与 1RM 是不同字段、不同语义
- **教练侧不推 PR**(教练在学员详情页看曲线看得到即可;教练推送是干扰)→ 本 spec 不动教练端
- **每个动作+变式独立 PR 检测**:深蹲 / 高杠深蹲 / 弓步蹲各自有 e1RM 历史,各自检测各自的 PR
- 折线图 V1 = **单条平均线**(per PRD §5 + ADR-002 状态说明,峰值/区间 V1.5 才上)

落地后学员看到啥:

```
Tab "今天" / "本周" / "历史" / "反馈" / **"我的"**(本 spec 加 Tab 5)
  ↓ 进 "我的" Tab → ListView 第一项 "成长曲线"
进 GrowthCurveView
  ↓ 顶部 segmented "深蹲 / 卧推 / 硬拉"(三大项 + variations 折叠展开)
  ↓ 时间轴 segmented "近 4 周 / 近 3 月 / 全部"
  ↓ SwiftUI Charts 折线 + scatter 点 (每次训练一点)
  ↓ tap 点 → bottom sheet "2026-05-15 周三 · squat W2 第 3 组 100kg×5 @RPE 8 → e1RM 117kg"

[ 学员录完一组某动作(spec 024 已实装) ]
  ↓ toggleComplete 成功 → 本 spec 拦截 → e1RM 计算 + 持久化 + PR 检测
  ↓ 若是 PR → 在 TodayWorkoutView 顶部滑出 PRBanner "今天你的 squat e1RM 突破!117kg",3s 自动消失 + 角标到"我的" Tab
```

## 范围

### 做什么

#### 1. CoreModels 新增 `E1RMHistoryPoint` + `PRBreakthroughEvent`

位置:`Modules/CoreModels/Sources/CoreModels/Entities/Plan/E1RMHistoryPoint.swift`(新)

```swift
public struct E1RMHistoryPoint: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let exerciseId: UUID          // CoreModels Exercise.id (包含 variation)
  public let setLogId: UUID            // 关联到产生此点的 StudentSetLog
  public let computedAt: Date          // 落点时间 = 学员打勾时间
  public let e1RMKg: Double            // 计算结果
  public let sourceWeightKg: Double
  public let sourceReps: Int
  public let sourceRPE: Double?
  public init(...) { ... }
}
```

位置:`Modules/CoreModels/Sources/CoreModels/Entities/Plan/PRBreakthroughEvent.swift`(新)

```swift
public struct PRBreakthroughEvent: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let exerciseId: UUID
  public let pointId: UUID              // 关联 E1RMHistoryPoint
  public let breakthroughE1RMKg: Double
  public let previousMaxE1RMKg: Double
  public let occurredAt: Date
  public let acknowledgedAt: Date?      // 学员 dismiss / 在 banner 上点过 → 不再弹
  public init(...) { ... }
}
```

#### 2. `StudentKit` 新增 `E1RMCalculator`(纯逻辑,无 IO)

位置:`Modules/StudentKit/Sources/StudentKit/Domain/E1RMCalculator.swift`(新)

```swift
public enum E1RMCalculator {
  /// RPE-based(优先;来自 ADR-002 / RTS framework)
  /// e1RM = weight / (1 - 0.02 * (1 - reps + (10 - rpe)))
  /// 简化:每 reps 增 1 ≈ 2% load 损失,每 RPE 降 1 ≈ 2% load 损失,RPE 10 + 1 rep = 100%
  /// 边界:reps >= 1,rpe ∈ [4, 10],否则 fallback
  ///
  /// Epley fallback(无 RPE 时)
  /// e1RM = weight * (1 + reps / 30)
  public static func calculate(
    weightKg: Double,
    reps: Int,
    rpe: Double?
  ) -> Double? {
    guard weightKg > 0, reps >= 1, reps <= 20 else { return nil }
    if let rpe = rpe, rpe >= 4.0, rpe <= 10.0 {
      // RPE-based formula:weight / (1 - 0.02 * (10 - rpe + (reps - 1)))
      let intensity = 1.0 - 0.02 * ((10.0 - rpe) + Double(reps - 1))
      guard intensity > 0.5 else { return nil }   // 安全下限(避免 1RM 估出 200% 离谱)
      return weightKg / intensity
    }
    // Epley fallback
    return weightKg * (1.0 + Double(reps) / 30.0)
  }
}
```

**重要 implementer note**:**RPE-based 公式有多个流派**,本 spec 选 RTS framework(Mike Tuchscherer)版本,与 ADR-002 一致。Codex 实装时**不要换公式**(数字会变),fixture 测试以 ADR-002 数据为准。

#### 3. `StudentKit` 新增 `E1RMRepository`

位置:`Modules/StudentKit/Sources/StudentKit/Repository/E1RMRepository.swift`(protocol)+ `InMemoryE1RMRepository.swift`(actor 实装)

```swift
public protocol E1RMRepository: Sendable {
  func recordPoint(_ point: E1RMHistoryPoint) async throws
  func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint]
  func fetchHistory(studentId: UUID, exerciseIds: [UUID]) async throws -> [UUID: [E1RMHistoryPoint]]
  func maxBefore(studentId: UUID, exerciseId: UUID, before: Date) async throws -> Double?

  func recordPR(_ event: PRBreakthroughEvent) async throws
  func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent]
  func acknowledgePR(eventId: UUID) async throws
}
```

`InMemoryE1RMRepository`:
- actor 持 `[UUID: [E1RMHistoryPoint]]`(key = `(studentId, exerciseId)`)+ `[PRBreakthroughEvent]`
- `maxBefore` 是 PR 检测核心:返回 `< before` 时刻的最大 e1RM
- DEMO_MODE seed 启动时塞历史 8-10 个点 + 1 个 unacknowledged PR(验 banner UI)

#### 4. `TodayWorkoutViewModel.toggleComplete` 拦截 + 算 e1RM + 检 PR

spec 024 `TodayWorkoutViewModel.toggleComplete` 实装 record set。本 spec 在 record set **成功后** 加 hook:

```swift
public func toggleComplete(rowIndex: Int) async {
  // ... spec 024 既有逻辑:recordSet → loggedSetId 回填 → completed = true ...

  // 本 spec 新增 hook:
  guard let weight = draft.actualWeight ?? draft.prescribed.weightKg,
        let reps = draft.actualReps,
        completed else { return }

  let e1rm = E1RMCalculator.calculate(weightKg: weight, reps: reps, rpe: draft.actualRPE) ?? return

  let point = E1RMHistoryPoint(
    id: UUID(), studentId: ..., exerciseId: planExercise.exercise.id,
    setLogId: setLog.id, computedAt: Date(),
    e1RMKg: e1rm, sourceWeightKg: weight, sourceReps: reps, sourceRPE: draft.actualRPE
  )
  try? await e1rm.recordPoint(point)

  let previousMax = (try? await e1rm.maxBefore(studentId: ..., exerciseId: ..., before: point.computedAt)) ?? 0
  if e1rm > previousMax + 0.5 {   // 0.5kg buffer 防浮点抖动重复 PR
    let event = PRBreakthroughEvent(
      id: UUID(), studentId: ..., exerciseId: ..., pointId: point.id,
      breakthroughE1RMKg: e1rm, previousMaxE1RMKg: previousMax, occurredAt: Date(),
      acknowledgedAt: nil
    )
    try? await e1rm.recordPR(event)
    pendingPRBanner = event   // ViewModel 暴露 @Published / @Observable 给 view 弹 banner
  }
}
```

#### 5. `PRBanner` UI

位置:`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/PRBanner.swift`(新)

学员看到啥:
- 屏顶 ribbon,绿色背景,emoji 🎉 + "今天你的 squat e1RM 突破!117kg(此前 112kg)"
- 3s 后自滑出,期间可手动 tap dismiss → `E1RMRepository.acknowledgePR(eventId:)`
- 若有未 dismiss 的 PR,启动 app 时也补弹一次 → 防漏看

#### 6. Tab 5 "我的" + GrowthCurve

新加 Tab 5 `MyProfileTab`(暂只放 "成长曲线" 入口,资料/设置 V0.1.x;TabView 现在 5 tab):

位置:`Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileView.swift`(新)

```
List {
  NavigationLink("成长曲线", destination: GrowthCurveView(...))
  // V0.1.x: 我的资料 / PR 通知设置 / 退出登录
}
```

`GrowthCurveView`:
- 顶部 segmented `[ 深蹲 ][ 卧推 ][ 硬拉 ]`(三大项),tap variation icon 弹 sheet 选具体变式(本 spec 仅"主项",变式 sheet V0.1.x)
- 下方 SwiftUI Charts `LineMark + PointMark`,x 轴日期(按时间轴 segmented 切),y 轴 e1RM
- tap 点 → bottom sheet 显示原始 set 数据 + 链接跳回当日 history view(reuse spec 024 `DayDetailView`)
- 空数据(新学员)→ "至少打勾 1 组训练才有第一点"

时间轴 segmented:`[ 近 4 周 ][ 近 3 月 ][ 全部 ]`,默认近 4 周(对内测期数据稀疏友好)。

#### 7. 教练端 0 改动

本 spec **不动** CoachKit。教练侧看曲线在 spec 029 教练端 review 内顺手做(reuse 本 spec 的 `GrowthCurveView` + `E1RMRepository`)。

#### 8. 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/StudentKit/Tests/StudentKitTests/Domain/E1RMCalculatorTests.swift`(新) | RPE-based 8 fixture(weight/reps/rpe → 预期 e1RM 误差 < 0.5kg);Epley fallback 4 fixture;边界(reps=0 / reps=20 / rpe=3.5);intensity < 0.5 返 nil |
| `Modules/StudentKit/Tests/StudentKitTests/Repository/E1RMRepositoryTests.swift`(新) | record / fetch / maxBefore(空 / 单点 / 多点 / 时间过滤);PR 流(unacknowledged + acknowledge) |
| `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkoutPRHookTests.swift`(新) | record set 后 hook 触发:已知历史 + 新点 → 是否检 PR / 是否不检(回退);0.5kg buffer 边界 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/GrowthCurveViewModelTests.swift`(新) | 时间轴切换数据过滤;空数据态 |

#### 9. `StudentRootView` 改 5 tab

```swift
TabView {
  TodayWorkoutView(...).tabItem { ... }
  WeekOverviewView(...).tabItem { ... }
  TrainingHistoryView(...).tabItem { ... }
  FeedbackInboxView(...).tabItem { ... }
  MyProfileView(...).tabItem { Label("我的", systemImage: "person") }
    .badge(pendingPRCount)   // 启动时有未 ack PR → 角标
}
```

构造器扩参数 `+ e1rm: E1RMRepository`。

### 不做什么

**V0.1.x defer**:
- 变式 sheet(深蹲下分 高杠/低杠/弓步/分腿 等)— 本 spec 仅"主项"维度;变式独立曲线 V0.1.x 单独 spec
- 推送通知(APNs):本 spec 仅 in-app banner;V0.1.x 加 push
- PR 突破推送的"教练侧静默 logging"(per PRD #16 "教练侧不推,但教练看曲线能看到"):教练侧曲线 reuse 由 spec 029 做,推送本身不存在(本 spec 即"不推教练")
- 单 set vs 整组判定:本 spec 每组打勾就算一个 e1RM 点,**不在 view 层做"该组最佳一组" pick**(以 set 为粒度算,曲线点密但真实)
- 1RM 字段编辑 UI:onboarding 流 V0.1.x(候选 2 完整版)+ 教练改 1RM = 评估总结 V0.1.x
- 周期对齐:Stage 4 大数据量后可能要 weekly aggregate;V0.1 单 cycle 内点数 < 100,List 直接渲染

**V0.2+ defer**:
- 跨学员 e1RM 对比(教练侧 dashboard,网页端 macro analytics,V1.5+)
- 训练量(volume = weight × reps × sets)曲线 / 强度区间分布 / 峰值 vs 平均 RPE(ADR-002 中被 PRD 延后到 V1.5)
- 教练写"目标 1RM" → 与 e1RM 折线对比(V2 算法生成 prerequisite)

## 技术要求

### 数据持久化策略

V0.1 **in-memory**(per spec 024 `InMemoryStudentTrainingLogRepository` pattern);spec 026 落地后切 JSON file cache(per ADR-005 §4 `Documents/training_log/*.json`)。

JSON file schema:
```
Documents/e1rm/
  ├── points-<studentId>.json    # [E1RMHistoryPoint]
  └── prs-<studentId>.json       # [PRBreakthroughEvent]
```

Stale-while-revalidate 模式:启动先读 cache,后台 backend fetch 同步(spec 026 加 `BackendE1RMRepository` 实装)。

### E1RM 公式来源(防 implementer 篡改)

本 spec 公式锚定 RTS framework(Mike Tuchscherer / Reactive Training Systems):

| reps | RPE 10 | RPE 9.5 | RPE 9 | RPE 8.5 | RPE 8 | RPE 7 | RPE 6 |
|---|---|---|---|---|---|---|---|
| 1 | 100% | 98% | 96% | 94% | 92% | 88% | 84% |
| 2 | 96% | 94% | 92% | 90% | 88% | 84% | 80% |
| 3 | 92% | 90% | 88% | 86% | 84% | 80% | 76% |
| 4 | 88% | 86% | 84% | 82% | 80% | 76% | 72% |
| 5 | 86% | 84% | 82% | 80% | 78% | 74% | 70% |

**算法等价于** `intensity = 1.0 - 0.02 * ((10 - rpe) + (reps - 1))`,e1RM = weight / intensity。

fixture 测试至少含上表 5 行的 7 列每个组合,误差 ≤ 0.5kg 容忍(浮点)。Epley fallback 仅在 RPE 缺失或越界时使用,fixture 测试覆盖。

### PR 检测的 0.5kg buffer

浮点 e1RM 可能因 RPE 输入扰动产生 0.x kg 差异,触发"假 PR"。`buffer = 0.5kg`(per 7e1RM 计算误差经验值),小于该值差异不算 PR。文档 + 单测显式 fix 此常量。

### 版本 / 兼容

- iOS 17.0+
- SwiftUI Charts(iOS 16+)V0.1 用,V1 普及版本要求一致
- 不引第三方 chart 库

## 验收清单

- [ ] CoreModels 新 2 类型 Codable roundtrip 单测
- [ ] `E1RMCalculator` RPE-based + Epley 双路径,fixture ≥35 case,边界 ≥ 5 case
- [ ] `InMemoryE1RMRepository` actor 单测 + maxBefore PR 检测路径过
- [ ] `TodayWorkoutViewModel` hook 在 toggleComplete 后调用 + PR 检测落地,单测验证
- [ ] `PRBanner` UI 在 simulator 真渲染过,3s 自滑出 + tap dismiss + 启动补弹
- [ ] `MyProfileView` Tab 5 加入 `StudentRootView`
- [ ] `GrowthCurveView` 三大项 segmented 切换 + 时间轴切换 + tap 点 bottom sheet
- [ ] 单测 `seed → 时间轴过滤` 验证
- [ ] DEMO_MODE seed 启动 8-10 个点 + 1 个 unacknowledged PR,验 banner 启动补弹
- [ ] CI 全过

## 估时(给 Codex 参考)

| 块 | 估时 |
|---|---|
| 1. CoreModels 2 类型 + 单测 | 0.3d |
| 2. `E1RMCalculator` + 公式 fixture | 0.5d |
| 3. `InMemoryE1RMRepository` + 单测 | 0.5d |
| 4. `TodayWorkoutViewModel` hook + 单测 | 0.5d |
| 5. `PRBanner` UI + 启动补弹 | 0.4d |
| 6. Tab 5 + `MyProfileView` 入口 | 0.2d |
| 7. `GrowthCurveView` SwiftUI Charts + bottom sheet | 1d |
| 8. seed 数据 + 整合测试 | 0.4d |
| 9. 手动跑 + bug 修 | 0.2d |
| **合计** | **4d** |

## 风险 / 待 implementer 关注

1. **公式不要换** — RPE-based RTS 公式 fixture 严格锚定,Codex 若引"更精准"公式(Brzycki / Lombardi / Wathan 等)会破单测;不同流派差异 ±3-5%,在内测期就被你或 xty 察觉数字"漂移"
2. **0.5kg PR buffer 来源**:浮点 e1RM 与"称重 0.5kg 增量"是平行轴,buffer 仅消化浮点抖动,真实人脑能感知的 PR 是 +1-2.5kg 级。若内测期发现"PR 弹得太勤",buffer 可调到 1.0kg
3. **DEMO_MODE seed PR 时机**:启动时若 student seed 含 unacknowledged PR,banner 启动 1.5s 后弹(让 Tab 1 先渲染)→ Codex 实装时用 task delay 0.5-1s 缓冲
4. **5 tab 拥挤**:iOS HIG 推荐 ≤ 5 tab,本 spec 刚好踩线;V0.1.x 若加更多 tab 必须收 More 抽屉
5. **教练侧曲线 reuse**:spec 029 实装时直接复用 `GrowthCurveView` + `E1RMRepository.fetchHistory(studentId:)`,本 spec **不画**教练侧入口
6. **重 set 行为**(学员误点 ✓ 反悔取消勾):spec 024 已设计 "再 tap ✓ 取消 complete";本 spec hook 仅在 `completed: true` 边沿触发 record point;取消 → V0.1 留 orphan E1RMHistoryPoint(不删,因为 setLog 被取消但学员已经看到过 PR);**实装时 hook 加 `completed == true && previously false` 边沿条件**

## Implementation Notes

无(spec PR 阶段)。

## 上游 / 下游

**上游**:
- spec 024 学员端 P0(`StudentSetLog` / `TodayWorkoutViewModel`)
- ADR-002 + PRD §5 #16(公式来源 + 锁 1RM 规则)

**下游**:
- spec 026 backend 真接入:加 `BackendE1RMRepository` 用 backend `/students/:id/e1rm` endpoint,JSON file cache + stale-while-revalidate
- spec 029 教练端 review:复用 `GrowthCurveView` 在学员详情页展示
- V0.1.x APNs push:`PRBreakthroughEvent.occurredAt` 触发服务端 push
- V0.1.x 变式 sheet:Exercise.variants 维度独立曲线
- V1.5 ADR-002 重启:训练量 / 区间分布 / 峰值 vs 平均 RPE

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。本地算 + in-app banner + 5 tab "我的" 入口 + 三大项主项曲线 | Claude |
