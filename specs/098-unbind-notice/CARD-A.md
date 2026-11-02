# 098 · 卡 A（iOS）— 被教练解绑后，绑定页说明原因

先读仓根 `CONTEXT.md`（有则读）、`CLAUDE.md`、`AGENTS.md`，再完整读 `specs/098-unbind-notice/SPEC.md`——它是唯一验收口径，本卡只补执行细节。分支 `feat/098-unbind-notice`（基于 `origin/release/1.0`），worktree `MeetPR-wt-098`。安卓 RN 同批另有一张镜像卡，两端文案与判定必须一致。

**分支说明（必读）**：本次是 Claude 派的任务卡，走 feature 分支 + PR（base = 发版线 `release/1.0`），**不是** `AGENTS.md` §发版直推流 说的「David 直驱小修」，所以那节的开工自检（当前分支必须是发版线）不适用，就在当前分支 `feat/098-unbind-notice` 实装；发版线被别的 worktree 占着，物理上也切不过去。直推流里与分支无关的纪律（lint / 模拟器）照守；`docs/CODEX-JOURNAL.md`、`NEXT-RELEASE.md`、`PARITY` 类台账不由你写。

## 为什么一张卡
模型加一个可选字段 + 绑定关卡 notice 映射加一个分支 + 三语文案，同一模块，一次验收。

## 目标
1. `Modules/CoreModels/.../Entities/Bind/BindRequest.swift`：加 `endedAt: Date?`（JSON `ended_at`，缺省 nil），解码沿用现有日期策略；旧后端不带此字段时解码照常。`BindRequestStatus` 枚举**不加**新值（后端对外只吐 `cancelled`）。
2. `Modules/StudentKit/.../Features/Bind/BindGateViewModel.swift`：`BindNotice` 加一个解绑 case（携带教练显示名）；`notice(for:)` 现只收 status，改为能拿到整条最近申请——`status == .cancelled && endedAt != nil` → 解绑提示；其余映射不变。两处调用点（约第 222、276 行）同步改。
3. 提示两行：第一行「{教练显示名}已与你解绑」（`coachDisplayName` 为 nil / 空白 → 「教练已与你解绑」），第二行「训练记录都还在，输入邀请码可重新绑定」。英文「{coach} has unlinked you」/「Your coach has unlinked you」+「Your training history is kept. Enter an invite code to link again.」。与 rejected / expired 同位置同样式；若现有 notice 视图只排一行，用最小改动支持两行（同一提示块内换行），不新增样式。
4. 文案进 `StudentStrings` 现有 key 体系（简中 + 英文手写），繁体用 `scripts/generate-zh-hant.py` 生成，不手写。
5. 普通 cancelled（`endedAt == nil`）不显示提示——行为与现在一致。
6. SPEC 变更第 3 条（已填过入学问卷时重新输入邀请码跳过问卷）是现有逻辑：读代码确认并在 JOURNAL 写明路径，不改。

## 约束
- 不加推送路由（旧版对未知 kind 只打开 App，正好落在绑定页）。不改其它关卡状态行为。
- 守仓内 `.swiftlint.yml` + `swift-format --strict`（唯一事实源是仓内配置）。
- 模拟器只准用 `iPhone 17e`，不新建、不换机型。
- 不 commit、不 push、不开 PR。

## 测试 seam（先红后绿，红要实际跑出来）
1. `Modules/StudentKit/Tests/StudentKitTests/Features/Bind/BindGateViewModelTests.swift`（主力）：「cancelled + endedAt + 教练名 → 解绑 notice（含名）」「cancelled + endedAt + 空名 → 兜底」「cancelled 无 endedAt → nil」，rejected / expired 照旧。
2. `BindRequest` 解码测试（CoreModels 现有解码测试旁）：带 `ended_at` / 不带各一条。
3. StudentKit + CoreModels 全量测试绿；swift-format / SwiftLint strict 通过；`iPhone 17e` 上 DemoStudent（`configuration=Demo`）构建通过。

## 交付
写 `docs/journal/2026-11-02-098-card-a.md`（一卡一文件）：改动文件、红 → 绿证据（命令 + 数字）、全量测试与 lint 结果、第 6 条确认结论、与 SPEC 不一致或拿不准的地方。界面亲验由 Opus 收货时在 `iPhone 17e` 上做。
