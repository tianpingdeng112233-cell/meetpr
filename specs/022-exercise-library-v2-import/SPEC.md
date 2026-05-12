# 022 — Exercise Library v2 Catalog Import(V0 demo 升级)

- **状态**: Done
- **PR**: https://github.com/tianpingdeng112233-cell/meetpr/pull/51
- **来源**:
  - [`~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2.xlsx`](~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2.xlsx) — 435 条动作库,教练 xty 已审完(2026-05-12,全过 + 一字未改)
  - [`~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2-RATIONALE.md`](~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2-RATIONALE.md) — v2 来源 / 分类方法论 / 字段定义
  - [`~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2-FOR-COACH-REVIEW.md`](~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2-FOR-COACH-REVIEW.md) — 教练 review 视图
  - 已合 [spec 005 coach planning step 0-3](../005-coach-planning-step-0-3/SPEC.md) — `fetchMainLiftCatalog` 消费方
  - 已合 [spec 006 coach planning step 4 accessories](../006-coach-planning-step-4-accessories/SPEC.md) — `fetchAccessoryExercises(filters:)` 消费方
  - [ADR-005 §iOS architecture](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — V0 InMemoryRepository pattern
- **触发**:option E(2026-05-12 用户决策"目前先注重产品建设")— 教练审完 xlsx 解锁本 spec → impl pipeline

## 目标

把 `InMemoryPlanRepository.previewCatalog()` 从 ~40 条手 hardcoded 占位 catalog 升级到 **438 条真 catalog**(3 synthetic competition lifts + 435 imported from xty 审完的 xlsx)。

落地后:

```
教练规划 Step 0-3  → 仍能选 3 条竞技主项 + 多条主项变式 (上游 happy path 不破)
教练规划 Step 4    → accessory 选择器从 ~34 条 thin demo 升级到 ~250 条真 catalog
                     (filter facets 体感跟生产接近 — 大幅提升 V0 demo TestFlight 内测真实感)
教练规划 Step 5-7  → 不变 (catalog 增量对 W1 强度 / 规则 / 周卡片预览 透明)
```

不接 backend(InMemoryRepository 的 V0 分工不变);不动 xlsx(那是教练的 source of truth,只读)。

## 范围

### 做什么

#### 1. 生成 fixture JSON 文件

**位置**: `Modules/CoachKit/Sources/CoachKit/Resources/exercise-catalog-v2.json`(SPM bundle resource)

**内容**: 435 条 `Exercise` Codable 数组(JSON 数组,顶层是 `[Exercise]`,跟 Exercise.swift Codable 一致)

**生成方式**:
- Codex 写一次性 Python 脚本 `scripts/import-exercise-catalog-v2.py`(impl PR 内放,不进 CI),读 xlsx → 转 JSON
- 脚本严格按 §技术要求 §Mapping tables 跑
- 跑完 commit JSON + 脚本到 impl PR;后续教练 review 改动只重跑脚本,不手改 JSON

#### 2. 重构 `InMemoryPlanRepository`

**文件**: `Modules/CoachKit/Sources/CoachKit/Planning/Repository/InMemoryPlanRepository.swift`

**改动**:
- 新加 `static func loadBundledCatalogV2() -> [Exercise]` — 读 `Bundle.module` 内 `exercise-catalog-v2.json`,JSONDecoder 解出 `[Exercise]`
- 新加 `static func syntheticCompetitionLifts() -> [Exercise]` — 保留现 `previewCatalog()` 内 3 条 `mainLift`(`竞技深蹲` / `竞技卧推` / `竞技硬拉`,UUID 沿用 `uuid(20)` / `uuid(21)` / `uuid(22)` 不变)
- `previewCatalog()` 改为 `syntheticCompetitionLifts() + loadBundledCatalogV2()` = 3 + 435 = 438 条
- 删除现有 `previewAccessoryCatalog()`(整体被 JSON 替代)+ `accessory(_:_:_:_:_:_:)` helper
- 删除现有非竞技的 3 条 hardcoded `mainLiftVariation`(`暂停卧推` / `节奏硬拉` / `前蹲举`)— 这 3 条 xlsx 内有等价/超集
- 保留 `uuid(byte: UInt8)` helper for student/profile fixtures (1-10 范围;catalog v2 UUID scheme 见下条不冲突)

#### 3. Catalog v2 ID scheme(避免与 student fixtures 冲突)

xlsx `#` 列(1-435)作 catalog seq。生成 UUID 用 4-byte tail signature `0xCA70` (代表 catalog) + 2-byte big-endian seq:

```
00000000-0000-0000-CA70-0000000000XX  # seq=1 → 0001
00000000-0000-0000-CA70-0000000001B3  # seq=435 → 01B3
```

(具体字节布局 Codex 实装时自定;只要保证 2 点:① 生成 deterministic, 给定 seq 永远同 UUID;② 跟 `uuid(byte:)` 生成的 student fixture UUIDs 永不冲突。)

3 条 synthetic competition lifts 沿用现 hardcoded UUID(`uuid(20)` / `uuid(21)` / `uuid(22)`)— 上游 spec 005-007 测试可能引这些值,**不要换**。

#### 4. CoachKit Package.swift resources 声明

`Modules/CoachKit/Package.swift` `target(name: "CoachKit", ...)` 段加 `resources: [.process("Resources")]` (or `.copy`,看 SPM 如何处理 JSON)。

#### 5. 测试更新 + 新增

**已存在测试**(可能需要数字 update):
- `InMemoryAccessoryRepositoryTests.swift` — 现 hardcode 期望 count;改成 ≥ 100 之类的 lower-bound assertion,或从 fixture 派生期望值
- `Step4ViewModelTests.swift` 等若有 hardcode count → 同上

**新增**: `Modules/CoachKit/Tests/CoachKitTests/Planning/PreviewCatalogV2Tests.swift`
- `previewCatalogContainsThreeSyntheticCompetitionLifts` — assert `.mainLift` 类型 ≥ 3 + 名字含 "竞技"
- `previewCatalogTotalCountIsFourThirtyEight` — assert total == 438
- `previewCatalogHasNoDuplicateIDs` — assert UUID set size == catalog count
- `previewCatalogAllExercisesHaveValidEnums` — assert 每条 Exercise 的 enum 字段都是有效 case (Codable 自动验)
- `previewCatalogCoversAllExerciseTypes` — assert {.mainLift, .mainLiftVariation, .accessory} 都至少有 1 条
- `previewCatalogCoversAllLiftFamilies` — assert mainLift 那 3 条 LiftFamily 是 {.squat, .bench, .deadlift}

#### 6. spec 020 CHECKLIST.md happy path 不破

15 步 manual happy path(教练 demo)走完仍 100% 通过。Step 4 accessory selector 现在显示更多动作 — 视觉差异是 expected,不算 regression。

#### 7. 扩展 CoreModels 三个 enum(用户 2026-05-12 决策 B 路径 — 1:1 with xlsx)

| 文件 | 改动 |
|---|---|
| `Modules/CoreModels/Sources/CoreModels/Enums/Equipment.swift` | 4 → 9 cases(加 `.cable` / `.band` / `.kettlebell` / `.specialtyBar` / `.other`,raw value 全 lowercase snake_case 同现有 pattern) |
| `Modules/CoreModels/Sources/CoreModels/Enums/MuscleGroup.swift` | 9 → 19 atomic cases(加 `.forearm` / `.hip` / `.hipFlexor` / `.adductor` / `.calf` / `.tibialis` / `.trap` / `.mobility` / `.cardio` / `.grip`) |
| `Modules/CoreModels/Sources/CoreModels/Enums/MovementPattern.swift` | 2 → 7 cases(**replace** `.push` / `.pull`,新加 `.squat` / `.horizontalPush` / `.verticalPush` / `.hipHinge` / `.horizontalPull` / `.verticalPull` / `.other`) |

raw value 完整列表见上 §Mapping tables Table C/D/E。

#### 8. Migrate `.push` / `.pull` callers(MovementPattern 整体 replace 后必做)

grep `\.push\b` `\.pull\b` 找全 callers,migrate 到 Table D 的 specific patterns。已知 surface(`grep -rn` 验过):
- `InMemoryPlanRepository.swift`: 3 条 synthetic competition lifts(留, 改 specific per Table D 注释);3 条待删 variants + 34 条待删 accessory() **不用管**(整体被 JSON 替代)
- `Modules/CoachKit/Tests/CoachKitTests/Planning/Fixtures/PlanningFixtures.swift`: ~10 处 — 按 fixture 语义改 specific(`squat` 类 fixture → `[.squat]`,`bench` 类 → `[.horizontalPush]`,`deadlift` 类 → `[.hipHinge]`,等)
- `AccessoryFiltersTests.swift` + `InMemoryAccessoryRepositoryTests.swift`: ~6 处 — 同上 + 测试 expected count 跟着 enum 变化 update

**Step 4 facet UI 自动 grow** — 已 verify `Modules/CoachKit/Sources/CoachKit/Planning/Views/AccessoryFilterSection.swift:41/62/83` 用 `MuscleGroup.allCases` / `Equipment.allCases` / `MovementPattern.allCases` 渲染 chip,加 enum case 自动出现。

**layout overflow risk**: 现 4+9+2 = 15 chips → 新 9+19+7 = 35 chips(chip 数 ~2.3×)。Step 4 视觉 sanity:Codex `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` 后跑 happy path 到 Step 4,看 chip 排列是否严重 overflow / 截断 / 换行混乱:
- 若可接受(chip 自然 wrap,功能上点得到)→ 通过
- 若严重 overflow → Codex 在 `NOTES.md` 加截图 + 简短描述,**留单独小 UI 重排 PR 处理**(类似 spec 021 的 P3 cleanup 模式),**不阻塞**本 spec 022 impl PR

### 不做什么

| ❌ 留 spec / 留 follow-up |
|---|
| **改 xlsx** — 教练 source of truth,只读 |
| **改 `Exercise` model** — 现有 10 字段够 V0 用;xlsx 多余字段(stance/grip/tempo/pause-pos/base/其他修饰/来源/备注)V0 不进 model |
| **真实 backend 接入 (`BackendPlanRepository`)** — V0.1+ |
| **改 spec 005-007 / 011 / 020 / 021 已合 view 内部** — 仅本 spec 范围 surfaces:`InMemoryPlanRepository.swift` / 新 `Resources/exercise-catalog-v2.json` / 新 `PreviewCatalogV2Tests.swift` / `Package.swift` resources 声明 / 现有 accessory test 数字 update |
| **改 ADR / PRD / coach-planning.md** — 不动设计层 |
| **学员端 view** — V0.1 起 |
| **import 前添加 v2 增量更新 pipeline**(教练后续再审追加新动作的支持)— V0.1+ 起新 spec |

## 技术要求

### Mapping tables(Codex 严格按这些跑 Python 脚本)

#### Table A: 大标签 → ExerciseType + isCompetitionLift

| xlsx 大标签 | Swift `ExerciseType` | `isCompetitionLift` | 备注 |
|---|---|---|---|
| 主项及变式 | `.mainLiftVariation` | `false` | 113 条全归 mainLiftVariation,**不**跨 mainLift(后者由 §做什么 #2 syntheticCompetitionLifts 提供 3 条) |
| 辅助项 | `.accessory` | `false` | 224 条 |
| 热身 | `.accessory` | `false` | 39 条;V0 同 accessory 处理(Step 4 会一起出现,这是 V0 lossy compromise,V0.1+ 加 `.warmup` 类型时再改) |
| 体能 | `.accessory` | `false` | 28 条;同上 |
| 举重 | `.accessory` | `false` | 16 条 |
| 大力士 | `.accessory` | `false` | 14 条 |
| 其他 | `.accessory` | `false` | 1 条 |

#### Table B: 细标签 → LiftFamily(只对 `主项及变式` 大标签 有效)

| xlsx 细标签 | Swift `LiftFamily` |
|---|---|
| 深蹲 | `.squat` |
| 卧推 | `.bench` |
| 硬拉 | `.deadlift` |
| 其他细标签 + 非主项及变式 | `nil` |

#### Table C: 器械 → Equipment(1:1,xlsx 9 → Swift 9 after enum 扩展)

| xlsx 器械 | Swift `Equipment` | rawValue | 备注 |
|---|---|---|---|
| 杠铃 | `.barbell` | `barbell` | 现有 |
| 哑铃 | `.dumbbell` | `dumbbell` | 现有 |
| 器械 | `.machine` | `machine` | 现有 |
| 自重 | `.bodyweight` | `bodyweight` | 现有 |
| 绳索 | `.cable` | `cable` | **新增**(独立于 machine,龙门架 / 绳索类) |
| 弹力带 | `.band` | `band` | **新增**(free 资源,跟 bodyweight 不同 friction profile) |
| 壶铃 | `.kettlebell` | `kettlebell` | **新增**(free weight 但跟 dumbbell 操作模式不同) |
| 特殊杆 | `.specialtyBar` | `specialty_bar` | **新增**(SSB / trap-bar / cambered / 弯杆) |
| 其他 | `.other` | `other` | **新增**(fallback) |

#### Table D: 动作模式 → MovementPattern(1:1 replace,xlsx 7 → Swift 7 after enum **重写**)

| xlsx 动作模式 | Swift `MovementPattern` | rawValue | 备注 |
|---|---|---|---|
| 蹲 | `[.squat]` | `squat` | **新增**(MovementPattern.squat 跟 LiftFamily.squat 同名但不同 namespace) |
| 水平推 | `[.horizontalPush]` | `horizontal_push` | **新增** |
| 垂直推 | `[.verticalPush]` | `vertical_push` | **新增** |
| 髋铰链 | `[.hipHinge]` | `hip_hinge` | **新增** |
| 水平拉 | `[.horizontalPull]` | `horizontal_pull` | **新增** |
| 垂直拉 | `[.verticalPull]` | `vertical_pull` | **新增** |
| 其他 | `[.other]` | `other` | **新增**(warmup / mobility / cardio 等不规整 pattern) |

> **Migration**: 现 `.push` / `.pull` **整体替换**。callers grep ~18 处:
> - `InMemoryPlanRepository.swift`: 3 条 synthetic competition lifts(留,migrate per 下表)+ 3 条待删 variants + 34 条待删 accessory() — **删的 37 处不用管,整体被 JSON 替代**
> - `PlanningFixtures.swift`: ~10 处 — 按 fixture 语义改 specific pattern
> - `AccessoryFiltersTests.swift`: 3 处 — 同上
> - `InMemoryAccessoryRepositoryTests.swift`: 3 处 — 同上 + 测试 expected count update
>
> **Synthetic competition lifts 的新 pattern**:
> - `竞技深蹲`: `[.squat]`
> - `竞技卧推`: `[.horizontalPush]`
> - `竞技硬拉`: `[.hipHinge]`

#### Table E: 主肌群 → MuscleGroup(1:1 atomic + multi-element composites,xlsx 21 → Swift 19 atomic after 扩展)

| xlsx 主肌群 | Swift `[MuscleGroup]` | rawValue | 备注 |
|---|---|---|---|
| quad | `[.quad]` | `quad` | 现有 |
| hamstring | `[.hamstring]` | `hamstring` | 现有 |
| shoulder | `[.shoulder]` | `shoulder` | 现有 |
| chest | `[.chest]` | `chest` | 现有 |
| core | `[.core]` | `core` | 现有 |
| back | `[.back]` | `back` | 现有 |
| glute | `[.glute]` | `glute` | 现有 |
| arm-bicep | `[.biceps]` | `biceps` | 现有 |
| arm-tricep | `[.triceps]` | `triceps` | 现有 |
| arm-forearm | `[.forearm]` | `forearm` | **新增** |
| hip | `[.hip]` | `hip` | **新增**(髋关节活动度,与 glute 区分) |
| hip-flexor | `[.hipFlexor]` | `hip_flexor` | **新增** |
| adductor | `[.adductor]` | `adductor` | **新增**(内收肌) |
| calf | `[.calf]` | `calf` | **新增** |
| tibialis | `[.tibialis]` | `tibialis` | **新增**(胫前肌) |
| trap | `[.trap]` | `trap` | **新增**(斜方肌) |
| mobility | `[.mobility]` | `mobility` | **新增**(关节活动度,热身专用语义) |
| cardio | `[.cardio]` | `cardio` | **新增**(心肺,体能专用) |
| grip | `[.grip]` | `grip` | **新增**(握力) |
| full-body | `[.core, .back, .quad]` | — | **保留 multi-element**(复合,不加 enum case) |
| post-chain | `[.back, .hamstring, .glute]` | — | **保留 multi-element**(复合,不加 enum case) |

#### Table F: name 字段

`Exercise.name` 取 xlsx `中文` 列(已含 "卧推/比赛卧推" 这类多名,直接保留 — 学员端 search 时多名 key 都能 match;V0 demo 不需要 split)。

#### Table G: 其他 Exercise 字段

| Exercise 字段 | 来源 |
|---|---|
| `id` | UUID 由 §做什么 #3 ID scheme 生成,seq = xlsx `#` 列 |
| `mainLiftFamily` | per Table B(只对 `主项及变式` 有效;其他 nil) |
| `createdByCoachID` | `nil`(catalog 全是系统 catalog,无 coach owner) |
| `createdAt` | `Date()`(spec 实装时刻;impl PR script 用 commit ISO 时间或当时刻,不必精确) |

### Fixture loading code sketch

```swift
extension InMemoryPlanRepository {
  static func loadBundledCatalogV2() -> [Exercise] {
    guard let url = Bundle.module.url(
      forResource: "exercise-catalog-v2",
      withExtension: "json"
    ) else {
      assertionFailure("Bundled catalog v2 missing — check Package.swift resources declaration")
      return []
    }
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode([Exercise].self, from: data)
    } catch {
      assertionFailure("Bundled catalog v2 decode failed: \(error)")
      return []
    }
  }

  static func syntheticCompetitionLifts() -> [Exercise] {
    let now = Date()
    return [
      Exercise(
        id: uuid(20), name: "竞技深蹲",
        exerciseType: .mainLift, mainLiftFamily: .squat,
        isCompetitionLift: true,
        muscleGroups: [.quad, .glute], equipment: [.barbell],
        movementPattern: [.push], createdAt: now
      ),
      // 卧推 + 硬拉 同样,沿用现有 hardcode UUIDs uuid(21) / uuid(22)
    ]
  }

  // previewCatalog() 改写:
  private static func previewCatalog() -> [Exercise] {
    syntheticCompetitionLifts() + loadBundledCatalogV2()
  }
}
```

### Package.swift resources 声明

`Modules/CoachKit/Package.swift`:
```swift
.target(
  name: "CoachKit",
  dependencies: [/* ... */],
  path: "Sources/CoachKit",
  resources: [.process("Resources")]
)
```

确保 `Sources/CoachKit/Resources/exercise-catalog-v2.json` 被打包,可通过 `Bundle.module.url(forResource:withExtension:)` 找到。

### Python 脚本(impl PR 一次性,不进 CI)

`scripts/import-exercise-catalog-v2.py` 大致结构:

```python
#!/usr/bin/env python3
"""One-shot: read exercise-library-v2.xlsx → emit exercise-catalog-v2.json
matching CoreModels Exercise Codable schema. Re-run after coach edits xlsx."""
import openpyxl, json, datetime
from uuid import UUID

XLSX = '~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2.xlsx'
OUT  = 'Modules/CoachKit/Sources/CoachKit/Resources/exercise-catalog-v2.json'
NOW  = datetime.datetime.now(datetime.timezone.utc).isoformat()

# Mapping tables A-E from SPEC.md §Mapping tables
TYPE_MAP = {'主项及变式': 'main_lift_variation', '辅助项': 'accessory', ...}
EQUIP_MAP = {'杠铃': 'barbell', '哑铃': 'dumbbell', ...}
# ... etc

def make_uuid(seq: int) -> str:
    # 0xCA70 catalog signature + seq big-endian (Table 中 §做什么 #3 scheme)
    return f"00000000-0000-0000-ca70-{seq:012x}"

# Read xlsx → emit JSON array of Exercise dicts
# ...
json.dump(exercises, open(OUT, 'w'), ensure_ascii=False, indent=2)
```

(Codex 实装时按 mapping table 完整写出，本 spec 给 sketch + 关键约束。)

## 验收清单

- [ ] `Modules/CoachKit/Sources/CoachKit/Resources/exercise-catalog-v2.json` 创建,含 435 条 Exercise
- [ ] `scripts/import-exercise-catalog-v2.py` 创建,可单独跑(给定 xlsx → 重生成 JSON);**impl PR 包含**,但 **不进 CI**
- [ ] `Modules/CoachKit/Package.swift` 加 `resources: [.process("Resources")]`
- [ ] `Modules/CoreModels/Sources/CoreModels/Enums/Equipment.swift` 4 → 9 cases(per §做什么 #7)
- [ ] `Modules/CoreModels/Sources/CoreModels/Enums/MuscleGroup.swift` 9 → 19 atomic cases(per §做什么 #7)
- [ ] `Modules/CoreModels/Sources/CoreModels/Enums/MovementPattern.swift` 2 → 7 cases **replace** `.push` / `.pull`(per §做什么 #7)
- [ ] `.push` / `.pull` callers migrated(per §做什么 #8 — 3 synthetic competition lifts + ~10 PlanningFixtures + ~6 测试,共 ~18 处;删的 37 处不用管)
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` 后跑 Step 4 视觉 sanity:35 facet chips 可点 / 不严重 overflow;若 overflow → NOTES.md 加截图 + 留单独小 UI PR
- [ ] `InMemoryPlanRepository.swift` 重构:
  - 加 `loadBundledCatalogV2()` + `syntheticCompetitionLifts()`
  - `previewCatalog()` 改为 syntheticCompetitionLifts + loadBundledCatalogV2 = 3 + 435 = 438 条
  - 删 `previewAccessoryCatalog()` 和 `accessory()` helper
  - 删非竞技的 3 条 hardcoded mainLiftVariation(`暂停卧推` / `节奏硬拉` / `前蹲举`)
  - 保留 `uuid(byte:)` for student/profile fixtures
  - 保留竞技 3 条 hardcoded UUID(`uuid(20)` / `uuid(21)` / `uuid(22)`)不变
- [ ] 新 `PreviewCatalogV2Tests.swift` 6 个 @Test 全通过(per §做什么 #5)
- [ ] 现有 `InMemoryAccessoryRepositoryTests.swift` / `Step4ViewModelTests.swift` 等 hardcode count 测试 update 为 lower-bound assertion 或 fixture-derived
- [ ] `swift test --parallel` 在 CoachKit 模块跑全绿
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` iPhone 17 simulator 跑通,Step 4 accessory 选择器现在显示 ≥ 100 条
- [ ] spec 020 CHECKLIST.md 15 步 manual happy path 全过(Step 4 accessory 数量增加是 expected)
- [ ] `swiftlint lint --strict` + `swift-format lint` 通过
- [ ] F-015 红线 grep 0 命中(本 spec 不涉及 coach planning 设计层)
- [ ] `specs/022-exercise-library-v2-import/SPEC.md` 状态 `Draft` → `Done`(review approve 后,**同 impl PR 内** 改完最后一步,per AGENTS.md §交付检查清单)
- [ ] SPEC.md PR 字段填本 PR 链接(同上)
- [ ] **CLAUDE.md 项目阶段 + 下一步 表 sync**(per 2026-05-10 lesson — spec impl PR 必须同步刷主线状态文档,避免再开 follow-up sync PR);本 spec 把 catalog 升级 status 加进"当前完成态"段

## 估时(给 Codex 参考)

- Python 脚本 + mapping table 1:1 实装:2 小时(比 lossy 多一点 mapping case)
- 跑脚本 + 验证 JSON × 435 条数据形态:30 分钟
- 扩展 3 个 enum(Equipment +5 cases / MuscleGroup +10 cases / MovementPattern replace + 5 net cases):1.5 小时(改 3 文件 + 跑 enum 自验测试)
- Migrate `.push` / `.pull` callers(~18 处, 删的 37 不用管):1 小时(grep + 按 fixture 语义对应)
- `InMemoryPlanRepository.swift` 重构:1 小时
- `Package.swift` resources + `Bundle.module` loading 验证:30 分钟
- `PreviewCatalogV2Tests.swift` 新增 + 现有测试 hardcode count + .push/.pull update:2 小时
- `xcodebuildmcp build_run_sim` 验证 + Step 4 视觉 sanity check(35 chips overflow 风险检查):1 小时
- buffer:1.5 小时(enum migration grep miss / JSON Decimal encoding / Bundle.module Xcode-vs-SPM / Step 4 layout tweak)

总:**~11 小时** Codex session(原 6.5h + ~4.5h enum extension overhead per 用户 2026-05-12 决策 B 路径)

## 风险 / 待 implementer 关注

1. **JSON Date 字段 encoding**:Exercise.createdAt 是 `Date`。JSON 用 ISO 8601 string,JSONDecoder 设 `dateDecodingStrategy = .iso8601` 必须;否则 Date timestamp double / millisecond 表示不一致会导致 fixture decode 失败
2. **`Bundle.module` 在 Xcode build vs SPM build 行为差异**:SPM 自动生成 `Bundle.module` accessor;Xcode build 用 `XCConfig` 也能。若 Xcode build 找不到 resource,可能需要在 `MeetPR.xcodeproj` Build Phases 加 Copy Bundle Resources。Codex 跑 `xcodebuildmcp build_run_sim` 验证两条路径都通
3. **Codable enum 严格性**:Exercise 的 enum 字段(ExerciseType / Equipment 等)是 String raw value。JSON 里若拼错(e.g. `"main_lift_var"` 漏字符)JSONDecoder 会 throw `keyNotFound` / `dataCorrupted`。脚本输出前应自验:每个值在 enum 的 allCases.rawValue 内
4. **xlsx 主肌群多 muscle 表达**:Table E 部分映射(`full-body` / `post-chain`)产 Swift `[MuscleGroup]` 数组多元素。Step 4 filter 用 `Set.isDisjoint(with:)` 兼容多元素,无需调整 filter 逻辑
5. **既存测试 hardcode count drift**:Codex 找现 `InMemoryAccessoryRepositoryTests.swift` 等,grep `== 34` / `count == ` 之类硬编码。改成 `≥ N` 或 fixture-derived. 若不止一处 hardcode,**全部** update,**不要** 漏 1 处导致 CI red
6. **Step 4 facet UI chip 数量从 15 涨到 35** — `AccessoryFilterSection.swift:41/62/83` 用 `*.allCases` 自动 grow,**不需要写 UI 代码**;但 35 chips × 3 facet 行的 layout 在 iPhone 17 simulator 上可能 wrap 到第 3-4 行 / 部分截断 / 与下方动作列表挤压。Codex `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` 后跑 happy path 到 Step 4 验视觉:可接受 → 通过;严重 overflow → NOTES.md 加截图 + 留单独小 UI PR(类似 spec 021 P3 cleanup),**不阻塞**本 spec impl PR
7. **JSON 文件大小 + repo overhead**:435 条 × 17 字段(实 10 进 model)估 ~80-150KB JSON。可接受。`.process("Resources")` 会让 Xcode encode JSON 进 .app bundle 资源,小 overhead
8. **F-015 grep 自检**:`4 周扫视态 / 4 周宏观视图 / 波形图 / 变式矩阵 / 密度条 / specificityBucket / waveformValue / accessoryDensityBucket / isDeloadWeek / Excel grid` 全部 0 命中(本 spec 不涉及 coach planning 设计层)

## 上游 / 下游

- **上游**(本 spec 落地依赖):
  - 已合 [spec 005-007](../) coach planning Step 0-7 + spec 020 V0 demo orchestration(Step 4 accessory 选择器 + InMemoryPlanRepository 已就位)
  - 教练 xty 审完 xlsx(2026-05-12 全过 + 一字未改 — α 路径)
- **下游**(本 spec 落地后启用):
  - V0 demo 教练规划体感大幅升级,TestFlight 内测见 ~250 条 accessory selection
  - **V0.1+ 起 backend `BackendPlanRepository`**(F-025 触发;接 backend 的 V0.1+ spec):JSON fixture 思路可复用(本机 fallback / offline mode)
  - **V0.1+ 起新 spec 加 ExerciseType `.warmup` / `.conditioning`** —— 现 spec 把热身/体能归 `.accessory`(Step 4 一起出现),V0.1+ 拆类型让 Step 4 / 学员端按"热身 / 主项 / 辅助 / 体能 / 缓和"分屏
  - **V0.1+ 起教练 xlsx 增量审追加 spec**:支持后续 v3 / v4 增量更新,不重新整个 import

## 修订记录

- 2026-05-12: 创建(Draft)。Claude 起草, Codex 接力实装。教练 xty 同日全过 xlsx 审核(α 路径)解锁本 spec → impl pipeline。
- 2026-05-12 amendment(B 路径 + 435 fix):
  - 用户决策"V0 现在就 1:1 扩 enum,不接受 lossy mapping" — Mapping tables C/D/E 全部改 1:1(Equipment 4→9 / MovementPattern 2→7 replace / MuscleGroup 9→19 atomic + 2 composites multi-element)
  - §做什么 加 #7(扩 3 个 enum)+ #8(migrate `.push`/`.pull` callers ~18 处 + Step 4 facet UI 自动 grow + 35 chips layout overflow risk 留 Codex sanity check)
  - §不做什么 删除"扩 enum"defer line
  - 估时 ~6.5h → ~11h(+4.5h enum migration overhead)
  - 用户产品诉求:Step 4 facet 跟 xty xlsx 1:1 对应(教练直接搜壶铃 / 弹力带 / 绳索 / 特殊杆 不用心算映射)
  - **Codex 在 feat/022-... 分支 QUESTIONS.md Q1 catch 到事实错误**:原 SPEC 写 "436 条" 实际是 xlsx max_row(含 header);data row 是 **435 条**(`#` seq 1-435,`_meta!B4 总条数=435`)。本 amendment 把所有 436 → 435 / 439 → 438(synthetic 3 + imported 435 = total 438)/ UUID 末 hex `01B4 → 01B3`。Q1 RESOLVED — Codex 可继续 impl
