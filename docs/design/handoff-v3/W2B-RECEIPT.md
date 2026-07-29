# W2b 回执 — 训练屏 + 学员 shell 卡（黑金 UI v3）

## 交付范围

- `StudentRootView` 从原生 `TabView` 改为 ZStack 分页 + `MeetPRTabBar`；
  不使用隐藏系统 tab bar 的 workaround，也未设置任何
  `UITabBar.appearance()`。
- `TodayWorkoutView` 保留既有 VM、Repository、SetEntry sheet、视频上传、
  rest timer、PR banner 与 `SessionSummaryView` 链路，只替换训练屏呈现层。
- 新增纯派生 `TodayWorkoutPresentation`、`TodayWorkoutProgress` 与
  `TrainingCalendarScrollState`，并为 presentation、missed 判定和滚动阈值补测试。
- 删除无调用的 `ExerciseExecutionView`、`SetRecordRow`、
  `WorkoutDayHeader`、`PlateMathSheet`、`SlideToCompleteButton` 及
  `SetRecordRow` 对应测试。
- 未修改 VM 逻辑、Repository/网络层、Dashboard、成长、我的、ChatUI、
  CoachKit、AppShell、`CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。

## 样机 DOM → SwiftUI 映射

唯一视觉标准：
`docs/design/handoff-v3/MeetPR 学员端.dc.html` 训练屏 DOM 168–278、
tab bar DOM 422–427，以及 `renderVals` 的 `heroListOn`、`heroRecOn`、
`exBlocks`、`remainText`、`allDone`、`trainCalOpen` 和 `cTodayI` 等派生逻辑。

| 样机 DOM / JS | SwiftUI 结构 | 映射内容 |
|---|---|---|
| 170–177 | `TodayWorkoutHeader` | MEETPR 描边字标、W 码、40pt 自绘刷新/状态/消息圆钮、danger-fill 未读 badge |
| 179–180 + JS 1072 | `TrainingCalendarCollapsedBar` + `TrainingCalendarScrollState` | ScrollView 内 sticky 收起条；`slack > 200 && offset > 56` 收起、`offset < 6` 展开 |
| 182 | `TrainingCalendarView` mode pills | 周选中 `ctaFill`、月选中 `borderStrong`，自绘 pill，不使用系统 segmented picker |
| 184–192 | `MeetPRDayChip` week strip | done/missed/rest/today/future；过去且有计划但未完成才 missed，休息日无红点 |
| 194–206 | `TrainingMonthDay` | 7 列、10pt 圆角、46pt 格；今天 `surfaceElevated` + 1.5pt gold；success/gold/danger 状态点与图例 |
| 208–223 | `TodayWorkoutHero` list mode | 今日训练、动作/组总数、动作预览、`GoldCTA` 开始第一组 |
| 224–237 | `TodayWorkoutHero` recording mode | 当前动作、上次/最佳、当前/完成胶囊、同源组/动作位置、54pt 重量、RPE、教练备注、记录/摄像入口 |
| 239–264 + `exBlocks` | `TodayWorkoutExerciseList` + W1 `ExerciseCard`/`SetRow` | 稳定 row index、受控 collapsed、完成动作默认收纳；失败组 danger 红叉；上传语义映射进 `SetRow.VideoState` |
| 266 + `remainText` | `TodayWorkoutRemainingPill` | 虚线胶囊、时钟、剩余动作/组同源文案 |
| 271–275 + JS 861–863 | `HoldToCompleteButton` | `holdTrack`、50% gold 边、shimmer、按下 0.96、1100ms 金渐变、7 段触觉、松手 300ms 回零、reduce-motion 直接确认 |
| 422–427 + `cTodayI` 等 | `MeetPRTabBar` | `surfaceCard` 底、`borderSubtle` 顶线、安全区合计 83pt 口径；四枚 SVG path 自绘图标；激活 `goldCTA`、未激活 `textTertiary`、我的 badge `dangerFill` |

## 状态与数据决定

- `TodayWorkoutViewModel.State.loaded` 与 `.recording` 继续合并为同一个渲染
  pattern，保留原注释所述的 SetEntry identity 修复。
- 日历点色先看 `TrainingDayProgress.state`：`.noPlan`（包括存在
  `StudentPlanDay` 但 `exercises` 为空）固定为 `rest`，永不进入过去日期的
  `missed` 分支；只有非空计划且未完成的过去日期才是 `missed`。
- 训练页“今天”统一由 `WorkoutDatePolicy.gymDayToday()` 提供，保持该页既有
  04:00 gym-day 口径。今日屏继续使用设备日历日：两者是刻意分开的业务域，
  不是要求跨页统一的同一口径。
- 空 exercises 的选中日直接渲染样机 `selRest` 卡
  `休息日 · 无训练安排`，不创建清单 hero，也不会出现“开始第一组”。
- 清单 hero 门为 UI 层 `started == false` 且没有已记录组；任一已有记录或点击
  “开始第一组”后进入记录 hero。VM 状态与持久化逻辑未改。
- `TodayWorkoutProgress` 是 remaining sets、remaining exercises、当前第几组/
  动作几和 `allDone` 的单一派生源。
- `TodayWorkoutPresentation.record(from:index:videoState:)` 是
  `SetRowDraft → ExerciseSetRecord` 的单一映射；失败组映射 `.failed`，
  上传状态映射 `.none/.uploading/.uploaded/.failed`。
- `ExerciseSetRecord.weight` / `SetRow.weight` 保留 optional；RPE 处方没有
  建议重量时，清单行、54pt hero 主重量和 SetRow 都显示 `—`，不再把 nil
  伪装成 `0`。
- 失败视频的 `SetRow` 摄像入口继续打开既有重试/删除 confirmation dialog；
  其他状态继续进入既有相机或 SetEntry 视频详情路径。
- 训练日历固定周一为每周第一天；计划日期、gym-day 可编辑门与既有
  `WorkoutDatePolicy`/`PlanCalendarDayIdentity` 契约未改。

## W2b 定向返修第 1 轮（7/7）

1. missed / gym-day：修正空计划对象的误判测试；新增非空过去计划 missed、
   空计划 rest、03:30 注入下“前一设备日仍是 gym-day today 且空态仍 rest”
   覆盖。
2. optional weight：presentation 与 DesignSystem 全链路保留 nil，补 RPE
   处方无重量测试。
3. tab shell：四页在同一 `ZStack` 中全部常驻；非当前页仅
   `opacity(0)`、`allowsHitTesting(false)`、`zIndex(0)`，并隐藏其
   accessibility layer。周/月、选中日、started、动作收纳和滚动位置不会因
   tab 往返销毁；presentation 往返测试锁定四层身份，模拟器实跑“月 →
   成长 → 训练”仍回到月态和原选中日。
4. PR banner：top `safeAreaInset` 下沉到 `TodayWorkoutScreen` 层，直接参与
   自绘 header 的 safe-area 计算；常驻 tab 下只在训练页 active 时 surface，
   避免隐藏层先计时并自动消失。实跑截图确认 banner 下方 MEETPR、W 码和三枚
   顶栏钮完整可见。
5. 44pt：三枚顶栏钮、四个 tab item、日历前后翻页箭头和周/月 pill 的命中框
   均至少 44pt；40pt 圆钮与 23pt segmented rail 的视觉尺寸不变。
6. 文案：周条固定 `周一…周日`；sticky 收起条由确定性 formatter 输出
   `七月24日 · 星期五`，并有逐字测试。
7. 像素闸门：
   - `ExerciseCard` 收纳 receipt 保持样机逐字
     `3 组 · 142.5kg×5 @7.5`，12pt mono 单行完整显示；收纳态降低 0.2pt
     tracking、允许 tightening / 最低 0.85 缩放，实跑无截断。
   - DemoStudent 的 `121.09kg` 根因不是单位换算，而是 e1RM demo seed
     错把 `sourceWeightKg` 生成为 `e1RM × 0.88`
     (`137.6 × 0.88 = 121.088`)。已改成各历史点明确的实际组重量，最新深蹲
     为 `142.5kg`；hero 实跑显示
     `上次 142.5kg×5 · 最佳 142.5kg×5` 和 `142.5 KG`。

## W2b 定向返修第 2 轮（6/6，最终轮）

1. sticky 真实滚动力学：
   - 周历/月历始终留在 `ScrollView` 布局树内，不再因展开/收起整块插入或移除，
     避免 content offset 反馈。
   - iOS 18+ 由 `onScrollGeometryChange` 直接读取 content offset、content
     height 与 container height；iOS 17 保留等价 preference fallback。
     状态机继续严格使用样机 JS 1072 的 `offset > 56`、`offset < 6`、
     `contentSlack > 200`。
   - 收起条改为训练屏 overlay，固定在顶部 safe area 下 6pt。DemoStudent
     选中 7 月 24 日并展开动作卡后滚到底，日历滚离而
     `七月24日 · 星期五` 固定出现；反向滑回顶后 sticky 消失、完整月历恢复。
     sticky 截图：
     `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_6b7d60ea-af92-400c-8187-7ca93a86a730.jpg`。
2. `ExerciseCard` 宽度：
   - 移除 `containerRelativeFrame`；由父布局实际 proposal 计算，展开为父可用宽
     100%，收纳为父可用宽 92%，不再拿 ScrollView 全宽叠加 20pt 页边距。
   - 展开/收纳实跑均未越过右侧页边距，摄像图标完整留在卡内。收纳截图：
     `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_d635972c-ac45-4f59-841a-e5020c8d0ee1.jpg`；
     展开截图：
     `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_6c5e6747-7621-4e75-b28e-3d36a9c863b6.jpg`。
3. `SetRow` 尾列：
   - 恢复 `trailingColumnWidth = 64` 与 `iconSpacing = 11` 的样机几何；
     状态图标和摄像图标按 trailing 对齐。
   - 摄像按钮视觉仍为 19pt，仅用 `contentShape` 向外扩展至 44pt 命中区，
     不移动图标。实跑截图：
     `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_6844624d-4a5a-40d3-a9ec-82b7012da88b.jpg`。
4. 常驻 tab 的 a11y 隔离：
   - `StudentTabHostStore` 保留四个 `UIHostingController`，所以周/月、选中日、
     动作收纳与滚动等 SwiftUI 状态继续跨 tab 保持；非当前 controller 的 view
     从容器物理 detach，并同时 disabled/hidden，彻底退出辅助技术树。
   - 新增语义级测试，锁定任意 selection 恰好只有一层参与 accessibility。
     模拟器语义快照：今日页 seq 58 共 120 个节点，只含今日内容与四个 tab；
     月历 → 成长 → 训练返回后的 seq 55 仍保留月历和 31 个日期按钮，且无其他
     隐藏页节点。
5. 今日 tab 图标：
   - 按样机 SVG 分层：双圆主描边 2.3pt；箭杆/箭羽独立描边；中心圆与箭头三角
     均为 `stroke = none` 的纯填充 shape。
   - DemoStudent 实跑截图：
     `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_cac099e6-6f8d-46f3-8354-af39a1aac5e9.jpg`。
6. 周/月 pill：
   - 每个按钮只保留一个 `Text`，删除 Button label 与 overlay 的双重文字；
     未选中项恢复样机 regular 字重。
   - DemoStudent 实跑截图：
     `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_a4dfa6a5-7c52-43d4-b2b9-e8e4f69de15c.jpg`。

## 两处保留件 / 偏离记录

1. 样机顶栏没有 readiness 入口。为不删除既有功能，将其作为刷新与消息之间的
   第三个 40pt 小圆钮保留。
2. `DayCompletionBanner` 暂留并完成 v3 token 化。样机无此件，W4 决定其在结算
   overlay 落地后的最终去留。

PR banner 与 rest timer 也继续沿用既有业务链路；PR banner 改为 top
safe-area inset，避免遮住新的自绘 header。

## W5 钩子

- `ExerciseCard.collapsed` 已改为真正的受控输入，父层按 exercise ID 保存状态；
  完成动作在未显式展开时默认收纳。
- `TodayWorkoutPresentation.Row.stableIndex` 直接来自原 drafts 数组下标，供
  SetEntry 和后续错峰动画稳定寻址。
- hero 容器保留 `matchedGeometryEffect(id: "today-workout-hero", ...)`
  namespace；本卡只做最简 fade。卷折、错峰和完整 morph 参数归 W5。

## Preview 覆盖

`TodayWorkoutV3Previews.swift` 提供以下六种状态的暗色/亮色成对 Preview，
共 12 个：

- 清单态
- 记录态
- 全完成（动作默认收纳 + 长按按钮）
- 只读历史日
- 休息日
- 月历

App 根当前仍在 `MeetPRApp` 强制 `.preferredColorScheme(.dark)`；该文件属本卡
范围外，因此亮色视觉由成对 Preview 验证，未改 AppShell/根主题策略。

## 教练端零改动证明

最终检查：

```text
git diff --name-only | rg 'CoachKit|CODEX-JOURNAL|NEXT-RELEASE|LegacyColors'
# 0 命中

git status --short | rg 'CoachKit|CODEX-JOURNAL|NEXT-RELEASE'
# 0 命中
```

同时未触碰 `LegacyColors.swift`、`CoachRootView` 或任何
`UITabBar.appearance()`。

## 验证

环境：iPhone 17 Simulator，iOS 26.5。

| 检查 | 结果 |
|---|---|
| StudentKit Swift Testing | 500 passed，0 failed，0 skipped；最终结构调整后复跑同结果 |
| 全部 9 个 SPM packages | 1289 passed，0 failed，0 skipped |
| W2b presentation / missed / gym-day / optional target / scroll threshold / tab a11y | 16 passed |
| DesignSystem | 60 passed，0 failed |
| `swiftlint lint --strict --quiet --config .swiftlint.yml` | 通过，零输出 |
| `swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` | 通过，零输出 |
| `git diff --check` | 通过，零输出 |
| 训练主屏 + tab bar `LegacyColors` / 全局 tab appearance / 隐藏系统 tab bar grep | 0 命中 |
| `MeetPR` / `Debug` iOS Simulator build | succeeded，0 warning |
| `MeetPR-Demo` / `Demo` iOS Simulator build | succeeded，0 warning |
| `MeetPR-DemoStudent` / `DemoStudent` iOS Simulator build | succeeded，0 warning |
| DemoStudent 暗色清单态 | 已核验 header、周历、两态 hero A、SVG tab bar 与 badge |
| DemoStudent 暗色月历 | 已核验 46pt 格、今天 gold 描边、状态点和图例 |
| DemoStudent tab 往返 | 月态 + 选中日跨“成长”往返保持 |
| DemoStudent tab a11y | 非当前页从语义快照消失；当前页与四个 tab 为唯一可见层 |
| DemoStudent PR banner | top inset 与 MEETPR / W 码 / 三钮无重叠 |
| DemoStudent 历史深蹲 | reference 与 54pt hero 均为 142.5kg |
| DemoStudent ExerciseCard receipt | `3 组 · 142.5kg×5 @7.5` 单行完整显示 |
| DemoStudent sticky | 展开动作卡滚到底出现 `七月24日 · 星期五`；回顶恢复完整日历 |
| DemoStudent ExerciseCard width | 展开 100% / 收纳 92% 均按父可用宽计算，摄像图标无越界 |
| DemoStudent SetRow | 64pt 尾列、11pt 图标间距与 44pt 摄像命中区实跑通过 |
| DemoStudent 今日图标 / 周月 pill | 填充/描边分层正确；pill 单文字、未选中 regular |

`swift test` 输出仍包含本轮前已存在的 Swift 6 并发与测试锁 warning
（`PlanImportCapability`、`WeightPercentPresets`、`TodayWorkoutViewModel`、
`BindTestSupport`、`OnboardingTestSupport`）；本轮改动文件未新增 warning，
三套 app build 均为 0 warning。

## 未执行

- 未写 `CODEX-JOURNAL.md`。
- 未写 `NEXT-RELEASE.md`。
- 未 commit。
- 未 push。


## 遗留(对质记录,2026-07-27)

- **日历收起态的 rs/1 快照残影**:收起时日历经 opacity(0)+allowsHitTesting(false)+
  accessibilityElement(.ignore)+accessibilityHidden(true) 四重隔离,视觉/触摸/VoiceOver
  三真实通道均正确;但 rs/1 运行时快照读原始视图树,仍会列出日历格节点(图例已真移除故不再出现)。
  彻底消除需把 TrainingCalendarView 内部状态(mode/displayedDate/私有 VM)提升重构 + 等高占位
  防滚动振荡,记为独立跟进卡,不阻塞本卡(review-loop 对质 CONCEDE)。
- **sticky 收起的过渡物理**:当前为「布局槽保留 + 互斥显隐」,与样机「流内塌缩」端态一致、
  过渡路径不同(SwiftUI 无浏览器 scroll-anchoring);流内塌缩 + 滚动补偿归 W5 动效卡。
