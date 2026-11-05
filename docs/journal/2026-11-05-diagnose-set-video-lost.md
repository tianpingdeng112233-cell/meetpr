# P0 · 部分组回看视频缺失 · 排障 JOURNAL

## 当前结论

当前到 Phase 6，返修第 1 轮已完成：消除 nil 组 ID → 删录像的放大器，先持久保留视频与组身份，再解析/绑定；保存成功或回原日自动挂回，失败可重试。补齐删除并发与补充组重载身份边界。StudentKit 1105 项、CoreModels 164 项及 iPhone 17e 应用构建全绿，两轴复审无剩余 finding。源码 debug 0 命中；shutdown 仍因环境权限失败，UDID 见末尾。未 commit/push、未写线上。未保存训练行本身在冷启动后不存在时，至少保留视频和持久记录，不擅自补造训练日志。以下保留分阶段历史，最新结论以返修第 1 轮为准。

任务来源：`docs/diagnose/set-video-lost-2026-11-05.md`。本次直接指令要求无红色反馈环则停止，优先于后续阶段的产物要求。

## 现场与范围

- 工作树：`/Users/david/Projects/apps/MeetPR-wt-video-lost`。
- 分支：`diagnose/set-video-lost-20261105`；HEAD：`09eef51d84c3ae253eabcf1be8e5664cc0b6a777`，符合指定基线。
- 本地 `beta/1.0-31^{commit}`：`4ffa409b76a0f06de9deff2661cfa24a2c9e34c5`。工作树含该版本之后的改动，不能把工作树等同于事故安装包。
- 启动时已有未跟踪任务卡，保留原文。发版工作树当前为 `60d0126b`，本任务没有移动基线。
- 已读 CONTEXT、CLAUDE、AGENTS、FOLLOWUPS、工程流程、记忆索引、diagnose 与 diagnosing-bugs 技能；为测试读取 xcodebuildmcp 技能及 096 规格/卡、相关现有测试。
- 没有访问线上 API、数据库或对象存储，没有读取凭证；后端仓未改动。
- FOLLOWUPS 未发现本次视频事故特有的新触发条件；历史维护项没有在 P0 排障中展开。

## 各阶段完成判据

| 阶段 | 状态 | 判据与证据 |
| --- | --- | --- |
| 1 反馈环 | 本地完成 | 完整三组场景实跑红，首/末组缺口与报告同形；4 个参数组合中仅 2 个交错组合失败；约 0.06 秒测试时间，命令墙钟约 0.45 秒。真实事故输入仍待补。 |
| 2 复现与最小化 | 本地完成 | 逐次删除 reload、结算、相邻组上传、其他处方组，每次仍红；最终一组、一个未返回的保存响应、一个相机回调足够。去掉时间交错则绿。 |
| 3 假设 | 完成 | 下表 4 个可证伪假设按原顺序保留，先回报后经 David 指令进入后续阶段。 |
| 4 埋点 | 本地完成 | H1→H4 逐项观察；H1 返回空，H2 canonical 合入正确，H3 队列/初始化均零，H4 有效附件可播放。 |
| 5 修复与回归 | 本地完成 | 正式测试先红后绿，只改 ID 解析入口；原 Phase 1 命令四个参数组合均绿。 |
| 6 修复验证与清理 | 代码验证完成；环境收尾例外 | 1099 项测试、iPhone 17e 应用构建、lint/format 与两轴审查通过；harness 已删，源码日志清零；shutdown 权限失败，需宿主确认。 |

## Phase 1：首轮已有测试尝试（追加 harness 前）

1. 查找任务相关日志、HAR、录屏与 fixture：`rg --files` 搜索 `docs/diagnose`、`docs/evidence` 和 `Modules/StudentKit/Tests`，再按事故日期及 W1D5/W2D1/W2D2 搜索。未找到本次事故的真实回放材料；日期搜索的另一命中是历史文档扫描 `spec095-trim-2026-11-02/residual-scan.txt`，不是学员运行日志。
2. 读取现有 `CompletedVideoReplayTests` 与 `HeroCameraUploadTests`，用于选择可运行 seam，没有沿实现猜原因。它们使用合成输入 / InMemory 仓储，不包含受影响学员的实际数据。
3. 先调用 XcodeBuildMCP `session_show_defaults`（全部未设置），再调用 `swift_package_test`，参数如下：

```json
{"packagePath":"/Users/david/Projects/apps/MeetPR-wt-video-lost/Modules/StudentKit","filter":"CompletedVideoReplayTests|heroCameraFirstUploadDoesNotRequireEntryPrefill"}
```

工具结果：`5 tests passed, 0 failed, 0 skipped`，含构建约 63.8 秒；既有编译警告 21 条，未扩展修复。日志位置：
`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-video-lost-d293bfe55635/logs/swift_package_test_2026-11-05T02-42-04-097Z_pid55284_6835d708.log`。

4. 为取得可直接复跑的秒级命令，使用工具不提供的 skip-build 参数复跑同一测试范围：

```sh
swift test --package-path Modules/StudentKit --skip-build --filter 'CompletedVideoReplayTests|heroCameraFirstUploadDoesNotRequireEntryPrefill'
```

脱敏输出（exit 0）：

```text
Target Platform: arm64e-apple-macos14.0
Test completedRowsUseServerSetLogIDsAndNewestVideo() passed after 0.030 seconds.
Test heroCameraFirstUploadDoesNotRequireEntryPrefill(editsArriveDuringCapture:) with 2 test cases passed after 0.051 seconds.
Test run with 5 tests in 1 suite passed after 0.051 seconds.
```

这是一条已运行的**绿色候选命令**，不是符合任务要求的红色反馈环。后续按 David 追加指令扩展为下方真实调用链 harness。

## Phase 3 假设排序表（原始排序；最终结果见 Phase 4）

| 排序 | 假设 | 可证伪预测 | 状态 |
| --- | --- | --- | --- |
| 1 | canonical ID 解析入口拒绝保存中的状态，视频未入队 | 若这是原因，仅让解析等待当前保存完成、按原组身份重新取 ID，就应使交错场景由红转绿；解析返回 nil 的那次不会调用 enqueue。 | 最符合最小场景；`ensureLoggedSetID` 的入口只接受 loaded，待 Phase 4 单变量验证。 |
| 2 | 保存返回后 canonical ID 合入 draft 丢失或错位 | 若这是原因，即使保存完成，原组 draft 仍无正确 ID；改成按稳定组身份合入/重取应消除缺口，服务端日志 ID 与 draft ID 会不一致。 | 次优；顺序 canonical ID 测试绿，最小场景无换日/重排，解释力较弱。 |
| 3 | enqueue 后队列持久化或替换覆盖了同组关联 | 若这是原因，入口得到正确 ID 且 enqueue 已成功，但 fetchAll 缺记录或 setLogID 不一致；仅修队列写入/替换即可让回看恢复。 | 较低；独立上传、替换、磁盘恢复、重试路径绿，仍需对红场景边界取证排除。 |
| 4 | 096 presentation 对正确视频做了错误过滤/匹配 | 若这是原因，传给 presentation 的上传成功附件与 draft canonical ID 一致而 row.video 仍空；仅修匹配应使红场景恢复。 | 较低；现有回看映射测试与所有顺序组合绿，待红场景边界取证。 |

以上只针对本地最小复现排序，尚未通过修改实现证实其中任何一个。正确假设栏留待 Phase 4/5；commit message 条件草稿（只有 H1 验证成立后可采用）：`Fix camera video attachment while set persistence is in flight (spec: 027/096)`，正文需写明保存中被误判为无法取得 canonical set ID 的证据。此处不是已证实结论，不执行 commit。

## Phase 1：追加的本地 harness

David 明确要求继续本地验证 (a)–(e)，可用一次性 harness / property loop，在取得红色反馈环后走到 Phase 3 并回报。

保留文件：
- `Modules/StudentKit/Tests/StudentKitTests/Debug/VL05VideoLossHarnessTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Debug/VL05VideoLossHarnessSupport.swift`

批准 seam：真实 `TodayWorkoutViewModel.ensureLoggedSetID` / `commitSet` / `completeCurrentDay`、`VideoUploadManager`、`BackendVideoAttachmentRepository`（磁盘恢复）、`CompletedDayPresentation`。网络与导出边界使用现有测试替身，真实组 ID 不同于本地提议 ID，使用独立临时目录；不触及线上。

| 指定路径 | 实际操作与断言 | 结果 |
| --- | --- | --- |
| (a) 首组无服务端 ID | 让 repository 按契约返回与请求不同的 canonical ID，上传三组、完成当日并 reload；逐行检查视频对应关系 | 顺序路径绿；保存与相机回调交错时红，见下 |
| (b) 末组后立即结算 | 最后一组入队后在 exporter 边界挂起，完成组与当日结算，放行上传，再 reload | 绿，三组视频均保留 |
| (c) 立即中断/冷启动 | 入队、源文件已迁入托管目录、export 未完成时复制磁盘 checkpoint；新 repository / manager 只从副本恢复，原 writer 在原目录结束，不共写 | 绿；另外实跑两个已有后台分片回调恢复测试，也绿。未验证 iOS 真机强杀/锁屏调度 |
| (d) 同组重录/替换 | 分别替换第 1、3 组，检查旧记录移除、新视频占原槽、邻组不变，结算后 reload | 两个参数组合均绿 |
| (e) 弱网重试/终态 | 第 1 组分片失败 1 次后自动重试；失败 6 次进终态后验证文件仍在并手动重试；结算后检查三组 | 两个参数组合均绿；另跑签名过期重传、确定性 4xx 通知测试，均绿 |
| (a/b) 相机回调交错保存 | 选首组或末组作为相机目标，邻组已有视频；暂停目标组保存响应，让相机回调按线上调用顺序解析 ID、入队，再放行保存、结算、reload | 首组得到 `[false,true,true]`；末组得到 `[true,true,false]`；同一场景先放行保存再回调，两个组合均绿 |

红色命令（工作树根目录，测试二进制已由 XcodeBuildMCP 构建）：

```sh
swift test --package-path Modules/StudentKit --skip-build --filter 'VL05VideoLossHarnessTests.cameraReturnOverlappingSetSaveKeepsAllThreeVideos'
```

脱敏输出（exit 1，最后连续 3 次均一致；此前单次与完整组合运行也一致）：

```text
targetRow → 0, overlapsSave → true:
Expectation failed: (rows.map { $0.video != nil } → [false, true, true]) == [true, true, true]
targetRow → 2, overlapsSave → true:
Expectation failed: (rows.map { $0.video != nil } → [true, true, false]) == [true, true, true]
Test cameraReturnOverlappingSetSaveKeepsAllThreeVideos(targetRow:overlapsSave:)
with 4 test cases failed after 0.060 seconds with 2 issues.
```

最后连续三次测试耗时 0.060 / 0.058 / 0.060 秒，命令墙钟 0.460 / 0.434 / 0.442 秒；两个非交错参数组合没有 issue。一次尝试由 Python subprocess 批量重复时遇到 Swift manifest cache 写权限错误，该次没有执行测试，不计入复现次数；后改回直接调用同一已成功运行的命令。

调用链的边界：harness 组合了 `TodayWorkoutView.attachDirectCameraVideo` 使用的真实公开 API，没有调用 iOS-only private SwiftUI 回调本身；没有复制 ID 解析或上传实现。生产回调对拿不到 ID 的分支会移除 sourceURL 并报处理失败（`TodayWorkoutView.swift`），本 harness 只断言最终回看缺口，**未宣称自动验证了录制文件被删除**。能否在学员当时手势、网络时序中触发，仍需真机/事件日志确认。也未证明中间组免疫：本测试按报告选择首/末组，任意未保存的目标组都可能需要同样验证。

## Phase 2：逐项最小化证据

每步只删一个因素，仍运行同名测试，其他输入保持不变：

1. 删除完成后 reload：两个交错用例仍红（日志 `02-50-34-893Z...ee01d3ef.log`）。
2. 删除 completeCurrentDay：仍红（`02-50-50-384Z...bddb0f31.log`）。
3. 删除相邻两组上传：目标组仍无视频（`02-51-15-452Z...faa0c6d4.log`）。
4. 处方缩成一组：交错用例仍红，顺序用例绿（`02-51-37-938Z...b1d7f2e9.log`）。

最终保留独立最小用例 `singleSetCameraReturnDuringSaveKeepsVideo(overlapsSave:)`，并恢复原始三组场景，二者都留在 Debug 目录。必需输入：尚无 canonical ID 的一个真实 draft、处于等待响应的保存、此时到达的相机回调；把等待响应移到回调之前则绿。完成日/冷启动/邻组都不是该本地失败的必要条件。上传与 presentation 留作用户症状断言的观察链。

## 最新验证与交付边界

- 组合运行 11 个测试定义：9 个通过，2 个带参数测试失败，共 3 个断言 issue（首组、末组、最小单组）；Swift Testing 原始末行是 `Test run with 11 tests ... with 3 issues`。MCP 摘要把 issue 数显示成 failed test 数，汇报采用原始结果。
- 最新组合日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-video-lost-d293bfe55635/logs/swift_package_test_2026-11-05T02-53-33-432Z_pid55284_eb8f7da0.log`。
- 新增 harness 编译成功，无新增 warning；两个文件 `swiftlint lint --strict` 和工具链 `swift-format lint --strict` 均通过。初稿的参数顺序/私有访问编译错误已修正，不计作 bug 红色反馈。
- 没有做实现修复，因此未运行修复后的全量 package 测试或应用 build，也未宣称验收通过。红测试有意保留，供下一阶段证伪。
- 未加入 debug 日志，源码通用前缀和本卡专用前缀均无命中。暂存的最小化副本在收尾删除；Debug 测试文件明确标为诊断 harness。
- 线上身份与只读入口已由 David 转要；不重复索要或等待它们才做本地工作。线上事故归因与存量视频找回方案仍依赖这些材料。

## 恢复工作需要的材料

- 受影响学员的非敏感身份定位（student ID 或获准账号标识）、相关计划/训练日标识；凭证只通过现有获准通道提供入口或条目名，不进入对话、文件或日志。
- 确认三个缺口组是否各自录制并点击了「使用」，录制与回看的大致时间、时区、设备型号、iOS 与实际 App build。
- 带时间戳的原始录屏或脱敏设备/请求日志，尤其对应三个缺口与一个正常组的记录；仓中只有文字转述。
- 线上只读查询权限已由本任务授予，不重复申请；仍需明确目标账号和可用查询入口。所需证据是相关训练记录、视频列表与上传记录之间的对应关系，查询限定该学员和事件时间窗。
- 如有本机上传队列及文件存在性清单，可用作离线回放输入；不清理、不补写这些数据。

## 停工清理与存量数据

- 没有引入 debug 日志；诊断 harness 保留在明确标识的 `StudentKitTests/Debug/`，最小化暂存副本已删除。源码扫描 `grep -R -n -F '[DEBUG-' Modules MeetPR --include='*.swift'` 无输出，exit 1（0 命中）。本卡专用前缀亦为 0。
- 本轮未安装、启动或操作模拟器 App。XcodeBuildMCP 清单显示 iPhone 17e（iOS 26.5）原已开机。
- 两轮收尾均按指令执行 `xcrun simctl shutdown 5D5FA360-BA49-48C6-A887-2F0D22F89749`，均 exit 1：`CoreSimulatorService connection became invalid` / `Operation not permitted` / `Unable to locate device set`。不能声称已关机；需 David 在可访问 CoreSimulator 的终端执行同一命令。没有改用其他模拟器或 shutdown all。
- 无线上数据写入，无升级迁移；只写独立临时测试 fixture。事故视频是否仍在服务端或本机未知，尚无证据形成具体找回/回填方案。

## Phase 4：单变量取证与证伪（续作）

按 H1→H2→H3→H4 顺序，每次只在同一最小测试加入一个观察点，运行后撤掉再加入下一个；生产实现此时未改。观察日志使用任务规定的前缀，收尾已从测试删除。

| 顺序 | 单一观察/对照 | 交错结果（顺序对照） | 判定 |
| --- | --- | --- | --- |
| H1 | ID 解析返回值 | `resolved=false`（`true`） | 支持：相机回调立即得到 nil。 |
| H2 | 保存完成后 draft ID 与 repository canonical ID 比较 | `canonicalMatches=true`（`true`） | 排除本次复现的合入丢失/错位解释。 |
| H3 | 边界处队列记录数、上传初始化调用数 | `queued=0 initiate=0`（`1,1`） | 排除本次复现的入队后覆盖；视频根本未入队。 |
| H4 | 在原红断言之后，仅补一个真实队列上传成功的 canonical 附件，再走原 presentation | `validAttachmentPlayable=true`（`true`） | 排除本次复现的回看过滤错误。原缺口断言仍红。 |

日志均位于 `~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-video-lost-d293bfe55635/logs/`：依次为 `swift_package_test_2026-11-05T02-59-06-028Z_pid55284_d194fd9c.log`、`02-59-29-426Z_pid55284_da956a01.log`、`02-59-52-555Z_pid55284_9d794bfc.log`、`03-00-22-672Z_pid55284_3018de78.log`（后三项文件名前缀同第一项）。完成判据：四项预测均有实跑边界证据；H1 待修复单变量转绿作最终验证。未将本地结果冒充线上三次事故的实证。

## Phase 5：正式回归先红后绿

正式 seam：真实 `TodayWorkoutViewModel` 的保存/ID 解析，接真实上传 manager 与 096 presentation；只有网络 repository、导出/上传服务使用测试替身。文件位于 `Tests/StudentKitTests/Features/TodayWorkout/`，不在 Debug 目录，名称不含任务代号：

- `CameraReturnDuringPersistenceTests.singleSetCameraReturnDuringSaveKeepsVideo`：最小一组，两种时序。
- `CameraReturnDuringPersistenceTests.cameraReturnOverlappingSetSaveKeepsAllThreeVideos`：首/末组 × 交错/顺序，保存 canonical ID 与完成状态，完成当日并 reload 后检查全部播放入口。
- `CameraPersistenceFixture.swift`：受控服务器响应 gate，返回不同于本地提议 ID 的 canonical ID。

先在未修实现上运行 `swift test --package-path Modules/StudentKit --filter CameraReturnDuringPersistenceTests`（通过 XcodeBuildMCP 执行）：两项测试共 3 个 issue，分别是最小单组缺视频、首组缺视频、末组缺视频；编译通过。红日志 `swift_package_test_2026-11-05T03-05-10-304Z_pid55284_9cff2b1c.log`。

实现只改 `ensureLoggedSetID`：允许从保存中 drafts 捕获稳定组身份；将解析操作排入现有 pendingPersist 链，等待前项完成后按身份重读 canonical ID；若仍需新建则保留最新 completed/failed 状态；检查 load generation，避免换日/重新加载后把结果交给别的组。未改上传队列、服务端关联或回看匹配。

改后正式测试 + 全部诊断 harness + 既有反向交错/重载测试合计 11 个测试定义全部绿，日志 `swift_package_test_2026-11-05T03-05-41-752Z_pid55284_a975ccdb.log`。原 Phase 1 命令原样重跑 exit 0：

```text
swift test --package-path Modules/StudentKit --skip-build --filter 'VL05VideoLossHarnessTests.cameraReturnOverlappingSetSaveKeepsAllThreeVideos'
✔ Test cameraReturnOverlappingSetSaveKeepsAllThreeVideos(targetRow:overlapsSave:) with 4 test cases passed after 0.069 seconds.
✔ Test run with 1 test in 1 suite passed after 0.070 seconds.
```

两个首组事故共享同一种组序场景、末组事故对应第三组场景；这是结构等价回放，不是三个线上账号/动作的真实数据回放。完成判据：正式测试已观察红→单一实现入口变更→绿；原环绿。随后删除两份一次性 Debug harness，最终复跑命令改用正式 suite，不能在删除后把旧名字的零匹配误报成通过。

正确假设 **H1 成立（本地复现）**。根因：相机回调与组保存交错时，ID 解析只接受 loaded 状态，把正在保存误判为无法取得组 ID，导致视频在入队前走失败清理。

供收货者使用的 commit message 草稿（不执行 commit）：

```text
Fix camera video loss during in-flight set persistence (spec: 027/096)

The canonical-ID resolver rejected recording state while a set save was
awaiting its response. The camera callback then skipped enqueue and tried
to remove the recording. Serialize ID resolution with set persistence,
re-read the stable target and canonical ID, and reject stale load generations.

Regression: single-set and first/last-set camera return overlap, followed
by completed-day playback; observed red before the fix and green after it.
```

## 存量视频去向与升级后的恢复边界

**本竞态的路径是「从未入队 + 调用方尝试删除本机源文件」；不是「上传成功挂空组」**。取证的上传初始化请求数为 0；`TodayWorkoutView.attachDirectCameraVideo` 取得 nil 后执行 `try? removeItem(sourceURL)` 并提示处理失败。删除失败被忽略，因此只能确定执行删除尝试；本 package harness 没有运行 iOS-only private SwiftUI 回调，不能声称实测了学员手机的文件删除结果。`VideoUploadManager.enqueue` 未调用，没有托管队列 JSON、组关联或托管源副本，也没有由这次调用新建的服务端附件/OSS 对象。

相机 `CameraRecorderView.useRecording` 在回调前会按偏好保存到系统相册；`saveToPhotoLibrary` 默认 true，但权限拒绝/保存失败/用户关闭均可能使它没有副本。之后 controller 交出 review 文件所有权。因此：

| 实际存量 | 升级后能否自动找回 | 只出方案的处理方式 |
| --- | --- | --- |
| 本竞态源文件已删除，相册也无副本 | 不能；修复仅预防新增丢失 | 先核对相册/用户已有备份；没有字节副本就不能恢复，禁止承诺云端可找回。 |
| 相册有已保存副本 | 不自动关联 | 用户按录制时间/内容确认对应训练日与组，再使用获准上传入口或另行安排定向恢复；不根据时间盲猜、不承诺当前已完成日 UI 提供补传。 |
| 删除失败，临时源文件尚在，但无队列记录 | 不自动关联 | 保留文件，先只读收集文件存在性/时长/时间；结合录屏与用户确认建立唯一组映射，再出恢复作业。当前补丁未添加无主文件扫描/迁移。 |
| 有有效 canonical setLogID 的持久化 pending/uploading 记录与本地文件 | 既有恢复流程可自动续传；不是本竞态新增的数据 | 保留 JSON 与文件，不清缓存；原磁盘 checkpoint 恢复测试已绿。终态 failed 走既有手动 retry；源文件缺失不能凭记录恢复内容。 |
| 服务端 ready 附件为空/错组，OSS 内容仍在 | 本补丁不会自动回填 | 属于另外的待查数据现象，按下方只读查询与经批准的回填方案处理。 |

不能把以上路径直接套到三条线上缺口；需要 David 正在获取的账号、事件时间、只读入口以及相册/本机队列存在性证据。

## 服务端只读查询与回填方案（均未执行）

只读参考 backend 本地 HEAD `1e494dbd46952ffcb6a07577a12133efaed7e917`，不是已部署版本证明。`uploads/index.ts` 对传入的 set_log_id 校验所属学员，不存在/不属于该学员则返回 404；iOS pipeline 明确传 setLogID，filename 包含 setlog ID 与本地 attachment ID。`videos.ts` 的视频墙只返回 ready、最多最新 100 条，教练视角另有 provenance 过滤，不能以列表没出现就断言服务端不存在。

取得入口后，先核对实际 schema/部署 SHA，在只读事务中用绑定参数（学员 UUID、带时区的时间窗；日志只有脱敏元数据）执行：

```sql
BEGIN READ ONLY;
-- 先枚举训练日的所有组，确认 set_index 的零基语义和 canonical IDs。
SELECT sl.id, sl.plan_exercise_id, sl.exercise_id, sl.set_index,
       sl.logged_date, sl.logged_at, sl.completed, sl.weight_kg, sl.reps
FROM set_logs sl
WHERE sl.student_id = $1::uuid
  AND sl.logged_date IN (DATE '2026-11-01', DATE '2026-11-03', DATE '2026-11-04')
ORDER BY sl.logged_date, sl.plan_exercise_id, sl.set_index;
-- 查该学员时间窗内所有 set_video，包括空关联、错关联与非 ready。
SELECT a.id, a.status, a.set_log_id, a.filename, a.created_at, a.updated_at,
       a.source_plan_id, a.source_coach_id, a.is_unlinked_explicit,
       a.size_bytes, a.actual_size_bytes,
       sl.student_id AS linked_student_id, sl.plan_exercise_id,
       sl.exercise_id, sl.set_index, sl.logged_date
FROM attachments a
LEFT JOIN set_logs sl ON sl.id = a.set_log_id
WHERE a.owner_id = $1::uuid AND a.kind = 'set_video'
  AND a.created_at >= $2::timestamptz AND a.created_at < $3::timestamptz
ORDER BY a.created_at, a.id;
ROLLBACK;
```

时间窗需覆盖实际录制至重试完成，不能仅限训练日零点；如有候选 filename/attachment ID，进一步按 ID 查时间窗外记录。对候选对象只做获准的 OSS HEAD（存在性、大小、元数据），不删除、不完成 multipart、不输出签名 URL 或密钥。空 set_log_id 本身不能证明是本 bug；显式不关联上传、历史 detach、错误关联都需分别核实。

回填作业提案：先建立 `attachment ID → 当前关联 → 目标 canonical set ID → 证据` 清单，验证 owner、日期、动作、组序、内容和不可变 provenance；filename 仅作线索。对唯一且经用户确认的映射备份受影响行，另行审批后用事务与旧值/updated_at 条件保护执行最小关联修正，逐行核对影响数；保留 source_plan_id/source_coach_id，不将未知或跨 provenance 视频放宽为显式无关联。原目标已有视频则先人工解决冲突，不能覆盖或删对象。随后验证学员回看/教练授权范围，回滚使用备份原关联。uploading/failed 对象另查 multipart/完成状态，不能直接把 status 改 ready。**本任务未执行任何线上查询或回填，也未改后端文件。**

## Android 只读对照

检查 `~/Projects/apps/meetpr-rn` HEAD `30c60d6005acbe65c87fd347d4a4c4116cfdc288`。`TodayWorkoutView.tsx` 的相机 ensureSetLog 走 `commit(attachmentOnly: true)`，commit 通过 `serial-task-queue.ts` 的 Promise tail 排队，并按 stableSetId 查 liveDrafts；未见 iOS 这种仅因全局保存中就立即返回空 ID 的入口。`VideoAttachmentControls.tsx` 的 onUse 交给 upload manager，`video-upload/manager.ts` 先 retainVideoSource、落持久化记录，再执行 ensureSetLog；失败进入 waiting/terminal 并 flush，catch 分支未删源文件。因此没有发现**同一条**「保存中拒绝 ID → 未入队就删录制」竞态。结论只来自静态只读调用链，不等于 Android 全链路无竞态；未运行 Android 测试、未修改该仓。


## Phase 6：最终检查与收尾

- 原始复现已转绿；Debug 目录两份一次性 harness 已删除。正式回归是 `CameraReturnDuringPersistenceTests`，对应源码和测试共 3 个文件，生产改动只有一个方法。
- **StudentKit 全量**：XcodeBuildMCP `swift_package_test` 无 filter，原始日志末行 `Test run with 1099 tests in 55 suites passed after 3.953 seconds.`；含编译约 30.4 秒。日志 `swift_package_test_2026-11-05T03-06-53-687Z_pid55284_5a6a885e.log`。20 类 warning 来自既有测试中的并发/多余 try 等；变更文件无新增 warning，不扩大修复范围。
- **应用 build**：MeetPR / Debug / iOS Simulator，目的地 iPhone 17e `5D5FA360-BA49-48C6-A887-2F0D22F89749`，iOS 26.5；`BUILD SUCCEEDED`，77.7 秒，工具未报告 warning。日志 `build_sim_2026-11-05T03-07-24-093Z_pid55284_560f2422.log`。仅 compile-only，没有启动/安装 App，也没有使用其他模拟器。
- 三个 Swift 文件 `swiftlint lint --strict`：0 violations；工具链 `swift-format lint --strict`：exit 0；`git diff --check`：exit 0。
- `grep -R -n '\[DEBUG-' Modules MeetPR --include='*.swift'`：无输出、0 命中；另独立扫描 StudentKit/Sources 与 MeetPR 同样无输出、exit 1。扫描涵盖业务与测试源码；任务卡/历史取证文档中保留前缀文字，不是运行日志，未为凑全仓文字零命中改写原卡。
- 已按指令执行 `xcrun simctl shutdown 5D5FA360-BA49-48C6-A887-2F0D22F89749`，exit 1，`CoreSimulatorService connection became invalid` / `Operation not permitted` / `Unable to locate device set`。David 已告知上一轮宿主关机；本轮仅构建，仍不能据本次失败命令独立确认最终设备状态。没有绕过权限或改用其他机型。
- 固定基准 `09eef51d84c3ae253eabcf1be8e5664cc0b6a777`；commit 区间为空，审查对象为未提交业务 diff + 新测试全文。code-review 技能要求的两位只读 reviewer 分别报告如下；主代理为唯一写者。

### Standards

0 项违规，0 个 blocker。符合 Swift Testing、MainActor 隔离、Repository 边界及单模块范围要求。ID 解析先占保存队列再读取 draft，没有自等待；稳定组 ID 与 load generation 防止串组。测试有受控挂起点，不依赖固定延时制造竞态；少量测试步骤重复用于展示不同复现范围，不构成阻断问题。

### Spec

0 项发现。满足正式红测试→修复→转绿，覆盖单组/首末组交错、上传、结算与回看；无越界。存量说明区分未入队/尝试删源文件与服务端孤儿，且保留线上未归因边界；只读查询、待批准回填、Android 静态对照与代码一致。

两轴结论：Standards 0、Spec 0，各自无严重项。reviewer 未重跑测试/构建，结果由主代理实跑提供。仓缺 `docs/agents/issue-tracker.md`，已按技能提示后续可运行 `/setup-matt-pocock-skills`；本卡直接文件足以作为此次 Spec 来源，未因此阻断排障。

交付保留项：David 补正在获取的学员/训练日定位、带时间戳日志及可用只读入口，并核对相册副本与本机文件/队列存在性；这是线上事故归因及定向恢复所需，不影响本地修复验证。当前没有已批准或已执行的数据回填。无 commit、无 push、无新依赖，无 backend/Android 写入。

## 返修第 1 轮：nil → 删源文件是丢视频的放大器

David 的 Spec 轴返修指出前轮只修了触发竞态，没有消除破坏性失败分支。本轮按新增的 P0 红线继续：组保存失败、超时、校验失败、换日代次失效等导致 nil 时，必须保留录好的视频，并可在正确组获得 canonical ID 后继续上传。前轮“两轴无发现”仅记录当轮审查结果，不代表本轮指出的缺口不存在。

### 先红证据与 seam

沿用 `CameraReturnDuringPersistenceTests` 的真实 workout + 上传 manager seam，将两个调用方原有的“解析 ID → nil 删源文件 → attach”共同交接逻辑移到 `VideoAttachmentViewModel.attach(sourceURL:draftID:studentID:trainingDate:resolveSetLogID:)` 作为可测试入口。先保留旧的 nil 删除行为运行测试，再改为持久挂起；最终两处 UI 都调用该入口，不再各自持有删除分支。

新增指定回归：

1. `cameraReturnDuringOfflineSaveRetainsVideoUntilSetIsSaved`：真实仓储记录调用返回断网错误；相机回传后断言源文件仍在且有附件记录，再恢复网络、保存组、触发同一恢复入口，断言上传记录关联该组 canonical ID、回看可播。
2. `cameraReturnAcrossDayChangeRetainsVideoUntilOriginalDayReturns`：保存响应挂起，切换到另一训练日使 generation 失效，再放行响应；断言文件/记录保留、不挂到另一日，回到原日后绑定原组并上传。

红命令（由 XcodeBuildMCP 执行）：

```sh
swift test --package-path Modules/StudentKit --filter 'cameraReturnDuringOfflineSave|cameraReturnAcrossDayChange'
```

修前脱敏输出：两项各有两个 issue，共 4 个，编译通过：

```text
cameraReturnDuringOfflineSaveRetainsVideoUntilSetIsSaved:
  fileExists(source) == false
  attachments.count == 0 (expected 1)
cameraReturnAcrossDayChangeRetainsVideoUntilOriginalDayReturns:
  fileExists(source) == false
  attachments.count == 0 (expected 1)
```

对应原始输出存于 `swift_package_test_parser-debug_2026-11-05T03-16-05-223Z_pid55284_fa41e818.log`（同前述 XcodeBuildMCP logs 目录；仅工具生成的测试日志，不在源码中增加 debug 输出）。初步修复后两项保留断言通过：`swift_package_test_2026-11-05T03-19-10-595Z_pid55284_c8c09438.log`。补齐保存成功/回原日后的关联与回看断言，整个 suite 四项通过：`03-20-31-038Z_pid55284_b7dc9e9d.log`。

### 实现与数据边界

- `VideoAttachment` 增加可选 `pendingDraftID`，旧 JSON 无该字段仍解码为 nil；与既有 trainingDate 一起标识原组。pending 时 setLogID 只是本地 row key，不作为服务端 ID 使用。
- `VideoUploadManager+PendingSet` 先复制源文件到现有托管 source 目录，再写现有附件 JSON；此时不发上传请求。即使复制/写盘失败，也不删除调用方的原文件。记录以现有 failed 态呈现；待关联记录排除自动容量/日期清理、普通 retry 和上传执行入口，防止将本地 key 发给服务端或清理唯一托管副本。
- 保存成功/重新加载原日时，通过稳定 draft ID + 原训练日（scheduledDate，而非可被顺延改变的展示日期）取得 canonical ID，更新同一持久附件记录后进入既有导出/上传流程。失败重试按钮先重新解析该组 ID。不会根据数组下标给另一天的组挂视频。
- 相机展示时捕获完整目标身份，回调不再依赖会在 dismiss 时被清空的 optional target。SetEntrySheet/VideoAttachmentSection 使用同一交接入口，并显示挂起记录的现有失败/重试控件；详情编辑同步也先按身份核对当前行，避免换日后向旧下标写数值。
- 挂起选择和绑定的短本地操作串行，避免旧回调在 repository await 期间删除新选择；仅在新 take 已持久绑定后沿用既有“同组替换”规则清理前一 take。保留原始临时文件副本，不再以“tmp 会泄漏”为由在 nil 分支删除录像。
- BackendVideoAttachmentRepository 的缓存更新移到原子写入成功之后，避免写盘失败却把尚未落盘的绑定当作持久成功。没有改服务端 schema、线上关联或对象存储，没有新增依赖或另一套上传器。

冷启动补充回归 `pendingCameraVideoSurvivesRestartAndRetentionBeforeBinding`：新建真正磁盘 repository/manager，读取前实例写入的 JSON；模拟原始临时文件消失并将时钟推进 90 天，恢复启动后逐字节核对托管源仍在，确认普通 retry 不会发起无 ID 上传，再保存目标组、挂回并上传成功。与原两项及前轮两项合计 5 个测试定义通过，日志 `swift_package_test_2026-11-05T03-22-28-945Z_pid55284_aed7ea5b.log`。这是磁盘重建恢复测试，不声称执行了 iOS 真机强杀。

### 全仓删除路径核查

搜索全仓 Swift 的 ensureLoggedSetID / resolveSetLogID 及 removeItem 调用链：原有三处入口（TodayWorkoutView 的 target 缺失、该视图解析 ID 失败、VideoAttachmentSection 解析 ID 失败）均已消除因无组 ID 删除录像的行为。其他删除位于用户主动取消/删除/替换、裁剪产物交接、未接受录制的相机生命周期清理和已有 canonical ID 后的上传文件管理，不是 nil 组 ID 路径；未做无关重构。挂起记录的主动删除仍只由用户现有删除按钮触发。

历史损失边界不变：本次升级能恢复**新版本已经持久挂起的**记录，不能重建旧版本已删除且无任何副本的视频。旧版残留无主文件没有可验证的 draft/date 记录，仍按前轮只读核查及人工确认方案处理，不盲猜关联。完全无法写盘（空间不足/文件系统错误）时任何应用都无法保证新持久记录落盘，本实现至少不删除原文件并显示处理失败；不把这个边界伪装成已成功保留。

### 本轮独立复审与定向返修

Standards 首轮报告 P1：绑定的 repository await 与用户删除可能交错，旧快照重建已删除记录；另有 P2：成功交接后仍留下额外临时副本。Spec 首轮报告 P2：补充组冷启动从服务器重建后 draft ID 变为 canonical ID，原挂起记录无法匹配。

分别处理并复核：

- **绑定/删除**：先新增 `deletingDuringPendingVideoBindingDoesNotReviveUpload`，受控暂停绑定写入、删除记录、再放行旧写入，观察到记录复活的红断言（`swift_package_test_2026-11-05T03-30-18-627Z_pid55284_e39689f3.log`）。修复让 remove 在首个 await 前记录删除意图，等待在途绑定写完成后再删除；绑定各挂起点检查删除标记与 generation；绑定内部清理旧 take 不等待自身队列。修后测试按新契约在“删除意图已登记”处放行写入，再等待二者结束，断言记录不存在、无上传初始化。初次测试替身漏实现协议方法的编译失败不计红证据。
- **临时副本**：只有 canonical 绑定成功、托管源与记录均已接管后才释放 caller 的临时副本；nil/持久化失败时保留原副本。新增 `successfulCameraHandoffReleasesOnlyTemporaryCopy`，验证临时副本释放后托管视频仍正常上传并可用。前文“保留原始临时副本”特指失败/尚未取得 ID 的路径，不能理解为所有成功上传永不清 tmp。
- **补充组身份**：可选 `pendingSetSlot(planExerciseID,setIndex)` 只为补充组提供重载 fallback，同时仍受学员与原 scheduledDate 限定；处方组继续按 draft ID。新增 `extraSetCameraVideoRebindsAfterDraftIdentityChangesOnReload`，用新 workout 实例从服务端记录重建补充组，观察到待关联字段未清、canonical ID 不正确两项红断言（`03-32-09-467Z_pid55284_6ee48f75.log`），修后挂起失败态可见且成功关联。首次仅用同一实例换日仍保留了内存 draft cache，只有“ID 应变化”的测试设定失败，不计为 bug 证据。

上述三项和先前回归组合共 7 项通过（`03-33-18-327Z_pid55284_e68fcd47.log`），之后又加入成功临时副本清理测试并纳入最终全量。独立 reviewer 二次复核：**Standards CONCEDE / CLEAN，剩余 0；Spec CONCEDE，剩余 0**。没有把两轴结论合并成替代用户收货的发布授权。

冷启动恢复限制：若组已保存，含补充组，返回原训练日可自动挂回；若补充组本身从未成功保存且冷启动后训练行也不存在，本补丁仍保留源文件、持久记录、原 draft/date 与补充组槽信息，但不自动制造训练日志或猜测丢失的重量/次数。完整恢复这类未保存训练行需要持久化整个编辑草稿，超出本轮最小视频修复；按 David 允许的最低边界保留文件/记录，后续根据原组上下文定向恢复，不清掉这些记录。

### 本轮最终验证

- StudentKit 全量 **1105 tests passed，0 failed**；日志 `swift_package_test_2026-11-05T03-36-49-190Z_pid55284_329833cb.log`，含编译约 16 秒。
- CoreModels 全量 **164 tests passed，0 failed**；日志 `swift_package_test_2026-11-05T03-36-47-136Z_pid55284_8ba94a86.log`。
- MeetPR / Debug / iPhone 17e / iOS 26.5 应用 **BUILD SUCCEEDED**；日志 `build_sim_2026-11-05T03-36-25-808Z_pid55284_6370da41.log`，约 21 秒；仅构建，未安装或启动 App。
- 19 个本卡 Swift 文件 swiftlint strict、swift-format strict 均 exit 0；git diff --check 通过。未改动的既有测试仍有此前记录的并发等编译 warning，未扩大处理。
- `grep -R -n '\[DEBUG-' Modules MeetPR --include='*.swift'` 无输出，源码/测试 **0 命中**；未为删除文档引用而修改原任务卡。
- 收尾再次运行 `xcrun simctl shutdown 5D5FA360-BA49-48C6-A887-2F0D22F89749`，exit 1，CoreSimulatorService connection invalid / Operation not permitted。无法独立确认关机，UDID 保留给宿主检查；没有换用其他模拟器或绕过权限。
- 无 commit/push；原基线和分支不变；后端、安卓和线上数据均未写入。下方是本卡当前累计文件清单，包含前轮测试/业务改动。

本轮更新的 commit message 草稿（不执行）：

```text
Preserve captured videos until their workout set can be linked (spec: 027/096)

A nil canonical set ID was amplified into data loss by deleting the camera
or imported source. Persist the recording and draft/day identity first,
keep unresolved records out of upload and retention cleanup, and bind them
after a successful save or reload. Preserve extra-set slot identity across
restart and serialize deletion against pending binding writes.

Regression: offline save, day-generation change, disk restart/retention,
extra-set identity restoration, concurrent deletion, and successful handoff.
```

### 当前累计 Swift 文件清单

- [VideoAttachment.swift](../../Modules/CoreModels/Sources/CoreModels/Entities/Plan/VideoAttachment.swift)
- [SetEntrySheet.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/SetEntrySheet.swift)
- [TodayWorkoutPresentation.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutPresentation.swift)
- [TodayWorkoutTypes.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutTypes.swift)
- [TodayWorkoutView.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift)
- [TodayWorkoutViewModel.swift](../../Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel.swift)
- [VideoAttachmentSection.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentSection.swift)
- [VideoAttachmentViewModel.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentViewModel.swift)
- [VideoUploadManager+Cleanup.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadManager+Cleanup.swift)
- [VideoUploadManager+Pipeline.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadManager+Pipeline.swift)
- [VideoUploadManager+Restore.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadManager+Restore.swift)
- [VideoUploadManager+Retry.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadManager+Retry.swift)
- [VideoUploadManager.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadManager.swift)
- [BackendVideoAttachmentRepository.swift](../../Modules/StudentKit/Sources/StudentKit/Repository/BackendVideoAttachmentRepository.swift)
- [VideoAttachmentViewModel+PendingSet.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentViewModel+PendingSet.swift)
- [VideoUploadManager+PendingSet.swift](../../Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadManager+PendingSet.swift)
- [CameraPersistenceFixture.swift](../../Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/CameraPersistenceFixture.swift)
- [CameraReturnDuringPersistenceTests.swift](../../Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/CameraReturnDuringPersistenceTests.swift)
- [PendingVideoBindingTests.swift](../../Modules/StudentKit/Tests/StudentKitTests/Features/VideoUpload/PendingVideoBindingTests.swift)

排障文档：本 JOURNAL 与 `docs/diagnose/set-video-lost-2026-11-05-phase1.md` 索引；原任务卡未修改。
