# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (21)
- 基底:`beta/1.0-20`(= TestFlight 在测的 1.0(20),2026-08-20 上传)之后的 release/1.0 直推累积
- build 号:21(✅ 2026-08-23 prep-beta 已 bump,agvtool 单源)
- 切包:本分支打 tag `beta/1.0-21`

## 本版将包含(落线后追加到这里)

- **学员端训练日定时提醒(spec 079,T1/P1)**:PR #334 → `24b871e0`。「我的」新增训练提醒:开关 +
  星期几多选 + 时间,默认勾选 = 档案里教练安排的训练日(缺档案回落一/三/五),首开才请求通知权限;
  纯本地 UNUserNotificationCenter,登出清理 + 进 shell 对账双保险。真机走查 08-21 通过(权限弹窗/
  到点横幅/默认日)。
- **训练视频角标:回看浮层 + 烧录导出(spec 078,T2/P1)**:PR #335 → `8b680322`。共享播放器加
  MeetPR 角标卡(全屏默认展开可收起;教练工作台恒 logo 圆标),式样正典 `docs/design/video-badge/`;
  「导出」把同款卡 + 渐变压暗 + 「教练:名」署名烧进视频存相册(add-only 权限),教练首次导出弹学员
  同意确认。真机走查 08-21 学员/教练端均通过。⚠️ 验收注意:iOS 26.5 **模拟器**的 AVFoundation 会丢
  Core Animation 层,模拟器导出的成片没有角标——真机才有,不是 bug。配套 backend #262(反馈视频摘要
  带 `rpe`)合并部署后,学员「教练反馈→关联视频」的角标 RPE 胶囊才点亮;未部署时该路径胶囊隐藏,不报错。

- **学员端六形态强度解码 + 忠实渲染 + 止血 + 周几对齐(spec 072 卡 1,T2/P1)**:PR #317 → `98b020fa`。
  `PlanSetDTO` 解 load_mode 九字段;新形式行渲染「72.5% × 5」「RPE 8–9 × 5」「165–175kg × 5」,
  消灭「-kg x 5」「目标 RPE 0/10」;非 RPE 新形式不再喂伪 RPE 给建议引擎;预填留空禁用「完成」;
  `anchor_weekday` 非 null 时 D1 对齐。08-22 合入最新线时解 1 个测试冲突。
- **% 强度处方三锚换算 + S13 设计稿换皮(spec 034 §9.4,T2/P1,⚖️08-21 口径:app 全算学员不动手)**:
  PR #336 → `8a5c32ac`(叠 #317)。`pct_anchor` 贯穿 DTO/投影/缓存;`PctAnchorResolver`:1RM 锚=登记
  1RM×%、e1RM 锚=当前 e1RM×%(为空静默回落登记 1RM,spec 034 §9.4 已注)、当日顶组锚=同动作前序行
  已完成非 failed 最大实际重量×%(顶组录完原位点亮,未录不预填);2.5 kg floor。组行「≈ 120 kg / 60% · 1RM」、
  动作副标题三种、面板预填弱色+点线框+「自动换算」角标(改动即转实色)+来源行四变体、RPE 无目标占位。
  Demo:`-student-empty-state pct-anchors` 三锚同屏。这是 08-20 审计 R1(学员按错误预填重量练)的根治。
- **gym-day 归日改设备时区 + 墙钟 04:00(审计 R6,T2/P1,海外送审前置)**:PR #330 → `75907a8c`。
  `WorkoutDatePolicy` 去掉 Asia/Shanghai 硬编码,归日与 backend `trainingDay` 墙钟语义逐字对齐,DST 安全;
  前台激活/登录时设备时区变化 PATCH /me/timezone。上海时区 24 小时参数化回归钉死中国用户零变化。
  ⚠️已知残留:CN 构建仍不上报 timezone(既有 gate),出境旅行归日仍可能两端分裂,口径待拍。
- **教练端成长 e1RM 改读 backend 序列(审计 R4,T2/P1)**:PR #332 → `6837de13`。
  `/coach/students/:id/exercise-stats` 同源于 web,本地绕闸门的计算路径删除不留 fallback;
  同一学员 web/iOS 两个数的问题根治;三态(loading/失败重试/缺序列空态)。
- **学员端空状态/错误态兜底 9 条(08-12 审计,T2/P1)**:PR #331 → `d1766eae`。距比赛/体重占位接线回归、
  首页骨架、休息日角标、零反馈空态、铃铛四态+alert、网络错误不再伪装「教练正在排计划」、账号与安全
  empty/failed 可达、容量/强度 gate 放行、E1RM 曲线错误与真空分离。文案级兜底,设计稿回来换皮。
  08-22 合入最新线时把 #334 训练提醒行穿进 `MyProfileFallbackRows`。
- **教练端空状态/错误态兜底 8 条(08-12 审计,T2/P1)**:PR #333 → `3b6e3a7c`。学员列表三态(0 学员邀请码
  引导/搜索无匹配/loading)、消息 tab 首帧 loading 门控、视频组次卡 setInfoState 四态、空会话三态、
  学员详情假 0/0 计划壳换真空态、0 学员不再「全部处理完」、Step0 空框、待反馈视频可退出。

- **CoachKit 动作别名表对齐 plan-web(自建动作三件套波残办,T1/P1)**:PR #337 → `d886c587`。
  `exercise-aliases.json` 44 → 49 行:`坐姿推肩`/`哑铃推肩`→`坐姿哑铃推举`、`两头起`→`V字上举`、
  +`帕洛夫推`→`弹力带 pallof 推`、+`对握弯举`→`绳索锤式弯举`,影响教练 Excel 导入的自动绑定。
  ⚖️08-23:`哑铃推肩` 本身是 seed 行(精确匹配先赢,该别名 iOS 侧仅 parity),与 `坐姿哑铃推举` 不去重。

## 1.0(21) 候选(前置解锁后即可进)

⚖️ 2026-08-09 收尾 1.0(18) 时登记。**登记在此不等于已排期**,下次切包前重新核。

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
- [ ] 067 APNs 硬前置:ASC 建 APNs Auth Key(p8→Bitwarden)+ SAE 配 PUSH_ENABLED 与五个 APNS_*;
      配好前 1.0(18) 的推送整体休眠
- [ ] 捞回队列余项:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] 注册页「学员 · 自己练」空壳待拍板:发版线上是否先藏起这一档(solo 波冻结在 main)。
      详见 RELEASES.md 1.0(14) §已知问题
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [x] CI 减灾:本机磁盘定期清扫 ✅2026-08-21 已上线(launchd `com.david.disk-janitor` 每小时,
      清扫四类白名单+15G 水位通知;实装在 ~/ClaudeConfig 33036e0,卡见 scratch/card-disk-janitor-2026-08-21.md)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
