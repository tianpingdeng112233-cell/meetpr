# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上，记录下一个内测包的内容与进度。
> 发版模型及权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (44)
- 基底为已上传的 `beta/1.0-43`（`98ba2e5d`），当前工程 build 为 43。升号前按全局规约核验归档机与发布 CI 的 Xcode 和 iPhoneOS SDK。

## 本版将包含

- **spec 099 开屏动画（P1，#501，2026-11-28 David 收货并排入下一班）**：冷启动先看到 MeetPR 字标入场和「Meet Every PR Together」，底下一条加载线从左扫到右，共 1.2 秒，首屏就绪后 0.3 秒淡出；首屏没好时加载线继续单向循环。系统启动屏换成同一张底图，交接无跳变；「正在验证会话…」文字去掉。纯客户端，无后端依赖。已验：AppShell 新增 7 条测试绿、iPhone 17e 已登录学员冷启动亲眼看、字标位置与定稿差 1pt 以内；未验：未登录冷启动、弱网时循环加载线的实机画面、后台切回不重播、带历史老账号升级后第一屏。安卓同批 meetpr-rn#229。[定稿与验收](specs/099-launch-animation/SPEC.md) · [实装记录](docs/journal/2026-11-27-099-launch-splash-ios.md)

- **学员端两处显示修复（P1，#497，T1 自合）**：成长 › RPE 对照表顶部的 e1RM 不再显示成一长串小数（如 `178.34793491864840192`），改为和 E1RM 曲线页一样保留 1 位；成长 › 强度指标横轴日期原来写死「日/月」，现在跟随系统地区，中国地区显示 `11/22`。纯客户端，无后端依赖。已验：`RPETableHistoryTests`、`ProgressMetricsTests` 新增回归测试绿，iPhone 17e DemoStudent 亲眼看；未验：英制（lb）下的对照表实机画面。安卓对照表无此问题，横轴日期同批修（[meetpr-rn#232](https://github.com/tianpingdeng112233-cell/meetpr-rn/pull/232)）。[卡](docs/cards/2026-11-27-student-rpe-chat-chart.md) · [排查记录](docs/journal/2026-11-27-student-rpe-chat-chart.md)

- **学员演示包宣发示例数据（不影响正式包，#499）**：`MeetPR-DemoStudent` 带 `-demo-showcase` 启动时换成一份 12 周备赛周期的丰富示例数据，供宣发截图用；顺带把 `RepositoryContracts` 列为 App 直接依赖，演示 scheme 的测试才能链接。正式包行为不变。[卡](docs/cards/2026-11-27-demo-showcase-data.md)

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23)、10-18 收尾 1.0(24)、1.0(25)、11-02 收尾 1.0(30)、11-04 收尾 1.0(31)、11-05 收尾 1.0(32)、11-07 收尾 1.0(33)、11-08 收尾 1.0(35)、11-11 收尾 1.0(37) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

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
