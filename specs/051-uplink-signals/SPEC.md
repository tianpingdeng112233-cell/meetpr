# SPEC 051 — 上行信号:接住学员写下的东西(走查 P0-3/P0-7/P1-4;P1-3 已存在仅验证)

- **状态**: Accepted(2026-07-04,与实现同 PR)
- **来源**: 自己练 Free 档 wave 泳道 B;走查报告「收集但丢弃比不收集更伤信任」。后端半 = backend spec 012(session_reviews)。
- **侦察修正(2026-07-04)**:P1-3 反馈已读回执学员侧**已实现**(FeedbackInboxView 上屏即 `markRead`,后端 read_at 落库)——本 spec 仅加一条回归断言并在走查台账记"已存在,教练侧显示归教练 wave";P1-4 的"填后回显"已有(工具栏心形 filled 态),缺的只是**动机文案**。

## 1. 训练回顾:三问收敛为一句话 + 持久化(P0-3)

- 走查建议采纳:SessionSummaryView 的三条自由反思**收敛为一条**「一句话感受」+ 可选整场 RPE(0-10 步进 0.5);减输入负担,能坚持写才有价值。
- 提交走 `SessionReviewRepository`(新协议,Backend 实现打 `PUT /students/:id/reviews/:date`,date=会话日与 set_logs.logged_date 同口径;InMemory 同步实现)。
- **学员自看**:成长 tab 历史(TrainingHistory 的日详情)展示当日回顾(实现:TrainingHistoryViewModel.reviewsByDay 按日索引,HistoryEntriesView 日头下一行「感受」·整场 RPE;取失败只隐藏该行不打翻历史页);coached 文案标注「教练会看到」,**solo 文案「记录你的状态,曲线之外的另一半」**(solo 没教练,不撒谎)。
- 断网:V1 直接失败提示重试(回顾非训练组,不入重发队列;若走查复检仍痛再升级)。

## 2. 深链与 PR 红点(P0-7)

- 通知面板各项落点核对(2026-07-04 实施期核实):**三条路由在 5-tab IA 下均已正确**——计划通知→训练 tab(计划的唯一住所,无独立计划页)+ markCurrentPlanSeen 清红点、反馈→成长 tab 反馈区、评估→总结页;走查时的偏航已被 1:1 改版(#180)+U6 今日 tab 分叉修复吸收,本 spec 无需改路由。
- **PR 红点消费面**:我的 tab 徽标现计 pendingPRCount 但无处查看/确认——成长 tab 增「未确认 PR」小节(列表:动作/数值/日期 + 逐条确认=ack),确认后徽标即刻减(tab 切换重数);PRBanner 既有即时流不变。

## 3. 问卷动机文案(P1-4)

- ReadinessCheckinSheet 顶部一句(coached):「教练会据此调整你的计划」。回显已有(心形 filled),不动。
- solo 版文案条款作废(2026-07-04 核实):solo 模式没有 readiness 入口——今日状态问卷长在 coached TodayWorkoutView 工具栏,SoloTodayView 不含。solo 疲劳自评是否值得做记 FOLLOWUPS F-030 族,不在本 spec。

## 非目标

教练端消费(回顾/回执/问卷的教练侧展示与推送)→ 教练 wave;通知系统重构不做,仅修落点。

## 测试

- SessionReview:VM 提交/覆盖/空输入禁提交;repo 双实现;历史回显。
- PR 消费:ack 后 unacknowledged 列表与徽标同步减(InMemoryE1RM)。
- 回归:FeedbackInbox markRead 断言(P1-3 已存在行为钉死);readiness 心形回显不回退。

## 验收

1. 写一句话感受 → 杀 app → 历史里仍在(staging 真机)。
2. 未确认 PR 在成长 tab 可见可确认,徽标同步。
3. solo 全程无「教练」字样;coached 采集点有动机文案。
