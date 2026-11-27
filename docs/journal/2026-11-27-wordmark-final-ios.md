# iOS 定稿字标 · 2026-11-27

分支 `feat/wordmark-final`，基线 `44ab7fb1`。

## 实现

- DesignSystem 的 `MeetPRMark(height:)` 通过 asset catalog 的 Any / Dark 外观选择原稿。成长和我的沿用 `.header`，图形高 18 pt，原有 97 × 24 pt 左对齐占位及无障碍隐藏行为保留。
- 三个共用 `GlobalAuthHero` 的认证页和两个旧认证页使用 23 pt。视频角标与导出共用 `VideoBadgeCard`，字标高 21 pt × 卡片缩放系数。左侧图标仍为 22 pt × 同一系数，两者在 HStack 内垂直居中。角标仅含深色背景版，保留 `MEETPR` 无障碍标签。
- 两个资源目录均保留矢量，三份 SVG 副本与相应原稿的 SHA-256 全部相同。旧 PNG 与描边文字绘制代码已移除。

## 验证

测试使用本 worktree 内的临时 Xcode workspace，将四个包的 Tests target 显式加入测试 scheme。本地复跑时设 `QA=build`，该目录保留了相同的临时 workspace。所有模拟器操作均指定 iPhone 17e（iOS 26.5），测试关闭并行克隆。

- 红灯：`xcodebuild -workspace "$QA/Packages.xcworkspace" -scheme Marks -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:DesignSystemTests/MeetPRMarkTests '-only-testing:ChatUITests/VideoBadgePresentationTests/wordmarkResource()' test`。3 条均失败。旧 header 实测 47.33 pt，主题资源查询为 nil，旧 PNG 的比例与 2443:605 相差 0.0953。
- 静态核对：旧构造器、描边文字实现均无匹配；`git diff --check` 通过。SwiftLint 严格检查改动的 7 个 Swift 文件，0 项违规。

- 绿灯：同一组 iPhone 17e 定向测试 **3 通过，0 失败**。高度断言使用 SwiftUI 渲染器报告的点尺寸；UIKit 宿主会把 72.68 pt 的宽度向上对齐到像素。资源断言分别读取浅深 trait 并比较图像数据。
- 构建：`xcodebuild -project MeetPR.xcodeproj -scheme MeetPR -destination 'platform=iOS Simulator,name=iPhone 17e' build` 通过。使用 XcodeBuildMCP 调用 xcodebuild，实际目标为 iPhone 17e 的 UDID。成长和我的已在此包查看浅色与深色，两者的标题位置一致。
- 格式：`xcrun swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` 退出 0，0 条诊断。

### 包测试

| 命令 | 通过 | 失败 |
|---|---:|---:|
| `swift test --package-path Modules/DesignSystem` | 84 | 0 |
| `swift test --package-path Modules/ChatUI` | 100 | 0 |
| `swift test --package-path Modules/AppShell` | 130 | 0 |
| `swift test --package-path Modules/StudentKit` | 1372 | 0 |

上述是 macOS SwiftPM 宿主结果。StudentKit 首轮有 20 条超时，第二次运行全包通过。

### 模拟器整包与导出核查

在修正页头测试的像素对齐问题前，额外运行 `xcodebuild -workspace "$QA/Packages.xcworkspace" -scheme All -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO test`。按 xcresult 中唯一测试计数，共 1655 通过、28 失败。DesignSystem 84/1，ChatUI 100/1，StudentKit 1343/24，AppShell 128/2（通过/失败）。页头断言已在定向复测通过。其余涉及视频导出、邀请按钮、多语言文案、提醒和 Keychain；本卡未改这些逻辑。

- iPhone 17e 的 AVFoundation 导出测试在三个采样帧均缺整张角标和渐变，两条输入音轨导为一条。使用红灯阶段保留的原版二进制，仅运行 `-only-testing:ChatUITests/VideoBadgeExporterTests` 复现同样的失败。该模拟器的端到端导出验收仍未通过。
- macOS 另外以 `actool` 编译 ChatUI 原始 catalog 后，将编译结果供 SwiftPM 测试 bundle 使用（命令行 SwiftPM 默认只复制 xcassets）。临时把原有导出 fixture 提到 1080 × 1920，运行 `swift test --package-path Modules/ChatUI --filter exportPreservesVideoContract`，**1 通过，0 失败**。检查了输出视频 0.25 秒处的解码帧，深底版本字标清晰、居中，P 内圆章可见。取证后恢复了 fixture 和导出测试文件。
- 测试结果包：定向红灯 `test_sim_2026-11-27T06-46-46-356Z_pid31069_c47102c1.xcresult`，定向绿灯 `test_sim_2026-11-27T07-14-43-878Z_pid31069_eedaa335.xcresult`，模拟器四包 `test_sim_2026-11-27T06-51-51-334Z_pid31069_077ba2a7.xcresult`。位于本机 XcodeBuildMCP 的本 worktree 结果目录。

### 认证页

`MeetPR-Global` 在 iPhone 17e 构建通过并启动，登录入口显示现有的首次隐私确认页。登录、注册和忘记密码共用 `GlobalAuthHero`；使用同一生产组件和编译后的 DesignSystem catalog，在 macOS 宿主分别渲染浅深环境，23 pt 字标及暗色金章均可见。当前 App 未登录时由 `MeetPRApp.preferredAppColorScheme` 固定浅色，此次沿用该设置。三条认证流程未逐页导航。

[认证页头 · 浅色](evidence/wordmark-final-ios/auth-hero-light.png) · [认证页头 · 深色](evidence/wordmark-final-ios/auth-hero-dark.png)

### 截图

[成长 · 浅色](evidence/wordmark-final-ios/growth-light.jpg) · [成长 · 深色](evidence/wordmark-final-ios/growth-dark.jpg) · [我的 · 浅色](evidence/wordmark-final-ios/profile-light.jpg) · [我的 · 深色](evidence/wordmark-final-ios/profile-dark.jpg) · [1080p 导出帧原像素局部](evidence/wordmark-final-ios/export-wordmark-1080p.png)

## 本次看到的 App 文案

教练「我的」版本信息使用 `coach.profile.internalBeta`（“内测”）。文案位于 `Modules/CoachKit/Sources/CoachKit/Resources/Localizable.xcstrings:14753`，调用位于 `Modules/CoachKit/Sources/CoachKit/Features/MyProfile/CoachMyProfileStrings.swift:68`。本卡只记录位置。

## 交付工作树

以下为 `git status --short -uall`。其中 `docs/brand/` 的两份 SVG 和 `docs/design/wordmark-final/` 的参照资料在开工时已存在。

```text
 M Modules/AppShell/Sources/AppShell/Auth/Global/GlobalAuthComponents.swift
 M Modules/AppShell/Sources/AppShell/Auth/LoginView.swift
 M Modules/AppShell/Sources/AppShell/Auth/SignupView.swift
 M Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset/Contents.json
 D Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset/meetpr-wordmark@2x.png
 M Modules/ChatUI/Sources/ChatUI/VideoBadgeCard.swift
 M Modules/ChatUI/Tests/ChatUITests/VideoBadgePresentationTests.swift
 M Modules/DesignSystem/Sources/DesignSystem/Components/Brand/MeetPRMark.swift
 M docs/brand/README.md
?? Modules/ChatUI/Sources/ChatUI/Resources/Media.xcassets/MeetPRWordmark.imageset/meetpr-wordmark-final-on-dark.svg
?? Modules/DesignSystem/Sources/DesignSystem/Resources/Brand.xcassets/Contents.json
?? Modules/DesignSystem/Sources/DesignSystem/Resources/Brand.xcassets/MeetPRMark.imageset/Contents.json
?? Modules/DesignSystem/Sources/DesignSystem/Resources/Brand.xcassets/MeetPRMark.imageset/meetpr-wordmark-final-on-dark.svg
?? Modules/DesignSystem/Sources/DesignSystem/Resources/Brand.xcassets/MeetPRMark.imageset/meetpr-wordmark-final.svg
?? Modules/DesignSystem/Tests/DesignSystemTests/MeetPRMarkTests.swift
?? docs/brand/meetpr-wordmark-final-on-dark.svg
?? docs/brand/meetpr-wordmark-final.svg
?? docs/design/wordmark-final/COMMON.md
?? docs/design/wordmark-final/reference.png
?? docs/journal/2026-11-27-wordmark-final-ios.md
?? docs/journal/evidence/wordmark-final-ios/auth-hero-dark.png
?? docs/journal/evidence/wordmark-final-ios/auth-hero-light.png
?? docs/journal/evidence/wordmark-final-ios/export-wordmark-1080p.png
?? docs/journal/evidence/wordmark-final-ios/growth-dark.jpg
?? docs/journal/evidence/wordmark-final-ios/growth-light.jpg
?? docs/journal/evidence/wordmark-final-ios/profile-dark.jpg
?? docs/journal/evidence/wordmark-final-ios/profile-light.jpg
```
