# Hero 动作行逐组展开 · iOS

- 卡：`docs/cards/2026-11-07-hero-expand-sets.md`。
- 工作树：`/Users/david/Projects/apps/MeetPR-wt-hero-expand`，分支 `feat/hero-expand-sets`，起点 `d267625f`。
- 开工可写探针：创建、确认、删除成功；没有切换 checkout。
- 权限：不 commit、不 push、不建 PR；正典台账与任务卡未改。
- 状态：开发实现与卡内自测取证完成，待 Opus 收货；没有 commit / push / PR。

## 实现与测试记录

测试 seam：`TodayWorkoutPresentation.Exercise.prescriptionRows`（逐组 id、显示组号与处方文本）。

改动文件：

- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutPresentation.swift`：逐组处方展示模型；排除 extra / 学员自加组，沿用显示组号，百分比传入解算结果，旧式按逐组 record 格式化。
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`：本地 `@State` 默认收起；内容视图通过 Binding 接收状态，沿用回顾卡按钮、Dynamic Type、字号/间距/边框、无障碍值；摘要计算保持原样。
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/HeroPrescriptionRowsTests.swift`：4 个处方展示测试。
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/HeroActionSummaryRowTests.swift`：1 个 ViewInspector 展开/收起测试。
- 本 JOURNAL 与本卡证据目录；`TrainingDayPreview` 复用原动作行，无需改文件。

已完成的 red → green：

1. `heterogeneousPrescriptionsKeepEachWeightAndDisplayNumber`：缺少属性导致编译失败 → 1/1 通过；不同重量与非零起始组号，原摘要仍为「2 组」。
2. `legacyPrescriptionsKeepLaterWeightsAndMissingWeight`：输出 `x` / `-kg` 导致断言失败 → 2/2 通过；逐组 record 的 kg、次数与缺重量占位。
3. `prescriptionRowsExcludeExtraAndStudentAddedSets`：额外组、自加组混入导致 3 条断言失败 → 3/3 通过；改为读取 `prescribedRows`。
4. `percentagePrescriptionIncludesResolvedWeight`：实际红测为 `75% × 3`，预期 `≈ 150 kg · 75% · 1RM × 3`；4 个测试中 1 个失败 → 最终聚焦绿测通过。
5. `summaryRowStartsCollapsedAndTogglesPrescriptions`：缺少内容视图导致编译失败（`hero-ui-red.log`）；补齐本地状态与绑定内容视图后验证默认收起、点击展开、逐组重量、无障碍值、再次收起及无视频按钮 → 最终聚焦绿测通过。

最终聚焦命令在下列 SwiftPM 命令增加 `--jobs 1`，filter 改为 `'HeroPrescriptionRowsTests|HeroActionSummaryRowTests'`：**5 tests / 2 suites passed**；日志 `scratch/evidence/hero-green-final.log`。

命令（日志见 `scratch/evidence/hero-{red,green}-N.log`）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/scratch/clang-cache" swift test \
  --package-path Modules/StudentKit \
  --scratch-path scratch/hero-tests-build \
  --cache-path scratch/hero-tests-cache \
  --disable-sandbox --skip-update --filter HeroPrescriptionRowsTests
```

环境记录：先调用 XcodeBuildMCP `session_show_defaults`，随后设定当前工程、`MeetPR-DemoStudent` 和 iPhone 17e（iOS 26.5，`5D5FA360-BA49-48C6-A887-2F0D22F89749`）。MCP `swift_package_test` 因 GitHub 连接失败无法拉取 ViewInspector，改用本机已有的 0.10.3 缓存与 worktree 内缓存目录运行 SwiftPM，没有改变依赖版本或 Package.swift。下载失败和早期缓存权限失败不计为红测。

2026-11-07 03:38 UTC：`uptime` 报告 load averages 256.04 / 184.06 / 145.59，编译明显变慢；未终止其他进程、未换模拟器。

百分比测试第一次长时间编译被本会话中断（exit 130，不计红测，日志 `hero-red-4-interrupted.log`）；随后用 `--jobs 1` 重跑得到上述有效红测。David 后续明确继续等待慢命令、不终止任何进程；其后遵循该约束。

## 静态验证与审查

- `swiftlint lint --strict --no-cache <上述 4 个 Swift 文件>`：0 violations，0 serious；`scratch/evidence/lint-final.log`。
- Xcode 工具链 `swift-format format -i <上述 4 个 Swift 文件>`，随后 `swift-format lint --strict <同样文件>`：exit 0，无输出；`scratch/evidence/format-final.log`。
- 本地 `review-loop` 一轮两个只读独立 reviewer：Standards **CLEAN**（无硬规则违反或有实质影响的坏味道）；Spec **CLEAN**（代码及测试符合卡，无越界）。两轴均未修改文件、未运行额外构建；运行验收证据由主代理补齐。
- 仓内缺少 `docs/agents/issue-tracker.md`，使用 review-loop 的本地双轴路径，没有私建 tracker，也未声称运行已配置的 tracker 工作流。

## 全量测试与 App 编译

- 同一 SwiftPM 命令去掉 filter，增加 `--skip-build`：运行 1191 个测试，14 个既有视频测试失败（15 条 issue，含一个双参数用例），均为生成视频夹具时 `Cannot Encode`；其余 1177 个通过，含全部 5 个新增测试。日志 `scratch/evidence/studentkit-full.log`。单跑 `passthroughTrimOfAShortSourceKeepsTheWholeClip` 同样失败（`video-fixture-probe.log`），排除仅由全量并发触发的解释；随后以同一源码、未修改的视频夹具，用 XcodeBuildMCP 原生运行器复测：**1191 / 1191 通过，79 suites，0 failed，0 skipped**（`studentkit-full-green.log`）。环境切换后既有视频测试全部通过，故不修改卡范围外代码。
- MCP 首次复用缓存的 symlink 别名导致 Clang module 路径冲突；未改代码，去掉 symlink 并使用独立 `.build`，日志 `mcp-cache-alias-failure.log`。
- `XcodeBuildMCP.build_sim`：`MeetPR.xcodeproj` / `MeetPR-DemoStudent` / iPhone 17e，`-jobs 1 -skipPackageUpdates -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO`，DerivedData 在 `scratch/hero-derived`。首次 MCP 等待 300 秒超时，但底层构建仍运行，未终止；等它自然结束后增量确认 **BUILD SUCCEEDED**，0 errors / 0 warnings（确认这次调用），日志 `scratch/evidence/app-build.log`。首次超时说明见 `app-build-mcp-timeout.log`。

原生全量调用（session configuration = `Debug`）：

```text
XcodeBuildMCP.swift_package_test({
  "packagePath": "/Users/david/Projects/apps/MeetPR-wt-hero-expand/Modules/StudentKit"
})
```

本次原生全量重建报告 21 条已有 warning（测试锁/并发、无效 try 等，均不在本次四个改动文件中），没有新增 warning；不越界修复。

## 截图取证

现有百分比 Demo 含已完成记录，不能直接展示未开练 Hero。为避免修改范围外的 Demo seed，在 `scratch/evidence/HeroEvidence.swift` 和同目录临时 Xcode 工程中直接调用真实 `TodayWorkoutScreen`，注入未开始的异重处方（140、125、120 kg），只用于模拟器取证，不进入产品 target。

- 宿主 `HeroEvidence` / Debug，bundle `com.meetpr.hero-evidence`，iPhone 17e（iOS 26.5）；`XcodeBuildMCP.build_run_sim` 参数 `-jobs 1 -skipPackageUpdates CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES`，构建、安装和启动成功（`scratch/evidence/host-build.log`）。首次自定义配置未向包传递 `-enable-testing`，改用标准 Debug 与显式 ENABLE_TESTABILITY 后解决，仅临时工程有调整。
- 收起态：`docs/evidence/2026-11-07-hero-expand/hero-collapsed.jpg`。
- 展开态：`docs/evidence/2026-11-07-hero-expand/hero-expanded.jpg`。
- 两张都是 MCP 从 iPhone 17e 截取的 JPEG（369×800），未改图；主代理已亲眼核对。摘要「3 组」不变，chevron 随状态切换，展开列出第 1/2/3 组及 140/125/120 kg，无视频按钮。
- 实际 tap：默认「已收起」→「已展开」并出现三组处方→再次点击「已收起」且逐组行消失。机器可读快照及断言在 `scratch/evidence/hero-interaction.json`。

## 偏差与遗留

- 功能、文件范围与 Out of Scope 无偏离。取证使用临时宿主注入数据、渲染真实组件，而非现有带完成记录的 Demo seed；正式 App 编译另有成功证据。未改产品工程、seed、依赖或文案 key。
- 全量测试最终改用 XcodeBuildMCP；shell 运行器的视频编码失败和一次缓存别名失败均保留原始日志，没有跳过或修改失败测试。额外复跑用于确认环境问题与取得构建退出结果，不冒充首次通过。
- 仅清理自己生成的构建缓存：从未跟踪的 scratch 移入本 worktree 已忽略的 `.build/hero-expand.*`，位置记录在 `scratch/evidence/build-cache-location.txt`。测试/构建命令中的 scratch 路径是执行时路径；日志、截图及可复现宿主仍保留。
- 新增 5 测试先红后绿、全量 1191 测试绿、lint/format、正式 App 编译及两张截图均已取得。没有未完成的卡内开发项。
- 收货与最终放行由 Opus 按任务卡决定。
