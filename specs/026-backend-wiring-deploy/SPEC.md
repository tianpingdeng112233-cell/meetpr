# 026 — Backend 真接入 + 阿里云部署 + 内测用户 seed

- **状态**: Draft
- **PR**: TBD(iOS 侧 1 PR;backend 侧 1-2 PR — seed migration + deploy docs;**跨 repo,2 PR/feature 约束按"iOS spec 2 PR + backend ≤2 PR" 拆**)
- **来源**:
  - [v0_1_pre_plan §候选 3](~/Brain/wiki/projects/MeetPR/v0_1_pre_plan.md) — F-025 RDS 重申 / SAE 部署 / `BackendPlanRepository` 真装 / JWT / offline cache
  - 上游 [backend spec 001-auth](~/Projects/apps/MeetPR-backend/specs/001-auth/SPEC.md) + [backend spec 002-coach-planning-crud](~/Projects/apps/MeetPR-backend/specs/002-coach-planning-crud/SPEC.md) — 全部 endpoint 已实装合 staging
  - [ADR-004 §1 后端选型 + §4 部署 + §6 上线前 blocker](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md) — 阿里云 SAE + RDS + OSS + RAM
  - [ADR-005 §3 Repository pattern + §4 横切关注点](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — Domain Model layer + stale-while-revalidate + 401 typed throw
  - 上游 [spec 025 real auth login + Keychain](../025-real-auth-login-keychain/SPEC.md) — access token 注入路径 ready,本 spec 复用
  - [FOLLOWUPS F-025](~/Projects/apps/MeetPR/FOLLOWUPS.md) — RDS 试用退订后重申要求

## 目标

把 V0 期挂的 backend 真接通起来:

1. **基础设施 ready** — F-025 RDS 单机版重申(阿里云 RDS PostgreSQL 17, 2c4G + 50GB ESSD PL1) + 阿里云 SAE 部署 backend staging build + `staging` 分支❄️解冻
2. **iOS Backend* repo 真装** — 替 V0 期 5 个 `BackendXxxRepository` 占位 `fatalError`(`BackendPlanRepository` / `BackendStudentPlanRepository` / `BackendStudentTrainingLogRepository` / `BackendStudentFeedbackRepository` / `BackendE1RMRepository`)
3. **offline cache** — stale-while-revalidate(per ADR-005 §4),Documents/ 下 JSON file 持久化 + 网络断开仍可读
4. **内测用户 seed** — backend 加 `0004-seed-internal-users.sql` migration,直接 insert 你 + xty + `BindRequest{status:'accepted'}` 关系,跳过完整注册 / 邀请码绑定流(per spec 025 走 B 子集决策)
5. **错误处理** — 401 typed → Session 清 Keychain + 回登录;其他错误 typed throw 由 ViewModel 决定 UI 展示

落地后两人真互通 happy path:
```
[你 iPhone 装 build → 登入(spec 025 已实装,本 spec 之后真 backend)]
教练 home → 排 plan → publish
  ↓ BackendPlanRepository.publishPlan(...) → POST /plans + 子节点
  ↓ → backend 002 publish endpoint → DB row plans.status='published' + 通知 stub fired
[xty iPhone(同一 backend)]
学员 Tab 今天 → fetchCurrentPlan
  ↓ BackendStudentPlanRepository.fetchCurrentPlan(studentId:) → GET /students/<xty_id>/plans?status=published
  ↓ → DB query plans WHERE trainee_id=<xty_id> AND status='published'
  ↓ → DTO 转 StudentPlanView → 学员侧 UI 渲染
点 reps + RPE + ✓ → BackendStudentTrainingLogRepository.recordSet(...)
  ↓ → POST /sets/log(本 spec 加新 backend endpoint;参考 backend 003 候选,本 spec 内顺手起草)
```

## 范围

### 做什么(分 iOS 侧 + backend 侧)

#### 1. 基础设施(运营动作,非代码;本 spec 显式追踪)

##### 1.1 RDS 重申 — F-025

- 阿里云控制台 → RDS PostgreSQL → 新建实例
- 规格:**单机版** 2c4G + ESSD PL1 50GB,PG 17.0
- 区域:cn-hangzhou(与 `meetpr-videos-prod` OSS bucket 同区,减跨区延迟 / 费用)
- 计费:**包月先试**(¥150-200/月)→ 跑通 2 周后 → 切包年 1y 自动续费(~¥1.8K/年)
- 安全组:白名单仅 SAE 部署 VPC + 你的开发 IP(per ADR-004 §6)
- SSL:**Stage 2 公测前** 开启(per ADR-004 §6 blocker);V0.1 内测可暂不开 SSL,放 followup
- 实例 ID + 密码 → Bitwarden `MeetPR RDS meetpr` 条目 update

##### 1.2 阿里云 SAE 部署

- 阿里云控制台 → SAE → 新建应用
- 命名空间:`meetpr-staging`
- 部署源:GitHub Actions 推 `staging` 分支 → Docker 镜像 → 阿里云 ACR → SAE 拉取
- 实例规格:**0.5 vCPU + 1GB**(预算 ~¥30-80/月,空闲免计费)
- 实例数:1(min=1, max=1;V0.1 不开 auto-scale)
- 环境变量:
  - `DATABASE_URL` = RDS 内网连接串(SAE 与 RDS 同 VPC = 免公网带宽)
  - `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` ≥ 32 chars(阿里云 SAE 配置;不进 git;Bitwarden 备份)
  - `NODE_ENV=staging`
  - `LOG_LEVEL=info`
- 健康检查:HTTP 200 on `GET /healthz`(backend 已有,per 001-auth `src/server.ts`)
- 暴露域名:V0.1 用 SAE 默认 `*.alicdn.com` 或临时 IP 直连;V0.1.x 切自有域名 + ICP 备案
- iOS `BuildConfig.backendBaseURL = "https://<sae-staging-url>"`(spec 025 留口)

##### 1.3 backend `staging` 分支解冻

- backend repo `CLAUDE.md` 头部 ❄️ FROZEN callout 移除
- 改成 "✅ V0.1+ 内测期:解冻,新 PR 须经 iOS spec 触发"
- 单独 docs PR(不计入本 spec 2 PR 约束)

#### 2. backend 侧改动(新 backend spec,本 SPEC 是 iOS spec 但里头收口 backend 改动清单)

##### 2.1 `0004-seed-internal-users.sql` migration(新)

位置:`db/migrations/0004-seed-internal-users.sql`

```sql
-- Seed: V0.1 内测核心用户 + bind 关系
-- David (coach) + xty (student) + bind status='accepted'
-- 用法:运行后真 phone+password 登入即可,跳过 register 流

BEGIN;

-- David coach(phone 占位,实装时 Codex 用 user 真手机号 + bcrypt password)
INSERT INTO users (id, phone, password_hash, role, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '+8613800000001',
  '$2b$10$REPLACEME_BCRYPT_HASH_FOR_David_PASSWORD',
  'coach',
  now(), now()
) ON CONFLICT (phone) DO NOTHING;

-- xty student
INSERT INTO users (id, phone, password_hash, role, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  '+8613800000002',
  '$2b$10$REPLACEME_BCRYPT_HASH_FOR_xty_PASSWORD',
  'coached_student',
  now(), now()
) ON CONFLICT (phone) DO NOTHING;

-- coach_profiles + student_profiles 各 1 行(per 002 schema)
INSERT INTO coach_profiles (user_id, display_name, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'David(内测教练)', now(), now())
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO student_profiles (user_id, display_name, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000002', 'xty(内测学员)', now(), now())
ON CONFLICT (user_id) DO NOTHING;

-- bind: David coach ← xty student, status='accepted'(直接 skip 评估期 + 邀请码)
INSERT INTO bind_requests (
  id, student_id, coach_id, status, submitted_at, responded_at,
  skip_evaluation, rejection_silent, expired_at
)
VALUES (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'accepted', now(), now(),
  true,   -- skip 评估期
  true,   -- silent reject(本字段对 accepted 无用,但 schema NOT NULL)
  now() + interval '7 days'
) ON CONFLICT (id) DO NOTHING;

COMMIT;
```

> **重要 implementer note**:`REPLACEME_BCRYPT_HASH_FOR_*` 占位**不能** commit 真 hash。Codex 实装时:
> - 在 migration 文件 head 加 `-- IMPLEMENTATION:在部署前手动 psql 跑 UPDATE 替占位为真 bcrypt hash`,migration 文件本身不留真密码
> - 或者在 SAE 部署后 manually `psql -h <RDS> -c "UPDATE users SET password_hash=... WHERE id=..."` 一次
> - **不要** 在 git 留任何真 hash,即便是测试 hash

也要 ensure `bind_requests` table schema 与 [data-model §1.5](~/Brain/wiki/projects/MeetPR/data-model.md) 对齐 — 若 backend 002 尚未建 bind_requests table,本 spec 一起补:

##### 2.2 检查 backend 002 是否已有 `bind_requests` table

- backend repo 跑 `\dt` 看现有 tables
- 若无 → 本 spec 加 `0003.5-init-bind-requests.sql` migration(参考 data-model §1.5 schema,简化字段:V0.1 不实装 evaluation,故 `evaluation_*` 列 V0.2+ 加)

> **决策点**:bind_requests schema 起多简洁取决于 backend 002 现状,Codex 实装时确认。最小 V0.1 列:`id, student_id, coach_id, status, submitted_at, responded_at, expired_at, skip_evaluation`。

##### 2.3 新 backend endpoint:`POST /sets/log`(学员录 set)

backend 002 只有教练 plan CRUD,**没有** 学员 set log endpoint。本 spec 加新 backend endpoint(可在 backend 单独 spec 003-student-actions 起,或与本 spec 同步走 backend deploy PR):

| Method + Path | Roles | Request | Response 200 |
|---|---|---|---|
| `POST /sets/log` | student | `{ planExerciseId, setIndex, weightKg, reps, rpe?, completed }` | `201 { id, loggedAt }` |
| `GET /students/:id/sets?from=...&to=...` | student(self) / coach(owner of plan trainee=id) | — | `200 { logs: SetLog[] }` |

DB schema(新 migration `0005-init-set-logs.sql`):
```sql
CREATE TABLE set_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_exercise_id UUID NOT NULL REFERENCES plan_exercises(id) ON DELETE CASCADE,
  set_index    INT NOT NULL,
  weight_kg    NUMERIC(6,2) NOT NULL,
  reps         INT NOT NULL,
  rpe          NUMERIC(3,1),
  completed    BOOLEAN NOT NULL DEFAULT FALSE,
  logged_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, plan_exercise_id, set_index)
);
CREATE INDEX idx_set_logs_student_logged ON set_logs (student_id, logged_at DESC);
```

UNIQUE `(student_id, plan_exercise_id, set_index)` = 学员同组重复录入 = upsert(`ON CONFLICT (...) DO UPDATE SET ...`)。

##### 2.4 新 backend endpoint:`POST /coach/feedback` + `GET /students/:id/feedback`(教练写 / 学员看反馈)

| Method + Path | Roles | Request | Response 200 |
|---|---|---|---|
| `POST /coach/feedback` | coach | `{ studentId, dayDate?, planExerciseId?, text }` | `201 { id, postedAt }` |
| `GET /students/:id/feedback` | student(self) / coach(owner) | — | `200 { items: Feedback[] }` |
| `PATCH /feedback/:id/read` | student | — | `204` |

DB schema `0006-init-feedback.sql`:
```sql
CREATE TABLE feedback (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id     UUID NOT NULL REFERENCES users(id),
  student_id   UUID NOT NULL REFERENCES users(id),
  day_date     DATE,
  plan_exercise_id UUID REFERENCES plan_exercises(id) ON DELETE SET NULL,
  text         TEXT NOT NULL CHECK (length(text) BETWEEN 1 AND 2000),
  posted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at      TIMESTAMPTZ
);
CREATE INDEX idx_feedback_student_posted ON feedback (student_id, posted_at DESC);
CREATE INDEX idx_feedback_student_unread ON feedback (student_id, posted_at DESC) WHERE read_at IS NULL;
```

> 这两个 endpoint 在 backend 应起独立 spec(`backend specs/003-student-actions/SPEC.md`)与本 iOS spec 平行。Codex 实装时:**先开 backend spec PR + impl PR**,后开 iOS impl PR(本 spec)。本 spec 描述 backend contract 是为了对齐双侧 API shape,**不 strip backend spec 的责任**。

#### 3. iOS 侧改动

##### 3.1 `BackendPlanRepository`(教练侧)实装

位置:`Modules/CoachKit/Sources/CoachKit/Planning/Repository/BackendPlanRepository.swift`(替占位)

```swift
public final class BackendPlanRepository: PlanRepository, Sendable {
  private let api: APIClient
  private let session: SessionStateReader   // 取 access token + currentUser
  private let cache: PlanCache              // Documents/ JSON cache
  public init(api: APIClient, session: SessionStateReader, cache: PlanCache) { ... }

  public func fetchStudents() async throws -> [CoachStudentSummary] {
    let token = try await session.accessToken()
    let dto: StudentsResponseDTO = try await api.get(path: "/coach/students", accessToken: token)
    let domain = dto.toDomain()
    await cache.save(students: domain)
    return domain
  }

  public func fetchMainLiftCatalog() async throws -> [Exercise] {
    // 走 backend 002 GET /exercises?exercise_type=main_lift
    // stale-while-revalidate: 先返 cache, 后台 refresh
    ...
  }
  // accessory / publishPlan 同 pattern
}
```

**stale-while-revalidate pattern**(per ADR-005 §4):
- 先调 `cache.fetch(...)` 拿 cached 值返回 UI
- 后台 task 调 backend → save cache → 通过 Combine / `AsyncStream` 通知 UI 刷新
- UI 层用 `.task { for await update in repo.observe(...) { ... } }` pattern

##### 3.2 `BackendStudentPlanRepository` / `BackendStudentTrainingLogRepository` / `BackendStudentFeedbackRepository`(学员侧)实装

位置:`Modules/StudentKit/Sources/StudentKit/Repository/Backend*.swift`(替 spec 024 留的占位 `fatalError`)

shape 同 §3.1 pattern;3 个 repo 各调对应 backend endpoint:
- StudentPlan → `GET /students/<id>/plans?status=published`(backend 002 已有)
- StudentTrainingLog → `POST /sets/log` + `GET /students/<id>/sets`(本 spec backend §2.3 新加)
- StudentFeedback → `GET /students/<id>/feedback` + `PATCH /feedback/<id>/read`(本 spec backend §2.4 新加)

##### 3.3 `BackendE1RMRepository`(spec 028 解锁后)

位置:`Modules/StudentKit/Sources/StudentKit/Repository/BackendE1RMRepository.swift`(若 spec 028 已落,加;否则 spec 028 内补)

E1RM 是**本地算**(per spec 028 §1),所以 backend 不存 e1RM points;BackendE1RMRepository 实际仍是**本地 JSON file cache**,**与 backend 无网络交互**。spec 028 内 `InMemoryE1RMRepository` → 本 spec 顺手切到 JSON file cache(per ADR-005 §4)。

→ 决策:**本 spec 不做** `BackendE1RMRepository`;e1RM 仅升级到 JSON file cache(本地);spec 028 改 `InMemoryE1RMRepository` → `LocalE1RMRepository`(JSON file)

##### 3.4 `PlanCache` / `StudentPlanCache` / `TrainingLogCache` / `FeedbackCache`(JSON file)

位置:`Modules/Networking/Sources/Networking/Cache/`

| Cache | path |
|---|---|
| `PlanCache` | `Documents/plans/<userId>.json` |
| `StudentPlanCache` | `Documents/student_plans/<studentId>.json` |
| `TrainingLogCache` | `Documents/training_log/<studentId>.json` |
| `FeedbackCache` | `Documents/feedback/<studentId>.json` |
| `E1RMCache` | `Documents/e1rm/<studentId>.json` |

actor 持文件 IO;schema 演变:`init(from:)` 容错(spec ADR-005 §4),解析失败丢 cache 重 fetch。

##### 3.5 `Networking` 模块 DTO + Domain mapping

位置:`Modules/Networking/Sources/Networking/DTO/`(新)

| 文件 | 内容 |
|---|---|
| `PlanDTOs.swift` | `PlanDTO` / `PlanDayDTO` / `PlanExerciseDTO` / `PlanSetDTO` / `PlanWithChildrenDTO`(对应 backend 002 wire format) |
| `StudentSetLogDTO.swift` | 上下行 set log DTO |
| `FeedbackDTO.swift` | 上下行 feedback DTO |
| `Mapping/PlanDTO+Domain.swift` | extension `func toDomain() -> StudentPlanView`(等) |

snake_case ↔ camelCase 走 `MeetPRCodec` 已建的 keyEncodingStrategy(spec 002-CoreModels 已建)。Decimal-as-string 走 `MeetPRCodec.decimalStringDecoder`(spec 002 已建)。

##### 3.6 `APIClient` 401 全局拦截

`APIClient` 内任一请求收 401 → throw `APIError.authInvalid`;Session 顶层 `task { for await event in api.errorStream { ... } }` 监听 → 自动 clear Keychain + state = `.anonymous`(per ADR-005 §3 中间路线)

##### 3.7 `MeetPRApp.init` 注入路径

DEMO_MODE 不变,沿用 in-memory mock;非 DEMO_MODE:
```swift
let api = APIClient.shared
let session = Session(auth: BackendAuthRepository(api: api), tokens: KeychainTokenStore())

let planCache = PlanCache()
let coachPlans = BackendPlanRepository(api: api, session: session, cache: planCache)

let studentPlanCache = StudentPlanCache()
let studentPlans = BackendStudentPlanRepository(api: api, session: session, cache: studentPlanCache)
// ... 3 个 student repo 同 pattern
```

##### 3.8 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/Networking/Tests/NetworkingTests/DTO/*MappingTests.swift`(新多个) | DTO ↔ Domain roundtrip;snake_case;Decimal-as-string;ISO 日期 |
| `Modules/Networking/Tests/NetworkingTests/Cache/PlanCacheTests.swift`(新) | save → read → roundtrip;schema 兼容性(缺字段不崩) |
| `Modules/CoachKit/Tests/CoachKitTests/Repository/BackendPlanRepositoryTests.swift`(新) | mock APIClient + cache,stale-while-revalidate 路径覆盖 |
| `Modules/StudentKit/Tests/StudentKitTests/Repository/Backend*Tests.swift`(3 个) | 同上 pattern |
| `Modules/Networking/Tests/NetworkingTests/APIClientErrorTests.swift`(新或扩) | 401 错误事件流路径 |

##### 3.9 CHECKLIST.md(本 spec 内)

```
[ ] RDS 实例 ready,psql 连上 + 跑完 migrations 0001-0006
[ ] SAE 部署成功,curl /healthz → 200
[ ] 0004-seed-internal-users migration 跑过,users 表有 David + xty 两行
[ ] iPhone A 安装 build,登入 David → 教练 home
[ ] 排 plan 4 周 → publish → backend DB row plans.status='published' for trainee=xty
[ ] iPhone B 安装 build,登入 xty → 学员 Tab 今天 → 看到刚 publish 的 plan 当日动作
[ ] 学员录 1 组 + 打勾 → backend set_logs 表有新 row + 教练 iPhone 切到学员详情(spec 029 后做)能看见
[ ] 教练写反馈(spec 029 后做)→ 学员 Feedback Tab 红点亮
[ ] 关闭网络 → 学员侧仍能看 cached plan(stale-while-revalidate)+ 录入失败 banner
[ ] 重启 app → Session.bootstrap 走 refresh → 仍 authenticated
```

### 不做什么

**V0.1.x defer**:
- SSL on RDS(per ADR-004 §6 上线前 blocker;V0.1 内测可暂不开,跑两周后切)
- RDS 白名单从 0.0.0.0/0 收敛(V0.1 用 SAE VPC 内网连 RDS,公网入口仅你 IP 白名单)
- ARMS 监控 / Sentry / SLS 长期日志(per lifecycle-stages §11 Stage 3 后启用)
- backend auto-scale + Postgres 读写分离(Stage 4)
- 多端同步 polling SLA ≤ 30s(本 spec 走 manual refresh + stale-while-revalidate,无 polling timer)
- e1RM 服务端化(本 spec 仍本地算,V0.1.x 若需要"换设备保留历史"才上 backend)
- WebSocket 实时同步(V1.5+)
- 海外副本 / CDN(Stage 5+)

**V0.2+ defer**:
- MPS 视频转码(spec 027 视频上传也仅 OSS 直传,V0.1 不转码;V0.2+ 启)
- KMS 加密 secret(V0.1 SAE 环境变量明文 + Bitwarden 备份;Stage 4 公测前切 KMS)
- 自动 backup + 跨区 DR(per ADR-004 §6 V1.5+)

## 技术要求

### Backend SPEC 跨 repo 协调

本 iOS spec **不是** backend spec 但描述 backend contract,因为 backend 改动是 iOS happy path 解锁的硬依赖。Codex 实装顺序:

1. **先开 backend repo `staging` 解冻 docs PR**(无代码,纯 CLAUDE.md 改)
2. **backend repo 起 spec 003-student-actions**(参考本 spec §2.3 + §2.4 描述,自起 SPEC.md 走 backend 2-PR 流程)
3. **backend repo impl PR**(实装 set_logs + feedback + seed migration)
4. **iOS 本 spec impl PR**(对接 backend endpoint)

→ 4 个 PR 串行(backend 2 + iOS 1 + docs 1)。可能比 1-spec-1-impl 多,接受。

### stale-while-revalidate 实装 pattern

```swift
public actor PlanCache {
  private let url: URL   // Documents/plans/<userId>.json

  public func fetch() async -> [PlanDTO]? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode([PlanDTO].self, from: data)
  }

  public func save(_ plans: [PlanDTO]) async {
    let data = (try? JSONEncoder().encode(plans)) ?? Data()
    try? data.write(to: url, options: [.atomic])
  }
}

public final class BackendPlanRepository: PlanRepository {
  public func fetchPlans() async throws -> [TrainingPlan] {
    // 1. 同步先返 cache
    if let cached = await cache.fetch() {
      Task.detached { try? await self.refreshInBackground() }
      return cached.map { $0.toDomain() }
    }
    // 2. cache 空 → 强制 fetch
    return try await refreshAndReturn()
  }

  private func refreshInBackground() async throws {
    let fresh = try await api.get(...)
    await cache.save(fresh)
    // 通知 UI(AsyncStream / NotificationCenter / @Observable bind)
  }
}
```

UI 层:`view.task { for await update in repo.changes { ... } }` 订阅刷新。

### Backend ↔ iOS DTO 字段名对照(critical)

backend 002 现 wire format 是 snake_case + Decimal-as-string + ISO 日期。`MeetPRCodec` 已建对应 converter(spec 002 + spec 004 已建)。Codex 实装时**任何新 DTO 都走 MeetPRCodec**,不在本 spec 重新发明。

### 部署 secret 管理

**绝不** commit:
- bcrypt 真 hash
- JWT_ACCESS_SECRET / JWT_REFRESH_SECRET
- RDS 连接串(账号密码)
- 阿里云 AK/SK(若需 OSS 签名 URL)

策略:
- 本地开发 → `.env` + `.gitignore`(per ADR-005 §4)
- SAE 部署 → SAE 控制台环境变量
- 备份 → Bitwarden 个人 vault(已有 `MeetPR RDS meetpr` 条目)

### 错误事件流

`APIClient` 持 `AsyncStream<APIError>`,Session bootstrap 时订阅:

```swift
session.bindToErrors(api.errorStream)
// Session 内部:
for await error in stream where case .authInvalid = error {
  try? await tokens.clear()
  state = .anonymous
}
```

ViewModel 层不感知 401 — Session 自动登出。其他错误 ViewModel 自处理。

## 验收清单

- [ ] RDS 实例 ready + 健康 + 内网连 SAE
- [ ] SAE staging 部署成功 + `/healthz` 200 + Apple Push 推送测试通过(若用 APNs;V0.1 跳)
- [ ] backend `staging` 解冻 PR 合并
- [ ] backend 003-student-actions SPEC + impl PR 合并
- [ ] 5 个 backend migrations 0001-0006 全跑过,DB schema ready
- [ ] 0004 seed migration 跑过,david + xty + bind 三行存在
- [ ] iOS 5 个 Backend* repo 真装,DEMO_MODE 占位仍 fatalError(双路径并存)
- [ ] 4 个 JSON file cache 实装 + stale-while-revalidate path 单测
- [ ] DTO ↔ Domain mapping 全套单测(包括 snake_case / Decimal / ISO)
- [ ] 401 全局拦截 + Session 自动登出 路径单测
- [ ] CHECKLIST 手动跑一遍(2 iPhone,1 RDS,1 SAE)
- [ ] CI 全过(iOS + backend 双 repo)

## 估时(给 Codex 参考)

| 块 | 估时 |
|---|---|
| 1. RDS 重申 + SAE 部署(运营动作) | 1.5d |
| 2. backend `staging` 解冻 + 003 spec 起草(Claude) | 0.5d |
| 3. backend impl(set_logs / feedback / seed migration) | 2d |
| 4. iOS BackendPlanRepository(教练侧) + cache + mapping | 1.5d |
| 5. iOS Backend* 3 个学员侧 repo + cache + mapping | 2d |
| 6. 401 全局拦截 + Session 错误流 | 0.5d |
| 7. e1RM cache(从 in-memory 切到 JSON file) | 0.3d |
| 8. CHECKLIST + 2 iPhone 联调 + bug 修 | 1.5d |
| **合计** | **≈ 10d**(含 1.5d 运营) |

## 风险 / 待 implementer 关注

1. **RDS 包年 1y commit 不可逆**:V0.1 内测先包月(¥150-200/月),跑 2-4 周验真用了 backend 再切包年(¥1.8K-2.4K/年)。若中途砍 backend 回 in-memory,包年钱不退
2. **SAE 冷启动延迟**:0.5 vCPU + 1GB 实例,免计费空闲后冷启动可能 5-15s,首次请求 timeout 风险。可设置 `min instances >= 1` 持续运行(月费 ~¥40);本 spec 选 `min=1` 避免冷启动
3. **跨 repo PR 协调**:4 个 PR 串行,Codex worktree 切换 + dependency wait 增加流转时间;建议你或 Codex 优先合 backend `staging` 解冻 + 003 spec,iOS 部分等 backend impl 上线后再跑联调
4. **seed migration 真 bcrypt hash**:**绝不 git commit**。流程:Codex 写 migration 占位 → 你或 Codex 在部署后 manual `psql` 一次性 UPDATE
5. **bind_requests schema 可能要新建**:backend 002 是否已起 table 决定本 spec 是否要 0003.5 migration。Codex 实装第一步 verify
6. **e1RM 仍本地**:本 spec 不引入 e1RM backend endpoint,因 V0.1 仅你+xty 不会换设备;V0.1.x 若教练换 iPhone 需要历史 e1RM 不丢,再加 backend
7. **stale-while-revalidate UI 闪烁风险**:cache 旧数据先渲染 + 网络 fresh 又渲染一次,UI 可能"跳"。建议 UI 加 `withAnimation(.smooth)` 缓和;若问题大,Codex 可改为"loading 状态时不渲染 cache"作 fallback

## Implementation Notes

无(spec PR 阶段)。

## 上游 / 下游

**上游**:
- spec 025 real auth login + Keychain(access token 注入路径)
- spec 024 学员端 P0(Backend* repo 占位)
- backend 001-auth + 002-coach-planning-crud(endpoint 已有)
- ADR-004 + ADR-005

**下游**:
- spec 027 视频上传:需 OSS endpoint(本 spec 不实装,留 §V0.1.x defer);spec 027 内补 OSS 签名 URL endpoint(backend) + iOS VideoUploadActor
- spec 029 教练端 review:复用本 spec `BackendStudentPlanRepository` / `BackendStudentTrainingLogRepository` / `BackendStudentFeedbackRepository` 读学员数据 + 写反馈
- V0.1.x SSL on RDS / 白名单收敛 / ARMS 监控
- V0.2+ MPS 转码 / KMS / backup

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。运营 + backend + iOS 三轴并行;V0.1 内测期 ¥190-290/月 | Claude |
