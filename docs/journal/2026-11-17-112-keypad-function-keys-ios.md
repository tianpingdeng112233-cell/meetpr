# spec 112 iOS — 数字面板功能键与学员自加热身组

- 工作树：`/Users/david/Projects/apps/MeetPR-wt-112`
- 分支 / 开工基线：`feat/112-keypad-function-keys` / `c693abab`
- 授权：实装完整 spec 112；不 commit、不 push，由 Opus 收货后提交。
- 唯一验收源：`specs/112-keypad-function-keys/SPEC.md`。背景：105 §6、107；写入契约核对 backend worktree `MeetPR-backend-wt-068/specs/068-warmup-sets/SPEC.md`。
- 最新授权（2026-11-17）：磁盘清理后，仅用命令行 `swift test` / `xcodebuild test` / `xcrun simctl`；不再使用 XcodeBuildMCP 或 cua_repl。模拟器交互与截图由 Opus 收货时完成，本卡不需要截图。
- 交付状态：两项审查返修完成且有先红后绿证据；三个指定包全量已重跑，DesignSystem / Networking 全绿，StudentKit 为 1320 通过 / 16 个视频 fixture 失败。112 回归通过，但不能宣称三个包全量全绿。未 commit、未 push。

## 实装边界

- 全天一览单独启用四功能键、RPE/RIR 快选与悬浮收起；旧 SetEntrySheet、体重及补记调用保持原形态。
- 热身只挂计划动作，最多 5 组，与额外组共用处方后的 wire set_index、分别计上限；`set_type = warmup` 的教练处方语义不变。
- `is_warmup` 经 Networking DTO、StudentSetLog、草稿、待同步队列、Repository 写回及读取恢复传递；旧记录缺字段默认 false。
- 后端 068 生产部署是发包前置门禁，本卡不修改或部署后端，不验证安卓实现。

## TDD 记录

测试均使用用户指定三个 seam；按行为纵向 red → green。

| 行为 | Red | Green |
| --- | --- | --- |
| 学员读取 / 缓存保留标记，旧记录 false | `allDayWarmupFlagSurvivesStudentReadAndLegacyRecordsDefaultToFalse`：1 测试 6 断言失败 | 1 测试通过 |
| 记组请求发 is_warmup | `allDayWarmupRequestUsesBackend068Flag`：缺请求参数，编译失败 | 读取与写入 2 测试通过 |
| 四键动作与 RPE 8.5 快选 | `allDayFunctionKeysAndQuickPicksForwardActions`：缺 allDayActions，编译失败 | 1 测试通过；RIR 六格与无 Next 补充检查通过 |
| 热身复制 / 置顶 / 摘要 / 分别上限 | `warmupsCopyOnlyPreviousWarmupAndKeepFormalSummaryAndSeparateLimits`：缺 addWarmupSet / isWarmup | AllDayDirectEditingTests 4 测试通过 |
| 离线重启 / 完成丢弃空热身 / 读取恢复 | `warmupSurvivesOfflineRestartAndCompletionDiscardsEmptyWeight`：1 测试 6 断言失败 | 1 测试通过 |
| 批量同字段 / 上下范围 / 两类隔离 / 空值 | `fillCopiesOnlyOneFieldWithinTheCurrentSetKind`：缺 fillAllDay / actionMessage | 1 测试通过 |
| 热身隔离统计 / 原重量注记与次数直接编辑 | 两个回归测试共 11 个 issues（完成组的 e1RM/PR 与原值显示等） | 修复后通过；统计另覆盖直存与离线队列两种保存路径 |
| 热身不能成为 Top Set / 上次重量建议；旧额外组删除空洞不重编号 | 独立审查后新增两个回归，11 测试中 2 失败、4 个 issues | 修复后最终定向 12 测试通过（其中统计用例 2 个参数案例），0 失败 |

构建中间态：一次 StudentKit 编译因源码在构建期间变化而中止；另一次测试宏 key-path 写法编译失败，已改闭包后通过。二者不计验收通过。XcodeBuildMCP 的失败数可能把一条 Swift Testing 测试的多个 issues 当成多个 tests，最终计数以原始日志 `Test run with ... tests` 为准。

## 验收清单逐条映射

| SPEC 项 | 本卡证据 / 对应测试 | 状态 |
| --- | --- | --- |
| 1. 四功能键、去 Next / 底部收起、悬浮收起 | NumberPadShortcutTests 两个 allDay 用例 | 单测通过；视觉由 Opus 收货 |
| 2. 跨动作直接换格，保留合法值 | switchingCellsKeepsLastLegalValueAndDoesNotSaveUntouchedRows | 通过 |
| 3. 上下填充、同字段、正式与热身隔离、原值 | fillCopiesOnlyOneFieldWithinTheCurrentSetKind；addedRowRemembersOriginalWeightAndRestingRepsIsDirectlyEditable | 单测通过；视觉由 Opus 收货 |
| 4. RPE 九格 / 8.5、RIR 六格 | allDayFunctionKeysAndQuickPicksForwardActions / allDayRIRHasSixQuickPicksAndNoNextAction | 通过 |
| 5. 热身复制、置顶、上限、无视频 | warmupsCopyOnlyPreviousWarmupAndKeepFormalSummaryAndSeparateLimits；warmupRowHasNoCamera | 单测通过；视觉由 Opus 收货 |
| 6. 摘要 / 进度 / 按计划 / e1RM / PR 不变 | warmupsNeverEnterVolumePRHistoryOrCompletionCounts（直存与队列两路）+ warmupsCannotBecomeTopSetOrPreviousWeightSuggestions；教练 App / 网页归 068 联验 | 本地通过，跨卡待验 |
| 7. 离线联网 is_warmup=true | warmupSurvivesOfflineRestartAndCompletionDiscardsEmptyWeight + AllDayContractTests | 本地闭环通过；真实服务器未验 |
| 8. 旧记录不凭空变热身 | allDayWarmupFlagSurvivesStudentReadAndLegacyRecordsDefaultToFalse；legacyExtraSetNumberSurvivesADeletedSlotAndOldDraftDecodesWithoutWarmup | DTO / 缓存 / 旧编号通过；升级首屏视觉由 Opus 收货 |
| 9. 三语 | 简中 / 英文手工 key，繁中脚本生成；13 keys 检查通过 | 通过 |
| 10. 深浅截图 | David 最新指令：模拟器与截图验收交 Opus，本卡不需要截图 | 已移交，不作为本卡阻塞 |

## 全量验证结果（磁盘清理后命令行重跑）

| 包 | swift test 通过 / 失败 | iOS xcodebuild test |
| --- | --- | --- |
| CoreModels（上一轮，非本轮要求的三个包） | 168 / 0 | 未执行 |
| Networking | 158 / 0 | simctl 无法连接服务，未执行 |
| DesignSystem | 83 / 0 | simctl 无法连接服务，未执行 |
| StudentKit | 1320 / 16（1336 tests；17 issues） | simctl 无法连接服务，未执行 |


Swift Testing 按测试函数统计；失败的音频转码用例有两个参数案例，所以 16 个失败测试对应 17 issues。所有 16 项均在源媒体 fixture 创建阶段抛出编码错误；没有将全量标绿。macOS SwiftPM 结果不能替代 iOS 平台测试。

```text
CoreModels: Test run with 168 tests in 2 suites passed.
Networking: Test run with 158 tests in 3 suites passed.
DesignSystem: Test run with 83 tests in 18 suites passed.
StudentKit: Test run with 1336 tests in 94 suites failed with 17 issues.
AllDayDirectEditingTests final focused: 12 tests passed (statistics test: 2 cases).
swiftlint: 43 changed Swift files; exit 0.
git diff --check: exit 0.
Traditional Chinese: 10 catalogs, 13 keys; placeholders, glossary, simplified-only scan OK.
```

## 三语生成环境

本机 Python 缺 OpenCC，pip 网络连接受限制。使用已连接 GitHub 的只读 fetch 取得 `yichen0831/opencc-python` 上游（setup.py 标识 0.1.7）的转换源码和所需字典，置于被忽略的 `.build/spec112-opencc/`；未修改 app 依赖与生成脚本。运行 `PYTHONPATH=.build/spec112-opencc python3 scripts/generate-zh-hant.py --keys …`，输出：`10 catalogs, 13 keys; placeholders, glossary, simplified-only scan OK`。只生成本卡 13 个 key。

## 独立审查（两轮收敛）

使用 `review-loop` 本地双轴审查，两个只读 Codex reviewer；固定基线 `c693abab` 与本卡工作区 diff。缺 `docs/agents/issue-tracker.md`，未使用依赖 tracker 的 Matt 流程、未私建配置。

- Standards：1 个 P2 blocker。当天重量建议 / Top Set 候选仍含热身，须从建议来源排除并补回归。
- Spec：1 个 P2 blocker。正式组显示号用数组位置重编号，会压缩旧额外组删除后留下的号位，违反升级首屏兼容；须保留既有编号，补旧记录回归。
- 两项均接受，先写失败回归再修复；第二轮 Standards 与 Spec 均返回 `VERDICT: CLEAN`。reviewer 均只读，未代跑构建。最终 12 测试绿。
- 真实服务器落库、教练 App/网页隐藏是跨卡联验，不以本地单测冒充通过。

## 早期构建环境事件（历史记录，最新执行方式见下节）

- XcodeBuildMCP 的 StudentKit 重编译与 DemoStudent 首次 iOS 构建均触及 300 秒调用等待上限。SwiftPM 原始日志后续明确报出 `IO failure on output stream: No space left on device`，故本轮属于环境构建失败，不能记为用例失败/通过。
- 已用 `df` 核实 APFS Data 卷余量波动约 4–7 GB；未删除源码或用户数据，也未清理其他工作树。环境错误已有直接证据，诊断不做无关业务改动。
- XcodeBuildMCP 随后返回 `Transport closed`（包括 session_show_defaults）。其 SwiftPM 工具无 jobs 参数，改由本地 `swift test --jobs 2` 顺序执行；缓存和日志放本卡 `.build/spec112-*`。iOS 平台验证未完成，不冒充截图通过。
- 本地命令：`CLANG_MODULE_CACHE_PATH=$PWD/.build/spec112-module-cache SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.build/spec112-module-cache swift test --package-path Modules/StudentKit --cache-path $PWD/.build/spec112-spm-cache --manifest-cache local --disable-sandbox --skip-update --jobs 2 --filter AllDayDirectEditingTests`。

- 备用 CUA 路径尝试访问 Simulator 时返回 `Computer Use was not approved to use Simulator`，未执行 UI 操作；当时请求恢复原连接；此请求已被 David 的“仅命令行”指令取代，未绕过权限访问。

- MCP 断连后尝试命令行 `xcodebuild test`，目标固定为既有 `iPhone 17e`（`5D5FA360-BA49-48C6-A887-2F0D22F89749`），scheme `MeetPR-DemoStudent`，`-parallel-testing-enabled NO -jobs 2`，复用 `/private/tmp/meetpr-112-derived`；exit 74，在执行测试前失败：`CoreSimulatorService connection became invalid`、`Connection refused`、SPM 用户缓存 `Operation not permitted`。未创建或改用其他模拟器。

## 磁盘清理后复跑与诊断（本轮）

- `df -h .`：可用 26 GiB。三个包并发使用 `swift test --jobs 4`，没有出现磁盘不足或构建失败。DesignSystem exit 0，Networking exit 0，StudentKit exit 1。
- 两项审查红测原始证据仍在：热身 200 kg 被错误用作 Top Set，得到建议 170 kg / 上次重量 200 kg（期望无 Top Set / 历史 100 kg）；旧额外组 setIndex 4 被错排为第 4 组（期望第 5 组）。原 11 测试中 2 失败、4 issues。本轮全量日志中这两个测试均再次通过。
- 修复：重量建议入口与历史重量投影排除 `isWarmup`；正式组沿用原 `SetDisplayNumber`，只扣掉前方实际热身占位，保留旧额外组删除形成的空洞。末次仅将提取后的 `lastWeights` 文档注释移至实际声明，无行为变化。
- 最小诊断程序不导入任何 MeetPR 模块，只调用系统 AVFoundation / VideoToolbox：`AVAssetWriter.startWriting() == false`，`AVFoundationErrorDomain -11834`，原因 `The encoder required for this media cannot be found.`。硬件加速 false / true 均返回 `-12908`，本机 SDK `VTErrors.h` 定义为 `kVTCouldNotFindVideoEncoderErr`。由此确认当前执行进程找不到视频编码器，错误不依赖本卡逻辑或测试 fixture；具体系统服务/沙箱配置根因尚未确认。
- `xcrun simctl list devices available` exit 1：`CoreSimulatorService connection became invalid`、`Connection refused`、系统日志路径 `Operation not permitted`。没有可用模拟器服务，未重复发起已知不能执行的 iOS test；没有新建或改用其它机型。
- 诊断假设：磁盘恢复后错误仍在；仓库外最小程序与软/硬编码探针排除了本卡业务逻辑和单一硬件路径原因。系统编码服务不可达/不可用仍是待环境恢复的阻塞。没有改视频生产代码、删断言、跳过失败用例或把失败计成通过。

复跑命令模板（`PACKAGE` 依次为 DesignSystem、StudentKit、Networking）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/spec112-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/spec112-module-cache" \
swift test --package-path "Modules/$PACKAGE" \
  --cache-path "$PWD/.build/spec112-spm-cache" --manifest-cache local \
  --disable-sandbox --skip-update --jobs 4
```

`--disable-sandbox` 仅关闭 SwiftPM 内层构建沙箱；当前会话外层访问限制仍在，未申请或绕过权限。

## 未完成项与交接

1. 本卡要求的三个包全绿尚未达成：需在能访问系统视频编码器的执行环境重跑 StudentKit 全量。当前 16 个失败均保留并如实计数；DesignSystem / Networking 已全绿。
2. 模拟器交互、升级首屏与深浅截图按 David 最新指令交 Opus 收货，本卡不再承担截图，也不再请求恢复 MCP / CUA。
3. 与 backend 068 联验真实服务器 `is_warmup = true`、教练 App / 网页不展示；发布前确认 068 已部署生产。本卡未部署后端或发版。
4. 安卓实现与截图由对应 RN 卡验收。

## 全量测试发现与处置

- 首轮 StudentKit 全量：1336 tests，18 issues。其一是旧 `allDayPoundEditingStoresMetricAndAllowsClearingWeight` 断言，按 112「空重量恢复最近合法值」更新为 `allDayPoundEditingStoresMetricAndRestoresLastLegalWeight`，保留磅转公斤 220.5 lb → 100.02 kg 的验证。
- 视频 fixture 在进入被测 exporter 前创建源媒体失败（`Cannot Encode` / `HEVC writer start failed`）；单独运行 `videoExportProducesReadableFastStartMP4` 仍 1/1 失败，排除全套并行压力这一单一解释。相关视频实现与 fixture 均未改，当前证据指向本机编码环境，未将这些失败豁免或改成 skip。
- 最终 43 个改动 Swift 文件 `swiftlint lint --strict --quiet --no-cache`：exit 0。

## 改动文件

### Modules/CoreModels/（1 文件）

- [StudentSetLog.swift](../../Modules/CoreModels/Sources/CoreModels/Entities/Plan/StudentSetLog.swift)

### Modules/DesignSystem/（8 文件）

- [MeetPRAllDayNumberPad.swift](../../Modules/DesignSystem/Sources/DesignSystem/Components/Inputs/MeetPRAllDayNumberPad.swift)
- [MeetPRAllDayPadActions.swift](../../Modules/DesignSystem/Sources/DesignSystem/Components/Inputs/MeetPRAllDayPadActions.swift)
- [MeetPRNumberPad.swift](../../Modules/DesignSystem/Sources/DesignSystem/Components/Inputs/MeetPRNumberPad.swift)
- [MeetPRNumberPadDismissButton.swift](../../Modules/DesignSystem/Sources/DesignSystem/Components/Inputs/MeetPRNumberPadDismissButton.swift)
- [MeetPRNumberPadField.swift](../../Modules/DesignSystem/Sources/DesignSystem/Components/Inputs/MeetPRNumberPadField.swift)
- [DesignSystemStrings.swift](../../Modules/DesignSystem/Sources/DesignSystem/DesignSystemStrings.swift)
- [Localizable.xcstrings](../../Modules/DesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings)
- [NumberPadShortcutTests.swift](../../Modules/DesignSystem/Tests/DesignSystemTests/NumberPadShortcutTests.swift)

### Modules/Networking/（3 文件）

- [SetLogDTOs.swift](../../Modules/Networking/Sources/Networking/DTO/SetLogDTOs.swift)
- [DomainMapping.swift](../../Modules/Networking/Sources/Networking/Mapping/DomainMapping.swift)
- [AllDayContractTests.swift](../../Modules/Networking/Tests/NetworkingTests/AllDayContractTests.swift)

### Modules/StudentKit/（33 文件）

- [AccessoryHistory.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryHistory.swift)
- [AllDayExercise.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayExercise.swift)
- [AllDayExerciseBlock.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayExerciseBlock.swift)
- [AllDayExerciseSummary.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayExerciseSummary.swift)
- [AllDayKeypadActions.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayKeypadActions.swift)
- [AllDayKeypadEditing.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayKeypadEditing.swift)
- [AllDayKeypadPersistence.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayKeypadPersistence.swift)
- [AllDaySetRow.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDaySetRow.swift)
- [AllDaySheetView.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDaySheetView.swift)
- [AllDayWeightHistory.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AllDayWeightHistory.swift)
- [StudentAddedPreviousSession.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentAddedPreviousSession.swift)
- [StudentAddedRows.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentAddedRows.swift)
- [TodayWorkoutTypes.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutTypes.swift)
- [TodayWorkoutViewModel+DraftBuilding.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+DraftBuilding.swift)
- [TodayWorkoutViewModel.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel.swift)
- [WorkoutCompletionPresentation.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutCompletionPresentation.swift)
- [WorkoutKeypadCell.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutKeypadCell.swift)
- [WorkoutKeypadOverlay.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutKeypadOverlay.swift)
- [WorkoutKeypadSession.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/WorkoutKeypadSession.swift)
- [GrowthScreenPresentation.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/GrowthScreenPresentation.swift)
- [ProgressMetrics.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/ProgressMetrics.swift)
- [StudentAddedDerivedHistory.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedDerivedHistory.swift)
- [StudentAddedHistory.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedHistory.swift)
- [StudentAddedLedgerRepair.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedLedgerRepair.swift)
- [BackendStudentTrainingLogRepository.swift](../../Modules/StudentKit/Sources/StudentKit/Repository/BackendStudentTrainingLogRepository.swift)
- [InMemoryStudentTrainingLogRepository.swift](../../Modules/StudentKit/Sources/StudentKit/Repository/InMemoryStudentTrainingLogRepository.swift)
- [PendingSetRecord.swift](../../Modules/StudentKit/Sources/StudentKit/Repository/SetSync/PendingSetRecord.swift)
- [SetSyncSender.swift](../../Modules/StudentKit/Sources/StudentKit/Repository/SetSync/SetSyncSender.swift)
- [Localizable.xcstrings](../../Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings)
- [StudentStrings.swift](../../Modules/StudentKit/Sources/StudentKit/StudentStrings.swift)
- [AllDayDirectEditingTests.swift](../../Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AllDayDirectEditingTests.swift)
- [AllDayReviewRegressionTests.swift](../../Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AllDayReviewRegressionTests.swift)
- [AllDayRevisionTests.swift](../../Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AllDayRevisionTests.swift)

### docs/（1 文件）

- [2026-11-17-112-keypad-function-keys-ios.md](../../docs/journal/2026-11-17-112-keypad-function-keys-ios.md)


## 原始日志索引（本机留证）

- 最终全量：[StudentKit](../../.build/spec112-logs/studentkit-full-final.log)、[DesignSystem](../../.build/spec112-logs/designsystem-full-final.log)。
- 定向回归：[审查发现红测](../../.build/spec112-logs/all-day-review-red.log)、[返修绿测](../../.build/spec112-logs/all-day-final-green.log)。
- 环境：[视频 fixture 单跑](../../.build/spec112-logs/video-fixture-isolated.log)、[iOS 测试尝试](../../.build/spec112-logs/ios-test-fallback.log)、[strict lint](../../.build/spec112-logs/swiftlint-final.log)。
- CoreModels / Networking 全量原始日志位于 `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-112-050b55d34065/logs/`，分别为 `swift_package_test_2026-11-17T11-13-42-615Z_pid43634_e0572d35.log`、`swift_package_test_2026-11-17T11-14-44-418Z_pid43634_6ccd0124.log`；两包在全量之后未改源码。
- `.build/` 日志被 git 忽略；上方输出摘要已写入本 JOURNAL，供提交后的永久追溯。此前 MCP 首次 iOS build 超时，没有成功产物证据，不能计为通过。

## 本轮原始日志

- [DesignSystem 全量 83/0](../../.build/spec112-logs/designsystem-rerun.log)
- [Networking 全量 158/0](../../.build/spec112-logs/networking-rerun.log)
- [StudentKit 全量 1320/16](../../.build/spec112-logs/studentkit-rerun.log)
- [独立编码器探针输出](../../.build/spec112-logs/encoder-probe.log)
- [simctl 连接错误](../../.build/spec112-logs/simctl-rerun.log)

以上日志均为本机忽略文件，关键红绿证据、底层错误码、测试计数已固化在本 JOURNAL。
