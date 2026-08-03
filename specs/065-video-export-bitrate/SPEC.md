# Spec 065 — 视频导出显式控码率（上传提速）

- **状态**: Approved（David 2026-08-03 拍板方案 B；T1 单模块）
- **分级**: T1 / P1（NEXT-RELEASE 候选，随 1.0(18) 班车）
- **前置**: 无后端依赖，上传管线零改动

## 背景与根因

学员反馈：app 内拍摄的视频上传特别慢，相册选取的视频却很快。

根因：`AVFoundationVideoExporter`（spec 027）用 `AVAssetExportPreset1920x1080` 转码，
该 preset **无码率控制**，1080p 输入实际输出 ~10 Mbps H.264——2 分钟顶格录制 ≈ 150 MB，
健身房蜂窝上行要传数分钟。相册素材往往本来就小（720p / 已被微信或剪辑压过），
preset 不放大分辨率，所以「相册快、拍摄慢」。动作反馈视频的用途是教练看动作形态，
720p / 2.5-3 Mbps 完全够用。

## 目标

1. 重写 `AVFoundationVideoExporter` 内部实现：`AVAssetExportSession` → `AVAssetReader` +
   `AVAssetWriter`，显式指定输出参数：
   - 视频：H.264，长边 ≤1280（等比缩放，**只降不升**——源短于 720p 保持源分辨率），
     `AVVideoAverageBitRateKey` ≈ 2.5-3 Mbps（可按分辨率微调），帧率保持源帧率不重采样。
   - 音频：AAC ≈ 96 kbps 单声道或双声道跟随源。
   - 容器：fast-start `.mp4`（`shouldOptimizeForNetworkUse = true` 的等效行为，
     AVAssetWriter 有同名属性）。
2. `CameraVideoPicker.videoQuality` 从 `.typeHigh` 降为 `.typeIFrame1280x720`
   （采集端从源头减小临时文件，缩短转码等待）。

预期收益：2 分钟视频从 ~150 MB 压到 ~40-50 MB，上传时间降到约 1/3-1/4；
「处理中」转码等待同步显著缩短。

## 文件范围

- `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/AVFoundationVideoExporter.swift`（主体重写）
- `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/CameraVideoPicker.swift`（一行降档）
- 对应单测（StudentKit tests）

**不动**：`VideoExporting` 协议签名、`VideoUploadManager*` 上传管线、
`VideoAttachmentSection` / ViewModel、后端与分片协议。

## 硬约束

1. **cooperative cancellation 语义保持**：外层 Task 取消 → reader/writer 取消，
   残片文件删除（对齐现实现的 `withTaskCancellationHandler` + 清理路径）。
2. **必须保留源视频方向**：竖屏视频的 `preferredTransform` 要正确落到输出
   （writer input 的 `transform` 或旋转后编码，二选一），否则视频躺倒——
   AVAssetWriter 路径经典坑，单测/实测必须覆盖竖屏源。
3. 源已小于目标（分辨率与码率都低于目标）时不放大；输出始终为 H.264 mp4
   （统一容器，上传 contentType 逻辑不变）。
4. `durationSeconds(of:)` 行为不变。
5. 失败路径沿用 `VideoUploadError.exportFailed(reason)`，错误信息含底层原因。

## 验收标准

- StudentKit 单测：导出成功（文件非空、可读时长）/ 取消后残片清理 / 错误路径。
  注意 SPM 单测跑 macOS host，`#if os(iOS)` 包住的测试会静默不执行——导出器本身
  是跨平台 AVFoundation 代码，测试放在不被 `#if os(iOS)` 排除的位置。
- 实测（模拟器或真机）：≥60s 1080p 源导出后码率 ≤3.5 Mbps、竖屏方向正确、
  QuickTime/播放器可正常播放且 moov 在前（fast-start）。
- `swiftlint --strict` + build 绿；StudentKit 既有测试全绿。
