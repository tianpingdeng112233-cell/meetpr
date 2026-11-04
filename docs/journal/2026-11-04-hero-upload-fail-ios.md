# Hero 摄像头首次上传失败：iOS 核查

**结论：iOS 不受本次 RN「相机直入、预填未就绪导致 attachment-only 首次建记录失败」影响。** 专项测试已绿；无生产代码修复。此结论不覆盖其他网络、鉴权或并发故障。

- 任务：David 2026-11-04 直接授权；仅 iOS 学员训练记录与视频上传，无 commit/push/PR。
- 基线：`fix/hero-camera-upload-fail` @ `bfc0fdc8`，开工工作区干净；发版线另在 worktree，未切换或合并。
- 已读：根 CONTEXT/AGENTS/CLAUDE/FOLLOWUPS、工程闭环、记忆 INDEX、ADR-005、spec 027/069 与 072 相关部分；本任务不触发新的产品或发布工作。
- 技能：diagnosing-bugs、tdd、xcodebuildmcp。测试 seam 按本任务授权选择最高可用公开接口：真实 `TodayWorkoutViewModel.ensureLoggedSetID` → `VideoAttachmentViewModel.attach` → `VideoUploadManager`；仅存储、媒体导出与远端传输使用已有测试替身。
- 模拟器：仅 `iPhone 17e` / iOS 26.5 / `5D5FA360-BA49-48C6-A887-2F0D22F89749`；代理环境变量设为空。

## Phase 1 · 反馈环（完成）

完成判据：实际运行确定性测试，断言相机路径第一次建记录成功且第一次上传到 uploaded；若错误地把未预填值当作完成校验，测试应在首次 set log 断言失败。未拍完时缺重量/次数与拍摄期间数据更新两个场景。不调用 retry。

已找到代码差异：iOS Hero 的无视频入口直接呈现相机，没有 initialCamera 参数或异步记录页预填；返回时按稳定 ID 获取 live draft。`validateCompletion` 只在 completed 为 true 时检查缺失重量，首次附视频维持 completed 为 false。

代码证据（相对仓根）：

| 位置 | 证据 |
| --- | --- |
| `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift:823` | Hero 摄像头调用 `onVideoAction(row)`。 |
| `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift:738`、`:399` | 无视频且相机可用 → `.camera` → 直接呈现 `CameraRecorderView`；不是 SetEntry initialCamera 流程。 |
| `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/Camera/CameraRecorderView.swift:248` | `onPicked(url)` 先于 relinquish 与相机关闭，目标 ID 在回调时仍可取得。 |
| `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift:816` | 拍摄后按稳定 set ID 查当前 row/draft，已有 log 复用，没有则 `ensureLoggedSetID`。 |
| `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel.swift:761`、`:1075` | 首次建 log 保持 draft 的未完成状态；`validateCompletion` 只对 completed=true 做缺重量检查。 |
| 同文件 `:1184` | `makeLog` 从当前实际值/处方取值，缺重量或次数落 0；无异步 SetEntry 预填依赖。 |
| `Modules/StudentKit/Sources/StudentKit/Repository/BackendStudentTrainingLogRepository.swift:22` | 真正网络 repository 直接编码请求，无 RN 式本地重量/次数校验。 |
| `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentViewModel.swift:82`、`VideoUploadManager.swift:110` | 管理器接收已存在的 setLogID，不负责先建 log，也不捕获拍摄时的输入用于校验。 |
| `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/SetEntrySheet.swift:72`、`:197` | 手动进入记录页时同步初始化 seed；picker 打开前与返回建 log 前均同步 draft，不存在 initialCamera 异步预填分支。 |
| `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+RecordingError.swift:17` | 同文案是保存异常通用兜底，key=`student.todayWorkoutViewModelRecordingError.copy004`（资源文件 `:20681`），不是相同根因证据。 |

额外只读交叉核对：本机 backend @ `1e494db` 的 `src/routes/sets.ts:43–52` 接受 weight_kg=0、reps=0、completed=false；只用于验证 fixture 契约，未改后端，也不声称验证了线上部署。

测试入口排障（不计为产品红测试）：

1. XcodeBuildMCP `test_sim` 对 App 工程的 StudentKit scheme 编译成功，但报 `There are no test bundles available to test`，0 项执行。
2. `projectPath=.../Package.swift` 不是合法 Xcode project；直接 shell 调 Xcode 又受沙箱 CoreSimulator 限制，均未执行测试。
3. 建立 `/tmp/meetpr-hero-upload.xcworkspace`，仅 FileRef 引用本仓 `Modules/StudentKit`。自动生成的 StudentKit scheme 仍无测试，遂在临时 workspace 添加 `StudentKit-HeroVerification` scheme，显式引用包的 `StudentKitTests` buildable/TestableReference；已在实际 build graph 看到该测试目标。未修改仓内项目、scheme、依赖或导航。
4. 并行以 XcodeBuildMCP `swift_package_test` 运行同一测试，作为 macOS host 快速反馈环；首次冷编译超过工具 300 秒响应上限，后续缓存就绪后成功。iOS 测试仍只跑 iPhone 17e。

**已运行的单命令反馈环：**

```sh
swift test --package-path Modules/StudentKit --filter heroCameraFirstUploadDoesNotRequireEntryPrefill
```

实际经 XcodeBuildMCP `swift_package_test({packagePath: <仓>/Modules/StudentKit, filter: "heroCameraFirstUploadDoesNotRequireEntryPrefill"})` 执行。结果 **1 test / 2 test cases / 0 failures**，用例执行 **0.044 秒**，含增量编译的工具耗时 **3.804 秒**。测试遍历未预填（nil/nil）与拍摄期间改成 82.5kg × 5；均第一次 mint 不完整 log，第一次上传到 `.uploaded`、没有 error、每片只传一次。未调用 retry。未注入假故障制造红；按用户允许的「不受影响」出口完成 Phase 1。

原始日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-hero-upload-492615f38920/logs/swift_package_test_2026-11-04T04-51-31-284Z_pid24414_e5d86733.log`。注意日志开头 XCTest 显示 0 tests，后续 Swift Testing 明确执行 1 个测试、2 个参数实例，不能只看 XCTest 计数。

完成判据核对：已运行；真实建 log 与上传公开链路；断言首建 log、最终 uploaded（failed 也立即结束等待后断言失败）、无手动重试；纯本地可重复，时间固定，外部边界用已有替身；秒级且无人值守。

## Phase 2 · 复现与最小化

完成判据：若 Phase 1 证实受影响，复跑并最小化确切失败；若不受影响，按用户指示停止，不人为制造另一类故障。

结果：**不适用，按用户 Phase 1 停止条件跳过**。未复现本次根因，不把基础设施错误当作产品红测试。

## Phase 3 · 假设

完成判据：仅受影响时列出 3–5 条排序且可证伪假设，并直接继续验证。

结果：**不适用，Phase 1 已证实本次同构预填路径不存在**；未编造待修根因或假设列表。

## Phase 4 · 埋点

完成判据：仅受影响时一次改变一个变量，临时日志统一使用用户指定前缀。

结果：**不适用**；无临时埋点、无生产代码变更。

## Phase 5 · 修复与回归

完成判据：受影响时先红后绿，覆盖首次成功、非法输入提示与视频保留；不受影响时不改生产代码，保留验证证据。

结果：**无需修复**。保留 `HeroCameraUploadTests.swift` 作为不受影响的验证测试。原有非法完成输入测试随全量测试验证，未修改校验、UI 布局或文案。

## Phase 6 · 清理

完成判据：相关测试全绿，生产代码无改动或修复已验证，无临时日志与一次性 harness，不提交/推送。

全量测试记录：

| 命令/工具 | 结果 |
| --- | --- |
| `swift test --package-path Modules/StudentKit --no-parallel`，经 XcodeBuildMCP `swift_package_test(..., parallel: false)` | **1095 passed / 0 failed / 0 skipped**；47.283 秒。 |
| 相同包全量、未显式禁用并行的第一次运行 | 1075 passed / 20 failed，均为已有后台异步等待 TimeoutError；未改生产代码或断言，仅显式禁用并行后上行全绿。保留失败记录，不算产品红测试。 |
| iPhone 17e，临时 `StudentKit-HeroVerification` scheme 全量 | **1070 passed / 22 failed / 0 skipped，合计 1092 tests**；Swift Testing 用例耗时 94.733 秒，77 issues。失败涉及既有多语言/日期断言，未修改这些文件；不能宣称 iOS 全量全绿。 |

iOS 全量虽然 MCP 调用超过 300 秒（含冷编译），实际进程完成并生成 xcresult；计数由 `xcresulttool get test-results summary` 读取，非从工具超时猜测。专项 Hero 测试在该轮 **2 cases passed / 0.039 秒**。原有缺 freeWeight 完成校验、flushed edits 与上传事件测试未失败。

全量原始证据：

- macOS 绿：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-hero-upload-492615f38920/logs/swift_package_test_2026-11-04T04-54-51-002Z_pid24414_b3fb3945.log`。
- macOS 并行超时：同目录 `swift_package_test_2026-11-04T04-52-40-428Z_pid24414_d79eb355.log`。
- iOS 日志：同目录 `test_sim_2026-11-04T04-52-13-973Z_pid24414_9bcf9751.log`。
- iOS 结果：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-hero-upload-492615f38920/result-bundles/test_sim_2026-11-04T04-52-13-976Z_pid24414_dea8adc0.xcresult`。

iOS 等价命令（实际经 XcodeBuildMCP 执行）：

```sh
xcodebuild test -workspace /tmp/meetpr-hero-upload.xcworkspace \
  -scheme StudentKit-HeroVerification \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -parallel-testing-enabled NO
```

临时 scheme 仅把包的 `StudentKitTests` 加到 BuildAction/TestAction（`BlueprintIdentifier="StudentKitTests"`、`ReferencedContainer="container:<仓绝对路径>/Modules/StudentKit"`）。本次不存在 App 工程原生 StudentKit 测试 scheme，故不把 wrapper 运行误称为 App scheme 全绿。

未满足项：**iOS 全量全绿未达成**。不为让本卡变绿而修范围外本地化/日期行为；用户规定 Phase 1 不受影响即可停止，本任务不以这些失败扩展产品修复范围。

### iPhone 17e 专项独立复跑

复用已构建 test products，经 `test_sim(testProductsPath: ..., extraArgs: ...)` 执行：

```sh
xcodebuild test-without-building \
  -testProductsPath /Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-hero-upload-492615f38920/test-products/test_sim_2026-11-04T04-52-13-977Z_pid24414_907b1b34.xctestproducts \
  -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO \
  '-only-testing:StudentKitTests/heroCameraFirstUploadDoesNotRequireEntryPrefill(editsArriveDuringCapture:)' \
  '-only-testing:StudentKitTests/ensureLoggedSetIDKeepsFlushedEditsWithoutCompleting()' \
  '-only-testing:StudentKitTests/loadTypeCompletionCannotPersistMissingFreeWeight()' \
  '-only-testing:StudentKitTests/viewModelTracksUploadLifecycleThroughEvents()'
```

结果：**4 tests passed / 0 failed / 0 skipped**，19.839 秒（含 simulator runner 启动）；Hero 参数化测试含两个场景。覆盖本卡首传路径、草稿编辑值保留、非法完成输入仍提示以及真实上传管理器状态流。

证据：日志 `test_sim_2026-11-04T04-57-56-925Z_pid24414_6bad1e44.log`；xcresult `test_sim_2026-11-04T04-57-56-925Z_pid24414_ff6049ed.xcresult`，父目录同上。

最终清理：无生产代码变更，无临时埋点；相关源码与新增测试搜索 debug 前缀结果为空；一次性 `/tmp/meetpr-hero-upload.xcworkspace` 已删除，保留构建产物/日志供复验。新增测试的临时视频目录与 UserDefaults 由 defer 清理。SwiftLint strict 0 violations，swift-format strict 与 git diff --check 通过。未 commit、push 或开 PR。

交付仅两文件：`Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/HeroCameraUploadTests.swift` 和本 JOURNAL。

## 独立审查与结论边界

使用 review-loop 本地未提交审查；仓内没有 `docs/agents/issue-tracker.md`，未私建 tracker，未声称运行依赖该配置的 Matt code-review 流程。以后需该流程时由 David 调用 `$setup-matt-pocock-skills`。

- Standards：1 轮独立只读 reviewer，无 blocker。测试使用 Swift Testing/MainActor、已有边界替身、5 秒有界等待、独立目录和 defaults 清理。
- Spec：1 轮独立只读 reviewer，无 blocker。结论必须限定本次 RN 预填竞态，不能扩大到所有首次上传失败。
- 已知边界：`TodayWorkoutView.swift:832–836` 在其他原因导致首次建 log 失败时仍删除视频源文件；`VideoAttachmentSection.swift:298–305` 有同类处理。这不是本次预填竞态证据，未扩大修复范围。测试不替代真机相机、真实网络、OSS 或鉴权验证。
