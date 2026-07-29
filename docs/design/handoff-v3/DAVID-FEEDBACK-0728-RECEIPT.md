# 黑金 UI v3 · David 0728 四件套回执

分支：`feat/black-gold-ui-v3`

交付方式：仅工作区实装与自检；未 commit、未 push。

## ① 今日页 E1RM 未成形态

- 今日页不再渲染「完成 3 次训练后解锁趋势」占位。
- `DashboardE1RMTrendRow` 按动作族携带 eligible 记录数与展示日期；解锁阈值直接复用
  `GrowthHistoryStats.trendUnlockThreshold`，与成长页 scene 02 同一口径。
- David 亲验退回后的第 1 轮返修按 0 / 1–2 / ≥3 三路显式分流：
  - 0 条使用 scene 03 语言，不再画空坐标轴：显示「未设定」、幽灵曲线图形、
    「第一个数据点·等你练出来」与首练后开始记录的说明。
  - 1–2 条使用 scene 02 完整成形图；复用成长页的坐标轴、横向网格、动态 Y 轴数字、
    日期标签、当前点光环与空心预测点。今日卡把图形本体放到 100pt，连同进度说明区约
    150pt，不再压成 48/68pt。
  - ≥3 条恢复正常实线趋势。
- 成形态的数值和日期来自同一 record：日期优先
  `latestRecordPoint.computedAt`，只有没有 record 时才回退 raw eligible 最新日期，避免把
  D1 的 170 kg 配成 D2 的日期。
- 0 / 1 / 2 / 3 条 eligible 的参数化测试分别锁定 `.zero` / `.forming` / `.forming` /
  `.mature`；另有「第二条 eligible 未破纪录」回归测试锁定数值—日期配对。
- DemoStudent 强制 `growth-forming` seed 目检：
  - 硬拉 0/3：显示「未设定」、scene 03 幽灵图形和首数据点文案，没有空轴或游离破折号。
  - 深蹲 1/3：显示真实 `128 kg` 单点、完整坐标件、1/3 进度与虚线幽灵曲线，没有 `+0` 平线。
  - 两种状态均没有「暂无数据」。

## ② 今日周历与日期身份

- `PlanCalendarDayIdentity` 明确分层：
  - 选中日与可见「今天」使用设备 `Calendar` 的自然日。
  - 计划日继续使用 UTC 年/月/日分量匹配。
  - 04:00 gym-day cutoff 只保留为写入资格规则，不再决定日历默认选中日。
- `StudentDemoSeed.makePlanView` 将设备日历的相对 D1 投影为 UTC plan date；日界线测试覆盖
  `Asia/Shanghai 2026-07-29 00:30`（对应 UTC 仍是 7/28），D1 仍匹配设备 7/29。
- 今日页与训练页共用上述 plan-day identity；训练 tab 初始化及「回到今天」都落设备今天。
- `TodayWorkoutView` 的初始化与 `jumpToTodayToken` 不再各自直接取时间；两个生产入口统一消费
  `TodayWorkoutSelectionResolver`。00:30 回归测试同时执行这两条 resolver 路径，锁定设备日
  7/29（即使 UTC 仍为 7/28），以后任何一条退回 gym-day anchor 都会失败。
- 有计划主项的点使用 `textPrimary` 点亮；无该主项保持描边；当天
  `TrainingDayProgress.state == .partial` 时使用 `gold500` 黄点。
- iPhone 17 模拟器实证（设备日期 2026-07-28）：
  - 今日页标题为 `7月28日 · 星期二`，周二硬拉点点亮。
  - 训练 tab 默认选中 `周二28日，今天`；`周三29日` 标记为未来。
  - 单测同时锁定日界线映射与 partial session 黄点。

## ③ CTA → 训练 morph header 锚点

- `TodayWorkoutHeader` 外层显式占满可用宽度并固定
  `alignment: .leading`。MEETPR mark 与 W-code 始终共享左锚点；morph / riseIn 不再因
  `LazyVStack` 的中间测量宽度产生水平居中帧。
- Reduced Motion 分支未修改，仍沿用既有直接完成路径。
- 模拟器录屏：`/tmp/meetpr-morph-0728-retry.mp4`。
- 宿主 AVFoundation 无法解码该模拟器录屏，因此另一次同路径触发用 touch-down/up 后在
  20 / 80 / 140 / 220 / 320 ms 直接抓取五张活帧；五帧中可见 W-code 的 leading 均约为
  15 pt，没有居中或横向位移。落稳后的训练 header 同样保持约 15 pt leading。

## ④ 今日 CTA 副行

- CTA 副行按当日主项数统一由 `DashboardTodayPresentation.liftSubtitle` 生成：
  0 项为空；1 项用完整动作名加「日」；2 项用两个完整动作名以「、」连接再加「日」；
  3 项才使用「蹲·推·拉」缩写。
- 测试一次覆盖 0 / 1 / 2 / 3 四档，分别锁定空串、「硬拉日」、「深蹲、卧推日」与
  「蹲·推·拉」。
- 产品代码唯一消费点是 `DashboardTodayScreen.liftSubtitle`，结果再传给
  `DashboardPrimaryAction`；没有第二套副行拼接逻辑。

## 自检

| 项目 | 结果 |
|---|---|
| `swift-format lint --strict` | ✅ 全仓 0 finding |
| `swiftlint lint --strict` | ✅ 全仓 0 violation |
| 全量 SPM | ✅ 9 packages，1354 passed，0 failed，0 skipped |
| 三套 build | ✅ `MeetPR` / Debug、`MeetPR-Demo` / Demo、`MeetPR-DemoStudent` / DemoStudent；iPhone 17（iOS 26.5），均 0 warning |
| 日界线与默认选中 | ✅ 今日页 7/28 点亮；训练 tab 默认 7/28 今天，7/29 未来 |
| E1RM 未成形态 | ✅ 0/3 与 1/3 均在浅色、深色目检；0 次无空轴/破折号，单点全坐标件且无 `+0` 平线 |
| morph header | ✅ 录屏完成；五张活帧无水平居中帧 |
| 范围红线 | ✅ CoachKit / ChatUI / auth / Bind / Evaluation 零 diff |

全量 SPM 的 AppShell 依赖重编译仍报告一条既有 warning：
`TodayWorkoutViewModel.swift:181` 的 `nextDrafts` 可改为 `let`。该文件不在本次 diff，未扩 scope
处理；最终 DemoStudent build 为 0 warning。
