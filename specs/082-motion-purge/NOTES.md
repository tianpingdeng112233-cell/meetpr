# spec 082 grep 验收记录

执行范围:`Modules/*/Sources`,仅扫描 `*.swift`,因此不包含 `.build`。

## `TimelineView(.animation`

```text
Modules/DesignSystem/Sources/DesignSystem/Motion/ShimmerOverlay.swift:18:    TimelineView(.animation) { context in
Modules/DesignSystem/Sources/DesignSystem/Motion/CelebrationEffects.swift:15:    TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
```

结果:仅剩 SPEC 允许的 shimmer 原语与奖励页庆祝原语。

## `meetPRShimmer(`

```text
Modules/DesignSystem/Sources/DesignSystem/Motion/ShimmerOverlay.swift:51:  public func meetPRShimmer(_ isEnabled: Bool = true) -> some View {
Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/DayCompletionBanner.swift:32:      .meetPRShimmer()
Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutCompletionFlowView.swift:145:            .meetPRShimmer()
```

结果:除原语定义外,产品用点仅为 `DayCompletionBanner` 与奖励页「查看总结」。

## 已删除符号

查询 `LaunchMorph|launchHeroRevealToken|GoldGlow|GoldCurtain` 无命中。

## `meetPRRiseIn(`

```text
Modules/DesignSystem/Sources/DesignSystem/Motion/PreciseTweenEffects.swift:98:  public func meetPRRiseIn(
Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutCompletionFlowView.swift:349:      .meetPRRiseIn(
```

结果:除原语定义外,仅保留奖励页 `CompletionSlide` 用点,属于 SPEC §A.2 明确例外。

## `RollUpCollapse`

```text
Modules/DesignSystem/Sources/DesignSystem/Motion/RollUpCollapse.swift:97:public struct RollUpCollapseModifier: @preconcurrency AnimatableModifier {
Modules/DesignSystem/Sources/DesignSystem/Motion/RollUpCollapse.swift:259:          RollUpCollapseModifier(isCollapsed: isCollapsed, collapsedHeight: collapsedHeight)
Modules/DesignSystem/Sources/DesignSystem/Components/Cards/ExerciseCard.swift:110:            RollUpCollapseModifier(
```

结果:卷起收起原语与 `ExerciseCard` 用点保留。

## 旧按钮样式

查询 `.buttonStyle(.plain)` / `.borderless` / `LoginButtonStyle` 无命中;`.bordered` / `.borderedProminent` 17 处按 SPEC §B.2 修订保留(系统自带按压高亮)。
