# spec 071 — 训练日推进制(iOS 学员端)

- **状态**:InReview(实现与本地验证完成,待 Claude review)
- **对应 backend spec**:`035-sequence-progression`(wire 契约权威;本 spec 消费)
- **取代**:`061-catch-up-shift`(spec PR #275 已作废关闭)。**父辈系谱**:054 整体顺延 V2
  的学员端 UI 随本 spec 下线——不是修补它,是拆掉它锚定的地基。

## 问题(为什么做)

学员训练日频繁受现实干扰,提前/延后是常态。日期锚定制下这是一串死局:过了日期的天
变只读、漏课永久欠账、顺延只能救「今天」。David 2026-08-07 拍板换制为**推进制**:
学员按 W1D1 → W1D2 → … 顺序推进,练完一天,下一次打开 app 就是下一天;教练排期降级
为「推荐日期」纯展示;顺延 UI 整体下线。「补上上周没练完的」不再需要任何功能——
游标停在哪就从哪继续,这就是默认行为。

## 语义正典(与 035 逐字对齐)

- **游标日** = 当前计划内按 `(weekNumber, dayOfWeek, sortOrder, id)` 升序的第一个
  `completedAt == nil` 的训练日。判定规则唯一权威 = 035 §术语与排序正典,iOS 实现
  注释必须指回,严禁本地变体。
- **当前计划**(拍板 5)= published 计划中 `published_at` 最大者(tie 依 `created_at`、`id`)。
  新计划发布即翻篇,旧计划残留不再影响游标。
- **推荐日期** = 现行位置式投影 `scheduledDate`(`BackendStudentPlanRepository` 已有),
  **不再叠加 `shiftedToDate` 覆盖**(拍板 2:忠实教练原排期)。纯展示,零调度语义。
- **完成**(拍板 1)= 服务端 completion 记录(auto:处方组全记 / manual:显式结束 /
  backfill:教练导入历史)。客户端不自造派生完成态当调度依据——`TrainingDayProgress`
  从 logs 反推的口径仅继续用于展示(打勾/进度),游标只认 `completedAt`。

## 数据面

- DTO/模型:`PlanDay` 及投影链追加 `completedAt: Date?`、`completionSource: String?`;
  计划模型追加 `publishedAt: Date?`。
- **缓存防线**(061 的 legacy-cache gotcha 直接继承):计划缓存 projection schema 版本
  bump——pre-071 缓存缺新字段,cache-first 的 `fetchCurrentPlan` 会拿旧 projection 把
  游标算错;旧版本缓存直接失效重拉,不靠字段猜。
- logs 拉取范围:现行「当周日期窗口」失去锚点,改为**按当前计划全周期一次拉取**
  (沿 061 §检测 已论证的方案:仍是一次请求、`scope=plan`、范围=全周期推荐日期 pad 1 天;
  不用 `scope=all`,adhoc 行与非可选 DTO 不兼容)。完成态本身来自 `completedAt` 字段,
  logs 只服务于组级展示与「还有 N 组未记录」文案。

## 学员端行为

### Dashboard 今日卡

- 主态 = **游标日卡**:标题「W2 · D3」+ 日名/动作摘要,副标「教练推荐 8月5日」
  (推荐日期已过/未到都照实显示,不标红不催促——拍板 2 的语义就是「参考」)。
- CTA「开始训练」交棒游标日(替换现行 `TodayWorkoutPlanHandoff(date: Date())` 的
  日期交棒为 dayID 交棒)。
- 完成一天后(同 gym-day 内):卡片切「今日已完成 ✓」态,显示下一节预览
  「下一节 · W2D4」,主 CTA 降级为次级入口「继续下一节」——不做同日多节硬门。
- 全周期完成:进入周期完成态(现行 `isAwaitingNextPlan` 判定从「planEndDate vs now」
  改为「全部训练日已完成 或 存在更新的 published 计划」)。
- **周历条重做**:`DashboardWeekCalendar` 的 7 格日期条换成**当前周序列进度条**
  (D1…Dn 各格:✓ 完成 / ● 游标 / ○ 未到),格子身份 = 序数,不再按日期反查。
  `weekCode` / `progressSegments` 数据源同步换序数(顺带消灭「过去日一律算完成」的
  旧口径不一致)。

### 训练 tab

- 选中态从 `selectedDate: Date` 改为 `selectedDayID`;`TodayWorkoutSelectionResolver`
  的 initial/jumpToToday 返回游标日 ID,逻辑形状不变。
- **周/月日历换序列视图**:`TrainingCalendarView` + `TrainingCalendarLogic` 的日历网格
  整体替换为**按周分组的训练日列表**(每行:W#D# / 日名摘要 / 完成✓ / 推荐日期灰字)。
  `.missed` 红点态删除——推进制无漏课。这是本 spec 最大一块 UI 重做。
- **可编辑性**:`isEditable` 从「选中日 == 今天(WorkoutDatePolicy)」改为
  「选中日 == 游标日」。已完成日 → 只读横幅「已完成 · 不可修改」+ 当天(gym-day)内
  显示「撤销完成」入口;未来日 → 「未轮到 · 仅预览」。
- **WorkoutDatePolicy 保留但降级**:不再回答「今天是不是这个计划日」,只继续负责
  日志时间戳的 gym-day 归桶(`dayRange` → fetchLogs 窗口、set-ref 分享的「当日」)。
  顺延的 UTC 口径随顺延一起删,端内日界线只剩这一家——三口径分裂自动消解。

### 完成动作

- **auto**:记满处方组后服务端自动完成;客户端在 set 写入响应/刷新后感知 `completedAt`,
  就地切「今日已完成」态(不加轮询,现有写后刷新链路够用)。
- **manual**(⚖️08-07 设计评审拍板,长按方案取代早稿的确认弹窗):训练界面常驻
  **长按「完成今日训练」**按钮,旁侧常显剩余提示「还有 N 个动作 · M 组未记录」
  (全记满时该提示消失);长按本身即防误触,不再加确认弹窗。0 组也可长按(= 跳过这天,
  不造第二概念)→ `POST /plans/days/:dayId/complete`。
- **撤销**:`DELETE …/complete`;错误码进域映射:`UNDO_WINDOW_PASSED`
  「只能在当天撤销」/ `NOT_LATEST_COMPLETION`「只能撤销最近完成的一天」/
  `NO_COMPLETION_TO_UNDO` 幂等收敛(刷新收口不弹错)。

### 顺延 UI 下线(删除清单)

整文件删:`PlanDayShiftLogic`、`PostponeConfirmationOverlay`、`DashboardDayShiftAlert`、
`PlanDayShiftDTOs` + 对应测试(`PlanDayShiftLogicTests`、`StudentPlanShiftProjectionTests`、
`PlanDayShiftDTOTests`)。
块删:`DashboardPrimaryAction` 的「顺延一天」link 与 `DashboardPostponedState`、
`DashboardView` 顺延编排(~100 行)、`DashboardTodayScreen.canShiftSelectedDay`、
`DashboardTodayPresentation` 的 `.postponed` 态与 UTC 比较、`APIClient+Plans` 两个 shift
方法、`StudentPlanRepository` 协议的 shift 方法对 + `PlanShiftError` 域、
`InMemoryStudentPlanRepository` 顺延实现 + `ShiftBatch`、`canShiftPlanDays` 全链
(RootView → StudentRootView → DashboardView)、相关 Preview fixture。
**保留**(W2 再动):模型展示字段 `totalShiftDays`/`latestShiftCreatedAt`/`shiftedToDate`
(backend 冻结期仍下发,教练端徽标仍消费)、`plan_shift` push 路由(老包仍可能触发顺延,
教练要能收到)、教练端全部 UI。`shiftedToDate` 在学员端投影中改为**读入但不消费**。

### Demo(InMemory)

同语义:completion store + log 满员 auto 判定 + manual/undo;种子含「W1 前两天已完成、
D3 部分记录」场景供走查游标态、部分完成不推进、撤销回退。

## 教练端 iOS(W1 明示不动)

周概览 7 列矩阵、分诊「没练 N 天」、执行时间线照旧——学员落后时教练端会出现
「红点漏课」的语义失真,**已知降级,接受一波**;W2 按拍板 4 重定义为
「距上次训练 N 天 + 卡在 W几D几」。本 spec 不碰 CoachKit(徽标消费的字段保留即可编译)。

## 验收 / 回归矩阵

- **游标推进全链**:记满 auto 完成 → Dashboard/训练 tab 双端切态 → 次日 CTA 是下一天;
  部分完成退出再进还是同一天;显式结束(含 0 组)推进;撤销回退游标并恢复可写;
  跨周推进(W1D5 → W2D1)无缝;全周期完成态。
- **拍板 5**:发布新计划后游标立即跟新计划;旧计划有未完成天不阻塞、不弹任何提示。
- **拍板 2**:存量带 shift 数据的计划显示**原排期**(非 shifted);推荐日期落后于真实
  进度时照实显示不报警。
- **缓存**:pre-071 缓存 schema bump 失效重拉,游标不被旧 projection 骗;冷启动离线
  (仅缓存)时游标可从缓存数据完整派生。
- **删净**:全仓 grep 无顺延 UI 残引;保留字段编译通过;老 push `plan_shift` 到达不崩。
- **时区**:gym-day 边界(03:59/04:00)只影响「撤销窗口」与日志归桶,不影响游标
  (游标与时钟无关——这是推进制的核心验收点)。
- Demo 走查:上述场景在 DemoStudent 构建档全部可复现。

## 不做 / 边界

- 不做教练端重定义(W2)、不做 plan-web 改动(W2)、不做 backend 顺延删除(W2,
  老包退场后);不做「今天没练」推送提醒;不做乱序选练(只能练游标日——想跳过就
  显式结束);不做同日多节硬门;不做推荐日期的动态顺推(拍板 2 已否)。
- **学员端无「休息日」概念**(⚖️08-07 设计评审拍板):今日卡在任何日历日打开都显示
  游标日(「下一节 W几D几 · 教练推荐 X/X」),不存在「今天是休息日 · 无训练安排」态
  ——那是日历制残余心智。计划浏览在训练 tab 序列列表,其标题正典文案:
  「N 周力量 · 推荐日期仅供参考」。

## 拍板记录(David 2026-08-07)

1. 完成判定 = **A**:全组记满自动完成 + 显式「结束今天训练」兜底,完成态落库。
2. 推荐日期 = **A**:忠实显示教练原排期,落后不重算。
3. 旧补练波作废:#275 / #104 已关闭。
4. 教练分诊改「距上次训练 N 天 + 卡在 W几D几」——W2 实施。
5. 换计划边界 = **A**:新计划发布即翻篇。

### spec 内决策(随 PR 终审一并确认)

1. 完成后同 gym-day 提供次级入口「继续下一节」,不设硬门;
2. 手动完成 0 组也允许(= 跳过);
3. W1 保留顺延展示字段与 push 路由、只删学员端触发链(教练端 W2 收尾)。

### 设计评审拍板(David 2026-08-07,对设计师首稿)

- P0 三条返修全采纳:①游标必须由完成推进派生、与日历解耦,补「学员落后」场景稿
  (推荐日期已过,照实灰字显示不催促);②今日卡完成态(✓ + 下一节预览 + 次级
  「继续下一节」);③已完成日当天「撤销完成」入口。
- 长按「完成今日训练」取代确认弹窗(见 §完成动作);
- 「休息日」态删除(见 §不做,与 P0-① 同根);
- 设计稿正典文案采纳入 spec:「N 周力量 · 推荐日期仅供参考」、未来日解锁说明
  「练完 W几 · ◯◯日 后自动轮到这一节」。
- **返修稿(2026-08-07 二审)已验收通过,入仓 `docs/design/sequence-handoff/` 为实装
  视觉正典**(浅色 = 全交互原型正本,深色 = 静态暗色变体;原型自带三演示场景:
  正常/落后/周期完成)。二审新增正典文案:完成态卡「W几D几 已完成」+「撤销完成 ·
  仅限今天」+ 次级「继续下一节」;周期完成卡「N 周计划已全部完成 / W1 – WN · 共 M 节 /
  下一份计划由教练发布。发布后这里会直接出现 W1 · D1。」;手动完成按钮
  「长按 · 完成今日训练」+ 剩余提示「还有 N 个动作 · M 组未记录」。
