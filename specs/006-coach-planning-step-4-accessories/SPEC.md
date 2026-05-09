# 006 — Coach Planning UI Step 4 添加辅助动作 (三标签 facets)

- **状态**: Done
- **PR**: (待填)
- **来源**:
  - [coach-planning.md v4.4 §Step 4 (v4.2 三标签并行筛选)](~/Brain/wiki/projects/MeetPR/coach-planning.md) — wireframe ground truth
  - [data-model.md v1.1 §1.4 Exercise (三标签 facets)](~/Brain/wiki/projects/MeetPR/data-model.md)
  - 上游 [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) — User / 相关 enum
  - 上游 [spec 003 DesignSystem foundation](../003-design-system-foundation/SPEC.md) — 14 atomic + token
  - 上游 [spec 004 CoreModels training plan](../004-core-models-training-plan/SPEC.md) — `Exercise` / `MuscleGroup` / `Equipment` / `MovementPattern` enum (本 spec UI 直接消费, 不改)
  - 上游 [spec 005 Coach Planning UI Step 0-3](../005-coach-planning-step-0-3/SPEC.md) — `PlanningCoordinatorView` / `PlanningStep` enum / `PlanningViewModel` / `DraftPlanExercise` / `PlanRepository` / `DraftStore` (本 spec 全部接力 + 扩展, 不重写)
  - 上游 backend [spec 002-coach-planning-crud GET /exercises](../../../MeetPR-backend/specs/002-coach-planning-crud/SPEC.md) — facet csv contract (OR within facet, AND across facets); 本 spec 用 InMemoryRepository 复刻同 filter 语义
  - [ADR-005 §1 (CoachKit 模块边界) + §3 (MVVM + Repository)](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
  - [ADR-009 SwiftData 例外](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) — `DraftPlanExercise` 已落地, accessory 复用同 model (`is_main_lift = false`)
  - [F-015 — 任何 coach planning spec 必须按 v4.4](../../FOLLOWUPS.md)

## 目标

接力 spec 005 Step 0-3 后, 实装 Step 4 (每天添加辅助动作) UI. 落地后:

1. 教练完成 spec 005 Step 3 后, 自然 push 进 Step 4, 看到 day chip bar (按 Step 2 assigned 训练日) + 三标签 filter + 匹配 list + 已选 list
2. 教练能 per-day 独立筛选 + add/delete accessory exercises, 写入 SwiftData draft (`DraftPlanExercise.is_main_lift = false`, `sort_order` 按 add 顺序自增)
3. 中途退出 / app 杀掉 / 切回再开, Editor 自动恢复到 Step 4 + 当前 day + 已选 accessories (复用 spec 005 `DraftStore` 持久化, 无 schema 改动)
4. Step 4 完成 → 末尾占位 CTA "完成辅助动作 — 下一步 (TODO spec 007)" (复用 spec 005 末尾 placeholder pattern)
5. UI 不接真 backend; 通过 `PlanRepository.fetchAccessoryExercises(filters:)` mock 喂 ~30-40 fixture accessory exercises (覆盖三 facets 各类组合)
6. 后续 spec 007 (Step 5 W1 强度) 接力填 per-set 数据

> **2026-04-28 v4.4 pivot 影响声明**: 本 spec 实装的 Step 4 与 v4.4 重写的 §7b/7c/7d (周卡片横滑 / cycle 历史 / 网页端宏观) **无 overlap**, 自然合规。 但禁止引入 F-015 标记的旧宏观/分析字段与组件 (与 spec 004 / spec 005 同红线; 详见验收 §F-015 红线 grep)。

## 范围

### 做什么

#### 1. 5 个新 SwiftUI view (`Modules/CoachKit/Sources/CoachKit/Planning/Views/`)

| 文件 | 作用 |
|---|---|
| `Step4SelectAccessoriesView.swift` | root for Step 4, 容纳 chip bar + scroll content |
| `DayChipBar.swift` | 顶部 horizontal scroll chips, Step 2 assigned days (e.g. 周一/周三/周五), currentDay highlighted |
| `AccessoryFilterSection.swift` | 3 行 horizontal-scroll multi-select chips (肌群 / 器械 / 模式), 每行带 "全部" 重置 chip |
| `AccessoryMatchListSection.swift` | "匹配 N 个" header + LazyVStack of cells, 点击 add |
| `SelectedAccessoryListSection.swift` | "已选 M 个" header + LazyVStack with [删除] 按钮 + swipe-to-delete |

文件内允许 file-private nested `struct` view helper (e.g. `AccessoryChip` / `AccessoryRow` / `SelectedAccessoryRow`), 与 spec 005 nested helper pattern 一致 (AGENTS.md "一个 type 一个文件" 显式允许 file-scoped private view helpers)。

#### 2. State (`Modules/CoachKit/Sources/CoachKit/Planning/State/`)

| 文件 | 作用 |
|---|---|
| `AccessoryFilters.swift` (新) | value struct: `muscleGroups: Set<MuscleGroup>` / `equipment: Set<Equipment>` / `movementPatterns: Set<MovementPattern>` + `static let empty` + `var isEmpty: Bool`; 类型 `Sendable`, `Equatable`, `Hashable` |
| `PlanningStep.swift` (改) | 加 case `.selectAccessories` (Codable raw value 与现有 case 同 snake_case 模式) |
| `PlanningViewModel.swift` (改) | 加 4 字段 + 5 方法 (详见 §技术要求 §PlanningViewModel 扩展 sketch) |

#### 3. Repository (`Modules/CoachKit/Sources/CoachKit/Planning/Repository/`)

| 文件 | 作用 |
|---|---|
| `PlanRepository.swift` (改) | protocol 加 `fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise]` |
| `InMemoryPlanRepository.swift` (改) | 加 ~30-40 accessory exercise fixtures (详见 Notes 给 Codex 的 fixture 指引) + `fetchAccessoryExercises` 实装 (Set isDisjoint 写法, 详见 §技术要求) |
| `BackendPlanRepository.swift` (改) | 加 `fetchAccessoryExercises` stub (`fatalError("TODO: spec NNN backend wiring")` 或 return [] 与现有占位风格一致) |

#### 4. Draft 持久化 (复用 spec 005, 无 schema 改动)

`DraftPlanExercise` (spec 005 已落地) 的 `is_main_lift = false` 写入 accessory 行。 `sort_order` 按 add 顺序自增 (per-day 独立, 起始值 = 该 day 现有 max(sort_order) + 1, 没 main lift 也 OK 从 0 起)。 不需要新 SwiftData migration, draft container 现有 schema 兼容。

#### 5. Coordinator wiring

`PlanningCoordinatorView.swift` (spec 005 已有) `navigationDestination(for:)` 加 case `.selectAccessories: Step4SelectAccessoriesView(viewModel: viewModel)`。 Step 3 末 CTA action 改为 push `.selectAccessories` (现 PR #25 main 上 button label 已是用户面文案, action 见实装即可)。

#### 6. 测试 (`Modules/CoachKit/Tests/CoachKitTests/Planning/`)

Swift Testing (`@Test` / `#expect`) + ViewInspector:

| 文件 | 覆盖 (测试数) |
|---|---|
| `Step4ViewModelTests.swift` (新) | 6 测试: `switchToDay` 切换 + filter 加载 / `updateFilters` 触发重新 fetch / `addAccessory` 写入 draft + sort_order 自增 / `deleteAccessory` 移除 + selected list 更新 / per-day 独立 (周一 filter 不影响周三, 已选互不污染) / `proceedToStep5` 校验 (允许全空 day, 教练可跳过 accessory) |
| `InMemoryAccessoryRepositoryTests.swift` (新) | 4 测试: empty filter → 返回所有 accessory exercises (排除 main_lift / main_lift_variation) / 单 facet 单值 / 单 facet 多值 OR / 跨 facet AND + 无匹配返回 [] |
| `AccessoryFiltersTests.swift` (新) | 3 测试: `empty` static / `isEmpty` 判定 (空 vs 任一非空) / `Equatable` + `Hashable` round-trip |
| `Step4FlowSnapshotTests.swift` (新) | 5 ViewInspector 测试: `DayChipBar` render N chips + currentDay 高亮 / `AccessoryFilterSection` 3 行 + 全部 chip / `AccessoryMatchListSection` tap 触发 `viewModel.addAccessory` / `SelectedAccessoryListSection` delete swipe + button / 整屏 layout (chip + filter + match + selected 全可见) |
| `PlanningViewModelTests.swift` (改, spec 005 已有) | 加 1 测试: `.selectAccessories` PlanningStep Codable round-trip |

总 ≥ 19 测试 (与 spec 005 floor 18 同 depth + 1)。

### 不做什么

- ❌ **重排 sort_order** (drag-to-reorder per-day) — V1 按 add 顺序, 删除+重加变序; 加 FOLLOWUP "Step 4 accessory drag-to-reorder"
- ❌ **swap exercise** (▼ dropdown 替换不删除) — V1 删除+重加; 加 FOLLOWUP "Step 4 accessory swap via dropdown"
- ❌ **per-exercise notes 输入** — defer 到 spec 007 W1 强度 或独立 spec
- ❌ **per-set 定义** (sets/reps/intensity) — Step 5 = spec 007
- ❌ **search input** — facets only V1; 加 FOLLOWUP "Step 4 accessory search input" 如 usability test 显示需要
- ❌ **backend `GET /exercises` 真接入** — 留独立 spec (与 spec 005 同 pattern, BackendPlanRepository 仍占位)
- ❌ **自定义 accessory** (coach 加自己的动作) — backend `POST /exercises` 已 ship, 但 iOS UI defer 独立 spec
- ❌ **真 simulator E2E 录屏** — spec 005 已验证 NavigationStack + chip + scroll pattern, 本 spec 用 ViewInspector 单元 + 手验
- ❌ **Step 5 真接入** — 留 spec 007, 本 spec 末 CTA 占位 (button action body 空 + log warn)
- ❌ 任何 F-015 标记的旧宏观/分析概念
- ❌ spec 005 既有架构 / spec 004 CoreModels schema 改动 — 本 spec 只增量

## 技术要求

继承 spec 005 模式 (per ADR-005 §3 MVVM + Repository, ADR-009 SwiftData 例外):

- 一个 type 一个文件:
  - **6 新源文件**: 5 view (Step4SelectAccessoriesView / DayChipBar / AccessoryFilterSection / AccessoryMatchListSection / SelectedAccessoryListSection) + 1 state struct (AccessoryFilters)
  - **4 新测试文件**: Step4ViewModelTests / InMemoryAccessoryRepositoryTests / AccessoryFiltersTests / Step4FlowSnapshotTests
  - **8 现有文件改**: PlanningStep (加 case) / PlanningViewModel (加 字段+方法) / PlanRepository (加 method) / InMemoryPlanRepository (加 fixture+impl) / BackendPlanRepository (加 stub) / PlanningCoordinatorView (加 navigationDestination case) / Step3SelectMainLiftsView (末 CTA action 换 push target) / PlanningViewModelTests (加 1 个 .selectAccessories Codable 测试)
- 严格并发 (StrictConcurrency upcoming feature 已配, spec 005 设过)
- 测试用 Swift Testing (非 XCTest), ViewInspector for SwiftUI traversal (spec 005 Package.swift 已 add ≥ 0.10.0 dep)
- DesignSystem atom 优先复用 (Card / Eyebrow / PrimaryButton / 任何已有 chip / pill / badge); 没合适 chip 在 file-private 内实装 `AccessoryChip` (类似 spec 005 nested private struct view helpers, AGENTS.md 显式允许)
- import 边界 (per ADR-005 §3):
  - Views/ allowed: `SwiftUI` / `CoreModels` / `DesignSystem` / 内部 sibling
  - State/ allowed: `Foundation` / `CoreModels` / `Observation`
  - Repository/ allowed: `Foundation` / `CoreModels`
  - **禁止**: 引 `Networking` (本 spec 不接真 backend); 引 `StudentKit` (CoachKit ⊥ StudentKit invariant); `AppShell` 不引 `SwiftData` (per ADR-009 例外只给 CoachKit/Planning/)

### Filter 应用规则 (与 backend GET /exercises 合同一致)

```
empty filter → return all visible accessory exercises (exercise_type == .accessory)
non-empty filter →
  for each facet (muscleGroups, equipment, movementPatterns):
    if facet 集合 is empty → skip 该 facet (不约束)
    else → exercise.<facet> ∩ filter.<facet> != ∅ (OR within facet)
  exercise 通过 = exercise_type == .accessory AND 所有非空 facet 全部命中 (AND across facets)
```

InMemoryRepository Swift 实装 sketch:

```swift
public func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise] {
    return seedAccessoryExercises.filter { exercise in
        guard exercise.exerciseType == .accessory else { return false }
        if !filters.muscleGroups.isEmpty,
           Set(exercise.muscleGroups).isDisjoint(with: filters.muscleGroups) {
            return false
        }
        if !filters.equipment.isEmpty,
           Set(exercise.equipment).isDisjoint(with: filters.equipment) {
            return false
        }
        if !filters.movementPattern.isEmpty,
           Set(exercise.movementPattern).isDisjoint(with: filters.movementPatterns) {
            return false
        }
        return true
    }
}
```

(注: spec 004 的 `Exercise.movementPattern` 字段名是单数还是复数, Codex 实装时按 spec 004 实际签名为准; data-model.md §1.4 写的是 `movement_pattern: enum[]` 复数语义。)

### PlanningViewModel 扩展 sketch

新增字段 (类内 `@Observable @MainActor` 现有 class):

```swift
public var currentDayID: UUID?                                   // chip bar 选中 day; nil = 默认 first day
public var accessoryFiltersByDay: [UUID: AccessoryFilters] = [:] // per-day 独立 filter state
public var availableAccessoriesCache: [UUID: [Exercise]] = [:]   // per-day fetch 结果 cache (filter 变就 invalidate 重 fetch)
public var isLoadingAccessories: Bool = false                    // fetch 中状态, view 显示 spinner
```

新增方法:

```swift
public func switchToDay(_ dayID: UUID) async        // chip 点击 → set currentDayID + 触发 reload (用 cache 或 fetch)
public func updateFilters(_ filters: AccessoryFilters, for dayID: UUID) async  // chip 选变 → 写入 accessoryFiltersByDay + 触发 fetch
public func addAccessory(_ exercise: Exercise, to dayID: UUID) async throws    // 点击 match list cell → 写 DraftPlanExercise(is_main_lift: false, sort_order: next)
public func deleteAccessory(_ draftExerciseID: UUID, from dayID: UUID) async throws  // 点删除 / swipe → 移除 draft + 调整 sort_order (V1 不重排, 留 gap)
public func proceedToStep5() async throws            // CTA 点击 → V1 校验允许全空 day → 推进 step (本 spec V1 不真推进, log placeholder; spec 007 替换)
```

### Per-day filter state 独立性

`accessoryFiltersByDay` 字典不预初始化, 每 day 第一次访问时按 `.empty` 处理 (没条目 = 空 filter)。 `switchToDay` 不重置 filter, 切换回时仍保留之前 filter 状态。 这给教练每天编排时灵活配置不同 facet focus 的能力 (e.g. 周一 push focus, 周三 pull focus)。

### Day chip bar 数据源

`viewModel.draftPlan.days` (Step 2 assigned 训练日, e.g. 周一/三/五) — 按 `dayOfWeek` raw value 排序 (Mon=1...Sun=7), chip label 显示中文 ("周一" 或简短 "一", 视空间 — 推荐"周一"完整, 与 wireframe 一致)。 chip 点击 → `viewModel.switchToDay(day.id)`. `currentDayID` 默认 = `viewModel.draftPlan.days.first?.id`.

### Step 4 → Step 5 占位 CTA

末尾 `PrimaryButton("完成辅助动作 — 下一步 (TODO spec 007)") { Task { try? await viewModel.proceedToStep5() } }`; `proceedToStep5` 内部 V1 实装 = log warn `step5_pending` (Session.bootstrap 用 print warn 是 spec 011 review/011-pr27 P3 #3 已开 FOLLOWUP, logger spec 落地后统一改) + 不真推进 step。 spec 007 实装时替换 method body 为真校验 + 推进 `.selectIntensity` (或 spec 007 命名的下一 case)。 复用 spec 005 末尾 `Step3SelectMainLiftsView` 的 placeholder pattern。

### F-015 awareness

spec 004 引入 facet enum (MuscleGroup / Equipment / MovementPattern) 已就位 (PR #21 merged); 本 spec 只做 UI 消费, 不改 CoreModels schema, 不与 v4.4 §7b/7c/7d (周卡片 / cycle 历史 / 网页端宏观) overlap, 自然合规。 但实装 + spec 全文必须 grep 验证不出现红线词 (见验收清单)。

## 验收标准

- [ ] Planning/Views/ 新增 5 文件: `Step4SelectAccessoriesView.swift` / `DayChipBar.swift` / `AccessoryFilterSection.swift` / `AccessoryMatchListSection.swift` / `SelectedAccessoryListSection.swift` (各 1 顶层 type per file, file-private nested view helper 允许)
- [ ] Planning/State/ 新增 1 文件: `AccessoryFilters.swift` (Sendable, Equatable, Hashable, `static let empty`, `var isEmpty: Bool`)
- [ ] Planning/State/PlanningStep.swift 改: 加 `.selectAccessories` case + Codable raw value
- [ ] Planning/State/PlanningViewModel.swift 改: 加 4 字段 (currentDayID, accessoryFiltersByDay, availableAccessoriesCache, isLoadingAccessories) + 5 方法 (switchToDay, updateFilters, addAccessory, deleteAccessory, proceedToStep5)
- [ ] Planning/Repository/PlanRepository.swift 改: protocol 加 `fetchAccessoryExercises(filters:) async throws -> [Exercise]`
- [ ] Planning/Repository/InMemoryPlanRepository.swift 改: 加 ~30-40 accessory exercise fixtures (覆盖 4+ 肌群 × 4 器械 × 推/拉 各类组合, 详见 Notes 给 Codex 的 fixture 指引) + `fetchAccessoryExercises` 实装 (Set isDisjoint)
- [ ] Planning/Repository/BackendPlanRepository.swift 改: 加 `fetchAccessoryExercises` stub (与现有占位风格一致)
- [ ] **顺手收尾 spec 005 PR #26 P3 #10 半 b**: 同时给 BackendPlanRepository 补全 `: PlanRepository` conformance (若之前未声明) + 之前未实装的 PlanRepository 方法补 fatalError stub (与上面 `fetchAccessoryExercises` 占位同风格); 编译器会在加新方法时逼出来, 顺手做掉省独立 PR. 详见 [PR #32 bundle 决策](https://github.com/tianpingdeng112233-cell/meetpr/pull/32)
- [ ] Planning/Views/PlanningCoordinatorView.swift 改: `navigationDestination(for:)` 加 `.selectAccessories` 路由
- [ ] Planning/Views/Step3SelectMainLiftsView.swift 改: 末 CTA action 改为 push `.selectAccessories` (button label 不动, 已是用户面文案)
- [ ] DraftPlanExercise reuse (无 SwiftData migration, 无 schema 改动); accessory 写入 `is_main_lift = false`, `sort_order` per-day 自增
- [ ] swift build 在 Modules/CoachKit 单独跑过, 0 warning 0 error, Swift 6 strict concurrency
- [ ] swift test 通过, 测试 ≥ 19 (6 ViewModel + 4 InMemory Accessory Repo + 3 AccessoryFilters + 5 ViewInspector + 1 PlanningStep 增)
- [ ] iPhone 17 simulator happy path 6 步:
  1. spec 005 完整流程跑到 Step 3 完 → 点 CTA push 进 Step 4
  2. 看到 DayChipBar 显示 Step 2 assigned days (e.g. 周一/周三/周五 chips), currentDay = 周一 高亮
  3. 看到 3 行 facet (全部 chip 高亮, 无具体 facet 选中), match list 显示所有 accessory fixtures (~30-40), 已选 list 空
  4. 选 "肌群: 股四" + "器械: 杠铃" → match list 缩到匹配项 (e.g. 杠铃前蹲举 / 杠铃箭步蹲) → tap 1 个 add → 已选 list 显示 1 项
  5. 切到下一天 chip (周三) → filter 重置为空 (该 day 第一次访问) → match list 显示全部 → tap 1 个不同的 add
  6. 切回周一 chip → filter 状态保留 (股四 + 杠铃 仍勾) → 已选保留 (周一的 1 项) → 点 [删除] 移除 1 个
- [ ] xcodebuild build -scheme MeetPR 通过 (整 app 编译, 不破坏 spec 005 + spec 011 已有 wire)
- [ ] swiftlint + swift-format 全绿
- [ ] CI 在 `feat/006-coach-planning-step-4-accessories` 分支跑过, 全绿
- [ ] **F-015 v4.4 红线 grep**: 用 FOLLOWUPS.md F-015 的 token list 扫 spec 全文 + 实装代码, 返回空
- [ ] FOLLOWUPS.md 加 3 条候选 (主动加, 教练 dogfood 后据 usability 决定何时触发):
  - "F-018 候选 — Step 4 accessory drag-to-reorder" (sort_order 手动重排; V1 按 add 顺序自增)
  - "F-019 候选 — Step 4 accessory swap via dropdown" (▼ 替换不删除; V1 删除+重加)
  - "F-020 候选 — Step 4 accessory search input" (free-text 搜索; V1 facets only)
- [ ] PR description 引用 SPEC.md + 填验收 checklist + 录可选 simulator 短截屏 (chip 切天 + filter + add/delete)

## 参考

- backend [spec 002-coach-planning-crud GET /exercises](../../../MeetPR-backend/specs/002-coach-planning-crud/SPEC.md) §Exercise catalog — facet csv contract (OR within facet, AND across facets); 本 spec InMemoryRepository 复刻同语义
- [coach-planning.md v4.4 §Step 4 v4.2 三标签并行筛选](~/Brain/wiki/projects/MeetPR/coach-planning.md)
- [data-model.md v1.1 §1.4 Exercise 三标签 facets](~/Brain/wiki/projects/MeetPR/data-model.md)
- [spec 004 CoreModels training plan](../004-core-models-training-plan/SPEC.md) — Exercise / MuscleGroup / Equipment / MovementPattern enum
- [spec 005 Coach Planning UI Step 0-3](../005-coach-planning-step-0-3/SPEC.md) — PlanningCoordinatorView / PlanningStep / DraftPlanExercise / PlanRepository / DraftStore (本 spec 全部接力)
- [ADR-005 §3 MVVM + Repository](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
- [ADR-009 SwiftData 例外](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md)

## Notes (给 Codex)

- 本 spec 接力 spec 005 (PR #25 已 merge), 大部分 hooks (DraftStore / PlanningCoordinatorView / DraftPlanExercise / PlanRepository / DraftMapping) 已就位; 你只是填 Step 4 内容 + 扩展 4 个现有文件 (PlanningStep / PlanningViewModel / PlanRepository / InMemoryPlanRepository / BackendPlanRepository / PlanningCoordinatorView / Step3SelectMainLiftsView)
- DesignSystem 没有现成 Chip atom (验你看 Modules/DesignSystem/Sources/DesignSystem/), 你可以在 `Modules/CoachKit/Sources/CoachKit/Planning/Views/` 里实装 file-private `AccessoryChip` (类似 spec 005 实装的 file-scoped private view helpers, AGENTS.md "一个 type 一个文件" 显式允许 nested private struct view helpers)。 chip 视觉: 圆角 capsule + selected 态 fillColor + tap action; 与 wireframe `[全部] [股四]` 风格一致
- `accessoryFiltersByDay` 的 key 用 `DraftPlanDay.id` (UUID), 不用 `dayOfWeek` raw value (避免重复 day 冲突, 虽然 V1 不支持但保险)
- accessory fixtures 需要 multi-facet 覆盖, 参考清单 (按 muscle_group 主分类, 每个动作含真实 muscle_groups + equipment + movement_pattern):
  - **股四 quad** (6): 哈克深蹲 (quad / machine / push), 杠铃前蹲举 (quad+core / barbell / push), 杠铃箭步蹲 (quad+glute / barbell / push), 倒蹬 (quad / machine / push), 腿屈伸 (quad / machine / push), 高脚杯深蹲 (quad / dumbbell / push)
  - **臀 glute** (4): 臀冲 (glute / barbell / push), 罗马尼亚硬拉 (glute+hamstring / barbell / pull), 单腿臀冲 (glute / bodyweight / push), 反向髋伸 (glute+hamstring / machine / pull)
  - **腘绳 hamstring** (3): 北欧腘绳 (hamstring / bodyweight / pull), 腿弯举 (hamstring / machine / pull), 罗马硬拉 dumbbell 版 (hamstring+glute / dumbbell / pull)
  - **胸 chest** (5): 上斜哑铃推 (chest / dumbbell / push), 平板哑铃推 (chest / dumbbell / push), 双杠臂屈伸 (chest+triceps / bodyweight / push), 龙门夹胸 (chest / machine / push), 俯卧撑 (chest / bodyweight / push)
  - **背 back** (4): 引体向上 (back+biceps / bodyweight / pull), 划船 (back / barbell / pull), 高位下拉 (back / machine / pull), 单臂哑铃划船 (back / dumbbell / pull)
  - **肩 shoulder** (3): 哑铃肩推 (shoulder / dumbbell / push), 侧平举 (shoulder / dumbbell / push), 面拉 (shoulder+back / machine / pull)
  - **二头 biceps** (2): 杠铃弯举 (biceps / barbell / pull), 哑铃弯举 (biceps / dumbbell / pull)
  - **三头 triceps** (3): 三头绳索下压 (triceps / machine / push), 仰卧臂屈伸 (triceps / barbell / push), 窄距俯卧撑 (triceps / bodyweight / push)
  - **核心 core** (4): 平板支撑 (core / bodyweight / push), 卷腹 (core / bodyweight / pull), 转体 (core / dumbbell / pull), 农夫行走 (core+back / dumbbell / pull)
  - 总 ~34 个 accessory; `exercise_type = .accessory`; `main_lift_family = nil`; `is_competition_lift = false`; `created_by_coach_id = nil` (系统种子); `id` 用 deterministic UUID (e.g. spec 005 fixture pattern `uuid(200 + offset)`) 方便测试
- 不要碰 spec 005 已有 view 内部实装 (Step3SelectMainLiftsView 只改末尾 CTA 的 navigation target — 现 action 是 placeholder, 改为 push `.selectAccessories`; button label 已被 PR #25 P3 cleanup 修干净, 不动)
- Step 4 → Step 5 CTA 的 button label "完成辅助动作 — 下一步 (TODO spec 007)" 是用户 visible 的, 跟 spec 005 末尾 CTA 同 placeholder pattern; spec 007 实装时换 label
- F-015 红线 grep 命令 (实装完跑一遍): 从 FOLLOWUPS.md F-015 复制 token list, 对 `Modules/CoachKit/Sources/CoachKit/Planning/` 和本 spec 目录执行扫描 — 期望返回空
- 任何疑问写 `specs/006-coach-planning-step-4-accessories/QUESTIONS.md`
- 完成后**别 self-merge** — Claude review 后才 merge (与 spec 005 / spec 011 同 pattern)
