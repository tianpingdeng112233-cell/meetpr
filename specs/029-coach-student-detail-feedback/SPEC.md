# 029 — Coach 端"看学员执行 + 写反馈" + StudentRoster + reuse 学员侧 view

- **状态**: Draft
- **PR**: TBD(iOS spec PR + iOS impl PR;backend 反馈 endpoint 已在 spec 026 §2.4 覆盖,本 spec 0 backend 工作)
- **来源**:
  - [PRD §5 教练端 P0 #1 学员管理 / #6 学员状态面板 / #7 视频反馈队列 / #8 学员详情页](~/Brain/wiki/projects/MeetPR/prd.md) — 教练侧 V1 P0 学员管理 + dashboard + 反馈
  - 上游 [spec 024 学员端 P0](../024-student-p0-views/SPEC.md) — `StudentPlanView` / `StudentPlanDay` / `StudentSetLog` / `CoachFeedback` 数据型 + `DayDetailView`(read-only)reuse
  - 上游 [spec 026 backend 真接入](../026-backend-wiring-deploy/SPEC.md) — `BackendStudentPlanRepository` / `BackendStudentTrainingLogRepository` / `BackendStudentFeedbackRepository` + 反馈 endpoint
  - 上游 [spec 027 视频上传](../027-video-upload/SPEC.md) — `VideoAttachment` + `VideoPlayerView`
  - 上游 [spec 028 e1RM 折线](../028-e1rm-curve-pr-push/SPEC.md) — `GrowthCurveView` + `E1RMRepository`
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — `CoachKit` 可读 `CoreModels` 类型(`StudentPlanView` 等),但**不可 import StudentKit** — reuse 学员侧 view 的策略本 spec 走"DesignSystem 抽 atomic + CoachKit 重写复合 view"

## 目标

教练端从"只能排计划"扩展到"能看学员、能给学员反馈",落地 V0.1 后:

**教练看到啥**:
```
登入教练账号 → CoachRootView(TabView,本 spec 改 3 tab)
  ↓
Tab 1 [ 排计划 ](spec 005-007 已实装)
Tab 2 [ 学员 ](本 spec 新增)
  ↓ list of bound students(spec 024 已有 5 demo,本 spec 真接 backend)
  ↓ tap 学员 → StudentDetailView
StudentDetailView(本 spec 新增,顶部 5 个 segment)
  ↓ [ 概览 ] 本周完成度 + 最近反馈 + 最近视频
  ↓ [ 执行 ] 本周 7 天 + 每日已录 sets read-only(reuse 学员侧 DayDetailView 逻辑,本 spec 在 CoachKit 内重写复合 view 调 CoreModels)
  ↓ [ 视频 ] 该学员所有视频 thumbnail grid + tap 播放(reuse spec 027 VideoPlayerView)
  ↓ [ 成长 ] 三大项 e1RM 曲线(reuse spec 028 GrowthCurveView)
  ↓ [ 反馈 ] 历史反馈列表 + 顶部"写反馈"按钮 → FeedbackComposerView
FeedbackComposerView(本 spec 新增)
  ↓ TextEditor + 可选关联日期 / 动作 chip + 发送
  ↓ → CoachFeedbackRepository.postFeedback(...) → backend → 学员 Tab 4 红点
Tab 3 [ 我的 ](本 spec 新增最小版,V0.1.x 扩)
  ↓ 退出登录 / app 版本 / V0.1 内测须知
```

**关键 reuse 设计**(ADR-005 §1 强约束:CoachKit ⊥ StudentKit):
- `CoachKit` 不能 `import StudentKit`,但**可以** 读 `CoreModels` 内的 `StudentPlanView` / `StudentSetLog` / `CoachFeedback` / `VideoAttachment` / `E1RMHistoryPoint`
- 因此学员侧 view(`DayDetailView` / `GrowthCurveView` / `MyVideoListView` / `VideoPlayerView`)**不能** 直接 reuse — 必须在 CoachKit 内重写复合 view,**但** 底层 atomic component(组数/重量/RPE 单元格;Charts;视频播放)走 `DesignSystem`
- 折中:本 spec 在 DesignSystem 抽 4 个 atomic 组件,CoachKit + StudentKit 各自调,view 重写
- 替代决策 B(被否)= 把 `GrowthCurveView` / `VideoPlayerView` 提到 DesignSystem。理由不选:这些 view 内嵌业务逻辑(选 exercise / 选时间轴),DesignSystem 应保持纯视觉 atomic

## 范围

### 做什么

#### 1. DesignSystem 抽 4 个 atomic component(reuse 基础)

位置:`Modules/DesignSystem/Sources/DesignSystem/Components/`

| 文件 | 用途 |
|---|---|
| `SetReadOnlyCell.swift` | 单组只读 cell `[ 序号 ][ Wt ][ reps ][ RPE ][ ✓ ]`,纯视觉 |
| `DayCompletionBar.swift` | 7 天完成度横条,某日完成度 mini visualization |
| `E1RMChart.swift` | SwiftUI Charts LineMark + PointMark,接 `[(Date, Double)]` 数据 |
| `VideoThumbnailCell.swift` | 视频缩略图 cell,thumbnail + duration + tap callback |

`SetReadOnlyCell` 与 spec 024 的 `SetRecordRow` 不同 — 后者可编辑,前者纯展示;两者的"原子样式"(段控 / 字体)走 DesignSystem 共用 `Typography` / `Color` enum。

spec 024 / 028 / 027 实装时已经在用 DesignSystem(单一来源 atomic),本 spec 在此基础上**追加** 4 个组件,不破坏 existing。

#### 2. CoachKit 新加 5 个 feature folder

位置:`Modules/CoachKit/Sources/CoachKit/Features/`

```
CoachKit/Sources/CoachKit/Features/
├── (Planning/ 已存在,spec 005-007 + 023)
├── StudentRoster/                            # Tab 2 list 入口
│   ├── StudentRosterView.swift
│   ├── StudentRosterViewModel.swift
│   └── StudentRosterRow.swift                # name + 头像 + 本周完成度 mini + 待反馈数
├── StudentDetail/                            # 单学员详情
│   ├── StudentDetailView.swift               # 顶部 segmented 5 tab(概览/执行/视频/成长/反馈)
│   ├── StudentDetailViewModel.swift
│   ├── Overview/
│   │   ├── StudentOverviewSection.swift      # 本周完成度 + 最近反馈 + 最近视频 3 块卡片
│   │   └── StudentOverviewViewModel.swift
│   ├── Execution/
│   │   ├── StudentExecutionView.swift        # 7 天竖排,每天展开看已录 sets(read-only)
│   │   └── CoachDayDetailView.swift          # 单日 read-only,replicates StudentKit DayDetailView 但 CoachKit-local
│   ├── Videos/
│   │   ├── StudentVideoGridView.swift        # 该学员视频缩略图 grid
│   │   └── StudentVideoGridViewModel.swift
│   ├── Growth/
│   │   └── StudentGrowthCurveView.swift      # 三大项 e1RM 曲线;用 DesignSystem.E1RMChart
│   └── Feedback/
│       ├── CoachFeedbackHistoryView.swift    # 历史反馈 list(教练自己写过的)
│       ├── FeedbackComposerView.swift        # 写反馈 modal
│       └── FeedbackComposerViewModel.swift
├── MyProfile/                                # Tab 3 教练端"我的"(最小版)
│   ├── CoachMyProfileView.swift              # 退出登录 + 版本 + 内测须知
│   └── CoachMyProfileViewModel.swift
└── Shared/
    ├── CoachVideoPlayerView.swift            # 内嵌 AVKit VideoPlayer + 速度控制(reuse spec 027 实装,但 CoachKit-local copy)
    └── StudentBindingService.swift           # 拉教练所有 bound students(reuse spec 005 PlanRepository.fetchStudents,本 spec 走 backend)
```

##### 2.1 `CoachRootView` 改 TabView

```swift
public struct CoachRootView: View {
  public var body: some View {
    TabView {
      PlanningCoordinatorView(...).tabItem { Label("排计划", systemImage: "calendar.badge.plus") }
      StudentRosterView(...).tabItem { Label("学员", systemImage: "person.2") }
        .badge(pendingAttentionCount)
      CoachMyProfileView(...).tabItem { Label("我的", systemImage: "person") }
    }
  }
}
```

`pendingAttentionCount` 来源 = 该教练所有 bound students 中**待教练关注**的数(粗定义:学员当周已完成训练 + 教练 N 天没反馈,V0.1 简化为"近 3 天有 set log 且无新 feedback");V0.1.x 加更精细规则。

**文案策略(2026-05-15 接 PR #117 Codex review non-blocking)**:UI 标签用 "**待关注**" 而非 "待反馈"。理由:V0.1 粗规则会误报(学员热身组打勾教练也看到"待反馈"),"待反馈"是强承诺(教练觉得"必须写反馈"心理负担重);"待关注"是轻承诺(教练看一眼即可,不强迫写)— 等 V0.1.x 加精细规则(只针对正式训练动作 + 智能去重)后再用"待反馈"。

##### 2.2 `StudentRosterView`(Tab 2)

教练看到啥:
- 顶部 title "学员"
- list of `StudentRosterRow`:
  ```
  [ 头像占位 ][ xty                  ][ 本周完成 3/4 训练 ]
              [ 上次活跃 2026-05-14 ][ 红点 N 待反馈      ]
  ```
- tap row → push `StudentDetailView(studentId:)`
- 顶部 search bar(若学员 ≥ 5;V0.1 仅 1-2 个学员可隐藏)

数据来源:`StudentBindingService.fetchStudents()` → 走 `BackendPlanRepository.fetchStudents()`(spec 026 amend 后实装,**backend 002 `/coach/students` 之前是 501 stub,backend 003 必须实装** — 见 §Backend dependencies hard prerequisites)。wire shape `CoachStudentSummary[]` 见 spec 026 §2.5。

##### 2.3 `StudentDetailView` 顶部 5 segment

```swift
struct StudentDetailView: View {
  let studentId: UUID
  @State private var selectedSection: Section = .overview

  enum Section: String, CaseIterable { case overview, execution, videos, growth, feedback }

  var body: some View {
    VStack {
      Picker("", selection: $selectedSection) {
        ForEach(Section.allCases, id: \.self) { Text($0.label).tag($0) }
      }.pickerStyle(.segmented).padding()

      switch selectedSection {
      case .overview:  StudentOverviewSection(studentId: studentId)
      case .execution: StudentExecutionView(studentId: studentId)
      case .videos:    StudentVideoGridView(studentId: studentId)
      case .growth:    StudentGrowthCurveView(studentId: studentId)
      case .feedback:  CoachFeedbackHistoryView(studentId: studentId) +
                       FloatingActionButton("✍️ 写反馈", { showComposer = true })
      }
    }
  }
}
```

##### 2.4 `StudentOverviewSection` 三块卡片

- **本周完成度卡**:`DayCompletionBar`(DesignSystem)+ "本周完成 N/M 训练日" + tap → 切到 Execution
- **最近反馈卡**:最近一条该学员收到的反馈(由教练自己写的;若无显示"暂无反馈,去 Feedback 写一条") + tap → 切到 Feedback
- **最近视频卡**:最近 3 个视频 thumbnail mini + tap → 切到 Videos

##### 2.5 `StudentExecutionView` 7 天 read-only

- 7 天竖排卡片(类似学员侧 WeekOverview,但**只读**)
- tap 任一天卡片 → push `CoachDayDetailView(date:studentId:)`
- `CoachDayDetailView` 显示该日所有动作 + 已录入组的 `SetReadOnlyCell`(DesignSystem),与学员侧 DayDetailView 视觉一致但代码在 CoachKit-local

数据:
- `BackendStudentPlanRepository.fetchCycleDays(studentId:)` → 一个 cycle 内 days
- `BackendStudentTrainingLogRepository.fetchLogs(studentId:in:)` → range 内 logs
- join 在 ViewModel 层

##### 2.6 `StudentVideoGridView`

- 3-column grid of `VideoThumbnailCell`(DesignSystem)
- tap → push `CoachVideoPlayerView`(AVKit `VideoPlayer` + 倍速 0.5/1/1.5/2)
- 数据:`BackendVideoRepository.fetchStudentVideos(studentId:)`(spec 027 backend `/students/:id/videos` 已 ready)
- 本 spec 加 iOS-side `BackendVideoRepository` protocol + 实装(spec 027 仅装学员侧自看,教练侧本 spec 加)

##### 2.7 `StudentGrowthCurveView`

直接 reuse `DesignSystem.E1RMChart`:
- 同 spec 028 学员侧 `GrowthCurveView` 视觉一致
- 数据走 `BackendE1RMRepository.fetchHistory(studentId:exerciseId:)`(本 spec 加教练侧入口,实装上仍是本地;V0.1 + V0.1.x 都本地算)

> **跨设备 caveat**:e1RM 是学员设备本地算,教练设备看不到。**本 spec 暂用 fallback**:从学员的 `StudentSetLog`(backend 已存)在教练端**重新算一次** e1RM(用 `E1RMCalculator` 同一公式,因数学纯逻辑,可在 CoachKit 内复制此 enum)。V0.1.x 上 backend e1RM endpoint 后切换。

##### 2.8 `CoachFeedbackHistoryView` + `FeedbackComposerView`

`CoachFeedbackHistoryView`:
- list of `CoachFeedback`(教练自己写过给该学员的)按 postedAt desc
- 每行 `[ 文本前 50 字 + ... ][ 关联日期 / 动作 chip(若有) ][ 相对时间 ][ 学员是否已读 ]`

`FeedbackComposerView`(modal):
```
[ TextEditor 多行,placeholder "给 xty 写反馈..." ]
[ 关联(可选): [ + 日期 ▼ ] [ + 动作 ▼ ] ]
[ 取消 ]                         [ 发送 ]
```

发送 → `BackendStudentFeedbackRepository.postFeedback(...)`(spec 026 backend `POST /coach/feedback` 已 ready)

#### 3. CoreModels 扩展(若 spec 026 未补全则本 spec 补)

`CoachFeedback`(spec 024 已建)需扩展 `studentDisplayName: String?` 缓存字段(教练侧 list 显示用,避免每次 join);或在 CoachKit-local 用 DTO 处理。

> 倾向不动 CoreModels,在 CoachKit ViewModel 层 join `CoachStudentSummary` 拿 displayName。

#### 4. iOS `BackendVideoRepository`(spec 027 加学员侧入口 + read URL contract,本 spec 仅消费,**0 backend 工作**)

位置:`Modules/RepositoryContracts/Sources/RepositoryContracts/VideoRepository.swift`(protocol;spec 027 起,本 spec 移到 RepositoryContracts per D3)+ `Modules/Networking/Sources/Networking/Repositories/BackendVideoRepository.swift`(impl;spec 027 起,本 spec 仅 reuse)

```swift
// In RepositoryContracts (per D3, 移自 spec 027 创建的初版位置)
public protocol VideoRepository: Sendable {
  /// 返回的每条 VideoAttachment 已带短期 1h presigned videoURL + thumbnailURL
  /// (per spec 027 §4.1 GET /students/:id/videos 返回 wire shape)
  func fetchStudentVideos(studentId: UUID) async throws -> [VideoAttachmentWithURLs]
}
```

**架构调整(2026-05-15 接 PR #117 Codex review #2 blocker)**:之前 0.1 spec 写本 spec 新加 `POST /upload/presign-read` endpoint — 与 PR header "本 spec 0 backend 工作" 冲突。**移除** 该 endpoint;read URL contract **完全归属 spec 027 backend 004 spec**(spec 027 修订版 0.2 已加 `GET /students/:id/videos` 返回每条 video 短期 1h presigned `videoURL` / `thumbnailURL`)。本 spec 仅消费 spec 027 提供的 `VideoRepository`,**不**碰 backend OSS 签名逻辑。

#### 5. `CoachKit` 注入 + `MeetPRApp` 入口扩

`CoachRootView` 构造器接收 6 个 repo:
```swift
public init(
  plans: PlanRepository,                     // spec 005-007 已有
  studentPlans: StudentPlanRepository,       // spec 024 + 026
  studentLogs: StudentTrainingLogRepository, // spec 024 + 026
  feedback: StudentFeedbackRepository,       // spec 024 + 026,此 spec 用 postFeedback 写
  videos: VideoRepository,                   // spec 027 + 本 spec
  e1rm: E1RMRepository                       // spec 028
)
```

注意:**这些 repo 都是 protocol**,CoachKit 不 import StudentKit;`StudentPlanRepository` 等 protocol 定义在新建的 SPM target **`Modules/RepositoryContracts/`** 内(D3 决议 b — 见 §技术要求)。

> **架构 decision(2026-05-15 接 PR #117 Codex review #1 blocker D3 b)** — protocol 定义位置:`StudentPlanRepository` / `StudentTrainingLogRepository` / `StudentFeedbackRepository` / `E1RMRepository` / `VideoRepository` 5 个 protocol 移到**新建 SPM target `Modules/RepositoryContracts/`**。CoreModels 保持纯数据。
>
> **影响**:
> - 新 SPM target `RepositoryContracts`(成为第 7 个 module),仅放 5 个 `protocol`,**不允许** import SwiftUI / Combine / IO / Foundation 之外的东西;依赖 `CoreModels` only
> - StudentKit / CoachKit / Networking / AppShell 各自加 `RepositoryContracts` SPM dep
> - 实装(`InMemory*` / `Backend*` / `Local*`)仍在各自 module
> - **ADR-005 §1 update**:本 spec 触发 ADR docs PR(`~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md`)— "6 个 SPM target" 改 "7 个" + 加 RepositoryContracts target 描述 + "Repository protocol 走 RepositoryContracts,CoreModels 保持纯数据 invariant 不被破坏"
> - 本 spec impl 时需 mechanical refactor spec 024 / 027 / 028 已合代码 — Codex 第一个 commit 做 refactor + CI 验过,再加 feature commit
>
> **替代方案 A**(原 0.1 spec 主方案,被否)= protocol 移到 `CoreModels/Repository/` 子文件夹。
> 理由不选(2026-05-15 接 Codex 论证):CoreModels 容易从 data model 沦为"跨模块杂物间";"6 个 SPM target" → "7 个" 的 build time tax 实测 +5-10s 可接受;ADR-005 §1 "CoreModels 仅纯数据"的 invariant 应保留作为长期不变量,而非微调。

#### 6. 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/CoachKit/Tests/CoachKitTests/Features/StudentRosterViewModelTests.swift`(新) | 加载学员 / unread count 计算 / 错误态 |
| 同 `StudentDetailViewModelTests.swift`(新) | 5 section 切换 / 数据 join |
| 同 `Features/StudentDetail/Overview/StudentOverviewViewModelTests.swift`(新) | 三块卡片数据组装 |
| 同 `Features/StudentDetail/Feedback/FeedbackComposerViewModelTests.swift`(新) | 文本空校验 / 发送成功 / 失败 banner / 关联 chip 状态 |
| `Modules/Networking/Tests/NetworkingTests/Repositories/BackendVideoRepositoryTests.swift`(新) | fetch + presigned URL |
| `Modules/CoreModels/Tests/CoreModelsTests/Repository/RepositoryProtocolTests.swift`(新) | protocol 编译 + 抽象方法签名稳定 |

#### 7. CHECKLIST.md

```
[ ] 教练端 build_run_sim 进 CoachRootView 看到 3 tab
[ ] Tab 学员 → list 显示 backend seed 的 1 个学员(xty)
[ ] 点 xty → 进 StudentDetailView,5 segment 都可点
[ ] 概览 段三块卡片有数据(本周完成 / 最近反馈空 / 最近视频空)
[ ] 执行 段看到 7 天 + 学员已录 sets read-only
[ ] 视频 段:学员上传后 thumb 出现 + tap 播放 + 倍速控制
[ ] 成长 段:学员录入 5+ 组深蹲后看到折线
[ ] 反馈 段:写一条反馈 → 学员端 Tab 4 红点亮 + 收到
[ ] 教练 Tab 1 unread badge 在学员训练后亮(N 天无反馈触发)
[ ] CI 全过
```

### 不做什么

**V0.1.x defer**:
- 邀请码 invite student(本 spec 走 backend seed,扩第三人前补完整邀请流 — gated by spec 025 完整版候选 2)
- 解绑学员(任一方单方触发;V0.1.x 真注册后才需要)
- 接收队列 / 评估期工作流(per PRD §5 #2 / #3,evaluation-workflow 整套 V0.2+)
- 视频反馈(在视频时间点写反馈)— evaluation-workflow 阶段
- 复制上周计划(per PRD §5 #4)
- 跨学员模板库 / 批量下发(V1.5+)
- 教练改 Type A 锁定字段 cascade 模态(v0.6 PRD,evaluation-workflow gated)
- 视频反馈队列(按时间 / 学员 / 紧急度,per #7)— V0.2+ 教练 dashboard

**V0.2+ defer**:
- 跨学员 dashboard / macro analytics(网页端,per PD-007)
- 教练 GTM funnel / 邀请新学员推送(per PD-006)
- 学员历史"按月" / 跨 cycle 列表(V0.1.x 单独 spec)

## 技术要求

### Protocol 重排(spec 024 / 027 / 028 影响)

本 spec impl PR 第一个 commit = mechanical refactor(D3 决议 b,2026-05-15):

1. 新建 SPM target `Modules/RepositoryContracts/`:
   ```
   Modules/RepositoryContracts/
   ├── Package.swift                # platforms iOS 17 / macOS 14;deps: CoreModels;StrictConcurrency on
   ├── Sources/RepositoryContracts/
   │   ├── StudentPlanRepository.swift          # protocol
   │   ├── StudentTrainingLogRepository.swift   # protocol
   │   ├── StudentFeedbackRepository.swift      # protocol
   │   ├── E1RMRepository.swift                 # protocol
   │   └── VideoRepository.swift                # protocol
   └── Tests/RepositoryContractsTests/
       └── ProtocolCompileTests.swift           # 仅验 protocol 编译 + 签名稳定
   ```

2. 移动 5 个 protocol from 当前位置 → RepositoryContracts(不动实装):
   - `StudentPlanRepository.swift` ← from StudentKit/Repository/
   - `StudentTrainingLogRepository.swift` ← from StudentKit/Repository/
   - `StudentFeedbackRepository.swift` ← from StudentKit/Repository/
   - `E1RMRepository.swift` ← from StudentKit/Repository/
   - `VideoRepository.swift` ← from Networking/Repositories/(spec 027 学员侧)

3. 更新 import statements:
   - `Modules/StudentKit/Package.swift` 加 `RepositoryContracts` dep + `InMemory*` 文件加 `import RepositoryContracts`
   - `Modules/Networking/Package.swift` 加 dep(若 `BackendVideoRepository` 装在 Networking)
   - `Modules/CoachKit/Package.swift` 加 dep + import(用 StudentPlanRepository / E1RMRepository / VideoRepository)
   - `Modules/AppShell/Package.swift` 加 dep + import(注入路径)
   - `Modules/CoreModels/Package.swift` **不**加 — RepositoryContracts 依赖 CoreModels,反向依赖会循环

4. **ADR-005 §1 docs PR**(`~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md` 更新):
   - "6 个 SPM target" → "7 个"
   - 加 `RepositoryContracts` target 描述:"跨 role Repository protocol(无实装,无状态);依赖 CoreModels;**禁止** import SwiftUI / Combine / IO 框架"
   - CoreModels 描述加一句:"保持纯数据型不变 — Repository protocol 走 RepositoryContracts target,不在此"
   - **本 docs PR 必须在 029 impl PR 之前合**(prerequisite)

5. RepositoryContracts target 加 CI 健康检查:
   - `grep -rE "^import (SwiftUI|Combine|Foundation\\.)" Modules/RepositoryContracts/Sources/` → 必须空(除 `Foundation` 自身)
   - protocol 全部 `Sendable`

### `CoachKit` 内 `E1RMCalculator` 复制 + golden fixture(2026-05-15 接 PR #117 Codex review non-blocking 加强)

本 spec 在 `CoachKit/Sources/CoachKit/Domain/E1RMCalculator.swift` 复制 spec 028 `Modules/StudentKit/Sources/StudentKit/Domain/E1RMCalculator.swift`(含 `rtsTable` 12×9 lookup + RPE 线性插值 + Epley fallback,与 StudentKit 1:1 一致)。

**两端输出一致性的 CI guardrail**:
1. 建 **共享 golden fixture** 文件:`Modules/CoreModels/Tests/CoreModelsTests/Fixtures/e1rm_golden.json`(纯数据,无 Swift 代码)
   - 至少 30 个 input/output triplet:`{weightKg, reps, rpe?, expectedE1RMKg}`(覆盖 RTS 表关键 cells + Epley fallback + 边界)
2. **CoachKit 单测** 跑 `CoachKit.E1RMCalculator.calculate(...)` 对 golden fixture,assert 浮点差 ≤ 0.001 kg
3. **StudentKit 单测** 跑 `StudentKit.E1RMCalculator.calculate(...)` 同 golden fixture,assert 一致
4. CI 同时跑两 module 测试,任一不一致 → fail build

**FOLLOWUPS.md F-030**:V0.1.x 视情况 extract `E1RMCalculator` 到 shared domain SPM target(触发 = Stage 3 EvaluationDomain extract 同期,或两端数学逻辑漂移导致单测维护成本上升)。

**替代方案 B**(被否):放 CoreModels — 纯逻辑函数 + RTS 数据表与 CoreModels"纯数据型"语义弱不合,且违反 D3 决议(CoreModels 保持纯数据)。

**替代方案 C**(被否):立即建 `E1RMDomain` SPM target — 仅 1 个 calculator 函数,target 颗粒过细;FOLLOWUPS 触发条件成熟再 extract。

### CoachKit ⊥ StudentKit 强约束自检(2026-05-15 接 PR #117 Codex review non-blocking 加强)

CI 检查 **两层**:

1. **Import-level grep**(已有):
   ```bash
   grep -rE "^import StudentKit" Modules/CoachKit/   # 必须空
   grep -rE "^import CoachKit" Modules/StudentKit/   # 必须空
   ```

2. **Package.swift dependency 图检查**(新加,per Codex review non-blocking):
   ```bash
   # 解析 Modules/CoachKit/Package.swift 的 dependencies,验证不含 StudentKit
   # 反之亦然
   # 用 swift-syntax 解析或简单 grep:
   grep -F "\"StudentKit\"" Modules/CoachKit/Package.swift   # 必须空
   grep -F "\"CoachKit\"" Modules/StudentKit/Package.swift   # 必须空
   ```

   理由:仅 grep import 不够 — target 依赖可能已加但暂时没 import,后续 Codex 调用一行就破坏不变量。Package.swift 是 declarative source of truth。

两层 CI step 加在 GitHub Actions workflow,任一失败 → fail build。

### Backend dependencies — hard prerequisites(2026-05-15 接 PR #117 Codex review #3 blocker)

本 spec **不引入新 backend endpoint**(0 backend 工作)。**前置条件**(spec 026 / 027 必须先合):

| Endpoint | 谁实装 | 现状 | 本 spec 用于 |
|---|---|---|---|
| `GET /coach/students` | **spec 026 / backend 003-student-actions(blocker — backend 002 仍是 501 stub)** | ⚠️ stub,待 spec 026 amend 后(per #114 review)+ backend 003 实装 | StudentRoster Tab 第一屏 |
| `GET /students/:id/plans?status=published` | backend 002 已合 | ✅ | StudentDetail Execution |
| `GET /students/:id/sets` | spec 026 / backend 003 | ⚠️ 待 spec 026 amend 实装 | StudentDetail Execution(学员录入回看) |
| `GET /students/:id/feedback` | spec 026 / backend 003 | ⚠️ 待 spec 026 amend 实装 | StudentDetail Feedback history + Tab 2 unread badge |
| `POST /coach/feedback` | spec 026 / backend 003 | ⚠️ 待 spec 026 amend 实装 | FeedbackComposer 发送 |
| `GET /students/:id/videos` (含 short-lived presigned URLs) | spec 027 / backend 004 | ⚠️ 待 spec 027 amend(per #115 review)+ backend 004 实装 | StudentDetail Videos thumbnail + player |

**本 spec impl 启动条件**:spec 026 + spec 027 上述 endpoint 全部 land 在 staging。**否则** 本 spec impl PR review 第一屏空、无视频、写反馈失败,无法验收。**Codex 实装时第一步验证 backend staging 全部 endpoint 返 200**,否则 abort 等。

**本 spec backend 工作量 = 0**(严格定义:不写 backend 代码 / 不动 backend schema / 不动 backend route)。

### 版本 / 兼容

- iOS 17.0+
- AVKit / SwiftUI Charts / PHPickerViewController 已在 spec 024-028 启用

## 验收清单

- [ ] **ADR-005 §1 docs PR 先合**(prerequisite)— "6 SPM target → 7 个" + RepositoryContracts target 描述
- [ ] Protocol mechanical refactor 完成(新建 RepositoryContracts target,5 个 protocol 移入)
- [ ] CoachKit ⊥ StudentKit 自检过 — **两层 CI step**:`grep import` + `grep Package.swift dependencies`
- [ ] Backend hard prerequisites 全 land 在 staging:`GET /coach/students` / `GET /students/:id/sets` / `GET /students/:id/feedback` / `POST /coach/feedback` / `GET /students/:id/videos`(curl 验过返 200)
- [ ] CoachRootView 3 tab,旧 PlanningCoordinatorView 仍可用(spec 005-007 不破坏)
- [ ] DesignSystem 4 atomic component 加入 + 单测
- [ ] StudentRoster list + 数据接 backend(空 list 显示 "暂无学员,等邀请码 V0.1.x")
- [ ] StudentDetail 5 segment 各自渲染数据
- [ ] FeedbackComposer 发送成功 + 学员侧红点真亮(联调 2 iPhone)
- [ ] Coach 端看视频 thumbnail + 播放 + 倍速(VideoAttachment 携带 1h presigned `videoURL` from spec 027 backend)
- [ ] Coach 端 e1RM 曲线渲染(数据从 StudentSetLog 用 CoachKit-local `E1RMCalculator` 反推,与 StudentKit golden fixture 比对 0 差异)
- [ ] FOLLOWUPS.md 加 F-030 extract `E1RMCalculator` to shared domain target
- [ ] CHECKLIST 手动跑 + 联调 1 教练 + 1 学员
- [ ] CI 全过

## 估时(给 Codex 参考)

| 块 | 估时 |
|---|---|
| 1. Protocol mechanical refactor + ADR-005 微调 docs PR | 0.5d |
| 2. DesignSystem 4 atomic component + 单测 | 0.8d |
| 3. `CoachRootView` 3 tab + 路由 | 0.3d |
| 4. `StudentRoster` + ViewModel + UI | 0.8d |
| 5. `StudentDetailView` segmented + 5 子 view 骨架 | 0.5d |
| 6. `StudentOverviewSection` 三块卡片 | 0.8d |
| 7. `StudentExecutionView` + `CoachDayDetailView` 复合 view | 1.2d |
| 8. `StudentVideoGridView` + `CoachVideoPlayerView` | 0.7d |
| 9. `StudentGrowthCurveView` + e1RM 反推 + 单测 | 0.8d |
| 10. `CoachFeedbackHistoryView` + `FeedbackComposerView` + 关联 chip | 1.2d |
| 11. `CoachMyProfileView` 最小版(退出登录 + 版本)| 0.3d |
| 12. `unread badge` 计算 + 单测 | 0.4d |
| 13. CHECKLIST + 2-iPhone 联调 + bug 修 | 1d |
| **合计** | **≈ 9d** |

## 风险 / 待 implementer 关注

1. **Protocol refactor 影响面大**:5 个 protocol 移到新 SPM target `RepositoryContracts`,会触发 spec 024 / 027 / 028 已合并代码的 import statement 改 + Package.swift dep 加 — Codex 实装时**第一个 commit 仅做 refactor**,跑 CI 验证 0 业务影响后再加 feature commit;混着改容易引入隐 bug
2. **e1RM 反推在教练端**:教练端从 StudentSetLog 反推 e1RM,与学员端本地算结果**必须一致**(同 `rtsTable` + 同 lookup/interpolation 逻辑 + 同输入 → 同输出)。Golden fixture(`Modules/CoreModels/Tests/CoreModelsTests/Fixtures/e1rm_golden.json`)由两 module 测试共同消费,CI 比对 0 差异。两端复制 calculator 的同步成本由 FOLLOWUPS F-030 跟踪
3. **CoachKit ⊥ StudentKit 自检 CI 两层**:`grep import` + `grep Package.swift dependencies`(per Codex review non-blocking);违反任一 → fail build
4. **教练 "待关注" badge 规则简化**:V0.1 "近 3 天有 set log 且无新 feedback"粗规则会误报(学员热身组打勾也算);"待关注" 文案弱承诺,接受 V0.1 误报;V0.1.x 加"教练已看过该日 execution / 排除热身组" 语义后再改"待反馈"
5. **5 段切换数据 fetch 抖动**:每段切换重 fetch 会闪烁;ViewModel 层加 cache + `viewModel.refresh()` 显式触发,自动 fetch 仅 onAppear 一次 + pull-to-refresh
6. **教练端 V0.1.x 仍要补的功能**:看 §不做什么 V0.1.x defer 一长串 — 邀请码 / 解绑 / evaluation-workflow / 复制上周计划 / cascade 模态 — 都是 V1 公测前的必经,本 spec 仅装 **"教练端 dashboard + feedback editor 闭环"**,**不应** 被描述为"V0.1 教练端完整闭环"(per PR #117 review non-blocking — 措辞防 scope 被读成 V1 P0 已完)。后续 spec 还有 5-8 个 V0.1.x / V0.2 / V1 公测前 dependency
7. **跨 repo prerequisite 链**(per PR #117 review #3 blocker):本 spec 启动**严格依赖**:
   - spec 026 amend(per #114 review)+ backend 003 实装(`/coach/students` + set_logs + feedback 三套 endpoint + 3 张 missing tables)
   - spec 027 amend(per #115 review)+ backend 004 实装(`GET /students/:id/videos` 带短期 presigned URLs)
   - ADR-005 §1 docs PR 已合
   缺任何一环本 spec impl 都跑不通,Codex 实装前必须 verify(`curl backend /endpoint` 返 200)

## Implementation Notes

无(spec PR 阶段)。

## 上游 / 下游

**上游**:
- spec 024(学员端 schema + 3 个 protocol — refactor 后移到 RepositoryContracts)
- spec 026 amend(backend endpoint:`/coach/students` 实装 + students / sets / feedback / 3 张 missing tables migration + seed)
- spec 027 amend(video schema + reader + `GET /students/:id/videos` 带短期 presigned URLs)
- spec 028(e1RM rtsTable lookup + GrowthCurve atomic)
- **ADR-005 §1 docs PR**(本 spec 触发):"6 → 7 SPM target",加 RepositoryContracts target 描述

**下游**:
- V0.1.x 教练端"接收队列 / 评估期 / 邀请码 / 解绑"(per PRD §5 教练端 #2 / #3 / #1)— 独立 spec
- V0.1.x 视频反馈(标注 + 时间点反馈)— evaluation-workflow 阶段
- V0.1.x 复制上周计划(per PRD §5 #4)
- V0.2+ 教练 macro 网页端 dashboard(per PD-007)

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。CoachKit ⊥ StudentKit 通过把 protocol 提到 CoreModels 实现 reuse;e1RM 反推 + atomic 组件下沉 DesignSystem | Claude |
| 2026-05-15 | 0.2 | 接 PR #117 Codex review:**blocker 1**(D3 b 决议)— 改方案 B,protocol 移到**新建 `Modules/RepositoryContracts/` SPM target**(原 0.1 方案 A protocol → CoreModels 被否,CoreModels 保持纯数据 invariant 不破),ADR-005 §1 docs PR 升级"6 → 7 SPM target" + 加 contract target 限制(禁 SwiftUI/Combine/IO);**blocker 2** — "0 backend"× read-presign 冲突,read URL contract 完全归 spec 027 amend 后的 backend 004,本 spec 仅消费 `VideoRepository` 不引入 backend endpoint;**blocker 3** — `GET /coach/students` 前置写成 hard prerequisite,Backend dependencies 表显式列 5 个 endpoint + curl 验过返 200 才能启动 impl;non-blocking — e1RM golden fixture(`CoreModels/Tests/Fixtures/e1rm_golden.json`)由两 module 测试共消费 CI 比对;CoachKit ⊥ StudentKit 自检加 Package.swift dep 图检查(第二层);"待反馈" → "**待关注**"防误报承诺过强;措辞 "教练端 dashboard + feedback editor 闭环",不称 V0.1 完整 coach 闭环 | Claude |
