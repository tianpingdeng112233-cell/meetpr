---
tags: [meetpr, data-model, domain-layer]
created: 2026-04-24
updated: 2026-04-27
status: draft
verification_status: framework
---

# MeetPR — 数据模型 v1.1（领域层）

> **Status**: Draft v1.1 · **Date**: 2026-04-27 · v1.1 = v1 + **2026-04-27 反转 v3 议题 4 多角色单用户**（V1 改回单角色 `user.role: enum`，多角色推迟到 V1.5+）
> 关联：[[prd|PRD v0.7]] §5 P0 + §11.2（V2/V3 数据模型预埋）+ [[evaluation-workflow]] + [[student-onboarding]] + [[coach-planning]]
>
> 本文档是**领域层**——画核心实体 + 关系 + 关键约束。**不是 SQL DDL**——具体 schema 由后端 ADR 决定（[[prd|PRD]] §13.2 #4 后端选型 ADR）。

---

## 0. 设计原则

1. **单用户单角色 V1**（**v1.1 反转 v3 议题 4 决议**）：`user.role` 是单值 enum；同一用户只能有一个角色，注册后不可切换。多角色（`roles: enum[]`）推迟到 V1.5+ 触发条件后实施，详见 [[decisions/003-dual-end-native-architecture|ADR 003 v4]]
2. **三类身份 enum**：`coach` / `coached_student` / `self_train_student`
3. **1RM vs e1RM 分离**（议题 6 决议）：1RM 锁定字段（学员只读），e1RM 自动算字段（每次训练后 update）
4. **三标签并行筛选**（议题 2 决议）：动作库 facets 系统（肌群 + 器械 + 模式）
5. **V2/V3 接口预埋**：必须留 `plan.source` / `coach.public_profile_id` / `coach_review` 等接口

---

## 1. 核心实体

### 1.1 User（V1 单角色 — v1.1 反转）

```
User
├── id
├── phone (unique, indexed)
├── apple_user_id (nullable, Apple Sign-In)
├── name, avatar_url
├── gender (M/F)
├── birth_date
├── height_cm, weight_kg
├── unit_system: 'metric' | 'imperial'
├── role: enum  ← v1.1 单值（v1 是 roles: enum[] 多值）
│   - 'coach'
│   - 'coached_student'
│   - 'self_train_student'
└── created_at, updated_at
```

**约束**：
- `role` 必填且唯一
- **V1 注册后不可切换**（教练 ↔ 学员、有教练 ↔ 自己练 全部锁死）
- 想换角色只能注销重新注册（与 v0.5 立场一致）

> **V1.5+ 多角色 deferred**（v3 议题 4 决议反转，v1.1 推迟）：
> - 升级为 `roles: enum[]` + `primary_role: enum`，允许同一用户持多身份
> - 触发条件：B2B Stage 5-6 公测稳定后，实际用户反馈"教练自己也要训练"场景 ≥ 5 人
> - 详见 [[decisions/003-dual-end-native-architecture|ADR 003 v4]] §背景 v4 反转

### 1.2 CoachProfile（教练独有数据）

```
CoachProfile
├── id, user_id (FK, role='coach')
├── public_profile_id (V3 marketplace 预埋)
├── discoverable: bool (V3 marketplace 预埋, V1 default false)
├── tags: text[] (V3 预埋, 专长标签)
├── bio: text (V3 预埋)
├── case_videos: UUID[] (V3 预埋, 关联训练视频)
└── created_at
```

### 1.3 StudentProfile（学员独有数据，含 onboarding）

```
StudentProfile
├── id, user_id (FK, user.role IN ('coached_student','self_train_student'))
├── training_mode: 'coached' | 'self_train'   -- V1 注册时锁死，V1.5 启用单向 toggle（有教练→自己练）
│
├── -- onboarding 数据（详见 student-onboarding v2.3）--
├── training_years: int                     -- 训练年限
├── squat_stance: 'high_bar' | 'low_bar'
├── deadlift_stance: 'conventional' | 'sumo'
├── bench_grip: 'narrow' | 'standard' | 'wide' (nullable)
├── current_squat_1rm, bench_1rm, deadlift_1rm: decimal  -- Type A 锁定
├── training_days_of_week: int[] (1-7, 如 [1,3,5,6])    -- Type A 锁定
├── gym_tier: 'home_with_rack' | 'commercial' | 'professional'  -- Type A 锁定
├── equipment_overrides: text[]                          -- Type A 锁定
├── daily_intensity_level: int (1-5, U 型)               -- Type B 推送
├── life_stress_level: int (1-5)                         -- Type B 推送
├── recovery_speed: int (1-5)                            -- Type B 推送
├── sleep_hours: int (5-9)                               -- Type B 推送
├── injuries: text[] + body_part_tags                    -- Type B 推送
├── muscles_to_strengthen: text[] (max 3)                -- Type C silent
├── competition_targeting: bool                          -- Type C silent
├── competition_date: date (nullable)                    -- Type C silent
├── target_weight_class: text (free-form)                -- Type C silent
├── notes_to_coach: text                                 -- Type C silent
│
├── -- v0.6 上传资料 --
├── uploaded_past_plans: file[]                           -- 学员 onboarding 上传计划
├── uploaded_lift_videos: { squat: video[], bench: video[], deadlift: video[] }
└── created_at, updated_at
```

**Type A/B/C/D 字段权限分级**（议题 2.2 决议，详见 [[student-onboarding]] §D）：
- A 锁定（cycle 中只读，仅教练改）
- B 立即推送教练
- C silent 偏好
- D silent 基础（身高 / 体重 / 联系方式）

### 1.4 Exercise（动作库 + 三标签 facets）

```
Exercise
├── id
├── name (zh-CN, 如 "竞技深蹲" / "哈克深蹲")
├── exercise_type: 'main_lift' | 'main_lift_variation' | 'accessory'
├── main_lift_family: 'squat' | 'bench' | 'deadlift' | null  -- v0.5 议题 C
├── is_competition_lift: bool  -- 是否比赛版本
│
├── -- 议题 2 三标签 facets（v4.2）--
├── muscle_groups: enum[]    -- 9 个值多选
│   - 'chest', 'shoulder', 'back', 'biceps', 'triceps'
│   - 'core', 'quad', 'hamstring', 'glute'
├── equipment: enum[]         -- 4 类多选
│   - 'barbell', 'dumbbell', 'machine', 'bodyweight'
├── movement_pattern: enum[]  -- 推/拉
│   - 'push', 'pull'
│
├── created_by_coach_id: nullable (教练自定义动作场景)
└── created_at
```

**搜索/筛选**：教练编排时按任意 facet 组合 filter（详见 [[coach-planning]] Step 4）。

### 1.5 BindRequest（学员绑定教练请求队列）

```
BindRequest (议题 3 决议)
├── id
├── student_id, coach_id, invite_code_id (FK)
├── status: enum
│   - 'pending'    -- 学员发请求，等教练响应
│   - 'accepted'   -- 教练接受
│   - 'rejected'   -- 教练拒绝（中性 silent）
│   - 'expired'    -- 7 天教练未响应自动 expired
│   - 'cancelled'  -- 学员主动取消
├── submitted_at, responded_at, expired_at
├── skip_evaluation: bool (true = 教练接收时勾选"跳过评估期")
├── skip_reason: text (nullable)
└── rejection_silent: bool (true) -- v1 always silent
```

### 1.6 InviteCode（3 类 + 老教练推荐）

```
InviteCode (议题 3 决议)
├── id, coach_id
├── code: text (10-char alphanumeric, indexed unique)
├── type: enum
│   - 'personal_permanent'  -- 教练默认随身码
│   - 'single_use'          -- 用 1 次失效
│   - 'time_limited'        -- 设过期时间
│   - 'coach_referral'      -- V1.5 老教练推荐码
├── max_uses: int (NULL for personal/time_limited; 1 for single_use)
├── used_count: int
├── expires_at: timestamp (NULL for personal/single_use)
├── revoked_at: timestamp (nullable)
├── label: text (nullable, 教练自填如"给小明")
└── created_at
```

### 1.7 EvaluationPeriod + StudentEvaluation（评估期）

```
EvaluationPeriod (议题 5 决议)
├── id
├── student_id, coach_id, bind_request_id
├── started_at, expected_end_at (started + 7d)
├── completed_at: timestamp (nullable)
├── completion_type: enum
│   - 'coach_completed'  -- 教练填评估总结后点完成
│   - 'auto_completed'   -- 7 天到期自动
│   - 'overdue'          -- 教练超期未完成
├── overdue_first_push_at, overdue_second_push_at (nullable, +36h)
└── created_at

StudentEvaluation (3 字段评估总结，议题 1.3 决议)
├── id
├── student_id, coach_id, evaluation_period_id (nullable, 跳过评估期则为 NULL)
├── overall_assessment: text   -- 整体评估（必填，自由文本）
├── training_plan: text         -- 训练规划（必填，自由文本）
├── words_to_student: text      -- 给学员的话（选填，自由文本）
├── first_saved_at, last_updated_at
└── is_active: bool

StudentEvaluationVersion (版本历史)
├── id, evaluation_id (FK)
├── overall_assessment, training_plan, words_to_student: text (snapshot)
├── notified_student: bool (本次保存时是否推送学员)
└── saved_at
```

### 1.8 TrainingPlan + Day + Exercise + Set（训练计划层）

```
TrainingPlan
├── id, coach_id (nullable, 自己练时为 NULL), trainee_id
├── name, start_date, end_date
├── plan_weeks: int (1 or 4)
├── source: enum
│   - 'coach'      -- 教练手写（B2B 工作流）
│   - 'template'   -- 自己练学员选模板（B2C V1）
│   - 'algorithm'  -- 算法生成（V2 预埋）
├── source_template_id: FK → WeekTemplate (nullable)
├── status: 'draft' | 'published' | 'completed' | 'paused'
└── created_at, updated_at

PlanDay
├── id, plan_id, day_of_week, week_number, sort_order

PlanExercise
├── id, plan_day_id, exercise_id (FK)
├── is_main_lift: bool, sort_order, notes

PlanSet
├── id, plan_exercise_id, set_number
├── target_reps, target_reps_max (nullable, 范围)
├── intensity_mode: 'weight' | 'rpe'
├── target_value: decimal
├── set_type: 'warmup' | 'working' | 'failed' | 'amrap' | 'backoff'
└── created_at
```

### 1.9 ProgressionRule + ExerciseWeekOverride（递进规则 v4 + 周覆盖 v4）

```
ProgressionRuleGroup (递进/递减规则)
├── id, plan_id (or week_template_id 模板时)
├── rule_type: enum (9 类，含递增递减)
│   - 'weight_inc' | 'weight_dec'
│   - 'rpe_inc' | 'rpe_dec'
│   - 'sets_inc' | 'sets_dec'
│   - 'reps_inc' | 'reps_dec'
│   - 'custom'
├── increment_value: decimal (nullable, 仅非 custom)
├── custom_sequence: jsonb (nullable, 仅 custom)
├── applied_weeks: int[]   -- 规则应用到哪几周（如 [2,3]）
├── detected_pattern: text (nullable)
└── created_at

ProgressionRuleAssignment (规则-动作关联)
├── id, rule_group_id, plan_exercise_id

ExerciseWeekOverride (周手动覆盖 / W1 必填)
├── id, plan_exercise_id, week_number
├── target_sets, target_reps
├── intensity_mode, intensity_value
├── source: 'w1_baseline' | 'manual_override'
└── created_at
```

### 1.10 e1RMHistory（议题 6 PR 重塑 - 新增）

```
e1RMHistory (每个动作历史 e1RM 时间序列)
├── id
├── trainee_id, exercise_id (FK)
├── computed_at: timestamp        -- 哪次训练完后算的
├── source_set_id: FK → PlanSet   -- 基于哪一组算的
├── e1rm_value: decimal           -- 计算结果
├── computation_method: 'rpe_based' | 'epley_fallback'
├── is_pr: bool                   -- 当时是否是 PR（历史 query 时算便利）
└── created_at
```

**关键规则**：
- 每次 working set 完成后系统自动 compute（详见 [[coach-planning]] §α）
- e1RM 不替代 1RM 字段；`StudentProfile.current_squat_1rm` 仍是 onboarding/教练填的
- PR 检测 = 当前 computed e1RM > 该 trainee_id × exercise_id 历史最大 e1RM → 推送学员

### 1.11 WeekTemplate（教练模板系统）

```
WeekTemplate
├── id, coach_id
├── name, days_per_week (3/4/5)
├── plan_weeks: int (1 or 4)
└── created_at

TemplateDay → TemplateExercise → TemplateSet → ProgressionRuleGroup（同上结构）
```

### 1.12 VideoUpload（视频管线）

```
Video
├── id, trainee_id
├── source_set_id: FK → PlanSet (nullable, 训练日视频; or null = onboarding 三大项视频)
├── video_type: 'set_video' | 'onboarding_lift_video'
├── lift_type: 'squat' | 'bench' | 'deadlift' (only for onboarding)
├── duration_seconds: int (≤120, v4.2 议题 7)
├── url: text
├── thumbnail_url: text
├── uploaded_at, transcoded_at
├── upload_status: 'queued' | 'uploading' | 'transcoding' | 'completed' | 'failed'
└── visible_to: 'bound_coach_only' (V1 default)
```

### 1.13 CoachFeedback（议题 8 简化版）

```
CoachFeedback
├── id, coach_id, trainee_id
├── target_set_id: FK → PlanSet (per-set granularity)
├── feedback_type: 'thumbs_up' | 'text'
├── text_content: text (nullable, 仅 text 类)
├── created_at
└── read_by_student_at: timestamp (nullable)
```

### 1.14 CoachReferral（老教练推荐 - V1.5+）

```
CoachReferral (议题 4.2 GTM 决议)
├── id
├── referring_coach_id, referred_coach_id, referral_code (FK)
├── referred_at, first_plan_completed_at
├── bonus_months: int (default 3)
├── bonus_applied_at: timestamp (nullable)
└── status: 'pending' | 'qualified' | 'bonus_applied' | 'expired'
```

### 1.15 V2/V3 预埋字段（详见 PRD §11.2）

```
-- V2 预埋
TrainingMeet (V2 比赛追踪)
├── id, trainee_id, meet_date, federation, weight_class, status

-- V3 预埋
CoachReview (V3 marketplace)
├── id, coach_id, student_id, rating, text, created_at

CoachPublicProfile (V3 marketplace)
├── id, coach_id, profile_url_slug, ...
```

---

## 2. 关系图（核心 entity 主链路）

```
User (V1 单角色 role; V1.5+ deferred → roles[])
  ├─→ CoachProfile (role = 'coach')
  │     ├─→ InviteCode (1:N, 3 类)
  │     ├─→ BindRequest (接收队列, N)
  │     └─→ WeekTemplate (个人模板库, N)
  │
  └─→ StudentProfile (role IN ('coached_student','self_train_student'))
        ├─→ uploaded_past_plans, uploaded_lift_videos
        └─→ TrainingPlan (作为 trainee_id, N)
              ├─→ PlanDay → PlanExercise → PlanSet
              ├─→ ProgressionRuleGroup → applied_weeks
              ├─→ ExerciseWeekOverride
              └─→ Video (per set, optional)

Coach ←→ Student (1:N) via BindRequest 'accepted'
              ↓
EvaluationPeriod (1:1 per bind, 7 天)
              ↓
StudentEvaluation (3 字段) → StudentEvaluationVersion (历史)
              ↓ 软推荐
TrainingPlan (首份正式)

PlanSet (working) → e1RMHistory (每次训练后 compute)
              ↓ 突破历史最高
推送学员 (PR detection)
```

---

## 3. 关键约束

### 3.1 单用户单角色 V1（v1.1 反转 v3 议题 4）
- `user.role` 是单值 enum（V1）
- 一个 user 只有一个 role，注册后不可切换
- 想换角色只能注销重新注册
- **V1.5+ deferred**：升级为 `roles: enum[]` + 跨身份数据隔离 + base profile（手机号 / 头像 / 三大项 1RM）跨身份共享。触发条件见 [[decisions/003-dual-end-native-architecture|ADR 003 v4]]

### 3.2 1RM vs e1RM 分离（议题 6）
- `StudentProfile.current_*_1rm` 是锁定字段（仅 onboarding / 教练改 / V2 比赛触发）
- `e1RMHistory` 是自动算的时间序列
- PR 检测仅基于 e1RM 历史，**不修改** `StudentProfile.current_*_1rm`

### 3.3 评估期约束
- 一个 BindRequest accepted 后只能创建 1 个 EvaluationPeriod
- 期内 `TrainingPlan.plan_weeks` 不能为 4（仅 1 周适应周）
- skip_evaluation=true 时不创建 EvaluationPeriod

### 3.4 V1 不创建 V3 marketplace 实体
- CoachReview, CoachPublicProfile 表 V1 不创建（仅 schema 预埋字段）
- coach.discoverable 默认 false

### 3.5 学员字段权限（议题 2.2）
- Type A 字段（1RM / 训练日 / 训练环境）：cycle 中学员不能改 SQL UPDATE
- Type B 字段（伤病 / 恢复评估）：学员可改 + 自动 push 教练
- Type C/D 字段：学员可改 silent

---

## 4. 数据模型变化历史

| 日期 | 版本 | 改动 |
|---|---|---|
| 2026-04-26 | v1 | 首次实质性填充。集成所有 ADR 003 v3 + 6 个 PD + evaluation-workflow + onboarding v2.3 + planning v4.2 的数据约束 |
| 2026-04-27 | v1.1 | **反转 v3 议题 4 多角色单用户**：`user.roles: enum[]` → `user.role: enum`（单值），移除 `primary_role`；`StudentProfile.training_mode` 加 V1 锁死注释；§3.1 约束改为单角色 V1；§5 移除"跨身份 base profile 共享字段范围"待定项（V1 不需要）。详见 [[decisions/003-dual-end-native-architecture|ADR 003 v4]] |

---

## 5. 待解决（V1 落地实施时定）

- 后端选型 ADR（PRD §13.2 #4）—— 决定 ORM / 表设计 / migration 策略
- 视频存储 ACL 详细 schema（PRD §8.7 隐私）
- e1RM 计算 RPE table 入库（议题 1：嵌入 app 还是服务端配置？）
- ~~跨身份 base profile 共享的具体字段范围~~ **V1 不需要**（v1.1 反转后单角色，不存在跨身份场景）—— V1.5+ 触发后再讨论
- 历史 1RM 修改 audit log（教练改 1RM 后留 record 追踪）

---

## 6. 相关

- [[prd|PRD v0.7]] §5 P0（功能列表）+ §11.2（V2/V3 接口预埋）
- [[student-onboarding|学员端 v2.3]] §D 4 级字段权限
- [[coach-planning|教练端 v4.2]] §α e1RM 计算 + §β 视频/反馈 + Step 4 三标签筛选
- [[evaluation-workflow|评估期工作流 v1]] §3-§5 接收队列 / 评估期 / 评估总结
- [[decisions/003-dual-end-native-architecture|ADR 003 v4]] 双端业务 + 单 app 单用户单角色（V1 反转）
- [[product-decisions/005-evaluation-period|PD-005 评估期]]
