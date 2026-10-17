# Spec 093 iOS 开发证据（2026-10-17）

工作树 `MeetPR-wt-093`，分支 `feat/093-cn-email-onboarding`，基线 `f2d44394`（release/1.0，beta/1.0-24）。本记录是开发自测，正式收货依 CARDS / SPEC。未发布 TestFlight / APK，未合并。

## I1 / I2 改动

- CN 使用现有 Global 邮箱登录、注册、找回密码页面；隐藏 Apple/Google，保留 Global 三入口；Session bootstrap、Keychain 与已登录主界面路径不变。
- CN 注册增加 6 位码、发送/60 秒冷却/重发/换邮箱清空、确认密码；验证码错误描红并立即允许重发，已发送行由错误行替代，帮助中的登录可点；邮箱已注册可回登录；提交期间锁定四输入。
- 字体修复根因：旧 AuthSecureField 把 mono18 + tracking2.52 施给中文 placeholder，邮箱是 body16 semibold，新验证码是 mono16 regular。CN 四输入统一 body16 semibold/tracking0，标签独立 body12 semibold。Global/旧手机号默认样式保留。确定性视觉问题用真实截图前后复验，无字体常量镜像单测。
- 两轨邀请码提取优先 `/i/CODE` 链接，再独立 4-3-3 / 10 字符码；CN 点击后才读剪贴板。CN 教练个人页和邀请码页复制完整消息，永久码提供系统 ShareLink；Global 保留纯码。

## 测试

使用 XcodeBuildMCP `swift_package_test(packagePath: .../Modules/<module>)`，等价命令 `swift test --package-path Modules/<module>`：

| 模块 | 通过 | 最终日志名 |
| --- | ---: | --- |
| AppShell | 116 | swift_package_test_2026-10-17T05-00-39-486Z_pid54844_170adde7.log |
| Networking | 139 | swift_package_test_2026-10-17T04-49-22-234Z_pid54844_c0af54db.log |
| CoreModels | 159 | swift_package_test_2026-10-17T04-49-24-219Z_pid54844_61d87922.log |
| CoachKit | 456 | swift_package_test_2026-10-17T04-49-24-973Z_pid54844_8f240613.log |
| StudentKit | 1021 | swift_package_test_2026-10-17T04-49-28-884Z_pid54844_fd8f4980.log |

合计 1891。日志根：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/Projects-cf51cf27789e/logs/`。

新行为先红后绿：Networking 注册 code payload 与发码 endpoint；CN 校验/换邮箱/冷却/错误码/邮箱已注册/提交锁定；Session code 透传；链接优先提取、整段输入；邀请模板使用真实 catalog。定向返修红日志：`swift_package_test_2026-10-17T04-57-21-261Z_pid54844_db7f77f8.log`（新错误状态 seam 未实现）、`...04-58-46-092Z_pid54844_e5cfcec7.log`（提交锁定 seam）、`...05-00-24-714Z_pid54844_44e81f1c.log`（错误后帮助行缺失）。

`swift-format format --in-place` 后修改 Swift 的 `swiftlint lint --quiet`、`git diff --check` 通过。CN 最终 Xcode `build_run_sim`：`build_run_sim_2026-10-17T05-00-46-357Z_pid54844_fbdd83ff.log`，17.5s，无 warning/error。设备 MeetPR-CI / iOS 26.5，UDID `F0E774D8-6FCC-45EE-A38F-6AF66D4C0AA8`；DerivedData `/tmp/meetpr-spec093-ios-derived`。

## 截图

- `cn-login.jpg`：CN 登录，无社交入口，三行英文标语。
- `cn-register.jpg`：字体修正后的空表单。
- `cn-register-code-sent.jpg`：明确 localhost 后重拍，已发送 + 冷却。
- `cn-forgot-email.jpg`：首步找回密码标题。
- `cn-forgot-code.jpg`：明确 localhost 后重拍，第二步重置密码。
- `cn-coach-profile-copy.jpg`：本地合成教练点击个人页复制。
- `cn-coach-invites-copy.jpg`：本地邀请码页点击复制。
- `cn-coach-share.jpg`：系统分享预览，内容以完整邀请消息开头。
- `cn-student-paste-message.jpg`：本地合成学员点击粘贴，从刚复制的完整消息抽出 XK7MPQ2RVT。

以上图片亲眼检查。原先名称不准确的 mismatch 截图已移除；不宣称它证明密码不一致态。

## 复现与环境偏差

本机 fixture 在 `127.0.0.1:3095`，合成数据不转发。启动脚本见 `fixture.py`。XcodeBuildMCP session defaults 内虽设置 `MEETPR_API_BASE_URL`，本次 `build_run_sim` 启动并未有效应用该 env（同一假账号登录返回错误）；改为 `stop_app_sim` 后显式 `launch_app_sim(env: {MEETPR_API_BASE_URL: "http://127.0.0.1:3095"})` 才确认本地收到请求并成功进入合成 coach 首页。后续网络操作前核对本地日志。

**边界偏差（已只读审计）**：显式 launch 修正之前点击过合成邮箱注册发码、forgot 发送和假密码登录；未提交注册或密码重置。主代理通过已登录 DMS 查询国内 staging：2026-10-17 04:30 UTC 之后，该合成学员邮箱的注册验证码记录为 **3**，首条 04:49:50 UTC、末条 04:55:30 UTC；同一邮箱的新增重置码为 **0**，两个合成邮箱的新增 users 为 **0**。这确认注册发码误请求了远端，发生在本轮统一部署批准前，是执行失误，不能称为纯本地或已获授权的 staging 验证。已向 David 披露；没有删除远端痕迹、补写或回滚。邮件服务实际投递结果未核实。只读原始结果保存在仓外私有部署审查目录 `ios-environment-audit.txt`。发码截图已在确认 localhost 后替换；B0 真实账号没有用于这次操作。

`fixture-requests.log` 只记 method/path，不含 body、邮箱、密码或 token。系统保存密码/强密码提示有时未出现在 MCP semantic snapshot，使用 CUA 读实际屏幕关闭，没有保存合成密码。该工具局限不应误判成 App 输入问题。

## 未验 / 人工作业

- 国内 staging 全链路与两个旧账号存量数据：本轮未执行，待部署批准后的主流程。
- 双端真实忘记密码 / 邮件码 / 新密码登录：David 填写：____。
- QQ/163 真邮箱收件箱/垃圾箱：David 填写：____。
- iOS beta24 已登录升级：David 填写：____。本轮只做代码保留与本地 Session 回归，没有替代该升级检查。
- 未上传 TestFlight；当前截图来自模拟器，未做真机。此前误发码的远端记录已在上节披露，邮件投递状态未核实。

## 最后补证

- Global / Global 配置 Xcode 编译通过，191.1s、无 warning/error：`build_run_sim_2026-10-17T05-06-37-645Z_pid54844_ae1dd897.log`。编译工具自动启动后立即停止，再以显式 localhost env 重启才操作。
- `global-login.jpg`：Apple、Google、邮箱三入口保留，英文原文从单一 catalog 读取。
- `global-student-no-paste.jpg`：合成学员绑定页没有 CN 的粘贴按钮。
- `global-coach-no-share.jpg`：Global 永久码页仍仅复制/重新生成，无 CN 分享入口。
- `global-copy-plain-code.jpg`：邀请码页复制后粘贴到未提交的登录输入框，实际为纯码 XK7MPQ2RVT。借输入框观察剪贴板，不是一次登录测试。
- `cn-student-paste-unrelated.jpg`：复制无关合成文本后点击粘贴，提示「复制的内容里没有找到邀请码」，输入不变。
- `cn-student-paste-link.jpg`：用姓名框作为本地剪贴板中转，复制合成裸链接再点击粘贴，得到 XK7MPQ2RVT；没有提交绑定申请，也没有保存姓名框中的链接。
- CUA 的 `super+a` / `super+c` 在真实 iOS 输入框内可复制；macOS clipboard paste API 不能可靠同步 simulator，故不把该失败操作作为 App 缺陷。

最后一次检查：28 个改动 Swift 文件 SwiftLint 通过，`git diff --check` 通过。共 15 张截图。CN / Global 测试进程已停止，本地 fixture 服务已停止；未删除模拟器、未清空用户 App 数据。session defaults 留本工作树 CN / Debug，后续必须显式 launch env。
