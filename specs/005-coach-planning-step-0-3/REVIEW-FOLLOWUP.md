# 005 — Review Followup Plan (digest of PR #26 feedback)

> 本文档消化 [PR #26](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) 关于 [PR #25 spec 005 实装](https://github.com/tianpingdeng112233-cell/meetpr/pull/25) 的 review 反馈,对比 main HEAD 当前代码状态,产出 fix 计划 + 决策清单。
>
> 来源 review: [`specs/005-coach-planning-step-0-3/REVIEW.md`](./REVIEW.md)(Claude · 2026-04-29 · Verdict: Request changes)

## TL;DR

**Review 提出的 1 P1 + 9 P3 中,实质上已落地 9.5/10。** 真正剩下需要决策的只有 1 条 nice-to-have(P3 #10 的可选条款)。

关键事实(回溯 git 历史时容易漏看):

- **PR #25 是 squash merge**,merge commit `2060ae5` 把 3 个原始 commits 压扁成一条,日志里能看到原 commit 列表:
  ```
  * feat(coach-planning): implement step 0-3 flow (spec: 005-coach-planning-step-0-3)
  * fix(coach-planning): clear drafts on logout (spec: 005-coach-planning-step-0-3)   ← P1 fix
  * refactor(coach-planning): apply review cleanups (spec: 005-coach-planning-step-0-3) ← P3 fix
  ```
- 也就是说,review 提的 P1 + 大多数 P3 在 **PR #25 自己 merge 前已经在 feature branch 内修完**,squash merge 的版本就是修后的版本。Review 是事后(2026-04-29 17:47:50Z)merge 的 PR #26,**只承载 REVIEW.md 文档**,不再带代码。
- 因此本文档的"修复策略"主要工作是**核实**而不是**安排**:对每条 review 项确认 main HEAD 上的当前形态,标 ✅/⚠️/❌。

剩下唯一可做的是:

- **P3 #10 的可选第二半**:给 `BackendPlanRepository` 加 `: PlanRepository` 占位 conformance(三个方法 fatalError body)。Review 自己说 "Optional but nice" — 完全可以推后。

## 状态总览(一张表)

| # | 优先级 | 项 | 状态 | 关联落地点 |
|---|---|---|---|---|
| 1 | **P1** | F-016 / `Session.logout()` 不清 `DraftStore` → 跨账号 draft leak | ✅ DONE | commit `9282274` (PR #25 内,见下方细节) |
| 2 | P3 | Step3 button label 漏出 `"TODO spec 006"` 给教练 | ✅ DONE | `Step3SelectMainLiftsView.swift:33` 现为 `"下一步"` |
| 3 | P3 | `DraftMappingError` 声明却从不抛;`throws` 是 dead | ✅ DONE | `DraftMapping.swift` 整文件无 enum、3 函数无 `throws` |
| 4 | P3 | `DayLiftAssignment` `public` 但无人引用 | ✅ DONE | 文件已删除(State/ 目录消失) |
| 5 | P3 | `Step3SelectMainLiftsView.swift:110-120` Binding setter 冗余 if-else | ✅ DONE | `Step3SelectMainLiftsView.swift:113-115` 单一赋值 |
| 6 | P3 | 硬编码 `[.squat, .bench, .deadlift]` 字面量出现 2 处 | ✅ DONE | `PlanningViewModel.swift:108` + `Step2AssignFrequencyView.swift:179` 都用 `LiftFamily.allCases` |
| 7 | P3 | `bootstrap()` 写 `errorMessage` 但没 view 读 | ✅ DONE | `PlanningViewModel.swift` 已删字段(catch 块清空 list,review 接受方案 b) |
| 8 | P3 | 5 个 `*PreviewFallback` enum,未 `#if DEBUG` 隔离 | ✅ DONE | `PlanningPreviewFactory.swift` 单一 helper 落地;5 view 文件 grep 0 hit |
| 9 | P3 | Fixture 4 个学员共享同一 `StudentProfile.id` (`uuid(100)`) | ✅ DONE | `PlanningFixtures.swift:32/38/44/50` 各为 `uuid(100/101/102/103)` |
| 10 | P3 | `BackendPlanRepository` 缺 `: Sendable`(以及可选 `: PlanRepository` w/ fatalError) | ⚠️ PARTIAL | `: Sendable` 已加(`BackendPlanRepository.swift:5`);`: PlanRepository` conformance 未加(review 自标 "Optional but nice") |

合计:**10/10** review item 中 **9 条全 closed**,**1 条 partial(只剩可选第二半未做)**。

---

## 逐项细节(P1 + 每条 P3)

### P1 #1 — F-016 / `Session.logout()` 不清 `DraftStore` → 跨账号 draft leak

- **Review 出处**: [PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P1 (must fix before merge)" 段;细节见 [REVIEW.md "P1 — must fix" §1](./REVIEW.md)
- **当前代码引用**(全部基于 main HEAD):
  - [`Modules/AppShell/Sources/AppShell/Session.swift:21-29`](../../Modules/AppShell/Sources/AppShell/Session.swift#L21-L29) — `init(auth:tokenStore:onLogout:)` 接受 `(@Sendable () async -> Void)?` 回调
  - [`Modules/AppShell/Sources/AppShell/Session.swift:81-85`](../../Modules/AppShell/Sources/AppShell/Session.swift#L81-L85) — `logout()` 在 `state = .anonymous` 之前 `await onLogout?()`
  - [`Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift:19-25`](../../Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift#L19-L25) — `DraftStore.shared` singleton (lazy 初始化持久 ModelContainer)
  - [`Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift:57-63`](../../Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftStore.swift#L57-L63) — `deleteAll() async throws` 落地
  - [`MeetPR/Sources/MeetPRApp.swift:13-28`](../../MeetPR/Sources/MeetPRApp.swift#L13-L28) — App init 接 `onLogout: { try? await draftStore.deleteAll() }`,且 app + Coach Planning flow 共用 `DraftStore.shared` 的同一个 SwiftData container
  - [`Modules/AppShell/Tests/AppShellTests/Auth/SessionTests.swift:113-130`](../../Modules/AppShell/Tests/AppShellTests/Auth/SessionTests.swift#L113-L130) — `logoutClearsStoreAndCallsLogoutHookOnce` 测试覆盖 callback exactly once + token store 全清
  - [`FOLLOWUPS.md`](../../FOLLOWUPS.md) — F-016 entry 已移到 `## 已完成` 段(关闭于 2026-04-29,关联 commit `9282274`)
- **判定**: ✅ DONE
- **修复策略**: 无 — 已落地。
- **遗留风险**: 无;ADR-009 §后续需回顾 #4 已满足,跨账号 leak 验证用例已被 unit test + 手测路径覆盖。
- **估时**: 0(已完成)

---

### P3 #2 — Step3 button label 漏出 `"TODO spec 006"` 给教练

- **Review 出处**: [REVIEW.md §P3 #2](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #1
- **Review 原 finding**: `Step3SelectMainLiftsView.swift:33` 的 PrimaryButton 标签是 `"完成基础编排（进入辅助项 TODO spec 006）"`,把内部 spec 编号泄露到 UI
- **当前代码引用**: [`Step3SelectMainLiftsView.swift:32-39`](../../Modules/CoachKit/Sources/CoachKit/Planning/Views/Step3SelectMainLiftsView.swift#L32-L39) 现为:
  ```swift
  PrimaryButton(
    "下一步",
    isDisabled: !viewModel.isCurrentStepValid,
    isFullWidth: true
  ) { Task { try? await viewModel.finish() } }
  ```
- **判定**: ✅ DONE
- **遗留 nit**: 当前 label `"下一步"` 比 review 建议的 `"完成基础编排"` 更通用,但语义 OK(用户走完 Step 3 → finish() → coordinator dismiss)。spec 005 §1 #3 原文要求 "明确的 '完成基础编排,进入辅助项 (TODO spec 006)' 占位 CTA" — 现在 CTA 没有显式表达"基础编排完成 / 辅助项即将上线"语义。**不阻塞 ship**,但下游 spec 006 接入 Step 4 时复审一下 Step 3 finish 的 user-visible flow 是否需要更明确的承上启下文案。
- **修复策略**(若想更进一步): copy 改为 `"完成基础编排"` + 副标题 / 说明栏 `"辅助项设置即将上线"`,再把 spec 编号挪进 `// MARK:`。
- **估时**: 0(已完成);若做文案细调 ≤ 15 min。

---

### P3 #3 — `DraftMappingError` 声明却从不抛;`throws` 是 dead

- **Review 出处**: [REVIEW.md §P3 #3](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #2
- **Review 原 finding**: `DraftMapping.swift:4-7` 定义 `enum DraftMappingError { case missingPlanID; case missingDayID }` 但全文件 0 throw;`toDomain` / `toDomainDays` / `toDomainExercises` 全标 `throws` 但没真 throw,call site 白付 `try`
- **当前代码引用**: [`DraftMapping.swift`](../../Modules/CoachKit/Sources/CoachKit/Planning/Drafts/DraftMapping.swift) — 整文件已无 `DraftMappingError`,4 个 free function (`toDomain` / `toDomainDays` / `toDomainExercises` / `fromDomain`) 全部 non-throwing
- **判定**: ✅ DONE(选了 review 方案 a:删 enum + 删 `throws`)
- **修复策略**: 无 — 已落地。
- **估时**: 0

---

### P3 #4 — `DayLiftAssignment` `public` 但无人引用

- **Review 出处**: [REVIEW.md §P3 #4](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #3
- **Review 原 finding**: `Modules/CoachKit/Sources/CoachKit/Planning/State/DayLiftAssignment.swift` 定义了 value struct 但 ViewModel 实际用 `[Int: Set<LiftFamily>]`,`grep -r DayLiftAssignment` 命中数 = 1(只有声明)
- **当前代码引用**: 文件已删除。`Modules/CoachKit/Sources/CoachKit/Planning/State/` 目录现仅含: `DayLiftKey.swift` / `PlanningStep.swift` / `PlanningValidationError.swift` / `PlanningViewModel.swift` / `SBDFrequency.swift`
- **判定**: ✅ DONE(选了 review "delete the file" 路径)
- **遗留 nit**: SPEC.md §1.2 文档表中仍列着 "`DayLiftAssignment.swift` | value struct: 单训练日 → `[LiftFamily]` 映射" — 与实装 drift。修 SPEC.md 的合适时机是把 `状态: InReview` → `Done`,届时一起把这行划掉。**等用户决策**(详见末尾 §决策清单)。
- **估时**: 删 SPEC.md 一行 ≤ 5 min,合并入 SPEC.md status 收尾改动。

---

### P3 #5 — `Step3SelectMainLiftsView.swift:110-120` Binding setter 冗余 if-else

- **Review 出处**: [REVIEW.md §P3 #5](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #4
- **Review 原 finding**: setter 两个分支都赋同一个值,可合并为单语句
- **当前代码引用**: [`Step3SelectMainLiftsView.swift:110-116`](../../Modules/CoachKit/Sources/CoachKit/Planning/Views/Step3SelectMainLiftsView.swift#L110-L116) 现为:
  ```swift
  private var selectedExerciseID: Binding<UUID?> {
    Binding {
      viewModel.selectedVariants[key]
    } set: { newValue in
      viewModel.selectedVariants[key] = newValue
    }
  }
  ```
- **判定**: ✅ DONE
- **估时**: 0

---

### P3 #6 — 硬编码 `[.squat, .bench, .deadlift]` 字面量出现 2 处

- **Review 出处**: [REVIEW.md §P3 #6](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #5
- **Review 原 finding**: `PlanningViewModel.swift:108` 与 `Step2AssignFrequencyView.swift:179` 各有一份 `[.squat, .bench, .deadlift]` 字面量,`LiftFamily` 已 `CaseIterable`,顺序为 SBD 约定
- **当前代码引用**:
  - [`PlanningViewModel.swift:106-109`](../../Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningViewModel.swift#L106-L109): `LiftFamily.allCases.filter { assignments.contains($0) }` ✓
  - [`Step2AssignFrequencyView.swift:178-186`](../../Modules/CoachKit/Sources/CoachKit/Planning/Views/Step2AssignFrequencyView.swift#L178-L186): `ForEach(LiftFamily.allCases, id: \.self)` ✓
- **判定**: ✅ DONE(用了 `LiftFamily.allCases`,review 接受的方案 1)
- **遗留 nit**: `PlanningViewModel.swift:289-296` 的 `restore` switch 仍显式 `.squat / .bench / .deadlift` — 这是 switch case,**允许**(将来加第 4 case 编译器会强制 exhaustive 报错,不算硬编码字面量)。
- **估时**: 0

---

### P3 #7 — `bootstrap()` 写 `errorMessage` 但没 view 读

- **Review 出处**: [REVIEW.md §P3 #7](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #6
- **Review 原 finding**: `PlanningViewModel.swift:73-78` catch block `errorMessage = error.localizedDescription` 但无 view 读;若 repo 抛错,用户只看到空 list 0 反馈
- **当前代码引用**: [`PlanningViewModel.swift:58-77`](../../Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningViewModel.swift#L58-L77) — `errorMessage` 字段已删,catch block 现为 `availableStudents = []; mainLiftCatalog = [:]`
- **判定**: ✅ DONE(选了 review 方案 b:remove the property until it's consumed)
- **遗留风险**: V1 mock-only `InMemoryPlanRepository` 阶段是 academic;真 backend 接入(后续 spec 落 `BackendPlanRepository` body)前必须重新评估 Step 0 empty state 是否需要 surface error。可写进那个 spec 的 §不做什么 → §做什么 切换清单,**不在本 followup 范围**。
- **估时**: 0(本 review item);后续 backend spec 各自承担。

---

### P3 #8 — 5 个 `*PreviewFallback` enum,未 `#if DEBUG` 隔离

- **Review 出处**: [REVIEW.md §P3 #8](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #7
- **Review 原 finding**: `PlanningCoordinatorView` / `Step0` / `Step1` / `Step2` / `Step3` 各自带一份 `<Step>PreviewFallback` enum,5 份重复 + release binary 可见
- **当前代码引用**:
  - [`Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningPreviewFactory.swift`](../../Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningPreviewFactory.swift) — 单一 helper 落地
  - 5 个 view 文件的 `#Preview` 块均用 `PlanningPreviewFactory.makeStore()`(grep `PreviewFallback` 命中 0)
- **判定**: ✅ DONE
- **遗留 nit**: 没核实 `PlanningPreviewFactory.swift` 自身是否包在 `#if DEBUG` 里。建议下次 ship cleanup 时确认;不阻塞。
- **估时**: 0(若顺手核实 `#if DEBUG` 包裹 ≤ 5 min)

---

### P3 #9 — Fixture 4 个学员共享同一 `StudentProfile.id`(`uuid(100)`)

- **Review 出处**: [REVIEW.md §P3 #9](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #8
- **Review 原 finding**: `PlanningFixtures.swift:166` 的 `profile()` 给 4 个学员都传 `uuid(100)` 作为 `StudentProfile.id`,latent bug
- **当前代码引用**: [`PlanningFixtures.swift:30-54`](../../Modules/CoachKit/Tests/CoachKitTests/Planning/Fixtures/PlanningFixtures.swift#L30-L54) — 4 个学员各自的 profile id 已分开:
  - 王小明: `uuid(100)`
  - 张三: `uuid(101)`
  - 李四: `uuid(102)`
  - 钱六: `uuid(103)`
- **判定**: ✅ DONE
- **估时**: 0

---

### P3 #10 — `BackendPlanRepository` 缺 `: Sendable`(以及可选 `: PlanRepository` w/ fatalError)

- **Review 出处**: [REVIEW.md §P3 #10](./REVIEW.md);[PR #26 body](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) "P3" #9
- **Review 原 finding** (两半):
  - **a) `: Sendable`** — 当前 empty struct 隐式 Sendable,但加了显式约束未来加字段会被编译器 catch
  - **b) `: PlanRepository`** — 占位 conformance + 三方法 fatalError body 能强制编译期签名核对(spec NNN 接 backend 时 catch drift);review 自标 "Optional but nice"
- **当前代码引用**: [`BackendPlanRepository.swift`](../../Modules/CoachKit/Sources/CoachKit/Planning/Repository/BackendPlanRepository.swift):
  ```swift
  import Foundation

  // swiftlint:disable:next todo
  // TODO: spec NNN backend wiring.
  public struct BackendPlanRepository: Sendable {
    public init() {}
  }
  ```
- **判定**: ⚠️ PARTIAL — 半 a 已落,半 b 未落
- **修复策略**(若决定做半 b):
  ```swift
  import CoreModels
  import Foundation

  // swiftlint:disable:next todo
  // TODO: spec NNN backend wiring.
  public struct BackendPlanRepository: PlanRepository, Sendable {
    public init() {}

    public func fetchStudents() async throws -> [CoachStudentSummary] {
      fatalError("BackendPlanRepository.fetchStudents() not implemented; tracked in spec NNN backend wiring")
    }

    public func fetchMainLiftCatalog() async throws -> [Exercise] {
      fatalError("BackendPlanRepository.fetchMainLiftCatalog() not implemented; tracked in spec NNN backend wiring")
    }

    public func publishPlan(plan: TrainingPlan, days: [PlanDay], exercises: [PlanExercise]) async throws {
      fatalError("BackendPlanRepository.publishPlan() not implemented; tracked in spec NNN backend wiring")
    }
  }
  ```
  - 注意:`fatalError` 被 AGENTS.md `try!`/force-unwrap 禁令豁免("不可恢复的启动失败" 类同),且 backend spec 落地时这些 body 会被替换。
  - 风险:实装期没人调这些 method,`fatalError` 永远不会跑;仅服务编译期签名核对。
- **判定 (1)/(2)/(3)**: 这是真正剩下需要 user 决策的 1 项,见末尾决策清单。
- **估时**: 半 b 实装 ≤ 15 min(包括 `import CoreModels`、3 个空方法体、`swift build` 验证)。

---

## 真正剩下要做的事(总结)

只剩 **1 条** 实质性可选改动 + **2 条**配套文档收尾(都是低成本、不阻塞):

1. **(可选)P3 #10 半 b** — 给 `BackendPlanRepository` 加 `: PlanRepository` conformance + 3 个 `fatalError` body。
2. **(SPEC.md 文档收尾)** — 把 `状态: InReview` → `Done`(P1 已落),并把 §1.2 文档表里的 `DayLiftAssignment.swift` 行删掉(P3 #4 实装时已删文件,SPEC.md drift)。
3. **(SPEC.md PR 字段收尾)** — `**PR**: (待填)` 填成 PR #25 链接。

按用户提示,**1 是 Codex 干**(实装),**2 / 3 是 Claude 干**(SPEC 维护),且**都不该在 user 决策前先做**。

---

## 决策清单(给 user)

请就以下 4 个开关给意见,然后下游 Codex / Claude 各自走分工:

### 决策 1 — P3 #10 半 b: `BackendPlanRepository` 加 `: PlanRepository` 占位 conformance?

- **(A) 现修**: 起 Codex session,用上面 §P3 #10 §修复策略 的代码模板,15 min 落地。下次接 backend spec 时编译器帮 catch 签名 drift。
- **(B) 推后**: 留到真正接 backend 那个 spec 一起做。届时三个方法 body 直接写真实实装,`fatalError` 占位本来也只活几小时。本质区别:**A** 多 1 个 PR + 短期收益,**B** 等于零成本但无短期收益。
- **(C) 不修**: review 标 "Optional but nice",不做也不破坏 spec 005 任何契约。

> **倾向**: B(推后),理由:本 spec 范围不接 backend,真接入那 spec 必然会重写这文件,占位 fatalError 价值仅活到那时;为这点价值起一个独立 PR 性价比低。但如果用户喜欢"立刻清掉一切 review item",A 也 OK,15 min 走完。

### 决策 2 — `specs/005-coach-planning-step-0-3/SPEC.md` 状态从 `InReview` → `Done`?

- 前置条件:P1 已落 ✅,9 P3 中 9 条 closed + 1 条 partial(若决策 1 选 C 或 B)
- AGENTS.md 交付检查清单原文要求 PR merge 前更新 SPEC.md 状态为 `InReview`,但**没规定** "Done" 改的时机;实际惯例(看 spec 002/003/004 现状)是 review approved + 全 P3 决策完毕后一起翻。
- **(A) 翻成 Done**:跟决策 1 同一个 PR 一起改,或独立小 PR 改。
- **(B) 暂留 InReview**:等决策 1 真正落地后再翻。
- **(C) 翻成 Done 同时把 §1.2 表里的 `DayLiftAssignment.swift` 行删掉**(spec drift 一并清):见决策 3。

> **倾向**: C — 一次性把 InReview → Done + 删 DayLiftAssignment 行 + 填 PR #25 链接,放在本 review-digest 的 follow-up Codex 实装 PR 里(若决策 1 = A),或单独一个 `docs(spec-005): finalize spec status post-review` PR(若决策 1 = B 或 C)。

### 决策 3 — SPEC.md §1.2 文档表里的 `DayLiftAssignment.swift` 行处置?

- 本条与决策 2 是同一动作的不同切片,但单独列以便 user 评估 "spec 文档要不要严格反映实装事实"。
- **(A) 删行**:实装已删文件,spec 文档同步删,保 spec ↔ 代码 1:1 对照。
- **(B) 保留 + 加 strikethrough / 注释**:留作"曾经设计过的 typed wrapper" 历史痕迹。

> **倾向**: A — spec 是契约不是档案,删干净。

### 决策 4 — Spec 005 SPEC.md 顶部 `**PR**: (待填)` 字段?

- **(A) 填 PR #25 + PR #26 链接**:`**PR**: [#25 实装](https://github.com/tianpingdeng112233-cell/meetpr/pull/25) / [#26 review](https://github.com/tianpingdeng112233-cell/meetpr/pull/26)`
- **(B) 只填 PR #25**:review 是关联 PR,但不是实装 PR,可选不列。
- **(C) 留 `(待填)`**:无意义,不推荐。

> **倾向**: A — 一次留全,后人回查时不用再翻 git log。

---

## 不做什么

- ❌ **不动代码** — 本 followup 是给 user 的决策清单,实装由下一个 Codex session 走 `feat/005-review-cleanup` 或 `chore/005-spec-finalize` 分支完成(看决策 1/2 结果)。
- ❌ **不动 SPEC.md** — 等 user 决策 2/3/4 后再改。
- ❌ **不重写 REVIEW.md** — 它是 PR #26 的产物,作为 review 历史保留。

## 来源

- [PR #26](https://github.com/tianpingdeng112233-cell/meetpr/pull/26) — review companion(MERGED 2026-04-29 17:47:50Z)
- [REVIEW.md](./REVIEW.md) — Claude 完整 review 报告
- [PR #25](https://github.com/tianpingdeng112233-cell/meetpr/pull/25) — spec 005 实装(MERGED 2026-04-29 17:38:10Z,squash commit `2060ae5`)
- [SPEC.md](./SPEC.md) — 原 spec 契约
- [FOLLOWUPS.md](../../FOLLOWUPS.md) — F-016 关闭记录
- [ADR-009](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) §后续需回顾 #4
