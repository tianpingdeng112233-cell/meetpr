# 110 — 周期接续规则与入口方案

## 接手

- David 反馈上周期未走完、下一计划已覆盖学员入口。三张用户截图显示旧计划 10/19 起、5 周（11/16 为 W5），新计划 11/23 起、12 周，学员已显示新计划 W1。
- 已读取 memory INDEX / iOS41 发布指针、工程闭环、iOS / backend 仓规、CONTEXT、FOLLOWUPS 触发条件以及 071 / backend 035 / 107；原 checkout 有既有修改，仅只读核查。
- iOS 已核实发布标签内容 `84bd30b0`；刷新远端后 `origin/release/1.0=f123cc96`。新托管工作树 `/Users/david/.codex/worktrees/plan-handoff/MeetPR`，分支 `docs/110-plan-handoff`。backend 远端 `origin/staging=42194b1`，本次不修改。

## 判断与授权

- 已发现旧 spec 与现有 iOS 选计划代码一致：最大 publishedAt 优先，不检查上一周期完成度。这是已有产品规则与本次真实使用需求冲突，尚未进行端到端复现或读取反馈账号数据库，不能报告数据恢复 / bug 已修复。
- David 曾在选项中选择“保留发布即切换，增加旧计划切回入口”，随后明确改为“旧计划练完自动接新计划，同时保留主动提前切换入口”。后一条为准，已进入 110 核心规则。
- 使用 diagnosing-bugs 查入口后在产品规则边界转入 grill；未把未确认新规则伪装成 bug 修复。Impeccable context 已读取，现有 107 / 设计 token 为视觉权威，未因缺 PRODUCT.md 另起产品访谈。
- 110 是待审结构稿，新增入口、存量首次显式选择及细化边界仍为提案。shape 要求结构稿确认后再实施；没有应用代码、迁移、线上数据修改。

## 本轮产出与验证

- 110 SPEC：确认规则、入口结构、升级 / 离线 / 并发 / 旧包兼容、测试 seam、A–L 验收与 Out of Scope；实装按 backend / iOS / Android 每仓一卡。
- 校验本次 Markdown 相对链接、关键验收段、diff whitespace；纯文档变更未运行 Swift / 原生 UI 测试。CI workflow 对 Markdown 与 specs 路径跳过，不能写成 CI 通过。
- 待 David 审入口布局与存量处理后固定跨端契约、写实装卡，开始先红后绿和独立验收。

## 网页影响补查

- David 追问“网页端是否需要更改”。只读核查 web worktree / status / log / CLAUDE / CONTEXT；`0c59fba` 为已记录部署的代码，`origin/main=fa0ff54`，后者为该部署记录的合并。
- `PlanWorkspace.tsx` 的 `fetchRosterWeekTonnage` 按 updated_at 选 published 计划，`activePublishedPlanId` 取第一份 published，确实与新选择语义冲突；编辑器另有自己的记忆计划与切换入口，两者应保持区分。
- 修正前稿遗漏：增加 web 状态 / 游标 / 发布结果文案的适配范围、公开组件测试 seam、验收 M；四仓每仓一卡。文案与状态显示仍为提案，没有修改网页代码或部署。既有教练关注规则不擅自改写。

## 接管与定稿（Claude 会话，同日）

- David 在 Claude 会话问「你这边为什么不可以推进」，110 由该会话接管；接管时 Codex 托管树 `plan-handoff` 干净、无未推送提交。
- 按 David 当日裁定重写 SPEC：撤回切换入口、存量首次选择、服务端指针；新增日期重叠拦截、只读翻看下一份、「正在练」服务端推导规则（David 确认「可以」）。`AMENDMENT-2026-11-16.md` 已并入并删除。
- 现网：backend #412 垫片在国内 staging `ef17157`，反馈学员确认本周计划恢复（David 转述）。110 后端卡以「隐藏 published_at 晚于正在练那份的计划」取代按日期过滤，使旧包也按接续规则走。
- 下一步：后端卡即派；学员端屏幕稿待「定稿」后派 iOS / Android / web 三卡。
