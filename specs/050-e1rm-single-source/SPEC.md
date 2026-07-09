# SPEC 050 — e1RM 只留一个事实(走查 P0-6)

- **状态**: 主体 #216 已合;本 amendment 追加 §5/§6 异常保护(走查 P0-5),分支 `feat/050-anomaly-guard`(Phase 1 数据层本 PR;Phase 2 确认 UI 待 feat/051 合后)
- **来源**: 自己练 Free 档 wave 泳道 B;走查报告 P0-6:「今日 tab 178.5、成长 tab 203.5、资料页基线 220——三个『我的实力』互不解释;单组记录把曲线顶高 25kg 无平滑」。
- **科学锚点**(powerlifting skill `strength-math-e1rm.md`,产品决策级):公式选定后全局一致比选哪个重要(现状 ✓ 全走 spec-028 `E1RMCalculator`);单次 session e1RM 波动 ±2-5% 是噪声底盘;判 PR 用「同条件超历史 best 且超 ~3% 噪声带」;RPE<7 的组不入估算;硬拉高 rep 组系统性高估,只信 r≤5;rep>10 全体失准不入。
- **现状诊断**(2026-07-04 代码核):公式已单源;**打架在聚合层**——①Dashboard 标题 = 最新原始点(`bestCurrentE1RM`→`latestPoint`)②成长曲线 = 原始点裸连线,无平滑无异常保护 ③资料页基线(onboarding 1RM)无「基线 vs 实测」注解 ④PR 判定仅 0.5kg 缓冲,无入选门/噪声带;TodayWorkout 与 SoloSession 各持一份 `recordE1RMPoint` 副本(U2 注记待合并)。

## 1. 入选规则(哪些组配进入 e1RM 估算)

一处定义,全端共用(`E1RMEligibility`):
- `completed == true && failed == false`(现状已有);
- **RPE < 7 的组不入**(有 RPE 且 <7 → 拒);RPE 为 nil 的组**仍入**(coached 计划大量无实测 RPE,全拒会饿死数据;公式按力竭假设估算,偏保守可接受);
- **rep > 10 不入**(全公式失准区);
- **硬拉(`mainLiftFamily == .deadlift` 的动作)只信 rep ≤ 5**(高 rep 硬拉受握力/位置疲劳限制,系统性高估)。

不合规的组照常记录训练日志(入选门只管 e1RM/PR,不管日志)。

## 2. 展示口径(三个数变一个事实)

新聚合层 `E1RMSeries`(纯函数,输入原始 `E1RMHistoryPoint`,输出展示序列):
- **当前值 = 4 周滚动窗口 max**(平滑;窗口尾随最新点);
- **曲线 = 滚动 max 折线**为主视觉,原始合规点以弱化散点叠加(诚实展示离散);
- **Best = 历史合规点最高值**(带日期),**Last = 最近合规点**(语义不变);
- Dashboard 标题、成长 tab 曲线、Last/Best 徽标全部消费 `E1RMSeries`,禁止各自摸原始点。

## 3. PR 判定收紧

`recordE1RMPoint` 两份副本(TodayWorkoutViewModel / SoloSessionViewModel)收敛为共享 `E1RMRecorder`:
- 入选门(§1)前置:不合规的组不产生 point 也不判 PR;
- PR 条件:新点 e1RM > 历史 best **且** 超出 `max(0.5kg, 历史best × 3%)` 噪声带;
- 其余(base-line before insert、幂等、banner 流)保持现状语义。

## 4. 基线的位置(220 的归宿)

- 资料页基线行加注解:「入门基线 · 实测走势见成长」;实测 best 已超基线时加「已超基线」徽标;
- Dashboard 与成长 tab **不出现基线数值**(现状如此则锁定为规范);
- 基线仅作 onboarding 起点与新号冷启动参照,永不与实测序列混算。

## 5. 异常保护:分级门(走查 P0-5)

> 产品锚:`~/Brain/wiki/projects/MeetPR/domain/e1rm-headline-and-anomaly-guard.md`(David 2026-07-04 拍板)。§2 滚动 max 只挡**向下**疲劳回落,**挡不住向上误记尖峰**(P1-1 数字键盘放开后 175→275 手滑高频);单点 e1RM 会顶穿 current/best/PR 三处并**永久锁死 PR 基线**(以后真 PR 打不过幽灵)。本节在**点生成层**设防,一处护三处。

分级基线 `B` = 该点之前的 running best **合规且 `.normal`** e1RM(`maxBefore` 收敛为只取 `.normal`)。新合规点 e1RM 相对 `B`:

- `jump ≤ soft`(0.10):`.normal` —— 正常入 best / current / PR(PR 仍走 §3 噪声带)。
- `soft < jump ≤ hard`(0.10–0.18):`.low` 低置信 —— 排除出 best / current(滚动 max)/ PR 判定,仍作弱化散点(honest scatter);**不追溯升格**。
- `jump > hard`(0.18):疑似误记 —— **Phase 2** 录入时 inline 一步确认「确认重量 {w}kg?你近期最好约 {B}kg」[没错]/[改一下],确认前不产生合规点;**Phase 1**(本 PR,无 UI)先按 `.low` 存(同样排除三处、留散点),不打断录入。
- `B == nil`(冷启动无历史):`.normal`(无可比;交 §6 的 coach 基线兜底)。

落地:`E1RMHistoryPoint` 加 `confidence: .normal|.low`(默认 `.normal`,旧 JSON 无字段解码为 `.normal`,后端与存量数据不变);`E1RMSeries` 的 best/smoothed/last 与 `E1RMRecorder` 的 PR 判定只吃 `.normal`;`maxBefore` 只取 `.normal`。阈值记常量 `softJump = 0.10` / `hardJump = 0.18`(依据:男进步 ~7%/年、单 session 真涨幅 0–5%,+18% over 全时最佳几乎必是误记)。

**已知局限(Phase 1)**:真·大跳(> hard 的真实 PR,罕见)在无确认时会被误判 `.low`;Phase 2 的确认 + 二次印证升格补齐(见 §6 与 domain 锚页 follow-up)。

## 6. 录入 sanity(冷启动也接住 typo)· Phase 2

- 主参照 = 学员自己 running best(= §5 的 `B`)。
- coach 锁基线 `L`(onboarding 1RM)在则**叠加**:录入 `e1RM > L × 1.15` 或裸重量 > `L` → soft nudge。让**第一条 log 无历史**时也接住 typo(§5 的 `B` 冷启动为空)。
- 形式:soft nudge + 一步 tap-through,**绝不硬 block**(不挡真 PR / 久别重练);仅在有 `B` 或 `L` 后生效。

## 非目标

- 不改公式/不引入新平滑算法调参(窗口宽度 4 周为工程决策,记常量);
- 不动后端(E1RMHistoryPoint 数据结构与存量数据原样,聚合在客户端);
- 教练端成长视图(CoachKit StudentGrowth)本 spec 不改,follow-up 到教练 wave(同一 series 可复用)。

## 测试

- `E1RMEligibility`:RPE<7 拒/nil 允/rep>10 拒/硬拉 r6 拒 r5 允/failed 拒。
- `E1RMSeries`:单点飙高 25kg → 当前值走滚动 max 不跳变;窗口滑出后回落;Best/Last 语义。
- `E1RMRecorder`:噪声带内(+2%)不判 PR,带外(+4%)判;RPE<7 组不产生 point;两 VM 共用(Today/Solo 各一条集成断言)。
- **`E1RMAnomalyClassifier`(§5)**:冷启动(B=nil)→ .normal;+2% → .normal;+12% → .low;+75% → .suspectHard;边界 +10%/+18% 精确落点。
- **`E1RMHistoryPoint.confidence`**:旧 JSON(无 confidence 字段)解码为 .normal;round-trip 保真。
- **`E1RMSeries`(§5)**:含一个 .low 高点时 best/current/last 不含它,rawEligible(散点)含它。
- **`E1RMRecorder`(§5)**:异常高点存为 .low + 不判 PR + 不顶基线(紧接一条正常点仍能 PR,证明基线未被幽灵污染);`maxBefore` 只取 .normal。
- 回归:StudentKit 全绿;PR banner 既有流不回退;既有 `E1RMSeriesTests` / `E1RMRepositoryTests` 全绿(confidence 默认 .normal 不改旧断言)。

## 验收

1. 同一学员同一时刻,今日 tab / 成长 tab 显示同一个「当前 e1RM」;资料页基线带注解不再像第三个事实。
2. 走查复演:单组异常高(相对近期最好 > 10%)记录后被判 `.low`,**不进 current / best / PR**,曲线主线不被顶高、不误报 PR(该点仅作散点可见)。⚠️ 滚动窗口本身只防**向下**回落、防不住**向上**尖峰——上尖峰由 §5 分级门拦(原验收误记为滚动 max 之功,已更正)。
3. RPE 6 的轻组、12 次的高 rep 组、6 次的硬拉组均不改变当前值与 PR 状态。
