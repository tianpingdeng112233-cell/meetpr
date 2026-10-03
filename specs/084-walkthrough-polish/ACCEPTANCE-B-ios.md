# Spec 084 · 卡 B（iOS）收货记录 · 2026-10-02

卡：[CARD-B-ios](CARD-B-ios.md)。分支 `feat/084b-week-strip-login`，叠在卡 A（PR #347）之上。实装方 Codex，收货方 Opus。返修 1 轮。

## 自动检查（收货方在本机复跑）

- `swift test`：StudentKit 912、AppShell 104 全部通过。Codex 沙箱里的视频编码 / Keychain 失败在本机不复现。
- `swiftlint lint --strict` 与 `swift-format lint --strict`：0 违规。
- 其余包与主工程测试没有重跑，以 Codex 的 JOURNAL 记录为准。

## 实屏（iPhone 17 模拟器，MeetPR-DemoStudent，演示计划共 2 周）

| 验收项 | 结论 |
|---|---|
| 训练页无 Plan summary | 通过 |
| 周条三行结构 | 通过。换周行（箭头｜W{n} + 状态胶囊 + 已完成数 / 总数｜箭头）、训练日行、周数小点。[当前周](evidence/b-week-strip-current-week-light.png) |
| 翻周 | 通过。右箭头到 W2 后右箭头置灰；W1 时左箭头置灰；在周条上左滑与右箭头等效；小点里正在看的周是拉长的深色点，离开当前周后当前周的点是金色。[其他周](evidence/b-week-strip-other-week-preview-light.png) |
| 选中与当前训练日分开 | 通过。当前训练日整格淡金底、日期金色加粗；选中是深色粗框并跟随点选；两者同时出现时都可辨 |
| 翻到其他周 | 通过。页头右侧换成 "Back to today"，标题为所选那天的 W#D#；未来训练日是只读预览（推荐日期、训练日名称、动作数与组数、动作行、解锁说明），没有开练按钮 |
| Back to today | 通过。回到 W1 并选中当前训练日 |
| Light / Dark | 都看过，Dark 截图是返修前的（字体问题见下） |

## 没验到的

- **登录页（§1）没有实屏核对。** 只有 Global 包展示这个登录页，而 Global 包首次启动有一层 "About usage data" 告知弹层，需要点 "Got it" 才能看到完整页面，收货方没有代点。顺序由 `GlobalAuthViewTests` 与 diff 确认：邮箱、密码、Sign in、两个文字链接、or、Apple、Google。Apple 按钮改为与 Google 同高、同圆角、带描边，Light 用白底描边样式、Dark 用黑底样式。
- 已完成训练日的展示、完成一天后回到当前训练日、切 tab 回来回到当前训练日：读代码确认（切到训练 tab 时触发回到当前训练日），没有逐项点。
- 超过 8 周不画小点：单测覆盖，演示计划只有 2 周。
- 小屏与大字体。
- 记组、休息计时、补录流程的回归：没有在模拟器上走，依赖现有测试。

## 返修第 1 轮

1. 新周条、预览卡与 "Back to today" 首轮用了系统文字样式，屏幕上是 SF 字体，与页面其余文字不是一套。已全部改为仓内字体 token。
2. 首轮多加了下拉刷新。那是卡面笔误带出来的，训练页原本只有页头刷新按钮，已去掉；点刷新按钮后回到当前训练日的行为保留。

## 追加：7 天日历格（2026-10-03）

David 真机复验反馈"看不出哪天休息"，§4 修订为连续日历格（SPEC 末尾）。DemoStudent 实屏通过：演示计划本周训练日在周三至周六，周条 7 格为 Wed D1、Thu D2、Fri D3、Sat D4、Sun / Mon / Tue Rest；休息格较窄、灰底、不可点。[截图](evidence/b-week-strip-seven-days.jpg)。StudentKit 测试与两个 lint 在叠加后的顶层分支上复跑通过（929 项）。小屏、大字体、超过 7 格的横向滚动只有单测或未验。
