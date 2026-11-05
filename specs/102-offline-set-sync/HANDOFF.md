# spec 102 交接（Opus → Codex，2026-11-05）

David 要求剩余工作由 Codex 接手，本文件是唯一的交接依据。先读仓根 `CONTEXT.md`，再读 `specs/102-offline-set-sync/SPEC.md`（含「屏幕稿」节，是唯一的验收口径）、本目录的 `CARD-A.md` / `CARD-B.md`，以及两端的 JOURNAL。本文件在两个 worktree 各放一份，内容相同。

## 现状

| 端 | worktree | 分支 | 基线 | 状态 |
|---|---|---|---|---|
| 安卓 RN | `~/Projects/apps/meetpr-rn-wt-102` | `feat/102-offline-set-sync`（未提交） | `dab26a2`（spec 改稿） | 卡 A 与返修第 1 轮已完成。Opus 本机复跑通过：tsc、lint 过，全量 203 个套件、2104 条用例通过。未上模拟器。 |
| iOS | `~/Projects/apps/MeetPR-wt-102` | `feat/102-offline-set-sync-ios`（未提交） | `b72ab542` = #403 分支 `diagnose/set-video-lost-20261105` 并入最新 `release/1.0` | 卡 B 的 Codex 作业 `task-mw30mgsc-1lavnb` 在本文写成时还在 verifying 阶段。JOURNAL 自报 1128 个测试通过。Opus 尚未读 diff。 |

- spec：iOS #401 / #404 已合 `release/1.0`。RN #132 已合；RN #134（改稿镜像）开了自动合并，写本文时仍是 OPEN，接手后先核实是否已合。
- 屏幕稿已定稿：https://claude.ai/artifact/XzbjkhWw3KPaSwhDNsCasJ（结构已经转写进 SPEC，打不开链接不影响）。
- 已拍板的口径：失败色保持**橙色**（不用红、不用金），与 101 统一。

## 剩余工作（按顺序）

### 1. iOS 作业收尾
等 `task-mw30mgsc-1lavnb` 结束（`node ~/.claude/plugins/cache/openai-codex/codex/1.0.6/scripts/codex-companion.mjs status`，在 iOS worktree 里跑），读 `docs/journal/2026-11-05-102-card-b.md`。

### 2. 返修（两端都要做，先红后绿）
1. **两端**：长按后「正在同步训练记录…」的**文字和转圈图标改成白色**，与「开始训练」按钮文字用同一个 token。这是 David 11/05 在 iPhone 17e 上看过后提的。安卓现在用的是 `colors.goldText`，iOS 现在是暗橙色。
2. **iOS**：失败态（稿 ②）改用橙色。仿照安卓 `src/design/tokens.ts` 新增的 `failure` / `failureSoft`，在 DesignSystem 浅深两套里加同值 token：深色 `#F0954A` / `rgba(240,149,74,0.14)`，浅色 `#C2410C` / `rgba(194,65,12,0.10)`。iOS JOURNAL 第 3 条里「复用 gold500」的做法**不接受**。
3. **iOS**：按安卓返修第 1 轮（见 RN 的 `CARD-A-R1.md`）自查同类问题，有的话一起修：
   - 本机回执和闸门记录只增不删：按服务器快照覆盖来清理，并加 14 天兜底清理；
   - 改已有记录时训练日期被改成今天：第一次写入时带点击那一刻的训练日，改已有记录时沿用原来的 `logged_date`。
4. **iOS**：补齐三种新状态（同步中、超时失败、退出弹窗）的截图，覆盖简中、英文、繁体和深浅色。

### 3. 双轴审查
两端各跑一次独立审查，Standards 与 Spec 分开记录，不要合并。Spec 轴逐条对照 SPEC「验收清单」，查缺做、多做、做错。有问题就定向返修，最多 2 轮；不收敛就停下，写进 JOURNAL，交回 David。

### 4. 模拟器验收（SPEC 验收清单第 16 条）
- iOS 只用 `iPhone 17e`，安卓用 AVD `meetpr`，不准新建或改用其它机型。
- 逐条亲验并截图：验收清单第 1、3–9、12 条。其中「带历史的老用户升级后第一屏」（第 13 条）必须用有历史数据的账号验，测试账号用仓内现有的造号流程，凭证不准写进文件。
- 第 7 条「教练删动作」可以在 staging 网页端操作。如果没有可用的测试教练账号，写进 JOURNAL，交回 David。
- 截图放在各端 `docs/journal/102-card-*-evidence/` 下。

### 5. 提交与 PR
- 两端各自做原子 commit（动词开头），commit 消息末尾带 `Co-Authored-By` 行，按各仓惯例写。
- iOS PR 的 base 选 `diagnose/set-video-lost-20261105`（#403 没合之前），或者等 #403 合进 `release/1.0` 后变基到 `release/1.0`。PR 描述里写明叠在 #403 之上。
- RN PR 的 base 是 `main`。
- **这是 T2，PR 等 David「放行」，不准自己合并**，RN 也不要开自动合并。
- PR 描述用一两句人话写清用户能看到的变化。

### 6. 交给 101
两端的闸门都给「视频全部送达」留了输入（RN 签名见 RN JOURNAL「给 101 的完成闸门接口」一节，iOS 见 iOS JOURNAL）。PR 开出来后，通知 101 会话（会话名「视频上传失败问题」，`local_7b7a82f5-1f11-418f-9e2d-69b0133d6f43`）。它的 101 卡要叠在 102 的分支上做。

## 约束
- 纯客户端，不改后端，不改 API 协议。
- 不新增依赖，不改锁文件，不改 RN 的 `PARITY.md`，也不改 iOS 的 RELEASES / NEXT-RELEASE 台账。这些台账在放行后由 Opus 定稿。
- 每张卡、每轮返修都把证据追加进对应的 JOURNAL：
  - `docs/journal/2026-11-05-102-card-a.md`（RN）
  - `docs/journal/2026-11-05-102-card-b.md`（iOS）
- 凭证不准写进任何文件。
