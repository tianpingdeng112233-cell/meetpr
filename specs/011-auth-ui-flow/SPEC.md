# 011 — iOS Auth UI Flow (Login + Signup → Role-routed RootView)

- **状态**: InReview
- **PR**: TBD
- **来源**:
  - [PRD §5 P0 #24 账号体系](~/Brain/wiki/projects/MeetPR/prd.md) — 手机号注册 + Apple Sign-In + 角色路由
  - Backend [spec 001-auth](../../../MeetPR-backend/specs/001-auth/SPEC.md) — `POST /auth/{register, login, refresh}` 已实装并 merge 进 staging
  - [data-model.md v1.1 §1.1 (User)](~/Brain/wiki/projects/MeetPR/data-model.md) + [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) (User entity, UserRole enum)
  - [ADR-005 §2 App 入口 + 角色路由](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — Session/RootView 已有架构
  - [ADR-003 v4 单角色](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md) — UserRole 单值,signup 时三选一 lock
  - 上游 [spec 003 DesignSystem](../003-design-system-foundation/SPEC.md) — PrimaryButton / MeetPRTextField / Card 等 atom

## 目标

把 [spec 001 bootstrap](../001-bootstrap/SPEC.md) 留下的 `AuthFlowView` 占位（两个假 login 按钮调 `Session.fakeLogin`）替换为**真实手机号 + 密码登录/注册流程**。落地后:

1. 教练 / 学员可以在 simulator 上完成完整 **signup → login → 路由到对应 root view** 的端到端流程
2. Token (access + refresh) + 缓存的 User 持久化到 **Keychain**，app 重启后自动恢复 session（bootstrap）
3. `Session.swift` 替换 `fakeLogin` 为真实 `signup` / `login` / `logout` async 方法，调 backend `POST /auth/*` endpoints
4. 不接 SMS OTP（V1 deferred per backend spec 001-auth），不接 Apple Sign-In（placeholder field 已存，真接入留独立 spec）
5. **完成后是首个真正能 demo 给用户的 iOS UI 流程**（B2B 有教练模式 E2E 路径第 1 步）

> **F-015 aware**：本 spec 不是 coach planning UI，不直接 trigger F-015。但 implementer 应注意：登录后路由进 CoachRootView 仍是 placeholder，真 Coach Planning UI 走 spec 005+。

## 范围

### 做什么

#### 1. AppShell 重构 (`Modules/AppShell/Sources/AppShell/`)

- **替换 `Session.swift`**：删除 `fakeLogin(role:)`，新增 4 个 async 方法：
  - `func bootstrap() async`（app 启动时调用：Keychain 有 token → 乐观 setState(.authenticated(cachedUser)) → 后台 refresh；无 token 或 refresh 失败 → .anonymous + 清 Keychain）
  - `func signup(phone: String, password: String, role: UserRole) async throws`
  - `func login(phone: String, password: String) async throws`
  - `func logout() async`（清 Keychain + 状态归位 + 通知 CoachKit DraftStore.deleteAll() 防跨账号 draft leak — per ADR-009 后果项）
  - 新增 internal: `private let auth: AuthRepository`, `private let tokenStore: TokenStore`
- **替换 `AuthFlowView.swift`**：删除两个 fake 登录按钮，新增 NavigationStack 包含两个子 view：
  - `LoginView`（initial）
  - `SignupView`（push 进入）
- **`RootView.swift`** 已有 routing 逻辑，本 spec **不动**（仅在 bootstrap 完成后 session.state 流转触发原有 `switch user.role`）

#### 2. AppShell 新增文件 (`Modules/AppShell/Sources/AppShell/Auth/`)

| 文件 | 作用 |
|---|---|
| `LoginView.swift` | 手机号 + 密码 + "登录" 按钮 + "没账号? 注册" 链接 |
| `SignupView.swift` | 手机号 + 密码 + 角色 picker (3 选 1) + "注册" 按钮 |
| `AuthFormViewModel.swift` | `@Observable @MainActor`，管 form state + 校验 + 提交；LoginView/SignupView 各自一个 instance（共享同一个 class，mode 通过 enum 区分） |
| `AuthRepository.swift` | `protocol AuthRepository: Sendable` + `NetworkingAuthRepository` 实装 + `InMemoryAuthRepository` mock for tests |
| `TokenStore.swift` | `actor TokenStore: Sendable`，封装 Keychain 读写；test 用 `InMemoryTokenStore` |

#### 3. Networking 模块新增 (`Modules/Networking/Sources/Networking/Auth/`)

补 3 个 endpoint 定义匹配 backend spec 001-auth + DTO:

- `POST /auth/register` body `{ phone, password, role }` → `{ user, accessToken, refreshToken }`
- `POST /auth/login` body `{ phone, password }` → `{ user, accessToken, refreshToken }`
- `POST /auth/refresh` body `{ refreshToken }` → `{ accessToken, refreshToken }`

DTO 类型 (Codable struct) 放 `Modules/Networking/Sources/Networking/Auth/` 子目录，与 `CoreModels.User` 转换通过手写 mapper（避免 Networking 反向依赖 CoreModels 之外的东西）。

**Mapper 默认值** (per review P2 #3) — backend register/login response user payload 是 `{ id, phone, role, createdAt }` 4 字段, 但 `CoreModels.User` (per spec 002) 有 13 字段含 non-optional `unitSystem` 和 `updatedAt`。Mapper 必须为缺失字段填默认, 否则 `JSONDecoder.decode(User.self, ...)` 直接 throw:

| `CoreModels.User` 字段 | 默认值 | 备注 |
|---|---|---|
| `unitSystem` | `.metric` | V1 内部 dogfood 中国用户优先, 后续 profile spec 加切换 UI |
| `updatedAt` | mirror `createdAt` from response | 注册时 createdAt = updatedAt 合理 |
| `name` | `nil` | 本 spec V1 不收 name (per P1 #2 决策), Profile spec 后续加 `PATCH /me` 时填 |
| `appleUserID` / `avatarURL` / `gender` / `birthDate` / `heightCm` / `weightKg` | `nil` | Optional 字段, mapper 一律 `nil` |

#### 4. UI Wireframe

**LoginView**:

```
┌──────────────────────────────────┐
│         MeetPR (logo)            │
│                                  │
│  手机号                           │
│  ┌────────────────────────────┐  │
│  │ +86 13800000000            │  │
│  └────────────────────────────┘  │
│                                  │
│  密码                             │
│  ┌────────────────────────────┐  │
│  │ ••••••••                   │  │
│  └────────────────────────────┘  │
│                                  │
│  [PrimaryButton 登录]              │
│                                  │
│  没账号? [注册]                    │
└──────────────────────────────────┘
```

**SignupView**:

```
┌──────────────────────────────────┐
│         注册账号                   │
│                                  │
│  手机号                           │
│  ┌────────────────────────────┐  │
│  │ +86 13800000000            │  │
│  └────────────────────────────┘  │
│                                  │
│  密码 (≥ 8 字符)                  │
│  ┌────────────────────────────┐  │
│  │ ••••••••                   │  │
│  └────────────────────────────┘  │
│                                  │
│  我是                             │
│  ( ) 教练                         │
│  ( ) 学员 (有教练)                 │
│  ( ) 学员 (自己练)                 │
│                                  │
│  [PrimaryButton 注册]              │
└──────────────────────────────────┘
```

> **`name` 字段不在本 spec V1 范围**（per review P1 #2）：backend spec 001-auth register body 是 `{ phone, password, role }`，不接 `name`。SignupView 不显示 name 字段，留 Profile/Onboarding 后续 spec 引入 `PATCH /me` 后再加。

#### 5. 测试 (`Modules/AppShell/Tests/AppShellTests/Auth/`,新建子目录)

- `AuthRepositoryTests.swift` — `InMemoryAuthRepository` signup/login/refresh 三方法 round-trip + 4 个 error code 映射
- `TokenStoreTests.swift` — `InMemoryTokenStore` save/load/clear roundtrip; Keychain 实装走 `#if os(iOS)` gate（SPM macOS 跑不了 Keychain）
- `SessionTests.swift` — bootstrap (3 路径: 无 token / token+refresh 成功 / token+refresh 失败), signup 状态转换, login 状态转换, logout 清状态
- `AuthFormViewModelTests.swift` — phone valid/invalid, password valid/invalid (8 字符 / 72 byte 边界), role required (signup), error code → toast text 映射
- `AuthFlowSnapshotTests.swift` — ViewInspector: LoginView 渲染 + 切到 SignupView push 导航 + role picker 3 选项

### 不做什么

| ❌ 留 spec / 留 future |
|---|
| **SMS OTP** — backend spec 001-auth 已 defer; iOS 也 defer 到 SMS OTP 后续 spec (留 FOLLOWUP) |
| **Apple Sign-In** — backend 字段 `apple_user_id` placeholder 已存,真接入留独立 spec |
| **WeChat 登录** — 留 V1.5 (PRD §5 P0 #24 显式 defer) |
| **忘记密码 / 改密码** — 留独立 spec |
| **Profile 完整 view** (头像/昵称编辑等) — 留学员/教练独立 onboarding spec |
| **正式 Logout button UI placement** — 本 spec 提供 `Session.logout()` 方法,UI 暴露在哪 (导航栏/设置页) 留对应 root view spec; 验收时用 dev-only 临时按钮 |
| **Token 自动 refresh interceptor** — 本 spec 只手动 refresh (Session.bootstrap 时); 自动 401 → refresh → retry 留 Networking 后续 spec (FOLLOWUP) |
| **Multi-device 处理** — backend V1 单设备 refresh tracking, iOS 端不做特殊 UI; 第二台设备 login 自动让前一台 refresh 失效, 前一台下次启动 bootstrap 失败 → AuthFlowView, 无消息提示 (V1.5 加 "你在另一台设备登录" 提示) |
| **离线模式 / queue requests** — auth 必在线, 离线一律失败 toast |
| **手机号海外区号 picker** — V1 只支持中国大陆 `^1[3-9]\d{9}$`, 海外留 V1.5 |

## 技术要求

继承 spec 002/003/004/005 模式:
- 一个 type 一个文件
- 严格并发 (StrictConcurrency)
- 测试用 Swift Testing (非 XCTest)
- DesignSystem atom 优先复用 (PrimaryButton / MeetPRTextField / Card / Eyebrow)
- import 边界 (per ADR-005 §3):
  - AppShell 允许: Foundation, SwiftUI, Observation, CoreModels, DesignSystem, Networking, CoachKit, StudentKit
  - Networking 允许: Foundation, CoreModels (本 spec **不**新增依赖)
  - **禁止**: AppShell 引 SwiftData (per ADR-005 §4 + ADR-009 例外只给 CoachKit/Planning/, 不给 AppShell)

### Session 接口形状

```swift
// AppShell/Session.swift
@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class Session {
    public enum State: Equatable, Sendable {
        case anonymous
        case authenticating
        case authenticated(User)
    }

    public private(set) var state: State = .anonymous
    @ObservationIgnored private let auth: AuthRepository
    @ObservationIgnored private let tokenStore: TokenStore
    @ObservationIgnored private let onLogout: (() async -> Void)?  // CoachKit DraftStore.deleteAll() injection

    public init(
        auth: AuthRepository,
        tokenStore: TokenStore,
        onLogout: (() async -> Void)? = nil
    ) { ... }

    public func bootstrap() async { ... }
    public func signup(phone: String, password: String, role: UserRole) async throws { ... }
    public func login(phone: String, password: String) async throws { ... }
    public func logout() async { ... }
}
```

### Bootstrap 流程

```
1. Read Keychain: accessToken, refreshToken, cachedUser
2. None present → setState(.anonymous), return
3. All present → setState(.authenticated(cachedUser)) // 乐观, 立即 render
4. Background: try refresh(refreshToken) →
   - success: save new tokens to Keychain
   - **failure dispatch by error type** (per review P2 #4):
     - **401 AUTH_INVALID_REFRESH / AUTH_REFRESH_EXPIRED**: clear Keychain + setState(.anonymous) — token 已失效,只能重登; 静默跳回 LoginView 不弹 toast
     - **网络错误 / 5xx / decode error / timeout** (任何非 401 的失败): **保留** cached User + tokens (不清 Keychain), log `bootstrap_refresh_deferred` warn, 等下次 foreground 或用户主动操作触发再 refresh — 防止地铁信号差/服务器临时挂直接 logout 的差体验
5. (Future spec) GET /me to refresh cached User; V1 minimal: trust cached User until next login
```

### TokenStore (Keychain wrapper)

```swift
public actor TokenStore: Sendable {
    public init(serviceName: String = "MeetPR")
    public func save(access: String, refresh: String) async
    public func saveUser(_ user: User) async  // JSON encode via MeetPRCodec.encoder
    public func accessToken() async -> String?
    public func refreshToken() async -> String?
    public func cachedUser() async -> User?
    public func clear() async
}
```

Keychain accessibility = `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (per review P3 #8) — 允许 background fetch + app 锁屏期间访问, 但 **`ThisDeviceOnly`** 防止通过 iCloud Keychain 同步 token 到其他设备。与 backend V1 单设备 refresh tracking (`users.refresh_token_jti` 单 slot) 模型一致 — 防 iCloud sync 把 token leak 到其他设备造成 reuse-detection 强制 logout。Access group 不设 (V1 单 app)。

### AuthRepository protocol

```swift
public protocol AuthRepository: Sendable {
    func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult
    func login(phone: String, password: String) async throws -> AuthResult
    func refresh(refreshToken: String) async throws -> TokenPair
}

public struct AuthResult: Sendable, Equatable {
    public let user: User
    public let accessToken: String
    public let refreshToken: String
}

public struct TokenPair: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
}
```

`NetworkingAuthRepository: AuthRepository` 调 `Modules/Networking/Sources/Networking/Auth/`。

### AuthFormViewModel 校验规则

- **手机号**: 正则 `^1[3-9]\d{9}$` (中国大陆 11 位 national number); 不通过 → field error "手机号格式不正确"
- **手机号 wire-format 转换** (per review P1 #1): validation regex 匹配用户输入的 11 位国内号码; **提交前 prepend `+86`** 构造 backend 期望的 E.164 格式 (`wirePhone = "+86" + userInput`). Backend `^\+[1-9]\d{7,14}$` 验 E.164, 例: 用户输 `13800000001` → 网络层发 `+8613800000001`. Response 里 `User.phone` 也是 E.164 形态 (`+86…`), 与原始用户输入做相等比较时必须用 wire form. 转换在 `NetworkingAuthRepository` 里做 (UI 层不感知 wire form), `InMemoryAuthRepository` mock 可选直接接受 raw 11 位
- **密码**: length ≥ 8 chars **且** UTF-8 byte length ≤ 72 (与 backend bcrypt 限制一致); 不通过 → "密码至少 8 字符,最多 72 字节"
- **角色** (signup only): 必选 1; 未选 → 提交按钮 disabled
- **提交时**: 禁用按钮 (loading state), 失败 toast 显示后端 error code 对应的中文:
  - `AUTH_PHONE_TAKEN` → "该手机号已注册"
  - `AUTH_INVALID_CREDENTIALS` → "手机号或密码不正确"
  - `VALIDATION_ERROR` → 第一条 issue 的 message
  - `RATE_LIMITED` → "请求过于频繁,请稍后重试"
  - 网络错误 (NSURLError* / 超时) → "网络异常,请重试"

### App entry wiring

```swift
// MeetPR/MeetPRApp.swift (App entry, 已存在 — 本 spec 修改)
@available(iOS 17.0, macOS 14.0, *)
@main
struct MeetPRApp: App {
    @State private var session: Session = {
        let api = APIClient.shared
        let auth = NetworkingAuthRepository(api: api)
        let tokenStore = TokenStore()
        return Session(auth: auth, tokenStore: tokenStore, onLogout: nil)
        // onLogout = nil for V1 — CoachKit DraftStore injection 留 spec 005 实装时 wire up
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .task { await session.bootstrap() }
        }
    }
}
```

> **Logout 时清 SwiftData 的连线** (per ADR-009 后果项): 当前 spec 留 `onLogout: nil`, 实际 wire-up 在 spec 005 实装完成后补 (因为 spec 005 才落地 DraftStore)。spec 005 PR 在 Logout flow 里加 ` session.onLogout = { await DraftStore.shared.deleteAll() }` 一行。本 spec 在 SessionTests 加占位测试: `onLogout` callback 在 logout 时被调用一次。

## 验收标准

- [ ] AppShell `Session.swift` 替换完成, `fakeLogin` 删除, 新增 4 方法 (bootstrap/signup/login/logout) + `onLogout` injection point
- [ ] AppShell `AuthFlowView.swift` 替换为 NavigationStack + LoginView (initial) + SignupView (push)
- [ ] `Auth/LoginView.swift` / `Auth/SignupView.swift` / `Auth/AuthFormViewModel.swift` / `Auth/AuthRepository.swift` (protocol + Networking impl + InMemory mock) / `Auth/TokenStore.swift` (actor + Keychain impl + InMemory mock) 全部存在
- [ ] `Modules/Networking/Sources/Networking/Auth/` 新增 DTO + endpoint definitions 匹配 backend spec 001-auth
- [ ] `MeetPR/MeetPRApp.swift` wiring 更新, `Session(auth:tokenStore:onLogout:)` 注入
- [ ] `swift build` 在 Modules/AppShell + Modules/Networking 单独跑通过, 0 warning 0 error, Swift 6 strict concurrency
- [ ] `swift test` 通过, 测试 ≥ **22** (per review P3 #6 修正): 7 AuthRepository (3 round-trip + 4 error code 映射) + 4 TokenStore + 4 Session + 4 AuthFormViewModel + 3 AuthFlowSnapshot
- [ ] **iPhone 17 simulator 跑 happy path 5 步 + 1 dev 验证** (per review P3 #7):
  1. 启动 app → 看到 LoginView (初次启动 Keychain 空)
  2. 点 "没账号? 注册" → SignupView push
  3. 填手机号 13800000001 + 密码 password123 + 选教练 → 提交 (Networking 层 prepend `+86` 后发 backend)
  4. 接口 200 → setState(.authenticated(coach)) → 自动路由到 CoachRootView (placeholder)
  5. **kill app → 重启 → bootstrap 成功 → 直接进 CoachRootView (跳过 LoginView)**
  - **Dev 验证 (可选)**: 在 CoachRootView 触发 `session.logout()` → 清 Keychain + 回 LoginView
- [ ] `xcodebuild build -scheme MeetPR` 通过 (整个 app 编译, 不破坏 CoachKit / StudentKit / CoreModels / DesignSystem 引用)
- [ ] swiftlint + swift-format 全绿
- [ ] CI 在 `feat/011-auth-ui-flow` 分支跑过, 全绿
- [ ] [FOLLOWUPS.md](../../FOLLOWUPS.md) 加新条目 (per review P3 #9): "Spec 005 PR 须把 `MeetPR/MeetPRApp.swift` 的 `onLogout: nil` 替换为 `onLogout: { await DraftStore.shared.deleteAll() }` (per ADR-009 后果项 + spec 011 §3 deferred wiring)"

## 参考

- backend [spec 001-auth](../../../MeetPR-backend/specs/001-auth/SPEC.md) — endpoint shape + error codes 合同
- [ADR-005 §2 App 入口 + 角色路由](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — Session/RootView 已有架构
- [ADR-009 SwiftData 例外](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) — Session.logout 须清 DraftStore（onLogout injection）
- [ADR-003 v4 单角色](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md)
- [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) — User 类型
- [spec 003 DesignSystem](../003-design-system-foundation/SPEC.md) — UI atom

## Notes (给 Codex)

- 本 spec 是 **iOS 端首个真实 UI 流程实装**, 有 demo 价值。完成后可在 simulator 录屏给肖+里欧看
- Keychain API 仅 iOS 上可用; `swift test` 在 macOS 上跑 `TokenStore` Keychain 测试需要 `#if os(iOS)` gate, `InMemoryTokenStore` 用于 SPM 测试
- `AuthFormViewModel` 的 toast / error message 是 V1 内部 dogfood 用, 后续 polish (Stage 3 alpha) 可能要 i18n / 改文案 — 当前 hardcode 中文 OK
- 手机号正则 `^1[3-9]\d{9}$` — V1 只支持中国大陆; 海外手机号 V1.5 加国家区号 picker
- 验收里 "(可选 dev) logout 按钮" 的位置: 可以放 CoachRootView / StudentRootView 顶部一个小按钮, 标 "(dev) Logout" 不进 design polish。正式 logout 入口是 Profile spec 的范围
- `Session.onLogout` 现在传 `nil`; spec 005 实装完成后另开 PR 补 wiring
- 任何疑问写 `specs/011-auth-ui-flow/QUESTIONS.md`
- 完成后**别 self-merge** — Claude review 后才 merge
