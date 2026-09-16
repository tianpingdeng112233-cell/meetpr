# 1.0(22) 切包准备 — 2026-09-16

## 已确认范围

David 明确要求“切包发车”。从 release/1.0@a1a578e9 准备，#338–#343 六项均已 MERGED，逐个 merge commit 已验证是 origin/release/1.0 祖先。main 未带入。

- #338 动作库与别名同步。
- #339 学员计划自动刷新与推送路由。
- #340 学员消费教练后移；网页/后端功能尚未启用，见下方限制。
- #341 装饰动效清理与统一按压。
- #342 快捷补记。
- #343 e1RM 来源详情与训练历史入口。

## 号与取包树

- 现场 agvtool 当前 21；MARKETING_VERSION=1.0。
- ASC MeetPR（app 6783772277）TestFlight iOS Builds 现场核实最高上传 1.0(21)，Complete，页面显示 Aug 23, 2026 11:03 PM；build 21 为 Testing，含 Neice/Ceshi。来源：[ASC 构建列表](https://appstoreconnect.apple.com/teams/f0e70ca1-8545-4f02-8e6f-81f8858f7911/apps/6783772277/testflight/ios)。本次未上传 22。
- 本地/远端未占用 beta/1.0-22；agvtool new-version 22，不使用 -all，保持 Info.plist 变量与 marketing version。
- 专用取包树：`/Users/david/Projects/apps/MeetPR-release-1.0-22`。原 `MeetPR-release` 有未提交 scheme、xcstrings、用户界面状态，不覆盖、不清理；本次使用新树。
- Archive 使用 `MeetPR` scheme（ArchiveAction=Release）；Demo 两个 scheme 仅作模拟器验收。

## 四基线与验证

含 bump 的准确切包 SHA、tag CI、双端已安装 build 与截图在验收后补记。准备前教练 iPhone 17、学员 iPhone 17 Pro 的 CN app 已安装号均为 21（直接读取 simulator Bundle/Application 下 Info.plist）。

## 发布边界

- backend #276 / 0070 / 镜像 / gate、web #101、APNs production 与实际送达未完成。本包包括 iOS 支持，不代表后移全链路已上线；推荐日期已有 shiftedToDate，nil 回落 scheduledDate，新推送种类仅增加消费路径。
- ASC Apps 页面提示 Apple Developer Program License Agreement Updated，需要 Account Holder 审阅并接受更新协议。由 David 本人处理；本次未接受任何协议。欧盟 trader status 提示属于 App Store EU 分发事项，不作为已完成项。
- Archive / Upload 仍由 David 手动。收到上传确认后再将本包移入 RELEASES 并开启下一包台账。

## 迁移后流程复核

本次使用独立取包树保留他人改动；ASC 首次旧会话失败后以新页面恢复并核实真实 build，避免使用旧记忆代替现场。已有六项代码审查和 PR CI 沿用，build 号只做配置断言并由 tag CI 验证，不重复功能实现审查。
