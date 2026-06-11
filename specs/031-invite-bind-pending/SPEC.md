# 031 — 邀请码 + 绑定请求 + 待接收(教练发码 → 学员输码 → BindGate 路由)

- **状态**: InProgress
- **PR**: TBD
- **来源**:
  - [V0.1b 完成波决议 §2 ⑤](~/Brain/wiki/projects/MeetPR/v0_1b_completion_wave.md) — "教练 Personal 永久码 + 一次性/限时码;学员输码→绑定请求→'待接收'状态页;48h/7d 惰性过期"
  - **backend [spec 005-bind-eval-profile](~/Projects/apps/MeetPR-backend/specs/005-bind-eval-profile/SPEC.md)(wire shape 最高权威,已实装合 staging)** — §端点 A 邀请码 / §端点 B 绑定状态机;本 spec 全部字段名、错误码、状态语义**逐字对齐它,不自创**
  - [evaluation-workflow.md v1.1](~/Brain/wiki/projects/MeetPR/evaluation-workflow.md) — §2 邀请码 3 类 + 生成 UX / §3.4 silent 拒绝中性文案 / §3.5 学员待接收
  - [student-onboarding.md v2.4](~/Brain/wiki/projects/MeetPR/student-onboarding.md) — §A 待接收状态页(等待时长 + 已上传资料计数 + 取消请求)
  - 上游 [spec 025 real auth](../025-real-auth-login-keychain/SPEC.md) — `Session` / `SessionStateReader` / `KeychainTokenStore`;BindGate 挂在 authenticated 之后
  - 上游 [spec 028](../028-e1rm-curve-pr-push/SPEC.md) + [spec 029](../029-coach-student-detail-feedback/SPEC.md) — 学员 5 tab(`StudentRootView`)与教练 3 tab(`CoachRootView` / `CoachMyProfileView`)现状结构
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — 实体进 CoreModels / 协议进 RepositoryContracts / 双实现进各 Kit 的既有惯例
  - 并行 [spec 032 onboarding](../032-onboarding-wizard/SPEC.md) — **code 暂存交接契约**(本 spec 定义 `PendingBindCodeStore`,032 在 complete 时消费;见 §技术要求"031↔032 接口契约")

## 目标

打通"陌生学员 → 教练接收前"的入口段双侧 UI:

1. **教练侧**:"我的" tab 新增 **我的邀请码** 页 — Personal 永久码卡(大字码 + 复制 + 重新生成)+ 一次性/限时码生成与列表(used_count、过期、revoke)。
2. **学员侧**:登录后无 bound coach 且无 pending 请求 → **输码页**(注册后首屏,同时采集学员姓名 display_name);提交后进 **待接收** 状态页(等待时长、已上传资料计数、取消请求、过期/被拒后重新输码)。
3. **路由层**:`StudentRootView` 之前加一层 **BindGate** — 无绑定 → 输码/待接收流;有 accepted → 正常 5 tab;评估期中 → 留 hook 点给 spec 033(本 spec 不做评估期 UI)。

backend 全部端点已 live(`POST/GET/DELETE /coach/invite-codes`、`POST /bind-requests`、`GET /bind-requests/mine`、`DELETE /bind-requests/:id`),本 spec **backend 0 改动**。

教练看到啥:

```
教练 "我的" tab
  ↓ 新 Card "我的邀请码" → InviteCodesView
  ┌── Personal 永久码 ──────────────┐
  │  XK7M PQ2R VT  (大字 monospaced) │
  │  已使用 23 次                     │
  │  [复制]  [重新生成]               │   ← 重新生成弹确认"旧码立即失效"
  └─────────────────────────────────┘
  ┌── 一次性码 + 限时码 ─────────────┐
  │ [+ 一次性码]  [+ 限时码]          │   ← 弹生成 sheet(备注 label;限时码选 7/30/自定义天)
  │ 现有码(created_at DESC):          │
  │ · 一次性 / 给小明 / 待用    [复制] │
  │ · 限时 / 馆活动周 / 6 天后过期     │
  │ · 一次性 / (无备注) / 已使用       │
  │   (swipe → 撤销)                  │
  └─────────────────────────────────┘
```

学员看到啥(coached_student 注册登录后):

```
[ 登录成功,role = coachedStudent ]
  ↓ BindGate 查 GET /bind-requests/mine
  ├─ accepted → StudentRootView 5 tab(033 在此插评估期 gate,本 spec 直通)
  ├─ pending  → 待接收页
  └─ 无记录 / rejected / expired / cancelled → 输码页
       ↓ 输入邀请码(10 位,自动大写)+ 你的姓名(display_name)
       ↓ [提交]
       ├─ onboarding 已完成 → 直接 POST /bind-requests → 待接收页
       └─ onboarding 未完成 → 暂存 (code, displayName) → 进 7 步向导(spec 032)
            ↓ (032) complete 成功 → 用暂存 code 发 POST /bind-requests → 待接收页

[ 待接收页 ]
  已发送绑定请求 / 等待教练 David(内测教练) 接收
  ⏱️ 已等待: 2 小时 14 分(每分钟刷新)
  ┌ 你已提交给教练的资料 ┐
  │ · onboarding 完整资料 │
  │ · 4 份上传资料        │   ← upload_attachment_ids.count(027 未合时 = 0,该行隐藏)
  └──────────────────────┘
  [取消请求](确认弹窗 → DELETE → 回输码页)
  "教练通常在 24-48 小时内响应;7 天未响应自动过期,可重新输码。"
  (下拉刷新 / 回前台自动刷新;accepted → 进 5 tab;rejected/expired → 回输码页带中性提示)
```

## 关键决策(裁量,起草拍板)

| #   | 决策 |
| --- | --- |
| D1  | **发绑定请求的时机 = onboarding complete 之后**(产品顺序对齐 wiki funnel "扫码→onboarding→发请求";backend `POST /bind-requests` 需要 code)。iOS 流程:输码(本 spec)→ 暂存 → onboarding(032)→ complete 时消费暂存 code 发请求。**例外**:输码时 onboarding 已 completed(被拒/过期后重输码、或 032 未合入的过渡期)→ 输码页直接发请求。 |
| D2  | **code 暂存用 UserDefaults**(`PendingBindCodeStore`),非 Keychain 非文件 — 邀请码本来就是教练对外分发的非机密,体积 < 200B;key 按 studentId 隔离。 |
| D3  | **输码页硬卡 10 位 + D4 字母表**(`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`,输入自动大写、剔除易混字符)。理由:code 可能在 7 步 onboarding **之后**才真正发给 backend 校验,格式预检是防止学员拿假码填完 7 步才发现错的唯一前置闸;backend D4 锁定生成规则为 10 位该字母表,两端耦合写进两侧 spec,变更需同步。 |
| D4  | **BindGate 放 StudentKit**(`Features/Bind/`),AppShell `RootView` 只在 `case .coachedStudent` 包一层;`selfTrainStudent` 不过 BindGate 直进 5 tab(backend `requireRole('coached_student')`,自练不发绑定请求)。 |
| D5  | **onboarding 完成判定经闭包注入**(`isOnboardingComplete: @Sendable () async -> Bool`),不直接依赖 032 的 `OnboardingRepository` — 两 spec 并行落地,031 先合时 AppShell 注 `{ true }`(退化为"输码即发请求",backend 容忍 onboarding 未完成,接收队列显示 `completed: false`);032 合入后换真实现 + 接向导路由。 |
| D6  | **教练 Personal 码不自动生成**:进页发现无 active personal code → 显示空态卡 + [生成我的永久码] 显式按钮。理由:自动生成在加载失败重试路径上可能连发两次 POST(第二次会静默 revoke 第一张已被复制出去的码);显式按钮行为可预期,成本 = 教练多点一下。 |
| D7  | **码状态读时计算**(client 端):`revoked_at != nil → 已撤销`;`type == single_use && used_count >= max_uses → 已使用`;`expires_at < now → 已过期`;否则有效。与 backend 惰性过期语义一致(backend 不回 status 字段)。 |
| D8  | **rejected 永远中性呈现**(wiki §3.4):学员侧不出现"被拒绝"字样,输码页顶部 notice = "教练当前不接收新学员,请输入新邀请码或稍后再试"。expired = "上次请求 7 天未响应已自动过期,可重新发送或换教练"。cancelled 无提示。 |
| D9  | **待接收页状态刷新 = onAppear + 下拉刷新 + scenePhase 回 .active**,无轮询 timer、无推送(V0.1b 无 APNs,wave 决议)。文案不承诺任何推送。 |
| D10 | **DEMO_MODE seed**:demo 学员 = 已 accepted bind(现有 demo 直通 5 tab 流程零破坏);demo 教练 = 1 张 personal(used 23)+ 1 张待用一次性 + 1 张 6 天后过期限时码。InMemory 实现模拟 backend 核心语义(见 §7)。 |
| D11 | **码的展示分组**:UI 显示 `XK7M PQ2R VT`(4-3-3 空格分组,易读不易复制错);复制到剪贴板永远是无分隔原始 10 位。学员输入框自动剥离空格/连字符再校验。 |

## 范围

### 做什么

#### 1. CoreModels 新增 `InviteCode` + `BindRequest`

位置:`Modules/CoreModels/Sources/CoreModels/Entities/Bind/`(新目录,2 文件)

```swift
public enum InviteCodeType: String, Codable, CaseIterable, Sendable {
  case personalPermanent = "personal_permanent"
  case singleUse = "single_use"
  case timeLimited = "time_limited"
}

public struct InviteCode: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let coachId: UUID
  public let code: String          // 10 位,大写,字母表 ABCDEFGHJKLMNPQRSTUVWXYZ23456789
  public let type: InviteCodeType
  public let maxUses: Int?         // single_use = 1;其余 nil
  public let usedCount: Int
  public let expiresAt: Date?      // time_limited 才有
  public let revokedAt: Date?
  public let label: String?
  public let createdAt: Date
  public init(...) { ... }
}

public enum BindRequestStatus: String, Codable, Sendable {
  case pending, accepted, rejected, expired, cancelled
}

public struct BindRequest: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
  public let coachDisplayName: String?   // coach_profiles left join,可 null → UI 显示"教练"
  public let inviteCodeId: UUID?         // code 被删 SET NULL,可 null
  public let status: BindRequestStatus
  public let submittedAt: Date
  public let respondedAt: Date?
  public let expiredAt: Date             // NOT NULL(pending 创建即 +7d)
  public let skipEvaluation: Bool
  public let skipReason: String?
  public init(...) { ... }
}
```

字段与 backend 005 §端点 A/B wire shape 一一对应(snake_case ↔ camelCase 由 `MeetPRCodec` 自动转换)。

#### 2. `RepositoryContracts` 新增 2 协议

位置:`Modules/RepositoryContracts/Sources/RepositoryContracts/`(新 2 文件)

```swift
/// 教练侧邀请码管理(spec 031)。对应 backend /coach/invite-codes 三端点。
public protocol InviteCodeRepository: Sendable {
  /// type == .timeLimited 时 expiresInDays 必填(1-365);其余必须为 nil(backend zod superRefine)
  func createCode(type: InviteCodeType, label: String?, expiresInDays: Int?) async throws -> InviteCode
  /// 全部码(含已 revoke),created_at DESC(backend 排序原样透传)
  func listCodes() async throws -> [InviteCode]
  /// 幂等;非本教练的码 backend 回 404 INVITE_CODE_NOT_FOUND
  func revokeCode(id: UUID) async throws
}

/// 学员侧绑定请求(spec 031)。对应 backend /bind-requests 三端点。
public protocol BindRepository: Sendable {
  /// code 提交前由调用方 uppercase 归一;display_name 1-100 trim 非空。
  /// 失败抛带 machine code 的错误(INVITE_CODE_INVALID / BIND_REQUEST_ALREADY_PENDING / BIND_ALREADY_BOUND)
  func submitBindRequest(code: String, displayName: String) async throws -> BindRequest
  /// 该学员最新一条(含历史 accepted/rejected/expired/cancelled);从未发过 → nil。
  /// backend 读时已做惰性过期翻转,client 不自判 expired。
  func myBindRequest() async throws -> BindRequest?
  /// own + pending → cancelled;非 pending 抛 BIND_REQUEST_NOT_PENDING(409)
  func cancelBindRequest(id: UUID) async throws
}
```

#### 3. `Networking` 增量:DTO + APIClient extension + 错误信封

位置:
- `Modules/Networking/Sources/Networking/DTO/BindDTOs.swift`(新)— `InviteCodeDTO` / `BindRequestDTO` / `CreateInviteCodeRequestDTO` / `CreateBindRequestRequestDTO` / `InviteCodesResponseDTO`(`{ invite_codes: [...] }`)/ `MyBindRequestResponseDTO`(`{ bind_request: ... | null }`)+ `toDomain()` mapping(`DomainMapping.swift` 既有模式)
- `Modules/Networking/Sources/Networking/APIClient+Bind.swift`(新):

```swift
extension APIClient {
  // 教练侧
  public func createInviteCode(_ body: CreateInviteCodeRequestDTO, accessToken: String) async throws -> InviteCodeDTO        // POST /coach/invite-codes → 201
  public func inviteCodes(accessToken: String) async throws -> InviteCodesResponseDTO                                        // GET /coach/invite-codes → 200
  public func revokeInviteCode(id: UUID, accessToken: String) async throws                                                   // DELETE /coach/invite-codes/:id → 204
  // 学员侧
  public func createBindRequest(_ body: CreateBindRequestRequestDTO, accessToken: String) async throws -> BindRequestDTO     // POST /bind-requests → 201
  public func myBindRequest(accessToken: String) async throws -> MyBindRequestResponseDTO                                    // GET /bind-requests/mine → 200
  public func cancelBindRequest(id: UUID, accessToken: String) async throws                                                  // DELETE /bind-requests/:id → 204
}
```

**Request wire(照抄 backend 005,逐字)**:

```json
POST /coach/invite-codes   { "type": "time_limited", "label": "馆活动周", "expires_in_days": 7 }
POST /bind-requests        { "code": "XK7MPQ2RVT", "display_name": "张三" }
```

**错误信封解析**:`APIError.httpStatus(Int, Data)` 的 Data 按既有 `AuthErrorEnvelopeDTO` 同款 `{ "error": "<MACHINE_CODE>" }` 解;Networking 加一个共享 helper(`BindErrorCode.from(APIError) -> String?`),repository 层把 machine code 翻成 typed error:

```swift
public enum BindRequestError: Error, Equatable, Sendable {
  case invalidCode              // 400 INVITE_CODE_INVALID(不存在/revoked/过期/用尽,backend 统一不区分,防枚举)
  case alreadyPending           // 409 BIND_REQUEST_ALREADY_PENDING
  case alreadyBound             // 409 BIND_ALREADY_BOUND
  case notPending               // 409 BIND_REQUEST_NOT_PENDING(cancel 时已被响应)
  case notFound                 // 404 BIND_REQUEST_NOT_FOUND
}
```

#### 4. `StudentKit` 新增 `PendingBindCodeStore`(031↔032 交接物)

位置:`Modules/StudentKit/Sources/StudentKit/Features/Bind/PendingBindCodeStore.swift`(新)

```swift
public struct PendingBindCode: Codable, Equatable, Sendable {
  public let code: String          // 已 uppercase + 剥分隔符归一
  public let displayName: String
  public let stashedAt: Date
}

/// 输码 → onboarding → complete 之间的 code 暂存(spec 031 定义,spec 032 消费)。
public protocol PendingBindCodeStoring: Sendable {
  func stash(_ pending: PendingBindCode, studentId: UUID)
  func peek(studentId: UUID) -> PendingBindCode?
  func clear(studentId: UUID)
}

/// UserDefaults 实现(D2),key = "bind.pendingCode.<studentId>",值 = JSON
public struct UserDefaultsPendingBindCodeStore: PendingBindCodeStoring { ... }
```

**生命周期约定**(032 同文照录):
- 写入:输码页提交且 onboarding 未完成时
- 读取/消费:① 032 complete 成功后发绑定请求;② BindGate 冷启动 resume(见 §6 状态机)
- 清除:绑定请求 **201 成功** 或 **INVITE_CODE_INVALID**(code 已确认无效,留着无意义;displayName 经 `.needsCode(prefill:)` 传回输码页预填)
- 不清除:网络失败 / already-pending / already-bound(后两者 reload mine 后状态机自然走开)

#### 5. `StudentKit` 输码页 `EnterCodeView` + `EnterCodeViewModel`

位置:`Modules/StudentKit/Sources/StudentKit/Features/Bind/`(新 2 文件)

- 标题"输入教练邀请码";副文案"没有教练?请向你的教练索取邀请码"
- code 输入框:`.keyboardType(.asciiCapable)` + `.textInputAutocapitalization(.characters)`,onChange 剥空格/连字符 + uppercase,显示按 D11 分组;**本地校验 = 恰好 10 位且全在 D4 字母表**(否则提交禁用 + hint)
- 姓名输入框:"你的姓名(教练将看到)",trim 1-100 非空;`prefill` 注入时预填(D8/INVITE_CODE_INVALID 回流场景)
- 顶部 notice 区(D8 中性文案,由 BindGate 注入)
- 提交逻辑:

```swift
@Observable @MainActor
public final class EnterCodeViewModel {
  public enum SubmitOutcome: Equatable {
    case requestSent(BindRequest)          // 已 POST(onboarding 已完成路径)
    case stashedForOnboarding(PendingBindCode)  // 已暂存,BindGate 路由去 032 向导
  }
  // deps: bind: any BindRepository, stash: any PendingBindCodeStoring,
  //       isOnboardingComplete: @Sendable () async -> Bool, studentId: UUID
  public func submit(code: String, displayName: String) async {
    let normalized = PendingBindCode(code: normalize(code), displayName: displayName.trimmed, stashedAt: now())
    if await isOnboardingComplete() {
      do { outcome = .requestSent(try await bind.submitBindRequest(code: normalized.code, displayName: normalized.displayName)) }
      catch BindRequestError.invalidCode { fieldError = .invalidCode }   // "邀请码无效或已失效"
      catch BindRequestError.alreadyPending, BindRequestError.alreadyBound { needsReload = true }  // BindGate reload
      catch { banner = .network }                                        // 通用重试
    } else {
      stash.stash(normalized, studentId: studentId)
      outcome = .stashedForOnboarding(normalized)
    }
  }
}
```

#### 6. `StudentKit` BindGate:`BindGateView` + `BindGateViewModel`(状态机核心)

位置:`Modules/StudentKit/Sources/StudentKit/Features/Bind/`(新 2 文件)

```swift
public enum BindGateState: Equatable {
  case loading
  case needsCode(prefillDisplayName: String?, notice: BindNotice?)  // notice: .coachNotAccepting / .requestExpired / nil(D8)
  case needsOnboarding(PendingBindCode)   // → 032 向导(经注入的 flow builder 渲染)
  case pendingAcceptance(BindRequest)     // → 待接收页
  case bound(BindRequest)                 // → 5 tab。spec 033 将在此插评估期分支(见下方 hook 注)
  case failed                             // mine 拉取失败 → 全屏重试态
}

@Observable @MainActor
public final class BindGateViewModel {
  public private(set) var state: BindGateState = .loading
  // deps: bind, stash, isOnboardingComplete, studentId

  public func load() async {
    state = .loading
    guard let mine = try? await bind.myBindRequest() else { state = stateOnFetchFailure(); return }
    switch mine?.status {
    case .accepted: state = .bound(mine!)
    case .pending:  state = .pendingAcceptance(mine!)
    case .none, .rejected, .expired, .cancelled:
      await resolveUnbound(latest: mine)
    }
  }

  /// 无活动绑定时的 resume 决策(冷启动杀 app 恢复也走这里):
  /// stash 有 + onboarding 已完成 → 自动补发绑定请求(032 handoff 的网络失败重试路径)
  /// stash 有 + onboarding 未完成 → 回 032 向导继续填
  /// stash 无 → 输码页(带 D8 notice)
  private func resolveUnbound(latest: BindRequest?) async {
    if let pending = stash.peek(studentId: studentId) {
      if await isOnboardingComplete() {
        do {
          let request = try await bind.submitBindRequest(code: pending.code, displayName: pending.displayName)
          stash.clear(studentId: studentId)
          state = .pendingAcceptance(request)
        } catch BindRequestError.invalidCode {
          stash.clear(studentId: studentId)
          state = .needsCode(prefillDisplayName: pending.displayName, notice: .invalidCode)
        } catch BindRequestError.alreadyPending, BindRequestError.alreadyBound {
          await load()                       // 状态已在服务端推进,重读一遍收敛
        } catch {
          state = .needsCode(prefillDisplayName: pending.displayName, notice: .network)  // stash 保留,下次 load 再试
        }
      } else {
        state = .needsOnboarding(pending)
      }
    } else {
      state = .needsCode(prefillDisplayName: nil, notice: notice(for: latest?.status))   // D8 映射
    }
  }
}
```

```swift
public struct BindGateView<MainContent: View, OnboardingContent: View>: View {
  // init(studentId:bind:stash:isOnboardingComplete:onboardingFlow:content:)
  //   onboardingFlow: (PendingBindCode, _ onCompleted: @escaping () async -> Void) -> OnboardingContent
  //     — 032 落地前 AppShell 传 EmptyView 占位(D5 下该分支不可达);032 落地后传 OnboardingWizardView
  //   content: () -> MainContent — StudentRootView
  // body: switch viewModel.state → loading 全屏 spinner(防闪烁,见 §风险 3)/ 各分支 view
  // .task { await viewModel.load() } + scenePhase .active 时 pendingAcceptance 态自动 reload(D9)
}
```

**spec 033 hook 点(本 spec 只留口子,不实装)**:`.bound(request)` 分支当前无条件渲染 `content()`。033 将把该分支扩成"`request.skipEvaluation == false` 且有未完成评估期 → 评估期页"的二级路由(预计加 `.evaluating` case + `EvaluationRepository` 查询)。本 spec 在 `BindGateState` 文档注释里写明该扩展点,**不**预埋空 case。

#### 7. `StudentKit` 待接收页 `PendingBindView` + `PendingBindViewModel`

位置:`Modules/StudentKit/Sources/StudentKit/Features/Bind/`(新 2 文件)

- 标题"已发送绑定请求";副标题"等待教练 {coachDisplayName ?? "教练"} 接收"
- 等待时长:`TimelineView(.periodic(from:by: 60))` 驱动 `now - submittedAt` → "已等待: 2 小时 14 分"
- 资料卡:"onboarding 完整资料"行(onboarding completed 时显示)+ "N 份上传资料"行(N = 自己 `GET /students/:id/onboarding` 的 `upload_attachment_ids.count`,032 的 repo 注入为可选依赖;032 未落地 / 404 / N == 0 时整行隐藏)
- 提示文案(D9,无推送承诺):"教练通常在 24-48 小时内响应;7 天未响应自动过期,可重新输码。"
- [取消请求]:confirmationDialog → `cancelBindRequest(id:)` → 成功回 `.needsCode`;`BindRequestError.notPending` → 不报错,直接 reload(可能刚被 accepted,见 §风险 5)
- 刷新:`.refreshable` + onAppear + scenePhase `.active` → BindGate reload;状态翻转由状态机分发(accepted → 5 tab;rejected/expired → 输码页 + D8 notice)

#### 8. `CoachKit` 我的邀请码:`InviteCodesView` + `InviteCodesViewModel`

位置:`Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/`(新目录 2 文件)+ `CoachMyProfileView` 改造

- `CoachMyProfileView`:在"内测须知"卡下加 NavigationLink Card "我的邀请码"(`person.badge.plus` 图标);`CoachRootView` init 注入 `inviteCodes: any InviteCodeRepository` 透传
- `InviteCodesView` 两区(见 §目标 线框):
  - **Personal 永久码卡**:取 `listCodes()` 里 `type == .personalPermanent && revokedAt == nil` 的唯一一张(backend D6 partial unique 保证至多一张);无 → 空态 + [生成我的永久码](D6);有 → 大字 monospaced 分组码(D11)+ "已使用 N 次" + [复制](UIPasteboard + "已复制" toast)+ [重新生成](confirmationDialog "重新生成后旧码立即失效,已分发的旧码将无法使用" → `createCode(type: .personalPermanent, label: nil, expiresInDays: nil)`,backend 事务内自动 revoke 旧码)
  - **一次性/限时码区**:[+ 一次性码] / [+ 限时码] → 生成 sheet(label 选填 1-100;限时码 expires_in_days segmented 7 / 30 / 自定义 stepper 1-365);列表按 created_at DESC,每行:类型 badge(一次性/限时)+ 分组码(tap 复制)+ label + 状态文案(D7 读时计算:待用 / 已使用 / X 天后过期 / 已过期 / 已撤销)+ 有效码 swipe action "撤销"(confirm → `revokeCode`)
  - 已失效码(已使用/已过期/已撤销)与有效码分两个 section,失效区置后
- VM:`@Observable`,`load()` / `createCode(...)` / `revoke(id:)`,操作后重拉 list(backend 是 source of truth,不本地拼状态)

#### 9. `StudentKit` / `AppShell` 双实现 + 装配

位置:`Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/`(教练侧 InMemory)+ `Modules/StudentKit/Sources/StudentKit/Repository/`(学员侧)+ `MeetPRApp.swift` / `RootView.swift`

- `InMemoryInviteCodeRepository`(actor,CoachKit):模拟核心语义 — personal 生成自动 revoke 旧 personal;revoke 幂等;DEMO seed per D10
- `BackendInviteCodeRepository`(actor,CoachKit):`APIClient + SessionStateReader`,既有 `BackendPlanRepository` 同款模式,无 cache(码列表轻量,每次直拉)
- `InMemoryBindRepository`(actor,StudentKit):模拟 submit 校验(假码表 + already-pending/already-bound 抛 typed error)、cancel 状态翻转;DEMO seed = 已 accepted 一条(D10)
- `BackendBindRepository`(actor,StudentKit):同上模式,无 cache(绑定状态必须实时,旧状态有害)
- `RootView` 改造:

```swift
case .coachedStudent:
  BindGateView(
    studentId: user.id, bind: studentBind, stash: pendingBindStore,
    isOnboardingComplete: isOnboardingComplete,     // 032 前 = { true }(D5)
    onboardingFlow: { pending, onCompleted in /* 032 前 EmptyView;032 后 OnboardingWizardView */ }
  ) {
    StudentRootView(studentID: user.id, plans: ..., logs: ..., feedback: ..., e1rm: ...)
  }
case .selfTrainStudent:
  StudentRootView(...)   // 不过 BindGate(D4)
```

- `MeetPRApp` 真环分支:`BackendBindRepository` / `BackendInviteCodeRepository` 注入;DEMO 分支:InMemory + seeds

#### 10. 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/CoreModels/Tests/CoreModelsTests/BindEntitiesTests.swift`(新) | `InviteCode` / `BindRequest` Codable roundtrip;status/type rawValue 与 backend 词表逐字对齐 |
| `Modules/Networking/Tests/NetworkingTests/BindDTOTests.swift`(新) | **backend 005 SPEC 的 JSON 示例原文作 fixture** decode → toDomain;encode 出 snake_case + `display_name` / `expires_in_days` 字段名逐字;`coach_display_name` null / `invite_code_id` null 路径;错误信封 machine code 解析 5 码 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Bind/BindGateViewModelTests.swift`(新) | **状态机决策表全路径**:mine ∈ {nil, pending, accepted, rejected, expired, cancelled} × stash ∈ {无, 有} × onboardingComplete ∈ {t, f};resume 自动补发(成功/invalidCode/alreadyPending/网络失败 4 路);fetch 失败 → failed |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Bind/EnterCodeViewModelTests.swift`(新) | 格式校验(10 位/字母表/小写归一/分隔符剥离/9 位 11 位拒);display_name trim 边界;onboardingComplete 两分支 outcome;invalidCode → fieldError 且 stash 不写 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Bind/PendingBindCodeStoreTests.swift`(新) | stash/peek/clear roundtrip;studentId 隔离;UserDefaults suite 注入 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Bind/PendingBindViewModelTests.swift`(新) | cancel 成功 / notPending 静默 reload;等待时长格式化(分/小时/天) |
| `Modules/CoachKit/Tests/CoachKitTests/Features/InviteCodes/InviteCodesViewModelTests.swift`(新) | 状态徽章 D7 四态判定(含 expires_at 边界);personal 重新生成后列表刷新;无 personal 空态;revoke 后重拉 |
| InMemory 双仓语义测试 | personal 自动 revoke 旧码;single_use 用尽 invalidCode;already-pending/bound 抛错;cancel 翻转 |

### 不做什么

**spec 033 范围(本 spec 仅留 hook)**:
- 教练接收队列 UI(9 项摘要卡 / 查看完整资料 / accept-reject 模态)— backend 端点已 live,iOS UI 归 033
- 评估期页(`.bound` 后的二级路由)+ 评估总结呈现
- `skip_evaluation` / `skip_reason` 的任何 UI(实体字段已带,033 消费)

**V0.1.x defer**:
- **扫码**(相机扫二维码 / 深链):V0.1 手输码;扫码入口 + code 转二维码分享卡片 V0.1.x
- APNs:新请求推教练 / 48h 未响应再推 / 接收结果推学员(wiki §3.5 推送行为全部降级为手动刷新,D9)
- 自练学员绑定路径(self_train → coached 转换是 V1.5 多角色议题)
- 解绑 / 换教练
- 码数据分析("哪个码最有效")

**明确不做(wiki / backend 已裁)**:
- spam 防护(office hours 决议移除)
- 拒绝原因填写(D18 silent)
- 学员同时多教练 UI(backend 数据层容忍双 bond,iOS 按单 bond 假定,`mine` 只看最新一条)

## 技术要求

### 031↔032 接口契约(两 spec 同文锁定,改一处必须改两处)

| 物 | 定义方 | 消费方 | 契约 |
|---|---|---|---|
| `PendingBindCodeStoring` + `PendingBindCode` | 031(StudentKit `Features/Bind/`) | 032 complete handoff | §4 生命周期表:谁写 / 谁读 / 何时清 |
| `BindRepository.submitBindRequest` | 031(RepositoryContracts) | 032 complete 后调用 | 错误处置:201 → 清 stash → 待接收;invalidCode → 清 stash → 回输码页(displayName 预填);already-* → BindGate reload;网络失败 → stash 保留 + BindGate 下次 load 自动补发(§6 resolveUnbound) |
| `isOnboardingComplete` 闭包 | 031 定义注入点 | 032 落地时由 AppShell 接 `OnboardingRepository`(profile?.completedAt != nil,404 → false) | 032 前临时值 `{ true }`(D5 退化:输码即发请求) |
| `onboardingFlow` view builder | 031 定义槽位 | 032 提供 `OnboardingWizardView(pending:onCompleted:)` | onCompleted 回调里 BindGate `load()` 收敛状态 |

### Wire 约定(全部沿用既有)

- snake_case ↔ camelCase:`MeetPRCodec`(CoreModels 既有)自动转换;**不**手写 CodingKeys 除非字段名转换有歧义
- 时间戳 ISO 8601 字符串;`expires_at` / `revoked_at` / `responded_at` nullable
- 错误信封 `{ "error": "<MACHINE_CODE>" }`,`AuthErrorEnvelopeDTO` 同构解析
- backend 005 错误码 ↔ UI 行为映射(§3 `BindRequestError`)是本 spec 验收面,枚举写死不串字符串

### 模块归属(锁定)

| 物 | 归属 | 理由 |
|---|---|---|
| `InviteCode` / `BindRequest` 实体 | CoreModels `Entities/Bind/` | 双端共享(033 教练接收队列复用 `BindRequest`) |
| 2 协议 | RepositoryContracts | 既有惯例(E1RMRepository 同处) |
| `InviteCodeRepository` 双实现 + 邀请码 UI | CoachKit `Features/InviteCodes/` | 纯教练侧 |
| `BindRepository` 双实现 + BindGate/输码/待接收 UI + `PendingBindCodeStore` | StudentKit `Features/Bind/` + `Repository/` | 纯学员侧;BindGate 虽是路由层但只服务学员 role,不进 AppShell(D4) |
| RootView 装配改动 | AppShell | 既有职责 |

### PR 切分

| PR | 内容 | 依赖 |
|---|---|---|
| 1 | CoreModels 实体 + RepositoryContracts 协议 + Networking DTO/APIClient/错误映射 + 双仓 InMemory/Backend 实现 + 单测 | 无 |
| 2 | CoachKit 我的邀请码(View + VM + CoachMyProfileView/CoachRootView 接线) | PR 1 |
| 3 | StudentKit BindGate + 输码 + 待接收 + PendingBindCodeStore + AppShell 装配 + DEMO seed | PR 1(与 PR 2 并行) |

每 PR 过 `/review-loop` 收敛(#148 规则)。

### 版本 / 兼容

- iOS 17.0+,纯 SwiftUI,无第三方库
- 视觉走 `Color.MeetPR.*` / `MeetPRSpacing` / `MeetPRRadius` token;码大字用 `.monospaced()` 系统字体
- Swift Testing(`@Test` / `#expect`)

## 验收清单

- [ ] CoreModels 2 实体 Codable roundtrip + 词表逐字单测过
- [ ] DTO fixture 用 backend 005 SPEC 原文 JSON,decode/encode 双向过;5 个 machine code 映射过
- [ ] 教练:无 personal 码空态生成;重新生成弹确认且旧码失效(列表刷新可见);复制出无分隔 10 位码;一次性/限时码生成(限时必填天数)+ 列表状态徽章 4 态 + revoke
- [ ] staging 真环手测:教练(David 账号)生成码 → 学员(xty 账号)输码全链路
- [ ] 学员:输码页格式校验(非 10 位/字母表外禁提交);姓名必填;假码提交(onboarding 已完成路径)→ inline "邀请码无效或已失效"
- [ ] BindGate:accepted 直进 5 tab(现有学员账号回归不被挡);pending 进待接收;rejected/expired 回输码页 + 中性 notice(无"拒绝"字样)
- [ ] BindGate resume:杀 app 重启,stash + onboarding 完成 → 自动补发;stash + 未完成 → 回向导分支(032 前该路不可达,单测覆盖)
- [ ] 待接收页:等待时长每分钟刷新;下拉刷新 / 回前台拉状态;取消请求确认后回输码页;cancel 撞 accepted(409)不报错收敛到 5 tab
- [ ] 状态机决策表单测全路径绿
- [ ] DEMO_MODE:demo 学员直通 5 tab 不回归;demo 教练 3 张 seed 码可演示
- [ ] 双 target(Debug/Demo)build + CI 全过

## 估时(给 implementer 参考)

| 块 | 估时 |
|---|---|
| PR 1:实体 + 协议 + DTO + 双仓实现 + 单测 | 1.2d |
| PR 2:邀请码页(2 卡 + 生成 sheet + 列表) | 1d |
| PR 3:BindGate 状态机 + VM 单测 | 0.8d |
| PR 3:输码页 + 待接收页 | 1d |
| PR 3:AppShell 装配 + DEMO seed + 手测 | 0.5d |
| **合计** | **4.5d** |

## 风险 / 待 implementer 关注

1. **D1 时序的 UX 代价**:code 真校验可能发生在 7 步 onboarding 之后(stash 路径)。缓解 = D3 格式硬卡(挡假码)+ invalidCode 回流不丢 onboarding(数据已在 server,重输码立即重发,**不**重过向导)。内测期若"格式对但已失效"(教练 revoke 了)案例多,V0.1.x 再评估预校验端点
2. **D3 与 backend D4 的耦合**:10 位 + 字母表写死两端。backend 改码规则 = breaking change,两侧 spec 修订同步;输码框注释里链接 backend 005 D4
3. **BindGate 闪烁**:`.loading` 必须渲染全屏 spinner(对齐 `AuthFlowView` 加载态),禁止先闪输码页再跳 5 tab;`mine` 拉取失败走 `.failed` 全屏重试,**不**默认放行进 5 tab(无绑定态进 5 tab 会看到空计划误导)
4. **取消 vs 接收 race**:学员点取消时教练恰好 accept → `DELETE` 回 409 `BIND_REQUEST_NOT_PENDING` → 静默 reload mine → 收敛 `.bound`。不弹错误(从学员视角"教练接收了"是好结局)
5. **coach_display_name null**:coach_profiles 无行时 backend 回 null,UI 兜底"教练"二字,别 force unwrap
6. **InMemory 与 Backend 语义漂移**:InMemory 仅模拟 UI 需要的语义(typed error / personal 单活跃 / 状态翻转),不复刻惰性过期时序;过期路径单测用 Backend 实现 + mock transport
7. **已使用/已过期判定时钟**(D7):`expires_at < now` 用注入 `now()`(测试假时钟),别直接 `Date()`
8. **拒绝中性原则**(D8):任何 copy 不出现"拒绝/rejected";code review 时 grep UI 字符串
9. **`mine` 只回最新一条**:被拒后学员重新发请求,旧 rejected 记录被新 pending 覆盖语义由 backend 排序保证;client 不缓存旧状态(BackendBindRepository 无 cache 是有意的)

## Implementation Notes

实装与草稿的偏离(2026-06-11,与 032 同分支交付):

1. **D11 分组取数字规则 4-3-3**:草稿正文写 "4-3-3 空格分组" 但线框示例 `XK7M PQ2R VT` 是 4-4-2,两处矛盾。按显式数字规则实装:`XK7MPQ2RVT` → `XK7M PQ2 RVT`(`InviteCodeFormat.grouped`,单测钉死)。复制仍是无分隔 10 位。
2. **`InviteCodeFormat` 进 CoreModels/Domain**(非 StudentKit 私有):教练侧大字分组显示与学员侧输入预检共用同一格式源(ADR-005 跨角色 domain,`E1RMCalculator` 同位先例),避免两 Kit 各持一份字母表漂移。
3. **错误映射分层微调**:Networking 持信封解析(`BackendErrorEnvelope.machineCode/missingFields`,只出 String),typed 映射放 RepositoryContracts(`BindRequestError.init?(machineCode:)`)— Networking 不引 RepositoryContracts,语义与草稿 "`BindErrorCode.from(APIError) -> String?` + repository 层翻 typed" 等价。
4. **`onboardingFlow` 完成回调带载荷**:`onCompleted` 从 `() async -> Void` 扩为 `(BindHandoffOutcome) async -> Void`(requestSent / invalidCode(displayName:) / needsReload)。否则 032 handoff 撞 INVITE_CODE_INVALID 清 stash 后,BindGate reload 拿不到 prefillDisplayName 与 notice,只能让 BindGate 重复 POST 一次换取信息。两 spec 契约表同文锁定。
5. **冲突收敛不递归**:resolveUnbound 撞 already-pending/already-bound 后走一次非递归 re-read(`reloadAfterConflict`)直接映射服务端状态,避免 load→resolve→submit 振荡;收敛进 pending/bound 时顺手清 stash。
6. **spec 002 遗留实体重塑**:`BindRequest`/`InviteCode`(CoreModels)按 backend 005 wire 重写 — 去掉 `rejectionSilent`、`inviteCodeId` 可空、`expiredAt` 非空、加 `coachDisplayName`;`InviteCodeType` 删去 backend 词表外的 `coach_referral`;`Gender` rawValue 由 `M/F` 改为 backend 的 `male/female/other`(全 codebase 仅测试引用,零外溢)。
7. **向导槽位渲染形态**:`.needsOnboarding` 分支渲染一页 interstitial("继续填写")+ fullScreenCover 承载向导,使"保存并退出"有落点(直接全屏渲染向导则退出无处可去)。

测试:BindGate 决策表 + EnterCode 格式/提交分支 + PendingBind cancel/时长 + stash 隔离(StudentKit);D7 四态判定 + VM 行为 + InMemory 语义(CoachKit);DTO fixtures + 错误信封 5 码(Networking);实体 roundtrip + 词表 + InviteCodeFormat(CoreModels)。staging 真环手测(David 发码 → xty 输码全链路)与模拟器回归留待主 session(验收清单对应项未勾)。

## 上游 / 下游

**上游**:
- backend 005-bind-eval-profile(已 live):邀请码 + 绑定状态机端点
- spec 025(Session/SessionStateReader)/ 028(5 tab)/ 029(教练 3 tab)
- evaluation-workflow v1.1 §2/§3 + student-onboarding v2.4 §A

**下游**:
- **spec 032(强耦合)**:消费 `PendingBindCodeStore` + `BindRepository` + `isOnboardingComplete` / `onboardingFlow` 注入点(§技术要求契约表)
- **spec 033**:`.bound` 分支插评估期路由;教练接收队列复用 `BindRequest` 实体 + Networking 错误映射;待接收页 accepted 翻转后的"评估期开始"提示
- V0.1.x:扫码 + 二维码分享卡;APNs(待接收推送 / 教练新请求推送);预校验端点(视内测反馈)

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-11 | 0.1 | 起草。教练邀请码页 + 学员输码/待接收 + BindGate 状态机;code 暂存交接契约(031 定义 032 消费);backend 0 改动 | Claude |
| 2026-06-11 | 0.2 | 实装落地(与 032 同分支):CoreModels 实体重塑 + 双仓 + BindGate/输码/待接收 + 教练邀请码页;偏离见 Implementation Notes | Claude |
