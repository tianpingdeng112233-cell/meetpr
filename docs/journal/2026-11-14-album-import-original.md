# 相册原片导入实装记录 — 2026-11-14

任务卡：[2026-11-14-album-import-original](../cards/2026-11-14-album-import-original.md)。
工作树：`/Users/david/Projects/apps/MeetPR-wt-album-original`；分支 `fix/album-import-original`；起点 `68787333`（含 #463）。T2 / P1。Claude 派卡，本次仅实装与自检，未 commit、push、开 PR；未修改发布台账。

## 实现

1. 三处 PhotosPicker 显式指定 `preferredItemEncoding: .current`，保留 #463 等待态、失败弹窗与录像页关闭逻辑。
2. HDR / 广色域检测覆盖 BT.2020、P3、HLG、PQ。只对这些源强制转码，在 AVAssetReader 解码输出和 AVAssetWriter 编码输出两侧指定 BT.709 三项颜色属性；reader 输出 8-bit YUV，writer 输出 H.264 High。原 SDR 的码率、1280 长边限制、变换、帧率与直通判断不变。
3. 新增平台无关的主轨选择函数：仅在启用轨中按像素面积取最大，同面积取第一条，无候选返回 nil。导出器只接入主视频轨与可选第一音轨。剪辑初始化共用选轨逻辑，多轨预览与缩略图共用仅包含主轨的内存 composition，源文件与 passthrough 裁剪不变。
4. 新增 `VideoProcessingDiagnostics`，复用 `Analytics.shared.track(.clientError)` 队列。载荷仅有 `domain=decode`、`screen=today_workout`、`code=video.<stage>.<symbol>`。覆盖 picker 的 nil/抛错、trim_info 的拒绝/读取失败、trim_export、duration 的超限/读取失败、export 的读取/导出失败。错误码用固定符号或 NSError 域白名单缩写与整数，不发送文件名、路径、描述、堆栈。
5. 上报过滤 Task 取消、CancellationError、URL/Cocoa/AVFoundation 的取消码。picker 任务在页面消失时取消，晚到文件释放；trim 的上报放在既有单次完成认领之后，已经关闭的 session 不再上报。VideoUploadManager 原有源文件留存、清理、分片、重试、上传流程未改。

颜色转换依据：[Apple — Incorporating HDR video with Dolby Vision into your apps](https://developer-mdn.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf)，以及 [Setting color properties for a specific resolution](https://developer.apple.com/documentation/avfoundation/setting-color-properties-for-a-specific-resolution)。按文档在 reader/writer 指定输出色彩，非仅重写文件标签。

契约核对：本地 backend `src/routes/events/schemas.ts` 的 `client_error` 三字段严格校验、code 的 1–64 字符限制；Android 参考工作树 `meetpr-rn-wt-album-export/src/features/training/video-upload/diagnostics.ts`（常规 `meetpr-rn` 目录不存在，未修改其他工作树）。

## 文件清单

以下路径均相对 `Modules/StudentKit/`：

| 文件（Sources 下均位于 StudentKit/Features/VideoUpload） | 改动 |
| --- | --- |
| `Camera/CameraRecorderView.swift`、`VideoAttachmentSection.swift`、`VideoMissingFileHost.swift` | 原片策略、picker 失败上报与晚到结果过滤 |
| `AVFoundationVideoExporter.swift`、`AVFoundationVideoExporter+Passthrough.swift` | 主轨接线、HDR 转码与颜色设置 |
| `AVFoundationVideoExporter+Color.swift`（新增） | HDR / 广色域检测、BT.709 属性 |
| `VideoMainTrackSelection.swift`（新增）、`AVAssetMainVideoTrack.swift`（新增） | 纯选轨算法、AVFoundation 适配及主轨预览 |
| `VideoTrimView.swift`、`VideoTrimThumbnailGenerator.swift` | 主轨初始化、预览与缩略图一致、初始化失败上报 |
| `VideoTrimCompletion.swift` | 单次完成认领后上报裁剪失败，取消后晚到不报 |
| `VideoProcessingDiagnostics.swift`（新增） | 严格载荷、取消过滤、时长读取诊断 |
| `VideoUploadManager.swift`、`VideoUploadManager+PendingSet.swift`、`VideoUploadManager+Replacement.swift` | 三处时长校验上报 |
| `VideoUploadManager+Pipeline.swift` | 上传前读取/导出失败上报 |
| `Tests/StudentKitTests/Features/VideoUpload/VideoMainTrackSelectionTests.swift`（新增） | 单轨、多轨、并列、未启用、零轨/全未启用 |
| 同目录 `AlbumVideoExportTests.swift`、`HDRVideoExportFixture.swift`（新增） | 合成双轨 / 10-bit HLG HEVC 的导出回归，无二进制夹具与 ffmpeg |
| 同目录 `VideoProcessingDiagnosticsTests.swift`（新增） | 现有 AnalyticsCore/EventQueueStore 测试替身验证所有阶段三字段、隐私、取消 |

共 20 个 Swift 文件（12 个修改、8 个新增），另加本 JOURNAL。任务卡为接手时已有的 untracked 文件，未改动。

## 红 → 绿

测试均经 XcodeBuildMCP `swift_package_test`，`packagePath` 固定本 worktree 的 `Modules/StudentKit`。下表命令为对应 SwiftPM 命令；日志目录为：

`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-album-original-4e034ff308a4/logs/`

| 回合 | 命令 | 结果与日志 |
| --- | --- | --- |
| 主轨红 | `swift test --package-path Modules/StudentKit --filter mainVideoTrackSelection` | 缺少 `VideoTrackCandidate` / `VideoMainTrackSelection`，编译失败；`swift_package_test_2026-11-14T04-07-17-772Z_pid81740_9e2e6ae3.log` |
| 主轨绿 | 同上 | 1 测试通过（含六组断言）；`swift_package_test_2026-11-14T04-08-35-639Z_pid81740_2dd7b4d6.log` |
| 多轨红 | `swift test --package-path Modules/StudentKit --filter albumExportSelectsMainTrack` | 合成两条视频轨成功，生产导出抛 `Expected exactly one video track`；`swift_package_test_2026-11-14T04-09-22-541Z_pid81740_4767e953.log` |
| 多轨绿 | 同上 | 1 测试通过，输出只有一视频轨且为较大轨的 640×360；`swift_package_test_2026-11-14T04-09-49-120Z_pid81740_555a374b.log` |
| HDR 红 | `swift test --package-path Modules/StudentKit --filter albumHDRExportConvertsToSDR` | HLG 源成功合成，导出颜色三项断言失败（仍为 BT.2020 / HLG）；`swift_package_test_2026-11-14T04-10-51-152Z_pid81740_b15f14b7.log` |
| HDR 绿 | 同上 | 1 测试通过，H.264 且三个 BT.709 标签；`swift_package_test_2026-11-14T04-11-39-588Z_pid81740_1b435de5.log` |
| 上报红 | `swift test --package-path Modules/StudentKit --filter videoProcessingDiagnostics` | 缺少诊断类型，编译失败；`swift_package_test_2026-11-14T04-12-37-319Z_pid81740_12f6b281.log` |
| 上报绿 | 同上 | 2 测试通过；`swift_package_test_2026-11-14T04-13-02-720Z_pid81740_553701b6.log` |

中间编译修正：SDK 不存在 `AVVideoColorPrimaries_DCI_P3`，改用 CoreVideo 的 `kCVImageBufferColorPrimaries_DCI_P3`；未跳过 HDR 测试。

## 验收

- `swift test --package-path Modules/StudentKit --parallel`：**1294 passed / 0 failed / 0 skipped**。最后一次日志 `swift_package_test_2026-11-14T04-18-47-650Z_pid81740_59bbc731.log`，耗时 68.8 秒。新增 5 个测试函数；现有 SDR、音轨、直通指纹、旋转、体积、裁剪、源文件保留、上传回归全部包含在内。
- 相关视频定向回归曾单独通过 49 项，日志 `swift_package_test_2026-11-14T04-14-46-487Z_pid81740_0be45544.log`。
- XcodeBuildMCP `build_sim`：`projectPath` 为本 worktree 的 `MeetPR.xcodeproj`，`scheme=MeetPR-DemoStudent`，`simulatorName=iPhone 17e`，`useLatestOS=true`，`derivedDataPath=<本 worktree>/DerivedData`，`extraArgs=[-parallelizeTargets,-jobs,4]`。首次构建通过（110.7 秒）；最后补充后的增量构建通过（66.2 秒、0 warning），日志 `build_sim_2026-11-14T04-19-24-987Z_pid81740_c04c7f08.log`。
- SwiftLint：`swiftlint lint --strict --quiet --config .swiftlint.yml <20 个改动 Swift 文件>`，通过，0 violation。
- swift-format：使用 `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format lint --strict --configuration .swift-format <同一文件清单>`，通过。未放宽规则、未加 lint disable。
- `git diff --check`：通过。
- 已按 Standards / Spec 自检完整差异；独立收货、界面验收与 PR 由派卡方执行，此记录不代替独立 review。

## 遗留与环境

- 未在真实电影效果模式、杜比视界素材或真机上验证；本次证明的是合成 10-bit HLG HEVC 与双视频轨输入。
- 按卡未驱动模拟器界面；HEVC/HDR 选完进入剪辑页耗时、多轨剪辑页进入及上传、HDR 上传件观感仍由 Opus 在 iPhone 17e 收货实测。未把宿主测试或构建当成该界面验收。
- 未验证 iCloud 未下载原片；进度、超时、文案/i18n、教练端、后端、版本号均未涉及。
- SwiftPM 全量编译仍报告仓内既有测试并发/锁/无效 try 警告（Bind、Onboarding、ProfileDetailPages、VideoTrimCompletionTests）；本次新增文件无警告。iOS 两次构建均报告 0 warning。
- 开工可用空间 6.7 GiB；最后记录约 4.2 GiB。构建缓存保留在本 worktree，未清理本 worktree 之外任何目录，未发生空间不足。
- FOLLOWUPS 已读；没有本卡需要新增执行的触发项，旧 V0 条目不能用作扩展本卡范围的授权。

## 返修第 1 轮 — 2026-11-14

仅处理任务卡末尾两条。继续在 `fix/album-import-original`（HEAD `68787333`）实装；与本轮开始时的文件快照逐一比对，只改以下 4 个 Swift 文件及本 JOURNAL，上一轮其余实现与任务卡均未改。未 commit、push、开 PR，未改发布台账、配置或依赖，未清理本 worktree 之外的目录。

### 改动与自检

- `VideoProcessingDiagnostics.swift`：补固定映射 `CoreTransferable.TransferableSupportError → TRANSFER`、`PHPhotosErrorDomain → PHOTOS`、`NSItemProviderErrorDomain → ITEMPROVIDER`、`CloudPhotoLibraryErrorDomain → CLOUDPHOTO`。未知域仍为 `UNKNOWN`。顶层 NSError 携带 `NSUnderlyingErrorKey` 时只附一层白名单符号与数值，不递归；将 `video.<stage>.` 一并计入长度，完整 code 超过 64 字符就省略整个底层段，顶层事件仍入队。
- `VideoProcessingDiagnosticsTests.swift`：在原 Analytics / EventQueueStore seam 新增 3 个参数化测试（共 11 组输入），覆盖四个域、未知顶层/底层域、仅一层错误、完整 code 恰好 64 / 65 字符、较长 stage 前缀和整数极值。逐事件校验 `client_error` 三字段、后端正则与隐私；原阶段载荷、取消与关闭后不上报测试保持绿。
- `VideoAttachmentSection.swift`：`importPicked` 抛错时先复位 `isPreparing` 再判取消；正常返回但任务已取消时，仍先释放晚到文件，再复位退出。
- `VideoMissingFileHost.swift`：`importVideo` 抛错时先复位 `isImporting` 再检查取消/记录有效性；正常返回但取消或记录失效时，保留晚到文件释放并复位退出。两处取消分支仍在上报调用之前返回，成功进入剪辑时不提前复位。
- Standards 自检：初次显式扩展取消分支触发 `VideoAttachmentSection` 的 400 行文件 / 50 行函数限制，已通过移动原有失败复位、移除一处空行消除重复；没有放宽规则或加 disable。最终 strict lint / format 通过。
- Spec 自检：只处理两条返修，原片策略、HDR/SDR、多轨、导出与上传流程均未改。取消界面状态通过分支检查及 iOS 编译验证；按卡未新增界面测试 seam、未驱动模拟器 UI，不将宿主测试称为「滚出再回来」的实测。

### 红 → 绿证据

以下均通过 XcodeBuildMCP `swift_package_test` 执行；`packagePath` 固定本 worktree 的 `Modules/StudentKit`。等价命令前缀为 `swift test --package-path Modules/StudentKit`。日志目录沿用上文的 XcodeBuildMCP 工作树日志目录。

| 回合 | 命令后缀 | 结果与日志文件 |
| --- | --- | --- |
| 域映射红 | `--filter videoProcessingDiagnosticsPickerDomains` | 四个新域仍输出 `UNKNOWN_-9`，4 个断言失败；未知域对照通过。`swift_package_test_2026-11-14T08-07-35-325Z_pid15457_88f24aff.log` |
| 域映射绿 | 同上 | 1 个参数化测试通过（5 组输入）。`swift_package_test_2026-11-14T08-07-59-803Z_pid15457_c544eed7.log` |
| 底层错误红 | `--filter videoProcessingDiagnosticsUnderlyingError` | 缺少底层符号段，2 个断言失败。`swift_package_test_2026-11-14T08-08-17-234Z_pid15457_6e241189.log` |
| 底层错误绿 | 同上 | 1 个参数化测试通过（2 组输入），第三层错误不出机。`swift_package_test_2026-11-14T08-08-41-444Z_pid15457_032091e2.log` |
| 长度边界红 | `--filter videoProcessingDiagnosticsCodeLength` | 超长底层段未省略，3 组输入各触发载荷/正则失败（共 6 个断言）；64 字符输入通过。`swift_package_test_2026-11-14T08-09-15-582Z_pid15457_37643e9a.log` |
| 长度边界绿及诊断回归 | `--filter videoProcessingDiagnostics` | 5 个测试通过（含全部新增参数组和原有取消/隐私回归）。`swift_package_test_2026-11-14T08-09-35-829Z_pid15457_b1549900.log` |

### 最终验收

- `swift test --package-path Modules/StudentKit --parallel`：最终改动后 **1297 passed / 0 failed / 0 skipped**，30.4 秒。日志 `swift_package_test_2026-11-14T08-11-28-461Z_pid15457_1434fe4a.log`。
- `swiftlint lint --strict --quiet --config .swiftlint.yml <本卡 20 个 Swift 文件>`：exit 0，0 violation。
- `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format lint --strict --configuration .swift-format <同一文件清单>`：exit 0。
- `git diff --check`：通过。原有未提交工作完整保留；独立复审由派卡方执行，本段为实现方自检。
- XcodeBuildMCP `build_sim`：`projectPath=/Users/david/Projects/apps/MeetPR-wt-album-original/MeetPR.xcodeproj`，`scheme=MeetPR-DemoStudent`，`simulatorName=iPhone 17e`，`useLatestOS=true`，`derivedDataPath=<本 worktree>/DerivedData`，`extraArgs=[-parallelizeTargets,-jobs,4]`。**构建成功**，72.2 秒；日志 `build_sim_2026-11-14T08-11-58-864Z_pid15457_dee1e60e.log`。未安装或运行其他模拟器。
- 磁盘可用空间由约 4.3 GiB 到约 4.0 GiB；未发生空间不足。真实电影效果模式、杜比视界、真机与 iCloud 原片的既有验证限制沿用上一轮；本轮只用合成 NSError 验证错误链载荷，不声称实测了这些素材或网络场景。

## 收货记录（Opus，2026-11-14）

- 亲读全量 diff（Standards / Spec 两轴）。首轮两条返修：picker 阶段错误码缺系统相册错误域（Spec）、取消路径未复位占位状态（Standards），第 1 轮收敛。
- 本机独立复跑：`swift test --package-path Modules/StudentKit --parallel` 1297 项通过；`MeetPR-DemoStudent` 在 iPhone 17e 构建通过；`git diff --check` 通过。
- iPhone 17e 实测（DemoStudent，合成素材）：45 秒 4K HEVC 10-bit 与 60 秒 1080p HEVC 10-bit 选完约 1 秒进入剪辑页并上传为「已附视频」（修复前默认策略分别等待 61.8 秒、24.8 秒）；多视频轨素材可进剪辑页并上传。
- 标记完整的 HLG 样本（BT.2020 / HLG）：修复前导出件仍标 BT.2020 / HLG，修复后三项均为 BT.709，画面与系统自带 SDR 转换结果的平均差 0.82/255。
- 未覆盖：真机、iCloud 未下载原片、真实电影效果模式与杜比视界素材。Demo 构建不证明真实服务器送达。
