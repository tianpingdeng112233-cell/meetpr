# Spec 111 iOS 验收证据

设备：iPhone 17e，iOS 26.5；DemoStudent；2026-11-17。

| 状态 | 浅色 | 深色 |
| --- | --- | --- |
| 首次／设置圆盘 R0/R5 | [首次自动弹出](R0-light.jpg)、[最终版长按设置](R5-light.jpg) | [同一设置盘](R0-R5-dark.jpg) |
| 待机 R1 | [最终位置](R1-light.jpg)、[首次提示](R1-first-hint-light.jpg) | [待机](R1-dark.jpg) |
| 计时 R2 | [计时](R2-light.jpg) | [计时](R2-dark.jpg) |
| 展开 R3 | [展开](R3-light.jpg) | [展开](R3-dark.jpg)、[最后 10 秒数字变金](R3-last-ten-dark.png) |
| 结束 R4 | [结束](R4-light.png) | [结束](R4-dark.png) |

附加：[提醒开关关闭](R5-alerts-off-dark.jpg)、[拖动左侧吸边](drag-left-dark.jpg)、[重启位置恢复](position-restored.jpg)、[英文设置](R5-en.jpg)、[英文计时盘](R3-en.jpg)、[繁体设置](R5-zh-Hant.jpg)、[繁体计时盘](R3-zh-Hant.jpg)。R4 与最后 10 秒图从 XcodeBuildMCP 模拟器录屏直接提取，未重绘界面。

R0 首次自动弹出与 R1 首次提示在第一轮成功构建取证，随后修复了圆环到完成按钮多计入的 12pt 容器内边距；其余截图来自最终增量构建。

## 行为现场记录

- 首次进入可练日自动弹盘；点圆盘外黑罩保存并收起，出现首次气泡；轻点启动后气泡消失；重启不再自动弹盘。
- 长按圆环打开设置；两个开关切为关闭，保存后仍为关闭。
- 轻点运行圆环打开居中计时盘，点黑罩收起仍继续；`-15s` 可减到 0，显示结束态后回待机。
- 深色运行中切到「我的」时无圆环；返回训练时剩余由 1:43 延续至 1:14，没有重置到 3:00。
- 左拖吸边，仍显示待机 3:00，没有触发轻点计时或长按设置；上拖不会越过周条；重启后恢复左侧与相同高度。

## 自动化证据

- `studentkit-tests.txt`：最终 MCP 非并行全量 1333 通过、0 失败、0 跳过（116.544 秒）；没有改断言或跳过用例。中间并行高延迟失败记录保留于 `studentkit-parallel-timeouts.txt`。
- `seam-green.log`：9 个模型／控制器 seam 通过；`tdd-reds.log`、`background-red.log`：先红记录。
- `swiftlint.log`、`swift-format.log`：改动文件严格 lint / format；空 format 日志表示无诊断。

声音、触感、静音键与真实锁屏／灵动岛行为必须真机验收。后台通知独立震动控制的 iOS API 差异见本卡 JOURNAL。

## 返修 1：首次弹层让位

2026-11-17，仍用 iPhone 17e / iOS 26.5。修复前后均通过主屏「移除 App → 删除 App」清掉本地标记后重装。

DemoStudent 默认禁用 Analytics，不显示使用数据告知。取证时临时应用 [取证补丁](fix1-privacy-harness.patch)，以 `--spec111-privacy-notice` 启动，复用 AppShell 原有告知、持久化标记和确认回调；Analytics 仍为 disabled，不上传数据。补丁已从交付源码移除，并再次构建成功。该补丁只供复现，不能合入产品。

修复前没有看到安卓式的两个可见弹层叠加，但确认存在呈现竞争：[全新启动 R0 抢先显示](fix1-before-R0-wins.jpg)，保存 R0 并重启后，[告知才出现](fix1-before-notice-after-relaunch.jpg)。

修复后亲看顺序：

1. [全新启动先显示使用数据告知](fix1-after-01-privacy-notice.jpg)，无 R0／悬浮圆环。
2. 点击「知道了」，等 sheet 的实际 `onDismiss` 后，[R0 才出现](fix1-after-02-R0.jpg)，无需重启。
3. 保持首次设置未完成，重启使用既有 `--plan-handoff-demo joined`：[周期接续提示显示时不弹 R0](fix1-after-03-handoff.jpg)。
4. 点击接续提示关闭按钮，[R0 随即出现](fix1-after-04-handoff-dismissed-R0.jpg)。

自动化与审查：

- [第一个红测试](fix1-first-settings-red.log)、[抢占场景红测试](fix1-preemption-red.log)、[两个 seam 变绿](fix1-seam-green.log)：其他弹层阻挡、关闭后弹出、未完成设置被抢占后可恢复、离开训练页不弹。
- [StudentKit 全量](fix1-studentkit-tests.log)：1335 tests / 93 suites 全通过，测试执行 145.430 秒。MCP 请求在 300 秒超时，后台编译／测试继续完成；判定依据为日志末尾的完整测试汇总。
- [iOS 取证构建](fix1-ios-build.log)及[移除取证开关后的最终构建](fix1-final-ios-build.log)：均成功，后者 12.5 秒、无诊断 warning/error。此次使用 `SWIFT_OPTIMIZATION_LEVEL=-Onone`，未修改工程配置；早期优化构建超过工具超时后也完成，但未用其产物判定最终交付。
- [SwiftLint strict](fix1-swiftlint.log)／[swift-format strict](fix1-swift-format.log)：返修涉及的 12 个 Swift 文件均通过，空日志表示无诊断。
- [Standards / Spec 独立审查](fix1-review.md)：两路定向复审 CLEAN。
- [AppShell 告知测试补跑](fix1-appshell-dependency-failure.log)：筛选 `analyticsPrivacy`，因 ViewInspector 拉取超时／HTTP2 错误而未进入测试；不计为通过。AppShell 最终代码已由上述 iOS 构建和告知 UI 复走验证。
- [本轮代码增量](fix1-changes.patch)：以返修前未提交卡为基线，不含临时取证开关。

spec 095 欢迎页、历史导入 review、训练页其余 sheet／alert／confirmationDialog 的阻挡状态已接入；本轮未逐项做端到端截图，状态门禁由代码审查和上述 seam 覆盖。取证结束后保存首次设置并停止 Demo App。
