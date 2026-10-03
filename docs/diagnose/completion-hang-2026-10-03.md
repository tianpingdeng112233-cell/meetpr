# Completion hang 排障记录（2026-10-03）

结论：**未复现，未修复，根因未确定**。停在阶段 1，没有进入三项改动的隔离、假设或试修；不能据此放行。

## 现场与阶段判据

- 分支 `diagnose/completion-hang`，基线 `2baeae10`；开工工作区干净。不 commit、不 push。
- 原始证据为同目录 `hang-main-thread-sample-2026-10-03.txt`：主线程采样集中于 SwiftUI transaction / lazy layout。该采样没有记录触发前的交互、状态和动画时序，不能单凭堆栈归因到某个业务改动。
- 阶段 1 要求：实际触发此 bug 的稳定红例、无人值守命令和明确超时判定。**未通过**：已构建并运行探针，但没有观察到原始卡死。
- 阶段 2：未进入；没有撤掉三项改动，没有跑 release 基线比较。
- 阶段 3–5：未进入；没有提出或检验根因假设，没有修复，没有声称存在已验证的回归测试。
- 清理：探针明确标为临时诊断，编译开关默认关闭；业务代码没有埋点或改动。Journal 仅记录“没有成立的假设”。这不等于阶段 6 的“原始复现已转绿”。

## 已运行的探针

`MeetPRTests/CompletionHangProbeTests.swift` 在真实 iPhone 17 / iOS 26.5 Simulator 上挂载 `TodayWorkoutView`，复用三组 Competition Deadlift 的 Demo 计划、真实 ViewModel、InMemory 仓储和真实 SwiftUI 布局。固定计划时间，先记两组，再在页面挂载后记最后一组；从不手动切换动作列表的折叠状态。

- 最后一组提交后扫描 0 / 16 / 50 / 100 / 200 / 350 ms 的滚动时机，交替使用带动画和无动画的滚动。
- 24 次无录入页探针：提交最后一组、滚动、调用完成入口，未复现。
- 100 次带录入页探针：呈现真实 `SetEntrySheet`，提交最后一组后立即收起，在上述时窗滚动，等待 1.1 s（长按时长），调用完成入口，未复现。
- 最终文件加编译开关、拆分辅助函数后，六个时窗各复跑一次，全部通过。累计 130 次。
- 每轮独立 detached 看门狗：8 s 内未完成该轮就终止测试。另用主线程 RunLoop 的 `beforeWaiting` 计数判断恢复空闲，并断言 reward controller 已呈现。没有用 ViewModel 状态机单测替代真实布局。

**边界**：该探针直接调用 `completeCurrentDay()`，未驱动 Hold 按钮的触摸/震动/回弹，也没有复用 `TodayWorkoutView` 私有 editing binding；录入页用 UIKit 全屏托管呈现和收起。隔离窗口没有原 App tab 容器。奖励页断言是 controller 存在，并非奖励页内容的无障碍断言。日期固定但框架调度未固定；未证明复现率，更不是确定性红例。

首次截图发现系统通知授权弹窗；100 次批次第 24 轮后关闭弹窗，后续无人值守。整批 MCP 调用在 300 s 超时，底层 xcodebuild 随后完成，测试耗时 303.742 s，最终 `TEST EXECUTE SUCCEEDED`。不能把该工具超时计作 App 卡死。

## 命令与原始输出

可在有 Simulator 权限的终端重跑：

```sh
HANG_PROBE_ITERATIONS=6 bash scripts/diagnose-completion-hang.sh
```

脚本只做同一探针的 CLI 封装，已检查 `bash -n`；本会话实跑使用 XcodeBuildMCP 的两段式 build-for-testing / test-without-building，而非执行这个脚本。以下是最终实跑工具参数，可独立复用：

```javascript
session_set_defaults({
  projectPath: "/Users/david/Projects/apps/MeetPR-wt-hang/MeetPR.xcodeproj",
  scheme: "MeetPR-DemoStudent", configuration: "Debug",
  simulatorId: "A5119984-9A8D-415C-83D4-E7145351FA79",
  derivedDataPath: "/tmp/MeetPR-completion-hang-derived"
});
test_sim({
  extraArgs: ["-skipPackageUpdates",
    "-only-testing:MeetPRTests/CompletionHangProbeTests",
    "-parallel-testing-enabled", "NO",
    "OTHER_SWIFT_FLAGS=$(inherited) -D COMPLETION_HANG_PROBE"],
  testRunnerEnv: {HANG_PROBE: "1", HANG_PROBE_SHEET: "1", HANG_PROBE_ITERATIONS: "6"}
});
```

输出摘录（完整逐轮摘录见 [probe output](completion-hang-probe-output-2026-10-03.txt)）：

```text
HANG-PROBE PASS iteration=99 sheet=true delayMs=100
Test run with 1 test in 1 suite passed after 303.742 seconds.
** TEST EXECUTE SUCCEEDED **
```

上面 PASS 行省略 idleDelta 字段。**bug 红输出：没有。修复后绿输出：没有。** 这些是修改业务代码之前的未复现结果。

### 构建边界

最初使用 `MeetPR-DemoStudent / DemoStudent` 托管测试，遇到 `StudentKit` 未启用 `-enable-testing`；命令加 `ENABLE_TESTABILITY=YES` 后该错误消失，但 App 仍缺 `RepositoryContracts.InMemoryVideoMarkerRepository` 和 `PendingVideoItem` 链接符号。补编译条件和关闭 dead stripping 均未解决。改用同 scheme 的 `Debug` configuration 才跑通隔离探针，因此不能称为原 Demo 配置的托管测试通过。未修改 pbxproj、依赖、签名或任何业务源码。

### 原 Demo 配置实屏补跑

随后 `MeetPR-DemoStudent / DemoStudent` 使用 `build_run_sim({extraArgs:["-skipPackageUpdates"]})` 构建启动成功，0 warning。iPhone 17 / iOS 26.5 实际逐组录入 3 组（前两组后点 Skip 关闭休息条），不手动折叠/展开动作列表；最后一组保存后滚到底部、真实长按 1300 ms，奖励页正常呈现且无障碍树可读，**未复现**。[奖励页截图](completion-hang-demo-not-reproduced-2026-10-03.jpg)。工具自动等待快照，不能证明这次命中了收起动画未结束的时间窗；不是稳定的无人值守复现命令。

构建日志：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-hang-884474953f5a/logs/build_run_sim_2026-10-03T07-59-43-627Z_pid88443_4d7f9e8d.log`。

## 改动文件与检查

- `MeetPRTests/CompletionHangProbeTests.swift`：默认不编译的临时探针，需 `COMPLETION_HANG_PROBE` 和 `HANG_PROBE=1` 双开关。
- `scripts/diagnose-completion-hang.sh`：探针命令封装。
- `docs/diagnose/completion-hang-2026-10-03.md`：本记录。
- `docs/diagnose/completion-hang-probe-output-2026-10-03.txt`：原始输出摘录。
- `docs/diagnose/completion-hang-demo-not-reproduced-2026-10-03.jpg`：原 Demo 配置奖励页截图。
- `docs/CODEX-JOURNAL.md`：末尾追加本轮结论。

探针 SwiftLint strict / swift-format strict、脚本 `bash -n`、`git diff --check` 均通过。无业务改动，未重跑九包全量逻辑测试。临时诊断日志前缀检查无命中。

## 后续需要的证据

优先补齐原容器中的无人值守交互：用 UI test 驱动真实组录入保存 → 收起未结束即滚动 → 持续按住 Hold，覆盖私有 editing binding 和按钮动画。当前 target 是 App 托管单测，尚无 UI test target；本次未擅自改 pbxproj 新建 target。

若人工先复现，请保留从最后一组保存前开始的屏幕录像与时刻、目标构建 SHA / configuration / runtime、当次模拟器 App 日志和卡住时的连续主线程采样；在恢复/重启前取证。已有单次堆栈不足以恢复动画与触摸时间窗。

在出现稳定红例前，不应撤掉动画、替换布局容器或延迟奖励页来宣称修复。
