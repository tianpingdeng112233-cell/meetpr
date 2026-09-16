# MeetPR 发布历史(TestFlight）

> 以每次 **archive** 为界,每个 build 一段,最新在最上面。
> 下个版本进行中的内容见 [NEXT-RELEASE.md](./NEXT-RELEASE.md);**archive 上传后**把那份的「本版包含」整段挪到这里。

## 版本号规则
- app 版本(`MARKETING_VERSION`):`1.0`
- build 号(`CURRENT_PROJECT_VERSION`):每次上传 TestFlight 必须**严格递增**(Apple 硬性要求,号 ≤ 已上传的会被拒)。

## 每版记录模板(新版照抄)
```
## 1.0 (N) — YYYY-MM-DD — 状态
- 打包来源:<branch @ commit>
### 本版包含
### 已知问题 / 局限
### 测试反馈
```

---

## 1.0 (21) — 2026-08-23 — 🟢 已上传(外测 Ceshi 提审中)
- 打包来源:tag `beta/1.0-21` @ e826b6f0(`release/1.0`,1.0(20) 基底累积;切包时 tip == tag,零落差)
- 双端 demo 已同步本包(`MeetPR-demo-latest` detach @ e826b6f0,教练 iPhone 17 / 学员 iPhone 17 Pro 双 sim 现建,均 build 21)
- tag CI 绿(self-hosted runner,run 32668550503)

### 本版包含
- **学员端训练日定时提醒(spec 079,T1/P1)**:PR #334 → `24b871e0`。「我的」新增训练提醒:开关 +
  星期几多选 + 时间,默认勾选 = 档案里教练安排的训练日(缺档案回落一/三/五),首开才请求通知权限;
  纯本地 UNUserNotificationCenter,登出清理 + 进 shell 对账双保险。真机走查 08-21 通过。
- **训练视频角标:回看浮层 + 烧录导出(spec 078,T2/P1)**:PR #335 → `8b680322`。共享播放器加
  MeetPR 角标卡(全屏默认展开可收起;教练工作台恒 logo 圆标),式样正典 `docs/design/video-badge/`;
  「导出」把同款卡 + 渐变压暗 + 「教练:名」署名烧进视频存相册(add-only 权限),教练首次导出弹学员
  同意确认。配套 backend #262(反馈视频摘要带 `rpe`)已部署,学员「教练反馈→关联视频」的角标 RPE 胶囊点亮。
- **学员端六形态强度解码 + 忠实渲染 + 止血 + 周几对齐(spec 072 卡 1,T2/P1)**:PR #317 → `98b020fa`。
  `PlanSetDTO` 解 load_mode 九字段;新形式行渲染「72.5% × 5」「RPE 8–9 × 5」「165–175kg × 5」,
  消灭「-kg x 5」「目标 RPE 0/10」;非 RPE 新形式不再喂伪 RPE 给建议引擎;`anchor_weekday` 非 null 时 D1 对齐。
- **% 强度处方三锚换算 + S13 设计稿换皮(spec 034 §9.4,T2/P1,⚖️08-21 口径:app 全算学员不动手)**:
  PR #336 → `8a5c32ac`。`pct_anchor` 贯穿 DTO/投影/缓存;`PctAnchorResolver` 三锚(登记 1RM /
  e1RM 回落 / 当日顶组=前序行规则);2.5 kg floor;预填弱色+「自动换算」角标+来源行四变体。
  08-20 审计 R1(学员按错误预填重量练)的根治。
- **gym-day 归日改设备时区 + 墙钟 04:00(审计 R6,T2/P1,海外送审前置)**:PR #330 → `75907a8c`。
  `WorkoutDatePolicy` 去 Asia/Shanghai 硬编码,与 backend `trainingDay` 墙钟语义对齐,DST 安全;
  时区变化 PATCH /me/timezone。中国用户 24 小时参数化回归钉死零变化。
- **教练端成长 e1RM 改读 backend 序列(审计 R4,T2/P1)**:PR #332 → `6837de13`。
  `/coach/students/:id/exercise-stats` 同源于 web,本地计算路径删除;两端数字一致;三态。
- **学员端空状态/错误态兜底 9 条(08-12 审计,T2/P1)**:PR #331 → `d1766eae`。
- **教练端空状态/错误态兜底 8 条(08-12 审计,T2/P1)**:PR #333 → `3b6e3a7c`。
- **CoachKit 动作别名表对齐 plan-web(T1/P1)**:PR #337 → `d886c587`。`exercise-aliases.json`
  44 → 49 行,影响教练 Excel 导入自动绑定。⚖️08-23:`哑铃推肩` seed 行与 `坐姿哑铃推举` 不去重。

### 已知问题 / 局限
- iOS 26.5 **模拟器** AVFoundation 丢 Core Animation 层:模拟器导出的成片无角标,真机正常(spec 078 验收注意,不是 bug)。
- CN 构建仍不上报 timezone(既有 gate),出境旅行归日仍可能两端分裂,口径待拍。
- 推进制老包尾巴(≤1.0(17) 不写 completion)未根治,靠催升级止血(0059 只回填到 08-09)。

### 测试反馈
- (待收)

---

## 1.0 (20) — 2026-08-20 — 🟢 已上传(外测 Ceshi 提审中)
- 打包来源:tag `beta/1.0-20` @ f920a107(`release/1.0`,1.0(19) 基底累积;切包时 tip == tag,零落差)
- 双端 demo 已同步本包(`MeetPR-demo-latest` detach @ f920a107,教练 iPhone 17 / 学员 iPhone 17 Pro 双 sim 现建)
- tag CI 绿(self-hosted runner)

### 本版包含
- **[P0] 修「记录完成后消失」**(bdc9ab45):推进制下超过计划排期终点后,今日页/周历拉取
  计划内记录的日期窗口把新记的组滤掉,显示 0/N 已记录、重量看似丢失(服务端数据完好)。
  窗口上界改 max(末排期日, 今天)+1d。倪嘉骏 08-19/08-20 两报即此病,升级本包验证。
- **英文化三连(specs 075/076/077,#325/#327/#328)**:i18n foundation(六小模块 strings enum
  + 时区安全 today 匹配)+ StudentKit + CoachKit 全量英文;设备语言=英文才生效,中文设备零变化。
- **spec 074 Global 轨三通道登录(W4)+ #326 Global 域名指 api.meetpr.app**——仅 Global 构建轨生效,
  **CN 四配置产物逐字节零变化**(Release 产物实证:无 Google scheme/无 applesignin entitlement)。
  含 #322 拍板前 E.164 遗留清理。

### 已知问题 / 局限
- 推进制老包尾巴(≤1.0(17) 不写 completion)未根治,靠催升级止血(0059 只回填到 08-09)。

### 测试反馈
- (待收)

---

## 1.0 (19) — 2026-08-13 — 🟢 已上传(外测 Ceshi 提审中)
- 打包来源:tag `beta/1.0-19` @ 6e3d315f(`release/1.0`,1.0(18) 基底累积;
  tip `bb1b8d8b` 比 tag 多一个纯 docs commit = 真机 smoke 记录,零代码落差)
- 双端 demo 已同步本包(`MeetPR-demo-latest` detach @ 6e3d315f,双端 CFBundleVersion 实测 19)
- 真机 smoke(David 亲验 @ iPhone 12 / iOS 26.5):录满 2 分钟可上传 ✅ / 录制→自研裁剪页 ✅ /
  Live Activity 锁屏形态 ✅;**灵动岛形态未验——本机无该硬件**(需 iPhone 14 Pro 及以上)

### 本版包含
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

### 已知问题 / 局限
- **Live Activity 灵动岛形态从未在硬件上验证过**:开发机是 iPhone 12(无灵动岛),
  仅验了锁屏形态。若外测有 14 Pro 及以上机型,这是重点回收项。
- 录制上限的根因未从相机侧根治:`RecorderCapturePipeline` 仍是「先写帧再判断」,
  成片仍会比 120s 多出约一帧,靠 `enqueue` 的 0.5s 宽限兜住(取舍见本版第 3 条)。

### 测试反馈
_(待回收)_

---

## 1.0 (18) — 2026-08-08 — 🟢 已上传(外测 Ceshi Testing 中;2026-08-09 ASC 实证)
- 打包来源:tag `beta/1.0-18` @ f52c3ccf(`release/1.0`,1.0(17) 基底累积;tag = 发版线 tip,零落差)
- 双端 demo 已同步本包(`MeetPR-demo-latest` detach @ f52c3ccf)
- 台账收尾补记:上传后未即时挪账,2026-08-09 补收(David 提示)

### 本版包含
- **spec 071 训练日推进制(学员端换制,T3;PR #314)**:游标制取代日期锚定——今日卡/训练 tab
  以「第一个未完成日」为轴,推荐日期降级纯展示,顺延学员端触发链整删(净删 ~2200 行)。
  ⚖️08-08 三连拍板:未开始态=汇总卡;**结算权归学员**(长按「完成今日训练」唯一结算,
  backend #201 同步下线 auto);问教练=卡片角文字芯片唯一入口。配套 backend 035(0057+#197+#201)
  已上线 staging。闸门:loop 10+8 BLOCKER 清、703 测试绿、David 双机多轮真机走查收口。
- **视频线真机走查修复+改进四连(08-07,David 走查产出并亲验)**:#310 录制全程屏幕常亮;
  #312 强杀后重开自愈补传(僵尸任务收割+409 远端对账,10 BLOCKER 清);#315 录制控件让开
  状态栏;#316 回看可拖 scrubber+确认页掐头去尾剪辑+「建议剪辑」轻提醒。⚖️「重拍」全 app 除名。
- **spec 070 组内视频回看+留存至训练日结束(PR #309)**:「视频」即播放入口,本地秒开无感切
  云端;本地留存到训练日结束(冷启动清扫+500MB 护栏)。同 PR 带 069 并发加固(~21 竞态
  BLOCKER,16 条确定性竞态测试)+「已送达教练/还在路上」状态行。闸门:loop 1+11 轮 CLEAN,731 测试绿。
- **spec 069 视频后台无感上传(PR #308)**:成功路径零 UI;分片迁 background URLSession
  (杀 app/锁屏续传);失败退避+时间盒本地通知+打开 app 恒可见可重试。零 backend 改动。
  ⚠️与 070 必须同包(069 原始版竞态由 070 修复,防 cherry-pick 单带)。
- **spec 068 自建录制相机+直通快路(PR #307)**:AVCaptureSession 720p/60fps 边录边编码,
  「处理中」近乎归零;录制状态机抗来电/切后台;存相册改可选 toggle;恢复 #269 remux 直通。
- **spec 065 视频导出控码率(PR #304)**:AVAssetReader/Writer 重写导出,H.264 ≤1280 长边、
  2.75Mbps average + 3.5Mbps DataRateLimits 硬顶(纯 average 被噪点内容顶穿,loop 实测),
  2min 视频 ~150MB→~40-50MB。学员「上传特别慢」反馈根治。
- **spec 066 聊天实时化(PR #305)**:30s/3s 轮询升级 WebSocket 实时(两端),断线回退轮询,
  回前台重连追平。服务端 backend spec 032 已上线 staging。
- **spec 067 APNs 接入(PR #306)**:推送注册/授权/前台策略/点按路由,配 backend spec 033
  六类教练推送。**未配 ASC push key + SAE APNS_* 时代码安全休眠**。

### 已知问题 / 局限
- 067 推送硬前置未解:ASC APNs Auth Key(David 手动)+ SAE `PUSH_ENABLED`/`APNS_*` 未配,
  本包推送整体休眠;TestFlight 需 `APNS_ENV=production`。
- 071 换制后学员记满不自动结算,教练侧感知依赖学员长按——W2 教练分诊重定义再补。
- wellness 五档(PR #273)未进本包,仍等 backend #95(迁移 0047)。

### 测试反馈
- (待收集)

## 1.0 (17) — 2026-08-03 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已提交 Beta App Review)
- 打包来源:tag `beta/1.0-17` @ 982cfaf(`release/1.0`,1.0(16) 基底累积;tag = 发版线 tip,零落差)
- 闸门:tag CI 三项绿(**首跑红过一次**:self-hosted runner 所在 Mac 磁盘满,swiftc `No space left
  on device` 崩溃,非代码问题;清出 74G(主凶 = XcodeBuildMCP 构建工作区 70G)后重跑一把绿。
  减灾项:CI 加跑后清理,待立卡)
- tag 重切一次:8-1 曾在 bump commit `8510a38` 预打过 tag,未上传 ASC,8-3 按「未上传 + David
  明确并入」规则删旧重打到 982cfaf,合法重切
- 双端 demo 已同步本包(`MeetPR-demo-latest` detach @ beta/1.0-17,教练 Demo @ iPhone 17 /
  学员 DemoStudent @ iPhone 17 Pro)

### 本版包含
- **[P0] 辅助项重量可设 20kg 以下(59c66ae)**:组录入弹窗三条重量输入路径(初始值/步进器/
  数字键盘)此前对所有动作一律钳 20kg 下限(空杠假设),辅助项(哑铃/绳索/自重等,动作库约
  1000 条)低于 20 的真实重量被静默改写成 20 落库。现按 `isAccessory` 分流:辅助项下限 0,
  杠铃主项/变式保留 20kg 空杠护栏。学员内测反馈直接触发。
- **e1RM 建议重量三修(PR #301,spec 050 修订)**:①失败组不再作同日沿用种子;②教练事后校准
  coach_rpe 追更学员端本地 e1RM 历史(`E1RMCoachRPEReconciler` + `E1RMHistoryReplayService`,
  revision CAS 防并发覆盖,PR 事件幂等补发报真实前纪录);③主项无建议时组录入面板显示缺失
  原因,不再静默回落 20kg。
- **视频打点(spec 063,PR #299 + #300 单一档拍板)**:教练视频反馈工作台打时间点标记,
  学员端反馈收件箱共享播放器,打点列表点击即 seek。backend #150 + 迁移 0054 已先行上线。
- **打点标注帧查看(spec 064,PR #302)**:学员点带铅笔标的打点 = seek + 暂停 + 覆盖显示教练
  画的标注帧。上游 backend #181(迁移 0055)与 web 教练端已上线。
- **RPE 刻度选档修复 + 拍摄按钮回首屏(PR #290)**:修「RPE 滚动老是选错」三缺陷(命中按真实
  竖条中心/抬手不重算/滚动横抖不误写),拖动加跟随气泡;852pt 机型杠铃图 148→108pt,
  拍摄/相册回到首屏。
- **杠铃卧推升格主项变式(PR #303,随 backend 0056)**:内置动作库杠铃卧推
  accessory→main_lift_variation/bench(竞技卧推不动)。后端迁移 0056 已先行应用并部署
  (sha-2adbbeb),先后端后 iOS 顺序正确。

### 已知问题 / 局限
- 注册页「学员 · 自己练」仍是空壳(承 1.0(14),待拍板)
- gym-day 残留:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉)
- ASC What to Test 字段含 emoji 会触发无提示校验错(✏️ 实测中招),外测提审文案用纯文字

### 测试反馈
_(待收集)_

## 1.0 (16) — 2026-07-31 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已提交 Beta App Review)
- 打包来源:tag `beta/1.0-16` @ e89c1b7(`release/1.0`,1.0(15) 基底累积;tag = 发版线 tip,零落差)
- 闸门:tag CI 三项绿(**首次切包时红过一次**,见下)
- Archive 起点:`~/Projects/apps/MeetPR-archive-1016`
  ——⚖️ **2026-07-31 David 拍板改掉**:以后统一用 `~/Projects/apps/MeetPR-release` 一棵树,
  不再每包新建 archive 树(切来切去太麻烦)
- ⚠️ **首次 tag CI 红**:`inMemoryStudentPlanRepositoryStacksAcrossDaysAndUndoesLatestBatch`
  在 `beta/1.0-15` 上同样复现,证明是既有的日期耦合脆弱测试,非本包引入——测试用
  `utcCalendar.startOfDay(Date())` 取「今天」,而 `StudentDemoSeed` 把**设备本地日**映射成
  UTC 锚点,两者不一致时「今天」落到种子休息日,`shiftPlan` 抛 `.onlyToday`。
  在 UTC+1 是每天凌晨一小时,**在东八区是每天 00:00–08:00**。已修(`e89c1b7`,测试口径对齐种子)
  并同名重切 tag。
- ⚠️ **本包唯一没过像素闸门的面**:教练端今日页「本周概况」——教练 Demo 种子没有在跑计划,
  模拟器上恒空态,从未与样机同屏对照。已写进外测 What to Test 请测试者重点看。
- 不进本包(留下一班车):wellness 五档量表(#273,硬前置 backend #95 未合未部署)、
  spec 062(SPEC 至今未提交)

- **教练端 iOS 全量 v3 浅色迁移**(PR [#298](https://github.com/tianpingdeng112233-cell/meetpr/pull/298)
  合集,merge `9e86b3b`,P1):教练端此前**一个 v3 token 都没有**——`MeetPRApp` 把它钉在 `.dark`,
  黑金波 PR #279 的收据明写教练端全程零 diff。本波按 David 2026-07-30 交付的《MeetPR 教练端》样机,
  把四个 tab 全部做成 v3 浅色,四张卡收拢为单次合并(叠层 PR 逐个合会合进各自的 base):
  - **卡1**(#295)外壳 + 今日 + 学员:5 tab → **4 tab**(今日/消息/学员/我的),「编排」**只摘 tab 入口、
    `Planning/` 代码原样休眠**;原生 `TabView` → ZStack 分页 + 自绘 tab bar;今日页待办队列 + 本周概况热力卡。
  - **卡2**(#296)消息合流 + 学员详情五子 tab:三段式分段控件 → 单一会话列表(一个学员一行,
    姓名进聊天、深色胶囊进待反馈视频,两条路分开);详情用「资料」换掉「执行」;聊天/申请资料/视频列表
    改为**全屏、不显示 tab bar**;教练侧 Demo 聊天种子对齐花名册 UUID。
  - **卡3**(#297)我的 + 收尾:邀请码 / 帮助与反馈 / 隐私与条款 / 退出登录(**补了二次确认**);
    邀请码屏换皮保留全部能力;**教练侧评估期封存**(2026-07-13 那次只关了学员一半,教练仍能打开
    被封存的评估摘要编辑器)。
  - **卡4**(#298)视频反馈工作台:v2 纯文本框表单 → 深色播放器 + 进度条 + **0.5×–2× 倍速** +
    组信息四宫格(本组重量/次数/RPE/组序)+ 「跳过 · 看下一段」**全局队列并在末尾回卷**。零后端
    (`StudentVideo.setLogID` 本就链到 set log,队列只是没透传)。
  ⚖️ **四条产品拍板**(2026-07-30,勿翻案):4 tab / 教练端恒亮 / 「＋打点」仍 deferred / 1RM 教练可改
  学员只读(跨端卡,不在本波)。
  ⛔ **样机画了但故意不做的**(后端不存在,画了就是死链或编数):教练资料编辑、三宫格统计、动作库、
  提醒规则、导出执教数据、注销账号;用户服务协议无 URL 故为禁用态。
  证据:CoachKit 423 / DesignSystem 70 / ChatUI 67 / AppShell 66 / StudentKit 620 / RepositoryContracts 5
  全绿(合并后复跑)、`xcodebuild -configuration Demo` 0 warning、`swiftlint --strict` +
  `swift-format --strict` 干净;模拟器逐屏实点(四 tab 切换、消息两条路径、五子 tab、视频队列 1/6 与倍速改速率、
  退出确认、评估卡消失)。互审 10 轮 + 定向返修 7 轮,19 条 BLOCKER 全部处置,transcript 四份在
  `~/Brain/wiki/projects/MeetPR/reviews/2026-07-30-coach-v3-*.md`。
  ⚠️ **教练 Demo 种子没有在跑计划**,所以今日页「本周概况」在模拟器上恒空态、学员页全员「无计划 0/0」——
  这是种子缺口不是 bug,但也意味着**那一屏始终没能与样机同屏对照**,切包前建议 David 用真实教练账号走一遍。

- **App 图标换成定稿「片里的折线」**(P1):David 2026-07-30 定稿的杠铃片 + 折线标记落地——
  纸底 `#F5F6F8` + 金盘 `#D97706` + 走平后拐头冲上去的折线 + 42% 淡段 + 上弧 + 下沿
  PERSONAL RECORD,两色无渐变。light / dark 共用同一张 1024(无 alpha、3 通道),tinted 另出
  灰度挖空版(圆盘实心、盘内形状挖成透明,系统自己上用户色)。矢量真源 + SPEC + 重出 PNG 的命令
  在 `docs/brand/`,以后改图标从那儿改。
  证据:asset catalog 编译 0 警告、iPhone 17 模拟器主屏 Default / Dark / Tinted 三态亲验。
  这是内测用户**看得见的品牌变更**(旧图标是黑底 MEET PR 字标)——**David 2026-07-30 看过定稿对照与
  三处上屏截图后拍板「没问题,进下班车」,prep-beta 时不必再问一遍**。同时确认的还有两处定稿没写口径、
  由实装侧定的:dark slot 与 light 共用同一张;tinted 走灰度挖空版。
  ⚠️ 定稿里还有两项本包没做:**启动页/破 PR 的图标动效**(圆盘淡入 → 折线画出 → 圆点弹入 →
  上弧扫出,与学员端「新纪录」徽标同一动作)只写在 SPEC 里,未实装;**Watch 圆形遮罩变体**
  本仓无 watch target,不适用。

- **学员端首屏与切 tab 提速**(PR #289,`aa54155`,P1):David 在 1.0(15) 实机反馈「加载特别慢,
  骨架屏要看很久,开始训练跳转不丝滑」。三层根因逐条修:①9 个 ViewModel 改保鲜刷新——原先 `load()`
  首行无条件 `state = .loading`,手里有数据也先扔掉退回骨架;②串行瀑布压平——今日页 5 段串行 → 4 路
  并发 + 1 段真依赖,训练页 6 段 → 3 跳,周概览去掉重复投影;③切回今日 25 秒节流窗(窗口内只刷日志/
  反馈/聊天/PR 数,**下拉刷新永远强制全量**);④动作库落版本化磁盘缓存 + `If-None-Match`/304
  (此前只有随进程消亡的内存缓存,每次冷启动都在首屏关键路径上全量重下 518KB);⑤「开始训练」把已加载
  的 plan 交棒给训练页,首帧立即出内容。
  证据:StudentKit 615 + Networking 99 测试绿、`xcodebuild -configuration Demo` 0 warning、
  **2026-07-30 David 真机(iPhone 12,Release 配置连真实后端)验收通过**——「不再重新加载了」。
  配套后端 gzip 已于同日部署 staging(backend #141,`sha-6c65173`,JS bundle 实测省 69%),
  **本包发出后学员端冷启动还会再快一截**(动作库 518KB → 约 30KB)。
  ⚠️ 收货期两轮定向返修拦下的坑,改这块前必读:交棒路径最初写成 `if let preloadedPlan { return ... }`,
  直接跳过 `fetchCurrentPlan`——而那个方法的 cache-first 分支**顺带启动仓储后台刷新**,于是教练改的
  计划不会出现;修完又发现计划没变时会白白重取一轮当日快照,再加等值比较挡掉。
  ⚠️ 另一条别重走的弯路:我曾判定 `MeetPRRiseInModifier` 的 `guard !Task.isCancelled` 会让卡片
  **永久透明**并开了 fix 分支——**前提错误,已撤回**。`.task(id:)` 每次 view appear 都会执行,
  id 只是「值变化时额外重建」的附加触发;实测(delay 放大到 2s)切 tab 回来内容立即完整、零重播。
  详见 `~/Brain/wiki/projects/MeetPR/reviews/2026-07-29-rise-in-cancellation.md`。

- **登录页 v3 浅色重做**(PR #291,`dfc24a8` 前一个 merge,P1):兑现 David 2026-07-29 提的「登录页重做」,
  两个待拍板都由 David 2026-07-30 提供的《MeetPR 登录 + 绑定教练(浅色)》设计稿一并解掉——**登录页跟浅色**,
  参照物就是稿子的 4a 屏(已抽成 `docs/design/login-v3/4a-login-light.html` 入仓,原始导出是 7MB 的
  design-canvas HTML,内联了 gzip 运行时,不适合入仓)。
  版式对调成 hero 在上 / 表单在下,字段改卡片式(`AuthPhoneField` 新增,带纯展示的 `+86` 前缀),
  密码加明文开关,CTA 换扁平金色矩形。`preferredAppColorScheme` 未登录态 `.dark` → `.light`(**只此一行**),
  coach 恒暗与 student 读 `@AppStorage` 两条分支零改动。
  ⚠️ **已知连带**:教练登录会「浅→暗」闪一下(David 已接受,没为它加逻辑);学员那边原有的「暗→浅」闪反而被修掉。
  ⚖️ **David 拍板 A**:忘记密码整行删掉(全仓零实现,不做死链)、条款行只写「隐私政策」(服务条款零 URL)。
  ⚠️ **条款行的隐私政策当前打不开**:`https://meetpr.app/privacy` 实测 DNS 解析到 `192.64.119.206`
  (Namecheap 停放段)但 HTTPS 超时,同机 `apple.com` 200。死链在 production 本已存在(原先藏在
  「使用数据说明」sheet 里),本包把它提到了**人人必经的首屏**。⚖️ David 拍板 D:先留着不阻塞发版,
  域名上线单独跟进。**切包前值得再 curl 一次**。
  证据:AppShell 65/65、`swiftlint --strict` 0 违规、iPhone 17 模拟器四态亲验(浅色初始 / 手机号聚焦 /
  密码明文 / 格式错误)。
  ⚠️ 改这块前必读的两条:①自绘按钮只加 `.disabled()` **不会**改自绘背景,空表单下按钮会满亮可点
  (真回归,截图证实,已修成 `surfaceRaised` + `textDisabled`);②`MeetPRRadius.point14` 实际是 **16**、
  `point9` 是 **10** —— `Radius.swift` 声明了 `§2 radius canon: 4/10/12/16/20/999` 并把所有 `pointNN`
  别名 snap 到这六档,**这是文档化的既定量化不是 bug**(review-loop 就此对质,Codex `CONCEDE`)。
  名字骗人这件事已另开仓级重命名卡。
  详见 `~/Brain/wiki/projects/MeetPR/reviews/2026-07-30-login-page-v3-light.md`。

- **绑定教练流 v3 浅色换皮**(PR #292,`dfc24a8`,P1):同一份设计稿的 4b/4d 屏。
  ⚖️ **David 拍板 A = 换皮**:10 位邀请码、`displayName` 必填、「提交 = 发申请等教练同意」机制一律不动。
  邀请码改分格输入(**2×5**,稿子画的是 6 格单行但 10 格挤在 342pt 里每格只剩约 27pt、装不下 mono 26pt),
  加「从剪贴板粘贴」按钮(教练多半微信发码),错误态染红且**不清空已输入**且提交按钮仍可用(能直接重试)。
  顺手修掉两个输入缺陷:字母表外字符(`O`/`0`/`I`/`1`)能打进格子但永不可能通过校验、按钮永久禁用且零解释;
  格下提示丢了 `I/O/0/1` 排除规则(唯一携带该信息的 `codeFormatHint` 已成死代码)。
  ⛔ **九条有意偏离设计稿**(跳过出口 / 4c 教练确认屏 / 教练卡六个字段 / 隐私承诺文案 / 今日页常驻卡 /
  步骤条等)全部写进了 PR 描述与 `docs/design/login-v3/CARD-bind.md`,**别当成漏做**;其中「门口死路」
  已开成独立 T3 卡(要角色变更能力 + 自练形态先解禁)。
  证据:StudentKit 620/620、`xcodebuild -configuration Demo` 0 warning、lint 全干净。
  ⚠️ **验证缺口**:这一屏**没人在模拟器里亲眼看过**——Demo 模式按设计穿过绑定门直落 5 tab
  (`RootViewDemoDefaults.swift:7`,spec 031 D10),要看得在 staging 造未绑定的 coachedStudent 真账号
  (走 `/testacct`)。**prep-beta 走查时优先补这一屏。**
  ⚠️ 改分格框前必读:透明 `TextField` 盖在自绘视觉上时,**平台控件保留自己约 16pt 的 intrinsic height,
  hit-test 走它的真实 frame**——`ZStack` sibling 加 `maxHeight:.infinity` 和改 `.overlay` 都无效
  (三次实测恒为 `342×16 @ y=69`,而网格 154pt)。必须走显式 `tap → isFocused = true`。
  详见 `~/Brain/wiki/projects/MeetPR/reviews/2026-07-30-bind-flow-v3-light.md`。

## 1.0 (15) — 2026-07-29 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已提交 Beta App Review)
- 打包来源:tag `beta/1.0-15` @ 4739896(`release/1.0`,1.0(14) 基底累积;tag = 发版线 tip,零落差——其后仅追加纯 docs commit)
- 规模:beta/1.0-14 起 **52 个 commit**,1.0 线至今最大一包
- 闸门:tag CI 三项绿;八个候选逐个 `merge-base --is-ancestor` 核实真在发版线上
- Archive 起点:专用干净树 `~/Projects/apps/MeetPR-archive-1015`(detached @ tag,零脏文件)
- ⚠️ 已知未验:黑金 v3 全程只在模拟器验证,真机学员端主链路未走;另见 FOLLOWUPS **F-030**(分享该组视频在 Demo 上勾不到,真机待核)

- **学员端黑金 v3 UI 全量重做**(PR #279 已合 `dd699fc`,2026-07-29):今日 / 训练 / 成长 / 我的
  四屏 + 记录链路(SetEntry / 数字键盘 / 组间休息)+ 收官 overlay(结算庆祝 / 训练回顾 / 顺延 /
  反馈档案)+ 七个空状态 + 动效逐参对齐 + 通知并入聊天。**双主题,默认浅色**(我的 → 外观 可切
  跟随系统 / 深色);教练端与登录流保持恒暗、全程零 diff。设计系统正典落
  `docs/design/handoff-v3/DESIGN-SYSTEM-CANON.md`(⚖️ David:今后学员端 iOS 新设计以它为准)。
  - 合并同时把发版线 spec 029(C0 组号契约 / C2a-c 组引用卡与「问教练」)接进 v3 各面,
    功能不回归;~~**遗留视觉债**:组引用卡与分享选择器仍是 ChatUI 现成样式,黑金化是下一张卡~~
    (清单见 `docs/design/handoff-v3/SETREF-BRIDGE-PHASE1-RECEIPT.md` 末节)——**✅ 已由 PR #287
    还清**(见下条)。
  - 闸门:每卡 review-loop CLEAN(累计 100+ blocker)、全量 SPM 1439 绿、三 configuration
    build 0 warning、lint/format strict 零、CI 三项绿。
  - ⚠️ 上包前建议真机走一遍学员端主链路(本波全部验证在 iPhone 17 模拟器完成)。

- **聊天面黑金化 + 「问教练」入口进 hero**(PR #287 已合 `c028860`,2026-07-29):v3 学员端重做没覆盖
  到 ChatUI 模块,自己发的组卡片在整条金色对话流里是块红砖;整模块统一到 v3 token。⚠️ 施工中踩过
  一个坑并已修:`goldText` 是「深色底上的金字」、`ctaText` 才是「金底上的深色墨」,用反会金底金字
  几乎不可读。同时把「问教练」从页面最底部挪进 hero 操作行——记完一组休息条立刻 pin 到底部把它
  盖住,恰恰是最想问教练的那一刻;完成态 hero 行消失,保留通栏变体落在完成区。

- **学员可分享「计划了但没练」的组 + 组卡片按参考设计重做**(PR #288 已合 `64d6b6d`,2026-07-29,
  SPEC 029 §11 修订 R3):⚖️ David 07-29 两拍——①「今日所有训练无论练完没练完」= 连计划组也能发;
  ②参考设计的「第 1 组 / 3」总组数要做,接受三仓小改。
  - 候选 = 当日 logged ∪ 当日 planned,按 plan set 去重(已练过的组只出现一次,落「已完成」而非
    「今日计划」);logged 侧 eligibility 放宽,不再要求打完成勾——**有数值的组就值得拿去问教练**。
  - 卡片改为深色卡 + 金色侧边条(贴外侧)、表头带发送时刻、两列数据行 + 竖分隔线、RPE 值金色、
    备注嵌套气泡、送达态通栏页脚。
  - ⚠️ **组号口径在 iOS 侧是反的**:backend 读的 `plan_sets.set_number` 本来就 1-based,但投影层交给
    iOS 的 `PrescribedSet.setIndex` 是 0-based,故 **iOS 两条路径都 +1、服务端只有 logged 路径 +1**。
    spec 原话「planned 不许 +1」只对 backend 成立,照搬会把第 2 组发成第 1 组。
  - ⚠️ 计划里的非规范值(`plan_sets` 无 RPE 步进约束,可写 7.25)**整组排除,不四舍五入**——
    永不悄悄改教练开的处方。
  - **明确没做**(spec 写死 deferred,别当遗漏):「新纪录」badge(需 PR 判定,数据里没有,不许用近似
    规则冒充)、连发折叠紧凑行(属消息列表分组归并)。
  - **硬前置已满足**:backend #135 已合并并部署 staging(`sha-267d61a`,无迁移)。plan-web #48 已合
    main,**web 换装待做**。
  - 闸门:review-loop 4 轮 2 BLOCKER;CoreModels 145 / ChatUI 63 / Networking 98 / StudentKit 595 /
    DesignSystem 69 = 970 绿;swiftlint strict 零;CI 三项绿;DemoStudent 模拟器实走(计划组发送、
    分区、去重、两种首行前缀全验)。
  - ⚠️ **切包即失效的前提**:`set_ref` 就地扩 v1 不升版本,靠的是「该形状从未发过版」。**1.0(15) 一切包
    这条就不再成立**,之后再改 `set_ref` 必须升版本 + 写降级路径。

- **e1RM 口径修订:取消低 RPE 门 + 消费教练校准 + PR 改实测重量**(PR #286 已合 `1c2c787`,
  2026-07-29,spec 050 修订):①入选门取消(分段口径 nil/<6→Epley、6–10→RTS、>10 拒);
  ②`coach_rpe` 全链路(取 `coachRPE ?? rpe`,教练端成长页同步);③**PR 判定改成实测重量**——
  只有真正完成的重量超过 max(登记 1RM, 历史实测最高) 才算 PR,新增 `E1RMWeightBaseline` 持久实体、
  基线单调更新、v2 重放按时序原子重建;④建议重量只吃 RPE≥7 或已校准组(与显示口径分离)。
  - ⚠️ **本卡 base 停在 v3 落线之前,是 rebase 上来的**,四处冲突 + 一处 git 自动合并语义断裂,
    解法逐条记在 PR 评论里。三条对后人有用:**a)** v3 已退役 PR 庆祝横幅(`PRBanner` 与成长 tab
    横幅双双移除),但 `pendingPRBanner` 检测状态仍在、展示改走「新 PR」计数器——**别再把横幅接回来**;
    **b)** `InMemoryE1RMRepository`/`LocalE1RMRepository` 里数组叫 `storedPREvents` 而非 `prEvents`,
    因为后者已是方法名(`prEvents(studentId:since:)`),写成裸 `prEvents` 会解析到方法;
    **c)** `LocalE1RMRepository` 的持久化已收敛为单一 `state.json`,`loadPRs()` 不复存在。
  - 闸门:review-loop 2 轮 CLEAN;八包 **1434 测试全绿**;swiftlint strict 零;CI 三项绿。

## 1.0 (14) — 2026-07-24 — 🟢 已上传(Neice 免审生效;**外测 Ceshi 同日已过 Beta App Review,在 Testing**)
- 打包来源:tag `beta/1.0-14` @ 7125a21(`release/1.0`,1.0(13) 基底小步直推;tag = 发版线 tip,零落差)
- tag CI 绿(run 30101801797)
- 两端 demo(模拟器)已从本 tag 现建同步(CFBundleVersion=14,教练 iPhone 17 / 学员 iPhone 17 Pro 各截图留证)
### 本版包含
- **[P1] 学员端看得见教练在说哪条视频**(spec 060,PR #271,`a11764f`):教练在 plan-web 视频弹窗里
  对某一条片子写的反馈,学员在反馈详情能看到「动作 · 第 N 组 · 负荷」的关联卡并点开全屏回看
  (0.5/1/1.5/2 倍速,链接过期自动重签)。同批修掉教练端一个既有 bug:待回复视频队列原先按动作
  粗匹配,同一动作两条视频回了一条、另一条也跟着从队列消失;现精确到视频,升级前的老反馈仍按
  动作级遮蔽。依赖 backend spec 025 + 迁移 0046(2026-07-22 上线 staging,`sha-cc1ba36`)
- **[P1] 教练↔学员 1:1 聊天**(spec 058,PR #272,`354f35c`):文本 + 图片,已读回执。学员端每个 tab
  都能进——聊天未读并进已有的通知铃(铃升级成消息中心,聚合「新计划 / 未读反馈 / 教练消息」),
  「我的」tab 另有「我的教练」卡片带最新消息预览;教练端五个 tab 的 header 都有消息入口,会话列表
  复用「接收」tab 的第三个分段。W1 用轮询(3s),APNs 推送是 W2 未开工。**仅限受教练学员**:自练学员
  路径显式关闭(有单测锁)。依赖 backend spec 024 + 迁移 0045(2026-07-22 上线 staging,`sha-7b65af4`)
- **[P1] 训练页摄像头直达拍摄**(`3808f44`):当前组大卡右侧的灰色摄像头在尚未附视频时不再先开
  「记录此组」弹层,而是直接进入系统视频拍摄页;首次使用仍先显示一次教练可见性说明。上传中/已上传
  继续进入详情管理,上传失败继续直达重试;无视频摄像头能力的环境安全回退到原弹层/相册入口
- **[P1] 学员周历训练日不再「渗」到下一天**(PR #274,`02da952`):网页端发布在 7/24 的训练日,学员端
  7/25 也能选中并看到同一份训练——选中日匹配的主路径用设备日历、fallback 用固定 UTC,北京 25 号零点
  仍是 UTC 24 号导致二次命中,UTC+8 下每个训练日必现。现统一为「日历天身份」判定(计划日按 UTC 取
  年/月/日,选中日按设备日历取,分量相等才同一天),周序推导同步收编;新增 6 个注入时区单测
### 已知问题 / 局限
- **注册页「学员 · 自己练」是空壳**(本版发现,非新引入):该角色档从最早的登录流(#27)就在注册页上,
  但真正的自练能力(选训练模板 · 自主跟练)属 solo 波,冻结在 main,发版线不带。发版线上
  `selfTrainStudent` 路由到 `studentRoot(activeCoach: nil, chat: nil, allowsChat: false)`,即一个没有
  任何计划来源、也没有自练空态引导的学员壳子。1.0(7)–(13) 同样如此并已多次过 Beta App Review。
  **待拍板**:发版线上是否先把这一档从注册页藏起来,等 solo 波解冻再放
- gym-day 残留:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- WeekOverview/TrainingHistory/周历圆点等同族 UTC 口径点本版未动(UTC+8 下现行为正确),归 gym-day 全量对齐待办
- 捞回队列余项未上车:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡 / #234a 非 UI 拆包
- 聊天上车但 backend #99(注销账号清聊天成员,迁移 0048)未合未部署——内测用户注销会留聊天成员残留
### 测试反馈
- (待收集)

## 1.0 (13) — 2026-07-19 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已提交 Beta App Review)
- 打包来源:tag `beta/1.0-13` @ 990634b(`release/1.0`,1.0(12) 基底小步直推)
- tag CI 绿(SwiftLint/swift-format/Build & Test,run 29664674130,~9min)
- 两端 demo(模拟器)已从本 tag 现建同步(CFBundleVersion=13)
### 本版包含
- **[P1] 组录入大卡片显示动作名**(d40351f + 4958c1c):原「第 02 / 02 组」红色小字改为白色加粗
  动作名标题 + 灰色「组序/总组数」计数(如「相扑硬拉 2/2」),练到第二个动作起也能一眼看出当前组
  属于哪个动作
- **[P1] 学员端 RPE 处方组的建议重量**(8f76580,#270):教练只开 RPE 不开重量的组,组录入表重量
  不再从 0 起——主项:同日同处方已完成组续填(「建议 · 同上组」),否则按当前 e1RM 反查 RTS 表
  向下取整到 2.5kg 台阶(「建议 · 基于 e1RM x」);主项变式/辅助项:同日续填,否则回填该动作上次
  训练重量(「建议 · 上次重量」,回看 12 周)。学员改过/已记录永不覆盖
- **[P1] 组录入 RPE 标签换 RIR 白话说明**(fef2090):四档笼统词改为逐 0.5 档具体余力说明
  (8.5 →「还能多做 1-2 次」,10 →「力竭,无保留」),口径与 onboarding 文案、
  Tuchscherer–Zourdos RIR 量表一致
- **[P1] 学员端看得到教练动作备注**(9c788a1 + 5f34e96):训练页当前组大卡显示网页计划编辑器
  「备注」列的动作级备注(灰色「教练备注」标签 + 全文换行);练完/回看历史日显示在动作卡头与
  「全部训练历史」——此前该字段存到后端但学员端从不展示
- **[P1] 相机录制修复**(eaa88f7,port of #268):退出前先妥善收尾录制、闪光灯默认关
  (同 PR 的 720p 降档已被 #269' 推翻,最终态见下条)
- **[P1] 视频 1080p 采集 + 免重编码上传**(3bfcce0,port of #269):实机核查证实 `.typeHigh` 即
  1080p H.264,回滚 720p 降档;≤1080p H.264 源导出改 passthrough remux(不重编码,导出即完成,
  保留相机码率 ~15Mbps),非 H.264 源保留 1080p 重编码兜底,失败一次性回退 + 全路径清理半成品
### 已知问题 / 局限
- gym-day 残留:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- 捞回队列余项未上车:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡 / #234a 非 UI 拆包
### 测试反馈
- (待收集)

## 1.0 (12) — 2026-07-17 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已提交 Beta App Review)
- 打包来源:tag `beta/1.0-12` @ 29f407b(`release/1.0`,1.0(11) 基底小步直推)
- tag CI 绿(SwiftLint/swift-format/Build & Test);真机走查 David 2026-07-17 亲验
  (含 #243/#249 1.0(10) 遗留项 + 1.0(11) 新项运行态)
- 两端 demo(模拟器)已从本 tag 现建同步(CFBundleVersion=12)
### 本版包含
- **[P1] 「查看回顾」入口押后到滑动完成之后**(9551a98,源自 David 1.0(10) 截图反馈):所有组打勾后
  不再同屏出现「今日训练完成 · 查看回顾」banner 和「滑动完成今日训练」滑条——banner 只在滑动确认+
  回顾页点「完成」后出现;历史只读日无滑条,banner 保留作回顾唯一入口。DemoStudent 模拟器亲验;
  review-loop 1 轮 CLEAN(transcript `~/Brain/wiki/projects/MeetPR/reviews/2026-07-17-review-entry-gating.md`)
- **[P1] refresh 400 视同硬失效干净回登录页 + wire key 契约测试**(c329981 + a15e158,backend #76
  键名事故的 iOS 侧姊妹修复):前台 token 刷新遇 400 不再困在重试死胡同,与 401 同走清会话回登录;
  编码契约测试钉死 `refresh_token` 键名防复刻。AppShell 测试全绿;review-loop 1 轮 CLEAN
  (transcript `…/2026-07-17-refresh-400-hard-failure.md`)
- **[P1] 视频上传源临时文件泄漏修复**(e9ab0d8,port of #263):相册/相机选完视频后,输入源 tmp 拷贝
  在导出成功/失败/超时长被拒三路都会被删除,不再每条视频在沙盒多留一份 15–200MB 拷贝
  (VideoUploadManager 明确 source ownership)。3 例新单测;review-loop 1 轮 CLEAN
  (transcript `…/2026-07-17-video-upload-source-cleanup.md`)
- **[P1] 赛扣偏好按学员隔离 + 配重数学补测试 + 赛扣 VoiceOver**(56bf338,#256 补审产出):同设备
  切换学员账号不再继承上一账号的「上赛扣」选择(key 按学员 UUID 分区,已有测试员的勾选一次性重置为
  默认关);配重数学抽纯函数 SetEntryPlateMath 补 8 测;开赛扣时 VoiceOver 同步播报
- **[P1] 训练 tab 按「主项及变式」/「辅助项」分段**(3753764,#264,David 拍板按 exerciseType gate):
  保持计划原序;辅助项记录弹窗不再显示杠铃配片图、配片明细和赛扣开关,重量输入与完成/失败流程不变。
  源自 David 教练端截图反馈(蝴蝶机夹胸配杠铃图);review-loop 2 轮 CLEAN
  (transcript `…/2026-07-17-training-tab-accessory-split.md`)
- **[P1] 学员端视频上传前时长裁剪**(dff484c,port of #260,David 拍板方案 A 系统裁剪 UI):超长视频
  从「整段拒绝重选」改为进系统裁剪屏截到 120s 内(拍摄路 allowsEditing 直进裁剪、相册路
  UIVideoEditorController);不可编辑视频降级走原路径;结束语义抽 VideoTrimCompletion/SingleShot
  (exactly-once + tmp 清理,与 e9ab0d8 的 enqueue 所有权互补)。review-loop main 侧 3 轮+1 对质、
  port 侧 1 轮 CLEAN(transcripts `…/2026-07-17-video-trim.md` 与 `…-video-trim-port.md`)
### 已知问题 / 局限
- gym-day 残留:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- 捞回队列余项未上车:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡 / #234a 非 UI 拆包
### 测试反馈
- (待收集)

## 1.0 (11) — 2026-07-17 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已过审在 Testing)
- 打包来源:tag `beta/1.0-11` @ b5ffc0f(`release/1.0`,1.0(10) 基底小步直推)
- 外测组 Ceshi(9 testers)本包已在 **Testing**(ASC 2026-07-17 确认),外测与 Neice 首次同版在测
- 两端 demo(模拟器)已从本 tag 现建同步(CFBundleVersion=11)
### 本版包含
- **[P1] 导入历史进 e1RM 基线**(spec 053,#227 六子卡重做,port of #227):教练在 plan-web 导入的
  过去计划(推定完成)回填为学员本地 e1RM 历史——成长页显示弱化虚线历史段(图例「浅色 = 导入的
  历史计划」),头条/卡片在近 28 天无记录时回退「历史最佳」;导入成绩超自填 1RM 时一次性问询
  (确实/没有),未确认前隔离不进基线;导入点作 PR 基线但自身不触发庆祝,完成率/训练次数统计排除
  推定记录(历史列表仍可翻)
- **[P1] 学员端 e1RM 曲线改为破纪录阶梯线**(spec 053 修正案,David 07-17 拍板):只在破纪录时
  跳升、永不回落,平延到今天;移除逐组散点(低置信隔离点保留弱化可见);今日/成长卡片按 90 天窗口
  裁剪,delta 同窗口口径;记录线/记录点改白色渲染,最新纪录日期可点出标注
- **[P1] 训练日切日改凌晨 4 点截断**(gym-day,镜像 backend spec 017):跨 0 点训练不再被自动锁成
  只读「自动结束」,可一路记到凌晨 4 点;凌晨冷启动/「回到今天」落在仍可编辑的前一训练日。源自
  内测学员反馈「晚上12点自动结束」
- **[P1] 重量记录界面 v2**(PR #258,源自 David 离线 mockup):RPE 从 ⊖⊕ 步进改**拖动刻度尺**
  (5–10 步进 0.5、松开确认、强度词 留有余力/中高强度/高强度/接近极限;非 0.5 预设值 seed/save
  自动 snap);**杠铃条按真实片规格重画**(Φ 直径→高、厚度→宽,15≠10;规格表原样渐变 + 居中 +
  右端粗套筒截断 + 八角赛扣);**底部按钮反白**(完成本组白底黑字 / 未完成失败描边)。review-loop
  3 轮收敛,StudentKit 350 测试绿
### 已知问题 / 局限
- 「查看回顾」入口押后(9551a98)落线晚于本包 tag,**随 1.0(12) 发**
- gym-day 残留:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- review-loop 补审欠账仍挂:fadbc3a(1.0(9) 遗留)+ #256(1.0(10) 遗留,Claude 已亲审 diff)
- #243 说明卡/设置页 + #249 视频占位的运行态真机亲验仍欠,随本包走查连同新项一并验
### 测试反馈
- (待收集)

## 1.0 (10) — 2026-07-13 — 🟢 已上传(Neice 免审生效;外测 Ceshi 已提 Beta App Review)
- 打包来源:tag `beta/1.0-10` @ ef2af52(`release/1.0`,1.0(9) 基底小步直推;tag CI 三检绿 +
  整 app 模拟器构建复验——#243/#257 各自 CI 未测过合体树,故合并后在发版线 head 补了本地真编译)
- 本包为**首个带埋点的包**(spec 043):ASC 隐私问卷按 PrivacyInfo 三 dict 口径勾选
  (ProductInteraction/DeviceID/OtherUserContent,均非 Tracking),David 2026-07-13 已答
- 两端 demo(模拟器)已从本 tag 现建同步(教练 iPhone 17 / 学员 iPhone 17 Pro,CFBundleVersion=10)
### 本版包含
- **[P1] e1RM 比赛主项三端统一**(#251,port of #250,spec 050):按学员 onboarding 站位/方式
  (低杠/高杠深蹲、传统/相扑硬拉)逐人解析主项,Today/成长头条/教练端三 gate 统一;端上存量历史
  一次性重放重算、旧 PR 基线重置(数字变化=口径变准,非数据丢失,公告已注明)
- **[P1] 记录组弹窗填充输入槽**(#253):重量/次数/RPE 改为可点击的填充输入框样式,点整块聚焦
  弹键盘;含输入长度上限 + VoiceOver 标签
- **[P1] 上赛扣勾选**(#256):记录弹窗配重计算器新增「上赛扣」小圆勾选,勾上按 2.5kg 赛扣
  计入配重(图示+明细联动),默认不勾;选择跨组跨启动记忆
- **[P1] 休息计时器可见性**(spec 055,#243):首次触发弹一次性说明卡(RPE 分档规则+指路);
  「我的」新增「组间休息设置」(自动按 RPE / 固定 30-600s);回落链=教练逐组处方 > 学员固定偏好 >
  RPE 自动表
- **[P1] 视频选片即出「准备中…」占位**(spec 027,#249):选中瞬间显示 spinner,根治「点了卡
  3-5s 零反馈」;前身 #248 曾随 1.0(9) revert 撤出,本班车正式上车
- **[P1] 自建一等公民埋点**(spec 043,#257):21 个行为事件、离线队列/崩溃补报/远程熄火、
  登录前一次性 PIPL 告知;Demo 构建硬禁用零埋点
- **[P1] 邀请码姓名栏文案消歧**(94265e4):标签「你的姓名」+占位「填你自己的名字」+辅助行,
  杜绝学员误填教练名字(已发生两例)
- **[P1] 评估期入口硬封存**(#254,David 07-13 拍板):学员 accepted 直进 5 tab,教练接收弹窗
  恒跳过评估期;代码原地休眠 defer≠delete
### 已知问题 / 局限
- #243 说明卡/设置页与 #249 占位的运行态视觉两 PR 均未截图,随本包真机走查亲验
- fadbc3a(1.0(9) 遗留)与 #256(实装 session codex 起不动,Claude 已亲审 diff)各欠一道
  review-loop 补审
- e1RM 重算使部分学员历史数字与上版不同——预期行为,见上
### 测试反馈
- (待收集)

## 1.0 (9) — 2026-07-12 — 🟢 已上传发布
- 打包来源:tag `beta/1.0-9` @ 4e321c2(`release/1.0`,1.0(8) 基底小步直推)
- 配套后端(同日部署 staging,老包不受影响):迁移 0038 + 镜像 `sha-e87ffac`(#57 顺延 V2 +
  #58 plan-web input-guard);curl 验证 V2 端点 404→401,台账见 backend `db/MIGRATIONS-APPLIED.md`
### 本版包含
- **[P0] 「我的」页退出登录始终可达**(fadbc3a):资料未填/加载失败时也显示「更多 + 退出登录」
  逃生舱,账号不再被困登录态
- **[P1] e1RM 单一真源**(#216/spec 050 主体):完成组先过资格门,成长曲线与头条统一使用
  4 周滚动最大值,新 PR 必须越过 3% 噪声带
- **[P1] e1RM 误记隔离**(#220/spec 050 §5 Phase 1):相对可信历史最佳跳升超过 10% 的记录
  保留为低置信散点,不进入当前值、Best/Last 或 PR;确认流程留待 Phase 2
- **[P1] 学员整体顺延**(spec 054 V2):coached 学员今日训练未开始时点「今天有事」,剩余计划
  整体后移一天并可在 UTC 当天撤销;教练执行页显示累计顺延天数
- **[P1] 今日状态静默化 + 选择态改白**(#241):readiness 问卷不再训练日自动弹,Today 顶栏
  心形为唯一入口;评分圆点/肌群 chip 选择态 brandRed→白色系
- **[P1] 凭证失效不再天书报错**(bcf8826,port of #245):凭证失效冷启动干净回登录页,
  训练页/周历/组记录错误文案中文化
- **[P1] 视频挂点不再冲掉未保存输入 + 拍摄后弹层重弹修复**(#246,spec 027 修缮):四层修复
  (草稿先刷入/相机盖层自身 binding 关闭/渲染分支保持弹层身份/persist 串行化+跨日护栏)
- **[P1] 组行视频状态摄像头变色 + 失败直达重试 + 拍摄相册留底**(#242,spec 027 修缮)
- **[P1] 测试基建:StudentKit 跨午夜时区 flake 根治**(#247,无 runtime 行为变化)
- 各项验证留痕见对应 PR 与 `docs/CODEX-JOURNAL.md`(review-loop 轮次/测试数/真机亲验记录)
### 已知问题 / 局限
- 视频「准备中…」占位(#248)tag 后合入又 revert 撤出,重开为 #249(⏸ 下班车),随 1.0(10)
- spec 055 休息计时器可见性(#243)未进本包,PR 待合
- fadbc3a 的 review-loop 补审仍欠(先发后补审)
- 附带发现:UTC 以西时区"今天"解析错位是产品级风险(#247 只治测试),已记海外 wave 时区险 ④
### 测试反馈
- (待收集)

## 1.0 (8) — 2026-07-11 — 🟢 已上传,内测组 Neice 生效
- 打包来源:tag `beta/1.0-8` @ dd14b9f(`release/1.0`,1.0(7) 基底小步直推;tag CI 绿)
### 本版包含
- **[P0] 组记录失败防扩散**:保存失败保留训练页与已输入值,sheet 不提前关;视频前置失败明确提示
  (同日 staging 库补齐迁移 0031→0037,`/sets/log` 500→201,记录/视频真实写入恢复)
- **[P0] 滑动完成后滑块不再复位**:完成→回顾→返回不回弹;回顾完成本机持久化;完成横幅加「查看回顾」
- **内测前点名三修**(#231'/#232'/#233'):教练执行页锚定本周 / 组号 1-based / 瞬时刷新失败不踢登录
- **学员可见教练组备注**(源自 #234):训练组行与历史组记录显示教练备注
- **账号台账**(port #221):「我的」新增改密码 / 全量训练数据 CSV 导出 / 注销账号(Apple 5.1.1(v))
- **学员 tab 首载取消不误报失败**(port #186)
- **教练今日分诊行一点直达学员详情**(port #212)
- **成长页微修饰**(port #222):E1RM 白话注释 / 曲线 min-max 轴标与数据点 / 杠片提示换行
- **动作库去重 10 组重复条目**(port #209,旧叫法保留为别名)
- 基建:build 号 apple-generic 单源(#229')/ 清 pbxproj 死键(#228')/ DraftStore 崩溃循环降级(#202')
### 已知问题 / 局限
- 「我的」页资料空态/加载失败时退出登录不可达——修复 fadbc3a 已落线但晚于本包 tag,**随 1.0(9) 发**
- solo 自练 / e1RM 真源 / 导入历史等 main 大版本线内容不在本包(main = 待分诊库存)
### 测试反馈
- (待收集)

## 1.0 (7) — 2026-07-08 上传 — 补记(收尾当时未做)
- 打包来源:`ship/today-entry-video-scroll @ 0ef0169`(ship 模式尾包;build 6 从未上传被 7 取代)
- 本版包含(含 1.0(6) 原清单):多项目 e1RM 成长曲线(#199)/ 教练编排中文动作名(#198)/
  分析数据层(#196)/ 导入入口置灰封存(#203)/ 动作库 ontology 修正(#204)/ onboarding 小白化(#205)/
  器械词表 v2(#206/#207/#208/#211)/ 别名回填(#193)/ 学员端走查 P0/P1 六项修复(#213)
- 已知问题(均被 1.0(8) 修复):记录/视频失败毁页面、滑块完成后复位、教练备注不可见、
  弱网误报加载失败、组号 0 起

## 1.0 (5) — 2026-06-29 — 🟡 已归档 + 上传,待内测组生效
- **打包来源**:`ship/today-entry-video-scroll`(基于 `origin/main`)= [PR #197](https://github.com/tianpingdeng112233-cell/meetpr/pull/197)
- **状态**:Xcode 已 archive(06-29)并 Upload 到 App Store Connect;**待**:确认分配内测组 **Neice**(走内部组免审最快)/ Apple 处理完成 → 测试者 TestFlight 点更新。
- 签名 team `28JW4SA779`,arch arm64,build 5(> 已上传的 4)。

### 本版包含
- **训练 tab 弹窗记录流**(`462d9d3`):点「记录此组」弹出 `SetEntrySheet`(杠铃配重图 + 重量/次数/RPE 加减步进)、**删除内联 RPE 横条**、次数放大、摄像头按钮打开弹窗并滚到录像区。
- **动作库**(`2465d7c`):新增 低杠位暂停深蹲 / 低杠位节奏深蹲;所有 RDL → 「罗马尼亚硬拉」(catalog 1229 条)。
- **教练编排只留 4 周 + 内测停用评估期**(#190),以及 build 4 落后 `origin/main` 的其余主线更新(spec 043 收尾 / 埋点 spec / CI 调整)。
- 发版配置:签名 team `XV97B4R4RZ`(作废)→ `28JW4SA779`、build 号统一 `5`。

### 已知问题 / 局限
- 评估期相关代码保留但**休眠**(内测停用,见 spec 033 defer)。

### 测试反馈
- (待填)

---

## 1.0 (4) — 2026-06-27 — 前一线上版(被 1.0(5) 取代)
- **打包来源**:`feat/043-coach-plan-import @ a4bbdaa`(≈ 当时 main + spec 043 教练导入,本地分支版)

### 本版大致包含(累计至此的主线功能)
- 1:1 设计改版(reskin，#180)+ Stacked Lockup logo
- 学员端重做:仪表盘 / 锻炼周月日历 / 进度中心(spec 034/035/036)
- 教练端:分诊 strip + 规划工作区(spec 037/038)、训练视频反馈 inbox(spec 042)
- 卧推配重四则计算器、每组休息计时(spec 040)、失败/未完成组记录(spec 039)
- 学员 SBD 周徽章、e1RM 曲线、比赛倒计时
- spec 043 教练导入学员 Excel 计划(本地分支版)

### ⚠️ 已知问题 / 局限(均在 1.0(5) 修)
- 训练 tab 仍是**旧记录流**:内联 RPE 横条 + 点「记录此组」直接提交(1.0(5) 改成弹窗录入)。
- 动作库缺低杠位暂停/节奏深蹲;RDL 未统一改名。
- **build 号曾错乱(2→1→4)**:build 号写死在各分支 `pbxproj`,从不同 worktree 打包导致号不单调 → 低号上传会被 Apple 拒。1.0(5) 已统一为 5。

---

## 1.0 (2) — 2026-06-24 — (已被取代)
- 打包于 06-24 15:55,首批内测 build(测试员 06-24 起先装此版)。

## 1.0 (1) — 2026-06-24 / 06-26 — (本地归档,未必上传)
- 06-24 12:08 与 06-26 14:48 各有一个 build 1 的本地归档;06-26 的号回退到 1 即上述「build 号错乱」现场。

---

## 项目演示与文档(非发版内容,随仓库跟踪)
- **[DEMO-SHOWCASE.html](./DEMO-SHOWCASE.html)** — **交互式原型**(纯 HTML/CSS/JS,按 build 5 源码还原):顶部切 学员端/教练端、底部 tab 导航、训练页点「记录此组」弹出录入页、加减按钮**实时重算杠铃配重**(真算法:杠 20kg + 每侧 2.5kg 卡扣,IPF 片色)。单文件自包含,可直接分享。
- **[USER-GUIDE.html](./USER-GUIDE.html)** — **教练 + 学员使用教程**,步骤按真实界面文案(编排 STEP 0–5 + 周卡片;学员绑定→今日→逐组记录→成长→反馈)。单文件自包含,底部链到 DEMO-SHOWCASE。
- 生成器:`scratchpad/build_showcase.py`(早期截图版,已被交互版覆盖)。
