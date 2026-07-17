# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (12)
- 基底:`beta/1.0-11`(= TestFlight 在测的 1.0(11),2026-07-17 上传,Neice + 外测 Ceshi 同版)之后的 release/1.0 直推累积
- build 号:12(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-12`

## 本版将包含(落线后追加到这里)

- 视频上传源临时文件泄漏修复:相册/相机选完视频后,输入源 tmp 拷贝在导出成功/失败/超时长被拒
  三路都会被删除,不再每条视频在沙盒里多留一份 15–200MB 拷贝(VideoUploadManager 明确 source
  ownership)。P1,StudentKit 401 测试绿 + 3 例新单测;review-loop 已收敛(1 轮 CLEAN,transcript:
  `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-video-upload-source-cleanup.md`);
  main 侧同修复走 PR #263。

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

- 赛扣偏好按学员隔离 + 配重数学补测试 + 赛扣 VoiceOver(56bf338,#256 补审产出):同设备切换
  学员账号不再继承上一账号的「上赛扣」选择(key 按学员 UUID 分区,已有测试员的勾选一次性重置为
  默认关);配重数学抽纯函数 SetEntryPlateMath 并补 8 测锁定开/关算术与边界;开赛扣时 VoiceOver
  同步播报赛扣。P1,StudentKit 407 + DesignSystem 29 测试绿,DemoStudent Demo 构建绿。

- 训练 tab 按「主项及变式」/「辅助项」分段并保持计划原序;辅助项记录弹窗不再显示杠铃配片图、
  配片明细和赛扣开关(exerciseType 按分类 gate,David 拍板),重量输入与完成/失败流程不变。
  源自 David 教练端截图反馈(蝴蝶机夹胸配杠铃图)。P1,DemoStudent 模拟器亲验双向(辅助项无
  配片/主项照旧);review-loop 已收敛(2 轮 CLEAN,transcript:
  `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-training-tab-accessory-split.md`)。

- 学员端视频上传前时长裁剪(dff484c,port of #260,David 拍板方案 A 系统裁剪 UI,源自 David
  截图反馈「教练看着累+存储成本」):拍摄路录完直接进系统裁剪屏(allowsEditing),相册路选片后
  先弹 UIVideoEditorController 裁到 120s 上限内——超长视频从「整段拒绝重选」改为「进裁剪屏
  截短」,不可编辑视频降级走原路径;结束语义抽平台无关 VideoTrimCompletion/SingleShot
  (exactly-once + tmp 清理,与上方 e9ab0d8 的 enqueue 所有权互补:裁剪器管原始拷贝、enqueue
  管最终文件)。P1,StudentKit 417 测试绿 + 模拟器 build 零警告;review-loop main 侧 3 轮+
  1 次对质、port 侧 1 轮 CLEAN(transcripts:`~/Brain/wiki/projects/MeetPR/reviews/
  2026-07-17-video-trim.md` 与 `…-video-trim-port.md`)。

## 📋 进度:离 archive 还差几步
- [→] 捞回队列余项不赶本班车,顺延下包:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡
      (等 Claude)/ #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [x] ✅ review-loop 补审欠账已清(2026-07-17):fadbc3a 1 轮 1 BLOCKER 对质 CONCEDE 收敛零改动
      (transcript `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-review-fadbc3a-logout-escape.md`);
      #256 2 轮收敛(4 BLOCKER+1 nit:2 条对质 CONCEDE 为存量另立 follow-up,3 条采纳修复=56bf338)
      (transcript `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-review-256-collar-toggle.md`)
- [x] ✅ 真机走查亲验(David 2026-07-17):#243 说明卡/设置页 + #249 视频占位(1.0(10) 遗留)
      + 1.0(11) 新项(导入历史虚线段/阶梯线/gym-day 4点/记录 v2)运行态一并验过
- [→] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),不阻塞本包,待全量对齐 spec
- [x] ✅ build 号 bump 12(agvtool 单源,2026-07-17)+ tag `beta/1.0-12`
- [ ] David:Archive → Upload → 分配 Neice(+外测 Ceshi 视审核情况)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
