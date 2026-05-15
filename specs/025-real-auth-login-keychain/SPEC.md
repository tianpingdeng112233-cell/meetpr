# 025 — Real auth login + Keychain(候选 2 子集:phone + password,跳过 SMS / 邀请码 / 协议)

- **状态**: Draft
- **PR**: TBD
- **来源**:
  - [v0_1_pre_plan §候选 2](~/Brain/wiki/projects/MeetPR/v0_1_pre_plan.md) — 用户 2026-05-15 拍板走"瘦身版 B":login + Keychain only,跳过 SMS / 邀请码 / 协议
  - 上游 [backend spec 001-auth(已合 staging)](~/Projects/apps/MeetPR-backend/specs/001-auth/SPEC.md) — `/auth/register` `/auth/login` `/auth/refresh` HS256 双 token + refresh rotation 全部 ready
  - 上游 [spec 011 auth UI flow](../011-auth-ui-flow/SPEC.md) — `AuthRepository` protocol / `Session` / `TokenStore` / `RootView` 路由
  - 上游 [spec 020 V0 demo orchestration](../020-v0-demo-orchestration/SPEC.md) — DEMO_MODE 编译条件 + `DemoAuthRepository` / `DemoTokenStore` 沿用作 fallback
  - [ADR-005 §2 App 入口 + 角色路由](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — JWT in Keychain,UserDefaults 明文存就是安全洞
  - [ADR-005 §4 横切关注点 / 持久化](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — Keychain → JWT

## 目标

把 `DemoAuthRepository` 替换为真打 backend 的 `BackendAuthRepository`,`DemoTokenStore` 替换为 `KeychainTokenStore`(Security framework + Keychain Services),让两台手机(你 + xty)分别装同一个 build,各自登入不同账号,**身份能区分,refresh token 跨重启持久**。

**为什么是 B 子集而不是候选 2 完整版**:
- 内测期只有 2 人,SMS / 邀请码 / 协议属于"扩到第三人时才需要"的能力
- 阿里云 SMS 模板审核 1-3 day lead time;法律协议需 review;两个都不在 V0.1 关键路径
- backend 001-auth `/auth/register` `/auth/login` 已完全支持 phone + password,本 spec 不动 backend

落地后两人登录 happy path:

```
[Build 在两台手机分别安装]
打开 MeetPR(非 DEMO_MODE)→ Session.bootstrap()
  ↓ KeychainTokenStore.refreshToken() 启动期取 → 有 ⇒ BackendAuthRepository.refresh(...) ⇒ .authenticated
  ↓                                            → 无 ⇒ .anonymous → AuthFlowView (login UI)
AuthFlowView "登录"
  ↓ phone + password TextField + "登录" 按钮(本 spec 不画"注册"UI 入口,见 §不做什么)
BackendAuthRepository.login(phone:password:) → backend `/auth/login` → AuthResult
  ↓ KeychainTokenStore.save(accessToken, refreshToken, user) → Session.state = .authenticated(user)
RootView routes by user.role → CoachRootView / StudentRootView
```

backend seed 你 + xty 账号 + bind 关系**不在本 spec 范围** — 落在 spec 026(backend 真接入),那里加 `db/migrations/0004-seed-internal-users.sql` migration。本 spec 实装期 dev 可手动 curl backend `/auth/register` 临时建 2 个 account 测,等 026 上线后用真 seed。

## 范围

### 做什么

#### 1. `Networking` 模块新增 `BackendAuthRepository` 实装

位置:`Modules/Networking/Sources/Networking/Auth/BackendAuthRepository.swift`(新)

```swift
import CoreModels
import Foundation

public final class BackendAuthRepository: AuthRepository, Sendable {
  private let api: APIClient
  public init(api: APIClient) { self.api = api }

  public func login(phone: String, password: String) async throws -> AuthResult { ... }
  public func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult { ... }
  public func refresh(refreshToken: String) async throws -> AuthResult { ... }
}
```

- `AuthRepository` protocol 来自 spec 011,本 spec 不动 protocol
- `AuthResult` shape 沿用 spec 011 定义(`accessToken` / `refreshToken` / `user`)
- 三个 endpoint shape 与 backend 001-auth 1:1 对齐(see §技术要求)

#### 2. `Networking` 模块 `APIClient` 真发请求

位置:`Modules/Networking/Sources/Networking/APIClient.swift`(扩展;若已有 stub 在 spec 020 内,扩展实装)

```swift
public final class APIClient: Sendable {
  public static let shared = APIClient(baseURL: URL(string: BuildConfig.backendBaseURL)!)
  private let baseURL: URL
  private let session: URLSession

  public init(baseURL: URL, session: URLSession = .shared) { ... }

  /// 不带 auth 的 endpoint(仅 /auth/*)
  public func post<Body: Encodable, Response: Decodable>(
    path: String,
    body: Body
  ) async throws -> Response

  /// 带 auth 的 endpoint(注入 Bearer header)
  public func post<Body: Encodable, Response: Decodable>(
    path: String,
    body: Body,
    accessToken: String
  ) async throws -> Response

  public func get<Response: Decodable>(
    path: String,
    accessToken: String
  ) async throws -> Response
}
```

- `BuildConfig.backendBaseURL`:DEMO_MODE = `"http://localhost:0"` 占位(不会被调到);非 DEMO_MODE = 阿里云 SAE 暴露的 `https://api.meetpr.app`(spec 026 部署后定下来,本 spec 通过 build setting 注入,先用占位 `https://api-staging.meetpr.app`)
- 错误处理:HTTP 4xx/5xx 映射到 `APIError` enum(`.validationFailed(code: String)` / `.authInvalid` / `.network(URLError)` / `.serverError(status:)`)
- 401 typed → `AuthRepositoryError.tokenInvalid` 上传,Session 层负责清 Keychain + 回 `.anonymous`(per ADR-005 §3 中间路线)
- timeout: 15s 默认,可 per-request override

#### 3. `Networking` 模块 `KeychainTokenStore` 实装

位置:`Modules/Networking/Sources/Networking/Auth/KeychainTokenStore.swift`(新)

```swift
public actor KeychainTokenStore: TokenStoring {
  private let service: String   // "app.meetpr.tokens"
  private let userCacheKey: String  // "app.meetpr.userCache"
  public init(service: String = "app.meetpr.tokens") { ... }

  public func accessToken() async -> String?
  public func refreshToken() async -> String?
  public func cachedUser() async -> User?
  public func save(accessToken: String, refreshToken: String, user: User) async throws
  public func clear() async throws
}
```

- Keychain 三项分别用 `kSecClassGenericPassword`,account 字段分 `"accessToken"` / `"refreshToken"` / `"cachedUser"`(后者存 User 的 JSON-encoded data)
- `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlock`(开机解锁后可读;avoid `AlwaysThisDeviceOnly` 避免设备恢复丢失)
- error 处理:`KeychainError.osStatus(OSStatus)` 透传 + 集中映射 `errSecItemNotFound` → nil(不抛)
- 单测覆盖:save → read → clear roundtrip;clear 后所有 getter 返 nil;User 编解码 roundtrip

#### 4. `AuthFlowView` UI(spec 011 已存在,本 spec 重新 wire)

学员/教练看到啥:
- 启动若 Keychain 有 refresh token → 后台 silent refresh(可能 1-2s loader),成功直接进 RootView 对应角色;失败回登录页
- 登录页:`[ 手机号 +86 13... TextField ][ 密码 SecureField ][ 登录 ]`,顶部副标题 "MeetPR(内测版)"
- 登录失败 → 顶部红 banner,文案 backend 错误码映射:
  - `AUTH_INVALID_CREDENTIALS` → "手机号或密码错误"
  - `VALIDATION_ERROR` → "手机号格式不对(+86 开头)"
  - 网络错误 → "网络不稳定,重试"
- 内测期不画"注册" / "找回密码" / "Apple Sign-In" / "微信登录" 按钮 — 全部 V0.1.x / V1.5+

实装位置:`Modules/AppShell/Sources/AppShell/AuthFlow/AuthFlowView.swift`(已存在,本 spec 删除 demo 占位 + 接 BackendAuthRepository)

#### 5. `MeetPRApp` 入口注入策略

```swift
// MeetPR/Sources/MeetPRApp.swift
@main
struct MeetPRApp: App {
  @State private var session: Session

  init() {
    let api = APIClient.shared

    #if DEMO_MODE
    let auth: AuthRepository = DemoAuthRepository()
    let tokens: TokenStoring = DemoTokenStore()
    #else
    let auth: AuthRepository = BackendAuthRepository(api: api)
    let tokens: TokenStoring = KeychainTokenStore()
    #endif

    self.session = Session(auth: auth, tokens: tokens)
  }

  var body: some Scene { ... }
}
```

- DEMO_MODE 保留 demo 路径,Codex / 你本地排 plan 仍可用 demo scheme 不被打扰
- 非 DEMO_MODE = 真 backend 路径,真 Keychain

#### 6. `Session.bootstrap` 真启 refresh

`Modules/AppShell/Sources/AppShell/Session.swift`(spec 011 已存在,本 spec 改 bootstrap)

```swift
public func bootstrap() async {
  state = .authenticating
  guard let token = await tokens.refreshToken() else {
    state = .anonymous; return
  }
  do {
    let result = try await auth.refresh(refreshToken: token)
    try await tokens.save(accessToken: result.accessToken, refreshToken: result.refreshToken, user: result.user)
    state = .authenticated(result.user)
  } catch {
    try? await tokens.clear()
    state = .anonymous
  }
}
```

- 启动 ≤ 2s loader UI(spec 011 已有 `.authenticating` 分支)
- refresh 失败 = 清 Keychain + 回登录页,**不重试**(防 retry storm)
- backend 001 refresh rotation 行为已验证:每次 refresh 旧 refreshToken 作废,新 refreshToken 进 Keychain

#### 7. 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/Networking/Tests/NetworkingTests/Auth/BackendAuthRepositoryTests.swift`(新) | login / signup / refresh 与 mock URLSession 互动;401 → AuthRepositoryError 映射;不同状态码错误透传 |
| `Modules/Networking/Tests/NetworkingTests/Auth/KeychainTokenStoreTests.swift`(新) | save → read → clear roundtrip;User encode/decode;并发 read 不数据竞争(actor 自然保证) |
| `Modules/Networking/Tests/NetworkingTests/APIClientTests.swift`(新或扩展) | 请求方法 / header / body 序列化;timeout 行为;`Authorization: Bearer xxx` 注入 |
| `Modules/AppShell/Tests/AppShellTests/SessionBootstrapTests.swift`(新或扩展 spec 011 测试) | bootstrap 有 token / 无 token / refresh 失败 三分支 |

#### 8. CHECKLIST.md(本 spec 内 manual happy path)

实装 PR 内补 `specs/025-real-auth-login-keychain/CHECKLIST.md`:

```
[ ] backend staging 已可访问(curl /healthz 200)
[ ] 手动 curl /auth/register 建 2 个测试账号(若 026 seed migration 还没上)
[ ] iPhone A 装非 DEMO build,输账号 A → 登入成功,kill app 重开仍登入态
[ ] iPhone B 装非 DEMO build,输账号 B → 登入成功
[ ] iPhone A "退出登录"(暂无 UI,V0.1.x;本 spec 通过删除 app 重装模拟)→ 回到 AuthFlow
[ ] backend 重启 refresh rotation 测试:30 天 sleep 模拟超期 → 401 → 回登录
[ ] 错误码映射:输错密码 → 红 banner 文案正确
```

### 不做什么

**V0.1.x defer(下波)**:
- 注册 UI(`/auth/register` endpoint 已存在,UI 等扩第三人前再画)
- "退出登录" 按钮(本 spec 删 app 重装模拟,V0.1.x 加 Settings tab)
- 找回密码(忘记密码流)
- 阿里云 SMS OTP 集成(`阿里云短信` lean v2 留位)
- 邀请码绑定(`BindRequest` 流;本 spec 走 backend seed 直接 hardcode 关系,见 026)
- 用户协议 + 隐私协议 dialog(Apple §5.1.1 内测可不强制;扩第三人前法律 review)
- Apple Sign-In(Apple §4.8 强制等微信登录触发)
- 多设备 refresh(backend 001-auth 单 `refresh_token_jti` 已记 V1 接受单设备登录,V0.1 不解决)

**V0.2+ defer**:
- 微信登录(V1.5+,Apple §4.8 合规 + WeChat OpenSDK)
- 多角色单用户(V1.5+,backend 001 已为单角色)
- Universal Links(域名 + ICP 备案后切,Stage 3-4)
- iCloud Keychain 跨设备(V1.5+ 评估)

## 技术要求

### Backend endpoint contract(与 backend 001-auth 1:1)

| iOS 调 | backend 路径 | Request | Response 200 |
|---|---|---|---|
| `BackendAuthRepository.login(phone:password:)` | `POST /auth/login` | `{ phone, password }` | `{ user, accessToken, refreshToken }` |
| `BackendAuthRepository.signup(phone:password:role:)` | `POST /auth/register` | `{ phone, password, role }` | `201 { user, accessToken, refreshToken }` |
| `BackendAuthRepository.refresh(refreshToken:)` | `POST /auth/refresh` | `{ refreshToken }` | `{ accessToken, refreshToken }`(注意:无 `user` 字段) |

**refresh response 缺 `user` 字段处理**:沿用 KeychainTokenStore 缓存的 user(因为 refresh 不可能换 user)。这与 backend 001 SPEC §"Refresh flow" 第 6 步语义一致 — refresh 仅换 token。

**`user` 字段映射**(backend 已用 snake_case + ISO TIMESTAMPTZ,iOS Codable 决定转换策略):

| backend 字段 | iOS `User` 字段 | 转换 |
|---|---|---|
| `id` (uuid string) | `id: UUID` | `UUID(uuidString:)` |
| `phone` (E.164) | `phone: String` | as-is |
| `role` (`'coach' / 'coached_student' / 'self_train_student'`) | `role: UserRole` enum | 三值映射(per CoreModels) |
| `createdAt` (ISO-8601) | `createdAt: Date` | `ISO8601DateFormatter` |

**`MeetPRCodec` 提供** snake_case ↔ camelCase + Decimal-as-string + ISO 日期解码组合,本 spec 直接复用(spec 002 + 004 已建)。

### Keychain 存储 schema

| Key (account) | Service | Value | accessible |
|---|---|---|---|
| `accessToken` | `app.meetpr.tokens` | UTF-8 string bytes | AfterFirstUnlock |
| `refreshToken` | `app.meetpr.tokens` | UTF-8 string bytes | AfterFirstUnlock |
| `cachedUser` | `app.meetpr.tokens` | `JSONEncoder().encode(User)` data | AfterFirstUnlock |

**不存** 在 UserDefaults。**不存** access token 在 memory-only — Session 启动 bootstrap 时从 Keychain 取一次,后续 refresh 后写回。

### 错误 handling

```swift
public enum AuthRepositoryError: Error, Sendable {
  case invalidCredentials   // 401 AUTH_INVALID_CREDENTIALS
  case phoneTaken           // 409 AUTH_PHONE_TAKEN(本 spec 不画 register 但 protocol 留口)
  case refreshInvalid       // 401 AUTH_INVALID_REFRESH / AUTH_REFRESH_EXPIRED
  case validation(field: String)   // 400 VALIDATION_ERROR
  case network              // URL 错误 / timeout
  case server(status: Int)  // 5xx
}
```

`Session` 顶层处理:
- `.invalidCredentials` / `.validation` → UI 显示 banner,**不清** Keychain
- `.refreshInvalid` → 清 Keychain + 回 `.anonymous`
- `.network` / `.server` → UI 显示 banner + 提供 retry CTA

### BuildConfig 注入策略

`Modules/AppShell/Sources/AppShell/Config/BuildConfig.swift`(新):

```swift
public enum BuildConfig {
  /// Set via xcconfig: BACKEND_BASE_URL=https://api.meetpr.app (release)
  /// Set via xcconfig: BACKEND_BASE_URL=https://api-staging.meetpr.app (debug)
  public static let backendBaseURL: String = {
    guard let v = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String else {
      fatalError("BackendBaseURL missing from Info.plist; check xcconfig wiring")
    }
    return v
  }()
}
```

- xcconfig 文件改 `MeetPR/SupportingFiles/Config.xcconfig`(新建,nil 安全模式)
- Info.plist 加 `<key>BackendBaseURL</key><string>$(BACKEND_BASE_URL)</string>`
- DEMO_MODE 配置 `BACKEND_BASE_URL = http://demo.invalid`(不会被调到)

### 版本 / 兼容

- iOS 17.0+
- Security framework 系统自带,无 SPM dep
- 不引第三方 Keychain wrapper(per ADR-005 减外部依赖)

## 验收清单

实装 PR 合并前必须满足:

- [ ] `BackendAuthRepository` 三方法接通 backend 001 endpoint,单测 mock URLSession 通过
- [ ] `KeychainTokenStore` save/read/clear roundtrip 单测过 + 真机/simulator manually verify
- [ ] `APIClient` 单测覆盖 GET / POST(无 auth + 带 auth)
- [ ] `Session.bootstrap` 启动时 refresh 路径单测过
- [ ] `AuthFlowView` 真机能登入 backend staging,登入后角色路由正确
- [ ] kill app 重开仍登入态(Keychain 持久)
- [ ] backend `staging` 分支必须**解冻**(`~/Projects/apps/MeetPR-backend/CLAUDE.md` ❄️ 字样去除)— 实装期 Codex 在 backend repo 提个 docs PR
- [ ] DEMO_MODE 路径未被破坏(spec 020 happy path 仍跑)
- [ ] 错误码映射 5 个分支全 UI 展示文案审过
- [ ] CHECKLIST.md 手动跑一遍记结果

## 估时(给 Codex 参考)

| 块 | 估时 |
|---|---|
| 1. `BackendAuthRepository` + `APIClient` + 单测 | 1d |
| 2. `KeychainTokenStore` + 单测 | 0.5d |
| 3. `AuthFlowView` rewire + 错误 banner UI | 0.5d |
| 4. `Session.bootstrap` 改 + 单测 | 0.3d |
| 5. `BuildConfig` + xcconfig + Info.plist 接线 | 0.3d |
| 6. CHECKLIST + 手动跑 + bug 修 | 0.4d |
| **合计** | **3d** |

## 风险 / 待 implementer 关注

1. **backend staging 必须先解冻**:CLAUDE.md ❄️ FROZEN callout 是 V0 期决策,本 spec 启动前 Codex 必须先开 backend docs PR 移除 frozen,否则 staging 不接受新提交
2. **Keychain 在 simulator vs 真机差异**:simulator Keychain 不加密(走 file backed),真机才走硬件 secure enclave。单测在 simulator 跑过不代表真机一定通,manually verify 必须在真机做一次
3. **`AccessibleAfterFirstUnlock` vs `WhenUnlocked`**:本 spec 选 AfterFirstUnlock 是为了让 silent push wake app 时能拿到 token;V0.1 没真 push 但留口
4. **xcconfig + DEMO_MODE 组合矩阵**:DEMO_MODE 在 xcodeproj 是 OTHER_SWIFT_FLAGS,xcconfig 是 build setting,两者独立。Codex 实装时确认 `MeetPR-Demo` scheme `DEMO_MODE` 开 + `BACKEND_BASE_URL=demo.invalid`,`MeetPR` (default) scheme `DEMO_MODE` 不开 + `BACKEND_BASE_URL=https://api-staging.meetpr.app`
5. **timeout 15s 适合健身房**:健身房 wifi/4G 抖动,15s loader 比 5s 通过率高;但 login 路径 15s 仍可能伤体验,user-perceived latency 可由 UI 立即 disable 按钮 + spinner 缓解
6. **backend rate limit**:001-auth 中间件已有 helmet/cors/rateLimit,本 spec 不动;若 testing 时连续登入触发 rate limit,Codex 反馈 backend rate 调整

## Implementation Notes

无(spec PR 阶段)。

## 上游 / 下游

**上游**:
- backend 001-auth(已合 staging) ✅
- spec 011 auth UI flow(已合)
- spec 020 V0 demo orchestration(已合)

**下游**:
- spec 026(backend 真接入):本 spec 解锁 access token 注入路径,026 的 `BackendPlanRepository` 直接拿 access token 调 plan endpoint
- spec 027(视频上传):需 access token 调 OSS 签名 URL endpoint
- spec 029(教练端 review):需 access token 调 student 列表 / feedback endpoint
- V0.1.x 注册 UI / 找回密码 / 退出登录:复用本 spec 的 Auth 路径
- V1.5 Apple Sign-In / 微信:替 `BackendAuthRepository` 之外加并行 repo

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。Scope = 候选 2 子集 B(login + Keychain),SMS / 邀请码 / 协议全 defer | Claude |
