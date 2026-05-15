# 024 — Student P0 views(学员端从占位装到"教练-学员两人能跑通的闭环")

- **状态**: Draft
- **PR**: TBD(spec PR + impl PR per AGENTS.md §Spec 生命周期)
- **来源**:
  - [`~/Brain/wiki/projects/MeetPR/v0_1_pre_plan.md`](~/Brain/wiki/projects/MeetPR/v0_1_pre_plan.md) §候选 1 — V0.1+ 学员端 P0 view think-through
  - [`~/Brain/wiki/projects/MeetPR/prd.md`](~/Brain/wiki/projects/MeetPR/prd.md) §5 #12 / #13 / #15 / #17 — 学员端 P0 有教练模式 4 条
  - [ADR-005 §1 模块边界(StudentKit ⊥ CoachKit)+ §3 Repository pattern + §4 学员侧 JSON file 持久化](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
  - 上游 [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) — `User` / `UserRole` / `StudentProfile`
  - 上游 [spec 004 CoreModels training plan](../004-core-models-training-plan/SPEC.md) — `TrainingPlan` / `PlanDay` / `PlanExercise` / `PlanSet` data shape
  - 上游 [spec 020 V0 demo orchestration](../020-v0-demo-orchestration/SPEC.md) — `DemoAuthRepository` / `DemoTokenStore` 沿用 build-time 切换
  - 上游 [spec 011 auth UI flow](../011-auth-ui-flow/SPEC.md) — `Session` / `RootView` role-routed 已支持 `.student` 分支(目前只指向占位)
  - **不在本 spec 范围**:候选 2(真实注册流)+ 候选 3(backend 真接入)— 本 spec 全程跑 in-memory mock,DEMO_MODE 注入

## 目标

把 StudentKit 从单文件 `Text("Hello Student 🏋️")` 占位,装到 **"学员侧 4 tab(今天 / 本周 / 历史 / 反馈)完整闭环 UI,使用 seeded 历史 data 自洽验证"**,全程 in-memory mock 不接真 backend。

**Scope clarification(2026-05-15 接 PR #112 Codex review #1 blocker 收窄)**:
- 本 spec **不承担** "教练 build A publish → 学员 build B 拉到同一份 plan" 的跨身份闭环 — 物理上 in-memory + 切 scheme = 新进程,数据会丢,无法用 manual checklist 验过
- 跨身份闭环正式 defer 到 **spec 026(backend 真接入)**:两台真手机 + 真 backend 才能验"教练 publish → 学员 fetch"
- 本 spec 同一 simulator 内 DEMO_MODE 切 scheme 自测时,**学员侧看到的是 `StudentDemoSeed` 预置的 4 周 plan + 历史 logs + feedback**,不依赖刚 publish 的数据;教练侧仍可走 spec 020 既有 happy path 排 plan(不要求被学员侧立刻看到)

**为什么这个 scope**:
- 用户 2026-05-15 dogfood scope 决策:候选 1(学员端) + 候选 2 内的"login + Keychain" 子集 + 候选 3(backend)三路并行,但本 spec 严格只做候选 1。
- 候选 2 / 候选 3 各起独立 spec,本 spec 写完后 UI + Repository protocol 已 ready,候选 3 直接换 `BackendStudentPlanRepository` 实装替 `InMemoryStudentPlanRepository`,UI 0 改。
- "教练-学员闭环"= plan publish + plan fetch + log record + feedback view 四件事;V0.1 闭环的真验证在 spec 026 落地后用真 backend + 两台手机做;本 spec 仅保证学员侧 UI / 数据流 / state machine 自洽。

落地后单 simulator 自测 happy path(收窄 scope 后):

```
[MeetPR-DemoStudent scheme: 学员 seed (DemoUserSeed.coachedStudent,本 spec 新增)]
打开 → StudentRootView (TabView, 4 tabs)
  ↓ 启动注入 InMemoryPlanStore 已含 StudentDemoSeed.makePlanView(weekIndex: 1) 预置 projection
  ↓ Tab 1 "今天" — 看到今日训练动作 + prescribed sets(来自 seed projection)
  ↓ 进每个动作详情 → 每组 [重量 prescribed 不可改 / reps / RPE / ✓]
  ↓ 录入 + 打勾 → InMemoryStudentTrainingLogRepository.recordSet(...)(内存)
  ↓ Tab 2 "本周" — 看本周 7 天 plan overview
  ↓ Tab 3 "历史" — 单 cycle 内按周翻 + 单日详情(含 seed historical logs)
  ↓ Tab 4 "反馈" — 看 seed 的 3 条 feedback + 未读红点 + markRead 后角标 -1

[可选:同一 simulator 切 MeetPR-Demo scheme(教练)]
教练 home → 排 plan → publish → InMemoryPlanRepository.publishPlan(...)
  ↓ 跑教练侧 mapper 一次性产出 StudentPlanView projection → 写入 InMemoryPlanStore
  ↓ (此处切回学员 scheme = 新进程,store 内存就丢;教练 publish 不会被学员侧看到)
  ↓ 教练 publish 本身的 demo 价值由 spec 020 既有路径承担,**本 spec 不依赖**
```

> **2026-05-15 scope 声明**:本 spec 范围 = 学员侧 4 tab 完整闭环 UI(自洽验证)。同期 V0.1 必做范围内并行 spec:
> - 教练端看学员执行 + 反馈 editor → spec 029(本 spec 学员反馈来源仍用 seed mock,029 落地后接 029 提供的真 postFeedback API)
> - 视频上传 → spec 027(本 spec `SetRecordRow` 不画视频附件 UI,留 affordance 给 027 加)
> - e1RM 折线 → spec 028(本 spec `StudentSetLog` schema 已含 weightKg/reps,028 直接读)
> - 真实 login + Keychain → spec 025(本 spec 用 `DemoUserSeed.coachedStudent`,025 落地后 user 注入路径不变)
> - **跨身份"教练 publish → 学员 fetch"真闭环** → spec 026(backend 真接入 + 两台真机互通)
>
> 跨 cycle 历史 / 按月 history / 资料 4 级权限 / 真 APNs push → V0.1.x

## 范围

### 做什么

#### 1. StudentKit 真实装 + feature folder 骨架

替 `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift` 占位实现,按 ADR-005 §3 MVVM + Repository 三层 pattern 起 4 个 feature folder。

**架构 update(2026-05-15 接 PR #117 Codex review #1 blocker D3 决议)**:3 个学员侧 Repository protocol(`StudentPlanRepository` / `StudentTrainingLogRepository` / `StudentFeedbackRepository`)**移到新建 SPM target `Modules/RepositoryContracts/`** — 详见 spec 029。本 spec 在 StudentKit 内仅放 In-Memory* 实装(impl),protocol 引用 `RepositoryContracts`。CoreModels 保持纯数据型,不放 protocol。

```
Modules/RepositoryContracts/Sources/RepositoryContracts/        # spec 029 新建,3 个 protocol 在此
├── StudentPlanRepository.swift                                  # protocol (fetch 本周 plan / fetch 日训练)
├── StudentTrainingLogRepository.swift                           # protocol (record set / fetch 已录入历史)
└── StudentFeedbackRepository.swift                              # protocol (fetch 反馈列表 / mark as read)

Modules/StudentKit/Sources/StudentKit/
├── StudentRootView.swift                              # TabView 4 tab + Session 注入 currentUser
├── Repository/
│   ├── InMemoryStudentPlanRepository.swift           # actor, 读 InMemoryPlanStore 的 projection
│   ├── InMemoryStudentTrainingLogRepository.swift    # actor, 录入存内存
│   ├── InMemoryStudentFeedbackRepository.swift       # actor, seed 3-5 条 fake 反馈
│   └── StudentDataDTO.swift                          # 跨 repo 复用的 DTO(StudentPlanView / StudentSetLog / CoachFeedback)
├── Features/
│   ├── TodayWorkout/                                 # Tab 1 "今天"
│   │   ├── TodayWorkoutView.swift                    # 主入口
│   │   ├── TodayWorkoutViewModel.swift               # @Observable @MainActor
│   │   ├── ExerciseExecutionView.swift               # 单动作详情 (列出该动作的 N 组)
│   │   ├── SetRecordRow.swift                        # 单组录入 [Wt 灰 / reps TextField / RPE slider / ✓]
│   │   └── DayCompletionBanner.swift                 # 全部 ✓ 时显示"今日完成"
│   ├── WeekOverview/                                 # Tab 2 "本周"
│   │   ├── WeekOverviewView.swift                    # 7 天 grid + 完成状态
│   │   ├── WeekOverviewViewModel.swift
│   │   └── DayCard.swift                             # 单日 card (动作数 / 完成度)
│   ├── TrainingHistory/                              # Tab 3 "历史"(单 cycle 内按周)
│   │   ├── TrainingHistoryView.swift                 # 4 周 list + 单周展开
│   │   ├── TrainingHistoryViewModel.swift
│   │   └── DayDetailView.swift                       # 单日已录入 sets 详情 (read-only)
│   └── FeedbackInbox/                                # Tab 4 "反馈"
│       ├── FeedbackInboxView.swift                   # 反馈列表 + 未读红点
│       ├── FeedbackInboxViewModel.swift
│       └── FeedbackDetailView.swift                  # 单条反馈展开
└── Demo/
    └── StudentDemoSeed.swift                         # 4 周 plan projection + 3 条 feedback + 历史 logs seed
```

**关键不变量** (per ADR-005 §1,spec 029 amend 后):
- `Modules/StudentKit/Package.swift` **不** 加 `CoachKit` 依赖 — 互不 import
- `Modules/StudentKit/Package.swift` 依赖加 `RepositoryContracts`
- Repository 内部用 `actor`,UI ViewModel `@Observable @MainActor`
- 所有 cross-module 类型走 CoreModels(`TrainingPlan` / `PlanDay` / `PlanExercise` / `PlanSet` / `Exercise` / `User` / `StudentProfile`),Repository protocol 走 RepositoryContracts

#### 2. CoreModels 新增"学员视角"型 read-only 数据

学员侧 fetch 出来的不应该再带教练编辑期的中间态(`PlanRule` / `WeeklyVariation` 等)。CoreModels 加几个 read-only projection 型:

| 文件 | 内容 |
|---|---|
| `Modules/CoreModels/Sources/CoreModels/Entities/Plan/StudentPlanView.swift`(新) | `public struct StudentPlanView: Codable, Hashable, Sendable` — 学员视角的当前 cycle plan: `cycleId / weekIndex / startDate / days: [StudentPlanDay]` |
| 同上 + `StudentPlanDay` 内嵌 | `public struct StudentPlanDay: Codable, Hashable, Sendable, Identifiable` — `id / date / exercises: [StudentPlanExercise]` |
| 同上 + `StudentPlanExercise` 内嵌 | `public struct StudentPlanExercise: Codable, Hashable, Sendable, Identifiable` — `id / exercise: Exercise / sequenceIndex / prescribedSets: [PrescribedSet]` |
| 同上 + `PrescribedSet` 内嵌 | `public struct PrescribedSet: Codable, Hashable, Sendable, Identifiable` — `id / setIndex / weightKg: Double? / reps: Int? / repsMax: Int? / rpe: Double?`(reps `repsMax` 二选一,RPE 教练可空) |
| `Modules/CoreModels/Sources/CoreModels/Entities/Plan/StudentSetLog.swift`(新) | `public struct StudentSetLog: Codable, Hashable, Sendable, Identifiable` — `id / studentId / planExerciseId / setIndex / loggedAt: Date / weightKg / reps / rpe / completed: Bool` |
| `Modules/CoreModels/Sources/CoreModels/Entities/CoachFeedback.swift`(新) | `public struct CoachFeedback: Codable, Hashable, Sendable, Identifiable` — `id / coachId / studentId / dayDate: Date? / planExerciseId: UUID? / text: String / postedAt: Date / readAt: Date?` |

> **不动现有 `TrainingPlan` / `PlanDay` / `PlanExercise`**:那是教练编辑期的"草稿"型,带 PlanRule 之类。学员视角必须是"已固化的、可执行的"。Mapper(草稿 → 学员视图)由 InMemoryStudentPlanRepository 内部实现,不暴露。

#### 3. Repository protocol + in-memory 实装

**Protocol 位置(2026-05-15 D3 决议)**:3 个 protocol 在 `Modules/RepositoryContracts/Sources/RepositoryContracts/` 内定义(spec 029 新建 SPM target)。本 spec impl 阶段 Codex 先开 RepositoryContracts target,再装 InMemory* impl。spec 029 内的 mechanical refactor 在 029 impl 时进行;本 spec impl 期 protocol 直接在新位置起。

##### 3.1 `StudentPlanRepository`(`RepositoryContracts/StudentPlanRepository.swift`)

```swift
import CoreModels
import Foundation

public protocol StudentPlanRepository: Sendable {
  /// 学员 ID 是隐式当前用户的;UI 层从 Session 取后传入
  func fetchCurrentPlan(studentId: UUID) async throws -> StudentPlanView?
  /// 指定日 (年-月-日 in user TZ); 返 nil 表示该日无训练
  func fetchDay(studentId: UUID, date: Date) async throws -> StudentPlanDay?
  /// 单 cycle 内全部历史日(含未来未发生的);UI 层按 weekIndex 分组
  func fetchCycleDays(studentId: UUID) async throws -> [StudentPlanDay]
}
```

`InMemoryStudentPlanRepository`(`StudentKit/Repository/InMemoryStudentPlanRepository.swift`):
- **D2 决议(2026-05-15 接 PR #112 review #2 blocker)**:store 持 **publish-ready `StudentPlanView` projection**,**不持** raw `(TrainingPlan, [PlanDay], [PlanExercise], [PlanSet])` 四件套。教练侧 `InMemoryPlanRepository.publishPlan(...)` 内部跑 mapper 把草稿转 projection,**写入** store;学员侧 `InMemoryStudentPlanRepository.fetchCurrentPlan(...)` 直接读 projection,**不做** mapping。
- 这一改动解决 PR #112 review #2 blocker:此前 `publishPlan(plan, days, exercises)` 签名缺 `[PlanSet]`,学员侧拿不到 set 级 `weight/reps/repsMax/rpe`。新签名见 §技术要求 / Repository 共享 store 设计
- AppShell 的 store 文件:`Modules/AppShell/Sources/AppShell/Demo/InMemoryPlanStore.swift`(新)
- mapper 位置:**`Modules/CoachKit/Sources/CoachKit/Planning/PublishProjection/PlanToStudentProjection.swift`(新,放教练侧)** — mapper 在教练 publish 路径上跑,不需要 StudentKit import CoachKit;StudentKit 仅读 projection

##### 3.2 `StudentTrainingLogRepository`(`RepositoryContracts/StudentTrainingLogRepository.swift`)

```swift
public protocol StudentTrainingLogRepository: Sendable {
  func recordSet(_ log: StudentSetLog) async throws
  func fetchLogs(studentId: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog]
  func fetchLogsForExercise(studentId: UUID, planExerciseId: UUID) async throws -> [StudentSetLog]
}
```

`InMemoryStudentTrainingLogRepository`:
- actor 持有 `[UUID: [StudentSetLog]]`(key = studentId)
- recordSet 幂等:同 `(studentId, planExerciseId, setIndex)` 重复录入直接 overwrite 不抛
- DEMO_MODE seed:启动时给当前学员塞 1-2 个已完成日的历史 log,验"历史 tab 不空"

##### 3.3 `StudentFeedbackRepository`(`RepositoryContracts/StudentFeedbackRepository.swift`)

```swift
public protocol StudentFeedbackRepository: Sendable {
  func fetchInbox(studentId: UUID) async throws -> [CoachFeedback]
  func markRead(feedbackId: UUID) async throws
  /// V0.1 测试用 seed 入口(impl 仅 in-memory,protocol 暴露给 Demo 调用注 seed)
  func _seedFeedback(_ items: [CoachFeedback]) async
}
```

`InMemoryStudentFeedbackRepository`:
- actor 持有 `[CoachFeedback]`
- DEMO_MODE seed 启动时塞 3 条:1 条已读 + 2 条未读 + 至少 1 条带 `planExerciseId`(验"点反馈跳到当时动作"V0.1.x defer 但 schema 先 ready)
- `markRead` 改 `readAt = Date()`,不抛

#### 4. StudentRootView 4 tab + Session 注入

```swift
public struct StudentRootView: View {
  @Environment(Session.self) private var session
  private let plans: StudentPlanRepository
  private let logs: StudentTrainingLogRepository
  private let feedback: StudentFeedbackRepository

  public init(
    plans: StudentPlanRepository,
    logs: StudentTrainingLogRepository,
    feedback: StudentFeedbackRepository
  ) { ... }

  public var body: some View {
    TabView {
      TodayWorkoutView(...).tabItem { Label("今天", systemImage: "figure.strengthtraining.traditional") }
      WeekOverviewView(...).tabItem { Label("本周", systemImage: "calendar") }
      TrainingHistoryView(...).tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
      FeedbackInboxView(...).tabItem {
        Label("反馈", systemImage: "bubble.left")
      }.badge(unreadCount)  // 从 FeedbackInboxViewModel 取 unread count
    }
  }
}
```

- `RootView`(AppShell)既有 `.student` 分支当前直接 `StudentRootView()`,改成传入 3 个 repo
- 3 个 repo 在 `MeetPRApp.init()` 创建:DEMO_MODE = in-memory mock 共享 store;非 DEMO_MODE 占位 `fatalError("TODO: spec 026 backend wiring")`(类比 BackendPlanRepository pattern)

#### 5. Today / Week / History / Feedback 4 个 View 行为

> 4 个 view 设计原则:学员侧 V1 文案极简(无 onboarding,无空态长说明),只给"动作 / 数字 / 打勾"3 元素。

##### 5.1 `TodayWorkoutView` (Tab 1)

**学员看到啥**:
- 顶部 large title "今天" + 副标题 e.g. "Week 2 · 周三 · 上肢日"
- 该日 N 个动作(主项 + 辅助按 plan sequence)— 每个动作是个 card,展开后内嵌 M 组 `SetRecordRow`
- 每组 row 布局 `[ 序号 ][ Wt(灰,prescribed,不可改) ][ reps TextField ][ RPE 滑块 0.5 步进 ][ ✓ 按钮 ]`
- RPE 滑块默认值 = prescribed RPE(若教练有填),没填默认 8.0
- reps TextField 默认值 = prescribed reps(单值时);prescribed 是 `repsMax`(范围)时 placeholder 显示 "≤ N"
- 点 ✓ → `StudentTrainingLogRepository.recordSet(...)` + row 高亮绿
- 全部动作所有组都打勾 → 底部 `DayCompletionBanner` 滑出 "今日完成 · 总组数 N / 完成 N"

**state machine**:
- `idle → loading → loaded([StudentPlanExercise]) → recording(setIndex) → loaded`
- error 显示顶部红 banner + retry 按钮
- 当日无训练:`StudentPlanRepository.fetchDay` 返 nil → 显示 "今天休息 💪 看本周计划",CTA 切到 Tab 2

##### 5.2 `WeekOverviewView` (Tab 2)

**学员看到啥**:
- 顶部 "Week N / 4"(总长由 cycle 决定;在 V0.1 sceond cycle 出现前先用 plan.cycleId 的 weekIndex 范围,UI 不假设 4 周)
- 7 个 `DayCard` 竖排(周一→周日):每个 card 显示 [日期 · 训练标签 · 完成度 N/M 组]
- 休息日:灰色 card "休息日"
- 已完全完成:绿色边框 + ✓ icon
- 进行中:橙边框
- 点任意 card → push 到 `DayDetailView`(若已有 log)或 `TodayWorkoutView`(若是今日且无 log)

##### 5.3 `TrainingHistoryView` (Tab 3)

**学员看到啥**:
- 顶部 segmented:"按周" / "按月"(V0.1 只装"按周",按月 placeholder 灰禁用,V0.1.x 实)
- "按周" 模式:list of `Week N(月-日 ~ 月-日)`,每行内嵌完成度 mini bar
- 点周 → 展开 7 天 + 每天可点入 `DayDetailView`
- 单 cycle 内 4 周;跨 cycle list V0.1.x

##### 5.4 `FeedbackInboxView` (Tab 4)

**学员看到啥**:
- 顶部 "反馈"
- list of feedback,每条 row `[ 圆点(未读)/无圆点(已读) ][ 教练名 ][ 反馈摘要前 50 字 ][ 相对时间 ]`
- 点行 → push `FeedbackDetailView`(全文 + 关联日期 chip + 教练头像占位)+ `markRead`
- Tab 角标显示未读数(`@Observable` ViewModel 暴露 unreadCount)

##### 5.5 `DayDetailView`(History + Week 共用)

**学员看到啥**:
- 当日所有动作 + 已录入组的实际 reps/RPE/重量(read-only)
- 未录入的组显示灰色 prescribed 值

#### 6. Demo seed 数据增强

`Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`(新):

```swift
public enum StudentDemoSeed {
  public static let coachedStudent: User  // role=.coachedStudent, displayName="演示学员", fixed UUID
  public static let coachId: UUID         // 指向 DemoUserSeed.coach.id
  public static func makePlanView(weekIndex: Int = 1) -> StudentPlanView
  public static func makeHistoricalLogs(studentId: UUID, weekIndex: Int) -> [StudentSetLog]
  public static func makeFeedback(coachId: UUID, studentId: UUID) -> [CoachFeedback]
}
```

> 实际字段名是 `.coachedStudent` / `.selfTrainStudent`(per CoreModels `UserRole` enum,非 `.student`)— 本 spec 全文沿用 `.coachedStudent` 指内测学员身份。

`Modules/AppShell/Sources/AppShell/Auth/Demo/DemoUserSeed.swift` 扩展:加 `public static let coachedStudent: User` 常量(与 coach 并列)。

`Modules/AppShell/Sources/AppShell/Auth/Demo/DemoTokenStore.swift` 扩展:
- DEMO_MODE 内增加 build-time toggle 选 `coach` / `coachedStudent` user seed,实装方式 = 一个 Swift compile flag `DEMO_USER_STUDENT`(默认未定义 → coach;定义 → coachedStudent)
- 在 xcodeproj 内加第二个 scheme `MeetPR-DemoStudent`(基于 MeetPR-Demo)显式设 `DEMO_USER_STUDENT`,跑 build B 时用这个 scheme

#### 7. MeetPRApp.init 注入 3 个学员 Repository

```swift
#if DEMO_MODE
let planStore = InMemoryPlanStore.shared  // shared actor,教练 publish + 学员 fetch 共用
let studentPlans = InMemoryStudentPlanRepository(store: planStore)
let studentLogs = InMemoryStudentTrainingLogRepository()
let studentFeedback = InMemoryStudentFeedbackRepository()
await studentFeedback._seedFeedback(StudentDemoSeed.makeFeedback(coachId: ..., studentId: ...))
// 同样 seed historical logs
#else
let studentPlans = BackendStudentPlanRepository()  // fatalError until spec 026
...
#endif
```

`RootView` 的 `.authenticated` 分支按 `user.role` 路由,`.student` 传入 3 个 repo。

#### 8. 测试 (`Modules/StudentKit/Tests/StudentKitTests/`)

| 测试文件 | 覆盖 |
|---|---|
| `Repository/StudentPlanRepositoryTests.swift`(新) | InMemoryStudentPlanRepository fetch:有 plan / 无 plan / 日期边界 |
| `Repository/StudentTrainingLogRepositoryTests.swift`(新) | recordSet 幂等覆盖 / fetchLogs 范围过滤 / 跨学员隔离 |
| `Repository/StudentFeedbackRepositoryTests.swift`(新) | inbox seed + markRead 状态翻转 / unread count 计算 |
| `Features/TodayWorkout/TodayWorkoutViewModelTests.swift`(新) | state machine idle→loading→loaded→recording,record 失败 → error |
| `Features/FeedbackInbox/FeedbackInboxViewModelTests.swift`(新) | unread count 准确,markRead 后 count -1 |
| `Demo/StudentDemoSeedTests.swift`(新) | seed 数据 well-formed:plan 至少 1 周 7 天,feedback 至少 1 未读 1 已读 |

UI snapshot 测试 V0.1 不强制(per CoachKit 现状),Codex 实装时可视情况补 swift-snapshot-testing。

#### 9. V0 demo 路径 manual checklist(本 spec `CHECKLIST.md`)

实装合并后人工跑一遍 happy path,放 `specs/024-student-p0-views/CHECKLIST.md` (新),Codex 在 impl PR 内写好。例:

```
[ ] 启 MeetPR-Demo scheme(coach)→ 排 4 周 plan → publish(spec 020 已有 button,本 spec 不动)
[ ] 启 MeetPR-DemoStudent scheme(本 spec 加)→ 进 StudentRootView
[ ] Tab 今天:能看到刚发的当周 plan 中今日动作,prescribed sets 可见
[ ] 录任一组 reps + RPE + ✓ → 视觉反馈 + 重启 simulator 后丢失(in-memory 预期)
[ ] 全部 ✓ → DayCompletionBanner 出
[ ] Tab 本周:7 天 cards 完整 + 完成度反映 step 1 的录入
[ ] Tab 历史:看到 seed 历史 + 今日已录入(若日内)
[ ] Tab 反馈:角标 = seed 未读数,点条目 markRead 后角标 -1
```

### 不做什么

**V0.1 内独立 SPEC 并行实装(本 spec 不做,平级 spec)**:
- §5 #14 视频上传 → [spec 027](../027-video-upload/SPEC.md)
- §5 #16 e1RM 折线 + PR 自动推送 → [spec 028](../028-e1rm-curve-pr-push/SPEC.md)
- 教练端"看学员执行" + feedback editor → [spec 029](../029-coach-student-detail-feedback/SPEC.md)

**V0.1.x defer(本阶段后下一波)**:
- §5 #18 我的资料 4 级权限(需 backend 字段权限矩阵)
- 跨 cycle 历史(本 spec 仅当前 cycle 内 4 周)
- 按月 history(segmented 占位 placeholder 灰)
- 真实 push notification(本 spec 仅 in-app badge + 角标;APNs/Push 独立 spec)
- 反馈点击跳到当时动作(schema 留 `planExerciseId` 字段,UI 跳转 V0.1.x)

**V0.2+ defer**:
- §5 #9-#11 待接收 / 评估期 / 评估总结(gated by 真注册流 候选 2 + evaluation-workflow 全栈)
- §5 #19-#23 自己练 mode(B2C,Phase 2,需 里欧模板交付)
- §5 #24 真实手机号 + Apple Sign-In(候选 2)
- 多个学员账号(本 spec DEMO_MODE 只支持一个固定学员 seed,候选 2 后才能多账号)

**永不做(架构决定,非 V?)**:
- 学员侧 SwiftData 持久化(per ADR-009 SwiftData 例外清单 — 仅 CoachKit Planning Editor,学员侧不在内)
- 学员侧 in-progress draft 概念(学员侧无草稿,录即终态)
- StudentKit import CoachKit(ADR-005 §1 强制不变量)

## 技术要求

### 模块位置 + import 边界(强制)

| 模块 | 新增内容 | 允许 import |
|---|---|---|
| `CoreModels` | `StudentPlanView` / `StudentPlanDay` / `StudentPlanExercise` / `PrescribedSet` / `StudentSetLog` / `CoachFeedback` | Foundation 仅 |
| **`RepositoryContracts`(spec 029 新 SPM target)** | 3 个 Repository protocol(`StudentPlanRepository` / `StudentTrainingLogRepository` / `StudentFeedbackRepository`) | `CoreModels` / Foundation 仅;**禁止** `SwiftUI` / IO / Combine |
| `StudentKit` | 4 feature folder + `InMemory*Repository` impl + Demo seed | `CoreModels` / `RepositoryContracts` / `Networking` / `DesignSystem` / `SwiftUI` |
| `AppShell` | `InMemoryPlanStore` actor + `DemoUserSeed.coachedStudent` + `RootView` 注入 | 既有 + `RepositoryContracts` |
| `CoachKit` | `InMemoryPlanRepository` 改:接收 `InMemoryPlanStore` 注入(构造器加参数);**新增 publish-side mapper** `Planning/PublishProjection/PlanToStudentProjection.swift`;**不引入 StudentKit 依赖** | 既有 + `RepositoryContracts`(若教练侧也跑反向 publish flow,本 spec impl 阶段 RepositoryContracts 仅 StudentKit / AppShell 引,CoachKit 可不引)|

**关键不变量自检**(impl PR review 时跑):
```bash
grep -rE "^import (CoachKit|StudentKit)" Modules/StudentKit/  # 应为空
grep -rE "^import StudentKit" Modules/CoachKit/               # 应为空
```

### Repository 共享 store 设计(critical · 2026-05-15 D2 重新设计)

**Design** (PR #112 Codex review #2 blocker D2 决议 b):store 持 **publish-ready `StudentPlanView` projection**;教练侧 `InMemoryPlanRepository.publishPlan(...)` 内部跑 mapper 把"教练草稿(plan / days / exercises / sets)"转成 projection 写入 store;学员侧 `InMemoryStudentPlanRepository.fetchCurrentPlan(...)` 直接读 projection。**学员侧 0 mapping**。

**为什么是 (b) 不是 (a)** — 选 (a) 把 raw 四件套塞 store + 学员侧 mapper 会拉学员 module 反推 set 级 prescribed,但教练侧的 `[PlanSet]` 真实数据由 `DraftMapping.toDomainSets(_:)` 单独展开,不在现 `PlanRepository.publishPlan(plan, days, exercises)` 签名内,学员侧反推不出 weight/reps/repsMax/rpe。projection 在教练侧 publish 时一次性产出最简单。

**实装结构**:

```
Modules/AppShell/Sources/AppShell/Demo/InMemoryPlanStore.swift            # 新
  actor InMemoryPlanStore {
    private var publishedProjections: [UUID: StudentPlanView]              // key = studentId
    public func savePublishedProjection(_ projection: StudentPlanView, forStudent studentId: UUID) async
    public func getPublishedProjection(forStudent studentId: UUID) async -> StudentPlanView?
  }

Modules/CoachKit/Sources/CoachKit/Planning/PublishProjection/             # 新文件夹
├── PlanToStudentProjection.swift                                          # 教练侧 mapper(本 spec 必装)
│   - input: TrainingPlan + [PlanDay] + [PlanExercise] + [PlanSet] + 当前 weekIndex
│   - output: StudentPlanView
└── PlanToStudentProjectionTests.swift                                     # 5+ fixture(在 CoachKit 测试 target,因 mapper 在此)

Modules/CoachKit/Sources/CoachKit/Planning/Repository/InMemoryPlanRepository.swift
  // 改:加 store 依赖,publishPlan 内跑 mapper 写 projection
  public actor InMemoryPlanRepository: PlanRepository {
    private let store: InMemoryPlanStore   // ← 新依赖
    public init(students:catalog:store:)
    public func publishPlan(plan: TrainingPlan, days: [PlanDay], exercises: [PlanExercise], sets: [PlanSet]) async throws {
      let projection = PlanToStudentProjection.project(plan: plan, days: days, exercises: exercises, sets: sets, weekIndex: ...)
      await store.savePublishedProjection(projection, forStudent: plan.traineeId)
    }
  }

Modules/StudentKit/Sources/StudentKit/Repository/InMemoryStudentPlanRepository.swift
  public actor InMemoryStudentPlanRepository: StudentPlanRepository {
    private let store: InMemoryPlanStore   // ← 共享 store
    private let studentId: UUID            // 当前学员 id
    public init(store: InMemoryPlanStore, studentId: UUID)
    public func fetchCurrentPlan(studentId: UUID) async throws -> StudentPlanView? {
      return await store.getPublishedProjection(forStudent: studentId)
    }
    // fetchDay / fetchCycleDays 走 projection slice,纯切片不 map
  }
```

**`PlanRepository.publishPlan` 签名扩展**:**加 `sets: [PlanSet]` 参数**(原签名缺,Codex review #2 blocker 直接修复)。改既有 `Modules/CoachKit/Sources/CoachKit/Planning/Repository/PlanRepository.swift` protocol;`PlanningCoordinatorView` 调用点同步改(传 `DraftMapping.toDomainSets(planExercise)` 展开后的 sets)。

**测试**:
- `InMemoryPlanStore` 单测:并发 save/get;按 studentId 隔离
- `PlanToStudentProjection` 单测:**≥6 fixture**(per Codex review #112 non-blocking 建议)— 简单单周 / 多周 WeeklyVariation progression / repsMax 范围 / RPE 空 / 主项+辅助混合 / **setCount > 1 多组展开** / **`.rpe` intensity_mode 与 `.rpe` 直接值的区别**
- `InMemoryStudentPlanRepository` 单测:store 注入 mock projection → fetch 返回相同

### DTO mapping(教练草稿 → 学员视图)— mapper 在教练侧

Mapper 位置:**`Modules/CoachKit/Sources/CoachKit/Planning/PublishProjection/PlanToStudentProjection.swift`**(新,**不在 StudentKit**)— 教练侧的 publish-time 静态函数,纯逻辑无 IO。

输入:`(TrainingPlan, [PlanDay], [PlanExercise], [PlanSet], weekIndex: Int)`
输出:`StudentPlanView`

关键规则:
- 学员视角不含 `PlanRule` / `WeeklyVariation`(那是教练 progression 引擎产出);mapper 把"本 cycle 第 N 周" 的 prescribed sets 落到具体值
- prescribed weight 计算:若 plan 含 `WeeklyVariation` rule → 按当前 weekIndex 算;若无 → 取教练手填值
- prescribed reps:同上;`repsMax` 范围保留
- prescribed RPE:可空,UI 层默认 8.0
- weekIndex 推断:由调用方传入(`PlanningCoordinatorView` 在 publish 时显式传当前 Week);**不在 mapper 内 implicit 推**(V0.1.x 改 plan.weekStart 显式字段)
- intensity_mode:`.rpe` 直接落 PrescribedSet.rpe 字段;`.percentageOfOneRM` / `.absoluteWeight` 落 PrescribedSet.weightKg(per 教练 plan)

> **mapper 是 V0.1 单元测试覆盖最高优先级**。fixture ≥ 6 个(见上),CI 跑通才算实装合格。

### state machine(`TodayWorkoutViewModel`)

```swift
@Observable @MainActor
public final class TodayWorkoutViewModel {
  public enum State: Sendable, Equatable {
    case idle
    case loading
    case loaded(plan: StudentPlanDay, drafts: [SetRowDraft])
    case rest        // 当日无训练
    case error(String)
  }
  public private(set) var state: State = .idle

  public struct SetRowDraft: Equatable, Sendable {
    public var prescribed: PrescribedSet
    public var actualWeight: Double?   // V0.1 = prescribed 不允许改; 字段留位
    public var actualReps: Int?
    public var actualRPE: Double?
    public var completed: Bool
    public var loggedSetId: UUID?      // 成功 record 后回填
  }

  public func load(date: Date, studentId: UUID) async { ... }
  public func updateReps(rowIndex: Int, reps: Int?) { ... }   // 本地 draft
  public func updateRPE(rowIndex: Int, rpe: Double?) { ... }  // 本地 draft
  public func toggleComplete(rowIndex: Int) async { ... }     // recordSet + 翻 completed
}
```

错误处理走 `error(String)` + 顶部 banner;**不静默吞**。

### 版本 / 兼容

- iOS 17.0+(per ADR-005 Stage 2 Phase 1)
- 用 `@Observable` + `@MainActor`,不用 `@ObservableObject`
- 全部 `Sendable`;StrictConcurrency 启用(已在 Package.swift)
- Repository 全部 `protocol Sendable`,impl 是 `actor`(不可用 class)

## 验收清单

实装合并前必须满足:

- [ ] `StudentRootView` 不再是 `Text("Hello Student 🏋️")`,展开 4 tab
- [ ] CoreModels 6 个新增类型(StudentPlanView / Day / Exercise / PrescribedSet / StudentSetLog / CoachFeedback)全 `Codable + Hashable + Sendable + Identifiable`,单测过
- [ ] 3 个 Repository protocol 定义 + 3 个 In-Memory actor 实装,单测覆盖各方法
- [ ] `InMemoryPlanStore` 在 AppShell 内,持 `StudentPlanView` projection;CoachKit `InMemoryPlanRepository.publishPlan` 跑 `PlanToStudentProjection.project` 写入 store;StudentKit `InMemoryStudentPlanRepository.fetchCurrentPlan` 直接读 projection,**同进程内** 教练 publish → 学员 fetch 验证 ok(集成测试)。注意:**跨身份** (切 scheme = 新进程) 不在本 spec 验证范围,defer 026
- [ ] `DemoUserSeed.coachedStudent` 加,`MeetPR-DemoStudent` scheme 加,build_run_sim 跑该 scheme 直接进 StudentRootView,并看到 `StudentDemoSeed` 预置 projection(不依赖刚 publish 的)
- [ ] 4 个 tab UI 单测各自 ViewModel state machine
- [ ] `PlanToStudentProjection`(教练侧 mapper)单测 ≥6 fixture(简单单周 / WeeklyVariation 多周 / repsMax / RPE 空 / 主项+辅助混合 / **setCount > 1** / **`.rpe` intensity_mode**)
- [ ] `PlanRepository.publishPlan` 签名加 `sets: [PlanSet]` 参数,`PlanningCoordinatorView` 调用点同步改
- [ ] `grep import CoachKit Modules/StudentKit` / `grep import StudentKit Modules/CoachKit` 输出空
- [ ] CHECKLIST.md 写好 manual happy path,跑一次记结果
- [ ] DEMO_MODE 不启时 3 个 Backend* repo 占位 `fatalError("TODO: spec 026 backend wiring")`,build pass
- [ ] CI 全过(swift build / swift test / swift-format / xcodebuild build for simulator)

## 估时(给 Codex 参考)

| 块 | 估时(连续工作日) |
|---|---|
| 1. CoreModels 6 个新类型 + 单测 | 0.5d |
| 2. RepositoryContracts SPM target 起 + 3 protocol(可由 spec 029 先建,本 spec 引用)| 0.3d |
| 3. `InMemoryPlanStore`(持 projection)+ AppShell wiring | 0.4d |
| 4. CoachKit `PlanRepository.publishPlan` 签名加 `sets`,`PlanningCoordinatorView` 调用点同步 | 0.3d |
| 5. `PlanToStudentProjection` mapper(教练侧)+ ≥6 fixture 单测 | 1.2d |
| 6. 3 个 In-Memory* repo impl + 单测 | 1.3d |
| 7. 4 个 feature folder UI + ViewModel + 单测 | 3.5d |
| 8. `StudentRootView` + RootView 注入 + `DemoUserSeed.coachedStudent` + `MeetPR-DemoStudent` scheme | 1d |
| 9. CHECKLIST.md + 手动跑一遍 + 修 bug | 1d |
| **合计** | **9.5d** |

V0.1+ 阶段 ~2 周 Codex impl 时间。pre_plan 原估 8-12d,本 spec scope 收窄(D1)+ 架构改动(D2/D3)+ 0.5d microsoft tax 后取 9.5d。

## 风险 / 待 implementer 关注

1. **mapper(教练侧 PlanToStudentProjection)复杂度**:weekly progression rule + repsMax + 教练手填值 + setCount + intensity_mode 的混合规则,fixture 必须覆盖 ≥6 种(per Codex review #112 non-blocking),否则学员侧看到的数字错。
2. **AppShell 注入参数膨胀**:StudentKit 进来后,`RootView` 构造器从"无参"变"传 3 个 student repo + 既有 coach repo";考虑用一个 `RepositoryBundle` struct 收口(本 spec 内可写也可不写,推荐写,见 §4 第 4 节简化版即可)。
3. **跨身份测试物理边界(2026-05-15 D1 决议)**:本 spec in-memory store **进程级生命周期**。同 simulator 切 scheme = 新进程 = store 丢。这是 in-memory + DEMO_MODE 的设计决定,**不是 bug**;本 spec 验证范围已收窄到"学员侧 4 tab + seeded data 自洽"。真跨身份"教练 publish → 学员 fetch"闭环 defer 到 spec 026 用真 backend + 两台手机验证。
4. **`_seedFeedback` 这种 protocol leak**:protocol 暴露给 Demo 注 seed 不优雅,V0.1.x 可改成 Repository 构造时注入 seed factory。本 spec 接受。
5. **scheme 复制风险**:`MeetPR-DemoStudent` 基于 `MeetPR-Demo` 复制,xcodeproj 改动易冲突。Codex 实装时用 `xcodebuild -list` 验 scheme 列表,改动后 commit 仔细看 `.xcodeproj/xcshareddata/xcschemes/` diff。
6. **CHECKLIST.md 不在 SPEC.md**:故意分文件,impl PR 内一起写;减少 SPEC PR 改动面。
7. **RepositoryContracts SPM target 由谁先起**:spec 029 描述了 SPM target 新建;本 spec impl 顺序 — 若 029 先 impl 则本 spec 直接 import;若本 spec 先 impl,Codex 在 本 impl 内 mechanical 建 target,029 impl 时只 add 2 个剩余 protocol(`E1RMRepository`、`VideoRepository`)。两种顺序都接受。

## Implementation Notes

无(spec PR 阶段,impl PR 由 Codex 写)。

## F-015 自检(扫一遍 spec 不出现以下字眼)

- [x] "MVP" — 无
- [x] "V1.5" / "V2" — 仅作 defer 标签,非范围
- [x] "phase 2" / "later" — 仅 defer
- [x] "TODO(spec NNN)" — 占位明确指 026(候选 3)

## 上游 / 下游

**上游 spec(已合)**:
- spec 002 CoreModels identity(User / Role / StudentProfile)
- spec 004 CoreModels training plan(TrainingPlan / PlanDay / PlanExercise / PlanSet)
- spec 020 V0 demo orchestration(DEMO_MODE + DemoUserSeed 模式)
- spec 011 auth UI flow(RootView 路由 + Session)

**下游 spec(本 spec 解锁)**:
- 候选 2(真实注册流;现在 sub 'login + Keychain' 子集 SPEC 待起):本 spec 用 `DemoUserSeed.coachedStudent`,候选 2 后真账号填进 Session.cachedUser,UI 0 改
- 候选 3(backend 真接入;SPEC 待起):本 spec 留 `BackendStudentPlanRepository` placeholder `fatalError`,候选 3 实装替占位
- V0.1.x 视频上传 spec:本 spec `SetRecordRow` 末尾留视频附件位(本 spec 不画 UI;impl 时 row 不预留视觉)
- V0.1.x e1RM 曲线 spec:本 spec 的 `StudentSetLog` schema 已含 weightKg / reps,e1RM 计算可基于此
- V0.1.x 教练端 StudentDetailView + feedback editor spec:本 spec `InMemoryStudentFeedbackRepository` 已暴露 `postFeedback` 形态(未写但预留),教练侧 spec 实装该 API 替换 seed

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。Scope 基于 v0_1_pre_plan 候选 1,进一步收敛(教练端看学员执行 / 跨 cycle 历史 / 资料页 defer) | Claude |
| 2026-05-15 | 0.2 | 接 PR #112 Codex review:**D1**(scope 收窄,跨身份闭环 defer 026)+ **D2**(store 持 publish-ready projection,mapper 在教练侧)+ **D3**(3 protocol 移到新 SPM target `RepositoryContracts`,per spec 029)+ `.coachedStudent`/`.selfTrainStudent` 字段名 + mapper fixture ≥6(加 setCount>1 / `.rpe` intensity_mode 覆盖) | Claude |
