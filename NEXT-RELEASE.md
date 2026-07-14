# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (11)
- 基底:`beta/1.0-10`(= TestFlight 在测的 1.0(10),2026-07-13 上传)之后的 release/1.0 直推累积
- build 号:11(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-11`

## 本版将包含(落线后追加到这里)

- 训练日切日改凌晨 4 点截断(gym-day,镜像 backend spec 017):跨 0 点训练不再被自动锁成只读
  「自动结束」,可一路记到凌晨 4 点;凌晨冷启动/「回到今天」落在仍可编辑的前一训练日。源自内测
  学员反馈「晚上12点自动结束」。残留:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec。

## 📋 进度:离 archive 还差几步
- [ ] 捞回队列余项逐个落线:#227 导入历史 e1RM 回填(已解锁,体量大拆子卡)/ per-set 逐组目标 /
      rename-student / #215'/#217' 裁剪卡(等 Claude)/ #234a 非 UI 拆包(等 Claude),
      状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] review-loop 补审欠账:fadbc3a(1.0(9) 遗留)+ #256(1.0(10) 遗留,Claude 已亲审 diff)
- [ ] 1.0(10) 真机走查亲验:#243 说明卡/设置页 + #249 视频「准备中…」占位的运行态视觉
- [ ] build 号 bump 11(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-11`
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
