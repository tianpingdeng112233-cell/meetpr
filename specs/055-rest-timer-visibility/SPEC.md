# Spec 055 — 学员组间休息:可感知 + 自定义兜底

- **状态**:已拍板(David 2026-07-11,内测反馈直出;P1,落 `release/1.0` 随 1.0(9) 班车)
- **级别**:T1(StudentKit 为主,允许向共享模块小幅下沉)
- **上游**:spec 030 §B(计时器本体)、spec 040(教练 per-set rest + RPE 自动兜底)

## 背景

组间休息现为三级回落:教练逐组 `restSeconds` > 按实记 RPE 查 `RestDefaults`(<7→120s,
<9→180s,≥9→240s,nil→180s)> 默认。机制本身合理,但学员**无从感知**:内测反馈
「怎么都是 3 分钟」——全场 RPE 8 恒落 180s 档,看起来像写死。且学员没有任何调整入口
(现场 ±30s 不持久化,是 040 有意边界,本 spec 不改)。

## 拍板内容(两点,不多不少)

1. **首次触发说明弹窗**:学员第一次弹出 rest timer 时,前置一张一次性说明卡,白话解释:
   - 休息时长按你记录的 RPE 自动匹配(RPE 低于 7 → 2 分钟;RPE 7 至 9 以下 → 3 分钟;
     RPE 9 及以上 → 4 分钟。注意 RPE 输入允许任意小数,8.6-8.9 也落 3 分钟档,文案勿写成 7-8.5);
   - 教练在计划里指定过休息的组,按教练设定;
   - 可在「我的 → 组间休息」修改默认行为。
   确认按钮「知道了」;只弹一次,flag 本机持久化(重装后允许再弹一次)。弹窗展示期间
   倒计时照常走(wall-clock `endsAt` 驱动,不暂停、不加状态机分支)。
2. **「我的」页设置入口**:学员「我的」页新增「组间休息」设置项,两档:
   - **自动(按 RPE)**——默认,行为与现状完全一致;
   - **固定时长**——picker 选定秒数(30…600,step 15,与教练端 `RestSecondsPicker` 同规格)。

## 优先级序(核心裁决,勿改)

`教练显式 restSeconds` > `学员固定时长偏好` > `RPE 自动表(RestDefaults)`

学员偏好**只替代自动兜底**,永不覆盖教练处方。即:
`prescribed.restSeconds ?? studentPreference ?? RestDefaults.seconds(forRPE:)`

## 范围与边界

- **动**:StudentKit(TodayWorkout 计时器触发路径、「我的」页)、必要时 CoreModels /
  DesignSystem(若 `RestSecondsPicker` 需从 CoachKit 下沉共享——不许 StudentKit 直接 import CoachKit)。
- **不动**:backend(偏好仅本机存储,V0.1 边界,不跨设备同步——文案不承诺同步)、
  CoachKit 行为、RestDefaults 表数值、±30s 不回写的既有边界。
- 存储用本机 UserDefaults(走 StudentKit 现有 settings/repository 惯例,若无则建最小 wrapper,
  便于测试注入)。

## 验收标准

1. 首次 rest timer 触发弹说明卡,「知道了」后本 session 及后续 session 均不再弹。
2. 「我的」出现「组间休息」入口:默认「自动(按 RPE)」;切「固定时长」并选值后,
   **无教练设定**的组倒计时 = 所选值;**有教练设定**的组仍用教练值。
3. 偏好保持「自动」时,全链路行为与现状 bit-for-bit 一致(RPE 表、nil 兜底、±30s、跳过均不变)。
4. 单测覆盖优先级回落三分支(coach > custom > auto)与首弹 flag 逻辑。
5. `swiftlint --strict` + `swift-format` 干净;`build_sim` 绿 + StudentKit `swift test`(SwiftPM)
   全绿(StudentKit scheme 未配置 TestAction,`test_sim` 对包级测试不适用)。

## 埋点

不在本 spec 范围(如 David 后续要求,另卡挂 analytics wave 口径)。
