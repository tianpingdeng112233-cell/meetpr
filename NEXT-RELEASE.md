# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标：1.0 (31)
- 基底：`beta/1.0-30` @ `0fb99494`；David 于 2026-10-31 确认 1.0(30) 已发布，内容（含未上传 29 的候选）已挪入 [RELEASES.md](./RELEASES.md)。
- build 号：工程内仍为 30，切 31 时再 `agvtool new-version 31`；marketing version 保持 1.0。

## 本版将包含

- **spec 098 被教练解绑提示（T1/P1，#388 `d7c44c2`）**：最近一条申请 `cancelled` 且带 `ended_at` 时，邀请码页顶部两行提示「{教练名}已与你解绑 / 训练记录都还在，输入邀请码可重新绑定」（三语 + 空名兜底，繁体走生成器；同次生成器校正 3 处既有繁体词条）。`BindRequest` / `BindRequestDTO` 加可选 `endedAt`，状态枚举不变，旧后端无字段时行为不变。依赖 backend 057（#356，迁移 0082，2026-11-02 已部署国内 staging）。验收：StudentKit / CoreModels / Networking 全量绿；iPhone 17e 在本机后端（同一 057 代码）上亲验带名与空名两种文案。教练接受重新申请后回到在训由后端端到端验过。

- **spec 100 学员端 RPE / RIR 说明卡片（T1/P1，#391 `88da16b`）**：记录弹窗、辅助项表头、补记表头的 RPE/RIR 字样旁加「?」，点开居中卡片（RPE、RIR 各一张）；RPE 刻度小字按 Zourdos 2016 原表改口径（9.5「做不了下一次，但能再加点重」、5–6「还剩 4–6 次」），RIR 步进器下显示「还剩 N 次 / 做不动了」。纯客户端，无后端依赖。验收：StudentKit 1073/1073；iPhone 17e 截图 15 张（三语、深浅色、最大字号）。安卓同批 rn#122。

- **spec 095 绑定后首次体验 + 资料向导缩成 4 步（T2/P1，#382 `163eeb4`，David 2026-11-03 放行）**：教练接受后一次性欢迎页、待接收页前台 30 秒轮询、新学员版等计划卡（无周小结/发布时间，带「完善资料」「填比赛日」）、本次绑定第一份计划卡；学员登录后不再自动弹通知权限，改由待接收页/欢迎页按钮触发；`bind_accepted` 推送点开路由。资料向导只留基础信息/训练背景/三大项 1RM/补充信息 4 步（训练环境、恢复能力、训练资料先不要，「我的资料」同步隐藏，数据列保留）；旧草稿续填落到保留步骤；待接收页「登出」不压标题、副标题拼名、资料行「基础资料」；「健康与恢复」卡改名「伤病记录」。判定全读后端 `first_run`，缺字段一律保持原样（老学员首页不变）。依赖 backend #338（bind_accepted + first_run，已部署）与 #359（完成必填 17→12，2026-11-03 已部署国内 staging，Global 未部署）。验收：九包 2218 绿（本机；CI 三次因本机 runner 连不上 github.com 443 未跑完）；iPhone 17e 走查截图 `docs/evidence/spec095-trim-2026-11-02/opus/`（4 步、旧草稿续填、待接收三种拼名、繁英、老学员首页与我的资料）。安卓同批 rn#111 / rn#121。

## 延期候选（未排期，前置解锁后另行排期）

⚖️ 2026-08-09 收尾 1.0(18) 时登记,08-23 收尾 1.0(21)、10-02 收尾 1.0(23)、10-18 收尾 1.0(24)、1.0(25)、11-02 收尾 1.0(30) 时顺延。**登记在此不等于已排期**,下次切包前重新核。

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
