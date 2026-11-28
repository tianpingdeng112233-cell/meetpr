# Spec 116 · iOS 视频角标

2026-11-28，T2 / P2，目标 1.0 (45)。当前工作树启动时创建并删除临时文件成功，分支为 `feat/116-video-badge`，基线 `1079af2b`。代码与测试留在工作树，未提交。**首轮 Codex 自测的 UI 未在模拟器验证**。Claude 核实当时 iPhone 17e 由其他会话占用。Codex 未安装、启动或截取任何模拟器。

## 实装与取舍

| 卡片项 | 实际落点 |
| --- | --- |
| 1、2 卡片与形态 | ChatUI 共用一张贴内容的卡片，字标原样复制自品牌 SVG，移除了旧暗渐变、金色 RPE 胶囊和教练名。明确传入 replay / export 形态，只有回放显示组序。空角标隐藏。 |
| 3、4 位置与导出 | 导出与录制预览共用左 44u、底 214u 的定位。反馈全屏按原型以底 150u 锚定卡片/圆盘，短评在底 98u，轨道中心在底 69u。长评超出预留单行时在卡片上方展开，选中后可滚动看全文，两种情况下卡片和轨道都固定。 |
| 5 回放入册 | 学员反馈、训练记录、历史回放均接入下载按钮与既有成功提示。训练页实际走 SetEntryVideoPlayerView，保留其倍速、暂停、退出和去点评操作。工作台原有确认与导出入口照旧。 |
| 6 录完入册 | 直接相机和附件入口都提供组行数据。自动裁剪也是录制预览，复用存相册开关和偏好。卡片贴在按视频方向算出的实际画面内，预览不可收起。使用视频时读取该组当前值，自重的零附加重量和仍显示占位的 RPE 不烧录；有附加重量或已填 RPE 时显示。上传继续使用无角标文件，包括用户选择的裁剪结果。 |
| 6 生命周期 | 先为源文件建独立硬链接再同步交给上传，随后独立导出并通过 PhotoKit 写入一次。无法建链时尝试映射原文件。取消、导出失败或系统后台时间到期时改存原片；已发起的 Photos 事务避免重复写入，到期同步结束后台任务。Photos 拒绝授权或原片本身无法读取/写入时使用已有失败提示，不能保证相册成功。系统杀进程后的补存不在规格内。 |
| 7 打点 | 全屏刻度和播放头共享坐标，重叠点击选最近刻度，保留无障碍调进度、跳打点、铅笔批注及失败重试。无角标、无打点的普通聊天视频保留原进度条。工作台继续使用原控件。 |
| 8 语言 | 复用已有字符串资源，未增改翻译。动作名单行超过 452u 时按 SPEC 截断；其余标签三语视觉仍待设备验收。 |

**首轮时的规格冲突（裁决见返修第 1 轮）。** 当时的 SPEC 验收 8 要求教练工作台没有存相册按钮，工作树基线已在有 badge 时显示导出按钮，且有一次性教练确认。按 David 明确的工作台保护约束保留该行为。对工作台视图本身仅删除卡片明确要求去掉的旧渐变引用。没有改后端接口、依赖、build 号或发版线。

## 测试 seam 与先红后绿证据

下表列的是从仓根可单独复跑的命令。macOS SwiftPM 测试由 XcodeBuildMCP 执行。原始 Build Logs 保存在本机 `~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-116-video-badge-f6568a2f0d3a/logs/`，按下列 UTC 时间检索 `swift_package_test_2026-11-28T…`。

| Seam | 复跑命令 | 红 | 绿 |
| --- | --- | --- | --- |
| 1 卡片呈现与几何 | `swift test --package-path Modules/ChatUI --filter VideoBadgePresentationTests` | 07:16:08，旧接口没有 mode、hasContent 与尺寸初始化。 | 07:18:57，呈现、全空/可选字段、组序与三种画幅的左下锚点均通过。和 seam 2、3 合计 6 个 macOS 测试。 |
| 2 点评时间窗 | `swift test --package-path Modules/ChatUI --filter VideoMarkerWindowTests` | 07:18:26，缺 VideoMarkerWindow。审查后追加 1001ms 边界，07:41:51 再次复现失败，暂停在 1.001 秒错误返回 nil。 | 07:18:57 首次转绿。改为比较秒之后，07:43:46 的 ChatUI 全包通过，覆盖 1.001 / 3.401 秒、相邻替换、暂停和空列表。 |
| 3 视频导出 | `swift test --package-path Modules/ChatUI --filter VideoBadgeExporterTests` | 07:15:03，旧渐变在三个采样帧都把画面底边从约 190 压到 71，误差约 119，超出阈值 12。 | 07:17:55 导出用例已绿，07:18:57 联跑通过。原有 24 fps、双音轨、带非对称方向标记的合成片保留显示尺寸、方向、时长，卡片区域变暗，底边亮度在容差内。 |
| 4 录制保存 | `swift test --package-path Modules/StudentKit --filter RecordingAlbumSaveTests` | 07:19:31，新增编排测试找不到 RecordingAlbumSave。 | 07:21:53 首批 6 个参数场景通过；07:39:58 全包中 7 个场景通过，含取消外层任务。覆盖开/关、无角标、导出失败/取消、任务到期，上传回调可立即移除原 URL，相册仍只得到预期内容。 |
| 5 跨模块既有用例 | `swift test --package-path Modules/StudentKit --filter 'feedbackVideo\|SetEntryVideoPlayerTests'`；`swift test --package-path Modules/CoachKit --filter VideoFeedbackPresentationTests` | StudentKit 07:16:35，旧角标缺 hasContent。CoachKit 首跑已包含模型改动，没有独立红测记录。 | StudentKit 07:27:05 与录制一起跑过 18 个测试；CoachKit 07:18:21 与 07:26:45 两轮各 10 个通过。保留两侧对指标和零基组序映射的断言。 |

## 构建和套件验证

从仓根运行的 macOS 全量命令如下。Swift Testing 参数化场景计入其所属测试。没有运行 iOS XCTest 或 UI 测试。

```sh
swift test --package-path Modules/ChatUI
swift test --package-path Modules/StudentKit
swift test --package-path Modules/CoachKit
```

三个包最终全量分别通过 101、1380、497 个测试，共 1978 个，零失败、零跳过。日志时间分别为 07:43:46、07:44:25、07:44:11。新增时间线源文件后，两个下游包一度使用了旧的 SwiftPM 源文件清单；重新生成这两个包的本地构建清单后通过。既有测试补入自重零附加重量断言后，又用 `swift test --package-path Modules/StudentKit --filter 'RecordingAlbumSaveTests|feedbackVideo|SetEntryVideoPlayerTests'` 复跑，07:46:55 共 18 个通过。已有非本卡文件的并发和测试警告仍存在。

完整 App 编译使用以下命令，目的地为 generic iOS Simulator，未指定实际机器。缓存只写临时路径。返回 65，ChatUI Media.xcassets 和 CoachKit InviteShare.xcassets 的 actool 报 `No available simulator runtimes for platform iphonesimulator. SimServiceContext supportedRuntimes=[]`。当前环境无法连接 CoreSimulatorService。**整包构建未通过。**

```sh
export CFFIXED_USER_HOME=/tmp/meetpr-116-xcode
export CLANG_MODULE_CACHE_PATH=/tmp/meetpr-116-modules
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/meetpr-116-modules
xcodebuild -project MeetPR.xcodeproj -scheme MeetPR-DemoStudent \
  -configuration DemoStudent -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/meetpr-116-dd -packageCachePath /tmp/meetpr-116-pm \
  -disableAutomaticPackageResolution -IDEPackageSupportDisableManifestSandbox=YES \
  -PBXBuildsContinueAfterErrors=YES ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
```

补充编译使用同一条命令，在 `build` 前插入下列两个 build settings。前者供沙箱内 Swift 宏插件执行，后者跳过依赖运行时的资源步骤。它验证 iOS 条件编译路径与 App 链接，无法覆盖资源编译和最终可安装包。

```sh
'OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sandbox' \
'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets *.storyboard'
```

补充构建最终返回 0，日志 `/tmp/meetpr-116-reviewed-build.log` 结尾为 `** BUILD SUCCEEDED **`。完整构建失败日志为 `/tmp/meetpr-116-final-build.log`。变动 Swift 文件逐个通过 `xcrun swift-format lint --strict --configuration .swift-format` 和 `swiftlint lint --strict --no-cache`；`git diff --check` 通过。

## 验收证据与缺口

| SPEC 项 | 已有证据 | 收货时仍待实测 |
| --- | --- | --- |
| 1、2 | 合成竖片三帧像素、方向与时长断言；三画幅几何断言。 | 暗片和亮片在手机上的可读性，横拍和 3:4 实际视频的卡高与像素位置。 |
| 3、4 | 呈现模型和回放视图测试；macOS ImageRenderer 目检四种静态卡片。画板 1× 实测宽 282 / 198 / 185 / 452，高均为 144；超长动作名省略。纯英文字标与品牌源 SVG 逐字节相同。 | iOS 资源加载、字体、展开/收起和真实屏幕对照原型。静态样张只用合成数据，未入仓。 |
| 5、6、7 | 注入导出器与保存器覆盖成功、失败、取消、到期、开关、上传立即消费原片。 | 实际相机→裁剪/使用→返回，PhotoKit 入册条数、播放声音与上传回看；真实前后台切换和权限拒绝。 |
| 8 | 下载和成功提示接入现有回放；教练确认保留。 | 学员实机相册与提示未验；工作台“没有按钮”与基线及保护约束冲突，未做。 |
| 9、10 | 毫秒时间窗、选中逻辑、共用横坐标和失败重试接线。 | 暂停/拖动、相邻刻度命中、画线覆盖、长评滚动和实际网络失败后的重试。 |
| 11、12 | 普通聊天沿用旧播放路径，未改数据模型或已有相册文件；相关包回归。 | 普通聊天 UI、老账号升级首屏与老视频、相册旧文件对照均未在设备验证。 |
| 13 | 复用已有简中、繁中、英文 key，无新增文案。 | 三语真机/模拟器排版与遮挡。 |

## 本地审查

Standards 和 Spec 两个只读 reviewer 分别对工作树做了一轮审查及修后复核。Standards 的三项修复包括 PhotoKit 的非空资源请求、后台到期立即结束 assertion，以及毫秒边界比较。Spec 的三项修复包括上述时间边界、单行点评与 150u 回放锚点、未填写 RPE 和自重默认零值。两个 reviewer 对各自 findings 的定向复核均通过，未代替设备验收。

## 改动文件

以下为相对仓根的完整清单，含删除文件与本 JOURNAL。

```text
 M Modules/ChatUI/Sources/ChatUI/ChatStrings.swift
 D Modules/ChatUI/Sources/ChatUI/FeedbackVideoMarkerOverlay.swift
 M Modules/ChatUI/Sources/ChatUI/FeedbackVideoPlayerActions.swift
 M Modules/ChatUI/Sources/ChatUI/FeedbackVideoPlayerChrome.swift
 M Modules/ChatUI/Sources/ChatUI/FeedbackVideoPlayerView.swift
 M Modules/ChatUI/Sources/ChatUI/FeedbackVideoWorkbenchPlayer.swift
 M Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset/Contents.json
 D Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset/meetpr-wordmark-final-on-dark.svg
 M Modules/ChatUI/Sources/ChatUI/VideoBadgeCard.swift
 M Modules/ChatUI/Sources/ChatUI/VideoBadgeExporter.swift
 M Modules/ChatUI/Sources/ChatUI/VideoBadgeInfo.swift
 M Modules/ChatUI/Sources/ChatUI/VideoBadgeOverlay.swift
 M Modules/ChatUI/Sources/ChatUI/VideoBadgePhotoLibrary.swift
 M Modules/ChatUI/Tests/ChatUITests/VideoBadgeExporterTests.swift
 M Modules/ChatUI/Tests/ChatUITests/VideoBadgePresentationTests.swift
 M Modules/CoachKit/Sources/CoachKit/CoachRootView.swift
 M Modules/CoachKit/Sources/CoachKit/Features/Receiving/VideoFeedbackDetailView.swift
 D Modules/CoachKit/Sources/CoachKit/Features/Shared/CoachVideoBadgeContext.swift
 M Modules/CoachKit/Sources/CoachKit/Features/Shared/CoachVideoBadgeResolver.swift
 M Modules/CoachKit/Sources/CoachKit/Features/StudentDetail/Videos/StudentVideoGridView.swift
 M Modules/CoachKit/Tests/CoachKitTests/Features/Receiving/VideoFeedbackPresentationTests.swift
 M Modules/StudentKit/Sources/StudentKit/Features/Coach/StudentBlackGoldChatView.swift
 M Modules/StudentKit/Sources/StudentKit/Features/FeedbackInbox/FeedbackDetailView.swift
 M Modules/StudentKit/Sources/StudentKit/Features/FeedbackInbox/FeedbackInboxView.swift
 M Modules/StudentKit/Sources/StudentKit/Features/FeedbackInbox/FeedbackVideoPresentation.swift
 M Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayVideoSheet.swift
 M Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/CompletedDayPresentation.swift
 M Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/SetEntrySheet.swift
 M Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/CameraRecorderComponents.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/CameraRecorderView.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/RecorderSessionController.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/CompletedVideoPlayerHeader.swift
 D Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/SetEntryVideoDetails.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/SetEntryVideoPlayerView.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentSection.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoLibrarySaver.swift
 M Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoTrimView.swift
 M Modules/StudentKit/Tests/StudentKitTests/Features/FeedbackInbox/FeedbackVideoPresentationTests.swift
 M Modules/StudentKit/Tests/StudentKitTests/Features/VideoUpload/SetEntryVideoPlayerTests.swift
?? Modules/ChatUI/Sources/ChatUI/FeedbackVideoMarkerCue.swift
?? Modules/ChatUI/Sources/ChatUI/FeedbackVideoMarkerScrubber.swift
?? Modules/ChatUI/Sources/ChatUI/FeedbackVideoTimeline.swift
?? Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset/meetpr-wordmark-plain-on-dark.svg
?? Modules/ChatUI/Sources/ChatUI/VideoBadgeAlbumExport.swift
?? Modules/ChatUI/Sources/ChatUI/VideoMarkerWindow.swift
?? Modules/ChatUI/Tests/ChatUITests/VideoMarkerWindowTests.swift
?? Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/RecordingAlbumSave.swift
?? Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/RecordingBadgePreview.swift
?? Modules/StudentKit/Tests/StudentKitTests/Features/VideoUpload/RecordingAlbumSaveTests.swift
?? docs/journal/2026-11-28-116-video-badge-ios.md
```

## 返修第 1 轮

**收货证据来源。** Claude 已在本机通过整包 iOS 构建，安装独立包名的演示包，在 iPhone 17e 上亲验了首轮卡片、收起/展开、回放存相册入口与打点刻度。iPhone 17e 模拟器上 AVFoundation 导出的成片不带叠加层，是 2026-11-27 字标换装时就记录过的模拟器既有现象。带角标成片以 macOS 导出与真机为准。Claude 已在 macOS 上用真实片段核过亮、暗、横拍、3:4 四种成片。本轮 Codex 只使用合成数据。[先前模拟器导出记录](2026-11-27-wordmark-final-ios.md#模拟器整包与导出核查)

| 项 | 返修与验证 |
| --- | --- |
| 1 点评裁切 | 将角标、按三行字体高度预留的点评区和进度条放进同一垂直布局。进度条整个 44pt 点击区参与排版；选中后超长正文在胶囊内滚动。macOS ImageRenderer 对照短评和三行长评的独立渲染高度，再从实际时间线像素测量上下间距、比较有无点评时的角标位置。 |
| 2 批注 | 全屏播放器按当前画线批注的可见状态暂时隐藏卡片或圆盘。展开状态仍由同一个时间线持有；关闭批注后沿用先前状态。顶栏、点评和进度条保留独立点击入口。渲染测试验证画线期间角标消失、点评仍在原处。 |
| 3、4a 后台保存 | 保存任务直接监听 App 进入后台，默认给导出 10 秒；若系统剩余时间更短，则最多用剩余时间的一半。及时回到前台会撤销计时。超时取消导出并立即发起一次原片保存，常规路径待 Photos 返回再结束后台任务；系统到期回调保留最后保险。十个参数场景包含成片写入失败后改存原片、建链失败时保存内存映射一次、延迟 10ms 超时且导出尚在取消收尾时就开始存原片。 |
| 4b 成片 | 对实际导出帧的卡片暗色区域取包围盒，与独立计算的左 44u、底 214u 锚点逐帧比较，容差 2 像素。新增 1920×1080 和 1080×1440 两种合成片，检查显示尺寸及实测卡高 ≤ 画面高 20%。原有上、中灰度容差和新的底边无渐变断言同时保留。三种画幅都恢复原阈值：橙金色像素 >30、亮字像素 >100。临时偏移下的小片只有 24–25 个橙金像素，恢复正确位置后，08:16:37 单跑原阈值，三个采样帧均通过。 |
| 4c 长动作名 | 实际渲染整卡，验证宽度 ≤452u、高度等于单行动作名卡片。仅改超长名称尾部时像素完全相同，改可见前缀时像素不同。 |
| 5 无障碍 | 点评铅笔恢复 accessibilityHidden，保留 feedback.video.marker.annotationBadge 标识符。未实际运行 VoiceOver。 |
| 6 最终记录 RPE | 初测证实存在回归。视频入口先写 nil，从训练行完成组后，仓储读回也为 nil，旧值应为 8。现恢复原有草稿和组记录的 RPE 值；本地草稿用一个可选标记区别占位和手动输入，旧草稿可照常解码。角标在未完成组过滤占位，重开编辑器或从直录相机读取时仍能识别；明确输入 8 会清除标记。测试走选片回调、解析真实组日志 ID、重开、完成组、读回仓储。 |
| 7 工作台与文档 | 已更正核实模拟器占用的人和成片证据来源。教练工作台按更正后的 SPEC 保留原导出按钮和确认，本轮未改工作台或 SPEC。 |

**红 → 绿。** 下列命令以仓根为工作目录，日志时间沿用本文件前述 XcodeBuildMCP 本地日志目录，时区 UTC。对首轮已经正确的行为使用临时负对照，让新断言先实际报错；负对照均已撤销。

| 用例与 macOS 命令 | 红灯证据 | 修后结果 |
| --- | --- | --- |
| `swift test --package-path Modules/ChatUI --filter renderedCueClearsBadgeAndScrubber` | 08:01:18，390×844 布局的短评底边侵入进度条点击区 0.83pt，上侧也不足 10u。08:05:30，保留角标的负对照使短评、长评两例的批注断言都失败；长评上方也测出间距不足。 | 两种长度均检查独立胶囊高度、上下净距和切换批注后的可见区域。 |
| `swift test --package-path Modules/StudentKit --filter RecordingAlbumSaveTests` | 08:01:40，关闭早期超时回退时保留了成片且导出未取消；临时移除已有的写入失败回退时抛出错误，跳过映射保存时写入数为零。 | 成片写入失败的尝试顺序为成片、原片；建链失败时一次映射写入、零次导出；后台超时只存原片。 |
| `swift test --package-path Modules/ChatUI --filter VideoBadgeExporterTests` | 07:59:36，测试先暴露不支持指定画幅的合成夹具。08:01:18，将导出的左边距临时增大 8u，使横拍、3:4 的位置断言分别偏离 9.5px、7px；此偏移下小竖片的旧金色阈值也失败。 | 两种实际大画幅及旋转竖片通过卡片区域与高度检查。竖片继续覆盖三帧、双音轨、方向、时长及底边亮度。 |
| `swift test --package-path Modules/ChatUI --filter longNameTruncation` | 08:01:18，临时将上限放至 552u 并取消单行限制；实测宽 552，改隐藏后缀还会改变像素。 | 恢复原卡片实现后，宽度、单行高度与前后缀像素对照均通过。 |
| `swift test --package-path Modules/StudentKit --filter videoHandoffThenSetCompletion` | 08:01:40，最终仓储值 nil 与基线 8 不同。08:09:03，只恢复存储逻辑时，未完成组重开编辑器与直录两处都把占位当成已填。08:13:16，改走全天键盘时，同值去重吞掉手动输入的 8，角标仍空。08:14:04，给同值确认也排入异步保存，会将紧接其后的完成态覆盖回未完成。 | 确认同值占位只更新本地输入来源，沿用数值不变时跳过异步保存的行为。以最终仓储及重开编辑器、直录角标共同断言空输入、原值 8.5、显式输入 8。 |

**尚待设备复验。** 本轮未使用模拟器或真机。返修后的点评间距、画线时收起态的恢复、点击、长文滚动、VoiceOver，以及真实后台通知、系统到期与 PhotoKit 入册时序尚待设备复验。原片回退已覆盖可读源文件和允许写入的情况；系统撤销权限、存储不可写或杀进程时无法保证入册，已有错误提示继续使用。

**全量与静态检查。** 下列全量命令在 macOS 运行，共 1982 个测试，零失败、零跳过。08:14:59 的最终 StudentKit 日志含录制保存的 10 个参数场景和 RPE 的 3 个参数场景。08:17:02 的最终 ChatUI 日志含两种实际导出画幅与两种点评长度。

| 命令 | 结果 |
| --- | --- |
| `swift test --package-path Modules/ChatUI` | 104 通过 |
| `swift test --package-path Modules/StudentKit` | 1381 通过 |
| `swift test --package-path Modules/CoachKit` | 497 通过 |
| `xcrun swift-format lint --strict --configuration .swift-format <变动的 Swift 文件>` | 通过 |
| `swiftlint lint --strict --no-cache <变动的 Swift 文件>`；`git diff --check` | 均通过 |

本轮另复跑上文的 generic iOS Simulator 补充编译，返回 0（`/tmp/meetpr-116-r1-ios-confirmed.log`）。该命令不指定设备，跳过资源目录和 storyboard，仅验证 iOS 条件代码和链接。Claude 的整包及模拟器收货记录对应返修前版本。

**本轮涉及的文件。**

- ChatUI 播放器：`FeedbackVideoTimeline.swift`、`FeedbackVideoPlayerView.swift`、`FeedbackVideoMarkerCue.swift`、`FeedbackVideoTimelineTests.swift`。
- ChatUI 成片和卡片测试：`VideoBadgeExportFixture.swift`、`VideoBadgeExporterTests.swift`、`VideoBadgePresentationTests.swift`。首轮已收货的导出器和卡片样式没有净变化。
- StudentKit：`RecordingAlbumSave.swift`、`RecordingAlbumSaveTests.swift`、`SetEntrySheet.swift`、`TodayWorkoutTypes.swift`、`AllDayKeypadPersistence.swift`、`TodayWorkoutViewModel.swift`、`CompletedDayPresentation.swift`、`SetEntryVideoPlayerTests.swift`、`SetWeightSuggestionOutcomeTests.swift`（复用内存仓储夹具）。
- 文档：本 JOURNAL。
