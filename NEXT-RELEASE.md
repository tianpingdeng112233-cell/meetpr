# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (22)
- 基底:`beta/1.0-21`(= TestFlight 在测的 1.0(21),2026-08-23 上传)之后的 release/1.0 直推累积
- build 号:22(待 prep-beta 时 bump,agvtool 单源)
- 切包:本分支打 tag `beta/1.0-22`

## 本版将包含(落线后追加到这里)

- **学员端计划自动刷新 + 计划推送路由（#339，T1，2026-09-02 落线 a7d0869b）**：回前台 / 切回训练 tab 自动重拉计划（25s 节流，记录中不打断、草稿不丢）；解析 `plan_updated` / `plan_published` 推送跳训练页强刷（APNs 配好前休眠）。配套 backend #273（batch 推 `plan_updated` + `updated_at`）、plan-web #99。

## 已批准进入 1.0(22)（2026-09-16）

David 已明确批准 #339 / #342 / #341 / #340 / #343 进入下一班车；无需再次询问这些项目的进包或合并授权。本节随整合 PR 合入 `release/1.0` 即成为本版范围，合入不等于已切包或部署。

- **#342 / spec 081 快捷补记**：游标日零记录入口、日期与整日预填、跳组、长按完成；包含日期窗口、Gregorian 日期、小数键盘、部分成功重试及与 #341 的兼容修复。
- **#341 / spec 082 动效清理**：页面同步切换、统一按钮按压，保留必要奖励与完成反馈。
- **#340 / spec 080 教练后移消费**：推荐日期显示后移值、后移推送刷新、教练徽标；完整功能启用仍依赖 backend #276 的 0070 / 部署 / gate、web #101 上线及三端验收。
- **#343 / spec 083 e1RM 来源与历史入口**：点选曲线节点查看保存的来源组与原计算；训练页直达历史并保留活动组与休息计时。组合修复使历史入口、详情关闭按钮遵循 #341 的统一按压。
- #339 已于 09-02 落线，见上方条目。以上四项的独立 PR CI 已于 09-16 全绿；整合代码保留 `73fea6d` 两条失效 lint 豁免清理，合并前再通过整合 PR CI。
- 最新整合证据见 [2026-09-16 验证记录](docs/verification-train22-2026-09-16.md)。09-14 的三项组合验证为历史证据，不代表包含 #343。
- **部署与发布剩余项**：APNs key 已在 Bitwarden；最近线上预检（09-14）为 `sandbox`，TestFlight production 配置与实际送达未验收；0070 尚未在线上执行。build 号仍为 21，尚未切 `beta/1.0-22`；Archive / Upload 由 David 手动。
- #338 仍为下方候选；本次仅说明其改动，没有新增进包授权。

## 1.0(22) 候选(前置解锁后即可进)

- **Spec 083 e1RM 节点溯源与训练历史入口（T2 / P1）**：实装分支 `feat/083-e1rm-history-impl`，869 项测试及 DemoStudent 双主题验收通过，独立审查 CLEAN；待 David 确认 PR 合并后进入候选。无后端迁移、无 build 号改动。证据见 [验收记录](docs/evidence/083-e1rm-history/README.md)。

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

- **iOS 切域名 `https://app.meetpr.cn`(C 序列第 2 步,T1)**:BuildConfig
  `productionBackendBaseURL` http://IP:3000 → https 域名 + 收 ATS 明文豁免;
  **硬前置 = 阿里云接线落地**(DNS/证书/CLB 443,David 手动,HTTPS 陪跑会话在办)。
  旧 hold/https-migration-2026-07-09 分支不复活,发版线重做。
- **spec 062 学员端统一收件口**:SPEC 已落仓(8639ce9,Draft/T3),实装未开工,待排期。
- **学员端 wellness 五档量表 + energy 档(PR #273,CI 绿)**:硬前置 backend #95(迁移 0047)
  合并+部署 staging,否则旧后端 `.strict()` 把 `energy` 400 掉。顺序:#95 → 部署 → #273。
  另有 chip 观感待 David 看截图定。
- **动作分类全审计 iOS 侧(#338,T1)**:同一动作不得两种分类,backend #267(0069)已落,
  iOS #338 待审;合入即候选。
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
