# 卡：spec 116 视频角标重做（iOS）

先读仓根 CONTEXT.md、CLAUDE.md、AGENTS.md，再读 `specs/116-video-badge/SPEC.md` 与同目录 `approved-prototype.html`（配图 `approved-prototype.png`）。SPEC 是验收范围的唯一依据，本卡只补 iOS 的落点与约束；二者冲突以 SPEC 为准并在 JOURNAL 里指出。

- 仓库：MeetPR iOS，工作树 `/Users/david/Projects/apps/MeetPR-wt-116-video-badge`，分支 `feat/116-video-badge`，基于 `origin/release/1.0`。只在这个工作树里改。
- 级别：T2，P2（目标 1.0 (45)，不进 44）。
- 模拟器：只用 `iPhone 17e`。动手装包前先看有没有别的会话正在用它；被占用就先做不需要模拟器的部分，并在报告里写明 UI 验证没做、卡在哪。严禁新建或改用其它模拟器，不碰 `iPhone 17 Pro` / `iPhone 17` / `MeetPR-CI`。
- 不 commit、不 push、不开 PR（由 Claude 收货时做）。JOURNAL 写到 `docs/journal/2026-11-28-116-video-badge-ios.md`，写明每条测试先红后绿的证据、未做与未验的项。

## 目标

按 SPEC 一至四节，在 iOS 落地：新角标卡片、带角标存相册（录完 + 回放页）、打点上进度条。

## 现状落点（origin/release/1.0，开工先核实）

- 角标卡片、版式比例、调色、暗渐变、圆盘标记：`Modules/ChatUI/Sources/ChatUI/VideoBadgeCard.swift`；展开收起：`VideoBadgeOverlay.swift`；呈现模型：`VideoBadgeInfo.swift`（`VideoBadgePresentation`）。
- 烧录导出：`VideoBadgeExporter.swift`（`ImageRenderer` 出图 + `AVVideoCompositionCoreAnimationTool`，现在连暗渐变一起烧、带教练名）；存相册：`VideoBadgePhotoLibrary.swift`；回放页导出入口：`FeedbackVideoPlayerActions.swift`（`requestExport` / `startExport`，教练侧有一次性确认）。
- 全屏播放器堆叠：`FeedbackVideoPlayerView.swift` 的 `fullScreenPlayer`：视频 → `VideoBadgeScrim` → 顶栏 → VStack（角标 → `FeedbackVideoMarkerOverlay` 打点面板 → `FeedbackVideoScrubber`）。打点面板在 `FeedbackVideoMarkerOverlay.swift`（黑 72% 底、列表最高 190）。进度条是系统 `Slider`，现在不画打点。
- 教练工作台：`FeedbackVideoWorkbenchPlayer.swift`（270 高舞台、角标固定收起）。**本卡不改它的布局与行为**；只在删除 `VideoBadgeScrim` 时同步去掉它的引用。
- 字标资源：`Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset`（#498 换成了带金章的 SVG）。
- 录制：`Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/CameraRecorderView.swift`。它现在拿不到这一组的任何数据；调用方是 `TodayWorkoutView.swift`（`directCamera(for:)`）与 `VideoAttachmentSection.swift`。存相册在 `useRecording` 里 `VideoLibrarySaver.save(url)`，开关键 `videoRecorder.saveToPhotoLibrary`。
- 带 `badge:` 的播放器调用方：`SetVideoPlaybackView`、`FeedbackDetailView`、`FeedbackInboxView`、`StudentBlackGoldChatView`（反馈视频）、CoachKit 的 `CoachVideoPlayerView` 与 `VideoFeedbackPlayerCard`。

## 要做的事

1. **卡片**：按 SPEC 第一节重写 `VideoBadgeCard` 与 `VideoBadgeLayout`。删除 `VideoBadgeScrim`、金色 RPE 胶囊、教练名一行（`includesCoachAttribution` 一并删）。字标换成 `docs/brand/meetpr-wordmark-plain-on-dark.svg`（原样放进 ChatUI 资源，不重画）；DesignSystem 的 `MeetPRMark` 与各页头字标不动。数字用 `Font.MeetPR.body`（IBM Plex Sans）的 Medium / SemiBold。文件头注释里「设计真源」改指 spec 116。
2. **两种形态**：外传形态无组序；App 内形态带「第 N 组」。用一个明确的入参区分，不要靠隐含条件。
3. **App 内位置与收起**：按 SPEC 第二节。卡片与圆盘靠左；底边在进度条之上并为浮出点评留一行，有无打点位置不变。
4. **导出**：`VideoBadgeExporter` 改用新几何（`scale = min(宽, 高×9/16)/540`，左 44、底 214），只烧卡片。导出仍保持方向、时长、音轨。
5. **回放页存相册**：沿用现有导出入口与教练确认逻辑，按钮图标换成下载箭头；成功提示沿用现有 key。
6. **录完存相册**：把这一组的 `VideoBadgeInfo`（动作名、重量、次数、已填的 RPE；不含组序也可，外传形态本就不显示）从两个调用方传进 `CameraRecorderView`。预览页显示卡片（不可收起）。点「使用视频」时：`onPicked` 与返回训练页不等待导出；开关开着且角标有内容时后台生成带角标版并存相册，失败、取消、后台任务到期都改存原片；开关关着不存；角标无内容时按现状存原片。导出期间源文件不得被 `relinquishReviewFile` 之类的清理删掉；上传用的文件始终是原片。用 `beginBackgroundTask` 争取切后台后跑完。
7. **打点上进度条**：按 SPEC 第四节。删除全屏播放器里的 `FeedbackVideoMarkerOverlay` 面板，原有能力（点一条 = `selectMarker`、带批注显示铅笔、加载失败提示与重试）迁到刻度与浮出点评上；现有无障碍 id 尽量保留在等价控件上。刻度必须与系统 `Slider` 的播放头对齐（播放头在打点时间时盖住刻度）；对不齐就把全屏进度条换成自绘轨道，教练工作台的进度条不动。
8. **字符串**：不新增用户可见文案；需要的都复用现有 key。三种语言下不截断。

## 约束

- 交付红线：不丢用户数据、不让已上线功能失效。普通聊天视频、教练工作台、相册选片上传、裁剪、上传重试的行为不变。
- 不加新依赖；不改后端与接口。
- `swift-format` / SwiftLint 按仓内配置。
- 仓库公开：不得提交任何真实训练视频或截图里带真人的素材；测试只用合成视频。

## 测试 seam（先红后绿，只在这些边界加测试）

1. `Modules/ChatUI/Tests/ChatUITests/VideoBadgePresentationTests.swift`：四种数据状态、外传形态无组序、全空不显示；版式几何纯函数在 1080×1920、1920×1080、1080×1440 下的 scale 与卡片原点。
2. 新增打点时间窗纯函数的测试：2.4 秒边界、相邻打点顶替、空列表、暂停在窗内。
3. `VideoBadgeExporterTests.swift`（复用 `VideoBadgeExportFixture` 合成视频）：方向、时长、音轨保持；卡片区域像素被压暗；画面最底一条不再被压暗（原来断言暗渐变的那条要反过来）。
4. 录制保存编排：把「开关 × 导出成败 → 存哪个文件」抽成可测的小单元（注入导出器与保存器），覆盖开→带角标版、开且导出失败→原片、关→不存，以及交给 `onPicked` 的始终是原片。
5. 其它模块里因删字段而需要同步的现有测试（StudentKit / CoachKit 的角标相关测试）跟着改，不新增。

## 验收（Codex 自测只算开发的一部分）

跑通 ChatUI、StudentKit、CoachKit 相关测试与整包构建；能用模拟器时，用 `MeetPR-DemoStudent` 在 iPhone 17e 上看：回放页展开、收起、存相册提示，带打点的反馈视频刻度与点评，录完预览页。没做到的逐条写进 JOURNAL，不要写成已验证。
