# 任务卡（iOS）：使用数据告知——按构建轨道取文案、保留期如实表述、正文不再被截断

开工先读仓内 CONTEXT.md（如存在）、AGENTS.md 与本卡。

- 级别：T1。基线 `release/1.0`，分支 `fix/usage-notice-copy`。目标 1.0(24) 候选。安卓同步卡在 meetpr-rn。
- 来源：走查 D-32 与 D-37。David 2026-10-03 定稿。
- **不 commit、不 push**。只在 `docs/CODEX-JOURNAL.md` 末尾追加本卡一节。本仓已公开。

## 背景事实（已核实，不要改动措辞含义）

- 首次启动的"使用数据说明"弹层（`Modules/AppShell/Sources/AppShell/AnalyticsPrivacyNotice.swift`，文案键 `appShell.privacy.analytics.body`）现在两条构建轨道同文，写的是 CN 轨事实（境内自建阿里云、不出境）。Global 轨后端在美国（DigitalOcean 纽约），文案与事实不符。
- "数据保留 90 天"不成立：后端没有到期清理。实际行为是账号存续期间保留；删除账号时使用数据与账号断开关联、成为匿名记录（与官网隐私政策的表述一致）。
- 弹层固定 `.presentationDetents([.medium])`，在 iPhone 17 默认字号下正文结尾被截成 "You can de…"，"可请求删除"一句看不到。

## 要做的

1. **文案按轨道取**（`BuildConfig.buildTrack`）：CN 轨沿用键 `appShell.privacy.analytics.body`；Global 轨新增键 `appShell.privacy.analytics.body.global`。两个键的中英文一律用下面的定稿原文，逐字照录，不要润色。

   Global · English：
   > To improve the training experience, MeetPR collects product interactions, an anonymous device identifier, and feedback text you choose to provide. This data is used only for product functionality and is stored on our own DigitalOcean infrastructure in the United States. It is not shared with third-party analytics SDKs and is not used for tracking or advertising. We keep it while your account exists; if you delete your account, it is unlinked from you and becomes anonymous records that can no longer identify you. Uninstalling clears the anonymous installation identifier. You can delete your account or contact us to request deletion.

   Global · 简体中文：
   > 为改进训练流程，MeetPR 会收集产品交互、匿名设备标识，以及你主动填写的反馈文本。数据仅用于产品功能，存放在我们位于美国的 DigitalOcean 自有服务器上，不接入第三方统计 SDK，也不用于追踪或广告。账号存续期间我们会保留这些数据；删除账号后，它们会与你断开关联，成为无法识别你的匿名记录。卸载会清除匿名安装标识，你可通过删除账号或联系我们请求删除。

   CN · English：
   > To improve the training experience, MeetPR collects product interactions, an anonymous device identifier, and feedback text you choose to provide. This data is used only for product functionality, stored on our self-hosted Alibaba Cloud infrastructure in mainland China, and is not shared with third-party analytics SDKs, transferred overseas, or used for tracking or advertising. We keep it while your account exists; if you delete your account, it is unlinked from you and becomes anonymous records that can no longer identify you. Uninstalling clears the anonymous installation identifier. You can delete your account or contact us to request deletion.

   CN · 简体中文：
   > 为改进训练流程，MeetPR 会收集产品交互、匿名设备标识，以及你主动填写的反馈文本。数据仅用于产品功能，留存在境内自建阿里云，不接入第三方统计 SDK、不出境，也不用于追踪或广告。账号存续期间我们会保留这些数据；删除账号后，它们会与你断开关联，成为无法识别你的匿名记录。卸载会清除匿名安装标识，你可通过删除账号或联系我们请求删除。

2. **正文完整可读**：弹层里正文不得被截断或省略。正文放进可滚动区域，标题在上、"Privacy Policy" 链接与 "Got it" 按钮固定在底部始终可见；弹层高度随内容自适应，放不下时正文滚动。iPhone SE 尺寸与最大一档动态字体下同样成立。标题、链接、按钮的文案与行为不变；确认后不再出现的逻辑不变。

3. 仓内其他位置若引用了旧的"90 天 / 90 days"使用数据表述（设置页、帮助页、测试期望值），列出来并同步为新口径；没有就写明没有。不要动 `PrivacyInfo.xcprivacy`。

## 测试 seam（先红后绿）

- AppShell 单测：给定 Global 轨返回 Global 键的文案、给定 CN 轨返回 CN 键的文案（选择逻辑抽成可注入轨道的纯函数或等价 seam，不依赖编译期轨道）；四段文案都不含 "90"。
- 弹层视图测试（仓内已有 ViewInspector / 快照惯例，沿用其一）：正文没有行数上限，且位于可滚动容器内；底部按钮在正文之外。
- 既有 `AuthFlowSnapshotTests` 等若因文案变化需要更新基线，更新并说明。

## 验收（Opus 收货，实装方不得自定范围）

1. 模拟器全新安装 `MeetPR-Global`：弹层显示 Global 英文定稿，能读到最后一句 "…contact us to request deletion."（必要时滚动），"Got it" 始终可见、点后进入登录页且再次启动不再弹。
2. 模拟器全新安装 CN 轨（`MeetPR` 或 Demo scheme，以实际会弹告知的那个为准）：显示 CN 文案。
3. iPhone SE（第 3 代）+ 最大动态字体：无截断，按钮可点。
4. 受影响包测试全过，swift-format --strict 与 SwiftLint 0 违规。

## Out of Scope

官网隐私政策（Opus 另行同步）、后端、登录页布局、告知弹层的出现时机。
