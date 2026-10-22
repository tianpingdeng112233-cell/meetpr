# 教练冷启动卡顿：开发取证

工作树 `MeetPR-wt-coach-launch-hang`，分支 `fix/coach-launch-hang`，基线 `b2afd513`。
未 commit/push；未改导航、tab、业务数据、正式依赖声明或发版信息。

## 已定位的机制

首页有训练日时，周概况比例条的 `containerRelativeFrame` 祖先容器尺寸查询会使冷启动布局不收敛，主线程不能处理后续事件。只移除该查询转绿，恢复原代码再次变红；汇总计算与 tab host 保持原样。最终改用固定高度 `GeometryReader` 的局部宽度，保留人数比例、段间距、颜色与其他 UI。

此为 iPhone 17e / iOS 26.5 上真实 `MeetPRApp → RootView → CoachRootView → CoachDashboardView` 路径的复现与修复。fixture 是已有 spec 092 的两学员计划/日志，经真实仓库注入；不是替换首页。未用真实账号，不能据此宣称 David 真机已根治。

## 红绿数字

| 阶段 | 结果 | 主线程响应 | Profile 点击至目标页 |
| --- | --- | --- | --- |
| 原始完整 fixture | 3/3 红 | 均 >3000 ms | AX 0 targets，无法处理交互 |
| 最小数据：1 学员、1 日、0 日志 | 红 | >3000 ms | 无响应 |
| 再去掉最后 1 日 | 绿 | 0.039125 ms | 995 ms |
| 只去掉容器查询 | 绿 | 0.028292 ms | 1059 ms |
| 恢复原容器查询 | 红 | >3000 ms | 无响应 |
| 回归测试，修前 | 红 | >3000 ms | 无响应 |
| 最终回归 1 | 绿 | 0.074542 ms | 2277 ms |
| 最终回归 2 | 绿 | 0.047875 ms | 1572 ms |
| 最终回归 3 | 绿 | 0.040083 ms | 1040 ms |

每次 watchdog 判定约 5–6.2 秒；包含截图/AX读取/点击时整个 agent 调用约 7–11 秒，不含首次编译。点击耗时包含自动化工具往返；编译并行时第 1 次较慢，仍在 3000 ms 阈值内。每次均终止旧进程再启动。

截图：[修前首屏](regression-red.jpg)、[最终首屏](final-green-1.jpg)。两张已亲眼查看。最终首屏有周表、比例条和原四个 tab，Profile 点击断言通过。

`red-1/red-2/control-default.json` 是初版 harness 过早读文件的 ERROR，不能计作红例；其稍后出现的 txt 保留为原始记录。正式基线是 `baseline-red-*`。另一次测试工具调用等待过久已中止，用 Home 恢复后重新冷启动运行 `regression-red`；中止调用不计入红绿数字。

## 重跑命令

脚本是供 `functions.exec` 调用的 MCP orchestration 表达式，不能当作普通 Node CLI。前置构建仍通过 XcodeBuildMCP；无需账号、手点或对工程结构做改动。

一次性准备（functions.exec）：

```javascript
await tools.mcp__XcodeBuildMCP__session_show_defaults({});
await tools.mcp__XcodeBuildMCP__session_set_defaults({
  projectPath: "/Users/david/Projects/apps/MeetPR-wt-coach-launch-hang/MeetPR.xcodeproj",
  scheme: "MeetPR-Demo", configuration: "Demo",
  simulatorId: "5D5FA360-BA49-48C6-A887-2F0D22F89749",
  derivedDataPath: "/Users/david/Projects/apps/MeetPR-wt-coach-launch-hang/.build/coachhang-derived",
  bundleId: "com.meetpr.app", persist: false
});
await tools.mcp__XcodeBuildMCP__build_run_sim({
  extraArgs: ["CODE_SIGNING_ALLOWED=NO", "OTHER_SWIFT_FLAGS=$(inherited) -D COACH_LAUNCH_HANG_TESTING"]
});
```

已实际执行的单条回归命令（functions.exec）：

```javascript
const source = await tools.exec_command({cmd: "cat scripts/diagnose-coach-launch-hang.js", max_output_tokens: 4000});
const result = await eval(source.output)(tools, {name: "final-green-1", screenshot: true});
text(result);
```

脚本中的 Python 断言修前 exit 1、修后 exit 0；返回 JSON 的 `exitCode` 同步该结果。exit 2 是 harness 错误，不能当作应用卡顿。绿色还要求 fixture 的学员行已出现，并能点击 Profile 到 `coach.profile.help`。回归 watchdog 显式检查响应时长 ≤3 秒，防止后台调度延迟误判。`COACH_LAUNCH_HANG_TESTING` 未开启时 watchdog 不编译、fixture 不注入；不会在普通 Demo 或正式包运行。

## 工程验证

- CoachKit：完整 472 项通过，见 `coachkit-offline-tests.log`。
- AppShell：完整 118 项通过，见 `AppShell-mcp-tests.json`。
- DesignSystem：完整 73 项通过，见 `DesignSystem-offline-tests.log`。
- MeetPR / Debug / 同一模拟器：主工程 build 成功（26.466s），9 项宿主测试通过（13.141s）。MCP 记录：`build_sim_2026-10-21T09-42-32-968Z_pid8345_5d3585db.log`、`test_sim_2026-10-21T09-47-45-564Z_pid8345_75503e70.log`。
- 四个改动 Swift 文件 `swift-format lint --strict`、`swiftlint lint --strict` 和 `git diff --check` 通过。没有新增生产编译 warning；离线测试仍有既有第三方及未改动代码的 warning，原输出保留。
- 合计 663 项相关包测试 + 9 项宿主测试 = 672 项。冷启动回归独立于这 672 项，不能由模型单测代替。

包测试最初被 GitHub 下载阻塞；shell 沙箱内两项 Keychain 测试读回失败（共三断言）。没有跳过或改弱测试；AppShell 最终通过 XcodeBuildMCP 原生 SwiftPM 工具完整重跑，全部通过。这与执行环境限制一致，没有把首次失败当作通过。

离线测试副本在 `.build/offline-tests/Modules`：1209 个源码/资源文件与工作树逐字节一致，仅生成副本的 Package.swift 把依赖地址改为本地目录，正式 Package.swift 不变。ViewInspector 为锁定的 `0.10.3`，从 GitHub 只读接口获取 126 个构建所需文件，逐一校验 Git blob SHA；其他依赖复用本树 Xcode 已解析的 checkout。校验清单见 `offline-source-verification.json`、`viewinspector-source-verification.json`。依赖自身的测试没有运行。

CoachKit / DesignSystem 使用的完整包命令（替换 PACKAGE 为对应包名）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache" \
swift test --disable-sandbox --manifest-cache local --skip-update \
  --scratch-path "$PWD/.build/offline-shared" \
  --package-path ".build/offline-tests/Modules/PACKAGE"
```

AppShell 使用 `swift_package_test({packagePath:"<本树>/.build/offline-tests/Modules/AppShell"})`，session configuration=Debug。

## 独立审查与清理

- Standards：初审 1 个 P2（watchdog 只检查有结果，可能放过 >3s）；已显式比较 Duration，定向复核 CLEAN。
- Spec：CLEAN，无实现 blocker；记录真实账号/真机与多组比例条截图的验证边界。
- 一次性数据最小化开关与实验布局已移除。保留的 `.js` 与 Swift watchdog 明确为回归 harness，并由编译开关隔离。
- `rg -n -F '[DEBUG-' MeetPR/Sources Modules --glob '*.swift' --glob '!**/.build/**'` 无匹配。历史原始取证 `.txt/.json` 的旧日志前缀保留，没有篡改证据；不是声称整个仓库历史文本均无该字符串。
- 未来 commit message 草稿：`Fix coach cold-launch layout hang by sizing week legend locally [P0]`。本轮未执行提交。

## 未验边界

真实后端教练账号、David 真机、iOS 17/26.4、多组比例条的实屏截图未验；多组宽度公式保留原 count/span 与 spacing 语义，独立审查已核对，但不冒充像素对比。没有取得系统 sample/Instruments 堆栈；根因依据单变量 A/B/A 和真实主线程响应取证。

Android RN 未读取或运行。本次复现完全离线，触发点是 iOS SwiftUI 布局查询，未发现共享后端同步等待机制，不能推断 RN 有同一故障。
