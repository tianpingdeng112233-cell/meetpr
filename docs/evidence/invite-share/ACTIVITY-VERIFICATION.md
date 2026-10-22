# invite-share H1 开发记录（2026-10-22）

基线 `e65a9a6a`，分支 `fix/invite-share-wechat`。用户指定的 H1 定向实现，未 commit/push。
**验收未完成；H1：代码已改、微信真机未验。** 本记录不覆盖上一轮 ShareLink 证据。

## 代码与测试

- iOS 的按钮改呈现 `CoachInvitationActivitySheet`；controller 的 activityItems 数组只有一个 `CoachInvitationActivityItemSource`。
- 默认（含 nil / 微信 / 其他扩展 / AirDrop）返回 URL；message / mail / copyToPasteboard 返回既有完整邀请语。
- placeholder 为同一 URL；metadata 使用 shareTitle、URL 和 InviteShareIcon；subject 使用 shareTitle。
- 两处调用布局、按钮标签、复制及 Global 分支未修改。macOS 保留 ShareLink，避免影响现有跨平台支持。
- 新增 **1 项 iOS 测试**，包含上述 payload、placeholder、metadata/图标、subject 断言。没有用 macOS 测试替代 UIKit 回调测试。

## 实际结果

| 项目 | 结果 | 原始输出 |
| --- | --- | --- |
| 新测试在旧模块上的编译红灯 | exit 1：找不到 CoachInvitationActivityItemSource | [red](activity-red-typecheck.txt) |
| 新源文件与新测试 iOS 类型检查 | exit 0，无诊断；仅类型检查，**不是测试运行绿灯** | [typecheck](activity-green-typecheck.txt) |
| CoachKit macOS 全量测试 | exit 0，476 tests / 14 suites；新增 iOS 测试受条件编译排除 | [tests](activity-coach-tests.txt) |
| swift-format | exit 0，4 文件 | [format](activity-swift-format.txt) |
| SwiftLint | exit 0，4 文件 / 0 violations | [lint](activity-swiftlint.txt) |
| git diff --check | exit 0 | [diff](activity-diff-check.txt) |
| MeetPR-Demo / Demo 完整构建 | exit 65，Missing package product；未取得 0 error | [build](activity-demo-build.txt) |
| 新面板截图 | exit 1，CoreSimulator 连接拒绝；未生成图片 | [screenshot](activity-screenshot-attempt.txt) |

没有替换或复制旧截图。预期路径 `docs/evidence/invite-share/zh-light-share-activity.jpg` **不存在**，标题/图标未获本轮视觉确认。

## 运行命令与限制

本会话未暴露 XcodeBuildMCP 工具，CLI 也不可用；采用 Xcode CLI。完整 build 的命令由 Xcode 记录在 build 日志开头；格式/lint/diff/typecheck 的完整命令和退出码已写入各自日志。

CoachKit 全量测试命令（仓根执行）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/swift-module-cache" swift test --package-path Modules/CoachKit --cache-path .build/swiftpm-cache --config-path .build/swiftpm-config --security-path .build/swiftpm-security --disable-sandbox --skip-update
```

类型检查使用既有 e65a9a6a iOS 模块及 SDK。红阶段只传新测试（需 `-Xfrontend -disable-testable-attr-requires-testable-module`，因旧 Demo 模块未开启 testing）。绿阶段把三个修改/新增源文件原样复制到 `.build/invite-share-typecheck/`，每份仅前置 `@testable import CoachKit` 以取得未改动的内部协作类型，再与原测试共同 typecheck；不替换 UIKit、不模拟回调结果。完整命令见 green 日志。该检查不链接、不运行，不证明真实分享行为。

完整模块直接 emit-module 的尝试被沙箱内 SwiftData macro plugin 响应失败阻塞：[过程日志](activity-ios-module.txt)。其中 item source 的 MainActor/nonisolated conformance 警告随后通过移除不必要的类隔离标注修正，最终 narrow typecheck 无诊断。

原先尝试在 Swift package 目录 `xcodebuild -scheme CoachKit ... build-for-testing`，工具未识别该目录为 Xcode package/workspace：[尝试日志](activity-red-attempt.txt)。这不是行为红灯。沙箱内 CoreSimulator 持续 connection refused，因此没有继续运行/安装 app，也没有声称点击过本轮分享按钮。

截图尝试命令：

```sh
xcrun simctl io BBE9EB95-01DE-452E-866C-3DD0B62F9BDA screenshot --type=jpeg docs/evidence/invite-share/zh-light-share-activity.jpg
```

## 只读审查与交接

- Standards：独立复核 CLEAN；不可变 item source 符合非隔离协议，无未决代码问题。
- Spec：独立复核 CLEAN；payload、metadata、subject、布局及 Global 边界符合请求。
- 未完成 gate：新增 iOS 测试实际运行绿灯、MeetPR-Demo 完整 build 0 error、安装新构建后点击分享并确认新截图标题/图标。
- 微信真机发送与接收由 Opus 继续验证；H1 尚未被真机证实，H2/H3 未在本任务处理。
