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

切包 SHA：`0748931563fefea14e7f50a7c9ee7330b5501bea`。annotated tag `beta/1.0-22` 已推送并解引用核对一致。

| 基线 | 现场值与来源 |
|---|---|
| 发版线 tip（切包时） | origin/release/1.0 = 07489315；后续只追加本验收文档与截图，代码不变 |
| beta tag | beta/1.0-22^{commit} = 07489315，本地/远端均已核实 |
| 模拟器已安装 | 教练 iPhone 17 与学员 iPhone 17 Pro 的 com.meetpr.app 均 1.0(22)，直接读取已安装容器 Info.plist |
| ASC 最新已上传 | 1.0(21)，09-16 现场 TestFlight 列表；22 尚未上传 |

双端 demo 专用树 `MeetPR-demo-latest` 已 detached 到准确 tag 07489315，工作树干净。两次 build/run 均 0 warnings / 0 errors，角色与页面亲验：教练 Today 待处理列表；学员训练页 W1D3、历史入口与快捷补记入口。

- [教练截图](evidence/beta-1.0-22/coach.jpg)；[学员截图](evidence/beta-1.0-22/student.jpg)。
- 教练已安装容器：`/Users/david/Library/Developer/CoreSimulator/Devices/A5119984-9A8D-415C-83D4-E7145351FA79/data/Containers/Bundle/Application/1A81D274-0600-449D-83D2-76B8D3E96DB1/MeetPR.app`。
- 学员已安装容器：`/Users/david/Library/Developer/CoreSimulator/Devices/D412AE31-0ED9-4A23-B0FD-FFFA4A5A5609/data/Containers/Bundle/Application/24CF4BC3-120C-48C4-BA6B-52FD2E1256EC/MeetPR.app`。
- build 日志：XcodeBuildMCP `build_run_sim_2026-09-16T07-08-53-848Z_pid93432_f46b3bc8.log`、`build_run_sim_2026-09-16T07-11-47-639Z_pid93432_1ed6ca90.log`，均在 `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/Projects-cf51cf27789e/logs/`。
- [tag CI run 35067056331](https://github.com/tianpingdeng112233-cell/meetpr/actions/runs/35067056331) 的 headSha 已核实为切包 SHA；最终全绿：九包 1,922（30/103/85/443/158/73/131/6/893）、主工程 9 测试、swift-format、SwiftLint 全部成功。

Xcode 已打开本次专用取包工程，MeetPR / Any iOS Device (arm64)。打开后 Xcode 自动重排 TestAction 的 MacroExpansion/Testables，并写用户界面状态；逐项 XML 比较语义完全一致，ArchiveAction 未变。仅这两处本机状态差异留存，不混入提交；源码、build settings 与 tag 一致。

[TestFlight 更新说明与建议测试项](evidence/beta-1.0-22/testflight-notes.txt) 可直接用于上传时说明。

## 交付状态

代码侧可 Archive：使用本次专用工程，MeetPR scheme / Any iOS Device (arm64) → Product → Archive。尚未 Archive 或上传，ASC 最高仍为 21；Apple 协议需 David 在上传前本人处理。完成上传后再核对 ASC 并关闭本包台账。

## 发布边界

- backend #276 / 0070 / 镜像 / gate、web #101、APNs production 与实际送达未完成。本包包括 iOS 支持，不代表后移全链路已上线；推荐日期已有 shiftedToDate，nil 回落 scheduledDate，新推送种类仅增加消费路径。
- ASC Apps 页面提示 Apple Developer Program License Agreement Updated，需要 Account Holder 审阅并接受更新协议。由 David 本人处理；本次未接受任何协议。欧盟 trader status 提示属于 App Store EU 分发事项，不作为已完成项。
- Archive / Upload 仍由 David 手动。收到上传确认后再将本包移入 RELEASES 并开启下一包台账。

## 迁移后流程复核

本次使用独立取包树保留他人改动；ASC 首次旧会话失败后以新页面恢复并核实真实 build，避免使用旧记忆代替现场。已有六项代码审查和 PR CI 沿用，build 号只做配置断言并由 tag CI 验证，不重复功能实现审查。
