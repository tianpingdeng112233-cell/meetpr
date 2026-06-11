# 027 — Video upload(学员每组拍/选视频 → 客户端 H.264 转码 → OSS multipart resumable → 教练端可见)

- **状态**: Draft
- **PR**: TBD(iOS spec PR + iOS impl PR + backend OSS endpoint spec/impl PR;跨 repo)
- **来源**:
  - [PRD §5 #14 视频上传](~/Brain/wiki/projects/MeetPR/prd.md) — 默认 60s 最大 120s + 每动作每组都有上传入口 + 本地队列 + 断点续传 + 首次同意"教练可见" + 入库审计
  - [PRD §8.10 视频管线 + v0.7.3 lean 优化](~/Brain/wiki/projects/MeetPR/prd.md) — 客户端 H.264 转码 / 服务端仅主项关键 set 转 H.265 / 1Mbps 码率 / OSS 标准存储
  - [ADR-005 §4 横切关注点 / Resumable Video Upload](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — `Networking/Sources/Networking/VideoUpload/` 模块结构 + `VideoUploadActor` / `UploadTask` / `UploadStateStore` / BackgroundURLSession / 状态机 / exponential backoff
  - [ADR-004 §1 / §4 阿里云 OSS](~/Brain/wiki/projects/MeetPR/decisions/004-backend-selection.md) — OSS 直传 + 签名 URL,bucket `meetpr-videos-prod` 已 provisioned
  - 上游 [spec 024 学员端 P0](../024-student-p0-views/SPEC.md) — `SetRecordRow` 留 affordance,本 spec 加视频附件 UI
  - 上游 [spec 026 backend 真接入](../026-backend-wiring-deploy/SPEC.md) — API access token 路径

## 目标

学员每组在 SetRecordRow 上多一个"📹"按钮 → 弹拍摄/相册 picker → 录或选 ≤120s 视频(默认 60s)→ 客户端转码 H.264 1Mbps 720p → 加入本地上传队列(`Documents/upload_queue/`)→ OSS multipart resumable 后台上传 → 完成后 backend 落 `video_attachment` 表 → 教练端拉学员 set log 时附带视频 URL → 教练端 AVPlayer 播放。

**关键设计**(per ADR-005 §4 + PRD §8.10):
- 健身房网络抖动是常态,视频 50-500MB 上传 80% 断网必须 resume,**不重传整个文件**
- 客户端 H.264 转码 ≠ 服务端 H.265 转码:本 spec **仅** 客户端 H.264;服务端 H.265 转码(MPS)V0.1.x defer(Stage 4 才开,per ADR-004 §11 lean)
- BackgroundURLSession 退后台 / 杀进程也能传(iOS 自动 resume)
- V1 单视频串行(防多 set 同时上传烧 CPU + 带宽);V1.5+ 并发
- **首次** 上传弹同意 dialog "视频将仅你绑定的教练可见" + 用户同意,**入库** 审计(per PRD §5 #14)
- 教练端**仅本 spec 给学员侧 + 学员自看入口**;教练端**看学员视频**入口 = spec 029 教练端 review 内做

## 范围

### 做什么

#### 1. CoreModels 新增 `VideoAttachment`

位置:`Modules/CoreModels/Sources/CoreModels/Entities/Plan/VideoAttachment.swift`(新)

```swift
public struct VideoAttachment: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let planExerciseId: UUID
  public let setIndex: Int
  public let ossKey: String           // bucket 内 path: students/<id>/sets/<setId>/<uuid>.mp4
  public let durationSeconds: Double  // <= 120
  public let fileSizeBytes: Int64
  public let thumbnailOSSKey: String  // bucket 内 path: students/<id>/thumbs/<uuid>.jpg
  public let recordedAt: Date
  public let uploadedAt: Date?        // nil = uploading;非 nil = uploaded
  public let coachVisibleAt: Date?    // 学员同意"教练可见"后填入
  public init(...) { ... }
}
```

#### 2. `Networking/VideoUpload/` 模块新建

per ADR-005 §4 结构:

```
Modules/Networking/Sources/Networking/VideoUpload/
├── VideoUploadActor.swift           # 单 actor 管所有任务
├── UploadTask.swift                  # 单任务 model
├── UploadStateStore.swift            # 持久化 Documents/upload_queue/*.json
├── VideoTranscoder.swift             # AVAssetExportSession 客户端 H.264 转码
├── OSSMultipartClient.swift          # OSS multipart upload 协议层(initiate / uploadPart / complete)
└── BackgroundURLSessionManager.swift # iOS BackgroundURLSession 单例
```

##### 2.1 `UploadTask`

```swift
public struct UploadTask: Codable, Sendable, Identifiable {
  public let id: UUID
  public let videoAttachmentId: UUID
  public let localFileURL: URL          // 转码后文件
  public let ossKey: String
  public var uploadId: String?          // OSS multipart upload ID
  public var partList: [UploadedPart]   // 已上传 chunk 列表
  public var status: Status
  public var lastAttemptAt: Date?
  public var attemptCount: Int
  public var totalBytes: Int64
  public var uploadedBytes: Int64       // 进度

  public enum Status: String, Codable, Sendable {
    case pending      // 转码已完成,等待开始上传
    case transcoding  // AVAssetExportSession 运行中
    case uploading
    case completed
    case paused       // 单 driver cycle 内重试 5 次失败 → 等网络恢复 / 用户重试 → reset attempt count 后 → uploading
    case cancelled    // 学员主动 cancel(调 AbortMultipartUpload 清 OSS server-side state)
  }
  public struct UploadedPart: Codable, Sendable {
    public let partNumber: Int
    public let etag: String
    public let sizeBytes: Int64
  }
}
```

##### 2.2 `VideoUploadActor`

```swift
public actor VideoUploadActor {
  private var tasks: [UUID: UploadTask] = [:]
  private let store: UploadStateStore
  private let oss: OSSMultipartClient
  private let api: APIClient
  private var currentUploadingTaskId: UUID?  // V1 串行

  public init(...) async {
    // 启动时从 UploadStateStore 恢复 pending / uploading / paused 任务
  }

  public func enqueue(localFileURL: URL, attachment: VideoAttachment) async throws -> UploadTask
  public func cancel(taskId: UUID) async
  public func currentProgress(taskId: UUID) async -> Double?
  public func observe() async -> AsyncStream<UploadTask>  // UI 订阅状态

  /// 内部 driver loop
  private func processNext() async { ... }   // 取下一个 pending / paused task → 跑
  private func uploadOnePart(...) async throws -> UploadedPart { ... }
  private func retryWithBackoff(...) async { ... }  // exponential 1/2/4/8/15s,单 cycle 内 5 次
}
```

状态机(per ADR-005 §4 + 2026-05-15 接 PR #115 Codex first-pass non-blocking + second-pass blocker 修订):
```
pending → transcoding → pending(转码完毕) → uploading → completed
                                              ↓ 单 cycle 内重试 5 次(backoff 1/2/4/8/15s)失败
                                          paused(等网络恢复 / app 重启 / 用户手动 → reset attempt count → uploading)
                                              ↓ 用户取消
                                          cancelled(主动 abort multipart upload + 清本地)
```

- **没有 terminal `failed` 状态**(per PR #115 second-pass blocker 决议 B):`UploadTask.Status` enum 已删 `failed` case,所有失败路径直接 `uploading → paused`,没有中间瞬时 `failed` 阶段。之前定义 "attemptCount >= 5 永久 terminal" 会让一次地铁/地下健身房短暂网络抖动就把任务判死,故移除
- 实装:**一个 driver cycle 内**重试 5 次 + backoff 1/2/4/8/15s,5 次仍失败 → 直接转 `paused`;**网络恢复**(`NWPathMonitor` 监听 satisfied)/ **app 重启** / **用户手动 tap "重试"** 任一触发 → attemptCount 清 0 → 回 `uploading`
- `paused` UI 显示:"暂停 · 等网络恢复后自动继续 / [立即重试]"

启动时 `loadAndResume()`:从 `Documents/upload_queue/` 读所有 .json,把 `status ∈ {pending, uploading, paused}` 全部塞回 tasks(此时所有 `paused / uploading`(异常退出)任务 attemptCount 重置为 0),driver loop 自动接管。读到任何**已删除**的旧 `failed` status JSON(persisted 兼容兜底)→ 当 `paused` 处理 + log warning,不崩。

##### 2.3 `OSSMultipartClient`

阿里云 OSS multipart upload 协议:`InitiateMultipartUpload` → `UploadPart × N` → `CompleteMultipartUpload`(或 `AbortMultipartUpload` 清理)。

V0.1 走"backend 代签 + 客户端直传"模式,避免 iOS 端持 AccessKey/SecretKey:

```
iOS                                  Backend                   阿里云 OSS
  │                                     │                          │
  ├── POST /upload/initiate ────────────>                          │
  │   { ossKey, contentType }           │                          │
  │                                     ├── InitiateMultipartUpload│
  │                                     <──────────────────────────┤
  │   <─── { uploadId, presignedParts } ┤  uploadId               │
  │       (per part 一个 presigned URL) │                          │
  │                                     │                          │
  ├── PUT <presignedURL> (part 1) ─────────────────────────────────>
  │   <─── etag1 ───────────────────────────────────────────────────┤
  ├── PUT <presignedURL> (part 2) ─────────────────────────────────>
  │   <─── etag2 ───────────────────────────────────────────────────┤
  │   ...                               │                          │
  ├── POST /upload/complete ────────────>                          │
  │   { uploadId, parts: [{n, etag}] }  │                          │
  │                                     ├── CompleteMultipartUpload>
  │                                     <──────────────────────────┤
  │   <─── { videoAttachmentId, urls } ─┤  最终 OSS 对象就绪       │
```

实装:
- backend 新加 endpoint `POST /upload/initiate` + `POST /upload/complete` + **`POST /upload/sign-parts`(re-sign,本 spec backend §4 详 — 2026-05-15 接 PR #115 review blocker)**
- iOS `OSSMultipartClient` 实装 `initiate` / `uploadPart` / `complete` / **`signParts(uploadId, ossKey, partNumbers)` 用于 resume 重签**,只与 backend + 直接 PUT 到 presigned URL 交互
- chunk size:**5MB**(per OSS multipart 最小 part 限制 100KB,V0.1 选 5MB 平衡 part 数 + 重传粒度)
- 单视频典型 50MB → 10 part;120s 1Mbps 720p ≈ 15MB → 3 part
- **presigned part URL 过期处理**(PR #115 Codex review blocker #1):initiate 返的 presigned URL 默认 1h 过期;若 `VideoUploadActor` 启动 resume 时发现 part PUT 收 `403 SignatureDoesNotMatch` 或 `AccessDenied`,即视为过期,自动调 `signParts(uploadId, ossKey, partNumbersRemaining)` 重签未完成 parts,再继续上传。本机超过 1h 后台/强杀恢复场景必走此路径

##### 2.4 `VideoTranscoder`

```swift
public actor VideoTranscoder {
  /// 转码到 H.264 720p, **best-effort 1Mbps**(per PR #115 Codex review non-blocking)
  /// AVAssetExportSession + AVAssetExportPresetMediumQuality 不精确控 bitrate;
  /// 主方案接受 0.8-2.0 Mbps 范围;验收 step measure 输出码率,若 > 1.5Mbps 才切 AVAssetWriter 路径
  public func transcode(input: URL) async throws -> URL {
    // AVAssetExportSession + AVAssetExportPresetMediumQuality
    // 不假装可精确设 1Mbps;PRD §8.10 lean 目标是"现代 iPhone 客户端转码减服务端负担",码率精度是次要约束
    // 输出 Documents/upload_queue/<uuid>.mp4
  }
  /// 用 AVAssetImageGenerator 抽 1 帧做 thumbnail
  public func generateThumbnail(input: URL) async throws -> URL { ... }
  /// 限时长(per PRD 60s 默认 120s 上限)
  public func enforceMaxDuration(input: URL, maxSeconds: Double = 120) async throws -> URL { ... }
}
```

**转码失败 fallback**(per PR #115 Codex review non-blocking 加强):
- 老 iPhone 上 H.264 转码失败 → **不转码直接上传原始**(graceful fallback)
- **但** fallback 原片可能从 ~15MB 膨胀到 ~200-500MB(120s ProRes / HEVC 原始)
- **UI 必须显式提示**:`VideoCapturePickerSheet` 或 upload row 上显示 ⚠️ "原始视频 ~300MB,蜂窝网络可能耗大量流量,继续上传?[ 仅 Wi-Fi 上传 ] / [ 任意网络上传 ]";学员选"仅 Wi-Fi" → `URLSessionConfiguration.allowsCellularAccess = false`(任务等到 Wi-Fi 才传)

#### 3. `StudentKit` 学员侧视频附件 UI

##### 3.1 `SetRecordRow` 加视频附件按钮

spec 024 既有 layout `[ Wt(灰) ][ reps ][ RPE ][ ✓ ]`,本 spec 加第 5 元素:`[ 📹 ]`(放在最右,✓ 之后)。

- 未上传:灰色 📹 icon
- 上传中:进度环 + 百分比
- 已上传:绿色 ✓ + thumbnail 缩略图 mini(20×20)
- 失败:红色 ⚠️ + "重试" 文案

点 📹 → 弹 `VideoCapturePickerSheet`(下方 sheet):
- `[ 📷 拍摄 ]` → `AVCaptureSession` 拍摄页(60s 默认显示倒计时,120s 自动停)
- `[ 🖼 相册 ]` → `PHPickerViewController`(媒体仅视频,单选)
- `[ 取消 ]`

##### 3.2 隐私同意 dialog(首次)

学员 app 内首次上传视频:
- Modal sheet
- 标题:"视频上传须知"
- 内容:"你上传的训练视频将仅你绑定的教练 David(内测教练)可见。MeetPR 不会向其他人公开你的视频。视频可在《我的资料》撤销可见性(V0.1.x)。"
- `[ 同意上传 ]` / `[ 不上传 ]`
- 同意 → `UserDefaults.set(true, forKey: "video_upload_consent_v1")` + backend `POST /privacy/consent` audit log
- 不同意 → 取消本次上传 + 不持久化(下次仍弹)

`UserDefaults` key 含版本号,V1.5 协议变化时可强制重弹。

##### 3.3 `MyVideoList` 学员自看入口

spec 028 已加 Tab 5 "我的"。本 spec 在该 Tab 加第 2 项 `NavigationLink("我的视频", destination: MyVideoListView(...))`:

- list of `VideoAttachment` 按 recordedAt 倒序
- thumbnail + 动作 + 日期 + 时长 + 上传状态(若 V0.1 失败仍可重试)
- tap → push 到 `VideoPlayerView`(AVKit `VideoPlayer` + 倍速 0.5x/1x/1.5x/2x)

#### 4. backend 侧新加(独立 backend spec)

backend 起 `specs/004-video-upload/SPEC.md`,含:

##### 4.1 endpoints

| Method + Path | Roles | Request | Response |
|---|---|---|---|
| `POST /upload/initiate` | student | `{ planExerciseId, setIndex, contentType, fileSizeBytes }` | `200 { uploadId, ossKey, presignedParts: [{partNumber, presignedURL}] }`(URL 1h 过期) |
| **`POST /upload/sign-parts`(新,per PR #115 review blocker #1)** | student | `{ uploadId, ossKey, partNumbers: [Int] }` | `200 { presignedParts: [{partNumber, presignedURL}] }`(re-sign 未完成 parts,URL 1h 过期) |
| `POST /upload/complete` | student | `{ uploadId, ossKey, parts: [{partNumber, etag}], durationSeconds, thumbnailFileSize }` | `201 VideoAttachment`(含 `videoURL: String` + `thumbnailURL: String` 短期 1h presigned read URL) |
| `POST /upload/abort` | student | `{ uploadId, ossKey }` | `204` |
| `POST /privacy/consent` | student | `{ kind: "video_visibility_v1", agreedAt }` | `204` |
| **`GET /students/:id/videos`(per PR #115 review blocker #2 修订)** | student(self) / coach(owner) | — | `200 { items: VideoAttachmentWithURLs[] }`(每条 `VideoAttachment` 字段 + **`videoURL: String` + `thumbnailURL: String`** 短期 1h presigned read URLs)|

**read URL strategy(per PR #115 review blocker #2)**:私有 OSS bucket 不可公网读;`GET /students/:id/videos` 直接在 response 内为每个视频附**短期 presigned read URL**(1h),iOS 播放器拿到即用。**避免** 单独 `POST /upload/presign-read` round-trip。1h 过期后学员重打开 list 刷新即可拿新 URL — 视频播放器 60-120s 时长内不会过期。

##### 4.2 OSS bucket 配置

bucket `meetpr-videos-prod` 已存在(secrets-pointer §117);本 spec 加 4 项细则(per ADR-004 §6):
- 读写权限:**私有**(预签名 URL 才能访问)
- Referer 防盗链:`*.meetpr.app`(V0.1 OSS 默认域,Stage 3 切自有域)
- CORS:`*` allow PUT 来自 iOS app User-Agent(具体 Codex 实装时按需 narrow)
- 生命周期:90 天后 OSS 标准 → OSS 低频;180 天后 OSS 低频 → OSS 归档(per ADR-005 §4 cost optimization;Stage 4 后启)

##### 4.3 DB schema:`0007-init-video-attachments.sql`

```sql
CREATE TABLE video_attachments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_exercise_id UUID NOT NULL REFERENCES plan_exercises(id) ON DELETE CASCADE,
  set_index       INT NOT NULL,
  oss_key         TEXT NOT NULL,
  duration_seconds NUMERIC(5,2) NOT NULL CHECK (duration_seconds <= 121),
  file_size_bytes BIGINT NOT NULL,
  thumbnail_oss_key TEXT NOT NULL,
  recorded_at     TIMESTAMPTZ NOT NULL,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  coach_visible_at TIMESTAMPTZ  -- 首次同意后填
);
CREATE INDEX idx_video_attachments_student_recorded ON video_attachments (student_id, recorded_at DESC);

CREATE TABLE privacy_consents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_kind TEXT NOT NULL,
  agreed_at   TIMESTAMPTZ NOT NULL,
  user_agent  TEXT,
  ip_address  TEXT,
  UNIQUE (user_id, consent_kind)
);
```

##### 4.4 OSS 签名 URL 生成

backend 用 阿里云 OSS Node.js SDK,服务端持 AccessKey/SecretKey(SAE env var)。所有 presigned URL **统一 1h 过期**(initiate / sign-parts / read 三处均一致)。`POST /upload/initiate` 内:
- 调 `InitiateMultipartUpload(bucket, ossKey)` → 拿 uploadId
- 按预估 part 数(`fileSizeBytes / 5MB`)生成 N 个 presigned URL(用 `signatureUrl` 方法,过期 1h)
- 返 iOS

`POST /upload/complete` 调 `CompleteMultipartUpload(bucket, ossKey, uploadId, parts)`;若失败调 `AbortMultipartUpload` 清理。

#### 5. iOS 集成 + 测试

| 文件 | 覆盖 |
|---|---|
| `Modules/Networking/Tests/NetworkingTests/VideoUpload/VideoUploadActorTests.swift`(新) | enqueue → 转码 → 上传 → completed 整路径;cancel 中途;失败 retry backoff;并发 enqueue V1 串行验证 |
| 同上 `OSSMultipartClientTests.swift` | mock backend signed URLs + mock URLSession;initiate / part upload / complete 各 happy path + 错误 |
| 同上 `UploadStateStoreTests.swift` | save / load / 启动恢复 |
| 同上 `VideoTranscoderTests.swift` | 实际跑 fixture 视频(短 10s 测试用 mp4 in test bundle);时长限制;输出码率约 1Mbps |
| `Modules/StudentKit/Tests/StudentKitTests/Features/VideoAttachmentRowTests.swift` | UI state(未传/传中/已传/失败)切换 |

#### 6. CHECKLIST.md

```
[ ] backend 004 spec + impl 已合 staging
[ ] OSS bucket 4 项配置完成
[ ] backend deploy SAE OSS SDK env vars ready(AccessKey/SecretKey)
[ ] iPhone 学员录 30s 视频 → 转码 → 上传 → 教练 iPhone 看到 thumbnail
[ ] 中途强杀 app → 重开 → 队列自动恢复,继续上传
[ ] 飞行模式 → 录视频 enqueue → 飞行模式关 → 自动 resume
[ ] 同意 dialog 首次弹,二次不弹
[ ] 录满 120s 自动停
[ ] 老 iPhone(SE 2nd gen)转码失败 → fallback 原始上传(蜂窝场景提示 ⚠️ + "仅 Wi-Fi 上传" 选项)→ 成功
[ ] **part URL 过期 → sign-parts 重签**:上传开始后等 65 分钟(超过 backend presigned 1h)→ 强杀 → 重开;Codex tools 或 device 时钟前推模拟;观察 OSSMultipartClient 收 403 后调 sign-parts 重签未完成 parts,上传 resume
[ ] **MyVideoList → 视频播放**:学员上传完一段 → 进"我的视频" Tab → thumb 渲染(thumbnailURL)→ tap 播放(videoURL 1h presigned)→ AVPlayer 起播,倍速 0.5/1/1.5/2x 可切
```

### 不做什么

**V0.1.x defer**:
- 服务端 MPS H.265 转码(主项关键 set;per PRD §8.10;Stage 4 启)
- 并发上传(V1.5,per ADR-005 §4)
- HEIC → H.265 客户端转码(V1.5)
- 元数据 overlay("张三 · 周三 · 深蹲 · 第 4 组 · 100kg×5")— V0.1 仅播放原始视频,overlay 走 SwiftUI 层 V0.1.x
- 倍速 0.5x/1x/1.5x/2x(本 spec **做** 0.5/1/1.5/2 4 档 in `VideoPlayer`;若 AVKit 默认不够再 V0.1.x 自定义)
- 视频反馈(教练在视频上标注 + 时间点反馈)→ V0.1.x evaluation-workflow 阶段
- 视频压缩 progress dialog(本 spec 转码在 background actor,UI 显示进度环;V0.1.x 加 modal)
- 视频删除 / 撤销可见性 — V0.1.x(《我的资料》)

**V0.2+ defer**:
- 视频反馈队列 / 按时间 / 按学员 / 按紧急度排(教练侧 PRD §5 #7)— V0.2 教练 dashboard
- 视频 watermark(防泄漏)
- 海外 CDN(Stage 5+)

## 技术要求

### iOS BackgroundURLSession 集成

```swift
public final class BackgroundURLSessionManager: NSObject, URLSessionDelegate, URLSessionDataDelegate {
  public static let shared = BackgroundURLSessionManager()

  /// 两个 session — wifi-only(用于 fallback 原片 + 用户选"仅 Wi-Fi 上传")和 any-network(默认转码后小文件)
  /// 不能在 single session config 上动态切 allowsCellularAccess(background config 是 immutable),
  /// 故按 task 类型选 session per-PR #115 second-pass non-blocking
  public lazy var anyNetworkSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "app.meetpr.video.upload.any")
    config.allowsCellularAccess = true
    config.isDiscretionary = false
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()
  public lazy var wifiOnlySession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "app.meetpr.video.upload.wifi")
    config.allowsCellularAccess = false
    config.isDiscretionary = false
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  /// iOS app 唤醒 callback(per AppDelegate.application(_:handleEventsForBackgroundURLSession:))
  /// 两 session 任一完成都进此 callback,需按 identifier 分发
  public func handleBackgroundCompletion(identifier: String, completionHandler: @escaping () -> Void)
}
```

`MeetPRApp` 的 `@UIApplicationDelegateAdaptor` 转发 `handleEventsForBackgroundURLSession` 到本 manager。`UploadTask` 加 `preferWifiOnly: Bool` 字段(fallback 原片或学员显式选 → true),`VideoUploadActor` 据此选 session;字段持久化到 `tasks.json`,startup resume 后语义保留。

### chunk size + retry

| 配置 | 值 |
|---|---|
| chunk size | 5MB(OSS 最小 100KB,本 spec 选 5MB 平衡 part 数 + 重传粒度) |
| max parts per upload | 10,000(OSS 上限)— 5MB × 10,000 = 50GB,远超 120s 视频上限 |
| 最大重试 attempts | 5 |
| backoff | 1s → 2s → 4s → 8s → 15s |
| timeout per part PUT | 60s |

### Documents 目录结构

```
Documents/
├── upload_queue/
│   ├── tasks.json          # [UploadTask] 全部任务序列化
│   └── files/<uuid>.mp4    # 转码后文件
└── thumbs/
    └── <uuid>.jpg
```

成功上传后**删除** `files/<uuid>.mp4` 与 `tasks.json` 中对应任务,保留 thumb local cache 加速 list 渲染。

### 隐私同意法律 review 缺口

V0.1 内测期同意文案 = **占位**(Apple §5.1.1 内测不强制法律 review)。**扩到第三人前** 必须法律 review(per spec 025 §不做什么)。本 spec 在 docs 里显式标注 "PLACEHOLDER — needs legal review before public TestFlight",代码内文案集中在 `StudentKit/Resources/PrivacyCopy.swift` 单文件好替换。

### 版本 / 兼容

- iOS 17.0+(`PHPickerViewController` / `AVAssetExportSession` 全 stable)
- 不引第三方 OSS SDK(阿里云 Node SDK 在 backend,iOS 走 presigned URL + URLSession 即可)
- 不引第三方 video player(AVKit `VideoPlayer` 够)

## 验收清单

- [ ] CoreModels `VideoAttachment` Codable + 单测
- [ ] `VideoUploadActor` enqueue → transcode → upload → complete 全路径单测
- [ ] `OSSMultipartClient` initiate / part / complete mock 单测
- [ ] `UploadStateStore` 启动恢复路径单测
- [ ] `VideoTranscoder` 真 fixture 视频转码 single test pass(test bundle 内 5-10s mp4)
- [ ] `SetRecordRow` 视频附件按钮 4 状态视觉验证
- [ ] 隐私同意 dialog 首次弹 / 二次不弹 / agreed_at 入 backend
- [ ] BackgroundURLSession 后台传完成路径(真机或 simulator background 测试)
- [ ] `MyVideoListView` Tab 5 入口加 + list 渲染
- [ ] `VideoPlayerView` AVKit 播放 + 倍速可用
- [ ] backend 004 spec + impl 已合并 staging
- [ ] OSS bucket 配置(读写私 / Referer / CORS / 生命周期)完成
- [ ] CHECKLIST 手动跑 + 飞行模式 + 强杀 app 路径
- [ ] CI 全过(iOS + backend 双 repo)

## 估时(给 Codex 参考)

| 块 | 估时 |
|---|---|
| 1. CoreModels `VideoAttachment` + 单测 | 0.2d |
| 2. `VideoTranscoder` AVAssetExportSession + fixture 测试 | 0.5d |
| 3. `OSSMultipartClient` + 单测 | 1d |
| 4. `VideoUploadActor` + state machine + 启动恢复 | 1.5d |
| 5. `UploadStateStore` JSON 持久化 | 0.3d |
| 6. `BackgroundURLSessionManager` + AppDelegate 转发 | 0.5d |
| 7. `SetRecordRow` 视频附件按钮 + 状态 UI | 0.5d |
| 8. `VideoCapturePickerSheet`(拍摄 / 相册 picker) | 0.5d |
| 9. 隐私同意 dialog + UserDefaults + backend audit | 0.3d |
| 10. `MyVideoListView` + `VideoPlayerView` | 0.7d |
| 11. backend 004 spec 起草(Claude) | 0.5d |
| 12. backend 004 impl(OSS endpoint + DB)(Codex) | 1.5d |
| 13. CHECKLIST + 真机联调 + bug 修 | 1d |
| **合计** | **≈ 9d**(含 0.5d Claude spec 起草) |

## 风险 / 待 implementer 关注

1. **健身房 wifi/4G 抖动是首测试场景**:Codex 实装期必须**真去健身房**或模拟弱网测试(`Network Link Conditioner` Profile = `Edge` / `3G`),不只在 office wifi 测;断网后能 resume 是核心承诺
2. **BackgroundURLSession 唤醒 + AppDelegate 兼容性**:SwiftUI App 转 AppDelegate 转 BackgroundURLSession 是 iOS 17 已知小坑;Codex 实装时优先参考 Apple official sample,避免 lifecycle 漏掉
3. **OSS 公网 IP 出口费**:V0.1 internal user 数据量小,但 `meetpr-videos-prod` bucket 在 cn-hangzhou,出口流量到 iPhone(教练拉视频)走公网 → ¥0.5/GB。每月 < 10GB 视频 cost < ¥5;Stage 4 后切自有域名 + CDN(¥0.2/GB)
4. **AVAssetExportSession quality preset 选择**:`AVAssetExportPresetMediumQuality` 默认 720p 1Mbps 接近 PRD §8.10 lean 目标;但具体码率 iOS API 不暴露 explicit 控制 → Codex 可改用 `AVAssetWriter` + 自定义 video output settings 精确控 1Mbps(更复杂)。本 spec 选 `MediumQuality` 默认值,measure 后若码率 > 1.5Mbps 再换 `AVAssetWriter` 路径
5. **隐私同意法律风险**:V0.1 内测期占位文案不构成法律承诺,但**扩第三人即合同**;扩第三人前 mandatory legal review(本 spec 不阻塞 V0.1 内测期)
6. **教练端看学员视频**:本 spec **不画** 教练端入口;spec 029 教练端 review 内做(展示 `GET /students/:id/videos` + `VideoPlayer`)
7. **视频删除 race**:学员上传中 cancel + 同时 delete app — 中途 abort 可能 leak OSS multipart 残留 → Codex 实装时确保 `AbortMultipartUpload` 始终被调
8. **HEIC 视频** iPhone 默认录 HEVC/HEIC,`AVAssetExportSession` 输出强制 H.264 mp4 — 应当 transcoder 自动处理;但 iCloud Photos relink HEIC 文件可能 transcoder 慢,V0.1 拍摄走 app 内 capture(本 spec)+ 相册走 PHPicker(可能慢)

## Implementation Notes

**2026-06-11 V0.1 实装(feat/027-video-upload)— backend 接口对齐 + scope 裁剪**:

本 spec §2.3/§4 的 backend 接口段写于 backend 004 重设计之前,**已过时**。实际 backend 落地为通用附件管线(`MeetPR-backend/specs/004-attachment-upload/SPEC.md`,PR #17 已合 staging),iOS 按真实 wire 实装:

- **真实端点**:`POST /uploads/initiate`(`{kind:'set_video', content_type, size_bytes, part_count, filename?}` → 201 `{attachment_id, upload_id, part_urls}`)→ 客户端逐片 PUT presigned URL(收 ETag,去引号)→ `POST /uploads/:id/complete`(`{parts:[{part_number, etag}]}`,409 = 终态)/ `POST /uploads/:id/abort`(空对象 body,204)/ `GET /uploads/:id/url`(播放用短期 presigned GET)。原 spec 的 `/upload/initiate`、`/upload/sign-parts`、`/upload/complete`、`GET /students/:id/videos`、`POST /privacy/consent` 均不存在。
- **sign-parts 重签不存在**:backend 004 把 part URL 过期场景定为"client 重新 initiate"(旧 uploading 行成 stale,服务端清理 job out of scope)。iOS 实装一致:重试 = 清 `remoteAttachmentID` 全新 initiate。
- **set_log ↔ attachment 关联是 V0.1 本地限制**:backend `attachments` 表无关联列(004 显式留给消费方)。iOS 侧 `setLogId → attachmentId` 映射存本地 JSON(`Documents/video_attachments/attachments.json`,LocalE1RMRepository 先例),同时 initiate 的 `filename` 带 `setlog-<setLogId>-<localId>.mp4` 供将来服务端反查。**后果:教练端跨设备视频墙(spec 029 消费)需要服务端关联增量才能做**,placeholder 到 029 二遍 / 后续 backend spec。
- **无 BackgroundURLSession / 断点续传(V0.1 裁剪)**:前台上传,5MB 切片并发 PUT(单片失败重试 2 次);app 杀掉后启动时把 `pending/uploading` 记录标 `failed` 可重试(整体重传)。原 spec 的 `VideoUploadActor`/`UploadStateStore`/`paused` 状态机/BackgroundURLSession 双 session 设计随 resumable 一起 defer。
- **隐私同意 V0.1 本地化**:backend 004 把 `privacy_consents` ledger 移交消费方 spec 且尚未实装,故首次上传同意 dialog 只落 `UserDefaults`(key `video_upload_consent_v1`),**无服务端审计**;文案集中在 `VideoPrivacyCopy.swift`(PLACEHOLDER,公测前法律 review)。
- **同样裁剪**:缩略图管线(backend 无 thumbnail kind)、`MyVideoList`/`VideoPlayerView` 学员自看入口、`SetRecordRow` 📹 第 5 元素(入口改在 `SetEntrySheet` 内"视频"区块)、转码失败原片 fallback + 仅 Wi-Fi 选项。转码用 `AVAssetExportSession` 1080p preset(H.264 .mp4,码率 best-effort),≤120s 在 export 前校验。
- **实装件**:CoreModels `VideoAttachment`(本地实体,含 setLogID 关联 + status 状态机 pending/uploading/uploaded/failed);Networking `UploadDTOs`/`APIClient+Uploads`(4 typed 端点)/`OSSPartUploader`(绕过 base URL 直传 OSS,ETag 去引号);RepositoryContracts `VideoAttachmentRepository` + InMemory/Backend 双实现;StudentKit `VideoUploadManager`(actor 状态机)+ `VideoAttachmentViewModel` + `SetEntrySheet` 视频区块(拍摄/相册/进度/重试/删除)+ 首次同意 dialog;Info.plist 相机/麦克风/相册权限文案 + PrivacyInfo 收集声明(PhotosorVideos, linked, AppFunctionality)。

## 上游 / 下游

**上游**:
- spec 024 学员端 P0(`SetRecordRow` affordance)
- spec 026 backend 真接入(access token + APIClient)
- ADR-005 §4 + PRD §8.10 + ADR-004 §1/§4
- 阿里云 OSS bucket `meetpr-videos-prod` ✅ provisioned

**下游**:
- spec 029 教练端 review:复用本 spec 的 `VideoAttachment` + `VideoPlayerView`,展示学员视频 list
- V0.1.x 视频删除 / 撤销可见性(《我的资料》)
- V0.1.x 视频反馈(教练在视频时间点写反馈)— evaluation-workflow 阶段
- Stage 4 MPS H.265 转码 + CDN + cost optimization

## 修订记录

| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-05-15 | 0.1 | 起草。客户端 H.264 + OSS multipart resumable + 单视频串行 + 隐私同意 V1 内测占位 | Claude |
| 2026-05-15 | 0.2 | 接 PR #115 Codex review:**blocker 1** — presigned URL 1h × resumable 跨过 1h 后 part URL 全过期,加 backend `POST /upload/sign-parts` re-sign endpoint + iOS resume 时 403 自动重签;**blocker 2** — 私有 bucket 缺 read URL contract,`GET /students/:id/videos` 直接附短期 1h presigned `videoURL` / `thumbnailURL`,本 spec 学员自看入口直接用;non-blocking — `VideoTranscoder` 改 "best-effort 1Mbps" 描述,移除"精确 H.264 1280×720 1Mbps 30fps" 假象;状态机加 `paused` 替 terminal `failed`,网络恢复 / app 重启 / 用户手动 reset attempt count;fallback 原片 UI 提示 "蜂窝可能耗大量流量" + "仅 Wi-Fi 上传" 选项 | Claude |
| 2026-05-15 | 0.3 | 接 PR #115 Codex **second-pass** review blocker:`UploadTask.Status` enum 已删 `failed`,但 init / driver / 状态图 / resume 注释仍引用 `failed` 字样(自相矛盾)。采纳决议 B 完全移除 `failed`:状态机图删 `failed → 重试` 中间状态,init/processNext 注释改 `pending/uploading/paused`,loadAndResume 接受 `pending/uploading/paused` 且对老 `failed` JSON 做兼容兜底(当 paused 处理 + log)。Non-blocking — CHECKLIST 加 "part URL 过期 → sign-parts" + "MyVideoList 播放" 两条;`BackgroundURLSessionManager` 拆 `anyNetworkSession` + `wifiOnlySession` 两 session(background config immutable,无法 per-task 动态切 allowsCellularAccess),`UploadTask` 加 `preferWifiOnly: Bool` 字段持久化 | Claude |
| 2026-06-11 | 0.4 | **V0.1 实装对齐 backend 004 通用附件管线**:本 spec §2.3/§4 backend 接口段过时,真实 wire = `/uploads/{initiate,:id/complete,:id/abort,:id/url}`(snake_case,presigned multipart,无 sign-parts / 无 `GET /students/:id/videos` / 无 `POST /privacy/consent`);set_log↔attachment 关联 V0.1 仅 iOS 本地 JSON + filename 反查 hint(教练端跨设备视频墙待服务端关联增量,placeholder 029 二遍);BackgroundURLSession 断点续传/缩略图/MyVideoList/原片 fallback 裁剪出 V0.1,杀进程恢复 = 标 failed 可整体重试;隐私同意本地 UserDefaults 无服务端审计。详见 Implementation Notes | Claude |
