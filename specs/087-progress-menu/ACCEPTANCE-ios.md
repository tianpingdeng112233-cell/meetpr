# Spec 087 · iOS 收货记录（第一步）· 2026-10-10

卡：[CARD-ios](CARD-ios.md)。分支 `feat/087-progress-menu`，叠在 `feat/085-today-final-walkthrough` 上。实装方 Codex，收货方 Opus。返修 0 轮。只做第一步：体重行与体重页不在本次。

## 自动检查（收货方在本机复跑）

- `swift test --package-path Modules/StudentKit`：948 项全部通过（本卡新增 6 项，既有断言零删改）。
- `swift-format lint --strict` 与 `swiftlint lint --strict`：0 违规（提交时 pre-commit 钩子再跑一遍）。
- 全量 diff 已读（Total 序列、入口行取值、通用行组件逐行看过）：Standards 无问题；Spec 无缺做、无多做。

## 改前基线（默认 Demo，动手前记的）

Squat 187.5、Bench press 118.6、Deadlift 178.5；Big-three e1RM total 484.6 kg；Training 1RM total 520 kg；训练 2 次、1 周、总容量 3,525 kg；反馈 3 条、2 条未读；强度未解锁。[改前首屏](evidence/baseline-progress-top.jpg)、[对比两格](evidence/baseline-comparison.jpg)、[三格统计](evidence/baseline-stats.jpg)

## 实屏

收货方亲看：iPhone Air 模拟器（iOS 26.4），`MeetPR-DemoStudent`，启动参数 `-spec087-progress squat-only`，英文浅色——入口页、e1RM 页 Total 段、点 Total 曲线节点。其余形态看的是 Codex 在 iPhone 17e 上留的截图。

| 验收项 | 结论 |
|---|---|
| 1 入口页 | 通过。页头 + 四行，没有任何图表与统计格。[英文](evidence/opus-menu-squat-only-en.png)、[默认 Demo](evidence/default-menu-en.jpg)、[中文](evidence/default-menu-zh.jpg) |
| 2 四行右侧值 | 通过。有值与 `—` 各看过；`1 session` / `{n} sessions`、`{n} new` 用复数变体。[缺一项时](evidence/missing-menu.jpg) |
| 3 四段与时间范围 | 通过。默认 Total；切段后范围不重置；返回再进回到 Total（单测 + Codex 实操） |
| 4 Total 段 | 通过。用「只更新了深蹲」的场景手算：最近一天深蹲 160，卧推最新点 101、硬拉最新点 202，曲线末点 463；大号数字 467 = 三段大号数字 160 + 102 + 205，与入口页那一行、下方对比格相同（回落期两者可以不等，是 spec 的口径）。点曲线节点没有反应，没有「点选节点」提示。[截图](evidence/opus-e1rm-total-squat-only-en.png)；[三项未齐的空态](evidence/missing-total.jpg) |
| 5 对比两格 | 通过。只在 Total 段出现 |
| 6 三段单项 | 通过。四种状态与来源弹层沿用原卡。[Squat 段](evidence/default-squat.jpg) |
| 7 历史记录页三格 | 通过。数值与改前基线一致（2 / 1 / 3,525 kg）。[截图](evidence/default-history.jpg) |
| 8 教练反馈行 | 通过。进现有反馈页，未读数与该页一致，读完返回后随之变化。[截图](evidence/default-feedback.jpg) |
| 9 强度指标页 | 通过。[未解锁态](evidence/default-intensity-locked.jpg)沿用现有说明；有数据的柱与线见 `squat-only` 场景 |
| 10 加载与失败 | 通过。失败时行仍在、可点，列表下方有重试。[截图](evidence/failure-menu.jpg) |
| 11 老用户第一屏 | 默认 Demo 改后四行的值与改前基线逐一相同（Total 484.6、2 sessions、2 new）。默认 Demo 只有一周两次训练，多周形态用 `squat-only` 场景看的，不是同一账号的改前改后对照 |
| 12 主题与大字号 | 中文深色 + `accessibility-large` 下名称与值不重叠，放不下时值整体落到下一行。[截图](evidence/menu-zh-dark-large.jpg) |

## 实装中发现并修掉的一处

Total 曲线最初用图表的节点标注画空心点，在 iOS 26.5 上切时间范围会让页面失去响应。改成两层点标记后恢复。这类挂起单测抓不到，只有实屏能看出来。

## 与安卓不同、需要知道的

- 对比两格下面 iOS 原来就有三项的逐项进度条，按「现有组件原样搬入」保留；安卓没有这三条。
- 强度图沿用 iOS 现有画法。

## 给 088 用的通用行

`StudentMenuRow(icon:title:value:valueColor:action:)` 在 `Features/Shared/`。名称与值一行放不下时，值整体落到名称下一行、左对齐，不截断。

## 没验到的

- 同一个真实账号改前改后的多周数据对照；真实账号覆盖安装升级。
- iPhone SE（用最小可用的 iPhone 17e 代替）。
