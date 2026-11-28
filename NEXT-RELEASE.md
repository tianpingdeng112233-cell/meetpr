# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上，记录下一个内测包的内容与进度。
> 发版模型及权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (44)
- 基底为已上传的 `beta/1.0-43`（`98ba2e5d`）。工程已升至 build 44，等待本班 TestFlight 上传。
- 2026-11-28 David 圈选：本班只发下列 9 项；#496 法律文本重新同意已从发版线撤回（见延期候选）。
- 工具链例外：本机与发布 CI 为 Xcode 26.6 / iPhoneOS SDK 26.5，低于全局规约「1.0(44) 起 Xcode 27 + iOS 27 SDK」；David 2026-11-28 批准 44 再例外一次，门槛顺延到 1.0(45)。[切包记录](docs/journal/2026-11-28-prep-beta-44.md)

## 本版将包含

- **学员训练相册视频导入（P1）**：文件未读完整时自动重读一次，仍缺数据则提示保存完整原片后重选；替换失败保留组内旧视频。与 Android #231 对齐。[验收记录](docs/journal/2026-11-28-ios-incomplete-album-video.md)

- 学员端「休息设置」移除圆盘下方的操作提示。点空白处仍会保存并收起。见 [spec 111](specs/111-rest-timer-ring/SPEC.md)。

- **spec 099 开屏动画（P1，#501，2026-11-28 David 收货并排入下一班）**：冷启动先看到 MeetPR 字标入场和「Meet Every PR Together」，底下一条加载线从左扫到右，共 1.2 秒，首屏就绪后 0.3 秒淡出；首屏没好时加载线继续单向循环。系统启动屏换成同一张底图，交接无跳变；「正在验证会话…」文字去掉。纯客户端，无后端依赖。已验：AppShell 新增 7 条测试绿、iPhone 17e 已登录学员冷启动亲眼看、字标位置与定稿差 1pt 以内；未验：未登录冷启动、弱网时循环加载线的实机画面、后台切回不重播、带历史老账号升级后第一屏。安卓同批 meetpr-rn#229。[定稿与验收](specs/099-launch-animation/SPEC.md) · [实装记录](docs/journal/2026-11-27-099-launch-splash-ios.md)

- **学员端两处显示修复（P1，#497，T1 自合）**：成长 › RPE 对照表顶部的 e1RM 不再显示成一长串小数（如 `178.34793491864840192`），改为和 E1RM 曲线页一样保留 1 位；成长 › 强度指标横轴日期原来写死「日/月」，现在跟随系统地区，中国地区显示 `11/22`。纯客户端，无后端依赖。已验：`RPETableHistoryTests`、`ProgressMetricsTests` 新增回归测试绿，iPhone 17e DemoStudent 亲眼看；未验：英制（lb）下的对照表实机画面。安卓对照表无此问题，横轴日期同批修（[meetpr-rn#232](https://github.com/tianpingdeng112233-cell/meetpr-rn/pull/232)）。[卡](docs/cards/2026-11-27-student-rpe-chat-chart.md) · [排查记录](docs/journal/2026-11-27-student-rpe-chat-chart.md)

- **学员演示包宣发示例数据（不影响正式包，#499）**：`MeetPR-DemoStudent` 带 `-demo-showcase` 启动时换成一份 12 周备赛周期的丰富示例数据，供宣发截图用；顺带把 `RepositoryContracts` 列为 App 直接依赖，演示 scheme 的测试才能链接。正式包行为不变。[卡](docs/cards/2026-11-27-demo-showcase-data.md)

- **学员视频上传时继续播放音乐（P1）**：从打开相机、录制带现场声音的视频，到相册选片、裁剪和上传，允许其他 App 继续播放音乐。[实现与验证](docs/journal/2026-11-28-068-upload-music-ios.md)

- **体重曲线只画线（P1，2026-11-28 David 拍板，T0）**：成长 › 体重的曲线不再给每条记录画圆点，每天称重的学员 90 天视图不再是一排密点；只保留最新一次称重的实心点。纯客户端。已验：iPhone 17e DemoStudent（`-demo-showcase`）30 天视图亲眼看；未验：只有一条记录时的画面（该分支代码未改结构）。无合适测试 seam（图表标记在私有 SwiftUI 视图里）。安卓同批 [meetpr-rn#234](https://github.com/tianpingdeng112233-cell/meetpr-rn/pull/234)。

- **换成定稿字标（P1，#498，2026-11-28 David 放行）**：学员端成长、我的页头字标换成 11/27 定稿图形（18 高，浅色主题浅色版、深色主题暗色版）；登录/注册/忘记密码页 23 高；训练视频角标里的字标换成暗色版 21 高（导出视频烧进去的同一张）。字标资源为矢量 asset（Any + Dark），源文件在 `docs/brand/`。纯客户端。已验：DesignSystem `MeetPRMarkTests` 绿、iPhone 17e 成长/我的浅深两色与登录页浅色亲眼看、macOS 导出帧字标清晰；未验：App 内播放器里的角标实机画面（演示数据没有带角标的视频）、带历史老账号升级后第一屏。角标卡片整体另开会话重新设计，本条只换字标。安卓同批 [meetpr-rn#226](https://github.com/tianpingdeng112233-cell/meetpr-rn/pull/226)。[实装记录](docs/journal/2026-11-27-wordmark-final-ios.md)

- **spec 116 视频角标重做（P1，#508，2026-11-28 David 定稿并放行进本班）**：训练视频上的角标改成左下偏中的半透明小卡——橙色圆盘加纯英文 MEETPR 字标，动作名在上、重量×次数最大、RPE 跟在后面；去掉底部暗渐变、金色 RPE 胶囊和教练名；App 内回放多显示「第 N 组」，点卡片收成圆盘。录完开着「存到相册」时相册里存的是带角标版（后台生成，不耽误回到训练页；失败、中断或切后台约 10 秒未完成则改存原片），传给教练的仍是原片；学员回放页的下载按钮导出带角标版。全屏看教练反馈时，打点列表改为进度条上的金色刻度加浮出点评，画线批注显示时角标让开。顺带修复「看过视频后完成该组，RPE 被存成空」。教练工作台不变，纯客户端，无后端依赖。已验：ChatUI 105、StudentKit 1381、CoachKit 497 项测试绿；整包构建通过；iPhone 17e 亲眼看回放页新角标、收起展开、下载导出入册、打点刻度与点评；macOS 用真实片段导出核过亮、暗、横拍、3:4 成片。未验（需真机）：真机上的带角标成片（模拟器导出不带叠加层，既有现象）、录制 → 预览页角标 → 存相册 → 切后台兜底整条流程、批注显示时角标让开、繁体与英文排版、带历史老账号升级后第一屏。安卓同批 [meetpr-rn#236](https://github.com/tianpingdeng112233-cell/meetpr-rn/pull/236)。[规格与验收清单](specs/116-video-badge/SPEC.md) · [实装记录](docs/journal/2026-11-28-116-video-badge-ios.md)

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23)、10-18 收尾 1.0(24)、1.0(25)、11-02 收尾 1.0(30)、11-04 收尾 1.0(31)、11-05 收尾 1.0(32)、11-07 收尾 1.0(33)、11-08 收尾 1.0(35)、11-11 收尾 1.0(37) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

- **#496 法律文本 v2026-12-01 与重新同意（iOS）**：首启提示同时列隐私政策与用户协议、法律版本变化时老用户重新同意、国内/Global 登录页与教练「我的」加用户协议链接。原提交 `44ab7fb1` 已落线，2026-11-28 David 圈选 1.0(44) 时决定不随本班发，已在发版线 revert。重新上车 = revert 那笔 revert，并重跑 AppShell/CoachKit 测试（CoachRootView 与 #508 有相邻改动）。线上 `meetpr.app/terms` 已是 v1.0、2026-12-01 生效。[实装记录](docs/journal/2026-11-24-legal-consent-ios.md)

- **iOS 切域名 `https://app.meetpr.cn`(C 序列第 2 步,T1)**:BuildConfig
  `productionBackendBaseURL` http://IP:3000 → https 域名 + 收 ATS 明文豁免;
  **硬前置 = 阿里云接线落地**(DNS/证书/CLB 443,David 手动,HTTPS 陪跑会话在办)。
  旧 hold/https-migration-2026-07-09 分支不复活,发版线重做。
- **spec 062 学员端统一收件口**:SPEC 已落仓(8639ce9,Draft/T3),实装未开工,待排期。
- **学员端 wellness 五档量表 + energy 档(PR #273,CI 绿)**:硬前置 backend #95(迁移 0047)
  合并+部署 staging,否则旧后端 `.strict()` 把 `energy` 400 掉。顺序:#95 → 部署 → #273。
  另有 chip 观感待 David 看截图定。
- ~~spec 061 补练/事后顺延~~:已作废(08-07 被推进制换制取代,#275/#104 已关,防复活)。

## 📋 长期挂账(每次切包前复核)
- [ ] **推进制老包尾巴(P0 2026-08-10 后续)**:≤1.0(17) 学员练完不写 completion(auto 已下线),
      拖久了升级即游标回卷小号复发(0059 只回填到 08-09)。止血=催升级;根治随 W2 教练分诊
      重定义一并拍(必要时二次回填)。事故与修复台账见 backend db/MIGRATIONS-APPLIED.md 0059 条。
- [ ] 067 APNs 验收:既有 APNs Auth Key 已存 Bitwarden；09-14 预检 SAE 的 PUSH_ENABLED=true、五个 APNS_* 存在，
      但 APNS_ENV=sandbox；TestFlight production 配置与实际送达待验收。
- [ ] 捞回队列余项:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] 注册页「学员 · 自己练」空壳待拍板:发版线上是否先藏起这一档(solo 波冻结在 main)。
      详见 RELEASES.md 1.0(14) §已知问题
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [x] CI 减灾:本机磁盘定期清扫 ✅2026-08-21 已上线(launchd `com.david.disk-janitor` 每小时,
      清扫四类白名单+15G 水位通知;实装在 ~/ClaudeConfig 33036e0,卡见 scratch/card-disk-janitor-2026-08-21.md)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
