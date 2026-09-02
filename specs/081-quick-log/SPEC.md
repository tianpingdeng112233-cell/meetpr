# spec 081 — 学员端补记(quick-log):练完忘开 app,一次按处方录完并结算

- **状态**:Ready(2026-09-02 grill 六轮拍板完毕,David 确认共识;屏幕稿待出)
- **级别/节奏**:T2;P1,目标 1.0(22) 班车。
- **范围**:纯 iOS 学员端(StudentKit + Networking DTO 一字段);**零 backend 改动**
  (`POST /sets/log` coached 体已接受可选 `logged_date`,完成接口无 body 幂等)。教练端不动。
- **词汇**:先读仓根 `CONTEXT.md`。**补记(quick-log)** = 学员练完没开 app,事后在游标日
  未开始态汇总卡上按处方一次性录入当天全部组并结算完成。_Avoid_:补练(已作废 061)、
  一键完成、跳过。
- **上游拍板继承**:spec 071 推进制全部口径不动——只有游标日可写;完成 = 学员显式长按结算;
  iOS 端**没有 0 组完成、没有「跳过这天」、不做乱序**;撤销只撤最近一天且仅当天。

## 问题(为什么做)

学员在健身房练完但没打开 app,现在只能回头一组一组走 `SetEntrySheet`(重量/次数/RPE/视频
四段,每组 3–4 次点击),一天 10–20 组要点上百次,结果是干脆不记 → 游标停住、教练端看不到、
e1RM 断档。推进制下「今天没练」的正确状态是游标停留,但「练了没记」需要一条低摩擦回填路。

## 方案概览

游标日处于**未开始态**(0 组记录,汇总卡「今日训练」+「开始第一组」)时,汇总卡上多一个
次级入口「练完了?补记今天」。进入补记 sheet:顶部选「练的日期」,下面按动作列出处方
(组×次×重量/RPE,走现有换算链预填),默认全部「按处方完成」;每个动作可改顶组重量/RPE、
减组数、或整体勾「没做」。底部长按「补记并完成今日训练」→ 逐组写记录 → 调完成接口 →
游标推进 → 回到训练 tab(汇总卡已切到下一节)+ 一行 toast「W#D# 已补记」。连补多天靠
游标串联(下一节仍是 0 组 → 汇总卡 → 入口又在),不提供多天批量 sheet。

## UI(结构与文案正典;像素与布局以 `docs/design/quick-log/` 屏幕稿为准,稿待 David 拍板)

### 入口(训练 tab · 汇总卡)
- 位置:`listHero` 内,`GoldCTA`「开始第一组」**下方**,次级样式(文字按钮或描边胶囊,
  不与主 CTA 抢视觉),文案「练完了?补记今天」。
- 可见条件 = `heroMode == .list && isEditable`(即游标日 + 0 组)。记录态、已完成日、未来日、
  无计划态一律不出现。首页今日卡**不加**入口(⚖️Q9 A)。

### 补记 sheet(`fullScreenCover`,与 `SetEntrySheet` 同容器)
1. 导航:左「返回」;标题「补记 · W#D#」;副标日名(如「硬拉日」)。
2. **练的日期**行:`DatePicker`(`.date`,compact),默认今天;可选区间 =
   `[上一已完成日的 loggedDate(无则计划 publishedAt 当日), 今天]`;显示格式沿用「9/1 周二」。
3. 动作列表(按 `sequenceIndex`),**一组一行**(⚖️09-02 David 改口径:步进式太慢):每个动作一张卡——
   - 头:序号胶囊 + 动作名 + 处方摘要「140kg × 5 · RPE 8」+ 右侧「N / M 记」计数;
   - 卡内就是组表,列与现有记录态组表一致(`#` / 重量 / 次数 / RPE),最右一列「记」勾选圈
     (默认全勾 = 按处方完成)。三格数值**复用** `makeDrafts` 产出的
     `SetRowDraft.actualWeight/actualReps/actualRPE`(六形态与 % 三锚预填,不另写解码);
     RPE/% 形式的换算重量弱色 + 「自动」角标(沿用 034 §9.4 预填样式)。
   - 点格子 → 底部升起 `MeetPRNumberPad`(复用 `SetEntrySheet` 的数字键盘),格子金色高亮;
     键盘上方两个快捷:「同步到全部 N 组」(改一格全组同值)与「下一格 →」
     (重量→次数→RPE→下一行);「完成」收起。
   - 勾掉一行 = 这组不记(尾组勾掉即少做,行灰化划线);整个动作全勾掉 = 没做,卡折叠成
     一行灰字「0 / M · 没做」,点击可展开恢复。不做逐组失败标记(想标失败走记录卡)。
4. 底部常驻:剩余摘要「将记录 N 个动作 · M 组」+ **长按按钮**「长按 · 补记并完成今日训练」
   (复用 `HoldToCompleteButton` 与 `HoldToCompleteGestureState`,进度填充/触觉/回弹一致)。
   当所有动作都勾「没做」时按钮不可用(= 0 组,071 红线),摘要改「至少要有一个动作」。
5. 提交中:按钮转 loading、sheet 不可关闭(`interactiveDismissDisabled`);逐组顺序 POST
   (与 `performPersist` 同一条路:`makeLog` → `logs.recordSet` → `E1RMRecorder`),
   全部成功后调 `plans.completeDay`。
6. 失败:某组失败即停,弹现有风格 alert「有 K 组没有保存,已保存的 J 组不会丢失,请重试」,
   留在 sheet;重试从失败组继续(后端按 `(student, planExerciseId, setIndex)` upsert 幂等,重发
   已成功的组也无害)。完成接口失败:组已全部写入,alert「记录已保存,但没有完成今天训练,
   请重试」,重试只调完成接口。
7. 成功:关闭 sheet,**不走** `WorkoutCompletionFlowView`(庆祝/回顾)(⚖️Q8 A);训练 tab
   回到汇总卡(游标已是下一节)并出 toast「W#D# 已补记」(2 s;仓内没有共享 toast 组件,
   做最简 capsule 放 DesignSystem,黑底金字,顶部安全区下滑入)。

### 不出现的东西
视频、备注、逐组失败标记、教练备注编辑、休息计时器、PR 弹窗(现无,不捞)。

## 数据面(硬约束)

- **日期**:`CreateSetLogRequestDTO` 增 `loggedDate: String?`(`YYYY-MM-DD`,`nil` 时不编码
  该键——普通记录路径行为零变化;编码键名 `loggedDate` 走既有 snake-case 转换 → `logged_date`)。
  补记路径:`StudentSetLog.loggedAt` = 所选日期当地 12:00(避开 04:00 gym-day 边界,iOS 归日与
  服务端 `trainingDay(timezone)` 一致),`loggedDate` = 同一日期字符串。**`E1RMRecorder` 的
  `now` 亦取该时刻**(e1RM 点与 PR 事件落在练的那天,不落提交日)。
- **完成**:`POST /plans/days/:dayId/complete`,与长按结算共用 `completeCurrentDay()`
  (含 `isCompletionMutationInFlight` 防重与 `applyCompletionMutation` 缓存对账)。
- **e1RM / PR**(⚖️Q5 A):补记的组与正常记录同等——`assumed: false`,过同一套
  `E1RMEligibility` 与异常门,生成 PR 事件进现有被动面(回顾页/首页头条/周 PR 计数)。
- **缓存**:成功后按 071 现有链路刷新 plan projection(`completedAt`)与 logs;补记写的组
  在下次 `fetchLogs(scope=plan)` 全周期窗口内可见(按 `logged_date` 落窗)。
- **在线要求**:无离线队列(仓内本就没有),也不做联网预检;断网时走上面第 6 条的失败
  alert,已写的组不丢,重试即可。

## 架构约束

1. **复用不复制**:预填 = `TodayWorkoutViewModel.makeDrafts(for:existingLogs:onboardingProfile:)`;
   写组 = 现有 `makeLog` + `logs.recordSet` + `E1RMRecorder` 路径,**禁止**新起一条绕过 e1RM
   钩子的写路;结算 = `completeCurrentDay()`。
2. 新增纯逻辑 `QuickLogPlan`(CoreModels 或 StudentKit/Features/QuickLog):输入
   `[SetRowDraft]` + 逐组编辑(`included: Bool` + 可覆盖的 weight/reps/rpe)+ 「同步到全部」
   展开规则 + 所选日期 → 输出待写 `[StudentSetLog]`(有序,仅 `included`)。这是可单测的核心,
   UI 只是它的编辑器。
3. VM 新增 `quickLog(plan: QuickLogPlan) async -> QuickLogOutcome`
   (`.completed / .partialFailure(writtenCount:failedIndex:) / .completionFailed`),
   内部串行写组、成功后 `completeCurrentDay()`;`recordingGeneration` 与现有并发防护共用。
4. i18n:新字符串全部进 `StudentStrings` + `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
   中英双语;不硬编码中文。
5. Demo(InMemory)同语义:`InMemoryStudentTrainingLogRepository` / `InMemoryStudentPlanRepository`
   走同一 VM 路径,DemoStudent 构建档可走查「补记 W1D3 → 汇总卡切 W1D4 → 再补」。
6. 不改 `TodayWorkoutPresentation.allowsManualCompletion` 语义;新增 `allowsQuickLog`
   (`heroMode == .list && isEditable`),由 Screen 消费。

## 测试 seam(先红后绿;优先最高层、最少)

1. **VM 级(主 seam,复用 `TodayWorkoutPRHookTests` 的 `makeLoadedViewModel` 构法:
   InMemory plans/logs/e1rm + 冻结时钟)**——`TodayWorkoutQuickLogTests`:
   - 全按处方补记 → logs 仓里组数 = 处方总组数、`assumed == false`、`loggedAt` 为所选日 12:00、
     plan day `completedAt != nil`、e1RM 仓有点;
   - 一个动作全部勾掉(没做)+ 另一动作勾掉尾组 → 只写勾选的组,`setIndex` 保持处方序号;
   - 全部「没做」→ 拒绝(不写、不结算);
   - 第 k 组 `recordSet` 抛错(用会失败的 fake logs 仓)→ 前 k-1 组已写、未调完成、outcome
     `.partialFailure`;重试从 k 继续、最终结算;
   - 完成接口抛 `PLAN_NOT_ACTIVE` → 组已写、outcome `.completionFailed`。
2. **纯逻辑**——`QuickLogPlanTests`:编辑→输出组序列的映射(单格改值、「同步到全部」
   展开、勾掉行不输出、日期→`loggedAt`/`loggedDate` 派生、区间夹逼)。
3. **DTO 契约**——`SetLogDTOTests`(Networking):`loggedDate == nil` 不出现 `logged_date` 键;
   非 nil 时编码为 `"logged_date":"2026-09-01"`。
4. **Presentation**——`TodayWorkoutPresentationTests` 追加:`allowsQuickLog` 仅在
   `.list && isEditable` 为真;已完成日/未来日/记录态为假。

UI 层(sheet/长按/toast)不写 UI 测试,靠 DemoStudent 模拟器走查 + 收货截图。

## 验收标准

- DemoStudent:W1D3 0 组 → 汇总卡见入口 → 补记(改硬拉顶组 180、RPE 9,做 2 组)→ 长按 →
  回训练 tab 见 toast、汇总卡为 W1D4、计划汇总 D3 打勾、D3 详情组表 2 行 180×3@9;
  首页 e1RM 头条更新;再补 W1D4 可连做。
- 真后端(staging 测试号):同上,且 `GET /students/:id/sets` 里该组 `logged_date` = 所选日、
  `plan_day_completions` 出现 manual 行;次日「撤销完成」不可用(仅当天)、当天可撤且撤后
  组记录仍在、汇总卡回到记录态(≥1 组 → 不再是未开始态,入口消失,符合 071)。
- 普通记录路径零回归:`SetEntrySheet` 请求体不含 `logged_date`;现有 StudentKit/Networking
  测试全绿。
- 老用户升级第一屏:无补记历史的账号打开训练 tab,与升级前唯一差别是汇总卡多一行次级入口。

## Out of Scope(防蔓延)

- 首页今日卡入口(Q9);记录态「剩余组按处方补齐」;多天批量 sheet;乱序补未来日;
- 逐组失败/视频/备注;PR 弹窗捞回;离线队列;
- 「撤销本次补记」批量回退(沿用 071 只撤最近一天);
- backend 任何改动(含批量写组端点——逐组 POST 本波接受,10–20 组量级);
- 教练端「补记」标识/分诊变化(补记的组与正常组在教练端无区别,W2 分诊重定义时再议)。

## 拍板记录(David 2026-09-02)

1A 按处方一键预填、可改;2A 补记确认即结算(长按);3A 仅未开始态汇总卡;
4 想补几天就几天 → 靠游标串联;5A e1RM/PR 与正常同等;6A 每动作可「没做」+ 减组数;
7A 补记带「练的日期」写 `logged_date`;8A 不走庆祝/回顾,toast 回汇总卡;9A 首页不加入口;
10A 撤销沿用 071。术语「补记」入 `CONTEXT.md`。
