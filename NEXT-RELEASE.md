# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (18)
- 基底:`beta/1.0-17`(= TestFlight 在测的 1.0(17),2026-08-03 上传)之后的 release/1.0 直推累积
- build 号:18(待 prep-beta 时 bump,agvtool 单源)
- 切包:本分支打 tag `beta/1.0-18`

## 本版将包含(落线后追加到这里)

_(1.0(17) 已发出,本节已清零。落线后追加。)_

## 1.0(18) 候选(前置解锁后即可进)

⚖️ 2026-08-03 切 1.0(17) 时核实。**登记在此不等于已排期**,下次切包前重新核。

- **spec 062 学员端统一收件口**:SPEC 已落仓(`specs/062-student-unified-inbox`,8639ce9,
  Draft/T3,David 07-25 三拍),实装未开工,待排期。
- **spec 061 补练/事后顺延**:spec PR iOS #275 + backend #104 均 OPEN 待 David 终审,
  实装未开工。

## 🕐 已完工、等前置解锁(还没落线,落线后挪到上面)

- **学员端 wellness 五档量表 + energy 档**(PR #273,base 已是 `release/1.0`,CI 绿):睡眠/精力/压力/情绪
  四档逐档文案上屏,肌群酸痛扩到四档。**硬前置:backend PR #95(迁移 0047)必须先合并并部署 staging**
  ——后端 `ReadinessBodySchema` 用 `.strict()`,旧后端会把新增的 `energy` 字段当未知字段 400 掉,
  导致学员 readiness 提交全数失败。顺序:#95 合并 → 部署 staging → #273 合并 → 自动进本包。
  另有一处观感待 David 看截图定:第二步未选中的 chip 显示「完全无酸痛」偏吵,可改留白。

## 📋 长期挂账(每次切包前复核)
- [ ] 捞回队列余项:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] 注册页「学员 · 自己练」空壳待拍板:发版线上是否先藏起这一档(solo 波冻结在 main)。
      详见 RELEASES.md 1.0(14) §已知问题
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [ ] CI 减灾:self-hosted runner 跑后清理(2026-08-03 磁盘满打红 tag CI,待立 T1 卡)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
