# W3 回执 — 记录链路卡（黑金 UI v3）

## 交付范围

- `SetEntrySheet` 重做为 iOS `fullScreenCover`：使用系统安全区承接状态栏高度，
  自带“返回 + 动作名 · 第 x 组”导航行，不再使用 detent sheet。
- 记录页按样机重做配片、重量/次数、RPE、视频、完成/失败和 NumberPad
  呈现；保留既有 `EditingTarget`、VM、Repository、视频上传、PR 检测、
  rest timer 与 analytics 链路。
- `MeetPRNumberPad` 改为 keypad 自有输入缓冲，不再触发系统键盘；重量/次数
  共用 W1 组件及其吸附、范围和确定/取消契约。
- 未修改 VM 逻辑、Repository/网络层、其他屏、CoachKit、
  `CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。

## 样机 DOM / JS → SwiftUI 映射

唯一视觉标准：
`docs/design/handoff-v3/MeetPR 学员端.dc.html` SetEntry DOM 429–521、
`renderVals` 的 `sePlates`、`seTicks`、`seBreakdown`、`padKeys`、`writeSet`
和 SE_RIR，以及 `NumberPad.dc.html`。

| 样机 DOM / JS | SwiftUI 结构 | 映射内容 |
|---|---|---|
| 432–435 | `SetEntryNavigationBar` | 全屏安全区、44pt 返回命中区、居中“动作名 · 第 x 组” |
| 437–460 + `sePlates` / `seBreakdown` | `PlateVisual` + `SetEntryPlateLoadout` | 固定 LTR：58×9 左圆头端帽 → 11×37 杆肩 → 1.5pt 间距片组 → 六角/螺纹套/−34° 斜杆销赛扣 → 92×17 右杆身；`空杠 20kg`、`仅 2.5kg 赛扣` 和分组配片明细逐字映射 |
| 462–476 | `SetEntryValueSection` | 重量/次数标签与步进注记、48pt 金色圆钮、54pt 卡面内 34pt mono 数值；整块数值可打开 NumberPad |
| 478–489 + SE_RIR / `seTicks` | `SetEntryRPEScale` | 32pt 当前值、11 档 RIR 逐字文案、11 条 32/22/13pt 刻度；点击和横向拖动交互保留 |
| 491–496 | `VideoAttachmentV3Content` | “视频”卡面、拍摄/相册金描边按钮；准备、处理、上传、成功、失败、重试、删除和取消仍接既有链路 |
| 500–503 | `SetEntryFooter` | 52pt 金色“完成本组”勾图标 CTA、44pt“未完成 / 失败”文字行 |
| 505–520 + `padKeys` | `MeetPRNumberPad` overlay | 黑色遮罩、点击空白取消、底部圆角弹层、数字/退格/取消/确定；不出现系统键盘 |
| 846–858 `writeSet` | 既有 `commitSet` / `currentRow` | 完成后写入当前组并定位下一未完成组；UI 再次打开时标题、重量、次数、RPE 跟随新组，赛扣按 `openSetEntry` 语义重置为关闭 |

## 状态与行为

- 重量步进继续使用 ±2.5kg，次数继续使用 ±1；NumberPad 分别使用 W1 的
  `.weight` / `.reps` 模式与确定时吸附语义。
- `PlateVisual` 直接接收当前总重量与赛扣状态。无杠片且无赛扣显示
  `空杠 20kg`；只有赛扣时显示 `仅 2.5kg 赛扣`；其余使用
  `PlateVisual.breakdownText` 的同源明细。
- 赛扣是当前 SetEntry 的瞬时状态，每次进入均为关闭；不再从 `AppStorage`
  恢复上次开关。关闭时片组按种分组并以 ` · ` 连接，打开时使用同源片组明细
  加 ` + 2.5kg 赛扣`。
- RPE 保留点击和横向 scrub；垂直滚动手势不抢夺页面滚动。辅助功能仍提供
  adjustable action。
- 完成/失败都先同步当前草稿，再调用既有 `save(failed:)` 链路；没有复制
  `writeSet` 或改动自动跳组算法。
- 视频选择前的草稿同步、首次授权、相机、相册、裁剪、上传、重试、删除和状态
  监听均保留，只替换卡面；无相机模拟器仍显示“拍摄 + 相册”双钮，“拍摄”使用
  disabled 降级语义。
- iOS 使用 `fullScreenCover`；仅为 StudentKit 的 macOS SwiftPM 编译保留
  `.sheet` fallback，不改变 iOS 呈现。
- NumberPad 的值头采用样机 `span` 对应的 SwiftUI `Text`，输入来源是组件内
  数字键而非 `TextField`，从结构上阻止系统键盘与自绘键盘同时出现。

## SE_RIR 与配片文案测试

`SetEntryRPEScaleTests` 锁定全部 11 档：

| RPE | RIR 文案 |
|---:|---|
| 5 | 还能多做 5 次 |
| 5.5 | 还能多做 4-5 次 |
| 6 | 还能多做 4 次 |
| 6.5 | 还能多做 3-4 次 |
| 7 | 还能多做 3 次 |
| 7.5 | 还能多做 2-3 次 |
| 8 | 还能多做 2 次 |
| 8.5 | 还能多做 1-2 次 |
| 9 | 还能多做 1 次 |
| 9.5 | 或许还能多做 1 次 |
| 10 | 力竭，无保留 |

同一测试文件还锁定每档索引和 32/22/13pt 刻度规则。
`SetEntryPlateMathTests` 锁定默认关闭、空杠、仅赛扣、分组杠片和赛扣后缀逐字输出。
`TodayWorkoutPresentationTests` 新增完成第 1 组后自动定位第 2 组的覆盖。

## Preview 覆盖

- `MeetPRNumberPad.swift`：暗色/亮色的 weight、reps 两种模式。
- `SetEntryRPEScale.swift`：暗色/亮色各自遍历全部 11 档。
- `VideoAttachmentV3Previews.swift`：暗色/亮色的相机可用/不可用初始选择、准备、
  处理、上传中、已上传、失败七种状态。
- 配片区由 `SetEntrySheet` 的实时总重和赛扣切换驱动；模拟器已核验有/无赛扣。

App 根当前仍强制暗色；该根主题策略不在 W3 范围内。亮色除成对 Preview 外，
本轮还临时切换根主题在 iPhone 17 Simulator 实跑同一路径，截图后已恢复暗色正典。

## 模拟器全链路

环境：iPhone 17 Simulator，iOS 26.5，`MeetPR-DemoStudent`。

实跑步骤：

1. 从训练记录态打开深蹲第 1 组，确认全屏导航、配片、重量/次数、RPE、视频与
   双底钮。
2. 点击重量卡打开底部 NumberPad，输入 `180` 并确定；系统键盘未出现，重量与
   配片明细同步刷新。
3. 点击 RPE 9.5，文案变为 `或许还能多做 1 次`。
4. 打开赛扣，明细变为
   `25kg × 3 · 2.5kg × 1 + 2.5kg 赛扣`。
5. 点击“完成本组”；第 1 组持久化为 `180kg × 3 @9.5`，训练 hero 自动定位
   `第 2 / 3组`，rest timer 同时出现。
6. 再打开第 2 组，标题和大数切换到该组值，赛扣恢复关闭，NumberPad 仍从底部
   正常弹出。

定向返修第 1 轮补验：

1. 暗色和亮色分别确认配片图从左到右为短圆头端帽、杆肩、片组、可选赛扣、长杆身，
   右杆身没有镜像到左侧。
2. 175kg 初次进入显示 `25kg × 3 · 2.5kg × 1`；打开赛扣显示
   `25kg × 3 + 2.5kg 赛扣`；退出后重进再次显示关闭分支。
3. iPhone 17 Simulator 没有相机，视频行仍同时显示“拍摄”和“相册”；
   “拍摄”为 disabled 降级态，“相册”保持可用。

截图：

- 全屏 SetEntry：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_143b3a0a-4873-4c89-afca-1f2c06f6c6d7.jpg`
- 180kg / RPE 9.5：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_a667f583-fa7d-47b2-a27b-f1b38f6ec7ca.jpg`
- 完成后自动跳第 2 组 + rest timer：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_911311ee-942f-4c20-a597-f8f231743b2e.jpg`
- 第 2 组 NumberPad：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_fc911869-e654-4b87-900f-822370739035.jpg`
- 第 1 轮暗色配片/赛扣默认关闭：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_c073f9bd-14b3-4922-8bbc-8312ac08ee67.jpg`
- 第 1 轮暗色赛扣开启（六角/螺纹套/−34° 斜杆销）：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_11233fee-64ed-4969-9ac2-e6083a04e03b.jpg`
- 第 1 轮暗色视频双钮（无相机，“拍摄”禁用）：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_2a0635b1-752f-4a9b-b5c8-93a5c8f85755.jpg`
- 第 1 轮亮色配片/赛扣默认关闭：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_aa92f8fc-921f-4672-8d05-b1f1f9408d87.jpg`
- 第 1 轮亮色赛扣开启（六角/螺纹套/−34° 斜杆销）：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_3c2fc88a-ab86-4e00-ac85-c6052ca0e0b6.jpg`
- 第 1 轮亮色视频双钮（无相机，“拍摄”禁用）：
  `/var/folders/jj/2g0n2tlj2198ykqylx3w3cp00000gn/T/screenshot_optimized_31be6d9f-6398-4ca7-9a14-44a39df724fe.jpg`

为绕过既有“开始第一组”控件在 rs/1 语义快照中不暴露可点击 target 的限制，
实跑前曾临时将本地 `started` 初值设为 `true`；亮色补验另临时将根主题切为
`.light`。完成验证后已分别恢复为 `@State private var started = false` 和
`.preferredColorScheme(.dark)`，并用最终源码重新构建。两个临时值均不在交付
diff 中。

## 验证

| 检查 | 结果 |
|---|---|
| StudentKit Swift Testing | 509 passed，0 failed，0 skipped |
| 全部 9 个 SPM packages | 1298 passed，0 failed，0 skipped |
| DesignSystem | 60 passed，0 failed |
| `swiftlint lint --strict --quiet --config .swiftlint.yml` | 通过，零输出 |
| `swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` | 通过，零输出 |
| `git diff --check` | 通过，零输出 |
| SetEntry / RPE / Video / NumberPad `LegacyColors` grep | 0 命中 |
| `MeetPR` / `Debug` iOS Simulator build | succeeded，0 warning |
| `MeetPR-Demo` / `Demo` iOS Simulator build | succeeded，0 warning |
| `MeetPR-DemoStudent` / `DemoStudent` iOS Simulator build | succeeded，0 warning；最终源码复跑同结果 |
| DemoStudent 记录一组全链路 | 通过；重量 → NumberPad → RPE → 完成 → 自动跳组 |
| Rest timer / PR / analytics / `EditingTarget` | 既有入口签名和调用链保留 |

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
