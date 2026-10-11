# Spec 090 · iOS 收货记录 · 2026-10-10

卡：[CARD-ios](CARD-ios.md)。分支 `feat/090-training-flow`，叠在 `feat/089-accessory-quick-log` 上（其下是 086）。实装方 Codex，收货方 Opus。返修 1 轮。

## 先说最要紧的：089 必须和本卡一起上

收货时拿 090 之前的提交 `576729ac`（即 089 的内容）做对照，发现它在自己的主流程里会卡死：

- 步骤：`MeetPR-DemoStudent` 带 `--spec089-accessory` 启动 → 训练页 → 点辅助项第 1 组的 ✓（休息计时开始）→ 上滑。
- 结果：089 的包 3 次里 3 次卡死，主线程 CPU 100%，停在 SwiftUI 懒加载列表的布局里（`LazySubviewPlacements.placeSubviews`）。[主线程采样节选](evidence/opus-089-hang-main-thread-sample.txt)
- 同样的步骤在本卡的包上 2 次里 0 次卡死（第 3 次是启动脚本没点上，不计）。本卡把记录态的列表从懒加载换成了一次排完，原因正是实装中遇到同类卡顿。

结论：**089 的 PR 不能脱离本卡单独合并**。另外，实装方在 089 的包上走默认 Demo 的主项路径时也报过冻结，而收货方同一路径跑了一次没有卡——主项路径是偶发的。发版线 `release/1.0` 上是否也能触发没有验；它和 2026-10-03 记录的那次「完成流程主线程卡死、排障未复现」很像，建议单开一次排障。

## 自动检查（收货方在本机复跑）

- `swift test --package-path Modules/StudentKit`：960 项全部通过（本卡新增 5 项）。DesignSystem 73 项以 Codex 记录为准（只公开了已有的两条文案）。
- `swift-format lint --strict` 与 `swiftlint lint --strict`：0 违规（提交时 pre-commit 钩子再跑一遍）。
- 改过的既有断言 1 条：全部记完时训练页上 Ask coach 入口数由 1 变 0。依据是 SPEC §3「所有动作都做完时 hero 卡消失」，原来唯一的 Ask coach 就在那张卡上。
- 全量 diff 已读：Standards 无问题；Spec 返修后无缺做、无多做。

## 实屏

收货方亲看：iPhone Air 模拟器（iOS 26.4），`MeetPR-DemoStudent`——分段条（`--spec090-main-two`，英文浅色）、记完主项末组后的上收、完整录入页、全部做完的吸底按钮（`--spec090-all`，中文深色）。其余形态看的是 Codex 在 iPhone 17 Pro 上留的截图。

| 验收项 | 结论 |
|---|---|
| 1–2 分段条 | 通过。三段，已记两段填实、当前段更宽并高亮。[截图](evidence/opus-segment-bar-en.png)；[标记失败的段用弱一档的灰，不用红](evidence/02-failed-segment.jpg) |
| 3 主项做完上收 | 通过。做完的动作收成一行排到 hero 上方并标 `Completed · 3 sets`，下一个动作顶进 hero，刚收上去的那一行贴近可视区顶部。[截图](evidence/03-main-complete-final.jpg) |
| 4 点开做完的一行 | 通过。能看各组、进录入页改成绩。[截图](evidence/04-edited-completed-final.jpg) |
| 5 辅助项 | 通过。逐组 ✓ 到最后一组、「全部按计划完成」都会上收；辅助项卡没有分段条 |
| 6、9 取消一组 | 通过。它回到下方或重新成为 hero；全部做完后取消则按钮回到滚动区底部。[截图](evidence/06-09-cancel-final.jpg) |
| 7 跳着做 | 通过（Demo 场景 + 单测）。[截图](evidence/07-skipped.jpg) |
| 8 全部做完 | 通过。hero 消失，长按按钮吸在 Tab 栏上方，列表不被遮住；长按能结算并出庆祝页。[中文深色](evidence/opus-all-done-zh-dark.png)、[庆祝页](evidence/08-celebration-final.jpg) |
| 10 只做了一部分 | 通过。按钮与「还剩…」提示仍在滚动区底部 |
| 11 老用户第一屏 | 通过（Demo 场景）。当天已记 5 组，打开即是正确分区，不自动滚动。[截图](evidence/11-upgrade-final.jpg) |
| 12 不该变的页面 | 未开始的汇总卡、只读预览、已结算详情、训练历史都打开看过，未见变化。[汇总卡](evidence/12-default-summary.jpg)。没有和旧包逐屏并排比 |
| 13 录入页 | 通过。iPhone 17 Pro 与 iPhone Air 默认字号下不滑动能完整看到 Record / Photos。[截图](evidence/opus-set-entry-en.png) |
| 14 深色、中文、磅 | 各跑过一遍 1–3、8、13。[磅](evidence/lb-08.jpg) |
| 结算后回训练页 | 正常，没有安卓那边「页头以下空白、拖一下才出现」的现象。[截图](evidence/08-return-training-final.jpg) |

## 返修一：完成按钮被休息条遮住

部分记录、休息计时在走时，滚到最底，滚动区里的长按完成按钮有一半在休息条下面，滚不上来。在 090 之前的包上实测同样如此（[截图](evidence/opus-before-090-button-under-rest-bar.png)），是改前就有的问题，顺带修了：休息条在场时给滚动内容补出等高的底部留白。休息条本身没动。[修后](evidence/r1-partial-rest-bottom.jpg)、[没有休息条时底部不多出空白](evidence/r1-partial-no-rest-bottom.jpg)、[全部做完时吸底按钮与休息条同时在场](evidence/r1-all-docked-rest.jpg)

## 需要知道的两处

- 全部记完后、结算之前，训练页上没有 Ask coach 入口（它原来在 hero 卡上，hero 卡此时按 spec 消失）。页头的消息按钮仍在。安卓同样如此。
- 下方动作组表里，没填 RPE 就记下的辅助项组，RPE 一栏显示的是教练处方值（组表的既有显示规则，本卡未动）；记录卡里它是空的。

## 没验到的

- 系统「减少动态效果」开关、VoiceOver 朗读、键盘开着或手动滚动时与自动上收的竞争（代码有对应处理，没有实测）。
- 真实拍摄、选片与回放；RPE 拖动、减号与长按连加。
- iPhone SE；真机。
