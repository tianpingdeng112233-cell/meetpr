# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (15)
- 基底:`beta/1.0-14`(= TestFlight 在测的 1.0(14),2026-07-24 上传)之后的 release/1.0 直推累积
- build 号:15(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-15`

## 本版将包含(落线后追加到这里)

- **学员端黑金 v3 UI 全量重做**(PR #279 已合 `dd699fc`,2026-07-29):今日 / 训练 / 成长 / 我的
  四屏 + 记录链路(SetEntry / 数字键盘 / 组间休息)+ 收官 overlay(结算庆祝 / 训练回顾 / 顺延 /
  反馈档案)+ 七个空状态 + 动效逐参对齐 + 通知并入聊天。**双主题,默认浅色**(我的 → 外观 可切
  跟随系统 / 深色);教练端与登录流保持恒暗、全程零 diff。设计系统正典落
  `docs/design/handoff-v3/DESIGN-SYSTEM-CANON.md`(⚖️ David:今后学员端 iOS 新设计以它为准)。
  - 合并同时把发版线 spec 029(C0 组号契约 / C2a-c 组引用卡与「问教练」)接进 v3 各面,
    功能不回归;**遗留视觉债**:组引用卡与分享选择器仍是 ChatUI 现成样式,黑金化是下一张卡
    (清单见 `docs/design/handoff-v3/SETREF-BRIDGE-PHASE1-RECEIPT.md` 末节)。
  - 闸门:每卡 review-loop CLEAN(累计 100+ blocker)、全量 SPM 1439 绿、三 configuration
    build 0 warning、lint/format strict 零、CI 三项绿。
  - ⚠️ 上包前建议真机走一遍学员端主链路(本波全部验证在 iPhone 17 模拟器完成)。

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
