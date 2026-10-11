# Spec 089 · iOS 收货记录 · 2026-10-10

卡：[CARD-ios](CARD-ios.md)（含修订一）。分支 `feat/089-accessory-quick-log`，叠在 `feat/086-training-strip-coach-note` 上。实装方 Codex，收货方 Opus。返修 1 轮。开工与实装中停过三次，裁定见下。

## 自动检查（收货方在本机复跑）

- `swift test --package-path Modules/StudentKit`：955 项全部通过（本卡新增 18 项，既有断言零删改）。CoreModels 158 项以 Codex 记录为准（本卡对它只读）。
- `swift-format lint --strict` 与 `swiftlint lint --strict`：0 违规（提交时 pre-commit 钩子再跑一遍）。
- 全量 diff 已读：Standards 无问题；Spec 返修后无缺做、无多做。

## 收货时退回的一处（已修）

Codex 第一版把「辅助项 RPE 不预填」改在了训练页与补记页共用的草稿上，补记（spec 081）里辅助项行的 RPE 因此从「处方值，没有则 8」变成空。安卓的共用草稿没有这个变化。返修后：未记录行的默认值恢复原样（补记、完整录入的初值与改前相同）；「RPE 留空」只在辅助项记录卡自己的行逻辑里；已用本卡记过且 RPE 为空的组，重新加载和覆盖后仍为空。补了一条先红后绿的补记测试守住它。[补记页](evidence/r1-default-demo-quicklog-rpe.jpg)、[记录卡](evidence/r1-accessory-empty-rpe-placeholder.jpg)

## 三处裁定

1. **休息时长存哪**：辅助项时长用独立新键 `meetpr.student.rest_timer.accessory_seconds.<studentID>`，主项那个键的读写一行不改。老用户的主项设置不受影响；新键缺失或脏值按 60 秒。
2. **动作库查不到的计划动作**：保持 iOS 现状（不展示），本卡不改。判定只认 `exerciseType == .accessory`，类型不明的不会被当成辅助项。
3. **软键盘**：实装方没有权限在模拟器里打开软键盘，这一项留给收货方，见「没验到的」。

## 实屏

收货方亲看：iPhone Air 模拟器（iOS 26.4），`MeetPR-DemoStudent`，启动参数 `--spec089-accessory`，英文浅色——辅助项记录卡的六列、RPE 留空与占位、组级备注小灰字、提示行与主按钮。其余形态看的是 Codex 在 iPhone 17 上留的截图。

| 验收项 | 结论 |
|---|---|
| 1 何时出现 | 通过。轮到辅助项时 hero 卡是行内表格；[主项的 hero 卡与改前一致](evidence/main-hero-unchanged.jpg)。[记录卡](evidence/opus-accessory-card-en.png) |
| 2 预填 | 通过。预填教练处方；[纯 RPE 处方的组重量为空、占位是上次重量](evidence/rpe-empty-weight.jpg)；[自重组显示 BW](evidence/bodyweight-en-dark-large-rows.jpg) |
| 3 点 ✓ 记录 | 通过。行变已完成；写入走完整录入的同一条路径（假仓库断言）。没有连真实教练账号核对 |
| 4 RPE | 通过。没填时请求里不带 RPE；占位显示教练预设，处方是 RIR 时显示 `RIR n` |
| 5 取消 | 通过。再点 ✓ 写回未完成，[重量次数保留](evidence/cancel-retains-values.jpg)；[带视频的组不能取消并有提示](evidence/video-cancel-blocked-zh.jpg)；附件还没读完或读取失败时同样不发出取消（单测） |
| 6 改数字后覆盖 | 通过 |
| 7 点组号进完整录入 | 通过（进入、标记失败、返回）。真实拍摄或选片上传后回来的整条链路没验 |
| 8 全部按计划完成 | 通过。[跳过空重量的行并提示还剩几组](evidence/batch-skipped-two.jpg)；[全部记完不起计时](evidence/batch-complete-no-timer.jpg)。中途失败后已写的保留、可重试，由假仓库断言覆盖 |
| 9 休息 | 通过。默认 60 秒；[设置页改成 1:30](evidence/settings90-en.jpg) 后生效；[教练设了 75 秒时用教练的](evidence/coach75-priority.jpg)；最后一组不起计时；主项规则不变 |
| 10 老用户第一屏 | 通过（Demo 场景 + 单测）。[训练到一半](evidence/upgrade-zh-lb-large-rows.jpg)：已记的组、视频标记都在，剩余组可继续；改前格式的休息设置（含更早的整数格式）读回与改前相同，辅助项为 60 |
| 11 结算 | 通过。长按结算、庆祝页、撤销与改前一致 |
| 12 主题、大字号、磅 | 中文浅色磅单位与英文深色自重组在 `accessibility-large` 下六列完整。软键盘避让见下 |
| 默认 Demo 首屏不变 | 通过。[不带参数启动](evidence/default-demo-first-screen.jpg) |

## 与安卓不同、需要知道的

- 动作库查不到的计划动作：安卓让它走完整录入，iOS 的既有逻辑是不展示，本卡未改。
- 辅助项以前会被自动套上主项的 180 / 240 秒休息默认值；现在只有教练明确设了才用教练的，否则是学员的辅助项设置（默认 60 秒）。这是本 spec 的口径，但对老用户是一处看得见的变化。

## 没验到的

- **键盘弹出时当前行不被遮住**：模拟器里点输入框后，界面元素树显示当前行上移到键盘工具条上方，但没能截到软键盘在场的画面，不能算实屏通过。需要真机确认。
- 真实视频拍摄或上传后回到记录卡；锁屏实时活动（Live Activity，锁屏与灵动岛上的倒计时卡片）上的辅助项时长，只有同源断言。
- iPhone SE；真实账号覆盖安装升级；真实断网。

## 范围外的观察

模拟器连着硬件键盘时，键盘工具条的 `Done` 会变成右下角一个悬浮小按钮并被截成 `D…`。只在接了外接键盘的设备上出现，未处理。
