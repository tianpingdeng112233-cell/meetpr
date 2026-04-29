# Review — 005-coach-planning-step-0-3 (PR #25)

**Reviewer:** Claude · **Date:** 2026-04-29 · **Verdict:** Request changes (1 P1 blocker + P3 cleanups)

## TL;DR

Strong, careful execution of the most ambitious spec to date — first real SwiftUI feature flow, first SwiftData adoption, first ViewInspector usage, all clean. F-015 / v4.4 pivot redline is **fully respected**: zero forbidden terms (`specificityBucket`, `waveformValue`, `accessoryDensityBucket`, `isDeloadWeek`, `波形`, `变式矩阵`, `密度条`, `4 周扫视`, `Excel grid`) anywhere in code or tests; no `TabView(.page)`, no 4-week macro view, no cycle comparison preempted. Spec 005 §验收标准 (20 checkboxes) all satisfied — verified line-by-line. Step 1 evaluation-period gate hard-disables the 4-week button at both view and view-model layers. ADR-005 §3 import boundaries clean across all 26 Planning files. ADR-009 SwiftData scope strictly limited to the 3 declared `@Model` classes with zero `@Attribute(.unique)`, zero CloudKit symbols, zero `toDomain` instance methods on `@Model` classes (free functions in `DraftMapping.swift` are correctly `@MainActor`). All 4 `@Test` test files use Swift Testing (zero XCTest), test count is **20** (≥ spec floor 18), ViewInspector pinned `from: "0.10.0"` per spec. Modern SwiftUI API discipline holds: zero `cornerRadius()` / `foregroundColor()` / `NavigationView` / 1-param `onChange` / `DispatchQueue.main.async` / `try!` in production code. CoachKit ⊥ StudentKit invariant preserved (zero `import StudentKit` anywhere).

Blocking: **F-016 / ADR-009 §后续 #4 — cross-account draft leak unwired.** PR introduces SwiftData persistence to the repo for the first time but does not wire `Session.logout()` to clear the draft store. The PR description doesn't mention F-016 (which was added to FOLLOWUPS.md by spec 011's PR #24 the same day this PR opened, so Codex likely didn't see it), but the underlying requirement is also stated in ADR-009 §后续需回顾 #4 ("Logout 时清 SwiftData") — the PR misses both. Symptom: coach A signs up → writes 1 draft → logs out → coach B signs up on the same device → `resumeMostRecentDraft()` iterates A's `traineeID` set and surfaces A's draft. Has to be fixed before merge.

After the P1 + P3 cleanups below, ready to ship.

Counts: **P0:0 P1:1 P2:0 P3:9**.

---

## P1 — must fix

### 1. F-016 / ADR-009 §后续 #4 — `Session.logout()` does not clear `DraftStore`, cross-account draft leak

[FOLLOWUPS.md F-016](../../FOLLOWUPS.md) (created 2026-04-29 by spec 011 review, triggered by *exactly* this PR):

> **触发条件**: Codex 在起 `feat/005-coach-planning-step-0-3` PR 时，或在 spec 005 实装 PR (任何把 `DraftStore` / `DraftTrainingPlan` 等 SwiftData @Model class 引入仓库的 PR)
> **动作**: 修改 `MeetPR/MeetPRApp.swift` 中 `Session` 初始化, 把 `onLogout: nil` 替换为 `onLogout: { await DraftStore.shared.deleteAll() }` (或等价 DI 写法)

[ADR-009 §后续需回顾 #4](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md):

> **跨账号 leak 验证**: spec 011 auth flow 实装后, 手动测教练 A logout → 教练 B login, 确认 B 看不到 A 的 draft

What's missing in PR #25:

1. [`MeetPR/Sources/MeetPRApp.swift`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/MeetPR/Sources/MeetPRApp.swift) line 7 — `Session(api: APIClient.shared)` is constructed with no `onLogout` callback.
2. [`Modules/AppShell/Sources/AppShell/Session.swift`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/AppShell/Sources/AppShell/Session.swift) — `Session.init(api:)` has no `onLogout` parameter; `logout()` simply sets `state = .anonymous`.
3. [`Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift) — exposes `deleteDraft(traineeID:)` only, no `deleteAll()`, no `shared` singleton or `@MainActor` static accessor.

Why the symptom is real, not theoretical: [`PlanningViewModel.resumeMostRecentDraft()`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningViewModel.swift) iterates **every available student's `traineeID`** against the on-device SwiftData store. The store is keyed by `traineeID`, not by `coachID` of the writing coach. After coach A logs out and coach B logs in on the same device, B's `availableStudents` list will overlap with A's only if students happen to repeat across coaches (unlikely in V1) — but the store still holds A's drafts under A's students' `traineeID`s. The risk surface is:

- If B's coach role grants visibility to any of A's students (e.g., shared studio fixture data, or restoring from a backup), B sees A's draft content.
- More importantly, A's drafts persist on disk under coach B's account session, which violates the implicit privacy contract called out in ADR-009 §后续 #4.

Fix scope (small, but touches 3 modules):

1. **`DraftStore`**: add `public func deleteAll() async throws { let drafts = try context.fetch(FetchDescriptor<DraftTrainingPlan>()); drafts.forEach { context.delete($0) }; try context.save() }`. Decide between a `shared` singleton (matches F-016 wording) and a DI shape (preferred per ADR-005 §2 "Session 通过 SwiftUI environment 注入 (非 singleton)"). Either is acceptable per F-016 "或等价 DI 写法".

2. **`Session`**: extend `init(api: APIClient, onLogout: (() async -> Void)? = nil)`; store the callback; invoke it inside `logout()` before `state = .anonymous`. This change is also required by [spec 011 SPEC.md §1](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/specs/011-auth-ui-flow/SPEC.md) (already merged on `main`), so it's not out-of-scope creep — it's the prerequisite both spec 011 implementation and F-016 share.

3. **`MeetPRApp.swift`**: change to `Session(api: APIClient.shared, onLogout: { await DraftStore.shared.deleteAll() })` (or wire via `@Environment(\.modelContext)` + a closure that captures the modelContext).

4. **Test**: add `SessionTests.swift` (or equivalent) asserting `Session.logout()` invokes the `onLogout` callback exactly once. Already foreshadowed in spec 011 REVIEW.md.

5. **FOLLOWUPS.md**: move F-016 entry from "待触发" to "已完成" with a link to this PR.

6. **PR description**: explicitly list the F-016 wiring change so the next reviewer doesn't repeat the audit.

Acceptable alternative (lower-confidence, only if the user wants to keep this PR's scope tight): merge PR #25 as-is + immediately open a follow-up PR that does items 1–5 above. Window of risk: any tester running multi-coach signup on the same device between merges would hit the leak. Not recommended.

---

## P3 — recommended cleanups

### 2. `Step3SelectMainLiftsView.swift:33` — user-facing button label leaks `TODO spec 006`

[`Step3SelectMainLiftsView.swift:33`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/Step3SelectMainLiftsView.swift):

```swift
PrimaryButton("完成基础编排（进入辅助项 TODO spec 006）", isFullWidth: true, ...)
```

The string `"TODO spec 006"` is rendered to coaches in the simulator walkthrough today. Spec 005 SPEC.md §1 #3 line 20 calls for "明确的 '完成基础编排,进入辅助项 (TODO spec 006)' 占位 CTA" — internal spec wording, not user-facing copy. Suggested clean copy: `"完成基础编排"` with a subtitle Eyebrow `"辅助项设置即将上线"`, or just `"完成基础编排"` standalone. Move the spec reference into a `// MARK:` comment.

### 3. `DraftMapping.swift:4-7` — `DraftMappingError` declared but never thrown; `throws` on three functions is dead

[`DraftMapping.swift:4-7`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftMapping.swift):

```swift
public enum DraftMappingError: Error, Sendable {
  case missingPlanID
  case missingDayID
}
```

Neither case is thrown anywhere in the file. `toDomain`, `toDomainDays`, `toDomainExercises` are all marked `throws` but contain no `throw`. Call sites (e.g. [`DraftMappingTests.swift`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Tests/CoachKitTests/Planning/DraftMappingTests.swift)) pay `try` for nothing.

Pick one:
- (a) Remove `DraftMappingError` enum and drop `throws` from the three signatures (cleanest — current behavior is total).
- (b) Add real validation, e.g. `guard draft.id != UUID() else { throw .missingPlanID }`, with a corresponding test.

### 4. `DayLiftAssignment` is declared `public` but referenced nowhere

[`Modules/CoachKit/Sources/CoachKit/Planning/State/DayLiftAssignment.swift`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/State/DayLiftAssignment.swift) — defined per SPEC.md §1.2 "value struct: 单训练日 → `[LiftFamily]` 映射" but the view model uses `[Int: Set<LiftFamily>]` directly. `grep -r "DayLiftAssignment" Sources/ Tests/` returns the declaration only. SwiftLint's `unused_declaration` analyzer rule (enabled in [.swiftlint.yml](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/.swiftlint.yml)) is likely to flag this on a clean run.

Either delete the file, or wire it into the view model as a typed wrapper (`var dayAssignments: [DayLiftAssignment]` instead of the dictionary — slightly cleaner Swift API but would touch the validation paths).

### 5. `Step3SelectMainLiftsView.swift:110-120` — redundant Binding setter branches

```swift
} set: { newValue in
  if let newValue {
    viewModel.selectedVariants[key] = newValue
  } else {
    viewModel.selectedVariants[key] = nil
  }
}
```

Both branches assign `newValue` to the dictionary. Reduces to:

```swift
} set: { newValue in
  viewModel.selectedVariants[key] = newValue
}
```

### 6. `LiftFamily` SBD order hardcoded literal in two places

- [`PlanningViewModel.swift:108`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningViewModel.swift): `let order: [LiftFamily] = [.squat, .bench, .deadlift]`
- [`Step2AssignFrequencyView.swift:179`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/Step2AssignFrequencyView.swift): `ForEach([LiftFamily.squat, .bench, .deadlift], id: \.self)`

`LiftFamily` is `CaseIterable` in CoreModels with declared order squat→bench→deadlift. Either use `LiftFamily.allCases` (reliance on declaration order is the SBD convention, and any future case addition would be deliberate) or extract a `static let sbdOrder: [LiftFamily] = [.squat, .bench, .deadlift]` once. If `allCases` order ever diverges from the literal, the two sites silently disagree — the kind of bug that surfaces only when adding a 4th lift family.

### 7. `bootstrap()` swallows errors into `errorMessage` with no UI surface

[`PlanningViewModel.swift:73-78`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningViewModel.swift):

```swift
} catch {
  errorMessage = error.localizedDescription
}
```

`errorMessage` is assigned but no view reads it. If `repository.fetchStudents()` or `fetchMainLiftCatalog()` throws, the user sees an empty list with zero feedback. For the V1 mock-only `InMemoryPlanRepository` this is academic — but Step 0 has empty-state real estate that should surface the message (or remove the property until it's consumed).

### 8. Five identical `*PreviewFallback` enums; not gated by `#if DEBUG`

[`PlanningCoordinatorView.swift:67-76`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningCoordinatorView.swift), [`Step0SelectStudentView.swift:174-183`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/Step0SelectStudentView.swift), [`Step1SelectDurationView.swift:130-139`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/Step1SelectDurationView.swift), [`Step2AssignFrequencyView.swift:233-242`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/Step2AssignFrequencyView.swift), [`Step3SelectMainLiftsView.swift:151-160`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Views/Step3SelectMainLiftsView.swift).

Each view ships its own private `<Step>PreviewFallback` enum whose only job is `try DraftStore.inMemory()` + `fatalError` on failure. Five copies, all reachable in release binaries (no `#if DEBUG`). The `#Preview` block then does `try? DraftStore.inMemory() ?? PreviewFallback.make()` which calls `try DraftStore.inMemory()` *again* — if the first call failed the second will too.

Suggested fix: collapse into a single `PlanningPreviewFactory.makeStore()` helper in a single `#if DEBUG` file (e.g. `Planning/Views/PlanningPreviewFactory.swift`), and make it `try!` (acceptable per AGENTS.md "不可恢复的启动失败" — and `#if DEBUG` makes it definitely not in production).

### 9. Test fixture: all 4 students share the same `StudentProfile.id`

[`PlanningFixtures.swift:166`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Tests/CoachKitTests/Planning/Fixtures/PlanningFixtures.swift) — `profile()` always passes `uuid(100)` for `StudentProfile.id`. So all four `StudentProfile` instances returned by `students()` (王小明 / 张三 / 李四 / 钱六) have the same `profile.id`. Only `userID` (which becomes `CoachStudentSummary.id`) differs.

No current test asserts on `profile.id`, so this is latent — but a future test that checks "this draft belongs to this profile" via `profile.id` would silently match across all four students. Cheap to harden:

```swift
public static func profile(userID: UUID, ..., profileSeed: Int = 0) -> StudentProfile {
  StudentProfile(id: uuid(100 + profileSeed), userID: userID, ...)
}
```

…or use distinct seeds per student in the `students()` factory.

### 10. `BackendPlanRepository` lacks explicit `: Sendable` and `: PlanRepository` conformances

[`BackendPlanRepository.swift:5`](https://github.com/tianpingdeng112233-cell/meetpr/blob/4f041d9cf9e5c6f0fb65ec7151853fabf2369bfb/Modules/CoachKit/Sources/CoachKit/Planning/Repository/BackendPlanRepository.swift):

```swift
public struct BackendPlanRepository {
  public init() {}
}
```

Spec 005 §1.4 line 65 explicitly accepts an empty placeholder, so this is not a violation. But:

- **Sendable**: implicit today (empty payload), but a future field could silently break Sendability without a compiler warning. Add `: Sendable` to lock it in (matches the pattern of every other Planning value-type).
- **PlanRepository conformance**: deferring conformance is what the spec asked for, but a placeholder with `fatalError("Not implemented; tracked in spec NNN")` bodies for the three protocol methods would force the type to compile-check against the protocol shape. When spec NNN actually wires this struct, the compiler catches signature drift instead of silently accepting a wrong call. Optional but nice.

---

## What I checked and found clean

- **F-015 / v4.4 redline**: zero hits on `specificityBucket` / `waveformValue` / `accessoryDensityBucket` / `isDeloadWeek` / `densityBucket` / `scanState` / `波形` / `变式矩阵` / `密度条` / `4 周扫视` / `Excel grid` across `Modules/CoachKit/Sources/` and `Modules/CoachKit/Tests/`. ✓
- **No 4-week macro view / TabView(.page) preempted**: zero `TabView` / `.page` / `PageTabView` hits in Planning/. Coordinator uses `NavigationStack(path:)` with sequential `PlanningStep` routing — exactly what spec 005 requires for Step 0-3. ✓
- **Spec 005 §验收标准 (20 checkboxes)**: all satisfied. Subdirs created; 5 view files with `public init` + `#Preview`; PlanningViewModel `@Observable @MainActor public final class` with all 9 fields; 3 `@Model` classes with all relationships optional; DraftStore `@MainActor public final class` with 3 methods; DraftMapping has free `toDomain`/`fromDomain` (`@MainActor`-annotated as required for SwiftData ↔ Sendable bridge); PlanRepository protocol exact 3 async-throws shape; `InMemoryPlanRepository` actor; `BackendPlanRepository` placeholder; `MeetPRApp.swift` `.modelContainer(for:)` registered; CoachRootView `PrimaryButton("排新计划")` + `.fullScreenCover`; Step 0 3-section grouping with ⚠️/🟡 + countdown/reason; Step 1 4-week button hard-disabled for inEvaluation; Step 2 template/copy buttons disabled placeholders + validation; Step 3 picker filters by `mainLiftFamily == liftFamily`; `bootstrap()` resume from SwiftData; `finish()` → `didFinish` → coordinator dismiss; **20 tests** (target ≥18); fixture has 1 evaluation + 2 active + 1 abnormal + 3 mainLift + 4 mainLiftVariation; `Package.swift` ViewInspector `from: "0.10.0"`. ✓
- **ADR-005 §3 import boundaries**: verified across all 26 Planning files. Views/ import only SwiftUI/CoreModels/DesignSystem/internal; State/ only Foundation/CoreModels/Observation; Drafts/ only Foundation/SwiftData/CoreModels; Repository/ only Foundation/CoreModels; `BackendPlanRepository.swift` only Foundation. Zero `import Networking` in Planning/. Zero `import StudentKit` anywhere in CoachKit. ✓
- **ADR-009 SwiftData scope**: exactly 3 `@Model` hits (the declared classes); 0 `@Attribute(.unique)`; 0 CloudKit/CKContainer/cloudKitDatabase symbols; 0 `toDomain` instance methods on `@Model` classes. `DraftMapping.swift` free functions all `@MainActor` as required. ✓
- **ADR-005 §1 CoachKit ⊥ StudentKit**: `Modules/CoachKit/Package.swift` does not list StudentKit dependency; `grep -r "import StudentKit" Modules/CoachKit/Sources/` returns 0. ✓
- **Swift 6 strict concurrency**: `Package.swift` has `.enableUpcomingFeature("StrictConcurrency")` on both main and test targets. `PlanningViewModel` is `@Observable @MainActor public final class`. `DraftStore` is `@MainActor public final class`. All step views explicit `@MainActor`. `InMemoryPlanRepository` is `public actor InMemoryPlanRepository: PlanRepository` with `protocol PlanRepository: Sendable`. All value types Sendable + Hashable as appropriate. No `@unchecked Sendable`. ✓
- **AGENTS.md modern API discipline**: zero `DispatchQueue.main.async`, `ObservableObject` family, `try!`, force-unwraps, `replacingOccurrences`, `DateFormatter`/`NumberFormatter`/`String(format:)`, `cornerRadius()`, `foregroundColor()`, `NavigationView`, 1-param `onChange`, `onTapGesture`, `AnyView`, `UIScreen.main.bounds`, `UIColor.*`, `UIGraphicsImageRenderer`, `Task.sleep(nanoseconds:)`. ✓
- **Test framework — Swift Testing (not XCTest)**: zero `import XCTest` / `XCTAssert` in `Tests/CoachKitTests/Planning/`. All 5 files use `import Testing` + `@Test`. ViewInspector wired into snapshot tests via `.inspect()` traversal. ✓
- **Test count per file**: PlanningViewModel=6 (target 5, +1), DraftStore=3 (target 3, ✓), DraftMapping=4 (target 4, ✓), PlanRepository=3 (target 3, ✓), PlanningFlowSnapshot=4 (target 3, +1). Planning total **20**, exceeds spec floor of 18. PR description's "21 tests" includes 1 outside Planning/ (`CoachRootViewTests.swift`) — reconciled. ✓
- **Step 0/1/2/3 behavior tests**: all asserted in `PlanningFlowSnapshotTests.swift` — 3-section grouping with counts, 4-week disabled badge, template/copy buttons disabled, per-day picker for assigned lift family. ✓
- **One type per file (AGENTS.md §通用工程)**: every file has exactly one top-level type. Nested `private struct` view helpers (StudentRow, DurationChoiceCard, etc.) are file-scoped private and tightly coupled — explicitly allowed. ✓
- **Format compliance**: SPEC.md is `Status: InReview`, structure 来源/目标/范围/技术要求/验收标准/参考/Notes matches spec 002/003/004 pattern. PR description Acceptance Checklist mirrors SPEC.md §验收标准. ✓
- **Pivot resilience**: spec 005 implementation does not touch `coach-planning.md` §7b/7c/7d territory. No premature 4-week UI scaffolding. F-015 awareness is structurally enforced by sequential NavigationStack architecture choice. ✓

---

## Summary of changes requested

1. **P1 #1** — Wire F-016 / ADR-009 §后续 #4: add `Session.init(api:onLogout:)`, add `DraftStore.deleteAll()` (and a stable accessor — `shared` singleton or DI), set `onLogout: { await DraftStore.shared.deleteAll() }` in `MeetPRApp.swift`, add 1 unit test asserting `Session.logout()` invokes the callback exactly once, move F-016 entry from "待触发" to "已完成" in FOLLOWUPS.md, list this in PR description.
2. **P3 #2** — Clean user-facing button label at `Step3SelectMainLiftsView.swift:33` (drop "TODO spec 006" string).
3. **P3 #3** — Resolve `DraftMappingError` dead code: drop `throws` and the unused enum, OR add real validation throwing it with a test.
4. **P3 #4** — Delete unused `DayLiftAssignment` (or wire it into the view model).
5. **P3 #5** — Simplify redundant Binding setter at `Step3SelectMainLiftsView.swift:110-120`.
6. **P3 #6** — Replace hardcoded `[.squat, .bench, .deadlift]` literals with `LiftFamily.allCases` or a single `LiftFamily.sbdOrder` static.
7. **P3 #7** — Either render `errorMessage` in Step 0 empty state, or remove the property until consumed.
8. **P3 #8** — Collapse five `*PreviewFallback` enums into a single `#if DEBUG` `PlanningPreviewFactory` helper.
9. **P3 #9** — Distinct `StudentProfile.id` per fixture student (`uuid(100 + offset)`).
10. **P3 #10** — Add `: Sendable` (and optionally `: PlanRepository` with `fatalError` bodies) to `BackendPlanRepository`.

After P1 #1, the rest can ship as a small follow-up cleanup PR if desired. Verdict flips to **Approve** once P1 lands.
