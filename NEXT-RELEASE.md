# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (13)
- 基底:`beta/1.0-12`(= TestFlight 在测的 1.0(12),2026-07-17 上传,Neice 免审生效、外测 Ceshi
  已提审)之后的 release/1.0 直推累积
- build 号:13(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-13`

## 本版将包含(落线后追加到这里)

_(暂无——落线一项记一项)_

## 📋 进度:离 archive 还差几步
- [ ] 捞回队列余项逐个落线:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [ ] build 号 bump 13(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-13`
- [ ] David:Archive → Upload → 分配 Neice(+外测 Ceshi 视审核情况)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
