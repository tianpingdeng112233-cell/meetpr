# 058 — 教练↔学员 1:1 聊天(iOS · W1 应用内消息)

- **状态**: InProgress(scope 已锁)。经 **6 轮 iOS 视角 review-loop**,30+ 项 finding 已处置;第 6 轮后剩余项均为「实装期用编译器解决」的签名/接线细节,已在 §本 spec 的边界 显式划出并交由**代码级 review-loop** 把关。**非 VERDICT: CLEAN 收敛,是平台化收口**(BLOCKER 曲线 14→7→6→5→4→5)。
- **PR**: TBD(iOS spec PR + iOS impl PR)
- **后端契约**: [`024-coach-student-chat`](~/Projects/apps/MeetPR-backend/specs/024-coach-student-chat/SPEC.md)(评审期在 `~/Projects/apps/MeetPR-backend-chat/`;已过 6 轮互审 **CLEAN**)。**wire 契约以 024 §Wire 契约 为唯一真源**,本 spec 只消费。
- **来源 / 授权**: David 2026-07-20 拍板启动;产品拍板 = **已读回执 / 文本+图片 / 教练复用「接收」tab 聚合 / 聊天入口每 tab 常驻(学员并进通知铃)/ 单一 active 教练(未来可换)/ W1 轮询·W2 APNs / 落 main(P2)**。

## ⚠️ 实装前置(硬 gate)

1. **ADR-005 amendment 必须先落**:ADR-005 定的是 per-role package 结构;新增两端共享的 `ChatUI` feature 模块是**架构变更**,不能只留「以后补脚注」。先在 `~/Brain/wiki/projects/MeetPR/decisions/` 落 amendment(或新 ADR)说明:双端 endpoint 同构 → 会话 UI 与 live repo 只实现一次;`CoachKit → ChatUI ← StudentKit` 不违反 `CoachKit ⊥ StudentKit`(两者只依赖 ChatUI,不互相依赖),与 `DesignSystem` 被双端共享同构。**amendment 未落不得开工实装**。
2. **backend 024 的 endpoint 需已在 staging 可用**才能联调 live;在此之前 iOS 用 `InMemoryChatRepository` 对着 024 §Wire 契约 搭 UI。

## 本 spec 的边界:哪些定死了、哪些留给实装期

本 spec 经 **6 轮 iOS 视角互审**收敛(transcript:`~/Brain/wiki/projects/MeetPR/reviews/2026-07-21-chat-ios-058.md`),**定死的是不变量、危险点与验收**:模块边界与 ADR 前置、coached-only gate、逐页挂载点、游标/已读口径、outbox 状态机与结算键、绑定失效传播与**自等待死锁**规避、清理与登出/换绑的**顺序**、图片续签算法、public surface 骨架、逐文件接线清单、测试矩阵。

**明确留给实装期(用编译器解决,不在散文里穷举)**:各 public API 的**最终精确签名**(参数标签/泛型/actor 标注)、SwiftUI 具体 view 组合与 `NavigationStack` destination 的落点写法、`AppShell` composition root(`MeetPRApp.swift` + `RootView.swift` + `Session`)里各依赖的构造次序细节。**实装时若与本 spec 的不变量冲突,以不变量为准并回报**;这些细节由**代码级 review-loop**(impl PR 前)把关,那时有编译器和真实调用点,比继续在文档里推演更可靠。

## 目标

给教练端与学员端一条**共享的 1:1 会话界面**(文本 + 图片气泡 + 已读回执 + 会话页内轮询),两端注入同一个 `ChatRepository`;教练在「接收」tab 聚合未读、每个 tab 可达;**coached 学员**在通知铃(升级为消息中心)与「我的教练」卡进入唯一会话。

**核心复用洞察**:聊天双方用**同一套 backend endpoint**(不像视频反馈是 per-role endpoint),故会话界面与 live repo **只需实现一次**。

## 关键架构决策

> **D1 — 新建 `ChatUI` SPM 模块(两端共享)**:`Modules/ChatUI/`,依赖 `CoreModels` + `RepositoryContracts` + `DesignSystem`。放共享会话 UI + VM + `InMemoryChatRepository` + `ChatDemoSeed`。见上「实装前置 1」。

> **D2 — live `ChatRepository` 落 `Networking`**:双端 endpoint 同构,live 实现收在 Networking 最省(见 §3)。

> **D3 — 聊天仅限 coached 形态(BLOCKER 修)**:`StudentRootView` 同时承载 **coached 与 self-train**(`trainingMode == .selfTrain`),而 024 的聊天路由明确拒绝 `self_train_student`。**所有聊天入口、VM 创建、轮询一律 gate 在 `.coached`**:self-train 四个 tab **无铃聊天行、无「我的教练」卡、零 chat 网络请求**(否则既违反 solo「零教练字样」约束,又持续打 403)。

> **D4 — 入口挂载点逐页定案(BLOCKER 修)**:tab 根的挂载方式**不统一**——多数自绘 header + `toolbar(.hidden, for: .navigationBar)`(此时 `.toolbar` 尾部**不会显示**),但 coached 训练页用系统 navigation title + `.toolbar` 且**已有 readiness/refresh items**。逐页定:
>
> | 端 / tab | 页面 | 挂法 |
> |---|---|---|
> | 学员 今日 | `DashboardView`(自绘 header,toolbar hidden) | 铃**嵌自绘 header 右上角** |
> | 学员 训练 | `TodayWorkoutView`(**系统 nav + 已有 toolbar**) | **追加**铃到现有 `.toolbar`,置于既有 readiness/refresh items **之后**;**不得改动或重排既有 items** |
> | 学员 成长 | `TrainingHistoryView`(自绘 header) | 铃嵌自绘 header 右上角 |
> | 学员 我的 | `MyProfileView`(自绘 header) | 铃嵌自绘 header 右上角 |
> | 教练 今日 / 学员 / 编排 / 接收 / 我的 | Dashboard / StudentRoster / Planning / **Receiving** / Profile | 五页**均已确认为自绘 header + 各自 `NavigationStack`** → 消息图标一律**嵌自绘 header 右上角**,destination 挂本栈 |
>
> **destination 归属**:每个 tab 各有独立 `NavigationStack`,入口 push 的 `ConversationListView` / `ConversationView` **必须挂在所属栈**,不得跨栈 push。

> **D5 — 游标/已读全用 024 的会话内 `seq`**:分页/轮询/已读比较一律按 `seq`;`createdAt` 仅用于气泡时间显示。

## 范围

### 1. domain model(`CoreModels`)

`Modules/CoreModels/Sources/CoreModels/Chat/`。**必须显式 `public init`**(Swift 合成 memberwise init 是 internal,Networking/ChatUI 无法构造)+ **`Codable`**(ADR-005 要求 CoreModels 数据型 Codable):

```swift
public struct ChatCursor: Codable, Hashable, Sendable {
  public let messageID: UUID
  public let seq: Int
  public init(messageID: UUID, seq: Int)
}

/// 学员当前 active 教练身份(定案,BLOCKER 修)。落 CoreModels 因 AppShell / StudentKit / ChatUI 都要读。
public struct ActiveCoachContext: Codable, Hashable, Sendable {
  public let coachID: UUID
  public let coachDisplayName: String   // 非可空
  public init(coachID: UUID, coachDisplayName: String)
}
// **构造规则(BLOCKER 修)**:现有 `BindRequest.coachDisplayName` 是 `String?`(无 profile 时 UI 既有约定回退「教练」)。
// 故由 BindRequest 构造时用 `request.coachDisplayName ?? "教练"` 填充,保持本 struct 字段非可空、
// 与既有回退文案一致。

public struct ChatConversation: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let otherPartyID: UUID
  public let otherPartyName: String
  public let lastMessagePreview: String?   // 文本截断 or「[图片]」
  public let lastMessageAt: Date?
  public let unreadCount: Int
  public let myLastRead: ChatCursor?       // 可空:从没读过
  public let otherLastRead: ChatCursor?    // 可空;渲染已读回执
  public init(...)                          // 全字段 public init
}

public enum ChatMessageKind: String, Codable, Sendable { case text, image }

public struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let conversationID: UUID
  public let seq: Int                      // 会话内单调序号:排序/游标/已读比较依据
  public let senderID: UUID
  public let kind: ChatMessageKind
  public let text: String?                 // wire `body` → text
  public let attachmentID: UUID?
  public let imageURL: URL?                // 现签,可空(oss 缺配/过期)
  public let imageExpiresIn: Int?          // 秒;驱动续签(见 D6)
  public let clientID: String              // **保留服务端 client_id**:pending 归并依据(BLOCKER 修)
  public let createdAt: Date               // 仅展示
  public init(...)
}
```

> **D6 — 图片签名 URL 会过期,必须有续签路径(BLOCKER 修)**:024 的 `image_url` TTL 900s,且对端**不能**走通用 attachment URL。3s 增量轮询只拉 `seq > max`,**不会刷新已加载图片的 URL**——久留会话、回滚旧图、点开全屏都可能失效。
> - **触发(nit 修 — 加载失败不受本地 expiry 门限制)**:**点开全屏 / 回到前台** → 走本地 `imageExpiresIn` 预检(客户端记取得时刻)后按需续签;**图片加载失败 → 无条件触发一次续签**——TTL 从服务端签名时起算,客户端从收到响应起算,本地判定天然偏晚,可能服务端已失效而本地仍认为没过期。每条消息加 **debounce / 单飞保护**,避免失败循环。
> - **精确算法(BLOCKER 修:`before_seq` 是严格 `seq < n`,直接传目标 seq 会把目标本身漏掉)**:请求 **`.before(seq: target.seq + 1, limit: 1)`**,校验返回消息 `id == target.id` 后**按 id/seq 原位更新** `imageURL`/`imageExpiresIn`——**不得当新消息插入**。仅当已确认目标就在最新页时才可用 `.latest`。
> - `image_url == nil`(oss 缺配)显占位、不重试。
> - 测试须覆盖「目标图片已滑出最新页」的续签路径。

### 2. repo 契约(`RepositoryContracts`)

`ChatRepository.swift`。**查询用带私有存储的 struct + throwing factory 让非法状态不可构造**(024 规定 since/before 互斥):

```swift
/// 游标查询。**唯一构造入口 = throwing static factory**(校验只有一处);但**必须暴露只读表示**
/// (BLOCKER 修:`NetworkChatRepository` 在另一个 package,要读方向/seq/limit 才能拼 query items)。
public struct ChatMessageQuery: Sendable {
  public enum Mode: Sendable {
    case latest
    case after(seq: Int)    // → since_seq
    case before(seq: Int)   // → before_seq
  }
  public let mode: Mode          // 只读,供 Networking switch
  public let limit: Int          // 只读
  private init(...)              // **private**:外部只能经 factory 构造合法值

  public static func latest(limit: Int) throws -> ChatMessageQuery
  public static func after(seq: Int, limit: Int) throws -> ChatMessageQuery
  public static func before(seq: Int, limit: Int) throws -> ChatMessageQuery
}

/// 公开的校验错误型(BLOCKER 修:factory throws 什么必须可被调用方 catch)
public enum ChatQueryValidationError: Error, Sendable { case invalidLimit(Int), invalidSeq(Int) }
// 校验(对齐 024:since_seq/before_seq/limit 均为**正整数**,limit ≤ 100):
//   limit ∈ 1...100,否则 throw;seq >= 1,否则 throw(**不是 >= 0**——发 since_seq=0 会被后端 400)。
// 空会话尚无最大 seq 时轮询用 `.latest(limit:)`;收到第一批后才切 `.after(maxSeq)`。
// 测试覆盖 limit 0/1/100/101 与 seq 0/1 边界。

public struct ChatMessagePage: Sendable {
  public let messages: [ChatMessage]      // VM 归一化为 seq 升序后使用
  public let otherLastRead: ChatCursor?
  public let hasMore: Bool
  public init(...)
}

/// markRead 返回**新读态**,供共享徽标原子更新(BLOCKER 修:原 Void 会让徽标陈旧)
public struct ChatReadState: Sendable {
  public let myLastRead: ChatCursor
  public let unreadCount: Int
  public init(...)
}

/// **绑定失效的跨模块传播(BLOCKER 修)**:ChatUI 按 ADR-005 禁止 import Networking,拿不到
/// `APIError`/错误信封;BindGate 又在 StudentKit(位于 ChatUI 之上)。故:
/// ① 此处定 typed error;② `NetworkChatRepository` 把 `403 CHAT_BIND_REQUIRED` 映射成它;
/// ③ `ConversationViewModel` / `ChatInboxViewModel` / `ChatSendCoordinator` 捕获后调**注入的
///    `onBindingInvalidated: @Sendable () async -> Void`**(**必须 async**:宿主要在其中 await
///    `cancelAllAndWaitForCleanup()` 再刷新 bind、切换 context;同步签名做不到「先清理后换绑」);
///    ChatUI 不反向依赖 StudentKit;
/// ④ 学员端:`BindGateView` 的 content builder 除 `ActiveCoachContext` 外**再提供一个 `refresh()` 闭包**
///    给 StudentRoot,由 StudentKit 去重后接到该回调;⑤ 教练端:该回调传 no-op(教练无 BindGate,
///    不得尝试刷新不存在的东西),仅走本地错误提示。
public enum ChatRepositoryError: Error, Sendable {
  case bindRequired          // 403 CHAT_BIND_REQUIRED
  case conversationNotFound  // 404
  case invalidAttachment     // 400 CHAT_INVALID_ATTACHMENT
  case invalidCursor         // 400 CHAT_INVALID_CURSOR(实装期补:024 有此错误码,本 spec 原先漏列)
}

public protocol ChatRepository: Sendable {
  func fetchConversations() async throws -> [ChatConversation]
  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation
  func fetchMessages(in conversationID: UUID, query: ChatMessageQuery) async throws -> ChatMessagePage
  func sendText(in conversationID: UUID, text: String, clientID: String) async throws -> ChatMessage
  func sendImage(in conversationID: UUID, imageData: Data, clientID: String) async throws -> ChatMessage
  func markRead(in conversationID: UUID, upTo messageID: UUID) async throws -> ChatReadState
}
```

### 3. live repo + 网络(`Networking`)

- **`DTO/ChatDTOs.swift` — 必须写显式 `CodingKeys`(BLOCKER 修)**:`MeetPRCodec.convertFromSnakeCase` 把 `client_id` 转成 `clientId`(**不是** `clientID`),`conversation_id`/`sender_id`/`attachment_id`/`image_url`/`message_id`/`other_user_id` 同理。照既有范式(`DTO/UploadDTOs.swift` 的显式 post-conversion CodingKeys)逐字段写。字段与可空性**严格照 024 §Wire 契约**:`client_id: String`(非 UUID,合法值形如 `"cli-xyz"`)、`attachment_id: UUID?`、`image_url: URL?`、`image_expires_in: Int?`、`body: String?`、`seq: Int`、双 read cursor 是**对象**`{message_id, seq}` 非裸 Int;所有 response wrapper(`{conversation}` / `{conversations}` / `{messages,meta}` / `{message}`)与 request body 都要有 DTO。**含 mark-read(BLOCKER 修,原漏列)**:请求 `ChatReadRequestDTO { message_id }`、响应 `ChatReadResponseDTO { my_last_read: {message_id, seq}, unread_count: Int }`(注意 `my_last_read` 是**对象**不是裸 Int,照 024 §Wire 契约),映射到 `ChatReadState(myLastRead: ChatCursor, unreadCount:)`;补 decode/encode + 字段缺失/类型错误 fixture 测试。
- **`public actor NetworkChatRepository: ChatRepository`**(BLOCKER 修:**必须是 actor**,与既有 live repository(`BackendOnboardingRepository` / `BackendCoachEvaluationRepository` / `BackendInviteCodeRepository` 等)及 ADR-005 的隔离模式一致;不得改用其它 Sendable 实现)。**鉴权与可注入**:`APIClient` 本身不持登录态,authenticated endpoint 需从 `SessionStateReader` 异步取 token。故 `init(apiClient:session:uploader:)` 显式注入 `APIClient` + `SessionStateReader` + `OSSPartUploader`(便于测试分别 mock backend transport 与 OSS PUT transport),**不硬用 `.shared`**。
  - `sendImage`:接收**已降采样**的 JPEG `Data`(降采样归 ChatUI,见 D7)→ 通用上传层 `APIClient+Uploads`(`kind: chat_image`)+ `OSSPartUploader` 分段 PUT → complete 拿 `attachment_id` → `POST /messages`。**Networking 不再二次压缩**。**失败/取消/幂等命中旧消息时,清理刚产生的未引用 attachment**(调既有 abort/delete;注意 024 D2b:已被消息引用的附件删会 409,属预期,不当错误)。**不复用** `VideoUploadManager`(StudentKit 私有、视频专用)。
- **`AttachmentKindDTO` 加 `chatImage` case**(`DTO/UploadDTOs.swift`)+ Codable 测试(wire `"chat_image"`)。
- **`Networking` 的 library target 必须真正链接 `RepositoryContracts`**(当前 `Modules/Networking/Package.swift` 只声明 package、target 仍只链 CoreModels)。

> **D7 — 降采样归 ChatUI,只做一次(nit 修)**:长边压到 ~1600px、JPEG q0.7(`chat_image` 限 10MB 是硬顶不是目标)。**归属定案**:`ChatUI` 的 `ChatImageDownsampler` 在 composer 选图后产出受限 JPEG `Data`,`ChatRepository.sendImage(imageData:)` 收到的**已是**降采样结果;`Networking` **不再压缩**。避免两边都做(重复压缩)或都不做(原图直传 OSS)。

### 4. 共享会话界面(`ChatUI`,新模块)

**新建 `Modules/ChatUI/Package.swift`**(library + test target;demo 占位图作 resource)。组件:

- **`ConversationView`**:消息列表(气泡:我方右/accent,对方左/中性;image 气泡缩略图 → tap 全屏)+ 底部 `ChatComposer`。
- **`ChatComposer`**:`TextField` + 发送 + `PhotosPicker`。**输入边界**:trim 后空文本不可发、上限 4000 字符(对齐 024 CHECK)、发送中按钮态、失败可重试。
- **`ConversationViewModel`**(`@Observable @MainActor`):
  - 持 `messages: [ChatMessage]`(按 `seq` 升序)、`pending: [PendingChatMessage]`、`otherLastRead: ChatCursor?`、`hasMoreHistory`。
  - **「我方消息」判定定案(BLOCKER 修)**:`ConversationViewModel(currentUserID:...)` —— `currentUserID` 由 **AppShell 从登录 session 的 `user.id` 透传**给两端 root,再注入 VM(与 `ChatInboxViewModel` / `ChatSendCoordinator` 同源)。气泡左右、pending 归并全靠它,**不靠 `senderID != otherPartyID` 反推**。
  - **pending 归并(BLOCKER 修)**:`PendingChatMessage` 持 `clientID` + 内容 + 每条自己的 `sendState{sending,failed}`(**不用全局单一 sendState**,并发多发表达不了)。合并渲染 = confirmed(按 `seq`)+ pending(末尾)。**匹配键 = `clientID` **且** `senderID == currentUserID`**——024 的幂等唯一键含 `sender_id`,对方理论上可用相同 `clientID`,只比 `clientID` 会误删我方 pending。轮询若先于 POST 响应带回匹配的已确认消息,立即移除对应 pending,杜绝「confirmed + pending 双气泡」。
  - **轮询唯一 owner(BLOCKER 修)**:会话页轮询由 `ConversationView` 的 `.task(id:)` structured task 独占(3s);`ConversationListSection` **只做一次 refresh、不自己轮询**(30s 轮询归 `ChatInboxViewModel` 唯一持有)。规则:重复 appear 只有一个 poller;disappear/logout/进后台取消;回前台只重启一次;取消不落错误态;**sleep/clock 可注入**(测试不真等 3/30s)。
  - **`hasMore` 同轮追赶(nit 修,写明确)**:一次轮询 tick 内若返回 `hasMore == true`,**立即以新的最大 `seq` 继续请求下一批,直到 `hasMore == false`**;若某批返回后最大 `seq` **未前进**则立刻停止(防紧循环)。否则高流量下会变成「每 3 秒只追一页」而永久落后。测试须造 **> 2 页**积压验证一轮追平。
  - **发送归 session 级 `ChatSendCoordinator`,不归会话 VM(BLOCKER 修 — 原方案自相矛盾)**:VM 随离页销毁,「Task 由 VM 持有」与「离页继续 + logout 可取消」三者不可能同时成立;且失败 pending 若只活在将销毁的 VM 里,用户重进会话看不到失败也无法重试 = **静默丢消息**。定案:
    - **所有权定案(BLOCKER 修 — 原文一处说角色 root 持有、一处说 AppShell 注入,自相矛盾)**:`ChatInboxViewModel` 与 `ChatSendCoordinator` **由 AppShell 构造并持有**(session 级,与 `Session` 同生命周期),经参数注入两个角色 root。**唯一构造点 = AppShell**。
    - **`ChatSendCoordinator`**(`@Observable @MainActor`,ChatUI)拥有发送 `Task` **与**按 `conversationID` 归档的 outbox。
    - **outbox 状态机 + 交接 API(BLOCKER 修 — 原只有 pending/send/retry/cancel,缺双向交接)**:每条 outbox item 状态 = `.sending` / `.failed(Error)` / `.confirmed(ChatMessage)`。
      - **POST 先返回**:coordinator 置 `.confirmed(msg)` 但**不立即删**;活跃 VM 观察到 `.confirmed` → upsert 进 `messages` → 调 **`acknowledgeConfirmed(clientID:)`** 让 coordinator 移除。**避免 coordinator 直接删导致气泡消失、要等下一轮轮询才回来**。
      - **轮询先返回**:VM 调 **`reconcile(with confirmedMessages:)`**,coordinator 按 `clientID` **且** `senderID == currentUserID` 移除对应 item。
      - 无活跃 VM 时 `.confirmed` 保留在 outbox,VM 重进会话时一次性 reconcile。
      - **`cancelAll` 用 generation 计数**:取消后晚返回的 Task 不得回写状态(比对 generation,过期即丢弃)。
      - **绑定失效必须经 AppShell 的 invalidation router,且严防自等待死锁(BLOCKER 修)**:若发送 Task 捕获 `bindRequired` 后直接 `await onBindingInvalidated()`,而该回调又 `await cancelAllAndWaitForCleanup()`——后者要等的在途任务**包含调用者自己**,直接死锁挂死。定案:① 回调由 **AppShell 持有的 invalidation router** 实现(它同时持 coordinator / inbox / bind refresh,是唯一能编排顺序的层);② 发送 Task **先把自己从在途集合注销、再 fire-and-forget 发事件**,不 await 回调;③ router 内做**去重**(同一失效窗口只 refresh 一次);④ `cancelAllAndWaitForCleanup()` 明确**排除调用方任务**。必测:「发送中收到 bindRequired → 不挂死、只 refresh 一次」。
      - **poll-first 后迟到的 POST 响应不得复活已 reconcile 的条目(BLOCKER 修)**:`reconcile(with:)` 移除某 `clientID` 时把它记入**已结算集合**(per conversation);该 clientID 的发送 Task 稍后返回时,查已结算集合命中即**丢弃结果、不再写回 outbox**(否则气泡会重新冒出来)。同理 `acknowledgeConfirmed(clientID:)` 也入该集合。集合随会话缓存清理而清空。
    - `ConversationViewModel` **只观察**该协调器,不自己持有发送 Task。离页 → VM 销毁,发送继续;**重进会话仍能看到在途/失败并重试**。
    - **清理顺序定案(BLOCKER 修 — 否则清 token 与 attachment 清理竞态、泄漏 OSS 对象)**:
      - 提供 **`cancelAllAndWaitForCleanup() async`**:取消在途 → **await 非取消的 cleanup scope 完成**(图片 attachment 的 abort/delete)→ 再清 outbox。
      - **logout 顺序 = `await chat.cancelAllAndWaitForCleanup()` → `await session.logout()`**(现 `Session.logout` 会先清 token,顺序反了清理就没鉴权可用)。**这条必须覆盖 `Session` 内部触发的自动登出**(token 刷新失败等非用户主动路径),不能只接在「用户点退出」按钮上——否则自动登出仍会泄漏未引用 attachment。实装时把清理挂在 Session 的登出入口(单点),而非各调用方。
      - **换绑/coachID 变化**同样先 await cleanup 再切 context。
      - 上传开始时**捕获当次可用 token** 供清理使用;若鉴权已失效无法清理,记 best-effort 日志并交由服务端侧未引用附件回收(不阻塞登出)。
    - 失败重试**复用同一 `clientID`**(靠 024 幂等,不产生重复消息)。
    - **图片**:上传已 complete 但消息 POST 失败/被取消 → 按 §3 清理该未引用 attachment。
    - `CancellationError`(仅 cancelAll 路径)**不进用户可见失败态**;其它错误进对应 pending 的 `failed`。
    - **W1 只在内存**(进程内保留失败 pending),不落盘;跨进程持久重试队列 defer。
    - 测试须覆盖:发送中 pop → 成功 / 发送中 pop → 失败后重进会话可见并可重试 / logout 取消 / 取消后图片 attachment 清理 / 幂等回包(同 clientID 命中既有)。
  - **历史分页(BLOCKER 修)**:`loadOlder()` 以当前最小 `seq` 作 `before`;初始页 DESC → VM 归一化升序;prepend 去重且不跳动;与轮询并发时按 seq 合并;`hasMore` 分「历史/增量」两个方向各存。
  - **已读**:进入会话 + 前台收到新入站 → `markRead(in:upTo messageID:)`(协议签名见 §2),用其返回的 `ChatReadState` **原子更新共享 `ChatInboxViewModel`**(见下),并防旧响应覆盖新状态(带请求序号/时间戳丢弃 stale)。
  - **已读回执派生**:我方最后一条下,`otherLastRead.seq >= 该消息.seq` 显「已读」,否则「已送达」。
- **`ConversationListSection`**:会话列表段(对方名 + 预览 + 相对时间 + 未读红点)。`onAppear` 刷新一次;数据读共享 `ChatInboxViewModel`。
- **`ChatInboxViewModel`**(`@Observable @MainActor`,**共享徽标唯一源**):持 `conversations` + `totalUnread`;**唯一 30s 轮询者**;暴露 `apply(_ readState:for:)` 供会话页 markRead 后原子清零。在 tab 容器层注入**一个实例**,所有入口/徽标读它。
- **`ChatEntryButton`**:图标 + 未读角标(读 `ChatInboxViewModel`),**供嵌进自绘 header**(见 D4),tap 行为由宿主注入。
- **`InMemoryChatRepository`**(`actor`)+ **`ChatDemoSeed`**。**当前用户身份必须显式(nit 修)**:`init(currentUserID:seed:)` 单独接收身份——`sendText/sendImage` 的 sender、未读计算(`senderID != currentUserID`)、`markRead` 都依赖它;教练/学员两套 demo seed 若共享错误的 sender 视角会算错未读与已读回执。补 repo 层测试:`openConversation` 幂等 / send 追加 + last message 更新 / markRead 单调 / 未读聚合。

#### 4b. ChatUI 的 public surface(BLOCKER 修 — Swift 合成 init 默认 internal,跨模块构造不了)

跨模块使用的类型/初始化器/状态/方法**必须显式 `public`**,最小清单:

| 类型 | public 要求 |
|---|---|
| `ConversationView` | `public init(conversationID:currentUserID:repository:inbox:sendCoordinator:)` |
| `ConversationListSection` | `public init(inbox:onSelect:)` |
| `ChatEntryButton` | `public init(unreadCount:action:)` |
| `ChatInboxViewModel` | `public init(repository:currentUserID:)`;只读 `conversations` / `totalUnread`;`refresh()` / `apply(_ readState:for:)` / `clear()` / 轮询 start-stop |
| `ChatSendCoordinator` | **`public init(repository:currentUserID:)`**(需 `currentUserID` 才能按 024 的完整幂等键 `(conversationID, senderID, clientID)` 结算);`outbox(in conversationID:) -> [ChatOutboxItem]` / `sendText(in:…)` / `sendImage(in:…)` / `retry(in:clientID:)` / **`acknowledgeConfirmed(in:clientID:)`** / **`reconcile(in:with:)`** / **`cancelAllAndWaitForCleanup() async`**。**所有按 clientID 的操作都必须带 `in conversationID:`**——否则定位不到 per-conversation outbox 与已结算集合,且两个会话/双方可能用相同 `clientID`。 |
| `ChatOutboxItem` / `ChatSendState` | 公开类型:`ChatSendState = .sending / .failed(Error) / .confirmed(ChatMessage)`;`ChatOutboxItem { clientID, conversationID, senderID, draft, state }`。**取代原 `PendingChatMessage.sendState` 只有两态却又承诺返回 confirmed 的自相矛盾** |
| `InMemoryChatRepository` / `ChatDemoSeed` | `public init(currentUserID:seed:)` / public seed 工厂 |
| `ChatMessageQuery` / `PendingChatMessage` | public 类型 + public throwing factory / public 只读字段 |

> **`ConversationListView` 归属定案**:它**不属于 ChatUI** —— 只有教练端用(学员是单会话直进),放进 ChatUI 会违反本 spec 与 ADR-005 amendment 定的「ChatUI 只收双端同构物」边界纪律。定为 **CoachKit 内对 `ConversationListSection` 的薄包装**(负责本栈 navigation destination)。

#### 4c. SPM / Xcode 逐文件接线清单(BLOCKER 修)

| 文件 | 改动 |
|---|---|
| `Modules/ChatUI/Package.swift`(新) | library product `ChatUI` + library target(依赖 `CoreModels` / `RepositoryContracts` / `DesignSystem`)+ test target;demo 占位图作 resource;`StrictConcurrency` 与其它模块一致 |
| `Modules/CoachKit/Package.swift` | 加 ChatUI package path + library target 依赖 product;若测试直接 `import ChatUI`,test target 也加 |
| `Modules/StudentKit/Package.swift` | 同上 |
| `Modules/AppShell/Package.swift` | 同上(AppShell 注入 live/demo repo 与两个 session 级 VM) |
| `Modules/Networking/Package.swift` | **library target 真正链接 `RepositoryContracts` product**(当前只声明 package、target 仍只链 CoreModels) |
| `Modules/ChatUI/…/Localizable.xcstrings`(新) | ChatUI 自带字符串资源,在其 Package.swift 以 `resources: [.process(...)]` 声明;宿主侧字符串进 CoachKit / StudentKit 各自 xcstrings(无则新建并同样声明 resource) |
| `MeetPR.xcodeproj/project.pbxproj` | 工程现有惯例 = 两个 app target 各自显式链接所需模块 product;**按此惯例给两个 app target 加 ChatUI**(若最终确认传递依赖已足够,须在 PR 说明里写明「无需改 pbxproj」并给出依据) |
| `~/Brain/…/decisions/005-ios-architecture.md` | **已全部同步并 committed**(ChatUI amendment + 模块数改 **9**(原 7 + 既有但从未列入的 `CatalogKit` + `ChatUI`)+ 模块树补 CatalogKit/ChatUI + AppShell/CoachKit/StudentKit 三处依赖行)。**impl PR 不需要再改 Brain 文档** |

### 5. 教练端接线(`CoachKit`)

- **每-tab 入口**:教练 5 tab(今日/学员/编排/接收/我的)——按 D4 **把 `ChatEntryButton` 嵌进各 tab 自绘 header 右上角**(Dashboard/Roster/Planning/Profile 均隐藏 nav bar);tap → 在**该 tab 自己的 `NavigationStack`** push `ConversationListView` → 选会话 → `ConversationView`。
- **`CoachReceivingView`**:新增第三段「消息」,渲染 `ConversationListSection`(读共享 `ChatInboxViewModel`);「接收」tab 仍是聚合主场。
- **`StudentDetailView`**:加「发消息」→ `openConversation(withOtherParty: studentID)` → 本栈 push `ConversationView`。
- **接收 tab 徽标** = 既有(新学员 + 训练视频)+ `ChatInboxViewModel.totalUnread`。
- **接线**:`CoachRootView` 加 `chat: (any ChatRepository)? = nil` + `currentUserID` + `inbox: ChatInboxViewModel` + `sendCoordinator: ChatSendCoordinator` 形参(**由 AppShell 构造并传入,角色 root 不自建**,见 §4 所有权定案);live 由 AppShell 注入 `NetworkChatRepository`,demo 注入 `InMemoryChatRepository(currentUserID: <教练 demo id>, seed: ChatDemoSeed.coach())`(注意 initializer 带 `currentUserID`,见 §4)。

### 6. 学员端接线(`StudentKit`)——**仅 coached**

> 全部入口 gate 在 `trainingMode == .coached`(D3)。

- **通知铃 → 统一「消息中心」+ 提到每 tab**:现有铃是「今日」私有(`DashboardView` 内建 `DashboardNotificationsViewModel` + `NotificationCenterSheet`,聚合计划发布/未读反馈/未读评估)。本 spec:
  1. **抽 StudentRoot 级共享通知协调器(BLOCKER 修)**:四个 tab 的铃**渲染同一个实例**(否则各自 fetch、plan-seen 状态不同步)。该协调器聚合 计划 + 反馈 + 评估 + **聊天未读**(读 `ChatInboxViewModel`),徽标 = 四类之和。
  2. **铃按 D4 的逐页挂载点接**(今日/成长/我的 = 嵌自绘 header;**训练 `TodayWorkoutView` = 追加到现有系统 `.toolbar`**,不改既有 readiness/refresh items 顺序)。
  3. **`NotificationCenterSheet` 加第四行「教练消息」**(教练名 + 预览 + 未读)→ 在**当前 tab 的栈**push `ConversationView`。
  4. **四行路由定案(BLOCKER 修 — 不留给实装者)**。规则:**先 dismiss sheet,再导航**(避免 sheet 盖住导航目标)。从**任意** tab 点击的行为一致:

     | 行 | 已读处理 | 目的地 |
     |---|---|---|
     | 计划发布 | mark seen(既有 `DashboardPlanSeenStore`) | 切到**训练** tab(既有行为) |
     | 未读反馈 | 既有反馈已读口径不变 | 切到**成长** tab(既有行为) |
     | 未读评估 | 进入即 `markRead`(既有) | **切到「今日」tab** 再 push `EvaluationSummaryView`(该 destination 挂在今日栈,不复制到其它栈) |
     | 教练消息(新) | 进会话即 `markRead` | **不切 tab**,在**当前 tab 自己的栈**push `ConversationView` |

  5. **聊天行显示条件定案**:**有 active 教练即显示**(即便 `unread == 0` 且尚无 conversation);点击走 `openConversation(withOtherParty:)` get-or-create 后进空会话。无 active 教练(理论上 coached 不会出现)则整行隐藏。
- **「我的教练」卡**:落 `MyProfileView`,显教练名 + 预览 + 未读 → 进唯一会话(与铃里聊天行同一入口逻辑)。
- **active coach 上下文定案(BLOCKER 修)**:`GET /conversations` 尚无会话时返回空数组,但卡/铃仍需 coach id/name 才能 `POST /conversations`;而现 `BindGateView` 在 `.bound` 分支直接调 `content()`、**丢掉了 `BindRequest`**。定案:
  - 类型 = `CoreModels.ActiveCoachContext { coachID, coachDisplayName }`(见 §1)。
  - `BindGateView` 的 content closure 改为**接收 `ActiveCoachContext`**(由 `.bound` 分支的 `BindRequest` 构造)。
  - `AppShell` 把它传给 `StudentRootView`,再注入共享通知协调器 + 「我的教练」卡。
  - **换绑/解绑的检测触发源定案(BLOCKER 修 — 原来没有触发源)**:现 `BindGateView` 回前台**只刷新 `.pendingAcceptance`**,`.bound` 态不再查询,因而根本发现不了解绑/换绑。定案两条触发:① **`.bound` 态也在回前台刷新 bind 状态**;② 任一聊天请求收到 **`403 CHAT_BIND_REQUIRED`** 即触发一次 bind refresh。
  - **换绑必须两阶段,不能直接 apply(BLOCKER 修)**:现 `BindGateViewModel.refresh()` 拉到结果**立即写入新 state**,异步回调追不上这个前台路径。定案改为 **`fetch candidate → 比较 old/new coachID → (变了才) await cleanup → 再 apply state`**(或等价的 `willApplyBindingChange` async hook)。必测:同 coach 刷新**不**取消在途发送;换绑时清理完成后才发布新 context。
  - **coachID 变化(换绑)与解绑统一处理**:**任何 `coachID` 变化**(不只 nil)都要先 **`await ChatSendCoordinator.cancelAllAndWaitForCleanup()`**(等图片 attachment 清理完成,见 §4)+ 清空旧会话缓存 + `ChatInboxViewModel` 清空停轮询,**再**载入新教练状态;解绑(置 nil)时聊天行与教练卡隐藏。
- **接线**:`StudentRootView`/`RootView` 加 `chat:` + `currentUserID` + `inbox` + `sendCoordinator` + `activeCoach` 透传(**均由 AppShell 构造传入,不在 tab 容器自建**,见 §4 所有权定案);学员端共享通知协调器由 `StudentRootView` 建(它聚合的计划/反馈/评估是学员侧概念),但其聊天未读分量读 AppShell 传入的 `inbox`。

### 不做(本 spec / W1)

- ❌ APNs / entitlement / PrivacyInfo push(W2 单独 spec)。
- ❌ SwiftData 缓存消息(ADR-009 圈死在 CoachKit 草稿);W1 内存态 + 网络直取。
- ❌ 消息编辑/撤回/删除、@提及、引用某组/视频、typing/在线态、视频消息。
- ❌ **self-train 形态的任何聊天呈现**(D3)。
- ❌ 学员多会话列表(024 D6:学员只列 canonical active 会话;「过往教练」入口 defer V1.x)。
- ❌ 教练端新造通知铃(那是学员侧概念)。

## 验收(模拟器)

> **构建档(BLOCKER 修)**:教练 demo = scheme `MeetPR-Demo` + configuration `Demo`;**学员 demo = scheme `MeetPR-DemoStudent` + configuration `DemoStudent`**(仓库已有该 scheme)。两个都要跑。

- [ ] 教练 demo:任一 tab 自绘 header 右上角有消息图标(带未读角标)→ tap 在本栈进会话列表 → 进会话;「接收」tab 有「消息」段;学员详情「发消息」进同一会话。
- [ ] 学员 demo(coached):四个 tab 的 header 都有铃,角标 = 计划+反馈+评估+聊天未读之和;点铃 sheet 四行;点「教练消息」在**当前 tab 栈**进会话;「我的」有「我的教练」卡进同一会话。
- [ ] **自练学员(self-train)**:四个 tab **无铃聊天行、无教练卡、零 chat 网络请求**(抓请求验证)。
- [ ] 从**非今日 tab** 点铃里的计划/反馈/评估三行,目的地与已读行为与今日 tab 一致(既有功能不回归)。
- [ ] 会话:发文本 → pending 气泡即时出现 → 确认后替换(无双气泡);发图 → 降采样 → 缩略图 → 全屏;已读回执「已送达」→「已读」。
- [ ] 离开会话前,教练五 tab 图标 / 接收徽标 / 学员铃 / 教练卡的未读**已一致清零**(markRead 返回态原子更新)。
- [ ] 图片久留会话后仍可查看(签名 URL 按 D6 续签);`image_url:null` 显占位。
- [ ] 历史:滚到顶加载更早、去重不跳动、与轮询并发不乱序。
- [ ] `swift build` + `swift test` 覆盖 **ChatUI + CoreModels + RepositoryContracts + Networking + CoachKit + StudentKit + AppShell**;两个 demo scheme 都能 `build_run_sim` 起来。

## 测试(Swift Testing)

- `ConversationViewModelTests`(轮询/渲染层):轮询单 owner(重复 appear 只一个)、取消不落错误态、`hasMore` 无前进则停、`hasMore` 同轮追平(>2 页);历史 prepend 去重;已读回执 `seq` 边界。
- **`ChatSendCoordinator` × VM 组合层测试**(nit 修:发送已不归 VM,不能再按「view 消失时 VM 取消 Task」写):pending↔confirmed 四种竞态(poll 先于 POST 响应 → `reconcile` / POST 先于 poll → `.confirmed` + `acknowledgeConfirmed` / 并发发送 / 失败复用同 clientID 重试);发送中 pop → 成功;发送中 pop → 失败后重进会话可见并可重试;`cancelAllAndWaitForCleanup()` 取消 + 等清理完成;generation 防晚返回回写;取消后图片 attachment 已清理。
- `ChatInboxViewModelTests`:唯一 30s 轮询;`apply(readState:)` 原子清零;stale 响应不覆盖。
- `NetworkChatRepositoryTests`:**规范 JSON fixture decode**(照 024 §Wire 契约逐字段/可空性)+ request JSON/query 精确 encode(非自编自解 round-trip);sendImage 上传→发消息串联 + 失败清理未引用 attachment;鉴权 header 走注入的 `SessionStateReader`。
- `StudentKit`:self-train 零聊天呈现/零请求;共享通知协调器四行路由(含从非今日 tab)+ 既有三类通知不回归;`ActiveCoachContext` 透传。
- `CoachKit`:每-tab 入口在本栈 push;接收段与徽标口径。
- `ChatDemoSeed`:教练多会话 / 学员单会话;含未读 + 已读态 + 图片;id 不撞既有 fixture。

## 备注

- **本地化归属(nit 修)**:ChatUI 内的可见字符串(「发送中」「发送失败」「已送达」「已读」「[图片]」等)由 **ChatUI 自带 `Localizable.xcstrings` resource**(在其 Package.swift 声明,`Bundle.module` 取用);宿主侧字符串(教练端「消息」入口、学员端「我的教练」卡与铃里「教练消息」行)进**各自宿主模块**的 xcstrings(CoachKit / StudentKit;若该模块尚无 `Localizable.xcstrings` 则**新建并在 Package.swift 声明 resource**——不要假设已存在)。两侧都补齐当前支持语言。
- **通知 sheet 布局(nit)**:现 `NotificationCenterSheet` 是固定 VStack + `.medium` detent,加第四行在小屏/大 Dynamic Type 下可能裁切 → 改可滚动或允许 `.large`,加 Dynamic Type 验收。
- **iOS 仓 CLAUDE.md「backend FROZEN / 学员端 V0.1 起」是 5/13 V0 残留**,已被后续 wave 取代;下次 neat-freak 清。
- 两端并行实装:iOS 先用 `InMemoryChatRepository` 对着 024 契约搭 UI,`NetworkChatRepository` 待 024 上 staging 后联调。
