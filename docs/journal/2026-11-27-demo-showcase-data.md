# 学员宣发示例数据

2026-11-27，`feat/demo-showcase-data`，基线 `44ab7fb1`。当前工作树根目录的临时文件写入和删除均成功。本轮交付为未提交改动。

## 场景

仅学员演示包识别 `-demo-showcase`。场景使用独立学员 ID、现有学员四个 tab 和内存仓库。从设备当天倒推 12 周计划的起点，推荐日期采用后端 UTC 日期口径，实际训练按本地日期记录。

- 陈屿由周砚指导，W7D1 已完成，W7D2 有 5 个动作，尚未开始。W1–W6 加 W7D1 共 25 练。W4 降低组数，W12 赛前减量。强度图为该场景取最近 7 周。
- 三项 E1RM 来自实际主项组的重量、次数和 RPE，保留前一周期导入点及 W6 深蹲 PR。近 90 天有 80 条体重，末值为 83.0 kg。比赛日为当天加 38 天。资料模型使用同一个文本字段展示赛事和级别。
- 7 条教练反馈、3 条带双打点的视频反馈、7 组已上传视频、2 张动作留言及 1 条应用图标图片消息。每周发布消息按周写入聊天记录。现有教练页还会在周期起日自动生成一张当前周的可跳转通知，回看 W1 时会额外看到 W7 提示。
- `-demo-showcase-video <绝对路径>` 统一供应这批反馈、历史训练组和聊天视频。省略时使用应用包内 14 秒的视频。图片使用应用包内的 AppIcon。

## 改动文件

| 文件 | 改动 |
| --- | --- |
| `MeetPR/Sources/MeetPRApp.swift` | 学员演示包启动分流 |
| `MeetPR/Sources/DemoShowcase.swift` | 参数、身份、绑定、资料、体重、E1RM 和 PR |
| `MeetPR/Sources/DemoShowcaseTraining.swift` | 处方、游标日、逐组实绩 |
| `MeetPR/Sources/DemoShowcaseConversation.swift` | 对话、反馈、打点与组视频回看 |
| `MeetPR/Sources/DemoShowcaseScreen.swift` | 场景装配与现有学员 tab 接入 |
| `Modules/StudentKit/Sources/StudentKit/Demo/ShowcaseChartHistory.swift` | 本场景 7 周的强度图窗口 |
| `Modules/StudentKit/Sources/StudentKit/Repository/InMemoryOnboardingRepository.swift` | 内存仓库支持预置每日体重 |
| `MeetPRTests/DemoShowcaseTests.swift` | 6 个场景数据断言用例 |
| `docs/journal/2026-11-27-demo-showcase-data.md` | 本卡记录 |

## 编译与测试

在当前工作树尝试了以下 generic 构建，含本地依赖缓存重试。Xcode 在解析 SwiftPM 清单时退出 74，未产出完整应用。原始错误为：

```text
xcodebuild: error: Could not resolve package dependencies:
  sandbox-exec: sandbox_apply: Operation not permitted
```

```sh
xcodebuild build -project MeetPR.xcodeproj -scheme MeetPR-DemoStudent \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/showcase
```

补充编译使用本机 iOS Simulator SDK、当前工作树的 StudentKit 源码和已缓存的其他依赖模块。Swift 编译器生成了应用目标文件和本卡测试目标文件，二者均为 arm64 Mach-O，平台标记为 IOSSIMULATOR，SDK 26.5，部署目标 17.0。改动的 Swift 文件通过 SwiftLint 严格检查。此项只覆盖 Swift 编译，完整的资源编译、链接及应用包检查仍待完成。现场日志在 `.build/showcase/generic-build.log`。

以下用例位于 `MeetPRTests/DemoShowcaseTests.swift`。本轮执行 0 个测试，通过数待测。

- `twelveWeeksOpenAtWeekSevenDayTwo`
- `threeLiftsGrowFromImportedHistoryAndLoggedSets`
- `sevenTrainingWeeksIncludeALighterWeekAndDailyWeighIns`
- `conversationLinksFeedbackMarkersAndReplays`
- `visibleTextAndIdentitiesBelongToTheFictionalStudent`
- `launchRequiresOptInAndKeepsMediaLocal`

## 下轮验收命令

以下示例均未执行。完整构建并安装学员演示包后，在指定 iPhone 17e 上使用。自备视频须放在模拟器进程可读的位置。

```sh
device=5D5FA360-BA49-48C6-A887-2F0D22F89749
xcrun simctl launch --terminate-running-process "$device" com.meetpr.app -demo-showcase -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
xcrun simctl launch --terminate-running-process "$device" com.meetpr.app -demo-showcase -demo-showcase-video /tmp/x.mp4 -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
xcrun simctl io "$device" screenshot /tmp/meetpr-showcase.png
xcodebuild test -project MeetPR.xcodeproj -scheme MeetPR-DemoStudent -destination "platform=iOS Simulator,id=$device" -only-testing:MeetPRTests/DemoShowcaseTests
```

待验收项包括无参数启动与原有测试回归、各页截图、已完成训练的实际值、三处视频播放、图片和未读角标。本轮未安装或启动应用，尚无截图。

## 2026-11-27 返修 · 体重图取点过密

宣发截图中，90 天内的 80 个圆点反复上下跳动。学员 `-demo-showcase` 现从今天起每隔 3、4 天交替取点，共 26 条。从 87 天前的 84.0 kg 缓降至今天的 83.0 kg，趋势上的微调覆盖整个窗口，称重值保留一位小数。

已更新 `sevenTrainingWeeksIncludeALighterWeekAndTwiceWeeklyWeighIns` 的点数、日期跨度、相邻差值和首末走势断言。独立 Swift 脚本运行生成代码，核实取点间隔和全部数值，相邻最大差值从 0.4 降到 0.1 kg。两个 Swift 文件通过 SwiftLint 和 swift-format 严格检查。Xcode 测试留待 Claude 在本机执行。

## 2026-11-27 返修 · 学员演示测试链接失败

本机复现时，`MeetPR-DemoStudent` 的 build 通过，test 在链接时找不到 `InMemoryVideoMarkerRepository` 和 `PendingVideoItem` 的符号。App 源码直接使用 `RepositoryContracts`，工程此前只通过其他包间接依赖它。现已在工程中登记本地包 `Modules/RepositoryContracts`，将同名 product 加入 `MeetPR` 的直接依赖和 Frameworks 构建阶段。报错引用来自宿主 App，测试源码没有直接导入该包，因此只调整 App target。本轮 `plutil -lint` 和依赖引用检查通过，实际测试链接待 Claude 在本机复验。
