# SPEC 063 — 视频打点:教练打点 + 学员点击跳转(iOS)

- 状态:APPROVED(实装卡,非 Draft)
- 分级:T2 / P1(随下一班车,进 NEXT-RELEASE 候选)
- base:`release/1.0`(8639ce9),PR 开向 `release/1.0`,不 merge 等 David
- 上游:backend PR #150(`feat/video-markers`,e94b149,迁移 0054;staging 未合,按契约实装,测试用 InMemory)

## 翻案依据(必读)

视频打点曾于 2026-07-28(#116 关闭)与 07-30(coach-v3 CARD-1-shell.md:192、RELEASES.md:53「勿翻案」)两次拍板 deferred。
**2026-07-31 David 明示「开始推进视频打点功能」= 正式重启**,本 spec 即翻案落地。设计不需重做:
`docs/design/coach-v3/MeetPR 教练端.dc.html` 758-803 行(琥珀刻度 + 「＋打点」+ 「打点 · N」列表)与
`CARD-4-video.md:45-49` 当时明令不画的三块,现在原样补回。

## 目标

1. 教练在视频反馈工作台对学员视频打时间点标记(时间 + 级别 + 备注),可删除;进度条上显示琥珀刻度。
2. 学员端回看该视频时看到打点列表(只读),点击任一条即 seek 到对应时间,时间显示同步。

## API 契约(backend feat/video-markers @ e94b149)

- `GET /videos/:videoId/markers`、`POST /videos/:videoId/markers`、`DELETE /videos/:videoId/markers/:markerId`
- **无 PATCH,编辑 = 删重建**
- wire 字段:`{ id, video_id, coach_id, time_ms, level, note, created_at }`
  - `time_ms`:毫秒 Int ≥ 0(不是秒)
  - `level`:`info | warn | bad`,默认 `info`
  - `note`:≤500 字,缺省 `''`(非 null)
  - 列表按 `time_ms` 升序
- 权限:GET 学员可读自己视频;POST/DELETE 仅 coach(DELETE 另要求 accepted bond + 作者本人)
- 错误:`409 ATTACHMENT_NOT_READY` / `404 ATTACHMENT_NOT_FOUND` / `403 AUTHORIZATION_FORBIDDEN`
- 404/网络错时 UI **静默隐藏打点块**(对齐 plan-web 降级策略,端点未部署不炸)

## 文件范围(≈13 文件)

新建:
- `Modules/Networking/Sources/Networking/DTO/VideoMarkerDTOs.swift`
- `Modules/Networking/Sources/Networking/APIClient+VideoMarkers.swift`(样板 `APIClient+StudentVideos.swift`)
- `Modules/CoreModels/Sources/CoreModels/Entities/VideoMarker.swift`(+ `VideoMarkerLevel` enum)
- `Modules/RepositoryContracts/Sources/RepositoryContracts/VideoMarkerRepository.swift`(list/create/delete)
- Backend + InMemory 实现(放共享位置,**避免 CoachKit→StudentKit 依赖**;Backend 实现只依赖 APIClient + SessionStateReader)

修改:
- `Networking/Mapping/DomainMapping.swift`:+`VideoMarkerDTO.toDomain()`
- `ChatUI/FeedbackVideoPlayerView.swift`:暴露 currentSeconds;可选 `markers` + `onSeek` 入参;新增 `seek(toMilliseconds:)`,用 `CMTime(value:timescale:)` + 容差(全仓无任意 seek 先例,唯一先例 L263 `seek(.zero)`)
- `ChatUI/FeedbackVideoWorkbenchPlayer.swift`:progressTrack(L98)叠琥珀刻度 + 「＋打点」按钮(样机 770/778 行)
- `CoachKit/Features/Receiving/VideoFeedbackDetailView.swift` + `VideoFeedbackDetailModel.swift`:加载 markers、打点列表块(插在播放器卡与四宫格之间,样机 790-797)、加/删 action
- 学员端(**路线 2 = 收编共享播放器**,兑现 spec 060「第三个调用点出现再抽」):
  - `StudentKit/FeedbackInbox/FeedbackDetailView.swift` L86-101 fullScreenCover 从 `StudentFeedbackVideoPlayerView` 换成 ChatUI `FeedbackVideoPlayerView`,传 markers + onSeek
  - `FeedbackInboxViewModel` 加 `markers(videoID:)` 拉取(现有 playbackURL 旁)
  - 删除 `StudentFeedbackVideoPlayerView.swift`(166 行)
  - 第二入口 `FeedbackInboxView.swift:31-42` 同播放器,一起换一起验

## 约束 / gotcha

- `MeetPRCodec` 已 `convertTo/FromSnakeCase`:Swift 侧写 `timeMs` / `videoID = "videoId"` / `createdAt`,**严禁手写 snake_case**(spec 060 明文)
- 共享件纪律:`FeedbackVideoPlayerView` 改动 = 可选参数 + 默认值保持现值(CARD-4-video.md:77-78),不得改变 ChatUI 聊天调用点现有行为
- timeline 轮询现仅 workbench 形态跑(`guard workbenchConfiguration != nil`);学员端 seek 后时间显示要能更新——必要时放开该 guard 或按需启动 timeline,但不改聊天全屏形态现状
- 学员端打点列表只读;教练端取 currentSeconds 四舍五入成 `time_ms`
- 新 endpoint 不进 `Endpoints.swift` enum,直接 path 字符串
- SPM 单测跑 macOS host,`#if os(iOS)` 内的测试静默不执行(关键断言别包进去)

## 验收标准

1. 单测:DTO 编解码(snake_case wire)、DomainMapping、repository(InMemory)、`seek(toMilliseconds:)` 换算边界(0、> duration)
2. 模拟器亲验(Demo 构建档须显式 `configuration=Demo`):教练工作台打点 → 刻度上屏 → 列表出现;删除即消失;学员端(DemoStudent)打开带打点视频 → 列表可见 → 点击 seek 到位、时间显示同步
3. 聊天里既有视频播放(教练 + 学员 ChatUI 调用点)行为不回归
4. `swiftlint --strict` 干净,CI 绿;PR 不合并等 David
