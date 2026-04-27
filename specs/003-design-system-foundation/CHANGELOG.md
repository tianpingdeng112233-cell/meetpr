# Spec 003 Design System — Bundle Changelog

## v4 — 2026-04-27 (current)

**Bundle source**:`https://api.anthropic.com/v1/design/h/YJ1p2nYRv-Ij6by3oRMVPg`

### Fixed (vs v3) — David 视觉走查 4 项 feedback
- **AuthFlow phone field 右侧遮住**(screens-2.jsx line 182)— 加 `flex:1 + minWidth:0 + width:100% + boxSizing:border-box`,标准 CSS overflow 修法
- **CoachDashboard 学员状态徽章** "直播" → "训练中"(screens-1.jsx line 71;`comp-badges.html` 同步加 `badge-live` 变体)
- **PlanningEditor 默认仅显示 W3,展开看完整 4 周中周期**(screens-1.jsx line 97 加 `useState(expanded)` + line 161 折叠按钮)
- **StudentPlanView 周日历改为 SBD 字母制**(screens-2.jsx line 116-130)— 每天 cell 仅显示 `S` / `B` / `D` / `—`,不再展示具体动作名;done 状态用红色三角角标

### Known design issue:Coach Planning Editor 4×7 grid 在 iPhone 仍偏挤
即便 v4 默认仅 W3,展开 4 周后 7 列 × 4 行在 375pt 屏宽下每格仅 ~40pt,密度过高。

**Spec 003 不修此问题**(hi-fi 屏 out-of-scope)。**真正解决**留到 Coach Planning Editor feature spec(预计 spec 010-015 区间),设计 3 模式 toggle:
- 日模式(默认):单日完整组数次数 RPE
- 周模式:7 天 × SBD 字母 grid(复用 StudentPlanView 同款)
- 整块模式:动作 × W1-W4 sparkline 矩阵

iOS native primitive 倾向:`Picker(.segmented)` 选模式 + `TabView(.page)` 切周。Codex 实施时按届时 feature spec 走,**不直接照搬当前 v4 hi-fi 屏的 4×7 grid 形态**。

---

## v3 — 2026-04-27 (replaced by v4)

**Bundle source**:`https://api.anthropic.com/v1/design/h/I-fGVIP1JnB9ZRx7hK0kkQ`

### Added
- `project/uploads/` — 8 个 PRD 文件作为 Claude Design 生成时的 ground truth 快照(prd / data-model / IA / user-stories / 003-ADR / student-onboarding / coach-planning / evaluation-workflow)
- `project/assets/icons/MAPPING.md` — 30+ Lucide → SF Symbols 映射(spec 003 验收要求的 4 个 SF Symbol 已被覆盖,后续 feature spec 也可直接查表)
- `colors_and_type.css`:新增 `--font-display-cn` 变量(中文 display 字体 stack),用于大号中文标题渲染

### Fixed (vs v1)
- **Auth flow**(`screens-2.jsx`)— phone-pre-registration 错误已修
  - v1:`"MeetPR is invitation-based. Enter the phone number on file with your coach."` ❌(把 binding 提前到 auth)
  - v3:`"输入手机号,我们将发送验证码。"` ✅(纯 auth,无教练耦合)
- **Role selection**(同上文件)— 单角色锁死
  - v1:`"Your number is registered for both. Pick the surface for this session — you can switch later."` ❌(违反 ADR 003 v4)
  - v3:`"注册后角色将锁定。多角色支持在 V1.5 评估。"` ✅
- **Role enum 3 值化**:学员·有教练 / 学员·自己练 / 教练(对齐 data-model.md v1.1 §1.1 `User.role`)
- **Apple Sign-In** 显示为 disabled + "即将开放" badge(后续 auth feature spec 实装时再启用)

### Known divergences from IA(implementation 严守 IA)
v3 的 hi-fi 屏在 tab 标签命名上跟 [`information-architecture.md`](~/Brain/wiki/projects/MeetPR/information-architecture.md) §1.2 / §1.3 略有出入。**实施时以 IA 为准**:

| Tab role | IA 标签 | bundle 标签 | 实施 ground truth |
|---|---|---|---|
| 教练 tab 1 | Dashboard | 今日 | IA(Dashboard / 仪表盘)|
| 教练 tab 3 | 编排器 | 计划 | IA(编排器)|
| 教练 tab 4 | 接收队列 | 消息 | IA(接收队列 — 仅 pending 学员请求,语义专属)|
| 学员 tab 3(coached_student)| 成长 | 记录 | IA(成长 — e1RM 时间序列 + PR 历史)|

bundle 取的中性命名是合理设计选择,但 IA 的命名跟数据模型语义 1:1 对应(接收队列 = `BindRequest(status='pending')` 列表;成长 = `e1RMHistory` 时间序列),保持 IA 命名能让 spec 跨文档可追溯。

### Out of scope for spec 003 implementation
- 5 屏 hi-fi(`ui_kits/ios_app/screens-*.jsx`)— 仅作视觉参考,**不在 spec 003 实施范围**
- WeekPlanGrid / Chart / VideoUploadCell / SetRow / CustomTabBar / EmptyState — 留 feature spec

---

## v1 — 2026-04-27 (replaced by v3)

**Bundle source**:`https://api.anthropic.com/v1/design/h/E2NUdM-5CWaMmpAd1H8bvQ` (deprecated)

### Issues that motivated v3
1. Auth screen invented "phone on file with your coach" flow conflicting with PRD invite-code binding(data-model.md §1.5)
2. Role screen showed "switch later" multi-role toggle conflicting with ADR 003 v4 single-role-lock decision
3. PRD files not attached to Claude Design — visual brief alone caused product-flow hallucinations
4. Missing `assets/icons/MAPPING.md`(README 提到但文件缺失)

v1 内容已被 v3 覆盖,不再保留;若需查阅 v1 diff 见 git history `commit feat/spec-003-design-system`(初始 commit `92fa884` ↔ replacement)。
