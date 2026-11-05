# P0 · iOS chat plus sheet autoclose · 2026-11-05

## Scope and state

- David 派卡；只诊断 Phase 1–3，Phase 3 写出后等待确认。不得 commit/push。
- 分支 `fix/chat-plus-sheet-autoclose`，HEAD / 本地 `origin/release/1.0` 均为 `09eef51d84c3ae253eabcf1be8e5664cc0b6a777`；开工工作区干净。
- 已读 CONTEXT、CLAUDE、AGENTS、FOLLOWUPS、memory INDEX、engineering-workflow、diagnosing-bugs、xcodebuildmcp、ADR-005 相关边界；未触发本卡范围内的额外 FOLLOWUPS 工作。
- 只使用 iPhone 17e，iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`；未操作其他模拟器。
- XcodeBuildMCP defaults：本 worktree `MeetPR.xcodeproj`、`MeetPR-DemoStudent`、`DemoStudent`、DerivedData `/tmp/c7p1-derived`。
- 用户录屏抽帧：`/Users/david/Projects/scratch/chat-plus-autoclose-20261105/sheet_{1,2}.png`。可见选组 sheet 多次出现后消失。

## Phase 1 — complete

### 尝试与反馈环

1. 现有工程没有 UI test target，只有 hosted Swift Testing；已有 `CompletionHangProbeTests.swift` 挂载 View 范例。纯 `SetRefPickerPresentation` / VM 单测无法观察 SwiftUI sheet 的实际消失，未用浅层状态测试充数。
2. XcodeBuildMCP `build_run_sim({})` 成功，首轮 108 秒；后续复现无需重编译。
3. 直接 snapshot + tap + `wait_for_ui(identifier: chat.setRef.confirm)` 超时，但不能证明 sheet 先出现，因此没有把此超时算红灯。录屏证明 snapshot 漏掉了短暂 sheet。
4. XcodeBuildMCP shell CLI 因 sandbox 内 daemon 启动失败不可用；沿用仓内 `diagnose-coach-launch-hang.js` 的 `functions.exec` runner 形式，仍通过 XcodeBuildMCP 操作模拟器。
5. Apple Vision OCR 在当前执行环境返回 `nilError`（CPU 模式也一样），故使用已安装 Pillow + ffmpeg 进行视觉断言，不引入产品依赖。模板为本机真实 sheet 的「问教练」标题；二值化、固定横坐标、纵向扫描覆盖上弹动画。阈值 20，实际可见帧误差 0–12.4，无 sheet 帧约 68。
6. 深色必须用 `launch_app_sim({launchArgs:["-meetpr.appearance","dark"]})`；`-AppleInterfaceStyle Dark` 被应用自己的外观偏好覆盖，早期两个录屏仍为浅色，不算深色证据。

### 已跑过的单条命令（functions.exec）

```javascript
const script = await tools.exec_command({cmd:"cat scripts/diagnose-chat-plus-autoclose.js",max_output_tokens:2500});
text(await eval(script.output)(tools,{name:"baseline-1"}));
```

前置：上述 defaults，构建后的 DemoStudent 已用 `-meetpr.appearance dark` 启动。脚本自动从今日页点消息入口或使用当前聊天页，录屏后只点一次「分享今日训练」，观察期间不选组、不发送、不关闭。未确认 sheet 曾出现则返回 2（INCONCLUSIVE），不会假报 bug。

脱敏输出（无凭证、全部 Demo 数据）：

```text
baseline-1 exitCode=1 firstVisible=0.7s lastVisible=1.3s observed=4.5s visibleFrames=7 postTapInputs=0 wall=5961ms
baseline-2 exitCode=1 firstVisible=0.6s lastVisible=1.2s observed=4.7s visibleFrames=7 postTapInputs=0 wall=5987ms
baseline-3 exitCode=1 firstVisible=0.7s lastVisible=1.3s observed=4.6s visibleFrames=7 postTapInputs=0 wall=5899ms
FAIL: sheet appeared then disappeared without further input
```

原始录屏 `/tmp/c7p1/baseline-{1,2,3}.mp4`。模板与 oracle 暂存 `scripts/chat-plus-probe/`；runner 为 `scripts/diagnose-chat-plus-autoclose.js`。Phase 6 删除一次性 harness。

完成判据：真实按钮→真实 StudentBlackGoldChatView.sheet→真实 SetRefSharePicker，明确出现再消失、3/3 复现、约 6 秒、无人值守。通过。无需二分或 HITL 升级。

## Phase 2 — complete

先在原文件添加仅由 `-c7p1-*` 启动参数开启的临时裁剪点；每次启动累加一个裁剪，复跑同一视觉断言。原文件原样备份在 `/tmp/c7p1/originals/`。不是修复，不把裁剪后的通过当功能验收。

## Phase 3

排序假设与确认停点见文末；所有假设均未验证。

## Phase 4–6 — not authorized in this delivery

等待 Phase 3 回报后的 David 确认。

### 已完成裁剪（每行累加一个变量）

| 录屏名 / 启动参数 | 保留项 | 结果 | 出现→最后可见 | 单轮 |
|---|---|---|---|---|
| cut-chat-task / `-c7p1-no-task` | 原 UI；跳过聊天 `.task(id: scenePhase)` 整条 load/refresh/poll | FAIL | 0.7→1.3s | 8.0s |
| cut-timeline / 再加 `-c7p1-no-timeline` | 移除消息/反馈列表及其 geometry 回调 | FAIL | 0.7→1.3s | 7.5s |
| cut-header / 再加 `-c7p1-no-header` | 移除聊天 header | FAIL | 0.7→1.2s | 7.4s |
| cut-candidates / 再加 `-c7p1-empty-candidates` | 候选 loader 替成固定空数组，无计划/日志/视频读取 | FAIL | 0.8→1.3s | 7.8s |
| cut-picker-task / 再加 `-c7p1-no-picker-task` | 不运行 picker task，保持 loading | FAIL | 0.7→1.3s | 8.3s |

以上均同一 runner、同一 iPhone 17e 深色，点 plus 后零交互。录屏 `/tmp/c7p1/<录屏名>.mp4`。

### 宿主裁剪

| 录屏 | 只替换的边界 | 结果 |
|---|---|---|
| minimal-parent | 用 `C7P1MinimalSheetHost`（按钮 + `.sheet` + 真实 picker，固定空候选、picker task 关闭）替换 StudentBlackGoldChatView，保留原外层 | FAIL，0.6→1.2s，7.5s |
| minimal-root | 同一个最小宿主移到 appContent 根部，移除学员根/通知/fullScreenCover 外层 | PASS，0.5→3.2s（观测结束仍可见），4.3s |

此处 PASS 是裁剪对照，**不是修复成功**。共同组件本身是否同病：替换到 ConversationView 后存在附件 Menu 中间步骤，原 runner 报 `Plus absent`，未误判为 PASS/FAIL；正在为同一 sheet 回调建立直接入口。

| 录屏 | 进一步缩减/交叉检查 | 结果 |
|---|---|---|
| single-tab-host | app 根下一个真实 `studentTabLayer` + 最小 fullScreenCover + 最小 sheet，无业务仓储/轮询 | PASS，0.3→2.8s（末帧仍可见） |
| nested-without-tab | 仅最小 fullScreenCover + 最小 sheet | PASS，0.4→2.9s（末帧仍可见） |
| common-direct-share | 原学员通知容器内换成真实 `ConversationView`；临时将附件 Menu 的 share action 直接接到按钮（没有改 sheet） | FAIL，0.6→1.2s，7 帧，8.2s |

`ConversationView` 结论限于**原学员容器里的实际 sheet 回调**；尚未对教练真实上层容器作复现，不能宣称教练端同样受影响。最初普通 Menu 点击后没有捕获到可操作菜单，保留为入口限制。

环境中途 iPhone 17e 被关机（本会话未调用 shutdown），导致一次 snapshot 失败；只重启了同一台 iPhone 17e，冷启动后一过性 snapshot 失败重试后恢复。此类失败不计入 bug 红绿结果。

| 录屏 | Dashboard 边界继续缩减 | 结果 |
|---|---|---|
| minimal-dashboard-host | Dashboard body 改为按钮 + **原** notificationHost，保留 StudentRoot、原 coordinator | PASS，0.3→2.8s |
| minimal-dashboard-nested | 同位置换成普通布尔绑定 fullScreenCover | PASS，0.4→2.9s |
| minimal-dashboard-nav | 在 minimal-dashboard-host 外只加回 NavigationStack | PASS，0.4→2.9s |
| minimal-dashboard-nav-destination | 再加回原 `.navigationDestination(item: $editingProfile)`，item 始终 nil | FAIL，0.4→0.9s，6 帧，4.9s |

这是最小化对照，仅说明该 modifier 在此场景中承重，尚不解释它如何导致关闭。

### 最终最小复现与负对照

无账号、网络、消息、计划、选组、发送、loader、poll、业务 coordinator。只保留一个静态「问教练」文字 sheet；底层使用现有 `studentTabLayer` / `StudentTabAccessibilityHost`。

```text
studentTabLayer
└─ NavigationStack
   └─ Button.fullScreenCover(...)
      .navigationDestination(item: nil) { unused }
      └─ Button.sheet(...)
         └─ static Text("问教练")
```

| 录屏 | 最小场景 / 单项删除 | 结果（首次→末次可见） |
|---|---|---|
| root-nested-destination | 无 tab hosting，保留 NavigationStack + nil destination + cover + 真实 picker | PASS 0.4→2.9s |
| root-static-destination | 上一项只把 picker 换静态文字 | PASS 0.4→2.8s |
| tab-nested-destination | 恢复真实 tab hosting，真实 picker 无加载 | FAIL 0.4→0.9s |
| tab-static-destination | 上一项只把 picker 换静态文字 | FAIL 0.4→0.9s |
| tab-static-no-cover | 上一项只移除中间 fullScreenCover，直接 sheet | PASS 0.4→3.0s |
| tab-static-no-navigation | 静态 sheet + cover + host，移除导航层 | PASS 0.4→2.9s |
| minimal-repeat-2 | 完整最小组合再次打开 | FAIL 0.4→0.8s，4.55s |
| minimal-repeat-3 | 完整最小组合第三次打开 | FAIL 0.3→0.8s，3.62s |

结合上一组 `minimal-dashboard-nav` / `minimal-dashboard-nav-destination` 对照：NavigationStack 单独不触发，nil item destination 的存在在当前组合中承重。每个保留的展示边界都有移除后绿色的对照；基础 Button、Text 和 app window 是触发/观察载体。这里的“最小”按公开展示边界定义，不代表已定位 UIKit/SwiftUI 内部机制。

视觉复核：`/tmp/c7p1/minimal-contact.png`；看到静态 sheet 上弹后消失，露出仍在的 fullScreenCover 内按钮。与用户症状一致（收回的是第二层 sheet，聊天/第一层 cover 保留）。

最小化构建及启动：在未修改基线应用 `scripts/chat-plus-probe/minimization.patch` 后，通过 XcodeBuildMCP build_run_sim，launchArgs 为：

```json
["-meetpr.appearance","dark","-c7p1-tab","-c7p1-destination","-c7p1-static"]
```

然后运行 Phase 1 相同 runner。负对照：去掉 `-c7p1-tab` 换 `-c7p1-nested`（无 tab hosting）；增加 `-c7p1-direct-nested`（无中间 cover）；去掉 `-c7p1-destination`（无导航层）。此 patch 含前面所有累加裁剪开关，仅用于诊断，**不得作为修复提交**。

Phase 2 判据：同症状、多次稳定复现、业务依赖全部移除、按展示边界逐项对照完成。通过。

### 停点前恢复

- 已把 6 个临时改动的生产源文件恢复到原内容，删除 2 个临时 Swift harness 源文件。
- `git diff --exit-code -- MeetPR Modules` 返回 0。
- `git apply --check scripts/chat-plus-probe/minimization.patch` 返回 0，裁剪可重建。
- 当前只留下本 JOURNAL、runner、视觉 oracle / 标题模板、诊断 patch；未 commit/push，未改导航/tab/产品文案。
- 已重新构建原始生产源码并复跑原页面。以下假设在该复核后记录，未运行 Phase 4 干预。

恢复后的原始生产源码构建成功（147.3s）；原页面复核：

```text
restored-baseline exitCode=1 firstVisible=0.8s lastVisible=1.4s observed=4.6s visibleFrames=7 postTapInputs=0 wall=8253ms
FAIL: sheet appeared then disappeared without further input
```

所有秒数均相对录屏起点，不是从用户触点计时。visible 起止差表示可见时长；10fps 采样精度为 0.1s。3/3 初始红灯、3/3 最小红灯，以及恢复后仍红，排除了诊断源码本身制造原症状的可能。

## Phase 3 — complete; awaiting David confirmation

以下为排序后的**未验证假设**，不是根因结论。未添加 Phase 4 调试日志、未执行这些干预、未修复。可测试的主要边界已从聊天/选组业务移到 UIKit hosting 与 SwiftUI 导航/模态组合。

| 排序 | 可证伪假设 | 若成立的预测 / 单变量实验 | 否证条件 |
|---|---|---|---|
| 1 | `StudentTabAccessibilityHost.updateUIViewController` 的无条件 `hostingController.rootView = rootView` 在 sheet 过渡引起的更新中触发导航/模态重协调，收回第二层 sheet。不是业务 poll 所必需。 | 先记录 update 时刻、hosting controller 身份、cover/sheet 的 State 身份和 binding；在最小 harness 中只停止重复 rootView 写入，保留 host/destination/cover，应保持 sheet；恢复写入则重新红。 | sheet 收回前没有 rootView 写入；或停止该写入仍稳定红。 |
| 2 | nil item 的 `navigationDestination` 与 cover 共用挂载作用域，在 UIViewControllerRepresentable hosting 下同步展示栈时误结束后代 sheet。 | 在最小 harness 中只把 fullScreenCover 的挂载点移出该 destination 所修饰的子树，保持 route、nil item、host、sheet 相同，应转绿；恢复原挂载关系重新红。 | 同作用域隔离后仍红，或 trace 显示先发生独立的宿主移除/业务 binding 写 false。 |
| 3 | `updateAccessibility` 对底层 hosting view 的 `isHidden` 无条件回写，与 UIKit fullScreenCover 的可见性管理冲突；新增 sheet 的过渡触发回写后被 UIKit 收回。 | 记录回写前后 isHidden、window、parent、presented controller；只去掉活动 tab 的 `hostingController.view.isHidden = false` 回写，保留 accessibility 标志与 rootView 更新，应转绿；恢复写入重新红。 | 收回前无该回写/可见性变化，或只取消这一写入仍红。 |

代码坐标（已恢复基线）：
- `Modules/StudentKit/Sources/StudentKit/StudentTabAccessibilityHost.swift:82`（rootView 更新）、`:131`（可见性同步）。
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardView.swift:138`（通知 modal modifier）、`:139`（profile item destination）。
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/StudentNotificationComponents.swift:19`（fullScreenCover）。

如获确认，Phase 4 只按顺序对单个预测埋点，前缀统一使用 David 指定的 DEBUG-c7p1；先观察，再单变量干预。修复之前另建立正确 seam 的先红后绿回归测试；当前视觉 loop 继续作为完整原页面复核，不以纯 VM 测试替代。Phase 5–6 尚未执行。

**停点**：按 David 本轮「Phase 3 先写 JOURNAL、列假设、停下等确认」要求，在此等待；无需账号或线上操作。不能把最小化的绿色对照当成产品已修复。


## Phase 4 — David authorized continuation on 2026-11-05

David confirmed H1→H2→H3 and authorized Phase 4, then Phase 5–6 after a hypothesis is established. This supersedes the previous stop point. No commit/push.

### Historical original-page control

Extracted untouched `beta/1.0-30` (`0fb99494fde65fcb4d82b427ccac7ca7bec9b517`) with `git archive beta/1.0-30 | tar -x -C /tmp/c7p1-tag30`. Built via XcodeBuildMCP `build_run_sim` with project `/tmp/c7p1-tag30/MeetPR.xcodeproj`, scheme/configuration `MeetPR-DemoStudent`/`DemoStudent`, DerivedData `/tmp/c7p1-tag30-derived`, iPhone 17e, args `-meetpr.appearance dark`. Build succeeded, 193.8s. No historical source edits.

Executed the same Phase 1 runner using `eval(runnerSource)(tools, {name:"tag30-original"})`:

```text
tag30-original exitCode=1 firstVisible=1.8s lastVisible=2.4s observed=6.5s visibleFrames=7 postTapInputs=0 wall=20083ms
FAIL: sheet appeared then disappeared without further input
```

Recording `/tmp/c7p1/tag30-original.mp4`. The exact symptom already reproduces on 1.0(30); the user-conditioned 30→31 bisect is therefore not entered. `667ebc78`/spec095 additions cannot be required to first introduce this symptom. Host file is unchanged between tags 30 and 31. This reduces weight of an explanation specific to newly added `isVisible`/firstRun, while leaving H1–H3 open.

### H1 observation (no behavior change)

Temporary logs in host update and chat/sheet lifecycle. Original page remained RED:

```text
h1-observation exitCode=1 firstVisible=2.1s lastVisible=2.7s observed=7.7s visibleFrames=7 postTapInputs=0
FAIL: sheet appeared then disappeared without further input
```

Sanitized trace (monotonic seconds, identities renamed A/B; same host throughout):

```text
381623.8077 sheet binding state=A false->true
381623.8654 sheet appear state=A
381623.9926 host update tab=today hidden=false active=true presented=true; assigns rootView
381624.0693 chat appear state=B
381624.6429 host update tab=today hidden=false active=true presented=true; assigns rootView
381624.7149 chat appear state=C
381624.9490 sheet disappear state=A binding=true
```

The sheet binding is still true when the original sheet disappears; the chat State identity has changed after host update. This supports H1's prediction but is not sufficient alone to prove causality. Next intervention suppresses only the rootView assignment in `updateUIViewController`; attachment and accessibility writes stay unchanged.

The video oracle occasionally exceeds the shell tool's first yield; runner now awaits its returned session until completion instead of losing the exit code. Observation is extended from 2.2s to 4.2s after the tap, and PASS requires at least 3.0s from first to last visible frame. RED semantics stay unchanged. The historical result used the original runner/oracle.

The first H1 intervention build hit the MCP 300s call timeout while compiling StudentKit with `-O -whole-module-optimization`; no runner result was produced, so this is not a RED/GREEN datum. Replaced the temporary deletion with runtime flag `-c7p1-skip-root` so both control and intervention use identical binaries. A fresh `/tmp/c7p1-h1-derived` build uses `SWIFT_OPTIMIZATION_LEVEL=-Onone SWIFT_COMPILATION_MODE=incremental -jobs 4`; both sides will be checked under these settings, and final original configuration will be verified after the fix.

### H1 intervention: falsified

Same Onone binary, original pages, only launch flag differs:

```text
h1-skip-root exitCode=1 firstVisible=2.8s lastVisible=3.5s observed=10.5s visibleFrames=8 postTapInputs=0 wall=25916ms
h1-write-control exitCode=1 firstVisible=1.4s lastVisible=2.0s observed=7.9s visibleFrames=7 postTapInputs=0 wall=15691ms
FAIL: sheet appeared then disappeared without further input (both)
```

Even with the updateUIViewController root setter skipped, chat State changed and the original sheet disappeared with binding still true. H1 is falsified; rootView update was correlated, not the established cause. Restored the setter before H2.

A subsequent build encountered disk exhaustion (`No space left on device`, 146MB free). Deleted only task-owned completed historical source/build copies and the completed old DerivedData; retained recordings/logs. Build succeeded in 204.9s after reclaiming space. Automatic command review rejected `rm -rf`; used the requested safer `rm -r` for these verified temporary directories. No user data was removed.

### H2 observation and single-variable intervention: supported

Observation kept the original attachment; `editingProfile` stayed nil and the cover binding setter never received false. Original conversation State was replaced before the sheet vanished (sheet binding still true).

```text
h2-observation exitCode=1 firstVisible=1.7s lastVisible=2.4s observed=8.5s visibleFrames=8 postTapInputs=0 wall=15955ms
FAIL: sheet appeared then disappeared without further input
h2-cover-outside-navigation exitCode=0 firstVisible=2.4s lastVisible=10.0s observed=10.1s visibleFrames=77 postTapInputs=0 wall=24409ms
PASS: sheet remained visible throughout observation
```

The only behavioral intervention moved the existing `.modifier(notificationHost)` from the ScrollView inside NavigationStack (also carrying the nil `.navigationDestination`) to the NavigationStack itself. No routes, tab behavior, sheet content, callbacks, or business dependencies changed. Host rootView/visibility writes remained original. The same chat State identity persisted through sheet presentation and the full observation. This supports H2 at the app composition boundary; it does not claim to explain SwiftUI's undocumented internal implementation. H3 is not tested, per the stop-after-confirmation instruction.

## Phase 5 — regression before final fix

Testing seam discovery: the existing app target hosts Swift Testing, and StudentKit's ViewInspector tests cover value/callback surfaces. The candidate hosted `studentTabLayer` fixture would reproduce the minimal symptom but would **not execute DashboardView's actual modifier placement**, so making that copied fixture green would not guard this fix. Actual Dashboard and chat presentation state is private; a reliable tap-through UIKit test would need a UI automation entry/target or test-specific production hooks. The existing project has no UI test target, and target/pbxproj restructuring or new test hooks would exceed this two-line composition fix. No static source-layout assertion or VM test is substituted. This is the missing correct hosted seam finding.

Per David's explicit fallback, use the original-page video runner as the exact-symptom regression: establish appearance, perform zero later input, fail if it disappears, and require at least 3s continuously visible for success. Restore pristine production sources first and watch this stricter regression go RED, then apply only the demonstrated modifier relocation and require 3/3 GREEN. The temporary test draft in /tmp is not added as a permanent test because it tests a copied composition. Final cleanup deletes the temporary runner/harness as requested; its command, oracle contract, output and videos remain documented.

### Final regression RED, then minimal production edit

All production sources were restored (`git diff --exit-code -- MeetPR Modules` exit 0). Original-page stricter regression:

```text
regression-pristine-red exitCode=1 firstVisible=1.6s lastVisible=2.3s observed=8.5s visibleFrames=8 continuousVisibleSeconds=0.7 postTapInputs=0 wall=17896ms
FAIL: sheet appeared then disappeared without further input
```

Reapplied only `.modifier(notificationHost)` relocation in DashboardView. All diagnostic production logging and intervention flags were removed before the final build. Final build uses original DemoStudent settings (no optimization overrides).

Oracle hardening before final green runs: after first confirmed appearance, any five consecutive missing frames fails even if the title later reappears; PASS needs a continuous run of 31 sampled frames (3s span) and visible final three frames. Re-evaluated the pristine RED video with this oracle: exit 1, continuousVisibleSeconds=0.7. This closes the independent Spec review's same continuity observation.

Standards review: 0 findings. Spec review: 0 code findings; continuity check addressed above, remaining validation pending. Both read-only reviewers compared the uncommitted production diff to `09eef51d`, used the user request and this JOURNAL, and made no edits. Missing `docs/agents/issue-tracker.md` was reported with the code-review skill's setup instruction; this task has an explicit local requirement source, so the unrelated tracker setup does not block review.

### Final original configuration build and 3/3 original-page GREEN

`build_run_sim({launchArgs:["-meetpr.appearance","dark"]})`, scheme/configuration `MeetPR-DemoStudent`/`DemoStudent`, no extra build overrides, same iPhone 17e. The tool's client timed out at 300s, but its build log subsequently ended `BUILD SUCCEEDED`. Explicitly installed the completed `/tmp/c7p1-h1-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app` via `install_app_sim`, then launched it with the dark preference. Final build log:
`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-chat-plus-06b57f0b1174/logs/build_run_sim_2026-11-05T04-19-16-313Z_pid56349_975362c9.log`.

Runner invocation stayed the Phase 1 command (`eval(runnerSource)(tools,{name:...})`, using `scripts/diagnose-chat-plus-autoclose.js` before cleanup). The oracle command was `python3 scripts/chat-plus-probe/assert-video.py /tmp/c7p1/<name>.mp4`. Added a bounded **pre-tap** readiness wait for the chat composer; it does not add any input or waiting changes after the plus tap beyond the documented observation window.

One cold-start attempt lacked a ready composer (no video assertion), and one attempt was observed in a light training-context sheet, yielding INCONCLUSIVE (title template did not match), not GREEN or RED. A supplemental `fixed-original-1` run passed (8.7s continuous), but the final required set below explicitly confirms the original Dashboard entry (`dashboard.sessionOverview`), dark screenshot, and iPhone 17e before counting. Each repetition closes the sheet, returns to Dashboard, and opens the original chat again; after the single plus tap, there are no further inputs until recording finishes.

```text
fixed-dashboard-1 exitCode=0 firstVisible=2.6s lastVisible=9.2s observed=9.3s visibleFrames=67 continuousVisibleSeconds=6.6 postTapInputs=0 wall=28032ms
fixed-dashboard-2 exitCode=0 firstVisible=2.1s lastVisible=8.9s observed=9.0s visibleFrames=69 continuousVisibleSeconds=6.8 postTapInputs=0 wall=21273ms
fixed-dashboard-3 exitCode=0 firstVisible=0.9s lastVisible=6.7s observed=6.8s visibleFrames=59 continuousVisibleSeconds=5.8 postTapInputs=0 wall=10364ms
PASS: sheet remained visible throughout observation (3/3)
```

Videos: `/tmp/c7p1/fixed-dashboard-{1,2,3}.mp4`. Visually inspected dark sheet screenshot: `/tmp/c7p1/fixed-sheet.jpg`. No source changes between these runs.

### Main-flow and adjacent-surface checks

- Original Dashboard → chat → plus → select **硬拉，第 2 组** → 发送给教练. Sheet dismissed on the explicit send; chat rendered `第2组/3 · 175kg × 3 · RPE 8.5` and `✓ 已送达 · 等教练看`. DemoStudent in-memory repository only, no live coach message. Screenshot visually inspected: `/tmp/c7p1/sent-second-set.jpg`.
- Chat back returned to Dashboard. Switched to 训练, started its demo workout, tapped the actual `TodayWorkoutView` hero 问教练 button. Same video oracle, no input after that tap:

```text
fixed-training-picker exitCode=0 firstVisible=1.1s lastVisible=6.9s observed=7.0s visibleFrames=59 continuousVisibleSeconds=5.8 postTapInputs=0
PASS: sheet remained visible throughout observation
```

- Training picker retained its initial first-set selection and enabled send. Closed explicitly; returned to the same workout. Visually inspected `/tmp/c7p1/training-picker.jpg`; video `/tmp/c7p1/fixed-training-picker.mp4`.
- Tab sequence 今日 → 训练 → 成长 → 我的 → 今日 displayed the expected workout, growth menu, profile menu, and Dashboard. No modal left behind.
- Dashboard 体重 card still navigated through the existing item destination to its editor, with 保存 and 返回 present; backed out without editing/saving. Screenshot `/tmp/c7p1/profile-destination.jpg`.
- `ConversationView` itself was not changed: earlier minimization showed the same sheet callback could fail under the affected student parent; final fix is at that parent. No claim is made about a coach-specific parent reproducing this bug.

### Full tests and static checks

Tool commands (session configuration temporarily Debug for SwiftPM; restored DemoStudent afterward):

```text
swift_package_test({packagePath:"/Users/david/Projects/apps/MeetPR-wt-chat-plus/Modules/StudentKit"})
PASS 1097 tests / 54 suites, 0 failed, 0 skipped; tool total 247.156s, test execution 12.837s
swift_package_test({packagePath:"/Users/david/Projects/apps/MeetPR-wt-chat-plus/Modules/ChatUI"})
PASS 84 tests / 15 suites, 0 failed, 0 skipped; tool total 93.988s, test execution 3.779s
swiftlint lint --strict Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardView.swift
0 violations, 0 serious
git diff --check
exit 0
```

SwiftPM tests run on the macOS host; the actual iOS modal behavior is covered by the original-page recordings on iPhone 17e. Total **1181 passed**, no new permanent unit tests (the missing hosted seam and allowed fallback are explained above). StudentKit reported 21 compiler warnings in unchanged reminder scheduling/test-support/test files (including Swift 6 concurrency warnings); none points at the edited DashboardView. ChatUI reported zero warnings. These unrelated files were not modified.

Full logs:
- StudentKit: `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-chat-plus-06b57f0b1174/logs/swift_package_test_2026-11-05T04-24-43-074Z_pid56349_bfcbaa22.log`
- ChatUI: `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-chat-plus-06b57f0b1174/logs/swift_package_test_2026-11-05T04-28-50-286Z_pid56349_35ea9ca4.log`

Phase 4 criterion: H1 falsified, H2 supported by observation + single-variable GREEN + restored pristine RED; H3 intentionally not pursued. Phase 5 criterion: exact-symptom fallback regression RED→GREEN, original page 3/3 continuous ≥3s, send flow and adjacent pages verified, both full module suites passed.

## Phase 6 — cleanup and handoff

Deleted `scripts/chat-plus-probe/` (including oracle/template/minimization patch) and `scripts/diagnose-chat-plus-autoclose.js`; removed the unused /tmp hosted-test draft. All production diagnostic logs and launch flags are gone. Raw recordings, screenshots and external tool logs remain evidence, not shipped code.

**Whole-repository grep exception:** the user's exact recursive DEBUG-prefix grep is not empty because HEAD already contains **26 documentary matches**: the read-only historical `docs/CODEX-JOURNAL.md` and `docs/evidence/coach-launch-hang/` evidence. These are unrelated old records, not active logging; changing them would violate the task's minimal-scope rule and alter historical evidence. They are preserved unchanged. The production Swift source check is empty; this task introduces zero matching lines. Full grep output is saved at `/tmp/c7p1/debug-cleanup.txt`. Do not claim the literal whole-repo-empty criterion passed.

Confirmed cause / commit-message material: **The Dashboard chat cover was attached inside the subtree carrying an item navigation destination. In the existing student UIKit tab host, presenting the nested Ask coach sheet replaced the presented chat's State and dismissed that sheet while its old binding remained true. Attach the unchanged notification cover to NavigationStack's outer scope to keep the presentation stable.** This states the proven app composition fault, not an undocumented framework-internal cause.

Final production diff is one removed line and one added line in `DashboardView.swift`; no tab/navigation route, business callback, copy, dependency, pbxproj, release ledger or build number changed. Final handoff files: that Swift file and this JOURNAL. No commit/push; Claude owns receipt and delivery.

Final cleanup checks: full requested grep produced exactly 26 pre-existing documentary lines; Swift production-source grep produced no output. Both temporary script paths are absent. `git diff --check` passed, and final status contains only DashboardView.swift modified plus this untracked JOURNAL. Branch remains `fix/chat-plus-sheet-autoclose`; no commits created.
