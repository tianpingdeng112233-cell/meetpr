# Spec 068 — 自建录制相机（Stance 式）+ 导出直通快路

- **状态**: Approved（David 2026-08-03 拍板「先 B 后 C」两波；本卡=C 波）
- **分级**: T2 / P1（NEXT-RELEASE 候选；PR 等 David 终审）
- **前置**: spec 065 已合入 release/1.0（95d0b32）——本卡直接建立在其导出器之上

## 背景

spec 065 用控码率转码把「拍摄上传慢」压了一个量级，但拍摄链路仍有三个结构性短板：

1. `UIImagePickerController` 是黑盒：录制参数不可控（仍以设备档位录高码率源），录完必须全长
   转码，学员要等一段「处理中」。
2. 「保存到相册」现状=**无条件恒存**（`ea26d94`，`VideoLibrarySaver.save` 挂在
   `VideoAttachmentSection` 与 `TodayWorkoutView` 相机直达两个入口）：学员没有选择权，
   Stance 式的「选择是否保存」缺失。
3. 拿不到相机帧流：未来杠铃 CV 测速的**实时**形态必须吃 `AVCaptureVideoDataOutput` 帧流，
   UIImagePicker 永远给不了。参照 Stance Fitness：app 内自建录制，录完选择是否存相册。

**勘误（2026-08-03 现场核实）**：#269 的 port（`3bfcce0`）曾给旧导出器加过
`AVAssetExportPresetPassthrough` remux 快路，spec 065 重写时被**无意移除**，
`VideoPassthroughEligibility.swift` 现为孤儿文件——本卡 B 部分既是回归修复也是增强
（迁到 reader/writer 直通实现并覆盖自录文件）。

## 目标

### A. 自建录制相机（主体）

新建 `CameraRecorderView`（SwiftUI 全屏，替换 `CameraVideoPicker` 的 fullScreenCover 挂载点），
配套 `RecorderSessionController`（AVCaptureSession 管理）与 `RecorderAssetWriter`（边录边编码）：

- **采集**：`AVCaptureSession` 720p（`.hd1280x720`）；后摄默认；帧率**优先锁 60fps**（设备
  format 支持则 `activeVideoMin/MaxFrameDuration` 锁定，否则 30fps）——CV 前瞻拍板参数。
- **编码**：`AVCaptureVideoDataOutput` + `AVCaptureAudioDataOutput` → `AVAssetWriter` 边录边写，
  视频设置与 spec 065 导出器同口径：H.264、720p、`AVVideoAverageBitRateKey` 2.75Mbps +
  `kVTCompressionPropertyKey_DataRateLimits` 3.5Mbps/1s 硬顶、AAC 96kbps、fast-start mp4。
  **录完的文件即上传就绪**（正好走 B 部分的直通快路，「处理中」近乎归零）。
  样本 PTS 保真透传（CV 前瞻：帧时间戳不重造）。
  **明确不用** `AVCaptureMovieFileOutput`（无码率控制、无帧流 tap 点）。
- **方向**：app 竖屏使用；video connection 设 rotation 90°（iOS 17 `videoRotationAngle` API），
  直接编码 720×1280 竖屏帧，transform 恒 identity——避开 transform 链路。
- **UI（扫视态极简）**：全屏预览 + 大圆录制/停止按钮 + 计时（已录 mm:ss / 上限倒数提示）+
  关闭按钮。`maxDurationSeconds`（现值 120s）到点自动停。停止后进入**回放确认**态：
  `AVPlayer` 循环回放 + 「重拍 / 使用」两键 + 「保存到相册」toggle。
  「使用」→ 回调文件 URL（沿用现有 `onPicked: (URL) -> Void` 形状）+（若开关开）复用
  `VideoLibrarySaver` 写入相册。不做构图辅助线/前摄切换/变焦（后续卡）。
- **权限**：相机/麦克风请求与被拒兜底（被拒→引导去设置的提示态）；相册仅 `.addOnly`
  且只在 toggle 首次打开时请求；四条 usage description 已在 Info.plist，零改动。
- **偏好**：「保存到相册」选择记入 `UserDefaults`，**默认开**（= 保持现行恒存行为，
  Info.plist 文案「素材不能丢」是既有产品承诺；toggle 只是把关掉的权利还给学员），下次预填。
  两个挂载点（`VideoAttachmentSection` + `TodayWorkoutView` 相机直达)行为一致。
- **降级**：无可用相机（模拟器）沿用现有入口判定逻辑隐藏「拍摄」chip（判定从
  `UIImagePickerController.isSourceTypeAvailable` 换成 `AVCaptureDevice` 探测，行为等价）。
- `CameraVideoPicker.swift` 删除（被取代件，git 历史在）。

### B. 导出直通快路（配套，独立可验收）

`AVFoundationVideoExporter` 恢复并增强 **passthrough 判定**：**复用/扩展孤儿化的
`VideoPassthroughEligibility`**（勿另写平行判定），源视频轨 H.264 且长边 ≤1280 且
`estimatedDataRate` ≤3.5Mbps、音频轨（若有）AAC 且 ≤128kbps 时，reader/writer 走
passthrough（`outputSettings: nil`）只重封装为 fast-start mp4，**不重编码**：

- 自建相机录出的文件秒级过「处理中」；
- 相册里本就压缩过的小视频同样受益；
- 判定抽成可单测的纯函数（输入=轨道参数，输出=passthrough/transcode 决策）。
- 任一条件不满足→照旧全量转码（065 路径不动）。

## 文件范围

- 新增 `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/`
  （RecorderView / SessionController / AssetWriter / 权限态等，文件数以清晰为准）
- `VideoAttachmentSection.swift` + `TodayWorkoutView.swift`（相机直达入口）：挂载点换新 view；
  入口可用性判定换 AVCaptureDevice；存相册从「回调后无条件 save」改为 recorder 内 toggle 驱动
- `AVFoundationVideoExporter.swift`（+ 需要的话拆判定文件）：passthrough 快路
- 删除 `CameraVideoPicker.swift`
- 单测：passthrough 判定表（码率/编解码器/尺寸/音频各边界）、直通输出不重编码
  （输出码率≈源码率断言）、writer 设置可测部分
- **不动**：`VideoExporting` 协议、`VideoUploadManager*` 上传管线、consent 弹窗逻辑、
  Info.plist、后端

## 硬约束

1. 上传管线零改动：录出的文件仍走 attach → export（直通）→ 分片 PUT。
2. 120s 上限继续由 `maxDurationSeconds` 参数驱动，别硬编码。
3. 录制中断（来电/切后台/权限中途吊销）必须落干净态：残片删除、session 停止、UI 可重进。
4. 相机相关代码 `#if os(iOS)` 包住（SPM 单测跑 macOS host——测试放包外，passthrough 判定
   等纯逻辑必须在 macOS 可执行，参照 065 测试布局）。
5. 存相册失败（权限拒/磁盘满）不阻塞「使用」主流程：视频照常上传，toast 提示存相册失败。
6. Sendable/actor 隔离守 065 的样式（coordinator 模式参照 `AssetWriterCoordinator`）。

## 验收标准

- 单测：passthrough 判定表全边界 + 直通不重编码断言 + 既有 StudentKit 全绿。
- 模拟器：Demo build 绿 + 无相机降级走查（拍摄 chip 隐藏、相册路径不受影响）。
- 实测（模拟器做不了相机，转码侧代替）：拿 065 测试 fixture 生成的「已达标」源走直通，
  验输出码率≈源码率、moov 前置、秒级完成。
- 真机 smoke（David，切包前）：录 10s → 「处理中」近乎瞬时 → 上传成功 → 教练端可播、
  竖屏方向正确；「保存到相册」开关真落相册、关闭时不落。
- swiftlint --strict + swift-format --strict + build 零违规零 warning。
