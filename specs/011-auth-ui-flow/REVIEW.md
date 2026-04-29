# Review — 011-auth-ui-flow

**Reviewer:** Claude · **Date:** 2026-04-29 · **Verdict:** Request changes

## TL;DR

Strong overall design — first real iOS UI flow, Session interface clean (4 async methods, clear state transitions), Bootstrap 3-path behaviour spelled out, ADR-009 logout hook correctly wired with deferred injection, validation rules concrete, error→toast mapping mostly done, simulator happy-path including kill-app-restart bootstrap is testable, out-of-scope list comprehensive. Format compliant (Status / 来源 / 范围 / 技术要求 / 验收 / 参考 / Notes), inherits spec 002/003 pattern (one type per file, StrictConcurrency, Swift Testing, DesignSystem atom reuse), import boundaries correct (AppShell ⊥ SwiftData per ADR-005 §4 + ADR-009 例外). Pivot-clean (auth doesn't touch coach planning UI).

Blocking: two backend-contract gaps that will bite Codex on day one. (1) Phone format — iOS regex matches raw 11-digit Chinese, backend regex requires E.164 with `+` prefix; no transformation step is specified. (2) `name` field — captured in SignupView UI and threaded through `Session.signup` / `AuthRepository.signup`, but the wire body in §3 says `{ phone, password, role }` with no `name`. Either the field is silently dropped (lost on cross-device login) or it gets sent to backend that doesn't accept it (VALIDATION_ERROR / silent drop depending on zod strict mode).

After the P1 + P2 items below, this is mergeable.

Counts: **P0:0 P1:2 P2:3 P3:4**.

---

## P1 — must fix

### 1. Phone format mismatch — iOS validates raw 11-digit, backend requires E.164

`SPEC.md` line 236 (AuthFormViewModel validation):

> **手机号**: 正则 `^1[3-9]\d{9}$` (中国大陆 11 位); 不通过 → field error "手机号格式不正确"

Backend [spec 001-auth §Validation](../../../MeetPR-backend/specs/001-auth/SPEC.md):

> `phone` | string, regex `^\+[1-9]\d{7,14}$` (E.164, 8–15 digits, leading non-zero). Stored verbatim.

Backend wire example (curl in spec 001-auth §Verification): `{"phone":"+8613800000001", ...}`.

So the iOS regex matches what the user types (`13800000001`) but the **wire format** must be `+8613800000001`. The wireframe at lines 73 / 95 hints at this with `+86 13800000000` rendered in the field, but no transformation step is documented. Codex has three plausible reads:

1. Send the raw 11 digits → every signup/login fails with `400 VALIDATION_ERROR { issues: [{ path: ["phone"], ... }] }`.
2. Treat `+86 ` as a static UI prefix and prepend at submit time → works.
3. Display the `+86 ` as a `Text` next to the field but only put `^1[3-9]\d{9}$` in the input → still need an explicit submit-time prepend.

The spec must spell this out. Suggested addition to §AuthFormViewModel 校验规则 (after line 236):

> **Wire-format transformation**: the validation regex matches the user-entered 11-digit national number. Before sending to backend, prepend `+86` to construct the E.164 format expected by `POST /auth/{register,login}`: `wirePhone = "+86" + userInput`. The cached `User.phone` from the response is also the E.164 form (`+86…`), and equality checks against captured input must use the wire form.

Without this, the spec implies a mismatch that fails every auth call.

### 2. `name` field is captured in UI / Session.signup but excluded from backend register body — flow under-specified

The spec is internally inconsistent on what happens to `name`:

- §1 line 35 (Session interface): `func signup(phone: String, password: String, role: UserRole, name: String?) async throws`
- §3 line 56 (Networking endpoint): `POST /auth/register` body `{ phone, password, role }` — no `name`
- §4 line 107 (SignupView wireframe): `昵称 (可选)` field
- §AuthRepository protocol line 215: `func signup(phone: String, password: String, role: UserRole, name: String?) async throws -> AuthResult`
- §AuthFormViewModel 校验规则 line 235: 昵称 (signup only): 可空, 长度 ≤ 50 字符

Backend [spec 001-auth](../../../MeetPR-backend/specs/001-auth/SPEC.md) register body is exactly `{ phone, password, role }` and the user response is exactly `{ id, phone, role, createdAt }` — no `name` in either direction. So today, the captured `name`:

- gets sent to backend in the body → either silently dropped (if backend zod is non-strict) or rejected with `400 VALIDATION_ERROR` (if `.strict()` mode).
- gets dropped at the Networking layer → captured but never persisted; on login from a second device the name is gone.

`CoreModels.User.name` is `String?` per spec 002, so iOS-side decoding tolerates a missing field. But the user-visible behaviour today is "you typed a nickname, it disappeared after install on a second device". That's a silent UX bug.

Three resolutions, pick one and document explicitly:

1. **Drop `name` from V1 signup entirely.** Defer to a Profile/Onboarding spec where `PATCH /me` lands. Remove `name` from `Session.signup`, `AuthRepository.signup`, `SignupView`, and the validation rule. Cleanest — matches the current backend contract.
2. **Capture but don't send.** Keep the SignupView field, drop `name` from the `Session.signup` and `AuthRepository.signup` parameter list, and explicitly state "captured for future profile spec; not persisted in V1". Weak UX (name vanishes on cross-device login) but explicit.
3. **Send and have backend accept.** Requires an amendment to backend spec 001-auth to add an optional `name` field to the register body and user response. Out of band for this spec.

Recommend option 1 unless you specifically want signup to feel less anonymous. Either way, the spec must stop being internally inconsistent on this.

Related: this also resolves a downstream ambiguity in the DTO ↔ `CoreModels.User` mapper — see P2 #3.

---

## P2 — recommended fix

### 3. DTO → `CoreModels.User` mapper defaults are not specified

Backend's user payload is `{ id, phone, role, createdAt }` (4 fields). `CoreModels.User` from [spec 002](../002-core-models-identity/SPEC.md) line 109-153 has 13 properties, including non-optional `unitSystem: UnitSystem` and non-optional `updatedAt: Date`. A bare `JSONDecoder.decode(User.self, from: ...)` against the backend response will throw on those two missing keys — `Decimal?` / `Gender?` fields tolerate missing via `decodeIfPresent`, but `unitSystem` and `updatedAt` are non-optional.

§3 line 60 acknowledges this with "DTO 类型 (Codable struct) ... 与 `CoreModels.User` 转换通过手写 mapper", which is the right pattern. But the mapper rules are not spelled out:

| Field | Default the mapper should pick |
|---|---|
| `unitSystem` | `.metric` (China-first per V1 dogfood; user-changeable later in profile spec) |
| `updatedAt` | mirror `createdAt` from the backend response |
| `name` | depends on P1 #2 resolution — captured value at signup time, `nil` at login time |
| `appleUserID`, `avatarURL`, `gender`, `birthDate`, `heightCm`, `weightKg` | `nil` (Optional fields, mapper sets `nil`) |

Add this table (or equivalent prose) to §3 so Codex doesn't guess on `unitSystem` (defaulting wrong, e.g. `.imperial`, would silently set the wrong default for V1 dogfood Chinese users).

### 4. Bootstrap refresh handling only specifies the 401 path; network/5xx behaviour is undefined

§Bootstrap 流程 lines 184-193:

```
4. Background: try refresh(refreshToken) →
   - success: save new tokens to Keychain
   - failure (401 AUTH_INVALID_REFRESH / AUTH_REFRESH_EXPIRED): clear Keychain + setState(.anonymous)
```

Implicit gap: what happens on a network error (offline, DNS, TLS) or a 5xx server error during the background refresh? The spec only branches on 401. Two reasonable behaviours, the spec must pick:

1. **Tolerate transient errors** (recommended): keep cached `User`, leave Keychain untouched, retry on next foreground / next refresh. Logs out only on actual 401.
2. **Aggressive logout**: any failure clears Keychain. Hostile UX — opening the app in a tunnel logs you out.

If unspecified, Codex will likely pick (2) by uniformly catching any throw → `clear()` → `.anonymous`, which surprises users.

Add to §Bootstrap 流程:

> **Refresh failure dispatch**: only `401 AUTH_INVALID_REFRESH` / `401 AUTH_REFRESH_EXPIRED` clear Keychain and force `.anonymous`. All other failures (network unavailable, 5xx, decode error, timeout) are non-fatal — keep cached `User` + tokens, log a `bootstrap_refresh_deferred` warning, retry on next foreground via `.task` re-fire or explicit user action.

### 5. `RATE_LIMITED` (429) is missing from the error→toast mapping

Backend [spec 001-auth §Error envelope](../../../MeetPR-backend/specs/001-auth/SPEC.md) lists `RATE_LIMITED` (429) as one of the error codes the auth handlers can emit (global limiter from `src/middleware/rateLimit.ts`). The iOS spec §AuthFormViewModel 校验规则 mapping at lines 240-244 covers `AUTH_PHONE_TAKEN` / `AUTH_INVALID_CREDENTIALS` / `VALIDATION_ERROR` / 网络错误 but not `RATE_LIMITED`.

Today a coach who fat-fingers their password 11 times in a row would hit the global rate limit on the next attempt and the toast layer has no mapping → either falls into the generic "网络异常" bucket (incorrect — this is a 429, not a network failure) or shows nothing.

Add a row:

> `RATE_LIMITED` → "请求过于频繁,请稍后重试"

While here, double-check that bootstrap's silent-failure case on `AUTH_INVALID_REFRESH` / `AUTH_REFRESH_EXPIRED` is intentional (no toast, just back to LoginView). Spec implies this is the design — fine, just confirm in prose.

---

## P3 — nice-to-have

### 6. Test count breakdown at line 281 doesn't match the per-suite detail at lines 116-122

Line 281: `测试 ≥ **20** (5 AuthRepository + 4 TokenStore + 4 Session + 4 AuthFormViewModel + 3 AuthFlowSnapshot)`.

Line 118 detail: `AuthRepositoryTests` = `signup/login/refresh 三方法 round-trip + 4 个 error code 映射` = 3 + 4 = **7** (not 5). Sum is still ≥ 20 so the gate passes either way, but the breakdown at line 281 is misleading. Either reword the detail at line 118 (e.g. "5 AuthRepository tests covering 3 round-trip happy paths + 2 representative error codes") or fix the count at line 281 (`7 AuthRepository + ...`).

### 7. Simulator happy path is "5 步" in the heading but actually 5 mandatory + 1 optional

Line 282 says "**iPhone 17 simulator 跑 happy path 5 步**" but lines 283-288 enumerate **6** numbered items (step 6 is `(可选 dev) logout`). Either renumber the heading to "5 + 1 步" or move the dev-only logout step out of the numbered list into a separate "Dev verification" sub-section.

### 8. Keychain accessibility should be `…AfterFirstUnlockThisDeviceOnly`, not `…AfterFirstUnlock`

Line 209: `Keychain accessibility = kSecAttrAccessibleAfterFirstUnlock（允许 background fetch 时访问;app 锁屏期间 OK）`.

`kSecAttrAccessibleAfterFirstUnlock` (without `ThisDeviceOnly`) makes the item iCloud Keychain-syncable. Combined with backend's V1 single-device refresh tracking model (per backend spec 001-auth §Token model — `users.refresh_token_jti` allows at most one device live), syncing tokens across iCloud is a UX foot-gun: device A's token gets to device B via iCloud, device B's first call rotates the JTI, device A's next call now fails reuse-detection → forced logout. Worse, it leaks credentials onto devices the user may not have intended.

`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` keeps the same background-fetch semantics, just doesn't sync — which is what the spec actually wants given backend's single-device assumption (called out as an Out-of-scope row at line 135). Cheap to harden:

```swift
let acl: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

Document the choice in §TokenStore so Codex doesn't second-guess.

### 9. Add explicit FOLLOWUPS entry for the deferred `onLogout` wiring

§3 line 271 + Notes line 309 correctly call out that `Session.onLogout` is wired to `nil` in this spec and the actual `await DraftStore.shared.deleteAll()` injection lands in spec 005's PR. ADR-009 §后续需回顾 also lists this as a verification step. But there's no explicit `FOLLOWUPS.md` entry to track "spec 005 PR must update `MeetPRApp.swift` to set `onLogout: { await DraftStore.shared.deleteAll() }`". Without one, the wiring is liable to be forgotten — and the only visible symptom is a cross-account draft leak at logout, which is hard to spot without manual testing of the exact ADR-009 §后续需回顾 #4 path.

Add to §验收标准 a checkbox:

> [ ] [FOLLOWUPS.md](../../FOLLOWUPS.md) updated with new entry: "Spec 005 PR must replace `onLogout: nil` in `MeetPR/MeetPRApp.swift` with `onLogout: { await DraftStore.shared.deleteAll() }` (per ADR-009 后果项 + spec 011 §3 deferred wiring)".

---

## What I checked and found clean

- **Spec format** ([specs/README.md](../README.md)): Status `InReview`, 来源 / 目标 / 范围 / 技术要求 / 验收标准 / 参考 / Notes structure matches spec 002 / 003 / 004 / 005 pattern. ✓
- **Backend contract — error codes**: `AUTH_PHONE_TAKEN` / `AUTH_INVALID_CREDENTIALS` / `VALIDATION_ERROR` mapped to Chinese toasts; `AUTH_INVALID_REFRESH` / `AUTH_REFRESH_EXPIRED` correctly handled silently in bootstrap → back to LoginView (no toast intended). ✓ (modulo P2 #5 for `RATE_LIMITED`).
- **Backend contract — single-device refresh tracking**: Out-of-scope row at line 135 explicitly aligns with backend spec 001-auth's `users.refresh_token_jti` single-slot model and accepts the V1 UX (silent re-login on the displaced device). ✓
- **ADR-005 §2 (Session/RootView routing)**: existing `Session.State` enum reused, `RootView.swift` not touched (line 40), `environment(session)` injection unchanged, `MeetPRApp.swift` wiring updated to construct `Session(auth:tokenStore:onLogout:)` with `APIClient.shared` still flowing in via `NetworkingAuthRepository`. ✓
- **ADR-009 (Session.logout → DraftStore)**: `onLogout` injection point is the right shape; deferred wiring through spec 005 is reasonable; placeholder test ("`onLogout` callback in `logout` invoked once") guards the contract. ✓ (modulo P3 #9 for explicit FOLLOWUPS).
- **ADR-003 v4 (single role lock)**: SignupView role picker is 3-choice mapped to `UserRole` cases (`.coach` / `.coachedStudent` / `.selfTrainStudent`), no role-switch UI, no multi-role pre-wiring. ✓
- **Pivot compliance**: spec is auth-only, doesn't reference 4-week macro view / week cards / specificity bucket. F-015 awareness called out at line 23 (登录后路由进 CoachRootView 仍 placeholder). ✓
- **Spec 002/003 pattern inheritance**: one-type-per-file (5 new Auth files, each one type), StrictConcurrency continues, Swift Testing + ViewInspector, DesignSystem atom reuse (`PrimaryButton` / `MeetPRTextField` / `Card` / `Eyebrow`). ✓
- **Import boundaries (ADR-005 §3)**: AppShell allowed = Foundation / SwiftUI / Observation / CoreModels / DesignSystem / Networking / CoachKit / StudentKit; Networking allowed = Foundation / CoreModels; AppShell SwiftData explicitly forbidden (ADR-009 例外 limited to `CoachKit/Planning/`). ✓
- **Session 4-method API**: `bootstrap() async` (no throws — silently handles all paths), `signup(...) async throws`, `login(...) async throws`, `logout() async` (idempotent, no throws). State transitions clear from prose at lines 184-193. ✓ (modulo P2 #4 for non-401 bootstrap paths).
- **TokenStore actor**: `actor TokenStore: Sendable`, Keychain wrapper with `InMemoryTokenStore` for SPM-on-macOS test runs (Keychain unavailable there) gated via `#if os(iOS)`. ✓ (modulo P3 #8 for `…ThisDeviceOnly`).
- **AuthRepository protocol shape**: `signup` / `login` / `refresh` returning `AuthResult` / `TokenPair` value types with `Sendable + Equatable`, `NetworkingAuthRepository` for production + `InMemoryAuthRepository` for tests. ✓ (modulo P2 #3 for mapper defaults).
- **Out-of-scope discipline**: 9 items explicitly deferred (SMS OTP / Apple Sign-In / WeChat / 忘记密码 / Profile / Logout placement / Token auto-refresh / Multi-device / 海外手机号), each with target-spec or trigger condition. ✓
- **Verification — simulator path**: kill-app-restart bootstrap is the right load-bearing test for the cached-User + Keychain round-trip; `xcodebuild build -scheme MeetPR` cross-module integrity check listed; CI gate listed. ✓ (modulo P3 #7 step count).

---

## Summary of changes requested

1. **P1 #1** — add explicit phone-format wire transformation rule to §AuthFormViewModel 校验规则: validation regex `^1[3-9]\d{9}$` matches user input; submit-time prepend `+86` to produce E.164 wire form.
2. **P1 #2** — resolve `name` field contract: pick option 1 (drop from V1 signup, defer to profile spec), option 2 (capture-don't-send + explicit "not persisted in V1" comment), or option 3 (amend backend spec 001-auth). Update Session / Repository / View / mapping consistently.
3. **P2 #3** — specify mapper defaults for the DTO → `CoreModels.User` conversion: `unitSystem = .metric`, `updatedAt = createdAt`, `name` per P1 #2 resolution, all other Optional fields `nil`.
4. **P2 #4** — extend §Bootstrap 流程 to specify non-401 refresh failure handling: keep cached `User` + tokens on network/5xx errors, only clear Keychain on 401.
5. **P2 #5** — add `RATE_LIMITED` → "请求过于频繁,请稍后重试" toast row to §AuthFormViewModel 校验规则.
6. **P3 #6** — fix test count breakdown at line 281 to match per-suite detail at lines 116-122.
7. **P3 #7** — reword "5 步" heading at line 282 to match the 5+1 numbered list (or move dev-only logout out of the numbered sequence).
8. **P3 #8** — change `kSecAttrAccessibleAfterFirstUnlock` → `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (matches V1 single-device backend assumption + prevents iCloud Keychain sync of tokens).
9. **P3 #9** — add explicit `FOLLOWUPS.md` entry for the deferred `onLogout` wiring (spec 005 PR to update `MeetPRApp.swift`).

After these, ready to flip Status to `Ready` and merge into `main`.

---

# Implementation Review (PR #27)

**Reviewer:** Claude · **Date:** 2026-04-29 · **Verdict:** **APPROVE**

PR: [#27 feat(auth): implement auth UI flow](https://github.com/tianpingdeng112233-cell/meetpr/pull/27)
Head: `01f711a22cff52e576be7411a89c3b37da27595c` · Base: `main` · 26 files +1710/-69
CI: 4/4 green (Swift Build & Test ×2, Lint ×2)

## TL;DR

Clean, spec-faithful implementation. Every one of the 10 acceptance checklist items has concrete code evidence. Every one of the 9 spec-review decisions (P1#1, P1#2, P2#3, P2#4, P2#5, P3#6, P3#7, P3#8, P3#9) is honored in the diff with a citable file:line. Test count exceeds the spec floor (28 vs 22 minimum, all Swift Testing, all green). Swift 6 strict concurrency is exemplary — no `@unchecked Sendable`, no `DispatchQueue`, `TokenStore` is an `actor`, `onLogout` typed `@Sendable () async -> Void`. Module boundaries (ADR-005 §3) are intact: AppShell imports only the allowed set with **zero** `import SwiftData` (per ADR-005 §4 + ADR-009 carve-out only for CoachKit/Planning/), Networking depends solely on Foundation+CoreModels with no reverse deps. F-016 is in `FOLLOWUPS.md` as required.

The one cross-module deviation — DesignSystem `Card.swift` (+2/-2 in commit `8e3793e`) — is a justified bug fix surfaced when spec 011 became the first non-static use of `Card`: the `RoundedRectangle.stroke` overlay was intercepting taps on the contained `PrimaryButton`/`MeetPRTextField`. The commit is correctly tagged `(spec: 011-auth-ui-flow)` and isolated from the auth feature commit. Per AGENTS.md "只动 spec 范围内的文件" — this is the legitimate carve-out (a downstream feature surfacing a real DS bug), not scope creep. **Soft P3 below**: a DesignSystem regression test would close the loop.

The one extra Auth/ file (`AuthSecureField.swift`, 6th vs spec's 5) is a legitimate `View` extracted because it's reused by both `LoginView` and `SignupView` — exactly the AGENTS.md "拆成独立的 `View` struct" prescription. Not scope creep.

Counts: **P0:0 P1:0 P2:0 P3:4**.

---

## Acceptance checklist verification (10/10 PASS)

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | `Session.swift` — `fakeLogin` removed; bootstrap/signup/login/logout + `onLogout` injection | PASS | [Session.swift L5-L83](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Session.swift#L5-L83) — 4 methods at L31/L57/L69/L81; onLogout typed `@Sendable () async -> Void` at L19, invoked at L83 |
| 2 | `AuthFlowView` = NavigationStack(LoginView → SignupView push) | PASS | [AuthFlowView.swift L4-L13](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/AuthFlowView.swift#L4-L13) + [LoginView.swift L70-L82](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/LoginView.swift#L70-L82) `NavigationLink { SignupView() }` |
| 3 | 5 new files in `Modules/AppShell/Sources/AppShell/Auth/` | PASS | LoginView, SignupView, AuthFormViewModel, AuthRepository, TokenStore — all present. Plus `AuthSecureField.swift` (justified — see TL;DR) |
| 4 | Networking auth DTOs + endpoints | PASS | [AuthDTOs.swift](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Auth/AuthDTOs.swift) (8 DTOs) + [APIClient+Auth.swift L1-L43](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Auth/APIClient%2BAuth.swift#L1-L43) (register/login/refresh) + [Endpoints.swift L10-L21](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Endpoints.swift#L10-L21) |
| 5 | `MeetPRApp.swift` wiring `Session(auth:tokenStore:onLogout:nil)` | PASS | [MeetPRApp.swift L4-L20](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/MeetPR/Sources/MeetPRApp.swift#L4-L20) |
| 6 | `swift build` clean, Swift 6 strict concurrency | PASS | CI green (Swift Build & Test ×2 SUCCESS); `@MainActor` on Session/AuthFormViewModel, `Sendable` on protocols/DTOs |
| 7 | Tests ≥ 22 | PASS | **28** total: AuthRepository=7, AuthFormViewModel=7, Session=7, TokenStore=4, AuthFlowSnapshot=3 (counted via `grep -c '@Test'`) |
| 8 | iPhone 17 simulator happy path (5 + 1 dev) | PASS (author attestation) | PR body explicitly: `LoginView -> SignupView -> register coach -> CoachRootView -> kill/relaunch -> CoachRootView`. `XcodeBuildMCP build_sim` + `test_sim` (6/6) recorded. Step 5 (kill/relaunch → bootstrap → CoachRootView) — the load-bearing assertion — explicitly named. |
| 9 | swiftlint + swift-format + xcodebuild + CI green | PASS | CI Lint ×2 SUCCESS; PR body lists `swift-format lint on changed files` + `swiftlint --quiet` + `XcodeBuildMCP build_sim: passed` |
| 10 | FOLLOWUPS.md F-016 entry for spec 005 onLogout wiring | PASS | [FOLLOWUPS.md L222-L235](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/FOLLOWUPS.md#L222-L235) — exact required wiring text at L228, references ADR-009 + spec 011 §3 + REVIEW P3 #9 |

---

## Spec REVIEW.md 9 decisions enforcement (8 PASS, 1 procedural-PASS)

### P1 #1 — Phone wire-format conversion · **PASS**

UI validates 11-digit national; `NetworkingAuthRepository` prepends `+86` to construct E.164.

- Validation regex `^1[3-9]\d{9}$` at [AuthFormViewModel.swift L88-L94](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthFormViewModel.swift#L88-L94)
- E.164 prepend at [AuthRepository.swift L103-L114](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthRepository.swift#L103-L114) — `wirePhone(from:)` returns input as-is if it has `+`, else prepends `+86` (idempotent)
- Used at signup/login call sites: [AuthRepository.swift L73-L100](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthRepository.swift#L73-L100)
- UI never displays `+86 ` as part of editable input — placeholder `13800000001` at [LoginView.swift L29-L35](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/LoginView.swift#L29-L35) and [SignupView.swift L29-L36](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/SignupView.swift#L29-L36)

### P1 #2 — No `name` field in V1 signup · **PASS**

Captured in zero places; mapper sets `name: nil`.

- `Session.signup` signature `(phone, password, role)` at [Session.swift L55-L67](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Session.swift#L55-L67)
- `AuthRepository` protocol method at [AuthRepository.swift L60-L67](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthRepository.swift#L60-L67)
- SignupView fields phone / password / role only — no name input ([SignupView.swift L25-L65](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/SignupView.swift#L25-L65))
- Register DTO `{ phone, password, role }` only at [AuthDTOs.swift L1-L17](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Auth/AuthDTOs.swift#L1-L17)
- Mapper sets `name: nil` at [AuthDTOs.swift L47-L60](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Auth/AuthDTOs.swift#L47-L60)

### P2 #3 — DTO → User mapper defaults · **PASS**

`AuthUserDTO.toUser()` fills the 9 fields the backend doesn't return:

- `unitSystem: .metric` (explicit) at [AuthDTOs.swift L47-L60](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Auth/AuthDTOs.swift#L47-L60)
- `updatedAt: parsedCreatedAt` (mirrors `createdAt`) — same block
- `name: nil` — same block
- `appleUserID` / `avatarURL` / `gender` / `birthDate` / `heightCm` / `weightKg` rely on `User.init` defaults of `nil` (verified at `Modules/CoreModels/Sources/CoreModels/Entities/User.swift:18-32`)
- Both non-optional User fields (`unitSystem`, `updatedAt`) explicitly set, so decode cannot throw on missing keys

### P2 #4 — Bootstrap refresh failure dispatch · **PASS**

401 → clear; non-401 → keep cached, log warn.

- Discriminator at [AuthRepository.swift L49-L60](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthRepository.swift#L49-L60) — `clearsBootstrapSession` returns `true` ONLY for `.backend(401, .invalidRefresh, _)` and `.backend(401, .refreshExpired, _)`; everything else (network/decode/5xx/timeout) returns `false`
- Bootstrap consumes it at [Session.swift L40-L56](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Session.swift#L40-L56) — clears Keychain only on auth-error; otherwise prints `bootstrap_refresh_deferred` warn and keeps cached state
- Both branches covered: [SessionTests.swift `bootstrapWithInvalidRefresh...` L41-L57 + `bootstrapWithNetworkRefreshFailure...` L58-L73](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Tests/AppShellTests/Auth/SessionTests.swift#L41-L73)

### P2 #5 — RATE_LIMITED toast · **PASS**

- `case rateLimited = "RATE_LIMITED"` at [AuthRepository.swift L37-L48](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthRepository.swift#L37-L48)
- Toast mapping `"请求过于频繁,请稍后重试"` at [AuthFormViewModel.swift L74-L88](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthFormViewModel.swift#L74-L88)
- Test asserts the mapping at [AuthFormViewModelTests.swift L59-L80](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Tests/AppShellTests/Auth/AuthFormViewModelTests.swift#L59-L80)

### P3 #6 — Test count ≥ 22 · **PASS (28)**

| File | `@Test` count | Spec target |
|---|---|---|
| AuthRepositoryTests.swift | 7 | 7 (3 round-trip + 4 error-code) |
| TokenStoreTests.swift | 4 | 4 |
| SessionTests.swift | 7 | 4 (exceeds; bonus: separate auth-fail vs network-fail bootstrap paths + onLogout-fires) |
| AuthFormViewModelTests.swift | 7 | 4 (exceeds; bonus: rateLimited + integration tests) |
| AuthFlowSnapshotTests.swift | 3 | 3 |
| **Total** | **28** | **22** |

All `import Testing` (Swift Testing, not XCTest). ViewInspector used in snapshot tests at [AuthFlowSnapshotTests.swift L1-L11](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Tests/AppShellTests/Auth/AuthFlowSnapshotTests.swift#L1-L11). Network tests: 3 in `APIClientTests.swift`.

### P3 #7 — Simulator happy path (5 + 1 dev) · **PASS (author attestation)**

PR body acceptance checklist explicitly: `iPhone 17 simulator happy path verified with local mock auth server: LoginView -> SignupView -> register coach -> CoachRootView -> kill/relaunch -> CoachRootView`. Validation section records `XcodeBuildMCP build_sim: MeetPR on iPhone 17 passed` + `XcodeBuildMCP test_sim: MeetPR scheme passed (6/6)`. Step 5 (kill/relaunch → bootstrap skips LoginView → directly into CoachRootView) is the load-bearing assertion and is explicitly named. No screenshot/video committed; standard for the project — accepting author attestation.

### P3 #8 — Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` · **PASS**

Exact constant present at [TokenStore.swift L65-L77](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/TokenStore.swift#L65-L77). Used in the central `save(_:account:)` method called for accessToken / refreshToken / cachedUser — all three Keychain entries get the `ThisDeviceOnly` attribute. iCloud sync of tokens is blocked, matching backend's V1 single-device `refresh_token_jti` model.

### P3 #9 — FOLLOWUPS F-016 entry · **PASS**

[FOLLOWUPS.md L222-L235](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/FOLLOWUPS.md#L222-L235) — F-016 with the exact required wiring text (`onLogout: { await DraftStore.shared.deleteAll() }`), trigger condition (spec 005 PR), action steps, verification (cross-account leak manual test), and back-references to ADR-009 + spec 011 §3 + REVIEW P3 #9.

---

## Architecture compliance (P1)

### Imports (ADR-005 §3) · **PASS**

`grep -r "^import " Modules/AppShell/Sources/` returns: `Foundation`, `SwiftUI`, `Observation`, `CoreModels`, `DesignSystem`, `Networking`, `CoachKit`, `StudentKit`, plus `Security` (system framework for Keychain in `TokenStore.swift`). Allowed-set complete; no extras outside system frameworks.

`grep -r "^import " Modules/Networking/Sources/` returns: `Foundation`, `CoreModels` only. Zero reverse imports of AppShell / DesignSystem / CoachKit / StudentKit.

### `import SwiftData` in AppShell · **PASS — zero matches**

`grep -r "import SwiftData" Modules/AppShell/` → 0. `grep -rn "@Model" Modules/AppShell/` → 0. ADR-005 §4 + ADR-009 carve-out boundary respected.

### View → Repository layering · **PASS**

`LoginView`/`SignupView` only import `DesignSystem`+`SwiftUI` (+ `CoreModels` for SignupView's role enum). They call `viewModel.submit(using: session)` — no `URLSession` / `URLRequest` / `APIClient` reference in either view. `AuthFormViewModel` likewise has 0 hits for `URLSession|URLRequest|HTTPURLResponse`. Strict layering: `View → ViewModel → Session → AuthRepository → APIClient`.

### DTO → CoreModels mapper unidirectional · **PASS**

`grep -rn "AuthDTO\|AuthResultDTO\|AuthUserDTO" Modules/CoreModels/` → 0. CoreModels has zero awareness of Networking DTOs; the mapper lives in Networking.

### DesignSystem `Card.swift` scope deviation · **PASS with P3 follow-up**

Commit `8e3793e fix(design-system): keep card controls interactive (spec: 011-auth-ui-flow)`. Diff at [Card.swift](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/DesignSystem/Sources/DesignSystem/Components/Cards/Card.swift): adds `.allowsHitTesting(false)` to the `RoundedRectangle.stroke` overlay so the border doesn't intercept taps; swaps `.accessibilityElement(children: .contain) + .accessibilityLabel(...)` to `.accessibilityIdentifier(...)` for snapshot/UI test infra. The change is causal — `LoginView`/`SignupView` are the first views to wrap interactive content in `Card`, so the bug is genuinely surfaced by spec 011, not pre-existing scope creep. Commit is correctly tagged with the spec slug and isolated from the auth-feature commit. AGENTS.md "只动 spec 范围内的文件" implicitly carves out downstream-surfaced bugs in dependencies — this fits. Not a blocker.

**Soft P3 below**: no DesignSystem regression test was added. `Modules/DesignSystem/Tests/DesignSystemTests/ComponentsSmokeTests.swift` only has a "Card instantiates" smoke. A test asserting "button inside Card is hit-testable" would lock in the contract.

### Untracked Xcode files · **PASS**

`grep -i 'xcuserdata' /tmp/pr27.diff` → 0 hits.

---

## Swift 6 strict concurrency (P2) · **10/10 PASS**

| Check | Status | Evidence |
|---|---|---|
| `Session` `@MainActor` + `@Observable` + `@ObservationIgnored` deps | PASS | [Session.swift L1-L25](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Session.swift#L1-L25) |
| `AuthFormViewModel` `@MainActor` + `@Observable` | PASS | [AuthFormViewModel.swift L1-L13](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthFormViewModel.swift#L1-L13) |
| `AuthRepository` Sendable; `AuthResult`/`TokenPair` `Sendable, Equatable` | PASS | [AuthRepository.swift L1-L70](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/AuthRepository.swift#L1-L70) |
| `TokenStore` is `actor` | PASS | [TokenStore.swift L1-L20](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/TokenStore.swift#L1-L20) |
| `InMemoryAuthRepository` is actor; `InMemoryTokenStore` is actor | PASS | AuthRepository.swift L171; TokenStore.swift L106 |
| All DTOs `Codable, Equatable, Sendable` | PASS | [AuthDTOs.swift](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/Networking/Sources/Networking/Auth/AuthDTOs.swift) — every struct (8 of them) declares all three |
| No `@unchecked Sendable` | PASS | grep returned 0 hits |
| No `DispatchQueue.main.async` | PASS | grep returned 0 hits |
| No redundant `Task { @MainActor in }` | PASS | LoginView/SignupView use plain `Task { ... }` inheriting MainActor from the view body |
| `onLogout` typed `@Sendable () async -> Void` | PASS | Session.swift L19 + L24 (both stored property and init param) |

---

## Test quality (P2) · **9/10 PASS, 1 spec-consistent gap**

All tests use Swift Testing (`import Testing`, `@Test` annotations) — zero `XCTest` references. ViewInspector imported in `AuthFlowSnapshotTests.swift`. Mock pattern: `InMemoryAuthRepository` + `InMemoryTokenStore` for unit tests, real `NetworkingAuthRepository` + `TokenStore` in production. All 4 backend error codes (`AUTH_PHONE_TAKEN`, `AUTH_INVALID_CREDENTIALS`, `VALIDATION_ERROR`, `RATE_LIMITED`) plus the network fallback are mapped to Chinese toasts and asserted in `AuthFormViewModelTests`. `LogoutSpy` is an `actor` (correct concurrency form) and `SessionTests.logoutClearsStoreAndCallsLogoutHookOnce` asserts `count == 1` after `Session.logout()`.

The one gap (P3 below): `TokenStoreTests.swift` runs only against `InMemoryTokenStore`. The real `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete` paths in `TokenStore.swift:67-103` have zero coverage. Spec line 124-125 only mandated `InMemoryTokenStore` round-trip + `#if os(iOS)` gate **hint** for any Keychain test; the gate is moot since no Keychain test exists to gate. **Spec-consistent**, but leaves the production Keychain wrapper exercised only at runtime.

---

## Code style (P3) · clean

- One-type-per-file: 5 spec files + 1 justified extra (`AuthSecureField.swift`). `AuthRepository.swift` packs the protocol with 4 tightly-coupled error/result types — within AGENTS.md's "tightly related" carve-out.
- Naming: side-effect methods are verbs (`bootstrap`, `signup`, `login`, `logout`, `submit`, `clear`, `save`); value-returning properties are nouns (`phoneError`, `canSubmit`).
- No `try!` / no force unwraps in PR-touched files (grep clean).
- No `DispatchQueue` (grep clean).
- Modern SwiftUI APIs throughout: `foregroundStyle`, `clipShape(.rect(cornerRadius:))`, `.bold()` — no legacy `foregroundColor` / `cornerRadius(_:)` modifier / `fontWeight(.bold)`.
- Views are thin shells delegating to `AuthFormViewModel`; `RoleOptionButton` is extracted as a separate `private struct: View`, not a computed property.
- Zero `TODO` / `FIXME` / `XXX` / `HACK` in PR-touched files.
- 3 commits, each with `(spec: 011-auth-ui-flow)` suffix; logical separation (impl / DS fix / FOLLOWUPS doc) is clean.

---

## P3 — soft follow-ups (non-blocking)

### 1. DesignSystem regression test for `Card` interactive content

Commit `8e3793e` ships a real Card hit-testing fix without a test in `Modules/DesignSystem/Tests/DesignSystemTests/`. A `ViewInspector` snapshot or behavioral test asserting "interactive content inside `Card` receives taps" would lock in the contract. The existing `ComponentsSmokeTests.swift:29` Card smoke is the natural place to extend.

### 2. iOS-gated real-Keychain integration test

`TokenStore.swift:67-103` Keychain code is exercised only at app runtime. A single round-trip test under `#if os(iOS)` (spec 011 lines 124-125 hinted at this gate) would catch regressions like an attribute typo or wrong service-name. Sketch:

```swift
#if os(iOS)
@Test func realTokenStoreRoundTripsViaKeychain() async {
    let store = TokenStore(serviceName: "MeetPRTest-\(UUID().uuidString)")
    await store.save(access: "a", refresh: "r")
    #expect(await store.accessToken() == "a")
    #expect(await store.refreshToken() == "r")
    await store.clear()
    #expect(await store.accessToken() == nil)
}
#endif
```

### 3. `Session.bootstrap` warn log goes through `print`

[Session.swift L40-L56](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Session.swift#L40-L56) emits `print("warning: bootstrap_refresh_deferred ...")`. Project doesn't yet have a structured logger; CLAUDE.md "技术栈" still lists logging as "待定". Once a logger spec lands, route this through it. Track as a separate FOLLOWUP if no logger spec is on the near-term roadmap.

### 4. Consider value-driven `navigationDestination(for:)` for the Login → Signup push

[LoginView.swift L70-L82](https://github.com/tianpingdeng112233-cell/meetpr/blob/01f711a22cff52e576be7411a89c3b37da27595c/Modules/AppShell/Sources/AppShell/Auth/LoginView.swift#L70-L82) uses `NavigationLink { SignupView() }` (label-driven). AGENTS.md (Swift & SwiftUI 实操约定 §SwiftUI 约定 — 导航) prefers `NavigationStack + navigationDestination(for:)` (value-driven). Functional now; cleaner if/when a third destination joins the flow.

---

## Final decision

**APPROVE.**

No P0 or P1 blockers. All acceptance items pass. All 9 spec-review decisions honored with concrete code evidence. Architecture, concurrency, and test quality are at or above the spec floor. The 4 P3 items above are soft follow-ups and can land in subsequent specs.

PR #27 is mergeable.

> Per orchestrator instruction: this review does not merge PR #27 — that's the main session's call.
