# 090 · iOS accessory hero 去重

## 范围与现场

- 卡：`specs/090-training-flow/CARD-accessory-hero-dedupe-ios.md`，T1 / P1。
- 工作树：`/Users/david/Projects/apps/MeetPR-wt-090b`。
- 分支：`fix/090-accessory-hero-dedupe`；开工 HEAD `bfc0fdc8`，跟踪 `origin/release/1.0`。未使用 main；不 commit、不 push。
- 开工工作区只有用户预置的未跟踪任务卡；该卡不改。
- 已读 CLAUDE、CONTEXT、AGENTS、FOLLOWUPS、任务卡与 SPEC §1 / 验收 11。工作树 SPEC 尚无 2026-11-04 修订，按用户明确指定以卡为准，不改正典。
- FOLLOWUPS 未发现本卡新增触发的工程动作；历史文档维护项不扩入本卡。

## 实现与歧义处理

- 公开测试 seam 沿用卡已批准的 `TodayWorkoutPresentation.trainingFlow(isEditable:)` / `TrainingFlowPresentation.belowHero`。
- 现有 `accessoryExercise(isEditable:)` 内部调用 `trainingFlow`，不能从 flow 初始化器直接反调它，否则递归。复用形态选择谓词，保留原条件（辅助项或 `hasUnspecifiedLoad`），不另造动作分类。
- 卡中的“主项 / 变式不变”按其明确限定的实际 hero 形态解释：普通主项 / 变式保留自己的下方卡；若未指定负重使其原本就进入 accessory 形态，则同样去重。
- 既有 `pageOrdersCompletedBeforeHeroAndRestoresAfterCancellation` 的 `[1, 2]` 断言要求当前辅助项重复展示；需要按新卡改为 `[2]`，其他既有断言保留。
- `flow == nil`、分区、滚动、完成按钮、自加动作区均不改。

## 原始验证记录

- 先新增辅助项回归用例与主项对照，用实现修改前的代码运行 `TrainingFlowTests`。
- XcodeBuildMCP 的 SwiftPM 工具会消费 session `configuration`；`Demo` / `DemoStudent` 不被 SwiftPM 接受（参数校验失败，不算红测），切换 `Debug` 后启动实际测试。
- 模拟器唯一目标：iPhone 17e，iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`。未创建或操作其它模拟器。
- 首次 XcodeBuildMCP 测试调用 300 秒超时，但后台继续编译；shell SwiftPM 等锁后因默认 clang cache 在沙箱外而失败。这两次均是工具/环境失败，不计红测。依赖编译结束后使用 MCP 重跑。

### Red → Green

- Red（改实现前）：7 tests，6 passed / 1 failed；辅助项新用例产生 3 issues，分别是 `[1, 2] != [2]`、最后辅助项仍留在列表、取消后再次重复。主项对照通过。
- MCP summary 把 3 issues 错计为 3 failed / 4 passed；上述计数以原日志逐个测试及最终 `7 tests ... 3 issues` 为准。
- Red 原日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T04-51-52-166Z_pid29515_1d6b1d2d.log`。
- Green（实现后）：`TrainingFlowTests` 7 passed / 0 failed / 0 skipped，155.5s（含增量编译）。
- Green 原日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T04-52-18-133Z_pid29515_099d2b5d.log`。
- 全量首跑：1096 tests，1077 passed / 19 failed，失败全部为视频/后台任务的 `TimeoutError`；当时模拟器 App 正在首次构建。尚不把并行负载断定为根因。
- 全量首跑日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T04-55-05-931Z_pid29515_fbc7d16d.log`。
- 3 个改动 Swift 文件 `swiftlint lint --strict`：0 violations；Xcode 工具链 `swift-format lint --strict` exit 0；`git diff --check` exit 0。
- 全量串行复跑（MCP `parallel: false`，已核对工具实现对应 `swift test --no-parallel`）也在 300 秒触及调用超时；日志尚无测试终态，不能视为通过。日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T05-03-49-505Z_pid29515_cb67fae3.log`。

### 模拟器构建

- 工程：本工作树 `MeetPR.xcodeproj`；scheme/configuration：`MeetPR-DemoStudent` / `DemoStudent`；bundle：`com.meetpr.app`。
- 首跑 DerivedData：`/tmp/meetpr-090-dedupe-build`。工具调用 300 秒超时后后台继续执行；最终原日志出现 `** BUILD SUCCEEDED **`，App 产物时间 05:13 UTC，并已安装运行于 iPhone 17e。截图与交互验证使用此优化构建。
- 首跑日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/build_run_sim_2026-11-04T04-52-57-709Z_pid29515_48f15e00.log`。
- 后续使用独立 `/tmp/meetpr-090-dedupe-debug`，仅命令参数指定 `SWIFT_OPTIMIZATION_LEVEL=-Onone SWIFT_COMPILATION_MODE=incremental -jobs 2`，复用首跑 SourcePackages。没有改工程配置或依赖。
- 备用构建同样触及工具调用超时，后台最终也出现 `** BUILD SUCCEEDED **`；日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/build_run_sim_2026-11-04T05-10-56-349Z_pid29515_4fb1520c.log`。两次构建均成功，不需要凭临时关闭优化来掩盖默认配置失败。
- Activity Monitor 进程检查未获 Computer Use 授权，没有操作该 App；继续以构建日志/产物验证。

### 实屏原始证据

截图目录：`specs/090-training-flow/evidence/dedupe-20261104/`。全部通过 XcodeBuildMCP 捕获并亲自查看；使用未改动的 `TrainingFlowDemoScenario` fixture，均是 Demo/InMemory 证据，不代表真实服务端持久化验证。

| 文件 | 操作与实际观察 |
| --- | --- |
| `01-main-hero.jpg` | 启动 `--spec090-main-two` → 训练 tab；硬拉 hero 第 3/3 组，下方仍是硬拉自身组表，显示 2/3 组已记录。 |
| `02-accessory-hero-upgrade.jpg` | 冷启动 `--spec090-upgrade`（已有 5 组）→ 训练 tab；硬拉 3 组上收，第一辅助项为 hero，三行中前两行有 ✓；没有该计划动作的重复三组表。截图为轻微滚动后完整 hero。 |
| `03-accessory-advanced.jpg` | 点 hero「完成第 3 组」；第一辅助项上收为「已完成 · 3 组」，第二辅助项进入 hero（动作 3/3、2 组），hero 后直接是「加动作」与剩余组提示，没有重复组表。 |
| `04-accessory-restored.jpg` | 展开 `training.completed.1`，取消第 3 组；原辅助项重新成为 hero（动作 2/3、3 组），下方仅保留下一计划动作。随后实点「全部按计划完成」再次验证上收。 |
| `05-all-completed-dock.jpg` | 第二辅助项点「全部按计划完成」；只剩 3 条已完成行，无 hero，唯一完成按钮在 tab 上方吸底。 |

fixture 中两个辅助项恰好都叫「坐姿划船」，但它们是两个不同的计划动作：ID 尾号 `000000000011`（3 组）与 `000000000012`（2 组）。去重按计划动作身份而非名称；`04` 中下方同名卡是后一个 2 组动作，不是重复的 3 组 hero。未为截图修改 fixture。

运行时 AX 摘录：

```text
主项：硬拉，2 / 3 组已记录 | 已展开
升级首屏：training.completed.0 = 硬拉，已完成，3 组
hero = 辅助项 · · 动作 2 / 3；取消第 1 组、取消第 2 组、完成第 3 组
上收后：training.completed.1 = 坐姿划船，已完成，3 组
hero = 辅助项 · · 动作 3 / 3；完成第 1 组、完成第 2 组
部分完成：长按完成今日训练（无 training.completionDock）
全部完成：training.completed.0 / .1 / .2；training.completionDock 唯一按钮
```

### 全量测试中的阻塞与解除

- 05:19 UTC 正常并行复跑被前一串行进程的构建锁挡住，原始输出：

```text
Another instance of SwiftPM (PID: 54935) is already running using
'/Users/david/Projects/apps/MeetPR-wt-090b/Modules/StudentKit/.build',
waiting until that process has finished execution...
```

- 等锁日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T05-19-33-483Z_pid29515_3d9e7e76.log`。
- 终止本次串行进程 `kill -TERM 54935` 被沙箱拒绝（operation not permitted）；专用 MCP `swift_package_stop` 返回该 PID 不在其托管进程表内。
- 当时请求 David 在本机停止这一个进程。后来构建锁已释放，已立即通知不再需要执行 kill；没有把未收到的用户回复当成授权或操作证据。未删锁文件、未绕过权限、未修改失败测试。
- 等锁后的并行复跑实际完成：1074 passed / 22 failed，全部仍为视频/后台任务 `TimeoutError`。保留上述日志，不将它报告为通过。

### 最终验证结果

- 隔离复跑 `filter: VideoUpload|BackgroundUpload|BackgroundVideo|VideoTrim`：121 passed / 0 failed / 0 skipped，5.8s；包括前述超时路径。
- 隔离日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T05-23-23-089Z_pid29515_2885cd2a.log`。
- **两次 App 构建均结束后，全量 StudentKit：1096 passed / 0 failed / 0 skipped，19.8s。** 沿用默认并行执行，没有删测试、改超时阈值或跳过用例；自第一次绿测后代码与测试都未再修改。
- 最终全量原日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T05-23-39-075Z_pid29515_a0e03985.log`。
- 观察支持前述超时与执行环境/调度相关，但未证明唯一根因，不声称修复了视频测试稳定性问题。本卡只改 hero 去重。
- iPhone 17e 的主项、辅助项升级首屏、逐组完成上收、取消恢复、全部按计划完成、完成按钮吸底已实屏观察，证据见上表；无后端/存储变更，真实存量账号升级仍由 Opus 按卡收货。
- 最终改动：2 个 presentation 源文件、1 个测试文件、本 JOURNAL、5 张截图。用户预置任务卡未改。未 commit、未 push、未改发版账本或 SPEC。

### 独立审查

- 使用 `review-loop` 一轮两个只读 reviewer；仓缺 `docs/agents/issue-tracker.md`，未声称运行完整 Matt tracker 流程，已提示需 `$setup-matt-pocock-skills`；本地审查直接以卡为源。
- Standards：CLEAN，0 findings。确认范围、共享谓词、无递归、Swift Testing 与行为 seam。
- Spec：CLEAN，0 findings。确认普通主项/变式、flow nil、分区/滚动/完成按钮未改，旧断言按卡修订合理。
- 这是开发自测与独立代码审查记录；Opus 仍按卡逐项收货。

## 2026-11-04 收货后交付

- David 本次明确授权完成 commit、push、向 `release/1.0` 开 PR，并在 CI 通过或仓库报告无 checks 后 merge；取代初始派卡的不提交限制。
- 按 David 的收货交接，Opus 已接受本卡，并在 iPhone 17e 验证：坐姿划船位于辅助项 hero 时，下方列表只显示下一个动作，模拟器验收通过。截图仍为 `specs/090-training-flow/evidence/dedupe-20261104/` 内五张证据。
- 交付前通过 XcodeBuildMCP 在本工作树 `Modules/StudentKit` 复跑完整 `swift test`：**1096/1096 通过，0 failed，0 skipped**；本次没有启动或操作模拟器。
- 原始结果行：`✔ Test run with 1096 tests in 54 suites passed after 3.637 seconds.`
- 本次全量日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-090b-a781f6c72888/logs/swift_package_test_2026-11-04T06-02-48-332Z_pid86928_7a48269b.log`。
