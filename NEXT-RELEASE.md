# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (40)
- 基底：`beta/1.0-39-rc2` @ `c89bcff6b6873edceb4b09194579d8243255b131`；David 于 2026-11-11 明确确认 39 已上传并提交 Ceshi 外测审核。Ceshi 审核结果未核实；2026-11-13 David 截图确认 Neice 的 38、39 均为 Testing。
- 工程 build 40，marketing version 1.0。准备新 annotated tag `beta/1.0-40`，待准确 tag CI、双端 demo 与取包树核验后交 David 手动 Archive/Upload。旧 39 tag 的 lint 失败记录和 39-rc2 tag 均保留。

## 本版将包含

- **辅助项上次重量（spec 109，#462，T2/P1）**：辅助项无明确重量时，按同动作最近一次训练逐组预填；扫视态金色，编辑态数字右侧显示“上次”。已存/手改/教练明确值优先；缺组留空，不预填主项、次数、RPE/RIR。已获 David 合并批准，落线 `df38eec1`，PR CI、独立双轴与原生验收通过。见 `specs/109-accessory-history/SPEC.md`。

- **已完成训练日视频状态与回放修复（spec 096 / 107，#461，P1）**：完成后仍显示上传中黄色、送达绿色、失败红色；已送达视频可只读回看；有较新远端片时优先最新来源。无视频的完成组不出现拍摄入口。已合入 `c2302d20`；StudentKit 1281 tests、独立 Standards/Spec、iPhone 17e 原生完成后回看与 PR CI 通过。证据见 `docs/journal/2026-11-12-107-completed-video.md`；原生证据使用 Demo 素材，不冒称真实用户 OSS 联验。

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
