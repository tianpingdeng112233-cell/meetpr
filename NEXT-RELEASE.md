# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (12)
- 基底:`beta/1.0-11`(= TestFlight 在测的 1.0(11),2026-07-17 上传,Neice + 外测 Ceshi 同版)之后的 release/1.0 直推累积
- build 号:12(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-12`

## 本版将包含(落线后追加到这里)

- 「查看回顾」入口押后到滑动完成之后(9551a98,源自 David 1.0(10) 截图反馈,落线晚于 11 的 tag):
  所有组打勾后不再同屏出现「今日训练完成 · 查看回顾」banner 和「滑动完成今日训练」滑条——banner
  只在滑动确认+回顾页点「完成」后出现;历史只读日无滑条,banner 保留作回顾唯一入口。P1,
  DemoStudent 模拟器亲验全流程;review-loop 已收敛(1 轮 CLEAN,transcript:
  `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-review-entry-gating.md`)。

- refresh 400 视同硬失效干净回登录页 + `/auth/refresh` 请求体 wire key 契约测试(c329981 + a15e158,
  backend #76 键名事故的 iOS 侧姊妹修复):前台 token 刷新遇 400 不再困在重试死胡同,与 401 同走
  清会话回登录;新增编码契约测试钉死 `refresh_token` 键名防复刻。P1,AppShell 54/72 测试全绿,
  review-loop 已收敛(1 轮 CLEAN,transcript:
  `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-refresh-400-hard-failure.md`)。

## 📋 进度:离 archive 还差几步
- [ ] 捞回队列余项逐个落线:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] review-loop 补审欠账:fadbc3a(1.0(9) 遗留)+ #256(1.0(10) 遗留,Claude 已亲审 diff)
- [ ] 真机走查亲验:#243 说明卡/设置页 + #249 视频占位(1.0(10) 遗留)+ 1.0(11) 新项
      (导入历史虚线段/阶梯线/gym-day 4点/记录 v2)运行态顺带一并验
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [ ] build 号 bump 12(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-12`
- [ ] David:Archive → Upload → 分配 Neice(+外测 Ceshi 视审核情况)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
