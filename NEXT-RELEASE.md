# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (24)
- 基底：`beta/1.0-23` @ `4e97a489`；David 于 2026-10-01 确认 1.0(23) 已 Archive 上传，内容已挪入 [RELEASES.md](./RELEASES.md)。
- build 号：24（尚未 bump，切包时用 agvtool 单源更新），marketing version 保持 1.0；原 23 tag 不变。
- 发版线：`release/1.0`；截至 2026-10-03 tip `40dfe751`，落线候选见下。
- 落线 ≠ 自动进包：切包前由 David 圈选；延期候选不自动进入本包。

## 本版将包含
- **spec 084 走查口径调整（#347 / #348 / #349，T2·P1，2026-10-03 落线 `40dfe751`，David 当日放行）**：安卓真机走查后两端同步的调整。
  - 卡 A（#347）：W#D# 改为"本周第几练"序号；Meetday 卡与体重卡可点进编辑页；删 e1RM 祝贺横幅；训练提醒默认日取教练计划的训练日。
  - 卡 B（#348）：登录页顺序调整（邮箱密码在上、第三方登录在下）；周条改 7 天日历格并可翻周；删 Plan summary。
  - 卡 C（#349）：Ask coach 选组页；聊天训练卡；组录入页视频原地播放（含中央播放按钮、倍速、放大）；休息说明。
  - 证据：[SPEC](specs/084-walkthrough-polish/SPEC.md) 与同目录各卡收货记录。只在模拟器用 Demo 数据验过；Global 包登录页 2026-10-03 已在模拟器实屏核对顺序。
- **长按完成后立即弹奖励页、后台同步（#350，T1·P1，同上落线）**：失败或 30 秒超时回滚本地完成状态并提示。收货时见过一次主线程卡死，排障未复现（探针 130 次 + 实屏 1 次），David 拍板不阻塞；记录见 [收货记录](specs/084-walkthrough-polish/ACCEPTANCE-INSTANT-COMPLETION-ios.md) 与 [排障记录](docs/diagnose/completion-hang-2026-10-03.md)。**切包后真机留意完成流程是否卡死。**

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

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
