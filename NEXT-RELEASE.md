# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (32)
- 基底：`beta/1.0-31` @ `4ffa409b`；1.0(31) 已于 2026-11-03 上传、11-04 David 确认已发，内容（095 / 098 / 100）已挪入 [RELEASES.md](./RELEASES.md)。
- build 号：工程内已 `agvtool new-version 32`（2026-11-05 切包）；marketing version 保持 1.0。
- 2026-11-05 David 在 iPhone 12 真机验收 iOS 通过并放行下列 6 项全部进 1.0(32)。

## 本版将包含

- **P0 视频「被吞」修复（meetpr#403，合入 `73ecbfc8`，2026-11-05 David 放行，定「不单独切包、进下班车」）**：
  记组保存未返回时相机回调拿不到组 id 就删录像，保存失败（断网/5xx/超时/换天）同样删。
  现改为排到保存队列后按 draft 身份取 id；拿不到 id 时录像持久挂起，组保存成功或回到原日后自动挂上并上传（冷启动可恢复）。
  证据：StudentKit 1105 / CoreModels 164 全绿，iPhone 17e 构建过，CI 绿；11-05 随 101/102 一并在 iPhone 12 真机验收通过。
  排障记录 `docs/diagnose/set-video-lost-2026-11-05.md`。已丢视频服务端无存，只能靠学员相册找回。
- **spec 101 A 卡：未送达视频不丢、训练中显示上传失败（PR #408，`eb70d25e`）**：上传失败时保留本机文件，训练页/录入页/已完成训练日显示失败与重试；
  文件缺失可从相册补选，重试限定在所选训练日。StudentKit 1118 / CoreModels 164 绿，CI 绿。
- **spec 102 打勾先变绿：离线记组本机先存、长按完成等组同步（PR #411，`38eb103e`）**：训练组先落本机并持久重试；同账号断网冷启动可恢复训练缓存；
  顺修重开训练日重复 ID 崩溃。StudentKit 1147 / AppShell 125 / DesignSystem 76 绿，CI 绿。
- **spec 101 B 卡：视频送达后才算完成训练日（PR #412，`1dfaa5b4`，含真机走查两处返修 `b04836de`）**：练完即时奖励不变，
  有视频在传时显示等待卡、重启可恢复、失败重试，全部送达后才写完成，送达/30 分钟超时走现有通知；断网完成挂起、联网补发。
  StudentKit 1178 / AppShell 126 绿，CI 绿。
- **训练页辅助项 hero 不再在下方重复（spec 090，PR #399）**：坐姿划船等辅助项在 hero 卡时，下方列表只显示下一个动作。11-04 已合 release/1.0 并经 iPhone 17e 收货，StudentKit 1096/1096 绿。
- **学员聊天「+」问教练面板秒关修复（P1，PR #406）**：1.0(30)/(31) 学员在聊天页点「+」，问教练面板约 0.5 秒自动收回；根因=聊天全屏页挂在带资料编辑 navigationDestination 的子树里，修复=挪到 NavigationStack 外层。安卓真机实测无此问题。⚖️2026-11-05 David 定：随下班车，不单独切包。证据见 docs/journal/2026-11-05-chat-plus-autoclose-ios.md。

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23)、10-18 收尾 1.0(24)、1.0(25)、11-02 收尾 1.0(30)、11-04 收尾 1.0(31) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

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
