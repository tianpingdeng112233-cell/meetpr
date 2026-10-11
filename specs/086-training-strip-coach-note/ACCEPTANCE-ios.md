# Spec 086 · iOS 收货记录 · 2026-10-10

卡：[CARD-ios](CARD-ios.md)（含修订一）。基线 `release/1.0@a36e1f13`，分支 `feat/086-training-strip-coach-note`。实装方 Codex，收货方 Opus。返修 0 轮（开工核对停过一次，裁定见卡的修订一；收尾因用量上限中断过一次后续跑完成）。

## 自动检查（收货方在本机复跑）

- `swift test --package-path Modules/StudentKit`：937 项全部通过（新增 5 项，既有断言零删改）。只动了 StudentKit，其余包没有重跑。
- `swift-format lint --strict` 与 `swiftlint lint --strict`：0 违规（以 Codex 交付日志为准，提交时的 pre-commit 钩子再跑一遍）。
- 全量 diff 已读：两轴结论——Standards 无问题；Spec 无缺做、无多做。

## 实屏

收货方亲看：iPhone Air 模拟器（iOS 26.4），`MeetPR-DemoStudent`，启动参数 `--spec086-behind --spec086-long-note`，英文浅色。其余形态看的是 Codex 在 iPhone 17e 上留的截图。

| 验收项 | 结论 |
|---|---|
| 1 格子内容 | 通过。训练日格 = 星期 / 状态图形 / 第三行，没有 D 序号；休息格 = 星期 + Rest，没有日期。[落后](evidence/opus-behind-en.png)、[正常](evidence/final-normal-en-light.jpg) |
| 2 第三行三种情况 | 通过。已完成显示日期；没到期显示日期；过期未完成显示 `Behind`，金棕色 |
| 3 不留旧日期、不拦操作 | 通过。落后时周条与[只读预览](evidence/behind-preview.jpg)都看不到旧推荐日期；可照常开练 |
| 3b 落后天数 | 通过。当前周胶囊 `18 days behind`；读屏标签实测为 `W1D3, Tue, behind schedule`、`W1D1, Fri 9/18`。0 / 1 / 18 / 123 天文案由单测覆盖 |
| 4 版式 2B | 通过。周次、胶囊、进度与 `Training history ›` 同一行；箭头在格子两端（28×64）；没有周数小点 |
| 5 翻周与选中 | 以 Codex 实操记录与截图为准，收货方未逐项重做 |
| 6 一周超过 7 天 | 通过。[后移场景横向滚动](evidence/shifted-scroll-zh-light-large.jpg) |
| 7 hero 备注 | 通过。淡金块在动作名下、标题 `Coach note`、长备注全文显示；[没有动作备注时没有淡金块](evidence/hero-no-exercise-note.jpg)。[截图](evidence/opus-hero-note-en.png) |
| 8 组级备注 | 通过。组级备注在卡片下方小灰字块；[只读态](evidence/completed-readonly.jpg)保持 iOS 改前行为（只显示动作备注） |
| 8b 圆点大小 | 通过。实心 / 空心 8、对勾 12，三种状态可区分 |
| 9 老用户第一屏 | 以 Demo 场景覆盖：落后 18 天与进度正常两种形态首屏正确；不是对真实账号做覆盖安装 |
| 10 主题与小屏大字号 | 中文浅色、英文深色 + `accessibility-large` 下三位数天数完整同排。[中文](evidence/final-behind123-zh-light-large.jpg)、[英文深色](evidence/final-behind123-en-dark-large.jpg) |
| 默认 Demo 首屏不变 | 通过。[不带参数启动](evidence/default-demo-first-screen.jpg) |

## 与安卓不同、需要知道的两处

- **只读态备注**：安卓只读态是「组级备注，没有才显示动作备注」，iOS 只读态一直只显示动作备注，本次按「不在范围」保持 iOS 现状。
- **可编辑态新增组级备注小灰字**：iOS 的 hero 卡以前从不显示组级备注，现在与安卓一致地显示。旧表格导入留下的组级说明、网页编辑器写的自重标记会因此出现在卡片下方（标题同为 `Coach note`）。

## 没验到的

- iPhone SE：本机没有 SE 模拟器，用最小可用的 iPhone 17e 代替。
- 真实账号覆盖安装升级；真实时间跨过凌晨 4 点（03:59 / 04:00 只有单测）。
- 同一训练日里两条不同的非空动作备注之间切换（Demo 数据到不了，取值无缓存、由单测覆盖）。
- CN 轨与 Global 轨正式包各自构建（实现没有按轨分支）。

## 范围外、未处理的既有问题

`accessibility-large` 下页头字标显示成 `ME…R`、概览卡动作名词内换行、大号重量 `175` 折行。均为改前就有，记在 JOURNAL。
