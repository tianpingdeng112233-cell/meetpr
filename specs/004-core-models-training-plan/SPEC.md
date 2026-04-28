# 004 — CoreModels Phase 2: Training Plan & Exercise Catalog 领域类型

- **状态**: InReview (spec 002/003 已 merge 进 main 于 2026-04-27,Modules/CoreModels identity + DesignSystem foundation 就位,本 spec 在 plan layer 接力)
- **PR**: TBD (本 PR 创建后填入)
- **来源**:
  - [data-model.md v1.1 §1.4 (Exercise) + §1.8 (TrainingPlan/PlanDay/PlanExercise/PlanSet)](~/Brain/wiki/projects/MeetPR/data-model.md)
  - [coach-planning.md v4.4 §Step 0-5 (训练计划领域 wireframes)](~/Brain/wiki/projects/MeetPR/coach-planning.md) — iPhone 周卡片横滑 UI 走 spec 005+
  - 上游 [spec 002 CoreModels Phase 1 identity](../002-core-models-identity/SPEC.md) — 复用 `MeetPRCodec` / 命名约定 / 测试模式
  - [ADR 005 §1 模块结构](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md): CoreModels = 0 SwiftUI 纯领域类型
  - [ADR 003 v4 单角色](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md)

## 目标

把 data-model.md §1.4 + §1.8 的**训练计划层 + 动作库 catalog** entity 翻成 Swift pure value types,加入 CoreModels module。落地后:

1. 后续 coach planning UI specs (005+) 可直接 import CoreModels 用这些类型
2. 网页端教练后台 spec (V1.x) 同源复用同一份类型 (通过 JSON Codable round-trip 跨语言)
3. backend 持久化 spec 可参照这些类型设计 schema (Exercise + plans + plan_days + plan_exercises + plan_sets 共 5 张表)
4. JSON Codable round-trip 测试覆盖所有类型

> **2026-04-28 office hours pivot 影响声明**:本 spec 是**纯数据模型,不受 iPhone 4 周宏观视图删除的影响**。**禁止**添加任何 `specificityBucket` / `waveformPoint` / `accessoryDensityBucket` / `isDeloadWeek` 字段——那些是 web view 衍生计算,属于网页端 view-model 范畴,不进 CoreModels。详见 [coach-planning.md §7b/7d v4.4](~/Brain/wiki/projects/MeetPR/coach-planning.md) + [office hours 记录](~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md)。

## 范围

### 做什么

1. **新增 entity 文件** (`Modules/CoreModels/Sources/CoreModels/Entities/`):
   - `Exercise.swift` (data-model §1.4) — 留 Entities 根目录,catalog 不属于 plan
   - `Plan/TrainingPlan.swift`
   - `Plan/PlanDay.swift`
   - `Plan/PlanExercise.swift`
   - `Plan/PlanSet.swift`

   > 子目录 `Entities/Plan/` 作为新组织单元,4 个 plan 相关 entity 全放进去。

2. **新增 enum 文件** (`Modules/CoreModels/Sources/CoreModels/Enums/`):
   - `LiftFamily` — `squat` / `bench` / `deadlift`
   - `ExerciseType` — `main_lift` / `main_lift_variation` / `accessory`
   - `MuscleGroup` — 9 值: `chest` / `shoulder` / `back` / `biceps` / `triceps` / `core` / `quad` / `hamstring` / `glute`
   - `Equipment` — `barbell` / `dumbbell` / `machine` / `bodyweight`
   - `MovementPattern` — `push` / `pull`
   - `PlanSource` — `coach` / `template` / `algorithm`(V2 预埋)
   - `PlanStatus` — `draft` / `published` / `completed` / `paused`
   - `IntensityMode` — `weight` / `rpe`
   - `SetType` — `warmup` / `working` / `failed` / `amrap` / `backoff`

3. **测试** (`Modules/CoreModels/Tests/CoreModelsTests/Plan/`,新建子目录,复用 spec 002 的 helpers):
   - 每个 entity ≥ 1 个 Codable round-trip 测试 (5 entities)
   - 每个 enum ≥ 1 个 raw-value 检查 (9 enums)
   - PlanSet 覆盖 `target_reps` 精确 (max=null) + 范围 (max=12) 两种形态
   - PlanSet 覆盖 `intensity_mode = weight` + `intensity_mode = rpe` 两种形态
   - Exercise 覆盖 facets 多选 (`muscle_groups: ["quad", "core"]`)
   - PlanExercise 覆盖 `is_main_lift: true` 和 `false`

### 不做什么

- ❌ ProgressionRule / ExerciseWeekOverride (data-model §1.9) — 留 spec 005 (Step 6 递进规则)
- ❌ WeekTemplate (data-model §1.11) — 留 Step 9 模板保存的专门 spec
- ❌ EvaluationPeriod / StudentEvaluation (data-model §1.7) — 学员端 evaluation feature 的 spec
- ❌ e1RMHistory (data-model §1.10) — PR 检测 feature 的 spec
- ❌ VideoUpload / CoachFeedback (data-model §1.12, §1.13) — 视频反馈 feature 的 spec
- ❌ CoachReferral (data-model §1.14) — V1.5+
- ❌ V2/V3 预埋字段 (本 spec 仅 PlanSource 含 `algorithm` 占位,其他 V2/V3 字段 V1.5+)
- ❌ Repository / API client / SwiftData mapping — 另外 spec
- ❌ Backend migration / Exercise catalog seed data — backend repo 的 spec (本 spec 只定义 Exercise **类型**,不定义初始数据列表)
- ❌ `specificityBucket` / `waveformPoint` / `accessoryDensityBucket` / `isDeloadWeek` 等 view-model 衍生字段 — 网页端 view-model 范畴,**禁止进** CoreModels (见上方"目标"声明)
- ❌ UI / SwiftUI view / Combine
- ❌ 任何业务逻辑 / runtime 字段约束校验(见各 entity 下"约束"注释)

## 技术要求

### 严格继承 spec 002 的约定

- Codable 策略统一在 `MeetPRCodec` (snake_case 转换 + ISO8601 + Decimal-as-string)
- 所有 entity `Codable, Hashable, Sendable, Identifiable`,所有 stored property `let`
- enum raw value **必须显式写**(`case mainLift = "main_lift"`),因为 `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` 不转 enum raw value
- 数值用 `Decimal` 不用 `Double`(强度精度敏感)
- 一个 type 一个文件
- 严格并发 (`StrictConcurrency` upcoming feature)
- 只允许 `import Foundation`,禁止 `SwiftUI` / `Combine` / `Networking`

### Entity 字段对照 data-model.md

#### Exercise (data-model §1.4)

```swift
public struct Exercise: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let name: String                          // zh-CN 显示名 (如 "竞技深蹲" / "哈克深蹲")
    public let exerciseType: ExerciseType            // main_lift | main_lift_variation | accessory
    public let mainLiftFamily: LiftFamily?           // squat | bench | deadlift | nil (accessory 时 nil)
    public let isCompetitionLift: Bool               // 是否比赛版本
    public let muscleGroups: [MuscleGroup]           // 9 值多选 (≥1)
    public let equipment: [Equipment]                // 4 类多选 (≥1)
    public let movementPattern: [MovementPattern]    // push/pull 多选 (可能空数组)
    public let createdByCoachID: UUID?               // null = 系统预置;非 null = 教练自定义
    public let createdAt: Date
}
```

> **约束**(文档级,本 spec 不 runtime 校验,留 service layer):
> - `exerciseType == .accessory` ⇒ `mainLiftFamily == nil`
> - `exerciseType ∈ {.mainLift, .mainLiftVariation}` ⇒ `mainLiftFamily != nil`
> - `muscleGroups.count >= 1`, `equipment.count >= 1`

#### TrainingPlan (data-model §1.8)

```swift
public struct TrainingPlan: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let coachID: UUID?                  // 自己练 (B2C) 时 nil;有教练时教练 user.id
    public let traineeID: UUID                 // 学员 user.id
    public let name: String
    public let startDate: Date                 // 起始日期 (cycle 第 1 天)
    public let endDate: Date
    public let planWeeks: Int                  // 1 或 4
    public let source: PlanSource              // coach | template | algorithm(V2 预埋)
    public let sourceTemplateID: UUID?         // FK to WeekTemplate (本 spec 未实现 WeekTemplate; 字段先占位)
    public let status: PlanStatus              // draft | published | completed | paused
    public let createdAt: Date
    public let updatedAt: Date
}
```

> **约束**:
> - `planWeeks ∈ {1, 4}`
> - `source == .template` ⇒ `sourceTemplateID != nil`
> - `endDate > startDate`
>
> **命名说明**:字段命名跟 data-model.md 一致(用 `TrainingPlan` 不是 "Cycle")。coach-planning UI 中俗称的 "cycle" 即指本 entity。

#### PlanDay (data-model §1.8)

```swift
public struct PlanDay: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let planID: UUID                     // FK
    public let dayOfWeek: Int                   // 1-7 (ISO 8601: 1=Mon, 7=Sun)
                                                // 与 spec 002 StudentProfile.trainingDaysOfWeek 同约定
    public let weekNumber: Int                  // 1-4 (4 周模式) 或 1 (1 周模式)
    public let sortOrder: Int                   // 同周同日多 day 时排序
}
```

> **约束**:`dayOfWeek ∈ [1,7]`, `weekNumber ∈ [1,4]`, `sortOrder >= 0`

#### PlanExercise (data-model §1.8)

```swift
public struct PlanExercise: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let planDayID: UUID                  // FK
    public let exerciseID: UUID                 // FK to Exercise (catalog)
    public let isMainLift: Bool
    public let sortOrder: Int                   // 该 day 内的动作顺序
    public let notes: String?                   // 教练备注
}
```

#### PlanSet (data-model §1.8)

```swift
public struct PlanSet: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let planExerciseID: UUID             // FK
    public let setNumber: Int                   // 1-based
    public let targetReps: Int                  // 目标次数
    public let targetRepsMax: Int?              // nil = 精确 reps; 非 nil = 范围 (e.g. 8-12)
    public let intensityMode: IntensityMode     // weight | rpe
    public let targetValue: Decimal             // weight: kg; rpe: 0-10
    public let setType: SetType                 // warmup | working | failed | amrap | backoff
    public let createdAt: Date
}
```

> **约束**:
> - `targetRepsMax != nil` ⇒ `targetRepsMax >= targetReps`
> - `intensityMode == .rpe` ⇒ `targetValue ∈ [1.0, 10.0]`
> - `intensityMode == .weight` ⇒ `targetValue > 0`
>
> **%1RM 不进 storage**: coach-planning Step 5 提到"强度两种模式: 重量(内置 kg/%1RM 切换) 和 RPE",其中 %1RM 是 UI 输入便捷 toggle,**实际存储统一转换为 kg 存入 `targetValue`**。intensity 不需要第三种 mode。

### Enum 定义

```swift
public enum LiftFamily: String, Codable, Hashable, Sendable, CaseIterable {
    case squat
    case bench
    case deadlift
}

public enum ExerciseType: String, Codable, Hashable, Sendable, CaseIterable {
    case mainLift = "main_lift"
    case mainLiftVariation = "main_lift_variation"
    case accessory
}

public enum MuscleGroup: String, Codable, Hashable, Sendable, CaseIterable {
    case chest
    case shoulder
    case back
    case biceps
    case triceps
    case core
    case quad
    case hamstring
    case glute
}

public enum Equipment: String, Codable, Hashable, Sendable, CaseIterable {
    case barbell
    case dumbbell
    case machine
    case bodyweight
}

public enum MovementPattern: String, Codable, Hashable, Sendable, CaseIterable {
    case push
    case pull
}

public enum PlanSource: String, Codable, Hashable, Sendable, CaseIterable {
    case coach
    case template
    case algorithm   // V2 预埋,V1 不出现该值
}

public enum PlanStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case draft
    case published
    case completed
    case paused
}

public enum IntensityMode: String, Codable, Hashable, Sendable, CaseIterable {
    case weight
    case rpe
}

public enum SetType: String, Codable, Hashable, Sendable, CaseIterable {
    case warmup
    case working
    case failed
    case amrap
    case backoff
}
```

### 不可变性

- 默认所有 stored property `let`,继承 spec 002
- 客户端要"改一个字段"构造新实例
- 后续 view-model spec 引入 mutable wrapper 时再决定哪些字段能改

### 文件 / 目录约定

- 一个 type 一个文件
- 子目录 `Entities/Plan/` 包含 4 个 plan 文件:`TrainingPlan.swift` / `PlanDay.swift` / `PlanExercise.swift` / `PlanSet.swift`
- `Exercise.swift` 留 `Entities/` 根 (catalog 不属于 plan)
- enum 文件命名 = enum 名,放 `Enums/` 根 (不分子目录,跟 spec 002 一致)
- 测试新增 `Tests/CoreModelsTests/Plan/` 子目录(`PlanEntityCodableTests.swift` + `PlanEnumRawValueTests.swift`),与 spec 002 的 `EntityCodableTests` / `EnumRawValueTests` 平行

## 验收标准

- [ ] 5 个新 entity 文件存在 (`Exercise` 在 `Entities/`; `TrainingPlan`/`PlanDay`/`PlanExercise`/`PlanSet` 在 `Entities/Plan/`)
- [ ] 9 个新 enum 文件存在于 `Enums/`
- [ ] `swift build` 在 `Modules/CoreModels/` 单独跑通过, 0 warning, 0 error, Swift 6 strict concurrency
- [ ] `swift test` 通过, 测试数 ≥ **5 entity round-trip + 9 enum raw-value + 4 特殊形态测试 = 18 个**
- [ ] PlanSet `intensityMode=.rpe` 测试: encode 后 JSON 包含 `"intensity_mode":"rpe"` 和 `"target_value":"7.5"` (Decimal-as-string)
- [ ] PlanSet 范围 reps 测试: encode `{ targetReps:8, targetRepsMax:12 }` JSON 含 `"target_reps":8` + `"target_reps_max":12`
- [ ] PlanSet 精确 reps 测试: encode `{ targetReps:5, targetRepsMax:nil }` JSON 含 `"target_reps":5` 且**不**含 `"target_reps_max"` (encodeIfPresent)
- [ ] Exercise 多 facet 测试: encode `{ muscleGroups:[.quad,.core], equipment:[.barbell], movementPattern:[.push] }` JSON 含 `"muscle_groups":["quad","core"]`
- [ ] TrainingPlan 测试断言: `"plan_weeks":4` + `"source":"coach"` + `"status":"draft"`
- [ ] ExerciseType raw value 测试: encode `.mainLiftVariation` JSON 字符串含 `"main_lift_variation"`
- [ ] PlanExercise 测试覆盖 `is_main_lift: true` 和 `false` 两种
- [ ] 在主 Xcode target 跑 `xcodebuild build -scheme MeetPR ...` 通过 (CoreModels 改了不能破坏 AppShell / CoachKit / StudentKit / Networking 的引用)
- [ ] **隔离回归**: CoachKit 仍不可 import StudentKit (复用 spec 001 验证)
- [ ] swiftlint + swift-format 全绿
- [ ] CI 在 `feat/004-core-models-training-plan` 分支跑过, 全绿

## 参考

- 数据模型源:[`~/Brain/wiki/projects/MeetPR/data-model.md`](~/Brain/wiki/projects/MeetPR/data-model.md) §1.4 (Exercise) + §1.8 (TrainingPlan + PlanDay + PlanExercise + PlanSet)
- coach-planning v4.4:[`~/Brain/wiki/projects/MeetPR/coach-planning.md`](~/Brain/wiki/projects/MeetPR/coach-planning.md) §Step 0-5 (训练计划领域 wireframes)
- 上游 [spec 002](../002-core-models-identity/SPEC.md):复用 `MeetPRCodec`、Codable 策略、测试模板
- ADR 005 §1 模块结构: CoreModels = 0 SwiftUI 纯领域类型
- ADR 003 v4 单角色: 不影响本 spec
- 2026-04-28 office hours pivot: [`meetings/2026-04-28-office-hours-iphone-macro-pivot.md`](~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md) — 本 spec **不受影响**;UI spec (005+) 才需要按 v4.4 周卡片走
- [F-015](../../FOLLOWUPS.md):任何 coach planning UI spec 必须按 v4.4 写 (本 spec 是数据层,与 UI 解耦,但 implementer 应 aware)

## Notes (给 Codex)

- 本 spec 是**机械翻译工作** — 严格按 data-model.md §1.4 + §1.8 列字段,**不要**"优化"字段名 / 加新字段 / 改类型
- 任何疑问写 `QUESTIONS.md` 由 Claude review,不擅自决定
- 测试 fixture 用最小**完整**数据 (即不要全 nil; 至少必填字段是真值,如 `name:"竞技深蹲"`, timestamps, UUIDs)
- 别 import `SwiftUI` / `Combine`; 只 `Foundation`
- `Decimal` JSON 默认行为: encode 时输出为 string (e.g. `"180.5"`)。测试时断言 string 而不是 number
- **禁止**添加 `specificityBucket` 字段 — specificity 是 view-model 概念,在网页端衍生计算 (见 spec 顶部"目标"声明)
- **禁止**添加 `isDeloadWeek` / `waveformValue` / `accessoryDensityValue` 等衍生字段 (同上)
- 子目录 `Entities/Plan/` 是新组织单元 — `Codec.swift` / Codec helpers **不需要改** (复用 spec 002 的 keyDecodingStrategy 已经处理 snake_case)
- 子目录 `Tests/CoreModelsTests/Plan/` 平行新增,不要把测试塞进现有 `EntityCodableTests.swift` / `EnumRawValueTests.swift`(spec 002 文件按身份 entity 组织,本 spec 按训练计划 entity 组织)
- PR description 必须列每个 entity vs data-model.md §1.4 / §1.8 的字段对照清单 (用 `gh pr create --body` HEREDOC 一次性贴)
- 完成后**别 self-merge** — Claude review 后才 merge
