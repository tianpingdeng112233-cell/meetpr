# 032 — 学员 onboarding 7 步向导 + 我的资料九卡(29 字段采集 → complete → 自动发绑定请求)

- **状态**: InProgress
- **PR**: TBD
- **来源**:
  - [V0.1b 完成波决议 §2 ⑥](~/Brain/wiki/projects/MeetPR/v0_1b_completion_wave.md) — "7 步向导 29 字段(per student-onboarding v2.4);1RM 填后学员锁定;Step 6 上传复用①管线;完成自动发绑定请求;'我的资料'九卡档案页"
  - **backend [spec 005-bind-eval-profile](~/Projects/apps/MeetPR-backend/specs/005-bind-eval-profile/SPEC.md)(wire shape 最高权威,已实装合 staging)** — §migrations 0013(29 列 + 词表)/ §端点 E(PUT 可重入 upsert / POST complete / GET / coach one-rm)/ D11-D17;本 spec 全部字段名、词表 token、校验边界**逐字对齐它,不自创**
  - [student-onboarding.md v2.4](~/Brain/wiki/projects/MeetPR/student-onboarding.md) — 7 步逐字段权威(控件/必填/文案/线框)+ "我的资料"九卡 + §D 4 级修改权限
  - [evaluation-workflow.md v1.1](~/Brain/wiki/projects/MeetPR/evaluation-workflow.md) — §1 funnel 顺序(onboarding 先于绑定请求)
  - [ADR-009 SwiftData 例外](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) — SwiftData **仅限** CoachKit 规划草稿;本 spec 本地暂存走 JSON file(`LocalE1RMRepository` 先例)
  - 上游 [spec 028](../028-e1rm-curve-pr-push/SPEC.md) — `E1RMCalculator`(Step 3 计算器复用)+ `MyProfileView` 现状(只有成长曲线入口)
  - 并行 [spec 031 邀请码+绑定](../031-invite-bind-pending/SPEC.md) — **code 暂存交接契约**(031 定义 `PendingBindCodeStore` / `BindRepository`,本 spec 在 complete 时消费;见 §技术要求"031↔032 接口契约")
  - 并行 [spec 027 video upload](../027-video-upload/SPEC.md) + backend spec 004 — Step 6 上传的管线依赖(`VideoUploadActor` / attachments 表 / `onboarding_video` `onboarding_doc` kind);**本 spec 默认降级版**,集成另起 follow-up(见 §做什么 8 + §上下游)

## 目标

学员第一次进 app 能把"教练评估你需要的一切"一次填完,之后能在"我的"里随时查、随时改(1RM 除外):

1. **7 步 onboarding 向导**:逐步照 wiki v2.4(字段/滑块/多选/条件显隐全列);每步"下一步"即 PUT 落 backend(可重入 upsert,中途退出杀 app 都能续填);30+ 字段本地 JSON 草稿兜底。
2. **complete → 绑定 handoff**:`POST /students/me/onboarding/complete` 成功后,消费 spec 031 暂存的邀请码自动发绑定请求 → 进"待接收"页。产品顺序 = wiki funnel(onboarding 先于绑定请求),工程顺序 = 输码在前暂存(backend `POST /bind-requests` 需要 code)。
3. **我的资料九卡**:`MyProfileView` 从单入口扩成档案页 — 九卡扫视态 + 每卡进编辑态(复用向导 step 组件);1RM 卡只读标注"已锁定,联系教练修改";教练评估卡占位(033 接数据)。

backend 全部端点已 live,本 spec **backend 0 改动**。

学员看到啥:

```
[ 输码页(031)提交 → onboarding 未完成 ]
  ↓ 进向导(全屏 cover,可随时左上"保存并退出")
  Step 1/7 基础信息   单位制 kg/lb · 性别 · 生日 · 身高 · 体重
  Step 2/7 训练背景   训练年限滑块 <1→10+ · 深蹲高杠/低杠 · 硬拉传统/相扑 · 卧推握距(选填)
  Step 3/7 你有多强?  三大项 1RM + 🧮 估算器(不确定?用近期训练估算)
                      ⚠️ "1RM 一旦填写,完成后只有教练能改"
  Step 4/7 训练环境   每周哪几天能练(选 2-6 天)· 家庭含架/商业健身房/专业力训馆 · 器械微调清单
  Step 5/7 恢复能力   日常生活强度(U 型)· 生活压力 · 恢复速度 · 睡眠时长(4 个 5 级滑块)
  Step 6/7 训练资料   上传训练计划/三大项视频(027 管线;未就绪 → "上传功能开放中"降级)
                      想增强的肌群(最多 3 个,可选)
  Step 7/7 补充信息   伤病记录+部位标签 · 是否备赛(→比赛日期) · 目标体重级别 · 给教练的话
  ↓ [完成,开始训练!] → 全量 PUT 兜底 → POST complete
  ├─ 422 缺必填 → 跳到对应 step + 字段高亮
  └─ 200 → 消费暂存 code 发绑定请求 → "待接收"页(031)

[ 中途退出(任何时刻)]
  → 已填字段已 PUT + 本地草稿已存;下次进 BindGate → 自动回向导,落在第一个未完成 step

[ 绑定后日常:"我的" tab ]
  成长曲线(028 既有)
  ── 我的资料 ──
  📋 基础信息   男 · 25岁 · 178cm · 83kg            ›
  🏋️ 训练背景   3年 · 低杠深蹲 · 传统硬拉            ›
  💪 我的极限   S 180 · B 120 · D 220 (kg) 🔒       ›  ← 只读:"已锁定,联系教练修改"
  📅 训练环境   周一·三·五·六 (4天/周) · 商业健身房   ›
  😴 恢复能力   强度:中等 压力:较高 恢复:正常 睡眠:7h ›
  📂 训练资料   上传 4 份 · 想增强:股四/腘绳/肩       ›
  🎯 比赛/备注  备赛: 2026-07-25 · IPF 83kg          ›
  🩹 伤病记录   左肩撞击综合征 (肩)                   ›
  📝 教练评估   (占位)"评估完成后可在这里查看"        ›  ← 033 接 GET evaluation-summary
```

## 关键决策(裁量,起草拍板)

| #   | 决策 |
| --- | --- |
| D1  | **单位制只影响显示**:wire 恒公制(`height_cm` / `weight_kg` / `*_1rm_kg`)。`unit_preference == lb` 时 UI 输入/显示做 lb↔kg(及 inch↔cm)换算,提交前转回公制。不引"双单位存储"。 |
| D2  | **修改权限降级**(wiki §D 4 级 → V0.1b 2 级):**只锁 1RM**(与 backend 真 gate `403 ONE_RM_LOCKED` 对齐);其余全部可编辑 silent 保存。理由:Type B"立即推送教练"依赖 APNs(V0.1b 无,wave 决议);训练日/gym_tier 的 Type A 锁 backend 没锁,iOS 单边锁是纸面 gate 还挡了真需求(学员换健身房)。完整 4 级权限 V0.1.x 随 APNs 一起上,届时修订本表。 |
| D3  | **`equipment_overrides` 存最终勾选全集**(选中器械 token 数组),非 diff/delta。理由:delta 需要 +/- 编码 + tier 切换 re-base 逻辑,易错;全集教练直接可读。tier 切换 → 重置为该 tier 预填清单(用户微调丢弃,切换前 confirm)。13 个 token 词表 iOS 持有(backend 注释"vocab owned by iOS"),见 §做什么 4 Step 4。 |
| D4  | **想增强肌群 chips = 10 个**:wiki 线框的"背"与"竖脊肌"合并为一个 chip "背(含竖脊肌)" → token `back`。理由:backend D15 把竖脊肌映射 `back`,两 chip 并存会产生重复 token,违 zod `uniqueItems` 直接 400。 |
| D5  | **部分更新用三态 `Patch<T>`**(absent = 不提交该 key / null = 显式清空 / value):每步 PUT 只带该步字段;可清空字段(`bench_grip` / `injury_*` / `competition_date` / `target_weight_class` / `note_to_coach` / `muscle_groups_to_strengthen` / `equipment_overrides`)在用户清空时发 JSON null。`upload_attachment_ids` **只在 Step 6 提交**(全量替换语义,absent ≠ 空数组,见 §风险 4)。 |
| D6  | **本地草稿 = JSON file**(`Documents/onboarding/draft-<studentId>.json`,`LocalE1RMRepository` 先例;ADR-009 SwiftData 例外不扩散)。**server 为底、较新者赢**:进向导先 GET server profile 预填,若本地草稿 `savedAt > server.updatedAt` 则本地非空字段盖上。每步推进双写(本地 + PUT);**complete 前必做一次全量 PUT 兜底**(把中途 PUT 失败漏掉的字段补齐),所以分步 PUT 失败可容忍(banner 提示,不挡前进)。complete 成功后清草稿。 |
| D7  | **Step 3 计算器复用 `E1RMCalculator`**(spec 028,StudentKit 已有):sheet 输入 重量/次数/RPE → 算 e1RM → 两个按钮 [填入估算值] / [保守填入 90%](wiki v2.3 议题 5 "如不确定填 90% 估测"),结果 round 到 0.5kg 网格。不新写数学。 |
| D8  | **滑块存档位不存物理值**:`training_years` 0-10(0 = <1 年,10 = 10+);恢复 4 项全部 SMALLINT 1-5 档位(`sleep_hours` 1..5 = ≤5h/6h/7h/8h/9h+,backend D12)。UI 显示中文标签(wiki v2.1 表逐字),wire 发 Int。 |
| D9  | **向导入口仅 coachedStudent**(BindGate 的 `.needsOnboarding` 分支)。自练学员 onboarding(§F.2 mode 选择)V0.1.x — backend 端点对 self_train 开放,iOS 入口不开。completed 之后向导不再可进,改资料只走九卡编辑态(`completed_at != nil` 后向导路由不可达;1RM 字段在任何编辑 PUT 中**永不携带**,403 守护见 §风险 6)。 |
| D10 | **九卡页数据源 = `GET /students/:id/onboarding`(self)**,404(理论不可达:bound 必经 complete;自练未填)→ 显示"完成资料填写后解锁"空态。每卡编辑保存 = PUT 该卡字段 patch → 重拉 profile 刷新摘要行。 |
| D11 | **Step 顺序的"必填"只在 complete 校验**:分步"下一步"做 UI 必填 gating(wiki 各 step 必填列),但 PUT 本身不要求字段齐(backend 全列 nullable);`training_days` 例外 — zod `min(2)`,不足 2 天时该字段从 patch 里 absent(不发),而非发不合法数组(见 §风险 3)。 |
| D12 | **服务端 `missing_fields` → step 跳转映射表**写死在 VM(backend complete 必填 18 项 + 条件 1 项 ↔ step 1-7),422 时跳最早缺字段的 step 并高亮。 |

## 范围

### 做什么

#### 1. CoreModels 新增 `OnboardingProfile` + 词表 enum

位置:`Modules/CoreModels/Sources/CoreModels/Entities/Onboarding/`(新目录)

```swift
// 词表 rawValue 与 backend src/db/types.ts 逐字对齐(单测钉死)
public enum UnitPreference: String, Codable, CaseIterable, Sendable { case kg, lb }
public enum Gender: String, Codable, CaseIterable, Sendable { case male, female, other }
public enum SquatStance: String, Codable, CaseIterable, Sendable { case highBar = "high_bar", lowBar = "low_bar" }
public enum DeadliftStyle: String, Codable, CaseIterable, Sendable { case conventional, sumo }
public enum BenchGrip: String, Codable, CaseIterable, Sendable { case narrow, standard, wide }
public enum GymTier: String, Codable, CaseIterable, Sendable { case homeWithRack = "home_with_rack", commercial, professional }
public enum TrainingDay: String, Codable, CaseIterable, Sendable { case mon, tue, wed, thu, fri, sat, sun }
public enum InjuryArea: String, Codable, CaseIterable, Sendable {
  case shoulder, elbow, wrist, lowerBack = "lower_back", hip, knee, ankle, other
}
// MuscleGroup 复用 CoreModels 既有(spec 030 先例);肌群 chips 白名单见 Step 6

public struct OnboardingProfile: Codable, Hashable, Sendable {
  // Step 1
  public let unitPreference: UnitPreference?
  public let gender: Gender?
  public let birthDate: String?            // "yyyy-MM-dd" date-only,String 防时区漂移(030 checkinDate 先例)
  public let heightCm: Decimal?
  public let weightKg: Decimal?
  // Step 2
  public let trainingYears: Int?           // 0-10 档位(D8)
  public let squatStance: SquatStance?
  public let deadliftStyle: DeadliftStyle?
  public let benchGrip: BenchGrip?
  // Step 3
  public let squat1RMKg: Decimal?
  public let bench1RMKg: Decimal?
  public let deadlift1RMKg: Decimal?
  // Step 4
  public let trainingDays: [TrainingDay]
  public let gymTier: GymTier?
  public let equipmentOverrides: [String]  // iOS 词表 token(D3),backend 自由 TEXT[]
  // Step 5(全部 1-5 档位)
  public let dailyLifeIntensity: Int?
  public let lifeStress: Int?
  public let recoverySpeed: Int?
  public let sleepHours: Int?
  // Step 6
  public let muscleGroupsToStrengthen: [MuscleGroup]   // ≤3
  public let uploadAttachmentIds: [UUID]
  // Step 7
  public let injuryNotes: String?
  public let injuryAreas: [InjuryArea]
  public let isCompeting: Bool?
  public let competitionDate: String?      // "yyyy-MM-dd"
  public let targetWeightClass: String?
  public let noteToCoach: String?
  // 元数据
  public let completedAt: Date?
  public let createdAt: Date
  public let updatedAt: Date
  public init(...) { ... }

  public var isCompleted: Bool { completedAt != nil }
}
```

```swift
/// 三态部分更新(D5)。absent = 该 key 不出现在 PUT body;null = 发 JSON null 清空。
public enum Patch<Value: Equatable & Sendable>: Equatable, Sendable {
  case absent
  case null
  case value(Value)
}

/// 29 字段全 Patch 化的 upsert 载荷;CoreModels 持类型,encode 在 Networking DTO 层
public struct OnboardingPatch: Equatable, Sendable {
  public var unitPreference: Patch<UnitPreference> = .absent
  // …(29 字段同构,略)
  public var uploadAttachmentIds: Patch<[UUID]> = .absent
  public static let empty = OnboardingPatch()
}
```

#### 2. `RepositoryContracts` 新增 `OnboardingRepository`

位置:`Modules/RepositoryContracts/Sources/RepositoryContracts/OnboardingRepository.swift`(新)

```swift
public enum OnboardingError: Error, Equatable, Sendable {
  case incomplete(missingFields: [String])   // 422 ONBOARDING_INCOMPLETE(snake_case 字段名原样)
  case oneRMLocked                           // 403 ONE_RM_LOCKED
  case notFound                              // 404 ONBOARDING_NOT_FOUND
}

/// 学员 onboarding 档案(spec 032)。对应 backend /students/me/onboarding 三端点。
public protocol OnboardingRepository: Sendable {
  /// GET /students/:id/onboarding(self)。404 → nil(不抛,"还没填过"是常态)
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile?
  /// PUT /students/me/onboarding。分步可重入 upsert;completed 后 patch 含 1RM key → 抛 oneRMLocked
  func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile
  /// POST /students/me/onboarding/complete。缺必填抛 incomplete(missingFields);已完成幂等 200
  func complete() async throws -> OnboardingProfile
}
```

(教练改 1RM 端点 `PUT /coach/students/:id/one-rm` 是 033 评估总结侧的事,本 spec 不建协议方法。)

#### 3. `Networking` 增量:DTO + Patch encoder + APIClient extension

位置:`Modules/Networking/Sources/Networking/DTO/OnboardingDTOs.swift` + `APIClient+Onboarding.swift`(新 2 文件)

- `OnboardingProfileDTO`:29 字段 + `upload_attachment_ids` + 3 元数据;decimal 列走既有 `decodeDecimal` / `encodeDecimalString`(wire 是 `"180.00"` 字符串);`birth_date` / `competition_date` 直接 String 透传(**不**过 `MeetPRCodec` 的 Date 解析,防 UTC 午夜时区 bug);`toDomain()`
- `OnboardingPatchDTO`:**手写 `encode(to:)`**(三态语义自动合成做不了):

```swift
// 每字段:
switch patch.benchGrip {
case .absent: break
case .null: try container.encodeNil(forKey: .benchGrip)
case .value(let grip): try container.encode(grip.rawValue, forKey: .benchGrip)
}
// Decimal 字段 .value 分支走 encodeDecimalString;
// CodingKeys 显式列出(snake_case 全名),不依赖策略 — zod .strict() 拒一切未知 key,字段名错 = 400
```

- `APIClient+Onboarding.swift`:

```swift
extension APIClient {
  public func onboardingProfile(studentId: UUID, accessToken: String) async throws -> OnboardingProfileDTO   // GET /students/:id/onboarding
  public func upsertOnboarding(_ body: OnboardingPatchDTO, accessToken: String) async throws -> OnboardingProfileDTO  // PUT /students/me/onboarding
  public func completeOnboarding(accessToken: String) async throws -> OnboardingProfileDTO                   // POST /students/me/onboarding/complete
}
```

- 错误信封:`{ "error": "ONBOARDING_INCOMPLETE", "missing_fields": [...] }` 解析 → `OnboardingError`(031 的信封 helper 同款扩展)

**Wire 校验边界备忘(照抄 backend zod,iOS UI 必须不产出非法值)**:

| 字段 | 边界 |
|---|---|
| `height_cm` | 字符串,>0 <300,≤2 位小数(UI 限 1 位,0.1 步进) |
| `weight_kg` | >0 <500,≤2 位小数 |
| `*_1rm_kg` | >0 <1000,≤2 位小数(UI 0.5 步进) |
| `training_years` | int 0-10 |
| `training_days` | 2-6 项、去重、token ∈ mon..sun |
| `equipment_overrides` | ≤30 项、每项 1-50 字符、去重、nullable |
| 恢复 4 滑块 | int 1-5 |
| `muscle_groups_to_strengthen` | ≤3、去重、token ∈ MUSCLE_GROUPS、nullable |
| `upload_attachment_ids` | ≤20 UUID、去重 |
| `injury_notes` / `note_to_coach` | 1-2000 字符、nullable(空串非法 → 清空发 null) |
| `injury_areas` | ≤8、去重、8 值词表、nullable |
| `competition_date` | "yyyy-MM-dd"、nullable |
| `target_weight_class` | 1-100 字符、nullable |

#### 4. `StudentKit` 7 步向导:`OnboardingWizardView` + `OnboardingWizardViewModel` + 7 step 子视图

位置:`Modules/StudentKit/Sources/StudentKit/Features/Onboarding/`(新目录;`Steps/` 子目录 7 文件 + 共享 field 组件)

**VM 骨架**:

```swift
@Observable @MainActor
public final class OnboardingWizardViewModel {
  public private(set) var step: Int = 1            // 1-7;resume 时 = 第一个未完成 step
  public var draft: OnboardingDraft                 // 29 字段可编辑工作副本(struct)
  public private(set) var saveBanner: SaveBanner?   // 分步 PUT 失败提示(不挡前进,D6)
  public private(set) var completing = false
  public private(set) var highlightedFields: Set<String> = []   // 422 回流高亮

  // deps: repo: any OnboardingRepository, draftStore: LocalOnboardingDraftStore,
  //       studentId: UUID, onCompleted: () async -> Void(BindGate 注入,handoff 完成后收敛状态)

  public func load() async { /* GET profile + local draft → D6 合并 → draft 预填 + step 定位 */ }
  public func advance() async { /* 当步 UI 必填 gating → draftStore.save → repo.upsert(当步 patch) → step += 1 */ }
  public func back() { step -= 1 }
  public func saveAndExit() async { /* draftStore.save + best-effort PUT → dismiss */ }
  public func complete() async {
    // 1. 全量 PUT 兜底(整 draft → patch,D6)
    // 2. repo.complete()
    //    ├─ .incomplete(fields) → step = earliestStep(fields)(D12 映射表), highlightedFields = fields
    //    └─ 成功 → draftStore.clear → handoff(见 §6)→ onCompleted()
  }
}
```

**逐步字段 / 控件清单(权威 = wiki v2.4,wire = backend 0013;两边冲突以 backend 字段为准、wiki 文案为准)**:

| Step | 字段(wire) | 控件 | 必填(UI gating) | 说明 |
|---|---|---|---|---|
| **1 基础信息** | `unit_preference` | segmented "公斤/厘米 · 磅/英寸" | ✓ | 切换即时换算已填数值显示(D1) |
| | `gender` | 单选 男/女/其他 | ✓ | |
| | `birth_date` | DatePicker(wheel,默认 2000-01-01,范围 1930-今) | ✓ | date-only String |
| | `height_cm` | 数字栏 + 单位后缀 | ✓ | lb 制显示 ft/in(D1) |
| | `weight_kg` | 数字栏 + 单位后缀 | ✓ | |
| **2 训练背景** | `training_years` | 滑块 0-10,锚点 "<1 … 10+"(JAI 滑块交互,spec 023 `PlanningCountPicker` 风格对齐) | ✓ | 档位语义 D8 |
| | `squat_stance` | 双卡单选 高杠/低杠 | ✓ | 线稿动画图 V0.1.x,先纯文字卡 |
| | `deadlift_style` | 双卡单选 传统/相扑 | ✓ | |
| | `bench_grip` | 三卡单选 窄/标准/宽 + "跳过" | 否 | 可清空(null) |
| **3 你有多强?** | `squat_1rm_kg` `bench_1rm_kg` `deadlift_1rm_kg` | 数字栏 ×3 + 🧮 按钮各一 | ✓×3 | 🧮 → 计算器 sheet(D7);页头注释"1RM 一旦填写,完成后只有教练能改"(wiki v2.3 议题 6) |
| **4 训练环境** | `training_days` | 周一-周日 7 chip 多选 + "已选 N 天/周" | ✓(2-6 天) | 不足 2 天禁"下一步"(D11) |
| | `gym_tier` | 三卡单选(家庭含架/商业健身房/专业力训馆) | ✓ | 选择即重置微调清单预填(D3) |
| | `equipment_overrides` | 13 项 checklist(按 tier 预填) | 否 | 全集语义 D3;token 见下表 |
| **5 恢复能力** | `daily_life_intensity` | 5 级滑块,标签 wiki v2.1 表逐字(U 型注释"久坐 ≠ 低消耗") | ✓ | |
| | `life_stress` | 5 级滑块 几乎无→极高 | ✓ | |
| | `recovery_speed` | 5 级滑块 很慢(>72h)→很快(<12h) | ✓ | |
| | `sleep_hours` | 5 档滑块 ≤5h/6h/7h/8h/9h+ | ✓ | 存档位 1-5(D8) |
| **6 训练资料** | (上传)→ `upload_attachment_ids` | 训练计划(PNG/JPG/PDF 多选)+ 深蹲/卧推/硬拉视频各 ≤3 | 否 | **027 依赖,降级版见 §8** |
| | `muscle_groups_to_strengthen` | 10 chip 多选 ≤3(D4) | 否 | token:`quad` `hamstring` `glute` `back`(背·含竖脊肌)`chest` `shoulder` `triceps` `biceps` `core` `calf` |
| **7 补充信息** | `injury_notes` | 多行文本 | 否 | 与 `injury_areas` 联动非强制 |
| | `injury_areas` | 8 chip 多选(肩/肘/腕/腰/髋/膝/踝/其他) | 否 | |
| | `is_competing` | 单选 没有/有 | ✓ | "有" → 展开比赛日期 |
| | `competition_date` | DatePicker(今天起) | 条件✓(备赛时) | |
| | `target_weight_class` | 单行文本,placeholder "例:IPF 83kg / WP -82.5kg" | 否 | |
| | `note_to_coach` | 多行文本 "想对教练说什么?" | 否 | 末步按钮 = [完成,开始训练!] |

**Step 4 器械 token 词表(iOS 持有,D3)+ tier 预填映射**:

| token | 中文 | home_with_rack | commercial | professional |
|---|---|:---:|:---:|:---:|
| `barbell_dumbbell` | 杠铃 + 哑铃 | ✓ | ✓ | ✓ |
| `squat_bench_rack` | 深蹲架 + 卧推架 | ✓ | ✓ | ✓ |
| `pullup_bar` | 引体向上杆 | ✓ | ✓ | ✓ |
| `cable_lat_pulldown` | 拉力机 / 高位下拉 | | ✓ | ✓ |
| `smith_machine` | 史密斯架 | | ✓ | ✓ |
| `heavy_dumbbells` | 哑铃区(>30kg) | | ✓ | ✓ |
| `leg_press_machine` | 蹲举机 | | ✓ | ✓ |
| `leg_curl_extension` | 腿弯机 / 腿伸机 | | ✓ | ✓ |
| `seated_row` | 坐姿划船 | | ✓ | ✓ |
| `lifting_platform` | 举重台 | | | ✓ |
| `blocks_chains_bands` | 块铃 / 链子 / 弹力带 | | | ✓ |
| `hack_squat` | 哈克深蹲架 | | | ✓ |
| `safety_bar` | 安全杠 | | | ✓ |

(wiki "待解决"注明器械清单待肖+里欧 review 补全 — 改清单 = 改本表 + 预填映射,Class 1。)

**导航壳**:全屏 cover(BindGate `.needsOnboarding` 分支渲染);顶部 "Step N of 7" 进度条 + 左上 [保存并退出];[上一步]/[下一步] 底部双按钮;键盘 safe-area 适配。

#### 5. `StudentKit` 本地草稿 `LocalOnboardingDraftStore` + `OnboardingDraft`

位置:`Modules/StudentKit/Sources/StudentKit/Features/Onboarding/`(新 2 文件)

```swift
/// 向导工作副本:29 字段全 Optional + UI 态。与 OnboardingProfile 区别:
/// draft 是可变 struct 给表单绑定;profile 是 server 快照。
public struct OnboardingDraft: Codable, Equatable, Sendable {
  // 29 字段(类型同 OnboardingProfile,全 Optional)…
  public var savedAt: Date
  public var furthestStep: Int        // resume 定位(D6)
  public static func from(_ profile: OnboardingProfile) -> OnboardingDraft { ... }
  public func patch(forStep step: Int) -> OnboardingPatch { ... }   // 当步字段 → Patch(清空字段发 .null)
  public func fullPatch() -> OnboardingPatch { ... }                // complete 前全量兜底(D6)
}

/// JSON file 持久化,Documents/onboarding/draft-<studentId>.json(LocalE1RMRepository 先例)
public actor LocalOnboardingDraftStore {
  public func load(studentId: UUID) throws -> OnboardingDraft?
  public func save(_ draft: OnboardingDraft, studentId: UUID) throws
  public func clear(studentId: UUID) throws
}
```

#### 6. complete → 绑定 handoff(消费 spec 031 暂存)

位置:`OnboardingWizardViewModel.complete()` 尾段 + 完成过渡页

```
POST complete 200
  → stash = pendingBindStore.peek(studentId)
  ├─ 有 stash → bindRepo.submitBindRequest(code: stash.code, displayName: stash.displayName)
  │    ├─ 201            → pendingBindStore.clear → onCompleted()(BindGate reload → 待接收页)
  │    ├─ INVITE_CODE_INVALID → pendingBindStore.clear → onCompleted()
  │    │     (BindGate 落 .needsCode(prefillDisplayName: stash.displayName, notice: .invalidCode);
  │    │      onboarding 已完成留在 server,重输码立即重发,不重过向导 — 031 D1)
  │    ├─ ALREADY_PENDING / ALREADY_BOUND → onCompleted()(状态已推进,BindGate reload 收敛)
  │    └─ 网络失败 → 完成过渡页显示 [重试发送];stash 保留,杀 app 后 BindGate resolveUnbound 自动补发(031 §6)
  └─ 无 stash(重装 app / 异常清除)→ onCompleted()(BindGate 落 .needsCode)
```

完成过渡页:"✓ 资料已提交" + 自动执行 handoff,只有网络失败分支需要交互。**本段与 031 §技术要求契约表同文,改一处必须改两处。**

#### 7. `MyProfileView` 九卡扩展 + 每卡编辑态

位置:`Modules/StudentKit/Sources/StudentKit/Features/MyProfile/`(改 `MyProfileView.swift`,新 `ProfileCardsSection.swift` + `ProfileCardEditView.swift` 族 + `MyProfileViewModel.swift`)

- `MyProfileView` 结构:保留"成长曲线"入口(028)置顶 → 新 Section "我的资料" 九卡(§目标 线框)。init 增参 `onboarding: any OnboardingRepository`,`StudentRootView` 透传
- 扫视态:每卡 = 图标 + 标题 + 摘要行(formatter 集中在 `OnboardingSummaryFormatter`,wiki 摘要格式逐字:年龄由 `birth_date` 客户端算 — backend D13 同款口径)
- 编辑态:tap 卡 → push 编辑页,**复用向导 step 子视图的 field 组件**(组件抽成 `OnboardingFieldSections` 共享层,wizard 与 card edit 同源);[保存] → `upsert(该卡字段 patch)` → pop + 重拉 profile
- **卡 3 我的极限(1RM)**:只读呈现(wiki §D Type A 线框):三行数值 + 🔒 + 底注 "🔒 已锁定,联系教练修改"。无编辑入口(D2;教练改 1RM 走 033 评估流)
- **卡 6 训练资料**:摘要 "上传 N 份 · 想增强:股四/腘绳/肩";编辑态只开放肌群多选;上传区降级同 Step 6(§8)
- **卡 9 教练评估**:V0.1b 占位卡(灰态,"教练完成评估后,可在这里查看评估总结");**033 接**:`GET /students/:id/evaluation-summary` + 摘要/展开呈现。本 spec 只留卡位 + NavigationLink disabled
- 404 空态(D10):九卡区整体替换为"完成资料填写后解锁"占位(自练学员场景)

#### 8. Step 6 上传:027 依赖标注 + 降级版(本 spec 默认交付形态)

**依赖**:spec 027 `VideoUploadActor`(转码 + OSS multipart)+ backend spec 004 attachments(`onboarding_video` / `onboarding_doc` kind 已在 backend `ATTACHMENT_KINDS` 词表预留)。027 并行实装中,**本 spec 不阻塞等它**。

**降级版(默认,vNext 集成前)**:
- Step 6 上传区渲染两张 disabled 卡("📋 上传训练计划" / "🎬 三大项动作视频"),角标"即将开放";肌群多选正常可用
- `upload_attachment_ids` 在所有 patch 中恒 `.absent`(不发 → 不动 server 状态)
- 九卡"训练资料"摘要只显示肌群;031 待接收页资料计数行隐藏(N == 0)

**集成版(027 合 main 后,follow-up PR,不在本 spec 验收内)**:
- 接缝已预留:Step6View / 训练资料卡接受 `uploadsEnabled: Bool` + `attachments` 注入
- 视频走 `VideoUploadActor.enqueue`(kind `onboarding_video`,≤120s 默认 60s,每动作 ≤3 个);**训练计划文档(PNG/JPG/PDF)是 027 没有的无转码路径**(027 只做 set_video)— 集成时评估归 027 amendment 还是独立小 spec,本 spec 不拍板
- 上传完成的 attachment id 列表 → Step 6 / 训练资料卡保存时发 `upload_attachment_ids`(全量替换,D5)

#### 9. `StudentKit` 双实现 + 装配

位置:`Modules/StudentKit/Sources/StudentKit/Repository/`(新 2 文件)+ `AppShell` / `MeetPRApp`

- `InMemoryOnboardingRepository`(actor):upsert 合并语义(absent 不动 / null 清空 / value 覆盖)、complete 必填校验镜像(backend 18+1 项,抛 `incomplete` 带 snake_case 字段名)、completed 后 1RM patch 抛 `oneRMLocked`。DEMO seed:demo 学员 = 已 completed 全 29 字段(九卡可演示);向导演示用未填新账号路径
- `BackendOnboardingRepository`(actor):`APIClient + SessionStateReader` 既有模式;**无 cache**(档案编辑要实时一致;草稿另有 LocalOnboardingDraftStore)
- 装配:`RootView` 的 BindGate 注入点(031 §9)换真值 — `isOnboardingComplete = { (try? await onboardingRepo.fetchProfile(studentId:))??.isCompleted ?? false }`;`onboardingFlow = { pending, onCompleted in OnboardingWizardView(...) }`;`StudentRootView` init 增参 `onboarding:` 透传给 `MyProfileView`

#### 10. 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/CoreModels/Tests/CoreModelsTests/OnboardingEntitiesTests.swift`(新) | 8 词表 enum rawValue 与 backend types.ts 逐字;`OnboardingProfile` Codable roundtrip;`Patch` 等值语义 |
| `Modules/Networking/Tests/NetworkingTests/OnboardingDTOTests.swift`(新) | **29 字段全量 fixture**(backend 005 wire 约定:decimal 字符串 `"180.00"` / date 字符串 / 数组原样)decode→toDomain→encode 闭环;`OnboardingPatchDTO` 三态:absent 无 key / null 出 `null` / value 出值(JSON 字典逐 key 断言);未知 key 永不产出(`.strict()` 风险钉死);`missing_fields` 信封解析 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/OnboardingWizardViewModelTests.swift`(新) | 每步必填 gating 矩阵(含 Step 4 不足 2 天 / Step 7 备赛条件必填);resume 定位第一个未完成 step;D6 合并(local 新赢 / server 新赢 / local 无);advance 时 PUT patch 只含当步字段;PUT 失败 banner 且可前进;complete:全量 PUT 先行 → 422 跳 step + 高亮(D12 映射表全 19 项)→ 成功清草稿 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/OnboardingHandoffTests.swift`(新) | §6 决策树 5 路全测(201 / invalidCode / alreadyPending / 网络失败 stash 保留 / 无 stash);与 031 `PendingBindCodeStore` 假实现对接 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/LocalOnboardingDraftStoreTests.swift`(新) | save/load/clear roundtrip;损坏 JSON → nil 不崩;studentId 隔离 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/EquipmentPrefillTests.swift`(新) | 三 tier 预填映射逐 token;tier 切换重置;token 全集 ≤50 字符去重(zod 边界) |
| `Modules/StudentKit/Tests/StudentKitTests/Repository/OnboardingRepositoryTests.swift`(新) | InMemory:upsert 三态合并;complete 缺项镜像(逐必填字段);completed 后 1RM 锁;幂等 complete |
| `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/ProfileSummaryFormatterTests.swift`(新) | 九卡摘要行格式化(年龄计算 / 单位换算显示 / 空字段省略);1RM 卡只读态;404 空态 |
| 计算器(D7) | `E1RMCalculator` 既有单测不动;新增 sheet VM 测试:估算值 / 90% 值 round 0.5 网格 |

### 不做什么

**spec 033 范围**:
- 教练评估卡的数据接入(`GET /students/:id/evaluation-summary`)与摘要/展开 UI
- 教练侧查看学员完整资料页(接收队列"查看完整资料"复用本 spec 的 `OnboardingProfileDTO`,UI 归 033)
- 教练改 1RM(`PUT /coach/students/:id/one-rm`)入口

**V0.1.x defer**:
- **自练学员 onboarding 入口**(D9;backend 已对 self_train 开放,iOS 不开)
- **wiki §D 完整 4 级修改权限**(Type B 改动推送教练依赖 APNs;训练日/gym_tier 的 Type A 锁随 033/正式 cycle 概念再评估)— V0.1b 全部 silent(D2)
- 深蹲/硬拉姿势线稿动画图(Step 2 先纯文字卡)
- onboarding 末尾"跟教练练 / 自己练" mode 选择(wiki §F.2;V0.1b 路径恒"跟教练",mode 由注册 role 决定)
- 上传计划 OCR / 结构化解析(V1.5 评估)

**明确不做(产品已裁)**:
- 人体解剖图肌群选择(chip 已满足;纯视觉投入)
- 多角色单用户(wiki §F 整段 V1.5 deferred)
- 1RM 比赛日自动 update(V2)
- 教练端额外 3 字段(训练水平等)— 教练侧概念,与学员 onboarding 无关

## 技术要求

### 031↔032 接口契约(与 031 §技术要求同文,改一处必须改两处)

| 物 | 定义方 | 本 spec 角色 |
|---|---|---|
| `PendingBindCodeStoring` / `PendingBindCode` | 031 | complete handoff 消费 + 清除(§6 决策树) |
| `BindRepository.submitBindRequest` | 031 | handoff 调用方;错误处置表照 031 |
| `isOnboardingComplete` 闭包 | 031 定义注入点 | 本 spec 提供真实现(`fetchProfile?.isCompleted ?? false`,fetch 失败按 false 处理 → 宁可多进一次向导,resume 无害) |
| `onboardingFlow` view builder | 031 定义槽位 | 本 spec 提供 `OnboardingWizardView(pending:onCompleted:)` |

### 落地顺序

031 PR1(契约物)→ 本 spec 全部 PR 可开;本 spec 合入前 031 的 BindGate 以 `{ true }` 退化运行(输码即发请求),合入后切真实现 — **切换属本 spec PR 3 的装配改动**,不是 031 的回头改。

### PR 切分

| PR | 内容 | 依赖 |
|---|---|---|
| 1 | CoreModels 实体/词表/Patch + RepositoryContracts + Networking DTO/encoder/APIClient + 双仓实现 + DraftStore + 单测 | 031 PR1 |
| 2 | 向导 7 步 UI + VM + 计算器 sheet + handoff + 完成过渡页 | PR 1 |
| 3 | 九卡 + 编辑态 + AppShell/BindGate 装配切换 + DEMO seed | PR 1(与 PR 2 并行,装配段在 PR 2 后收口) |

每 PR 过 `/review-loop` 收敛(#148 规则)。

### Wire / 校验

- snake_case:`OnboardingPatchDTO` 显式 CodingKeys(手写 encode);`OnboardingProfileDTO` 走 `MeetPRCodec` 自动转换 + decimal/date 自定义字段例外
- 服务端 zod 是真 gate,iOS UI gating 只是 UX;**iOS 永不产出非法值**(§3 边界表)是单测验收面
- `birth_date` / `competition_date` 全链路 String("yyyy-MM-dd"),生成用 `WireFormatting.dateOnlyString`(030 先例)

### 版本 / 兼容

- iOS 17.0+,纯 SwiftUI,无第三方库;表单控件优先复用 DesignSystem 既有 atomic 组件 + spec 023 `PlanningCountPicker`/`PlanningNumberField` 先例
- Swift Testing(`@Test` / `#expect`)

## 验收清单

- [ ] 词表 enum 与 backend `src/db/types.ts` 逐字单测过(8 词表 + MuscleGroup 白名单)
- [ ] DTO 29 字段全量 fixture 闭环;Patch 三态 JSON 断言过;无未知 key
- [ ] 向导 7 步 simulator 全流程真跑:每步控件 / 必填 gating / 条件显隐(备赛→日期)/ lb 切换换算显示
- [ ] Step 3 计算器:输入 100kg×5@RPE8 → 估算 ≈128kg(028 fixture 同源)/ 90% ≈115.5kg,round 0.5 网格
- [ ] Step 4:tier 切换重置预填(confirm);不足 2 天禁下一步且 `training_days` 不出现在 PUT body
- [ ] 中途退出续填:Step 3 填一半杀 app → 重启 BindGate 自动回向导、预填已存值、落正确 step
- [ ] 分步 PUT 失败(飞行模式)→ banner + 可继续;complete 前全量 PUT 把缺的补齐(staging 抓包验证)
- [ ] complete 422 → 跳最早缺字段 step + 高亮;补填后重 complete 过
- [ ] handoff 5 路:201 → 待接收页;假码 → 回输码页(姓名预填、不重过向导);网络失败 → 重试按钮 + 杀 app 重启自动补发(031 resume 联测)
- [ ] staging 真环全链路:xty 新学员账号 输码 → 7 步 → complete → David 教练端接收队列可见(摘要 9 项有数据)
- [ ] 九卡:摘要行格式 per wiki 线框;每卡编辑保存后摘要刷新;1RM 卡只读 + 锁定文案;教练评估占位卡;404 空态
- [ ] 1RM 永不出现在任何编辑 patch(单测 + grep 验收)
- [ ] Step 6 降级:上传卡 disabled、肌群可选、`upload_attachment_ids` 恒 absent
- [ ] DEMO_MODE:demo 学员九卡满数据可演示;CI 全过

## 估时(给 implementer 参考)

| 块 | 估时 |
|---|---|
| PR 1:实体/词表/Patch + DTO/encoder + 双仓 + DraftStore + 单测 | 1.8d |
| PR 2:向导壳 + Step 1-5、7(field 组件共享层) | 2.2d |
| PR 2:Step 6 降级版 + 计算器 sheet | 0.5d |
| PR 2:complete handoff + 过渡页 + 联测 | 0.7d |
| PR 3:九卡扫视态 + 编辑态 + formatter | 1.3d |
| PR 3:装配切换 + DEMO seed + staging 手测 | 0.5d |
| **合计** | **7d** |

## 风险 / 待 implementer 关注

1. **zod `.strict()` 是全字段名雷区**:任何 key 拼错/多发 = 整个 PUT 400。`OnboardingPatchDTO` 的 CodingKeys 必须逐字段抄 backend §migrations 0013 列名;DTO 单测的 JSON 字典断言是唯一防线,别省
2. **decimal 字符串格式**:backend regex `^\d+(\.\d{1,2})?$` — `encodeDecimalString`(NSDecimalNumber stringValue)对用户输入 `83.456` 会原样发出导致 400;UI 输入层必须限小数位(身高 1 位、体重/1RM 2 位),encode 前再 round 一次双保险。禁止科学计数法路径
3. **`training_days` 的 min(2) 陷阱**(D11):用户选了 1 天就退出 → 该字段 absent 不发,本地草稿保留;**不要**发单元素数组(400 会把整步 PUT 拖死)
4. **`upload_attachment_ids` 全量替换语义**(backend D17):absent = 不动,`[]` = 清空所有上传。降级版恒 absent;集成版只在 Step 6/训练资料卡明确保存时发全集。把 `.null` case 对该字段禁用(它不是 nullable 列)
5. **D6 合并策略的时钟**:`savedAt > server.updatedAt` 比较跨设备不可靠(本地时钟漂移)— V0.1 单设备场景接受;实现时给 1min 容差并 log,别静默吞
6. **1RM 锁是流程保证不是 if 保证**:completed 后唯一的编辑入口是九卡,1RM 卡无编辑态,`patch(forStep:)` / 卡编辑 patch 构造器物理上不含 1RM 字段(completed 路径);万一撞 `403 ONE_RM_LOCKED`(理论不可达)→ toast"1RM 已锁定,请联系教练修改"兜底,不崩
7. **背/竖脊肌合并**(D4)别被"还原 wiki 线框 11 chip"好心破坏 — 两 chip 同 token = zod uniqueItems 400
8. **年龄/摘要计算口径**:`birth_date` 是 date-only String,年龄 = 本地日历整年差(backend D13 把计算留给客户端,教练端 033 同口径,避免两端岁数差 1)
9. **lb 模式只是镜片**(D1):换算只在 formatter/parser 层,draft 与 wire 恒公制;切单位不改任何存量数值,只改显示。单测覆盖 83kg ↔ 183lb 往返不漂移(round-trip 容差)
10. **向导组件复用别过度抽象**:field 组件共享层(wizard ↔ 卡编辑)是为了同源不漂移,不是做表单框架;每个 section 一个 View struct + 绑定即可

## Implementation Notes

实装与草稿的偏离(2026-06-11,与 031 同分支交付):

1. **`DeadliftStyle` 复用既有 `DeadliftStance`**(CoreModels,rawValue `conventional/sumo` 与 backend 逐字一致)— 不另造同义新类型。
2. **`OnboardingProfile` 增带 `userId`**:wire 响应携带 `user_id`,实体保留(九卡与 033 教练侧查档案都按 student 维度取数)。
3. **lb 模式身高显示为总英寸单栏**(后缀 "in"),非 ft+in 双栏 — V0.1b 简化,D1 镜片语义不变(draft 与 wire 恒公制);ft/in 双栏归 V0.1.x 打磨。
4. **可见默认值即选中**:Step 1 生日 wheel 进入即落 2000-01-01(wiki 默认值),Step 2 训练年限滑块进入即落 0("<1 年" 锚点可见)。这两项的必填 gating 由可见默认满足;其余必填(性别/身高/体重/1RM/训练日/场馆/恢复四滑/备赛)仍需显式操作。
5. **卡 7(比赛/备注)与卡 8(伤病记录)共用 step-7 patch builder**:编辑页只显示各自字段,保存按 `patch(forStep: 7)` 发 step-7 六字段全集(draft 持有未编辑字段现值,无数据丢失);`ProfileCardKind.patchStep` 物理上永不为 3 → 1RM 永不入卡编辑 PUT(risk 6,单测钉死)。
6. **D6 合并容差**:local 覆盖条件为 `local.savedAt > server.updatedAt - 60s`(近平局偏向本地 — 用户刚敲的数据),非严格大于。
7. **D7 计算器取整顺序**:保守值 = 原始 e1RM × 0.9 后再落 0.5 网格(100×5@8 → 估算 128.0 / 保守 115.5,与验收 fixture 一致;先取整再 90% 会得 115.0)。
8. **handoff 回调带 `BindHandoffOutcome` 载荷**(031 Implementation Notes #4 同文):INVITE_CODE_INVALID 路径 BindGate 直落 `.needsCode(prefill: displayName, notice: .invalidCode)`,不重复 POST。
9. **空集语义**:muscle/equipment/injury 空集发 `.null`(显式清空)而非空数组;`training_days` 不足 2 项 absent(risk 3);`upload_attachment_ids` 全程 absent(§8 降级版),encoder 对其 `.null` 直接 debug assert 拒绝(risk 4)。
10. **`OnboardingPatchDTO` 防线落实**:CodingKeys 全量手写 snake_case(`squat_1rm_kg` 等逐字,key 策略对纯小写 snake_case 是 no-op);非空列收到 `.null` 一律 debug assert + 略过(物理上无法产出 400 body);decimal 按列 scale(身高 1 位 / 体重·1RM 2 位)round 后字符串化。

测试:向导 VM(resume/D6 合并/分步 PUT 隔离/422 跳步高亮/handoff 5 路)+ draft 步进 gating 与 patch 矩阵 + D12 19 字段映射 + DraftStore + 器械预填 + InMemory 仓(18+1 gate 镜像/1RM 锁/幂等)+ 摘要 formatter + 估算器与单位镜片(StudentKit);29 字段 fixture + Patch 三态 JSON 断言 + missing_fields 信封(Networking);词表 + Profile roundtrip + Patch 语义(CoreModels)。模拟器 7 步全流程真跑、staging 全链路(xty 新号输码→7 步→complete→David 接收队列)留待主 session 手测(验收清单对应项未勾)。

## 上游 / 下游

**上游**:
- backend 005-bind-eval-profile(已 live):onboarding 端点 + 0013 schema + 词表
- spec 031:`PendingBindCodeStore` / `BindRepository` / BindGate 注入点(契约表)
- spec 028:`E1RMCalculator`(计算器复用)+ `MyProfileView` 现状
- ADR-009(草稿持久化边界)/ ADR-005(模块归属)
- student-onboarding v2.4(7 步 + 九卡 + §D 权限)/ evaluation-workflow v1.1(funnel 顺序)

**下游**:
- **spec 033**:教练评估卡接数据(`GET /students/:id/evaluation-summary`);教练接收队列"查看完整资料"复用 `OnboardingProfileDTO` + 词表中文映射(`OnboardingSummaryFormatter` 抽到可共享位置由 033 裁量);教练改 1RM 入口;评估期页
- **spec 027 集成 follow-up**:Step 6 / 训练资料卡接 `VideoUploadActor` + 文档无转码上传路径(归属 027 amendment 或独立小 spec,集成时拍板);031 待接收页资料计数随之生效
- V0.1.x:自练 onboarding 入口;4 级修改权限 + APNs;姿势线稿图;mode 选择
- V1.5:上传计划 OCR;多角色

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-11 | 0.1 | 起草。7 步向导(29 字段逐控件)+ Patch 三态部分更新 + JSON 草稿续填 + complete→绑定 handoff(消费 031 暂存)+ 九卡档案页(1RM 锁定呈现 / 教练评估占位)+ Step 6 上传降级版(027 依赖标注) | Claude |
| 2026-06-11 | 0.2 | 实装落地(与 031 同分支):29 字段实体/Patch 三态/7 步向导/草稿续填/handoff/九卡;偏离见 Implementation Notes | Claude |
