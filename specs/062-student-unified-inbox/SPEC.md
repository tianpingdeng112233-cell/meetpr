# spec 062 · 学员端统一收件口：铃直进对话流 + 系统卡混排 + 教练卡改造

> 状态：Draft ｜ 分级：T3（产品形态改动，David 2026-07-25 拍板）｜ 发布节奏：P1
> 需求原话：「学员端的消息接收全放右上角，把计划发布、聊天、教练反馈都塞进聊天框里」
> 前序：spec 058（聊天 W1，已随 1.0(14) 发布）。本 spec **取代** 058 的「铃升级消息中心 sheet + 三行分流」形态（David 自改自板，2026-07-25）。
> 后继：组卡片波（学员发「某一组」给教练）以本 spec 的对话流为画布，排在本 spec 之后。

---

## 1. 三条拍板（2026-07-25，不重新提案）

1. **铃点开直进对话流**。右上角通知铃保持每 tab 常驻；点开不再弹「消息中心 sheet」，直接进入与教练的对话页。计划发布、教练反馈以**系统卡**形式按时间混排在聊天气泡之间，点击各自深链（计划 → 训练 tab；反馈 → 成长 tab，见 §4.3 深链降级）。
2. **系统条目 = 学员端本地拼接**，不是服务器消息。教练侧（iOS + plan-web）看不到系统卡。
3. **「我的教练」卡改造**：从「消息预览卡」改为**教练展示卡**——教练姓名、合作时长（自绑定接受日起算），加「联系教练」按钮，按下进入同一个对话页。

## 2. 为什么系统卡必须本地拼接（硬约束，非偏好）

1.0(14) 已切包并通过外测审核，测试机上跑着的 `ChatMessageKind` 是**无 unknown 兜底的裸 String enum**，且 `ChatMessagesResponseDTO.messages` 整数组合成解码——后端一旦下发第三种 kind，在测老包**整屏聊天记录 + 会话列表双双解码失败**。所以：

- 本 spec **零后端改动、零服务端迁移、零 wire 改动、不动 `ChatMessageKind`、不动 Networking**。（本地状态有一次 plan-seen 迁移，见 §4.5——两处口径一致，别拿本行当「连本地迁移也不许」读。）
- 系统卡的数据源是学员端已有信号（§4），只在渲染层混排。
- 将来若要服务器化（W2+ 与 APNs 一起议），前置条件是先发一个带 unknown-case 兜底的 iOS 包并铺开。

### 2.1 诚实声明：本地拼接的三个固有限制（产品接受，UI 不得掩饰）

1. **计划系统卡的时间不是真实发布时间**。`StudentPlanView` 没有发布时间字段；卡片时间 = **本机首次观察到该计划签名变化的时刻**（app 在前台轮询/刷新时记录）。文案写「发现第 N 周新计划」而非「教练于某时发布」。
2. **换机/重装后计划观察记录清零**（计划事件在本机推导）；反馈卡会从服务端条目重新推导、按 §4.5 规则播种——所以重装后不是"历史清零"，而是"计划卡起点重置、反馈卡按服务端已读态恢复"。
3. **计划信号无教练归属**（`StudentPlanView` 无 coachID）。换绑防串台走观察基线重置（§4.4），不承诺追溯旧教练时期的计划事件。

## 3. UI 结构

### 3.1 对话页

```
┌ ‹返回   王教练 ──────────────────┐
│  [系统卡] 📋 发现第 3 周新计划     │ ← 点击 → 训练 tab
│           7月20日                │    （卡内自带日期）
│  〔教练〕这周深蹲加到 140          │
│  〔我〕收到                  已读 │
│  [系统卡] 💬 教练回复了你的训练反馈 │ ← 点击 → 成长 tab
│           7月22日                │
│  〔教练〕[图片]                   │
├──────────────────────────────┤
│  [📷] [输入消息          ] [↑]   │
└──────────────────────────────┘
```

- 系统卡与聊天气泡明确区分：居中窄卡、带图标、**卡内自带日期行**、无已读回执、无发送者侧向。
- **不引入日期分隔线**。现有 `ConversationTimeline` 顺序渲染消息与 pending、没有日期分组逻辑；本 spec 不添加（系统卡自带日期已够定位，教练端零变化）。
- 排序：聊天气泡按 `seq`（既有语义不动）；系统卡按事件时间戳插入相邻气泡之间；同刻与气泡并列时系统卡在前。
- **混排窗口规则**（分页边界的完整定义）：
  - 系统卡候选集 = 「未曝光的」+「最近 30 天内的」事件（命名常量 `systemCardWindowDays = 30`）。
  - **进页时冻结候选快照**：本次会话的渲染与分页一律使用进页瞬间的候选快照——曝光标记（§4.2）只影响徽标与**下次**会话的候选集，不把卡从当前快照中移除。这保证「超 30 天且此前未曝光」的事件在本次会话里仍能翻页看到，进页即清不与之矛盾。
  - 页面可见期间新到达的事件**追加进当前快照**（并即时按 §4.2 标曝光）。
  - 时间戳落在【已加载最老消息，∞）区间的快照项按时间插入；**晚于最新消息的追加在时间线尾部**。
  - 早于已加载最老消息的快照项**暂不渲染**，向上翻页扩窗后按同规则插入；翻页插入必须保持滚动锚点稳定（验收 §8.4）。
  - **空会话**（零聊天消息）：快照全部渲染，按时间正序。
  - 同刻多张系统卡以**稳定 ID 字典序**为次级排序；plan ID 中 `startDate` 用 **UTC/Gregorian 的 ISO-8601 date-only（`yyyy-MM-dd`）** 规范编码——设备切时区不得改变同一 `Date` 生成的 ID。
  - 每张系统卡有稳定 ID（§5.2），任何扩窗/刷新不得产生重复卡（验收 §8.4）。

### 3.2 通知铃（各 tab header，位置不动）

- **徽标口径有变**（旧：计划未读 + 反馈未读 + 聊天未读；新：**服务端聊天 unread + 本地未曝光系统卡数**）。首启按 §4.5 播种，学员不会看到存量已读事件冒红点。
- 点击行为：直接进入对话页（`NotificationCenterSheet` 退役，§7）。
- 无绑定教练（防御态）：铃不显示。

### 3.3 「我的教练」卡（「我的」tab）

```
┌ 我的教练 ──────────────────┐
│  王教练                     │
│  合作 3 个月（2026-04 至今）  │
│  [ 联系教练 ]               │
└────────────────────────────┘
```

- 姓名：`BindRequest.coachDisplayName`（空则「教练」）。
- 合作时长：`BindRequest.respondedAt` 至今；分档：<1 月「合作 N 天」，≥1 月「合作 N 个月」，≥1 年「N 年 M 个月」；`respondedAt == nil` 显示「合作中」。
- **数据通路要打通**：`respondedAt` 现在**没有**流到卡片——`ActiveCoachContext` 只带 coach ID/name，`BindGateView` 的映射不传时间。本 spec 给 `ActiveCoachContext` 加 `cooperationStartedAt: Date?` 并在 `BindGateView` 映射处填充（纯端上模型，非 wire）。
- 「联系教练」→ 进入对话页（与铃同一 destination 形态，§5.3）。
- **教练介绍/bio：端上与后端均无此字段，W1 不做**（要 bio 需后端字段 + 教练端编辑入口，另立，非目标）。
- 原「最新消息预览」移除。

## 4. 系统卡数据源、已读语义、换绑防串台

### 4.1 事件推导（不复用 unreadCount，按条目推导）

| 系统卡 | 推导 | 事件时间 | 稳定 ID |
|---|---|---|---|
| 发现第 N 周新计划 | 计划签名（`cycleID + weekIndex + startDate`，即现 `DashboardPlanSignature` 的构成）变化时，在本机记一条观察 | 本机首次观察时刻（§2.1） | `plan:<cycleID>:<weekIndex>:<startDate(UTC yyyy-MM-dd)>` |
| 教练回复了你的训练反馈 | **遍历反馈条目本身**（`FeedbackInboxViewModel` 的数据源），每条 feedback 一个事件；**不是**从 `unreadCount` 推导——学员先在成长页读掉详情时，`readAt` 置位会让它从"未读信号"消失，但曝光记录是独立口径 | 反馈创建时间 | `feedback:<feedbackID>` |

- 反馈详情的服务端已读（`readAt`）与系统卡曝光**互不驱动**：成长页读详情不算卡片曝光；卡片曝光不打详情已读。（新徽标口径里 `readAt` 完全不参与计数，它只在 §4.5 播种时被读一次。）

### 4.2 曝光触发（两个时机，状态机需单测锁死）

1. **进入对话页**（`onAppear`）：把当前候选集全部标曝光——不逐卡 `onAppear`，保证「进来红点就清」与渲染窗口无关。
2. **页面可见期间 coordinator 刷新发现新事件**（app 从后台恢复触发 Root 层刷新等；注意现有轮询只刷聊天，计划/反馈的获取时机就是 coordinator reload——本 spec **不新增**计划/反馈轮询）：新事件加入当前快照（§3.1）并**即时标曝光**——不存在「卡已显示但徽标还挂着，要退出重进才清」的窗口。判定「页面可见」复用对话页现有的生命周期信号（`onAppear`/`onDisappear` 配对维护的可见标志），不引入新机制。

### 4.3 深链（W1 降级口径）

- 计划卡 → 训练 tab（现有 `StudentNotificationRoute.plan → .training`）。
- 反馈卡 → **成长 tab（反馈列表）**。现有 `StudentNotificationRoute.feedback` 只切 `.growth` 不携带 feedback ID，直达详情需要新的根级导航状态——**W1 不做**，列表页顶部即最新反馈，损失可接受。直达详情列为后继增强（非目标 §9）。
- 点击卡片只做导航；曝光已在进页时批量发生，无先后顺序问题。

### 4.4 换绑防串台

- **反馈事件按 coachID 过滤**：反馈条目带 coachID，只有 `coachID == 当前 active coach` 的进入候选集。
- **计划事件走基线重置**：观察记录写入时附带「当时的 active coachID」；真实换绑时把非新教练的计划观察全部丢弃，并以当前计划签名重新播种基线。
- **换绑判定不靠钩子语义，靠持久化的 last-active-coach ID**：`BindGateViewModel` 冷启动会经历 `.loading`（coach = nil）→ 当前 coach 的迁移，`willApplyBindingChange` 同样会触发——直接当换绑处理会**每次冷启动都重置基线**。规则：事件 store 持久化 `lastActiveCoachID`；仅当「持久化值非 nil 且 ≠ 新 coachID」才执行重置，nil → coach 视为恢复。
- **钩子接线（marker 模式，不做对象引用传递）**：现状 `RootView` 的 `willApplyBindingChange` 闭包只通知 `ChatSessionController`（RootView.swift:246 附近），而 coordinator 由 `StudentRootView` 在下游内部创建——RootView **拿不到它的引用**，且钩子执行时旧 StudentRootView 可能正在拆除。所以不传引用：`StudentInboxEventStore` 是公开的、UserDefaults-backed（按学员 ID 命名空间），RootView 钩子只**写入一条 coach-change marker**（新 coachID）；coordinator 在下一次加载完当前计划后消费 marker、完成基线重置与重播种。RootView 与 coordinator 各自构造同命名空间的 store 实例，UserDefaults 即会合点。

### 4.5 首启播种（按真实已读态，不吞未读）

「seen-store 空」无法区分升级、新装、换机——三者都满足。所以播种**不按场景判定，按真实已读态逐条推导**，任何场景下都不吞未读：

- **反馈**：`readAt != nil` 的播种为已曝光；`readAt == nil` 的保持未曝光（新设备上服务端真未读的反馈照常亮红点）。
- **计划**：若旧 `DashboardPlanSeenStore` 有记录，**迁移**其已见签名（不是丢弃）；没有（真·新装）则当前签名保持未曝光——与旧版新装首见计划亮红点的行为一致。
- **迁移的是 seen 状态，不是事件**：旧 store 只有「某签名是否已见」、没有历史时间——被迁移为已见的签名**不生成观察记录、不产卡**（否则升级后会冒出一张时间 = 迁移时刻的假「刚发现计划」卡）。
- 声明口径：本 spec 零**服务端**迁移；本地状态有一次 plan-seen 迁移。旧 store 迁移后随 sheet 休眠。

## 5. 架构边界（红线）

### 5.1 ChatUI 注入点的完整契约

现状：`ConversationView` **内部私有持有** `ConversationViewModel`，`ConversationTimeline` 是 private——StudentKit 无法（也不需要）共驾聊天 VM。注入的是**纯数据 + 回调**，聊天 VM 所有权不动：

```swift
// ChatUI 新增（公开；显式 public init——Swift 合成的 memberwise init 是
// internal，缺了它 StudentKit 根本构造不出这个类型）
public struct ChatTimelineDecoration: Identifiable, Equatable, Sendable {
  public let id: String          // §4.1 稳定 ID
  public let date: Date          // 排序键
  public let icon: String        // SF Symbol 名
  public let title: String       // 已本地化文案
  public let dateText: String    // 卡内日期行（调用方格式化）

  public init(id: String, date: Date, icon: String, title: String, dateText: String)
}

// ConversationView 新增便捷 initializer（旧 initializer 原样保留）
public init(
  ...既有参数...,
  navigationTitle: String? = nil,          // nil = 现状 ChatStrings.messages
  decorations: [ChatTimelineDecoration] = [],
  onDecorationTap: ((String) -> Void)? = nil
)
```

- 默认值 = nil 标题 + 空数组 + nil 回调 → **教练端调用点一行不改、行为零变化**（源兼容由保留旧 initializer 保证；验收 §8.3 教练端回归）。
- **标题**：现状 `ConversationView` 没有标题参数、硬编码 `ChatStrings.messages`（ConversationView.swift:46）。新增可选 `navigationTitle`，学员端传教练名，nil 时保持现状。
- `ConversationTimeline` 渲染时把 decorations 按 §3.1 窗口规则与消息合流；点击回调只上抛 ID，路由逻辑全部留在 StudentKit。
- 曝光**不经过** ChatUI（§4.2 在 StudentKit 侧做），ChatUI 不长曝光概念。

### 5.2 状态归属

- 新建 `StudentInboxEventStore`（落 StudentKit，**public**）：观察记录 + seen 记录 + 播种 + coach-change marker，UserDefaults 持久化（模式参照 `UserDefaultsEvaluationSummaryReadStore`），按学员 ID 隔离命名空间。
- 事件推导与徽标计数并入**现有** `StudentNotificationsCoordinator`（注意：它定义在 `DashboardNotificationsViewModel.swift` 内，不是独立文件）。

### 5.3 对话页实例形态

1.0(14) 已发布的形态就是**每 tab 各自持有 conversation destination**（`StudentNotificationHostModifier` per-tab 创建 `ConversationView`），TabView 保留各导航栈、多实例并存是既有现实且工作正常——发送归 session 级 `ChatSendCoordinator`（共享单例）、markRead 幂等（服务端 `GREATEST` 单调）。**本 spec 不改这个结构**；只要求 decorations 数据来自共享的 coordinator 层，保证各 tab 打开时看到同一组系统卡。

## 6. 边界

1. **前教练旧会话**：服务器侧历史保留、成员可读的口径不变（权威 = **backend 仓 `MeetPR-backend/specs/024-coach-student-chat/SPEC.md` D3**；注意本仓 specs/024 是 student-p0-views，编号撞车勿引错）。本统一入口只呈现当前教练对话；不删除不改写历史。
2. **系统卡不跨端**：教练侧任何界面不出现系统卡（§5.1 默认值保证）。
3. **时区**：卡内日期行用设备本地日历格式化；稳定 ID 的日期编码固定 UTC（§3.1）；不引入 gym-day 口径（那是另一专项）。
4. **评估期**：已硬封存，系统卡不含 evaluation 事件。

## 7. 文件级改动清单（已按真实路径核对）

| 文件 | 动作 |
|---|---|
| `Modules/ChatUI/Sources/ChatUI/ConversationView.swift` | `ChatTimelineDecoration` 类型（显式 public init）+ 新便捷 initializer（含 `navigationTitle`）+ timeline 合流渲染（旧 initializer 保留） |
| `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardNotificationsViewModel.swift` | `StudentNotificationsCoordinator`（就在此文件内）：事件推导、徽标新口径、消费 coach-change marker |
| `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/StudentInboxEventStore.swift` | 新建（public）：观察 + seen + 播种 + marker（UserDefaults，按学员隔离） |
| `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/StudentNotificationComponents.swift` | 移除 sheet presenter；铃点击改进对话页；`MyCoachCard`（就在此文件内）改展示卡 |
| `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/NotificationCenterSheet.swift` | 退役（含其内的 `NotificationActionRow`；入口移除，文件休眠一个版本周期，defer≠delete） |
| `Modules/StudentKit/Sources/StudentKit/StudentNotificationRouting.swift` | 铃 → 对话页；系统卡深链复用现有 route（计划 → training，反馈 → growth） |
| `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift` | coordinator 构造处对接同命名空间 event store |
| `Modules/CoreModels/Sources/CoreModels/Chat/ActiveCoachContext.swift` | 加 `cooperationStartedAt: Date?`（纯端上模型） |
| `Modules/StudentKit/Sources/StudentKit/Features/Bind/BindGateView.swift` | 映射处填充 `cooperationStartedAt`（自 `BindRequest.respondedAt`） |
| `Modules/AppShell/Sources/AppShell/RootView.swift` | `willApplyBindingChange` 闭包扩展：写 coach-change marker（§4.4 marker 模式） |
| `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileView.swift` | 教练卡挂载点与时长文案 |
| 测试 | 见 §8 |

## 8. 验收标准

1. `swift test` 全绿 + `swiftlint --strict` 零 error。
2. DemoStudent 模拟器：四 tab 铃直进对话流；系统卡混排位置正确、卡内日期显示；点计划卡到训练 tab、点反馈卡到成长 tab；「我的」tab 教练卡三要素齐全。
3. Demo 教练端模拟器：对话页**无任何系统卡**、标题仍为「消息」、与 1.0(14) 行为一致（回归）。
4. 单测锁死：混排窗口规则（含空会话、事件晚于最新消息、翻页扩窗插入不重复不跳锚、**进页快照冻结后超 30 天旧卡本次会话仍可翻到**）、同刻多卡按稳定 ID 字典序、**ID 日期编码固定 UTC（切时区 ID 不变）**、进页批量曝光清徽标、**页面可见期间 coordinator 刷新发现新事件即曝光**（后台恢复场景）、成长页读详情不影响卡片曝光（反之亦然）、**播种按真实已读态：`readAt == nil` 的反馈在新设备上仍亮红点、旧 plan-seen 记录被迁移且不产假卡**、**冷启动 nil→coach 不触发基线重置（lastActiveCoachID 判定）**、换绑后反馈按 coachID 过滤 + 计划基线重置、时长文案分档（天/月/年/nil）。
5. 全中文、`zh-Hans` 纪律不动。

## 9. 非目标

- 系统卡服务器化 / 新消息 kind（W2+，需 unknown 兜底包先行）
- 反馈卡直达详情页（需新的根级导航状态，后继增强）
- 教练 bio 字段（需后端，另立）
- 日期分隔线（现有时间线无此概念，不引入）
- 计划/反馈的新增轮询（获取时机维持 coordinator reload）
- APNs 推送（W2）；组卡片（后继 wave）；教练端任何 UI 变化
