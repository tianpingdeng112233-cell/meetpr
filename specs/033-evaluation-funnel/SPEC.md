# 033 — 教练接收队列 + 评估期 + 评估总结(双端 UI)

- **状态**: InProgress
- **PR**: TBD(iOS spec PR + iOS impl PR;**0 backend 工作** — backend spec 005 已全部实装合 staging,本 spec 只消费)
- **来源**:
  - [backend spec 005-bind-eval-profile](~/Projects/apps/MeetPR-backend/specs/005-bind-eval-profile/SPEC.md) — **wire shape 最高权威**(staging `efcdcfd` 已合):接收队列 / accept / reject / 评估期双视角 / 评估总结 / onboarding 读取 / publish 真 gate。实际实装:`src/routes/{bind-requests,evaluations,onboarding}.ts` + `src/handlers/{coach-bind-requests,evaluations,evaluation-summary,onboarding}.ts`
  - [evaluation-workflow.md v1.1](~/Brain/wiki/projects/MeetPR/evaluation-workflow.md) — 产品权威:§3 接收队列 9 项摘要 + 接收二选一模态 + silent 拒;§4 评估期内教练能做/不能做 + 学员视角;§5 评估总结 3 字段 + 摘要/展开 + 推送规则;§6 软推荐排首份计划
  - 上游 [spec 029 coach 学员详情 + 反馈](../029-coach-student-detail-feedback/SPEC.md) — `StudentRosterView` / `StudentDetailView` 5 段 / `FeedbackComposerView`(本 spec 的留言复用)/ RepositoryContracts 模式
  - 上游 [spec 024 学员端 P0](../024-student-p0-views/SPEC.md) + [spec 030](../030-jai-readiness-timer-platemath/SPEC.md) — `TodayWorkoutView`(适应周训练入口复用)/ StudentKit 5 tab 结构
  - 并行 **spec 031 / 032(起草中)** — 学员端 onboarding 7 步 + 绑定请求 / BindGate 路由;接口依赖见 §与 031/032 的接口契约
  - [ADR-005 §1 模块边界](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — CoachKit ⊥ StudentKit;跨端 Repository protocol 走 `RepositoryContracts`,跨端纯数据型走 `CoreModels`

## 目标

把 evaluation-workflow funnel 的 [4]→[9] 段落地成双端 UI:教练从"只能管已绑学员"扩到"能接新学员、能跑评估期、能交付评估总结";学员从"被接收后直接进 5 tab"细化出"评估期中间态"。

**教练看到啥**:

```
学员 Tab(spec 029 已有)
  ↓ 顶部新增"新学员请求"区块(有 pending 才显示;tab 角标 += pending 数)
  ↓ 请求卡片:张三 · 男 · 25 岁 · 83kg / 训练 3 年 / S180 B120 D220
  │          想增强: 股四·腘绳·肩 / 商业健身房 / 备赛 07-25
  │          备注"想突破 200kg 深蹲" / 资料 4 份 / 已等待 2 小时
  ↓ [查看完整资料] → onboarding 29 字段全展示(只读)
  ↓ [接收] → 模态二选一:●进入 7 天评估期(推荐) / ○跳过评估期(熟人,可选原因)
  ↓ [拒绝] → 中性确认 → silent
接收进评估期后 → StudentDetailView 顶部出现评估期条
  ↓ "评估期 · 剩 4 天 13 小时"(超期 → "已超期 2 天,请尽快交付总结")
  ↓ [发适应周](planning 锁 1 周 adaptation) [评估总结] [完成评估]
评估总结编辑器:整体评估(必填) + 训练规划(必填) + 给学员的话(选填)
  ↓ [保存草稿] / [完成并通知学员]
  ↓ 完成 → 软推荐弹窗"要不要立即为他排第一份正式计划?" [立即排] / [稍后]
  ↓ 立即排 → planning 预填(学员 + 1RM + 训练日 + 训练环境)
```

**学员看到啥**:

```
被接收(跳过评估) → 直接正常 5 tab
被接收(进评估期) → BindGate 评估期分支 → 评估期状态页(单页)
  ↓ "评估进行中 · 教练 X 正在评估你" + 倒计时进度条(超期不显示负面提示)
  ↓ 教练留言卡(复用反馈数据) + 适应周训练入口(push 今日训练)
教练完成评估 → BindGate 转正常 5 tab
  ↓ 仪表盘顶部"评估完成 ✓"摘要卡(训练规划/给学员的话前 2 行 + 展开看完整)
  ↓ "我的"Tab 挂"评估总结"永久入口(只读全文)
```

## Backend 契约(已实装,iOS 只消费)

全部 staging live,snake_case wire + NUMERIC-as-string(`"180.00"`)+ DATE-as-text(`"2026-07-25"`),iOS 侧 `MeetPRCodec`(`.convertToSnakeCase` / `.convertFromSnakeCase`)直接对齐。

| Endpoint | 用途 | 本 spec 消费方 |
|---|---|---|
| `GET /coach/bind-requests` | 接收队列(pending,submitted_at ASC),每项含 9 项摘要 `onboarding` 子对象 | 教练队列区块 |
| `POST /coach/bind-requests/:id/accept` body `{skip_evaluation: Bool, skip_reason?: String}` | 接收;`skip_evaluation=false` → 响应携带新建 `evaluation_period` | 接收模态 |
| `POST /coach/bind-requests/:id/reject` body `{}`(strict 空对象) | silent 拒绝 | 拒绝按钮 |
| `GET /students/:id/onboarding` | 29 字段全量 + `upload_attachment_ids`;授权 self / bound coach / **live-pending coach**(D16) | 完整资料页 + planning 预填 |
| `GET /coach/students/:id/evaluation` | (coach=me, student) 最新评估期(含已完成);无 → 404 | 评估期条 |
| `GET /coach/students` | (backend fix #20)每学员回 `status: 'active'\|'in_evaluation'` + `evaluation: {id, expected_end_at, overdue} \| null` | roster 状态(D2 修订) |
| `GET /students/me/evaluation` | 学员视角最新评估期;无 → 404 | BindGate 评估期分支 |
| `POST /coach/evaluations/:id/complete` | 提前/到期完成;已完成 → 409 | [完成评估] |
| `PUT /coach/students/:id/evaluation-summary` body `{overall_assessment, training_plan, words_to_student?, notify_student}` | upsert + version 快照;需 accepted bond | 总结编辑器 |
| `GET /students/:id/evaluation-summary` | self → 本人最新;coach → 只回自己写的那行;无 → 404 | 双端总结呈现 |
| `POST /plans` | 已支持 `kind: 'regular'\|'adaptation'`(optional,缺省 regular;adaptation ⇒ plan_weeks=1 zod 强制) | planning 发适应周 |
| `POST /plans/:id/publish` | **真 gate**:active 评估期内非"1 周 adaptation" → `403 EVALUATION_IN_PROGRESS`;天数越界 → `422 PLAN_DAYS_EXCEED_WEEKS` | publish 错误映射 |

关键 wire 细节(照实装抄,iOS DTO 必须逐字对齐):

- **队列项** `CoachBindRequestItem`:`{id, student_id, display_name, submitted_at, expired_at, onboarding: {completed, gender, birth_date, weight_kg, training_years, squat_1rm_kg, bench_1rm_kg, deadlift_1rm_kg, muscle_groups_to_strengthen, gym_tier, is_competing, competition_date, note_to_coach, upload_count}}`。onboarding 行不存在 → `completed=false` + 全 null + `upload_count=0`。**年龄客户端用 birth_date 算**(D13);**等待时长客户端用 submitted_at 算**。
- **评估期** `EvaluationPeriod`:`{id, student_id, coach_id, bind_request_id, started_at, expected_end_at, completed_at, completion_type, in_progress, overdue}`。`overdue` 读时计算:**到期不自动完成**(D7),iOS 剩余时间用 `expected_end_at` 自己算,不要缓存服务器算好的值。
- **总结** `EvaluationSummary`:`{id, student_id, coach_id, evaluation_period_id, overall_assessment, training_plan, words_to_student, first_saved_at, last_updated_at, is_active}`。`notify_student` 只在 PUT body,响应不回显(落 version 行;推送语义归 iOS,V0.1b 无 APNs → 见 D7 学员侧红点)。
- **accept 错误**:404 `BIND_REQUEST_NOT_FOUND` / 409 `BIND_REQUEST_EXPIRED`(本次请求顺手翻 expired)/ 409 `BIND_REQUEST_NOT_PENDING` / 409 `BIND_ALREADY_BOUND` — 全部 → 刷新队列 + banner,不弹重试。
- **reject body 是 `.strict()` 空对象**:必须发 `{}`,带任何 key 都 400。
- **skip_reason 仅当 skip_evaluation=true 时允许携带**(zod superRefine),UI 层保证。

## 范围

### 做什么

#### 1. CoreModels / RepositoryContracts / Networking 地基

**CoreModels**(跨端纯数据,双 Kit 都读):

| 文件 | 内容 |
|---|---|
| `Entities/EvaluationPeriod.swift`(新) | 上表 wire 字段 1:1,`Codable + Hashable + Sendable + Identifiable`;加便捷计算属性 `remaining(now:) -> (days: Int, hours: Int)?` + `progressFraction(now:)`(started_at→expected_end_at,clamp 0…1) |
| `Entities/EvaluationSummary.swift`(新) | wire 1:1;加 `trainingPlanExcerpt` / `wordsExcerpt`(前 2 行/80 字摘要,纯字符串逻辑) |
| `Entities/Onboarding/OnboardingProfile.swift`(**已存在,031/032 建**) | 29 字段 + `completedAt` + `uploadAttachmentIds`,decimal 字段 `Decimal`(`decodeDecimalIfPresent`),date-only 字段 `String`。033 直接复用零改动(接口契约"先合者建"已兑现) |
| `Entities/Plan/StudentPlanView.swift`(改) | 加 `planKind: PlanKind`,decode 缺省 `.regular`(学员端"无 published regular plan → 等待首份正式计划"行的判定依据;projection/缓存兼容旧数据) |
| `Enums/PlanKind.swift`(新) | `regular / adaptation` |
| `Entities/Plan/TrainingPlan.swift`(改) | 加 `kind: PlanKind`,decode 缺省按 `.regular`(`decodeIfPresent`,不破坏既有 fixture) |

**RepositoryContracts**(protocol,无实装):

```swift
public protocol CoachBindQueueRepository: Sendable {
  func fetchQueue() async throws -> [CoachBindRequestItem]
  func accept(requestID: UUID, skipEvaluation: Bool, skipReason: String?) async throws
    -> (request: BindRequestDecision, evaluation: EvaluationPeriod?)
  func reject(requestID: UUID) async throws
}

public protocol EvaluationRepository: Sendable {
  func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod?   // coach 视角,404 → nil
  func fetchMyEvaluation() async throws -> EvaluationPeriod?                // student 视角,404 → nil
  func completeEvaluation(id: UUID) async throws -> EvaluationPeriod        // 重复完成 throw .alreadyCompleted
}

public protocol EvaluationSummaryRepository: Sendable {
  func fetchSummary(studentID: UUID) async throws -> EvaluationSummary?     // 404 → nil
  func putSummary(studentID: UUID, overallAssessment: String, trainingPlan: String,
                  wordsToStudent: String?, notifyStudent: Bool) async throws -> EvaluationSummary
}

public protocol OnboardingProfileReading: Sendable {                        // 修订:031 已先建 OnboardingRepository,
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile?     // 033 拆出读侧 protocol 并 retrofit
}                                                                           // `OnboardingRepository: OnboardingProfileReading`
```

accept/reject 的典型 4xx 走独立 `CoachBindQueueError`(notFound / expired / notPending / alreadyBound),不复用学员侧 `BindRequestError`(它缺 `BIND_REQUEST_EXPIRED`,且两侧 UI 语义不同)。

`CoachBindRequestItem`(队列项,coach 专用)放 RepositoryContracts 同文件夹的纯数据 struct(protocol 入参出参,跨 CoachKit/Networking)。**不动 spec 002 时代的 `CoreModels/Entities/BindRequest.swift`** — 它与 backend 005 wire 已漂移(`inviteCodeID` non-optional / 缺 `coach_display_name`),对齐归 031(学员侧消费方),教练队列走独立 DTO 零冲突。`BindRequestDecision` = accept/reject 响应里的 bind_request 轻量型(id + status + skip_evaluation + skip_reason),不复用旧 entity。

**Networking**:

| 文件 | 内容 |
|---|---|
| `APIClient+BindRequests.swift`(新) | `coachBindRequests()` / `acceptBindRequest(id:body:)` / `rejectBindRequest(id:)`(空对象 body) |
| `APIClient+Evaluations.swift`(新) | 评估期 3 端点 + 总结 2 端点 + `studentOnboarding(id:)` |
| `DTO/EvaluationDTOs.swift` 等(新) | 对应 request/response DTO,经 `MeetPRCodec` snake_case |
| Backend repository 实装(修订:**进各 Kit,不进 Networking**) | protocol 实装;404 机器码(`EVALUATION_NOT_FOUND` / `EVALUATION_SUMMARY_NOT_FOUND` / `ONBOARDING_NOT_FOUND`)→ 返 nil,其余 throw。031 已定 Networking library 不依赖 RepositoryContracts("contracts-free",见 Networking/Package.swift)→ 教练侧 `Backend*` 实装进 CoachKit、学员侧进 StudentKit(`BackendInviteCodeRepository` / `BackendBindRepository` 先例) |
| `BackendErrorEnvelope`(已存在,031 建) | 把 `APIError.httpStatus(code, data)` 的 data 解 `{"error": "<MACHINE_CODE>"}` 暴露给上层 — publish 错误映射(§10)和 accept 409 分支都靠它,直接复用 |

In-memory/preview 实装各 Kit 自带(沿用 029 模式)。

#### 2. StudentRoster"新学员请求"区块(教练 Tab 2)

`StudentRosterView` `List` 顶部加 Section(在学员行之前):

```
┌ 新学员请求 (2) ──────────────────┐
│ [BindRequestCard 张三]            │
│ [BindRequestCard 李四]            │
└──────────────────────────────────┘
── 学员 ──
[StudentRosterRow xty] …
```

- 数据:`CoachBindQueueRepository.fetchQueue()`,与 roster 同一 `task` 并行拉;pull-to-refresh 一起刷
- 队列空 → 区块整体隐藏(V0.1b 常态)
- **Tab 角标**:`CoachRootView` 学员 tab `.badge` 从 `pendingAttentionCount` 改为 `pendingAttentionCount + bindQueueCount`(裁量 D1)
- 空学员 + 有请求时,`ContentUnavailableView("暂无学员")` 不再整屏占据 — 改为请求区块 + 下方空态行;`暂无学员` 副文案从"等邀请码 V0.1.x"改"接收新学员请求后会出现在这里"

#### 3. `BindRequestCard` — 9 项摘要卡

wire → 展示映射(per wiki §3.2 + backend D13):

| # | 摘要项 | wire 来源 | 展示 |
|---|---|---|---|
| 1 | 姓名/性别/年龄/体重 | `display_name` `gender` `birth_date` `weight_kg` | "张三 · 男 · 25 岁 · 83 kg";年龄 = 当前日历年减 birth_date(客户端算,Calendar.current) |
| 2 | 训练年限 | `training_years` | 0 → "训练 <1 年";10 → "训练 10+ 年";其余 "训练 N 年" |
| 3 | 三大项 1RM | `squat/bench/deadlift_1rm_kg` | "S:180 B:120 D:220 (kg)";`"180.00"` → 去尾零展示 |
| 4 | 想增强肌群 | `muscle_groups_to_strengthen` | token → 中文名走既有 `MuscleGroup` + PlanningDisplay 映射(spec 022) |
| 5 | 训练环境 | `gym_tier` | `home_with_rack` 家庭深蹲架 / `commercial` 商业健身房 / `professional` 专业力量房 |
| 6 | 备赛日期 | `is_competing` + `competition_date` | true → "备赛: 2026-07-25";false/null → 行隐藏 |
| 7 | 备注 | `note_to_coach` | "备注: …"(2 行截断);null → 行隐藏 |
| 8 | 资料计数 | `upload_count` | "资料 4 份"(V0.1b 不细分视频/计划,per backend D13);0 → "无上传资料" |
| 9 | 已等待时长 | `submitted_at`(客户端算) | "已等待 2 小时 14 分" / "已等待 3 天";`expired_at` 临近(<24h)加 amber "即将过期" |

`onboarding.completed == false` → **降级卡**:姓名 + "资料未填写完成" + 等待时长 + 三按钮照常(完整资料页对 404 显示空态)。

卡底三按钮:`[查看完整资料]`(push §4)`[接收 ▼]`(弹 §5 模态)`[拒绝]`(确认 §5)。

#### 4. `StudentOnboardingProfileView` — 完整资料页(只读)

push 进入,`GET /students/:id/onboarding`(live-pending 授权由 backend D16 放行)。29 字段按 onboarding 7 步分组展示,每组一张卡:

1. **基础信息**:单位偏好 / 性别 / 生日(+ 算出年龄)/ 身高 / 体重
2. **训练背景**:训练年限 / 深蹲站位(high_bar 高杠·low_bar 低杠)/ 硬拉风格(conventional 传统·sumo 相扑)/ 卧推握距(narrow/standard/wide,选填)
3. **三大项 1RM**:S / B / D
4. **训练环境**:训练日(mon…sun → 周一…周日 chips)/ gym_tier / 器械备注(`equipment_overrides` 原样 token 列出,词表归 031)
5. **恢复能力**:日常强度 / 生活压力 / 恢复速度 / 睡眠 — 4 个 1-5 档位横条(`●●●○○`);睡眠档位文案 1=≤5h, 2=6h, 3=7h, 4=8h, 5=9h+
6. **训练资料**:想增强肌群 chips + "已上传 N 份"(V0.1b 只显示计数,文件预览等 attachments 集成 spec)
7. **补充信息**:伤病史(`injury_areas` token → 中文:肩/肘/腕/下背/髋/膝/踝/其他 + `injury_notes` 全文)/ 是否备赛 + 比赛日期 + 目标体重级 / 想对教练说

null 字段显示 "—";`404 ONBOARDING_NOT_FOUND` → `ContentUnavailableView("学员尚未填写资料")`。pending 过期后再进(403)→ 空态 + 返回时刷新队列。

页底也放 `[接收 ▼] [拒绝]`(教练看完资料就地决策,不用退回队列)。

#### 5. 接收模态 + 拒绝确认

**接收模态**(sheet,per wiki §3.3):

```
接收 张三 进入:
 ● 进入 7 天评估期         ← 默认选中
   推荐:陌生 / 不熟悉的学员
 ○ 跳过评估期(熟人)
   适合:已带过的 / 朋友介绍
   [原因(选填)__________]   ← 仅选中"跳过"时显示,≤500 字
[取消]              [确认接收]
```

- 确认 → `accept(requestID:, skipEvaluation:, skipReason:)`;skipReason 仅在跳过分支传值(否则 nil — zod superRefine 真 gate 兜底)
- 成功(进评估期)→ toast "已接收,评估期 7 天开始" + 队列移除该卡 + roster 刷新(新学员出现,状态 = 评估期)
- 成功(跳过)→ toast "已接收" + 同上(状态 = 活跃)
- 409/404 → banner(文案按机器码:已过期 "该请求已过期" / 已被处理 "该请求已被处理" / 已绑定 "你们已是绑定关系")+ 强制刷新队列

**拒绝**:confirmationDialog "拒绝后学员会看到中性提示(不会显示拒绝原因),确定拒绝?" → `reject(requestID:)` → 队列移除。无原因输入(wiki §3.4 silent,backend D18 无 reason 字段)。

#### 6. StudentDetail 评估期条(`EvaluationStatusBanner`)

`StudentDetailView` 在 segmented Picker **上方**插入条状卡(只在该学员有 in_progress 评估期时显示):

```
┌ 评估期 · 还剩 4 天 13 小时 ────────────────┐
│ ████████░░░░░░░░ 55%                        │
│ [发适应周]   [评估总结]   [完成评估]         │
└─────────────────────────────────────────────┘
```

- 数据:`EvaluationRepository.fetchEvaluation(studentID:)`,挂 `StudentDetailViewModel.loadIfNeeded()` 并行;nil(无记录)或 `completed_at != nil` → 条隐藏
- `overdue == true` → 红色态:"已超期 2 天,请尽快交付总结"(剩余/超期都用 `expected_end_at` 与本地 now 算,显示"X 天 Y 小时")
- **[发适应周]** → 进 planning,`intent = .adaptationWeek(student)`(§7);该学员已有 published adaptation plan 时按钮变 "查看适应周"(跳 Execution 段)— 判定用 StudentDetail 已拉的 plan 数据,不另起请求
- **[评估总结]** → push §8 编辑器
- **[完成评估]** → confirmationDialog "完成后即可发布正式 4 周计划。还没写评估总结的话,建议先写总结再完成。[仍然完成] [先写总结] [取消]" → `completeEvaluation(id:)`;409 `EVALUATION_ALREADY_COMPLETED` → 静默刷新(并发场景);成功 → 条消失 + roster 状态翻活跃
- **留言**:不加新按钮 — 评估期内留言 = 既有"反馈"段 `FeedbackComposerView` 原样复用(wiki §4.2 的"一次性反馈"与 029 的反馈是同一物,零新代码)

**roster/Step 0 的评估期状态来源(裁量 D2,2026-06-11 修订)**:backend fix #20(`4d08269`,已合 staging)后 `GET /coach/students` 直接返回 `status: 'active' | 'in_evaluation'` + `evaluation: {id, expected_end_at, overdue} | null`(active 评估期 left join,读时算 overdue)。iOS 实装:`CoachStudentSummaryDTO` 加 `evaluation` 子对象,`BackendPlanRepository.fetchStudents()` 用 `expected_end_at` 与本地 now 现算 `.inEvaluation(remainingDays:remainingHours:)`,**不做 per-student fan-out**(草稿 0.1 的 N+1 方案作废,对应 FOLLOWUPS 触发条件不再需要)。

#### 7. 适应周 planning 锁(UI 锁 + backend 真 gate 兜底)

**入口改造**:`PlanningCoordinatorView.init` 加 intent:

```swift
public enum PlanningIntent: Sendable {
  case blank                                                  // 现状:Tab1 排新计划,Step 0 选学员
  case adaptationWeek(CoachStudentSummary)                    // 评估期条入口
  case firstRegularPlan(CoachStudentSummary, OnboardingProfile?)  // 软推荐"立即排"入口(§9)
}
```

- `.adaptationWeek` / `.firstRegularPlan` → `PlanningViewModel` 预设 `selectedStudent` + 初始 `path = [.selectDuration]`(跳过 Step 0,导航栏仍可返回改人 — 返回即退化为 blank 流程)
- `PlanningViewModel` 加 `planKind: PlanKind`(blank/firstRegular → `.regular`;adaptationWeek → `.adaptation`)
- **Step 1 锁定**:`planKind == .adaptation` → 仅"1 周"可选,"4 周"disabled + 已有 `StatusBadge("评估期内仅 1 周")` 复用;`selectDuration` / `validateStep(.selectDuration)` 的既有 `isEvaluationStudent ⇒ planWeeks==1` 校验保留(双保险:状态驱动 + intent 驱动)
- 计划名默认 "\(displayName) 适应周"(现 "\(displayName) 1 周计划" 模板分支)
- **wire**:`CreatePlanRequestDTO` 加 `kind: String`(**显式发送** `"regular"` / `"adaptation"`,不靠缺省 — 裁量 D9);`BackendPlanRepository.publishPlan` 从 `TrainingPlan.kind` 透传;`PlanDTO` 解析响应 `kind`
- **UI 锁不是 gate**:publish 时 backend 真 gate(`403 EVALUATION_IN_PROGRESS` / `422 PLAN_DAYS_EXCEED_WEEKS`)是唯一权威,错误映射见 §10

#### 8. 评估总结编辑器(`EvaluationSummaryEditorView`,coach)

push 进入(评估期条 / 概览段总结卡两处入口):

```
评估总结 · 张三
┌ 整体评估(必填)──────────────┐  TextEditor,≤10000
┌ 训练规划(必填)──────────────┐  TextEditor,≤10000
┌ 给学员的话(选填)────────────┐  TextEditor,≤10000
首存:    [保存草稿]          [完成并通知学员]
已有总结: [保存]  ☐ 同时通知学员(默认不勾)
```

- 进入先 `fetchSummary(studentID:)`:nil → 空表单(首存模式);有 → 预填(编辑模式)
- 校验:两个必填字段 trim 后非空才可保存(zod min(1) 对齐);超长在 UI 截到 10000
- **首存模式**:
  - [保存草稿] → `putSummary(notify: false)`(backend 仍记 version 快照;学员侧不亮红点 — D7)
  - [完成并通知学员] → 链式(裁量 D3):① `putSummary(notify: true)` → ② 若该学员有 in_progress 评估期 → `completeEvaluation(id:)`(409 已完成 → 忽略)→ ③ 弹软推荐(§9)。② 失败(非 409)→ banner "总结已保存,但完成评估失败,请在学员详情页重试" — 总结不丢,评估期条还在
- **编辑模式**(per wiki §5.4):[保存] + 勾选框(默认不勾);勾选 → `notify: true`。编辑模式不触发软推荐、不碰评估期
- 跳过评估期的学员(无评估期)同样可写总结(backend `evaluation_period_id` 自动 NULL,D10);此时"完成并通知"仅 ① + ③
- **概览段总结卡**(裁量 D5):`StudentOverviewSection` 加第 4 张卡"评估总结" — 有总结 → 训练规划摘要 2 行 + "更新于 MM-dd",tap → 编辑器;无总结且(曾有评估期或已绑)→ "未填写,去写一份",tap → 编辑器。评估期完成后条消失,这张卡是总结的永久入口(wiki §5.5)

#### 9. 软推荐 + planning 预填

完成链 ③ 弹 alert(per wiki §6.1):

```
✓ 评估完成,张三已收到通知。
要不要立即为他排第一份正式计划?
[稍后]            [立即排]
```

- [稍后] → dismiss,留在编辑器(显示已保存态)
- [立即排] → 先 `fetchProfile(studentID:)`(失败/404 → profile 传 nil,照样进 planning 不预填,toast "学员资料未读到,手动填写")→ fullScreenCover `PlanningCoordinatorView(intent: .firstRegularPlan(student, profile))`

**预填字段映射**(对照 `PlanningViewModel` 现有可预填面,逐项):

| onboarding wire 字段 | PlanningViewModel 落点 | 映射规则 |
|---|---|---|
| (学员本身) | `selectedStudent: CoachStudentSummary?` | intent 直接预设;初始 path 跳到 Step 1 |
| `squat_1rm_kg` / `bench_1rm_kg` / `deadlift_1rm_kg`(string) | **新增** `prefilledOneRMs: [LiftFamily: Decimal]` | `Decimal(string:)` 解析;`oneRM(for:)` 现为 stub(恒 nil,`PlanningViewModel.swift:364`)→ 改为查 `prefilledOneRMs[family]`。消费点:Step 4 组数编辑卡 %1RM 模式换算基数 + 主项卡顶部 "1RM 180kg" 角标。无预填(blank 流程)→ 维持 nil,现 UI 已兼容 |
| `training_days`(`["mon"…"sun"]`) | Step 2 `dayAssignments: [Int: Set<LiftFamily>]` 的 day 键域 | token → Int:mon=1 … sun=7(对齐 `PlanningDisplay.weekdayName`)。**只标不填**:学员可练日的 `AssignmentDayCard` 加 "学员可练" badge 并排序置顶;**不**自动 assign lift(`validateAssignments` 与教练编排权不变,裁量 D8) |
| `gym_tier` + `equipment_overrides` | Step 4 `accessoryFiltersByDay` 的 `AccessoryFilters.equipment` 初始值 | `professional` / `commercial` → 不预设(空 filter = 全器械);`home_with_rack` → 预设 `{barbell, dumbbell, bodyweight, band}`(教练可改/清空);`equipment_overrides` token 命中 `Equipment` rawValue → 并入预设,未命中忽略(词表归 031,见 §接口契约) |
| `kind` | `planKind = .regular` | 首份正式计划;Step 1 1 周/4 周都可选(评估期已完成,`isEvaluationStudent` 应已翻 false — roster 刷新保证) |

不预填的字段(明确不做,防 implementer 过度发挥):恢复能力 4 档位、伤病、备赛日期 → 教练在完整资料页自行查看,不进 planning 状态。

#### 10. publish 错误映射

**实装注**:当前 codebase 的 planning UI 止于 Step 7(Step 8 发布 = spec 008 TODO,`Step7WeekCardSwipeView` 按钮即占位)— PlanningViewModel 里没有 publish 调用点。本 spec 把映射落成 CoachKit 内独立 `PlanPublishErrorMapping`(机器码 → banner 文案,带测试),spec 008 发布流接入时直接消费。

publish 失败 catch `APIError.httpStatus` → `BackendErrorEnvelope` 解机器码:

| 机器码 | UI 文案(banner) |
|---|---|
| `EVALUATION_IN_PROGRESS`(403) | "评估期内只能发布 1 周适应周计划。先完成评估,或改发适应周。" |
| `PLAN_DAYS_EXCEED_WEEKS`(422) | "计划里有超出周数范围的训练日,请检查后重试。"(理论不可达 — 编排器天数恒在 planWeeks 内,backend 兜底防 UI bug) |
| 其余 | 沿用现有通用失败文案 |

发布失败**不**清草稿(DraftStore 现行为保持),教练修正后可重发。

#### 11. 学员端:评估期状态页(`EvaluationPeriodView`,StudentKit)

**挂载点**:**BindGate 评估期分支**(BindGate 路由器归并行 spec 031/032:登录后按 bind/evaluation 状态分发 等待接收页 / 评估期页 / 正常 5 tab;本 spec 只提供该分支的页面与判定数据源 `EvaluationRepository.fetchMyEvaluation()` — nil 或 `in_progress == false` 即不在本分支)。

单页(非 5 tab,裁量 D6),per wiki §4.3 裁剪:

```
评估进行中
教练正在评估你
评估期还剩: 4 天 13 小时
████████░░░░░░░░ (55%)
┌ 教练留言 ───────────────────┐   ← 复用 FeedbackInboxViewModel,最近 3 条
│ "触底节奏太快,总结里详谈"     │      tap → push FeedbackInboxView 全列表
└─────────────────────────────┘
┌ 适应周训练(本周)────────────┐   ← 有 published adaptation plan 时显示
│ 周一: 深蹲 …                  │      [开始训练] → push TodayWorkoutView(复用)
└─────────────────────────────┘      无 → "教练正在为你准备适应周训练"
```

- **超期**:`overdue == true` → 学员侧**仍显示"评估进行中"**,倒计时换成 "评估即将完成",无负面提示、无换教练按钮(wiki §4.4 决议 1.5)
- **不做** "教练已查看资料 x/y"(backend 无 view tracking,spec 005 防漂移清单)
- 适应周训练入口数据:`StudentPlanRepository` 既有 published plan fetch — adaptation plan 就是一份普通 published 1 周计划,`TodayWorkoutView` / 训练记录 / e1RM 全链路零改动
- 评估完成(轮询/前台刷新发现 `in_progress == false`)→ 回调 BindGate 切正常 5 tab

#### 12. 学员端:评估总结呈现 + "我的资料"入口

- **`EvaluationSummaryView`(只读全文)**:三段卡(整体评估 / 训练规划 / 给学员的话),教练名 + `last_updated_at` 日期头;数据 `fetchSummary(studentID: self)`
- **仪表盘摘要卡**:`DashboardView` 顶部,当存在总结且**未读**时显示 "评估完成 ✓" 卡 — 训练规划摘要 + 给学员的话摘要(各前 2 行)+ [展开看完整] → push 全文;底部状态行:无 published regular plan → "教练正在为你排第一份正式计划"(wiki §6.2);已有 → 行隐藏
- **未读判定(裁量 D7)**:V0.1b 无 APNs,`notify_student` 仅落 backend version 行 → 学员侧用本地 `UserDefaults` 存"已读时间戳",`last_updated_at > 已读时间戳` → 仪表盘卡显示 + "我的" tab 红点 1;打开全文即写时间戳。换设备丢已读态可接受(只多看一次卡)
- **"我的"入口**:`MyProfileView` 加 row "评估总结"(有总结才显示)→ push `EvaluationSummaryView`,永久可回看(wiki §5.5)

#### 13. 测试

| 文件 | 覆盖 |
|---|---|
| `CoachKitTests/Features/BindQueue/BindRequestQueueViewModelTests`(新) | 队列加载 / 9 项映射(含年龄计算 / 去尾零 / completed=false 降级)/ accept 双分支 / skipReason 只在跳过分支携带 / 409 各机器码 → 刷新 / reject |
| `CoachKitTests/Features/StudentDetail/EvaluationBannerViewModelTests`(新) | 剩余时间计算 / overdue 文案 / complete 成功+409 / 条隐藏条件(nil / completed) |
| `CoachKitTests/Features/StudentDetail/EvaluationSummaryEditorViewModelTests`(新) | 首存/编辑模式切换 / 必填校验 / notify 默认值 / 完成链 ①②③ 顺序与 ② 失败降级 / 跳过评估期学员链路 |
| `CoachKitTests/Planning/PlanningViewModelPrefillTests`(新) | intent 预设 student+path / adaptation 锁 1 周 / prefilledOneRMs 接入 oneRM(for:) / training_days token→Int / equipment 预设表 / kind 透传 |
| `StudentKitTests/Features/Evaluation/EvaluationPeriodViewModelTests`(新) | 倒计时/进度 / overdue 学员侧无负面文案 / 留言+适应周入口数据装配 |
| `StudentKitTests/Features/Evaluation/EvaluationSummaryPresentationTests`(新) | 摘要截取 / 未读时间戳判定 / "等待首份计划"行显隐 |
| `NetworkingTests/Repositories/Backend*RepositoryTests`(新 ×4) | wire 编解码往返(snake_case / decimal string / DATE string)/ 404→nil / reject 空 body / accept 响应含 evaluation_period |
| `CoreModelsTests/EvaluationEntitiesCodecTests`(新) | EvaluationPeriod/Summary/OnboardingProfile decode fixture(从 backend 测试响应抄真 JSON)+ TrainingPlan.kind 缺省 regular 兼容 |

#### 14. CHECKLIST.md(双机联调,David=coach + xty=student staging 账号)

```
[ ] 学员(031 流程)发绑定请求后,教练 Tab2 顶部出现请求卡,tab 角标 +1
[ ] 卡片 9 项齐全;学员未完成 onboarding 时降级卡
[ ] 查看完整资料页 29 字段分 7 组;未填字段显示 —
[ ] 接收→进评估期:roster 出现该学员(评估期状态),StudentDetail 顶部评估期条倒计时
[ ] 接收→跳过(填原因):无评估期条,直接活跃
[ ] 拒绝:队列移除;学员侧(031)中性提示
[ ] 评估期内发 4 周 regular:Step1 4 周禁用;绕过 UI 直接 publish(curl)→ 403 EVALUATION_IN_PROGRESS
[ ] 发适应周:Step1 锁 1 周,publish 成功,学员评估期页出现适应周入口并可进今日训练
[ ] 评估期条 [完成评估] → 条消失,4 周 regular 可发
[ ] 评估总结:保存草稿→学员无感知;完成并通知→学员仪表盘摘要卡 + 我的红点;展开看全文
[ ] 软推荐 [立即排] → planning 跳过 Step0,1RM/训练日标记/器械预设就位
[ ] 学员评估期页:倒计时/留言/适应周;教练完成评估后刷新转 5 tab
[ ] CI 全过(CoachKit ⊥ StudentKit 两层自检含新文件)
```

### 不做什么

**本 spec 明确不做**(spec 005 防漂移清单 + office hours 决议对齐):
- ❌ 批量接收(V1 每教练每周 1-3 个新学员)
- ❌ 视频 timestamp 评论 / 画线标注(V1.5 / V2)
- ❌ 换教练按钮(marketplace 前不存在,wiki §4.4)
- ❌ 评估总结 markdown(纯文本)
- ❌ APNs / 推送(48h 再推、超期催办、"教练完成评估"推送全是推送概念 — V0.1b 用 in-app 红点/卡片近似)
- ❌ "教练已查看 x/y" view tracking(backend 无此数据)
- ❌ 解除绑定 / 评估期内"决定不带"(wiki §4.2 跳过-事后行,独立 spec)
- ❌ 邀请码生成/管理 UI(教练侧"我的邀请码"页归 031 配套或独立小 spec — 本 spec 队列假设请求已存在)
- ❌ 学员发起绑定 / 等待接收页 / onboarding 7 步表单(031/032 范围)
- ❌ onboarding 上传资料的文件级预览(attachments 集成 spec;本 spec 只显示计数)
- ❌ 教练改学员 1RM(`PUT /coach/students/:id/one-rm`)的 UI(cascade 模态是独立产品流,V0.1.x)

## 技术要求

- **模块边界**:新 protocol 全进 `RepositoryContracts`(029 D3 先例);`EvaluationPeriod` / `EvaluationSummary` / `OnboardingProfile` 进 CoreModels(双 Kit 消费);教练专用 view/VM 进 `CoachKit/Features/BindQueue/` + `Features/StudentDetail/Evaluation/`;学员专用进 `StudentKit/Features/Evaluation/`。CoachKit ⊥ StudentKit 两层 CI 自检照旧
- **时间计算统一**:剩余/超期/等待时长全部"wire 时间戳 + 本地 now"现算,不缓存派生值;跨午夜刷新用 `TimelineView(.everyMinute)` 或 onAppear 重算,不开 Timer 常驻
- **错误信封**:`BackendErrorEnvelope` 是本 spec 多处依赖(accept 409 分支 / publish 真 gate 映射 / 404→nil),实装放 Networking 一处,禁止各 repo 自己 ad-hoc 解 JSON
- **iOS 17.0+**;无新系统框架依赖

## 与 031/032 的接口契约(并行起草,先合者建后合者依)

| 接口物 | 归属 | 033 的依赖方式 |
|---|---|---|
| BindGate 路由器(登录后 pending/评估期/正常分发) | 031/032 | 033 只交付 `.evaluationActive` 分支视图 `EvaluationPeriodView` + 判定数据源 `fetchMyEvaluation()`;分支 enum 命名以先合方为准 |
| `OnboardingProfile` entity + `OnboardingProfileReading` protocol + Backend 实装 | **共用**(031 写侧 PUT/complete,033 读侧 GET) | 谁的 impl PR 先合谁建;protocol 拆 `Reading`(033 用)与写侧扩展(031 用),避免互相 block |
| `equipment_overrides` 词表(iOS owned,backend 自由 token) | 031 定义 | 033 预填仅消费"命中 `Equipment` rawValue 取交集"规则;031 若定独立词表,033 的映射表同 PR 跟进 |
| `CoreModels/Entities/BindRequest.swift`(spec 002 旧)对齐 backend 005 wire | 031(学员侧消费方) | 033 **不碰**:教练队列走独立 `CoachBindRequestItem`,accept/reject 响应走 `BindRequestDecision` 轻量型 |
| 学员"被拒/过期"中性提示页 | 031 | 033 reject 仅打点 backend,学员侧呈现归 031 |
| MeetPR-Demo build 的 in-memory seed(演示队列/评估期) | 033 自带 | InMemory 实装含 1 条 pending 请求 + 1 个评估期学员 fixture(Demo 配置 gotcha:跑 Demo 必须显式 `configuration=Demo`) |

## 裁量决策清单(已拍板进本 spec,review 时可挑战)

| # | 决策 | 理由 |
|---|---|---|
| D1 | 学员 tab 角标 = 待关注数 + pending 请求数合并 | V0.1b 不加第 4 个 tab;请求和学员同住 Tab2,角标同源 |
| D2(已修订) | roster 评估期状态直接消费 `GET /coach/students` 的 `status` + `evaluation {id, expected_end_at, overdue}` 字段,不做 fan-out | 草稿 0.1 拍板时 backend 硬编码 `'active'`,fan-out 是临时桥;backend fix #20 已合 staging 回真数据 → 直接消费,N+1 方案作废 |
| D3 | "完成并通知学员" = PUT summary(notify=true) → complete evaluation(若 active,409 忽略) → 软推荐 | wire 上是两个端点,产品上是一个动作;顺序先 PUT 保总结不丢;② 失败降级 banner,评估期条仍在可重试 |
| D4 | notify 默认:首存的"完成"按钮恒 true;编辑模式勾选框默认 false | wiki §5.4 决议 1.8 照抄 |
| D5 | 评估期完成后 banner 收起,总结永久入口 = 概览段第 4 张卡 | wiki §5.5"学员详情页有评估总结入口";不为总结加第 6 个 segment |
| D6 | 学员评估期 = 单页替代 5 tab(留言/训练以 push 复用) | 评估期是中间态,5 tab 大半空态(历史/仪表盘无正式计划数据);单页把"等待感"做成产品(wiki §4.3 原型即单页) |
| D7 | 学员"未读总结"= 本地 UserDefaults 已读时间戳 vs `last_updated_at` | V0.1b 无 APNs,backend `notified_student` 只记账;换设备丢已读态可接受 |
| D8 | 预填"只标不填":训练日只置顶+badge 不自动 assign;1RM 只作换算基数;恢复/伤病不进 planning | 教练是计划 owner(设计哲学§0),预填是省键击不是代编排 |
| D9 | `kind` 显式发送("regular"/"adaptation"),不靠 backend 缺省 | 质量>工程量:wire 显式优于隐式,日志/排查一眼可辨 |
| D10 | 拒绝加 confirmationDialog 但无原因输入 | silent 是产品决议(wiki 3.3);确认层防误触,不开口子 |
| D11 | 完整资料页脚重复 [接收][拒绝] | 教练动线"看完资料才决策"是主路径,不让他退回队列再点 |
| D12 | accept/reject 一切 4xx → 刷新队列 + banner,不做就地重试 | 惰性过期意味着队列随时陈旧,刷新是唯一正确恢复 |

## 估时(给 implementer 参考)

| 块 | 估时 |
|---|---|
| 1. CoreModels entities + RepositoryContracts protocols + Networking(DTO/APIClient/4 repo/错误信封) | 1.2d |
| 2. 队列区块 + 9 项卡 + 降级卡 + 角标 | 0.8d |
| 3. 完整资料页(7 组 29 字段) | 0.8d |
| 4. 接收模态 + 拒绝 + 错误分支 | 0.6d |
| 5. 评估期条 + 完成评估 + roster 状态 fan-out | 0.8d |
| 6. planning intent + adaptation 锁 + kind wire + publish 错误映射 | 1d |
| 7. 评估总结编辑器 + 完成链 + 概览卡 | 1d |
| 8. 软推荐 + 预填(1RM/训练日/器械) | 0.8d |
| 9. 学员评估期页 + 总结呈现 + 我的入口 + 未读 | 1.2d |
| 10. 测试 + fixture + CHECKLIST 双机联调 | 1.3d |
| **合计** | **≈ 9.5d**(可拆 3 个 PR:教练队列+资料页 / 评估期+planning / 总结+学员端) |

## 风险 / 待 implementer 关注

1. **031/032 时序耦合**:学员端无 031 的绑定发起流程,033 的学员侧分支在真机上无法端到端验收(只能 staging 直插 bind_request 行 / curl 模拟)。建议 033 教练侧 2 个 PR 先行,学员侧 PR 排在 031 主流程可跑之后
2. **队列陈旧性**:7 天惰性过期意味着卡片可能已 expired 而 UI 还显示 — accept 的 409 EXPIRED 分支必须真实现+真测试,不是防御性装饰
3. **完成链部分失败**(D3 ②):总结已存但评估期未完成时,教练侧状态 = 总结卡有内容 + 评估期条仍在 — 两处入口都可恢复,不要做成死局
4. **PlanningViewModel 改动面**:intent/prefill 触碰 bootstrap/draft 恢复路径(SwiftData DraftStore);带 intent 进入时若该学员已有未完成草稿,弹既有"继续草稿/重新开始"对话,**不**静默覆盖
5. **oneRM(for:) 是 stub**:现实装恒 nil(`PlanningViewModel.swift:364`),%1RM 相关 UI 一直按"无 1RM"渲染;接入 prefill 后首次有真值,Step 4 换算 UI 需要回归一遍
6. **decimal/日期格式化**:wire `"180.00"` / `"2026-07-25"` — 展示去尾零、年龄/等待时长本地算,集中放 formatting helper,禁止 view 里散落 `Double(...)` 转换
7. **学员评估期页轮询**:V0.1b 无推送,"教练完成评估"靠前台 onAppear/手动刷新发现;不做后台轮询(电量/复杂度),BindGate 切换以前台刷新为准

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-11 | 0.1 | 起草(对照 backend 005 实装 wire + evaluation-workflow v1.1 + CoachKit/StudentKit 现状) | Claude |
| 2026-06-11 | 0.2 | 实装期修订:① **D2 作废 fan-out** — backend fix #20 已合 staging,`GET /coach/students` 直接回 `status` + `evaluation` 对象,roster 零额外请求;② Backend repository 实装位置从 Networking 改进各 Kit(031 已定 Networking contracts-free);③ `OnboardingProfile` 实体 031/032 已建,033 复用 + 拆 `OnboardingProfileReading` 读侧 protocol;④ §10 publish 调用点尚不存在(spec 008 TODO),映射落成 `PlanPublishErrorMapping` 待接入;⑤ 加 `StudentPlanView.planKind`(学员端"等待首份正式计划"行判定);⑥ accept/reject 4xx 用独立 `CoachBindQueueError` | Claude |
