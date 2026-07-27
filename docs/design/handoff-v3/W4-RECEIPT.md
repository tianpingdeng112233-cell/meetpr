# W4 回执 — 收官 overlay 卡（黑金 UI v3）

## 交付范围

- 新增全屏结算庆祝流程，替换 hold-to-complete 后直接进入回顾的旧行为：
  `hold → 结算庆祝 → 查看详细报告 → 训练回顾 → 今日`；结算页“完成”可直接回今日。
- `SessionSummaryView` 按 v3 样机重做总容量、PR、动作表现与训练反思，并继续使用
  既有 `SessionReflectionStore` 本地持久化。
- “顺延一天”确认由系统 `Alert` 改为 v3 居中 overlay，确认后仍调用既有
  `shiftToday` / `shiftPlan` 链路。
- 成长页“全部教练反馈”改为全屏 v3 反馈档案，继续使用既有
  `FeedbackInboxViewModel`、已读更新、签名播放 URL 与播放器。
- 未修改 ViewModel、Repository、网络层、CoachKit、工程结构、依赖、
  `CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。

## 样机 DOM / JS → SwiftUI 映射

唯一视觉标准：
`docs/design/handoff-v3/MeetPR 学员端.dc.html` 结算 DOM 570–594、
`doneRef` 1085–1100、`sparks` 984、训练回顾 DOM 523–568、
顺延 DOM 596–604、反馈档案 DOM 606–628。

| 样机 | SwiftUI 结构 | 映射内容 |
|---|---|---|
| 570–594 | `WorkoutCelebrationView` | 全屏 `bg-base`、底部金色径向光晕、bloom、奖牌、标题、教练回执、WnDn / 组数双栏、dnMeta、可选 streak、金 CTA 与“完成” |
| 984 + 1085–1100 | `CelebrationEffects` + completion modifiers | 18 颗 spark 的角度/半径/尺寸/六档延迟/双色规则；750ms bloom、520ms stamp、460ms slide、900ms quart ticker、450ms fade |
| 523–568 | `SessionSummaryView` | 回顾标题与绿胶囊、深金总容量卡、46pt 大数、四格统计、PR 行、动作表现、三栏反思和底部 CTA |
| 596–604 | `PostponeConfirmationOverlay` | 60% 黑遮罩、20pt 圆角 elevated 卡、默认边框、30/60 阴影语义、动态“明天（M/D 周X）”与双胶囊按钮 |
| 606–628 | `FeedbackInboxView` | 全屏档案头、反馈总数、未读金/已读强边框左色条、标签/日期/正文、视频缩略行与既有回放 |

奖牌 SVG 逐段对应样机：左右绶带使用各自渐变，圆盘使用三停金色渐变，
内盘为 `#17120A`，外加半透明金环和圆角金勾。所有新增颜色来自
`Color.MeetPR` token，没有使用 `LegacyColors`。

## 结算聚合与 PR 口径

`WorkoutCompletionPresentation` 是纯呈现边界：

- `flat` 只取已记录组；总容量、总次数、平均 RPE 和动作行均从同一组集合聚合。
- 成功组数 = 已记录组数 − failed 组数；failed 组仍参与样机的容量、次数与
  动作统计，并显示“降重完成 N 组”。
- 主项 RPE 为第一个动作已记录组的平均值；与计划 RPE 相差不超过 0.5 时显示
  “符合计划”，否则显示“高于计划”或“低于计划”。
- 每个动作的最重组按重量优先、同重量次数优先选择；PR 只有在重量超过既有最佳，
  或重量相同且次数更多时成立。
- 教练名使用现有 `activeCoach.coachDisplayName`，直接显示
  “{名}已收到你的训练日志”；名称为空时降级为“教练已收到你的训练日志”，
  `周教练` / `演示教练` 等名称不会重复拼接“教练”。
- streak 以 `Int?` 留在 presentation 接口，生产接线当前传 `nil` 并隐藏胶囊。
  **待 settle 端点上线接回。**

`WorkoutCompletionPresentationTests` 共 9 个 Swift Testing 测试，覆盖：

1. 成功/失败组、容量、次数、主项 RPE、计划符合度与教练名聚合。
2. 更重 / 同重更多次数的 PR 规则，以及未达到最佳时不报 PR。
3. streak 缺失时保持隐藏，以及无教练名降级文案。
4. `周教练` / `演示教练` 两种含“教练”名称的回执形态。
5. 非整数主项与平均 RPE 一位小数，并按 round-half-up 舍入（`8.25 → 8.3`）。
6. 计划 RPE `±0.5` 边界、超过上界与低于下界三态。
7. 整数主项 RPE 按样机 1013 去掉小数（`8`），平均 RPE 仍 `8.0`。
8. 非整数各组平均出精确整值（`7.5/8.5` → `8`）同样去掉小数。
9. 非整数平均值即使舍入到整（`8.9/9` → `9.0`）仍保留一位小数。

## 训练回顾与反思

- 总容量卡使用 `#17120A → surface-card` 深金渐变、金边、46pt 大数及
  `rgba(0,0,0,.35)` 四格统计。
- 有 PR 时显示金色皇冠和“动作名 追平/刷新最佳纪录”；动作行同时显示最重组、
  PR 胶囊及 success / danger 状态色。
- 三栏反思使用多行 `TextField`，标题与 placeholder 逐字对应样机；锁行显示
  “仅自己可见 · 保存在本机”。
- 文本继续按 `studentID + session date` 读写既有 `SessionReflectionStore`；
  模拟器实跑输入后重新进入回顾，内容成功读回。
- 底部“完成 · 回到今日”在关闭 overlay 后通过最小 callback 将根 tab 切回
  `.today`，同时保留原有 review 标记和 analytics。

## 顺延与反馈接线

- 顺延 overlay 仅替换确认呈现；取消顺延、成功提示、失败提示仍使用原逻辑，
  确认后调用原 `shiftToday(proposal)`，没有复制计划移动算法。
- 反馈卡正文或视频播放都会调用既有已读逻辑；播放仍先从
  `FeedbackInboxViewModel.playbackURL` 取签名 URL，再进入既有播放器。
- 当前 `CoachFeedbackVideo` DTO 没有时长字段。呈现模型已保留
  `durationText: String?` 槽位；生产数据为 `nil` 时不伪造时长，待既有数据契约
  提供后可直接显示。没有视频的反馈不渲染视频行。

## Preview 覆盖

`W4V3Previews.swift` 提供暗色 / 亮色成对 Preview：

- 结算：PR + streak、PR + 无 streak、无 PR + streak、无 PR + 无 streak。
- 回顾：有 PR 的完整总容量、动作表现和反思。
- 顺延：动态日期的居中确认 overlay。
- 反馈档案：未读、已读、无视频。

`accessibilityReduceMotion` 开启时，bloom、stamp、spark、slide、ticker、fade
以及 celebration → review 页面切换均跳过 tween，直接呈现最终状态。

## 定向返修第 1 轮

- WnDn、完成组数、总容量大数和四格统计数字字体均改为
  `.MeetPR.display`（Archivo），ticker 与所有大数字继续使用
  `.monospacedDigit()` 保持数字等宽。
- 教练回执不再自行补“教练”前缀；仅空名称使用通用“教练”降级。
- `mainRPEText` / `averageRPEText` 统一固定一位小数，并在格式化前用
  `NSDecimalRound(..., .plain)` 实现 round-half-up。
- celebration → review 的 screen animation 读取
  `accessibilityReduceMotion`，reduce motion 开启时传入 `nil` animation。
- 补齐教练名称、RPE 舍入和计划比较边界测试；未修改上述定向范围外的实现。

## 定向返修第 2 轮

- `mainRPEText` 改为样机 1013 语义：整数主项 RPE 显示为 `8`（无小数位），
  非整数保持一位小数 round-half-up；四格平均 RPE 维持 toFixed(1)。
- 新增整数主项 RPE 与整值平均两条测试（presentation 测试 6 → 8）。

## 定向返修第 3 轮

- 整值判断改为按**原始平均值**（对齐样机 1013 `mainRpe===Math.round(mainRpe)`）：
  只有精确整值走无小数分支；非整数即使舍入到整（`8.95 → 9.0`）也保留一位小数。
- 新增非整数舍入到整仍显示 `9.0` 的测试（presentation 测试 8 → 9）。

## 模拟器全链路

环境：iPhone 17 Simulator，iOS 26.5，`MeetPR-DemoStudent`。

实跑步骤：

1. 进入训练页，依次完成硬拉 3 组（175kg × 3 @8.5）。
2. 长按“完成今日训练”超过 1.1 秒，进入全屏结算；确认奖牌、光晕、18 颗
   spark、动态 W1D1、3/3、教练回执和 dnMeta。
3. 点击“查看详细报告”进入回顾；总容量为 1,575kg，统计为
   1 动作 / 3 组 / 9 次 / 8.5 RPE。
4. 在“本次目标”输入反思，重新进入后确认本地持久化。
5. 点击“完成 · 回到今日”，overlay 关闭并选中“今日”tab。
6. 成长页打开反馈档案，确认全屏呈现、未读/已读色条、无视频分支和视频回放入口。
7. 今日页打开顺延确认，确认动态日期文案、遮罩、卡面和取消/顺延按钮。

截图：

- 结算庆祝：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_49dc5261-a057-429f-b957-9fc12c3cfd49.jpg`
- 训练回顾：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_e049b960-4ff9-49b3-9077-69bbfb853f63.jpg`
- 顺延确认：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_e996263d-9236-4196-a487-698391e7257d.jpg`
- 反馈档案：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_c1a9732f-1d34-40d3-8c8f-2fec9db03208.jpg`

为绕过既有“开始第一组”控件在 rs/1 快照中不暴露点击 target 的限制，实跑前
临时将本地 `started` 初值设为 `true`。完成验证后已恢复为
`@State private var started = false`，并用最终源码完成全部测试和三 configuration
构建；临时值不在交付 diff 中。

## 验证

| 检查 | 结果 |
|---|---|
| `WorkoutCompletionPresentationTests` | 9 passed，0 failed |
| StudentKit Swift Testing | 518 passed，0 failed，0 skipped |
| 全部 9 个 SPM packages | 1307 passed，0 failed，0 skipped |
| DesignSystem | 60 passed，0 failed |
| `swiftlint lint --strict --quiet --config .swiftlint.yml` | 通过，零输出 |
| `xcrun swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` | 通过，零输出 |
| `git diff --check` | 通过，零输出 |
| W4 涉及文件 `LegacyColors` grep | 0 命中 |
| `MeetPR` / `Debug` iOS Simulator build | succeeded，0 warning |
| `MeetPR-Demo` / `Demo` iOS Simulator build | succeeded，0 warning |
| `MeetPR-DemoStudent` / `DemoStudent` iOS Simulator build | succeeded，0 warning |
| 三组完成 → 结算 → 报告 → 今日 | 通过 |
| 反思持久化 / 反馈回放 / 已读逻辑 / 顺延确认 | 既有数据与动作链路保留 |

## 范围审计

最终检查：

```text
git diff --name-only |
  rg 'CODEX-JOURNAL|NEXT-RELEASE|ViewModel|Repository|Networking|CoachKit|project.pbxproj'
# 0 命中
```

- 未写 `CODEX-JOURNAL.md`。
- 未写 `NEXT-RELEASE.md`。
- 未修改 build 号、签名、工程结构或依赖。
- 未 commit。
- 未 push。
