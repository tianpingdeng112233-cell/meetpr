# spec 061 — 补练:漏课后的事后整体顺延(iOS 侧)

- **状态**:Draft(David 2026-07-24 拍板 A「补练/事后顺延」授权本 spec;细则见 §拍板与待确认)
- **对应 backend spec**:`026-catch-up-shift`(同一 wave;wire 契约由它定义,本 spec 消费)
- **父 spec**:`054-whole-plan-shift`(整体顺延 V2)。本 spec 是 054 的补集:054 解决「今天有事,
  提前把课推走」,本 spec 解决「当天没打开 app,课已滑进历史」——两者共用同一套 batch 覆盖层、
  撤销窗口与累计计数,只是触发时机与后移天数不同。

## 问题(为什么做)

学员漏课后是死局:①「记录此组」CTA 锁今天,过去日期只读,补不了卡;②顺延门是
`SHIFT_ONLY_TODAY`,只能顺延「今天」的课。两道锁各自正确,组合起来把「缺席一天、
次日想继续」这个最常见场景关在门外。力量举计划课次连续(恢复间隔、连续日压力是编排的
一部分),漏课的正确语义是「整体后移」,不是「跳过」——现行为等效强制跳过。

## 语义(一句话)

打开学员端时,若存在「生效训练日早于今天、且没有任何 set log」的课,提示一键补练:
**整份计划从最早漏课日起整体后移 N 天(N = 今天 − 最早漏课日),使最早漏课落到「今天」**
——此处「今天」均指**服务端 gym-day**(上海口径);设备在上海时即用户眼中的今天,
旅行场景可能是设备口径的明天(§时区正典 已定义)。课序原封,之后的课依次顺延,
周期结束日 +N。

## 时区正典(端内唯一口径 = 现行 `WorkoutDatePolicy`)

- **iOS 端内「今天」只有一个来源**:现行 `WorkoutDatePolicy`(**设备本地日历 + 04:00 截断**,
  1.0(11) 建立,`WorkoutDatePolicy.swift:13-18`)。本 spec **不新建第二口径**——补练检测、
  dismiss 作用域日期、乱序判定、撤销入口可见性,全部消费它;`PlanDayShiftLogic` 现行的
  UTC 日期比较(`PlanDayShiftLogic.swift:49`)一并收编到该口径。这样补练卡与「开始训练」CTA
  永远同属一个训练日,不再出现两道锁口径分裂。
- **与服务端的分歧明示接受**:backend 顺延域用 `shanghaiTrainingDay()`(固定上海 04:00,
  见 026)。设备在上海时区时两者恒等;旅行场景两者可差一天,后果**逐项定义**(不是一句
  "服务端权威"带过):
  - **本地假阴性**(上海已翻日、设备还没翻):漏课卡可能晚最多一天出现——接受,漏报无害,
    没有 POST 就没有伤害;
  - **N 口径差**(双方都判漏课但天数不同):以服务端算的 N 为准,成功后今日卡刷新为
    **最新生效计划**——补上的课可能落在设备口径的"明天",成功文案因此不承诺"今天":
    「已顺延,从◯◯课继续」。该成功提示**每次 catch-up 成功都展示**(现行 today 顺延
    累计 <3 天无成功 alert,catch-up 不同——学员需要确认"补课生效了";累计 ≥3 天的
    建议联系教练提示追加在同一 alert 内,不另弹);
  - **本地误报防重弹**:`NOTHING_TO_CATCH_UP` 拒绝后,除权威刷新外,还按
    `(studentID, cycleID, earliestMissed, 本地 gym-day)` 存**服务端拒绝标记**——同四元组
    当天不再弹(时钟口径差导致的误报刷新后依旧误报,单靠刷新会违反"不重试轰炸")。
  UTC 口径与 gym-day 的分歧窗口是**04:00–08:00**(04:00 前两者同日)。
- `latestShiftCreatedAt` 的乐观回填(顺延成功后 iOS 以本机 `Date()` 暂填)保留——撤销窗口
  最终由服务端 `UNDO_WINDOW_PASSED` 兜底,时钟漂移的代价只是按钮短暂多显示/少显示,可接受。
- 边界测试基线:本地 03:59/04:00、07:59/08:00、跨 UTC 午夜、设备处非上海时区
  (断言端内三处消费方给出同一个「今天」)。

## 检测(数据面,消 fetch 缺口)

现状:Dashboard 链路只保留当前计划周、logs 只拉当周范围——**不足以**发现跨周漏课。
本 spec 把现有那次 logs 请求(`scope=plan`)的**日期范围扩为「全周期生效日期范围前后各
pad 1 天」**(仍是一次请求,无新端点),再按 `planExerciseID` 归属过滤判定各训练日有无 log。
pad 的原因:服务端按 `logged_at` 的 UTC 午夜窗口筛选,周期首日北京凌晨(如 04:30)的 log
其 `logged_at` 落在前一 UTC 日,不 pad 会漏读、把已练判成漏课。**不用 `scope=all`**:
adhoc 行的 `plan_exercise_id` 可为空,与现行非可选 DTO 不兼容。
漏课判定 = 生效日期 < 今天(均按 §时区正典 口径)且该日 0 条归属 log,取最早者;
日期比较沿 `PlanCalendarDayIdentity`(#274)的分量式判定。

## iOS 行为

- **提示卡**(今日 tab,检测命中时):「7月X日的课没练。把计划顺延,补上这节课?」
  主按钮「顺延计划」→ POST `mode: "catch_up"`(N 由服务端算,见 026);
  副按钮「今天不练」= dismiss。文案不承诺"顺延到今天"——旅行场景服务端的 N 可能
  使课落到设备口径的明天(§时区正典)。
- **入口互斥**:漏课态下隐藏「今天有事」普通顺延入口(其语义只移今天以后,会遗留漏课欠账),
  补练卡是唯一顺延入口;今天课的「开始训练/记录」CTA **不阻断**(学员有权今天照练,
  见下一条的后果处置)。
- **学员今天照练**:今天的课一旦产生 set log,漏课条件转为乱序(服务端将回 `SEQUENCE_DIVERGED`),
  补练卡就地切换为静态提示「课程顺序已调整过,请联系教练重排计划」,当个周期内不再提供一键补练。
  **乱序是派生态不是瞬时态**:本地 card state 的判定 = 「earliest missed 之后是否存在任意
  归属 log」(与检测同一数据面算出),不依赖 `SEQUENCE_DIVERGED` 响应或内存 `@State`——
  冷启动时若后续课程已有 log,直接进静态「联系教练」态。
- **dismiss 作用域**:本地存 `(studentID, cycleID, earliestMissed gym-day, dismissed-on gym-day)`
  四元组;当天(gym-day)不再弹,四元组任一变化(新的一天/最早漏课变化/换周期/换账号)即重新评估。
  POST 失败不写 dismiss。
- **成功后**:刷新为**最新生效计划**——补上的课仅当其生效日期命中设备 gym-day 时进今日卡
  (上海场景恒命中;旅行场景可能显示在明天);红字「撤销顺延」按 054 现行规则显示;
  `total_shift_days ≥ 3` 时追加累计提示「已累计顺延 N 天,建议联系教练调整计划」。
- **撤销确认文案改为通用式**(054 现行文案承诺"回到今天",对 catch-up batch 是错的):
  「撤销后,课程将回到顺延前的日期」——不承诺具体日期,不改 wire。
- **错误处置**(新 machine code 进 `PlanShiftError` 域映射;**proposal 态与 card 派生态是
  两个状态**——前者是一次点击的进行中流程,后者由检测条件派生):
  - `NOTHING_TO_CATCH_UP`(多设备竞态的正常态):**权威刷新**后收起卡片,不弹错误。
    权威刷新 = invalidate 计划缓存后重拉(现行 `fetchCurrentPlan` 是 cache-first,普通 reload
    会用旧 projection 把同一张卡再画出来)+ 同步重拉 logs,再重算卡片状态;
  - `SEQUENCE_DIVERGED`:**收到即无条件写 cycle 级拒绝标记**(标记本身足以驱动静态
    「联系教练」态,冷启动/刷新不回退成按钮),随后**尽力**重拉 logs 让 detector 从数据面
    也派生出乱序(该码最典型来源是多设备竞态,本地旧数据派生不出)。不采用"重拉失败才写
    标记":现行 `BackendStudentTrainingLogRepository.fetchLogs` 网络失败时静默回退缓存,
    调用方拿不到失败信号,"失败才写"不可实现;标记的清除条件 = cycle 变化;
  - **除上述两个收敛码外**的失败(网络/未知码):清 proposal 态、卡片保持可再次触发,
    文案沿 054 映射(未知码兜底「请检查网络后重试」)。
- **可见性谓词**:`canShiftPlanDays`(现行 = role == coachedStudent,`RootView.swift:335`)
  **且当前计划 `planKind == .regular`**。后者排除评估期 adaptation 计划——封存态学员的
  role 谓词恒 true(`BindGateViewModel` 封存直进五 tab,不读 evaluation 状态),必须用
  plan kind 这个 Dashboard 已有的数据面来排除,不引新判定源。solo 无 coached 计划,天然不进。
  **legacy 缓存防线**:pre-033 缓存 projection 缺 `planKind`、解码默认 `.regular`,而
  `fetchCurrentPlan` cache-first——旧 adaptation 缓存会在后台刷新落地前骗过谓词。双防:
  ① 计划缓存 schema 版本 bump,旧版本 projection 直接失效重拉(不靠字段猜);
  ② backend 026 对 `kind !== 'regular'` 的 catch_up 拒绝门是最后防线(见 026 §门)。
- **教练端**:无新 UI;计划级「已顺延 N 天」徽标随 `total_shift_days`(现为累计天数)自然变大。
- **Demo(InMemory)**:同语义实现(含 `NOTHING_TO_CATCH_UP`/`SEQUENCE_DIVERGED` 路径),
  种子含「昨天漏课」场景供走查。依赖接缝明确:`InMemoryStudentPlanRepository` 现只持有
  plan store,无法判 set log——**注入一个 log 读取器**(`StudentTrainingLogRepository` 或
  等价闭包)实现同语义门,不靠上层预判。

## 验收 / 回归矩阵(nit 采纳)

- 补练:漏 1 天 / 跨周漏多天(最早者锚定)/ dismiss 当天不弹次日再弹 / 竞态两码的 UI 收敛 /
  冷启动即乱序(后续课程已有 log)直接静态「联系教练」态 / legacy 缓存(缺 planKind)不弹卡 /
  **拒绝标记**:`NOTHING_TO_CATCH_UP` 后即使刷新数据仍满足本地误报条件,同四元组当天不重弹,
  本地 gym-day 或 earliest missed 变化后重新评估;`SEQUENCE_DIVERGED` 重拉失败时标记兜底,
  冷启动不回退成按钮。
- `total_shift_days` 单位升级三消费方回归:周期结束日、累计 ≥3 提示、教练徽标——
  覆盖 catch-up N>1、today+catch-up 叠加、撤销 N-day batch 后回退,断言显示的是**天数**。
- 时区边界:§时区正典 的四组基线用例(检测、dismiss、撤销入口三处都跑)。

## 不做 / 边界

- 不做逐日单独补练(只整体后移,054 序列哲学不变);不做过去日补卡(CTA 仍锁今天);
- 碰撞检测沿 054 拍板 3(先允许 + 教练可见);
- 不做「今天没练」推送提醒(APNs W2 之后另立卡)。

## 拍板与待确认

- ⚖️ 已拍(2026-07-24):方向 A「补练/事后顺延」成立,取代「漏课永久欠账」现状。
- 待 David 过目的 spec 内决策(loop 收敛后随 spec PR 一并确认):
  1. 乱序(漏课后又打了后面的课)不提供一键补练,转「联系教练」——备选是乱序也允许只移
     未打卡日,但破坏 054「覆盖层不重排课序」哲学,不推荐;
  2. iOS 端内「今天」统一收编到现行 `WorkoutDatePolicy`(设备本地 04:00),与服务端沪口径的
     旅行场景分歧由服务端权威兜底——不在端内造第二口径;
  3. 漏课态下隐藏「今天有事」入口(补练为唯一顺延动作),今天的训练 CTA 不阻断。
