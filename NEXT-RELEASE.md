# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (27)
- 基底：`beta/1.0-25` @ `a8e39fd3`；David 于 2026-10-18 截图确认 1.0(25) 已上传，内容已挪入 [RELEASES.md](./RELEASES.md)。
- build 号：27（2026-10-22 P0 切包 `agvtool new-version 27`，tag `beta/1.0-27`）。`beta/1.0-26`（2026-10-18，[切包记录](docs/prep-beta-1.0-26-2026-10-18.md)）是否已上传 ASC 未经 David 确认；27 包含 26 全部内容，26 若未传则作废不传。marketing version 保持 1.0。

## 本版将包含
- **教练「退出登录」弹窗去掉「手机号」（#369，T0·P1，2026-10-18 落线 `686d946a`）**：spec 093 改邮箱登录后，弹窗仍写「退出后需重新用手机号登录」，David 在 1.0(25) 上发现；改为「退出后需要重新登录。」。两端全仓扫描无其他可达的手机号登录文案（旧 LoginView/SignupView 不可达）。安卓 meetpr-rn#97 同步。
- **下拉刷新不再误报「加载失败」（#370，T2·P1，2026-10-18 落线 `2bf60ad4`）**：David 在 1.0(25) 上发现教练「学员」tab 每次下拉刷新都弹全屏加载失败。真机探针确认根因：刷新时 SwiftUI 取消了请求（NSURLError -999），代码把取消当成失败清空了列表。改为刷新期间保留已有内容、请求被取消时恢复原状态；教练端与学员端全部 13 处下拉刷新一并修。新增 26 条取消用例（修前红），CoreModels 160、CoachKit 472、StudentKit 1033、AppShell 118 本地全绿；David 在 iPhone 12（Release 构建）反复下拉复测通过。

- **P0 教练冷启动卡死（#373，T1·P0，2026-10-22 落线 `82f4afd4`）**：David 报教练首次打开 App 首页卡住点不动。根因：首页「本周概况」比例条用 `containerRelativeFrame` 查询外层滚动容器尺寸，只要有学员本周有训练日，冷启动布局就不收敛、主线程卡死。改为比例条按自身宽度计算，视觉不变。修前探针 3/3 红（iOS 26.5），Opus 在 26.4 撤修复复跑仍红，修后全绿；CoachKit 472 绿；David iPhone 12 真机装 Release 构建试用。回归探针只在 `COACH_LAUNCH_HANG_TESTING` 编译开关下存在。
- **P0 教练码分享到微信 + 按钮改版（#374，T1·P0，2026-10-22 落线 `3ea5bd5a`）**：原分享是「链接+文字」混合载荷，微信报「不支持的分享类型」；改为只交给微信一个邀请链接（短信/邮件/复制仍给完整邀请语），David 真机发微信成功。「我的」卡片与邀请码页改为满宽「分享给学员」+「复制邀请语」，右上「管理 ›」，「重新生成」挪进「…」；分享标题「{教练名} 教练邀请你在 MeetPR 跟练训练计划」。仅国内版。配套后端 #319 已部署国内 staging（`07a8ed31`，邀请页卡片标题带教练名，同批带上 #318 网页去快捷回复），安卓 meetpr-rn#101 已合。

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23)、10-18 收尾 1.0(24)、1.0(25) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

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
