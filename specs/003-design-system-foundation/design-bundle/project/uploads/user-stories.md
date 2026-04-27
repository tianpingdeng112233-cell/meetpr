---
tags: [meetpr, user-stories, requirements, p0, mvp]
created: 2026-04-27
updated: 2026-04-27
status: draft
verification_status: framework
---

# MeetPR — 用户故事 (User Stories) v1

> **Status**: Draft v1 · **Date**: 2026-04-27 · 从 [[prd|PRD v0.7]] §5 P0 27 项映射 + [[student-onboarding|Onboarding v2.4]] / [[coach-planning|Coach Planning v4.2]] / [[evaluation-workflow|Evaluation v1.1]] 抽取
> 关联: [[information-architecture|IA v1]] (姊妹文档,每个 page/state 至少 1 条 US)

> [!info] V1 单角色 (US-S vs US-C 互不交叉)
> 详见 [[decisions/003-dual-end-native-architecture|ADR 003 v4]]。学员故事 (US-S-XXX) 与教练故事 (US-C-XXX) 对应不同 RootView，**注册后不可切换**，不会出现"同一用户既是 US-S-... 又是 US-C-..."的场景。多角色单用户场景 deferred 到 V1.5+。

> [!info] 优先级图例
> - **P0** — V1 MVP 必做
>   - **Phase 1** (B2B 优先): 教练端 + 学员有教练 + 双端共享, B2B 公测先上
>   - **Phase 2** (B2C 跟随): 学员自己练 + B2C IAP, gated by 里欧 1 周交付模板
> - **P1** — V1.5 迭代 (V1 公测后 1-3 月)
> - **V1.5+ deferred** — 触发条件未满足前不做

---

## 学员侧 (Student / `US-S-XXX`)

### US-S-001 — 单角色注册 + 选角色锁死

**As a** 新用户
**I want** 用手机号或 Apple Sign-In 注册并选择"学员"角色
**So that** 我能进入学员端开始训练流程，且不会因身份切换的复杂性导致选错入口

**验收标准**:
- [ ] 提供手机号注册 (短信验证码) + Apple Sign-In (iOS §4.8 合规) 两种入口
- [ ] 注册第一步弹"教练 / 学员"选择，选定后不可在 app 内切换
- [ ] 选定 学员 后路由到 `StudentRootView`，不展示教练端任何 UI 元素
- [ ] 想换角色仅可注销重新注册 (明确弹提示)
- [ ] V1 不含微信登录 (V1.5 评估)

**关联**: [[prd|PRD]] §5 P0 #24 · [[data-model#1.1 User]] · [[decisions/003-dual-end-native-architecture|ADR 003 v4]] · [[decisions/005-ios-architecture|ADR 005]] §2

**优先级**: **P0** (Phase 1)

---

### US-S-002 — 选训练 mode (有教练 / 自己练) 锁死

**As a** 学员
**I want** 在 onboarding 末尾选择"跟我的教练"或"自己练"
**So that** app 知道把我路由到 B2B 流程还是 B2C 模板系统，不被混合 UI 干扰

**验收标准**:
- [ ] Onboarding Step 7 后弹 mode 选择页 (二选一)
- [ ] 选定后 `user.role` 写入 `coached_student` 或 `self_train_student`
- [ ] V1 选定后不可切换 (在"我的"无切换按钮)
- [ ] 选 有教练 → 进入 邀请码输入页;选 自己练 → 进入模板浏览 (Phase 2 才生效)
- [ ] 学员 mode toggle (有教练 → 自己练) V1 不开放, V1.5 评估

**关联**: [[prd|PRD]] §5 P0 #19 + #24 · [[student-onboarding#§F.2 学员角色 → 选 mode (V1 注册时锁死)]] · [[data-model#1.3 StudentProfile (学员独有数据,含 onboarding)]]

**优先级**: **P0** (Phase 1: coached; Phase 2 上后: self_train 也可选)

---

### US-S-003 — 完成 7 步 Onboarding

**As a** 新学员
**I want** 用 7 个步骤填完 基础信息 / 训练背景 / 1RM / 训练环境 / 恢复能力 / 训练资料 / 补充信息
**So that** 教练能在 ≤ 5 分钟内得到我的完整画像，我能拿到匹配的训练计划

**验收标准**:
- [ ] 7 步,每步独立页面,顶部进度条 (Step N of 7)
- [ ] 必填字段 (身高 / 体重 / 性别 / 生日 / 单位制 / 训练年限 / SBD 姿势 / 三大项 1RM / 训练日 / gym tier / 恢复 4 滑块 / 是否备赛) 未填不能下一步
- [ ] 1RM 弹计算器键盘,可用 RPE-based / Epley 估算;不确定提示填 90% 估测
- [ ] gym tier 选定后自动预填器械清单,可微调
- [ ] 完成后所有字段写入 StudentProfile + 自动同步给教练侧学员评估表

**关联**: [[prd|PRD]] §5 P0 #9 (隐含 onboarding 前置) · [[student-onboarding|学员 Onboarding v2.4]] Step 1-7 · [[data-model#1.3 StudentProfile (学员独有数据,含 onboarding)]]

**优先级**: **P0** (Phase 1)

---

### US-S-004 — 上传过往训练计划 + 三大项视频

**As a** 学员
**I want** 在 onboarding Step 6 上传过往训练计划截图 (可选) + 三大项视频 (深蹲 / 卧推 / 硬拉，每项最多 3 个角度，默认 60s 最大 120s)
**So that** 教练能通过我的过往技术录像评估我，而不是只靠数字判断

**验收标准**:
- [ ] 训练计划接受 PNG / JPG / PDF, 可多张 (例: 飞书 / 腾讯文档 / Excel 截图)
- [ ] 视频录制时长默认 60s, 上限 120s (议题 7 v0.7 升级, 之前 90s)
- [ ] 每项三大项最多 3 个视频 (角度由学员自定)
- [ ] 上传走 OSS multipart resumable upload (断点续传)
- [ ] 想增强肌群最多选 3 个 (从 9 选: 股四 / 臀 / 腘绳 / 竖脊肌 / 胸 / 背 / 肩 / 三头 / 二头 / 核心 / 小腿)
- [ ] V1 不做 slow-mo 录制 (V1.5)

**关联**: [[prd|PRD]] §5 P0 #14 · [[student-onboarding#Step 6 of 7 — 训练资料 (v2 重构)]] · [[coach-planning#§β.3 视频上传 conventions]] · [[data-model#1.12 VideoUpload (视频管线)]]

**优先级**: **P0** (Phase 1)

---

### US-S-005 — 输入邀请码绑定教练

**As a** 学员 (有教练 mode)
**I want** 输入或扫教练给我的邀请码完成绑定请求
**So that** 我能与该教练建立绑定关系,接收他/她的评估和训练计划

**验收标准**:
- [ ] 接受 10 字符 alphanumeric code (3 类: Personal 永久 / 一次性 / 限时, 学员侧不需识别类型)
- [ ] 提交后立即创建 `bind_request` (status='pending')
- [ ] 进入 待接收 状态页 (US-S-006)
- [ ] 限时码过期 / 一次性码已用过 / Personal 码 revoked → 报错"邀请码无效"
- [ ] 支持扫码入口 + 手动输码入口

**关联**: [[prd|PRD]] §5 P0 #25 · [[evaluation-workflow#2 邀请码体系(3 类 code)]] · [[data-model#1.5 BindRequest (学员绑定教练请求队列)]] · [[data-model#1.6 InviteCode (3 类 + 老教练推荐)]]

**优先级**: **P0** (Phase 1)

---

### US-S-006 — 待接收状态查看

**As a** 学员 (绑定请求已发出)
**I want** 提交绑定请求后看到 "已发送 + 等待教练接收 + 已等待 X 小时"
**So that** 我知道请求已送达，不会误以为 app 卡住或自己漏了一步，且能看到合理的预期等待时间

**验收标准**:
- [ ] 显示倒计时 (已等待 X 小时 X 分)
- [ ] 显示"教练通常 24h 内响应"提示
- [ ] 列出已上传给教练的资料概览 (N 视频 + N 计划)
- [ ] [取消请求] 按钮 → status='cancelled'
- [ ] 教练 48h 未响应 → 收到"教练尚未响应"推送
- [ ] 教练 7 天未响应 → 收到"请求过期"推送 + status='expired', 可重新输码或换教练

**关联**: [[prd|PRD]] §5 P0 #9 · [[evaluation-workflow#3.5 学员侧"待接收"状态]] · [[student-onboarding#§A 待接收状态]] · [[data-model#1.5 BindRequest (学员绑定教练请求队列)]]

**优先级**: **P0** (Phase 1)

---

### US-S-007 — 评估期内状态查看

**As a** 学员 (`evaluation_period` 进行中)
**I want** 看到 "评估进行中 + 还剩 X 天 X 小时 + 教练已查看 N/M 资料 + 教练留言 + 适应周训练 (如有)"
**So that** 我知道教练真的在看我的资料，不被 silent 等待逼到放弃，同时能利用适应周熟悉 app

**验收标准**:
- [ ] 显示倒计时进度条 (`started_at + 7d - now`)
- [ ] 显示教练已查看视频 + 计划计数 (3/4 视频 + 1 计划)
- [ ] 显示教练留言 (V1 单条; V1.5 多条积累 thread)
- [ ] 适应周训练卡片 (如教练发了 1 周轻量计划) [开始训练]
- [ ] 期内可执行 [开始训练] 跑适应周
- [ ] 不显示 [换教练] 按钮 (V1 marketplace 前不上)
- [ ] 不显示教练 evaluation note 进度细节

**关联**: [[prd|PRD]] §5 P0 #10 · [[evaluation-workflow#4 评估期(7 天硬框架)]] · [[student-onboarding#§B 评估期状态]]

**优先级**: **P0** (Phase 1)

---

### US-S-008 — 评估总结摘要 + 一键展开

**As a** 学员 (评估期完成)
**I want** 收到"教练完成评估"推送 → 点开看 摘要 (训练规划前 1-2 句 + 给学员的话前 1-2 句) → [展开看完整]
**So that** 我能快速理解教练对我的判断，且需要时能看完整 3 字段全文

**验收标准**:
- [ ] 首次保存 = 自动推送学员 ("教练张三完成了你的评估!点击查看")
- [ ] 点推送跳到摘要页
- [ ] 摘要显示训练规划 + 给学员的话各 1-2 句 (整体评估字段不在摘要,仅展开时显示)
- [ ] [展开看完整] → 跳到 3 字段全文页 (整体评估 + 训练规划 + 给学员的话)
- [ ] 持久访问: "我的资料" → "教练评估"卡片 (教练后续修改的最新版永远显示)
- [ ] 教练后续修改 → 默认 silent + 教练保存时可勾选 通知学员

**关联**: [[prd|PRD]] §5 P0 #11 · [[evaluation-workflow#5 评估总结(3 字段简化模板)]] · [[student-onboarding#§C 评估总结呈现]] · [[data-model#1.7 EvaluationPeriod + StudentEvaluation (评估期)]]

**优先级**: **P0** (Phase 1)

---

### US-S-009 — 接收正式训练计划 + 推送

**As a** 学员 (评估完成 / 跳过评估期 后)
**I want** 收到 "教练发布了你的训练计划" 推送 → 看到本周日历 + W1-W4 概览 (4 周模式)
**So that** 我能立即开始训练，知道接下来 N 周怎么练

**验收标准**:
- [ ] APNs 推送到达 SLA ≤ 30s (90 分位, ADR 004)
- [ ] 学员侧训练 tab 切换到状态 E (正式 cycle)
- [ ] 本周日历显示训练日 + 休息日 + 主项概览
- [ ] 1 周 / 4 周模式都支持
- [ ] 教练改未来日期的计划 → 学员端立即更新

**关联**: [[prd|PRD]] §5 P0 #12 + #26 · [[coach-planning|coach-planning v4.2]] Step 8 发布 · [[data-model#1.8 TrainingPlan + Day + Exercise + Set (训练计划层)]]

**优先级**: **P0** (Phase 1)

---

### US-S-010 — 训练日逐组录入

**As a** 学员 (训练中)
**I want** 每组完成后录入 重量 / 次数 / RPE，RPE 用 0.5 步进滑块
**So that** 我能精准记录训练数据，系统能算出 e1RM 跟踪进步

**验收标准**:
- [ ] 数字输入弹计算器键盘 (不弹默认输入法)
- [ ] RPE 滑块步进 0.5, 默认值预填 (从计划读)
- [ ] 重量输入支持 kg / %1RM 切换 (内置实时换算)
- [ ] 完成打勾 → set.status='working' (or 'failed' / 'amrap' / 'backoff')
- [ ] 当组所有字段填完 → 自动跳下一组
- [ ] 当日全部组完成 → `session.status='completed'` + 推送教练

**关联**: [[prd|PRD]] §5 P0 #13 · [[data-model#1.8 TrainingPlan + Day + Exercise + Set (训练计划层)]] PlanSet · [[coach-planning#§α e1RM 计算]]

**优先级**: **P0** (Phase 1)

---

### US-S-011 — 录视频 + 隐私同意 + 上传队列

**As a** 学员
**I want** 在每组完成后选择性录视频 (默认 60s 最大 120s)，首次上传时弹隐私同意 (仅绑定教练可见)，视频走断点续传后台上传
**So that** 教练能看到我的技术，同时网络不稳定不会丢失视频

**验收标准**:
- [ ] 每动作每组都有 [+ 录视频] 入口 (不限于重点组)
- [ ] 录制时长默认 60s, 上限 120s
- [ ] 首次上传弹隐私 modal: "视频将仅你绑定的教练可见,你同意吗?" → [同意] 写入合规审计
- [ ] 加入上传队列 → `VideoUploadActor` 走 OSS multipart upload
- [ ] 网络断 → 暂停 + 持久化 `Documents/upload_queue/*.json`
- [ ] App 重启 / 网络恢复 → 自动 resume
- [ ] V1 单视频串行 (一组 set 录 3 视角排队传); V1.5 并发 + HEIC→H.265 客户端转码

**关联**: [[prd|PRD]] §5 P0 #14 · §8.10 视频管线 · [[coach-planning#§β.3 视频上传 conventions]] · [[decisions/005-ios-architecture#§ 4. 横切关注点]] resumable upload · [[data-model#1.12 VideoUpload (视频管线)]]

**优先级**: **P0** (Phase 1)

---

### US-S-012 — 训练历史按周/月查看

**As a** 学员
**I want** 在 计划 tab 切换"按周 / 按月"查看历史训练记录
**So that** 我能复盘过去几周做了什么 / 状态如何

**验收标准**:
- [ ] 提供周视图 + 月视图切换
- [ ] 单天点击 → 跳到当天训练详情 (主项 + 辅助 + 每组数据)
- [ ] 月视图显示该月所有训练日 (高亮)
- [ ] 历史训练只读, 无法编辑

**关联**: [[prd|PRD]] §5 P0 #15 · [[data-model#1.8 TrainingPlan + Day + Exercise + Set (训练计划层)]]

**优先级**: **P0** (Phase 1)

---

### US-S-013 — 三大项 e1RM 折线 + PR 推送

**As a** 学员
**I want** 在 成长 tab 看三大项 e1RM 折线 (基础版,单条平均线)，且当 e1RM 突破历史最高时收到推送
**So that** 我能看到自己变强的客观证据，这是 PR 重塑后的"进步指标"

**验收标准**:
- [ ] 三大项各独立折线 (squat / bench / deadlift, 每个 variation 独立曲线)
- [ ] 显示"近 4 周最高 e1RM"避免单点暴跳
- [ ] e1RM 每次训练完成后系统自动重算 (RPE-based + Epley fallback)
- [ ] e1RM > 历史最大 → 推送 "今天你的 squat e1RM 突破!"
- [ ] 1RM 字段不被改 (锁定, 仅 onboarding / 教练 / V2 比赛触发)
- [ ] 单条平均线即可 (峰值 / 平均 RPE 分离推迟到 V1.5, 详见 [[prd|PRD]] §5 顶部 ADR 002 状态说明)

**关联**: [[prd|PRD]] §5 P0 #16 · [[coach-planning#§α e1RM 计算 (v4.2 新增 - 议题 1 决议)]] · [[evaluation-workflow#0.1 v1 → v1.1 update(领域会议议题 6 PR 重塑)]] · [[data-model#1.10 e1RMHistory (议题 6 PR 重塑 - 新增)]]

**优先级**: **P0** (Phase 1)

---

### US-S-014 — 查看教练反馈

**As a** 学员
**I want** 看教练对我每组视频的反馈 (👍 OR 文本)
**So that** 我能拿到具体的技术指导,知道哪组做对了哪组要调整

**验收标准**:
- [ ] 反馈 per-set granularity
- [ ] 2 类: 👍 没问题 OR 文本反馈 (V1 不含语音 / 5-10 预设按钮)
- [ ] APNs 推送通知到达学员
- [ ] 学员端反馈聚合页 OR 在训练日页 inline 展示
- [ ] 已读 → `CoachFeedback.read_by_student_at` 写入

**关联**: [[prd|PRD]] §5 P0 #17 · [[coach-planning#§β 视频反馈队列 (v4.2 新增 - 议题 7 + 议题 8 决议)]] · [[data-model#1.13 CoachFeedback (议题 8 简化版)]]

**优先级**: **P0** (Phase 1)

---

### US-S-015 — 我的资料 4 级修改权限

**As a** 学员
**I want** 在"我的"修改 onboarding 字段, Type A 锁定 / Type B 改完推送教练 / Type C/D silent
**So that** 我能维护自己的资料，但不会改坏 cycle 基线 (教练计划基于 1RM)

**验收标准**:
- [ ] **Type A** (1RM / 训练日 / 训练环境): cycle 中只读 🔒, 显示"联系教练修改"
- [ ] **Type B** (伤病 / 恢复评估 4 滑块): 可改 + 弹"已通知教练"
- [ ] **Type C** (想增强肌群 / 比赛日期 / 给教练备注): 可改 silent (无提示)
- [ ] **Type D** (身高 / 体重 / 单位制 / 联系方式): 可改 silent
- [ ] 教练评估总结持久查看 + 教练改后最新版永远显示

**关联**: [[prd|PRD]] §5 P0 #18 · [[student-onboarding#§D 我的资料 4 级修改权限]] · [[data-model#3.5 学员字段权限(议题 2.2)]]

**优先级**: **P0** (Phase 1)

---

### US-S-016 — 训练日 24h 内紧迫推送

**As a** 学员
**I want** 教练改我明天的训练计划时收到高优先级推送 + 主页红点
**So that** 我不会因为没看到改动而按旧计划训练

**验收标准**:
- [ ] 教练改 24h 内训练日 → 推送 "⚠️ 教练刚刚调整了你明天的训练,请查看"
- [ ] 主页红点 + 训练日卡片 highlight
- [ ] 教练改 W2-W4 (非 24h 内) → normal 推送 "教练更新了你 W2 的训练计划"
- [ ] V1 不显示具体 diff (V1.5 评估)
- [ ] V1 不显示教练改动原因 (走"留言"通道)

**关联**: [[prd|PRD]] §5 P0 #26 · [[coach-planning#§Z 教练改 cycle 计划的学员端推送规则 (v4.1 新增 - office hours Gap #5 Q-5.2)]] · [[student-onboarding#§E 教练改 cycle 计划的学员端通知 (v0.6 新增 - office hours Q-5.2)]]

**优先级**: **P0** (Phase 1)

---

### US-S-017 — 解绑教练 (单方)

**As a** 学员 (已绑定教练)
**I want** 在"我的"主动解绑当前教练，不需对方同意
**So that** 教练教得不合适或我换城市等场景能切换出去

**验收标准**:
- [ ] "我的" → 我的教练 → [解绑教练] 弹确认 modal
- [ ] 确认后 bind 关系终止 + 当前 cycle 标记 'paused' / 'completed'
- [ ] 学员侧切回未绑定状态 (训练 tab 状态 A)
- [ ] 教练侧推送 "学员解绑"
- [ ] 学员历史训练数据保留 (e1RM / 训练记录 / 视频)

**关联**: [[prd|PRD]] §5 P0 #1 学员管理 · [[data-model#1.5 BindRequest (学员绑定教练请求队列)]]

**优先级**: **P0** (Phase 1)

---

### US-S-018 — 自己练 onboarding (B2C 简化版)

**As a** 自己练学员
**I want** 走简化 onboarding (1RM 自填 + 目标 + 频率 + 选模板)
**So that** 不依赖教练也能拿到一份基于欧美主流 program 的训练计划

**验收标准**:
- [ ] 1RM 自填 + 不确定填 90% 估测提示 (复用有教练 onboarding Step 3 组件)
- [ ] 训练目标选择 (增力量 / 增肌 / 备赛 / 综合)
- [ ] 训练频率 3 / 4 / 5 天 / 周
- [ ] 模板浏览 10-15 个 program (里欧整理交付,详见 [[prd|PRD]] §13.1)
- [ ] 完成后路由到模板参数化页 (US-S-019)

**关联**: [[prd|PRD]] §5 P0 #19 + #20 · [[student-onboarding#§F.2 学员角色 → 选 mode (V1 注册时锁死)]] · [[product-decisions/004-b2c-v1-template-based|PD-004]]

**优先级**: **P0** (Phase 2)

---

### US-S-019 — 自己练参数化生成训练计划

**As a** 自己练学员
**I want** 选定模板 + 输入参数 (1RM / 频率 / 周期长度) 后系统按模板规则展开成可执行计划
**So that** 我不需要自己算每周的重量递增,直接按计划训练

**验收标准**:
- [ ] 模板参数化展开为多周训练计划 (PlanDay / PlanExercise / PlanSet)
- [ ] 周期推进 (线性渐进 OR 模板内置周期)
- [ ] deload 自动插入 (按模板规则)
- [ ] V1 不做算法生成 / AI 生成 / 个性化偏离模板
- [ ] V1.5+ 评估 AutoPlanDomain 算法替代 (详见 [[decisions/005-ios-architecture#§ 5. Stage 演进 + V1.5 触发条件]])

**关联**: [[prd|PRD]] §5 P0 #21 · [[decisions/005-ios-architecture#§ 5. Stage 演进 + V1.5 触发条件]] (Stage 3-4 边界 AutoPlanDomain) · [[product-decisions/004-b2c-v1-template-based|PD-004]]

**优先级**: **P0** (Phase 2)

---

### US-S-020 — 自己练训练执行 + 成长曲线

**As a** 自己练学员
**I want** 复用 录 set + 训练历史 + e1RM 折线组件 (去掉教练反馈)
**So that** B2B 和 B2C 共享同一套训练数据底层,我能看到自己的进步

**验收标准**:
- [ ] 复用 US-S-010 训练记录组件
- [ ] 复用 US-S-012 训练历史组件
- [ ] 复用 US-S-013 e1RM 折线 + PR 推送
- [ ] 不显示教练反馈相关 UI
- [ ] V1 不做视频上传 (无教练接收侧, V1.5 评估"复盘视频"独立场景)

**关联**: [[prd|PRD]] §5 P0 #22 · [[decisions/005-ios-architecture|ADR 005]] §1 SPM 包共享

**优先级**: **P0** (Phase 2)

---

### US-S-021 — 自己练 B2C 订阅 + 试用

**As a** 自己练学员
**I want** "我的" → 订阅页 7-14 天免费试用 + IAP 付费续订
**So that** 试用期感受产品价值,合适再付钱

**验收标准**:
- [ ] 7-14 天免费试用期 (具体天数 V1 启动前定)
- [ ] 试用期内全功能可用
- [ ] 试用期结束前 N 天推送提醒
- [ ] IAP (Apple 内购) 走 §4.8 合规
- [ ] 取消订阅 → 试用期结束后切只读模式或提示重新订阅

**关联**: [[prd|PRD]] §5 P0 #23 · §8.3 IAP

**优先级**: **P0** (Phase 2)

---

## 教练侧 (Coach / `US-C-XXX`)

### US-C-001 — 单角色注册 (教练)

**As a** 教练
**I want** 注册时选 "教练" 角色,获得教练端 RootView
**So that** 我能进入接收学员 + 编排计划的工作流，不被学员端 UI 干扰

**验收标准**:
- [ ] 提供手机号注册 + Apple Sign-In
- [ ] 选 教练 后路由到 `CoachRootView` (5 个 tab)
- [ ] 不展示学员端任何 UI (Onboarding 7 步流不出现)
- [ ] V1 注册后不可切换 (教练不能"自己当学员")
- [ ] 想自己练只能注销重新注册成学员账号 (V1 workaround; V1.5+ 多角色启用后才有副身份场景, 触发条件: B2B Stage 5-6 公测稳定后 ≥ 5 教练反馈)

**关联**: [[prd|PRD]] §5 P0 #24 · [[decisions/003-dual-end-native-architecture|ADR 003 v4]] · [[data-model#1.1 User]]

**优先级**: **P0** (Phase 1)

---

### US-C-002 — 生成 3 类邀请码

**As a** 教练
**I want** 生成 Personal 永久 / 一次性 / 限时 三类邀请码
**So that** 不同场景 (朋友圈固定推 / 给特定学员 / 馆活动周限时) 有合适的码

**验收标准**:
- [ ] **Personal 永久码**: 默认 1 个,可手动 revoke 后重新生成
- [ ] **一次性码**: 按需生成,用 1 次后自动失效,可加 label "给小明"
- [ ] **限时码**: 按需生成,设过期天数 (7/30/自定义),到期自动失效
- [ ] 每码 10 字符 alphanumeric, indexed unique
- [ ] V1 无数量上限 (议题 V1 默认)
- [ ] V1 不做 spam 防护 (silent 拒绝本身已是阻力)
- [ ] 老教练推荐码 V1 公测后开放,V1.5 准备

**关联**: [[prd|PRD]] §5 P0 #1 · [[evaluation-workflow#2 邀请码体系(3 类 code)]] · [[data-model#1.6 InviteCode (3 类 + 老教练推荐)]]

**优先级**: **P0** (Phase 1)

---

### US-C-003 — 接收队列查看新请求摘要

**As a** 教练
**I want** 在 接收队列 tab 看新学员请求摘要 (9 项)
**So that** 我能在 30s 内判断要不要接,不需要打开完整 onboarding 详情

**验收标准**:
- [ ] tab badge 显示 pending 数量
- [ ] 卡片摘要 9 项: 姓名/性别/年龄/体重 · 训练年限 · 三大项 1RM · 想增强肌群 · 训练环境 · 备赛日期 · 备注 · 资料计数 · 等待时长
- [ ] [查看完整资料] → 弹完整 onboarding (29 字段 + 视频 + 计划)
- [ ] [接收 ▼] / [拒绝] 按钮
- [ ] 已等待时长实时刷新

**关联**: [[prd|PRD]] §5 P0 #2 · [[evaluation-workflow#3.1 队列入口]] + [[evaluation-workflow#3.2 接收队列摘要字段(v1 spec)]] · [[coach-planning#§X.1 教练端主页结构]]

**优先级**: **P0** (Phase 1)

---

### US-C-004 — 接收 → 弹模态 2 选 1 (评估期 / 跳过)

**As a** 教练
**I want** 点 [接收] 后弹模态选 "进 7 天评估期" 或 "跳过评估期 (熟人)"
**So that** 陌生学员走严谨评估流程，熟人可直接 bind 进编排，不被产品强制 7 天

**验收标准**:
- [ ] 模态 2 选 1 + (跳过) 可选填 reason 文本
- [ ] 选 进评估期 → 创建 `evaluation_period` (`started_at = now`, `expected_end_at = now + 7d`)
- [ ] 选 跳过 → `bind_request.skip_evaluation = true` + 直接弹软推荐 "立即排首份计划?"
- [ ] 学员侧推送 "教练已接收"
- [ ] 评估期内教练在编排器 Step 1 不能选 "4 周" (系统拦截)

**关联**: [[prd|PRD]] §5 P0 #2 · [[evaluation-workflow#3.3 [接收] 按钮 — 弹模态 2 选 1]] · [[data-model#1.7 EvaluationPeriod + StudentEvaluation (评估期)]]

**优先级**: **P0** (Phase 1)

---

### US-C-005 — 拒绝学员 (silent 中性)

**As a** 教练
**I want** 点 [拒绝] 后无须填原因，学员收到中性 silent 推送
**So that** 我能高效清空不合适的请求，不被填表负担拖累 day-1 工作流

**验收标准**:
- [ ] [拒绝] 按钮 → 直接 `bind_request.status = 'rejected'`
- [ ] 教练侧无原因弹窗
- [ ] 学员侧推送中性文案 "教练当前不接收新学员,请输入新邀请码或继续浏览自己练模式"
- [ ] V1 无 spam 防护 (议题 V1 默认决定移除)

**关联**: [[prd|PRD]] §5 P0 #2 · [[evaluation-workflow#3.4 [拒绝] 按钮 — silent 中性]]

**优先级**: **P0** (Phase 1)

---

### US-C-006 — 评估期内看资料 + 留言

**As a** 教练 (评估期 7 天内)
**I want** 看学员上传的视频 (AVPlayer + 倍速) / 训练计划 / onboarding 数据 + 给学员发文字留言
**So that** 我能在不当面接触的情况下评估学员，且学员知道我在认真看

**验收标准**:
- [ ] 视频 player 支持 0.5x / 1x / 1.5x / 2x 倍速
- [ ] V1 不做 timestamp 评论 (V1.5 评估)
- [ ] V1 不做画线标注 (V2)
- [ ] 文字留言 → 学员侧立即可见 + APNs 推送
- [ ] V1 单条积累 (V1.5 多条积累 thread)

**关联**: [[prd|PRD]] §5 P0 #3 · [[evaluation-workflow#4.2 期内规则]]

**优先级**: **P0** (Phase 1)

---

### US-C-007 — 评估期发适应周 (系统拦截 4 周)

**As a** 教练 (评估期内)
**I want** 给学员发 1 周适应周训练 (轻量 / 技术为主)，系统拦截我发正式 4 周
**So that** 学员能熟悉 app 操作,我能观察学员训练日数据但不押重量

**验收标准**:
- [ ] 编排器 Step 1 在评估期内只能选 1 周, 不能选 4 周
- [ ] 系统拦截时显示提示 "评估期内仅可发适应周(1 周轻量计划)"
- [ ] 适应周训练写入 TrainingPlan (plan_weeks=1)
- [ ] 学员侧训练 tab 显示适应周训练卡片 [开始训练]

**关联**: [[prd|PRD]] §5 P0 #3 · [[evaluation-workflow#4.2 期内规则]] · [[coach-planning#Step 0: 选择学员]] (评估期内学员标记) · [[data-model#3.3 评估期约束]]

**优先级**: **P0** (Phase 1)

---

### US-C-008 — 填评估总结 3 字段 + 通知学员

**As a** 教练
**I want** 在"评估总结"页填 整体评估 + 训练规划 + 给学员的话(选填) 3 自由文本字段，首次保存自动通知学员
**So that** 学员知道我对他/她的判断，后续修改我可控制是否打扰

**验收标准**:
- [ ] 3 字段自由文本输入 (无星评 / 无 enum / 无水平等级)
- [ ] 整体评估 + 训练规划 必填,给学员的话 选填
- [ ] 首次保存 → 自动推送学员 + `notified_student = true`
- [ ] 后续修改 → 默认 silent + 复选 "通知学员" 勾选时才推
- [ ] 每次保存 → 写入 `student_evaluation_versions` 历史
- [ ] 教练随时可调整 (持久内容,不是临时文件)

**关联**: [[prd|PRD]] §5 P0 #3 + #8 · [[evaluation-workflow#5 评估总结(3 字段简化模板)]] · [[data-model#1.7 EvaluationPeriod + StudentEvaluation (评估期)]]

**优先级**: **P0** (Phase 1)

---

### US-C-009 — 软推荐衔接首份计划

**As a** 教练 (评估总结完成 OR 跳过评估期)
**I want** 系统弹 "立即排第一份计划 / 稍后"，点 立即排 跳到编排器 Step 0 (预填该学员)
**So that** 我不需要手动找学员再开排，产品流程顺畅引导我完成 day-1 闭环

**验收标准**:
- [ ] 评估总结 [完成 + 通知学员] 后弹软推荐 modal
- [ ] [立即排] → 跳编排器 Step 0,预填学员 1RM + 训练日 + 训练环境
- [ ] [稍后] → 退出 modal,教练自己后续主动排
- [ ] 跳过评估期场景 → 接收时直接弹软推荐

**关联**: [[prd|PRD]] §5 P0 #3 · [[evaluation-workflow#6 评估总结 → 首份正式计划(软推荐)]]

**优先级**: **P0** (Phase 1)

---

### US-C-010 — 编排 Step 0-2: 选学员 + 计划长度 + 复制上周 / 模板

**As a** 教练 (编排器入口)
**I want** Step 0 选学员 (按状态分组), Step 1 选 1 周/4 周, Step 2 SBD 频率分配 + [使用模板] / [复制上周] / [从零开始]
**So that** 复用上次工作 (复制上周) / 模板库 (跨学员复用)，不每次从零

**验收标准**:
- [ ] Step 0 学员列表按 评估期内 / 活跃 / 异常 三分组
- [ ] Step 1 1 周 / 4 周 选择 (评估期内学员只能选 1 周)
- [ ] Step 2 [复制上周] 1 周 + 4 周模式都可用,从最近一份给该学员的同周数计划加载 (动作 + 组数 + 次数 + 实际重量 + 4 周模式含规则)
- [ ] [使用模板] 自动按周数 + 训练天数过滤
- [ ] 模板库按 1 周 / 4 周 + 天/周 双层归档

**关联**: [[prd|PRD]] §5 P0 #4 · [[coach-planning|coach-planning v4.2]] Step 0-2 · [[coach-planning#模板归档(v4: 按 X 天/周 + 1/4 周 双层归档)]]

**优先级**: **P0** (Phase 1)

---

### US-C-011 — 编排 Step 4: 三标签筛选辅助动作

**As a** 教练
**I want** 添加辅助动作时按 肌群 (9) + 器械 (4) + 模式 (推 / 拉) 三标签任意组合 filter
**So that** 我能快速找到符合学员目标 + 器械 + 训练模式的动作，不被巨大动作库淹没

**验收标准**:
- [ ] 三标签独立 checkbox 多选 (肌群 9 / 器械 4 / 模式 2)
- [ ] 任意组合 filter (AND 逻辑)
- [ ] 匹配动作列表实时刷新 + 显示数量
- [ ] 每个动作可被多个 tag cover (动作的标签是 enum[] 多值)
- [ ] 教练自定义动作场景: 教练可添加私有动作 (`created_by_coach_id`)

**关联**: [[prd|PRD]] §5 P0 #4 · [[coach-planning#Step 4: 添加辅助动作 (v4.2 — 三标签并行筛选)]] · [[data-model#1.4 Exercise (动作库 + 三标签 facets)]]

**优先级**: **P0** (Phase 1)

---

### US-C-012 — 编排 Step 5-7: W1 必填 + 9 种递进规则 + Excel 预览

**As a** 教练 (4 周模式)
**I want** Step 5 W1 必填基线 → Step 6 设置 9 种递进/递减规则 (主项 + 辅助项同一套) → Step 7 规则应用周 + Excel 式 4 周预览，任意单元格点击直接修改
**So that** 减少手动填 W2-W4 重复劳动，且能在 Excel 视图直观调整任何细节

**验收标准**:
- [ ] Step 5 W1 必填,所有动作 组数 × 次数 × 强度 (重量 OR RPE)
- [ ] Step 6 9 种规则: 重量递增 / 递减 + RPE 递增 / 递减 + 组数递增 / 递减 + 次数递增 / 递减 + 自定义
- [ ] 一条规则可应用多个动作,一个动作可被多条规则覆盖 (冲突后写入优先 + UI 高亮)
- [ ] Step 7 规则应用周 (W2-W4 任意子集,可 [☑W2 ☑W3 □W4] 等组合)
- [ ] Excel 预览 4 列 (W1-W4) × N 行 (按训练日 + 动作), 点单元格直接修改
- [ ] 颜色规则: 绿色=W1 教练手填 / 灰色=规则递推 OR 同上周 / 白色=W2-W4 教练手动覆盖
- [ ] 未被任何规则覆盖的周默认 "同上周"

**关联**: [[prd|PRD]] §5 P0 #4 · [[coach-planning|coach-planning v4.2]] Step 5-7 · [[data-model#1.9 ProgressionRule + ExerciseWeekOverride (递进规则 v4 + 周覆盖 v4)]]

**优先级**: **P0** (Phase 1)

---

### US-C-013 — 编排 Step 9: 保存模板 (1 周 vs 4 周差异化)

**As a** 教练
**I want** 发布后选保存为模板，系统自动识别规则类型，按 1 周/4 周 + 天/周 双层归档
**So that** 给下个学员复用，不重复设计同一程序

**验收标准**:
- [ ] **1 周模板**: 存动作编排 + 组数 + 次数,不存递进规则
- [ ] **4 周模板**: 存动作编排 + 组数 + 次数 + 递进规则 (含应用周) + 自定义数值 (绝对重量自动转 %1RM)
- [ ] 系统识别规则类型 (RPE 递增 / 重量递增 / 组数递减 / 自定义 等)
- [ ] 命名 + 归档到 X 天/周 + 1/4 周 双层文件夹
- [ ] 模板套用新学员: 教练填 W1 重量 → W2-W4 按规则递推

**关联**: [[prd|PRD]] §5 P0 #4 · [[coach-planning|coach-planning v4.2]] Step 9 · [[data-model#1.11 WeekTemplate (教练模板系统)]]

**优先级**: **P0** (Phase 1)

---

### US-C-014 — Type A cascade 模态 3 选 1

**As a** 教练
**I want** 在学员详情页改 1RM / 训练日 / 训练环境 (Type A 锁定字段) 时，如果当前 cycle 进行中弹模态 3 选 1
**So that** 我控制改动如何影响学员当前 cycle，不会让计划基线和实际数据脱节

**验收标准**:
- [ ] 触发场景: 学员详情 → 学员信息卡片 / 训练日 / 训练环境 编辑保存
- [ ] 当前 cycle 不存在 → 直接保存
- [ ] 当前 cycle 进行中 → 弹模态 3 选 1
  - **① 重排 cycle** → 跳编排器 Step 1 加载 cycle + 调整 W2-W4
  - **② 不动** → 当前 cycle 按旧值,新值用于下个 cycle, 学员侧推送 "档案已更新但当前 cycle 仍按旧值"
  - **③ 提前结束 cycle** → 当前 cycle 终止于 W_n, 学员侧推送 "教练结束当前训练周期,等待新计划"

**关联**: [[prd|PRD]] §5 P0 #5 · [[coach-planning#§Y Type A 锁定字段 cascade 模态 (v4.1 新增 - office hours Gap #2 Q-2.3)]] · [[information-architecture#2.1 教练端 cascade 模态 (跨 tab 跳转)]]

**优先级**: **P0** (Phase 1)

---

### US-C-015 — Dashboard 学员状态面板

**As a** 教练
**I want** 在 Dashboard 看 学员卡片列表 / 本周完成度 / 待反馈视频数 / 异常学员预警
**So that** 我每天打开 app 第一眼知道哪些学员需要立即处理

**验收标准**:
- [ ] 学员按状态分组 (评估期内 / 活跃 / 异常)
- [ ] 评估期内学员有倒计时 (4 天 13 时剩)
- [ ] 异常学员标记: 3 天未训练 / 卡 W2 未完成 / 评估期超期
- [ ] 待反馈视频数显示 + 跳转入口
- [ ] 最后活跃时间显示

**关联**: [[prd|PRD]] §5 P0 #6 · [[coach-planning#Step 0: 选择学员]] · [[coach-planning#§X.1 教练端主页结构]]

**优先级**: **P0** (Phase 1)

---

### US-C-016 — 视频反馈队列 (per-set + 👍 OR 文本)

**As a** 教练
**I want** 在视频反馈队列按 时间 / 学员 / 紧急度 排序，每组视频 [▶ 播放] + [👍 没问题] 1-tap OR [文本反馈]
**So that** 我能在碎片时间快速处理大量视频，不被打字成本拖垮

**验收标准**:
- [ ] 队列项显示: 学员 / 训练日 / 动作 / 第 N 组 / 重量 × 次数 × RPE / 视频时长 / 上传时间
- [ ] [▶ 播放] AVPlayer + 倍速
- [ ] [👍 没问题] 1-tap → CoachFeedback (`feedback_type = 'thumbs_up'`) + 推送学员
- [ ] [文本反馈] 弹文本框 → CoachFeedback (`feedback_type = 'text'`, `text_content`)
- [ ] V1 不含 5-10 预设按钮 (议题 8 简化决议)
- [ ] 排序选项: 时间 / 学员 / 紧急度

**关联**: [[prd|PRD]] §5 P0 #7 · [[coach-planning#§β 视频反馈队列 (v4.2 新增 - 议题 7 + 议题 8 决议)]] · [[data-model#1.13 CoachFeedback (议题 8 简化版)]]

**优先级**: **P0** (Phase 1)

---

### US-C-017 — 学员详情页 (e1RM + 评估总结编辑)

**As a** 教练
**I want** 单个学员详情页看 onboarding 完整 / 当前 cycle / 历史训练 / 三大项 e1RM 折线 / 视频历史 / 评估总结编辑入口
**So that** 我对学员有 360° 视图，且可以随时调整评估总结

**验收标准**:
- [ ] onboarding 完整 (29 字段 + 视频 + 计划)
- [ ] 当前 cycle (W1-W4 概览, 跳到编排器修改)
- [ ] 历史训练记录 (按周 / 月)
- [ ] 三大项 e1RM 折线 (教练只看, 不被 PR 推送, 仅推学员)
- [ ] 视频历史
- [ ] 评估总结编辑入口 (随时改 + 复选 通知学员)
- [ ] [解绑学员] 按钮 (弹确认)

**关联**: [[prd|PRD]] §5 P0 #8 · [[coach-planning#§α e1RM 计算 (v4.2 新增 - 议题 1 决议)]] §α.2 教练侧 · [[evaluation-workflow#5.5 评估总结 = 学员信息卡片永久内容]]

**优先级**: **P0** (Phase 1)

---

### US-C-018 — 解绑学员 (单方)

**As a** 教练
**I want** 在学员详情页 [解绑学员]，无需对方同意
**So that** 学员长期失联 / 不付费 / 不合适场景能清理 roster

**验收标准**:
- [ ] [解绑学员] 弹确认 modal "确认解除与该学员的绑定关系?"
- [ ] 确认后 bind 关系终止 + 当前 cycle 标记 'paused'
- [ ] 教练 roster 移除该学员
- [ ] 学员侧推送 "教练解除了与你的绑定"
- [ ] 学员历史训练数据保留

**关联**: [[prd|PRD]] §5 P0 #1 · [[data-model#1.5 BindRequest (学员绑定教练请求队列)]]

**优先级**: **P0** (Phase 1)

---

### US-C-019 — 收到学员事件推送

**As a** 教练
**I want** 学员训练完成 / 视频上传 / 主动发问 / 加新伤病 / 恢复评估更新 / 绑定请求时收到推送
**So that** 我不漏接学员事件，能及时反馈

**验收标准**:
- [ ] 触发事件: 视频上传完成 / 训练完成 / 学员主动发问 / 学员加新伤病 / 恢复评估更新 / 新绑定请求
- [ ] APNs 推送 SLA ≤ 30s (90 分位)
- [ ] 推送点击 → 跳到对应页面 (如 视频上传 → 视频反馈队列, 新绑定请求 → 接收队列)
- [ ] 系统 → 教练 reminder: 48h 待响应未处理 / 评估期超期 36h / 老教练推荐 bonus 解锁

**关联**: [[prd|PRD]] §5 P0 #26 · [[decisions/004-backend-selection|ADR 004]] §3 推送 SLA

**优先级**: **P0** (Phase 1)

---

### US-C-020 — 教练订阅 (按学员数 IAP)

**As a** 教练
**I want** "我的" → 订阅页 按学员数订阅 (含试用期)
**So that** 教练学员越多付费越多，产品有 ARR

**验收标准**:
- [ ] 订阅按学员数分档 (具体定价 V1 启动前定, 详见 [[prd|PRD]] §8.3 IAP 待定)
- [ ] 试用期管理
- [ ] IAP 走 Apple §4.8 合规
- [ ] 学员数超过订阅档 → 推送提醒升级
- [ ] 订阅过期 → 教练端切只读模式或提示重新订阅 (具体行为 V1 启动前定)

**关联**: [[prd|PRD]] §5 P0 #27 · §8.3 IAP

**优先级**: **P0** (Phase 1, 定价待 office hours 决议)

---

## 优先级汇总

| 优先级 | 学员侧 | 教练侧 | 总计 |
|---|---|---|---|
| **P0 (Phase 1, B2B)** | US-S-001 ~ US-S-017 (17 条) | US-C-001 ~ US-C-020 (20 条) | 37 条 |
| **P0 (Phase 2, B2C)** | US-S-018 ~ US-S-021 (4 条) | — | 4 条 |
| **总 P0** | 21 条 | 20 条 | **41 条** |

---

## 覆盖矩阵 (PRD §5 P0 → US 映射)

| PRD §5 P0 # | 功能 | US |
|---|---|---|
| #1 | 学员管理 + 邀请码 + 解绑 | US-C-002 + US-C-018 + US-S-017 |
| #2 | 接收队列 | US-C-003 + US-C-004 + US-C-005 |
| #3 | 评估期工作流 | US-C-006 + US-C-007 + US-C-008 + US-C-009 |
| #4 | 计划编排 | US-C-010 + US-C-011 + US-C-012 + US-C-013 |
| #5 | Type A cascade 模态 | US-C-014 |
| #6 | 学员状态面板 | US-C-015 |
| #7 | 视频反馈队列 | US-C-016 |
| #8 | 学员详情页 | US-C-017 |
| #9 | 待接收状态 | US-S-006 (前置依赖 US-S-003 onboarding + US-S-005 输码) |
| #10 | 评估期状态 | US-S-007 |
| #11 | 评估总结 | US-S-008 |
| #12 | 接收计划 | US-S-009 |
| #13 | 训练记录 | US-S-010 |
| #14 | 视频上传 | US-S-004 (onboarding) + US-S-011 (训练日) |
| #15 | 训练历史 | US-S-012 |
| #16 | e1RM + PR 推送 | US-S-013 |
| #17 | 教练反馈 | US-S-014 |
| #18 | 我的资料 4 级 | US-S-015 |
| #19 | mode 切换 | US-S-002 |
| #20 | 自己练 onboarding | US-S-018 |
| #21 | 训练计划生成 | US-S-019 |
| #22 | 自己练训练执行 | US-S-020 |
| #23 | B2C 订阅 | US-S-021 |
| #24 | 账号体系 单角色 | US-S-001 + US-C-001 |
| #25 | 绑定关系 | US-S-005 |
| #26 | 推送通知 | US-S-016 + US-C-019 |
| #27 | 订阅入口 (教练) | US-C-020 |

---

## V1.5+ Deferred / Reference Only

以下场景 V1 不实施，触发条件满足后再实施。仅作为产品愿景留底。

| 假设场景 | 触发条件 | 来源 |
|---|---|---|
| 多角色单用户 (教练启用学员副身份) | B2B Stage 5-6 公测稳定后, 实际用户反馈 ≥ 5 人 | [[decisions/003-dual-end-native-architecture\|ADR 003 v4]] · [[decisions/005-ios-architecture\|ADR 005]] §5 |
| 学员 mode toggle (有教练 → 自己练) | V1 实测教练流失场景 ≥ 3 例 | [[decisions/005-ios-architecture\|ADR 005]] §5 |
| 教练端跨学员模板批量下发 | V1 公测后教练实际请求 | [[prd\|PRD]] §5 P1 |
| 教练端反馈预设语 (5-10 快捷按钮) | V1 公测后教练打字成本反馈 | [[prd\|PRD]] §5 P1 |
| 教练语音反馈 | V1 公测后实际使用强需求 | [[prd\|PRD]] §5 P1 |
| 视频 highlight / timestamp 评论 | V1 公测后实际使用强需求 | [[coach-planning\|coach-planning v4.2]] §β · [[evaluation-workflow#4.2 期内规则]] |
| 微信登录 | Apple §4.8 合规 + WeChat OpenSDK 集成研究 | [[prd\|PRD]] §5 P1 · [[decisions/005-ios-architecture\|ADR 005]] §5 |
| Marketplace 教练撮合 | V3 (V2 后 6-12 月) | [[prd\|PRD]] §5 P3 |
| 比赛 / Meet 追踪 | V2 | [[prd\|PRD]] §5 P2 |
| AutoPlanDomain 算法替代模板 | Stage 3-4 边界 30 自己练 user test | [[decisions/005-ios-architecture\|ADR 005]] §5 |

---

## 待解决 (V1 启动前定)

- [ ] B2C 试用期具体天数 (7 / 10 / 14 中选一, US-S-021)
- [ ] 教练订阅按学员数分档定价 (US-C-020, 详见 [[prd|PRD]] §8.3 IAP 待定)
- [ ] 评估期状态 D (等待首份计划) 超时具体逻辑 (评估完后 7 天教练没排首份计划, 学员看到什么)
- [ ] e1RM RPE table 嵌入 app 还是服务端配置 (US-S-013, [[data-model]] §5 待解决)
- [ ] 教练改 cycle 计划 detailed diff (US-S-016, V1 不做但 V1.5 可能要)
- [ ] 学员"我的教练"联系入口 (V1 微信 deep link 还是内置) - 影响 US-S-017 解绑触发场景

---

## 来源

- [[prd|PRD v0.7]] §5 功能清单 P0 (27 项, US 全覆盖)
- [[student-onboarding|学员端 Onboarding v2.4]] 7 步 + §A/§B/§C/§D/§F
- [[coach-planning|教练端编排架构 v4.2]] Step 0-9 + §X/§Y/§Z + §α/§β
- [[evaluation-workflow|评估期工作流 v1.1]] §1-§7
- [[information-architecture|MeetPR 信息架构 v1]] (姊妹文档,每条 US 对应 IA 中的 page / state)
- [[data-model|数据模型 v1.1]]
- [[decisions/003-dual-end-native-architecture|ADR 003 v4]] V1 单角色锁死
- [[decisions/004-backend-selection|ADR 004]] 推送 SLA ≤ 30s
- [[decisions/005-ios-architecture|ADR 005]] 模块切分 + Phase 演进
- [[product-decisions/004-b2c-v1-template-based|PD-004]] B2C V1 = 模板版
