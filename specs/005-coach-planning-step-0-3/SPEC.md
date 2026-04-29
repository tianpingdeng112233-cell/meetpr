# 005 — Coach Planning UI Step 0-3 (选学员 / 选周数 / SBD 频率 / 选主项变式)

- **状态**: InReview
- **PR**: (待填)
- **来源**:
  - [coach-planning.md v4.4 §Step 0-3](~/Brain/wiki/projects/MeetPR/coach-planning.md) — wireframe ground truth (2026-04-28 pivot 后)
  - [data-model.md v1.1 §1.3 (StudentProfile) + §1.4 (Exercise) + §1.8 (TrainingPlan/PlanDay/PlanExercise)](~/Brain/wiki/projects/MeetPR/data-model.md)
  - 上游 [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) (`StudentProfile` / `User` / 相关 enum)
  - 上游 [spec 003 DesignSystem foundation](../003-design-system-foundation/SPEC.md) (14 atomic 组件 + token)
  - 上游 [spec 004 CoreModels training plan](../004-core-models-training-plan/SPEC.md) (`TrainingPlan` / `PlanDay` / `PlanExercise` / `Exercise` / `LiftFamily` / `ExerciseType` / `PlanSource` / `PlanStatus`)
  - [ADR-005 iOS architecture §1 (CoachKit 模块边界) + §3 (MVVM + Repository)](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
  - [F-015 — 任何 coach planning spec 必须按 v4.4](../../FOLLOWUPS.md)

## 目标

落实 **教练编排器前 4 步 SwiftUI UI**——选学员 / 选周数 / SBD 频率分配 / 选主项变式——以及串这 4 步的整体 NavigationStack flow。落地后:

1. 教练能从 `CoachRootView` 入口打开"排新计划"流程,顺序走完 Step 0 → Step 3,产生**本地 SwiftData draft**(in-progress `TrainingPlan` 状态)
2. 中途退出 / app 杀掉 / 切回再开,Editor 自动恢复到上次的 step + 已填字段(SwiftData @Model 持久化)
3. Step 3 完成 → draft 写入 SwiftData → 退出 Editor。**Step 4 (添加辅助动作) 留 spec 006**;本 spec 在 Step 3 完成处给一个明确的 "完成基础编排,进入辅助项 (TODO spec 006)" 占位 CTA
4. 后续 spec (006-011) 接力填 Step 4-9 各步骤
5. UI 不接真 backend;通过 `PlanRepository` protocol + `InMemoryPlanRepository` mock 喂数据。真接入留独立后续 spec

> **2026-04-28 v4.4 pivot 影响声明**:本 spec 实装的 4 个 step (Step 0-3) **不触及** v4.4 重写的 §7b/7c/7d (周卡片横滑 / 学员历史 / 网页端宏观视图) — 那些走 spec 009+ 和 web companion。但 spec 必须遵守 v4.4 红线:**禁止**引入 specificityBucket / waveformValue / accessoryDensityBucket / 4 周宏观视图相关概念。详见下方 §不做什么。

## 范围

### 做什么

#### 1. 4 个 SwiftUI screen + 1 个 root coordinator (`Modules/CoachKit/Sources/CoachKit/Planning/Views/`)

| 文件 | 作用 | wireframe 源 |
|---|---|---|
| `PlanningCoordinatorView.swift` | root `NavigationStack` + `navigationDestination(for:)` 路由 4 个 step + 顶部学员浮层 (collapsed/expanded) | coach-planning §"全局组件:学员信息浮层" |
| `Step0SelectStudentView.swift` | 学员 picker,按状态分 3 段 (评估期内 / 活跃 / 异常) | coach-planning §Step 0 |
| `Step1SelectDurationView.swift` | 1 周 / 4 周 二选一,评估期内学员锁 1 周 | coach-planning §Step 1 |
| `Step2AssignFrequencyView.swift` | SBD 频率 picker + 训练日 → 大项分配 (multi-select chips); "使用模板" / "复制上周" 入口 disabled | coach-planning §Step 2 |
| `Step3SelectMainLiftsView.swift` | per-day per-lift-family 变式 picker (e.g. 周一深蹲 → [竞技深蹲 ▼]) | coach-planning §Step 3 |

#### 2. State management (`Modules/CoachKit/Sources/CoachKit/Planning/State/`)

| 文件 | 作用 |
|---|---|
| `PlanningViewModel.swift` | 单一 `@Observable @MainActor` 类持: `currentStep` / `draftPlan` / 各 step 输入字段 / available students / main lift catalog / 校验 + navigation 方法 |
| `PlanningStep.swift` | enum: `.selectStudent` / `.selectDuration` / `.assignFrequency` / `.selectMainLifts` (`Hashable, Codable, Sendable`) — `navigationDestination(for:)` 用 |
| `SBDFrequency.swift` | value struct: 三大项各自频率 (1-7) + 校验 helper |
| `DayLiftAssignment.swift` | value struct: 单训练日 → `[LiftFamily]` 映射 |

#### 3. SwiftData persistence layer (`Modules/CoachKit/Sources/CoachKit/Planning/Drafts/`)

| 文件 | 作用 |
|---|---|
| `DraftTrainingPlan.swift` | SwiftData `@Model` class — mutable wrapper,字段对应 `CoreModels.TrainingPlan` + 当前 `PlanningStep` raw value |
| `DraftPlanDay.swift` | SwiftData `@Model` class — 对应 `CoreModels.PlanDay` |
| `DraftPlanExercise.swift` | SwiftData `@Model` class — 对应 `CoreModels.PlanExercise`,只持 main lift (Step 3 范围),accessory 留 spec 006 |
| `DraftMapping.swift` | 自由函数 `toDomain(_:) throws -> TrainingPlan` + `fromDomain(_:days:exercises:)` — 与 CoreModels pure value types 互转;**不允许**在 `@Model` class 内部加 toDomain method (Swift 6 concurrency + SwiftData 主线程隔离会冲突) |
| `DraftStore.swift` | `@MainActor` final class — 封装 `ModelContext` 增删改查;暴露 `loadDraft(traineeID:)` / `saveDraft(_:)` / `deleteDraft(traineeID:)` |

#### 4. Backend abstraction layer (`Modules/CoachKit/Sources/CoachKit/Planning/Repository/`)

| 文件 | 作用 |
|---|---|
| `PlanRepository.swift` | `public protocol PlanRepository: Sendable` —— `fetchStudents()` / `fetchMainLiftCatalog()` / `publishPlan(_:)` 三个 async throws 方法 |
| `InMemoryPlanRepository.swift` | `public actor` mock 实现 — V1 唯一实装;接受 `[StudentProfile]` + `[Exercise]` fixture 作为 init 参数;`publishPlan` 仅本地存,不发网络 |
| `BackendPlanRepository.swift` | **占位文件** — 仅含 `// TODO: spec NNN backend wiring` 注释 + 空 `struct BackendPlanRepository {}`,保 module export shape;实际 Networking 接入留后续 spec |

#### 5. CoachRootView 接入

修改 `Modules/CoachKit/Sources/CoachKit/CoachRootView.swift`(spec 001 留下的 stub):
- 加一个 `PrimaryButton("排新计划") { showPlanning = true }`
- `.fullScreenCover(isPresented: $showPlanning) { PlanningCoordinatorView(repository: ..., draftStore: ...) }`
- repository 通过 SwiftUI environment 或 init 注入(spec 在技术要求里指定)
- modelContainer 的 root 注入位置见技术要求 §SwiftData 集成

#### 6. 测试 (`Modules/CoachKit/Tests/CoachKitTests/Planning/`)

Swift Testing (`@Test` / `#expect`) + ViewInspector(已在 AGENTS.md "技术栈" 预批准):

| 文件 | 覆盖 |
|---|---|
| `PlanningViewModelTests.swift` | step navigation forward/backward / 输入字段写入 / 校验 (评估期内学员选 1 周 vs 4 周) |
| `DraftStoreTests.swift` | SwiftData round-trip — save → load → 字段一致;deleteDraft 清掉 |
| `DraftMappingTests.swift` | `DraftTrainingPlan` ↔ `CoreModels.TrainingPlan` 双向转换;含 `PlanDay` 列表 + `PlanExercise` (is_main_lift=true) |
| `PlanRepositoryTests.swift` | `InMemoryPlanRepository` 三个方法的行为(fetchStudents 返回所有传入 fixtures / fetchMainLiftCatalog 过滤 `exerciseType ∈ {.mainLift, .mainLiftVariation}` / publishPlan 写入并能再读) |
| `PlanningFlowSnapshotTests.swift` | ViewInspector 验证: Step 0 渲染 3 段分组 / Step 1 评估期内学员 4 周按钮 disabled / Step 2 模板和复制上周入口 disabled / Step 3 per-day 显示对应 lift family picker |

测试 fixture (`Tests/CoachKitTests/Planning/Fixtures/`): 1 evaluation-period 学员 + 2 active 学员 + 1 abnormal 学员 + 一份基础 catalog (3 main lifts + 4 main lift variations)。

### 不做什么

| ❌ 留 spec |
|---|
| **Step 4** 添加辅助动作 (三标签 facets — 肌群/器械/模式) → spec 006 |
| **Step 5** 填写 W1 强度 (kg / %1RM / RPE 计算器键盘) → spec 007 |
| **Step 6** 递进/递减规则 9 类 → spec 008 |
| **Step 7b** iPhone 周卡片横滑 (`TabView(.page)` v4.4) → spec 009 |
| **Step 7c** 学员历史 cycle 列表入口 → spec 010 |
| **Step 8** 发布 cycle (推送学员 / status `published`) → spec 011 |
| **Step 9** 保存为模板 (1 周 vs 4 周 模板沉淀差异化) → spec 012 |
| **"使用模板"** / **"复制上周"** 入口实装 — Step 2 必须显示 disabled 占位按钮,但点击不响应 |
| **评估期 1RM cascade 模态** (§Y v4.1) — 仅做 happy path,1RM 改动延后 |
| **§Z 改 cycle 计划学员端推送规则** — 跟发布一起在 spec 011 |
| **真 backend** — 仅 `InMemoryPlanRepository` 落地,protocol 暴露形状 |
| **4 周宏观视图** / **跨 cycle 对比** / **多学员 dashboard** — 走网页端 (PD-007),iPhone 不做 |
| **波形图** / **变式矩阵** / **密度条** / **specificityBucket** / **isDeloadWeek** 等衍生字段 — v4.3 已废弃,本 spec 严禁引入 |
| **Lite role switch** / **multi-role** / **ModeAware routing** — V1.5+ deferred |
| **PlanRepository 真 actor 化 + actor isolation 完整 audit** — spec 范围内 mock 用 `actor`,但严格的 isolation 验证留 backend 接入 spec |

## 技术要求

### 模块位置 + import 边界

CoachKit 现有 SPM target,**不新建** target。新代码全在 `Modules/CoachKit/Sources/CoachKit/Planning/` 子目录下,4 子目录组织 (Views / State / Drafts / Repository)。

import 规则(继承 ADR-005 §3):

| 文件类别 | 允许 import |
|---|---|
| Planning/Views/* | `SwiftUI`, `CoreModels`, `DesignSystem`,以及本 module 的 `..State`/`..Repository`/`..Drafts` 类型 |
| Planning/State/* | `Foundation`, `CoreModels`,本 module 的 `..Drafts`/`..Repository` |
| Planning/Drafts/* | `Foundation`, `SwiftData`, `CoreModels` |
| Planning/Repository/* (protocol + mock) | `Foundation`, `CoreModels` |
| Planning/Repository/BackendPlanRepository.swift | 占位,仅 `Foundation` (后续 spec 加 `Networking`) |

**禁止**(swiftlint custom rule 检测,跟 spec 003 一致):
- ❌ Planning/Views 下任何文件 import `Networking`
- ❌ Planning/State 下任何文件 import `SwiftUI` / `Networking`
- ❌ Planning/Drafts 下任何文件 import `SwiftUI` / `Networking`
- ❌ Planning 下任何文件 import `StudentKit`(继承 spec 001 反向回归)

`Modules/CoachKit/Package.swift` **无需新增 dependency**(SwiftData 是 system framework,Foundation/SwiftUI/CoreModels/DesignSystem 已在);ViewInspector 加进 testTarget 的 `dependencies`(见 §测试)。

### State management 形状

```swift
// Planning/State/PlanningStep.swift
public enum PlanningStep: Int, CaseIterable, Hashable, Codable, Sendable {
    case selectStudent = 0
    case selectDuration = 1
    case assignFrequency = 2
    case selectMainLifts = 3
}

// Planning/State/PlanningViewModel.swift
@Observable
@MainActor
public final class PlanningViewModel {
    // navigation
    public var path: [PlanningStep] = []      // NavigationStack path
    public var currentStep: PlanningStep { path.last ?? .selectStudent }

    // step 0
    public private(set) var availableStudents: [StudentProfile] = []
    public var selectedStudent: StudentProfile?

    // step 1
    public var planWeeks: Int? = nil          // 1 or 4

    // step 2
    public var sbdFrequency: SBDFrequency = .empty
    public var dayAssignments: [Int: Set<LiftFamily>] = [:]   // dayOfWeek (1-7) -> assigned lifts

    // step 3
    public private(set) var mainLiftCatalog: [LiftFamily: [Exercise]] = [:]
    public var selectedVariants: [DayLiftKey: UUID] = [:]     // (dayOfWeek, liftFamily) -> exerciseID

    // dependencies
    private let repository: any PlanRepository
    private let draftStore: DraftStore

    public init(repository: any PlanRepository, draftStore: DraftStore) { ... }

    // lifecycle
    public func bootstrap() async { ... }     // call on PlanningCoordinatorView .task; loads students + catalog + 尝试 resume draft
    public func goNext() async throws { ... } // 校验当前 step + append 下一 step 到 path + 保存 draft
    public func goBack() { ... }              // path.removeLast(); 不删 draft
    public func finish() async throws { ... } // Step 3 完成 → 写 draft → 关闭 editor (UI 层 onChange path 监听)
}
```

校验规则:
- Step 0 → Step 1: `selectedStudent != nil`
- Step 1 → Step 2: `planWeeks ∈ {1, 4}`;若 student 在评估期内 (`evaluationPeriod.completedAt == nil && expectedEndAt > now`,见下"学员状态判定")⇒ `planWeeks == 1`(UI 层 4 周按钮 disabled,ViewModel 也再校验)
- Step 2 → Step 3: `sbdFrequency.totalSessions == sum(dayAssignments[i].count)`(分配数 = 频率和);每个有 assignment 的 dayOfWeek 必须在 `student.trainingDaysOfWeek` 内
- Step 3 → finish: 每个 (day, liftFamily) 对应 assignment 都有 `selectedVariants` 条目(per-day per-lift-family)

### 学员状态判定 (Step 0 分组 logic)

学员状态来自 `StudentProfile` + 关联 `EvaluationPeriod` (来自 `PlanRepository.fetchStudents()` 返回的复合 view-model)。**spec 005 范围内不实装 EvaluationPeriod 真模型**(那是 spec 002 之后的 evaluation feature spec 才会加 `CoreModels` entity);本 spec 在 `PlanRepository` 层用一个**临时 view-model**:

```swift
// Planning/Repository/PlanRepository.swift
public struct CoachStudentSummary: Sendable, Hashable, Identifiable {
    public let id: UUID                          // = profile.userID
    public let profile: StudentProfile
    public let displayName: String
    public let status: CoachStudentStatus
}

public enum CoachStudentStatus: Sendable, Hashable {
    case inEvaluation(remainingDays: Int, remainingHours: Int)   // 评估期内 + 倒计时
    case active                                                   // bound + 无评估期内 + 无异常
    case abnormal(reason: AbnormalReason)                         // 3+ 天未训练 / 卡 W2 / etc.
}

public enum AbnormalReason: Sendable, Hashable {
    case noTrainingForDays(Int)
    case stuckOnWeek(Int)
}
```

> ⚠️ `CoachStudentSummary` / `CoachStudentStatus` / `AbnormalReason` 是**本 spec 内的 Repository view-model**,**不是** CoreModels 领域实体。后续 evaluation feature spec 将 `CoachStudentStatus` 提升为基于真实 `EvaluationPeriod` entity 的导出。当前实装 `InMemoryPlanRepository` 直接返回 fixture `CoachStudentSummary` 列表,不经任何业务规则。

Step 0 UI 渲染 logic:
1. 从 `availableStudents: [CoachStudentSummary]` 按 `status` group 成 3 段
2. 段头显示数量: "评估期内 (1)" / "活跃 (3)" / "异常 (2)"
3. 评估期内段每行显示 ⚠️ 图标 + "评估期 X 天 Y 时剩";异常段显示 🟡 + reason 文本
4. 点击行 → `viewModel.selectedStudent = ...` → `goNext()`

### Step 2 wireframe → SwiftUI 映射

```
顶部:
  [使用模板 ▼] (.disabled = true,SecondaryButton 灰态)
  [复制上周]   (.disabled = true)
  ── 或从零开始 ──    (Eyebrow 组件 from spec 003)

学员训练日 (来自 Type A 锁定字段 student.trainingDaysOfWeek):
  Eyebrow "训练日" + Label "周一·周三·周五·周六" (静态)

频率分配:
  ForEach LiftFamily.allCases [.squat, .bench, .deadlift]:
    HStack:
      Label("深蹲" / "卧推" / "硬拉")
      Spacer
      NumericInput (spec 003 组件) — 1 到 7 step 1,默认值由教练填

训练日 → 大项分配:
  ForEach student.trainingDaysOfWeek:
    Card (spec 003) 内:
      Label("周一" / 等 — 用 Date.formatted(.dateTime.weekday(.wide)) 本地化)
      多选 chip (3 个 LiftFamily): 点击 toggle 加入/移出 dayAssignments[dayOfWeek]
      实时校验:右下角 Badge 显示当前 day 已分配 N/T (T = 该 day 应承载几次)

底部 PrimaryButton "下一步":
  仅当 sbdFrequency.totalSessions == sum(dayAssignments[i].count) 且
  每个有 assignment 的 day 都 ∈ student.trainingDaysOfWeek 时启用
```

### Step 3 wireframe → SwiftUI 映射

```
ForEach dayAssignment in dayAssignments (按 dayOfWeek 排序):
  Section("周一 — 深蹲 + 卧推"):           ← 拼接 day label + 大项 names
    ForEach liftFamily in dayAssignment:
      HStack:
        Label("深蹲:" / "卧推:" / "硬拉:")
        Picker(selection: $viewModel.selectedVariants[(day, liftFamily)]):
          ForEach mainLiftCatalog[liftFamily]:
            Text(exercise.name).tag(exercise.id)

底部 PrimaryButton "完成基础编排 (进入辅助项 — TODO spec 006)":
  - 仅当所有 (day, liftFamily) 都有 variant 时启用
  - 点击 → viewModel.finish() → SwiftData 写 draft → coordinator dismiss
```

> Step 3 picker 数据源约束: `mainLiftCatalog[liftFamily]` 取自 `repository.fetchMainLiftCatalog()`,过滤 `exerciseType ∈ {.mainLift, .mainLiftVariation}` 且 `mainLiftFamily == liftFamily`。**本 spec 不实装** "教练自定义新动作" — 那是 spec 006/007 接入。

### SwiftData @Model 形状

```swift
import Foundation
import SwiftData

@Model
public final class DraftTrainingPlan {
    public var id: UUID
    public var traineeID: UUID
    public var coachID: UUID?
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var planWeeks: Int                     // 1 or 4
    public var currentStepRawValue: Int           // PlanningStep raw value (resume 用)
    public var lastSavedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DraftPlanDay.plan)
    public var draftDays: [DraftPlanDay] = []

    public init(
        id: UUID = UUID(),
        traineeID: UUID,
        coachID: UUID? = nil,
        name: String,
        startDate: Date,
        endDate: Date,
        planWeeks: Int,
        currentStepRawValue: Int = 0,
        lastSavedAt: Date = .now
    ) { ... }
}

@Model
public final class DraftPlanDay {
    public var id: UUID
    public var dayOfWeek: Int                     // 1-7 ISO 8601
    public var weekNumber: Int                    // V1 本 spec 范围 = 1
    public var sortOrder: Int
    public var plan: DraftTrainingPlan?           // back-ref;CloudKit 兼容性所有 relationship optional

    @Relationship(deleteRule: .cascade, inverse: \DraftPlanExercise.day)
    public var draftExercises: [DraftPlanExercise] = []

    public init(...) { ... }
}

@Model
public final class DraftPlanExercise {
    public var id: UUID
    public var exerciseID: UUID                   // FK → CoreModels.Exercise (catalog 来自 repository)
    public var isMainLift: Bool
    public var sortOrder: Int
    public var notes: String?
    public var day: DraftPlanDay?

    public init(...) { ... }
}
```

约束:
- **不**用 `@Attribute(.unique)`(AGENTS.md SwiftData 规则: CloudKit 兼容前提下禁用)
- 所有 relationship optional(同上)
- 所有 stored property 给默认值或 optional(同上)
- 所有 `@Model` class **不**手写 `Codable` / **不**手写 `toDomain()` instance method —— 自由函数 in `DraftMapping.swift` 完成转换,避免 SwiftData 主线程隔离与 Sendable Codable closure 冲突

### `DraftStore` + ModelContainer 注入

```swift
// Planning/Drafts/DraftStore.swift
import Foundation
import SwiftData

@MainActor
public final class DraftStore {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func loadDraft(traineeID: UUID) throws -> DraftTrainingPlan? {
        let descriptor = FetchDescriptor<DraftTrainingPlan>(
            predicate: #Predicate { $0.traineeID == traineeID }
        )
        return try context.fetch(descriptor).first
    }

    public func saveDraft(_ draft: DraftTrainingPlan) throws {
        if !context.hasChanges { return }
        try context.save()
    }

    public func deleteDraft(traineeID: UUID) throws { ... }
}
```

`ModelContainer` 在 AppShell 层创建并通过 `.modelContainer(for: [...])` 注入(本 spec 修改 `MeetPRApp.swift` `WindowGroup` 加 `.modelContainer(for: [DraftTrainingPlan.self, DraftPlanDay.self, DraftPlanExercise.self])`)。`PlanningCoordinatorView` 内 `@Environment(\.modelContext) var modelContext` 取出来包成 `DraftStore`。

### `PlanRepository` protocol + mock

```swift
// Planning/Repository/PlanRepository.swift
import Foundation
import CoreModels

public protocol PlanRepository: Sendable {
    func fetchStudents() async throws -> [CoachStudentSummary]
    func fetchMainLiftCatalog() async throws -> [Exercise]
    func publishPlan(plan: TrainingPlan, days: [PlanDay], exercises: [PlanExercise]) async throws
}

// Planning/Repository/InMemoryPlanRepository.swift
public actor InMemoryPlanRepository: PlanRepository {
    private var students: [CoachStudentSummary]
    private var catalog: [Exercise]
    private var publishedPlans: [TrainingPlan] = []

    public init(students: [CoachStudentSummary], catalog: [Exercise]) {
        self.students = students
        self.catalog = catalog
    }

    public func fetchStudents() async throws -> [CoachStudentSummary] { students }

    public func fetchMainLiftCatalog() async throws -> [Exercise] {
        catalog.filter {
            $0.exerciseType == .mainLift || $0.exerciseType == .mainLiftVariation
        }
    }

    public func publishPlan(plan: TrainingPlan, days: [PlanDay], exercises: [PlanExercise]) async throws {
        publishedPlans.append(plan)
        // 本 spec 不持久化 publishedPlans 到磁盘 — 真 publish 流程在 spec 011
    }
}

// Planning/Repository/BackendPlanRepository.swift
import Foundation

// TODO: spec NNN — wire to Networking.APIClient
// 实际 Networking 接入在 backend planning endpoint spec 落地后开
public struct BackendPlanRepository {
    public init() {}
}
```

### Navigation flow 形状

```swift
public struct PlanningCoordinatorView: View {
    @Bindable var viewModel: PlanningViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack(path: $viewModel.path) {
            Step0SelectStudentView(viewModel: viewModel)
                .navigationDestination(for: PlanningStep.self) { step in
                    switch step {
                    case .selectStudent:   Step0SelectStudentView(viewModel: viewModel)
                    case .selectDuration:  Step1SelectDurationView(viewModel: viewModel)
                    case .assignFrequency: Step2AssignFrequencyView(viewModel: viewModel)
                    case .selectMainLifts: Step3SelectMainLiftsView(viewModel: viewModel)
                    }
                }
                .toolbar { /* 顶部学员浮层 collapsed/expanded */ }
        }
        .task { await viewModel.bootstrap() }
        .onChange(of: viewModel.didFinish) { _, finished in
            if finished { dismiss() }
        }
    }
}
```

`viewModel.didFinish: Bool` 是 `finish()` 内部 set true 的标志,coordinator 监听 → dismiss。

### 严格并发 + Sendable

继承 spec 001/002/003/004:`Modules/CoachKit/Package.swift` 已配 `.enableUpcomingFeature("StrictConcurrency")`。所有 `@Model` class 自动 `@MainActor` 隐式(SwiftData 默认),所有 view-model 显式 `@MainActor`,所有 actor / value-type 自然 Sendable。

### 测试约定 (新增 ViewInspector)

`Modules/CoachKit/Package.swift` testTarget 加 dependency:

```swift
.package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
```

并加到 testTarget `dependencies`:

```swift
.testTarget(
  name: "CoachKitTests",
  dependencies: [
    "CoachKit",
    .product(name: "ViewInspector", package: "ViewInspector"),
  ],
  swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
)
```

> AGENTS.md 技术栈段已预批准 ViewInspector 按需加 — 本 spec 即"按需"的首次落地。

## 验收标准

- [ ] `Modules/CoachKit/Sources/CoachKit/Planning/` 4 子目录 (Views/State/Drafts/Repository) 创建
- [ ] **5 个 view 文件** 存在 (`PlanningCoordinatorView` + 4 个 step view),public init,加 `#Preview`
- [ ] **PlanningViewModel** 是 `@Observable @MainActor final class`,字段如技术要求 §State management 形状所列
- [ ] **DraftTrainingPlan / DraftPlanDay / DraftPlanExercise** 是 SwiftData `@Model class`,relationship 全部 optional,**无** `@Attribute(.unique)`
- [ ] **DraftStore** 是 `@MainActor final class`,3 个方法 (loadDraft / saveDraft / deleteDraft) 通过 SwiftData round-trip 测试
- [ ] **DraftMapping.swift** 含 `toDomain` + `fromDomain` 自由函数;互转测试断言 (a) `DraftTrainingPlan(...).toDomain()` 字段对应 `CoreModels.TrainingPlan` (b) `fromDomain(plan:days:exercises:)` 重建出的 draft `==` 原始 draft 的关键字段
- [ ] **PlanRepository protocol** 暴露 3 个 async throws 方法
- [ ] **InMemoryPlanRepository actor** 实装 protocol,fetchMainLiftCatalog 过滤 main lift / variation,publishPlan append 到内部数组
- [ ] **BackendPlanRepository** 占位 struct 存在(空 init),module export 不影响后续 spec 接入
- [ ] **MeetPRApp.swift** `WindowGroup` 加 `.modelContainer(for: [DraftTrainingPlan.self, DraftPlanDay.self, DraftPlanExercise.self])`
- [ ] **CoachRootView** 加 `[PrimaryButton "排新计划"]` + `.fullScreenCover(...)` 接 `PlanningCoordinatorView`
- [ ] **Step 0 行为**:`InMemoryPlanRepository` 喂 (1 evaluation + 2 active + 1 abnormal) → 渲染出 3 段分组,段头数量正确,评估期内行有 ⚠️ + 倒计时文本,异常行有 🟡 + reason
- [ ] **Step 1 行为**:学员是 evaluation period 时,4 周按钮 `.disabled` 为 true,1 周按钮可点;学员是 active 时,1 周和 4 周都可点
- [ ] **Step 2 行为**:"使用模板" / "复制上周" 两个按钮渲染但 `.disabled` 为 true;sbd 频率和 day assignment 实时校验,"下一步" 按钮在不通过时 disabled
- [ ] **Step 3 行为**:per-day 显示该 day 已分配的 lift family,每个 family 一个 Picker;catalog filter 后,squat picker 仅出现 mainLiftFamily=.squat 的 exercises
- [ ] **导航 flow**:Step 0 → Step 1 → Step 2 → Step 3 顺序前进 + 系统返回手势 / `goBack()` 后退到上一步,不丢字段
- [ ] **Resume**:`viewModel.bootstrap()` 检测 SwiftData 已存 `DraftTrainingPlan`(traineeID 匹配选中学员)→ 恢复到该 draft 的 `currentStepRawValue` step + 已填字段
- [ ] **完成 flow**:Step 3 "完成基础编排" 点击 → `finish()` → SwiftData 写 → `viewModel.didFinish = true` → coordinator dismiss
- [ ] `swift build` 在 `Modules/CoachKit/` 单独跑通过,0 warning,0 error,Swift 6 strict concurrency
- [ ] `swift test` 通过,测试数 ≥ **18 个** (5 ViewModel + 3 DraftStore + 4 DraftMapping + 3 PlanRepository + 3 SnapshotTests)
- [ ] 主 Xcode target `xcodebuild build -scheme MeetPR ...` 通过
- [ ] 主 Xcode target `xcodebuild test -scheme MeetPR ...` 通过(CoachKit 改了不能破坏 AppShell 等其他 module 的引用)
- [ ] **隔离回归**:CoachKit 仍不可 import StudentKit(spec 001 验证步骤复用);Planning/Views 下 `grep -r "import Networking"` 命中数 = 0
- [ ] swiftlint + swift-format 全绿
- [ ] CI 在 `chore/spec-005-coach-planning-step-0-3` 不要紧 — 实装 PR 用 `feat/005-coach-planning-step-0-3` 跑过,全绿
- [ ] **手动 simulator 走查**:启动 app → 点 "排新计划" → 完整走 Step 0 → Step 3 → 看到 SwiftData 草稿写盘 → 杀 app → 重开 → 自动恢复到上次 step

## 参考

- **Wireframe ground truth**: [`~/Brain/wiki/projects/MeetPR/coach-planning.md`](~/Brain/wiki/projects/MeetPR/coach-planning.md) v4.4 §Step 0 / §Step 1 / §Step 2 / §Step 3
- **数据模型**: [`~/Brain/wiki/projects/MeetPR/data-model.md`](~/Brain/wiki/projects/MeetPR/data-model.md) v1.1 §1.3 (StudentProfile Type A 锁定字段) / §1.4 (Exercise + facets) / §1.8 (TrainingPlan / PlanDay / PlanExercise)
- **架构**: [ADR-005 §1 (CoachKit 模块边界) + §3 (MVVM + Repository pattern + 三层职责)](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
- **Pivot 红线**: [coach-planning v4.4 §7d (网页端 scope 扩张吸收所有 4 周宏观能力)](~/Brain/wiki/projects/MeetPR/coach-planning.md) + [PD-007 web companion deferred V1.x](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md)
- **F-015 双保险**: [FOLLOWUPS.md](../../FOLLOWUPS.md)
- **上游 spec**:
  - [spec 002](../002-core-models-identity/SPEC.md) — `StudentProfile` / `User` / 各 enum
  - [spec 003](../003-design-system-foundation/SPEC.md) — `PrimaryButton` / `SecondaryButton` / `Card` / `NumericInput` / `Eyebrow` / `MeetPRListRow` 等 atomic 组件
  - [spec 004](../004-core-models-training-plan/SPEC.md) — `TrainingPlan` / `PlanDay` / `PlanExercise` / `Exercise` / `LiftFamily` / `ExerciseType` / `PlanSource` / `PlanStatus`

## Notes (给 Claude review + Codex)

### 🎯 用户已拍板的 3 个决定 (本 spec 必须按这 3 个写)

| 维度 | 决定 | 落地形态 |
|---|---|---|
| **UI 模块放哪** | β | CoachKit 现有 SPM target,子目录 `Planning/`,**不**新建 target |
| **Draft 持久化** | b | SwiftData `@Model` (`DraftTrainingPlan` 等 3 个 class) + `DraftStore` (`@MainActor` ModelContext wrapper) |
| **Backend endpoint 假设** | β | `PlanRepository` protocol + `InMemoryPlanRepository` actor mock + `BackendPlanRepository` 占位 — 真接入留独立后续 spec |

### ⚠️ ADR-005 §4 偏离声明 — 需 Claude review 判定

ADR-005 §4 写 "**V1 不用 SwiftData**: 学习曲线 + schema migration 风险 + 单 dev 早期承担不起。V1.5 数据量爆炸 / 复杂查询 / iCloud sync 时再迁"。

本 spec 引入 SwiftData,**scope 严格限制在 Coach Planning Editor draft**(3 个 `@Model` class):
- 不替代 ADR-005 §4 的 JSON file + Codable 用于 当前 cycle / 训练记录草稿 / 视频上传队列 — 那些仍 JSON
- SwiftData 仅服务"教练编辑器中途退出后下次自动恢复"这一个用例,write-heavy + 复杂可变对象图的场景比 rolling JSON 干净
- 不接 CloudKit (V1 不需要)

**建议 review 决定**:
1. **接受偏离**:在本 spec merge 前,起 `ADR-009` 把 ADR-005 §4 的 "V1 不用 SwiftData" 句子收紧成 "V1 默认不用 SwiftData,例外仅本地 draft 编辑器 (CoachKit Planning) 用,不接 CloudKit",或
2. **拒绝偏离**:回到 JSON file + Codable 重写本 spec 的 Drafts/ 子目录;ViewModel 接口形状不变

如果 review 决定 (1),Codex 实施前 ADR-009 必须先落地;如果 (2),本 spec 重写 Drafts/ 部分(ViewModel / Repository / View 不影响)。

### F-015 自检 (扫一遍 spec 不出现以下字眼)

- ✅ "4 周扫视态" — 0 命中
- ✅ "Excel grid" — 0 命中
- ✅ "波形图" / "波形" — 0 命中
- ✅ "变式矩阵" — 0 命中
- ✅ "密度条" / "密度热图" — 0 命中
- ✅ "specificityBucket" / "waveformValue" / "accessoryDensityBucket" / "isDeloadWeek" — 0 命中

### 给 Codex 的实施小提示

- 本 spec **不是机械翻译工作** — 与 spec 002/004 的纯领域类型 spec 不同,本 spec 是**真实 UI 实装**,可能遇到 SwiftUI / SwiftData / NavigationStack 边角 case。任何疑问写 `QUESTIONS.md` 由 Claude review,不擅自决定。
- **ViewInspector 引入** 是 V1 第一次加第三方依赖 — 严格按 `Package.swift` 改动 commit,版本锁 `from: "0.10.0"`。
- **SwiftData @Model 不写 Codable** — `DraftMapping.swift` 自由函数完成与 `CoreModels` value types 互转,避免 main-actor isolation + Sendable 冲突。
- 测试 fixture 用最小**完整**数据 — `CoachStudentSummary` fixtures 至少含 1 evaluation + 2 active + 1 abnormal 各覆盖 status 三 case。
- 完成后**别 self-merge** — Claude review 后才 merge。
- 实装 PR 用 `feat/005-coach-planning-step-0-3` 分支(本 PR `chore/...` 仅承载 spec 文件)。
- PR description 列每个 step 的 wireframe 截图 (Xcode Canvas) 对照 coach-planning.md 文本 wireframe。
