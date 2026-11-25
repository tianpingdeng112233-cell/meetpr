# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上，记录下一个内测包的内容与进度。
> 发版模型及权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (43)
- 基底为已上传的 `beta/1.0-42`（`b4c20a68`）。工程当前为 build 42；43 是下一班目标，尚未升号或切 tag。

## 本版将包含

- **spec 114 本周期主项走势 + RPE 对照表（P1，#492，2026-11-25 David 放行）**：训练页标题旁「整个周期」胶囊，底部弹层每周一根阶梯柱看深蹲 / 卧推 / 硬拉推到多重；已练完的周显示实际组并浅金填充 + 金色 ✓，本周金色描边，最高周金色；交接预览里也能看下一份计划。成长 tab 末行新增「RPE 对照表」，按学员当前 e1RM 换算 kg。纯客户端，无后端依赖。已验：StudentKit 1363 tests 绿、iPhone 17e DemoStudent 浅 / 深色亲眼看（返修 1 轮对齐安卓）；未验：带历史老账号升级后第一屏、12 周计划、繁体 / 英文。安卓同批 meetpr-rn#220。

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
- [ ] **Xcode 27 / iOS 27 SDK**：1.0(42) 上传时 ASC 警告，2027 年 4 月起须用 Xcode 27 构建才能上传；届时之前升级本机 Xcode 与 CI runner。
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
