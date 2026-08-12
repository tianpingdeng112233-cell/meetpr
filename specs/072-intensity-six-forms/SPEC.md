# SPEC 072 — 学员端强度六形式跟进(解码 + 止血 + 周几对齐)

- Status: InReview(David 2026-08-12 拍板开工;简报评审记录见 scratch/2026-08-12-web-followup-task-list.md)
- 班车:1.0(19),base = release/1.0
- 背景:backend spec 034 v2.1(迁移 0058,已部署 staging)让教练网页端能写六种强度形式 + 独立重量列;
  旧字段是写入时有损投影,iOS 现在把投影当真值显示 → 教练写 A 学员看到 B。
  契约侦察全文:scratch/2026-08-12-web-to-ios-followup-recon.md。

## 1. 目标

1. **E1 解码与忠实渲染**:学员端读懂六形式处方,显示忠实的值(过渡期朴素文本即可,视觉换装另卡)。
2. **E2 止血**:重量建议引擎与记录预填不再使用投影伪造值;不静默编数。
3. **E3 周几对齐**:按 `anchor_weekday` 推「教练推荐日期」,消除 web/iOS 周几不一致。
4. 旧计划(全部 `load_mode == null`)行为零变化。

## 2. 契约事实(backend 已上线,以此为准)

`GET /plans/:id` 每个 set 新增 9 字段(JSON):

| 字段 | 类型 | 说明 |
|---|---|---|
| `load_mode` | string \| null | `pct` / `rpe` / `rir` / `weight_range` / `rpe_range` / `fixed_weight`;null = 老行 |
| `target_pct` | string(".1") \| null | 20.0–110.0 |
| `target_rpe` | string(".1") \| null | 1.0–10.0 |
| `rir_target` | **number**(int)\| null | 0–9,⚠️唯一 number,其余值是 string |
| `rpe_low` / `rpe_high` | string \| null | low < high |
| `weight_low` / `weight_high` | string(".2") \| null | low < high |
| `target_weight` | string(".2") \| null | 独立重量列 |

- 旧字段 `intensity_mode`(`weight`\|`rpe`)+ `target_value` **永远在、永不为 null**(投影),wire 上不会出现新的 mode 字符串,现有严格解码不会崩。
- **`load_mode != null` 时不得信任旧字段**:pct → 查表伪 RPE;区间 → 只剩下限;任一模式带 `target_weight` → 投影只剩重量。
- **`load_mode == null` 的老纯 RPE 行没有新字段表示**(`target_rpe` 为 null),必须保留 legacy 路径:按 `intensity_mode`/`target_value` 解释。
- 同一动作各组 `load_mode` 可异构;单值模式(pct/rpe/rir)允许稀疏:该组强度值 null 但 `target_weight` 有值。
- `fixed_weight`:值在 `target_weight`;`weight_range` 禁 `target_weight`。
- plan 级新增 `anchor_weekday`: number \| null,1=周一…7=周日,含义「D1 落在周几」,纯展示元数据,server 不发日期。

## 3. 实装范围

### E1 解码 + 投影 + 过渡渲染
- `Modules/Networking/.../PlanDTOs.swift` `PlanSetDTO`:增解上述 9 字段(全 optional,string 值走现有 decodeDecimal 的宽松路径);`PlanDTO` 增解 `anchor_weekday`。旧字段解码保持不动。
- `Modules/CoreModels` `PlanSet` / `StudentPlanView.PrescribedSet`:拆掉 weight XOR rpe——`weightKg` 独立承载(fixed_weight/target_weight/legacy weight 归此),另加强度锚(建议 enum:`pct(Decimal)`/`rpe(Decimal)`/`rir(Int)`/`rpeRange(Decimal,Decimal)`/`weightRange(Decimal,Decimal)`;legacy rpe 行归 `.rpe`)。**StudentPlanView 有本地缓存 Codable 往返:老缓存 payload 必须还能解开(新字段 optional + 默认),新 payload round-trip 测试。**
- 投影两处同改(逻辑重复):`Modules/StudentKit/.../BackendStudentPlanRepository.swift:313-324` 与 `Modules/CoachKit/.../PlanToStudentProjection.swift:92-104`。`load_mode == null` → 现行为不变;非 null → 按新字段忠实映射,忽略旧字段。
- 过渡文本渲染(朴素、忠实,别做视觉设计):
  - `StudentFormatting.prescribed`:`72.5% × 5`、`RPE 8–9 × 5`、`165–175kg × 5`、`170kg × 5 @RPE9`(双锚)、稀疏组 `150kg × 5`;消灭「-kg x 5」——无重量有强度锚时显示锚。
  - TodayWorkout hero(`TodayWorkoutScreen.swift:574-611` + `TodayWorkoutPresentation.swift:150`):大数字位无重量时显示强度锚文本;**「目标 RPE 0/10」禁止出现**——无 RPE 目标时该块隐藏或显示对应锚(pct/RIR/区间)。
  - 历史行/日详情/汇总行沿用 `StudentFormatting` 统一格式。

### E2 止血
- `TodayWorkoutViewModel+DraftBuilding.swift`:`load_mode == 'pct'` 时**不用投影 RPE 算建议**;有该动作 e1RM → 建议重量 = pct × e1RM(复用现有 e1RM 建议管线,来源标注沿用现有 UI);无 e1RM → 走现有「暂无建议」降级(文案沿用现行句式,新文案等 D4 稿)。`rir`/区间模式 → 降级,不硬算。
- `SetEntrySheet.swift:66-74` 预填:只预填忠实值——`target_weight`/fixed_weight 预填重量;pct 有 e1RM 可预填换算重量;其余不再落 20kg 空杆底。记录「实际 RPE」输入的默认值行为(legacy `?? 8`)不在本卡范围,维持现状。
- `RestDefaults.seconds(forRPE:)` 派生(`DraftMapping.swift:100`/`PlanPublishAssembler.swift:156`):rpe_range 取下限喂入;pct/rir/fixed_weight 传 nil 走默认,不喂伪 RPE。

### E3 周几对齐
- `BackendStudentPlanRepository.swift:327-332` 日期推导:`anchor_weekday` 为 null → 现状不变(D1 = startDate);非 null → **D1 = startDate 起(含当天)第一个 weekday == anchor 的日期**,后续沿用 `(week-1)*7 + (dayOfWeek-1)` 偏移。日历口径沿用该文件现行 UTC gregorian,不新增第四种日界线口径。
- 下游(DashboardWeekCalendar 周几表、DashboardPrimaryAction、TrainingCalendarLogic)全部吃 `scheduledDate`,基准修对即全对,无需逐处改。

## 4. 约束

- **不碰**:教练端编排工作台写路径(E4 模式锁定编辑是另一张卡)、completion/settlement(071 已对齐)、`target` 字段(休眠)、`viewed_at`(P2 另卡)、任何新依赖。
- 守仓内 `.swiftlint.yml` + `swift-format --strict`。
- SPM 单测跑 macOS host:纯逻辑测试(解码/投影/推导/建议 gating)别包 `#if os(iOS)`,否则静默不执行。

## 5. 验收标准

1. 单测 fixture 全覆盖:六形式各一 + 双锚 + 稀疏 + 异构组 + legacy 老行(纯 RPE / 纯重量)+ 老缓存 payload 解码 + 新 payload round-trip。
2. 投影测试:`load_mode != null` 时旧字段被忽略(pct 行不得产出 RPE 显示);legacy 行为逐项与现状一致。
3. 建议引擎测试:pct+有 e1RM → 按百分比换算;pct+无 e1RM → 降级;rir/区间 → 降级;rpe/legacy → 现行为不变。
4. anchor 推导测试:null / anchor==startDate 周几 / anchor 偏移若干天 三例,含跨周。
5. 渲染快照或字符串断言:上述 §3 E1 的格式表逐条;「目标 RPE 0/10」与「-kg x 5」在新形式下不再出现。
6. `swift test` + `build_sim`/`test_sim` 全绿;swiftlint --strict 零告警。
