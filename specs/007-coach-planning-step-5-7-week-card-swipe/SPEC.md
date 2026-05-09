# 007 — Coach Planning UI Step 5-7 (W1 强度填写 / 规则配置 / 周卡片横滑预览)

- **状态**: Done
- **PR**: (待填)
- **来源**:
  - [coach-planning.md v4.4 §Step 5 / §Step 6 / §Step 7a / §Step 7b](~/Brain/wiki/projects/MeetPR/coach-planning.md) — wireframe ground truth (2026-04-28 pivot 后)
  - [data-model.md v1.1 §1.8 (PlanSet) + §1.9 (ProgressionRuleGroup / ProgressionRuleAssignment / ExerciseWeekOverride)](~/Brain/wiki/projects/MeetPR/data-model.md)
  - [meetings/2026-04-28 office hours iPhone macro pivot](~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md) — pivot 决策原委 + 7 议题处置
  - [prd.md §4 场景 1 + §5 P0 教练端 #4](~/Brain/wiki/projects/MeetPR/prd.md) — v4.4 周卡片横滑叙事已 sync
  - 上游 [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) — `User` / `StudentProfile` / 相关 enum
  - 上游 [spec 003 DesignSystem foundation](../003-design-system-foundation/SPEC.md) — 14 atomic 组件 + token (NumericInput / SegmentedControl / Card / Eyebrow / PrimaryButton / Badge / Label)
  - 上游 [spec 004 CoreModels training plan](../004-core-models-training-plan/SPEC.md) — `Exercise` / `PlanSet` / `IntensityMode` / `SetType` / `LiftFamily`
  - 上游 [spec 005 Coach Planning UI Step 0-3](../005-coach-planning-step-0-3/SPEC.md) — `PlanningCoordinatorView` / `PlanningStep` / `PlanningViewModel` / `DraftStore` / `DraftTrainingPlan` / `DraftPlanDay` / `DraftPlanExercise` / `DraftMapping` / `PlanRepository` (本 spec 全部接力 + 增量扩展, 不重写)
  - 上游 [spec 006 Coach Planning UI Step 4 添加辅助动作](../006-coach-planning-step-4-accessories/SPEC.md) — facet 模式 / per-day independence / `AccessoryFilters` / `accessoryFiltersByDay` (本 spec 复用相同的 per-exercise + per-day pattern)
  - [ADR-005 §1 (CoachKit 模块边界) + §3 (MVVM + Repository)](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
  - [ADR-009 SwiftData 例外](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) — 本 spec 仅在已有 3 个 `@Model` class 上**加 optional 字段**, **不引入** 新 `@Model` class (无需扩张 ADR-009 例外范围)
  - [F-015 — 任何 coach planning spec 必须按 v4.4](../../FOLLOWUPS.md)

## 目标

接力 spec 005 / spec 006 (Step 0-4 完毕, draft 已含 days + main lift variants + accessories), 实装教练编排器后 3 步:

1. **Step 5** — Week 1 各组强度填写 (per-exercise 组数 × 次数 × 强度, 强度模式 = 重量 / RPE; 重量模式内置 kg / %1RM 切换). W1 是教练手动写完整的基线, 必填.
2. **Step 6** — 9 类递进 / 递减规则 + 应用动作 (多对多) + 应用周 (W2-W4 任意子集). 未被任何规则覆盖的 (动作, 周) 默认 "同上周".
3. **Step 7** — 周卡片横滑预览 (`TabView(.page(indexDisplayMode: .never))`, W1 ↔ W2 ↔ W3 ↔ W4 swipe; 1 周模式仅 1 张 Week 1/1 卡). 每张卡片 = 该周完整训练计划摘要 (按训练日 group, per-exercise 行显示组数 × 次数 + 强度). W2-W4 行的值由 W1 + 规则 derive (pure 函数, 不持久化).

落地后:

1. 教练完成 spec 006 Step 4 后 → 自然 push 进 Step 5 → Step 6 → Step 7, 形成完整 4 周 (或 1 周) draft 计划
2. SwiftData draft 持久化复用 spec 005 已有 schema, **仅在 `DraftPlanExercise` / `DraftTrainingPlan` 上各加 1 个 optional 字段** (`setsData: Data?` / `progressionRulesData: Data?`), 通过 SwiftData lightweight 自动迁移生效, **无需** 手写 `VersionedSchema` + `MigrationStage`
3. 中途退出 / app 杀掉 / 切回再开 → Editor 自动恢复到上次 step + 已填字段 (W1 强度 / 规则 / 当前预览周 index)
4. Step 7 末尾占位 CTA "进入发布 (TODO spec 008)" — 复用 spec 005 / spec 006 末尾 placeholder pattern
5. UI 不接真 backend; `PlanRepository.publishPlan(_:)` 沿用 spec 005 留的 TODO 占位 (本 spec 不动 `BackendPlanRepository`)
6. 后续 spec 008+ 接 Step 8 发布 / Step 9 模板保存; spec 010 接 Step 7c 学员历史 cycle 列表

> **2026-04-28 v4.4 pivot 影响声明**: 本 spec 实装的 **Step 7 = iPhone 周卡片横滑** (`TabView(.page)`), 严格遵守 v4.4 红线. 显式**不实装** v4.3 已废弃的 4 周扫视态 / 波形图 / 变式矩阵 / 密度条, **不实装** v4.2 已废弃的 4 周 Excel grid 编辑 (这两个去网页端 [PD-007], V1.x defer, hard gate Stage 4 Week 22-24). 本 spec **不引用** v4.3 / v4.2 — 见 [F-015](../../FOLLOWUPS.md). 详见 §不做什么 + 验收清单 §F-015 红线 grep.

## 范围

### 做什么

#### 1. 8 个新 SwiftUI view (`Modules/CoachKit/Sources/CoachKit/Planning/Views/`)

| 文件 | 作用 | wireframe 源 |
|---|---|---|
| `Step5SetIntensityView.swift` | root for Step 5; ScrollView + 顶部 Eyebrow "Week 1 必填(基线)" + per-day section + 每动作 1 张 `ExerciseSetEditorCard` (主项 + 辅助项混排, 主项加 `(主项)` Badge) | coach-planning §Step 5 |
| `ExerciseSetEditorCard.swift` | per-exercise card: `IntensityModeToggle` + 组数 / 次数 `NumericInput` + 强度输入 (`WeightInputField` 或 RPE `NumericInput`); 通过 `viewModel.updateW1SetSpec(_:for:)` 写入 | coach-planning §Step 5 |
| `IntensityModeToggle.swift` | segmented control [重量 / RPE], 切换 `IntensityMode`; 切换时保留另一边的最近输入值 (UI memo, 不写 draft) | coach-planning §Step 5 |
| `WeightInputField.swift` | 内置 [kg / %1RM] segmented + `NumericInput`; %1RM 模式下实时换算到 kg 显示, 但 **存储统一 kg** (per spec 004 §PlanSet 约束); %1RM 仅当学员 `StudentProfile.<lift>OneRM` 该 lift family 有值时可用 (无值 → toggle 锁定 kg + 提示) | coach-planning §Step 5 + spec 004 §PlanSet 约束 |
| `Step6ProgressionRulesView.swift` | root for Step 6; ScrollView + "规则 N" 列表 (`ProgressionRuleEditorCard`) + "+ 添加规则" `PrimaryButton` + 底部 "未被任何规则覆盖" 信息行 (动态计算) | coach-planning §Step 6 |
| `ProgressionRuleEditorCard.swift` | per-rule card: 规则类型 Picker (9 cases + custom) + 增减量 `NumericInput` (custom 模式时变成"每周数值"序列) + 应用动作 multi-select chips (列出 draft 内全部 main lift + accessory) + 应用周 4 个 toggle chip (W1 锁定 disabled, W2/W3/W4 可勾) + [删除规则] | coach-planning §Step 6 + §Step 7a |
| `Step7WeekCardSwipeView.swift` | root for Step 7; `TabView(selection:)` + `.tabViewStyle(.page(indexDisplayMode: .never))` 包 N 张 `WeekCardView` (N = `draftPlan.planWeeks` ∈ {1, 4}); 顶部学员浮层 + 卡片标题 "Week N / N"; 底部 `PrimaryButton("进入发布 (TODO spec 008)")` | coach-planning §Step 7b |
| `WeekCardView.swift` | 单张周卡片: ScrollView + per-day Section + per-exercise row (动作名 + "组数 × 次数" + 强度); W1 直接读 draft, W2-W4 调 `WeekDerivation.deriveSetSpec(forWeek:exerciseID:w1:rules:)` 派生; 每行支持 `.contextMenu(menuItems:preview:)` 长按 Peek (V1 显示动作名 + 强度详情 + 备注; PR / e1RM 写 "TODO spec NNN backend wiring") | coach-planning §Step 7b "iPhone 原生增强交互(V1)" |

> **不新建** root coordinator — 复用 spec 005 `PlanningCoordinatorView`, 仅 `navigationDestination(for:)` 加 3 个 case (见 §5 Coordinator wiring).

#### 2. State (`Modules/CoachKit/Sources/CoachKit/Planning/State/`)

| 文件 | 作用 |
|---|---|
| `DraftSetSpec.swift` (新) | value struct: `id: UUID` / `setCount: Int` / `targetReps: Int` / `targetRepsMax: Int?` / `intensityMode: IntensityMode` / `targetValue: Decimal` / `setType: SetType (default .working)` / `notes: String?`. `Codable, Hashable, Sendable`. **V1 范围**: 1 个 SetSpec / exercise (uniform working sets — 全部组同 reps 同强度); per-set 变化 (warmup / amrap / backoff) = V1.5 follow-up. 发布时 (spec 008) expand 为 N 个 `CoreModels.PlanSet` (set_number 1..N 顺序赋值). |
| `DraftProgressionRule.swift` (新) | value struct: `id: UUID` / `ruleType: ProgressionRuleType` / `incrementValue: Decimal?` (非 custom) / `customSequence: [Decimal]?` (custom only, 长度 = `appliedWeeks.count`) / `customDimension: ProgressionRuleDimension?` (custom 时非 nil, 否则 nil) / `exerciseIDs: Set<UUID>` (可应用主项 + 辅助项, FK → `DraftPlanExercise.id` 而**非** `Exercise.id`, 因为同一 catalog Exercise 在不同 day 是不同的 draft 行) / `appliedWeeks: Set<Int>` (W1 = 基线**不**入此 set, 实际取值 ⊆ {2, 3, 4}) / `displayOrder: Int` (规则在 UI 中的展示顺序, 也用于"后写入优先"冲突仲裁). `Codable, Hashable, Sendable`. |
| `ProgressionRuleDimension.swift` (新) | enum, 4 cases: `.weight` / `.rpe` / `.sets` / `.reps`. custom rule 的单维度选择; `String, Codable, CaseIterable, Hashable, Sendable`. |
| `ProgressionRuleType.swift` (新) | enum, 10 cases: `.weightInc` / `.weightDec` / `.rpeInc` / `.rpeDec` / `.setsInc` / `.setsDec` / `.repsInc` / `.repsDec` / `.custom`. (coach-planning §Step 6 表格 9 行 + custom = 10; "default 同上周" 不入 enum, 是计算 fallback). `String, Codable, CaseIterable, Hashable, Sendable`. raw value 显式 snake_case. |
| `WeekDerivation.swift` (新) | 自由函数 (内部 enum 命名空间) `public enum WeekDerivation { public static func deriveSetSpec(forWeek weekN: Int, exerciseID: UUID, w1: DraftSetSpec, rules: [DraftProgressionRule]) -> DraftSetSpec }` — pure / 100% 单测. 详见 §技术要求 §WeekDerivation 行为. **不依赖** `@Observable` / SwiftUI / SwiftData — 纯 Foundation. |
| `PlanningStep.swift` (改) | 加 3 个 case: `.fillW1Intensity = 4` / `.configureRules = 5` / `.previewWeekCards = 6`. raw value 连续, Codable round-trip 测试覆盖全 7 case. |
| `PlanningViewModel.swift` (改) | 加 8 字段 + 8 方法 (详见 §技术要求 §PlanningViewModel 扩展 sketch). |

#### 3. Draft 持久化 (复用 spec 005 已有 3 个 `@Model` class, **不引入新 `@Model`**)

| 文件 | 改动 |
|---|---|
| `DraftPlanExercise.swift` (改) | 加 1 个 optional stored property: `public var setsData: Data? = nil` (encode 后的 `DraftSetSpec` JSON; nil = 教练尚未在 Step 5 填该动作). |
| `DraftTrainingPlan.swift` (改) | 加 1 个 optional stored property: `public var progressionRulesData: Data? = nil` (encode 后的 `[DraftProgressionRule]` JSON; nil = 尚未配规则; 空数组 `[]` = 配过但全部删除, 与 nil 等价行为). |
| `DraftMapping.swift` (扩) | 加 helper: `encodeSetSpec(_:) -> Data` / `decodeSetSpec(_:) -> DraftSetSpec?` / `encodeRules(_:) -> Data` / `decodeRules(_:) -> [DraftProgressionRule]`. `toDomain(_:)` 扩展: 在生成 `[PlanSet]` 时, 对每个 `DraftPlanExercise` 调 `decodeSetSpec` 取 SetSpec, 然后 expand 成 `setCount` 个 `CoreModels.PlanSet` (`setNumber` 1..N, 其他字段从 SetSpec 复制). 当 `setsData == nil` 时 → 该 exercise 产 0 个 PlanSet (publish layer 校验时 reject; 本 spec 不持久化校验, 留 spec 008). |

> **SwiftData 迁移说明**: `setsData: Data?` 和 `progressionRulesData: Data?` 是新增的 optional 字段, default = nil. SwiftData lightweight 自动迁移直接处理 (旧 draft 容器打开时这两字段读为 nil, 不破坏现有 row). **不需要** `VersionedSchema` + `MigrationStage` 显式代码. ADR-009 §"⚠️ 需警惕" 提到的 "改 `DraftTrainingPlan` 字段需要 `VersionedSchema` + `MigrationStage`" 适用于**字段类型变更 / 删除 / 重命名 / 非 optional 加入需 backfill** 等情形, 本 spec 是 **additive optional**, 属 SwiftData lightweight 范畴.

#### 4. Repository (无新增方法)

`PlanRepository` protocol / `InMemoryPlanRepository` / `BackendPlanRepository` 在本 spec 范围内**不动签名**. spec 005 留下的 `publishPlan(plan:days:exercises:)` 仍是 TODO 占位 (`InMemoryPlanRepository` append 到内存数组 + `BackendPlanRepository` 空 struct). 真发布 (含 W1 PlanSet expand + 规则序列化) = spec 008.

> 本 spec 末尾占位 CTA "进入发布 (TODO spec 008)" 内部行为 V1 = log warn `step8_pending` (复用 spec 006 末 `proceedToStep5` 同 placeholder pattern), **不**调 `publishPlan`.

#### 5. Coordinator wiring

`PlanningCoordinatorView.swift` (spec 005 已有) `navigationDestination(for:)` 加 3 case:
```
case .fillW1Intensity:    Step5SetIntensityView(viewModel: viewModel)
case .configureRules:     Step6ProgressionRulesView(viewModel: viewModel)
case .previewWeekCards:   Step7WeekCardSwipeView(viewModel: viewModel)
```

spec 006 留下的 `Step4SelectAccessoriesView.swift` 末 CTA `proceedToStep5()` 内部行为本 spec 替换: 改为校验 + push `.fillW1Intensity` (label "完成辅助动作 — 填写 W1 强度" 替换 spec 006 留下的 "TODO spec 007" 占位文案).

#### 6. 测试 (`Modules/CoachKit/Tests/CoachKitTests/Planning/`)

Swift Testing (`@Test` / `#expect`) + ViewInspector (spec 005 已 add ≥ 0.10.0 dep):

| 文件 | 覆盖 (测试数) |
|---|---|
| `Step5IntensityViewModelTests.swift` (新) | 7 测试: `updateW1SetSpec` 写入 draft + 持久化 round-trip / `IntensityMode` 切换保留另一边输入 / kg ↔ %1RM 换算 (含学员该 lift family 有 1RM 时和无 1RM 时 toggle 锁定行为) / RPE 边界 [1.0, 10.0] (越界 clamp + 校验 fail 信号) / `setCount` ≥ 1 校验 / `targetReps` ≥ 1 校验 / `proceedToStep6` 校验所有 main lift + accessory `setsData != nil` (主项必填; accessory 也必填, 因为 spec 006 已加进 draft, 不允许"加了但没填") |
| `Step6ProgressionRulesViewModelTests.swift` (新) | 7 测试: `addRule` 追加 + `displayOrder` 自增 / `updateRule` 按 id mutate / `deleteRule` 移除 + 重排 displayOrder / `toggleAppliedWeek` (W1 永远不可勾, W2/W3/W4 toggle) / `toggleRuleExercise` (添加 / 移除 exerciseIDs) / custom 规则的 `customSequence` 长度自动同步 `appliedWeeks.count` / `proceedToStep7` 无校验失败 (规则全空也允许; 默认行为 = 全部 W2-W4 同上周) |
| `WeekDerivationTests.swift` (新, 纯函数) | 11 测试: weight inc 单规则 W2 → W2.targetValue = W1 + Δ / weight dec / RPE inc / RPE dec (RPE 衍生 clamp [1.0, 10.0]) / sets inc / sets dec (sets 衍生 clamp ≥ 1) / reps inc / reps dec (reps 衍生 clamp ≥ 1) / custom 规则 (`appliedWeeks = {2,3,4}`, `customSequence = [a,b,c]` → W2 用 a, W3 用 b, W4 用 c) / 多规则同 exercise 不同维度 = 复合 (e.g. weight+5 + reps-1 同时生效) / 多规则同 exercise 同维度 = `displayOrder` 大者优先 / skip 周递推 (rule 应用 W2+W4 跳过 W3): W3 = W2 (default 同上周), W4 = W3 + Δ |
| `Step7WeekCardSwipeViewModelTests.swift` (新) | 4 测试: `currentPreviewWeek` 默认 = 1 / `currentPreviewWeek` 切换写 draft `lastSavedAt` (恢复用) / 1 周模式 N=1 仅 1 张卡片 / 4 周模式 N=4 共 4 张卡片 / `proceedToStep8` placeholder log (V1 不真推进) |
| `DraftSetSpecCodableTests.swift` (新) | 3 测试: round-trip kg 模式 / round-trip RPE 模式 / `targetRepsMax` nil vs 非 nil (encodeIfPresent) |
| `DraftProgressionRuleCodableTests.swift` (新) | 4 测试: 9 种 ruleType raw value 检查 / `incrementValue` Decimal-as-string round-trip / custom 规则 customSequence 数组 encode/decode / `exerciseIDs` Set 序列化为 array (Codable Set 默认行为) |
| `Step5FlowSnapshotTests.swift` (新) | 4 ViewInspector 测试: per-exercise card 渲染主项 + 辅助项各 1 / IntensityModeToggle tap 切换 / WeightInputField kg / %1RM 切换 (学员有 1RM) / WeightInputField %1RM disabled (学员无该 lift family 1RM) |
| `Step6FlowSnapshotTests.swift` (新) | 3 ViewInspector 测试: 空规则态 (列表空 + "+ 添加规则" 可见) / 单规则态 (rule card + 应用动作 chips + 应用周 chips) / "未被任何规则覆盖" 行动态显示 (W2-W4 分别列未覆盖动作) |
| `Step7FlowSnapshotTests.swift` (新) | 5 ViewInspector 测试: TabView 4 张卡片 (4 周模式) / TabView 1 张卡片 (1 周模式) / 卡片标题 "Week N / 4" 格式 / 卡片内 per-day section 渲染 / 长按 contextMenu 弹 preview (验证 menuItems + preview 都 present, 不验证视觉) |
| `DraftMappingTests.swift` (改, spec 005 已有) | 加 4 测试: `encodeSetSpec` round-trip / `decodeSetSpec` 兼容 nil 数据 / `encodeRules` 空数组 vs 非空 round-trip / `toDomain` 扩展: SetSpec setCount=4 expand 成 4 个 PlanSet (set_number 1..4) |
| `PlanningViewModelTests.swift` (改, spec 005 已有) | 加 1 测试: `.fillW1Intensity` / `.configureRules` / `.previewWeekCards` PlanningStep Codable round-trip (3 个 case 都覆盖) |

总 ≥ **49 新增/扩展测试** (7+7+11+4+3+4+4+3+5+4+1 = 53; 含部分扩展现有测试文件, 净增量约 49). 与 spec 005 (≥18) / spec 006 (≥19) 同 depth × 3 → 反映本 spec 多覆盖 3 个 step + 1 个纯函数模块.

### 不做什么

| ❌ 留 spec / 留 follow-up |
|---|
| **Step 8 发布** (推送学员 / status `published` / 真 backend POST /plans / W1 SetSpec → CoreModels.PlanSet expand) → spec 008 |
| **Step 9 保存为模板** (1 周 vs 4 周 模板沉淀差异化 / `WeekTemplate` entity / 模板归档) → spec 009 |
| **Step 7c 学员历史 cycle 列表入口** → spec 010 |
| **Step 7d 网页端 4 周宏观视图 / 跨 cycle 对比 / 多学员 dashboard / 4 周 Excel 编辑网格** — v4.3/v4.2 废弃 iPhone 方案全部走网页端 ([PD-007](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md)) V1.x defer, hard gate Stage 4 Week 22-24, **iPhone 不做** |
| **4 周宏观扫视态 / 波形图 / 变式矩阵 / 密度条 / specificityBucket / accessoryDensityBucket / isDeloadWeek / waveformValue** — v4.3 已废弃, 网页端做 ([F-015](../../FOLLOWUPS.md) 红线) |
| **Excel grid 4 周编辑** — v4.2 已废弃, 仅作为网页端 V1.0 layout reference 保留 ([F-015](../../FOLLOWUPS.md) 红线) |
| **跨 cycle 视觉对比** — 网页端 ([PD-007](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md)) |
| **多学员 dashboard** — 网页端 ([PD-007](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md)) |
| **真 backend** — `PlanRepository.publishPlan(_:)` 沿用 spec 005 留的 TODO 占位; `BackendPlanRepository` 仍是空 struct + `// TODO: spec NNN backend wiring` |
| **Step 7 row tap 进入强度编辑** (coach-planning §7b 提到的 "点击任一动作行进入该动作的强度编辑") — V1 卡片**全只读**, 编辑只能通过 NavigationStack back 回 Step 5; 加 FOLLOWUP "F-021 候选 — Step 7 row tap 直跳 Step 5 该 exercise 上下文" |
| **Step 7 per-cell W2-W4 手动覆盖** (coach-planning §Step 7a "教练可在下方预览中手动覆盖任意单元格" + data-model §1.9 `exercise_week_overrides`) — V1 不做 (W2-W4 全部 derive 自 W1 + 规则); 加 FOLLOWUP "F-022 候选 — Step 7 per-cell override (W2-W4 单格手覆盖)" |
| **per-set 变化** (warmup / amrap / backoff 不同 set_type 同一 exercise 内混排) — V1 = 1 SetSpec / exercise (全部 working sets uniform); 加 FOLLOWUP "F-023 候选 — Step 5 per-set 变化 (warmup row 等)" |
| **deload 自动检测 / deload tag** — V1 不做 (coach-planning §7b "V1 不自动判定 deload tag — 教练自己知道; V1.5 再评估"); 卡片标题永远 `Week N / N` |
| **PR / e1RM 在长按 Peek 显示** — V1 Peek 只显示动作名 + 强度详情 + 备注; PR 历史 + e1RM 需要 backend 训练记录数据, 留 spec NNN backend wiring 后做 |
| **教练自定义 accessory 动作** (coach 加自己的动作) — backend `POST /exercises` 已 ship, 但 iOS UI defer 独立 spec; 与 spec 006 同立场 |
| **CoreModels 新增 `ProgressionRule` / `ExerciseWeekOverride` value type** — 本 spec 仅在 CoachKit 内部用 `DraftProgressionRule` value struct (本地 draft 层); 提升到 CoreModels 留 spec 008 (publish 真发布时需要 cross-language 序列化才有意义) |
| **新增 SwiftData `@Model` class** (e.g. `DraftPlanSet` / `DraftProgressionRuleGroup`) — 会扩张 ADR-009 例外范围, 需要新 ADR; 本 spec 范围内**不做**, 改用 optional `Data?` 字段方案 (见 §3 Draft 持久化) |
| **修改 spec 005 / spec 006 已有 view 内部实装** — 仅 spec 006 末 CTA `proceedToStep5()` 内部行为换 push target (button label 与 spec 005/006 既有 cleanup 风格一致), 其他 view 不动 |
| **任何 v4.4 红线词** (v4.3/v4.2 禁止词: 4 周宏观视图 / 波形图 / 变式矩阵 / 密度条 / specificityBucket / waveformValue / accessoryDensityBucket / isDeloadWeek / "4 周扫视态" / "Excel grid") — F-015 红线, 实装 + spec 全文 grep 0 命中 |
| **修改 spec 005 / 006 SPEC.md** — 上游已锁; 本 spec 是 strict 增量 |
| **Lite role switch / multi-role / ModeAware routing** — V1.5+ deferred, 与 spec 005 同立场 |

## 技术要求

继承 spec 005 / spec 006 模式 (per ADR-005 §3 MVVM + Repository, ADR-009 SwiftData 例外):

- 一个 type 一个文件 (file-private nested view helper struct 允许, AGENTS.md 显式允许)
- 严格并发 (StrictConcurrency upcoming feature 已配)
- 测试用 Swift Testing (非 XCTest), ViewInspector for SwiftUI traversal
- DesignSystem atom 优先复用 (Card / Eyebrow / PrimaryButton / NumericInput / Badge / Label / SegmentedControl 等); 没有现成 chip atom 时, 在 view 文件内 file-private 实装小 helper (与 spec 006 `AccessoryChip` 同 pattern)

### 模块位置 + import 边界

CoachKit 现有 SPM target, **不新建** target. 新代码全在 `Modules/CoachKit/Sources/CoachKit/Planning/` 下子目录 (Views / State / Drafts), 与 spec 005 / 006 一致.

import 规则 (继承 ADR-005 §3 + spec 005 §模块位置):

| 文件类别 | 允许 import |
|---|---|
| Planning/Views/* (Step5SetIntensityView / ExerciseSetEditorCard / IntensityModeToggle / WeightInputField / Step6ProgressionRulesView / ProgressionRuleEditorCard / Step7WeekCardSwipeView / WeekCardView) | `SwiftUI`, `CoreModels`, `DesignSystem`, 本 module 的 `..State` / `..Drafts` 类型 |
| Planning/State/DraftSetSpec.swift, DraftProgressionRule.swift, ProgressionRuleType.swift, WeekDerivation.swift | `Foundation`, `CoreModels` (复用 `IntensityMode` / `SetType`); **禁止** `SwiftUI` / `Observation` / `SwiftData` |
| Planning/State/PlanningViewModel.swift (改) | `Foundation`, `CoreModels`, `Observation`, 本 module 的 `..Drafts` / `..Repository` |
| Planning/Drafts/* (DraftPlanExercise.swift / DraftTrainingPlan.swift / DraftMapping.swift) | `Foundation`, `SwiftData`, `CoreModels` (与 spec 005 同) |

**禁止** (swiftlint custom rule 检测, 与 spec 005 / 006 同):
- ❌ Planning/Views 下任何文件 import `Networking`
- ❌ Planning/State 下任何文件 import `SwiftUI` / `Networking` / `SwiftData`
- ❌ Planning/Drafts 下任何文件 import `SwiftUI` / `Networking`
- ❌ Planning 下任何文件 import `StudentKit`

`Modules/CoachKit/Package.swift` **无需新增 dependency**.

### `DraftSetSpec` 形状

```swift
public struct DraftSetSpec: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var setCount: Int                     // ≥ 1; V1 = uniform working sets
    public var targetReps: Int                   // ≥ 1
    public var targetRepsMax: Int?               // nil = 精确; 非 nil = 范围 (e.g. 8-12)
    public var intensityMode: IntensityMode      // .weight | .rpe (复用 CoreModels enum)
    public var targetValue: Decimal              // 重量模式: kg (统一存 kg, %1RM 仅 UI 显示); RPE 模式: [1.0, 10.0]
    public var setType: SetType                  // V1 默认 .working, V1.5 支持 warmup/amrap/backoff
    public var notes: String?                    // 教练备注 (V1 UI 暂不暴露输入, schema 占位)

    public init(id: UUID = UUID(), setCount: Int, targetReps: Int, targetRepsMax: Int? = nil,
                intensityMode: IntensityMode, targetValue: Decimal,
                setType: SetType = .working, notes: String? = nil)
}
```

> **存储统一 kg**: `WeightInputField` 在 %1RM 模式下做 UI 实时换算 (`kg = oneRM * percent / 100`), 但写入 `targetValue` 时永远是 kg. 这与 spec 004 §PlanSet 约束 "%1RM 不进 storage" 一致.

### `DraftProgressionRule` 形状

```swift
public struct DraftProgressionRule: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var ruleType: ProgressionRuleType
    public var incrementValue: Decimal?          // 非 custom 时 ≠ nil (如 +5kg, +0.5 RPE, +1 set, +1 rep); custom 时 == nil
    public var customSequence: [Decimal]?        // custom 时 ≠ nil, 长度 = appliedWeeks.count, 顺序对齐 sorted(appliedWeeks)
    public var customDimension: ProgressionRuleDimension? // custom 时非 nil, 否则 nil
    public var exerciseIDs: Set<UUID>            // FK → DraftPlanExercise.id (不是 catalog Exercise.id; 同动作不同 day = 不同 draft 行)
    public var appliedWeeks: Set<Int>            // ⊆ {2, 3, 4} (W1 是基线, 不入 set; UI 上 W1 chip disabled)
    public var displayOrder: Int                 // UI 顺序; 也用作冲突仲裁 "displayOrder 大者优先"
}
```

### Custom rule dimension picking

V1 custom rule 只能绑定 **1 个维度**。UI 在 custom 模式下显示维度 segmented control:

```swift
public enum ProgressionRuleDimension: String, Codable, CaseIterable, Hashable, Sendable {
    case weight, rpe, sets, reps
}
```

`DraftProgressionRule.customDimension` 在 `ruleType == .custom` 时必须非 nil; 非 custom 时保持 nil。`WeekDerivation` custom 分支按 `customDimension` dispatch: `.weight` 写 `targetValue` + `.weight` mode, `.rpe` 写 `targetValue` + `.rpe` mode 并 clamp `[1, 10]`, `.sets` 写 `setCount`, `.reps` 写 `targetReps`。`customSequence` 的每个值是该维度在对应 applied week 的**绝对值**。

### `ProgressionRuleType` 形状

```swift
public enum ProgressionRuleType: String, Codable, CaseIterable, Hashable, Sendable {
    case weightInc = "weight_inc"
    case weightDec = "weight_dec"
    case rpeInc = "rpe_inc"
    case rpeDec = "rpe_dec"
    case setsInc = "sets_inc"
    case setsDec = "sets_dec"
    case repsInc = "reps_inc"
    case repsDec = "reps_dec"
    case custom
}
```

> raw value 显式 snake_case (与 CoreModels enum 同约定, 因为 `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` 不转 enum raw value).

### `WeekDerivation` 行为

```swift
public enum WeekDerivation {
    /// Pure 函数: 给定 W1 SetSpec + 规则集合, 返回第 weekN 周该 exercise 的派生 SetSpec.
    /// - W1 (`weekN == 1`): 直接返回 `w1` (基线).
    /// - W2-W4 (`weekN ∈ {2,3,4}`): 递推从 weekN-1 derive, 应用 `rules` 中 `appliedWeeks.contains(weekN) && exerciseIDs.contains(exerciseID)` 的规则.
    /// - 多规则同 exercise 同维度: `displayOrder` 大者覆盖小者 (后写入优先).
    /// - 多规则同 exercise 不同维度: 合并 (各维度独立应用).
    /// - 无规则覆盖: 默认 `prevWeek` 同值 (即 `deriveSetSpec(forWeek: weekN-1, ...)`).
    /// - 边界 clamp: setCount ≥ 1, targetReps ≥ 1, RPE ∈ [1.0, 10.0] (clamp 不 throw).
    /// - Custom 规则: `appliedWeeks` 排序后取 weekN 在序列中的 index, 用 `customSequence[index]` 作为该周该维度的绝对值 (语义见 coach-planning §Step 9 "自定义 → 复合多维度"; V1 简化为 custom 规则在创建时由教练绑定到一个维度, 写在 `ruleType.custom` + `customSequence` 含该维度每周值).
    public static func deriveSetSpec(forWeek weekN: Int,
                                     exerciseID: UUID,
                                     w1: DraftSetSpec,
                                     rules: [DraftProgressionRule]) -> DraftSetSpec
}
```

> **递归实现注意**: 实装时建议 memoize (e.g. 在 `deriveSetSpec` 外包一层 cache, 同一 exercise 计算 W2/W3/W4 共享中间结果), 避免 O(n²) 重复递推. memoize 是实装细节, 不强制 (函数签名是 pure, 无副作用).

> **Custom 规则 V1 简化**: coach-planning §Step 6 #9 描述 "复合多维度 (如 +5kg + -1 次)", 但 V1 UI **不支持复合** — custom 规则在 UI 层创建时教练只能绑定 **1 个维度** (kg / RPE / sets / reps 选其一), `customSequence` 是该维度每周绝对值序列. 复合 custom = V1.5 follow-up (加 FOLLOWUP "F-024 候选 — custom rule 复合多维度").

### `PlanningStep` 扩展

```swift
public enum PlanningStep: Int, CaseIterable, Hashable, Codable, Sendable {
    case selectStudent = 0
    case selectDuration = 1
    case assignFrequency = 2
    case selectMainLifts = 3
    case selectAccessories = 4    // spec 006
    case fillW1Intensity = 5      // 本 spec
    case configureRules = 6       // 本 spec (1 周模式跳过, 直接到 .previewWeekCards)
    case previewWeekCards = 7     // 本 spec
}
```

### `PlanningViewModel` 扩展 sketch

新增字段 (类内 `@Observable @MainActor` 现有 class):

```swift
// step 5
public var w1SetSpecs: [UUID: DraftSetSpec] = [:]            // key = DraftPlanExercise.id; 加载时从 setsData decode 填充
public var lastIntensityModeMemo: [UUID: IntensityMode] = [:] // 切换 IntensityMode 时保留另一边输入 (UI memo, 不写 draft)

// step 6
public var progressionRules: [DraftProgressionRule] = []     // 加载时从 progressionRulesData decode 填充

// step 7
public var currentPreviewWeek: Int = 1                       // ∈ [1, draftPlan.planWeeks]; V1 不持久化, 重开默认 W1; V1.5 评估是否需要
public var didFinish: Bool = false                            // spec 005 已有, 末 CTA 触发 (本 spec 末 CTA 改为 placeholder, 不真 set didFinish=true)
```

新增方法:

```swift
// step 5
public func updateW1SetSpec(_ spec: DraftSetSpec, for draftExerciseID: UUID) async throws  // 写 w1SetSpecs + encode 到 draft.setsData + DraftStore.saveDraft
public func toggleIntensityMode(to newMode: IntensityMode, for draftExerciseID: UUID) async  // 切 mode + 维护 lastIntensityModeMemo
public func proceedToStep6() async throws                 // 校验所有 main lift + accessory `setsData != nil` + spec 校验 (setCount ≥ 1, reps ≥ 1, RPE ∈ [1,10] 等); 通过 → push .configureRules (4 周模式) 或直接 .previewWeekCards (1 周模式)

// step 6
public func addRule(_ rule: DraftProgressionRule) async throws       // append + encode 到 draft.progressionRulesData
public func updateRule(_ rule: DraftProgressionRule) async throws    // 按 id mutate + 重 encode
public func deleteRule(id: UUID) async throws                         // 移除 + 重排 displayOrder + 重 encode
public func proceedToStep7() async throws                              // 无校验 (规则全空也允许); push .previewWeekCards

// step 7
public func setCurrentPreviewWeek(_ week: Int)            // 0 < week ≤ planWeeks; 写入 currentPreviewWeek; 顺手触发 saveDraft 仅刷新 lastSavedAt, 不持久化 week index
public func proceedToStep8() async throws                  // V1 placeholder = log warn `step8_pending`, 不真推进 step (spec 008 替换 method body)
```

### Step 5 wireframe → SwiftUI 映射

```
NavigationStack 内部:
  ScrollView:
    Eyebrow "Week 1 必填(基线)"

    ForEach draftPlan.days.sorted(by: dayOfWeek):
      Section header: 自然语言 day label (周一/周二/...)
        ForEach day.exercises (主项 isMainLift=true 在前, 辅助在后, sortOrder 内排序):
          ExerciseSetEditorCard(viewModel: viewModel, draftExercise: exercise)

  底部 PrimaryButton:
    label: "完成 W1 强度 — 进入规则配置 (4 周模式)" 或 "完成 W1 强度 — 预览本周 (1 周模式)"
    action: Task { try await viewModel.proceedToStep6() }   // 校验过 → 自动 push 下个 step
    disabled: 任一 exercise.setsData == nil 或 spec 不通过校验 (setCount<1 / reps<1 / RPE 越界)
```

`ExerciseSetEditorCard` 内部:
```
Card:
  HStack: Label(exercise.name)  +  Badge("(主项)", isMainLift ? .visible : .hidden)
  IntensityModeToggle (segmented [重量 / RPE])
  if mode == .weight:
    WeightInputField (内含 [kg / %1RM] segmented + NumericInput)
  else:
    NumericInput RPE  (range [1.0, 10.0] step 0.5, decimal)
  HStack:
    NumericInput 组数 (setCount, ≥1)
    NumericInput 次数 (targetReps, ≥1)
    [optional] NumericInput 次数上限 (targetRepsMax, optional, ≥ targetReps)
```

`WeightInputField` 内部:
```
SegmentedControl [kg / %1RM]:
  - 学员该 lift family 有 1RM (StudentProfile.squatOneRM/benchOneRM/deadliftOneRM 非 nil) → 两态可切
  - 学员该 lift family 无 1RM → segmented 锁定 kg + Eyebrow "未设 1RM, 无法换算 %1RM"

if 当前 == kg:
  NumericInput value (Decimal, kg)
if 当前 == %1RM:
  NumericInput percent (1-150, 整数; 实时换算 = oneRM * percent / 100, 显示 "= X.X kg")
```

> **lift family 判定**: `WeightInputField` 需要知道当前 exercise 属于哪个 lift family 才能查 `StudentProfile.<>OneRM`. 主项 (`isMainLift = true`) → 从 `Exercise.mainLiftFamily` 取 (catalog 已知); 辅助项 (`isMainLift = false`) → 没有 lift family 概念, %1RM 模式直接禁用 (强度只能 kg / RPE). spec 006 fixtures `mainLiftFamily = nil` 已经准备好.

### Step 6 wireframe → SwiftUI 映射

```
NavigationStack 内部:
  ScrollView:
    ForEach progressionRules.sorted(by: displayOrder):
      ProgressionRuleEditorCard(viewModel: viewModel, rule: rule)

    PrimaryButton "+ 添加规则" {
      Task { try await viewModel.addRule(.init(/* default = weightInc, +5kg, exerciseIDs=[], appliedWeeks=[2,3] */)) }
    }

    Eyebrow "未被任何规则覆盖":
      ForEach week ∈ {2, 3, 4}:
        Label: "W\(week): " + 列出 (draftPlan 内全部 exerciseIDs - 任一 rule 应用 to week 的 exerciseIDs) 的动作名;
        若全部覆盖 → 隐藏该行

  底部 PrimaryButton:
    label: "完成规则 — 预览 4 周"
    action: Task { try await viewModel.proceedToStep7() }
    disabled: 永远 false (规则全空也允许)
```

`ProgressionRuleEditorCard` 内部:
```
Card:
  HStack: "规则 \(displayOrder + 1)" + Spacer + [删除] (确认弹窗)

  Picker(selection: $rule.ruleType) ForEach ProgressionRuleType.allCases.

  if rule.ruleType != .custom:
    NumericInput 增量值 (Decimal, sign 由 ruleType 暗示: *_inc 显示 + / *_dec 显示 -)
  else:
    ForEach rule.appliedWeeks.sorted():
      NumericInput "W\(week) 值" (绑定 customSequence[index])

  Eyebrow "应用动作":
    ForEach (draftPlan 内全部 DraftPlanExercise, 主项在前):
      ChipMultiSelect (绑定 rule.exerciseIDs.contains(ex.id))

  Eyebrow "应用周":
    HStack:
      Chip "W1" disabled: true  (基线, 永远不可勾)
      Chip "W2" / "W3" / "W4" toggle (绑定 rule.appliedWeeks)
```

> **冲突 UI 提示** (coach-planning §Step 6): 当多规则同 exercise 同维度同 week → 在被覆盖的低 displayOrder rule card 上显示 Badge "被规则 #\(higherDisplayOrder + 1) 覆盖" (V1 静态显示, 不交互).

### Step 7 wireframe → SwiftUI 映射

```
NavigationStack 内部:
  顶部 学员浮层 (复用 spec 005 PlanningCoordinatorView 顶部 toolbar)

  TabView(selection: $viewModel.currentPreviewWeek) {
    ForEach 1...draftPlan.planWeeks: { weekN in
      WeekCardView(viewModel: viewModel, weekNumber: weekN)
        .tag(weekN)
    }
  }
  .tabViewStyle(.page(indexDisplayMode: .never))
  // 不显示 page dots; 标题已含 "Week N / N"
  // 边界 bounce 由 TabView 默认行为提供; 不 wrap, 不 advance 到下个 cycle

  底部 PrimaryButton:
    label: "进入发布 (TODO spec 008)"
    action: Task { try await viewModel.proceedToStep8() }   // V1 = log warn, 不真推进
```

`WeekCardView` 内部:
```
ScrollView:
  HStack: "Week \(weekNumber) / \(draftPlan.planWeeks)"  (header)

  ForEach draftPlan.days.sorted(by: dayOfWeek):
    Section: 自然语言 day label
      ForEach day.exercises (主项在前, sortOrder 内排序):
        let derived = WeekDerivation.deriveSetSpec(forWeek: weekNumber, exerciseID: exercise.id,
                                                   w1: viewModel.w1SetSpecs[exercise.id]!,
                                                   rules: viewModel.progressionRules)
        HStack:
          Label exercise.name
          Spacer
          Label "\(derived.setCount) 组 × \(derived.targetReps)次"
          Label intensity: 取决于 mode (kg 或 @RPE X)
        .contextMenu {
          // V1 menuItems 留空 (无操作); 仅用 preview 显示长按 Peek 详情
        } preview: {
          ExercisePeekView(exercise: exercise, derived: derived)
          // V1 只显示动作名 + 强度详情 + 备注
          // PR 历史 / e1RM = "TODO spec NNN backend wiring"
        }

  底部 Eyebrow:
    if weekNumber == 1: "Week 1 是基线 (你手填的)"
    else: "Week \(weekNumber) 由规则推导 (W1 + 规则)"

  // 横滑提示 (UX hint):
  if weekNumber > 1:           "← swipe to Week \(weekNumber - 1)"
  if weekNumber < planWeeks:   "swipe to Week \(weekNumber + 1) →"
```

### TabView page swipe 与 NavigationStack back 手势的兼容

per coach-planning v4.4 §7b:
> NavigationStack 边缘 swipe-back 由系统处理, TabView 自动让出 ~20pt 左边缘

实装时**不显式自定义** `.navigationBarBackButtonHidden` 或自定义边缘手势识别器. SwiftUI 默认行为已经处理: `TabView(.page)` 仅在卡片中央区域响应 horizontal swipe, 边缘 ~20pt 让位给 NavigationStack edge swipe. iOS 17+ 行为稳定.

> **手势冲突回归测试**: 验收清单 §iPhone 17 simulator happy path 包含手动验证步骤 — 从 W2 卡片左边缘 ~10pt 起手 swipe → 应 pop NavigationStack (回 Step 6); 从 W2 卡片中央 swipe → 应切到 W1.

### Step 4 → Step 5 push (spec 006 末 CTA action 替换)

spec 006 `Step4SelectAccessoriesView.swift` 末 CTA 当前 action = `viewModel.proceedToStep5()` (V1 = log warn `step5_pending`). 本 spec 替换 method body:

```swift
public func proceedToStep5() async throws {
    // 校验: spec 005 + 006 已就位 (selectedStudent / planWeeks / dayAssignments / selectedVariants 全填); spec 006 不强制每个 day 必有 accessory (允许 0 accessory)
    // 通过 → path.append(.fillW1Intensity); saveDraft (currentStepRawValue 同步)
    path.append(.fillW1Intensity)
    try await saveDraft()
}
```

button label 维持 spec 006 留下的 "完成辅助动作 — 下一步 (TODO spec 007)" 不变 — 实装本 spec 时改 label 为 "完成辅助动作 — 填写 W1 强度". 这是 spec 006 已锁的 button 文案, 不算 spec 006 实装回归 (行为变化是 spec 007 范围内允许的接力扩展).

### Resume / 持久化恢复 (复用 spec 005 `bootstrap()`)

`PlanningViewModel.bootstrap()` (spec 005 已有) 末尾扩展: 加载 draft 后, 解析 `setsData` / `progressionRulesData`:

```swift
// 在 spec 005 现有 bootstrap 内:
// ... existing: load students, catalog, find draft for selectedStudent ...
if let draft {
    // spec 005 已有: currentStepRawValue → path 恢复; 字段恢复
    // spec 007 新增:
    self.w1SetSpecs = decodeW1SetSpecs(from: draft)         // 遍历 draft.draftDays[*].draftExercises[*].setsData
    self.progressionRules = decodeRules(from: draft.progressionRulesData)
    self.currentPreviewWeek = 1   // 简化: 恢复永远从 W1 开始; 不持久化 currentPreviewWeek
}
```

### 严格并发 + Sendable

继承 spec 001-006: `Modules/CoachKit/Package.swift` 已配 `.enableUpcomingFeature("StrictConcurrency")`. `DraftSetSpec` / `DraftProgressionRule` 是 Sendable value struct; `WeekDerivation` 是 enum 命名空间 + static func, 自然 Sendable; `PlanningViewModel` 显式 `@MainActor`.

### 测试约定

继承 spec 005 / 006: Swift Testing (`@Test` / `#expect`); ViewInspector 已在 testTarget. **不新加** Package.swift dependency.

测试 fixture:
- `Tests/CoachKitTests/Planning/Fixtures/`: 复用 spec 005 / 006 已有 fixture 学员 + catalog; 加 `WeekDerivationFixtures.swift` 集中 W1 SetSpec + 各类规则测试 case.

### v4.4 红线 awareness

本 spec 实装 Step 7 = 周卡片横滑 (`TabView(.page)`), 严格遵守 v4.4. 实装代码 + spec 全文 grep 验证不出现红线词 (见验收清单).

## 验收标准

- [ ] Planning/Views/ 新增 8 文件: `Step5SetIntensityView.swift` / `ExerciseSetEditorCard.swift` / `IntensityModeToggle.swift` / `WeightInputField.swift` / `Step6ProgressionRulesView.swift` / `ProgressionRuleEditorCard.swift` / `Step7WeekCardSwipeView.swift` / `WeekCardView.swift` (各 1 顶层 type per file, file-private nested view helper 允许)
- [ ] Planning/State/ 新增 4 文件: `DraftSetSpec.swift` / `DraftProgressionRule.swift` / `ProgressionRuleType.swift` / `WeekDerivation.swift` (各 Sendable, Codable 适用)
- [ ] Planning/State/PlanningStep.swift 改: 加 3 case (`.fillW1Intensity = 5` / `.configureRules = 6` / `.previewWeekCards = 7`); raw value 连续, Codable round-trip 测全 7 case
- [ ] Planning/State/PlanningViewModel.swift 改: 加 4 字段 (`w1SetSpecs` / `lastIntensityModeMemo` / `progressionRules` / `currentPreviewWeek`) + 8 方法 (updateW1SetSpec / toggleIntensityMode / proceedToStep6 / addRule / updateRule / deleteRule / proceedToStep7 / setCurrentPreviewWeek / proceedToStep8); `bootstrap()` 末尾扩展 decode `setsData` / `progressionRulesData`
- [ ] Planning/Drafts/DraftPlanExercise.swift 改: 加 `public var setsData: Data? = nil` (optional, default nil)
- [ ] Planning/Drafts/DraftTrainingPlan.swift 改: 加 `public var progressionRulesData: Data? = nil` (optional, default nil)
- [ ] Planning/Drafts/DraftMapping.swift 扩: 加 `encodeSetSpec` / `decodeSetSpec` / `encodeRules` / `decodeRules` helpers; `toDomain(_:)` 扩展为 SetSpec → N 个 PlanSet expand
- [ ] Planning/Views/PlanningCoordinatorView.swift 改: `navigationDestination(for:)` 加 3 case 路由 (`.fillW1Intensity` / `.configureRules` / `.previewWeekCards`)
- [ ] Planning/Views/Step4SelectAccessoriesView.swift (spec 006 留) 末 CTA action: `viewModel.proceedToStep5()` 内部行为换为 push `.fillW1Intensity` (button label 改为 "完成辅助动作 — 填写 W1 强度", 替换 spec 006 留下的 "TODO spec 007" 占位文案)
- [ ] DraftPlanExercise / DraftTrainingPlan 加 optional 字段后 SwiftData lightweight 自动迁移 (无需 `VersionedSchema` + `MigrationStage`); 实装后 spec 005 已有 draft 数据打开时这两字段读为 nil, 不破坏现有 row
- [ ] **不新增** SwiftData `@Model` class (ADR-009 例外范围不扩张)
- [ ] **不修改** spec 004 CoreModels schema (`PlanSet` / `IntensityMode` / `SetType` / `Exercise` 复用现有定义)
- [ ] **不修改** spec 005 `DraftStore` / `PlanningCoordinatorView` 主体 / `PlanRepository` protocol / `InMemoryPlanRepository` / `BackendPlanRepository` 签名
- [ ] **不修改** spec 006 view 内部实装 (仅 spec 006 留下的末 CTA `proceedToStep5()` method body 替换 + button label 替换 — 在本 spec 范围内允许)
- [ ] swift build 在 Modules/CoachKit 单独跑过, 0 warning, 0 error, Swift 6 strict concurrency
- [ ] swift test 通过, 测试 ≥ 49 (新增 + 扩展加和)
- [ ] **iPhone 17 simulator happy path 8 步**:
  1. spec 005 + 006 完整流程跑到 Step 4 完 → 点 CTA push 进 Step 5
  2. Step 5: 看到每天每动作 1 张 ExerciseSetEditorCard, 主项有 (主项) Badge; 切 IntensityMode 重量 ↔ RPE; 切 kg ↔ %1RM (主项, 学员有该 lift family 1RM); 填全 main lift + accessory 的 setCount / reps / 强度
  3. Step 5 → 点 CTA "完成 W1 强度 — 进入规则配置" (4 周模式) → push Step 6
  4. Step 6: + 添加规则 (默认 weight inc +5kg) → 选应用动作 (chip 多选) → 选应用周 (W1 disabled, W2/W3/W4 toggle) → 添加第 2 条规则 (RPE inc +0.5, 应用 W2,W3) → 看到 "未被任何规则覆盖" 行动态更新
  5. Step 6 → 点 CTA "完成规则 — 预览 4 周" → push Step 7
  6. Step 7: 看到 TabView 4 张卡片, 默认在 Week 1; horizontal swipe → 切到 Week 2 → 看到 W2 派生值 (W1 + 规则)
  7. 长按 W2 上某个动作行 → 弹 contextMenu preview (V1 显示动作名 + 强度详情)
  8. 边缘 swipe-back (左边缘 ~10pt 起手) → pop 回 Step 6 (验证手势不冲突 TabView page swipe)
- [ ] **杀 app + 重开 resume**: 在任一 step 5/6/7 操作中杀 app → 重开 → 自动进入对应 step + 已填字段恢复 (W1 SetSpec / rules 都恢复; currentPreviewWeek 恢复到 1, 不持久化中间预览位置)
- [ ] **1 周模式回归**: spec 005 Step 1 选 1 周 → 走完 Step 5 (规则跳过, 直接 push `.previewWeekCards`) → Step 7 仅 1 张卡片标题 "Week 1 / 1", 无 swipe 可切
- [ ] xcodebuild build -scheme MeetPR 通过 (整 app 编译, 不破坏 spec 005 / 006 / 011 已有 wire)
- [ ] xcodebuild test -scheme MeetPR ... 通过
- [ ] **隔离回归**: CoachKit 仍不可 import StudentKit; Planning/State 下 `grep -r "import SwiftUI\|import SwiftData\|import Networking"` 命中数 = 0; Planning/Views 下 `grep -r "import Networking"` 命中数 = 0
- [ ] swiftlint + swift-format 全绿
- [ ] CI 在 `feat/007-coach-planning-step-5-7-week-card-swipe` 分支跑过, 全绿
- [ ] **F-015 v4.4 红线 grep**: `grep -rE "specificityBucket|waveformValue|accessoryDensityBucket|isDeloadWeek|4 周宏观|4 周扫视态|波形图|波形|变式矩阵|密度条|密度热图|Excel grid|跨 cycle" Modules/CoachKit/Sources/CoachKit/Planning/ specs/007-coach-planning-step-5-7-week-card-swipe/` — v4.3/v4.2 禁止词检查; 期望返回空 (本 spec 引用这些词的位置仅在 §不做什么 + Notes §F-015 自检 章节内, **作为禁止词列出**, grep 时人工 exclude 这两个 section 后期望 0 命中)
- [ ] FOLLOWUPS.md 加 4 条候选 (主动加, 教练 dogfood 后据 usability 决定何时触发):
  - "F-021 候选 — Step 7 row tap 直跳 Step 5 该 exercise 上下文" (V1 行只读)
  - "F-022 候选 — Step 7 per-cell W2-W4 单格手覆盖 (`ExerciseWeekOverride`)" (V1 W2-W4 全 derive)
  - "F-023 候选 — Step 5 per-set 变化 (warmup row / amrap row)" (V1 = 1 SetSpec / exercise)
  - "F-024 候选 — custom rule 复合多维度 (e.g. +5kg + -1 次 同一规则)" (V1 custom = 1 维度 / 规则)
- [ ] PR description 引用 SPEC.md + 填验收 checklist + 录可选 simulator 短截屏 (Step 5 输入 + Step 6 加规则 + Step 7 横滑 W1↔W2↔W3↔W4)

## 参考

- **Wireframe ground truth**: [`~/Brain/wiki/projects/MeetPR/coach-planning.md`](~/Brain/wiki/projects/MeetPR/coach-planning.md) v4.4 §Step 5 / §Step 6 / §Step 7a / §Step 7b
- **Pivot 决策原委**: [`~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md`](~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md) — iPhone 不做 4 周宏观 + 7 议题处置表
- **PRD v4.4 sync**: [`~/Brain/wiki/projects/MeetPR/prd.md`](~/Brain/wiki/projects/MeetPR/prd.md) §4 场景 1 + §5 P0 教练端 #4 (周卡片横滑叙事 + iPhone 不做 4 周宏观)
- **数据模型**: [`~/Brain/wiki/projects/MeetPR/data-model.md`](~/Brain/wiki/projects/MeetPR/data-model.md) v1.1 §1.8 (PlanSet) + §1.9 (ProgressionRuleGroup / ProgressionRuleAssignment / ExerciseWeekOverride — 仅作设计参考, 本 spec 仅在 CoachKit 内用 `DraftProgressionRule` value struct, 不入 CoreModels)
- **架构**: [ADR-005 §1 (CoachKit 模块边界) + §3 (MVVM + Repository pattern + 三层职责)](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)
- **SwiftData 例外边界**: [ADR-009 SwiftData 例外](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) — 本 spec **不扩张** ADR-009 例外范围 (仅加 optional 字段, 不引入新 `@Model` class)
- **F-015 双保险**: [FOLLOWUPS.md](../../FOLLOWUPS.md) — 任何 coach planning UI spec 必须按 v4.4 写
- **Pivot 红线**: [coach-planning v4.4 §7d (网页端 scope 扩张吸收所有 4 周宏观能力)](~/Brain/wiki/projects/MeetPR/coach-planning.md) + [PD-007 web companion deferred V1.x](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md)
- **上游 spec**:
  - [spec 002 CoreModels identity](../002-core-models-identity/SPEC.md) — `User` / `StudentProfile` (含 `<lift>OneRM` 字段供 %1RM 换算)
  - [spec 003 DesignSystem foundation](../003-design-system-foundation/SPEC.md) — atomic 组件
  - [spec 004 CoreModels training plan](../004-core-models-training-plan/SPEC.md) — `Exercise` / `PlanSet` / `IntensityMode` / `SetType` / `LiftFamily`
  - [spec 005 Coach Planning UI Step 0-3](../005-coach-planning-step-0-3/SPEC.md) — `PlanningCoordinatorView` / `PlanningStep` / `PlanningViewModel` / `DraftStore` / 3 个 `@Model` class / `DraftMapping` / `PlanRepository`
  - [spec 006 Coach Planning UI Step 4 添加辅助动作](../006-coach-planning-step-4-accessories/SPEC.md) — `AccessoryFilters` / per-day independence / chip 模式

## Notes (给 Claude review + Codex)

### 🎯 用户已拍板的 4 个决定 (本 spec 必须按这 4 个写)

| 维度 | 决定 | 落地形态 |
|---|---|---|
| **Step 5 数据粒度** | per-exercise 1 个 SetSpec (V1 uniform working sets) | `DraftSetSpec` 单 value struct, V1 不支持 per-set warmup/amrap; 加 FOLLOWUP F-023 |
| **Step 6 规则形状** | 9 类 + custom + 应用周 W2-W4 子集 | `DraftProgressionRule` + `ProgressionRuleType` enum 10 cases; custom V1 = 1 维度 / 规则, 加 FOLLOWUP F-024 |
| **Step 7 实现** | `TabView(.page(indexDisplayMode: .never))` 横滑 W1↔W2↔W3↔W4, 卡片标题 "Week N / N" | `Step7WeekCardSwipeView` + `WeekCardView`, V1 行只读 (加 FOLLOWUP F-021), V1 无 per-cell override (加 FOLLOWUP F-022) |
| **Draft 持久化** | 复用 spec 005 已有 3 个 `@Model` + 加 optional 字段 (additive lightweight 迁移) | `DraftPlanExercise.setsData: Data?` + `DraftTrainingPlan.progressionRulesData: Data?`; **不**引入新 `@Model` (ADR-009 不扩张) |

### ⚠️ ADR-009 边界声明 — 需 Claude review 确认

ADR-009 §"⚠️ 需警惕" 写: "未来如果有 spec 想 '再来一个 SwiftData @Model', **必须开新 ADR 显式扩张本 ADR 的例外范围**". 本 spec **不引入** 新 `@Model` class — 仅在已有 `DraftPlanExercise` / `DraftTrainingPlan` 上加 optional `Data?` 字段.

ADR-009 §"⚠️ 需警惕" 也写: "V1 改 `DraftTrainingPlan` 字段 (如新增 deload tag 字段) 需要 SwiftData `VersionedSchema` + `MigrationStage` 实装". 本 spec 加的字段是 **additive optional with nil default** — SwiftData lightweight 自动迁移直接处理 (Apple 文档 + WWDC23 "Migrate to SwiftData" 明确支持此情形不需 `VersionedSchema`).

**判定要点 (建议 review 决定)**:

1. **接受** — additive optional 字段属 SwiftData lightweight 范畴, 本 spec **不需** ADR 修订即可实装. 这是大多数 SwiftData 应用的常规做法; 本 spec 走此路径.
2. **保守** — 即便 additive optional 也要走 `VersionedSchema` + `MigrationStage` 显式版本声明, 防 V1.5 迁移路径复杂时漏迁. 此情形请 review 时明示, Codex 实装会改用 v1 → v2 显式 schema 声明 (工作量 +0.5 天).

> 默认走 (1). 若 review 选 (2), 本 spec 验收清单加 `VersionedSchema` 文件 (e.g. `PlanningSchemaV1.swift` / `PlanningSchemaV2.swift` + `PlanningMigrationPlan.swift`) 的实装条目.

### F-015 自检 (扫一遍 spec 不出现以下字眼, 除"不做什么"和"Notes"两个明示禁止词的 section 外)

- ✅ "4 周扫视态" — v4.3 禁止词, 仅在 §不做什么 中作为废弃方案列出, 0 实装引用
- ✅ "Excel grid" — v4.2 禁止词, 仅在 §不做什么 中作为废弃方案列出, 0 实装引用
- ✅ "波形图" / "波形" — v4.3 禁止词, 仅在 §不做什么 中作为废弃方案列出, 0 实装引用
- ✅ "变式矩阵" — v4.3 禁止词, 仅在 §不做什么 中作为废弃方案列出, 0 实装引用
- ✅ "密度条" / "密度热图" — v4.3 禁止词, 仅在 §不做什么 中作为废弃方案列出, 0 实装引用
- ✅ "specificityBucket" / "waveformValue" / "accessoryDensityBucket" / "isDeloadWeek" — v4.3 禁止词, 仅在 §不做什么 + Notes §F-015 自检 中作为禁止词列出, 0 实装引用
- ✅ "跨 cycle" — 仅在 §不做什么 中作为网页端范畴列出, 0 实装引用

实装后 grep 命令 (v4.3/v4.2 禁止词): `grep -rE "specificityBucket|waveformValue|accessoryDensityBucket|isDeloadWeek|4 周宏观|4 周扫视态|波形图|波形|变式矩阵|密度条|密度热图|Excel grid|跨 cycle" Modules/CoachKit/Sources/CoachKit/Planning/` — 期望 0 命中 (实装代码不应包含红线词).

### 给 Codex 的实施小提示

- 本 spec 接力 spec 005 (PR #25 已 merge) + spec 006 (PR #?? 待 merge — 实装时确认 spec 006 已合 main, 否则 rebase 等待). 大部分 hooks (DraftStore / PlanningCoordinatorView / DraftPlanExercise / DraftTrainingPlan / DraftMapping / PlanRepository / Step4SelectAccessoriesView) 已就位; 你是填 Step 5/6/7 内容 + 微调 6 个现有文件 (PlanningStep / PlanningViewModel / PlanningCoordinatorView / Step4SelectAccessoriesView 末 CTA / DraftPlanExercise 加 1 字段 / DraftTrainingPlan 加 1 字段 / DraftMapping 扩 helper)
- DesignSystem 没有现成 SegmentedControl atom (核 spec 003 时未列入), 你可在 `Modules/CoachKit/Sources/CoachKit/Planning/Views/` 内实装 file-private `IntensityModeToggle` 用 SwiftUI 原生 `Picker(...).pickerStyle(.segmented)` 包装 + DesignSystem token. `WeightInputField` 同理 file-private. 与 spec 005 / 006 nested private struct view helpers 同 pattern, AGENTS.md 显式允许
- `DraftPlanExercise.setsData` 与 `DraftTrainingPlan.progressionRulesData` 加字段后, 如果用 SwiftData lightweight 自动迁移路径 (推荐, 见 ADR-009 边界声明), 修改后**直接** 跑 `swift test` 验证 spec 005 已有 draft 测试不破坏, 不需要写 migration 代码
- `WeekDerivation` 是 pure 函数, 在 `WeekDerivationTests.swift` 用各种 `DraftSetSpec` + `DraftProgressionRule` 组合断言. 不依赖 SwiftUI / SwiftData, 测试速度快
- `customSequence` 长度 = `appliedWeeks.count`, 在 `updateRule` 时**自动同步** (用户 toggle 应用周 chip → ViewModel 检测到 appliedWeeks 变 → 自动调整 customSequence 数组长度: 加 chip → append nil; 减 chip → remove 对应 index). 这是隐式 invariant, 测试覆盖
- `currentPreviewWeek` 切换时调 `setCurrentPreviewWeek(_:)` → 只更新 ViewModel 状态 + 触发 `saveDraft()` 让 `lastSavedAt` 推进. **不**新增 SwiftData 字段持久化 currentPreviewWeek 本身 — bootstrap 恢复永远从 W1 开始, 简化 UX
- W1 row 在 Step 7 长按 Peek 显示的 SetSpec 跟 Step 5 输入完全一致 (W1 是基线, derived = W1); W2-W4 row 显示 derived SetSpec (经过 `WeekDerivation`)
- 测试 fixture `WeekDerivationFixtures.swift` 应集中常用 W1 SetSpec (kg 模式 4×5 @100kg, RPE 模式 3×5 @8.5) + 各 ruleType 单条规则 + 复合多规则的标准组合, 给后续 spec 008 (publish) / spec 009 (template) 测试复用
- F-015 红线 grep 命令 (实装完跑一遍): 见验收清单 §F-015. 期望 0 命中 (除 spec 文档自身的 §不做什么 + Notes §F-015 自检 章节)
- 任何疑问写 `specs/007-coach-planning-step-5-7-week-card-swipe/QUESTIONS.md`
- 完成后**别 self-merge** — Claude review 后才 merge (与 spec 005 / 006 / 011 同 pattern)
- 实装 PR 用 `feat/007-coach-planning-step-5-7-week-card-swipe` 分支 (本 PR `chore/...` 仅承载 spec 文件)
- PR description 列每个 step 的 wireframe 截图 (Xcode Canvas) 对照 coach-planning.md 文本 wireframe, 以及 W2-W4 derived 值的手算对比
