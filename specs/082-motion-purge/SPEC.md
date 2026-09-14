# spec 082 — 删装饰动效、统一按压反馈、强化蓄力与奖励反馈

- **状态**:Done(2026-09-14 David 授权推进至完成；独立 Standards/Spec 收货通过。原批准记录：2026-09-02 /grill 三题 David 拍板:① 按钮反馈 = 视觉 + 分级触感;
  ② 蓄力渐强触感 + 奖励页盖章重震;③ 其他动效全部硬切,奖励页「查看总结」流光除外)。
- **级别/节奏**:T2(跨 DesignSystem / StudentKit / CoachKit / AppShell);P1,目标 1.0(22)。
- **范围**:iOS 双端(按钮反馈全 app 统一;装饰动效学员端为主,教练端本就没有);零 backend。
- **来源**:2026-09-02 学员反馈「老是卡住/卡一下」+ David 自用体感;根因排查见本文「问题」。

## 问题(为什么做)

1. 学员截图停在「开始训练」跳场动效的中间帧(Today 已淡出、Training 未淡入、底部只剩起飞的
   金色幽灵胶囊)。跳场状态机 `awaitingDestinationFrame` 无超时,主线程一卡即黑屏。
2. 常驻逐帧动效(CTA 流光 `TimelineView(.animation)`、日期呼吸点、Today 头部 `repeatForever`
   脉冲)在四 tab 常驻保温(#289)下 120Hz 不停跑,老机型/低电量叠加掉帧。
3. 入场 rise-in 让首屏内容延迟 0.5s 以上才出现;折叠/展开/反馈卡编排让操作有「等一下」感。
4. 产品口径(David):训练记录工具第一性原理 = 极简高效;只留「反馈」和「奖励」,删「装饰」。

## 术语(已写入 CONTEXT.md)

- **装饰动效**:不承载状态反馈的入场/流光/呼吸/跳场/编排;本卡全删。
- **按压反馈**:按钮按下瞬间的视觉确认(缩放+变暗)+ 动作型按钮的触感;全 app 统一。
- **蓄力完成**:训练页底部长按 1.1s 完成当日训练的按钮(`HoldToCompleteButton`)。
- **奖励页**:蓄力完成后的 `WorkoutCelebrationView`(勋章盖章 + 火花 + 分段入场 + 连胜)。
- **奖励线(本卡保留的动效全集)**:动作卡卷起收起 → 蓄力完成 → 奖励页 → 完成后 `DayCompletionBanner` 流光。

## 方案

### A. 删除清单(硬切 = 状态直接翻转,无过渡)

1. **跳场 morph 整套**:`StudentRootView` 里 `LaunchMorphPhase` 状态机及全部 launch* state
   (launchTask / launchCompletionTask / `LaunchDestinationFrameLatch` / launchSourceFrame /
   launchMorphProgress / launchGhostFadeProgress / dashboardExitProgress / launchDestinationOpacity /
   revealsLaunchTarget / heroFrameRequestToken / launchHeroRevealToken / dashboardCTAFrame)、
   `MeetPRLaunchMorphOverlay` / `MeetPRLaunchMorphEffect` / `MeetPRLaunchMorphSpec` /
   `MeetPRLaunchExitModifier`;`DashboardView` / `DashboardPrimaryAction` 的
   `isStartWorkoutHidden` / `onStartFrameChange` / `onGeometryChange`;`TodayWorkoutView` /
   `TodayWorkoutScreen` / `TodayWorkoutHero` 的 `isLaunchTargetHidden` / `heroFrameRequestToken` /
   `launchHeroRevealToken` / `onHeroFrameChange` / `TodayWorkoutHeroFrameMeasurement` /
   `matchedGeometryEffect` + namespace / `launchHeroRise`。
   **「开始训练」新行为 = 现有 reduceMotion 分支唯一化**:设 handoff、`trainingJumpToken += 1`、
   `selectedTab = .training`,同步完成,无任何延时。
2. **入场 rise-in**:`RiseInModifier.swift`(`RiseInModifier` / `PillRiseInModifier` /
   `SkeletonPulseModifier`)、`PreciseTweenEffects.swift` 里 `MeetPRRiseInModifier` /
   `MeetPRRiseInEffect`;用点 `TodayWorkoutScreen`(recording 列表 stagger + launchHeroRise)、
   `DashboardTodayScreen`、`DashboardFeedbackCard`。**例外**:奖励页内部若用到 rise-in 原语,
   原语保留、只删上述用点。
3. **流光 shimmer**:删 `GoldCTA` / `BrandPrimaryButton` 的 `showsShimmer` 用点
   `TodayWorkoutScreen`(开始 CTA、蓄力按钮待机流光)、`SessionSummaryView`、
   `DashboardPrimaryAction`。**保留** `ShimmerOverlay` 原语,用点只剩两处:奖励页「查看总结」CTA,
   以及当日完成后训练页底部的 `DayCompletionBanner`(完成当天任务后**开始**流光,作为奖励延续;
   David 2026-09-02 追加)。蓄力按钮待机无流光。
4. **呼吸/脉冲**:`DayChip.statusDot` 的 `TimelineView(.animation)` → 静态点;
   `DashboardHeader` 的 `pulses` `repeatForever` → 静态。
5. **死代码**:`GoldGlowModifier.swift`、`GoldCurtain.swift`(全仓零用点)删除。
6. **反馈卡编排**:`DashboardFeedbackCard` 的 展开/收起/预览淡出淡入/箭头 全部 `withAnimation`
   与 `Task.sleep` 编排删除,状态直接翻转。
7. **卷起收起(保留)**:`RollUpCollapse.swift` + `ExerciseCard` 的 rollUp 动画(0.62s 四帧 +
   轻→中→重触感)是「一个动作练完」的完成反馈,**原样保留**,含手动折叠走同一动画
   (David 2026-09-02 拍板);相关 token 与 `MotionTests` 的 roll-up test 一并保留。
8. **零散过渡**:`TodayWorkoutView` 休息计时器 `.animation(MeetPRMotion.spring, value: restTimer)`;
   `SetEntrySheet` 数字键盘 `.animation(MeetPRMotion.sheet)`;`SetEntryRPEScale` 三处
   `.animation`;`RPESlider` `pillSelect`;`DashboardE1RMRail` `.easeInOut`;
   `TodayWorkoutHero` `.transition(.opacity)`;`WorkoutCompletionFlowView` 奖励页→总结页的
   `.animation(MeetPRMotion.screen, value: phase)` 与两处 `.transition(.opacity)`;
   `CoachMyProfileView` 两处 `withAnimation(MeetPRMotion.press)` + `.transition(.opacity)`;
   `ChatUI/FeedbackVideoPlayerView` `.transition(.move…)`。系统 sheet / NavigationStack /
   fullScreenCover 自带过渡**不动**。
9. **Motion tokens 瘦身**:`Tokens/Motion.swift` 只留仍有用点的 token(press / hold /
   celebration / completion / rollUp / 奖励页用到的曲线);launch* / rise* / feedback* / glow
   等随用点一并删。`MotionTests.swift` 同步:删 launch 几何、feedback overshoot、rise 曲线相关
   test;保留 timing 值(裁到存活 token)、roll-up keyframes/haptics 与 celebration sparks test。

### B. 按压反馈统一(全 app)

1. `PressScaleButtonStyle` 升级为全局默认样式(可改名 `MeetPRPressFeedbackStyle`,保留旧名
   typealias 亦可):按下 **即时** scale 0.97 + opacity 0.85,松开即时复原,**无动画**
   (`.animation(nil)`);`reduceMotion` 下去 scale、留 opacity;disabled 保持现有 0.35。
2. 在 AppShell 根(学员 root、教练 root、登录/注册/全局登录页)以 `.buttonStyle(...)` 注入,
   使所有 `Button` 默认继承;仓内 `.buttonStyle(.plain)`(115 处)/ `.borderless` /
   `LoginButtonStyle` 全部改为统一样式或删掉让其继承。**系统 `.bordered` / `.borderedProminent`
   (17 处,登录外的系统风格表单/工具按钮)保留原样**:它们自带系统按压高亮,且其边框/填充是
   静态外观,重做等于顺手改静态样式(收货时 Claude 定,2026-09-02)。
   `Toggle` / `Picker` / `NavigationLink` 系统控件不动。
3. **触感分级**(`sensoryFeedback`):
   - 动作型 = `GoldCTA` / `PrimaryButton` / `BrandPrimaryButton` / `SecondaryButton`(light impact)、
     `DangerButton`(warning)、`IconButton`(light)、数字键盘 / RPE 选择(现有 selection 类不动):
     现状已有,保持。
   - 导航型 = `MeetPRTabBar`、`MeetPRListRow`、NavigationLink 行、展开/折叠、返回:**不震**;
     `MeetPRListRow` 现有 light impact 删除。
   - 不新增全局触感;不在 `ButtonStyle` 里加触感(避免满屏震)。

### C. 蓄力完成反馈强化(`HoldToCompleteButton`)

1. 7 段触感由「全 light」改为**渐强**:段 1–2 `.impact(weight: .light, intensity: 0.5)`,
   段 3–5 `.impact(weight: .medium, intensity: 0.7…0.85)`,段 6–7
   `.impact(weight: .heavy, intensity: 1.0)`。段数、`durationHoldComplete = 1.1s` 不变。
2. 满格:现有 `.success` 保留,加按钮一次短促回弹 scale 1.0 → 1.04 → 1.0(≤0.25s,
   reduceMotion 下不做)。
3. 取消:现有 `.warning` + 0.3s 回退保留。金色填充、待机外观(去流光后)不变。
4. 渐强表抽成纯函数(如 `HoldToCompleteHapticSchedule.feedback(forStep:)` 返回 weight+intensity),
   进现有 `HoldToCompleteGestureStateTests` seam。

### D. 奖励页反馈强化(`WorkoutCelebrationView`)

1. 页面出现即 `.success` 触感(`sensoryFeedback(.success, trigger:)` 以 onAppear 翻一次)。
2. 勋章**盖章落定那一刻**(`CelebrationEffects` 的 stamp progress 首次到 1,即 bloom 后
   `durationStamp` 结束)触发一次 `.impact(weight: .heavy)`:`CelebrationEffects` 暴露
   `onStamp` 回调或等价 trigger;reduceMotion 下 stamp 立即为 1,仍触发一次。
3. 奖励页其他动效(bloom / 火花 / 分段 slide、fade / 连胜胶囊 / 「查看总结」流光)**原样保留**;
   总结页 `SessionSummaryView` 除删流光外不动。

## 架构约束

1. 动效原语只在 DesignSystem;删除后 `TimelineView(.animation` 在 `Modules/*/Sources` 仅剩
   `CelebrationEffects.swift` 与 `ShimmerOverlay.swift`;`meetPRShimmer(` 用点仅剩奖励页与 `DayCompletionBanner`;
   `meetPRRiseIn(` 用点为零或仅奖励页。这三条以 grep 作为验收硬指标。
2. 不做全局强制 reduceMotion 的取巧路径(代码要真删);现有 `accessibilityReduceMotion` 分支在
   保留的动效(奖励页、蓄力、按压)里继续尊重。
3. 静态样式(阴影 / 渐变 / 描边)不是动效,不在本卡范围,不顺手改。
4. 交付红线:纯 UI,不碰 model / repository / 迁移 / 用户数据;「开始训练」handoff 语义
   (plan + dayID + existingLogs)不变。
5. i18n 无新增文案。

## 测试 seam(先红后绿)

1. `Modules/DesignSystem/Tests/DesignSystemTests/MotionTests.swift`:裁剪后对存活 token 的
   timing 断言 + celebration sparks 断言(现有 seam)。
2. `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/HoldToCompleteGestureStateTests.swift`:
   新增渐强触感表断言(段 1–2 light / 3–5 medium / 6–7 heavy,intensity 单调不减)——先红。
3. `TodayWorkoutPresentationTests.swift`:删除 `LaunchDestinationFrameLatch` 相关 test
   (类型随跳场一起删)。
4. 不在其他 seam 上新加测试;SwiftUI 视图层验收走模拟器走查 + grep 硬指标。

## 不做(防蔓延)

- 不重设计奖励页、蓄力按钮布局与时长;不改 tab 导航结构;不动 Live Activity / 休息计时器逻辑。
- 不做「减弱动态效果」全局开关;不做动效偏好设置项。
- 不改阴影/渐变等静态样式;不做性能 profiling 工具化(MetricKit 等)。
- 教练端只吃统一按压样式,不做别的改动;plan-web / backend 零改动。
- `docs/design/*` 里的动效参考稿不删,但本卡起视为作废,SPEC 即新口径。

## 验收标准

1. `build_sim` + 全量 `test_sim` 绿;`swift-format --strict` + swiftlint 过。
2. grep 硬指标(`Modules/*/Sources`,排除 `.build`):`TimelineView(.animation` 仅
   `CelebrationEffects.swift` / `ShimmerOverlay.swift`;`meetPRShimmer(` 用点仅奖励页 + `DayCompletionBanner`;
   `LaunchMorph` / `launchHeroRevealToken` / `meetPRRiseIn(` / `GoldGlow` / `GoldCurtain`
   零命中(奖励页若确需 rise-in 例外并在 PR 注明);`RollUpCollapse` 保留。
3. 模拟器走查(Claude 收货):Today 点「开始训练」**同帧**切到 Training 且 hero 立即可见,无黑帧
   无幽灵胶囊;Today / Training 首屏内容随数据到达立即出现;反馈卡展开、休息计时器出现硬切,
   动作卡记完全部组仍有卷起收起动效与三段触感;`.plain` 遗留检查:随机抽 tab、列表行、icon、CTA、登录按钮各一,按下均有缩放+变暗。
4. 蓄力:长按可感知 7 段由轻到重,满格 `.success` + 回弹,中途松手 `.warning` + 回退。
5. 奖励页:进入一次 `.success`,盖章一次 heavy impact;开启「减弱动态效果」后奖励页仍走现有降级
   且盖章触感仍触发一次。
6. 教练端任意页按钮按下有同样视觉反馈;列表行、tab 切换不震。
