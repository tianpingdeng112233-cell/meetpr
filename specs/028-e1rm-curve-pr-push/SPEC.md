# 028 — e1RM 折线 + PR 自动推送(每次训练后本地算 + 突破历史最高 → in-app banner)

- **状态**: Draft
- **PR**: TBD
- **来源**:
  - [PRD §5 #16 成长曲线 + e1RM 推送(v0.7 PR 重塑)](~/Brain/wiki/projects/MeetPR/prd.md) — 1RM 锁定不动 / e1RM 每次训练后自动重算 / 突破历史 → 仅推学员不推教练 / 每动作含 variation 独立 PR 检测
  - [ADR-002(状态:Superseded by PRD §5)](~/Brain/wiki/projects/MeetPR/decisions/002-intelligent-analysis-over-passive-display.md) — RPE 公式 historical reference,**状态被 PRD §5 supersede**;本 spec 的公式权威源是 RTS 表(见 §技术要求)
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

**Source of truth(2026-05-15 接 PR #116 Codex review #1 blocker)**:RTS(Reactive Training Systems,Mike Tuchscherer)RPE 强度表为权威数据源,**lookup + bilinear interpolation** 实装。**不**用单一线性公式 — 因为 RTS 表在 reps 1-4 与 reps 5+ 是分段斜率(reps 1-4:-4%/rep;reps 5+:-2%/rep),线性公式 `1.0 - 0.02 × ((10 - rpe) + (reps - 1))` 在 reps=5 RPE=10 算出 92% 但 RTS 表 = 86%(差 6%)。

```swift
public enum E1RMCalculator {
  /// RTS RPE 强度表(% of 1RM),source of truth
  /// rtsTable[reps - 1][rpeIndex],其中 rpeIndex = Int((rpe - 6.0) / 0.5)
  /// reps 范围 1-12;RPE 范围 6.0-10.0 步 0.5(9 列)
  private static let rtsTable: [[Double]] = [
    // RPE:    6.0   6.5   7.0   7.5   8.0   8.5   9.0   9.5   10.0
    /* 1 */  [0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.96, 0.98, 1.00],
    /* 2 */  [0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.96],
    /* 3 */  [0.76, 0.78, 0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92],
    /* 4 */  [0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86, 0.88],
    /* 5 */  [0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86],
    /* 6 */  [0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84],
    /* 7 */  [0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82],
    /* 8 */  [0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80],
    /* 9 */  [0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78],
    /* 10 */ [0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76],
    /* 11 */ [0.58, 0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74],
    /* 12 */ [0.56, 0.58, 0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72],
  ]

  public static func calculate(
    weightKg: Double,
    reps: Int,
    rpe: Double?
  ) -> Double? {
    guard weightKg > 0, reps >= 1 else { return nil }

    if let rpe = rpe, rpe >= 6.0, rpe <= 10.0 {
      // RTS lookup,reps 越界 saturate 到 12,RPE 线性插值(0.5 间隔)
      let safeReps = min(reps, 12)
      let intensity = rtsIntensity(reps: safeReps, rpe: rpe)
      guard intensity > 0.5 else { return nil }   // 安全下限
      return weightKg / intensity
    }

    // Epley fallback(RPE 缺失或 < 6 越界):e1RM = weight * (1 + reps / 30)
    guard reps <= 20 else { return nil }
    return weightKg * (1.0 + Double(reps) / 30.0)
  }

  /// RTS table lookup + RPE bilinear interpolation
  /// reps 取整数(实装期学员录 reps 是 Int);RPE 0.5 间隔之间用线性插值
  private static func rtsIntensity(reps: Int, rpe: Double) -> Double {
    // 找到 rpe 在表内的两个相邻 column index
    let rpeFloat = (rpe - 6.0) / 0.5   // 6.0 → 0, 6.5 → 1, ..., 10.0 → 8
    let lo = Int(rpeFloat.rounded(.down))
    let hi = min(lo + 1, 8)
    let t = rpeFloat - Double(lo)
    let row = rtsTable[reps - 1]
    return row[lo] * (1 - t) + row[hi] * t
  }
}
```

**E1RMCalculator fixture 测试**(本 spec 单测最高优先级,**直接覆盖 RTS 表内每个 cell** — `12 × 9 = 108` 个 fixture point + Epley fallback ≥ 6 个 + 边界(reps=0 / reps=13 / rpe=5.5 / rpe=10.5 / weight=0)≥ 5 个):

| reps | RPE 10 | RPE 9.5 | RPE 9 | RPE 8.5 | RPE 8 | RPE 7 | RPE 6 |
|---|---|---|---|---|---|---|---|
| 1 | 100% | 98% | 96% | 94% | 92% | 88% | 84% |
| 2 | 96% | 94% | 92% | 90% | 88% | 84% | 80% |
| 3 | 92% | 90% | 88% | 86% | 84% | 80% | 76% |
| 4 | 88% | 86% | 84% | 82% | 80% | 76% | 72% |
| 5 | 86% | 84% | 82% | 80% | 78% | 74% | 70% |
| 6 | 84% | 82% | 80% | 78% | 76% | 72% | 68% |
| 7 | 82% | 80% | 78% | 76% | 74% | 70% | 66% |
| 8 | 80% | 78% | 76% | 74% | 72% | 68% | 64% |
| 9 | 78% | 76% | 74% | 72% | 70% | 66% | 62% |
| 10 | 76% | 74% | 72% | 70% | 68% | 64% | 60% |
| 11 | 74% | 72% | 70% | 68% | 66% | 62% | 58% |
| 12 | 72% | 70% | 68% | 66% | 64% | 60% | 56% |

> **fixture 测试 100kg × 5 reps @ RPE 8** → intensity 0.78 → e1RM = 100 / 0.78 ≈ **128.2 kg**(±0.1 浮点容差)

**实装锁定**(防 Codex 篡改):
- **不**回退到线性公式(reps 1-4 与 5+ 斜率不同)
- **不**换 Brzycki / Lombardi / Wathan 公式(数字差 ±3-5%)
- RPE 中间值(8.25 / 9.25 等)用线性插值
- reps > 12 → saturate 到 reps=12;rep > 20 + 无 RPE → 返 nil(超出 hypertrophy 上界)
- RPE < 6 → Epley fallback(RTS 表 6 下不可靠)
- intensity ≤ 0.5(reps=12 RPE<6 等极端组合)→ 返 nil(避免 e1RM 估出 > 2x weight 离谱)

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

spec 024 `TodayWorkoutViewModel.toggleComplete` 实装 record set。本 spec 在 record set **成功后** + **completed 边沿翻转**(false → true,不是 true → false 取消勾)时加 hook:

```swift
public func toggleComplete(rowIndex: Int) async {
  let previouslyCompleted = drafts[rowIndex].completed
  // ... spec 024 既有逻辑:recordSet → loggedSetId 回填 → toggle completed ...
  let nowCompleted = drafts[rowIndex].completed

  // 本 spec hook — 仅在 false → true 边沿触发(防取消勾留 orphan PR)
  guard !previouslyCompleted, nowCompleted else { return }

  let draft = drafts[rowIndex]
  guard let weight = draft.actualWeight ?? draft.prescribed.weightKg,
        let reps = draft.actualReps,
        let estimatedOneRepMaxKg = E1RMCalculator.calculate(
          weightKg: weight, reps: reps, rpe: draft.actualRPE
        ) else { return }

  let point = E1RMHistoryPoint(
    id: UUID(), studentId: studentId, exerciseId: planExercise.exercise.id,
    setLogId: setLog.id, computedAt: Date(),
    e1RMKg: estimatedOneRepMaxKg,
    sourceWeightKg: weight, sourceReps: reps, sourceRPE: draft.actualRPE
  )
  try? await e1rmRepo.recordPoint(point)

  let previousMax = (try? await e1rmRepo.maxBefore(
    studentId: studentId, exerciseId: planExercise.exercise.id,
    before: point.computedAt
  )) ?? 0
  if estimatedOneRepMaxKg > previousMax + 0.5 {   // 0.5kg buffer 消化浮点抖动
    let event = PRBreakthroughEvent(
      id: UUID(), studentId: studentId, exerciseId: planExercise.exercise.id,
      pointId: point.id,
      breakthroughE1RMKg: estimatedOneRepMaxKg, previousMaxE1RMKg: previousMax,
      occurredAt: Date(), acknowledgedAt: nil
    )
    try? await e1rmRepo.recordPR(event)
    pendingPRBanner = event   // @Observable 暴露给 view 弹 banner
  }
}
```

**关键 invariants**(per PR #116 Codex review):
- **边沿触发**(`!previouslyCompleted && nowCompleted`):仅在学员**首次**勾 ✓ 时算 e1RM,**取消勾**(true → false)不影响已落 PR(留 orphan E1RMHistoryPoint 接受 — 学员已看过 banner,撤回不再追回)
- 局部变量命名 `estimatedOneRepMaxKg` 而非 `e1rm`,避免遮蔽 `e1rmRepo` repo 变量
- `0.5kg` buffer 消化浮点抖动(127.99 vs 128.01 不算 PR);若内测期发现"PR 弹得太勤",调到 1.0kg(本 spec 接受调整)

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
| `Modules/StudentKit/Tests/StudentKitTests/Domain/E1RMCalculatorTests.swift`(新) | **RTS 表全 108 cell**(reps 1-12 × RPE 6.0/6.5/.../10.0 9 列;每个 cell 计算与表内 % 对齐,容差 ±0.5kg);Epley fallback ≥ 6 fixture(无 RPE / RPE < 6);RPE 中间值插值(RPE 7.25 / 8.25 / 9.25 等)≥ 3 fixture;边界(reps=0 → nil / reps=13 saturate to 12 / reps=21 + 无 RPE → nil / rpe=5.5 → Epley / rpe=10.5 → nil / weight=0 → nil);intensity < 0.5 返 nil |
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

### 数据持久化策略(2026-05-15 接 PR #116 Codex review non-blocking 统一)

| 阶段 | 实现 | backend 参与 |
|---|---|---|
| V0.1 本 spec 落地 | `InMemoryE1RMRepository` actor | ❌ |
| **spec 026 落地后** | **`LocalE1RMRepository`(JSON file cache,per ADR-005 §4 `Documents/e1rm/<studentId>.json`)** | ❌ 仍本地 |
| V0.1.x(换设备保留历史触发)| `BackendE1RMRepository` + backend `/students/:id/e1rm` endpoint | ✅ 另开独立 spec |

> **统一口径**:本 spec / spec 026 / spec 029 一致 — V0.1 阶段 e1RM **全本地算**,backend 0 参与。spec 026 仅做"InMemory → JSON file" 的本地升级,**不引入** `BackendE1RMRepository` 也**不加** backend endpoint。删除本 spec 之前对 `BackendE1RMRepository` / stale-while-revalidate / `/students/:id/e1rm` endpoint 的引用。

JSON file schema:
```
Documents/e1rm/
  ├── points-<studentId>.json    # [E1RMHistoryPoint]
  └── prs-<studentId>.json       # [PRBreakthroughEvent]
```

### E1RM 公式来源 — see §2

**Source of truth = §2 `E1RMCalculator.rtsTable`**(RTS 12×9 强度表)。**不**用线性公式。完整测试矩阵在 §测试 内。详细论证见 §2 implementer note。

### PR 检测的 0.5kg buffer

浮点 e1RM 可能因 RPE 输入扰动产生 0.x kg 差异,触发"假 PR"。`buffer = 0.5kg`(per e1RM 计算误差经验值),小于该值差异不算 PR。文档 + 单测显式 fix 此常量。若内测期发现"PR 弹得太勤",可调到 1.0kg(本 spec 接受调整,需 update 单测 fixture)。

### 版本 / 兼容

- iOS 17.0+
- SwiftUI Charts(iOS 16+)V0.1 用,V1 普及版本要求一致
- 不引第三方 chart 库

## 验收清单

- [ ] CoreModels 新 2 类型 Codable roundtrip 单测
- [ ] `E1RMCalculator` RTS 表全 108 cell fixture + Epley fallback ≥ 6 + RPE 中间值插值 ≥ 3 + 边界(reps=0/13/21/RPE 5.5/10.5/weight=0)≥ 6;无任何 cell 偏差 > 0.5kg
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

1. **公式不要换** — `rtsTable` 是 source of truth,**不**回退线性公式(reps 1-4 vs 5+ 斜率不同);**不**换 Brzycki / Lombardi / Wathan(±3-5% 漂移内测期会被你或 xty 觉察)
2. **0.5kg PR buffer 来源**:浮点 e1RM 与"称重 0.5kg 增量"是平行轴,buffer 仅消化浮点抖动,真实人脑能感知的 PR 是 +1-2.5kg 级。若内测期发现"PR 弹得太勤",buffer 可调到 1.0kg
3. **DEMO_MODE seed PR 时机**:启动时若 student seed 含 unacknowledged PR,banner 启动 1.5s 后弹(让 Tab 1 先渲染)→ Codex 实装时用 task delay 0.5-1s 缓冲
4. **5 tab 拥挤**:iOS HIG 推荐 ≤ 5 tab,本 spec 刚好踩线;V0.1.x 若加更多 tab 必须收 More 抽屉
5. **教练侧曲线 reuse**:spec 029 实装时直接复用 `GrowthCurveView` + `E1RMRepository.fetchHistory(studentId:)`,本 spec **不画**教练侧入口
6. **重 set 行为**(学员误点 ✓ 反悔取消勾):spec 024 已设计 "再 tap ✓ 取消 complete";本 spec hook 仅在 `!previouslyCompleted && nowCompleted` 边沿触发 record point;取消 → V0.1 留 orphan E1RMHistoryPoint(不删,因为 setLog 被取消但学员已经看到过 PR)。**边沿条件已写入 §4 主流程伪代码**(per PR #116 review non-blocking — 不再仅在风险段提及)
7. **`estimatedOneRepMaxKg` vs `e1rmRepo` 变量命名**:§4 伪代码 explicitly 命名 e1RM 数值为 `estimatedOneRepMaxKg`,避免与 `e1rmRepo` 同名遮蔽(per PR #116 review non-blocking)

## Implementation Notes

无(spec PR 阶段)。

## 上游 / 下游

**上游**:
- spec 024 学员端 P0(`StudentSetLog` / `TodayWorkoutViewModel`)
- ADR-002 + PRD §5 #16(公式来源 + 锁 1RM 规则)

**下游**:
- spec 026 backend 真接入:仅做 `InMemoryE1RMRepository → LocalE1RMRepository`(JSON file)本地升级,**不**加 backend endpoint(per 2026-05-15 持久化口径统一)
- spec 029 教练端 review:复用 `GrowthCurveView` + `E1RMCalculator` 复制份在 CoachKit 算 e1RM(因 e1RM 本地数据不上 backend,教练端从 StudentSetLog 反推 — 两端 calculator 单测验证一致)
- V0.1.x **独立 spec**:`BackendE1RMRepository` + backend `/students/:id/e1rm` endpoint(触发条件 = "换设备保留 e1RM 历史"用户需求)
- V0.1.x APNs push:`PRBreakthroughEvent.occurredAt` 触发服务端 push
- V0.1.x 变式 sheet:Exercise.variants 维度独立曲线
- V1.5 ADR-002 重启:训练量 / 区间分布 / 峰值 vs 平均 RPE

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。本地算 + in-app banner + 5 tab "我的" 入口 + 三大项主项曲线 | Claude |
| 2026-05-15 | 0.2 | 接 PR #116 Codex review:**blocker** — 公式 / 注释 / RTS 表三者不一致(线性公式 reps≥5 失准 6%),改用 `rtsTable` 12×9 lookup + RPE 线性插值作 source of truth,fixture 覆盖全 108 cell;non-blocking — ADR-002 链接修正到 `002-intelligent-analysis-over-passive-display.md` + 说明 PRD supersede;持久化口径统一(本 spec V0.1 in-memory → spec 026 切 JSON file,backend e1RM endpoint 另开独立 spec,不在 026 内);§4 toggleComplete hook 边沿条件 `!previouslyCompleted && nowCompleted` 上移到主流程伪代码;e1RM 变量重命名 `estimatedOneRepMaxKg` 防遮蔽 | Claude |
