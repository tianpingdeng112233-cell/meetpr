# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (16)
- 基底:`beta/1.0-15`(= TestFlight 在测的 1.0(15),2026-07-29 上传)之后的 release/1.0 直推累积
- build 号:16(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-16`

## 本版将包含(落线后追加到这里)

_(尚无候选)_

## 🎯 已排上但未开工

- **登录页重做**(David 2026-07-29 提):登录页是 v3 唯一没覆盖的界面(#279 收据明写「教练端与登录流保持恒暗、全程零 diff」),现仍是 v2 旧 token——`brandRed`×2 / `fgPrimary` / `fgSecondary` / `fgTertiary` / `surface2` / `border` / `bg`,一个 v3 token 都没有,在新学员端旁边割裂。
  ⚠️ **两个待拍板**:①登录页**角色无关**(还不知道是教练还是学员),而 v3 正典只覆盖学员端且默认浅色、教练端恒暗——跟哪套?②v3 设计包里**没有登录页参照物**,是照 `DESIGN-SYSTEM-CANON.md` 推导还是另出稿?
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
