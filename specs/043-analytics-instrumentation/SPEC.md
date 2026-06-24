# 043 — Analytics instrumentation(自建一等公民埋点:`Analytics` 叶子模块 + 离线磁盘队列 + ~18 事件接进各 feature 模块)

- **状态**: Draft
- **PR**: TBD(iOS spec PR + iOS impl PR;backend `POST /events` / `events` 表 / `GET /events/config` 由 **backend spec 008-analytics-events** 实装,本 spec 0 backend 工作 — 仅消费 008 提供的端点)
- **来源**:
  - [埋点 wave(brainstorm 定稿 + CEO review 决策)](~/Brain/wiki/projects/MeetPR/analytics-instrumentation-wave.md) — 方案 A(自建 first-party 事件)/ 4 个 founder 分叉 / 5 CRITICAL / 事件收敛 ~18
  - [埋点 wave CEO review(5 lens + codex)](~/Brain/wiki/projects/MeetPR/reviews/analytics-instrumentation-ceo-review.md) — 数据流影子图 / ERROR & FAILURE registry / Day-1 founder dashboard / 18 项 auto-decided / 部署顺序
  - 上游 **backend spec 008-analytics-events**(先行,iOS 依赖它):`events` 表 migration + `POST /events`(批量,await-insert-then-respond + `event_id` UNIQUE + ON CONFLICT)+ `/events` 专属 `express-rate-limit` + `createOptionalAuth` + `GET /events/config`(kill-switch)。**本 spec 启动条件 = 008 全部端点 land 在 staging**
  - 上游 [spec 029 §「e1RM 客户端算、不加 macro endpoint」](../029-coach-student-detail-feedback/SPEC.md) — RepositoryContracts SPM target 既有约定(新 protocol 落 contract target,CoreModels 保持纯数据)
  - 上游 [spec 027 视频上传](../027-video-upload/SPEC.md) — `media_upload` 事件接其上传管线(027 已确认在内测构建,见 §5 #22)
  - 上游 [spec 039 set outcome](../039-set-failed-outcome/SPEC.md) — `set_logged` 的 `outcome:completed|failed` prop 复用 039 的失败标记
  - 上游 [spec 031 invite/bind](../031-invite-bind-pending/SPEC.md) / [spec 032 onboarding wizard](../032-onboarding-wizard/SPEC.md) / [spec 033 接收队列+评估期](../033-evaluation-funnel/SPEC.md) — 事件接线的来源流程
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — `Analytics` 必须是**叶子**:StudentKit / CoachKit / AppShell 可 import 它,它**不反向** import 任一 feature 模块;transport 依赖 `Networking` 可以

## 目标

给内测装一层「刚好够读懂用户行为」的**自建**观测层——不引第三方境外 SDK,数据全留境内自建阿里云后端。内测目标(David 选定):**① 卡点定位**(哪个流程让人困惑/卡住/放弃)+ **② 功能取舍**(哪些功能真被用)。n<50 时核心交付不是聚合漏斗,而是 **per-user 故事时间线**(`SELECT * FROM events WHERE user_id=? ORDER BY ts_client, ts_server, seq`,008 §8 读序契约),由 backend 008 + 本 spec 共同喂出。

**David(founder)看到啥**(本 spec 的产物 = 让这条时间线有数据可读):

```
某学员一次使用 → events 表里一条故事线
  ↓ 19:03 app_open{cold} → screen_view{今日训练}
  ↓ 19:04 workout_log_start{plan_id, source=dashboard}
  ↓ 19:05 set_logged{深蹲, set_index=1, has_video=true, outcome=completed}
  ↓ 19:07 field_re_edit{flow=record_set, field=weight, count=3}  ← 重量改 3 次 = 犹豫
  ↓ 19:08 set_logged{深蹲, set_index=3, outcome=failed}        ← 第 3 组失败
  ↓ 19:08 flow_cancel{flow=record_set, from=今日训练}           ← 显式退出(不是崩溃)
  ↓ (无 workout_log_save) → 后端派生「放弃」兜底
```

**关键:崩溃 vs 困惑可区分**。沉默崩溃与 UX 卡点在时间线里长得一模一样,所以本 spec 装 `client_error` 崩溃捕获(下次启动补发一条),让「app 闪退」与「用户主动退出」在故事线里两种形状。

**摩擦反馈提示(David 加选,超出 CEO 建议 defer)**:同字段改 ≥2 次、或一次 `flow_cancel`/放弃后,弹一句「卡住了?一句话告诉我们」。**两段物理隔离**(David 2026-06-24 决策:质化文本要存):① 发一条 enum-only `friction_feedback` **信号**事件进 events 流(标记"卡点处 + 用户参与了");② 用户键入那句话走**独立** `POST /events/feedback` → backend `analytics_feedback` 表(events 表仍零自由文本,真 gate 不变)。这条就是你当初选 in-app 反馈进 v1 要的**质化 why**。gate 住别 nag(见 §12)。

## 关键复用设计(ADR-005 §1:`Analytics` 是叶子 / 真能用什么 vs 只能参照什么)

> **codex review 纠正**:CEO review 说"复用 Networking BindQueue 磁盘原语别从头造",但核对本仓后:`APIClient+BindQueue.swift` 只是 `/coach/bind-requests` 的 endpoint 包装(不是磁盘队列);`BuildConfig` 只解析 backend base URL(不检测 Demo/Debug);`VideoUploadManager`/`LocalOnboardingDraftStore` 在 **StudentKit** 里——叶子 `Analytics`(ADR-005 §1:只 import CoreModels + Networking)**根本不能 import**。所以下面分清「真能用」与「只能参照、得自己实现」。

**真能用(Networking,可 import)**:

| 用 | 来源 | 用途 |
|---|---|---|
| `APIClient`(`get`/`post`,签名带 `accessToken: String`) | `Networking` | `Analytics` 经它 POST `/events` 与 `/events/feedback`(或加 `APIClient+Events.swift` 扩展) |
| `BuildConfig.backendBaseURL` | `Networking` | 取后端 base URL(**仅此**;Demo 检测**不**走 BuildConfig,走 `#if DEMO_MODE`,见 §10) |
| `OSSPartUploader.Transport` 的 typealias DI **形态** | `Networking` | `Analytics` 的 `EventTransport` 照此 `@Sendable (URLRequest, Data) async throws -> ...` 形态(测试替假传输、live 走 `URLSession`),不新发明传输抽象 |

**只能参照、本 spec 自己实现(StudentKit 的实现叶子进不去,且其能力没我原写的强)**:

| 参照模式 | 来源(进不去) | `Analytics` 自己建什么 |
|---|---|---|
| 「actor + `Documents/*.json` + `.write(.atomic)` + 容错读(坏文件读成 `nil` 不抛)」落盘模式 | `StudentKit.LocalOnboardingDraftStore` | **自建** `EventQueueStore`(actor)落 `Documents/analytics/queue/`,**reimplement**(不 import) |
| 「actor 管任务 + 杀进程后下次启动恢复」结构 | `StudentKit.VideoUploadManager` | **自建** `EventFlusher`(actor)。⚠注意 `VideoUploadManager` **没有** background resume(`recoverInterruptedUploads` 只标 failed)、retry 是**固定 1s 不是 1/2/4/8**——所以 `Analytics` 的 exponential backoff + 启动 resume 是**本 spec 新写的**,不是"复用 027"。 |

> **后果**:离线队列 + 重试 + 落盘三件套是 `Analytics` **自己实现的真子系统**(reimplement,非 import),CEO review 的"半天预算"偏乐观,实际按 ~1.5d 算(spec 043 最大工程量在此)。叶子边界(`Analytics` ⊥ StudentKit)是硬约束。

## 范围

### 做什么

#### 1. 新增 `Modules/Analytics` 叶子 SPM target

`Modules/Analytics/Package.swift`(照 `Networking/Package.swift` 的 leaf 模式:`swift-tools-version:5.10` / `platforms iOS 17 + macOS 14` / `StrictConcurrency` upcoming feature on):

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "Analytics",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "Analytics", targets: ["Analytics"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Networking"),  // transport only(POST /events + GET /events/config)
  ],
  targets: [
    .target(
      name: "Analytics",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "AnalyticsTests",
      dependencies: ["Analytics"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
```

**叶子不变量(ADR-005 §1,本 spec 触发 CI 自检)**:
- `Analytics` **不可** import `StudentKit` / `CoachKit` / `AppShell`。CI grep:`grep -rE "^import (StudentKit|CoachKit|AppShell)" Modules/Analytics/Sources/` 必须空
- `Package.swift` dep 图检查:`Analytics` 的 dependencies 不含任何 feature 模块(只 `CoreModels` + `Networking`)
- 各 feature 模块的 `Package.swift` **加** `Analytics` dep(StudentKit / CoachKit / AppShell);埋点调用写在 feature 模块里**调进** `Analytics`,方向单一

#### 2. 公开 API(`configure` 注入 + 四个 emit 方法 `track`/`screen`/`flow`/`submitFrictionText`,emit 全非 throwing / fail-silent / 不上主线程 / 永不阻塞 UI)

`Modules/Analytics/Sources/Analytics/Analytics.swift`:

```swift
public final class Analytics: Sendable {
  public static let shared: Analytics

  /// 启动注入(AppShell 在 app 启动时调一次)。叶子 Analytics 不能 import AppShell,
  /// 所以 transport / base URL / token 全靠这里注入。
  /// - accessTokenProvider: 可选 token 提供者;有登录态返回 token,否则 nil(pre-login 匿名上报)。
  ///   AppShell 用 `{ await tokenStore.accessToken() }`(`TokenStoring.accessToken() async -> String?`,非 throwing 形态)注入。
  public func configure(
    baseURL: URL,                                   // = BuildConfig.backendBaseURL
    transport: @escaping EventTransport,            // 照 OSSPartUploader.Transport 形态;测试可替
    accessTokenProvider: @escaping @Sendable () async -> String?
  )

  /// 通用打点。non-throwing:内部 try? 吞掉一切;调用方永远拿不到 error。configure 前调 = 入队待发(或丢,见实现)。
  public func track(_ name: AnalyticsEvent, props: [String: AnalyticsValue] = [:])

  /// screen_view 语法糖。
  public func screen(_ screen: AnalyticsScreen)

  /// 流程打点(start/step/cancel/complete)。flow + from_screen 由参数带。
  public func flow(_ flow: AnalyticsFlow, _ step: AnalyticsFlowStep, props: [String: AnalyticsValue] = [:])

  /// 摩擦反馈那句话(§12):走 `POST /events/feedback`(独立于 events 流),与触发的 friction_feedback 信号同 event_id。
  public func submitFrictionText(eventID: UUID, flow: AnalyticsFlow, fromScreen: AnalyticsScreen, trigger: FrictionTrigger, text: String)
}

public typealias EventTransport = @Sendable (URLRequest, Data) async throws -> (Data, URLResponse)
```

> **叶子注入(ADR-005 §1 + CRITICAL #4 编码)**:`Analytics`(只 import CoreModels + Networking)拿不到 AppShell 的 `Session`/`TokenStore`,所以**反过来由 AppShell 注入**:`MeetPRApp`/`AppShell` 启动时 `Analytics.shared.configure(baseURL: BuildConfig.backendBaseURL, transport: …URLSession…, accessTokenProvider: { await tokenStore.accessToken() })`。`accessTokenProvider` 返回 `String?`——有 token 就带 `Authorization`(登录后 server 推 user_id),没有就匿名发(pre-login onboarding 漏斗)。客户端**绝不**自己塞 `user_id`/`role`。方向单一:AppShell → Analytics,Analytics 不反向 import。

**三条硬规矩(ERROR registry 第 1 行:`Analytics.track()` 调用点抛错必须吞)**:
1. **永不 throwing**:四个 emit 方法(`track`/`screen`/`flow`/`submitFrictionText`)签名都不 `throws`。内部一切 IO / encode / 入队失败 `try?` 吞掉。CI / 单测断言「fail-silent never throws to caller」。
2. **不上主线程 / 永不阻塞 UI**:`track` 立刻把事件丢给内部 `actor`(off main thread),调用方 return 不等任何 IO。入队在 actor 内串行。
3. **离线安全**:内存入队 → 磁盘队列落盘 → 联网批量 flush;失败重试到上限即丢。

**`AnalyticsValue`**(props 类型 gate — 这是个 Swift `enum`,只允许 `id(UUID)` / `int` / `bool` / `enumCase(String)` 几种 case,**没有** `.freeText(String)` case):呼应 5 CRITICAL 配套的「props 只准 ID/enum,禁自由文本/值」——客户端类型层面就堵死把用户输入塞进 props。**无例外**:摩擦反馈提示的 `friction_feedback` 事件 props 同样 enum-only(`flow`/`from_screen`/`trigger`),用户键入的自由文本 v1 不入 events 流(见 §12)。

`AnalyticsEvent` / `AnalyticsScreen` / `AnalyticsFlow` / `AnalyticsField` / `AnalyticsFlowStep` / `OnboardingStepName` 等全是 `String`-backed `enum`(allowlist;新增事件/值 = 改 enum,编译期 gate)。**这些 client enum 是 `screen`/`flow`/`field`/`from_screen`/`step_name`/`source`/`tab`/`kind`/`outcome`/`trigger`/`stage`/`context`/`domain` 等值集的单一真源**;backend 008 §8.1 的 zod `z.enum([...])` 逐字镜像同一闭集,**增减同步两边 + bump `schema_version`**。具体种子值集见 [008 §8.1](~/Projects/apps/MeetPR-backend/specs/008-analytics-events/SPEC.md)。

#### 3. 事件信封自动字段(client 设置,除标注外)

每条事件自动带,**与 backend spec 008 SHARED EVENT CONTRACT 逐字段对齐**:

| 字段 | 来源 | 说明 |
|---|---|---|
| `event_id` | **client 生成 uuid** | 每事件一个,server 端 UNIQUE 去重键(CRITICAL #2) |
| `anon_id` | **client,UserDefaults**(非 Keychain) | 每安装一稳定 uuid;卸载即清(PIPL 删除权可辩护,非 Tracking 姿态干净) |
| `user_id` | **server 从 JWT 推**,client 不设 | pre-login NULL;client 即便塞了也被 008 strip/ignore |
| `role` | **server 从 JWT 推**,client 不设 | 同上 |
| `session_id` | client uuid | 进前台生成;后台 **≥30min** 重置(`UIApplication` 生命周期 → 记 background 时间戳,回前台算 delta) |
| `seq` | client | per-session **单调**计数器(从 0 自增);供时钟 skew 时 tie-break 排序 |
| `name` | client | enum allowlist |
| `props` | client | per-event,只准 id/enum,禁自由文本 |
| `app_version` / `build` | client | `Bundle` + `BuildConfig` |
| `platform` | client = `"ios"` | 常量 |
| `ts_client` | client device clock | **不可信**;server 端 tie-break 用 `ts_server`+`seq` |
| `ts_server` | server `DEFAULT now()` | — |

> **POST 信封层级(与 008 CRITICAL #3 对齐)**:flush 时 `anon_id` / `app_version` / `build` / `platform` 一批一致,**提到 batch body 顶层发一份**(不是每事件重复);`event_id` / `session_id` / `seq` / `name` / `props` / `schema_version` / `ts_client` 留 `events[]` 里 per-event。这样 backend 008 的 limiter `keyGenerator` 能从 `req.body.anon_id` 稳定取键。即 body = `{ anon_id, app_version, build, platform, events:[{event_id, session_id, seq, name, props, schema_version, ts_client}] }`。`user_id`/`role` 客户端**绝不发**(008 服务端从 JWT 推)。

`anon_id` / `session_id` / `seq` 状态由 `AnalyticsSessionStore`(actor)持有:
- `anon_id`:`UserDefaults.standard` 读取,缺则生成 uuid 写回(`NSPrivacyAccessedAPICategoryUserDefaults` 已在 `PrivacyInfo.xcprivacy` 声明,无需新增 API reason)
- `session_id` 轮换:监听 `scenePhase` / `UIApplication.didEnterBackgroundNotification` 记 ts;`willEnterForeground` 时若 `now - bgTs >= 1800s` 则新 `session_id` + `seq` 归零

#### 4. 离线磁盘队列(REUSE Networking 原语,做全队列)

`Modules/Analytics/Sources/Analytics/Queue/`:

- **`EventQueueStore.swift`**(actor,**自建 reimplement,不 import StudentKit**)— 参照 `LocalOnboardingDraftStore` 的 `Documents/*.json` + `.atomic` 写 + 容错读(坏文件读成空不崩)模式,自己实现。落盘到 `Documents/analytics/queue/`。
  - **队列上界(auto-decided)**:cap **N=1000** 事件 **/ 7d TTL**,满则 **drop-oldest**(FAILURE registry「离线 N 天 → 队列无界」rescue)。盘满/写失败 → 吞 + 丢,用户无感。
- **`EventFlusher.swift`**(actor,**自建**)— 参照 `VideoUploadManager` 的 actor-管任务结构,但 backoff/resume 是本 spec **自写**(VideoUploadManager 实际**无** background resume、retry 固定 1s):
  - **触发**:① 进前台 ② 联网恢复(`NWPathMonitor`)③ 定时器(周期 flush,默认 ~30s,可调)
  - **批量**:`batch ≤ 50` 事件/POST(**硬上限 = backend 008 §3.1 的 1–50 batch cap;超 50 backend 返 400 `EVENTS_BATCH_TOO_LARGE`,故客户端永不发 >50**)(well under backend `express.json` 1mb 上限);props 单条 `≤4KB`。flush builder 组装顶层信封(`anon_id`/`app_version`/`build`/`platform` 一份 + `events[]` per-event,见 §3 信封层级);同一批必须共享同一 `anon_id`(本就如此,单安装)
  - **413 拆批(CRITICAL #2 客户端侧)**:POST 收 413 → 把该批一分为二重试,**永不 wedge**(FAILURE registry「413 wedge」rescue)
  - **删批仅在 204 ack 后(CRITICAL #2)**:磁盘队列里该批只有收到 **204** 才删(008 成功码就是 204);否则留着重发 → at-least-once 投递 + server `ON CONFLICT(event_id) DO NOTHING` 保证 exactly-once 存储
  - **retry-cap**:**本 spec 自写** exponential backoff(1/2/4/8s)重试到上限即丢该批(避免无限重试风暴)
  - **杀进程安全**:已落盘事件下次启动 resume flush(**自写**启动恢复;`VideoUploadManager.recoverInterruptedUploads` 只标 failed 不续传,不可照搬)

> **预算修正**(codex review):离线队列 + 重试 + 落盘是 `Analytics` **自己实现的真子系统**(StudentKit 的实现叶子进不去、且能力不足),CEO review 的"半天"偏乐观,按 **~1.5d** 估;这是 043 最大工程量,也是最易 rot 区,实装务必配齐 §测试 的队列单测。

#### 5. 把 ~18 事件接进各 feature 模块(本 spec 的体力活)

> 命名 snake_case。下表只列**业务 props**(信封字段见 §3 自动带)。「接线点」= 在哪个 view / flow / 模块里调 `Analytics.shared.track/screen/flow`。

| # | 事件 | props | 接线点(view / flow / 模块) |
|---|---|---|---|
| **A 用量广度** ||||
| 1 | `app_open` | `cold`(bool) | `AppShell` MeetPRApp / RootView 启动 |
| 2 | `screen_view` | `screen` | `AppShell` 路由层统一打(或各根 view `.onAppear`);覆盖 Student + Coach 主屏 |
| **B 录训练闭环(最细)** ||||
| 3 | `workout_log_start` | `plan_id?`, `source`(dashboard/calendar) | StudentKit `TodayWorkout/TodayWorkoutView`(入口) |
| 4 | `set_logged` | `exercise_id`, `set_index`, `has_video`, `outcome`(completed/failed) | StudentKit `TodayWorkout/ExerciseExecutionView`(`outcome` 复用 spec 039) |
| 5 | `workout_log_save` | `n_sets`, `duration_ms` | StudentKit `TodayWorkout/SessionSummaryView`(保存) |
| **C 学员流程** ||||
| 6 | `onboarding_step` | `step_index`, `step_name` | StudentKit `Onboarding/OnboardingWizardView`(spec 032) |
| 7 | `onboarding_complete` | `n_steps_filled`, `used_draft_resume` | StudentKit `Onboarding/OnboardingWizardViewModel`(终点;区分放弃 vs 续填) |
| 8 | `bind_coach_action` | `stage`(invite_open/submitted/accepted) | StudentKit `Bind/EnterCodeView` + `PendingBindView`(spec 031) |
| 9 | `plan_viewed` | `plan_id` | StudentKit 看计划主屏(Dashboard / 计划 tab) |
| 10 | `progress_viewed` | `tab`(e1rm/volume/history) | StudentKit `TrainingHistory/ProgressDashboardView`(spec 028/036) |
| **D 教练闭环** ||||
| 11 | `coach_open_student` | `student_id` | CoachKit `StudentDetail/StudentDetailView`(spec 029) |
| 12 | `coach_feedback_sent` | `student_id`, `kind`(text/video) | CoachKit `StudentDetail` 文本反馈 + `Receiving/VideoFeedbackDetailView`(spec 029/042) |
| 13 | `coach_plan_assigned` | `student_id` | CoachKit `PlanningWorkspace` 下发 |
| 14 | `coach_intake_action` | `stage`(request_seen/accepted_eval/accepted_skip/rejected), `student_id` | CoachKit `Receiving/CoachReceivingView`(spec 033 教练侧) |
| 15 | `eval_summary_action` | `stage`(draft_saved/delivered), `student_id` | CoachKit `Evaluation`(spec 033 评估总结) |
| **E 摩擦/放弃(横切,卡点金矿)** ||||
| 16 | `validation_error` | `flow`, `field` | 各表单校验失败点(onboarding / record_set / bind / planning) |
| 17 | `field_re_edit` | `flow`, `field`, `count`(≥2) | 同字段反复改的 view(record_set 重量 / onboarding 字段) |
| 18 | `nav_back` | `from_screen`, `in_flow`(实践必填) | 流程中途回退(横切;返回手势 / 返回按钮) |
| 19 | `flow_cancel` | `flow`, `from_screen` | **显式**放弃(退出录训练 / 退出 onboarding);替代纯派生 |
| **F 崩溃** ||||
| 20 | `client_error` | `domain`, `code`, `screen` | `AppShell` 顶层 handler;**持久化 + 下次启动 flush 一条**(见 §6) |
| **G 摩擦反馈(David 加选)** ||||
| 21 | `friction_feedback` | `flow`, `from_screen`, `trigger`(re_edit/flow_cancel) | `Analytics/FrictionFeedback.swift` + 轻量 prompt;**enum 信号进 events**;用户键入那句话经独立 `submitFrictionText` → `POST /events/feedback` → `analytics_feedback` 表(见 §12) |
| **F′ 视频上传(027 已确认在内测构建)** ||||
| 22 | `media_upload` | `stage`(started/succeeded/failed), `context`(onboarding/set_log/coach_feedback), `bytes?` | StudentKit `VideoUpload/VideoUploadManager` 的 start/success/fail 回调处打点(`MeetPRApp.swift:166` non-Demo app 已接 `.backend(api:session:)` 视频管线,故 027 在内测构建内);与 008 §8 allowlist 一致,**必接** |

> **放弃信号口径(auto-decided)**:放弃 = **显式 `flow_cancel`** + **后端派生兜底**(有 start 无 save)。abandonment **不另埋**事件——纯派生太噪(混淆切后台/崩溃/续录),显式 `flow_cancel` 是去噪后的强信号。
>
> 表里 **1–22 全部内测必接**:#21 `friction_feedback` 是 David 加选(enum 信号 + 文本走 /events/feedback),#22 `media_upload` 已确认 IN(027 在内测构建);onboarding_complete/coach_intake/eval_summary/flow_cancel/client_error 是 CEO review 新增。核心「~18」是 CEO review 收敛口径,叠加 David/codex 后实为 **22** 个。**事件名 + props 与 backend 008 §8 registry 逐字一致**。

#### 5.1 接线辅助(避免散落 magic string)

各 feature 模块**不**直接拼 props 字典;`Analytics` 暴露强类型 helper(如 `Analytics.shared.flow(.recordSet, .cancel, from: .todayWorkout)`),`flow` / `field` / `screen` 全走 enum。理由:18 个事件散在两个 kit 几十个 view,字符串 typo 会让某条事件永远查不出来(且 server 端 enum allowlist 会 skip 掉,静默)。

#### 5.2 接线的「不污染 feature 逻辑」约束

埋点是**旁路**:feature view 的业务逻辑不因埋点改变控制流。`Analytics.shared.track(...)` 调用是 fire-and-forget 单行,删掉它 feature 仍正确工作(对应 ADR-005 「View 不写业务逻辑」精神 + 叶子模块单向依赖)。

#### 6. `client_error` / 崩溃捕获

`Modules/Analytics/Sources/Analytics/CrashCapture.swift`。**signal-safety 真 gate(codex review)**:崩溃 handler 内**只能用 async-signal-safe 操作**——`JSONEncoder` / `FileManager` / actor 访问 / Swift 堆分配**全不是 signal-safe**,在 handler 里跑会引入崩溃路径上的未定义行为。所以**不在 handler 里 encode/入队**,改成「预备 → 极简写标记 → 下次启动转事件」三段:

- **启动时预备**(主线程,安全):`open()` 一个预置 fd 指向 `Documents/analytics/crash-marker`,并把 `anon_id`/`session_id`/最后 screen 预渲染成**定长字节缓冲**(随 screen_view 更新这块缓冲,纯内存写)。装 handler:`signal()` 捕 `SIGABRT/SIGSEGV/SIGILL/SIGBUS/SIGFPE/SIGTRAP` + `NSSetUncaughtExceptionHandler`(后者只盖 ObjC 异常)。
- **崩溃瞬间**(handler 内,async-signal-safe):只做一次 `write(fd, 预渲染缓冲, len)`(raw `write(2)`,signal-safe),写完 re-raise 默认 handler。**不** encode、不碰 actor、不分配。
- **下次启动**:正常路径检测到 crash-marker 存在 → 读出定长字节 → 转成一条正常 `client_error{domain, code, screen}` 事件**走常规入队 flush**(此时在安全上下文,可 encode)→ 删 marker。
- **诚实边界**:`NSSetUncaughtExceptionHandler` **盖不住** Swift `fatalError`/`precondition`/越界(走 `SIGTRAP`/`SIGILL`/`SIGABRT`,靠 signal handler 兜大部分);**后台 watchdog 杀 / OOM 抓不到**。故 `client_error` 是 **best-effort**;补一个「干净退出标志」启发式:启动写 `running` flag、正常 `willTerminate` 清掉,下次启动若发现上次没清 → 补发一条 `client_error{domain: unknown}`(粗粒度兜底)。
- 这一条让 FAILURE registry「录训练崩溃 → 误读成放弃」可区分:时间线里 `workout_log_start` 后跟 `client_error` = 崩溃,跟 `flow_cancel` = 主动退出,什么都没有 = 后端派生放弃。

> **范围(已定,无降级口子——codex review 二轮)**:不引第三方崩溃 SDK(撞「无第三方 SDK」声明)。**本 spec 必做** = 上述 signal-safe crash-marker(`write()` 定长缓冲 + 下次启动转 `client_error`)**作为验收**;「干净退出标志」启发式是它的**补充兜底**(抓 watchdog/OOM 这类 signal 抓不到的),**不是**替代。即崩溃捕获是 043 范围内必交付,不拆 follow-up(与 §验收 `CrashCaptureTests` 一致)。

#### 7. 服务端 kill-switch 客户端(`GET /events/config`)

- `app_open` 时(或启动早期)读 `GET /events/config` → `{ enabled: Bool, sample_rate: Double }`(由 backend 008 提供)
- `enabled == false`:**drain + drop** 磁盘队列、停止一切 emit(`track/screen/flow` 变 no-op)。让 David 远程一键关埋点(坏数据 / 隐私事件 / 管道事故时)
- `sample_rate`:客户端按 `anon_id` 哈希稳定采样(同一安装要么全采要么全不采,避免一条故事线半截);内测 n<50 默认 `1.0`
- config 拉取失败 → 默认 **enabled**(fail-open,与端点 fail-open 一致;别因 config 不可达静默丢内测数据)

#### 8. `PrivacyInfo.xcprivacy` 字面 plist diff(CRITICAL #5)

现状 `MeetPR/PrivacyInfo.xcprivacy` 的 `NSPrivacyCollectedDataTypes` 数组含 `AudioData` + `PhotosorVideos`,`NSPrivacyTracking=false`。本 spec 在 `NSPrivacyCollectedDataTypes` 数组**追加三个 `<dict>`**(ProductInteraction + DeviceID + **OtherUserContent**;`NSPrivacyTracking` 保持 `false`,`NSPrivacyTrackingDomains` 保持空数组):

```xml
		<!-- ↓↓↓ APPEND inside existing <key>NSPrivacyCollectedDataTypes</key><array> ↓↓↓ -->
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeProductInteraction</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeDeviceID</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeOtherUserContent</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
				<string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
			</array>
		</dict>
		<!-- ↑↑↑ END append ↑↑↑ -->
```

- **`ProductInteraction`**:`Linked=true`(关联 user_id)、`Tracking=false`、Purposes = `[Analytics, AppFunctionality]` — 即 ~18 个行为事件
- **`DeviceID`**:`Linked=true`、`Tracking=false`、Purpose = `[Analytics]` — `anon_id` 是 dev-assigned id(开发者自分配的安装标识,不是 IDFA),归此类型
- **`OtherUserContent`**(David 2026-06-24 决策存质化文本后**新增**):`Linked=true`、`Tracking=false`、Purposes = `[AppFunctionality, Analytics]` — in-app 摩擦反馈用户**主动键入**的那句话(落 backend `analytics_feedback` 表,backend 008 §4b)。这是本 wave 唯一的 User Content 收集面,故声明此类型;若 founder 改回不存文本(§开放问题),删此 `<dict>`。
- `NSPrivacyTracking` **保持 false**(无跨 App / 广告追踪);`NSPrivacyAccessedAPITypes` 的 `UserDefaults`(`CA92.1`)已在文件里,`anon_id` 存 UserDefaults 不需新增 API reason

> ⚠️ App Store Connect 隐私问卷必须**同步**勾选**全部三类**(与 plist 三个 dict 一一对应,否则问卷与 manifest 漂移):**Usage Data / Product Interaction**(用途 Analytics + App Functionality)、**Identifiers / Device ID**(`anon_id`,用途 Analytics)、**User Content / Other User Content**(摩擦反馈文本,用途 App Functionality + Analytics);三者 **Tracking 全 = 否**。这是运维动作(不进代码),但与本 plist 一同在「带埋点的 TestFlight 构建上传前」完成(部署顺序 §部署)。

#### 9. PIPL 告知(Notice-only + 隐私政策文案)

founder 分叉 = **Notice-only + 改隐私政策**(非 explicit opt-in,不打折 n<50 样本)。在 **onboarding 前/时**披露一段隐私政策文案,内容覆盖:
- 收集**使用分析**(行为事件 = 屏幕/动作/摩擦信号,enum/id,**非**输入内容)
- 收集**你主动填写的反馈文本**(in-app「卡住了?一句话告诉我们」你打的那句话)—— David 决策存质化文本后**必须披露**(对应 PrivacyInfo 的 User Content 声明,§8);若改回不存文本则删此条
- **为什么**:改进产品、定位卡点
- 数据**留境内自建阿里云**(不出境、无第三方统计 SDK)
- **90 天 TTL**(retention,backend 008 文档化 + 删除路径;events 与 analytics_feedback 同)
- **删除路径**:卸载即清 `anon_id`;账号删除时 events 的 `user_id` 走 `ON DELETE SET NULL`、`analytics_feedback` 行**硬删**(User Content 须完整删除),用户可请求删除

文案展示位(**已钉死**,codex review 二轮纠正):**AppShell 首启动一次性 notice**(在 `AppShell` 启动 / 登录注册层,**角色无关**,登录前展示),**不**放 StudentKit onboarding 首屏。理由(codex 对):① `app_open`/`screen_view` 在 AppShell 启动就打点,**早于** onboarding——放 onboarding 首屏会"先收集后告知";② 教练用户**根本不走** StudentKit onboarding,放那里教练永远看不到 notice 却在被收集。**收集前置 gate**:notice 未展示/未确认前 `EventFlusher` **不 flush**(事件可本地入队,但不离开设备),notice 展示后才开闸——保证"告知先于任何数据离开设备",且覆盖 student + coach 双角色。落位:`AppShell` 首启动(UserDefaults 一次性标志),一行 notice +「隐私政策」链接。

#### 10. Demo 构建 HARD disable

Demo 构建检测走 **`#if DEMO_MODE`** 编译标志(`MeetPRApp.swift:29` 现用的同一机制;**不是** `BuildConfig`——它只解析 base URL)。Demo 下 `Analytics` 编译/运行为 **no-op**:`track/screen/flow/submitFrictionText` 直接 return,**数据永不离开设备**(连磁盘队列都不写)。避免演示数据污染真实内测时间线。

> 实现取向:`Analytics.shared` 在 Demo 下注入 no-op 内核(internal `kind: .live / .noop`),公开 API 形态不变(调用点无需 `#if`)。与 CEO review「Demo HARD disable(或 tag build='Demo' 默认 WHERE build NOT LIKE 'Demo%'」二选一——本 spec 取 **HARD disable**(更强:数据根本不产生),backend 默认过滤是第二层保险。

#### 11. DEBUG verbose mode + e2e 验证仪式

- **DEBUG verbose**:Debug 构建下,每次 `track` / 每次 flush 打印一行(事件名 + props + flush 的 batch size + server 返回状态码)。让实装期肉眼可验「事件确实发出、server 确实收下」
- **e2e 验证仪式**(扩 `e2e-smoke`):
  1. `build_run_sim`(真内测构建,**非** Demo)起模拟器
  2. 跑一遍 `workout_log` 闭环(start → set_logged → save)
  3. backend `SELECT name, props, ts_client FROM events WHERE anon_id=? ORDER BY ts_client, ts_server, seq` 看到完整序列(008 §8 读序契约)
  4. 断言 `event_id` 唯一、`seq` 单调、`user_id` 登录后非空 / pre-login 为 NULL
- 这一步与 backend 008 的 e2e-smoke(emit → assert rows)对接;部署顺序见 §部署

#### 12. 摩擦反馈提示(in-app friction feedback,David 加选进 v1)

`Modules/Analytics/Sources/Analytics/FrictionFeedback.swift` + 一个轻量 SwiftUI prompt:
- **触发**:同一 `field` `field_re_edit.count ≥ 2`,**或**一次 `flow_cancel` / 放弃
- **UI**:底部一句「卡住了?一句话告诉我们」+ 单行输入 + 「发送 / 跳过」
- **写入(两段物理隔离)**:
  1. **信号**:弹窗触发即记一条 **`friction_feedback` 事件**(`props: { flow, from_screen, trigger:(re_edit|flow_cancel) }`,**enum-only**,经 `Analytics.shared` 同一队列进 `/events`,与 backend 008 §8 registry 逐字一致)—— "提示触发 + 用户参与"的信号。`AnalyticsValue` 类型层面堵死自由文本,这条永远不带那句话。
  2. **那句话**(David 2026-06-24 决策要存):用户点「发送」→ 经**独立** API `POST /events/feedback`(backend 008 §4b)上报 `{ event_id(=信号事件 id), anon_id, session_id, flow, from_screen, trigger, text, ts_client }` → 落 backend `analytics_feedback` 专表(events 表零自由文本不变;靠 `event_id` 与信号 join)。这条**不**走 `Analytics.track`(那是 enum-only 通道),走 `Analytics` 内一个**单独**的 `submitFrictionText(...)` 方法(同样复用离线队列 + fail-silent + 204-后删,但打到 `/events/feedback`)。`text` 客户端侧 trim + `≤500` 字符截断(与 008 zod 对齐)。
- **gate 住别 nag(关键)**:
  - 每 session 最多弹 **1 次**;同一 flow 整个内测期最多弹 N 次(可配)
  - 用户「跳过」→ 只记信号事件(`friction_feedback`),**不**发 `/events/feedback`(无文本可发);跳过后冷却(记 UserDefaults 时间戳,X 天内不再弹)
  - kill-switch `enabled=false` 时连带关闭(信号 + 文本都停)

> ⚠️ 摩擦反馈提示是用户**主动**输入的反馈(非埋点抓取)。**v1 收集这句话**(David 决策),但严格隔离:信号(enum)进 `events`,自由文本进**独立** `analytics_feedback` 表(backend 008 §4b,本观测层唯一自由文本路径)。因此 **PIPL 文案必须覆盖"你主动填写的反馈文本会被收集用于改进产品"**(见 §9),`PrivacyInfo.xcprivacy` 须声明 **User Content** 数据类型(见 §8)。两表 90d TTL + 账号删除时硬删 feedback(008)。

### 不做(本 spec)

- ❌ **Metabase 自托管 / session-replay-lite 消费层**:beta 先 stored SQL(backend 008 + David 手跑 Day-1 dashboard);超过约每日手跑再上 Metabase(阿里云自托管是真运维 + 默认凭据 foot-gun)
- ❌ **比赛模式 instrumentation**:meetcard「比赛模式」端口埋点 V0.2+
- ❌ **readiness-timer 内部交互**(spec 030)/ **视频播放器内部交互**(029/042 倍速等):颗粒过细,不进 v1
- ~~`media_upload` 门控~~ **已确认 IN**(codex review:`MeetPRApp.swift:166` non-Demo app 已接 backend 视频管线,027 在内测构建内)→ 已移到 §5 表 #22 必接,与 008 §8 allowlist 一致。
- ❌ **后端工作**:`POST /events` / `events` 表 / `GET /events/config` / zod / limiter / optional-auth 全归 **backend spec 008**,本 spec 仅消费
- ❌ **聚合漏斗 UI / 留存激活分析**:n<50 不做,直接读 per-user 时间线;留存回访直接问
- ❌ **`events` 表当成 PD-007 网页 macro-analytics 面**:events 是可替换的内测 seed,**不** gold-plate 成长期分析栈(`schema_version` 留 forward-compat 接口即可,无 event_version)

## 5 个 CRITICAL — 客户端侧必须编码(server 侧在 backend 008)

| # | CRITICAL | 客户端侧本 spec 编码点 |
|---|---|---|
| 1 | await-insert-then-respond(server await DB insert → 204 / 5xx) | 客户端**只在 204 后删批**;收 5xx 留批重试。客户端不能假设「发出去就 = 存了」 |
| 2 | `event_id` UNIQUE + ON CONFLICT DO NOTHING(at-least-once 投递 + exactly-once 存储) | 客户端**生成 `event_id`**;删批仅在 **204** ack 后(008 成功码);**413 → 拆批**重试不 wedge |
| 3 | `/events` 专属 limiter(keyed on anon_id)+ TRUST_PROXY + fail-open | 客户端**永不被 429 踢出真 app**;若真收 429(理论不该)按 fail-open 当临时失败留批,不影响用户。client 侧不重试风暴(retry-cap + backoff) |
| 4 | `createOptionalAuth`(token 有则填 user_id,无则 NULL,**永不 401**) | 客户端**pre-login 照常 emit**(onboarding/bind 漏斗 token 还没有);带上 token(若有),**绝不**自己塞 user_id/role(server 会 strip) |
| 5 | `PrivacyInfo.xcprivacy` 字面 plist diff(ProductInteraction+DeviceID+**OtherUserContent**,Tracking=false)+ PIPL notice | 见 §8 字面 diff(三个 dict)+ §9 PIPL 文案;TestFlight 带埋点构建前完成 |

## 其它锁定决策(auto-decided,无 founder 分叉)

- 离线磁盘队列 = **做全队列**,**Analytics 自建** `EventQueueStore`/`EventFlusher`;只复用 Networking 可 import 的 `BuildConfig.backendBaseURL` / `APIClient` / `OSSPartUploader.Transport` 形态;StudentKit 的 `LocalOnboardingDraftStore`/`VideoUploadManager` 仅作**参照模式**(叶子进不去,见 §关键复用设计)
- 队列 cap **N=1000** 或 **7d TTL**,drop-oldest;batch **≤50** 事件/POST(硬上限 = backend 008 1–50 cap,超则 400;well under 1mb);props 单条 **≤4KB**;**413 → 拆批**
- `anon_id` 存 **UserDefaults**(非 Keychain)
- `client_error` / 崩溃捕获:顶层 handler,持久化 + 下次启动 flush 一条
- kill-switch `GET /events/config {enabled, sample_rate}`,`app_open` 读;disabled → drain+drop+停 emit
- Demo 构建 **HARD disable**(no-op,数据永不离开设备)
- `schema_version`:per-event 带版本字段供 forward-compat(events 是可替换 seed,不 gold-plate)。**只有 `schema_version`**——backend 008 信封/zod 无 `event_version`,客户端发它会被 strict 拒(codex review 移除)
- 摩擦反馈提示发 enum-only `friction_feedback` 信号进 events 流(David 加选进 v1);**用户键入那句话存进独立 `analytics_feedback` 表**(走 `POST /events/feedback`,David 2026-06-24 决策;events 表仍零自由文本)+ PrivacyInfo 加 User Content + PIPL 文案披露反馈文本收集;gate 住别 nag

## 测试(镜像既有 harness — Swift Testing `@Test` / `#expect`)

`Modules/Analytics/Tests/AnalyticsTests/`:

| 文件 | 覆盖 |
|---|---|
| `EventQueueStoreTests` | **冷启动队列持久化**:入队 → 模拟杀进程(新建 store 实例读同目录)→ 事件还在;cap N=1000 drop-oldest;7d TTL 丢旧;坏文件读成空不崩 |
| `EventFlusherTests` | **联网恢复 flush**(注入假 transport,offline → online 触发);**retry-to-cap-then-drop**(transport 持续失败 → backoff → 到上限丢批);**删批仅在 204 后**(非 2xx 留批);**413 → 拆批**重试 |
| `AnalyticsSessionStoreTests` | **session 30min 重置**(注入 clock,background 1800s+ → 新 session_id + seq 归零;<1800s 不重置);**anon_id 跨启动稳定**(新 store 读同 UserDefaults → 同 id);`seq` 单调自增 |
| `AnalyticsAPITests` | **fail-silent never throws**:transport / encode / IO 注入抛错 → `track/screen/flow` 不传播 error;Demo no-op 内核下 `track` 真 no-op(0 落盘) |
| `KillSwitchTests` | `enabled=false` → drain+drop 队列 + 后续 emit no-op;config 拉取失败 → fail-open(照常 emit);`sample_rate` 按 anon_id 稳定采样 |
| `CrashCaptureTests` | `client_error` 持久化 → 下次启动随队列 flush(用注入 store 验落盘,不真 crash 进程) |
| `FrictionFeedbackTests` | 触发条件(re_edit≥2 / flow_cancel);per-session 1 次上限;跳过冷却;kill-switch 连带关;**发送 → enum 信号进 /events + 文本经 `submitFrictionText` 打到 /events/feedback(注入假 transport 断言 body 含 text + event_id 与信号一致)**;**跳过 → 只发信号、不打 /events/feedback**;text >500 字符客户端截断 |

CI 两层叶子自检(per ADR-005,镜像 029 的 CoachKit⊥StudentKit 自检):
- `grep -rE "^import (StudentKit|CoachKit|AppShell)" Modules/Analytics/Sources/` 必须空
- `grep -F "\"StudentKit\""`(及 CoachKit/AppShell)`Modules/Analytics/Package.swift` 必须空

## 验收

- [ ] `Modules/Analytics` 叶子 target 建成;`swift build` + `swift test`(Analytics)绿;CI 两层叶子自检过
- [ ] 四个 emit 方法(`track`/`screen`/`flow`/`submitFrictionText`)non-throwing / off-main / fail-silent;`configure` 注入 transport+token provider;`AnalyticsAPITests` 覆盖「never throws」
- [ ] `anon_id`(UserDefaults,跨启动稳定)/ `session_id`(≥30min background 重置)/ `seq`(per-session 单调)/ `event_id`(每事件 uuid)信封字段齐,与 backend 008 SHARED EVENT CONTRACT 逐字段对齐
- [ ] 离线队列冷启动持久化 + 联网 flush + retry-to-cap-then-drop + 413 拆批 + 删批仅 204 后,`EventQueueStore`/`EventFlusher` **自建**(只复用 Networking baseURL/transport/APIClient,StudentKit 仅参照),单测覆盖
- [ ] ~18 事件全接进 feature 模块(§5 表逐行);`set_logged.outcome`(039)/ `nav_back.in_flow` / 显式 `flow_cancel` 在内
- [ ] `client_error` 崩溃捕获:持久化 + 下次启动 flush 一条
- [ ] kill-switch:`enabled=false` → drain+drop+停 emit;`sample_rate` 稳定采样;config 失败 fail-open
- [ ] 摩擦反馈提示:re_edit≥2 / flow_cancel 触发,gate 住不 nag(per-session 1 次 + 冷却),发 enum 信号 `friction_feedback` 进 events;用户键入那句话经 `submitFrictionText` → `POST /events/feedback` → `analytics_feedback` 表(events 表零自由文本);跳过则只发信号不发文本
- [ ] `PrivacyInfo.xcprivacy` 字面 plist diff(ProductInteraction+DeviceID+OtherUserContent 三个 dict,Tracking=false)已合;`NSPrivacyTracking` 仍 false;App Store Connect 隐私问卷同步勾**三类**:Usage Data(Product Interaction)+ Identifiers(Device ID)+ User Content,Tracking 全否
- [ ] PIPL notice 在 **AppShell 首启动**(角色无关、登录前)展示一次(90d TTL + 删除路径);**未展示前不 flush**(收集前置 gate),student + coach 双角色都覆盖
- [ ] Demo 构建 HARD disable:`build_run_sim`(MeetPR-Demo,**configuration=Demo**)起来,埋点全 no-op,0 落盘
- [ ] DEBUG verbose mode 打印每 track/flush + server 状态
- [ ] e2e 验证仪式跑通:真构建跑 workout_log 闭环 → `SELECT ... ORDER BY ts_client, ts_server, seq` 看到完整序列(对接 backend 008 e2e-smoke)
- [ ] 启动条件:backend 008 全部端点(`POST /events` / `GET /events/config`)land staging(curl 验过)

## 已解决的设计问题(原开放问题,现已钉死)

- ~~**PIPL notice 文案落位**~~ **已钉死(codex review 二轮)**:AppShell 首启动一次性 notice(角色无关、登录前、flush 前置 gate),不放 StudentKit onboarding 首屏(否则先收集后告知 + 教练看不到)。见 §9。
- ~~**`friction_feedback` 质化文本是否 v1 持久化**~~ **已定(David 2026-06-24):存**。用户键入那句话经独立 `POST /events/feedback` → backend `analytics_feedback` 专表(008 §4b),events 表仍零自由文本。配套已落:PrivacyInfo 加 User Content(§8)、PIPL 文案披露反馈文本收集(§9)、90d TTL + 账号删除硬删 feedback(008)。
- ~~**`media_upload` 门控**~~ **已确认 IN**(`MeetPRApp.swift:166` 已接 backend 视频管线)→ §5 表 #22 必接。

本 spec 无悬而未决的 founder 分叉。

## 部署顺序(与 backend 008 协同;本 spec 第 5-6 步是 iOS 侧)

1. backend 008:`events` 表 migration 合 staging + 手 psql 验 `\d events` + 索引
2. backend 008:`POST /events` + `GET /events/config` 部署 staging,e2e-smoke(emit→assert rows)
3. backend 008:同 migration 上生产 RDS
4. **iOS 043:`PrivacyInfo.xcprivacy` 字面 diff + App Store Connect 隐私问卷 + PIPL 隐私政策文案**
5. **iOS 043:`Analytics` 模块 + 接线 + 验证仪式跑通**
6. 才切**带埋点的 TestFlight 构建**(Demo 构建无埋点不受影响)

## 上游 / 下游

**上游**:backend spec 008-analytics-events(硬前置)/ spec 027(`media_upload` 接其上传管线,已确认 IN)/ spec 039(`set_logged.outcome`)/ spec 031·032·033(接线来源流程)/ ADR-005 §1(叶子边界)

**下游**:
- backend Day-1 founder dashboard(stored SQL,backend 008 交付)+ 超量后 Metabase 自托管(运维,defer)
- V0.2+:比赛模式埋点 / readiness 内部 / 视频播放器内部交互 / 网页 macro-analytics(PD-007,events 表**不**升级为此面)

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-24 | 0.1 | 起草。`Analytics` 叶子 SPM target(三口 non-throwing API)+ anon_id(UserDefaults)/session(≥30min)/seq/event_id 信封 + 离线磁盘队列 REUSE Networking BindQueue/OSSPartUploader/LocalOnboardingDraftStore/VideoUploadManager 原语 + ~18 事件接进 feature 模块 + client_error 崩溃捕获 + kill-switch + 摩擦反馈提示(David 加选)+ PrivacyInfo 字面 plist diff(ProductInteraction+DeviceID)+ PIPL notice + Demo HARD disable + DEBUG verbose + e2e 仪式。5 CRITICAL 客户端侧编码。依赖 backend 008 | Claude |
| 2026-06-24 | 0.2 | David 决策质化反馈要存:摩擦反馈那句话经 `submitFrictionText` → `POST /events/feedback` → backend `analytics_feedback` 表(events 表仍零自由文本);PrivacyInfo 加 `OtherUserContent` + PIPL 文案披露反馈文本收集 + 测试/验收/开放问题同步 | Claude |
| 2026-06-24 | 0.3 | 同步 008 review-loop 契约改动:POST 信封 `anon_id`/`app_version`/`build`/`platform` 提 batch 顶层(对齐 008 limiter key 修正)+ §2 标明 client enum 是值集单一真源、008 §8.1 镜像 | Claude |
| 2026-06-24 | 0.4 | review-loop 轮1 codex 7 BLOCKER+2 nit 全采纳:复用设计纠偏(BindQueue/BuildConfig/VideoUploadManager 实情 + 叶子进不去 StudentKit→自实现队列)；加 `configure()` 注入 API(transport+token provider)；PrivacyInfo 三个 dict(+OtherUserContent)全处一致；media_upload 改必接;崩溃捕获改 signal-safe 标记方案;PIPL notice 落位钉死 onboarding 首屏;删 event_version;ORDER BY ts→ts_client,ts_server,seq;2xx→204;Demo 检测改 #if DEMO_MODE | Claude |
| 2026-06-24 | 0.5 | review-loop 轮2 codex 3 BLOCKER+4 nit 全采纳:锁定决策/验收的"REUSE Networking 原语"残留改成自建;**PIPL notice 改 AppShell 首启动**(onboarding 首屏漏教练 + 先收集后告知)+ flush 前置 gate;崩溃捕获去掉降级口子定为必做验收;残留 2xx→204、ORDER BY seq→全序、media_upload 门控残留、"三口"→四方法 全清 | Claude |
| 2026-06-24 | 0.6 | review-loop 轮3 codex 1 BLOCKER 采纳:ASC 隐私问卷同步说明 + 验收补 Identifiers/Device ID(与 plist 三个 dict 一一对应,Tracking 全否) | Claude |
