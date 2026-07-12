# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (10)
- 基底:`beta/1.0-9`(= TestFlight 在测的 1.0(9),2026-07-12 上传)之后的 release/1.0 直推累积
- build 号:10(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-10`

## 本版将包含(落线后追加到这里)

- e1RM 比赛主项按学员 onboarding 解析，并一次性重算端上存量历史、重置旧 PR 基线（port of #250，spec 050）。
- (tag 后曾合入的 #248 视频「准备中…」占位已 revert 撤出,重开为 #249 待合)

## 📋 进度:离 archive 还差几步
- [ ] **解禁可合的上班车遗留**(包已切出,P2「留分支不合」机制解除):#249 视频「准备中…」占位
      (前身 #248 撤出重开)、#243 spec 055 休息计时器可见性——合前照常过 review 闸门
- [ ] 捞回队列余项逐个落线:#227 导入历史 e1RM 回填(依赖的 #216/#220 已随 1.0(9) 发出,
      **已解锁**,体量大拆子卡)/ per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] fadbc3a 的 review-loop 补审(1.0(9) 遗留,先发后补审)
- [ ] build 号 bump 10(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-10`
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(10) 一节,清空本文件、目标号 +1。
