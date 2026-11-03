# 实装卡 2026-11-02：spec 100 学员端 RPE / RIR 说明卡片

先读仓根 CONTEXT.md（有则读），再读 `specs/100-rpe-rir-explainer/SPEC.md`（正典，本卡与之冲突以 spec 为准）。本卡 iOS（MeetPR，基线 `origin/release/1.0`）与安卓（meetpr-rn，基线 `origin/main`）各一份，内容相同，两端同批交付。

- 来源：用户反馈 #6「RPE/RIR 需要向小白解释」
- 级别：T1，P1（随下一班车）
- 分支：`feat/100-rpe-rir-explainer`（安卓 worktree `/Users/david/Projects/apps/meetpr-rn-wt-100`，iOS worktree `/Users/david/Projects/apps/MeetPR-wt-100`）

## 目标（详见 spec §变更 1–4）

1. 记录弹窗强度区标题、辅助项记录卡表头、补记表头强度列：RPE / RIR 字样旁加「?」按钮，按当前显示的是 RPE 还是 RIR 打开对应说明卡片。
2. 新建两张说明卡片（RPE 一张、RIR 一张），文案逐字照 spec 表格（简中 + 英文；繁体走现有繁体生成流程，见 spec 094，不手写）。
3. RPE 刻度每档小字（`student.setEntryRpe.copy001…011`，copy001 = RPE 5 … copy011 = RPE 10）按 spec §3 表改值，key 不改。
4. 记录弹窗 RIR 模式步进器下加小字：0 →「做不动了」，1–9 →「还剩 N 次」（英文单复数），未填不显示。

## 屏幕稿（已定稿，方案 A：居中浮起卡片；稿在 Claude Design，下面是转写）

- 弹出：全屏半透明遮罩（用仓里现有弹窗遮罩 token，没有就深色 60% / 浅色 45% 黑），卡片垂直水平居中，左右各留 20，宽度 = 屏宽 − 40，圆角 18，1px `borderStrong` 描边，背景用现有卡片/浮层表面 token（暗色要和遮罩后的弹窗底能分开）。点遮罩或右上角 × 关闭；系统返回键（安卓）/ VoiceOver 退出手势（iOS）也关闭。
- 卡片内边距：上 20、左右 20、下 16（RIR 卡下 18）；纵向间距 14。
- 头部：左侧两行，标题 18 semibold `textPrimary`，副标题 13 `textMuted`，两行间距 4；右上角关闭按钮命中区 44×44，图标 16 的 ×，`textMuted`，无障碍名「关闭 / Close」。
- RPE 卡片表格：8 行，每行上方 1px `borderStrong` 分隔线，行上下内边距 9；左列数值等宽字体 15 bold `gold500`，固定宽 40；右列说明 15 `textSecondary`；两列间距 12，基线对齐。表格下一行 13 `textMuted` 结尾句。
- RIR 卡片：头部副标题即正文句；中间一个例子块：`surfaceRaised` 底、圆角 10、内边距 12/14，一行内依次「例：做了 6 次，觉得最多能做 8 次」(15 `textSecondary`)「→」(`textMuted`)「填 2」(等宽 bold `gold500`)，放不下可换行；下面 13 `textMuted`「一次也做不动了就填 0」。
- 「?」按钮：18 的圆圈问号线性图标，描边 `textMuted` 1.4，视觉紧跟在 RPE/RIR 字样（及其切换图标）右侧，命中区 44×44 但不能与左边原有 RPE/RIR 切换按钮的命中区重叠（切换照常可点）。无障碍名「RPE 是什么 / What is RPE」「RIR 是什么 / What is RIR」。
- RIR 步进器小字：在步进器数值下方居中，13 `textSecondary`，与 RPE 刻度小字同一纵向位置感。
- 深浅色都用 token，不写死色值；动态字体放大时卡片可滚动，不截断。

## 约束

- 只改：记录弹窗、RPE 刻度小字数据源、辅助项记录卡表头、补记表头、新卡片组件、字符串目录、对应测试。
- **不碰今日卡**：主会话的今日卡修复卡正在改 RN `WorkoutBody.tsx`、iOS `TodayWorkoutScreen.swift` / `TrainingDayPreview.swift` 及新文件 `TodayWorkoutSummaryPresentation.swift`，本卡一行都不许动这些文件。也不碰 onboarding、绑定页、计划编辑器、入门问卷 Step3 那句 RPE 解释。
- 不改任何存储字段、取值范围、步进、提交逻辑；不加「首次自动弹出」或已读状态。
- 卡片不标出处、不加换算说明（spec Out of Scope）。
- iOS 模拟器只用 `iPhone 17e`（simulatorName=iPhone 17e）；安卓用现有 AVD `meetpr`。
- Codex 只改工作区，不 commit、不 push、不开 PR；收货后由 Opus 提交并开 PR。

## 验收清单

照 spec「验收清单」1–8 条逐条做，截图放 `docs/evidence/rpe-rir-20261102/`（只用测试/演示数据），至少：主项 RPE 卡片（暗色、浅色）、RIR 卡片、辅助项表头「?」、补记表头「?」、刻度 9.5 档小字、RIR 步进器 0 与 2、英文与繁体各一张卡片、最大字体一张。

## 测试 seam（先红后绿，越少越好）

- 安卓：`src/features/training/__tests__/training-policy.test.ts` 里现有 `rirCopy` 逐档表测试改成新口径（先红）；新增纯函数 `effortExplainerFor(kind: 'rpe' | 'rir')`（返回卡片标题/副标题/行/结尾的 i18n key 结构）与 `rirStepperCopy(value: string)`（空 → null，0 → 做不动了，1–9 → 还剩 N 次），各一组测试。三处「?」共用 `effortExplainerFor`。
- iOS：`Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/SetEntryRPEScaleTests.swift` 补 `SetEntryRPE.descriptions` 新口径逐档断言（先红）；同名语义的卡片内容与 RIR 小字纯函数各一组测试。
- 卡片视图不写快照测试，靠模拟器亲验。

## 交付

- 工作区改动 + `docs/journal/2026-11-02-100-rpe-rir-<android|ios>.md`（红/绿两次的命令与结果摘要、截图路径、偏离屏幕稿之处及理由、未决项）。
- 两端既有测试全绿；iOS 至少跑 StudentKit 测试 + 在 iPhone 17e build；安卓 `npm test`、`npx tsc --noEmit`、lint 全过。
