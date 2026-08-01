# SPEC 064 — 打点标注帧查看(iOS)

- 状态:APPROVED(⚖️ 2026-08-01 David:标注线永久锚在视频那一帧,学员点打点看到教练画的帧)
- 分级:T2 / P1(1.0(17) 候选);base = release/1.0,分支 feat/marker-annotation-view;PR 不合等 David
- 上游:backend #181(迁移 0055 已应用已部署):marker wire 新增
  `attachment_id: uuid|null`、`annotation_url: string|null`(900s 签名)、`annotation_expires_in: number|null`。
  web 教练端已上线同款(发送标注自动落带图打点)。

## 目标

1. 学员(与教练)在播放器打点列表看到带标注的打点有 ✏️ 徽章;
2. 点击带标注的打点:seek 到该时刻 + **暂停** + 在视频上覆盖显示教练画的标注帧(AsyncImage,黑底 contain);
3. 点击覆盖层关闭,恢复普通播放交互(不自动续播);
4. 无标注的打点行为完全不变(纯 seek)。

## 改动面

- `CoreModels/Entities/VideoMarker.swift`:+`attachmentID: UUID?`、`annotationURL: URL?`、`annotationExpiresIn: Int?`。
  ⚠️ MeetPRCodec convertFromSnakeCase 把 `annotation_url` 转成 `annotationUrl`——属性名要么用 `annotationUrl`,
  要么显式 CodingKey(参照 `videoID = "videoId"` 先例)。**向后兼容:三字段可缺省(旧后端/无标注)解码不失败**——单测锁死。
- `Networking/DTO/VideoMarkerDTOs.swift` + `DomainMapping`:同步三字段。
- `ChatUI/FeedbackVideoMarkerOverlay.swift`(学员+全屏共用列表):带 annotationURL 的行加 ✏️ 徽章;
  点击回调从 `seek(Int)` 扩展为可携带 marker(共享件纪律:可选参数+默认值保持现值,现有调用点行为不变)。
- `ChatUI/FeedbackVideoPlayerView.swift`:新增标注帧覆盖层态(marker 带 annotationURL 被点击时:
  `player.pause()` + seek + 覆盖 AsyncImage;点击关闭)。加载失败(签名过期)→ 关闭覆盖层并触发一次
  `onMarkersRefresh?()` 回调(新可选参数,学员端接到后重拉 markers)。
- `CoachKit` workbench 侧(VideoMarkerList/VideoFeedbackDetailView):同样加徽章与查看(复用同一覆盖层组件或最小实现)。
- 学员端 FeedbackInbox 管线把刷新回调接上(复用现有 markers(videoID:) 拉取)。

## 约束

- 严禁手写 snake_case;共享件改动=可选参数+默认值保持现值,聊天调用点零回归;
- `#if os(iOS)` 里别包关键断言;swiftlint --strict 干净;
- 不 commit 不 push,留未提交 diff 等互审。

## 验收

1. 单测:DTO 三字段有/无解码、DomainMapping、缺省向后兼容;
2. 模拟器(Demo/DemoStudent 显式 configuration):InMemory seed 一条带 annotationURL 的打点(可用本地占位图 URL/file):
   徽章上屏、点击 seek+暂停+覆盖层出现、点击关闭;无标注打点行为不变;
3. 聊天调用点回归不变;CI 绿。
