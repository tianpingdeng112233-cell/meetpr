# 042 — Coach 端「训练视频」收件箱(跨学员待反馈视频队列)

- **状态**: Draft
- **PR**: TBD(iOS spec PR + iOS impl PR;0 backend 工作 — 复用既有 per-student endpoint 客户端聚合)
- **来源**:
  - [PRD §5 教练端 P0 #7 视频反馈队列](~/Brain/wiki/projects/MeetPR/prd.md) — 教练侧 P0 能力
  - 上游 [spec 029 §「不做 / V0.2+ defer」](../029-coach-student-detail-feedback/SPEC.md) — 本 spec 把 029 里**明确推迟到 V0.2+** 的「视频反馈队列(按时间 / 学员 / 紧急度)」提前实装;029 已建好的 per-student 底座(`StudentVideo` / `CoachStudentVideoRepository` / `CoachVideoPlayerView` / `StudentFeedbackRepository` / `FeedbackComposerView`)本 spec 直接复用
  - 上游 [spec 027 视频上传](../027-video-upload/SPEC.md) — 学员打卡录制 → `VideoAttachment` 上传管线
  - 上游 [spec 033 接收 tab](../033-evaluation-funnel/SPEC.md) — 「接收」tab 双段容器(新学员 + 训练视频),本 spec 把 `训练视频` 段从诚实空状态升级为 live 队列;`BindQueueViewModel` / `CoachReceivingView.studentsSegment` 是本 spec 的同构样板
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — `CoachKit` 可读 `CoreModels` + `RepositoryContracts`,不 import `StudentKit`;新 repo 协议落在 `RepositoryContracts`

## 目标

把「接收」tab 的 `训练视频` 段从空状态升级为**真实跨学员待反馈队列**。

**教练看到啥**:

```
教练账号 → 接收 tab → [ 训练视频 N ] 段
  ↓ 所有绑定学员里「上传了视频但教练还没回」的视频,聚成一条列表(新→旧)
  ↓ 每行: 学员名 + 关联动作(若有) + 上传时间 + 文件大小
  ↓ tap 某行 → 视频反馈详情 sheet
视频反馈详情 sheet(本 spec 新增)
  ↓ 顶部「▶ 播放视频」→ 全屏 CoachVideoPlayerView(复用 029,0.5/1/1.5/2 倍速)
  ↓ 下方文本反馈编辑器(TextEditor + 发送)
  ↓ 发送 → 该视频出队、`训练视频` 计数 -1、接收 tab 红点 -1
段空时回到诚实空状态(现状文案保持)
```

**「待反馈」措辞(对比 spec 029「待关注」)**:029 名册行用「待关注」,因为「近 3 天有 set log 且无反馈」的粗规则会被热身组误报,「待反馈」是强承诺。**本队列不同**:进队的是**学员主动打卡上传的视频**——这是学员明确想要教练看的强信号,不存在误报,所以这里用「待反馈」是诚实的。

## 关键复用设计(ADR-005 §1:CoachKit ⊥ StudentKit)

本 spec **不新建** 视频/播放/文本反馈底层,只新建「跨学员队列」这一层:

| 复用 | 来源 | 用途 |
|---|---|---|
| `StudentVideo` 实体 | CoreModels(029) | 视频 metadata |
| `CoachVideoPlayerView` | CoachKit(029) | 全屏播放 + 倍速 + 过期重试 |
| `CoachStudentVideoRepository` | RepositoryContracts(029) | per-student `fetchVideos` / `playbackURL` |
| `StudentFeedbackRepository.postFeedback` | RepositoryContracts(024/029) | 写文本反馈(已有 backend endpoint) |
| `CoachReceivingView.studentsSegment` + `BindQueueViewModel` | CoachKit(033) | 同构样板(live 段 / loadIfNeeded / 出队 / tab 计数) |

## 范围

### 做什么

#### 1. 新增队列 repo 协议 + 模型(RepositoryContracts)

`Modules/RepositoryContracts/Sources/RepositoryContracts/CoachVideoQueueRepository.swift`:

```swift
/// 一条待反馈视频(跨学员队列的行模型)。桥接 StudentVideo metadata + 学员身份。
public struct PendingVideoItem: Hashable, Identifiable, Sendable {
  public let id: UUID                 // = StudentVideo.id(同时是播放 URL 兑换 key)
  public let studentID: UUID
  public let studentDisplayName: String
  public let planExerciseID: UUID?    // 反馈 scoping(可空)
  public let exerciseName: String?    // 行内展示(可空)
  public let dayDate: Date?           // 反馈 scoping(可空)
  public let uploadedAt: Date         // = StudentVideo.displayDate
  public let sizeBytes: Int64
}

public protocol CoachVideoQueueRepository: Sendable {
  /// 所有绑定学员里「无教练反馈」的视频,新→旧。
  func fetchPendingVideos() async throws -> [PendingVideoItem]
  /// 单条视频的短时效预签名播放 URL(= per-student playbackURL)。
  func playbackURL(videoID: UUID) async throws -> URL
  /// 对该视频的学员发文本反馈(scope 到其 day/exercise),返回已存反馈;
  /// 该视频随后从 fetchPendingVideos 出队。
  func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback
}
```

#### 2. 两套实现(CoachKit)

`Modules/CoachKit/Sources/CoachKit/Features/Receiving/`:

- **`InMemoryCoachVideoQueueRepository.swift`**(actor)— demo / 测试 / 默认空 fallback。`init(seed: [PendingVideoItem] = [], playbackURLs: [UUID: URL] = [:])`。`sendFeedback` 从 pending 移除该条 + 合成返回 `CoachFeedback`。
- **`AggregatingCoachVideoQueueRepository.swift`**(struct)— **live,零新增 backend endpoint**,与 spec 029 §189「e1RM 客户端算、不加 macro endpoint」同套路。deps = `roster: any PlanRepository` + `videos: any CoachStudentVideoRepository` + `feedback: any StudentFeedbackRepository` + `plans: any StudentPlanRepository`。
  - `fetchPendingVideos`: 遍历 `roster.fetchStudents()` → 每个学员 `videos.fetchVideos` + `feedback.fetchInbox` + `plans.fetchCurrentPlan` → **pending = 已关联计划动作(`planExerciseID != nil`)且该 `planExerciseID` 在该学员反馈里找不到匹配的视频**;**未关联上传(`planExerciseID == nil`)排除**(无 plan slot 可追踪反馈是否已回,收录会导致教练回完仍永不出队);`studentDisplayName` 取自 roster;**`exerciseName` 经 `[planExerciseID: exercise.name]` 从计划解析(D2)** —— 即教练撰写计划里该 slot 的主项/变式名,解析不到则留空(行只显示时间+大小)。
  - `playbackURL` → `videos.playbackURL`;`sendFeedback` → `feedback.postFeedback(studentID:dayDate:planExerciseID:text:)`,下次 fetch 自动重算出队。

> **判定「已反馈」的口径(V0.2 粗规则)**:视频按 `planExerciseID` 匹配反馈。同一动作/同一天有两条视频时无法逐条区分(`StudentFeedbackRepository` 无 videoID 维度)——这是 V0.2 可接受的有损;精确 videoID 级 provenance 留 V0.2.x(需后端 feedback payload 加 `video_id`,本 spec **不**碰冻结的 backend schema)。demo(InMemory)走 videoID 精确出队,无此有损。

#### 3. 队列 ViewModel(CoachKit)

`Modules/CoachKit/Sources/CoachKit/Features/Receiving/CoachVideoQueueViewModel.swift`(`@Observable @MainActor`),镜像 `BindQueueViewModel`:
- `state` / `items: [PendingVideoItem]` / `pendingCount { items.count }`
- `loadIfNeeded()` / `refresh()` → `repository.fetchPendingVideos()`
- `playbackURL(videoID:)` 透传(给 player 的 refresh 闭包)
- `sendFeedback(for:text:) async -> Bool` → 成功后从 `items` 移除该条 + toast

#### 4. UI:两层 ——「训练视频」段(一人一条)→ 学员详情(按天分组)→ 视频反馈

> **D1(决策,2026-06-23)**:一个训练日可能同时有深蹲 + 卧推 + 硬拉好几段视频,所以收件箱**按学员聚合(一人一条)**,点进去再**按天分组、每天列各动作/组的视频**。理由:扁平「一视频一条」让同一人占多条、且无法体现"一天多组"的结构。

> **D2(决策,2026-06-23)**:视频的动作名**对齐教练撰写计划里的主项/变式** —— live 经 `planExerciseID` 从 `plans.fetchCurrentPlan` 解析出该 slot 的 `exercise.name`(非自由字符串);demo 用真实主项(比赛式深蹲/卧推/传统硬拉)+ 变式(暂停深蹲/窄握卧推),每个多段学员的一天配「主项 + 变式」。

- **`CoachReceivingView`**(改):新增 `videoQueueViewModel: CoachVideoQueueViewModel? = nil` 形参(与 `queueViewModel` 同模式,默认 nil 保持旧调用方/测试可编);`videosSegment` 渲染 `viewModel.studentGroups` —— **每个学员一条**(名字 + 「N 段待反馈」+ 最近上传相对时间),空则回退现状空状态;`videoCount` 仍由 VM 的 `pendingCount`(视频总数)派生。点一行 → `navigationDestination` push `StudentPendingVideosView`。
- **`StudentPendingVideosView.swift`**(新增,push):读 `viewModel.items(for: studentID)` → `CoachVideoQueueViewModel.daySections` 按训练日分组(新→旧),每天列出该日各动作的视频行(动作名 + 时间 + 大小)。点某段 → `VideoFeedbackDetailView` sheet。某段反馈发完即出队;该学员清空 → 自动 pop 回收件箱。
- **`VideoFeedbackDetailView.swift`**(新增,sheet):顶部学员名 + 该视频元信息 + 「▶ 播放视频」(走 `fullScreenCover` + `CoachVideoPlayerView`,播放 URL 经 VM 兑换);下方文本编辑器(TextEditor + 发送,视觉对齐 `FeedbackComposerView`,但**无** day/exercise picker — scope 由视频隐含)。发送 → `videoQueueViewModel.sendFeedback` → dismiss。
- **VM 派生**(`CoachVideoQueueViewModel`):`studentGroups`(按 studentID 聚合,最近上传排序)、`items(for:)`、`static daySections(_:)`(按 `dayDate ?? uploadedAt` 的当日分组)。`pendingCount` 仍是视频总数(tab 计数/红点用)。

#### 5. 接线(CoachRootView + RootView + MeetPRApp)

- **`CoachRootView`**:新增 `videoQueue: (any CoachVideoQueueRepository)? = nil` 形参;`resolvedVideoQueue = videoQueue ?? AggregatingCoachVideoQueueRepository(roster: repository, videos: studentVideos, feedback: feedback)`(live 默认即聚合,无需 MeetPRApp 改 live 块);建 `CoachVideoQueueViewModel`,传入 `CoachReceivingView`;接收 tab `.badge` 改为 `queueViewModel.pendingCount + videoQueueViewModel.pendingCount`(红点 = 收件箱待处理总数)。
- **`RootView`**:新增 `coachVideoQueue: (any CoachVideoQueueRepository)? = nil` 形参,透传给 `CoachRootView`。
- **`MeetPRApp`(DEMO_MODE 块)**:注入 `InMemoryCoachVideoQueueRepository(seed: CoachDemoSeed.pendingVideos())`,使 demo 开机即进「有几条待反馈视频」态(per David 2026-06-23 决策:单一 demo 态,不做运行时开关)。

#### 6. demo 注入(CoachDemoSeed)

`CoachDemoSeed.pendingVideos()` 返回 **6 段** `PendingVideoItem`,挂在**名册真实 ID**上(避开 029 探明的「名册 ID ≠ 学员 demo 数据 ID」坑),动作名为主项/变式(D2):
- 王晨曦 `previewStudentID(4)` × 3 —— 同一天 **比赛式深蹲(主项) + 暂停深蹲(变式) + 比赛式卧推(主项)**(演示「按天分组、一天多组、主项+变式」)
- 李嘉宁 `previewStudentID(8)` × 2 —— **比赛式卧推(主项) + 窄握卧推(变式)**(今天)
- 张以恒 `previewStudentID(2)` × 1 —— **比赛式传统硬拉(主项)**(昨天)

→ 收件箱 **3 行**(王晨曦「3 段待反馈」/ 李嘉宁「2 段」/ 张以恒「1 段」);`训练视频` tab 计数 = 6;接收红点 = 新学员(1)+ 视频(6)= 7。视频 `id` 用 demo 命名空间新字节(不撞现有 fixture)。**playbackURL 不 seed** —— 与 029 既有单学员视频墙 demo 一致(metadata-only,点播放走优雅失败态);列表/计数/写反馈全程可演示,播放为既有约定降级。

### 不做(本 spec)

- ❌ **按学员/紧急度筛选、排序切换**:V0.2 只做单一「新→旧」队列(PRD #7 的 filter 维度 V0.2.x)
- ❌ **videoID 级反馈 provenance**:不碰冻结 backend schema;粗 `planExerciseID` 匹配 + demo 精确出队
- ❌ **未关联计划的上传(`planExerciseID == nil`)进 live 队列**:无 plan slot 可追踪反馈是否已回 → 排除(否则永不出队);V0.2.x 若需收录,得靠 videoID 级 provenance(同上,需后端解冻)
- ❌ **视频时间点打点反馈**:evaluation-workflow 阶段(029 已 defer)
- ❌ **后端新 endpoint**:live 走 per-student 既有 endpoint 客户端聚合
- ❌ **demo 真实视频回放**:沿用 029 metadata-only 约定,不往 repo 塞二进制

## 验收

- [ ] 教练 demo 开机 → 接收 tab → `训练视频` 段显示 **3 行**(王晨曦「3 段待反馈」/ 李嘉宁「2 段」/ 张以恒「1 段」);`训练视频` 段计数 = 6;接收 tab 红点 = **7**(新学员 1 + 视频 6)
- [ ] tap 王晨曦 → 该学员详情按天分组,今天一天列出 **比赛式深蹲 / 暂停深蹲 / 比赛式卧推**(主项 + 变式)三段
- [ ] tap 某段 → 详情 sheet:学员名 + 元信息(主项/变式名)+ 「▶ 播放视频」+ 文本编辑器
- [ ] 写一条反馈 → 发送 → 该段出队、`训练视频` 计数 6→5、tab 红点 7→6;该学员清空后行消失、自动 pop 回收件箱
- [ ] live(非 demo):视频行的动作名来自 `plans.fetchCurrentPlan` 解析(`AggregatingCoachVideoQueueRepositoryTests.aggregatorResolvesExerciseNameFromPlan` 覆盖)
- [ ] 段空(全部回完)→ 回到诚实空状态「学员训练视频会出现在这里」
- [ ] live 路径(非 demo)：`AggregatingCoachVideoQueueRepository` 编译通过、聚合逻辑单测覆盖(pending 判定 + 出队)
- [ ] `swift build` + `swift test`(CoachKit + RepositoryContracts)绿;`build_run_sim`(MeetPR-Demo,**configuration=Demo**)起得来

## 测试

- `CoachVideoQueueViewModelTests`:load → items;sendFeedback → 出队 + count -1;失败态保持快照;`studentGroups` 一人一条按最近上传排序;`daySections` 按天分组
- `AggregatingCoachVideoQueueRepositoryTests`:多学员聚合;`planExerciseID` 匹配则排除;**`nil planExerciseID`(unlinked)排除**;**linked clip 发送→刷新→出队**(de-queue invariant);动作名从 `plans.fetchCurrentPlan` 解析
- `InMemoryCoachVideoQueueRepositoryTests`:seed → fetch;sendFeedback 精确按 videoID 出队
- `CoachDemoSeed.pendingVideos()`:6 段、3 学员、ID 不撞 fixture、动作名非空(主项/变式)

## 备注

- CLAUDE.md 头部「学员端不做 / backend 冻结」是 5/13 V0 里程碑约束,git log(024–041 全合)显示已被 6 月 V0.1 各 wave 取代;本 spec 0 backend、复用 live 既有 endpoint,不触冻结红线。
- 同批 Class-1 改动(**不**在本 spec 内,走快车道单独 commit):学员端 `DashboardView` 周历角标从「当天第一个主项」升级为「当天全部主项+变式 → 去重 → 按 S,B,D 排 → 拼字母(SB/SBD)」,分类逻辑落 `MainLiftExerciseFamilyResolver.families(in:)`(可单测);配套 `StudentDemoSeed` 补一个组合日令 `SB` 可见。
