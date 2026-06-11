# 030 — JAI 训练体验三件套(readiness check-in + 组间自动倒计时 + 配片计算器)

- **状态**: Draft
- **PR**: TBD
- **来源**:
  - [V0.1b 完成波决议 §1 ④](~/Brain/wiki/projects/MeetPR/v0_1b_completion_wave.md) — David 2026-06-11 拍板"三件全进";Out 清单锁死 readiness 不算分不调计划
  - [Juggernaut AI 竞品分析](~/Brain/wiki/projects/MeetPR/competitors/juggernaut-ai.md) — 三件套操作逻辑参照源:readiness 2 步 check-in / Auto Timer RPE→时长映射表 / Plate Math 彩色可视化。**只对标操作逻辑,不做其 AI 自动编程**
  - [ADR-001 data-first-not-ai-first](~/Brain/wiki/projects/MeetPR/decisions/001-data-first-not-ai-first.md) — **红线**:readiness 只采集 + 展示给教练,不算 readiness score、不自动调计划
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — 跨 role 纯数学进 CoreModels Domain(spec 028 `E1RMCalculator` 先例),PlateMathCalculator 同级落位
  - 上游 [spec 024 学员端 P0](../024-student-p0-views/SPEC.md) + [spec 028](../028-e1rm-curve-pr-push/SPEC.md) — `TodayWorkoutViewModel.persist` 的 `!previouslyCompleted && completed` 完成边沿 hook 先例,rest timer 挂同一边沿
  - 上游 backend [spec 001 auth](~/Projects/apps/MeetPR-backend/specs/001-auth/SPEC.md) + [spec 003 student-actions](~/Projects/apps/MeetPR-backend/specs/003-student-actions/SPEC.md) — `requireAuth`/`requireRole` 中间件、snake_case wire 约定、`GET /students/:id/sets` 的 student(self)/coach(bound) 授权矩阵,readiness 端点全部照此办理

## 目标

给学员端"练"的体验补上 Juggernaut 风格的三个独立增量,让记训练这件事从"能用"变成"顺手":

1. **Readiness check-in**:学员打开今日训练,先见一个 2 步问卷(可跳过)——第 1 步睡眠/情绪/压力 5 级量表,第 2 步今日主肌群疲劳度(chip 多选 + 轻/中/重档)。数据存 backend,教练在学员详情概览能看到当日状态(教练 UI 在 spec 029 二遍)。**只采集 + 展示,不算 readiness score、不自动调计划**(ADR-001 红线;JAI 的"3 次训练后开始算分"我们明确不做)。
2. **组间自动倒计时(Auto rest timer)**:学员记完一组,按该组 RPE 自动弹组间休息倒计时浮层(JAI 映射:RPE≤6.5→2min / 7–8.5→3min / 9+→4min),可跳过、可 ±30s。纯本地、无持久化。
3. **配片计算器(Plate Math)**:组行重量旁小图标,点开 bottom sheet 显示每边杠片彩色可视化(20kg 杠 + IPF 标准片组,每种无限量)。纯本地纯函数。

三件相互独立,可分 3 个 PR 落地(顺序建议见 §技术要求)。

落地后学员看到啥:

```
[ 打开"锻炼" Tab(今天有训练 & 今日没填过 & 没跳过)]
  ↓ 自动弹 ReadinessCheckinSheet
  ↓ Step 1/2:睡眠 ●●●●○ / 情绪 ●●●○○ / 压力 ●●○○○(右上"跳过")
  ↓ Step 2/2:今天哪里还累?[股四][腘绳][臀][背][胸][肩][肱三头][核心/下背] chip 连点循环 轻→中→重→取消
  ↓ 完成 → 存 backend(同日重填覆盖);跳过 → 当日不再弹
  ↓ 顶栏图标常驻:已填 → tap 重填;未填(跳过后)→ tap 补填

[ 学员 tap 组行 → SetEntrySheet 调重量/次数/RPE → "完成本组" ]
  ↓(首次完成边沿)浮层从底部滑入:◔ 组间休息 2:43   [-30s] [跳过] [+30s]
  ↓ 到点 → "休息结束 💪" + haptic,3s 自动消失;今日最后一组完成 → 不弹(完成 banner 顶上)

[ 组行重量 "100 kg" 旁 ⚖ 小图标 ]
  ↓ tap → PlateMathSheet bottom sheet
  ↓ 杠片可视化(每边):▐25▌▐15▌ + "每边:25 / 15" + "杠 20 kg · 总重 100 kg"
  ↓ 目标 101 kg → 显示 "实际 100 kg(最小增量 2.5 kg)" amber 提示
```

教练看到啥(本 spec 只保证数据可读,UI 归 spec 029 二遍):学员详情概览页一行当日 readiness "睡眠 4 · 情绪 3 · 压力 2 · 疲劳:股四(重) 核心(轻)";没填显示"今日未填"。

## 范围

### 做什么

三件套按依赖从轻到重排:A 配片(纯函数 + 一个 sheet)→ B 倒计时(VM 状态 + 浮层)→ C readiness(双仓:实体/协议/双实现/2 步 UI/backend 表 + 端点)。

---

#### A1. CoreModels Domain 新增 `PlateMathCalculator`(纯函数,无 IO)

位置:`Modules/CoreModels/Sources/CoreModels/Domain/PlateMathCalculator.swift`(新)— 与 `E1RMCalculator` 同级,per ADR-005 §1 跨 role 纯数学;教练端(规划时看配片)将来直接复用,不再搬家。

```swift
/// 杠铃配片计算(spec 030)。V0.1 锁定:20kg 标准杠 + IPF 标准片组每种无限量。
/// 自定义片库 / lb / 15kg 女杠 → V0.1.x(见 §不做什么)。
public enum PlateMathCalculator {
  public static let barWeightKg: Double = 20.0
  /// IPF 标准片面额,降序。所有面额都是 1.25 的倍数(= 2 的负幂和),
  /// Double 二进制可精确表示,本计算器全程无浮点误差。
  public static let plateDenominationsKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

  public struct Loadout: Hashable, Sendable {
    public let requestedKg: Double        // 学员输入的目标重量
    public let achievedKg: Double         // 取整后实际可配总重
    public let platesPerSideKg: [Double]  // 每边片清单,大→小,含重复(如 [25, 25, 10, 1.25])
    public var isExact: Bool { achievedKg == requestedKg }
  }

  /// 取整规则(锁定):每边最小片 1.25kg → 总重网格 = 2.5kg。
  /// 非 2.5 倍数 → 四舍五入到最近网格点(.5 远离零进位,
  /// 例:101.25 → 102.5;101.2 → 100)。UI 对 !isExact 显示"实际 X kg"。
  /// target < 20kg(空杠)→ nil,UI 显示"低于空杠重量"。
  public static func loadout(forTargetKg target: Double) -> Loadout? {
    guard target >= barWeightKg else { return nil }
    let steps = ((target - barWeightKg) / 2.5).rounded(.toNearestOrAwayFromZero)
    let achieved = barWeightKg + steps * 2.5
    var remaining = (achieved - barWeightKg) / 2
    var plates: [Double] = []
    for denomination in plateDenominationsKg {
      while remaining >= denomination {
        plates.append(denomination)
        remaining -= denomination
      }
    }
    return Loadout(requestedKg: target, achievedKg: achieved, platesPerSideKg: plates)
  }
}
```

**实装锁定**(防漂移):
- 贪心 大→小 分解。该面额集下贪心结果即最少片数,**不**做动态规划
- 取整 = `.toNearestOrAwayFromZero`(四舍五入),**不**是 floor("宁可少配"听着稳但学员看到 102.5 显示 100 会以为 bug)
- `target == 20` → `platesPerSideKg = []` 合法空杠;`target < 20` → nil
- 入参从 `Decimal`(draft.actualWeight)转 `Double` 后调用;面额全是二进制精确值,无需容差,但 `while remaining >= denomination` 若 implementer 改动计算路径引入误差,以 fixture 测试为准

**PlateMathCalculator fixture**(单测,典型 ≥ 10 + 边界 ≥ 5):

| 目标 kg | 实际 kg | 每边 |
|---|---|---|
| 20 | 20 | (空) |
| 22.5 | 22.5 | 1.25 |
| 25 | 25 | 2.5 |
| 60 | 60 | 20 |
| 62.5 | 62.5 | 20, 1.25 |
| 100 | 100 | 25, 15 |
| 102.5 | 102.5 | 25, 15, 1.25 |
| 107.5 | 107.5 | 25, 15, 2.5, 1.25 |
| 142.5 | 142.5 | 25, 25, 10, 1.25 |
| 170 | 170 | 25, 25, 25 |
| 227.5 | 227.5 | 25, 25, 25, 25, 2.5, 1.25 |
| **21**(取整) | 20 | (空) |
| **101.2**(取整) | 100 | 25, 15 |
| **101.25**(tie,进位) | 102.5 | 25, 15, 1.25 |
| **18** | nil | — |
| **0 / 负数** | nil | — |

#### A2. `StudentKit` 新增 `PlateMathSheet` + 组行图标入口

位置:`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/PlateMathSheet.swift`(新)

入口:`SetRecordRow` 改造 — #149 后整行是一个 Button(开 SetEntrySheet),改为 HStack 内**两个并列 button**:行主体 button(行为不变)+ 目标重量旁 `scalemass` 小图标 button(hit target ≥ 40pt),tap 传 `draft.actualWeight ?? draft.prescribed.weightKg` 给 `TodayWorkoutView` 的 `@State plateMathTargetKg: Double?`,sheet(item:) 弹 `PlateMathSheet`。无重量的组行(weightKg nil)不显示图标。

`PlateMathSheet`(`.presentationDetents([.medium])`,风格对齐 `SetEntrySheet`):
- 标题:总重 + "杠 20 kg"
- **杠片可视化**:水平杠线 + 每边片按面额渲染彩色圆角矩形(高 ∝ 面额,25 最高),只画一边 + "每边"文案。IPF 标准色:25 红 / 20 蓝 / 15 黄 / 10 绿 / 5 白 / 2.5 黑 / 1.25 银。**色值硬编码在该 view 内**(领域颜色非主题色,不进 `Color.MeetPR.*` token);5kg 白片与 2.5kg 黑片各加 `Color.MeetPR.border` 描边保证双模式可见
- 片清单文字:"每边:25 ×1 · 15 ×1 · 2.5 ×1"(同面额聚合计数)
- `!isExact` → amber 行 "目标 101 kg → 实际 100 kg(最小增量 2.5 kg)";`target < 20` → "低于空杠重量(20 kg)" 空态

---

#### B1. `StudentKit` 新增 `RestTimerPolicy`(enum,纯映射)

位置:`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/RestTimerPolicy.swift`(新)— 映射表是学员端 UX 参数而非跨 role 领域数学,留 StudentKit(与 PlateMathCalculator 落位不同,有意为之)。

```swift
/// RPE → 组间休息秒数,参数照搬 JAI(竞品分析 §3 Auto Timer)。
/// V0.1 不做自定义映射;改表 = 改这里 + fixture,别处不许出现这些常量。
enum RestTimerPolicy {
  /// | RPE        | 时长 |
  /// |------------|------|
  /// | nil(没填) | 3min |
  /// | ≤ 6.5      | 2min |
  /// | 7 – 8.5    | 3min |(JAI 表 7–7.5 与 8–8.5 同为 3min,实现合并为一段)
  /// | 9+         | 4min |
  static func restSeconds(forRPE rpe: Decimal?) -> Int {
    guard let rpe else { return 180 }
    if rpe < 7 { return 120 }
    if rpe < 9 { return 180 }
    return 240
  }
}
```

#### B2. `TodayWorkoutViewModel` 完成边沿挂 timer 状态

`persist()` 内 spec 028 e1RM hook 的**同一个** `!previouslyCompleted && completed` 边沿,追加:

```swift
public struct RestTimerState: Equatable, Sendable {
  public let endsAt: Date        // wall-clock 终点;后台回前台剩余时间自动正确
  public let totalSeconds: Int   // 浮层进度条分母
}

// TodayWorkoutViewModel 新增
public private(set) var restTimer: RestTimerState?

// persist() 内既有边沿处:
if !previouslyCompleted, completed {
  await recordE1RMPoint(for: draft, log: log, studentID: studentID)   // spec 028 既有
  startRestTimer(after: draft, drafts: nextDrafts)                    // 本 spec 新增
}

private func startRestTimer(after draft: SetRowDraft, drafts: [SetRowDraft]) {
  // 今日最后一组:不弹(下一刻是 DayCompletionBanner,倒计时无意义)
  guard !drafts.allSatisfy(\.completed) else {
    restTimer = nil
    return
  }
  let seconds = RestTimerPolicy.restSeconds(forRPE: draft.actualRPE)
  restTimer = RestTimerState(
    endsAt: now().addingTimeInterval(TimeInterval(seconds)), totalSeconds: seconds)
}

public func adjustRestTimer(bySeconds delta: Int) {
  guard let timer = restTimer else { return }
  let remaining = timer.endsAt.timeIntervalSince(now()) + TimeInterval(delta)
  // 剩余 clamp [0, 900];减到 0 = 立即结束
  let clamped = min(max(remaining, 0), 900)
  restTimer = RestTimerState(
    endsAt: now().addingTimeInterval(clamped), totalSeconds: timer.totalSeconds)
}

public func skipRestTimer() { restTimer = nil }
```

**关键 invariants**:
- 仅完成边沿触发:`commitSet` 对**已完成组**的"保存修改"不重起 timer(`previouslyCompleted == true`);取消勾再勾 = 新边沿,重起,接受(本地 UX,无持久化无副作用)
- 连续完成两组:新 timer **覆盖**旧 timer(重起新时长)
- 纯本地零持久化:杀 app timer 消失,V0.1 接受;`endsAt` 用 wall-clock,**前台 only** 但锁屏/切后台回来剩余时间自然正确,不需要 background task

#### B3. `RestTimerOverlay` UI

位置:`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/RestTimerOverlay.swift`(新)

- `TodayWorkoutView` 经 `.safeAreaInset(edge: .bottom)` 挂浮层(`viewModel.restTimer != nil` 时出现,滑入滑出动画),不遮 tab bar、不挡组行 tap
- `TimelineView(.periodic(from:by: 1))` 驱动:剩余时间 `m:ss` 大号 monospacedDigit + 细进度条(`remaining / totalSeconds`,`Color.MeetPR.brandRed`)
- 三按钮:`[-30s]` `[跳过]` `[+30s]` → 调 B2 的 VM 方法
- 到点:文案换 "休息结束 💪" + `UINotificationFeedbackGenerator` success haptic(`#if canImport(UIKit)` 包住,macOS 目标跳过),3s 后 VM 清状态自动消失。无声音、无推送(V0.1.x)

---

#### C1. CoreModels 新增 `ReadinessCheckin` 实体

位置:`Modules/CoreModels/Sources/CoreModels/Entities/ReadinessCheckin.swift`(新)

```swift
public struct MuscleFatigue: Codable, Hashable, Sendable {
  public let muscleGroup: MuscleGroup   // 仅 allowedMuscleGroups 8 个 case 合法
  public let severity: Int              // 1 轻 / 2 中 / 3 重
  public init(...) { ... }
}

public struct ReadinessCheckin: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  /// 学员本地日历日 "yyyy-MM-dd"(复用 Networking.WireFormatting.dateOnlyString 生成)。
  /// 用 String 不用 Date:这是日历日语义,Date+ISO8601 编码会踩 UTC 午夜时区 bug。
  public let checkinDate: String
  public let sleepQuality: Int          // 1-5,5 = 最好
  public let mood: Int                  // 1-5,5 = 最好
  public let stress: Int                // 1-5,5 = 最轻松 —— 三项方向统一"高 = 好"
  public let muscleFatigue: [MuscleFatigue]
  public let submittedAt: Date
  public init(...) { ... }

  /// 力量举相关 8 主肌群白名单 —— chip 顺序 + 前后端校验的唯一 source of truth,
  /// backend zod whitelist 必须与此逐字对齐(全量 MuscleGroup 19 case 不开放)
  public static let allowedMuscleGroups: [MuscleGroup] = [
    .quad, .hamstring, .glute, .back, .chest, .shoulder, .triceps, .core,
  ]
}
```

**量表方向锁定**:三项统一 1 = 最差 / 5 = 最好。压力项 UI 文案做反转("1 压力爆表 … 5 很轻松"),**数据不反转** — 教练扫一眼三个数字方向一致,不用心算哪项是反的。

#### C2. `RepositoryContracts` 新增 `ReadinessRepository` 协议

位置:`Modules/RepositoryContracts/Sources/RepositoryContracts/ReadinessRepository.swift`(新)

```swift
/// 学员 readiness check-in 存取(spec 030)。V0.1 只采集 + 当日读,
/// 不算 readiness score(ADR-001);教练端消费走同一 fetch(spec 029 二遍)。
public protocol ReadinessRepository: Sendable {
  /// 同日重复提交 = 覆盖(upsert by (studentId, checkinDate))
  func submit(_ checkin: ReadinessCheckin) async throws
  /// checkinDate "yyyy-MM-dd";没填过返 nil
  func fetchCheckin(studentId: UUID, checkinDate: String) async throws -> ReadinessCheckin?
}
```

#### C3. `StudentKit` 双实现

位置:`Modules/StudentKit/Sources/StudentKit/Repository/`(新 2 文件)

- `InMemoryReadinessRepository`:actor 持 `[String: ReadinessCheckin]`(key = `"\(studentId)|\(checkinDate)"`),submit 直接覆盖。DEMO seed:**昨日已填一条**(验"已填/重填"态 + 029 二遍教练侧 demo 数据)、**今日不填**(验弹窗)
- `BackendReadinessRepository`:actor,对齐 `BackendStudentTrainingLogRepository` 既有模式(`APIClient` + `SessionStateReader`);`Networking` 加 2 个端点方法 + `ReadinessCheckinDTO`(snake_case wire,`MeetPRCodec` 自动转换)。**不做本地 cache**(数据极小、当日语义,失败就是失败)

#### C4. `ReadinessCheckinViewModel` + 弹出 gate

位置:`Modules/StudentKit/Sources/StudentKit/Features/Readiness/ReadinessCheckinViewModel.swift`(新,Feature 目录新建 `Readiness/`)

```swift
@Observable @MainActor
public final class ReadinessCheckinViewModel {
  public enum Gate: Equatable {
    case unknown          // 还没查
    case needed           // 今日没填、没跳过 → view 弹 sheet
    case done(ReadinessCheckin)   // 今日已填 → 顶栏图标"已填",tap 重填(预填旧值)
    case skippedToday     // 今日跳过 → 不再自动弹;顶栏图标可手动补填
  }
  public private(set) var gate: Gate = .unknown

  private let repo: any ReadinessRepository
  private let skipStore: ReadinessSkipStore   // UserDefaults 包装,key
                                              // "readiness.skipped.<studentId>.<yyyy-MM-dd>";可注入假实现测试
  public func load(studentId: UUID, date: Date) async { ... }   // fetch → gate 三态
  public func submit(_ draft: ReadinessDraft) async -> Bool { ... } // upsert 成功 → .done
  public func skip(studentId: UUID, date: Date) { ... }          // 记 skip 标记 → .skippedToday
}
```

**Gate 规则**(全部条件同时满足才自动弹):今天日期 && `TodayWorkoutViewModel.state` 已 `.loaded` 且 drafts 非空(**rest day / 无计划不弹**)&& gate == `.needed`。每日最多自动弹 1 次;跳过/提交失败放弃后当日靠顶栏图标手动进。

#### C5. `ReadinessCheckinSheet`(2 步 UI)

位置:`Modules/StudentKit/Sources/StudentKit/Features/Readiness/ReadinessCheckinSheet.swift`(新)

- `TodayWorkoutView` `.sheet` 弹出(`.presentationDetents([.large])` 或 `.medium` 由 implementer 按内容高度定),两步间 step indicator "1/2"
- **Step 1**:三行 5 级量表(睡眠质量"昨晚睡得怎么样" / 情绪"今天状态如何" / 压力"今天压力大吗"),每行 5 个可点圆点 + 两端锚点文案;**三项全选**才激活"下一步"
- **Step 2**:"今天哪些肌群还累?" — `allowedMuscleGroups` 8 个 chip 流式布局,中文名走既有展示映射(股四/腘绳/臀/背/胸/肩/肱三头/核心·下背);**连点循环** 未选 → 轻(1)→ 中(2)→ 重(3)→ 取消,选中 chip 显示档位点(· ·· ···)。可全不选(今天不累是合法答案),"完成"常可点
- 右上"跳过"两步常驻 → `skip()` 收 sheet
- 提交失败:sheet 不收,inline error + "重试";"放弃" = 视同跳过(当日不再自动弹,V0.1.x 再加补填提醒)
- 重填:顶栏图标(`heart.text.square`)tap → 同 sheet 预填当日已有值,提交走同一 upsert

#### C6. `TodayWorkoutView` / `StudentRootView` 装配

- `TodayWorkoutView` init 增参 `readiness: any ReadinessRepository`,内部建 `ReadinessCheckinViewModel`;`.task` 里 `load` 完今日计划后查 gate;toolbar 加 readiness 图标(已填/未填两态)
- `StudentRootView` 两个 init 透传(demo init 用 seeded `InMemoryReadinessRepository`);AppShell 真环装配处对齐既有 Backend* 注入模式加 `BackendReadinessRepository`
- **不动 tab 结构**(spec 028 后 5 tab:仪表盘/锻炼/历史/反馈/我的)

#### C7. Backend 增量(MeetPR-backend 仓,migration + 2 端点;体量小,不另开 backend spec,本节即权威)

**Migration** `000X-init-readiness-checkins.sql`(编号 = 落地时 `db/migrations/` 最大号 +1;0007 已被 backend spec 004 附件管线预定,预计本表 = 0008):

```sql
CREATE TABLE readiness_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  checkin_date DATE NOT NULL,
  sleep_quality SMALLINT NOT NULL CHECK (sleep_quality BETWEEN 1 AND 5),
  mood SMALLINT NOT NULL CHECK (mood BETWEEN 1 AND 5),
  stress SMALLINT NOT NULL CHECK (stress BETWEEN 1 AND 5),
  muscle_fatigue JSONB NOT NULL DEFAULT '[]'::jsonb,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, checkin_date)
);
```

**端点**(均 `requireAuth`,错误信封 `{ error: '<MACHINE_CODE>' }`,wire 全 snake_case per backend 003 约定):

| Method + Path | Roles | Request | Success |
|---|---|---|---|
| `POST /students/me/readiness` | student | `{ checkin_date, sleep_quality, mood, stress, muscle_fatigue: [{ muscle_group, severity }] }` | `201 { id, submitted_at }` |
| `GET /students/:id/readiness?date=YYYY-MM-DD` | student(self) / coach(accepted bind) | — | `200 { checkin: {...} \| null }` |

- `POST` 语义 = **upsert**:`ON CONFLICT (student_id, checkin_date) DO UPDATE SET sleep_quality/mood/stress/muscle_fatigue/updated_at`,覆盖后仍返 201(对齐 `POST /sets/log` 风格)
- zod:`checkin_date` 严格 `YYYY-MM-DD`;三量表 int 1-5;`muscle_fatigue` 数组 ≤ 8、`muscle_group` ∈ 8 值白名单(逐字对齐 C1 `allowedMuscleGroups` rawValue:`quad/hamstring/glute/back/chest/shoulder/triceps/core`)、`severity` int 1-3、`muscle_group` 不得重复;**校验在服务端 zod,这是真 gate**,iOS 端校验只是 UX
- `GET` 授权矩阵照抄 `GET /students/:id/sets`(backend 003):student 仅 self;coach 需对该 student 有 `status='accepted'` 的 bind_requests 行;其余 403。`date` 必填,非法 → 400 `VALIDATION_ERROR`
- **路由注册顺序**:`/students/me/readiness` 的字面量 `me` 段必须先于 `/students/:id/readiness` 注册(Express 按序匹配,否则 `me` 被 `:id` 吞掉 UUID parse 报错)

**POST 请求示例**:

```json
{
  "checkin_date": "2026-06-11",
  "sleep_quality": 4,
  "mood": 3,
  "stress": 2,
  "muscle_fatigue": [
    { "muscle_group": "quad", "severity": 3 },
    { "muscle_group": "core", "severity": 1 }
  ]
}
```

#### C8. 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/CoreModels/Tests/CoreModelsTests/PlateMathCalculatorTests.swift`(新) | §A1 fixture 全表:典型 ≥ 10 + 边界(<20 → nil / =20 空杠 / 21 取整到 20 / 101.2 → 100 / **101.25 tie → 102.5** / 0、负数 → nil);Loadout.isExact 两侧 |
| `Modules/CoreModels/Tests/CoreModelsTests/ReadinessCheckinTests.swift`(新) | Codable snake_case wire roundtrip(含 muscle_fatigue 数组);allowedMuscleGroups 恰好 8 个且无重复 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/RestTimerPolicyTests.swift`(新) | 映射 9 fixture:nil→180 / 5→120 / 6.5→120 / 7→180 / 7.5→180 / 8→180 / 8.5→180 / 9→240 / 10→240(边界值全在 0.5 网格上) |
| `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutRestTimerTests.swift`(新) | 完成边沿起 timer 且时长按 RPE;已完成组"保存修改"不重起;连续完成覆盖旧 timer;今日全完成不弹;±30s clamp [0, 900];skip 清状态(`now` 注入假时钟) |
| `Modules/StudentKit/Tests/StudentKitTests/Repository/ReadinessRepositoryTests.swift`(新) | InMemory:submit/fetch;**同日重提交覆盖**(字段全换);不同日两条共存;不同 student 隔离 |
| `Modules/StudentKit/Tests/StudentKitTests/Features/Readiness/ReadinessCheckinViewModelTests.swift`(新) | gate 三态(无记录→needed / 有记录→done / skip 标记→skippedToday);submit 成功转 done;skip 写标记;失败留 needed 不弹第二次(假 skipStore 注入) |
| backend `tests/readiness.test.ts`(新) | zod 拒绝:量表越界 / severity 越界 / muscle_group 非白名单 / 重复 muscle_group / camelCase 字段 / 坏日期;**upsert 同日覆盖**(两次 POST 后 GET 是第二次的值);授权矩阵:student self 200 / 他人 403 / bound coach 200 / unbound coach 403;date 缺失 400 |

### 不做什么

**V0.1.x defer**:
- **自定义片库 / lb 单位 / 自定义杠重**(15kg 女杠、专项杠):V0.1 锁 20kg 杠 + IPF 标准组每种无限量;自定义片库是首个该做的(健身房没有 1.25 片很常见)
- **timer 推送通知 / 后台续跑 / 声音 / 自定义映射表**:V0.1 前台浮层 + haptic only;后台到点提醒需通知权限,V0.1.x 一并做
- **readiness 补填(非当日)/ 历史趋势曲线 / 提醒推送**:V0.1 只有"今天";教练端只读当日行(029 二遍)
- **人体解剖图肌群选择**(JAI 三视图):V0.1.x 也大概率不做,chip 多选已满足采集;解剖图是纯视觉投入
- **教练端 readiness 趋势聚合 / 跨学员对比**:cockpit V0.2 净增量,本 wave 不碰(per [[coach-cockpit]] 边界)

**V0.2+ defer(ADR-001 红线,解锁需新 ADR + David 拍板)**:
- **readiness score 计算 / 自动调计划 / 容量建议**:JAI 的核心 AI 行为,我们的定位是数据给真人教练。任何"根据 check-in 自动改今天的组数重量"都不做
- 基于 readiness 的 intra-session 调整(JAI 招牌)同上不做
- JAI 式 per-lift Daily Readiness Ratings(按 Squat/Bench/Deadlift 分项打分)

## 技术要求

### PR 切分与落地顺序(三件独立,依赖递增)

| PR | 内容 | 依赖 |
|---|---|---|
| 1 | **配片**:A1 + A2 + fixture | 无(纯本地纯函数) |
| 2 | **倒计时**:B1 + B2 + B3 + 测试 | 无(纯本地,挂 028 既有边沿) |
| 3 | **readiness**:C1–C8(iOS + backend 同波;backend migration/端点可先行单独小 PR) | backend 部署窗口(staging migration) |

PR 1/2 在 wave 1 可并行直落;PR 3 进 wave 2("030 readiness 双端" per wave 决议 §3)。每个 PR 过 `/review-loop` 收敛(#148 规则)。

### 模块归属(锁定)

| 物 | 归属 | 理由 |
|---|---|---|
| `PlateMathCalculator` | CoreModels `Domain/` | 跨 role 纯数学(教练规划期复用),E1RMCalculator 同级先例 |
| `RestTimerPolicy` | StudentKit `Features/TodayWorkout/` | 学员端 UX 参数,非领域数学;教练端永远用不到 |
| `ReadinessCheckin` / `MuscleFatigue` | CoreModels `Entities/` | 双端共享实体 |
| `ReadinessRepository` 协议 | RepositoryContracts | 既有惯例(E1RMRepository 同处) |
| InMemory / Backend 实现 | StudentKit `Repository/` | 既有惯例;教练端消费方式归 029 二遍决定(挪共享或 CoachKit 对等实现,本 spec 不预设) |
| 三件套全部 UI | StudentKit | wave 决议;PlateMathSheet 将来若教练复用再下沉 DesignSystem(E1RMChart 先例),V0.1 不动 |

### 日期与时区(readiness)

- `checkin_date` = **学员设备本地日历日**,客户端用 `WireFormatting.dateOnlyString`(既有)生成后上送;服务端存 `DATE` 不做时区换算
- 23:59 开始填、00:01 提交 → 记提交时刻的本地日。边缘可接受,不做会话级日期锁
- 可重入语义 = `(student_id, checkin_date)` 唯一 + upsert,**这是验收项**

### Wire / 校验

- HTTP snake_case,iOS `MeetPRCodec` 自动转换(backend 003 既有约定);DTO mapping 测试两侧 fixture 对齐
- 肌群白名单唯一 source of truth = `ReadinessCheckin.allowedMuscleGroups`(8 值),backend zod 逐字镜像;新增肌群 = 两侧同步改 + 测试,spec 修订
- 服务端 zod 校验是真 gate;iOS 端 UI 约束(必选三量表等)只是体验

### 版本 / 兼容

- iOS 17.0+,纯 SwiftUI,无第三方库
- 视觉走 `Color.MeetPR.*` / `MeetPRSpacing` / `MeetPRRadius` token;唯一例外 = 杠片 IPF 标准色(领域颜色,view 内硬编码)
- Swift Testing(`@Test` / `#expect`);backend vitest

## 验收清单

- [ ] `PlateMathCalculator` fixture 全表过(典型 ≥ 10 + 边界 ≥ 5,含 101.25 tie 进位、<20 → nil)
- [ ] `PlateMathSheet` simulator 真渲染:彩色可视化 + 每边清单 + 取整 amber 提示 + 低于空杠空态
- [ ] `SetRecordRow` 双 button 结构:图标不抢行主体 tap(两区独立可点验证)
- [ ] `RestTimerPolicy` 9 fixture 过;RPE nil → 180s
- [ ] 完成一组(首次边沿)浮层滑入、时长按该组 RPE;保存修改不重起;今日最后一组不弹
- [ ] ±30s clamp / 跳过 / 到点 haptic + 3s 自动消失;切后台回前台剩余按 wall-clock 正确
- [ ] `ReadinessCheckin` Codable snake_case roundtrip 单测过
- [ ] `InMemoryReadinessRepository` 同日覆盖 / 跨日共存 / 跨 student 隔离单测过
- [ ] 2 步 sheet:Step 1 三项全选才能下一步;Step 2 可空提交;跳过当日不再自动弹、次日再弹;已填态可重填(预填旧值)且覆盖生效
- [ ] rest day / 无计划日不弹 check-in
- [ ] backend migration + 2 端点落 staging;vitest 全过(zod 拒绝矩阵 / upsert 覆盖 / 授权矩阵)
- [ ] `GET /students/:id/readiness` 教练(accepted bind)可读、unbound 403 —— 029 二遍消费前置
- [ ] DEMO_MODE seed:昨日已填一条 + 今日未填(启动锻炼 tab 弹 sheet 可演示)
- [ ] 双仓 CI 全过

## 估时(给 implementer 参考)

| 块 | 估时 |
|---|---|
| A1 `PlateMathCalculator` + fixture | 0.4d |
| A2 `PlateMathSheet` + 组行图标 | 0.6d |
| B1 `RestTimerPolicy` + fixture | 0.1d |
| B2 VM timer 状态 + 单测 | 0.4d |
| B3 `RestTimerOverlay` UI | 0.5d |
| C1–C3 实体 + 协议 + 双实现 + 单测 | 0.7d |
| C4–C6 gate VM + 2 步 sheet + 装配 | 1.2d |
| C7 backend migration + 端点 + vitest | 0.8d |
| seed + simulator 手动跑 + bug 修 | 0.3d |
| **合计** | **5d**(3 PR 可并行压缩) |

## 风险 / 待 implementer 关注

1. **ADR-001 红线别越**:readiness 任何地方不出现 score、加权、建议文案。教练端显示的就是原始值。哪怕"顺手算个平均分"也不行 — 那是 V2 的 ADR 级决策
2. **SetRecordRow 嵌套可点区**:#149 整行是 Button,直接在 label 里塞第二个 Button 手势会抢;按 §A2 拆成 HStack 两个并列 button,图标 hit target ≥ 40×40pt,真机/模拟器手测两区互不串
3. **timer 不引 background task**:`endsAt` wall-clock 推算已覆盖"切走再回来"场景;到点在后台 = 回前台看到"休息结束"态,V0.1 接受。别为这个加通知权限请求
4. **取整方向是四舍五入不是 floor**:fixture 101.25 → 102.5 是有意的 tie 进位 case,别"优化"成 floor
5. **杠片色值别进 token**:IPF 片色是领域常量;进 `Color.MeetPR.*` 会污染主题语义。白片/黑片记得描边
6. **Express 路由顺序**:`/students/me/readiness` 先于 `/students/:id/readiness` 注册,否则 `me` 当 UUID 解析 500
7. **muscle_fatigue 是 JSONB 不是关联表**:8 项封顶、当日快照、无独立查询需求,开表是过度工程;若 V0.1.x 要趋势查询再迁
8. **检查弹窗别变骚扰**:gate 四条件(今天 + loaded 非空 + 未填 + 未跳过)缺一不弹;每日自动弹至多 1 次。内测期 xty 若反馈烦,首选改成 Dashboard 入口卡片而非自动弹(留作调整空间,改动属 Class 1)
9. **`Decimal` → `Double` 转换点**:plate math 入参在 view 层转(`NSDecimalNumber(decimal:).doubleValue`,028 hook 同款);面额运算本身无浮点风险

## Implementation Notes

无(spec PR 阶段)。

## 上游 / 下游

**上游**:
- spec 024 + #149 重设计:`TodayWorkoutView` / `SetEntrySheet` / `SetRecordRow` 现结构
- spec 028:CoreModels Domain 落位先例 + `persist()` 完成边沿 hook(timer 与 e1RM 同边沿共存)
- backend 001/003:auth 中间件、snake_case wire、`GET /students/:id/*` 授权矩阵
- ADR-001(data-first 红线)/ ADR-005(模块边界)
- [[v0_1b_completion_wave]] §3:PR 1/2 进波 1,PR 3 进波 2

**下游**:
- **spec 029 二遍(直接依赖本 spec C7)**:教练学员详情概览加"当日 readiness"行,消费 `GET /students/:id/readiness?date=今天`;教练端 repository 接入方式(共享 or CoachKit 对等实现)由 029 二遍裁量;未填态显示"今日未填"
- V0.1.x:自定义片库 + 杠重 + lb;timer 通知/后台/自定义映射;readiness 补填 + 趋势 + 提醒
- V0.2+:cockpit"聪明信号"若要消费 readiness 趋势,从本表读,不改采集端;readiness score/自动调节需新 ADR 推翻 ADR-001 边界
- 比赛模式(MeetCard port,"比赛模式"愿景):plate math 纯函数可直接复用做试举重量配片

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-11 | 0.1 | 起草。三件套:配片(CoreModels 纯函数 + bottom sheet)/ 组间倒计时(RPE 映射 + VM 边沿 + 浮层)/ readiness 2 步 check-in(实体 + 协议 + 双实现 + backend 表/端点);3 PR 独立落地;ADR-001 不算分红线写死 | Claude |
