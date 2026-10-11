# Spec 085 · iOS 收货记录 · 2026-10-10

卡：[CARD-ios](CARD-ios.md)（含修订一）。基线 `release/1.0@a36e1f13`，分支 `feat/085-today-final-walkthrough`。实装方 Codex，收货方 Opus。返修 1 轮（`Remove meet` 颜色、体重单项页字段标题）。开工核对停过一次，裁定见卡的修订一。

## 自动检查

- `swift test --package-path Modules/StudentKit`：942 项全部通过（新增 10 项）。收货方在返修前于本机沙箱外复跑 942/942；返修后的 942/942 以 Codex 的 JOURNAL 为准。Codex 沙箱内视频导出类用例报过 `Cannot Encode`，沙箱外不复现，属沙箱编码环境问题。
- `swift-format lint --strict` 与 `swiftlint lint --strict`：0 违规（提交时 pre-commit 钩子再跑一遍）。
- 改过的既有断言 8 条，全部是本 spec 的新口径（体重两位小数、体重卡进单项页、Meet 行的写法、第 7 步不再因没回答是否备赛而拦截），逐条依据在 JOURNAL。
- 全量 diff 已读：Standards 无问题；Spec 返修后无缺做、无多做。

## 实屏

收货方亲看：iPhone Air 模拟器（iOS 26.4），`MeetPR-DemoStudent`，启动参数 `-spec085-profile legacy`，英文浅色——Today 首屏、点选 D2、老用户的 Meet 编辑页。其余形态看的是 Codex 在 iPhone 17e 上留的截图。

| 验收项 | 结论 |
|---|---|
| 1a 周条两种标记 | 通过。选中 = 深色粗框白底，当前训练日 = 淡金底金色圆点，两者分开。[点选 D2](evidence/opus-today-legacy-select-d2.png) |
| 1b 概览卡与跳转 | 通过。卡内只有名称、状态小标、动作数与组数、一行动作名；点卡进训练页并选中同一天，训练页已在内存里时同样生效。[从 Today 进 D4](evidence/training-handoff-d4.jpg) |
| 1c 页头与 Start training 不跟点选走 | 通过。训练页先翻到别的周，再点 Today 的 Start training 或训练 tab，都回到当前训练日所在周（Codex 实操记录） |
| 1d 已完成的日子 | 通过。可选中并显示 `Completed`；当天结算后概览卡仍在 |
| 2a 体重单项页 | 通过。只有一个输入框，第三位小数输不进去，保存后 Today 显示两位小数。[英文](evidence/r1-weight-en-light.jpg)、[中文深色](evidence/r1-weight-zh-dark.jpg) |
| 2b 磅 | 通过（英文）。`183.25 lb` 存成 `83.12 kg`，再打开仍是 `183.25`，再保存 kg 不变。[读回](evidence/weight-lb-readback.jpg) |
| 2c Basic information | 通过。同一输入规则，摘要两位小数 |
| 3a Meet 编辑页 | 通过。没有是 / 否题与留言框；保存后 Today 显示倒数与 `IPF · 83 kg`；[教练端看到同一段文字](evidence/coach-meet-formatted.jpg) |
| 3b 级别表 | 通过。四家 × 男女八张表与正文逐格一致（单测逐格断言）；性别为 other 时可切 Men / Women。[IPL 女子](evidence/meet-ipl-women-zh-dark-large.jpg) |
| 3c 必填与换赛事方 | 通过。换赛事方清掉级别；缺项时标红并提示、不保存。[截图](evidence/meet-switch-clears-class.jpg) |
| 3d Remove meet | 通过。红色文字入口，有确认框，确认后 Today 回到 `Not scheduled`。[英文](evidence/r1-meet-en-light.jpg)、[中文深色](evidence/r1-meet-zh-dark.jpg) |
| 3e Profile 两行 | 通过。`Meet` 与 `Note to coach` 各进各的编辑页，原留言原样可见。[截图](evidence/profile-split-rows.jpg) |
| 3f 引导第 7 步 | 通过。不展开可完成；展开后缺项不能继续。[收起](evidence/onboarding-step7-collapsed.jpg)、[缺项](evidence/onboarding-step7-incomplete.jpg) |
| 3g 营养占位卡 | 通过。在体重 / Meetday 行下面，四格与 `Coming soon`，不可点。[中文深色大字号](evidence/today-zh-dark-large-fixed.jpg) |
| 4 老用户第一屏 | 通过（Demo 场景 + 单测）。手填 `83kg`：Today 与编辑页的 `Previously entered: 83kg` 都在，取消不改；[从未回答](evidence/unanswered-first-screen.jpg)与[有备赛无日期](evidence/no-date-first-screen.jpg)显示 `Not scheduled`；体重 `83.5` 显示 `83.50`。留言都在 |
| 5 主题与小屏大字号 | 中文深色 + `accessibility-large` 下 Today、体重页、八张级别表已看；没有穷举全部组合 |

## 与安卓一致、但值得知道的一处

Basic information 页体重为空时不能保存（要改身高也得先填体重）。核对过安卓 `137d816` 的同一页也是这样，所以保持一致没有放开。

## 修订一带来的训练页改动

从 Today 交给训练页的指定训练日以前会被重置回当前训练日。本卡在接收端做了最小修复：带指定日进入就选中那一天；不带指定日的跳转（训练 tab、Start training、通知）仍回到当前训练日。

## 没验到的

- iPhone SE：本机没有 SE 模拟器，用最小可用的 iPhone 17e 代替。
- 中文系统键盘下的小数输入：自动化没能驱动中文键盘，只验了英文键盘与逗号地区的单测。
- 真实投递并点开一条系统通知后的跳转（只有调用链核对与单测）。
- 新用户走完引导后进入 Today 的整条链路：Demo 在引导完成后停在「等待教练接受」，Today 展示由已绑定的 Demo 与单测覆盖。
- 真实账号覆盖安装升级；真实后端上学员保存 → 教练端同步（两端 Demo 是各自的内存数据）。
