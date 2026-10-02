# Spec 084 · 卡 B（iOS）：登录页顺序、训练页周条翻周、删除 Plan summary

开工先读仓内 `CONTEXT.md`（如存在）、`AGENTS.md`、`specs/084-walkthrough-polish/SPEC.md` 的 §1、§4、「设计定稿」里的 §1 与 §4、「设计项的验收清单」。

- 级别／节奏：T2 / P1。本分支 `feat/084b-week-strip-login` 叠在卡 A（`feat/084a-walkthrough-behaviors`，PR #347）之上，卡 A 合入后 PR 指向发版线 `release/1.0`；目标 1.0(24) 候选（落线不等于进包）。
- 这是 Opus 派的任务卡，走 feature 分支 + PR，**不是** `AGENTS.md` §发版直推流里的"David 直驱小修"：那一节的开工自检（当前分支必须是发版线）不适用，就在当前分支实装；发版线正被别的 worktree 占着，也切不过去。直推流里与分支无关的纪律（lint、测试）照守。
- **不 commit、不 push**。不改 `NEXT-RELEASE.md`、`RELEASES.md`、build 号；只在 `docs/CODEX-JOURNAL.md` 末尾追加本卡一节。本仓已公开。
- 设计稿实装方打不开，SPEC「设计定稿」的文字转写就是参照物：结构、层级、相对间距按转写，颜色字号间距用仓内现有 token，不引入新色值。

## §1 登录页顺序

落点：`Modules/AppShell/Sources/AppShell/Auth/Global/GlobalLoginView.swift`（及 `GlobalRegisterView.swift`，若它展示第三方入口）。要求：自上而下为 wordmark → 大标题 → EMAIL → PASSWORD（带显示/隐藏）→ 主按钮 Sign in → 一行两个文字链接（左 Create account，右 Forgot password?）→ 中间带 "or" 的分隔线 → 第三方登录按钮（Apple、Google 上下排列、同等尺寸、描边次要按钮样式、整行宽）→ 页面底部法律文案。只调顺序与分隔，各入口的行为、校验、错误展示、无障碍标识不变。CN 轨的登录页不在范围内。

## §4 训练页周条翻周 + 删除 Plan summary

现状：训练页（`Features/TodayWorkout/TodayWorkoutScreen.swift`）页头下有一条只显示当前周的周条；页面下方的 `TrainingCalendarView`（标题 "Plan summary"，按周折叠列表）是查看其他周的入口；`TrainingCalendarLogic.swift` 的 `TrainingSequenceLayout` 提供按周分组与选中 / 当前状态。

要求（逐条对应 SPEC「设计定稿 §4」）：

1. 周条区块改为三行：换周行（左箭头｜"W{n}" + 状态胶囊 + "已完成数 / 总数"｜右箭头；箭头命中区不小于 44pt；第一周左箭头、最后一周右箭头置灰且不可点）、训练日行（该周每个训练日一格等宽）、周数指示小点（每周一个；正在看的周是拉长的深色点；不在当前周时当前周的点为金色；计划超过 8 周不画小点）。
2. 状态胶囊：当前周 "Current week"（淡金底）；未来周 "Upcoming"（中性底）；已过的周 "Completed"。中英文文案键同步新增。
3. 训练日格的两种标记分开：**选中** = 深色 2pt 粗框、白底（Dark 下用对应的表面色），跟随点选；**当前训练日** = 整格淡金底、日期金色加粗、状态图形为金色空心圆。两者可同时出现。已完成 = 绿色对勾；未完成 = 空心圆。格内三层：状态图形、"D{序号}"（序号走卡 A 的 `StudentPlanSequence.dayNumbers`）、日期。
4. 默认停在当前周并选中当前训练日。左右箭头翻到计划内任意一周；翻周后默认选中该周第一个训练日（翻回当前周则选中当前训练日）。也支持在周条上左右滑动翻周，与箭头等效。
5. 不在当前训练日时：页头右侧三个圆形按钮的位置换成文字链接 "Back to today"，点了回到当前周并选中当前训练日；标题显示所选那天的 W#D#。
6. 周条下方的卡片展示所选那天：未来训练日是只读预览（教练推荐日期一行、训练日名称、"N exercises total · M sets"、逐个动作行），没有开练按钮，底部一句说明当前该练的是哪一天（复用现有的解锁提示文案 `TrainingSequenceText.unlockMessage`）；已完成的训练日沿用现有的已完成展示；当前训练日就是现状的训练卡。现有"点选其他训练日后页面如何展示"的逻辑能复用就复用，不重写记组流程。
7. 删除 `TrainingCalendarView`（Plan summary 区块与按周折叠列表）及其不再使用的文案键、预览；`TrainingSequenceLayout` 里只为它服务的函数一并删除或改造为周条的分页数据源。
8. 选中状态不持久化；切 tab 再回来、点页头刷新按钮、完成一天后，回到当前周当前训练日（与现状"进入训练页落在当前训练日"一致）。

## 约束

- 不改后端契约与本地持久化结构；不加依赖；不改记组、休息计时、补录、完成当天的流程与导航结构（tab、页头其余元素不动）。
- 存量照护：带历史的老用户升级后进入训练页，仍落在当前训练日；已完成进度、草稿、休息计时不变。
- 守仓内 `.swiftlint.yml` 与 `swift-format --strict`。单文件长度若触线，按仓内既有做法拆子视图文件。

## 测试 seam（先红后绿，只在这些边界）

1. `GlobalLoginView` 的元素顺序（现有 `GlobalAuthViewTests`）。
2. `TrainingSequenceLayout` 的按周分页数据源：周列表、每周的格子（序号 / 状态 / 是否当前训练日 / 是否选中）、翻周后的默认选中、首尾周的箭头可用性、"是否显示 Back to today"。

视图样式不写镜像测试。

## 验收清单（Opus 收货，逐项核）

- [ ] 登录页自上而下：邮箱、密码、Sign in、两个文字链接、or、Apple、Google、法律文案；Apple 与 Google 同等尺寸；各入口行为不变。
- [ ] 训练页无 Plan summary。
- [ ] 周条可翻到第一周与最后一周，首尾箭头置灰；左右滑动与箭头等效；小点指示正确（超过 8 周不画）。
- [ ] 选中框跟随点选；当前训练日始终淡金底；两者同时出现时都可辨。
- [ ] 翻到其他周：出现 "Back to today"，标题为所选那天的 W#D#；未来训练日只读、无开练入口、有当前该练哪天的说明；已完成的训练日显示已完成内容。
- [ ] "Back to today" 回到当前周并选中当前训练日；切 tab 回来、点刷新按钮后也在当前训练日。
- [ ] 记组、休息计时、补录、完成当天流程与修改前一致。
- [ ] Light / Dark、小屏（iPhone SE 尺寸）与大字体下周条不截断、不遮挡主按钮。
- [ ] 九个包的 `swift test`、主工程测试、`swiftlint lint --strict`、`swift-format lint --strict` 通过。

模拟器实屏由 Opus 收货时做；沙箱里跑不了模拟器就如实写"未做设备验证"。

## Out of Scope

SPEC §7–§10（卡 C）；Today 页的周条（Dashboard）；Progress 页；教练端；CN 轨登录页；build 号、tag、`NEXT-RELEASE.md`、Archive / Upload。

## 返修第 1 轮（Opus 收货，2026-10-02）

StudentKit 912 / AppShell 104 项测试与两个 lint 在收货方本机复跑通过。DemoStudent（Dark）实屏：周条三行结构、箭头首尾置灰、状态胶囊、小点、选中框跟随点选、当前训练日淡金底、左右滑动翻周、"Back to today"、未来训练日只读预览与解锁说明、Plan summary 已删，都对。两处返修：

1. **新增视图用了系统字体，和页面其他部分不是一套字。** `TrainingWeekStrip.swift`、`TrainingDayPreview.swift` 与页头的 "Back to today" 用的是 `.headline` / `.caption` / `.subheadline` / `.title3` / `.body` 这类系统文字样式，屏幕上是 SF 字体，而同页其余文字走 `Font.MeetPR`（如 `.MeetPR.mono(size:)`、`.MeetPR.body(size:weight:)`、`.MeetPR.display(size:)` 配 `MeetPRFontMetrics`）。全部改为仓内字体 token，层级参照同文件相邻元素：W{n} 与 "已完成数 / 总数"、D{序号}、日期用等宽字；状态胶囊与 "Back to today" 用正文字；预览卡的训练日名称用与现有训练卡标题同级的展示字，推荐日期与小结行对齐现有同类文字的字号。图标尺寸也用 `.MeetPR.system(size:weight:)`。
2. **去掉本卡新增的下拉刷新（`.refreshable` 与 `onPullToRefresh`）。** 训练页原本只有页头的刷新按钮，卡面里"下拉刷新"是我的笔误，已改为"点页头刷新按钮"。刷新按钮点了之后回到当前训练日的行为保留。

返修后重跑 StudentKit、AppShell 测试与两个 lint，JOURNAL 本卡一节追加一行。仍不 commit、不 push。
