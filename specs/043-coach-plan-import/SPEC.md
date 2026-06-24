# 043 — Coach 端「导入学员存量计划」(Excel 计划表 → 已发布计划)

- **状态**: Draft
- **PR**: TBD — **3 个 PR**:① iOS spec PR;② iOS impl PR(CoachKit 导入 + CoreModels/Networking/StudentKit 的 `coachNote`);③ **MeetPR-backend PR**(放宽 `plan_weeks`/`week_number` 约束 + `plan_sets.coach_note` 列 + DTO/查询透传)
- **来源**:
  - 用户真实需求(2026-06-24 brainstorm):教练加入 app 时,给学员写的计划还有 N 周没跑完,希望把**剩余部分**导进来,让学员在 app 里**继续跑**——降低教练迁移成本。
  - **V1 唯一样本** = 学员「吕子豪」的 12 周 `Monster宇力型兼备计划`(教练手写 xlsx,日历网格布局)。单教练、格式稳定,故解析器**锁定这张表的布局与简写**,不追求通用。
  - **设计修订(经 Codex review-loop 2 轮,2026-06-24)**:
    - r1:原"复用草稿 + `PlanPublishAssembler`、0 backend"被否——草稿每动作仅单个 `DraftSetSpec`、assembler 是 W1 模板克隆,装不下手调多周/逐组内容 → 改为**专用导入管线直接构造已发布实体树**,调既有 `publishPlan`。
    - r2:后端硬约束比预期多——① `plan_weeks ∈ {1,4}` / `week_number 1..4`(`schemas.ts:14,18`、`0003-init-plans.sql:22,44`)→ **放宽为任意周**(David 决策);② `target_value` 处处必填且 weight>0 / rpe1-10(`schemas.ts:159-188`、`PlanRequestDTOs.swift:106-123`、`PlanSet.swift:9`)→ **不做 note-only,教练补真实数字**;③ 学员真实读取走 `BackendStudentPlanRepository.StudentPlanProjection`(非 `PlanToStudentProjection`)→ coachNote 走**完整 wire 链路**。
  - **学员可见备注(David 2026-06-24)**:无法结构化的强度暗号要让学员看到 → 新增 `coachNote` 附加字段(跨 CoreModels / Networking / StudentKit / 后端)。
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md);上游 [spec 038](../038-planning-workspace/SPEC.md)(`publishPlan`)/ [004](../004-core-models-training-plan/SPEC.md) / [022](../022-exercise-library-v2-import/SPEC.md)。

## 目标

教练把手写 Excel 不重新誊写地导进 app:客户端本地解析 → 导入审阅(选周/匹配/补全)→ 直接发布。学员逐组打卡;教练的暗号/cue 作为学员可见备注跟在每组旁。

**教练看到啥**:

```
教练端 → 规划工作台 → [ 导入计划 ] (选学员: 吕子豪)
  ↓ 选 .xlsx (电脑 AirDrop 到手机) — 客户端本地解析,文件不出设备
导入审阅 sheet (本 spec 新增,独立于规划工作台编辑器)
  ↓ "共解析出 12 周 · 48 训练日 · 31 动作"
  ↓ ① 勾要导入的周(剩两周→勾最后两周) ② 选开始日(默认下周一,旧日期作废)
  ↓ ③ 动作匹配(精确折叠相等→自动绑;未命中→选库 / 暂跳过)
  ↓ ④ 强度复核:能结构化的已填好;无法结构化的标"待你定"——
        教练填真实重量/RPE(他本就知道),原暗号留成 coachNote 给学员看
  ↓ [ 发布给学员 ] (直接构造已发布实体树 → publishPlan)
学员端 (吕子豪)
  ↓ 剩余两周,逐组目标(重量/RPE)+ 每组 coachNote(如「70%top」「节奏3-1-0」「力竭」)
  ↓ 逐组打卡 → e1RM / 进度照常
```

## 背景与设计原则

1. **每组都有合法数字目标;暗号作附加 cue。** 后端要求每组有 `target_value`(weight>0 或 rpe1-10),且这对 e1RM/进度展示是好事。故**不做 note-only 组**:无法结构化的强度,教练在审阅里补一个真实值(他知道);原暗号存进 **`PlanSet.coachNote`(本 spec 新增,学员可见)**,既不丢信息又不污染目标/e1RM。

2. **真 gate = 导入审阅。** 解析器拿不准就不瞎猜——**绝不"算"或"猜"重量**;无法结构化的留空 + coachNote 原文,标"待你定",教练补真实值才能发布。

3. **专用管线,不污染既有授权流。** 既有"W1 模板 + 渐进规则"草稿/assembler 不动;导入走自己的解析→审阅→组装→发布,直接产出已发布实体。iOS 授权向导里 `planWeeks∈{1,4}` 的假设(`PlanningViewModel`/`Step1`)与导入无关(导入绕开);后端放宽约束后这些向导假设保持不变。

4. **V1 单教练单格式。** 锁吕子豪布局;别的教练异构表 / LLM / app 内手填 / `递增` 自动多周展开——不做。

## 架构

```
CoachKit/Planning/Import/                      (新增子树)
  ├─ XLSXReader.swift          ← CoreXLSX 封装,只读 cell
  ├─ PlanSheetGeometry.swift   ← 网格几何(7天×5列/天 stride,日期行)
  ├─ PlanSheetParser.swift     ← cell → ParsedPlan
  ├─ ParsedPlan.swift          ← 中间模型
  ├─ ImportPlanAssembler.swift ← ParsedPlan+审阅 → (TrainingPlan,[PlanDay],[PlanExercise],[PlanSet])
  ├─ ImportReviewViewModel.swift
  └─ Views/ (ImportEntryButton, ImportReviewSheet, ExerciseMatchSection, IntensityReviewSection)
```

- **发布**:`ImportPlanAssembler` 构造已发布实体树 → 既有 `PlanRepository.publishPlan(plan:days:exercises:sets:)`(`BackendPlanRepository.swift:51-130`,逐周 `PlanDay.weekNumber`、逐组 `PlanSet`、`PlanExercise.notes` 都已透传)。**不经 `DraftStore` / `PlanPublishAssembler`。**
- **新增依赖**:[`CoreXLSX`](https://github.com/CoreOffice/CoreXLSX)(**Apache-2.0**,纯 Swift 只读;Package iOS9+,iOS17 兼容)**钉 `0.14.2`**,挂 `Modules/CoachKit/Package.swift`。
- **跨仓改动**:见 §范围 G(后端放宽周数约束 + coachNote 全链路)。

## 范围

### 做什么

#### A. xlsx 读取 — `XLSXReader`(封装 CoreXLSX)
```swift
struct CellGrid { let maxRow: Int; let maxCol: Int; func value(row: Int, col: Int) -> CellValue? }  // 1-based
enum CellValue { case text(String); case number(Double); case date(Double) }
struct XLSXReader {
  init(fileURL: URL)                                    // security-scoped URL(见下)
  func cells(inSheetNamed name: String) throws -> CellGrid
  func sheetNames() throws -> [String]
}
```
- 文件选择:`fileImporter(allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .spreadsheet])`;选回的 URL 用 `startAccessingSecurityScopedResource()` / `stopAccessing…` 包裹读取。
- V1 读 `吕子豪` 这张 sheet;`注意事项` / `2026` 不解析。仅一张计划页则取之,否则审阅里让教练选。

#### B. 网格几何 — `PlanSheetGeometry`(实测锁定)
| 维度 | 规则 |
|---|---|
| 7 天横排 | 第 d 天(0..6)占列 `[1+5d..5+5d]` = A–E/F–J/K–O/P–T/U–Y/Z–AD/AE–AI(5 列/天)|
| 每天 5 列 | col1=动作名,col2=组*次,col3=强度,col4/col5=浮动(rpe/数字/tempo,按内容判别)|
| 周块分隔 | 日期行 = 各天 col1 落日期序列号(44900–45400),一行 7 连续日期;周块间空行 |
| 休息日 | col1=`休息` |
| 续行 | col1 空 + col2/col3 非空 → 上一动作追加组 |
| 多行辅助格 | col1 含换行 → 逐行拆成辅助动作 |
| 坏日期行 | 顶部第 1 行日期损坏(2024-12-30)→ 仍是周块,日期不可信;不影响(重排期)|

#### C. 解析器 → `ParsedPlan`(中间模型,非草稿)
```swift
struct ParsedSet { var reps: Int?; var repsMax: Int?; var weightKg: Decimal?; var rpe: Decimal?
                   var setType: SetType; var coachNote: String? }
struct ParsedExercise { var rawName: String; var isMainLift: Bool; var sets: [ParsedSet]; var exerciseNote: String? }
```

#### D. 解析规则 — 见 §解析规则附录。

#### E. 导入审阅 UI — `ImportReviewSheet`
1. 工作台「导入计划」入口(选学员后可见)→ `fileImporter`。
2. **选周**:全部解析 → 勾要导入的周。
3. **开始日**:默认下周一。
4. **动作匹配**:`rawName` 与库**精确折叠相等**(`ExerciseSearch.fold` 后字符串 `==`)→ 自动绑;否则 `ExerciseSearch.matches`(折叠子串)给候选,选库内 / 暂跳过。**V1 不建自定义。**
5. **强度复核**:`reps==nil`、`weightKg`/`rpe` 均空、或动作未绑 → 标"待你定";教练补真实重量/RPE(`力竭`默认建议 rpe10);coachNote 默认带上原暗号,可改。

#### F. 组装 + 发布 — `ImportPlanAssembler`
直接构造 → `publishPlan`:
- `TrainingPlan`:`planWeeks=选中数`(`1..52`,依赖后端放宽),`startDate`=开始日,`endDate=startDate + planWeeks*7 − 1 天`,`kind=.regular`,`source=.coach`,`status`/`createdAt`/`updatedAt` 走既有发布态(后端 create→publish 两步,同 `BackendPlanRepository`;时间戳取服务器值)。
- `[PlanDay]`:每选中周×每训练日,`weekNumber` 重排 `1..N`,`dayOfWeek`=原列位(0–6→1–7),休息日不产 day。
- `[PlanExercise]`:`exerciseID`=绑定结果,`isMainLift` 由 `mainLiftFamily` 判,`notes`=动作级上下文。
- `[PlanSet]`:**逐组一条**(阶梯/逐组 RPE/列举重量→各组不同 `targetValue`),`setNumber` 递增,`coachNote`=该组暗号。

#### G. coachNote 全链路 + 后端放宽周数(跨仓)
**wire 命名**:后端 JSON/DB 用 `coach_note`,Swift DTO/domain 属性用 `coachNote`(经 `MeetPRCodec` 转换)。

| 层 | 改动 |
|---|---|
| **MeetPR-backend** | ① `PlanWeeksSchema` / `WeekNumberSchema` 放宽为**有上限范围 `1..52`**(去 `{1,4}` / `1..4`;DB 列 `SMALLINT` 足够),Zod schema 与 DB CHECK 同步迁移 `plans_plan_weeks_check` / `plan_days_week_number_check`(只拓宽 CHECK,不动存量行);**保留** publish 阶段 `week_number ≤ plan_weeks` 与 `kind=adaptation⇒plan_weeks=1`。② `plan_sets` 加 `coach_note text NULL`;`PlanSetBodySchema` 收可选 `coach_note`;create 写入;backend serialization 类型 `PlanSetResponse` + 计划查询(教练 & 学员)select 返回 `coach_note` |
| **CoreModels** | `PlanSet` + `PrescribedSet` 加 `coachNote: String?`(`decodeIfPresent`,旧数据 nil)|
| **Networking(iOS DTO 链)** | `PlanSetDTO` + `CreatePlanSetRequestDTO` 加 `coachNote`;`DomainMapping`(DTO↔domain)透传(注:`PlanSetResponse` 是 backend 类型,不在此层)|
| **发布侧** | `BackendPlanRepository.createSets` 把 `PlanSet.coachNote` 放进 `CreatePlanSetRequestDTO` |
| **学员读取侧** | `BackendStudentPlanRepository.StudentPlanProjection` 把 `PlanSet.coachNote` 投进 `PrescribedSet.coachNote`(`BackendStudentPlanRepository.swift:62-68,94-170`)|
| **StudentKit UI** | 组行渲染 `coachNote`(在目标重量/RPE 旁,如小字 cue)|

> 后端只"拓宽约束 + 加列 + 透传",无业务逻辑改动。**部署次序**:导入功能依赖 backend PR 先上线(未升级后端会拒 `plan_weeks=2`、不持久化 `coach_note`)——故**导入入口 gated 到 backend capability/version 后才放出**;`decodeIfPresent` 只保证"新 iOS 能读旧响应",不代表旧后端能承接导入。

#### H. 完成度 gate(导入专用)
导入**不复用** `DraftSetSpec.isCoachComplete` / `PlanningViewModel.isValidSetSpec`(后者私有、绑草稿)。导入自有校验:每个 `PlanSet` 必须 ① `targetReps>=1`,② weight 模式 `targetValue>0` 或 rpe 模式 `1..10`,③ 动作已绑定。任一不满足 → "待你定",阻止发布。`coachNote` 永远可选。

### 不做(YAGNI / V1 边界)
- ❌ 别的教练异构表 / 任意布局探测;LLM / 截图导入;app 内网格手填。
- ❌ note-only 组(无数字目标)——教练补真实值;真 note-only 推迟(需 `targetValue` 可空,更大手术)。
- ❌ 运行时新建自定义动作(V1 绑库 / 跳过;推迟 V2)。
- ❌ 导入产物经规划工作台编辑器二次编辑 / 发布后再编辑(另立)。
- ❌ `递增` 当周间渐进自动展开;tempo/`D/L` 无递增/`70%top` 自动折算重量。
- ❌ 后端业务逻辑改动(仅拓宽周数约束 + 加 `coach_note` 列 + 透传)。
- ❌ 解析 `注意事项` / `2026` sheet。

## 解析规则附录(锁吕子豪写法;数值逐格照搬,拿不准→coachNote+待你定)

### 组*次(col2)
| 原文 | 解析 | 出处 |
|---|---|---|
| `4*8` `5*5` `3*3` `2*12` `1*5` | setCount=左, reps=右 | C2 |
| `4组` | setCount=4,**reps 审阅补**,setType=.amrap | U20 `引体向上 4组 力竭` |
| `N*a-b` | setCount=N, reps=a, repsMax=b | 注意事项 |

### 强度(col3)
| 原文 | 解析 | 出处 / 校验 |
|---|---|---|
| `D{d}/L{l} 递增{s}`(或 `增{s}`,L 可缺)| 组内阶梯:第 i 组=`min(d+i·s, l)` | **`D80/L90 递增5kg`(4组)→80/85/90/90**;`D62.5/L70 递增2.5kg`→62.5/65/67.5/70 |
| `{w1}/{w2}/…` 纯数字列举 | 逐组重量 | H37 `120/125/130/135` |
| 纯数字 | 全组同重量 | W37 `125` |
| `rpe{n}` | 全组 RPE=n | I4 `rpe9` |
| `rpe`(裸,配数字)| 逐组 RPE(见下)| F5+I5 |
| `amrap`/`力竭` | setType=.amrap;审阅补 reps + 默认 rpe10;coachNote=原文 | C7,W20 |
| `减{x}kg*{k}`/`回组减{x}` | setType=.backoff;weightKg 留空(审阅补);coachNote=原文 | R17,H23 |
| `{n}%top`/`D/L`无递增/其它 | weightKg 留空(审阅补);coachNote=原文 | C3 `70%top`,P16 |

### 数字编号(col4/col5,按内容判别)
| 内容 | 解析 | 出处 |
|---|---|---|
| 整数,位数=组数,各位 5–9 | 逐组 RPE | **`6788`(4组)→6/7/8/8**;`6789`→6/7/8/9 |
| 整数 + tempo 动作(名含 节奏/离心/暂停 或 col3=%top)| coachNote `节奏 a-b-c` | E3 `310`→3-1-0 |
| `rpe{n}` | RPE=n | I7 |
| 其它整数 | coachNote 原样 | — |

### 动作名(col1)
非空非日期非组次 → 动作名(名尾粘连数字如 `节奏深蹲310` 剥离为 tempo coachNote 再匹配);`休息`→休息日;空 col1+有组次→续行;多行格→逐行拆辅助。

## 数据与隐私
- **不提交真实学员文件**(PII);测试用脱敏精简 fixture(假学员/2 周/覆盖每规则)。
- 解析全程本地;xlsx 不上传/不进后端/不进日志。`coach_note` 写库的是教练对学员的处方文本(本就在 app 内流转)。

## 测试
- **解析器单测**(脱敏 fixture)goldens:`D100/L110 递增5kg`(4组)→`[100,105,110,110]`;`D62.5/L70 递增2.5kg`→`[62.5,65,67.5,70]`;`6789`(4组 rpe)→`[6,7,8,9]`;`120/125/130/135`→逐组;`310`(节奏)→coachNote「节奏3-1-0」;`70%top`→weightKg 空+coachNote;`减10kg*2`→.backoff+coachNote;`4组力竭`→.amrap+reps 待补;续行/多行/休息/坏日期行各 1。
- **几何 / 组装单测**:stride 寻址、日期行识别、周块切分;选周→weekNumber 重排;逐组不同 targetValue;开始日重排期;`publishPlan` 入参形状。
- **匹配单测**:`低杆深蹲` 精确折叠绑、`噩梦硬拉` 未命中、杆/杠 折叠。
- **coachNote 全链路单测**:`PlanSet`/`PrescribedSet` 带 coachNote 的 Codable round-trip(缺省→nil);`CreatePlanSetRequestDTO`/`PlanSetDTO`/`DomainMapping` 透传;`BackendStudentPlanRepository.StudentPlanProjection` 投到 `PrescribedSet.coachNote`;StudentKit 组行渲染 coachNote。
- **后端测试**:`plan_weeks=2`/`week_number>4` 现在被接受;`coach_note` create→读取 round-trip;放宽迁移不破坏既有 {1,4} 计划。
- **完成度单测**:reps<1 / 无合法 target / 未绑动作 → 阻止发布。

## 风险与边界
| 风险 | 处置 |
|---|---|
| 放宽周数约束的下游假设 | iOS 授权流被导入绕开;**审计 StudentKit 按周渲染**对任意周数稳健;保留 adaptation⇒1周 约束 |
| 解析误判重量 | 绝不生成数字,只照搬;不确定即留空+coachNote+待你定 |
| 跨仓后端迁移 | 只拓宽 CHECK + 加列,不动存量行;独立 PR 走 backend review;iOS `decodeIfPresent` 向后兼容 |
| 未匹配动作 | 强制复核绑库 / 跳过 |
| CoreXLSX 维护 | 仅只读取值,钉 0.14.2,封装一层可替换 |
| 不经工作台编辑器 | 审阅 sheet 内补全;发布后改动另立 |

## 验收标准
1. 教练对吕子豪导入,选 xlsx,**勾最后两周**(`planWeeks=2`)+ 选开始日,审阅后发布,无崩溃。
2. 主项 D/L 阶梯、逐组 RPE、列举重量**逐组结构化正确**(对齐 goldens);`70%top`/节奏/减重等暗号教练补值后,原文作 **coachNote**。
3. `reps==nil`、无合法 target、未绑动作的项标"待你定"并**阻止发布**;补齐后可发布。
4. 发布后学员端吕子豪见这两周、逐组目标 + **coachNote**(如「70%top」「节奏3-1-0」),逐组打卡,e1RM/进度照常。
5. 后端接受 `plan_weeks=2`(及 `1..52` 内任意值,`week_number ≤ plan_weeks`);仅多 `coach_note` 列与透传;放宽迁移不破坏既有 {1,4} 计划;导入入口 gated 到 backend 上线后。
6. 原始 xlsx 不离开设备;仓库不含真实学员文件。

## 复用与改动资产表
| 复用 / 改动 | 来源 | 用途 |
|---|---|---|
| `publishPlan(plan:days:exercises:sets:)` | CoachKit(038/026)| 发布完整实体树(任意周/逐周/逐组)|
| `TrainingPlan`/`PlanDay`(weekNumber)/`PlanExercise`(notes)/`PlanSet` | CoreModels(004)| 导入直接构造的发布实体 |
| `PlanSet.coachNote` + `PrescribedSet.coachNote` + 全 wire 链路(**新增**)| CoreModels/Networking/StudentKit/backend(本 spec)| 暗号直达学员 |
| 放宽 `plan_weeks`/`week_number` 约束(**新增**)| MeetPR-backend(本 spec)| 支持任意剩余周数 |
| 1228 动作库(`Exercise`,`mainLiftFamily`)| CoreModels/CoachKit(022)| 动作匹配 / 主项判定 |
| `ExerciseSearch.fold`/`.matches` | CoachKit | 精确折叠绑定 + 候选建议 |
| `PrescribedSet`(weightKg/rpe 可空)| CoreModels(033)| 学员端逐组呈现,支持无目标重量打卡 |
