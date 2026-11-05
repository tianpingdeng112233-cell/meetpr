# 102 · 卡 B（iOS）— 打勾先变绿：组记录本机排队、后台同步

先读仓根 `CONTEXT.md`、`CLAUDE.md`、`AGENTS.md`，再完整读 `specs/102-offline-set-sync/SPEC.md`（含末尾「屏幕稿」节），它是唯一的验收口径，本卡只补执行细节。分支 `feat/102-offline-set-sync-ios`，worktree `MeetPR-wt-102`。本分支叠在视频 P0 修复 meetpr#403（`diagnose/set-video-lost-20261105`）之上，已合入最新 `release/1.0`。安卓有一张镜像卡（卡 A）同批在做，两端的行为、时长（20 秒）和文案必须一致。

## 为什么一张卡
同步队列、叠加显示、长按完成前的同步与失败态、退出弹窗都在 StudentKit 今日训练这一块，拆开验不了「点了就算数」这件事，所以合成一次交付。

## 目标（对应 SPEC 各节）
1. **同步队列**（§1、§6）：在 StudentKit 里新建一个与界面无关的队列（Repository 层，按用户 id 分开落盘，杀 app 后能恢复；持久化方式选仓内已有的，不要引入 SwiftData，ADR-009 只允许 CoachKit 草稿用它）。范围是 SPEC §1.1 列出的全部入口：主项和变式的 `SetEntrySheet.save` → `commitSet`（立即关页），辅助项、不定重量和学员自加的 `saveAccessoryRow` / `completeAccessoryRows` / `persistAdded` / 删自加组等。这些操作都改成先入队、立即更新 `state`，再由队列按顺序发送。去掉 `accessorySavingIDs` / `accessoryBatchInFlight` 对其他组和「全部按计划完成」的禁用，也去掉失败回滚。
2. **复用 #403**：#403 已经把 `ensureLoggedSetID` 排到保存队列之后、按 draft 身份取 id，并新增「拿不到组 id 时视频持久挂起、组保存后自动挂上」（`VideoUploadManager+PendingSet` / `VideoAttachmentViewModel+PendingSet`）。§2.7「待同步的组也能拍视频」**必须复用这套挂起逻辑**，不要另写一套；你的队列在组同步成功、拿到服务端 id 时触发它挂上。
3. **失败策略**：网络错误、超时、5xx 退避重试，网络恢复时立即重试（`NWPathMonitor` 或仓内已有的网络状态来源）。不可重试的 4xx 标记为「没传上」并停止自动重试。**不回滚界面**，不弹 `actionErrorMessage`，训练过程中**不显示任何同步提示**。
4. **叠加显示**（§6）：写一个纯函数「服务器快照 + 队列 → drafts」，`load` / `refreshCurrentPlan` / `applyPlan` 的数据都要经过它。刷新、切 tab、冷启动后已勾的组不能变回没勾。
5. **长按完成**（§2）：改 `completeCurrentDay` / `completeDay(presentsCelebration:)` 一带。长按后如果队列里还有这天的记录，立即插队发送，按钮原位显示「正在同步训练记录…」（稿 ①）。同步完成后照常出奖励（`completionPhase = .celebration`），再调完成接口。队列本来就空则直接出奖励，不要闪同步状态。**20 秒**没同步完，或者遇到 4xx，就进入失败态（稿 ②）：橙色提示块加「重试」按钮，不出奖励，也不调完成接口。点「重试」重新计时；离开页面再回来，按钮恢复为长按。
6. **完成闸门**：写成独立类型，输入是「这天的组是否全部同步」，并为 spec 101 预留「视频是否全部送达」输入（101 还没实装，现在恒为真；101 的 iOS 卡会接这个输入），**不要把闸门写死在 ViewModel 里**。闸门状态要落盘，杀进程后能恢复。完成后仍走现有 `FlexibleTrainingDay.canWrite` 语义，组全部同步之前不能让当天进入已完成。
7. **计划动作被删**（§3）：发送时后端表示计划动作不存在（实测返回码写进 JOURNAL），就改按 092 自加动作写入这一天，用原来的 `exercise_id`，数据原样保留。
8. **退出登录**（§5，稿 ③）：学员端退出入口（`Session.logout` 的调用方）在队列非空时弹窗。「先上传再退出」时立即发送并显示进度，清空后再 logout，传不完时可以取消。「直接退出」时队列留在本机。换账号登录时只读当前账号自己的队列。
9. **文案**：进 StudentKit `Localizable.xcstrings`（简中、英文），繁体走仓内现有生成流程。文案以 SPEC「文案」表为准。

## 定稿结构
照 SPEC「屏幕稿」节执行，色值、字号取 DesignSystem token，不硬编码。失败色用 101 同款橙色。深浅色两套都要有。没有动画（遵守动效口径，装饰动效全删）。

## 约束
- 纯客户端：不改后端，不改 API 协议。确实需要改后端时停下来写进 JOURNAL，不要自己扩范围。
- 补记（081 `QuickLogSheet`）、身体状态、聊天不进队列。
- 网络正常时，服务器最终数据必须与改动前同样操作的结果一致。
- 不改 #403 已有的行为与测试；冲突或需要调整时写进 JOURNAL。
- swiftlint `--strict`、swift-format lint 通过。不 commit、不 push、不开 PR、不新增 SPM 依赖。
- 模拟器只用 `iPhone 17e`，严禁新建或改用其它机型。

## 测试 seam（先红后绿，红必须实际跑出来；Swift Testing）
1. 队列单测（主力）：注入发送函数、时钟、网络状态、存储。覆盖：按序发送；失败重试不回滚；同一组多次改以最后一次为准；4xx 标记没传上并停止；「立即发送」插队；按用户隔离；从存储重建。
2. 叠加纯函数单测：勾选、取消勾选、改数、刷新后不回退。
3. 完成流程单测（注入时钟）：队列空时直接奖励；20 秒内同步完时先同步后奖励；超过 20 秒或遇 4xx 进失败态，不奖励、不调完成；重试重新计时；完成接口只调一次；视频条件为假时不调完成。
4. `TodayWorkoutViewModel` 层（复用现有 repository 注入）：请求挂起时 `saveAccessoryRow` 立即返回且 drafts 已更新、其他行可写；请求挂起时 `commitSet` 立即返回 true。
5. 组同步成功后，#403 的挂起视频被挂上（一条集成式单测即可）。
6. 计划动作不存在时改写自加：在发送层注入错误。
7. StudentKit 全量 `swift test`（XcodeBuildMCP `swift_package_test`）全绿；MeetPR Debug 在 `iPhone 17e` 构建成功。

## 交付
写 `docs/journal/2026-11-05-102-card-b.md`（一卡一文件）：改动文件、红 → 绿证据（命令 + 数字）、全量测试与构建结果、§3 计划动作不存在时后端的实际返回码、闸门对 101 预留的接口签名、与 #403 的衔接点、与 SPEC 不一致或拿不准的地方。
