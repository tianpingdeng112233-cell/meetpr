# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (17)
- 基底:`beta/1.0-16`(= TestFlight 在测的 1.0(16),2026-07-31 上传)之后的 release/1.0 直推累积
- build 号:16(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-17`

## 本版将包含(落线后追加到这里)

_(1.0(16) 已发出,本节已清零。落线后追加。)_

- **e1RM 建议重量三修(PR #301,2026-07-31 合入 7a55806,spec 050 修订)[P1]**:
  ①失败组不再作为同日沿用种子(主项/辅助两条路径补 `!failed`);②教练事后校准 coach_rpe
  追更学员端本地 e1RM 历史——新增 `E1RMCoachRPEReconciler` + `E1RMHistoryReplayService`
  挂今日页加载点,repo 级 revision CAS 防并发覆盖、缺点自愈、PR 事件按 `studentID+setLogID`
  幂等补发且报真实前纪录(`E1RMWeightBaseline.previousMaxWeightKg` 新增);③主项无建议时
  组录入面板一行缺失原因提示(无合格历史/处方无 RPE/无次数/次数>12 等),不再静默回落 20kg。
  闸门:review-loop 5 轮 6 BLOCKER 全清(David 裁决加轮 1 次),StudentKit 638 + CoreModels 147
  全绿,Demo build 0 warning,模拟器四态亲验。零后端依赖(校准 endpoint 0052 早已上线)。

- **视频打点(spec 063,PR #299,2026-07-31 合入 09ef608)[P1]**:教练视频反馈工作台打时间点标记
  (单一档+备注——⚖️07-31 拍板 A 砍掉三档级别(#300),进度条刻度,删重建无编辑);学员端反馈收件箱两个入口切共享播放器,
  只读打点列表点击即 seek。backend 侧 #150 + 迁移 0054 已于同日部署 staging(打点面对 404 静默降级,
  后端已上线故双端即刻可用)。review-loop 3 轮收敛 + 模拟器双端亲验。
- **打点标注帧查看(spec 064,PR #302,2026-08-01 合入)[P1]**:学员点带 ✏️ 的打点 = seek + 暂停 +
  覆盖显示教练画的标注帧(点击关闭不续播);三处播放器调用点统一,共享件可选参数零回归。
  上游 backend #181(迁移 0055,provenance 防跨学员泄露)与 web 教练端(发标注自动带图挂点)已上线。
  review-loop 2 轮收敛 + DemoStudent 模拟器亲验。

## 1.0(17) 候选(上一包挡下的,前置解锁后即可进)

⚖️ 2026-07-31 切 1.0(16) 时核实后挡下。**登记在此不等于已排期**,下次切包前重新核。

- **spec 062 学员端统一收件口**:SPEC.md 已写好(19KB,Draft/T3,David 07-25 三拍)但**从未提交**,只存在于 `~/Projects/apps/MeetPR-release` 工作区,未跟踪。开工前先把它落进仓里。

## 🕐 已完工、等前置解锁(还没落线,落线后挪到上面)

- **学员端 wellness 五档量表 + energy 档**(PR #273,base 已是 `release/1.0`,CI 绿):睡眠/精力/压力/情绪
  四档逐档文案上屏,肌群酸痛扩到四档。**硬前置:backend PR #95(迁移 0047)必须先合并并部署 staging**
  ——后端 `ReadinessBodySchema` 用 `.strict()`,旧后端会把新增的 `energy` 字段当未知字段 400 掉,
  导致学员 readiness 提交全数失败。顺序:#95 合并 → 部署 staging → #273 合并 → 自动进本包。
  另有一处观感待 David 看截图定:第二步未选中的 chip 显示「完全无酸痛」偏吵,可改留白。

## 📋 进度:离 archive 还差几步
- [ ] 捞回队列余项逐个落线:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] 注册页「学员 · 自己练」空壳待拍板:发版线上是否先藏起这一档(solo 波冻结在 main,
      发版线上该角色进去是没有计划来源的学员壳子)。详见 RELEASES.md 1.0(14) §已知问题
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [ ] build 号 bump 15(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-15`
- [ ] David:Archive → Upload → 分配 Neice(+外测 Ceshi 视审核情况)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。

**移出理由**:
- **wellness**:硬前置 backend PR #95(迁移 0047)**仍是 OPEN、未部署 staging**。旧后端
  `ReadinessBodySchema` 走 `.strict()`,会把新增的 `energy` 字段当未知字段 **400 掉**,
  学员 readiness 提交将全数失败。顺序不变:#95 合并 → 部署 staging → #273 合并 → 进下一包。
- **spec 062**:SPEC 至今**未提交**,只存在于 `~/Projects/apps/MeetPR-release` 工作区(未跟踪),
  且是文档不影响包体。落进仓里之后再谈排期。

## 🎯 已排上但未开工
