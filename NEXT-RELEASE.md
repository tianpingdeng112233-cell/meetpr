# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (18)
- 基底:`beta/1.0-17`(= TestFlight 在测的 1.0(17),2026-08-03 上传)之后的 release/1.0 直推累积
- build 号:18(待 prep-beta 时 bump,agvtool 单源)
- 切包:本分支打 tag `beta/1.0-18`

## 本版将包含(落线后追加到这里)

- **spec 068 自建录制相机 + 直通快路**(PR #307,2026-08-03 squash 合入 8cb7b51)[P1]:
  拍摄换自建 AVCaptureSession(720p/60fps 可锁则锁,边录边按 065 口径编码,录完即上传就绪,
  「处理中」近乎归零);录制状态机(starting/stopping+generation)抗来电/切后台/首帧失败;
  存相册从恒存改可选 toggle(默认开=保持现行为,留底变 720p 压缩版);恢复 065 无意移除的
  #269 remux 直通快路(遍历全部 format descriptions,失败回退全量转码)。
  闸门:review-loop 3 轮 4 BLOCKER 全清,StudentKit 665 绿,Demo sim build 过。
  ⚠️ 切包前必须真机 smoke(模拟器无相机):录 10s→处理中近乎瞬时→上传→教练端可播、
  竖屏方向正确;存相册开关两态;昏暗场地录一条验体积。

- **spec 065 视频导出控码率(拍摄上传提速)**(PR #304,2026-08-03 squash 合入 95d0b32)[P1]:
  学员反馈「app 内拍摄的视频上传特别慢」根治。导出器从 AVAssetExportSession(1080p preset
  ~10Mbps 无码率控制)重写为 AVAssetReader+AVAssetWriter:H.264 长边 ≤1280 只降不升、
  2.75Mbps average + 3.5Mbps/1s DataRateLimits 硬顶(纯 average 会被昏暗健身房噪点类内容
  顶穿到 ~8Mbps,review-loop 实测发现)、AAC 96k、fast-start mp4、保帧率与竖屏 transform;
  拍摄采集降档 .typeIFrame1280x720。2min 拍摄视频 ~150MB → ~40-50MB。
  闸门:StudentKit 657 绿 + 60s 1080p 超标源实测 ≤3.5Mbps + Demo sim build 0 warning。
  ⚠️ 切包前建议真机 smoke:昏暗场地拍 30s 上传,验体积与教练端可播。

- **spec 066 聊天实时化**(PR #305,2026-08-03 合入,52bd0a0):聊天从 30s/3s 轮询升级为
  WebSocket 实时推送(教练/学员两端同吃),断线无感回退轮询,回前台重连+立即刷新。
  服务端 = backend spec 032(PR #190 已合并部署 staging)。
  ⚠️ 切包前复核:真双端端到端实测证据(消息 ≤1s/断线回退/回前台追平)应已补进 PR #305。

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
