# 聊天反馈视频点击回归（spec 060 / 103 / 108）

2026-11-11，David 直驱。用户截图反馈学员聊天中教练反馈视频无法点击。本次为 T1 / P1 调查与回归补齐；未改变产品行为、发布台账或 build 号。

## 结论与版本边界

- 已发布基线 `beta/1.0-35`（`cfbbad09`）的 `Features/Dashboard/StudentBlackGoldChatView.swift` 中，`.feedback` 只渲染 `StudentFeedbackChatCard`；封面为 `ZStack`，未绑定 Button/手势/导航。因此可看到播放图标，却没有点击动作。
- 当前远端 `release/1.0` 基线 `d3892d2e` 已含 `ee27c365`（spec 108，#451）：文件移入 `Features/Coach/`，反馈卡包在 Button 中，设置 selectedFeedback 并通过 navigationDestination 进入 FeedbackDetailView。详情沿用原有带 URL 续签与标注的 FeedbackVideoPlayerView。
- 当前 NEXT-RELEASE 指向 1.0(36)，已列入 spec 108；未核实用户实际安装号，不将截图推断成版本实读。本问题在已发布35的代码上成立，最新候选已有修复，无需重复改生产代码。

## 差分复现与自动化测试边界

临时 `StudentFeedbackChatPlaybackTests.feedbackVideoInChatHasTappableEntry` 使用真实 StudentBlackGoldChatView + 内存仓储载入一条视频反馈，按反馈正文查找所属 Button 并执行点击。该探针已移到 work，不作为正式回归提交，原因见下方审查。

命令：

```sh
swift test --package-path Modules/StudentKit --filter StudentFeedbackChatPlaybackTests
```

差分红测在实际 `.feedback` 调用点临时撤掉最新 Button 外壳，恢复35“只渲染卡片”的缺陷模式（其余108布局保留），同一测试失败：`Search did not find a match`，退出1。恢复生产文件后测试通过（0.139秒）；临时改动已全部还原。首次冷编译时间不计入单测时长。

原始日志位于此工作树 `work/chat-feedback-video/`：`missing-entry-red.log`、`current.log`、`full-tests.log`、`build.log`；差分脚本 `reproduce.py` 使用 finally 还原生产文件，不入库。

## 模拟器自测

工程为本工作树 MeetPR.xcodeproj；scheme/configuration = MeetPR-DemoStudent / DemoStudent；仅使用 iPhone 17e / iOS 26.5（5D5FA360-BA49-48C6-A887-2F0D22F89749）。`build_run_sim` 成功，276.1秒，0 warnings / 0 errors；安装启动 PID 44885。

真实操作：教练 tab → 带视频反馈卡 → 反馈详情 →「播放关联视频」→ 全屏回放。视频画面出现，时间从0:00推进至0:04 / 0:14；两条教练标注可见。素材与仓储为既有 Demo seed，只证明客户端点击/路由/播放器链路，不代表截图用户私有视频或真实签名服务联验。

截图：本聊天 outputs/chat-feedback-video/feedback-detail.jpg、video-playing.jpg。没有临时注入媒体或改 Demo 数据。

## 验证与审查

- 当前代码 StudentKit 全包（含最初探针）1261 tests / 88 suites 通过，29.399秒；swift-format、SwiftLint strict 与 diff-check 通过。
- 使用 review-loop 两个只读独立 reviewer：Standards 发现固定次数 Task.yield 等待不确定（P2）；Spec 发现只检查点击后的已读，不能捕获丢失 selectedFeedback 导航赋值（P2）。均接受。
- 尝试 ViewHosting + 查找实际 FeedbackDetailView，现有 ViewInspector 0.10.3 无法在该 item navigationDestination 上取得已呈现目标，当前正确代码也失败（route-test.log）。无正确且已验证的单测 seam，不为测试改生产架构；撤掉这条自动化探针，不冒充已有完整路由回归。以本次模拟器真实点击/播放证据确认当前行为，未来补 UI automation 时应同时锁住目标页面/播放器。
- 撤下探针后全包重跑1260项出现22个既有视频上传/导出 TimeoutError；生产代码无diff。随后对这22项及反馈视频相关测试执行 `swift test --package-path Modules/StudentKit --skip-build --no-parallel --filter <失败项与反馈测试>`，34项全部通过（1.276秒），详见 targeted-rerun.log。与首次全包绿对照，符合并发负载下超时；未擅改无关测试或断言最终全包全绿。
- 最终交付只有本卡原始调查 JOURNAL；生产代码和测试代码均与基线一致。正典版本台账由 Opus 维护。

## 用户追加：为何还要再点一次

David 在看到反馈详情后追问为何不是直接播放。当前 spec 108 明写“点卡进反馈详情”（§教练 tab，验收3），所以封面的播放图标也触发整卡导航，再点详情中的关联视频才进入播放器。这解释了当前行为，却不消除额外点击。

已向 David 说明：更直接的交互是点视频封面直接播放、点反馈正文进详情。此项属于交互约定调整，需回到 Opus 的 spec，而非将原有108接线当成播放故障继续返修。本次未自行改变该行为。
