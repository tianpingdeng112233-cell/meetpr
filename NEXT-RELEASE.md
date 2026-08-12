# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (19)
- 基底:`beta/1.0-18`(= TestFlight 在测的 1.0(18),2026-08-08 上传)之后的 release/1.0 直推累积
- build 号:19(已 bump,agvtool 单源;2026-08-12 prep-beta)
- 切包:本分支打 tag `beta/1.0-19`

## 本版将包含(落线后追加到这里)

- **spec 073 休息倒计时 Live Activity(灵动岛+锁屏,T2;PR #319,2026-08-12 合入 21d03285)**[P1]:
  组间休息倒计时投到灵动岛与锁屏,切后台/刷手机全程可见,点一下回 app 原地续上;到点自动切
  「休息结束」,app 全程不需要醒。新增 `MeetPRWidgets` widget extension(bundle id
  `com.meetpr.app.widgets`,四 configuration 全配置);倒计时用系统原生 `Text(timerInterval:)`,
  **零推送、零后台任务**。架构红线:StudentKit 不 import ActivityKit(只注入纯 Swift 协议
  `RestTimerActivityControlling`),attributes/controller 放 `Widgets/Shared/` 双 target membership。
  ⚖️08-12 拍板 A=Live Activity 单做(本地通知兜底未选,防复活);实装期采纳 CHALLENGE #1:
  Live Activity 不跑 widget timeline,`staleDate=endsAt` + `context.isStale` 切结束态(spec 已修订)。
  ⚖️08-12 David 终裁本地化=跟活代码(手写 `WidgetStrings` enum,AGENTS.md 死条文另开卡修正)。
  闸门:review-loop 3 轮 + 1 对质收敛 CLEAN(2 BLOCKER 清),731 测试绿,Release/Demo/DemoStudent
  三 configuration 构建绿,模拟器实证四态(后台跳秒/到点完成/跳过消失/回前台清理)。
  真机 smoke(2026-08-12,David 亲验 @ iPhone 12 / iOS 26.5):**锁屏形态 ✅ 无问题**;
  **⚠️灵动岛形态未验且本机验不了——David 的机器是 iPhone 12,无灵动岛硬件**(Dynamic Island
  自 iPhone 14 Pro 起)。别把「锁屏已验」当成灵动岛已验;要清这一条需借 14 Pro 及以上机器。

- **今日页头部日期恒显真实今天(a3273c0,P1)**:修外测「日期卡在 8/9」误读——头部原钉游标日排期,
  现按设计正典显示真实今天并跨午夜自动翻篇;教练推荐日期仍在训练日卡与周条。

- **🔥录满 120 秒的视频即废(0b253eca / PR #321)**[P0]:**1.0(18) 线上既有缺陷**,David 08-12 真机
  录满 2 分钟实测暴露。根因=`RecorderAssetWriter.appendVideo` **先 append 帧再算时长**,
  `RecorderCapturePipeline` 拿到时长才判断 `>= maximumDuration` 停止,故使时长首次达 120 的那帧
  已写入,成片必然 ≥120.0(30fps 约 120.033);而 `enqueue` 用 `duration <= max` 严格拒绝、抛错后
  defer 删源文件 = **app 自己截停录制再自己拒绝并销毁它**,「请截短后再上传」用户无法执行。
  修法=`enqueue` 复检加 0.5s 宽限(`durationGraceSeconds`)。**未动相机采集热路径**:append 前预判
  丢帧既不能保证成片严格 ≤120(末帧时长仍外溢)又在采集热路径加判断,风险大于收益(Codex 复核未反对)。
  闸门:review-loop 1 轮 CLEAN 0 BLOCKER;**负验证已做**(容差归零→测试红,报错与真机截图逐字一致)。
  真机复验 ✅(2026-08-12 David 亲验:录满 2 分钟能正常上传,不再撞「超过 120 秒上限」)。

- **视频「更换」空窗与重试链修真(e25a5d04 / PR #318)**[P1]:外测学员反馈「按键卡住 / 要传两遍」,
  真机复现根因=选片到系统裁剪页呈现有 5–7 秒空窗,期间 `presentationState` 先查 rowState 再查
  `isPreparing`,故「更换」路径(旧 attachment 还在)画面**纹丝不动**→用户反复点(嵌套 cover chrome
  叠印)或退出(整次选片静默丢弃)。修=`preparing` 独立控件态且优先于 rowState、全程覆盖到裁剪流交接、
  重入守卫;并修既有死链:保源 `<id>.source.<ext>` 至上传成功/删除,retry 与休眠重启可**从源重导出**
  (原 retry 在文件缺失时静默 no-op),`sourceMissing` 事件冒真话,失败弹窗文案不再谎称「仍保存在本机」。
  闸门:review-loop 1 轮(1 BLOCKER 清:exportFailed 误降 transient 会让确定性坏素材静默退避 30 分钟)。

- **相册裁剪换自研 + 单次压缩(2eabc18a / PR #320)**[P1]:legacy `UIVideoEditorController` 呈现慢
  (5–7 秒)、typeHigh 重编码后我方 exporter 再全量转码(**双重压缩**)、嵌套呈现叠印、模拟器
  `canEditVideo` 恒 false 致该链**不可模拟器测试**。换自研 `VideoTrimView`(三段式+异步帧条+双把手
  +区间预览)+ `AVAssetExportPresetPassthrough` timeRange **裁剪不重编码**,压缩只发生一次;相册与
  录制两路同时切换,删除 `VideoTrimmerView` 与 `canEditVideo` gating。闸门:review-loop 3 轮
  **8 BLOCKER 全清**(状态机数据竞争/取消误报为失败/导出 Task 游离生命周期外/缺素材轨道预检/
  把手互推未实现/已取消却成功返回的导出仍 claim/prepare 取消后回写/lint 超长行);另**真机走查修掉
  互审没抓到的第 9 个**:嵌套 cover 下 safe area 被清零致工具栏压状态栏(与 #315 同症状不同成因)。
  ⚠️测试 fixture 约束:带音轨的 passthrough fixture 须保持 `frameCount:30`,放大会与既有音轨测试
  并发争用编码器致**整套件挂死**(已在测试注释锁定)。
  真机复验 ✅(2026-08-12 David 亲验:录制→自研裁剪页路径无问题)。

## 1.0(19) 候选(前置解锁后即可进)

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
- [ ] CI 减灾:self-hosted runner 跑后清理(2026-08-03 磁盘满打红 tag CI,待立 T1 卡)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。
