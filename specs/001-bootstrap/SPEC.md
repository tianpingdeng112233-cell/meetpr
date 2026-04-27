# 001 — Xcode 项目 + 6 SPM target 骨架 (Bootstrap)

- **状态**: InReview
- **PR**: (待填)
- **来源**: [ADR 005 §1 模块结构](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) · CLAUDE.md "下一步" §3

## 目标

把 ADR 005 §1 定的 6 个 SPM target 骨架立起来, 让 Xcode 项目能 build / test / pass CI, 之后所有 feature spec (002+) 可在此基础上加代码.

## 范围

### 做什么

1. **生成 Xcode 项目 `MeetPR.xcodeproj`**
   - SwiftUI App template, iOS 17+ deployment target, single iPhone target named `MeetPR`
   - Bundle ID: `com.meetpr.app` (placeholder, App Store Connect 注册另议)
   - Swift 6 strict concurrency 启用
   - 启动屏: 默认 SwiftUI placeholder (无定制)
   - Universal app 不需要 (V1 仅 iPhone)

2. **6 个 SPM package**, 各自有 `Package.swift` + `Sources/<Name>/` + `Tests/<Name>Tests/`
   - 位置: `~/Projects/apps/MeetPR/Modules/<Name>/`
   - 主 Xcode target 通过 local SPM dependency 引用全部 6 个

3. **每个 package 的最小骨架**, 仅够 build 通过 + 至少 1 个 smoke test:

   #### `Modules/CoreModels/`
   ```
   Sources/CoreModels/
     User.swift              — public struct User, public enum UserRole {coach, student}
     Plan.swift              — public struct Plan (id/title 占位字段)
     // 后续 spec 加 Cycle / Set / Exercise / Evaluation*
   Tests/CoreModelsTests/
     UserTests.swift         — 测试 User init + Codable 往返
   ```

   #### `Modules/Networking/`
   ```
   Sources/Networking/
     APIClient.swift         — public final class APIClient (单例 .shared, baseURL 从 env 读, 仅有 stub get/post 方法返回 stub data)
     Endpoints.swift         — public enum Endpoint (auth/coach/student 几个 case, 仅 path string)
     // 后续 spec 加 VideoUpload/, DTO/, Auth/
   Tests/NetworkingTests/
     APIClientTests.swift    — 测试 APIClient.shared 不为 nil + Endpoint case 的 path
   ```
   依赖: `CoreModels`

   #### `Modules/DesignSystem/`
   ```
   Sources/DesignSystem/
     Colors.swift            — public extension Color { static let meetprPrimary = Color(...) }
     Typography.swift        — public struct MeetPRFont 占位
     PrimaryButton.swift     — public struct PrimaryButton: View (一个 styled button)
   Tests/DesignSystemTests/
     ColorsTests.swift       — 测试 Color.meetprPrimary 不等于 Color.clear
   ```

   #### `Modules/AppShell/`
   ```
   Sources/AppShell/
     Session.swift           — public final class Session (@Observable @MainActor), enum State {anonymous/authenticating/authenticated(User)}; init(api: APIClient); fakeLogin/logout 方法 (Phase 1 stub, spec 002 替成真实)
     RootView.swift          — public struct RootView: View (从 environment 取 Session; switch session.state → AuthFlowView / CoachRootView / StudentRootView)
     AuthFlowView.swift      — public struct AuthFlowView: View (placeholder: 一个 "Sign in as Coach" 和 "Sign in as Student" 两个 button, 点了 fakeLogin 设 state = .authenticated(User(role: .coach 或 .student)))
   Tests/AppShellTests/
     SessionTests.swift      — 测试 Session 初始 state == .anonymous; fakeLogin 后 == .authenticated; logout 后回 .anonymous
   ```
   依赖: `CoreModels`, `Networking`, `DesignSystem`, `CoachKit`, `StudentKit`

   #### `Modules/CoachKit/`
   ```
   Sources/CoachKit/
     CoachRootView.swift     — public struct CoachRootView: View; body 返回 NavigationStack 包一个 Text("Hello Coach 👨‍🏫")
   Tests/CoachKitTests/
     CoachRootViewTests.swift — smoke test: CoachRootView 可初始化
   ```
   依赖: `CoreModels`, `Networking`, `DesignSystem`. **明令不可 import StudentKit** (Package.swift 不声明)

   #### `Modules/StudentKit/`
   ```
   Sources/StudentKit/
     StudentRootView.swift   — public struct StudentRootView: View; body 返回 NavigationStack 包一个 Text("Hello Student 🏋️")
   Tests/StudentKitTests/
     StudentRootViewTests.swift — smoke test
   ```
   依赖: `CoreModels`, `Networking`, `DesignSystem`. **明令不可 import CoachKit** (Package.swift 不声明)

4. **`MeetPRApp.swift`** (主 target 入口, ~10 行):
   ```swift
   import SwiftUI
   import AppShell
   import Networking

   @main
   struct MeetPRApp: App {
       @State private var session = Session(api: APIClient.shared)
       var body: some Scene {
           WindowGroup {
               RootView().environment(session)
           }
       }
   }
   ```

5. **更新 `.xcodebuildmcp/config.yaml`** 写入实际的 project + scheme + simulator 默认值:
   ```yaml
   project: MeetPR.xcodeproj
   scheme: MeetPR
   simulator: iPhone 15  # 或最新可用
   ```

6. **CI workflow 验证 (`.github/workflows/ci.yml`)**: push 到 feat/001-bootstrap 分支后:
   - lint (swiftlint) 通过
   - format check (swift-format) 通过
   - `xcodebuild -scheme MeetPR -destination 'generic/platform=iOS Simulator' build` 通过
   - `xcodebuild test -scheme MeetPR -destination 'platform=iOS Simulator,name=iPhone 15'` 通过, 6 个 target 的 smoke test 全绿

### 不做什么

- ❌ 任何业务功能 (auth 真实流程 / 网络真实调用 / 数据库 / 视频上传 / 推送) — 留 spec 002+
- ❌ Apple Sign-In 集成 — V1 公测前都不做 (ADR 005 §决策)
- ❌ Universal Links 配置 — Stage 3-4 域名 + ICP 完成后 (ADR 005 §决策)
- ❌ App Icon / Launch Screen 定制 — 后续 spec
- ❌ Localization xcstrings 完整化 — spec 003 加 (本 spec 仅初始化空 xcstrings 文件占位)
- ❌ AGENTS.md 列的所有"待定"技术栈条目 (持久化 / 推送等) — 都在 ADR 005 已定, 但 V1 实现按 spec 002+ 节奏
- ❌ 引入任何第三方依赖 — 仅 Apple platform native (URLSession / SwiftUI / Foundation)

## 技术要求

### Package.swift 规范 (每个 SPM target)

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "<TargetName>",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "<TargetName>", targets: ["<TargetName>"])
    ],
    dependencies: [
        // local path dependencies, e.g.:
        // .package(path: "../CoreModels")
    ],
    targets: [
        .target(name: "<TargetName>", dependencies: [/* "CoreModels" */]),
        .testTarget(name: "<TargetName>Tests", dependencies: ["<TargetName>"])
    ]
)
```

### Strict Swift 6 concurrency

`Package.swift` 各 target 加:
```swift
swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
```

### 命名约定

- Module name: PascalCase (`CoreModels`, `AppShell`, `CoachKit`)
- 文件名: PascalCase, 一个 type 一个文件 (除非紧密相关; AGENTS.md 硬规矩)
- 不使用 emoji 命名

### `@Observable` + `@MainActor` 规范 (Session 类)

```swift
import SwiftUI
import CoreModels
import Networking

@Observable
@MainActor
public final class Session {
    public enum State: Sendable {
        case anonymous
        case authenticating
        case authenticated(User)
    }

    public private(set) var state: State = .anonymous
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    // Phase 1 stub — spec 002 替成真实 login
    public func fakeLogin(role: UserRole) {
        let user = User(id: UUID(), role: role, displayName: "Test User")
        state = .authenticated(user)
    }

    public func logout() {
        state = .anonymous
    }
}
```

### Bundle ID 与 Signing

- Bundle ID: `com.meetpr.app`
- Signing: 用 personal Apple ID 自动签名 (Xcode → Signing & Capabilities → Automatically manage signing). 公司账号注册后再迁
- 不开启 entitlements (V1 暂不需 Push / Universal Links / iCloud)

## 验收标准

- [ ] `~/Projects/apps/MeetPR/MeetPR.xcodeproj` 存在, 用 Xcode 17+ 能打开无报错
- [ ] `~/Projects/apps/MeetPR/Modules/` 下 6 个目录存在, 每个有 `Package.swift` + `Sources/` + `Tests/`
- [ ] `swift build` 在每个 Modules/* 目录单独跑过 (验证 SPM 独立性)
- [ ] `xcodebuild build -scheme MeetPR ...` 通过, 0 warning, 0 error
- [ ] `xcodebuild test -scheme MeetPR ...` 跑过, 6 个 SPM target smoke test 全绿
- [ ] **CoachKit 不可 import StudentKit**: 在 `CoachKit/Sources/CoachKit/CoachRootView.swift` 临时加 `import StudentKit` 行, build 应该失败 (验证 Package.swift 强制隔离). 验证完移除该行
- [ ] **StudentKit 不可 import CoachKit**: 同上反向
- [ ] **CI 真跑 (不再 skip)**: push feat/001-bootstrap 分支, GitHub Actions 应执行 build + test step (检查 logs 看到 `xcodebuild test` 输出)
- [ ] swiftlint + swift-format 在所有新增 .swift 文件上通过
- [ ] `.xcodebuildmcp/config.yaml` 已写入 project + scheme + simulator 默认值
- [ ] **手动走一遍** (验证 RootView 状态机 + 角色路由):
  - 在 Xcode 跑模拟器
  - 启动看到 AuthFlowView 两个 button ("Sign in as Coach" / "Sign in as Student")
  - 点 "Sign in as Coach" → 屏幕变成 "Hello Coach 👨‍🏫"
  - 在模拟器 Cmd-Q (杀进程) + 重启 → 因无持久化, 回到 AuthFlowView (验证 anonymous default)
  - 点 "Sign in as Student" → 屏幕变成 "Hello Student 🏋️"
  - **不**测试 logout: logout button 留 spec 002 (auth feature) 实现, 那时引入 protocol-based session 注入解决跨 kit 访问

## 参考

- 相关 ADR:
  - [ADR 005 iOS architecture](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — 架构总纲, 6 SPM target 切分依据
  - [ADR 003 v4 dual-end native](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md) — 单 binary 决策
  - [ADR 004 backend selection](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md) — 后端 stack (本 spec 不实现 backend, 仅 APIClient stub)
- 相关 PRD: 暂无 (本 spec 是脚手架, 不映射 PRD feature)
- AGENTS.md / CLAUDE.md (`~/Projects/apps/MeetPR/`): 工程约定 + 启动必读顺序

## Notes (给 Codex)

- 本 spec 是**脚手架**, 不要试图实现真实功能 (auth 网络调用 / repository / 视频 upload 等). 任何 stub 之外的实现属于超 scope, 写到 `NOTES.md` 等下个 spec
- Xcode project 生成可手动 (Xcode UI) 或脚本 (XcodeGen / Tuist), 选你最快的. 推荐手动 - V1 单 dev 不需要工具链复杂度
- **跨 kit Session 访问**: Spec 001 placeholder 阶段 `CoachRootView()` / `StudentRootView()` 不需要访问 Session (它们只显示静态 "Hello" 文本). Logout / Session 读取逻辑留 spec 002 实现, 那时引入 SessionStateProtocol 在 CoreModels 解决 (CoachKit/StudentKit 都依赖 CoreModels, 不引循环). 本 spec 不要预留任何 Session 相关代码进 CoachKit/StudentKit.
- 如果遇到 Xcode 17 + Swift 6 strict concurrency 与 SwiftUI environment 注入有兼容问题 (`@Observable` + `@MainActor` + `.environment()` 偶尔有怪 warning), 写到 `QUESTIONS.md`
- 完成后在 `FOLLOWUPS.md` 加一项: F-007 "Bundle ID `com.meetpr.app` 公司账号注册后迁"
