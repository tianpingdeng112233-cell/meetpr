# SPEC 066 — 聊天实时化客户端:WebSocket 订阅取代 30s/3s 轮询

- **Status: InReview(implementation complete 2026-08-03)**
- **级别**: T2(跨模块:Networking + ChatUI + AppShell)。**P1**,base = `release/1.0`,
  随 1.0(18) 班车。
- **来源**: 教练零感知专项(2026-08-03)。app 内唯一自动感知是聊天 30s 轮询,拍板升级为实时。
- **端**: iOS(本仓)。服务端为 backend **spec 032**(`specs/032-realtime-chat-channel/SPEC.md`,
  backend 仓),wire 契约以其 §3 为准,本 spec §2 照录不改。
- **受益面**: ChatUI 为教练/学员两端共用——两端同时实时化,无需分端开工。

## 0. 现状锚点(侦察已核实,file:line 以 `origin/release/1.0` 595342c 为准)

- 收件箱 30s 轮询:`Modules/ChatUI/Sources/ChatUI/ChatInboxViewModel.swift:113-128`
  (`poll(generation:)`,`sleep(.seconds(30))` 注入式可测)。
- 会话内 3s 轮询:`Modules/ChatUI/Sources/ChatUI/ConversationViewModel+Loading.swift:50-63`,
  由 `ConversationView.swift:100-107` 的 `.task(id: scenePhase)` 驱动。
- 聊天图装配:`Modules/AppShell/Sources/AppShell/ChatSessionController.swift`
  (`ChatSessionContext` 持 repository / inbox / sendCoordinator;role kit 只收图不自建)。
- token 供给:`Modules/Networking/Sources/Networking/NetworkChatRepository.swift` 的
  `session.accessToken()`(`SessionStateReader` 协议)——RealtimeClient 复用同一协议。
- baseURL:`Networking/BuildConfig.swift` `http://121.40.160.241:3000` → ws URL 由
  同一 baseURL 派生(`http`→`ws`/`https`→`wss`),**不新增任何配置项**。
- 教练端 tab 红点吃 `chat.inbox.totalUnread`(`CoachRootView.swift:213-223`),
  实时化后红点即时性自动跟上,无需改 CoachKit。

## 1. 目标与非目标

### 1.1 目标

- 对端发消息 → 本端收件箱未读数/红点与打开中的会话在 1s 级更新(app 前台)。
- 断线/服务端不可用 → **无感回退现有轮询**,行为与 1.0(17) 完全一致(不丢消息、不空窗)。
- 退后台断连,回前台重连 + 立即刷新一次(顺带修「回前台最坏等 30s」的旧缺口)。

### 1.2 非目标

- ❌ APNs / 离线推送(app 杀掉仍零感知,另一轨道)。
- ❌ 聊天以外事件的消费(未知 `type` **必须静默忽略**——backend 032 的前向兼容口子)。
- ❌ 删除轮询代码:轮询是降级态的正式路径,**保留不删**。
- ❌ typing indicator / 在线状态等新 UI。

## 2. Wire 契约(照录 backend 032 §3,锁死)

`GET /realtime` WebSocket 升级,`Authorization: Bearer <access token>` 头鉴权
(`URLSessionWebSocketTask` 走 `URLRequest`,可带头;**token 绝不进 URL query**)。
服务端→客户端单帧 JSON 文本:

```jsonc
{ "type": "hello",        "payload": {} }
{ "type": "chat.message", "payload": { "conversation_id": "<uuid>", "seq": 42, "sender_id": "<uuid>" } }
{ "type": "chat.read",    "payload": { "conversation_id": "<uuid>", "user_id": "<uuid>", "last_read_seq": 41 } }
```

payload 只有指针没有消息体(可见性裁剪在 HTTP 读路径,设计如此)——收到指针后走既有
repository 方法增量拉取。心跳是 WebSocket 协议层 ping/pong 帧,不是 JSON。

## 3. 架构与文件范围

### 3.1 Networking 模块新增

| 文件 | 职责 |
|---|---|
| `RealtimeClient.swift` | `public actor RealtimeClient`:`URLSessionWebSocketTask` 长连接;`init(baseURL:session:)`(session = `any SessionStateReader`);`connect()` / `disconnect()`;对外两条 `AsyncStream`:`events: AsyncStream<RealtimeEvent>` 与 `state: AsyncStream<RealtimeConnectionState>`(`.connected` / `.disconnected`);重连指数退避 1s→2s→4s…封顶 30s + 全幅抖动,收到 `hello` 视为连接成功并重置退避;客户端每 20s `sendPing`,失败即判死走重连;`disconnect()` 后不得再自动重连(显式 `connect()` 才恢复) |
| `RealtimeEvent.swift` | 事件解码:snake_case DTO → `enum RealtimeEvent { case hello; case chatMessage(conversationID:seq:senderID:); case chatRead(conversationID:userID:lastReadSeq:) }`;**未知 type 解码为 nil 并跳过,绝不 throw**(1.0(14) 裸 enum 整屏崩的教训写进注释) |

约束:token 取自 `session.accessToken()`(它自带刷新语义);握手 401 → 按普通断线走退避
重连(下一次 `accessToken()` 会给新 token),**不做**独立的 401 特殊路径。

### 3.2 ChatUI 接入(降级三态契约)

- `ChatInboxViewModel`:现有 `startPolling()/stopPolling()` 与 generation 机制**不动**;
  新增 `attachRealtime(events:state:)` 类接口(具体签名 Codex 定,保持注入可测):
  - `state == .connected`:挂起轮询循环(复用现有 stopPolling/startPolling 或等价 gate);
    收 `chat.message` → `refresh()`;收 `chat.read` 且涉及本用户会话 → 更新对应会话的
    `otherLastRead`(已有 `apply` 心智,防倒退用 seq 比大小)。
  - `state == .disconnected`:恢复 30s 轮询(即现状行为)。
- `ConversationViewModel`(+Loading):同一契约——connected 时挂起 3s 轮询;
  收本会话 `chat.message` → 走既有增量拉取路径;收本会话 `chat.read` → 更新对端已读回执 UI。
  注意防重入 gotcha(收件箱重入滚动 bug 的教训):事件触发的拉取要合并抖动
  (同会话密集事件只保留一次在飞拉取,复用现有 refreshRequest/generation 防倒退套路)。
- 事件扇出:一个 RealtimeClient 实例服务整个聊天图,inbox 与当前会话各自订阅
  (AsyncStream 单消费者语义——由 ChatUI 层做一对多分发,如 `ChatRealtimeRouter`
  @MainActor 把事件转投给 inbox 与 active conversation;别让两个 VM 抢同一条 stream)。

### 3.3 AppShell 装配与生命周期

- `ChatSessionContext` 增持 realtime 句柄;`ChatSessionController` 的
  activate(coach/student)时创建 RealtimeClient 并 `connect()`,teardown(登出/换绑)时
  `disconnect()`(跟既有 teardown 时序走,不新开生命周期分支)。
- scenePhase:`.background` → `disconnect()`;`.active` → `connect()` + `inbox.refresh()`
  一次(挂在现有 scenePhase 监听处,教练端 `CoachRootView.swift:239-242` 与学员端对应位置)。
- Demo 构建(DEMO_MODE / DemoStudent configuration):聊天走 `InMemoryChatRepository`,
  **不建 RealtimeClient**(装配处按现有 demo 分支跳过),demo 行为保持纯轮询/本地。

## 4. 约束与红线

- 轮询代码是降级态正式路径,不删不弱化;实时路径任何故障的最坏结果 = 回到 1.0(17) 现状。
- 不动 `MeetPRTabBar` / CoachKit 红点消费面——未读数据流不变,只是更新更快。
- SwiftLint `--strict` + swift-format 守仓内配置;新类型全部注入可测
  (sleep/transport 闭包注入,对齐 `ChatInboxViewModel` 现有风格)。
- SPM 单测跑 macOS host:RealtimeClient 别写 `#if os(iOS)` 专属路径
  (scenePhase 接线在 AppShell,Networking 层保持平台无关)。

## 5. 测试与验收

单测(Networking + ChatUI):

1. RealtimeClient 状态机:注入 fake transport——连接成功收 hello → `.connected`;
   断开 → `.disconnected` + 退避重连(fake clock 断言退避序列与封顶);
   `disconnect()` 后不再重连。
2. 解码:三种已知事件正确解出;未知 type / 畸形 JSON 跳过不 throw。
3. Inbox 三态:connected 时轮询挂起(fake sleep 断言不再被调)、事件驱动 refresh;
   转 disconnected 后 30s 轮询恢复。
4. 会话内:本会话事件触发增量拉取;他会话事件不触发;密集事件合并为单次在飞拉取。

端到端实测(backend 032 部署 staging 后;旧 gotcha:同步合成事件测不出真实时序,
必须真双端):

1. 模拟器教练登录,另开学员端(模拟器第二实例或 curl 直发)发消息 →
   教练消息 tab 红点 ≤1s 变化;打开会话,再发 → 气泡 ≤1s 出现。
2. 断网(模拟器断 Wi-Fi 或 Network Link Conditioner)发两条 → 恢复后轮询兜底拉全,不丢。
3. 退后台 → 对端发消息 → 回前台 ≤1s 内追平(重连 + 主动 refresh)。
4. 学员端同样跑一遍 1(方向反转)。

验收证据:模拟器录屏或时间戳截图 + 单测输出,进 PR body。

## 6. 发布

- P1,随 1.0(18) 班车;合并后由 Claude 在 `NEXT-RELEASE.md` 登记(Codex 不写台账)。
- 与 backend 032 无部署时序硬依赖(纯增量、有轮询兜底):iOS 先合后合均可,
  端到端验收在 032 上 staging 后补跑即可。
