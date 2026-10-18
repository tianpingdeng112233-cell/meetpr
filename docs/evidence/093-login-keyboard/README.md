# 093 登录键盘修复验证记录

2026-10-18；worktree `MeetPR-wt-093-keyboard`；分支 `fix/093-login-keyboard`；基线 `9ac4d7fb`。全部改动未提交，未 push。

## 根因与结论

**iPhone 12 上“焦点字段完全被遮挡且不能滚动”的完整根因尚未确认。** 本机只有 iOS 26.4/26.5 模拟器，选择最小可用机型 iPhone 17e（390 × 844 pt），使用 CN `MeetPR` / `Debug`。旧版在该系统上能自动露出焦点字段，但长口号下密码框贴近键盘、登录按钮在键盘下方；在键盘上方有效区域拖动可以滚动。因此不能把 `.basedOnSize`、GeometryReader 的 minHeight 或 NavigationStack 写成已证实的锁死原因。

已确认的代码事实：原登录页靠 GeometryReader/minHeight/Spacer 形成底部表单，三页均没有显式的焦点滚动定位；AuthFlowView/RootView 没有给前景内容设置 `ignoresSafeArea(.keyboard)`。GlobalAuthBackground 的 `ignoresSafeArea()` 只用于背景。最初自动化默认滑动落在键盘或文本输入区域，未移动页面；这不是“ScrollView 锁死”的有效证据。

本次按用户允许的代码分析＋结构测试降级路径加固：共享容器通过 `@FocusedValue` 读取字段目标，在焦点变化及视口缩小时用 `ScrollViewReader.scrollTo` 定位；保留原无键盘布局，统一 `.always` bounce 和 `.interactively` 收键盘。采用的 API 语义参考 [Apple FocusedValue](https://developer.apple.com/documentation/swiftui/focusedvalue) 与 [scrollDismissesKeyboard](https://developer.apple.com/documentation/swiftui/view/scrolldismisseskeyboard(_:))。

为排除文案缩短造成的混淆，额外恢复旧长口号、仅保留滚动修复做对照：邮箱聚焦后，密码和登录按钮自动进入键盘上方。该效果已通过截图确认，但不能替代原 iPhone 12 的复测。最终产物已恢复 David 批准的 `Meet Your\nPR Here.`，en/zh-Hans 只改 `auth.chinaSlogan` 一个 key。

## 文件

- `Sources/AppShell/Auth/Global/AuthFormScrollView.swift`：共享焦点滚动容器、字段目标标记。
- `Sources/AppShell/Auth/Global/GlobalLoginView.swift`：接入容器、邮箱/密码目标；原无键盘 minHeight 和排版保留。
- `Sources/AppShell/Auth/Global/GlobalRegisterView.swift`：邮箱、验证码、密码、确认密码接入。
- `Sources/AppShell/Auth/Global/GlobalForgotPasswordView.swift`：邮箱阶段及 code/newPassword 阶段接入。
- `Sources/AppShell/Resources/Localizable.xcstrings`：批准的 CN 两行文案。
- `Tests/AppShellTests/Auth/GlobalAuthViewTests.swift`：新增两项测试，滚动结构测试参数覆盖 CN/Global。

## 测试与构建

红测试：`swift test --package-path Modules/AppShell --filter 'chinaLoginUsesApprovedTwoLineSloganInBothLanguages|emailAuthFormsExposeFocusedFieldsAsScrollTargets'`（shell 使用独立临时 scratch/module cache）。旧代码结果：

```text
emailAuthFormsExposeFocusedFieldsAsScrollTargets: Search did not find a match
chinaLoginUsesApprovedTwoLineSloganInBothLanguages: old slogan != Meet Your\nPR Here.
Test run with 2 tests ... failed ... with 3 issues.
```

修后 XcodeBuildMCP `swift_package_test`（对应 `swift test --package-path Modules/AppShell`）：

```text
118 tests passed, 0 failed, 0 skipped (5.0s)
```

结构测试只证明三页的 ScrollViewReader 与稳定字段 ID 接线，**不能模拟 UIKit 软件键盘/视口布局**；没有能替代模拟器的纯单元测试 seam。几何避让、滚动和无键盘外观以下方截图为证。

- CN Debug 最终构建成功，0 warnings / 0 errors；临时 reset 入口已删除后重新构建。
- Global 配置构建成功，0 warnings / 0 errors。
- 五个变动 Swift 文件 `swiftlint lint --strict --no-cache`：`Found 0 violations, 0 serious in 5 files.`
- 同五文件 `swift-format lint --strict`：无输出，成功；`git diff --check` 成功。
- Global 无键盘前后 JPEG 均为 369 × 800；比较 `(0,60)-(369,800)` 内容区域：`diff bbox: None`，RGB 平均差异 `[0.0, 0.0, 0.0]`，完全一致。状态栏时间不参与比较。

日志路径（本机）：

- 红测试：`/tmp/093-keyboard-red.log`
- 最终全量测试：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-093-keyboard-e4c9a5e629cb/logs/swift_package_test_2026-10-18T03-23-21-524Z_pid62775_07ce3691.log`
- CN 最终 build：同目录 `build_run_sim_2026-10-18T03-22-43-215Z_pid62775_af1b4c87.log`
- Global build：同目录 `build_run_sim_2026-10-18T03-19-40-538Z_pid62775_8dd07468.log`
- lint/format：`/tmp/093-keyboard-lint-final.log`、`/tmp/093-keyboard-format-final.log`

环境说明：首次下载依赖遇到 GitHub 超时，后续使用本机同版本缓存。普通受限 shell 全量测试有两项 Keychain 测试因权限失败；正式 XcodeBuildMCP 重跑基线 116/116、最终 118/118 均通过，未改测试绕过权限问题。

## 截图与操作

目录：[docs/evidence/093-login-keyboard]()。软件键盘已打开，均未提交表单。`MEETPR_API_BASE_URL=http://127.0.0.1:9` 固定在所有启动环境；Global 自动 challenge 只访问该本机空端口，前后同样出现离线 toast；没有访问 staging。

| 场景 | 修前 | 修后 |
| --- | --- | --- |
| CN 登录邮箱聚焦 | [before-cn-login-email.jpg](before-cn-login-email.jpg) | [after-cn-login-email.jpg](after-cn-login-email.jpg) |
| CN 登录密码聚焦 | [before-cn-login-password.jpg](before-cn-login-password.jpg) | [after-cn-login-password.jpg](after-cn-login-password.jpg) |
| CN 注册验证码 | [before-cn-register-code.jpg](before-cn-register-code.jpg) | [after-cn-register-code.jpg](after-cn-register-code.jpg) |
| CN 注册确认密码 | [before-cn-register-confirm-password.jpg](before-cn-register-confirm-password.jpg) | [after-cn-register-confirm-password.jpg](after-cn-register-confirm-password.jpg) |
| CN 找回邮箱 | [before-cn-forgot-email.jpg](before-cn-forgot-email.jpg) | [after-cn-forgot-email.jpg](after-cn-forgot-email.jpg) |
| CN 找回 code（本地状态注入） | [before-cn-forgot-code-local-fixture.jpg](before-cn-forgot-code-local-fixture.jpg) | [after-cn-forgot-code-local-fixture.jpg](after-cn-forgot-code-local-fixture.jpg) |
| CN 找回新密码（本地状态注入） | [before-cn-forgot-password-local-fixture.jpg](before-cn-forgot-password-local-fixture.jpg) | [after-cn-forgot-password-local-fixture.jpg](after-cn-forgot-password-local-fixture.jpg) |
| Global 无键盘 | [before-global-login-no-keyboard.jpg](before-global-login-no-keyboard.jpg) | [after-global-login-no-keyboard.jpg](after-global-login-no-keyboard.jpg) |

补充证据：

- 注册页键盘展开时，页面边缘上下拖动产生可见位移：[下滚](after-cn-register-scroll-down.jpg)、[上滚](after-cn-register-scroll-up.jpg)。中间输入框会优先处理文本手势，复测拖动位置选页面左侧边缘。
- 登录旧版的有效区域上滑：[before-cn-login-visible-area-swipe.jpg](before-cn-login-visible-area-swipe.jpg)，说明在此模拟器上并非滚动锁死。
- 保留旧长口号的独立加固对照：[邮箱](probe-scroll-fix-original-slogan-email.jpg)、[密码](probe-scroll-fix-original-slogan-password.jpg)。
- 最终新口号无键盘：[after-cn-login-no-keyboard.jpg](after-cn-login-no-keyboard.jpg)；Global 密码聚焦：[after-global-login-password.jpg](after-global-login-password.jpg)。
- `before-cn-login-keyboard-hidden.jpg` 是首次环境排障截图；两个 `*-after-swipe.jpg` 是自动化手势无效的记录，不能据此声称滚动被锁。

找回第二步对照临时在 AppShell AuthFlowView 注入 `GlobalForgotPasswordViewModel.step = .reset`，没有发送验证码、没有走真实服务；修前/修后使用相同入口。入口和所有临时恢复的旧代码均已清除，AuthFlowView 不在最终 diff 中。

## 独立审查

使用 review-loop 本地未提交双轴审查，一轮。Standards 与 Spec reviewer 均只读，无阻塞 finding；都明确结构测试的几何验证限制。未调用基于 tracker 的 code-review 流程（仓内未配置 `docs/agents/issue-tracker.md`；该流程需先运行 `$setup-matt-pocock-skills`）。

剩余不确定项：iPhone 12 原始系统/键盘组合的完整故障未复现，仍需该真机回测；不宣称其根因已确认或整项产品验收已通过。
