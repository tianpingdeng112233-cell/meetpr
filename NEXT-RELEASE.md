# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (25)
- 基底：`beta/1.0-24` @ `f2d44394`；David 于 2026-10-18 截图确认 1.0(24) 已上传并在外部组测试，内容已挪入 [RELEASES.md](./RELEASES.md)。
- build 号：25（切包时单源更新五处 `CURRENT_PROJECT_VERSION`），marketing version 保持 1.0。

## 本版将包含
- **spec 093 国内邮箱注册 + 邀请消息分享（#366，T2·P1，2026-10-17 落线 `06bf0e6d`）**：安卓 spec 093 同步。
  - CN 轨改用邮箱登录 / 注册 / 找回密码（复用 Global 页面，隐藏 Apple / Google）；注册带 6 位验证码、60 秒冷却、确认密码；修正中文占位字体。
  - 教练个人页与邀请码页复制完整邀请消息，永久码可系统分享；学员点「粘贴」可从整段消息或 `/i/CODE` 链接里取出邀请码。Global 轨仍是纯码。
  - 开发自测：五模块 1891 项通过，CN / Global 两个配置都能编译；截图在 [docs/evidence/spec093-2026-10-17/](docs/evidence/spec093-2026-10-17/README.md)。
  - **收货通过（Opus 2026-10-18）**：David 在 iPhone 12 上实测真邮箱注册（验证码信未进垃圾箱）、找回密码、从 1.0(24) 登录态升级不掉登录。[收货记录](docs/acceptance-spec093-ios-2026-10-18.md)。
  - **⛔ 发包闸门**：发 TestFlight 前 plan-web `/i/<码>` 落地页（plan-web #110）必须已部署，否则邀请消息里的链接打开是教练登录页。
- **Global 恢复绑定页「粘贴」按钮（#367，T1·P1，2026-10-18 落线 `2533d636`）**：#366 误把 1.0(24) 已上线的 Global 粘贴按钮删了，收货时发现并恢复；CN 文案仍是「粘贴邀请码」。
- **登录 / 注册 / 找回密码键盘不再遮挡输入框 + CN 口号改两行（#368，T1·P1，2026-10-18 落线 `12f5dc2c`）**：聚焦的输入框自动滚到键盘上方，页面可滑动、可下拉收键盘；CN 口号改为「Meet Your / PR Here.」（David 10/18 定，安卓 meetpr-rn#96 同步）。David 真机复测通过；模拟器未复现原问题，根因未点名。

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23)、10-18 收尾 1.0(24) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

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
