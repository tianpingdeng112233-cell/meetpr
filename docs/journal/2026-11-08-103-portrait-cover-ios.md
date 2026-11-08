# 103 — iOS 学员聊天竖拍反馈封面

日期：2026-11-08。工作树 `MeetPR-wt-103b`，分支 `feat/103b-portrait-cover`，基线 `cd5b1ffa`。本卡唯一需求与验收来源为 `specs/103-chat-timestamps-video-poster/SPEC.md` 的「3. 竖拍视频用竖框」及验收 9–11。按派卡保持未提交，未 commit/push，未改 SPEC 或发布台账。

## 实装

- `ChatVideoCoverPresentation.frameSize(imageSize:availableWidth:)` 纯函数：高大于宽时高 240pt、宽按比例且至少 135pt；横图、正方及缺失图输出可用宽度 × 150pt。
- 首图解码成功后，`ChatVideoPoster` 将图片宽高记录到 `ChatVideoPosterDimensions`。尺寸以视频 UUID 为键、仅内存保存，由 MainActor 隔离并支持 Observation；新建反馈卡同步读取，签名 URL 更新不会改变记忆键。真实加载/解码失败清除该尺寸、回退横框；因滚动或退出导致的取消不清除尺寸。
- `StudentFeedbackChatCard` 只调整大封面，沿原 VStack 左对齐；长动作标签单行尾部省略，标签两侧留边，播放钮与右下时长保持原位。横框宽度继续交给原 SwiftUI 布局填满。
- 44pt 组分享缩略图调用点、导航、依赖、pbxproj 均未改。

## 先红后绿

三个新增测试函数覆盖本卡指定 seam：

1. 竖图 600×800 → 180×240，窄竖图 300×800 → 135×240：`frameSize` 缺失编译红 → 实现竖图分支绿。
2. 横图 800×600、正方 600×600、缺失图，给定可用宽 320 → 320×150：横图与正方断言红 → 增加非竖图回退后绿。
3. 同视频 UUID 存入尺寸后，新卡在加载图片前同步得到 180×240；另一 UUID 无记忆：记忆类型缺失编译红 → 内存记忆实现绿。

逐轮原始日志保存在 `scratch/spec103b/logs/swift_package_test_2026-11-08*.log`，顺序为 04:55:13 红、04:56:00 绿、04:56:05 红、04:56:19 绿、04:56:21 红、04:56:47 绿。

## 自动验证

- ChatUI：95 passed / 0 failed。日志 `scratch/spec103b/logs/swift_package_test_2026-11-08T04-56-52-098Z_pid22423_2e2510de.log`。
- StudentKit：1203 passed / 0 failed。日志 `scratch/spec103b/logs/swift_package_test_2026-11-08T04-57-11-991Z_pid22423_94169e90.log`。全量重编译报告既有并发、未用返回值和不必要 try 警告，均位于本卡未改文件；本卡无新增警告。
- 五个生产/测试 Swift 文件 `swiftlint lint --strict --quiet` 通过，日志 `scratch/spec103b/logs/lint.log`；`git diff --check` 通过。
- 移除 fixture 后最终生产版 `MeetPR-DemoStudent` / `DemoStudent` app build、安装、启动全部成功，282.9 秒，0 warnings/errors。日志 `scratch/spec103b/logs/build_run_sim_2026-11-08T05-04-48-319Z_pid22423_e756a1b7.log`。

## iPhone 17e 自测与证据

仅使用既有 iPhone 17e，iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`。工程为本工作树 `MeetPR.xcodeproj`，scheme `MeetPR-DemoStudent`，configuration `DemoStudent`。

本地生成 JPG：竖图 600×800，横图 800×450；上下绿色/红色边条用于识别裁切。fixture 替换的是实际学员聊天时间线数据，经过实际首图解码、尺寸记忆和反馈卡渲染。图片由临时 bundle 加载分支提供，每次延迟两秒，便于观察加载前后。沙箱禁止本地 HTTP bind，因此未使用 HTTP fixture 服务。

| SPEC 验收项 | 自测结果与仓根相对证据路径 |
| --- | --- |
| 9：竖框完整画面；横拍照旧横框 | `scratch/spec103b/portrait-landscape-light.jpg`：两卡同屏，竖图 180×240、上下边条完整，横图满宽×150，均为 cover。 |
| 10：长标签单行截断，深浅色/大字播放钮可见 | `scratch/spec103b/portrait-landscape-dark-large.jpg`、`scratch/spec103b/portrait-light-large.jpg`：Accessibility 3，省略号在框内，播放钮清楚。`scratch/spec103b/portrait-landscape-light-large.jpg` 补横图大字效果。 |
| 11：滚动、退出重进不再次跳动 | 上下滚动后 `scratch/spec103b/portrait-dark-large-after-scroll.jpg`；退出再进通过临时尺寸观测日志 `scratch/spec103b/logs/reentry-dimensions.log` 核对：首次 APPEAR 高 150 → RESIZE 180×240；第二次 APPEAR 已为 180×240，无第二条 RESIZE。每次图片重新加载仍有两秒延迟，尺寸不依赖重新解码。 |

fixture 源码、两张 JPG 与注入 patch 留在 `scratch/spec103b/fixture-harness/`。截图后已从 Modules 移除 fixture、资源、字体/主题注入与日志语句，并比对还原文件与截图前生产快照完全一致。截图是本地 fixture 自测证据，不代表真实服务端视频联验；本卡范围仅 9–11，未重新定义或重跑验收 1–8。

## 独立审查

按 `review-loop` 对基线 HEAD 的五个目标文件做 Standards / Spec 两路只读审查，一轮均 `VERDICT: CLEAN`，无 blocker、无返修。审查排除临时截图 harness；最终生产改动与审查版本一致。

仓内缺 `docs/agents/issue-tracker.md`，本次使用不依赖 tracker 的本地双轴流程；需补 Matt tracker 时由 David 调用 `$setup-matt-pocock-skills`，未私建配置。以上为开发自测与审查证据，验收由 Opus 按本卡原清单收货。

## 交付

代码及本卡 JOURNAL 的完整补丁：`scratch/spec103b/implementation.diff`。最终仅五个 Swift 文件（含一个新增尺寸记忆类型）、本卡 JOURNAL 和 scratch 证据有变动；未 commit/push。
