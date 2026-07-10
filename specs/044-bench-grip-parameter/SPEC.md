# 044 — 卧推握距作为计划参数(grip parameter)

- **状态**:Draft（待 David 通审 + 拆 PR）
- **PR**:(待填)
- **来源**:2026-06-26 David 决策（本文件 §背景）。产品决策待沉淀为 `~/Brain/wiki/projects/MeetPR/product-decisions/0XX-bench-grip-parameter.md`。
- **基线**:本 spec 基于 **post-043 main**(见 §依赖与合并顺序)。所有 id / 现名以届时 catalog 为准,implementer 须按 id 复核。

## 背景

握距(宽/中/窄)此前被编进卧推动作名,导致同一动作因握距裂成多条、库内不齐。决策:**握距不进动作名,改成计划时选择的参数,默认中握**。范围 = **所有杠铃卧推(主项 + 全部变式)**。采用 **approach A(加法式)**:加字段 + 标 deprecated,**不删行、不 remap 线上 `plan_exercises`**。

## 目标

_所有杠铃卧推动作在选择器里只暴露无握距名,握距(`BenchGrip`,默认 `standard`)作为 `plan_exercise` 上的参数,贯穿 教练计划 → 学员执行 → 导入;老计划仍显示其原始(含握距)动作名,不被改写。_

## 范围

### 做什么

1. **复用** CoreModels 既有 `BenchGrip { narrow, standard, wide }`(raw `"narrow"/"standard"/"wide"`,onboarding 已在用)。展示:`narrow=窄握 / standard=中握 / wide=宽握`。**不新建枚举、不引入 "medium"**。默认 = `standard`(中握)。
2. **Exercise(CoreModels)新增三字段**:
   - `supportsGrip: Bool`(默认 `false`)——出现握距选择器的标记,**物化**到 catalog/API。
   - `deprecated: Bool`(默认 `false`)——选择器过滤。
   - `gripVariantOf: GripVariantRef?` = `{ baseExerciseId: UUID, grip: BenchGrip }`——deprecated 握距变体 → "基底 + 隐含握距",**仅供导入解析用**(见 §导入)。
3. **`supportsGrip` 的取值规则(物化,非运行时派生 UI)**:对每个满足 `mainLiftFamily==bench && equipment ∋ barbell` 的条目置 `true`(含**提升后的** `1b4 杠铃卧推`),外加合成的 `比赛式卧推`。= post-043 下 **26+ 条**杠铃卧推主项+变式(scope A 全集),不是只有归并基底。deprecated 变体同样满足谓词 → `supportsGrip=true`,但被 `deprecated` 过滤出选择器。
4. **计划数据加 `grip: BenchGrip?`**:`PlanExercise` / `DraftPlanExercise` / `StudentPlanExercise`(学员投影里的嵌套类型,**非** `StudentPlanView` 顶层)/ backend `plan_exercises` 列。
5. **握距进名条目的归并**(规则见 §合并规则;完整清单由 implementer 生成、David merge 前审):凡名字把握距编进去的杠铃卧推 → 标 `deprecated` 并填 `gripVariantOf`。**无改名**。
6. **基底属性修正**:`1b4 杠铃卧推` 由 `accessory/null` 提升为 `main_lift_variation/bench`(成为平板基底)。
7. **选择器 UI**(iOS CoachKit 计划 + web 计划编辑器):`supportsGrip && !deprecated` 的动作出现握距分段(窄/中/宽),默认中握。
8. **学员链路**:grip 流经 `PlanToStudentProjection`、`BackendStudentPlanRepository`、`StudentPlanExercise`,学员执行视图显示该握距。

### 显示规则(B-r2-3 — 闭合三分支)

渲染任一 plan_exercise 的动作名:
1. `exercise.deprecated == true` → 显示 `exercise.name` **原名**(老计划历史;不读 grip 列、不加后缀)。
2. `exercise.supportsGrip == true`(且非 deprecated)→ 显示 `exercise.name · effectiveGrip`,`effectiveGrip = planExercise.grip ?? .standard`。**始终带后缀(含中握)**。
3. 否则 → `exercise.name`。

→ 老计划引用 `058 窄握卧推`(deprecated,grip 列 NULL)走分支①,仍显示 **窄握卧推**,历史处方不被改坏;**零 remap、零删行、零 effective-grip 反推**。

### 导入 DSL / 别名(grip-aware)

教练 Excel 写"窄握卧推/窄推/暂停宽握卧推/弹力带窄推"→ 命中 deprecated 条目(名 / `ExerciseAliasTable` 别名)→ 解析成 `gripVariantOf.baseExerciseId` + `gripVariantOf.grip`,新计划存 **基底 + grip**(不再引用 deprecated 条目)。

### 不做(本 spec)
- ❌ 不删任何 `exercises` 行,不 remap 线上 `plan_exercises`。
- ❌ 不动 2 条 accessory `窄距卧推(敞开式/靠近式)`(372/373;"敞开/靠近"是动作身份)。
- ❌ 不推广到深蹲杠位 / 硬拉站距(同思路,另开 spec)。
- ❌ 哑铃/器械卧推不带握距(`supportsGrip=false`)。
- ❌ 无握距进名的杠铃卧推变式(链条/地板/上斜/下斜/反握/死点/spoto暂停…)**只获得握距选择器(默认中握)**,无归并、无改名。

## 合并规则(替代手列映射表 — David 2026-06-26 裁决 A)

握距进名条目**不在 SPEC 手工穷举**(catalog 命名不统一 握/距/推、基底名对不上、弹力带簇 equipment 乱标,手列必漏),改为**定规则 + implementer 生成清单交 David merge 前审**。

**规则**:`mainLiftFamily==bench && equipment∋barbell` 且**名字把握距编进去**的条目 → `deprecated=true`,`gripVariantOf = { 无握距基底 id, 解析 grip }`,**无改名**。
- 握距 token 解析:`超宽握/宽握/宽距/宽推 → wide`;`中握/中距 → standard`;`窄握/窄距/窄推 → narrow`。
- 基底 = 去握距 token 后对应的无握距杠铃卧推。**基底名不一定是纯字符串相减**(`中握卧推`→`杠铃卧推`(1b4)、`中握拉森卧推`→`拉森卧推（无腿直腿卧推）`(06c)),故由 implementer 提名、David 确认。

**实装生成 + 审核(merge 前 gate)**:implementer 在 **post-043 catalog** 跑脚本产出:
1. 完整候选合并清单(变体 id/名 → 提名基底 id/名 → 解析 grip),覆盖 握/距/推 全部写法;
2. **疑难项单列交 David 裁定**:
   - 弹力带簇 `053 弹力带杠铃卧推`(band)/`054 弹力带中握卧推`(band)/`04de 弹力带窄推`(barbell+band)——是否三合一为单个带式卧推基底 + 握距?equipment 标注是否一并修正?
   - 无现成无握距基底、需新建 or 复用的;
   - `超宽握` 归 wide 是否可接受;
3. David 签字后该清单即权威映射,落进 catalog/migration。

> 已确认的干净示例(供脚本对照):`暂停宽握卧推`(05e)→`暂停卧推`(057)+wide;`节奏宽握卧推`(064)→`节奏卧推`(063)+wide;`宽/窄握 spoto`(071/06f)→`spoto 卧推`(070);`中/窄/超宽握·宽距 卧推`(05d/058/05a/065)→`杠铃卧推`(1b4,提升后)。`1b4` 当前 accessory/null,本 spec 提升为 main_lift_variation/bench。

## 跨仓 wire contract(B7 — PR1 先固定)

- `GET /exercises`(及 catalog 同步):每条返回 `deprecated`、`supports_grip`、`grip_variant_of: { base_exercise_id, grip } | null`。iOS 端直接 decode 进 `Exercise`(当前 `ExercisesResponseDTO` 返回 `[Exercise]`,无单独 `ExerciseDTO`);backend/web 用 `ExerciseResponse`。
- `plan_exercises` 行 / `PlanExercise` Response/Create/Patch:`grip: "narrow"|"standard"|"wide" | null`,DTO 用 typed `BenchGrip?`(对齐 `PlanKind`/`IntensityMode`)。**PATCH absent(不带键)= 不改;null = 显式清空 → 回落 `.standard`**。
- backend `CHECK (grip IS NULL OR grip IN ('narrow','standard','wide'))`。

## 依赖与合并顺序(B8)

- 044 依赖 **spec 043 已合并**:`ExerciseAliasTable.swift` + 043 的 bench coverage 条目。043 的 `04de 弹力带窄推`(`["barbell","band"]`,bench)是握距进名条目,纳入 §合并规则 生成清单(与 `053/054` 弹力带簇一起交 David 裁定),否则 grip-in-name 重入 catalog。
- 顺序:**043 全链路合 main → 044 PR1(backend)→ PR2(iOS)→ PR3(web)**。044 catalog json 须 rebase 到含 043 的 catalog(计数届时复核)。

## 技术要求

### Schema / 数据
- **backend migration**(新号,按 staging 实际 head 定,**勿复用 0019/0022**;幂等 `ADD COLUMN IF NOT EXISTS`):
  - `plan_exercises` 加 `grip TEXT CHECK (grip IS NULL OR grip IN ('narrow','standard','wide'))`。
  - `exercises` 加 `deprecated`、`supports_grip`、`grip_variant_of`(列或等价表示)。
  - `UPDATE` 标 10 条 deprecated + 填 grip_variant_of;置基底 `supports_grip=TRUE`;提升 `1b4` 的 type/family;INSERT 新基底 `弹力带卧推`。**不删行、不改 exercise_id**。
- **catalog json**(`exercise-catalog-v2.json`):同步上述;`PreviewCatalogV2Tests` 等计数同步(注意与 043 合并后的计数)。

### iOS
- `CoreModels`:`Exercise` 三字段 + `GripVariantRef`;复用 `BenchGrip`;`PlanExercise`/`DraftPlanExercise`/`StudentPlanExercise` 加 `grip`。
- `CoachKit`:握距分段控件(supportsGrip&&!deprecated)+ 草稿/发布映射 + `PlanningDisplay.gripName` + 三分支显示 + picker 过滤 deprecated + 导入解析(deprecated→base+grip)+ `PlanToStudentProjection` 透传 grip。
- `Networking`:`BackendStudentPlanRepository` 透传 grip;`Exercise`/`PlanExercise` DTO 新字段。

### web(`apps/meetpr-plan-web`)
- 握距分段(默认中握)+ 三分支显示 + 导入 DSL 解析握距 + picker 过滤 deprecated;与 iOS 别名表/枚举一致。

## 验收
- [ ] 选到任一 `supportsGrip&&!deprecated` 杠铃卧推(含 链条/地板/上斜/下斜/反握/spoto/暂停/节奏/拉森/比赛式卧推)出现握距分段,默认中握;哑铃卧推、深蹲、硬拉无握距控件。
- [ ] **遍历 catalog 断言**:所有 `supportsGrip&&!deprecated` 出现控件;所有 `deprecated` 不出现(非只列例子)。
- [ ] 计划保存后 `plan_exercise.grip` 落库;学员执行视图显示该握距。
- [ ] 非 deprecated 基底显示带后缀(含中握):`杠铃卧推 · 中握`。
- [ ] 老 `plan_exercise` 引用 `058 窄握卧推`(grip=NULL)仍显示 **窄握卧推** 原名,exercise_id 不变。
- [ ] 审核清单内所有 deprecated 条目不进任何选择器;无重复基底(含"无腿卧推"/弹力带簇)。
- [ ] 导入"窄握卧推/窄推/暂停宽握卧推/弹力带窄推"→ 解析成 base + 对应握距。
- [ ] migration 幂等;`plan_exercises.grip` CHECK 生效;`exercise_id` 引用不变。

## 测试
- iOS:`BenchGrip` round-trip;`PlanningDisplay.gripName`;显示三分支(deprecated 原名 / 基底+grip / 普通);picker 过滤 deprecated;遍历 catalog 断言 supportsGrip↔控件;导入解析(含 弹力带窄推→base+narrow);`PlanToStudentProjection` grip 透传。
- backend:migration 幂等 + grip CHECK + `/exercises` 新字段 + DTO 序列化。
- web:选择器 + DSL 解析 + deprecated 过滤单测。

## 参考
- 相关 ADR:[ADR-005 iOS 架构](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md)、[ADR-004 后端选型](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md)
- 既有类型:`Modules/CoreModels/Sources/CoreModels/Enums/BenchGrip.swift`、`Entities/Plan/PlanExercise.swift`、`Entities/Plan/StudentPlanView.swift`(grip 落其内嵌 `StudentPlanExercise`,非顶层)
- 相关:`Modules/CoachKit/Sources/CoachKit/Planning/Import/ExerciseAliasTable.swift`、`Planning/PublishProjection/PlanToStudentProjection.swift`、spec 043 coach-plan-import
