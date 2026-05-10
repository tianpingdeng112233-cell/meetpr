# 020 — V0 Demo Orchestration (auth bypass + demo build config + happy path 验证)

- **状态**: Draft
- **PR**: (待填)
- **来源**:
  - [`~/Brain/wiki/projects/MeetPR/roadmap.md`](~/Brain/wiki/projects/MeetPR/roadmap.md) — V0 hard deadline 2026-06-20 + happy path 定义
  - 上游 [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) — `User` / `UserRole` / `CoachProfile`
  - 上游 [spec 011 auth UI flow](../011-auth-ui-flow/SPEC.md) — `AuthRepository` protocol / `Session` / `TokenStore` / `AuthResult` / `RootView` role-routed dispatch
  - 上游 [spec 005 / 006 / 007 coach planning](../005-coach-planning-step-0-3/SPEC.md) — V0 demo 落点 = `PlanningCoordinatorView` Step 0-7 happy path
  - [ADR-005 §1 (CoachKit / AppShell 模块边界) + §3 (Repository pattern)](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
  - `MeetPR-backend` repo CLAUDE.md ❄️ FROZEN callout — V0 不接 backend
  - AGENTS.md §Spec 生命周期 — 1 spec = spec PR + impl PR

## 目标

把现有 8 个已合 spec 串成 **TestFlight 可演示的端到端 build**, 不依赖真 backend, 不依赖真注册学员. 解决 V0 路径上的最后一个集成 gap: **app 启动后能直接进认证态** (现在 `MeetPRApp.init()` 用 `NetworkingAuthRepository` + 真 `TokenStore`, 启动时 token 为空 → 落 `.anonymous` → 登录 UI; 真 backend 又是 ❄️ FROZEN, 没法走完登录).

落地后 V0 happy path:

```
打开 MeetPR-Demo build (xcodebuildmcp build_run_sim)
  ↓ launch screen (本 spec 不做; W22 spec 020+ 加资产)
DemoAuthRepository 注入 → DemoTokenStore 已有 fake 教练 user → Session.bootstrap() 直接 .authenticated
  ↓ RootView role-routed
CoachRootView ("教练端" + "排新计划" 按钮)
  ↓ tap "排新计划"
PlanningCoordinatorView (`InMemoryPlanRepository.preview()` 已有 demo 学员)
  ↓ Step 0 - Step 4 (spec 005 / 006 已实装)
  ↓ Step 5 W1 强度 - Step 6 规则 - Step 7 周卡片横滑 (spec 007 已实装)
点 "进入发布 (TODO spec NNN backend)" → V1 placeholder log warn, 不真发布
```

整个链路本机 InMemory + Mock + DraftStore SwiftData, 无网络依赖.

> **2026-05-09 V0 strategic shift 影响声明**: 本 spec 是 V0 critical path 的 **W21 关键里程碑** (per roadmap §V0 周计划 W21). 不做 W22 资产 (icon / launch / privacy manifest), 不做 W23 release engineering (TestFlight signing / archive / distribute). 本 spec 完成后, app 在 simulator 上能跑出完整 happy path; 接 W22 是 "device-runnable + reviewer-ready", 接 W23 是 "TestFlight build distributable".

## 范围

### 做什么

#### 1. AppShell 加 Demo 实装层 (`Modules/AppShell/Sources/AppShell/Auth/Demo/`)

| 文件 | 作用 |
|---|---|
| `DemoAuthRepository.swift` (新) | `final class DemoAuthRepository: AuthRepository, Sendable` — `signup` / `login` / `refresh` 全返回固定 `AuthResult` (fake `accessToken` / `refreshToken` 字符串 + 内嵌 `User` 同 DemoTokenStore preset; refresh 永远成功不 throw). 不调任何网络. 不持久化. |
| `DemoTokenStore.swift` (新) | `actor DemoTokenStore: TokenStoring` — 内存里持有预置 fake access/refresh token 字符串 + 预置 `User` (role = `.coach`, fake UUID, name = "演示教练"); `accessToken()` / `refreshToken()` / `cachedUser()` 启动时直接返回非 nil → Session.bootstrap() 走 `.authenticated` 分支无登录 UI; `save/clear` no-op (写入即丢). |
| `DemoUserSeed.swift` (新) | `public enum DemoUserSeed { public static let coach: User; public static let accessToken = "demo-access"; public static let refreshToken = "demo-refresh" }` — 预置常量, 集中维护避免散落. |

#### 2. iOS app 入口加 DEMO_MODE 编译条件 (`MeetPR/Sources/MeetPRApp.swift`)

```swift
@main
@MainActor
struct MeetPRApp: App {
  private let draftStore: DraftStore
  @State private var session: Session

  init() {
    let draftStore = DraftStore.shared
    self.draftStore = draftStore

    #if DEMO_MODE
      let auth: any AuthRepository = DemoAuthRepository()
      let tokenStore: any TokenStoring = DemoTokenStore()
    #else
      let api = APIClient.shared
      let auth: any AuthRepository = NetworkingAuthRepository(api: api)
      let tokenStore: any TokenStoring = TokenStore()
    #endif

    _session = State(
      initialValue: Session(
        auth: auth,
        tokenStore: tokenStore,
        onLogout: { try? await draftStore.deleteAll() }
      )
    )
  }
  // body 不变
}
```

实质改动 = init 里 4 行 + `#if DEMO_MODE` 包住 `let auth` / `let tokenStore`. 现有 Debug / Release 行为不动.

#### 3. Build configuration + scheme

新建文件:

| 文件 | 作用 |
|---|---|
| `MeetPR.xcodeproj/xcshareddata/xcschemes/MeetPR-Demo.xcscheme` | 新 scheme `MeetPR-Demo`, build configuration = Demo (新建), Run / Test / Profile / Archive 都用 Demo configuration |
| Build settings | xcodeproj 加新 build configuration `Demo` (基于 Debug); 在 `OTHER_SWIFT_FLAGS` (Demo only) 加 `-D DEMO_MODE`; 其他 setting 跟 Debug 一致 |

(实装路径有两条选择, 见 §技术要求 §Build config 实装策略)

#### 4. Demo 数据增强 (`Modules/CoachKit/Sources/CoachKit/Planning/Repository/InMemoryPlanRepository.swift`)

现有 `preview()` 已含 multi 学员 + main lift catalog + accessory catalog. **审视一遍数据真实度**:

| 检查项 | V0 期望 | 改动 |
|---|---|---|
| 学员数 | 3-5 个不同 SBD 1RM 区间 (含至少 1 个全 1RM 数据 + 1 个无 1RM 数据 — 验证 %1RM 切换 disabled 路径) | 若现有不满足, 补 fixture |
| 学员名 | 中文真实感 (避免 "test" / "fixture") | 若现有英文/dummy, 改中文 |
| 主项 catalog | spec 005 已 ship,V0 不动 | — |
| Accessory catalog | spec 006 已 ship,验证现有覆盖三标签 (muscle / equipment / movement) 至少各 5 个 | 若不足补 |
| 预置 plan-in-draft | **不预置** — happy path 从空 draft 开始走 Step 0,验证完整创建路径 | — |

> **理由**: V0 demo 主要给 Apple 审核员 + xty/肖天宇/里欧 看。审核员不看老 plan, 看的是 "能创建一个完整 plan". 所以 happy path = create flow.

#### 5. V0 happy path manual checklist (本 spec `CHECKLIST.md`)

`specs/020-v0-demo-orchestration/CHECKLIST.md` (新) — 12 步 manual verification:

```markdown
## V0 Happy Path Manual Checklist (iPhone 17 simulator)

每次 V0-related PR merge 后跑一次。每步预期截图(可选)放 specs/020-.../screenshots/.

1. xcodebuildmcp build_run_sim Scheme=MeetPR-Demo  → app 启动 → splash 后**跳过登录 UI** 直接落 "教练端" 主页 (CoachRootView)
2. CoachRootView 显示 "教练端" + "排新计划" 按钮  → 点击
3. fullScreenCover 推上 PlanningCoordinatorView, Step 0 显示学员列表 (≥3 中文名学员, S/B/D 1RM 数字可读)  → 选首位
4. Step 1 显示 [1 周 / 4 周] segmented  → 选 4 周
5. Step 2 SBD 频率 inputs  → S/B/D 各设 2 / 1 / 1, 验证训练日分配预览
6. Step 3 主项变式选择 (3 列 chips)  → 各选 1 变式
7. Step 4 辅助动作 三标签筛选  → 加 2 个不同 day 的 accessory
8. Step 5 W1 强度填写  → 主项填 100kg/4×5/RPE7, accessory 填 60kg/3×10
9. WeightInputField %1RM 切换  → 学员有 1RM 那位 segmented 可切, 切到 50% 看到换算 = 50kg; 无 1RM 学员 (若有) segmented 锁定 kg
10. Step 6 加 1 条 weightInc 规则,绑定主项 squat,勾 W2/W3  → 完成
11. Step 7 周卡片横滑  → W1 displays 100kg, swipe W2 displays 105kg (W1+5), W3 displays 110kg, W4 displays 110kg (default 同上周)
12. 长按任一 exercise row → contextMenu Peek 弹出 ExercisePeekView 显示动作名 + 强度详情
13. 点 "进入发布 (TODO spec NNN backend)" → 无视觉变化 (placeholder log warn `step8_pending`)
14. (regression) 边缘 swipe 测试: W2 卡片左 ~10pt 起手 swipe → 应 pop NavigationStack 回 Step 6;卡片中央 swipe → 切 W1
15. 杀 app + 重开 (cmd+shift+H 关掉 simulator, 再 build_run_sim)  → 应仍在 .authenticated 态 (DemoTokenStore 重启后预置 fake user 仍生效)

预期通过率 = 15/15. 任一失败 = 阻塞 V0 ship.
```

#### 6. README / DEMO.md (`MeetPR/DEMO.md` 新)

`MeetPR/DEMO.md` (新, 1-2 屏) — 解释:
- Demo build 是什么 / 为什么(给 Apple 审核 + 内测)
- 怎么切到 Demo scheme + run (XcodeBuildMCP `session_set_defaults` scheme=MeetPR-Demo / 命令行 `xcodebuild -scheme MeetPR-Demo`)
- DemoAuthRepository / DemoTokenStore 行为说明 (token 不持久化但 cachedUser 永远预置 → 看上去像 "已登录" 状态)
- 怎么在 Debug build 测试真 auth (切回 MeetPR scheme)
- V0.1+ 接真 backend 时该 spec 的处置 (DemoAuthRepository 留作集成测试用 / 或删)

#### 7. 测试 (`Modules/AppShell/Tests/AppShellTests/Auth/Demo/`)

Swift Testing (`@Test` / `#expect`):

| 文件 | 覆盖 (测试数) |
|---|---|
| `DemoAuthRepositoryTests.swift` (新) | 4 测试: signup 返回 DemoUserSeed.coach + 预置 token / login 同 / refresh 不 throw + 返回非空 tokens / 多次 refresh 返回相同 tokens (deterministic) |
| `DemoTokenStoreTests.swift` (新) | 5 测试: accessToken 启动即非 nil / refreshToken 启动即非 nil / cachedUser 启动即非 nil = DemoUserSeed.coach / save 后再 load 仍是预置值 (no-op verified) / clear 后 load 仍是预置值 (no-op verified — Demo 模式禁登出回 anonymous) |
| `DemoSessionBootstrapTests.swift` (新) | 3 测试: Session(auth=DemoAuthRepository, tokenStore=DemoTokenStore).bootstrap() → state == .authenticated(DemoUserSeed.coach) / refresh 调用不 throw / logout 后 state 仍 = .authenticated (Demo 模式 logout 是 no-op? 见 §不做什么 第 7 项决策) |

总 **≥ 12 新测试**.

### 不做什么

| ❌ 留 spec / 留 follow-up |
|---|
| **App icon (AppIcon.appiconset 1024 + 各尺寸)** — 走 W22 / 单独 spec 021 (AssetCatalog 真资产 + F-013 触发) |
| **Launch screen (LaunchScreen.storyboard 或 SwiftUI launch screen)** — 同上, W22 |
| **Privacy manifest (PrivacyInfo.xcprivacy)** — W22, App Store 审核硬要求, V0 ship 前必有 |
| **Bundle ID 公司账号迁移 (com.meetpr.app)** — F-012 触发条件 = "Apple Developer 公司账号 ready", 现在用 placeholder bundle ID + personal account 就能 TestFlight |
| **TestFlight build / signing / archive / Apple 审核提交** — W23-25 release engineering, 不在本 spec |
| **真 backend wiring (NetworkingAuthRepository 真用 + BackendPlanRepository 真实装)** — V0.1+, 等 backend ❄️ unfreeze |
| **Demo 模式登出行为完整定义** — 现在 Session.logout 调用 `tokenStore.clear()`, `DemoTokenStore.clear()` 是 no-op 但 state 仍会被 Session 设回 `.anonymous` (Session 主动 set, 不是 tokenStore 反应). V0 不暴露登出按钮(CoachRootView 没有), 等 V0.1+ 加 settings + logout UI 时再决定 Demo 模式行为 (按 V0.1+ spec 决定, 现在 placeholder 行为 = "logout 实际生效, 下次启动重新预置 demo user") |
| **XCUITest happy path 自动化** — V0 用 manual checklist (CHECKLIST.md), V0.1+ 评估投入产出比再加 |
| **Demo 数据预置 plan-in-draft / 已发布 plan history** — happy path 是 create flow, 不需要; 见 §做什么 #4 |
| **Demo 模式开关切换 UI** — DEMO_MODE 是 build flag, 不暴露 runtime toggle. 切换需要重新 build scheme. |
| **多 demo 用户 / 角色切换 (coach ↔ student demo)** — V0 只 demo 教练 happy path. Student demo 留 V0.1+ 学员端 spec |
| **网络层 mock (APIClient mock for offline-but-non-demo)** — 不需要, NetworkingAuthRepository 在 Demo 模式压根不 instantiate |
| **修改 spec 002-007 / 011 已合 view 内部** — 仅允许的 surface: MeetPRApp.swift init / InMemoryPlanRepository.preview 数据 (若需) / 新建 Demo* 文件 |
| **改 ADR / PRD / coach-planning.md / data-model.md** — 本 spec 不动设计层. 若 implementer 发现需要 ADR (e.g. demo 模式策略要不要 ADR-010 锁定), 走 AGENTS.md §文档质疑权 协议提 CHALLENGE.md |

## 技术要求

### 模块位置 + import 边界

继承 ADR-005 §1 (CoachKit / AppShell / Networking 边界):

| 文件类别 | 允许 import |
|---|---|
| `Modules/AppShell/Sources/AppShell/Auth/Demo/*` (DemoAuthRepository / DemoTokenStore / DemoUserSeed) | `Foundation`, `CoreModels`, 本 module 的 `Auth/AuthRepository` / `Auth/AuthDTOs` / `Auth/TokenStoring` / `Auth/AuthResult` |
| `MeetPR/Sources/MeetPRApp.swift` | 现有 `AppShell`, `CoachKit`, `Networking`, `SwiftData`, `SwiftUI`; **不新增** import (DemoAuthRepository 通过 AppShell re-export 可见) |
| `Modules/AppShell/Tests/AppShellTests/Auth/Demo/*` | 现有 + `Testing` |

**禁止**:
- ❌ Demo 实装文件 import `Networking` (没必要 — 不调网络)
- ❌ Demo 实装 import `SwiftUI` (它们是 repository 层, 与 view 解耦)
- ❌ MeetPRApp.swift 在非 `#if DEMO_MODE` 路径 instantiate Demo* (污染 prod build size)

### `DemoAuthRepository` 形状

```swift
import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public final class DemoAuthRepository: AuthRepository, Sendable {
  public init() {}

  public func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult {
    fixedResult()
  }

  public func login(phone: String, password: String) async throws -> AuthResult {
    fixedResult()
  }

  public func refresh(refreshToken: String) async throws -> AuthTokens {
    AuthTokens(
      accessToken: DemoUserSeed.accessToken,
      refreshToken: DemoUserSeed.refreshToken
    )
  }

  private func fixedResult() -> AuthResult {
    AuthResult(
      user: DemoUserSeed.coach,
      accessToken: DemoUserSeed.accessToken,
      refreshToken: DemoUserSeed.refreshToken
    )
  }
}
```

(若 `AuthResult` / `AuthTokens` 字段名不一样, Codex 按 AppShell 现有定义贴齐. 这里仅传达"返回固定值不抛错"语义.)

### `DemoTokenStore` 形状

```swift
import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public actor DemoTokenStore: TokenStoring {
  public init() {}

  public func accessToken() async -> String? { DemoUserSeed.accessToken }
  public func refreshToken() async -> String? { DemoUserSeed.refreshToken }
  public func cachedUser() async -> User? { DemoUserSeed.coach }

  public func save(access: String, refresh: String) async {
    // no-op: Demo 模式 token 在内存预置, 不接受外部覆盖
  }

  public func saveUser(_ user: User) async {
    // no-op
  }

  public func clear() async {
    // no-op: Demo 模式 cachedUser 永远存在
  }
}
```

> **等价语义**: Session.logout 调用 `clear()` 后会自己 set `state = .anonymous`. Demo 模式下下次启动 (重新 init Session) `bootstrap()` 仍能从 DemoTokenStore 读到 cachedUser → 回 `.authenticated`. 等于 logout 是"本次 session 内有效, 重启即恢复 demo user"行为. 与本 spec §不做什么 第 7 项一致.

### `DemoUserSeed` 形状

```swift
import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public enum DemoUserSeed {
  public static let accessToken = "demo-access-2026-05-10"
  public static let refreshToken = "demo-refresh-2026-05-10"
  public static let coach = User(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
    role: .coach,
    // 其他必填字段按 spec 002 CoreModels User struct 实际定义贴齐
    // 推荐: name = "演示教练", phone = "13800000000", createdAt = .distantPast 等
  )
}
```

(具体字段待 Codex 对照 spec 002 CoreModels User 实装贴齐. raw value 选择 deterministic 是因为重启后 user.id 仍要稳定, 否则 InMemoryPlanRepository 关联 coach_id 会断。)

### Build config 实装策略 (二选一)

#### 策略 A: xcodeproj 直接改 (推荐)

XcodeBuildMCP 不直接管 build config, 但 Codex 可手动改 `MeetPR.xcodeproj/project.pbxproj`:

1. 加新 build configuration `Demo` (基于 `Debug` 的复制)
2. `OTHER_SWIFT_FLAGS` (Demo only) 增加 `-D DEMO_MODE`
3. 加 shared scheme `MeetPR-Demo.xcscheme` (build/run/test/archive 全部 Demo)
4. 不动现有 `Debug` / `Release` configurations + `MeetPR.xcscheme`

这是 iOS 标准做法, project.pbxproj 改动 ~30 行.

#### 策略 B: SPM target conditional (备选, 不推荐 V0)

若策略 A 因 xcodeproj 复杂度无法实施, 备选: `Package.swift` 加 `Demo` define 通过 `swiftSettings = [.define("DEMO_MODE", .when(...))]`. 但 SPM target define 不能跟 Xcode build config 直接 1:1 对应, 切换体验差 (要改 Package.swift 而不是切 scheme).

> **指导**: 优先策略 A. 策略 B 仅当 Codex 实测策略 A 无解 (e.g. project.pbxproj merge conflict 反复出现) 时启用, 并在 spec impl PR 内 amend 本段说明.

### Session.bootstrap() 行为验证

无需改 Session.swift. 现有逻辑 (Session.swift:31-55) 已支持本 spec 路径:
- DemoTokenStore.accessToken/refreshToken/cachedUser 全非 nil → guard 不进 anonymous → state = .authenticated(cachedUser) ✅
- DemoAuthRepository.refresh 不 throw → tokens 重 save (DemoTokenStore.save 是 no-op, 等价于不动) ✅
- 不进 catch 路径 → 不 print warning ✅

> **遗留 P3** (本 spec **不修**): `Session.swift:52` 仍是 `print("warning: bootstrap_refresh_deferred ...")`, 跟 spec 007 P2-4 同模式 (print 不是 log). 留 follow-up "F-NNN — Session.bootstrap print → Logger" cleanup, 不属本 spec 范围.

### 版本 / 兼容

- iOS 最低基线 17.0 (per ADR-005 + spec 005), 不变
- Swift 6 strict concurrency, 不变
- DemoAuthRepository / DemoTokenStore 都标 `@available(iOS 17.0, macOS 14.0, *)` 跟现有惯例

## 验收清单

- [ ] `Modules/AppShell/Sources/AppShell/Auth/Demo/DemoAuthRepository.swift` 实装
- [ ] `Modules/AppShell/Sources/AppShell/Auth/Demo/DemoTokenStore.swift` 实装
- [ ] `Modules/AppShell/Sources/AppShell/Auth/Demo/DemoUserSeed.swift` 实装
- [ ] `MeetPR/Sources/MeetPRApp.swift` init 加 `#if DEMO_MODE` 分支 (4 行 + 包住 let auth/tokenStore)
- [ ] `MeetPR.xcodeproj` 加 `Demo` build configuration + `MeetPR-Demo.xcscheme` (策略 A)
- [ ] `OTHER_SWIFT_FLAGS` (Demo) 含 `-D DEMO_MODE`
- [ ] `Modules/AppShell/Tests/AppShellTests/Auth/Demo/DemoAuthRepositoryTests.swift` (4 测试) 全绿
- [ ] `Modules/AppShell/Tests/AppShellTests/Auth/Demo/DemoTokenStoreTests.swift` (5 测试) 全绿
- [ ] `Modules/AppShell/Tests/AppShellTests/Auth/Demo/DemoSessionBootstrapTests.swift` (3 测试) 全绿
- [ ] `swift test --parallel` 全绿 (含本 spec ≥12 + 上游所有 spec 测试 — 不破)
- [ ] `swift build` 0 新 warning
- [ ] `swiftlint lint --strict` + `swift-format lint` 通过
- [ ] **XcodeBuildMCP `build_run_sim` Scheme=MeetPR-Demo** iPhone 17 simulator 构建 + 跑通: app 启动直接落 CoachRootView (无登录 UI)
- [ ] **manual happy path** `specs/020-v0-demo-orchestration/CHECKLIST.md` 15 步全通过 (含杀 app 重开仍 .authenticated 验证 + 边缘 swipe gesture coexistence)
- [ ] `XcodeBuildMCP build_run_sim` Scheme=MeetPR (现有 Debug, 非 Demo) 仍能 build (验证未污染现有 build)
- [ ] `MeetPR/DEMO.md` 写完 (1-2 屏, 含切 scheme + run 步骤 + Demo 行为说明)
- [ ] `specs/020-v0-demo-orchestration/SPEC.md` 状态 `Draft` → `Done` (review approve 后,在同 impl PR 内改完最后一步; per AGENTS.md §交付检查清单 line 278)
- [ ] SPEC.md PR 字段填 impl PR 链接 (同上)

## 估时 (给 Codex 参考)

- DemoAuthRepository / TokenStore / UserSeed: 1.5 小时 (含 12 测试)
- MeetPRApp 改 init 4 行: 10 分钟
- xcodeproj Demo configuration + scheme (策略 A): 1.5 小时 (project.pbxproj 手改 + 测试)
- DEMO.md: 30 分钟
- CHECKLIST.md 11+4 步 manual verify: 30 分钟 + simulator 实跑 30 分钟
- buffer (策略 A 出错 / 测试 flake / lint fix): 1 小时

总: **~5.5 小时** Codex session.

## 风险 / 待 implementer 关注

1. **xcodeproj.pbxproj merge 难调试**: 加新 build configuration 时, 字段顺序 / xcuserdata / xcsharedata 任何一个错都会让 Xcode 打开报错. 推荐 Codex 用 Xcode GUI 跑一遍验证 (XcodeBuildMCP 启动 simulator, 切换 scheme 选择)
2. **AuthRepository / TokenStoring protocol 实际签名**: 上面给的 sketch 是基于 spec 011 + Session.swift 推断, 实际字段名 (e.g. `AuthTokens` vs `AuthResult.AccessTokens`, optional 状态等) 以 AppShell 现有源码为准. 不一致时按现有 protocol 贴齐, 不是改 protocol.
3. **DemoUserSeed.coach.id 必须 deterministic**: 否则跨重启 InMemoryPlanRepository.preview() 跟 user.id 关联失败 (虽然现在 preview 不依赖 user.id, 防御性). 用 UUID(uuidString: "0000...0001") 锁定.
4. **Session.bootstrap 的 print warning P3**: 见 §技术要求 §Session.bootstrap() 行为验证, 不修.
5. **Demo 模式 logout 行为**: 见 §不做什么 第 7 项, V0 不暴露登出 UI 所以不阻塞.

## F-015 自检 (扫一遍 spec 不出现以下字眼)

`4 周扫视态` / `4 周宏观视图` / `波形图` / `变式矩阵` / `密度条` / `specificityBucket` / `waveformValue` / `accessoryDensityBucket` / `isDeloadWeek` / `Excel grid` — 本 spec 不涉及 coach planning 设计层, 自然 0 命中.

## 上游 / 下游

- **上游 (本 spec 落地依赖)**: 已合 spec 002 / 005 / 006 / 007 / 011 + AGENTS.md §Spec 生命周期 (新流程 已合 #36)
- **下游 (本 spec 落地后启用)**:
  - W22 spec 021 候选: App icon + Launch screen + Privacy manifest 资产 + Bundle ID 配置
  - W23 release engineering: TestFlight signing + archive + distribute (非 spec, 是工程任务)
  - V0.1+ spec NNN backend wiring (BackendPlanRepository 真实装 + DemoAuthRepository 退役或保留作集成测试)

## 修订记录

- 2026-05-10: 创建 (Draft). Claude 起草, Codex 接力实装.
