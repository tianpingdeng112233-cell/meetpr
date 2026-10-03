# Spec 084 · 卡 A（iOS）收货记录 · 2026-10-02

卡：[CARD-A-ios](CARD-A-ios.md)。基线 `release/1.0@bcabd9a4`，分支 `feat/084a-walkthrough-behaviors`。实装方 Codex，收货方 Opus。返修 1 轮。

## 自动检查（收货方在本机复跑）

- `swift test`：CoreModels 158、StudentKit 908、CoachKit 443 全部通过。Codex 沙箱里 StudentKit 报过 15 个视频 `Cannot Encode`，本机不复现，属沙箱编码环境问题。
- `swiftlint lint --strict` 与 `swift-format lint --strict`：0 违规。
- 其余六个包与主工程测试没有重跑，以 Codex 的 JOURNAL 记录为准（九个包共 1936 项、主工程 9/9）。

## 实屏（iPhone 17 模拟器，MeetPR-DemoStudent）

| 验收项 | 结论 |
|---|---|
| §2 序号 | 通过。演示计划本周训练日在周二至周五，Today 页头 W1D3、周条 D1–D4；训练页页头、周条、计划摘要一致。[Today](evidence/a-today-ordinal-and-saved-weight.png)、[训练页](evidence/a-training-page-ordinals.png) |
| §3 卡片可点 | 通过（有值态）。体重卡进入 Basic information，改为 83.5 保存后回 Today 即时显示 83.5 kg，Profile 同步；Meetday 卡进入 Meet / notes，返回不写。[编辑页](evidence/a-basic-info-editor-from-today.png) |
| §5 去横幅 | 发版线上本来就没有展示横幅的视图，本卡删掉了残留状态并在记录时静默确认；由单测覆盖，实屏无横幅 |
| §6 提醒默认日 | 通过。演示学员档案训练日是一三五六，提醒页默认选中周二至周五（取自计划推荐日期）。[截图](evidence/a-reminder-default-from-plan.png) |

## 没验到的

- 两张卡的空态点击：演示数据都有值，只有单测覆盖。
- 教练端学员详情的 W#D#：MeetPR-Demo 的演示学员没有已发布计划，页面显示 "No plan yet"，无法实屏核对；代码走同一个序号入口。
- "补加一个更早的训练日后重排为 D1–D5"：演示数据改不了计划，只有单测覆盖。
- 触发一次真实 e1RM 提升后的训练页与 Progress：没有在模拟器上记组，只有单测覆盖。
- 小屏、大字体、Today 的 Dark。

## 返修第 1 轮

`StudentPlanSequence.dayNumbers(inWeek:)` 原用 `Dictionary(uniqueKeysWithValues:)`，重复 id 会崩溃；改为保留首次出现的序号，并加回归测试。
