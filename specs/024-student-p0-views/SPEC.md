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

把 StudentKit 从单文件 `Text("Hello Student 🏋️")` 占位,装到 **"教练装 build A 排计划 → 学员装 build B 拉到当周 plan → 学员录每组 reps/RPE 打勾 → 教练看执行结果 → 教练写文字反馈 → 学员看到反馈红点"** 的完整闭环 UI,全程 in-memory mock 不接真 backend,可在 1 台 simulator 内通过 DEMO_MODE 切换"我是教练"/"我是学员" 两份 user seed 自测,也可在 2 台 simulator 用预 seed 数据互相验证。

**为什么这个 scope**:
- 用户 2026-05-15 dogfood scope 决策:候选 1(学员端) + 候选 2 内的"login + Keychain" 子集 + 候选 3(backend)三路并行,但本 spec 严格只做候选 1。
- 候选 2 / 候选 3 各起独立 spec,本 spec 写完后 UI + Repository protocol 已 ready,候选 3 直接换 `BackendStudentPlanRepository` 实装替 `InMemoryStudentPlanRepository`,UI 0 改。
- "教练-学员闭环"= plan publish + plan fetch + log record + feedback view 四件事,缺一不可;视频 / e1RM / 历史跨 cycle / 资料 4 级权限属于扩展能力,本 spec 全部 defer。

落地后两人小圈测试 happy path:

```
[Build A: 教练 seed (DemoUserSeed.coach)]
打开 MeetPR-Demo → CoachRootView
  ↓ 排新计划(已有 spec 005-007 实装)
publishPlan(plan, days, exercises) → InMemoryPlanRepository(教练侧)持久化
  ↓ (本 spec 加)InMemoryStudentPlanRepository 共享同一 in-memory store 拿到该 plan

[Build B: 学员 seed (DemoUserSeed.student,本 spec 新增)]
打开 MeetPR-Demo → StudentRootView (TabView, 4 tabs)
  ↓ Tab 1 "今天" — 看到今日训练动作 + prescribed sets
  ↓ 进每个动作详情 → 每组 [重量 prescribed 不可改 / reps / RPE / ✓]
  ↓ 录入 + 打勾 → InMemoryStudentTrainingLogRepository.recordSet(...)
  ↓ Tab 2 "本周" — 看本周 7 天 plan overview
  ↓ Tab 3 "历史" — 单 cycle 内按周翻 + 单日详情
  ↓ Tab 4 "反馈" — 看教练文字反馈 + 未读红点

[切回 Build A: 教练]
学员详情页 (本 spec 暂不做学员 roster 入口的执行回看; 教练端看学员执行 V0.1.x 单独 spec)
教练写反馈 (本 spec 暂用 in-memory seed 模拟)
  ↓ InMemoryStudentFeedbackRepository.postFeedback(...)
  ↓ Tab 4 学员侧红点亮,展开看到内容
```

> **2026-05-15 scope 声明**:本 spec 范围 = 学员侧 4 tab 完整闭环 UI。同期 V0.1 必做范围内并行 spec:
> - 教练端看学员执行 + 反馈 editor → spec 029(本 spec 学员反馈来源仍用 seed mock,029 落地后接 029 提供的真 postFeedback API)
> - 视频上传 → spec 027(本 spec `SetRecordRow` 不画视频附件 UI,留 affordance 给 027 加)
> - e1RM 折线 → spec 028(本 spec `StudentSetLog` schema 已含 weightKg/reps,028 直接读)
> - 真实 login + Keychain → spec 025(本 spec 用 DemoUserSeed.student,025 落地后 user 注入路径不变)
> - backend 真接入 → spec 026(本 spec In-Memory* repo 是 protocol 实装,026 落地后切 Backend* impl,UI 0 改)
>
> 跨 cycle 历史 / 按月 history / 资料 4 级权限 / 真 APNs push → V0.1.x

## 范围

### 做什么

#### 1. StudentKit 真实装 + feature folder 骨架

替 `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift` 占位实现,按 ADR-005 §3 MVVM + Repository 三层 pattern 起 4 个 feature folder:

```
Modules/StudentKit/Sources/StudentKit/
├── StudentRootView.swift                              # TabView 4 tab + Session 注入 currentUser
├── Repository/
│   ├── StudentPlanRepository.swift                   # protocol (fetch 本周 plan / fetch 日训练)
│   ├── StudentTrainingLogRepository.swift            # protocol (record set / fetch 已录入历史)
│   ├── StudentFeedbackRepository.swift               # protocol (fetch 反馈列表 / mark as read)
│   ├── InMemoryStudentPlanRepository.swift           # actor, 共享教练侧 publish 的 plan 数据
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
    └── StudentDemoSeed.swift                         # 4 周 plan + 3 条 feedback seed (DEMO_MODE 用)
```

**关键不变量** (per ADR-005 §1):
- `Modules/StudentKit/Package.swift` **不** 加 `CoachKit` 依赖 — 互不 import
- Repository 内部用 `actor`,UI ViewModel `@Observable @MainActor`
- 所有 cross-module 类型走 CoreModels(`TrainingPlan` / `PlanDay` / `PlanExercise` / `PlanSet` / `Exercise` / `User` / `StudentProfile`)

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

##### 3.1 `StudentPlanRepository`

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

`InMemoryStudentPlanRepository`:
- 与 `CoachKit.InMemoryPlanRepository` **共享同一 actor-backed store** —— 教练 publish 写,学员 fetch 读。本 spec 在 AppShell 内注入时把同一实例传给两侧。
- 因为 mapper 跨 module 不能直接 import CoachKit,store 抽象到 CoreModels 或 AppShell 持有的中间层:**实装策略选 (a)** — 在 AppShell 新建 `InMemoryPlanStore` actor 持有 raw plan 数据,CoachKit 的 `InMemoryPlanRepository` 和 StudentKit 的 `InMemoryStudentPlanRepository` 都注入这个 store;mapper(教练草稿 → 学员视图)放在 StudentKit 内,因为 mapper 只需读 CoreModels 类型。
- AppShell 的 store 文件:`Modules/AppShell/Sources/AppShell/Demo/InMemoryPlanStore.swift`(新)

##### 3.2 `StudentTrainingLogRepository`

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

##### 3.3 `StudentFeedbackRepository`

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
  public static let student: User  // role=.student, displayName="演示学员", fixed UUID
  public static let coachId: UUID  // 指向 DemoUserSeed.coach.id
  public static func makePlanView(weekIndex: Int = 1) -> StudentPlanView
  public static func makeHistoricalLogs(studentId: UUID, weekIndex: Int) -> [StudentSetLog]
  public static func makeFeedback(coachId: UUID, studentId: UUID) -> [CoachFeedback]
}
```

`Modules/AppShell/Sources/AppShell/Auth/Demo/DemoUserSeed.swift` 扩展:加 `public static let student: User` 常量(与 coach 并列)。

`Modules/AppShell/Sources/AppShell/Auth/Demo/DemoTokenStore.swift` 扩展:
- DEMO_MODE 内增加 build-time toggle 选 `coach` / `student` user seed,实装方式 = 一个 Swift compile flag `DEMO_USER_STUDENT`(默认未定义 → coach;定义 → student)
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
| `StudentKit` | 全部本 spec 内容 | `CoreModels` / `Networking` / `DesignSystem` / `SwiftUI` |
| `AppShell` | `InMemoryPlanStore` actor + `DemoUserSeed.student` + `RootView` 注入 | 既有 |
| `CoachKit` | InMemoryPlanRepository 改成接收 `InMemoryPlanStore` 注入(构造器加参数);**不引入 StudentKit 依赖** | 既有 |

**关键不变量自检**(impl PR review 时跑):
```bash
grep -rE "^import (CoachKit|StudentKit)" Modules/StudentKit/  # 应为空
grep -rE "^import StudentKit" Modules/CoachKit/               # 应为空
```

### Repository 共享 store 设计(critical)

教练 publish 与学员 fetch 必须读同一份内存数据,否则两人测试时学员根本看不到教练发的 plan。三选一:

| 策略 | 实现 | 推荐 |
|---|---|---|
| **A. AppShell 持有 `InMemoryPlanStore` actor**,双侧 repo 都注入它 | store 暴露 `addPlan / fetchPlans / fetchPlanForStudent` 等 API,CoachKit / StudentKit 各自 wrap | ✅ 推荐 |
| B. CoreModels 加 store | CoreModels 应保持纯数据,不引入 actor state | ❌ |
| C. 各 Kit 单例 + NotificationCenter 同步 | 单例不可注入测试;NC 同步弱保证 | ❌ |

**实装 A**:
- `Modules/AppShell/Sources/AppShell/Demo/InMemoryPlanStore.swift` 新建
- `actor InMemoryPlanStore` 持有:
  - `private var publishedPlans: [UUID: (TrainingPlan, [PlanDay], [PlanExercise])]`(key = `studentId`)
- API:
  - `addPlan(forStudent:plan:days:exercises:)`(教练 publishPlan 内部调)
  - `getPublishedPlan(forStudent:)`(学员 fetchCurrentPlan 内部调)
- 既有 `InMemoryPlanRepository` 改构造器:`init(students:catalog:store: InMemoryPlanStore)`,publishPlan 写 store 而非自身 var
- `InMemoryStudentPlanRepository.init(store: InMemoryPlanStore, studentId: UUID)`,fetch 走 store
- **测试**:store 单测覆盖并发 add/get;CoachKit / StudentKit 测试各自 inject mock store

### DTO mapping(教练草稿 → 学员视图)

Mapper 位置:`Modules/StudentKit/Sources/StudentKit/Repository/PlanProjection.swift`(新)

输入:`(TrainingPlan, [PlanDay], [PlanExercise])`(教练草稿)
输出:`StudentPlanView`

关键规则:
- 学员视角不含 `PlanRule` / `WeeklyVariation`(那是教练 progression 引擎产出);mapper 把"本 cycle 第 N 周" 的 prescribed sets 落到具体值
- prescribed weight 计算:若 plan 含 `WeeklyVariation` rule → 按当前 weekIndex 算;若无 → 取教练手填值
- prescribed reps:同上;`repsMax` 范围保留
- prescribed RPE:可空,UI 层默认 8.0
- weekIndex 推断:`Calendar.current.dateComponents([.weekOfMonth], from: cycle.startDate, to: Date()).weekOfMonth`(粗糙,V0.1.x 替换为 plan.weekStart 显式字段)

> 这一步的复杂性提示 Codex:**mapper 是 V0.1 单元测试覆盖最高优先级**。准备至少 5 个 fixture:简单单周 / 多周 progression / repsMax / RPE 空 / 主项+辅助混合。

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
- [ ] `InMemoryPlanStore` 在 AppShell 内,CoachKit `InMemoryPlanRepository.publishPlan` 写入 store,StudentKit `InMemoryStudentPlanRepository.fetchCurrentPlan` 读 store,**同进程内教练 publish → 学员 fetch 验证 ok**(集成测试)
- [ ] `DemoUserSeed.student` 加,`MeetPR-DemoStudent` scheme 加,build_run_sim 跑该 scheme 直接进 StudentRootView
- [ ] 4 个 tab UI 单测各自 ViewModel state machine
- [ ] mapper(TrainingPlan → StudentPlanView)单测 ≥5 fixture
- [ ] `grep import CoachKit Modules/StudentKit` / `grep import StudentKit Modules/CoachKit` 输出空
- [ ] CHECKLIST.md 写好 manual happy path,跑一次记结果
- [ ] DEMO_MODE 不启时 3 个 Backend* repo 占位 `fatalError("TODO: spec 026 backend wiring")`,build pass
- [ ] CI 全过(swift build / swift test / swift-format / xcodebuild build for simulator)

## 估时(给 Codex 参考)

| 块 | 估时(连续工作日) |
|---|---|
| 1. CoreModels 6 个新类型 + 单测 | 0.5d |
| 2. InMemoryPlanStore + CoachKit 注入改造 | 0.5d |
| 3. 3 个 Repository protocol + In-Memory actor + 单测 | 1.5d |
| 4. mapper(教练草稿 → 学员视图)+ 单测 | 1d |
| 5. 4 个 feature folder UI + ViewModel + 单测 | 3.5d |
| 6. StudentRootView + RootView 注入 + DemoUserSeed.student + MeetPR-DemoStudent scheme | 1d |
| 7. CHECKLIST.md + 手动跑一遍 + 修 bug | 1d |
| **合计** | **9d** |

V0.1+ 阶段 1.5-2 周 Codex impl 时间。pre_plan 原估 8-12d,本 spec scope-shrink 后取下界。

## 风险 / 待 implementer 关注

1. **mapper 复杂度被低估**:weekly progression rule + repsMax + 教练手填值的混合规则,fixture 必须覆盖至少 5 种,否则学员侧看到的数字错。
2. **AppShell 注入参数膨胀**:StudentKit 进来后,`RootView` 构造器从"无参"变"传 3 个 student repo + 既有 coach repo";考虑用一个 `RepositoryBundle` struct 收口(本 spec 内可写也可不写,推荐写,见 §4 第 4 节简化版即可)。
3. **两 simulator 同进程问题**:本 spec in-memory store **同一 simulator 内** 教练 publish 后切 scheme 重启 simulator 学员侧 fetch — 数据**会丢**(进程重启)。两 simulator 真互通要 backend(候选 3)。本 spec 验闭环用**同一 simulator 切 scheme**(学员侧 seed 也包含一份 mock plan,验"看到 plan + 录入"行得通,不依赖刚 publish 的)。
4. **`_seedFeedback` 这种 protocol leak**:protocol 暴露给 Demo 注 seed 不优雅,V0.1.x 可改成 Repository 构造时注入 seed factory。本 spec 接受。
5. **scheme 复制风险**:`MeetPR-DemoStudent` 基于 `MeetPR-Demo` 复制,xcodeproj 改动易冲突。Codex 实装时用 `xcodebuild -list` 验 scheme 列表,改动后 commit 仔细看 `.xcodeproj/xcshareddata/xcschemes/` diff。
6. **CHECKLIST.md 不在 SPEC.md**:故意分文件,impl PR 内一起写;减少 SPEC PR 改动面。

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
- 候选 2(真实注册流;现在 sub 'login + Keychain' 子集 SPEC 待起):本 spec 用 `DemoUserSeed.student`,候选 2 后真账号填进 Session.cachedUser,UI 0 改
- 候选 3(backend 真接入;SPEC 待起):本 spec 留 `BackendStudentPlanRepository` placeholder `fatalError`,候选 3 实装替占位
- V0.1.x 视频上传 spec:本 spec `SetRecordRow` 末尾留视频附件位(本 spec 不画 UI;impl 时 row 不预留视觉)
- V0.1.x e1RM 曲线 spec:本 spec 的 `StudentSetLog` schema 已含 weightKg / reps,e1RM 计算可基于此
- V0.1.x 教练端 StudentDetailView + feedback editor spec:本 spec `InMemoryStudentFeedbackRepository` 已暴露 `postFeedback` 形态(未写但预留),教练侧 spec 实装该 API 替换 seed

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。Scope 基于 v0_1_pre_plan 候选 1,进一步收敛(教练端看学员执行 / 跨 cycle 历史 / 资料页 defer) | Claude |
