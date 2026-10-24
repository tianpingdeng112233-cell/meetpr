# 卡 096-B · iOS 学员端：已完成训练回看视频

先读仓根 `CONTEXT.md`（有则读）、`CLAUDE.md`，再读同目录 `SPEC.md`（正典，共识与口径不得改）和 `SCREENS.html`（已定稿屏幕稿，浏览器打开即可）。

## 目标
SPEC 共识 1–4 在 iOS 学员端落地：已完成训练日总结卡 `CompletedDayOverviewCard`、训练记录页，有视频的组行尾显示播放图标，点开只读播放；被教练点评过的视频播放时右上角显示「教练已点评 ›」，点它跳到学员反馈详情（`FeedbackInbox/FeedbackDetailView`）。

## 屏幕稿转写（一比一）
- 图标：SF Symbol `play.circle`（细线），约 22pt，浅灰 `#9CA3AF`（暗色 `#6B6B72`，进 DesignSystem 颜色 token，别硬编码在视图里），点击区 ≥44pt（`MeetPRSpacing.minimumHitTarget`），放在组行最右；无障碍标签「播放第 N 组视频」。
- 总结卡展开行（`CompletedDayOverviewCard` 里 `exercise.rows` 那段）与训练记录页每组行（含额外组/自加动作）都加；其余布局、间距、文案不动。
- 播放器：复用训练中单组视频播放器，只读模式隐藏删除/重录/换片；可以全屏呈现，左上角关闭，底部进度条与「动作 · 第 N 组 · 重量 × 次数 · RPE」信息行沿用现有。
- 「教练已点评 ›」：画面右上角胶囊标签，半透明深底白字（稿上 rgba(17,24,39,.72)，1px 白 18% 描边，高 30），文案进 StudentKit xcstrings（zh-Hans 源，zh-Hant 走 094 生成流程，en「Coach reviewed」）。

## 口径
照 SPEC「口径」节：数据用现有 `studentVideos` 接口按 set_log_id 对应；上传中/失败沿用 `SetVideoUploadIndicator` 不出播放图标；「已点评」= 学员反馈列表里 video_id 匹配的条目，多条取最新；只有标记无反馈不算。不改后端，不新增接口。

## 文件范围
`Modules/StudentKit/.../TodayWorkout/`（`CompletedDayOverviewCard`、`CompletedDayPresentation`、播放器相关）、训练记录页所在文件、新增一个纯函数（判定「已点评」与「某组可播视频」）、xcstrings、DesignSystem 颜色 token、对应测试。超出此范围先停下在 JOURNAL 写明原因。

## 测试 seam（先红后绿）
照 SPEC「测试 seam」iOS 部分：`CompletedDayPresentation` 每组是否有可播视频单测；「已点评」判定纯函数单测；训练记录 presentation 一例；播放器只读一例。

## 验收
SPEC 验收清单 1–10 中 iOS 部分全部自测；学员 Demo（configuration=Demo）在模拟器截图：总结卡展开带图标、播放中带标签、训练记录页带图标、带历史账号第一屏。截图放 `docs/evidence/spec096-<日期>/`。相关包 `swift test` + 主工程测试全绿，守仓内 .swiftlint.yml + swift-format --strict。

## 交付
JOURNAL 写 `docs/journal/2026-10-24-096-B.md`（做了什么、偏差、证据路径）。不 commit、不 push，留工作区给 Opus 收货。

## 范围补充（2026-10-24 Opus 批，回应 JOURNAL 096-B 首节）
准予以下三处，均只做接线，不改 tab、导航结构或产品行为：
- `StudentRootView.swift`：给 TodayWorkoutView 传反馈依赖、给 TrainingHistoryView 传视频依赖。
- StudentKit `Repository/` 下新增学员侧只读视频仓储，只调用现有 `studentVideos` 与播放地址接口；不改 CoachKit、不改后端。
- `Features/VideoUpload/VideoUploadServices.swift`：组装上述只读视频源，现有上传行为不变。
- Demo fixture：只补本卡截图所需的视频、点评和历史记录。
