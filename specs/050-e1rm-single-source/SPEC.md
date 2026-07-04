# SPEC 050 — e1RM 只留一个事实(走查 P0-6)

- **状态**: Draft
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

## 非目标

- 不改公式/不引入新平滑算法调参(窗口宽度 4 周为工程决策,记常量);
- 不动后端(E1RMHistoryPoint 数据结构与存量数据原样,聚合在客户端);
- 教练端成长视图(CoachKit StudentGrowth)本 spec 不改,follow-up 到教练 wave(同一 series 可复用)。

## 测试

- `E1RMEligibility`:RPE<7 拒/nil 允/rep>10 拒/硬拉 r6 拒 r5 允/failed 拒。
- `E1RMSeries`:单点飙高 25kg → 当前值走滚动 max 不跳变;窗口滑出后回落;Best/Last 语义。
- `E1RMRecorder`:噪声带内(+2%)不判 PR,带外(+4%)判;RPE<7 组不产生 point;两 VM 共用(Today/Solo 各一条集成断言)。
- 回归:StudentKit 全绿;PR banner 既有流不回退。

## 验收

1. 同一学员同一时刻,今日 tab / 成长 tab 显示同一个「当前 e1RM」;资料页基线带注解不再像第三个事实。
2. 走查复演:单组异常高记录后曲线主线不跳 25kg(散点可见,主线平滑)。
3. RPE 6 的轻组、12 次的高 rep 组、6 次的硬拉组均不改变当前值与 PR 状态。
