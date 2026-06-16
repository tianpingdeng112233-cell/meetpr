# 040 — 教练设组间休息 + 学员端兜底自动计时

- **状态**:Ready
- **PR**:TBD(后端 1 PR + iOS 1 PR)
- **来源**:David dogfood 2026-06-15 #4「休息倒计时可以通过教练设定,没设定就根据 auto timer 来制定」。落地形态 office Q 2026-06-16:**A 折中 = 每动作一个默认值(预填 auto,可改)+ 可展开「逐组单独设」**,数据按组存。
- **跨仓**:`MeetPR`(iOS)+ `MeetPR-backend`。后端先合并部署,iOS 再合。

## 目标
学员每完成一组弹休息倒计时,现在长度是 app 按**这组 RPE 自动算**的(`RestTimerPolicy`:nil→3min,<7→2min,7–8.5→3min,9+→4min)。让教练在排计划时能设休息时间;没设就回落到这个自动规则。

落地后教练看到啥(排计划 Step 5 动作设置卡,在 组数/次数/强度 之下新增):
```
组间休息   3:00            ← 单个默认值,预填 auto(按本动作 RPE 算),可改
□ 逐组单独设               ← 关:所有组用上面这个值
                              开:展开 setCount 行,每组一个休息选择器(预填默认值)
  第1组  2:00
  第2组  3:00
  …
```
学员端:完成一组 → 若该组有教练设的休息值用它,否则按现有 RPE 自动算。

## 共享默认规则(关键架构点)
现 `RestTimerPolicy.restSeconds(forRPE:)` 在 StudentKit,注释写"student-only、不得他处出现"。David 的决策让**同一规则成为教练端预填默认值 + 学员端兜底**两用 → 升格为跨角色。
- 在 **CoreModels** 新增角色中立纯函数:`public enum RestDefaults { public static func seconds(forRPE rpe: Decimal?) -> Int }`(同一张表:nil→180,<7→120,<9→180,9+→240)。
- StudentKit `RestTimerPolicy.restSeconds(forRPE:)` 改为转发到 `RestDefaults.seconds(forRPE:)`(保留现有 StudentKit API 调用点,只换实现);更新那条"不得他处出现"注释为"规则在 CoreModels.RestDefaults,两端共用"。
- CoachKit 预填用 `RestDefaults.seconds(forRPE:)`。三处共用一张表,零重复。

## 数据模型
- **CoreModels `PlanSet.swift`**:加 `public let restSeconds: Int?`(nil=未设)。`CodingKeys` 加 `restSeconds`(int,不走 decimal-string);`init(from:)` `decodeIfPresent(Int.self) `;memberwise init 默认 `restSeconds: Int? = nil` 保持现有构造点兼容。
- **CoreModels `StudentPlanView.swift` `PrescribedSet`**:加 `public let restSeconds: Int?`(学员收到的每组休息);CodingKeys + decodeIfPresent + 默认 nil。
- **CoachKit `DraftSetSpec.swift`**:加两个字段——
  - `public var restSeconds: Int?`(本动作的默认休息,nil=未设=用 auto 默认)
  - `public var restSecondsPerSet: [Int]?`(nil=不逐组,所有组用 `restSeconds`;非 nil=长度应==setCount,逐组各自值)
  扩 `init` / `CodingKeys` / `init(from:)`(两个都 `decodeIfPresent`)/ `encode(to:)`。Int 用普通 encode,数组用普通 encode。

## 范围
### 后端(MeetPR-backend)
- **migration `db/migrations/0018-add-rest-seconds-to-plan-sets.sql`**(用 0018,不要 0017——0017 被 spec 039 占):`ALTER TABLE plan_sets ADD COLUMN rest_seconds INT;`(nullable;nil=学员端回落 auto)。
- `src/db/types.ts` `PlanSetsTable`:加 `rest_seconds: number | null`。
- `src/routes/plans/schemas.ts` `PlanSetBodySchema`:加 `rest_seconds: z.number().int().min(0).max(3600).nullable().optional()`。
- `src/routes/plans/index.ts`:plan_sets `.insertInto('plan_sets').values({...})`(line ~814)加 `rest_seconds: body.data.rest_seconds ?? null`;PATCH `/sets/:setId`(line ~860+)加 `if (body.data.rest_seconds !== undefined) patch.rest_seconds = body.data.rest_seconds;`。
- `src/routes/plans/serialization.ts`:`PlanSetResponse` 接口(line ~40)加 `rest_seconds: number | null`;`toPlanSet`(line ~135)map `rest_seconds: row.rest_seconds`。
- **学员投影**:确认学员侧拿计划的端点/序列化(学员收 `PrescribedSet`)把 `rest_seconds` 带出去——搜学员 plan 投影里 set 的序列化,补 `rest_seconds`。若学员复用同一 `toPlanSet`,则上一步已覆盖;否则补对应处。
- 自检:`npm run lint` + `npm test`(看 package.json 脚本)。

### iOS — Networking(MeetPR)
- 计划相关 set DTO(教练 create/patch set 的请求体 + 计划 fetch 响应里的 set;学员 plan 响应里的 prescribed set):各加 `restSeconds: Int?`,CodingKeys 对齐后端 `rest_seconds`,解析 `decodeIfPresent`。搜 Networking/DTO 里 `targetReps`/`set_number`/`PrescribedSet` 相关 DTO 定位。

### iOS — 教练排计划 UI(CoachKit)
- `ExerciseSetEditorCard.swift`:在 组数/次数/强度 输入之下加:
  1. **组间休息** 单值选择器:复用 `PlanningCountPicker`(秒,range 30...600,step 15,显示 `m:ss`;PlanningCountPicker 是 `Binding<Double>`,用秒的 Double 桥接 + 自定义 formatStyle)。绑定 `DraftSetSpec.restSeconds`;**初值预填** = 当前 `restSeconds ?? RestDefaults.seconds(forRPE: intensityMode == .rpe ? targetValue : nil)`,即教练看到的是已经算好的默认值,可改。
  2. **「逐组单独设」** disclosure/toggle:关 → `restSecondsPerSet = nil`,所有组用上面单值;开 → 初始化 `restSecondsPerSet` 为长度 `setCount`、每项=当前单值;展开 `setCount` 行,每行 `第N组` + 一个休息选择器绑定 `restSecondsPerSet[i]`。
  3. **setCount 变化同步**:`setCount` 改动时,若 `restSecondsPerSet != nil` 则裁剪/补齐到新长度(补齐用单值或 auto 默认)。
- 卡片若超 400 行(SwiftLint),把"逐组休息"段拆成子视图(同文件 fileprivate struct 或新文件)。
- `PlanningViewModel`:`defaultSetSpec(for:)`(line ~601)新建 spec 时不用预设 restSeconds(留 nil,UI 层预填显示);发布/组装时(见下)落实际值。`normalizedSetSpec`(line ~1244)对 restSecondsPerSet 做 setCount 一致性 clamp。
- **跨周派生**:`WeekDerivation.swift` 从 W1 spec 派生 W2–W4 时,`restSeconds` + `restSecondsPerSet` **原样带过去**(休息不随强度递增变化)。补到派生/clamp 逻辑里,别丢。

### iOS — 发布展开(CoachKit)
- 草稿发布成 `PlanSet`(逐周 publishPlan 把 DraftSetSpec 展开成 setCount 个 PlanSet)时,第 i 组 `restSeconds = spec.restSecondsPerSet?[i] ?? spec.restSeconds ?? RestDefaults.seconds(forRPE: spec.intensityMode == .rpe ? spec.targetValue : nil)`。即**发布后每个 PlanSet 都带显式 restSeconds**(默认值或逐组覆盖)。找到 DraftSetSpec→PlanSet 的展开点(搜 `setCount` 展开 / publishPlan 组装 sets 处)。

### iOS — 学员端兜底(StudentKit)
- `TodayWorkoutViewModel.startRestTimer(after:drafts:)`:`let seconds = draft.prescribed.restSeconds ?? RestTimerPolicy.restSeconds(forRPE: draft.actualRPE)`。仅此一处接线(教练值优先,缺失回落自动)。**注意**:本文件同期被 spec 039 改 `persist`,039 iOS 先合,本 spec iOS 基于 039 合并后的 main。
- (可选,低优先)`RestTimerOverlay`:倒计时条加一行极小标注"教练设定 / 自动"。本期可省,省了不算缺。

### 不做
- 组间休息以外的时间(动作间/热身)——只这一个。
- 学员端改休息值持久化回后端(学员现场 +30/-30 仍是临时,不回写)。
- 教练端休息的统计/分析。

## 技术要求
- 后端先合并部署,iOS 再合;DTO 对旧数据缺 `rest_seconds` 容错(decodeIfPresent → nil → 学员回落 auto)。
- `RestDefaults` 纯函数单测(沿用现有 RestTimerPolicy 测的边界:nil/6.5/7/8.5/9)。
- 发布展开"逐组覆盖 ?? 默认 ?? auto"优先级 + WeekDerivation 带过去 + setCount 变化 clamp:各一个单测。
- CoachKit ⊥ StudentKit 边界:`RestDefaults` 放 CoreModels 两端共用,不跨 Kit 直引。
- SwiftLint strict(文件≤400/函数体≤50/参数≤5/无多尾随闭包/sorted_imports/无 `private extension`)、`xcrun swift-format --strict` 干净;后端 lint+test。

## 验收
- [ ] 后端:`plan_sets.rest_seconds` 列(migration 0018);create/patch/序列化/学员投影都带 `rest_seconds`;`npm test` 绿
- [ ] 排计划:动作卡有「组间休息」单值(预填 auto,可改)+「逐组单独设」展开逐组
- [ ] 发布后每个 PlanSet 带 restSeconds(逐组覆盖 > 默认 > auto);W2–W4 派生带过去;setCount 变化不崩
- [ ] 学员端:有教练值用教练值倒计时,无则回落 RPE 自动;旧计划(无 rest_seconds)正常回落
- [ ] `RestDefaults` 纯函数 + 发布优先级 + 派生 单测;`RestTimerPolicy` 转发到 `RestDefaults`(规则零重复)
- [ ] CoachKit ⊥ StudentKit 不破;swiftlint/swift-format strict 双绿;`MeetPR-Demo`(教练设休息)+`MeetPR-DemoStudent`(学员倒计时取值)双机手测

## 风险
1. **设计反扣**:`RestTimerPolicy` 原注释禁止规则他处出现 → 必须真的移到 CoreModels 并让 StudentKit 转发,否则两端表漂移。
2. `restSecondsPerSet` 与 `setCount` 长度一致性(改组数后)= 易漏边界,必测。
3. iOS 与 spec 039 同改 `TodayWorkoutViewModel.swift` → 本 spec iOS 在 039 iOS 合并后做。
4. `PlanningCountPicker` 是 Double 绑定;秒值用 Int 模型 → 桥接处注意取整,别引入 0.x 秒。
