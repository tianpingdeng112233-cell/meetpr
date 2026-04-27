# 002 — CoreModels Phase 1: Identity & Onboarding 领域类型

- **状态**: InReview (spec 001 已 merge 进 main 于 2026-04-27,Modules/CoreModels stub 就位,本 spec 接力替换)
- **PR**: (待填)
- **来源**: [data-model.md v1.1 §1.1–1.3, §1.5–1.6](~/Brain/wiki/projects/MeetPR/data-model.md) · [ADR 005 §1](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) · [ADR 003 v4](~/Brain/wiki/projects/MeetPR/decisions/003-dual-end-native-architecture.md)

## 目标

把 data-model.md v1.1 中 **身份 / onboarding / 绑定** 相关的领域 entity 翻成 Swift pure value types, 替换 spec 001 在 `CoreModels` 留下的 `User.swift` / `Plan.swift` 两个 stub. 这是 `CoreModels` 模块第一份实质内容; 后续 spec (003+) 按领域分批补 Workout / Plan / Evaluation / e1RM / Video.

> CoreModels 即 ADR 005 §1 定的 6 个 SPM target 中"零 SwiftUI、纯领域类型"的那个 — 给 Networking / CoachKit / StudentKit 共用.

## 范围

### 做什么

1. **删除** spec 001 留下的 stub `Modules/CoreModels/Sources/CoreModels/Plan.swift`. Plan 留 spec 004 加.
2. **替换** stub `Modules/CoreModels/Sources/CoreModels/User.swift` 为 v1.1 完整字段版本.
3. **新增 entity** 文件 (`Modules/CoreModels/Sources/CoreModels/Entities/`):
   - `User.swift` (从根目录 move 进 Entities/)
   - `CoachProfile.swift`
   - `StudentProfile.swift` (含完整 onboarding Type A/B/C/D 字段, 详见 data-model §1.3)
   - `BindRequest.swift`
   - `InviteCode.swift`
4. **新增 enum** 文件 (`Modules/CoreModels/Sources/CoreModels/Enums/`):
   - `UserRole` (`coach` / `coached_student` / `self_train_student` — 单值, 见 ADR 003 v4)
   - `TrainingMode` (`coached` / `self_train`)
   - `Gender` (`M` / `F`)
   - `UnitSystem` (`metric` / `imperial`)
   - `SquatStance` (`high_bar` / `low_bar`)
   - `DeadliftStance` (`conventional` / `sumo`)
   - `BenchGrip` (`narrow` / `standard` / `wide`)
   - `GymTier` (`home_with_rack` / `commercial` / `professional`)
   - `BindRequestStatus` (`pending` / `accepted` / `rejected` / `expired` / `cancelled`)
   - `InviteCodeType` (`personal_permanent` / `single_use` / `time_limited` / `coach_referral`)
5. **新增** `Modules/CoreModels/Sources/CoreModels/Codec.swift`, 暴露 `MeetPRCodec.encoder` / `MeetPRCodec.decoder` 工厂.
6. **测试** (`Modules/CoreModels/Tests/CoreModelsTests/`):
   - 每个 entity ≥ 1 个 Codable round-trip 测试
   - 每个 enum ≥ 1 个 raw-value 检查 (encode 后 JSON 字符串包含期望的 snake_case)
   - 至少 1 个针对 `MeetPRCodec` 的 snake_case key 转换测试 (e.g. `created_at` ↔ `createdAt`)
   - 至少 1 个 ISO8601 日期往返测试

### 不做什么

- ❌ Exercise / Plan / PlanDay / PlanExercise / PlanSet / ProgressionRule / Override (留 spec 003-004)
- ❌ EvaluationPeriod / StudentEvaluation / StudentEvaluationVersion (留 spec 005)
- ❌ e1RMHistory (留 spec 006)
- ❌ Video / CoachFeedback (留 spec 007)
- ❌ WeekTemplate + 子 entity (留 spec 008)
- ❌ V2/V3 预埋字段 (`coach.public_profile_id`, `discoverable`, `case_videos`, V2 `TrainingMeet`, V3 `CoachReview` / `CoachPublicProfile`) — 留 V1.5+
- ❌ V1.5 多角色升级 (本 spec 只做单 `role: UserRole`, 不写 `[UserRole]`)
- ❌ Apple Sign-In 实际接入 (字段 `appleUserID: String?` 占位即可; 真接入留 auth feature spec)
- ❌ 任何业务逻辑 / Repository / API 调用 / SwiftUI view / Combine

## 技术要求

### Codable 策略 (统一在 `MeetPRCodec`)

| Backend (PostgreSQL / JSON) | Swift |
|---|---|
| `created_at` (snake_case key) | `createdAt` (camelCase, 由 `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` 转换) |
| ISO 8601 timestamp string | `Date` (`DateDecodingStrategy.iso8601`) |
| `decimal` (e.g. `height_cm`, `weight_kg`, `current_squat_1rm`) | **`Decimal`** ✋ 不用 `Double` — 后端 RDS 是 `decimal`, 精度敏感 |
| UUID string | `UUID` |
| nullable column | Swift `Optional` |
| array column | Swift array; backend `null` 数组按 `[]` 解码 (decode 用 `decodeIfPresent ?? []`) |
| enum string (e.g. `"coached_student"`) | enum case + **显式 `rawValue`** (见下) |

### Enum raw value 必须显式写

```swift
public enum UserRole: String, Codable, Hashable, Sendable, CaseIterable {
    case coach
    case coachedStudent = "coached_student"
    case selfTrainStudent = "self_train_student"
}
```

理由: `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` **只转 dictionary key, 不转 enum raw value**. 不写显式 raw value, 后端发 `"coached_student"` 客户端会解码失败. 所有 snake_case 多词 enum case 都要写.

### `Codec.swift`

```swift
import Foundation

public enum MeetPRCodec {
    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]   // 让测试 deterministic
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
```

### entity 模板 (User 示例)

```swift
import Foundation

public struct User: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let phone: String
    public let appleUserID: String?
    public let name: String?
    public let avatarURL: URL?
    public let gender: Gender?
    public let birthDate: Date?
    public let heightCm: Decimal?
    public let weightKg: Decimal?
    public let unitSystem: UnitSystem
    public let role: UserRole
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        phone: String,
        appleUserID: String? = nil,
        name: String? = nil,
        avatarURL: URL? = nil,
        gender: Gender? = nil,
        birthDate: Date? = nil,
        heightCm: Decimal? = nil,
        weightKg: Decimal? = nil,
        unitSystem: UnitSystem,
        role: UserRole,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.phone = phone
        self.appleUserID = appleUserID
        self.name = name
        self.avatarURL = avatarURL
        self.gender = gender
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.unitSystem = unitSystem
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### 不可变性

- **默认所有 stored property `let`** (immutable). 客户端要"改一个字段"就构造新实例 (后续 spec 加 builder helper, 本 spec 不做).
- 后续 view-model spec 引入 mutable wrapper 时再决定哪些 entity 字段能改.

### 文件 / 目录约定

- 一个 type 一个文件 (AGENTS.md 已写明)
- enum 文件名 = enum 名, entity 文件名 = entity 名
- 不要把多个 entity 塞同一个文件 (即使关系密切)
- 子类型 (e.g. `User.UserMetadata`) 跟 owner 同文件; 但本 spec 没有 nested type 需求

### 严格并发

继承 spec 001 在 `Package.swift` 配的 `.enableUpcomingFeature("StrictConcurrency")`. 所有 type 必须 `Sendable` (value type + 全 `let` + 全 Sendable 字段 ⇒ 自动 `Sendable`).

### 不允许的 import

- ❌ `SwiftUI` (CoreModels 是 0 SwiftUI 模块, 见 ADR 005 §1)
- ❌ `Combine`
- ❌ `Networking` (Networking 反过来依赖 CoreModels, 引入会循环)
- ✅ 只允许 `Foundation`

## 验收标准

- [ ] 5 个 entity 文件存在 (`User`, `CoachProfile`, `StudentProfile`, `BindRequest`, `InviteCode`)
- [ ] 10 个 enum 文件存在
- [ ] `Codec.swift` 存在, public 暴露 `MeetPRCodec.encoder` / `.decoder`
- [ ] 旧 `Modules/CoreModels/Sources/CoreModels/Plan.swift` 删除
- [ ] 旧 `Modules/CoreModels/Sources/CoreModels/User.swift` (根目录 stub) 删除或 move 到 `Entities/User.swift`
- [ ] `swift build` 在 `Modules/CoreModels/` 单独跑通过, 0 warning, 0 error, Swift 6 strict concurrency
- [ ] `swift test` 通过, 测试数 ≥ 5 entity round-trip + 10 enum raw-value + 2 codec smoke = **17 个**
- [ ] User round-trip 测试断言: encode 后 JSON 包含字符串 `"role":"coached_student"` 和 `"created_at":` (snake_case)
- [ ] StudentProfile round-trip 测试覆盖 `training_days_of_week: [1,3,5,6]` (`[Int]` 字段) 和 `current_squat_1rm: "180.5"` (`Decimal` 字段, JSON 默认 string 输出)
- [ ] InviteCode round-trip 覆盖 `type: "personal_permanent"` (snake-case enum)
- [ ] 在主 Xcode target 跑 `xcodebuild build -scheme MeetPR ...` 通过 (CoreModels 改了不能破坏 AppShell / CoachKit / StudentKit 的引用)
- [ ] **隔离回归**: CoachKit 仍不可 import StudentKit (spec 001 验证步骤复用一次)
- [ ] swiftlint + swift-format 全绿
- [ ] CI 在 `feat/002-core-models-identity` 分支跑过, 全绿

## 参考

- 数据模型源: [`~/Brain/wiki/projects/MeetPR/data-model.md`](~/Brain/wiki/projects/MeetPR/data-model.md) §1.1 (User), §1.2 (CoachProfile), §1.3 (StudentProfile), §1.5 (BindRequest), §1.6 (InviteCode)
- ADR 005 §1 模块结构: `CoreModels = 0 SwiftUI, 纯领域类型`
- ADR 003 v4 单角色: `User.role: enum` 单值, **不是** `[UserRole]`
- spec 001-bootstrap 验收 §"CoachKit 不可 import StudentKit": 本 spec 不能破坏

## Notes (给 Codex)

- 本 spec 是**机械翻译工作** — 严格按 data-model.md §1.1–1.3 §1.5–1.6 列字段, 不要"优化"字段名 / 加新字段 / 改类型. 任何疑问写 `QUESTIONS.md` 由 Claude review, 不擅自决定.
- 如果发现 data-model 字段命名 ambiguous (如 `notes` 是教练给学员的还是学员自己记的), 不要猜, 写 `QUESTIONS.md`.
- 测试 fixture 用最小**完整**数据 (即不要全 nil; 至少必填字段是真值, e.g. `phone` + `role` + timestamps).
- 别 import `SwiftUI` / `Combine`; 只 `Foundation`.
- `Decimal` JSON 默认行为: encode 时输出为 string (e.g. `"180.5"`). 测试时记得断言 string 而不是 number.
- `URL?` 字段 (e.g. `avatarURL`): 后端可能传相对路径. 本 spec 假设后端传完整 URL string; 如果不是, 写 `QUESTIONS.md` 让 Claude 决定是改 `String?` 还是 spec backend.
- PR description 必须列每个 entity vs data-model.md §X.Y 的字段对照清单, 方便 review (用 `gh pr create --body` HEREDOC 一次性贴).
- 完成后**别 self-merge** — Claude review 后才 merge.
