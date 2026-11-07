# acc-cols iOS 实装记录

状态：返修 1 已完成代码与包测试验证；设备触摸仍待 Opus 原场景复验。未 commit、未 push。

## 范围与实现

- 任务：[CARD-acc-cols.md](../../CARD-acc-cols.md)。分支 `fix/accessory-table-columns`，开工 HEAD `c4d5d3c2`，基于未合并的 `feat/105-in-app-keypad`。开工仅任务卡未跟踪；先在当前工作树创建并删除临时文件，写权限验证成功。
- `AccessoryColumns.widths` 保持组、KG、次数、完成列原分配，强度列改为与次数列相同；原强度列释放的宽度全部归「上次」。343pt 表格的分配从 `[36,56,64,44,88,40]` 改为 `[36,100,64,44,44,40]`（另有 5 个 3pt 间隔）。88 仅保留为旧分配的转移基准，不再是强度列保底。
- `AccessoryRow.previousText` 为行展示 seam，统一计划组及自加组的上次文案：RIR 优先，其次原始 RPE，不使用 coachRPE；无强度不加后缀，无记录为 `—`。沿用 KG/LB 转换及去尾零；点击上次仍只填重量和次数。
- `AccessoryLogRow` 消费上述文案，无空格，11pt 原字体的缩放下限设为 10pt。
- 辅助表头的切换与问号分别保持独立 Button、原 accessibility label 和独立 contentShape。初版问号使用 14pt 字号、14×44pt 点击区域，图标上移形成角标；但真实符号布局尺寸超出点击框，返修 1 已改为实际 14×14pt 图像与显式横向分区。其他调用点维持原样，说明卡内容不变。
- `StudentAddedInlineRows` 已共用 `AccessoryColumns` 与 `AccessoryLogRow`，无需重复修改，自动保持对齐。未修改 free-weight 且不允许 RIR 的独立排版、主项卡、模型、后端、依赖、任务卡或正典账本。

## 测试与原始证据

先写测试，然后将原 View 拼接原样提取至行模型、将原 widths 改为模块内可见，未改变行为；以下红测是实际断言失败，不是编译失败。

首次 `XcodeBuildMCP.swift_package_test(packagePath: …/Modules/StudentKit, filter: AccessoryColumnsTests)` 在依赖获取阶段 300 秒超时，见 [环境日志](../evidence/acc-cols/mcp-initial-test.log)。随后复用本机相同版本 ViewInspector 0.10.3 的依赖缓存，未复制其他工作树业务源码。

红、绿命令（从本工作树根执行；输出分别写入 red.log / green.log）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/Modules/StudentKit/.build-acc-cols/ModuleCache" swift test --package-path Modules/StudentKit --scratch-path Modules/StudentKit/.build-acc-cols --cache-path /tmp/acc-cols-spm-cache --disable-sandbox --skip-update --filter AccessoryColumnsTests
```

- [红测](../evidence/acc-cols/red.log)：2 tests failed，21 issues。列宽 11 个失败断言，上次文案 10 个失败断言。
- [绿测](../evidence/acc-cols/green.log)：2 tests passed，0 issues。覆盖 RIR/RPE/无强度/无记录、RIR 0、RIR 优先、KG/LB、长文案、复制不填强度、两类历史记录、列宽相等及宽度守恒。
- 全量 StudentKit 最终串行结果：1193 passed / 0 failed（返修 1 后），见下方原始日志。早期并行运行的 21 个视频超时未在当前分支与基线的串行运行中复现。
- [SwiftLint strict](../evidence/acc-cols/swiftlint.log)：5 files，0 violations。首次发现测试的 3 元 tuple，改为 2 元组合；断言及行为未变。
- [swift-format strict](../evidence/acc-cols/swift-format.log) 与 `git diff --check`：通过。

## 模拟器

- 仅 iPhone 17e / iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`。
- 项目为本工作树 `MeetPR.xcodeproj`，scheme `MeetPR-DemoStudent`，DerivedData `/tmp/acc-cols-derived-data`，启动参数 `--spec089-upgrade`。复用现有辅助项 Demo，不改 fixture。
- 初次优化构建由 David 停止。后续截图由 Opus 完成；本轮按 David 指示不再构建模拟器或截图。Opus 在 iPhone 17e / DemoStudent / `--spec089-upgrade` 上发现问号触摸误触切换，见下方返修记录。截图路径未在返修交接中提供。

## 独立审查与遗留

按 review-loop 对 HEAD 后本卡 diff 及新增测试做两路只读审查：Standards **CLEAN，0 findings**；Spec **CLEAN，0 findings**。两路均未运行测试，测试与设备证据由主代理执行。缺 `docs/agents/issue-tracker.md`，使用批准任务卡的本地入口，未伪建 Matt tracker；如需该 tracker 流程，由 David 调用 `$setup-matt-pocock-skills`。

本卡只交 iOS；安卓不在本工作树任务范围。未自行宣布产品验收通过。


## 返修 1

### 接收与验证边界

Opus 复现：坐姿划船辅助卡的问号可见位置约 `(291,119)` / `(292,127)`，点击触发 RPE/RIR 切换，没有打开说明。本轮不做模拟器构建或截图。原独立审查为静态检查，未覆盖系统实际触摸分发，不能作为此行为通过的依据。

ViewInspector 可以检查 modifier 与按钮动作，但不运行 SwiftUI 原生布局/触摸路由；其 GeometryReader 通过零初始化的 GeometryProxy 展开内容。因此不能用 `Button.tap()` 证明坐标触摸正确。本轮采用辅助表头布局与真实符号测量的最近 seam；系统手指触摸仍须 Opus 在原设备场景复验。

### 视频并发基线比较

- 基线为本地 `origin/release/1.0` @ `c7af485785dae08daa368ebf4062e9acbb490df8`，通过 git archive 建立独立临时 checkout `/tmp/meetpr-acc-cols-baseline`，未复制本卡业务源码。
- 同机串行重跑原 21 个超时测试：**21 passed / 0 failed**，见 [baseline-serial.log](../evidence/acc-cols/baseline-serial.log)、[完整测试名单](../evidence/acc-cols/video-timeout-tests.txt) 和 [基线上下文](../evidence/acc-cols/baseline-context.txt)。
- 结论：基线串行没有复现这 21 个失败，不能报告为「已证实的基线缺陷」。原并行超时与机器负载/执行模式相关的可能性仍在；不能仅凭该结果认定本卡有回归或没有回归。

```sh
CLANG_MODULE_CACHE_PATH=/tmp/meetpr-acc-cols-baseline/ModuleCache swift test --package-path /tmp/meetpr-acc-cols-baseline/Modules/StudentKit --cache-path /tmp/acc-cols-baseline-spm-cache --disable-sandbox --skip-update --no-parallel -j 4 --filter "$(cat /tmp/meetpr-acc-cols-baseline/test-filter.txt)"
```

### 已确认的布局缺陷与改动

- 修复前用 ViewInspector 读取生产符号的 font、外层固定 frame 和 offset，再用 `NSHostingView.fittingSize` 测量：14pt 字体的问号符号布局边界实际为 **16×16pt**，并非 14×14pt。343pt 表宽下 help 区为 `(30,0,14,44)`，符号边界为 `(29,6,16,16)`，左侧 1pt 进入切换区域。280/320/343/360/390 五种表宽均复现。这里只证明 macOS SwiftUI 布局边界不匹配，不将其冒充 iOS 可见墨迹测量或指定触点的完整根因证明。
- 纵向 offset 后符号仍在 44pt 高区域内，未发现纵向越界；旧 HStack 对 toggle 的原生命中路由不能由 ViewInspector 判定，因此未把“无限宽覆盖”或“HStack 挤出”宣称为已证实原因。
- `EffortHelpIcon` 对辅助表头改用可缩放符号并把实际图像限定为 **14×14pt**，保持右上角 offset；外层点击框仍为 **14×44pt**。非辅助表头保持原来的 18pt 字体与 44×44pt 按钮。
- `AccessoryEffortHeaderLayout` 在生产 `placeSubviews` 中使用 `hitAreas(width:)`，把列的剩余宽度给 toggle，最后 14pt 给 help，两个区域不重叠。toggle 允许最小宽度为 0，避免固有文字宽度争用 help 分区。没有改动切换动作、说明内容或原无障碍标签。
- 回归测试最终读取完整生产图标的实际布局尺寸与外层 frame/offset，并调用生产布局的 `hitAreas`；断言图标边界包含于 help、help 与 toggle 横向无交集、help 右边界等于列右边界、命中高度至少 44pt。

### 本轮测试

沿用已建立的隔离 CLI build cache，避免原 MCP 包测试锁；没有重启模拟器构建。首轮测试代码曾误用 ViewInspector `actualView()` 读取 Image，编译诊断后改用其 `actualImage()`；这次编译失败不计为红测。以下红测是随后真实断言失败。

命令前缀（从本工作树根执行）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/Modules/StudentKit/.build-acc-cols/ModuleCache" swift test --package-path Modules/StudentKit --scratch-path Modules/StudentKit/.build-acc-cols --cache-path /tmp/acc-cols-spm-cache --disable-sandbox --skip-update --no-parallel -j 4
```

- 红：加 `--filter AccessoryColumnsTests.helpHitAreaContainsVisibleBadgeWithoutEnteringToggle`。**0 passed / 1 failed，10 issues**；随后 `--skip-build` 同过滤器复核仍红，原始证据 [rework-1-red.log](../evidence/acc-cols/rework-1-red.log)。此时尚未更改生产实现。
- 绿：加 `--filter AccessoryColumnsTests`。**3 passed / 0 failed**，[rework-1-green.log](../evidence/acc-cols/rework-1-green.log)。
- 辅助卡相关：加 `--filter '(?i)(accessory|StudentAdded|EffortExplainer|RIRStepper)'`。**62 passed / 0 failed**，[rework-1-related.log](../evidence/acc-cols/rework-1-related.log)。包括最终格式修整后的回归测试。
- CLI 串行全量：不加过滤器，**1179 passed / 14 failed（15 issues），共 1193 tests**。失败全为媒体测试 `Cannot Encode`；原 21 个并发超时测试全部通过。见 [rework-1-full-serial.log](../evidence/acc-cols/rework-1-full-serial.log)。为区分 CLI 执行环境影响，另外通过 XcodeBuildMCP 做一次串行全量核实。

```sh
swiftlint lint --strict Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogCard.swift Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogRow.swift Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryRow.swift Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/EffortExplainerCard.swift Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryColumnsTests.swift
```

Strict lint：**5 files / 0 violations**，[rework-1-swiftlint.log](../evidence/acc-cols/rework-1-swiftlint.log)。首跑的类型长度超限通过拆分同义 frame modifier 解决，未屏蔽规则。`xcrun swift-format lint --strict`（本轮三个 Swift 文件）与 `git diff --check` 通过。

本轮 review-loop 两路只读复审：Standards **CLEAN / 0 findings**；Spec **CLEAN / 0 code blockers**。两者均强调本次布局测试不能替代 iOS 原生手指触摸复验。最终代码未改变按钮动作或说明内容；Opus 仍需复验原坐姿划船页的问号触点。


### 全量最终结果与遗留

```text
XcodeBuildMCP.swift_package_test({
  "packagePath": "/Users/david/Projects/apps/MeetPR-wt-acc-cols/Modules/StudentKit",
  "parallel": false
})
```

- **1193 passed / 0 failed，79 suites，20.134s 测试耗时**。原始日志：[rework-1-full-mcp-serial.log](../evidence/acc-cols/rework-1-full-mcp-serial.log)。本次 MCP 调用正常完成，没有重复重启。
- CLI 报 `Cannot Encode` 的 14 个测试在该执行通道全部通过；失败未在 MCP 通道复现，保留 CLI 原始日志而不更改媒体代码。
- 原 21 个视频并发超时测试在本分支全量串行、基线过滤串行均为 **21 passed / 0 failed**。两侧串行均未复现，不能归因为已证实的 release 基线缺陷；原并行运行/高负载下的超时仍作为历史环境现象记录，本卡不扩展修改视频并发代码。
- 本轮实际改动：`AccessoryLogCard.swift`、`EffortExplainerCard.swift`、`AccessoryColumnsTests.swift`、本 JOURNAL 与 `docs/evidence/acc-cols/` 日志。`AccessoryLogRow.swift` / `AccessoryRow.swift` 保留本卡上一轮改动，本轮未再修改。任务卡保持原样。
- 验收边界：布局不变量、辅助卡相关测试与全量包测试已通过；未按指示重新构建模拟器或截图。iPhone 17e 指定触点是否不再误切换、是否打开说明，仍待 Opus 在原场景复验，不宣称已通过该设备验收。

清理已完成并核实目录不存在：`Modules/StudentKit/.build-acc-cols`、本任务 MCP 建立的 `Modules/StudentKit/.build`、`/tmp/meetpr-acc-cols-baseline`、`/tmp/acc-cols-derived-data`、`/tmp/acc-cols-spm-cache`、`/tmp/acc-cols-baseline-spm-cache`。删除前核实包测试锁已释放；保留全部原始测试日志。未 commit、未 push，`CARD-acc-cols.md` 保留。
