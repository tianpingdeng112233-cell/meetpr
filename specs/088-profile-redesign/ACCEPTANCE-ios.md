# Spec 088 · iOS 收货记录（第一步）· 2026-10-10

卡：[CARD-ios](CARD-ios.md)。分支 `feat/088-profile-redesign`，叠在 `feat/087-progress-menu` 上（其下是 085）。实装方 Codex，收货方 Opus。返修 1 轮（两处大字号排版）。只做第一步：头像上传与教练端头像不在本次。

## 自动检查（收货方在本机复跑）

- `swift test --package-path Modules/StudentKit`：956 项全部通过（本卡新增 8 项，既有断言零删改）。`Modules/AppShell` 107 项通过（只加了一个把登录标识传给学员端的参数）。
- `swift-format lint --strict` 与 `swiftlint lint --strict`：0 违规（提交时 pre-commit 钩子再跑一遍）。
- 全量 diff 的非界面部分已读（登录标识接线、档案加载状态、打卡弹层、账号弹层、Tab 栏在二级页隐藏）：Standards 无问题；Spec 返修后无缺做。多出的一处见下「需要知道的」第一条。

## 实屏

实装方的第一轮截图因两个作业共用一台模拟器而作废，之后在专用设备上重跑。收货方亲看：iPhone 17 Pro 模拟器（iOS 26.4）默认字号英文浅色的首屏与 Settings 页；iPhone 17e 模拟器（iOS 26.5）`accessibility-large` 下的长邮箱场景，英文浅色与中文深色。其余形态看的是 Codex 的截图。

| 验收项 | 结论 |
|---|---|
| 1 首屏 | 通过。页头 + `My profile` + 身份摘要卡 + 五行，没有小标题、胶囊、内嵌控件、退出按钮；iPhone 17 Pro 默认字号下不滚动能看到全部五行。[英文](evidence/opus-home-pro-en.png)、[中文](evidence/home-zh.jpg) |
| 2 身份卡 | 通过。手机号登录：名字位是手机号、头像位是人像图标；[邮箱登录](evidence/identity-email.jpg)：邮箱 + 首字母；[没有已通过的绑定](evidence/identity-no-coach.jpg)：教练行不出现。头像位不可点 |
| 3 四格 | 通过。180 / 120 / 220 / 520 与改前 1RM 卡一致，格内不写单位；[缺一项](evidence/missing-lift.jpg)时该格与 Total 为 `—`；点四格或锁定说明弹出现有说明 |
| 4 五行右侧值 | 通过。有值与[无值](evidence/state-unanswered.jpg)各看过 |
| 5 二级页 | 通过。[About me](evidence/about-en.jpg) 四行、[Health & recovery](evidence/health-en.jpg) 两行，逐行打开的都是现有编辑页；改体重保存后二级页与首屏即时更新 |
| 6 「改动会通知教练」 | 通过。[伤病编辑页](evidence/editor-injuries.jpg)与[状态打卡弹层](evidence/readiness-profile-save.jpg)的保存按钮上方有那一行灰字；其余编辑页没有 |
| 7 Settings | 通过。外观三块立即生效且重启后保持；组间休息、训练提醒进现有设置页；改密码、导出、删号三个弹层能打开（[删号只走到输入确认前](evidence/account-delete-before-confirmation.jpg)）；`Sign out` 回到登录页。[截图](evidence/opus-settings-pro-en.png) |
| 8 从 Today 直达 | 通过。体重卡与 Meet 卡直接打开各自编辑页，保存后回 Today，不经过二级页 |
| 9 加载中、失败、无档案 | 通过。三种状态下都能进 Settings 并退出登录；[失败时](evidence/state-failure.jpg)其余四行点了不崩；[刷新失败时保留已显示的值](evidence/refresh-failure-retained.jpg) |
| 10 老用户第一屏 | 通过（同一台模拟器先装改前的包、再覆盖安装新包，不卸载不清数据）。改前 Profile 的每一行在新结构里都有入口，对照表在 JOURNAL「改前每一行 → 改后入口」。[改前上](evidence/baseline-top.jpg)、[中](evidence/baseline-middle.jpg)、[下](evidence/baseline-bottom.jpg)。不是对真实账号做覆盖升级 |
| 11 小屏大字号 | 返修后通过。四格数字同一字号、标签与数字各自对齐；行内的值只在 ` · ` 处折行，数字与单位不拆开；长邮箱与长教练名截断正常。[英文浅色](evidence/r1-17e-en-light-large.jpg)、[中文深色](evidence/r1-17e-zh-dark-large.jpg)；[默认字号没有变化](evidence/r1-pro-en-light-default.jpg)；[087 的入口行没被带坏](evidence/r1-17e-progress-squat-only-large.jpg) |

## 需要知道的

- **「删除账号」入口回到了学员端**。iOS 学员端从 2026-07-27 的改版起不显示这个入口（代码里是显式关掉的），安卓定稿的 Settings 页有它，本卡按定稿放了回来，复用原有的删号流程。若 iOS 仍想隐藏，一行开关即可。
- 名字位第一步显示登录标识：CN 轨是手机号，所以绝大多数学员看到的是「手机号 + 人像图标」，要等第二步（后端下发名字）才会变成名字。
- 二级页用系统导航栏（标题居中、左滑返回），进入后隐藏底部 Tab 栏，与 iOS 现有整页编辑页一致。
- `Sign out` 仍是直接退出、没有二次确认（现状），只是从红色实心按钮变成了页底的描边按钮。

## 没验到的

- 真实账号覆盖安装升级；CN 轨与 Global 轨正式包各自的登录标识（用 Demo 场景的手机号与邮箱两种形态代替）。
- iPhone SE（用 iPhone 17e 代替）。

## 范围外、未处理的既有问题

英文训练环境摘要拼成 `weekMon·Wed·Fri·Sat`；英文伤病摘要 `Shoulders injuries`；改密码与删号弹层的系统 Cancel 按钮在窄屏下被截断；大字号下页头字标显示成 `ME…R`。
