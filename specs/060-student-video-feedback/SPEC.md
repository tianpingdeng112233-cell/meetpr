# Spec 060 — 学员端看得见「教练在说哪条视频」

- **状态**:已拍板(David 2026-07-21,「起 W3」;P1,落 `release/1.0` 随 1.0(14) 班车)
- **级别**:T2(跨 CoreModels / Networking / StudentKit / CoachKit 四模块,含新界面)
- **上游**:backend spec 025(`feedback.video_id`,迁移 0046,PR #93)、plan-web PR #27(教练侧写入口)

## 背景

教练在 plan-web 视频弹窗里看完一条动作视频顺手写的反馈,现在带着 `video_id` 落库了
(spec 025)。但学员端**读不出来**:`FeedbackDetailView` 只渲染「关联训练日」,连动作名都不显示;
而且 StudentKit **全模块没有任何视频播放能力**(只有 `Features/VideoUpload/` 一堆上传件,
零 `AVPlayer` / `VideoPlayer`)。字段种下去了,灯还没亮。

同时有一处**双端口径不一致**要一并抹平:教练端 iOS 的 `VideoFeedbackDetailView`(spec 042)
明明是从某一条具体视频点进去写的反馈,发出去时却不带 `video_id`——同一个功能,web 入口有、
iOS 入口没有。不修的话学员端会看到「有些视频反馈能点回视频,有些不能」,而原因对用户完全不可解释。

## 拍板内容

1. **学员反馈详情能看见、并能点开那条视频**。有 `video` 关联时,详情页显示动作名 · 第 N 组 ·
   重量×次数,点击进入全屏播放。
2. **教练端 iOS 从视频写的反馈补上 `video_id`**,与 plan-web 入口同口径。

## 范围

| 模块 | 改动 |
|---|---|
| CoreModels | `CoachFeedback` 加 `videoID: UUID?` 与 `video: CoachFeedbackVideo?`(动作名/组号/重量/次数/记录时间) |
| Networking | `FeedbackDTO` 解出新字段并 `toDomain`;`CreateFeedbackRequestDTO` 加 `videoID` |
| StudentKit | `FeedbackDetailView` 渲染关联视频卡 + 新建学员端播放器 |
| CoachKit | `VideoFeedbackDetailView` 发送路径带上 `videoID` |

**不在范围**:学员端主动给教练发消息(那是聊天波 spec 058);视频列表页;反馈的编辑/删除;
把播放器做成可复用的公共组件下沉 DesignSystem(本波先各自持有,等第三个调用点出现再抽)。

## 接口契约(backend spec 025 已定,照此解码)

`GET /students/:id/feedback` 每条 item 新增:

```jsonc
{
  "video_id": "uuid | null",
  "video": { "id", "exercise_name", "set_index", "weight_kg", "reps", "logged_at" } | null
}
```

- **DTO 字段名写 camelCase**:`MeetPRCodec` 用 `.convertFromSnakeCase` / `.convertToSnakeCase`,
  所以 `video_id` 到手是 `videoId`、`exercise_name` 是 `exerciseName`、`weight_kg` 是 `weightKg`。
  照 `planExerciseID = "planExerciseId"` 的既有写法,**别自己写 snake_case**。
- `weight_kg` 是**字符串**(后端 `NUMERIC(6,2)`,如 `"125.00"`),不是数字。
- `video` 可能为 null(没关联、或视频已删)——**`video_id` 非空但 `video` 为空是合法状态**,
  按「视频已不可用」渲染,不要崩、不要显示半个卡片。

## 播放

- 学员播放自己的视频**不需要后端配套改动**:`GET /uploads/:id/url` 对 owner 本人直接放行
  (`APIClient.attachmentURL` 已存在)。
- 播放器**照抄 `CoachKit/Features/StudentDetail/Videos/CoachVideoPlayerView.swift`**:
  presigned URL 会中途过期,player item 失败要重新签发再重试(那边已踩过这个坑,别重新发明)。
  倍速 0.5/1/1.5/2 一并沿用——学员回看自己的动作同样需要慢放。
- 播放器放 StudentKit 内部,不下沉共享模块(见「不在范围」)。

## 验收

- 学员端:有关联视频的反馈,详情页显示动作名/组号/负荷并可点开播放;`video` 为 null 时详情页
  与改动前一致(只是没有视频卡),不出现空卡片或占位崩溃。
- 教练端 iOS:从训练视频 inbox 写的反馈,请求体带 `videoId`;学员端收到后能点回该视频。
- 老数据(`video_id` 为 null 的历史反馈)渲染不变。
- `swift build` + SPM 测试绿。⚠️ **单测跑 macOS host**,`#if os(iOS)` 包起来的测试会**静默不执行**
  ——新测试别裹在 `#if os(iOS)` 里,否则等于没写。
- 守仓内 `.swiftlint.yml` + `swift-format --strict`。
