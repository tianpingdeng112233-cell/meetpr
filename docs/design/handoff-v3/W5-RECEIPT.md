# 黑金 UI v3 · W5 动效精修回执

分支：`feat/black-gold-ui-v3`

交付方式：仅工作区实装与自检；未 commit、未 push。

## 动效与唯一事实源对照

| 动效 | HTML 唯一事实源 | Swift 实现 |
|---|---|---|
| CTA 蓄力按压 | `motion/01` lines 38、74–80：`.13s ease`、scale `.97`、brightness `1.06`、主/副文案 opacity `.6/.45`、三层 ring/glow | `Modules/DesignSystem/Sources/DesignSystem/Tokens/Motion.swift:29`；`Components/Buttons/GoldCTA.swift:97,109,171,364`；`Tokens/VisualEffects.swift:100–123`；`Components/Buttons/GoldCTAHeldGlow.swift:3` |
| CTA → 训练 hero morph | `motion/01` lines 84–112：源 CTA 隐藏；旧屏 `200ms`、`p²`、y `26`；`140ms` 换屏；目的屏线性淡入 `280ms`；几何与圆角 `28→16` 以 exact easeOutCubic 运行 `420ms`；hero 子项 `220ms`、y `9`、间隔 `55ms`；ghost `200ms` 淡出 | `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift:277,381–466`；`Features/Dashboard/DashboardPrimaryAction.swift:32`；`Modules/DesignSystem/Sources/DesignSystem/Motion/PreciseTweenEffects.swift:95–211`；`TodayWorkout/TodayWorkoutScreen.swift:325–640` |
| 教练反馈展开/收起 | `motion/02` lines 57–78：preview `50ms`；条目 `20+i×30ms`、`200ms`、y `-8`；箭头 `260ms`；展开高度 `380ms` + `p>.62` 三点 sine overshoot；收起 `280ms`；preview `90ms + 180ms` | `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardFeedbackCard.swift:68,169–176,275–397`；纯函数参数在 `Motion.swift:74–86,170–184` |
| 动作卡卷折 | `motion/03` lines 31、37、41、48、58–74：只对 body 运行四段 keyframe offsets `0/.3/.62/1`，rotateX `0/-26/-52/-78`，scaleY `1/.82/.48/.06`，opacity `1/.92/.6/0`，`perspective(760px)`；header 常驻，meta 与外层高度分别压缩；实测收起 header 高度；统一 `620ms cubic-bezier(.4,0,.2,1)`；收起态宽 `92%`、圆角 `14`；展开立即换 DOM，宽度 `280ms`，源码同节点 background `240ms` | `Modules/DesignSystem/Sources/DesignSystem/Motion/RollUpCollapse.swift`；`Components/Cards/ExerciseCard.swift`；独立 header 在 `ExerciseCardHeader.swift` |
| 错峰 riseIn / pillIn | `motion/04` lines 28–35、97–107：direct children `500ms` exact easeOutCubic，opacity `0→1`、y `72→0`、scaleY `.88→1`；今日页 `20+i×40ms`；动作卡 `360+i×90ms`；pill `340ms`、y `-9`、scaleY `.62` | exact tween modifier：`Modules/DesignSystem/Sources/DesignSystem/Motion/PreciseTweenEffects.swift:5–92`；今日页：`DashboardTodayScreen.swift:128–220`；动作卡：`TodayWorkoutScreen.swift:627–634`；pill：`TodayWorkoutScreen.swift:880–889` |
| 完成庆祝 | `motion/05` lines 48–54、64–74：18 sparks、`(i%6)×18ms`、`800ms`；bloom `750ms`；stamp `520ms` 分段；data-slide `340+i×130ms`、`460ms`、y `26`；ticker `470ms + 900ms` quart；data-fade `450ms` | `Modules/DesignSystem/Sources/DesignSystem/Motion/CelebrationEffects.swift:3–144`；`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutCompletionFlowView.swift:90–156,270–361` |

### `motion/03` 参数裁决

任务括号中写有“380ms 收 / 320ms 展 + overshoot”，但可运行参考源码 `03-exercise-rollup.html` line 18 与 lines 64–74 明确规定收起为统一 `620ms cubic-bezier(.4,0,.2,1)`，line 48 的展开是立即重渲染，仅 line 31 保留背景 `240ms`、宽度 `280ms` 过渡，源码没有 overshoot。依“HTML 为唯一事实源”的要求，Swift 实现采用后者，没有混入 380/320 参数。SwiftUI 的展开态与收起态是两个 representation：交接时直接采用各自 background，不虚构跨 representation 的共享 background tween；宽度仍按源码 `280ms` 运行。

## 定向返修第 1 轮

- **B1 · motion/03 卷折对象**：`RollUpBodyModifier` 仅挂到卡片 body；header 不再参与 rotateX / scaleY / opacity。meta 使用独立高度/opacity modifier，外层容器继续按实测 header 高度压缩。background 按上节所述由两个 representation 交接，不把不存在的共享 identity 写成 `240ms` tween。
- **B2 · CTA morph 状态机**：加入显式 phase gate（idle / 旧屏退出 / 等待目的帧 / morph / ghost fade）。切往非预期 tab、离场或运行中开启 Reduce Motion 都会取消两类延迟任务并清空 ghost、source frame、progress、fade，恢复 dashboard CTA。CTA 隐藏时禁 hit testing，进行中重复点击直接忽略。auto-start 先把训练 hero 切到 recording，再开放目的帧 gate；只接受等待态下首个有效 recording hero frame并锁定，不再用 `Task.yield()` 充当 layout barrier。
- **B3 · 反馈卡任务**：展开/收起共用一个可取消 `transitionTask` 与显式 target；每次新动作先取消旧任务，反向点击、离场、Reduce Motion 变化都终止旧写入，快速收起→展开不会并发改 `previewOpacity`。
- **B4 · held glow**：held dark primary 时外层 `.shadow` 不再重复绘制 `74/16` token；最终严格为一层 ring + `9/36`、`16/74` 两层 glow。
- **B5 · riseIn 索引**：metrics 缺失时，E1RM 标题、图表/空态与 CTA 的索引立即前移；所有实际渲染条目保持连续 `20+i×40ms`。
- **nit · 测试入口**：生产 `MeetPRLaunchMorphSpec.state` 直接接收 raw linear clock，内部完成 easeOutCubic 后同时返回 frame 与 corner radius。测试不再预先 easing，并锁定 corner、offset、preview、arrow、destination/ghost/completion fade 参数。

## 定向返修第 2 轮

- **B1 · 历史日 Reduce Motion 直达**：`TodayWorkoutAutoStartGate` 将 auto-start token 挂起；只有选中日期可记录、且该日期的 workout 已加载完成时才消费。历史日同时收到 jump/auto-start 时，日期回正 handler 先清理旧记录态并完成今日数据加载，随后确定进入首组记录态；新增状态机测试锁定“历史日不消费 → 今日加载后消费一次”。
- **B2 · 运行中 Reduce Motion**：
  - `ExerciseCard` 监听 Reduce Motion 开启，立即取消 `rollTask`，并在无动画 transaction 中同步 body、meta、外层高度及展开/收起 representation 到最终态。
  - `MeetPRRiseInModifier` 的 task identity 同时包含 trigger 与 Reduce Motion；开启会取消睡眠中的旧 task 并直置 `progress=1`，关闭后以已完成 trigger 为 gate，不重播、不暴露中间 progress。
  - 反馈卡仅在展开态或准备展开时挂载 expanded representation；收起即从 ZStack 卸载，逐项 delay task 随 view 生命周期取消。
- **B3 · 反馈高度中途反向**：外层实时采集当前呈现高度；每次反向以该高度作为新 tween 的 `h0`，并在同一个无动画 transaction 中更新新端点与归零时钟，避免先跳完整端点再反向。
- **nit · 参数锁定**：补齐 `launchExitDuration`、`feedbackItemInitialDelay`、completion slide 初始延迟/错峰/位移、ticker 延迟，以及 rise/pill 初始 offset 与 scale 的精确 token 测试。

### 第 2 轮自检

| 项目 | 结果 |
|---|---|
| `swift-format lint --strict` | ✅ 27 个改动 Swift 文件，0 finding |
| `swiftlint lint --strict` | ✅ 27 个改动 Swift 文件，0 violation |
| 全量 SPM | ✅ 9 packages，1312 passed，0 failed（新增 auto-start gate + 反馈反向高度 2 个测试） |
| iOS Simulator · Debug / `MeetPR` | ✅ iPhone 17 Pro（iOS 26.5）build succeeded，0 warning |
| iOS Simulator · Demo / `MeetPR-Demo` | ✅ iPhone 17 Pro（iOS 26.5）build succeeded，0 warning |
| iOS Simulator · DemoStudent / `MeetPR-DemoStudent` | ✅ iPhone 17 Pro（iOS 26.5）build succeeded，0 warning |

## Reduced Motion 覆盖

- CTA：按压动画传 `nil` 且不做 `.97` scale；启动直接切训练 tab 并自动开始首组，不创建 source frame、ghost、exit 或 morph 中间态。
- riseIn / hero reveal / sticky pill：modifier 直接把 progress 置为 `1`，不等待 delay。
- 反馈卡：直接切最终展开/收起结构；高度、条目、箭头与 preview 不留 tween 状态。
- 动作卡：直接切最终展开/收起 representation，不运行 3D keyframes。
- 完成庆祝：不生成 sparks；bloom 为结束态、stamp 为最终态；slide/fade/ticker 直接显示最终值。
- 所有延迟任务均在取消或离场时停止；CTA morph 完成后清空 source frame、progress、fade 与 reveal 状态。

## dark-pin 分域拆除

`MeetPR/Sources/MeetPRApp.swift:273–298` 将原全局 `.preferredColorScheme(.dark)` 改为按会话角色决定：

- 未登录、鉴权中、登录流：显式 `.dark`。
- coach：显式 `.dark`，CoachKit 不获得亮色入口。
- coached/self-train student：返回 `nil`，由系统 appearance 决定。
- Demo 与 DemoStudent 仍由各自编译配置注入的 demo user role 走同一分域逻辑，没有 scheme 特判。

`git diff --quiet -- Modules/CoachKit Modules/ChatUI` 为真：CoachKit、ChatUI 零改动。模拟器实跑 `MeetPR-Demo` 后，教练“今日”首屏仍为黑色背景、暗色卡片与暗色 tab bar；随后 `MeetPR-DemoStudent` 实跑并完成 CTA 按压与发射，训练页正常落到首组记录态。

## SwiftUI 与浏览器的可见差距

- SwiftUI 没有 CSS `box-shadow` 的原生 spread 参数；实现保留 HTML 的 blur/spread/opacity 数值，用外扩 stroke + SwiftUI blur 映射。CSS blur `26px` 对应 SwiftUI radius `13pt`，边缘栅格化会有平台级细微差异。
- 浏览器在 `140ms` 回调中同步量取 hero DOM；SwiftUI 需等待目的 view 完成一次 layout 才能取得 global rect，因此 morph 的起点、终点、`420ms` 曲线与圆角完全一致，但在极慢设备上可能比 `140ms` 多一个 render frame 才开始几何 tween。
- CSS `perspective(760px)` 映射为 SwiftUI `m34=-1/760` 的等价 width-relative perspective；Core Animation 与浏览器的抗锯齿可能产生亚像素差异。
- `motion/03` 的 background transition 在浏览器中发生于同一个 DOM 节点；SwiftUI 采用展开/收起两个 representation，交接时使用各自 background，没有伪造共享 tween。宽度 `280ms` 与 body/meta/outer-height 的卷折参数仍逐项对齐源码。

## 定向返修第 3 轮(Claude 接管)

- 初始加载完成后补 `consumePendingAutoStartIfReady()` 消费口(TodayWorkoutView 首次
  `.task`)：CTA 在今日 workout 仍 `.loading` 时点击不再把 token 悬挂——日期不变时这是
  唯一消费入口。
- 完成页 ticker 与 `CompletionFade` 的 `.task` identity 纳入 `reduceMotion`，并加终态闩：
  Reduce Motion 开启即锁定终值（ticker `startedAt=.distantPast`、fade `visible=true`），
  往返切换不重播、不残留睡眠任务。
- `MeetPRMotion.completionSlideDelay(index)` 纯函数取代调用点 `0.34/0.47/0.60/0.73`
  字面量，参数测试直接锁函数输出（motion/05 line 65 `340+i×130ms`）。
- 修订本回执过期验收数字（原 1310/24 段）。

## 定向返修第 4 轮(Claude 接管)

- 终态闩补齐「初始即开启 Reduce Motion」入场态:ticker/fade 的 `.task` 在
  `reduceMotion == true` 分支主动写入终态(`startedAt=.distantPast` / `visible=true`)
  而非仅 return;CelebrationEffects 的 `onAppear` 在 Reduce Motion 下将时钟锁到
  `.distantPast` 并新增 `onChange` 闩——bloom/stamp 读到 progress=1、sparks 已耗尽,
  往返切换不从中间态续播。

## 定向返修第 5 轮(Claude 接管,模拟器实跑发现)

- 冷启动 CTA 卡死修复:CTA 点击首次挂载 TodayWorkoutView 时 `autoStartToken`
  已是新值,`onChange` 不触发、gate 收不到 token,morph 永远等不到 recording
  hero frame(空金框 ghost 卡死,模拟器实跑复现)。初始 `.task` 现在先把当前
  token 交给 gate 再消费。冷启动与暖路径(已挂载走 onChange)均实跑验证落到
  首组记录态。

## 定向返修第 6 轮(Claude 接管)

- `TodayWorkoutAutoStartGate.receive` 改为单调:旧 token 在 `await loadWorkout`
  后重放不得把加载期间收到的更大 pending token 降级(遗留未消费 token 会在
  视图重挂载时无 CTA 重入记录态)。补纯函数测试
  `receive(2)→receive(1)→pending 仍为 2`(StudentKit 520→521)。

## 验收(第 3–6 轮返修后)

| 项目 | 结果 |
|---|---|
| iOS Simulator · Debug / `MeetPR` | ✅ build succeeded，0 warning |
| iOS Simulator · Demo / `MeetPR-Demo` | ✅ build succeeded，0 warning |
| iOS Simulator · DemoStudent / `MeetPR-DemoStudent` | ✅ build succeeded，0 warning |
| 全量 SPM | ✅ 9 packages，1313 passed，0 failed（DesignSystem 63 + StudentKit 521 等） |
| 新增测试 | ✅ raw clock → eased launch geometry/radius；corner/offset/preview/arrow/fade 与 completionSlideDelay 参数锁定；feedback sine overshoot boundary/peak/end |
| `swiftlint lint --strict` | ✅ 0 violation |
| `swift-format lint --strict` | ✅ 0 finding |
| 模拟器动效检查 | ✅ CTA held visual、松开发射、hero reveal、自动进入首组记录，无残留 ghost |
| 范围红线 | ✅ 仅 DesignSystem、StudentKit、MeetPR app 壳与本回执；CoachKit/ChatUI 零 diff |
