# 卡：相册选视频改取原片，去掉系统预转码（iOS 学员端）

先读仓根 CONTEXT.md 与 CLAUDE.md。工作目录 = 本 worktree `/Users/david/Projects/apps/MeetPR-wt-album-original`（分支 `fix/album-import-original`，基于 `origin/release/1.0@68787333`，已含 #463）。级别 T2，优先级 P1（目标 1.0(41)）。

本卡是 Claude 派的任务卡，走 feature 分支 + PR（base = `release/1.0`），**不是** AGENTS.md §发版直推流 的「David 直驱小修」：那节「当前分支必须是发版线」的开工自检不适用，就在当前分支实装；与分支无关的纪律（lint、模拟器白名单）照守。`docs/CODEX-JOURNAL.md`、`NEXT-RELEASE.md`、`RELEASES.md` 不由本卡写。

## 背景与证据

学员从相册选训练视频「选完停在录像页没反应」。#463 只补了等待与失败提示。排查结论（全文 `/Users/david/Projects/scratch/album-upload-audit-20261114/REPORT.md`，证据在同目录 `evidence/`）：

- 三处 `PhotosPicker` 未指定 `preferredItemEncoding`，默认 `.automatic` 实测等同 `.compatible`：原片是 HEVC 时系统先整段转成同分辨率 H.264 才交付。iPhone 17e 模拟器实测：1080p HDR 60 秒等 24.8 秒，4K HDR 45 秒等 61.8 秒；`.current` 均为 0.02 秒交付原片。
- 直接拿原片后，现有导出器对 HDR 源不做色彩转换：10-bit HLG 源导出的 H.264 标记为 `color_space=bt2020nc`、传递函数与原色未标，画面会发灰。
- 剪辑页与导出器都要求「恰好一条视频轨」，多视频轨素材选完即「视频处理失败」。
- 相册导入、剪辑初始化、裁剪导出、上传前导出的失败，iOS 目前一条都不上报。

## 目标

1. **取原片**：三处选择器都显式用 `preferredItemEncoding: .current`。
   - `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/CameraRecorderView.swift`（`PhotosPicker(selection:matching:)`）
   - `.../VideoUpload/VideoAttachmentSection.swift`（`.photosPicker(isPresented:selection:matching:)`）
   - `.../VideoUpload/VideoMissingFileHost.swift`
2. **HDR 源导出成正确的 SDR**：`AVFoundationVideoExporter` 的转码路径，对 HDR/广色域源输出 8-bit BT.709，并在输出上正确标记原色、传递函数、矩阵三项。SDR 源的现有行为与体积口径（长边 ≤1280、码率口径、直通快路判定）不得变化。
3. **多视频轨取主轨**：剪辑页初始化（`VideoTrimView.prepare`）与导出器不再因「视频轨不止一条」拒绝，改为选主视频轨处理；主轨 = 已启用的视频轨里像素面积最大的一条，并列取第一条。零条视频轨仍判失败。最终上传件只含一条视频轨（加可选一条音轨）。
4. **失败上报**：这条链路的失败经现有 Analytics 队列发 `client_error`，`code = video.<stage>.<code>`，与安卓 CN14 同一码制（见 `meetpr-rn` 的 `src/features/training/video-upload/diagnostics.ts`）。stage 至少覆盖：`picker`（`loadTransferable` 抛错或返回 nil）、`trim_info`（剪辑页初始化拒绝或读取失败）、`trim_export`、`duration`（超时长）、`export`（上传前导出）。`code` 只允许有限长度的符号码或数值（如 `NSError` 的 domain 缩写 + code），**不得**上传路径、文件名、原始异常文案或堆栈。用户主动取消、关闭页面后的晚到失败不上报。后端 `client_error` 契约是严格校验的（domain / code / screen 三字段，取值见 backend `src/routes/events/schemas.ts`），不改后端。

## 不做（Out of Scope）

iCloud 下载进度与超时；任何新增或改动的文案与 i18n key；上传、分片、重试、后台续传；「待绑定组的视频显示为失败样式」；相机直拍路径的行为；教练端；后端；版本号、台账。#463 的等待态、失败弹窗、关闭取消逻辑保持原样。

## 约束

- 交付红线：不得让已上线的相机直拍、裁剪、上传、回看失效；`VideoUploadManager` 对源文件的留存与清理语义不动。
- 守仓内 `.swiftlint.yml` 与 `swift-format --strict`（以仓内配置为准）。
- 不加新依赖。测试夹具按仓内现有做法在测试里合成，不提交二进制视频，不依赖 ffmpeg。
- 模拟器只准用 `iPhone 17e`（simulatorName 写死）；不新建、不改用其它机型。
- 本机磁盘只剩约 6G：不要清理本 worktree 之外的任何目录；空间不足就停下并在 JOURNAL 写明卡在哪。

## 测试 seam（先红后绿，只在这些边界加测试）

1. `AVFoundationVideoExporter.export(from:to:)`（`Modules/StudentKit/Tests/StudentKitTests/Features/VideoUpload/` 现有导出测试旁）：
   - 合成一条 10-bit HLG（BT.2020）HEVC 源 → 导出件为 H.264，格式描述里原色 / 传递函数 / 矩阵均为 BT.709。
   - 合成一条含两条视频轨的源 → 导出成功，输出恰好一条视频轨，尺寸对应面积较大的那条。
   - 现有 SDR、直通快路用例全部保持绿。
2. 主轨选择抽成平台无关的纯函数（与 `VideoPassthroughEligibility` 同层），覆盖：单轨、多轨取大、并列取首、含未启用轨、零轨。
3. 失败上报：在现有 Analytics 测试替身上断言各 stage 发出的 `client_error` 载荷（domain / code / screen），以及「取消不报」「载荷不含路径与原始文案」。

选择器策略参数与剪辑页的界面行为无法在宿主测试里断言，由 Opus 收货时在 iPhone 17e 上实测（HEVC/HDR 素材选完进入剪辑页的耗时、多轨素材能进剪辑页并上传、HDR 素材上传件观感），本卡不必尝试驱动模拟器界面。

## 验收

- 上述新测试先红后绿（JOURNAL 里各留一行红、一行绿的命令与结果）。
- `swift test --package-path Modules/StudentKit --parallel` 全绿；`MeetPR-DemoStudent` 在 `iPhone 17e` 上构建通过。
- SwiftLint strict、swift-format lint strict、`git diff --check` 通过。
- JOURNAL 写 `docs/journal/2026-11-14-album-import-original.md`：改了哪些文件、每个目标怎么实现的、测试命令与结果、已知遗留（尤其是没能在真实电影效果模式 / 杜比视界素材上验证的部分要写明）。
- 不 commit、不 push、不开 PR（Opus 收货后做）。

## 返修第 1 轮（2026-11-14，Opus 收货）

收货结果：全量测试本机复跑通过；iPhone 17e 实测 45 秒 4K HEVC 选完约 1 秒进剪辑页、多视频轨素材可进剪辑页并上传；标记完整的 HLG 样本导出件三项均为 BT.709，画面与系统自带 SDR 转换的平均差 0.82/255。以下两处需要改，其余不动。

1. **Spec · picker 阶段的错误码没有信息量**。`VideoProcessingDiagnostics.report(_:error:)` 的域白名单只有 Cocoa / URL / AVFoundation / OSStatus，而 `loadTransferable` 实际抛的是 `CoreTransferable.TransferableSupportError`（#463 的 JOURNAL 里记录过），底层常是 `PHPhotosErrorDomain`（例如 iCloud 原片需要联网）。现在这些全落成 `UNKNOWN_<n>`，等于没报。要求：
   - 域白名单补 `CoreTransferable.TransferableSupportError`、`PHPhotosErrorDomain`、`NSItemProviderErrorDomain`、`CloudPhotoLibraryErrorDomain`，各给一个固定缩写。
   - 顶层错误带 `NSUnderlyingErrorKey` 时，再附一层底层错误的「域缩写_数值」，用 `.` 连接；整段 code 仍须满足后端 `^[A-Za-z0-9_.-]{1,64}$`，超长时截掉底层段而不是整体丢弃。未知域仍是 `UNKNOWN`，任何域名原文、描述、路径都不得出机。
   - 在现有 `VideoProcessingDiagnosticsTests` seam 上先红后绿：上述四个域、带底层错误、超长截断、未知域。
2. **Standards · 取消路径把界面留在「准备中」**。`VideoAttachmentSection.importPicked` 在 `Task.isCancelled` 时直接 return，没有把 `isPreparing` 复位；`VideoMissingFileSheet.importVideo` 同样没有复位 `isImporting`。`.onDisappear` 触发取消后如果视图仍然存活（例如被滚出屏幕后又回来），选片按钮会一直禁用。要求：两处取消分支都把本地占位状态复位；不改变「取消不上报、晚到文件释放」的现有行为。

验收：新增测试先红后绿；`swift test --package-path Modules/StudentKit --parallel` 全绿；`MeetPR-DemoStudent` 在 iPhone 17e 构建通过；lint / format / `git diff --check` 通过。结果追加写在同一份 JOURNAL 末尾。仍然不 commit、不 push、不开 PR。
