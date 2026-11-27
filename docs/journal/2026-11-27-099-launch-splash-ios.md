# 2026-11-27 · spec 099 开屏动画 · iOS

实装方：Claude（David 当面指定「不调用 Codex，就你来做」，因此没有跑 review-loop 的 Codex 互审）。

## 做了什么

- 新增冷启动开屏层：`Modules/AppShell/Sources/AppShell/Launch/`（阶段模型、时间轴纯函数、画面、挂载用的 `launchSplash()`）。`MeetPRApp` 在 `MinimumVersionGate` 外面挂一次，每个进程只播一次。
- 「首屏未就绪」由各处全屏转圈自己声明：`DesignSystem` 新增 `launchBlocking()`，标在 session 恢复、组同步宿主、e1RM 迁移门、绑定门、聊天上下文激活这五处。没人声明就视为就绪，所以漏标的后果是提早退出，不会卡死在开屏上。
- `Session.hasBootstrapped`：冷启动恢复落定后才为真，避免恢复开始前那一帧「未登录」被当成就绪。
- 系统启动屏改为烘焙的动画第 0 帧背景（`LaunchScreenBackground` + `LaunchScreenColor`），两份 plist 都改，不再是整屏红。
- 删掉「正在验证登录」文案（常量与 `Localizable.xcstrings` 条目）；转圈保留给退出登录等非冷启动场景。
- 定稿字标 SVG 入 `docs/brand/`（与 `feat/wordmark-final` 分支上的同名文件逐字节相同）。

## 踩到的坑

- 一开始用 `.overlay` 挂开屏层，它跟着底下内容的尺寸走，恢复期间底下只有一个转圈，开屏被压成一小块。改成 `ZStack`。
- 光晕椭圆比屏幕宽（437pt 对 390pt），放在同一个 `ZStack` 里把布局撑大，字标、标语、加载线整体低了约 50pt。光晕和背景改成 `.background`，不参与布局。
- 动画最初按墙上时钟算。机器很卡时第一帧画出来已经过了 1.5 秒，开屏整段被跳过，启动屏直接接首页。改为 `LaunchSplashClock`：从第一帧真正画出来开始计时，每帧最多前进 0.05 秒，主线程卡住时动画暂停而不是跳过。

## 验证

- `swift test --filter "launchSplash|sessionReportsBootstrap"`：7 条全绿（阶段表 8 例、首末帧、关键时刻、短条只向右、循环可见、恢复标记、时钟不跳帧）。
- `swiftlint` 与 `swift-format lint` 对改动文件无输出。
- iPhone 17e 冷启动录屏逐帧看过（最终版，已登录学员）：系统启动屏与第一帧衔接无切换 → 字标、标语入场 → 加载线 → 淡出进首页。字标色块量得 358.7–429.3pt，参照稿同尺寸视口为 358–430pt。
- 较早的版本（修位置之前）还录过：深色外观下仍是浅色画面；减弱动态效果直接出最后一帧并正常退出。这两项在最终版上没有重录。

## 没验的

- 未登录冷启动、弱网下的循环加载线（只有单测）、从后台切回不重播、带历史老账号从现网版本升级后的第一屏。
- 教练端冷启动（首发只上学员端，未安排）。
- 没跑全量测试，只跑了本次新增的 7 条。
