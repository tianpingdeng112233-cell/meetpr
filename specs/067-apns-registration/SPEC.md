# SPEC 067 — APNs 接入:注册、授权、前台策略与点按路由(iOS)

- **Status: InReview(implementation complete 2026-08-03)**
- **级别**: T2(app target 能力变更 + AppShell + 双端路由)。**P1**,base = `release/1.0`
  (spec 066 已合并,PR #305),随后续班车。
- **来源**: 教练零感知专项 APNs 波。服务端为 backend **spec 033**(六类推送内容与
  custom payload 契约以其 §2 为准)。
- **拍板变更登记**: 本 spec 取代 spec 031 D9「V0.1b 无 APNs」——
  `PendingBindView.swift:9` 等三处「no push」注释一并更新。

## 0. 现状锚点

- 全仓零推送代码:无 entitlements 文件、无 `UIApplicationDelegateAdaptor`、
  `MeetPRApp.swift` 纯 SwiftUI App、Info.plist 无 UIBackgroundModes。
- token 注册端点已存在:`POST /devices/token`(hex token,全角色可调)。
- 签名 team 28JW4SA779;pbxproj 结构性修改用 ruby gem(xcodeproj),别手编
  (仓内既有纪律);Xcode 自动回写的 pbxproj 噪声不 commit。

## 1. 目标与非目标

### 1.1 目标

- 教练/学员两端登录后完成:通知授权请求 → `registerForRemoteNotifications` →
  device token 上报 `POST /devices/token`。
- 前台策略:聊天推送在 app 前台**不弹横幅**(WS 实时已上屏,弹了是双重打扰);
  其余五类前台照弹横幅。
- 点按路由:聊天推送 → 消息 tab 并打开目标会话;其余 → 对应 tab(缺练/破PR/顺延 → 学员 tab,
  视频 → 消息 tab,绑定申请 → 学员 tab)。冷启动与热启动都要能路由(冷启动存 pending route,
  等 root 图装配完再消费)。

### 1.2 非目标

- ❌ 精确桌面角标(backend 不下发 badge,本波不做 setBadgeCount)。
- ❌ 通知设置页/分类开关(V2)。
- ❌ 静默推送(content-available)、Notification Service Extension(富媒体)——不做。
- ❌ Demo 构建:不请求授权、不注册(装配处按 DEMO_MODE 分支跳过)。

## 2. 实装范围

| 位置 | 改动 |
|---|---|
| app target | 新增 `MeetPR.entitlements`(`aps-environment`,Debug=development / Release·Demo 按签名自动);pbxproj 挂 entitlements + push capability(ruby gem 改) |
| `MeetPRApp.swift` | `@UIApplicationDelegateAdaptor` 挂轻量 AppDelegate,仅接
  `didRegisterForRemoteNotificationsWithDeviceToken` / `didFailToRegister`(token → hex 字符串转发给 PushRegistrar) |
| Networking | `APIClient+Devices.swift`:`registerDeviceToken(hex, accessToken:)` 调 `POST /devices/token` |
| AppShell 新增 `PushRegistrar` | @MainActor:登录会话激活后 ①`UNUserNotificationCenter.requestAuthorization(.alert,.sound,.badge)`(拒绝则静默,不闹)②`registerForRemoteNotifications()` ③收到 token 后带 `SessionStateReader.accessToken()` 上报;token 变化/重登录重报;登出不删 token(服务端 410 自清,与 0042 设计一致) |
| AppShell 通知委托 | `UNUserNotificationCenterDelegate`:`willPresent` 按 §1.1 前台策略(读 custom `kind`;`chat_message` 且 app 前台 → `[]`,其余 → `.banner,.sound`);`didReceive` 解析 kind + ids → 路由意图 |
| 路由 | 路由意图注入 Coach/Student root(教练端 4 tab 常驻 ZStack,切 tab = 改 selection;聊天深链复用既有「从收件箱开会话」路径);冷启动 pending route 在 root 图 ready 后消费一次 |
| 注释更新 | `PendingBindView.swift:9` 等「no APNs」注释改为指向本 spec |

授权请求时机:登录成功进入 root 后首次出现时请求(不在启动页拦路);已拒绝过的不重复骚扰
(读 `notificationSettings` 判断)。

## 3. 约束与红线

- **Payload 是数据不是指令**:路由只认白名单 `kind` + UUID 字段,非法值静默丢弃。
- 推送与 WS 双通道并存:同一条消息可能「WS 已上屏 + 通知中心还挂着横幅」——可接受,
  点横幅进会话即消,本波不做通知撤回(`apns-collapse-id` 已在服务端做同会话折叠)。
- SPM 测试跑 macOS host:UN* API 的接线薄壳放 app target/AppShell 平台门内,
  核心逻辑(payload 解析→路由意图、token hex 转换、注册状态机)抽纯函数/纯类型单测。
- pbxproj 改动最小化;签名仍 automatic(28JW4SA779)。

## 4. 测试与验收

单测:payload→路由意图解析(六类 kind + 非法 payload 丢弃);token Data→hex;
PushRegistrar 状态机(授权拒绝/token 上报失败重试下次激活)。

真机验收(APNs 模拟器不可靠,必须真机;backend 033 上 staging 且 `APNS_ENV` 与装法匹配):

1. 教练真机登录 → 设置里可见通知权限已请求;`device_tokens` 表有行(SQL 查一眼)。
2. 六类各触发一次,锁屏全部收到、文案正确;点按各自落到正确 tab/会话(冷启动+热启动各验一遍)。
3. 学员端收教练聊天回复推送。
4. 教练 app 前台开着 → 学员发消息:UI 即时更新(WS)且**不弹**横幅;学员传视频 → 前台弹横幅。

## 5. 发布

- 随下一班内测包(APNs 对 TestFlight 走 production 环境,
  切包前确认 SAE `APNS_ENV=production`)。
- 台账由 Claude 落 NEXT-RELEASE.md;Codex 不写。
