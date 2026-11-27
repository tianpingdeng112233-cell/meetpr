# 卡：学员端三处显示问题（RPE 对照表 e1RM 长小数 / 看完反馈视频后对话左移 / 图表横轴日期日在前）

先读仓根 CONTEXT.md（有则读）、CLAUDE.md、AGENTS.md。

- 仓库：MeetPR iOS，工作树 `/Users/david/Projects/apps/MeetPR-wt-student-fixes`，分支 `fix/student-rpe-chat-chart`，基于 `origin/release/1.0@44ab7fb1`。只在这个工作树里改。
- 级别：T1（StudentKit / DesignSystem 内，≤5 文件，无迁移）。
- 模拟器：只用 `iPhone 17e`（UDID 5D5FA360-BA49-48C6-A887-2F0D22F89749）。动手装包前先 `ps aux | grep 5D5FA360` 看有没有别的会话正在用它（例如别的 `simctl launch` 或 xcodebuild test）；被占用就先做不需要模拟器的部分，最后在报告里写明 UI 验证没做、卡在哪。严禁新建或改用其它模拟器，不碰 `iPhone 17 Pro` / `iPhone 17`（演示机）。
- 不 commit、不 push、不开 PR（由 Claude 收货时做）。JOURNAL 写到 `docs/journal/2026-11-27-student-rpe-chat-chart.md`。

## 背景（Claude 11/27 侦查结论）

用 1.0(43) 学员演示包（`MeetPR-DemoStudent` scheme）截 user path 时发现，已对照 `release/1.0` 代码核实：

### A. RPE 对照表顶部 e1RM 没取整（根因已知，直接修）
- 现象：成长 › RPE 对照表 › 深蹲，顶部显示 `178.34793491864840192`，占两行；E1RM 曲线页同值显示 178.3。
- 根因：`Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/RPETablePage.swift` 第 33 行 `UnitDisplay.weightText(kg: Decimal($0), unit:)`。kg 分支 `plainString(kilograms)` 不取整；`Decimal(Double)` 会把二进制误差原样带出（如 92.5/0.81 → `114.19753086419750912`）。e1RM 由 `E1RMCalculator.calculate` 在本机算出、不取整。真实包同样会出。
- 修法：对照表顶部按 E1RM 曲线页同一口径显示（1 位小数，去掉尾随 0）；lb 分支同样处理。不改 `UnitDisplay.weightText` 的全局语义（它被问卷等输入回显复用），在对照表这一处取整或新增专用格式函数。
- 安卓（meetpr-rn）已是 `Math.round(e1rm*10)/10`，不用改。

### B. 看完教练反馈视频后，教练 tab 对话整体左移且不恢复（根因未知 → 走下方六阶段）
- 现象：教练 tab › 点反馈卡里的视频（全屏回放，`FeedbackVideoPlayerView`，`StudentBlackGoldChatView.swift` 第 231–235 行 `.fullScreenCover`）› 关闭。回来后整个对话（卡片和时间戳）往左偏约 14pt 贴屏幕左边；切到别的 tab 再回来也不恢复，杀进程重开才好。演示包上连续复现 2/2。
- 演示视频是横版测试片；真实视频多为竖拍，真实账号未验证。没有演示专用代码分支。

### C. 图表横轴日期在中国地区仍显示「日/月」（根因未知 → 走下方六阶段）
- 现象：成长 › 强度指标，横轴显示 `22/11`。模拟器地区设为英国时出现属正常，但把地区改成中国（`-AppleLocale zh_Hans_CN -AppleLanguages (zh-Hans-CN)` 启动参数，以及 `defaults write -g AppleLocale zh_Hans_CN` 后重启 App 两种方式）后，同一页面仍是 `22/11`；同一次运行里聊天卡「11/27周五」、体重页「10/29」、训练回顾「11/27」都已变成月在前。
- 代码：`Modules/DesignSystem/Sources/DesignSystem/Components/Charts/CapacityIntensityChart.swift` 约第 89 行 `Text(date, format: .dateTime.month(.twoDigits).day(.twoDigits))`；同类还有 `GrowthTotalCard.swift:137` 的 `AxisValueLabel(format:)`、`BodyWeightChartCard.swift:124`。
- 期望：中国地区（以及 zh-Hans 系统语言）下横轴是「11/22」月在前，与 App 其他地方一致。
- 注意：未证实 C 在真机上也出现，可能和模拟器 / 偏好缓存有关；必须先造出确定会红的环再下结论，环造不出就如实报告。

## 范围
- 改：上述 A、B、C 相关文件 + 对应测试。
- 不改：安卓、后端、教练端、文案、布局与视觉（B 只修偏移，不改样式）。

## 测试 seam（先红后绿，优先复用已有）
- A：`StudentKitTests` 里对 RPE 对照表快照或展示层（`RPETable` / `RPETablePage` 的格式化）断言 178.34793491864840192 → `178.3`、114.19753086419750912 → `114.2`、180 → `180`。
- B：优先 UI test（`MeetPRUITests` 若有，用 DemoStudent 配置）：进入教练 tab → 打开反馈视频 → 关闭 → 断言对话首张卡片 frame.minX 与打开前一致。没有合适 seam 就记录「无 seam」作为发现。
- C：能在单元测试里固定 `Locale(identifier: "zh_Hans_CN")` 渲染轴标签字符串的，就用它；否则 UI test 带 `-AppleLocale zh_Hans_CN` 启动断言轴标签。

## B、C 必须按 /diagnose 六阶段走，每阶段回报完成判据
1. 造反馈环：一条已跑过的、对该症状会变红的命令（贴调用+输出），确定性、秒级、无人值守。造不出就停，列出试过的，不准进假设。
2. 复现+最小化：确认复现的就是上面描述的症状；一次切一样，只留承重条件。
3. 假设：列 3–5 个可证伪假设并排序（每条写「若 X 是原因，改 Y 会消失」）。排序表写进 JOURNAL 和最终报告，然后按自己的排序继续，不等回复。
4. 埋点：一次改一个变量；debug 日志统一前缀 `[DEBUG-sf27]`。
5. 修+回归测试：有正确 seam 先写失败测试看它红，再修看它绿，再对原始场景重跑第 1 步的环。
6. 清理：原始复现不再复现；回归测试过或记录无 seam；`grep -rn '\[DEBUG-sf27\]'` 为空；一次性 harness 删除；正确假设写进 JOURNAL（commit message 由 Claude 写时引用）。

## 验收清单（Claude 收货逐条核）
- [ ] A：对照表深蹲/卧推/硬拉顶部都是 ≤1 位小数，单行；kg、lb 都核；E1RM 曲线页数值不变。
- [ ] B：iPhone 17e DemoStudent 包，教练 tab 打开反馈视频再关闭，对话位置与打开前一致，连续 3 次不偏；切 tab 来回不偏。
- [ ] C：地区中国时强度指标、E1RM 曲线、体重曲线横轴都是月在前；地区英国时行为不变（跟随系统）。
- [ ] `xcodebuild test` 相关 scheme 全绿（贴通过数）；新增回归测试先红后绿有记录。
- [ ] 无 `[DEBUG-sf27]` 残留；无范围外改动（`git diff --stat` 贴出）。

## 交付
- 工作树内未提交改动 + `docs/journal/2026-11-27-student-rpe-chat-chart.md`（含 B、C 六阶段记录、假设排序表、最终根因、测试命令与输出摘要）。
- 最终回报：A/B/C 各一句结论（修了什么 / 根因 / 是否在模拟器验证变绿；验不了要写明卡在哪）。
