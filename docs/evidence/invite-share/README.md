# 教练邀请码 URL 分享开发自测

- 基线：`origin/release/1.0 @ b2afd513`；工作分支：`fix/invite-share-wechat`。
- 依据：David 2026-10-22 直接批准的 P0 方案 A。仅修改 CN 邀请分享；Global 保持裸码复制和原入口。未 commit/push。
- 分享 item 为 URL；subject / message / preview 分别携带双语标题、完整邀请语、标题及现有 App 图标。图标复制自 `MeetPR/Assets.xcassets/AppIcon.appiconset/meetpr-icon-1024.png`，未重新设计。
- CN 卡片本体不再是按钮；管理、分享和复制各自独立。加载/失败/无永久码分支仍复用原入口。管理页的重新生成仍使用既有 confirmationDialog。

## 自动化证据

- `red-message.txt`：实现前，缺少 inviteURL / shareTitle 的编译失败。
- `red-ui.json`：实现前，缺少 CN 共用控件及注入 seam 的编译失败。
- `green-focused.json`：定向 5 项通过（新增 4 项测试，其中标题测试参数化覆盖中英；另保留原有复制测试）。
- ViewInspector 实际断言共享操作区中 ShareLink 在 SecondaryButton 前，以及已加载永久码的 profile 在 CN 渲染操作区、Global 不渲染。
- `coach-tests.json`：CoachKit 全量 **476 passed / 0 failed / 0 skipped**。
- `designsystem-tests.txt`：DesignSystem 全量 **73 passed**；合计 **549**。首次 MCP 下载 ViewInspector 超时（保留 `designsystem-tests.json`），随后复用本 worktree 内已下载的同版本仓库，使用独立本地缓存离线通过。
- `build.json`：MeetPR-Demo / Demo / iPhone 17e (iOS 26.4)，**SUCCEEDED，0 error**，98.5 秒。首次冷构建超出 MCP 300 秒等待窗口但后台继续，后续增量构建取得明确成功结果。
- `swift-format.txt`、`swiftlint.txt`：10 个修改/新增 Swift 文件，exit 0。
- `git diff --check` 通过。SwiftPM 提示的 PlanImportCapability / WeightPercentPresets 并发 warning 位于未修改的既有代码。

## Demo 复现

Scheme / configuration：`MeetPR-Demo` / `Demo`。

- 中文浅色：`-demo-invite-share-cn -AppleLanguages (zh-Hans) -AppleLocale zh_CN`
- 中文深色：再加 `-demo-invite-share-dark`
- 参数处理位于 app 的 `#if DEMO_MODE` 路径；覆盖值只注入邀请相关 view 的 environment，不改变全局 BuildConfig、认证或后端 track。
- 点击「我的」查看卡片；点击「管理」进入邀请码页；两处「分享给学员」触发原生分享；右上角「…」展开重新生成。

## 未验边界

微信 iOS 分享扩展的发现、发送和接收需安装微信的真机；模拟器不能证明该链路通过。本轮不访问真实账号、不执行后端变更、不发布。

## 模拟器截图（已逐张查看）

设备：iPhone 17e / iOS 26.4，UDID `BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`。

| 场景 | 中文浅色 | 中文深色 |
| --- | --- | --- |
| 我的卡片 | [截图](zh-light-profile.jpg) | [截图](zh-dark-profile.jpg) |
| 我的卡片分享面板 | [截图](zh-light-profile-share.jpg) | [截图](zh-dark-profile-share.jpg) |
| 邀请码管理页 | [截图](zh-light-management.jpg) | [截图](zh-dark-management.jpg) |
| 管理页分享面板 | [截图](zh-light-management-share.jpg) | [截图](zh-dark-management-share.jpg) |
| … 菜单展开 | [截图](zh-light-menu.jpg) | [截图](zh-dark-menu.jpg) |

额外核对：[重新生成二次确认](zh-light-regenerate-confirmation.jpg)，通过点外部取消，未执行重新生成。分享面板均显示现有 App 图标和「演示教练邀请你加入 MeetPR」。自动化快照偶发超时后已重新取快照、检查实际图像并重拍。

## 开发自审

- Standards：使用既有 token、Repository 边界与本地化入口；PrimaryButton 仅抽出同样式的无按钮 label 供 ShareLink 使用，避免嵌套 Button；无依赖、导航、tab 或后端改动。
- Spec：逐项核对方案 A 的 1–5 条；Global 分支仍复制裸码、不显示分享，旧的 copy/regenerate 行保留；CN 无永久码/加载/失败走原分支。未把模拟器分享面板视为微信真机验收。

## 修改文件

- `MeetPR/Sources/MeetPRApp.swift`
- `Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/CoachInvitationActions.swift`
- `Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/CoachInvitationCard.swift`
- `Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/CoachInvitationMessage.swift`
- `Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/InviteCodesView.swift`
- `Modules/CoachKit/Sources/CoachKit/Features/MyProfile/CoachMyProfileView.swift`
- `Modules/CoachKit/Sources/CoachKit/Resources/InviteShare.xcassets/Contents.json`
- `Modules/CoachKit/Sources/CoachKit/Resources/InviteShare.xcassets/InviteShareIcon.imageset/Contents.json`
- `Modules/CoachKit/Sources/CoachKit/Resources/InviteShare.xcassets/InviteShareIcon.imageset/meetpr-icon-1024.png`
- `Modules/CoachKit/Sources/CoachKit/Resources/Localizable.xcstrings`
- `Modules/CoachKit/Tests/CoachKitTests/Features/InviteCodes/CoachInvitationActionsTests.swift`
- `Modules/CoachKit/Tests/CoachKitTests/Features/InviteCodes/CoachInvitationMessageTests.swift`
- `Modules/DesignSystem/Sources/DesignSystem/Components/Buttons/PrimaryButton.swift`
- `Modules/DesignSystem/Sources/DesignSystem/Components/Buttons/PrimaryButtonLabel.swift`
- `docs/CODEX-JOURNAL.md`
