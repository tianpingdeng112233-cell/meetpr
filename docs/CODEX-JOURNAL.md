# 2026-09-27 P0 发版推进

- David 授权 P0 加急，#345 已合并 release/1.0@03021ff6；此前待合并/P1 条目为历史状态。
- David 确认最高已上传 22；全新 1.0(23) tag 4e97a489、CI run 36330361925 全绿（1,930 + 9 测试），双端实装 23。可 Archive，尚未上传；不改原 22 tag。[记录](prep-beta-1.0-23-2026-09-27.md)。

# CODEX-JOURNAL — David 直驱改动台账

> **用途**:David 在 Codex 直驱的每笔 commit 在这里留一行,新条目在最上。
> 后续主代理每次开工按全局规约读本文件 catch-up——**这里没有的改动等于不存在**。
> **格式**:`- YYYY-MM-DD <short-sha> — 一句话改了什么(牵动的模块)`
> 密钥/密码永不入此文件。

## 2026-09-27 硬拉 e1RM 修复（待合并）

- 2026-09-27 `fix/050-imported-e1rm-baseline` — [Codex][CI] PR #345 首跑被上游 ViewInspector 新版 manifest 阻断；四模块统一固定原已验证的 0.10.3，窄范围双轴补审 CLEAN，StudentKit 901 复验绿，重新跑完整 CI。

- 2026-09-27 `fix/050-imported-e1rm-baseline` — [Codex][T2/P1] 实练异常基线排除 imported，Progress 首次读取前恢复受影响旧历史；保留导入复核、退役历史、PR 与不回退的重量基线。StudentKit 901 测试、strict lint/format、模拟器90天曲线/来源组亲验通过；独立 Standards/Spec 第二轮均 CLEAN。未改 build/tag，未合并/上传。[验证记录](verification-e1rm-imported-baseline-2026-09-27.md)。

## 2026-09-16 准备 1.0(22)

- 2026-09-16 07489315— [Codex][prep-beta] David 要求切包；核实 ASC 最高 21 与六项祖先关系，agvtool 升至 22、marketing 保持 1.0；使用独立取包树保留旧树修改。tag CI 九包 1,922 + 主工程 9 全绿，双端 demo 已装 22；Archive/Upload 尚未执行，Apple 新协议待本人处理。完整状态见 [切包记录](prep-beta-1.0-22-2026-09-16.md)。

## 2026-09-16 追加 #338（已落线）

- 2026-09-16 24d47f65（组合 2e816526，原实现 8ba5b638）— [Codex][T1/P1] David 追加批准动作库同步进入 1.0(22)；合入最新五项发版基线，功能差异仍为两 JSON 与两测试。CoachKit 443/443、最终 CI 九包 1,922 + 主工程 9、format/lint 全绿后合入；验证及最终 CI 见 [#338 验证记录](verification-338-2026-09-16.md)。

## 2026-09-16 下一班车整合（已落线）

- 2026-09-16 9a28115d（修复 3acc828）— [Codex][P1] 按 David 批准整合 #339/#342/#341/#340/#343 进入 1.0(22)，保留已有组合修复；修正 #343 两个新按钮绕过 #341 统一按压、上午补记被 Demo 历史时间窗口过滤的问题。当时 #338 留候选，后续追加见上；未切包、未执行线上迁移或部署。#344 全绿合入，九包 1,922 + 主工程 9 测试。证据见 [整合验证](verification-train22-2026-09-16.md)。

## 2026-09-14 收货历史（当时尚未落线）

- 2026-09-14 73fea6d — [Codex] 组合 #342/#341/#340，修复补记日期窗口、Gregorian 日期、部分写入重试、数字键盘小数及动作清理兼容；#342 修复已回推 c21a3d7/dbcf60fa。组合 1,913 个 SwiftPM + 主工程 9 测试、DemoStudent 实点及完整 lint/format 通过；GitHub billing 与阿里云登录阻塞合并/部署。详见 [验证记录](verification-finish22-2026-09-14.md)。

## 2026-09-14 独立实装历史（当时未进入发版线）

- 2026-09-14 cc8efa53 — [Codex][T2/P1] Add e1RM source details and training history navigation：学员端每日最佳节点可查来源组和原计算，训练页直达历史并保留活动组/休息计时；869 测试、DemoStudent 双主题实点、strict lint/format 通过；Standards/Spec 独立审查 CLEAN。分支 `feat/083-e1rm-history-impl` 待合并，证据 `docs/evidence/083-e1rm-history/`，原型保留设计分支。

## 独立设计分支（未进入发版线）

- 2026-09-14 876600a — [Codex][设计反馈] Spec 083 原型非末尾节点半径 4→2.7、描边 1.7→1.3；末点与点击范围保持，悬停仍维持大小层级；浏览器截图亲验，spec 同步。

- 2026-09-14 abdff9b — [Codex][P1][待看稿] Spec 083 e1RM 节点溯源与训练历史入口：产品行为写入 spec，ImageGen 概念稿与双主题交互 HTML 已浏览器实点；分支 `feat/083-e1rm-history`，等待 David 确认设计，无 Swift／后端／发布改动。

## release/1.0 历史落线记录

- 2026-08-20 bdc9ab45 — [Claude][P0] 修「记录完成后消失」:推进制下实际训练晚于排期,今日页/周历的计划内 set_logs 拉取窗口钉死在 [首排期日-1d, 末排期日+1d],越过排期终点后新记的组全落窗口外 → 显示 0/N 已记录、重量『丢失』(服务端数据全程完好,staging 已核实倪嘉骏 08-19/08-20 全部在库);窗口上界改 max(末排期日, 今天)+1d,WeekOverviewViewModel 注入可测时钟(StudentKit 2 源文件+2 回归测试;774 测试绿 + swiftlint strict;Global 配置同分支同覆盖,main 为 071 前旧形态无此病不落)
- 2026-08-12 a3273c0 — [Claude][P1] 今日页头部日期改恒显真实今天(TimelineView 跨午夜自翻篇):原钉在游标日教练排期 scheduledDate,学员落后/当日完成后整页看着冻在旧日期,外测学员 08-12 报「卡在 8.9」;设计正典 sequence-handoff todayStr 三场景均为真实今天,推荐日期只留训练日卡(StudentKit 3 源文件+1 测试 +36/-16;731 测试绿 + swiftlint strict;review-loop 1 轮 1 BLOCKER 修复收敛;DemoStudent 模拟器亲验落后盘头部显 8月12日·周三)
- 2026-08-01 59c66ae — [Claude][P0] 辅助项重量可设 20kg 以下:三条输入路径(弹窗初始 max(20)/步进器减号/数字键盘 snapped [20,500])全按 `draft.isAccessory` 分流,辅助项下限 0、杠铃主项/变式保留空杠 20 护栏;此前教练开 <20 处方被静默顶成 20 落库=数据不正确(StudentKit/DesignSystem 3 文件 +28/-6;DesignSystem 71 + StudentKit 638 测试绿 + swiftlint strict;DemoStudent 模拟器亲验:辅助项 15→减号 12.5→键盘 7.5 保存成功、主项输 15 仍钳回 20;P0 紧急直发,review-loop 欠账待补)
- 2026-07-30 560d840 — [Claude][P1] App 图标换成 David 定稿的「片里的折线」(纸底 #F5F6F8 + 金盘 #D97706 + 折线/淡段/上弧/下沿 PERSONAL RECORD,两色无渐变):主图与 dark 同一张 1024(无 alpha,3 通道),tinted 另出灰度挖空版(圆盘实心 + 盘内挖成透明,系统自己上用户色);矢量真源 + SPEC + 重出 PNG 命令落 docs/brand/(3 张 PNG + 3 个新文件;asset catalog 编译 0 警告,iPhone 17 模拟器主屏亲验 light/dark/tinted 三态)
- 2026-07-23 3808f44 — [Codex][P1] 当前组大卡摄像头改为未附视频时直达系统拍摄页,保留首次隐私确认/相册留底/上传链路;上传中与已上传仍进详情、失败仍直达重试,无视频摄像头能力时安全回退弹层并修 `UIImagePickerController` 媒体类型误报崩溃(StudentKit 5 文件;strict lint/format 0,467 测试绿;MeetPR-DemoStudent iPhone 17 模拟器构建绿并实点回退路径)
- 2026-07-18 5f34e96 — [Claude][P1] 回看也能看到动作备注(David 追加拍板):无活动组时(日练完/历史只读)动作卡头显示备注、全部训练历史动作块同步补;抽共享 CoachNotePill(surface2 变体防 surface1 卡上隐形)+ CoachNoteDisplay.reviewNote 纯函数策略,补 3 测(StudentKit 426);ExerciseSpec 移文件级解 type_body_length(StudentKit 5 文件;swiftlint strict 0,426+126 绿;review-loop 2 轮 3 BLOCKER 全修 CLEAN;模拟器亲验训练tab历史日+全部训练历史两路径)
- 2026-07-18 9c788a1 — [Claude][P1] 学员端动作级教练备注可见:StudentPlanExercise.notes 投影透传(backend plan_exercises.notes,web 备注列)+ 训练页当前组 hero 卡渲染(灰标签+正文独立换行,仅 hero 卡,David 三拍板),旧缓存缺 key 解码兼容测试 + 投影 passthrough 测试补齐(CoreModels/StudentKit 6 文件;swiftlint strict 0 + 双模块测试绿;review-loop 2 轮 3 BLOCKER 全修 CLEAN;DemoStudent 模拟器亲验)
- 2026-07-18 4958c1c — [Claude][P1] 组录入大卡片动作名升格白色标题:20pt heavy 白字动作名 + 15pt 灰色组数计数,撤红色等宽眼眉样式(David 看图反馈「太小」后二拍)(StudentKit 1 文件;swiftlint strict + 423 测试绿;DemoStudent 模拟器亲验)
- 2026-07-18 d40351f — [Claude][P1] 学员端组录入大卡片眼眉行改「动作名 X/X」(如「相扑硬拉 2/2」),替换原「第 02 / 02 组」——卡片此前不显示动作名,练到第二个动作起无从知道当前组属于哪个动作;顺删无引用 twoDigit(StudentKit 1 文件;swiftlint strict + 423 测试绿;DemoStudent 模拟器亲验)
- 2026-07-17 dff484c — [Claude][P1] 学员端视频时长裁剪(port of #260):相机 allowsEditing + 相册 UIVideoEditorController 前置裁剪,超长视频改「先裁再传」,VideoTrimCompletion/SingleShot 平台无关幂等+tmp 清理,与 e9ab0d8 enqueue 所有权互补(StudentKit VideoUpload 4 改 3 新;417 测试绿+build 零警告;review-loop main 3 轮+port 1 轮 CLEAN)
- 2026-07-17 56bf338 — [Claude][P1] #256 补审产出三修:赛扣偏好 key 按学员 UUID 分区(修跨账号继承,旧全局 key 弃用一次性重置)+ 配重数学抽 SetEntryPlateMath 纯函数补 8 测 + PlateLoadout VoiceOver 播报赛扣(StudentKit/DesignSystem 5 文件;407+29 测试绿 + DemoStudent Demo 构建绿;review-loop 2 轮收敛,2 存量 finding 对质 CONCEDE 另立 follow-up;fadbc3a 补审同日 1 轮 CONCEDE 收敛零改动——两笔 1.0(9)/(10) 补审欠账全清)
- 2026-07-17 e9ab0d8 — [Claude][P1] 视频上传源 tmp 文件泄漏修复(port of #263):enqueue 转移 source ownership,导出成功/失败/取消 + enqueue 抛错全路 best-effort 删源,retry nil 不碰导出产物(StudentKit VideoUpload 4 文件 + 台账;401 测试绿 + swiftlint strict;review-loop 1 轮 CLEAN)

- 2026-07-17 1bd39b7 — [Claude][P1] e1RM 曲线主线/纪录点改白色(fgPrimary,导入段维持灰虚线;迷你卡同步;E1RMChart 共用组件,教练端只读图同色)(DesignSystem/StudentKit 2 文件;27+399 测试绿;模拟器亲验)
- 2026-07-17 4207ca2 — [Claude][P1] e1RM 图表:最新突破点常显中文日期 + 点按任意突破点弹「日期·kg」标注(无外部 onSelect 时),红线降 1.5pt/80% 透明度、纪录点缩小(DesignSystem 1 文件;27+399 测试绿;模拟器亲验常显标签)
- 2026-07-17 418ee42 — [Claude][P1] e1RM 图表轴日期改中文「M月D日」(月前日后,locale 无关)+ 破纪录点实心标出(E1RMChartPoint.marksRecord,平延段不标;今日页 Sparkline 开点标)(DesignSystem/StudentKit 4 文件;DesignSystem 27 + StudentKit 399 测试绿;DemoStudent 模拟器亲验)
- 2026-07-17 385fa92 — [Claude][P1] 纪录轨迹渲染改上升斜线(David 二次拍板,阶梯观感否):纪录点间平滑斜线相连、平尾保持,撤 .step 插值与 sparkline 阶梯拐点,数据投影不变(StudentKit 4 文件;399 测试绿;DemoStudent 模拟器今日/成长两页亲验)
- 2026-07-17 120a5c4 — [Claude][P1] spec 053 修正案(David 拍板):学员端 e1RM 曲线改破纪录阶梯线——E1RMSeries 新增 records 投影 + 头/尾平延,E1RMChart 增线型参数(.stepEnd,教练端默认 .curve 不变),移除逐组散点(.low 隔离点保留),Dashboard/成长卡按 chartWindowDays=90 窗口裁剪、delta 同窗口,「历史最佳」=近 28 天无新纪录(StudentKit/DesignSystem 13 文件;review-loop 2 轮 2 BLOCKER 修复 CLEAN;StudentKit 399 + DesignSystem 27 绿;DemoStudent 模拟器亲验阶梯渲染)
- 2026-07-16 0ede4c1 — [Claude][P1] spec 053 图例消歧 + 文案裁剪(David 现场反馈):E1RMChart 图例改「虚线 = 导入的历史记录」并加虚线样本符号(原「浅色」在黑底上不自明);成长页 E1RM 说明行删「越高越强」(DesignSystem/StudentKit 2 文件;DesignSystem 27 + StudentKit 386 测试绿;DemoStudent 模拟器亲验)
- 2026-07-16 4c8af71 — [Claude][P1] Port #227/spec 053 导入历史 e1RM 回填 + review gate:assumed/origin/exerciseID 数据层透传、E1RMRepository upsert/confidence 改写 + ImportedHistoryReviewStore、ImportedHistoryBackfill actor(120 天窗/幂等/超 1RM 族问询/水位/per-student 串行)、E1RMSeries 赢家溯源 + E1RMChart 双层渲染(imported 虚线/低置信弱化/图例)、四处统计排除 assumed、StudentRootView 三触发接线 + alert 队列 + 「历史最佳」回退;迁移重放跳过 assumed(8 个原子 commit,0308f0f..4c8af71;review-loop 3 轮 3 BLOCKER 全修 CLEAN;CoreModels 125/Networking 71/DesignSystem 27/StudentKit 386 测试绿;DemoStudent 模拟器亲验问询/升格/隔离/图例)
- 2026-07-14 8040a70 — [Claude] 训练日切日改凌晨 4 点 gym-day 截断(镜像 backend spec 017):WorkoutDatePolicy -4h 位移 + gymDayToday() 锚点,selectedDate 初始化/回到今天/restTitle/readiness 刷新四处对齐,修内测反馈「晚上12点自动结束」(仅 StudentKit 3 文件;review-loop 2 轮 CLEAN,1 BLOCKER 修复;345 测试绿+模拟器白天路径亲验;残留=今日tab/周历午夜视觉翻篇待 spec)
- 2026-07-13 a051287 — [Codex][P1] spec 043 自建埋点:Analytics 叶子模块+21 事件接线+离线队列/崩溃补报/kill-switch/PIPL notice/摩擦反馈,Demo 双形态硬禁用(Analytics/AppShell/StudentKit/CoachKit;780 测试+正式/双 Demo 构建绿)
- 2026-07-13 94265e4 — [Claude] 学员端 EnterCodeView 姓名栏文案消歧:标签「你的姓名」/占位「填你自己的名字」/新增辅助行「教练会在学员列表里看到这个名字」,修复满屏"教练"语义场致学员误把教练名填进姓名栏(已两例);仅 StudentKit 1 文件 +3/-2;swiftlint --strict + StudentKit swift test 331 绿;纯文案,EnterCodeView 在 Demo 架构不可达(demo 学员预绑定)故未上模拟器
- 2026-07-13 adbce18 — [Codex] #251 review-loop 第 2 轮：迁移重放 confidence 同时服从旧信任档与本次 anomaly verdict，旧 `.normal` 尖峰仍降 `.low` 且不产 PR（StudentKit，972 测试）
- 2026-07-13 ea4c9b2 — [Codex] #251 review-loop 三 BLOCKER 返修：迁移按 setLogId 保真旧 confidence、旧 catalog 动作可重放/未知孤儿显式丢弃；迁移上提 AppShell 共同学员 gate 且失败阻塞重试；Today 低杠变式标题改走 onboarding resolver（AppShell/StudentKit/spec050，971 测试+双模拟器复验）
- 2026-07-12 e0e5074 — [Codex] Port #250/spec050 存量重算：canonical set_logs 按 release/1.0 E1RMRecorder 时序重放，逐学员替换历史并清旧 PR，UserDefaults 幂等且兼容仅 planExerciseID 日志；迁移对照/三项 DemoStudent 模拟器截图落证(StudentKit/RepositoryContracts/NEXT-RELEASE)
- 2026-07-12 3daee8b — [Codex] Port #250/spec050 主项门：competition_stance 解码+Swift/后端镜像解析器，Today/成长头条/教练三 gate 按学员 onboarding 统一裁决，bundled/demo catalog 补齐 stance(CoreModels/StudentKit/CoachKit/AppShell)
- 2026-07-11 bcf8826 — [Claude] 凭证失效兜底修复(port of #245):bootstrap fail-closed(瞬态/429 除外)+ 401 全码清 session 回登录 + 训练页/周历/组记录中文错误文案,「AuthRepositoryError error 0」天书糊屏根治(AppShell/Networking/StudentKit 8 文件 +160;三模块 435 测试绿;staging 双形态模拟器 E2E 亲验:服务端轮换凭证→冷启动→干净回登录页)
- 2026-07-11 601e093 — [Codex→Claude 收货] 顺延 V2(spec 054):整体计划后移替换 V1 挪休息日,计划级端点+撤销窗口(latest_shift_created_at)+≥3 天提示+教练累计徽标(21 文件;865 测试;模拟器全环亲验:确认→周条整体滑移→休息态→撤销复原);backend 侧 PR#57 已合 staging,**发包硬门=0038 迁移+滚镜像先部署**
- 2026-07-11 8ede34e — [Codex 写→Claude 接管验收] Port #234b 顺延 iOS:全栈(DTO/端点/契约/纯函数/教练标记)+入口接旧今日卡(25 文件 +590;5 模块测试绿;模拟器负向路径亲验);附带修 Demo 种子日期改 UTC 午夜锚(原本地锚使 UTC 门控行为与生产不一致)
- 2026-07-11 dee9e39 — [Codex 写→Claude 接管验收] Port #220/spec050§5 误记隔离:纯分类器(软 10%/硬 18% 跳幅门)+置信档持久化,低置信点保留散点不进头条/PR(15 文件 +294;Codex 沙箱跑不了测试卡死 2h 被取消,Claude 外部复验 116+299 测试绿)
- 2026-07-11 ee60951 — [Codex→Claude 收货] Port #216/spec050 e1RM 真源:资格门(RPE≥7/reps≤10/硬拉≤5)+28 天滚动 max+3% 噪声带 PR,阈值集中 E1RMPolicy(StudentKit 13 文件 +582;292 测试;成长页亲验;§5 留给 #220)
- 2026-07-11 fadbc3a — [Claude][P0] 「我的」空态死锁修复:资料空/加载失败时补渲染「更多+退出登录」逃生舱,账号不再被困登录态(仅 StudentKit MyProfileView +14;lint/281 测试/模拟器空白绑定号亲验;review-loop 补审欠着)
- 2026-07-10 e31dc93 — [Codex→Claude 收货] 教练备注学员可见修复(源自 #234):历史页 DayDetailView 补读 coachNote + CoachNoteDisplay helper;链路/训练页本就通(6 文件 +30;模拟器历史页亲验截图)
- 2026-07-10 7a7cb10 — [Codex→Claude 收货] Port #221 账号台账:注销/改密/CSV 导出挂旧「我的」页「账号与安全」卡(15 文件 +963;Apple 5.1.1(v);putNoContent 按本线 401 机制适配;solo 依赖跳过;NEXT-RELEASE 同步并收掉 P0 的 backend 尾注——staging 当晚已根治)
- 2026-07-10 b88ec76 — [Codex→Claude 收货] Port #186:学员 tab 取消不误报错误,统一 isTaskCancellation + 各 VM 取消分类 + 6 回归测试(StudentKit 15 文件+AppShell 测试;Session guard 已随 #233' 存在跳过;冻结的 #214 协议扩展未带)
- 2026-07-10 8c6baf2 — [Codex→Claude 收货] Port #222:E1RM 白话注释+杠片换行+曲线轴标/点标(DesignSystem Sparkline + StudentKit 2 文件;模拟器成长页亲验)
- 2026-07-10 bd49108 — [Codex→Claude 收货] Port #212:教练今日分诊行 NavigationLink 直推 StudentDetailView(仅 CoachKit 2 文件;模拟器 axe 实点验证跳转 OK)
- 2026-07-10 6c33faa — [Codex→Claude 收货] Port #209:动作库去重 10 组重复 nameEn,删除项转 alias,与 main 版逐字节一致(仅 CoachKit catalog/alias JSON + 2 测试)
- 2026-07-10 f34895e — [Claude] Port #202 差集:DraftStore 崩溃循环降级为内存兜底+日志(Session 半边已随 #233' 入包;仅 CoachKit DraftStore)+ 队列表加 per-set/rename 两行(David 拍板提前)
- 2026-07-10 780ea6d — [Claude] CI 加 beta/* tag 触发(David 拍板 B:切包点机器绿,日常直推零 CI)
- 2026-07-10 8ada119 — [Codex][P0] 写组失败保留训练页/录入值并阻止 sheet 提前关闭;视频前置失败明确提示(staging `/sets/log` 500 仍需 backend 修复;StudentKit + NEXT-RELEASE)
- 2026-07-10 37e9a50 — [Claude] Port #229:apple-generic versioning 单源(project 级=7,prep-beta 再 bump 8)+ 恢复 Info.plist 变量引用(仅 pbxproj/Info.plist)
- 2026-07-10 4081362 — [Claude] Port #228:清 pbxproj 死 INFOPLIST_KEY 设置(仅 pbxproj)
- 2026-07-10 01e2ebf — [Claude] Merge three-fix port #231'/#232'/#233' into release/1.0(AppShell/Networking/CoachKit/StudentKit + NEXT-RELEASE 更新)
- (示例,勿删)2026-07-10 0000000 — Fix xxx in TodayWorkoutView(仅 StudentKit)

## 2026-10-02 · spec 084 卡 A · Codex 实装交回 Opus

- T2 / P1；工作分支 `feat/084a-walkthrough-behaviors`，基准 `bcabd9a4`，目标 PR base 为 `release/1.0`。四项实装保留未提交工作区；未 commit / push / 开 PR，未改版本账本、build 号或 SPEC 状态。最终验收由 Opus 按卡 A 清单执行。
- §2：共享序号入口为 `StudentPlanSequence.dayNumbers(inWeek:)`，复用原有排序，已完成日占号。接入清单：Today 页头、Today 完成卡和下一练标签、Today 周条、训练页页头、训练页当前周条、计划周列表、补记 sheet / toast、训练奖励与总结页（消费同一 weekCode）、教练学员详情概览。全仓检索确认本线训练历史和聊天训练卡没有独立 W#D# / D# 展示入口；没有新增标签。教练排课 `DAY n`、日期投影、游标、完成推进、组录入及持久化结构未改。
- §3：体重与 Meetday 的空态、有值态均为带 `PressScaleButtonStyle` 的 Button，分别导航到既有 `.basics` / `.competition` 编辑器。每次导航独立加载 profile 后创建草稿；保存沿用 `MyProfileViewModel.save`，取消沿用返回，回 Today 重新读取指标。
- §5：删除 `pendingPRBanner` 与旧展示/手动确认方法；新 PR 记录后立即确认，进入训练页时确认积压事件，保留 PR 与 e1RM 历史。现场基准已不存在横幅视图及其专用文案键，因此没有额外视图或文案可删；Progress 未改。
- §6：未保存设置时，从当前游标周（全完成则最后周）的推荐日期按 UTC 日历身份取星期，包含已完成日与后移日期；回落档案训练日，再回落一三五。提醒页打开时刷新计划；已保存设置优先，加载期间禁用编辑，存储格式不变。

### 自测证据

四个约定 seam 逐项先红后绿，没有新增其他 seam。新增 6 个测试方法（导航按空/有值参数运行），同步旧标签及 PR 测试：

| seam | 红证据 | 绿证据 |
| --- | --- | --- |
| 序号函数 / 标签 presentation | `TrainingDayNumberTests` 因缺少序号函数与标签上下文失败 | D1–D4、补早日后 D1–D5、同槽排序、Dashboard / 训练页标签通过 |
| Today 卡片导航 | `DashboardProfileNavigationTests` 因缺少导航回调失败 | 空态与有值态的两个 Button 点击分别返回 `.basics` / `.competition` |
| 训练页 PR 处理 | 原 persist / 启动测试观察到横幅待展示状态及未确认事件，4 条断言失败 | 新事件记录与确认、积压确认、重进不再待确认、重复记录隔离通过 |
| 提醒默认星期 | `TrainingReminderDefaultTests` 因缺少计划 / 已存设置输入失败 | 推荐日期、当前周、三级回落、空星期的已保存设置不变通过 |

- 九个 SPM 包 `swift test` 全通过，共 1936 项：CoreModels 158、RepositoryContracts 6、Networking 131、DesignSystem 73、Analytics 30、ChatUI 85、CoachKit 443、StudentKit 907、AppShell 103。
- 全量首轮发现已有 `dashboardWeekCellsAreSequenceOrdinalsNotCalendarSlots` 仍断言 `[1, 4]`，按本卡更新为 `[1, 2]`；随后 StudentKit 全量通过。
- CoachKit / AppShell 初次依赖解析因 GitHub 连接失败中止，使用本机缓存及 `--skip-update` 完成。shell 沙箱下 AppShell 两项 Keychain 测试失败；经 XcodeBuildMCP 重跑 103 项全绿。未改变依赖版本或测试实现。
- 主工程 XcodeBuildMCP `test_sim`：`MeetPR.xcodeproj` / `MeetPR` / Debug / MeetPR-CI（iOS 26.5），9/9 通过；参数 `CODE_SIGNING_ALLOWED=NO -skipPackageUpdates`。首次网络解析失败，重跑跳过更新后通过。
- `swiftlint lint --strict`：全仓 1073 个 Swift 文件，0 violations。`swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules`：通过。`git diff --check`：通过。保留既有 Swift 并发等编译 warning，本卡未新增 warning。
- 本机原始日志：`/tmp/084a-coach-tests.log`、`/tmp/084a-swiftlint-final.log`、`/tmp/084a-format-final.log`；XcodeBuildMCP 本 worktree 日志中 StudentKit 为 `swift_package_test_2026-10-02T13-09-02-507Z_pid7167_945d2585.log`，AppShell 为 `swift_package_test_2026-10-02T13-11-00-051Z_pid7167_4b508db9.log`，主工程为 `test_sim_2026-10-02T13-09-49-406Z_pid7167_04b7057b.log`，同次 xcresult 已保留。

### 自审与待收货

- Standards 独立只读自审：CLEAN。
- Spec 独立只读自审：发现 1 项 P2（重开 Today 编辑器可能沿用旧草稿），已改为每次导航创建独立 ViewModel，定向复审 CLEAN。
- 未做设备验证：DemoStudent / Demo 的 Light / Dark、小屏、大字体与保存/取消实屏操作，按卡 A 交 Opus 收货。主工程自动测试通过不等于完成该视觉与交互验收。
- 2026-10-02 返修第 1 轮：仅修 `dayNumbers(inWeek:)` 重复 id 构造崩溃，保留排序后首次出现的序号；新增重复 id / 反转输入的稳定性回归，先复现 `Duplicate values for key` 崩溃，修后序号测试 3/3 通过。三包均以 `--skip-update` 复跑：CoreModels 158、CoachKit 443 全绿；StudentKit 跑 908 项，序号测试通过，视频测试报 15 个 `Cannot Encode` 问题，全量未绿。全仓 SwiftLint 严格模式 1073 文件 0 违规、swift-format 严格模式及 `git diff --check` 通过；本次未做设备验证，未 commit / push，其余既有改动保留。日志：`/tmp/084a-r1-{red,green,CoreModels,StudentKit,CoachKit,swiftlint,format}.log`。

## 2026-10-02 · spec 084 卡 B · Codex 实装交回 Opus

- T2 / P1；工作分支 `feat/084b-week-strip-login`，基准 `605d1243`（卡 A）。按 CARD-B-ios.md 在当前分支实装，未 commit / push / 开 PR；未改 SPEC、NEXT-RELEASE、RELEASES、build 号、依赖或工程结构。本节为末尾追加，前文保留；最终验收由 Opus 按卡 B 清单执行。
- §1：Global 登录页改为邮箱 → 密码 → Sign in → 两个文字链接 → or → Apple → Google → 法律文案。Apple / Google 同宽同高、描边次要样式，保留认证回调、错误、取消行为和原无障碍标识。GlobalRegisterView 无第三方入口，无需修改；CN 登录未动。
- §4：TrainingSequenceLayout 提供全部训练周、当前/可见周、每格序号与独立选中状态、完成计数、首尾边界及翻周默认选择。新 TrainingWeekStrip 接入箭头、横滑、状态胶囊、小点（超过 8 周隐藏）、深色选中框和淡金当前训练日。翻回当前周选游标日；全完成计划沿用最后一天回落。
- 页头非当前选择显示 Back to today；未来日用 TrainingDayPreview 只读展示推荐日期、日名、动作/组数与现有解锁提示。已完成/当前训练日继续走原展示。训练 tab 的用户点击复用 jump token 回当前；下拉刷新和完成流程结束回当前。记录、计时、补记、仓储与持久化结构未改。
- 删除 TrainingCalendarView、旧 CalendarContent 接线、按周折叠专用函数、旧日历预览及无用双语文案。新增七个周条中英文 symbol key；预览计数复用原有单复数文案。

### 自测证据

仅在卡约定 seam 新增 7 个测试方法（登录顺序 1、TrainingSequenceLayout 分页 6）。红 → 绿按行为逐步执行：

| seam / 行为 | 红证据 | 绿证据 |
| --- | --- | --- |
| GlobalLoginView 元素顺序 | `/tmp/084b-login-red.log`：文本/渠道顺序两条断言失败，Apple/Google 位于邮箱前 | `/tmp/084b-login-green.log`：顺序与既有 Apple 取消测试 2/2 通过 |
| 周分页默认选择 | `/tmp/084b-paging-red.log`：缺少 page 入口编译失败 | `/tmp/084b-paging-green.log`：全部周可访问、默认当前周/当前训练日通过 |
| 翻周默认选择及首尾边界 | `/tmp/084b-navigation-red.log`：缺少前后周选择入口 | `/tmp/084b-navigation-green.log`：含跳号周、过去/未来/返回当前周 2/2 通过 |
| 独立选中、当前状态和完成数 | `/tmp/084b-markers-red.log`：缺少状态/计数/小点入口 | `/tmp/084b-markers-green.log`：3/3 通过；后补空计划、失效选择、全完成、单周、8/9 周、完成后游标推进回归 |

- 删除仅针对旧 Plan summary 的两个测试及旧文案断言。全量初跑另外暴露两个 SetNumberSurfaceTests 的 fixture 用未来日期选日，却要求显示录入界面；按未来日只读约束改为选 StudentPlanSequence.cursorDay，保留原组号断言。定向复测分页/组号/本地化 21/21 通过（`/tmp/084b-review-green.log`）。
- 九包均尝试 `swift test --skip-update --disable-sandbox --cache-path /tmp/084b-swift-cache`；模块缓存通过 `CLANG_MODULE_CACHE_PATH` / `SWIFTPM_MODULECACHE_OVERRIDE` 指向 `/tmp/084b-module-cache`。首次依赖网络代理不可达，复制本机既有依赖缓存后成功解析，未更新依赖版本。XcodeBuildMCP 的 SwiftPM test 工具无 skip-update 参数，因此按用户约束使用 CLI。
- 六包全量通过：CoreModels 158、RepositoryContracts 6、Networking 131、DesignSystem 73、Analytics 30、CoachKit 443。日志 `/tmp/084b-full-<包名>.log`。
- 三包全量未绿：ChatUI 85 项有 1 个视频编码问题；StudentKit 912 项初跑有 15 个视频编码问题及上述 2 个 fixture 问题；AppShell 104 项有 2 个 Keychain 测试共 3 条失败断言。编码错误为 AVFoundation `Cannot Encode`，Keychain 失败发生于 shell 沙箱；前序卡 A 已记录同类环境限制，没有修改生产视频/Keychain 逻辑来规避。
- 修正 fixture 后，排除受限视频/Keychain 测试的可运行回归通过：StudentKit 896、AppShell 102、ChatUI 84（`/tmp/084b-available-<包名>.log`）。排除模式分别为 `AVFoundationVideoExporterTests|PassthroughVideoTrimExporterTests|realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer`、`keychainTokenStore`、`VideoBadgeExporterTests`；不将这些结果写成九包全绿。
- 主工程 `MeetPR` / Debug / MeetPR-CI（iOS 26.5）XcodeBuildMCP test_sim：9/9 通过，参数 `-skipPackageUpdates CODE_SIGNING_ALLOWED=NO`。xcresult：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084b-5377bbb74f9d/result-bundles/test_sim_2026-10-02T13-59-03-043Z_pid24316_8bd59943.xcresult`。
- 最终 DemoStudent 与 Global 构建启动均成功，使用同一 worktree、`/tmp/meetpr-084b-derived` 及 `-skipPackageUpdates`。最终全仓 `swiftlint lint --strict`：1075 文件 0 违规；工具链 `swift-format lint --recursive --strict --configuration .swift-format MeetPR MeetPRTests Modules` 与 `git diff --check` 通过（`/tmp/084b-lint-final.log`、`/tmp/084b-format-final.log`）。

### Standards 自审

- 独立只读 reviewer：CLEAN，0 finding。确认状态类型 Sendable、分页逻辑位于约定 seam、独立子视图、现有 token / Dynamic Type、中英文文案及范围约束；未发现值得报告的 Fowler smell。

### Spec 自审

- 独立只读 reviewer 初轮发现 P2：全完成计划切 tab 的旧 jump resolver 无游标可选；已统一调用分页 currentSelection，保留末日回落。另发现 P3：四个旧日历预览键残留；已删除。两项定向复核关闭，最终 CLEAN。
- 收尾的摘要文案复用、录入测试 fixture 修正、移除覆盖子按钮标识的父级 identifier，已再次定向复核 CLEAN。

### 模拟器证据与待收货

- 已做有限模拟器验证，并非“未做设备验证”：MeetPR-CI / iOS 26.5 / Light / 默认字体 / 英文，Global 登录页亲眼确认顺序与 Apple/Google 同等尺寸；DemoStudent 亲眼确认当前日淡金与选中框并存、未来周只读无开练按钮、首尾箭头状态、小点、同周选日、Back to today、切 tab 回当前，以及横向 drag 翻周、实际下拉 drag 刷新回 W1D3。
- 截图：`/tmp/084b-evidence/login-light.jpg`、`/tmp/084b-evidence/training-current-light.jpg`、`/tmp/084b-evidence/training-future-light.jpg`。当前周图采于最终文案/identifier 清理前，当前周布局未再改变；未来周与登录图来自最终行为版本。
- 未做真机、Dark、iPhone SE 尺寸、大字体、完整记组/计时/补记/完成流程及存量升级验收；交 Opus 按卡逐项核，不以自测代替收货。
- 范围外既有文案：英文训练日后缀 `trainingCalendarLogic.copy011` 被译为 `Sun`，Dashboard 同类拼接也显示 `DeadliftSun`；本卡复用日名/解锁提示后预览显示 `SquatSun`。没有扩展修改共享旧文案，交 Opus 分诊。此项也出现在上述未来周截图。
- 本次审查直接使用仓内卡与 spec，不依赖 tracker；仓内缺少 `docs/agents/issue-tracker.md`，将来使用依赖 tracker 的 Matt 流程前需由 David 调用 `$setup-matt-pocock-skills`。

- 2026-10-02 返修第 1 轮：仅将 TrainingWeekStrip、TrainingDayPreview 与 Back to today 的文字/图标改为 MeetPR 字体 token（预览标题 display 22、小结 mono 12），删除训练页新增 `.refreshable` / `onPullToRefresh` 及预览接线，保留页头刷新后回当前训练日。两包均以 `--skip-update` 全量复跑：StudentKit 912 项有 15 个既有视频 `Cannot Encode` 问题；AppShell 104 项有 2 个 Keychain 测试共 3 条断言失败，与本节前轮沙箱限制一致，全量未绿；按前轮同一模式排除受限测试后 StudentKit 896、AppShell 102 项通过。全仓 SwiftLint 严格模式 1075 文件 0 违规、swift-format 严格模式与 `git diff --check` 通过；Standards / Spec 独立只读复核均 CLEAN。对照开工快照确认只改本轮五个 Swift 文件并追加本行，其余改动保留；本轮未做设备验证，交 Opus 收货，未 commit / push。日志：`/tmp/084b-r1-{StudentKit,AppShell,available-StudentKit,available-AppShell,swiftlint,format}.log`。

## 2026-10-02 — Spec 084 Card C · iOS Ask coach / 聊天训练卡 / 组录入视频 / 休息说明

- Opus 派卡；T2 / P1；分支 `feat/084c-chat-video-rest`，起点 `0c9cafb7`（叠在卡 B）。未 commit、未 push、未开 PR；未改发版账本、SPEC 状态、build 号、依赖或线上数据结构。开工时 `CARD-C-ios.md` 已为 untracked，本次未修改该卡。交由 Opus 收货后提交并开 PR。
- §7：两入口复用单页 picker，动作卡按 exercise ID 分组、三列单选、W#D# 走卡 A 的 `TrainingSequenceText`；训练页预选当前组，聊天入口未选不可发送。问题与选组同页，保留带视频开关/失败禁用；确认后依次走现有 `makeSetRefIntent → stageSetRef → sendStagedSetRef`，outbox、幂等键、重试和 wire set_ref 不变。新增分组元数据只存在于 picker 内存候选。
- §8：留言在气泡上方，附件内嵌下方，空留言无占位；缺失指标省略；双方配色复用各自会话色与正文字体，时间/现有送达文案在气泡下方。带视频继续走原播放入口，无视频附件可展开只读详情；历史 canonical body 识别规则保留。
- §9：新增可测 `SetEntryVideoPlaybackState` 与组录入页持有的单一 `AVPlayer`，默认暂停，拖动、四档倍速、同页 overlay 放大/缩小；放大时顶部下滑/收起按钮/无障碍返回先缩小，进度倍速保留。加载重试随视图 task 取消，离开宿主停止并释放。视频下方状态与 Replace/Delete 用 `ViewThatFits` 整体换行；上传、替换、删除、重试入口继续复用原 VM。`SetVideoPlaybackView`、`FeedbackVideoPlayerView`、教练打点/标注未改。
- §10：底部说明三行由 `RestTimerPolicy` 默认规则计算并格式化；中英文同步，链接进入原 `RestTimerSettingsView` 并复用注入的设置 store。出现条件、用户级已读 key、已有偏好结构不变。新增文字全部使用 `Font.MeetPR` token。

### TDD 与验证证据

只在卡内四个 seam 加/更新 5 个行为测试；替换旧两步 picker 的 4 个测试，未写视图样式镜像测试。

| Seam | Red | Green |
| --- | --- | --- |
| Picker 无默认选择 / 显式预选 / 单选 | `/tmp/meetpr-084c-picker-red.log`：默认首项选择导致 2 条断言失败 | `/tmp/meetpr-084c-picker-green.log`：1/1 |
| Picker 动作分组 / 三列内容 / 发送摘要 | `/tmp/meetpr-084c-groups-red.log`：新 presentation 入口缺失，编译失败 | `/tmp/meetpr-084c-groups-green.log`：2/2（含上一行为） |
| 气泡留言 / 附件 / 视频 / 缺字段 | `/tmp/meetpr-084c-card-red.log`：新摘要入口缺失，编译失败 | `/tmp/meetpr-084c-card-green.log`：1/1；原历史 fixture 测试保留 |
| 视频暂停 / 播放 / 四档速率 / 放大返回 | `/tmp/meetpr-084c-video-red.log`：状态模型缺失，编译失败 | `/tmp/meetpr-084c-video-green.log`：1/1 |
| 休息默认规则与规则变化后的格式化 | `/tmp/meetpr-084c-rest-red.log`：presentation 缺失，编译失败 | `/tmp/meetpr-084c-rest-green.log`：2/2（含视频 seam） |

- 九包均执行 `swift test --skip-update --disable-sandbox`。SwiftPM MCP 无 skip-update 参数，按本卡要求使用 CLI；缓存/构建目录均在 `/tmp/meetpr-084c-*`，模块缓存用 `CLANG_MODULE_CACHE_PATH` / `SWIFTPM_MODULECACHE_OVERRIDE`。首跑系统缓存不可写、依赖代理不可达，改用 `/tmp` 缓存并复制本机卡 B 的既有依赖缓存，未更新版本。
- 六包全绿：Analytics 30、CoachKit 443、CoreModels 158、DesignSystem 73、Networking 131、RepositoryContracts 6。日志 `/tmp/meetpr-084c-test-<包名>.log`。
- 三包全量未绿：ChatUI 84 项有 1 条 AVFoundation `Cannot Encode`；StudentKit 914 项有 15 条视频编码失败；AppShell 104 项有 2 个 Keychain 测试共 3 条断言失败。与本文件卡 A/B 已记的 shell 沙箱限制一致；未修改这些生产逻辑或删除测试。AppShell 初跑曾因并行审查修复期间源文件变化而终止，静止代码后已重跑获得上述完整结果。
- 排除受限项的可运行回归：ChatUI 83、StudentKit 898、AppShell 102 全绿。排除模式分别为 `VideoBadgeExporterTests`、`AVFoundationVideoExporterTests|PassthroughVideoTrimExporterTests|realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer`、`keychainTokenStore`。日志 `/tmp/meetpr-084c-available-ChatUI-final.log`、`/tmp/meetpr-084c-available-StudentKit.log`、`/tmp/meetpr-084c-available-AppShell-final.log`；不视为九包全绿。
- 主工程 XcodeBuildMCP：`MeetPR` / Debug / MeetPR-CI（iOS 26.5），`-skipPackageUpdates`，9/9 通过。xcresult：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084c-67e6b5aceff6/result-bundles/test_sim_2026-10-02T14-59-55-588Z_pid47335_4c741608.xcresult`。
- 审查修复后 `MeetPR-DemoStudent` / DemoStudent 最终构建启动成功，无新增构建 warning。日志：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084c-67e6b5aceff6/logs/build_run_sim_2026-10-02T15-08-20-770Z_pid47335_76e9b8f6.log`。
- 全仓 `swiftlint lint --strict --no-cache`：1081 文件 0 违规；工具链 `swift-format lint --recursive --strict --configuration .swift-format MeetPR MeetPRTests Modules`、`git diff --check` 通过。日志 `/tmp/meetpr-084c-lint-final.log`、`/tmp/meetpr-084c-format-final.log`。

### Standards 自审

- 按 code-review 技能做独立只读 Standards 审查：发现 1 个 P2，关闭组录入后未取消的重试加载可能重建播放器，弱引用监控可能持续空转。已改为随视图取消的 `.task(id:)` 加取消检查，监控宿主释放即退出；复审 CLEAN，0 未解决项。
- 核对 Font.MeetPR、Sendable、单写者、无新依赖、无 wire / 持久化变更，未发现需单列的 Fowler smell。仓内缺 `docs/agents/issue-tracker.md`，已提示后续用 `$setup-matt-pocock-skills` 补配置；本次直接按任务卡审查，不依赖 tracker。

### Spec 自审

- 独立只读 Spec 审查：发现 1 个 P2，expanded 的 safeAreaInset 挤开视频、inline 仅背景有圆角。已改为 expanded 顶底半透明 overlay、inline 整体圆角裁剪，倍速菜单用向上 popover 避免被裁剪；复审撤销 finding，0 未解决静态项。
- 已在 DemoStudent 的 MeetPR-CI 上亲看 Light 界面：训练页当前组预选、动作三列卡、同页输入与发送（仅 InMemory demo）、新气泡上文下附件/送达脚注、聊天 + 进入同页且无预选不可发送。截图 `/tmp/meetpr-084c-evidence/ask-coach.jpg`、`/tmp/meetpr-084c-evidence/chat-set-bubble.jpg`。
- 视频控件尚未做带样片的设备验证：该模拟器 Photos 显示“无视频”（`/tmp/meetpr-084c-evidence/photos-no-video.jpg`），没有把状态单测当成实际播放/上传证据。Computer Use 读取 Simulator 未获访问，未继续该通道。
- 休息说明/设置链接的实屏、教练端与历史消息实屏、Light/Dark、小屏和大字体矩阵，以及视频播放/拖动/倍速/放缩/替换删除实屏仍留 Opus 按卡验收。保留本地限制，不勾选卡内验收清单；本次开发自测不等于功能验收。
- 2026-10-03 返修第 1 轮（未 commit/push）：仅修顶部组号 `{0}` 中英文插值并补重量/次数/RPE、保留同一 AVPlayer/item/AVPlayerLayer 与内嵌占位以保持进度和滚动位置、改 4pt 金色进度轨 + 10pt 滑块 + 44pt 命中区；不足 1 秒片段比例同步修正。新增 4 项测试，插值/完整组信息先红后绿；播放器层测试覆盖真实 AVPlayer seek 时间、item/layer 身份、双向缩放及播放意图（macOS 媒体读取受限，不代表解码播放验收）。全量 ChatUI 84 / StudentKit 918 已跑，既有编码测试报 Cannot Encode（分别 1 / 15 条 issue）；排除原有受限项后 83 / 902 通过，两项 strict lint 与 diff-check 通过，Standards / Spec 独立审查均无遗留项。DemoStudent / iPhone 17 构建启动成功；系统相册不在 MCP runtime snapshot 内，Computer Use 未获准访问 Simulator，未完成返修后带样片设备验证，留 Opus 收货。证据 `/tmp/084c-r1-{red,header-red,header-green,player-green,ChatUI,StudentKit,ChatUI-available,StudentKit-available,swiftlint-final,format-final}.log`，本轮增量 `/tmp/084c-r1-only.diff`。
- 2026-10-03 返修第 2 轮（未 commit/push）：仅修改 SetEntryVideoPlayer / SetEntryVideoPlayerView 及播放器测试；取消跨宿主搬动共享 AVPlayerLayer，改为宿主各自持有 layer、主线程交接时先解绑旧 layer 再绑定同一 AVPlayer，dismantle 显式解绑且迟到的旧宿主拆卸不影响新绑定；保留原 player/item、进度、播放意图、倍速及内嵌占位。新增单宿主绑定回归 1 项，覆盖双向交接、先建后拆/先拆后建与 stop 解绑（新增接口缺失编译红 → 5 项播放器测试绿；不代表黑屏设备复现已转绿）。两包使用 --skip-update 全量重跑：ChatUI 84 / StudentKit 919，既有 AVFoundation Cannot Encode 分别 1 / 15 条 issue；排除原受限项后 83 / 903 全绿。全仓 swiftlint lint --strict --no-cache（1083 文件）、工具链 swift-format lint --recursive --strict、git diff --check 通过；Standards / Spec 独立只读审查均 CLEAN。DemoStudent / iPhone 17（iOS 26.5）用 -skipPackageUpdates 构建启动成功（0 warning），日志 ~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084c-67e6b5aceff6/logs/build_run_sim_2026-10-03T02-16-53-072Z_pid21929_54cfaa1d.log。已进入组录入相册并见样片，但 MCP runtime snapshot 不含系统相册目标，Computer Use 自动审批未批准访问 Simulator（未给具体原因），未完成带样片放缩出画验证，仍留 Opus 按原复现收货。证据 /tmp/084c-r2-{red,green,ChatUI,StudentKit,ChatUI-available,StudentKit-available,swiftlint,format}.log；本轮增量 /tmp/084c-r2-only.diff。
- 2026-10-03 Opus 接手第 2 轮未收敛项（放大 / 缩小后画面黑）：模拟器日志确认是旧内嵌图层在拆除前又被更新一次、抢回并清空播放器。`SetEntryVideoPlayer` 改为按 `SurfaceRole`（inline / expanded）与展开状态绑定；新增回归测试 `staleUpdateFromOutgoingSurfaceDoesNotStealPlayer`，同角色图层替换时释放旧图层。ChatUI 84 / StudentKit 920、两个严格 lint 通过；模拟器放大与缩小均出画。

## 2026-10-03 — Spec 084 · iOS 即时奖励页 / 后台完成请求

- Opus 派卡 `specs/084-walkthrough-polish/CARD-INSTANT-COMPLETION-ios.md`；T1 / P1；分支 `fix/instant-completion-celebration`，基线 `baef8db7`（`feat/084c-chat-video-rest`）。本次未 commit、未 push、未开 PR；未改 SPEC、NEXT-RELEASE、build 号或依赖。开工时任务卡已为 untracked，原样保留。
- 完成动作在第一次网络等待前设置 VM 的奖励页与发送状态，局部乐观完成不提前推进计划游标；奖励页沿用现有 CoachReceiptLine / MeetPR 字体，仅通过 presentation 切换中英文发送文案。成功响应立即更新回执，再走原有刷新与 completionRevision；提前关闭奖励页时，成功后仍回到当前训练日。undo 与 quick-log 的请求路径保持原状。
- 失败 / 30 秒截止：关闭仍在展示的完成流程，清除发送状态，只还原当前日完成标记、保留组草稿，沿用完成失败提示。独立 request/deadline 竞速只交付第一个结果，超时不等待不响应取消的 repository，迟到结果不再操作 VM；成功时取消计时任务。

### 红绿与运行证据

- 在卡内 VM / 完成 presentation seam 新增 5 个测试函数：在途奖励与成功回执、失败回滚保留组并可重试、假定时器超时及迟到结果、提前关闭后成功/失败均不重开、中英文发送文案。原重复 complete/undo 与 projection 测试保留。
- 先红后绿：`/tmp/instant-completion-red.log`（新 seam 未实现编译红）→ `...-green.log`；`...-failure-red.log`（3 条断言失败）→ `...-failure-green.log`；`...-timeout-red.log`（注入 seam 缺失）→ `...-timeout-green.log`（6 项关联测试通过）。完整前缀均为 `/tmp/instant-completion`。
- 计时实现曾复现本机 Swift 运行时 `freed pointer was not the last allocation`：传递 Duration 的异步闭包在取消后返回处崩溃，单独成功测试也复现；去除取消可通过，换时钟或拆函数仍复现。将注入 seam 收窄为无参数截止等待（默认固定 30 秒，取消检查保留）后，原成功、失败、超时与全量测试均不再崩溃。调查日志 `...-crash-isolated.log`、`...-crash-probe.log`、`...-no-cancel-probe.log`；无临时诊断代码遗留。
- 九包全部执行 `swift test --skip-update --disable-sandbox`。SwiftPM MCP 没有 skip-update 参数，因此使用 CLI；依赖代理不可达，复用本机卡 C 的固定版本缓存，缓存/构建置于 `/tmp/instant-completion-*`，未更新依赖。
- 全绿六包：Analytics 30、CoachKit 443、CoreModels 158、DesignSystem 73、Networking 131、RepositoryContracts 6。日志 `/tmp/instant-completion-<包名>-full.log`。
- 全量未绿三包：StudentKit 925 项 / 15 条既有 AVFoundation Cannot Encode；ChatUI 84 项 / 1 条同类错误；AppShell 104 项 / 2 个 Keychain 测试共 3 条断言失败，另 1 项 push 时序测试初跑失败、复跑通过。没有修改相关生产逻辑或删除测试。
- 排除历史受限项后：StudentKit 909、ChatUI 83、AppShell 102 全绿，日志 `...-<包名>-available.log`。排除模式分别为 `AVFoundationVideoExporterTests|PassthroughVideoTrimExporterTests|realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer`、`VideoBadgeExporterTests`、`keychainTokenStore`；不视为九包全量通过。
- 全仓 SwiftLint strict：1084 文件 0 违规；工具链 swift-format recursive strict、JSON 解析及 `git diff --check` 通过。日志 `/tmp/instant-completion-lint-final.log`、`/tmp/instant-completion-format-final.log`。

### 双轴审查与模拟器自测

- `code-review` 两个独立只读 reviewer：Standards CLEAN / Spec CLEAN，均 0 findings；未把自测当作 Opus 收货。任务卡直接提供 spec，不依赖仓内尚缺的 `docs/agents/issue-tracker.md`；后续依赖 tracker 的流程仍需 David 调用 `$setup-matt-pocock-skills`。
- XcodeBuildMCP 使用本 worktree 的 MeetPR.xcodeproj / MeetPR-DemoStudent / DemoStudent / MeetPR-CI（iOS 26.5），`-skipPackageUpdates`，构建启动成功，无新增 warning。
- 亲看正常完成奖励页；Demo 仓储临时注入 8 秒等待后，长按调用约 3.6 秒内（含 1.3 秒长按和工具快照）已看到奖励页与发送中，服务器响应模拟完成后原位切为已收到。发送中/已收到截图：`/tmp/instant-completion-evidence/sending-delay8.jpg`、`received-delay8.jpg`；正常截图 `normal-receipt.jpg`。
- Demo 仓储模拟 HTTP 503 错误：奖励页关闭，原「保存失败 / 暂时无法完成训练，请稍后重试。」提示实际展示；W1D3 仍为游标、3 组记录保留、长按入口恢复；关闭提示再次长按可重进发送中奖励页。截图 `/tmp/instant-completion-evidence/failure-alert.jpg`。这是 repository 错误注入，不是线上服务返回 503 的证据。
- 临时注入仅用于本机 Demo，已逐字还原 InMemoryStudentPlanRepository，清除启动注入环境并重建最终版本。未做真机流量、真实 backend 503、30 秒实等或其他尺寸/语言设备矩阵；超时用卡内假定时器验证，中英文用 catalog/presentation 测试。交 Opus 按原卡收货。
- 移除注入后的最终 DemoStudent 构建/启动：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-complete-51fc02eb6290/logs/build_run_sim_2026-10-03T05-39-59-847Z_pid57019_0a2b64ef.log`，0 warning。最终产物再次完成 3 组→长按→奖励页→「完成」回到今日已完成卡；训练 tab 继续指向推进后的训练日。
- 2026-10-03 追加改动（David 真机反馈，未 commit/push）：仅在 SetEntryVideoPlayerView 的共用画面层增加暂停态中央播放按钮（56pt 命中区、仓内字体/颜色/尺寸 token、复用播放无障碍文案），内嵌与放大态一致；播放时隐藏，结尾复用既有暂停/从头播放逻辑，底部控件保留。新增 1 项参数化行为测试覆盖两种形态的按钮点击、显隐、暂停后重现和结尾重播归零；先红后绿，相关 8 项测试通过。StudentKit 使用 --skip-update 全量 921 项有既有 AVFoundation Cannot Encode 15 条 issue；沿用前轮受限项排除后 905 项通过，不视为全量绿。改动 Swift 文件的 swiftlint lint --strict --no-cache、工具链 swift-format lint --strict 与 git diff --check 通过；Standards / Spec 独立只读复核均 CLEAN。本轮未做设备验证，按卡由 Opus 实屏收货。证据 /tmp/meetpr-ios-084c-central-play-{red,green,StudentKit,available,lint,format}.log；增量 /tmp/meetpr-ios-084c-central-play.diff。
- 2026-10-03 追加「周条 7 天日历格」：仅改训练页周条及分页数据源，按 UTC 推荐日期 `day.date`（含后移）输出至少 7 天，训练格保留序号/状态/选中，空日期输出不可点的约 0.7 倍宽休息格；星期置顶、短日期单行，超 7 格及大字体放不下时使用横向 ScrollView，滚动不触发翻周，换周行仍可滑动。文字/图标全部使用 MeetPR token，新增 Rest/休及双语读屏键。执行中 Opus 更新卡面为「一天一练」，已删除开工版本要求的同日双练分支和测试。约定分页 seam 新增 3 测试：四练补休息日、后移跨月扩展两项逐项红→绿；七天全练/跨年/全完成补回归通过（前两项原始日志 `/tmp/084b-calendar-{red1,green1,red2,green2}.log`）。九包均带 `--skip-update` 全量复跑：CoreModels 158、RepositoryContracts 6、Networking 131、DesignSystem 73、Analytics 30、CoachKit 443 通过；StudentKit 915 项有 15 个既有 Cannot Encode 问题、ChatUI 85 项有 1 个同类问题、AppShell 104 项有 2 个 Keychain 测试共 3 条断言失败，全量未绿；按前轮相同排除模式复跑 StudentKit 899、ChatUI 84、AppShell 102 通过。日志 `/tmp/084b-calendar-{full,available}-<包名>.log`。主工程 MeetPR/Debug、MeetPR-CI/iOS 26.5，XcodeBuildMCP test_sim 加 `-skipPackageUpdates CODE_SIGNING_ALLOWED=NO`：9/9 通过，xcresult `~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084b-5377bbb74f9d/result-bundles/test_sim_2026-10-03T04-21-48-633Z_pid41868_17b3942b.xcresult`。全仓 SwiftLint strict：1078 文件 0 违规，swift-format strict 通过；本轮 Modules/JOURNAL diff whitespace 检查通过（用户原有 SPEC.md 末尾空行未改）。Standards/Spec 独立只读复核均 CLEAN。DemoStudent 最终构建启动通过，中英文 Light 七格实屏及未来日点选/Back to today 已核，截图 `/tmp/084b-calendar-evidence/{chinese-light,english-light}.jpg`；未做 SE、Dark、大字体、超 7 格滚动及 VoiceOver 实屏验证（Dark 启动参数未实际改变外观），交 Opus 按卡收货。本轮未 commit/push，未改 spec/卡片、发布台账、build 或依赖。

## 2026-10-03 · completion-hang 排障（阶段 1 未通过）

- Opus 派单；当前 `diagnose/completion-hang`，基线 `2baeae10`。不 commit、不 push，未改业务源码、工程结构、依赖或发布账本。
- **未复现，未修复，根因未确定。成立的假设：无。** 遵守六阶段门槛，因没有稳定红例，未进入最小化/三项改动隔离、假设、埋点或试修。
- App 托管的真实 TodayWorkoutView 探针：无录入页 24 次、带真实 SetEntrySheet 收起及 1.1 秒等待 100 次、最终加编译开关后 6 次，均恢复主 RunLoop 空闲且呈现 controller。扫描 0/16/50/100/200/350 ms，8 秒独立看门狗。探针为 Debug configuration；直接调用完成入口、UIKit 呈现录入页，未覆盖真实 Hold 手势和私有 editing binding，不能替代原时序。100 次批次中通知授权弹窗已关闭，工具 300 秒超时但底层测试最终成功；详情见原始输出。
- 原 MeetPR-DemoStudent / DemoStudent / iPhone 17（iOS 26.5）build_run_sim 成功、0 warning；实屏逐组记完三组，未手动折叠/展开，滚动后长按 1300 ms，奖励页正常且无障碍树可读。工具会等待快照，未保证命中收起动画中途的窗口。
- 临时探针以 `COMPLETION_HANG_PROBE` + `HANG_PROBE=1` 双开关隔离，正常构建不编译；SwiftLint strict / swift-format strict / bash -n / diff whitespace 检查通过，无临时诊断日志遗留。没有业务修复，未声称回归红→绿或验收通过。
- 方法、命令、测试构建障碍、后续所需证据与六个改动文件见 [排障记录](diagnose/completion-hang-2026-10-03.md)，逐轮输出见 [probe output](diagnose/completion-hang-probe-output-2026-10-03.txt)，原 Demo 实屏见 [奖励页截图](diagnose/completion-hang-demo-not-reproduced-2026-10-03.jpg)。下一步需原容器 UI test 驱动真实保存→收起期间滚动→Hold，或补该时段录像、日志和连续主线程采样；没有红例前不试修。

- 2026-10-03 · T0/P1 Opus 文案卡，`fix/video-row-replace-copy`：仅将 StudentKit `student.videoAttachmentV3Controls.copy004` 英文 Change 改为 Replace，中文「更换」与布局不变；未 commit/push。
- 使用点核对：Localizable.xcstrings:16358 定义 → StudentStrings.swift:1117 映射 → VideoAttachmentV3Controls.swift:162 的 replace 按钮（上传中/已上传/失败状态、横纵布局共用）；上层为 VideoAttachmentSection → SetEntrySheet，另有 Preview，无异义复用，也无 Change 测试/快照断言需修改。
- 验证：StudentKit 首轮 928 过/1 项 retryAfterFailureReinitiatesFromScratch 超时，单项复跑 1/1、全包复跑 929/929 通过（0 skipped）；最终日志 `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-replace-99081fdce275/logs/swift_package_test_2026-10-03T09-40-41-282Z_pid28207_240bc866.log`。相关两份 Swift 的 SwiftLint strict、工具链 swift-format strict、catalog 唯一英文值差异检查及 diff --check 通过；catalog 的 "Change" 搜索为 0。未做模拟器实屏验证。


## 2026-10-03 · usage-notice-copy（T1/P1，Opus 派卡，待收货）

- 分支 `fix/usage-notice-copy`，开工 HEAD `033c9143`，基线 `release/1.0`。按 `specs/084-walkthrough-polish/CARD-USAGE-NOTICE-ios.md` 实装；不 commit、不 push。本节仅追加在 JOURNAL 末尾，未改历史内容、发布账本、任务卡、PrivacyInfo.xcprivacy、出现时机或确认持久化。
- 改动：`Modules/AppShell/Sources/AppShell/AnalyticsPrivacyNotice.swift`（默认读取 BuildConfig.buildTrack；正文独立 ScrollView、不限行、自然高度；标题与链接/确认按钮留在正文之外；测量三块高度适配 sheet），同目录 `AppShellStrings.swift`（可注入轨道的键选择/本地化 seam）、`Resources/Localizable.xcstrings`（CN 保留原键，Global 新键，四段定稿直接从卡复制；独立脚本逐字比对 4/4 相同）、`Modules/AppShell/Tests/AppShellTests/AnalyticsPrivacyNoticeTests.swift`（新增 3 测试），以及本 JOURNAL。
- 先红后绿：`analyticsPrivacyCopyUsesAccountLifetimeInBothTracksAndLanguages` 旧文案触发 7 条 issue（中英文仍含 90、缺账号存续与匿名化语句、Global 键不存在）→ 1/1 通过；`analyticsPrivacyBodySelectsTheRequestedBuildTrack` 缺少选择 seam 的编译错误 → 1/1 通过；`analyticsPrivacyBodyScrollsWithoutTruncationAndKeepsActionsOutside` 找不到 ScrollView → 1/1 通过，并覆盖正文无行数上限/按自然高度布局、标题和操作区在滚动正文之外、原隐私链接及确认回调。三项合跑 3/3 通过。红绿原始输出在 `/tmp/usage-notice-evidence/{copy,track,layout}-{red,green}.log`；轨道测试的红为缺 seam 的编译失败，不宣称是运行时断言失败。
- 最终验证：AppShell 全包 **107 passed / 0 failed / 0 skipped**（含既有 AuthFlowSnapshotTests，无基线更新）；3 个 Swift 文件 `xcrun swift-format lint --strict` **0 违规**、`swiftlint lint --strict --no-cache` **0 违规**。日志 `/tmp/usage-notice-evidence/{appshell-all-final,format,lint}.log`。初次依赖构建有 CoachKit 两条既有并发 warning、StudentKit 一条既有未使用表达式 warning，未修改范围外代码。独立只读 Standards / Spec 审查分别 CLEAN，0 findings；自测与审查不代替 Opus 验收。
- UI 证据：本 worktree `MeetPR.xcodeproj`，iPhone 17 / iOS 26.5（A5119984-9A8D-415C-83D4-E7145351FA79），DerivedData `/tmp/usage-notice-derived`。`MeetPR-Global / Global`、`MeetPR / Debug` 均 XcodeBuildMCP build_run_sim 成功、0 构建 warning。Global 英文默认字号末句完整；最大动态字体（启动参数 `UICTContentSizeCategoryAccessibilityXXXL`）可滚动到末句，标题、Privacy Policy、Got it 保持固定且可点。默认字号 Got it 后回登录页，停进程并去掉强制告知参数再启动，告知未再出现。CN 中文定稿完整可见。截图 `/tmp/usage-notice-evidence/global-en-default.jpg`、`global-en-ax5-top.jpg`、`global-en-ax5-bottom.jpg`、`cn-zh-default.jpg`，均已亲看。
- UI 验证限制：沿用模拟器既有安装/数据，通过进程参数 `-meetpr.analytics.privacy_notice_confirmed NO` 展示告知，未卸载或清空现有数据；因此**未覆盖卡验收 1/2 的全新安装前提**。无可用 iPhone SE（第 3 代），创建独立模拟器的 simctl 被沙箱拒绝（CoreSimulatorService / Operation not permitted），因此**验收 3 的 SE + 最大动态字体仍未覆盖**；iPhone 17 最大字号证据不能替代。最终两个测试进程均停止。
- “90 天 / 90 days / 90d TTL”全仓排查：运行时使用数据文案只命中原 AppShell 正文，现已替换；设置、帮助页、既有测试期望无其他同义副本。StudentKit `student.growthScreenPresentation.copy002`、USER-GUIDE/DEMO-SHOWCASE、设计稿/发版证据中的 90 天为成长曲线时间窗；spec 027 为 OSS 存储分层期限，均无关，保留。
- 文档交接：旧正典 `specs/043-analytics-instrumentation/SPEC.md` **317、351、413、422 行**仍写 90 天/90d TTL。新口径以本卡为准：账号存续期间保留，删除账号后与账号断开关联成为匿名记录，卸载清匿名安装标识，可删除账号或联系请求删除。按本轮正典文档归 Opus、JOURNAL 仅末尾追加的分工，未改旧 spec；这 4 处及相邻删除路径表述交 Opus 同步定稿，不能把本轮报告当作“全仓所有旧表述已清零”。

## 2026-10-04 · en-concatenated-labels（T1/P1，Opus 派卡，待收货）

- 按 `specs/084-walkthrough-polish/CARD-EN-LABELS-ios.md` 三项范围实装。分支 `fix/en-concatenated-labels`，开工/交付 HEAD `6c3f64b0`；与现场 `release/1.0` 的 merge-base 为 `202e95db`。未 commit、未 push；本节仅追加在 JOURNAL 末尾，未改任务卡、发布账本、Demo 数据、build 号或依赖。
- 中文硬约束：训练日原为「深蹲卧推日」，Dashboard 原为「深蹲、卧推日」；卡内「中文直接相连」与后者现状不一致，按 David 本轮“中文输出逐字不变”保留两处原输出。零/三主项分支保持原样。Dashboard 新增整句键 `student.dashboardTrainingDayName`，保留也用于星期日的 `student.dashboardTodayPresentation.copy011`（Sun/日）。英文单/双主项为 Deadlift day / Squat / Bench press day；恢复标签为 Medium Intensity / High Stress / About 2 days Recovery。

### 改动文件

均位于 `Modules/StudentKit/`（下列省略此前缀），加本 JOURNAL，共 11 文件：

- `Sources/StudentKit/Features/TodayWorkout/TrainingCalendarLogic.swift`：整句训练日名称；按 locale 连接主项。
- `Sources/StudentKit/Features/Dashboard/DashboardTodayPresentation.swift`：整句副标题；中文顿号、零/三主项原样。
- `Sources/StudentKit/Features/MyProfile/MainLiftExerciseFamilyResolver.swift`：主项名称 locale seam，原 property 继续默认当前语言。
- `Sources/StudentKit/Features/MyProfile/MyProfileV3Presentation.swift`：恢复标签整句占位符及可按语言验证的展示 seam。
- `Sources/StudentKit/Features/Onboarding/OnboardingLabels.swift`：三个恢复量表的 locale 重载；原公开属性/选项不变。
- `Sources/StudentKit/Features/MyProfile/MyProfileView.swift`：仅 recovery 标签允许换行、不缩字；injury 原行为不变。
- `Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`：抽出标题 View，普通字号保留原 HStack/Spacer；accessibility 字号用 VStack，让动作名占整行、单个 Ask coach 在下方。
- `Sources/StudentKit/StudentStrings.swift`、`Sources/StudentKit/Resources/Localizable.xcstrings`：新增 1 个双语手工键、4 个旧后缀改为整句模板；无其他 catalog 改动。
- `Tests/StudentKitTests/ConcatenatedLabelsTests.swift`：新增以下 3 个测试。

### 红 → 绿及检查条数

先写测试，再增加语言参数以运行旧逻辑取得真实断言红例，随后修复；未以编译/环境失败代替回归红例。

| 测试名 | 红例 | 绿例 |
| --- | --- | --- |
| `trainingDayNamesUseWholeLocalizedPhrases` | 1 测试失败、2 issues：DeadliftSun / SquatBench pressSun | 1/1；中英文单/双/零/三主项 |
| `dashboardLiftSubtitlesUseWholeLocalizedPhrases` | 1 测试失败、2 issues：DeadliftSun / Squat, Bench pressSun | 1/1；中英文单/双/零/三主项 |
| `recoveryChipsUseWholeLocalizedPhrases` | 1 测试失败、1 issue：三个标签数组缺空格 | 1/1；英文整句与中文原值 |

- 原始日志 `/tmp/en-labels-evidence/{training,dashboard,recovery}-{red,green}.log`。第一次直接 `swift test --package-path Modules/StudentKit --filter trainingDayNamesUseWholeLocalizedPhrases` 被沙箱 clang ModuleCache 写权限阻止；XcodeBuildMCP 首次随后报缺少 locale 参数的编译错误，补语言 seam 后才取得表中断言红例。首次 ViewInspector 更新网络有 HTTP2 warning，使用缓存后构建完成。
- StudentKit 首轮全量 932 项中 930 通过、2 失败：`inProgressHeroOwnsAskCoachEntry` / `completedSectionOwnsAskCoachEntry` 发现双候选 ViewThatFits 含两个 Ask coach 实例。保留原测试，改为单组视图后通过；实屏再发现自然宽度方案会提前改变默认字号布局，最终改用上文 AnyLayout。最终全量 **932 passed / 0 failed / 0 skipped**，XcodeBuildMCP `swift_package_test` 执行 `swift test --package-path .../Modules/StudentKit`，日志 `/tmp/en-labels-evidence/studentkit-final.log`（源日志 `swift_package_test_2026-10-04T03-29-41-779Z_pid31366_a7de3bf6.log`）。
- 最终工具链 `swift-format lint --strict`：**9 Swift 文件，0 违规，exit 0**；`swiftlint lint --strict --no-cache`：**9 文件，0 违规 / 0 serious，exit 0**。日志 `/tmp/en-labels-evidence/{format,lint}.log`。JSON 解析、仅 4 个模板及 1 个新增键的差异核对、中文后缀逐字核对、星期日旧键未变、`git diff --check` 均通过。
- `code-review` 独立只读 Standards / Spec 两轴及最终布局增量复审均 **CLEAN，0 findings**。未替代 Opus 收货，未改 SPEC 状态。

### 实屏证据与未覆盖验收

- XcodeBuildMCP：本 worktree `MeetPR.xcodeproj` / `MeetPR-DemoStudent` / `DemoStudent`，iPhone 17、iOS 26.5（A5119984-9A8D-415C-83D4-E7145351FA79），DerivedData `/tmp/en-labels-derived`。最终 `build_run_sim -skipPackageUpdates` 成功，0 warning，日志 `/tmp/en-labels-evidence/build-final.log`。
- 已亲看：英文 Today 的 Deadlift day；英文 Profile 三恢复标签完整可见、同字号自然换行；中文 Today 的「硬拉日」、Profile「中等强度 / 较高压力 / 约2天恢复」。截图 `/tmp/en-labels-evidence/{today-en,profile-en,today-zh,profile-zh}.jpg`。
- 最终标题：默认字号恢复 Competition / Deadlift 两行、右侧 Ask coach；accessibility-large（启动参数 `UICTContentSizeCategoryAccessibilityL`）完整显示 Competition / Deadlift，Ask coach 在下方。截图 `/tmp/en-labels-evidence/training-en-default.jpg`、`training-en-accessibility-large.jpg`。没有新增能准确测实际词内断行的布局单测，未用无关断言充数；原有唯一入口测试保留并通过。
- **未覆盖的卡验收**：验收 1/2 的“下一练”双主项卡片在中英实屏未到达（两处函数的双语输出已单测）；验收 3 指定的当前组 Competition Squat + Ask coach 未复现于最终 Demo（游标为 Deadlift，未改 Demo 数据），已用同样较长的 Competition Deadlift 验证；未做改前/改后默认字号截图逐像素对比。Opus 按原卡补验，不把这些替代证据写成完整验收通过。
- 无障碍大字号下的重量数字及其他卡外布局问题未改。模拟器只经正常导航与开始按钮，未录入/删除训练数据；测试进程已停止，语言/字号通过进程参数注入。

## 2026-10-10 · spec 086 iOS（开工核对，因现状矛盾停止）

- 工作树：`MeetPR-wt-086`；分支：`feat/086-training-strip-coach-note`；HEAD：`a36e1f13`。启动时在当前目录用 `mktemp "$PWD/.codex-write-check.XXXXXX"` 创建临时文件并删除，退出码 0；初始工作区干净。未 commit、未 push。
- 改动文件清单：仅 `docs/CODEX-JOURNAL.md` 追加本节。代码、测试、Demo、SPEC、发布台账均未修改。

### 阻塞：只读 hero 备注的“保持改前行为”与 iOS 现状不符

- SPEC §3 与 CARD-ios「iOS 上要注意的地方」要求：只读态备注保持改前行为，即“组级备注，没有才显示动作备注”；测试 seam 3 同时要求只读态行为不变。
- 当前 iOS `TodayWorkoutPresentation.swift:257` 的 `Exercise.note` 仅取 `CoachNoteDisplay.text(exercise.notes)`；`TodayWorkoutScreen.swift:660–675` 的 hero 下方灰色备注块直接显示这个 `exercise.note`，没有按 `isEditable` 区分，也没有读取 `row.draft.prescribed.coachNote`。因此当前可编辑态及已完成只读 hero 都只显示动作备注，并不存在描述中的组级优先回落行为。
- `coachNote` 字段确实存在于 `StudentPrescribedSet`，`StudentPlanProjection.swift:101` 也保留了它；不是后端缺字段。历史详情 `Features/TrainingHistory/DayDetailView.swift:61` 另有逐组备注展示，不等于训练页 hero 的取值策略，且不在本卡修改范围。
- 待 David/Opus 裁定：A）“只读态不变”按当前 iOS 事实执行，继续只显示动作备注；可编辑 hero 才新增组级小灰块并上移动作备注。B）以安卓行为为最终口径，iOS 只读 hero 也改为组级优先、动作级兜底，明确这属于新增行为而非保持现状。未替用户选择。
- 按本次指令“发现 SPEC 与 iOS 现状矛盾时停下来”停止实装。未发现需要更换推荐日期算法的证据：现有周条消费 `StudentPlanDay.date`，已有后移日期的周条测试；本次不改派生。

### 测试、验收与证据状态

- seam 1（落后派生）：未新增测试，未执行红/绿。
- seam 2（周条 presentation）：未新增测试，未执行红/绿。
- seam 3（hero 备注）：因上述矛盾未新增测试，未执行红/绿。
- seam 4（既有训练页测试）：既有断言零修改，未运行；没有人为制造失败。
- 测试结果数字：新增 0，执行 0；未宣称通过。StudentKit 全量、其他包测试、swift-format、SwiftLint 均未执行。
- 原验收 1、2、3、3b、4、5、6、7、8、8b、9、10、替换后的 11：全部未实装、未验证。
- 老用户升级第一屏：落后两周以上、进度正常两种形态均未覆盖；未创建 Demo 开关，默认 Demo 未改变。
- 未构建或启动模拟器，未触碰另一工作树的模拟器或缓存。无截图及测试日志路径；本节源码路径与行号是此次核对证据。XcodeBuildMCP 仅查询 session defaults，未设置构建配置。
- spec 外问题：未展开调查或修改；本次唯一阻塞是本卡只读态行为定义与 iOS 基线不符。

## 2026-10-10 · spec 086 iOS（实装交付，修订一取 A）

本节接续上面的开工阻塞记录。David/Opus 已在 CARD-ios「修订一」裁定 A；按裁定实装。工作树 `MeetPR-wt-086`，分支 `feat/086-training-strip-coach-note`，基点 `a36e1f13`。各次续作均在工作树试写、删除临时文件成功。未 commit、未 push；没有修改 SPEC、NEXT-RELEASE、RELEASES、build 号、后端、存储结构/键、依赖或 Dashboard。CARD-ios 的修订一是用户交接时已有的改动，不是本次实现改写。

### 改动文件清单

以下路径均相对仓根；仅 StudentKit 与本 JOURNAL：

- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCalendarLogic.swift`：从现有有效推荐日期派生 isBehind / daysBehind，不改游标推进。
- 同目录 `TrainingWeekPresentation.swift`（新增）：格子文字、无障碍标签、当前周落后胶囊。
- 同目录 `TrainingWeekStrip.swift`：箭头移到格子两端，删除独立周行与小点；提供合并后的周标题。
- 同目录 `TrainingWeekCalendarRow.swift`：星期/图形/日期或 Behind；休息无日期；圆点 8、对勾 12；保持宽度比与横滚，横滚初始定位选中格。
- 同目录 `TrainingWeekHeaderLayout.swift`（新增）：单行宽度不足时按内容比例压缩，防三位数天数截断，历史入口靠右。
- 同目录 `TodayWorkoutScreen.swift`：周次/胶囊/进度与历史同排；可编辑 hero 动作备注上移、组备注下方独立显示。
- 同目录 `TodayWorkoutView.swift`：传递 gymDayToday，并在进入、前台、现有计划刷新触发时更新。
- 同目录 `TrainingDayPreview.swift`：已落后时隐藏推荐日期行，其他情况消费现有 `day.date`（含教练后移）。
- 同目录 `CoachNoteDisplay.swift`：纯函数区分可编辑/只读备注来源，新增淡金动作备注 View；只读仍只取动作备注。
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`：新文案访问及原有 macOS DEBUG 测试资源回退支持 xcstrings plural。
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`：中英逐字采用 Android `137d816` StudentKit/RnExtras 对应值，daysBehind 与读屏采用 plural one/other；休息读屏移除日期。
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift` 与新增 `TrainingStripDemoScenario.swift`：仅启动参数启用的正常、落后、三位数、长备注和后移场景。
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TrainingWeekCalendarTests.swift`：新增 1 项。
- 同目录 `TrainingWeekPresentationTests.swift`（新增）：新增 2 项。
- 同目录 `CoachNoteReviewDisplayTests.swift`：新增 2 项。既有断言零删除、零改写。
- `docs/CODEX-JOURNAL.md`：本次开发自测与原始证据记录。

### 四处 seam 与最终检查

全部证据目录 `/tmp/spec086-evidence/`；红阶段是先写测试、公开 seam 尚不存在造成的真实编译失败，未伪造 assertion failure。

| seam | 红 | 绿 |
| --- | --- | --- |
| 1 日期与落后天数 | `logic-red.log`，缺 isBehind/daysBehind | `logic-green.log`，新增 1 项通过；完成/同日/18 天/0 天/凌晨 03:59 与 04:00/后移 |
| 2 周条 presentation | `presentation-red.log`，缺 presentation 类型 | `presentation-green.log`，新增 2 项通过；三种训练格、休息无日期、读屏、当前/非当前、英文 1/18/123 与中文 |
| 3 备注取值 | `notes-red.log`，缺 heroExerciseNote/heroLowerNote | `notes-green.log`，新增 2 项通过；动作有/无/空白、组级有/无、互不影响、只读 iOS 旧取值 |
| 4 既有训练页回归 | 无独立人为制造的红；前述编译红阶段全套无法运行。卡要求既有断言不改，故不为了红灯破坏现有行为 | 全量 `studentkit-delivery.log`：937 passed / 0 failed / 0 skipped，45 suites，含既有保存、完成、补记、set-ref、周条及备注测试 |

最终全量是在行长修正之后重新执行；新增合计 5 项，既有 932 项保持通过。实际执行入口：XcodeBuildMCP `swift_package_test({packagePath:"/Users/david/Projects/apps/MeetPR-wt-086/Modules/StudentKit"})`，session configuration `Debug`，内部运行 `swift test --package-path .../Modules/StudentKit`。沿用 JOURNAL 2026-10-04 的 MCP 路径，不使用包 scheme 的 xcodebuild test；本轮未需另设 clang ModuleCache 权限绕行。最终原始源日志 `swift_package_test_2026-10-10T07-48-59-067Z_pid52792_17dbf7b8.log` 已复制到上述目录。其余包零改动，因此没有额外包测试。

最终 `swift-format lint --strict` 和 `swiftlint lint --strict` 均检查 `swift-files.txt` 所列 15 个 Swift 文件：各 exit 0、0 违规；日志 `swift-format.log`、`swiftlint.log`。格式化工具为 Xcode toolchain 内的 swift-format；SwiftLint 为 `/opt/homebrew/bin/swiftlint`。`git diff --check` 通过。`resource-boundary-check.log` 记录新增/调整键 manual、中英齐全、Android 文案逐字、plural 与 StudentKit 无 CoachKit import 的检查；既有 StudentStrings 本地化测试在全量内通过。

### 验收逐项开发自测

以下是开发自测，不代替 Opus 按卡收货。

| SPEC 项 | 结论与证据 |
| --- | --- |
| 1 | 实屏：训练格星期/图形/第三行，无 D 序号；休息星期+Rest/休，无日期。见正常与落后截图。 |
| 2 | 实屏：完成格保留日期、未到期和恰为今天显示日期、未完成过期为金棕 Behind。单测覆盖三分支。 |
| 3 | 实屏：过期预览无旧推荐日期（`behind-preview.jpg`），未到期预览仍有推荐日期（`normal-preview-zh-dark.jpg`）；落后 18 天能开始并记录 3 组，无落后弹窗/拦截。已完成日期按 §1 保留。 |
| 3b | 0/1/18/123 天文案有单测；正常/18/123 有实屏。翻其他周 Upcoming 不带天数。长按完成当前日后 18→16、2/4→3/4，见 `completion-cursor-16days.jpg`。 |
| 4 | 实屏符合 2B，同排周次/胶囊/进度/历史，左右箭头、无小点。源码格子 minHeight=64、箭头 height=64（均≥44）。 |
| 5 | 已实操首/末周箭头、Back to today、点选未完成预览与已完成日；选中框与当前淡金格分离，见 `behind-preview.jpg`、`completed-readonly.jpg`。 |
| 6 | `--spec086-shift` 将同周第 4 日后移 5 天，周跨度 12 天；在中文 accessibility-large 实操横滚到后移格，未挤压，见 `shifted-scroll-zh-light-large.jpg`。既有 shiftedRecommendationExtendsCalendarBeyondSevenDays 测试未改。 |
| 7 | 有备注的可编辑 hero 在动作名下展示金块，灰块仅为组级；无动作备注的当前 Squat 无金块；空白由纯函数测试覆盖。中英≥200字符备注均滚动到末尾，无截断，见 hero-long-* 上/下截图。 |
| 8 | Deadlift 第 1→2→3 组动作备注保持一致，各组下方小灰字为 3-second eccentric。只读完成日金块消失，原灰字动作备注保留，见 `completed-readonly.jpg`。 |
| 8b | 实屏完成绿色对勾、当前金色实心、未轮到空心可区分；源码分别 size12 / size8，格高未变。 |
| 9 | 以有两天完成历史的同构 Demo 数据覆盖正常和落后 18 天第一屏：normal-en-light / normal-zh-dark、behind-en-light。记录组、计时、结算与游标重算均实操（`recorded-set-rest-timer.jpg`、`completion-cursor-16days.jpg`）。这是存量形态模拟，不是对真实账号执行安装升级；未改存储键/结构。 |
| 10 | 无可用 iPhone SE runtime/device，按共同约定取现有最小 iPhone 17e（390pt 宽）+ accessibility-large；英文 Dark、中文 Light 均检查三位数与长备注。默认字号中英 Light/Dark 已看。滚动视口边缘可出现下一格的部分内容，格内文字完整；选中当前格进入时居中。 |
| 11 | StudentKit 937/0/0；两 lint 0 违规；DemoStudent 独立 DerivedData 构建与运行记录见下。 |

长按完成确认：模拟器实际录入 3 组，长按完成按钮 2200ms，进入原有完成弹层，Done 返回 Today，再进 Training 游标到 W1D4、落后为 16 天；回选 W1D3 为已完成只读。`HoldToCompleteButton`、gesture state、完成保存链路均零改动，原测试保留。工具曾提示快照未稳定，重新 snapshot 后确认成功，没有把工具超时误认成功。

### Demo、存量形态与复验方法

使用 `MeetPR-DemoStudent` / `DemoStudent`，向 app 进程传下列 launch args；默认不传任何 spec086 参数：

- `--spec086-normal`：两天已完成，第 3 天推荐日期恰为 gymDayToday，第 4 天未来，含休息格。
- `--spec086-behind`：相同完成历史，当前日落后 18 天；已完成格仍有合法历史日期，未完成过期格无旧日期。
- `--spec086-behind123`：三位数落后天数。
- 上述任一基础场景可再加 `--spec086-shift`：同周第 4 日后移 5 天，验证 >7 天横滚；可加 `--spec086-long-note`：重复现有 Demo 备注至 ≥200 字符，不引入新的产品文案。
- 英文 `-AppleLanguages (en) -AppleLocale en_US`；中文 `-AppleLanguages (zh-Hans) -AppleLocale zh_CN`；大字号 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`；默认字号 `UICTContentSizeCategoryL`；主题 `-meetpr.appearance light` / `dark`。

默认 Demo 首屏不改的代码证据：无参数时 scenario=nil，原 startDate/todayOffset/day offset/endDate、完成状态、notes、仅第一组 coachNote 均沿用原分支；shift helper 返回 nil，long-note 无参数原样返回。没有写新的 UserDefaults 键；上述 Demo 场景是进程参数，不持久化。原有 Demo tests 保留并在全量通过。

### 平台差异、范围外问题与验证边界

- 修订一：只读 iOS 从来只取动作备注，已原样保留。iOS 原有 Last time 参考行在重量上方，本卡未搬它；新小灰组备注位于下方、仍在该行之后。iOS hero 的 Ask coach 与标题布局、完成流程保留。
- 既有大字号 logo 显示成 ME…R、概览动作标题词内换行、重量 175 换成 17/5 的问题不在卡内，未改。见大字号截图。此前全量重编译出现 18 条既有 Bind/VideoUpload 等测试并发警告；最终增量全量无警告，未为清警告越界改测试。
- 未实测真实时间跨凌晨 4 点的驻留/后台全过程；03:59/04:00 算法有单测，前台/进入刷新有源码接线。未用真实线上账户安装升级，存量验证方式如上。未分别构建 CN/Global 正式包；实现无按轨分支。
- 开始选用的 iOS 26.5 iPhone 17e 安装包中途被并行作业覆盖，后切换先前 Shutdown 的 iOS 26.4 iPhone 17e（`BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`）继续；没有关闭、重置或清掉其他设备。DerivedData 始终 `/tmp/spec086-derived`。尝试 shell 创建 SE 时沙箱 CoreSimulatorService 连接被拒，未绕权限；故使用共同约定的最小可用设备替代。
- Standards / Spec 独立只读审查均无 blocker；Layout 非有限宽度 nit 已处理。自测不宣告 Opus 验收通过。不需要新增产品裁定。

### 最终构建与证据索引

- 最终 `build_sim`：`MeetPR-DemoStudent` / `DemoStudent`，`-skipPackageUpdates`，独立 `/tmp/spec086-derived`，成功（111.5 秒），工具返回 0 errors / 0 warnings；原始日志已复制为 `/tmp/spec086-evidence/build-delivery.log`。随后 install_app_sim + launch_app_sim 成功；运行源日志 `com.meetpr.app_2026-10-10T07-55-27-106Z_helperpid81663_ownerpid52792_4132f6ab.log`。
- 最终包复验截图：`final-normal-en-light.jpg`、`final-behind123-en-dark-large.jpg`、`final-behind123-zh-light-large.jpg`。正常时左侧周次/胶囊/进度紧凑、历史右对齐；大字号时三位数完整同排。
- 默认不传 spec086 参数的最终启动截图：`default-demo-first-screen.jpg`。首屏仍为 Today、W1D3 Deadlift、2/4、原始连续推荐日期与已完成历史。Dashboard 代码零变动；对照 Demo diff 的 nil 分支与原有测试，未把验证场景变成默认首屏。
- 其余截图均在同一目录：`behind-en-light.jpg`、`behind-preview.jpg`、`normal-en-light.jpg`、`normal-zh-dark.jpg`、`normal-preview-zh-dark.jpg`、`hero-en-light.jpg`、`hero-no-exercise-note.jpg`、`hero-long-en-dark-large-top.jpg`、`hero-long-en-dark-large-bottom.jpg`、`hero-long-zh-light-large-top.jpg`、`hero-long-zh-light-large-bottom.jpg`、`shifted-scroll-zh-light-large.jpg`、`recorded-set-rest-timer.jpg`、`completion-cursor-16days.jpg`、`completed-readonly.jpg`。`behind123-en-dark-large-before-fix.jpg` 是修正前失败证据，不能用于最终通过结论。
- 验收 8 的覆盖边界补充：已看同一 Deadlift 三组保持原动作备注、结算后下一个训练日 Squat 无动作备注时没有旧金块残留；未在同一训练日实屏跑出“两条不同非空动作备注”的切换（现有组合日三个动作的备注均为空）。取值每次直接消费当前 exercise.note、无缓存，且纯函数测试两来源互不影响；不把该源码证据写成已看过该形态。
- 无真实安装升级账户、没有 SE 设备、没有实时跨 4 点全过程的限制仍按上文保留；不需要用户作新的产品决定。功能代码交付待 Opus 收货，未修改任何 SPEC 验收勾选或状态。

## 2026-10-10 · spec 089 iOS（开工核对：休息偏好存储待裁定）

- 工作树 `MeetPR-wt-086`，分支 `feat/089-accessory-quick-log`，HEAD `36770eaa`，初始工作区干净。当前目录创建并删除临时文件成功，exit 0。已读共同约定、089 SPEC / CARD-ios、086 JOURNAL 与 ACCEPTANCE；未 commit、未 push。
- 改动文件清单：仅本 JOURNAL 末尾追加记录；尚未修改代码、测试、Demo、SPEC 或发布账本。

### 需要裁定：只追加一个字段不能表达现有自动模式

现场证据位于 `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/StudentRestTimerSettings.swift`：

- 第 109–120 行：`setPreference(.automatic)` 删除整个既有存储键；只有 custom 写入 JSON。
- 第 154–172 行：version 2 JSON 仅有 `version`、`lowSeconds`、`midSeconds`、`highSeconds`，解码后一律构造 custom；不存在 mode 字段。
- 第 85–106 行：无数据为 automatic；旧整数迁移成三个相同的 custom 分档。
- 所以在同一个键只加 `accessorySeconds`，无法无歧义地区分“自动 + 辅助项 90 秒”和“自定义 120/180/240 + 辅助项 90 秒”。沿用删除键会丢辅助项时长；把默认三档当自动会丢用户的模式选择；复用 version 或时长哨兵会改变既有字段含义。

拟议最小扩展（未实施）：允许在原 JSON 增加两个可选字段 `mode` 与 `accessorySeconds`，保持原存储键和原有字段。旧 version 2 JSON 缺 mode 按原语义 custom，缺 accessorySeconds 为 60；无存储仍为 automatic / 60；旧整数迁移继续保留原三档。新写入显式保存 automatic/custom，切模式保留辅助项时长。此方案超出本轮“只追加一个字段”限制，按用户规定的存储结构停问边界，等待 David/Opus 裁定。

### 测试与验收状态

- 六处 seam 均未开始红绿；新增测试 0、执行 0，既有断言零删改。未运行包全量、format 或 lint；不宣称通过。
- 验收 1–13 均未实装、未验证；老用户升级第一屏和旧格式解码验证尚未执行。
- 未新增 Demo 参数，默认 Demo 未修改；未构建运行模拟器，未生成 DerivedData，未触碰其他工作树的模拟器。
- 与安卓差异：安卓偏好已有 mode，iOS 以键缺失表示 automatic；本次发现的是存储表示差异，非产品行为裁决。其他差异与 spec 外问题尚未展开。
- 原始源码证据：`/tmp/spec089-evidence/rest-settings-baseline.txt`；无测试日志或截图。

## spec 089 iOS（实装交付，2026-10-10）

本节接续前面的「开工核对」：该节所述 JSON 扩展提议未实施，待裁定状态已由 CARD-ios「修订一」及 David 后续两次线程指令取代。工作树 `MeetPR-wt-086`，分支 `feat/089-accessory-quick-log`，基于 spec 086 提交 `36770eaa`。未 commit、未 push；自测结果供 Opus 收货，不宣告验收通过。

### 实现与裁定落实

- 仅动作库 `Exercise.exerciseType == .accessory` 进入辅助项卡，nil / 未知 raw value 返回 false；不读取计划主项标记。保留 iOS 对 catalog 缺失动作整项不展示的既有投影，不定义缺失动作模型、名字，不另开卡（David 第二处裁定）。
- 在现有 hero 内接入六列行内卡，保留 086 淡金动作备注与小灰字组级备注；自重行重量不可编辑、按 0 写入，RIR 仅作占位。常驻视频/失败入口提示；组号仍进原完整录入 sheet。数字输入有逐行 FocusState 与键盘工具条 Done / 完成按钮。
- 逐组写入、覆盖、取消及串行批量全部复用现有 `persist → recordSet` 路径；取消显式 `completed:false`、`failed:false`，保留原始重量次数。空 RPE 不写处方值，请求省略 RPE；批量只选未记录且合法行，空重量跳过、计数提示，失败停止、成功保留、可重试。无新增后端接口、DTO 字段或依赖。
- 存储按修订一采用独立整数键 `meetpr.student.rest_timer.accessory_seconds.<studentID>`；缺失、非法类型、越界或非 15 倍数均回退 60。主项 `fixed_seconds` 键的读写删、version 2 JSON、旧整数迁移及「键不存在 = 自动」实现逐字保留，未加 mode 或其他 JSON 字段。协议增加两方法，两个既有 preview/test 内存实现补齐。
- 设置页新增始终可调的辅助项段，30–300 秒、步进 15 秒；自动/自定义切换不影响辅助项值。24 个辅助项中英键逐字取 `meetpr-rn@137d816`，页底说明改为目录中的复数写法。
- 休息走教练明确值 → 辅助项偏好 → 60。主项原分支不变；辅助项不弹 RPE 说明；逐组覆盖也重新计时；末组与批量不起计时。计时条与 Live Activity 的 UI、+30/−30/Skip 均未改。

### 投影与范围扩展的证据

`StudentPlanProjection` 以前给所有 canonical load mode 注入主项 180/240 秒，导致辅助项偏好永远无法生效。本卡仅在辅助项投影时保留原始 `planSet.restSeconds`；该处 Repository 范围已由 David 明确允许。

1. `accessoryProjectionPreservesCoachRestAndMainLiftVariants` 用 JSON 解码带显式 75 秒的 PlanSet，确认辅助项保留 75，其余未设组为 nil；写入集成测试再确认偏好 90 时教练 75 仍优先。
2. 同一 10 组 fixture 的主项与主项变式投影逐字段全等，休息逐组为 `[75,180,180,180,240,180,240,180,nil,nil]`；原 `studentProjectionUsesCanonicalIntensityFieldsAndIgnoresLegacyProjection` 全部断言原样通过。原主项 `restSeconds(for:)` 一行未改。
3. `accessoryOverwriteRestMatchesLiveActivity` 对 `RestTimerActivityControlling` 注入 spy，逐组、覆盖时校验页面 `restTimer` 与 activity 的 `totalSeconds`、`endsAt` 完全相同；批量后两者为空。生产 `startRestTimer` 只构造一个 nextTimer，原计时条直接消费同一 state。没有修改 Widgets，也未做真机锁屏视觉复验。

另两处小范围协议兼容接线为 `GrowthProfileV3Previews`、`StudentEmptyStateViewTests`；Demo 带视频场景需在 `VideoUploadServices.demo()` 注入 fixture，默认仍为空。VideoUpload 的生产改动只在 `VideoAttachmentViewModel`：增加 `hasLoadedAttachments`，成功读取（含空列表）才设 true；原 `manager.attachments` 把异常折成空列表，无法作取消依据，故在这里调用同一 repository 的 throwing fetchAll，并保持原 recordedAt 排序。加载失败仍保持原界面表现，只让辅助项知道状态未知；上传、压缩、播放、重试管线均未动。既有 VideoUpload 测试文件零改动并全量通过。

### 独立审查与返修

- Standards 第一轮 P2：冷启动附件尚未读完可取消。初步加 VM 状态闸；依 David 最新要求补齐失败状态和提示：未知时点已完成 ✓ 显示既有「暂时无法撤销，请稍后重试」，在 persist 前返回，详情入口保留；已知且有视频用安卓目录提示。测试覆盖成功空列表、读取失败、未知禁止写入并有提示、已知无视频可取消、已知有视频不能取消。
- Standards 第一轮 P2：lb 显示回算导致未改 60 kg 写成 60.01 kg。修为未编辑重量直接取原处方/原记录 kg；仅编辑后的输入才换算。测试覆盖首次 lb 保存原值和取消保留原值，旧覆盖测试保持。
- 自查第三项：安卓 `TodayWorkoutView.tsx` 对辅助项已完成组覆盖也起休息，而 iOS 原完成边沿条件漏掉此情形。仅辅助项放开完成边沿；测试先失败，补齐后重计时并同步 Live Activity，主项原规则不变。
- Spec 第一轮 catalog 缺失 finding 按 David 第二次裁定撤回；平台差异见下。二轴第二轮均 CLEAN；读取失败/提示的追加改动又做了 Standards 定向只读复核，CLEAN。审查者未写文件。

### 六处 seam 与原始红绿

证据目录统一为 `/tmp/spec089-evidence/`；下列均为原始工具/测试日志，不以摘要代替原输出。新增 Swift Testing 16 个，既有测试行及断言零删改。

| seam | 覆盖 | 红 | 绿 |
|---|---|---|---|
| 1 判定 | accessory / mainLift / mainLiftVariation / nil / unknown raw value，只有 accessory 为真 | `seam1-red.log`（缺 API 编译失败） | `seam1-green.log`，最终全量 |
| 2 行模型/历史 | 处方/已有记录/上次同序号；同一次历史不混更早组；BW、RPE/RIR、空重量、选择与校验 | `seam2-red.log`、`seam2-history-red.log` | `seam2-green.log`、`seam2-history-green.log`，最终全量 |
| 3 休息/存储/投影 | 优先级、旧格式、模式切换、主项不变、教练 75、活动同源、末组 | `seam3-storage-red.log`、`seam3-policy-red.log`、`seam3-projection-red.log`（实际断言失败）、`seam3-overwrite-red.log`（实际断言失败） | 对应 `*-green.log`；`seam3-rest-integration-green.log`、`seam3-terminal-green.log`、`seam-review-green.log`、最终全量 |
| 4 写入 | 普通记录/显式取消/空 RPE/覆盖/视频保护/串行失败重试/磅原值/未知提示 | `seam4-red.log`、`seam4-batch-red.log`、`seam4-review-compile-red.log`、`seam4-review-red.log`（实际断言失败）、`seam4-video-snapshot-red.log`、`seam4-unknown-hint-red.log`（实际断言失败） | `seam4-green.log`、`seam4-batch-green.log`、`seam-review-green.log`、`seam4-video-snapshot-green.log`；未知提示的绿为 `studentkit-final.log` 对应 test passed 行 |
| 5 presentation | editable recording 辅助项才替换；main/readonly/planning 不替换；全部记完推进 | `seam5-red.log` | `seam5-green.log`，最终全量 |
| 6 原功能回归 | 记录、结算、补记、聊天引用、休息、视频等原测试 | 不制造功能红测或改旧断言；全量曾出现 3 个既有视频异步 TimeoutError，原始 `studentkit-timeouts.log` 保留（不能当功能测试的红） | `video-timeouts-recheck.log` 3/0；最终 `studentkit-final.log` 953/0、`coremodels-final.log` 158/0 |

补充投影的显式教练值/主项变式、失败组后的最后未记录组等是同 seam 内已实现行为的追加证明，加入即绿，未伪造失败。六处中的前五处有真实 red→green；第六处是原测试回归边界，未人为破坏旧断言来制造 red。全量中三个超时用例是 `persistedGenerationRejectsOlderEventThatArrivesFirstAfterRestart`、`sessionFinishedDuringPersistenceDoesNotRollBackMemoryGeneration`、`staleRecoveryLoopCannotInterfereWithImmediateRetryOfSameRecord`；停 UI 操作后的定向与完整复跑均通过，代码未针对超时改动。视频导出实际通过，没有把 Cannot Encode 当通过。

### 老用户与 Demo 覆盖

- `accessoryRestUsesIndependentKeyAndPreservesLegacyPreferences` 写入真实改前格式 `{"version":2,"lowSeconds":105,"midSeconds":195,"highSeconds":315}`，逐档读回 105/195/315 且原 JSON 字节未变；旧整数 195 按原迁移读回三档 195，两种均确认辅助项 60。另测新键缺失、90 写读、学生隔离、非法值/字符串回退、自动→自定义→自动保留 90。源码比较确认现有主项 preference 方法起至文件尾与 HEAD 逐字相同。
- `--spec089-upgrade`：主项三组已完成，辅助项第一组已完成且有 uploaded 视频 marker，其余两组可继续；这是加载已有日志与附件后的第一屏，不是先现场点完的替代。附件 fixture 不含真实可播放文件，覆盖 marker/禁止取消/覆盖，不冒充真实上传。
- `--spec089-accessory`：基础辅助项 hero，默认 60 kg / 12 次、RPE 8 占位，第二组带 3-1-1 备注。
- `--spec089-rpe`：纯 RPE 无处方重量；上次 55 kg / 10 次仅作占位，可点 Last 填入。
- `--spec089-bodyweight`：重量为空但备注 bodyweight，BW / RIR 2，占位不写实际 RPE。
- `--spec089-coach-rest`：教练明确 75 秒，覆盖已在设置页存入的 90 秒。
- `--spec089-lb`：可与上述任意场景组合，单位偏好 lb。
- 任一 `--spec089-` 参数才启用 fixture；默认不带参数时 Today 仍为 W1D3 Deadlift、1 动作/3 组、周进度 2/4。默认截图 `default-demo-first-screen.jpg`；未改导航或默认 Demo 入口。
- 语言/样式验证附加启动参数：`-AppleLanguages (en)` / `(zh-Hans)`，对应 locale；`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`（恢复常规为 `UICTContentSizeCategoryL`）；用已存在的 `-meetpr.appearance dark` / `light` 覆盖仅本次进程的样式。休息 1:30 是实际进入 Profile 页面按两次 + 设置，并非靠启动参数伪造。

### CARD-ios 验收逐项自测

| 项 | 自测结论与证据 |
|---|---|
| 1 | 辅助项六列表格与 086 两级备注实屏确认：`accessory-en-light.jpg`。主项原 hero、淡金备注、小灰字组备注：`main-hero-unchanged.jpg`。主项变式 classifier / projection 断言通过；未单独把变式推进到可编辑 hero，复用的非辅助项分支未改。 |
| 2 | 处方预填、纯 RPE 空重量/上次占位：`rpe-empty-weight.jpg`；BW 无重量输入：`bodyweight-en-dark-large-rows.jpg`。 |
| 3 | 逐组变绿、下方组表/Today 在结算后推进；普通 repository 日志与 DTO 假仓库断言证明与完整录入同路径，未改 CoachKit。`single-default60.jpg`、`completion-celebration.jpg`。未连接真实教练账号。 |
| 4 | 空 RPE 请求无键、日志 nil 的单测通过；实屏保存空 RPE 后行内为空；BW/RIR 2 占位手填 7.5 后保存：`bodyweight-rpe75-saved.jpg`。 |
| 5 | 取消后行不再绿，重量 55 / 次数 10 保留：`cancel-retains-values.jpg`；fake repo 两个 false，原聚合/Progress 回归通过。带视频取消提示且状态不变：`video-cancel-blocked-zh.jpg`。未知状态/读取失败禁止取消及提示由 seam 4 验证，未额外造 UI 故障场景。 |
| 6 | 已完成带视频行 lb 重量改为 143 后覆盖成功，视频 marker 保留、重起休息：`video-overwrite-lb.jpg`；fake repo 确认仍同一 log ID。 |
| 7 | 组号进入原完整录入：`full-entry.jpg`；点失败可返回，行仍为记录态；相册 consent 与系统 picker 可达：`photos-entry.jpg`、`photos-picker.jpg`。本模拟器相册为 No Videos、无实体摄像头，真实拍摄/选片上传再返回的完整往返未验到；上传生命周期/转码等既有单测通过，升级 fixture 的视频 marker 可见。提示行常驻见各行截图。 |
| 8 | 点击 Last 仅填重量次数；批量只完成合法行、提示缺重 2 组：`batch-skipped-two.jpg`；补齐后无计时、完整完成态：`batch-complete-no-timer.jpg`。中途失败/成功保留/重试不重复用假仓库第 2 次失败断言覆盖，未用真实断网模拟。 |
| 9 | 默认 60：`single-default60.jpg`；Profile 实调 1:30 与后续生效：`settings90-en.jpg`、`custom90-running.jpg`；教练 75 优先于 90：`coach75-priority.jpg`；最后一组清掉计时：`final-set-no-timer.jpg`；批量无计时。主项旧规则与模式保持的原测试全通过，Live Activity 同源用 spy 证明，锁屏 UI 未单独实屏复验。 |
| 10 | 老用户首屏含已记组、视频和剩余可写行：`upgrade-zh-lb-large-top.jpg`、`upgrade-zh-lb-large-rows.jpg`；设置旧 JSON/旧整数/从未设置均有解码测试。首次进入设置默认 1:00，之后实调 1:30；原主项自动设置保持。 |
| 11 | 全部辅助项完成后原长按结算、庆祝、Today 撤销入口走通：`completion-celebration.jpg`、`completion-undone.jpg`，原结算/撤销断言不改。 |
| 12 | Light 中文 lb 超大字号、Dark 英文 BW/RIR 超大字号、英文常规字号均亲眼检查六列完整、132.3/143 与 7.5 不截断。无 SE；17e 均已 Booted 且有并行作业，选空闲的 iPhone 17 / iOS 26.4 `CFAA1293-2795-45DC-A279-7012482F2716`，不停止/重置其他设备。软键盘避让未验到，按 David 最新指令交 Opus；详见下。 |
| 13（iOS 替换） | StudentKit **953 passed / 0 failed / 0 skipped**；CoreModels **158 / 0 / 0**，未改其他包。全仓 swift-format strict 0 违规；SwiftLint strict 1106 文件 0 违规。DemoStudent 最终构建运行成功，工具 0 errors / 0 warnings。 |

### 软键盘、未覆盖与平台差异

- 键盘避让：沿用 TodayWorkoutScreen 原 ScrollView 和 SwiftUI 自动 keyboard safe-area/focus 避让，未添加 ignoresSafeArea(.keyboard)。AccessoryLogRow 的每行 FocusState 绑定三个输入框；焦点存在时 `.toolbar` 的 `.keyboard` ToolbarItemGroup 提供 Done / 完成，点它把 focusedField 清为 nil。未加点空白收起，也未另加程序滚动定位。硬件键盘下实际输入并保存了第三组重量、第一组 lb 重量和 RPE 7.5，Done 可清焦点；硬件键盘工具条以系统浮动区域显示，按钮有时缩成 `D…`。软键盘没有弹出；CUA 原生 Simulator 控制被工具拒绝（`Computer Use was not approved to use Simulator`），XcodeBuildMCP 无切换软键盘入口。依 David 指令不等待人工，该项明确未验到，由 Opus 开软键盘收货。
- 其他未实屏覆盖：实体摄像头、从相册实际选择视频上传再返回（本机相册为空）、真实教练端/真实断网、真机锁屏 Live Activity。分别以入口实屏、原视频全量测试、假仓库与 activity spy 补充，不冒称完整端到端验过。
- 安卓类型无法解析 → 完整录入；iOS catalog 缺失 → 既有逻辑整项不展示，本卡未改（David 裁定）。仍以唯一 accessory 类型判真，未知绝不误进辅助项。
- 按 CARD-ios 保留 iOS 完整录入的 RPE 5–10、0.5 步进与现有 lb 换算精度（编辑输入换算到 kg 保留两位；未动重量保存原值）；不复制安卓 0–10 输入范围/另一精度。
- 休息偏好采用 iOS 独立新键（修订一），安卓仍为自身偏好结构；本地模式/后端形状不改。
- 现有下方组表/完成 hero 在日志 RPE 为空时仍可能显示处方 RPE；本卡只保证行内与写入为空，按「下方表维持现状」未顺手改。已有休息条在 accessibility-large 下数字和 ±30/Skip 会换行（见 `video-overwrite-lb.jpg` / `bodyweight-rpe75-saved.jpg`），属于本卡明确沿用的 iOS UI，未改。
- 默认 Demo、spec 081 补记、训练日结算撤销、e1RM、CoachKit、Widgets、发布台账和 build 号均未改。`CARD-ios.md` 工作区改动为用户提供的修订一，本实现未写该文件。无待 David 再裁定的问题。

### 改动文件清单

以下为本任务 33 个文件（不含用户提供的 CARD-ios 修订）：

- `Modules/StudentKit/Sources/StudentKit/Demo/AccessoryDemoScenario.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/AccessoryRestSettings.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/RestTimerPreferenceRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/RestTimerSettingsView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/StudentRestTimerSettings.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryClassification.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryHistory.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryWorkoutHero.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/RestTimerPolicy.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+DraftBuilding.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/GrowthProfileV3Previews.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadServices.swift`
- `Modules/StudentKit/Sources/StudentKit/Repository/StudentPlanProjection.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/StudentEmptyStateViewTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/StudentRestTimerSettingsTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryClassificationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryPresentationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryRowTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessorySaveTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/RestTimerPolicyTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Repository/StudentPlanIntensityProjectionTests.swift`
- `docs/CODEX-JOURNAL.md`

### 最终证据与环境

- `/tmp/spec089-evidence/studentkit-final.log`：最终 953/0，包含原 VideoUpload、QuickLog、completion、set-ref、rest-timer 全部回归；`coremodels-final.log`：158/0。
- `swift-format-final.log` 为空（exit 0）；`swiftlint-final.log`：1106 文件 0 违规（exit 0）。`guards.log`：24 × 2 文案逐字比对与四项模块边界通过。源码保护检查确认旧主项偏好实现逐字未改、既有测试零删行、禁改文件未动。
- `build-final.log`：MeetPR-DemoStudent / DemoStudent，独立 `/tmp/spec089-derived`，`-skipPackageUpdates`，成功 180.6 秒；`runtime-final.log`：安装启动成功。首次 build_run_sim 超过工具 300 秒等待，`build-first-timeout.log` 自身最终 BUILD SUCCEEDED；后续完整构建运行已有明确成功结果。
- 上表截图全在 `/tmp/spec089-evidence/`，仅文件，不把图片贴进交付正文。`changed-files.txt` 为 33 个本任务文件清单（31 Swift、xcstrings、JOURNAL；不含用户 CARD 改动）。所有日志与截图都是 Demo/假数据，无账号、密钥、内网细节。
- 使用一份 DerivedData；交付前删除本任务 `/tmp/spec089-derived` 的构建中间产物与模块缓存，保留安装包产品便于复验，不清理其他工作树或模拟器。

### 返修一（共用草稿 RPE 回归，2026-10-10）

Opus 收货指出初版把所有辅助项共用草稿的实际 RPE 都设为 existingLog?.rpe，连带使 spec 081 补记的未记录辅助项初值与提交值变空。上一交付节「补记未改」仅能证明源文件未改，不能证明行为未改；该回归在本轮修复。

- 生产改动只有 `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+DraftBuilding.swift` 一处条件：仅在 `exercise.exercise.isAccessory && existingLog != nil` 时保留原记录 RPE（含 nil）；无已有记录时所有类型恢复 `set.rpe ?? 8`。主项与变式已有记录继续使用原 `existingLog?.rpe ?? set.rpe ?? 8`。
- `AccessoryRow` 的既有独立输入初始化保持不变：无 loggedSetID 时输入恒为空，教练 RPE / RIR 仅作占位；saveAccessoryRow 原 `updateRPE(rowIndex:rpe: row.rpe)` 继续把空输入写为 nil。QuickLogPlan / QuickLogSheet 源文件零改动，现有补记断言零删改。
- 本轮另改三个测试文件：`Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutQuickLogTests.swift` 新增未记录辅助项补记测试；同目录 `AccessoryRowTests.swift` 追加共用草稿默认值与已记录 nil 断言（seam 2）；`AccessorySaveTests.swift` 新增保存空 RPE→重新 load→只改重量覆盖的整条验证（seam 4）。加上本 JOURNAL，本轮共 5 文件，新增 Swift Testing 2 个。

先红后绿与最终结果：

- `r1-quicklog-red.log`：新补记测试 1 个失败、2 个断言失败，页面行初值与实际 repository 提交值均为 `[nil,nil]`，预期 `[7,8]`。工具摘要把两个 issues 算作 2 failed，原始 Swift Testing 明确为 1 test / 2 issues。
- `r1-quicklog-green.log`：修复后该测试 1/0，处方 7 和无处方默认 8 的初值、写入均正确。
- `r1-seam2-seam4-green.log`：2/0，未记录行在草稿为 8 时卡输入仍为空；已有记录 nil 经重载后仍为空；只改 60→65 kg 覆盖仍同一 log ID、RPE nil。这里是已满足行为的追加回归验证，没有伪造红测。
- 最终 StudentKit **955 passed / 0 failed / 0 skipped**（`r1-studentkit-final.log`）；CoreModels **158 / 0 / 0**（`r1-coremodels-final.log`）。既有视频测试及补记测试全量零改动通过。无其他包改动。
- 全仓 `swift-format lint --strict` exit 0、零违规（`r1-swift-format-final.log`）；`swiftlint lint --strict` exit 0、1106 文件零违规（`r1-swiftlint-final.log`）。`r1-guards.log` 记录补记源码未改、既有测试零删行。Standards / Spec 定向独立只读复核分别 CLEAN，见 `r1-review.txt`。

两处模拟器实屏均完成（iPhone 17 / iOS 26.4，同前轮专用模拟器，不碰其他工作树）：

1. 默认 Demo 无 spec089 参数：从 Training 的 W1D3 补记并完成，自动推进 W1D4，再打开补记页、滚动至 Seated Row。三组辅助项 RPE 都显示处方值 **8**；同屏主项处方 7、变式无处方默认 8 也保持。截图 `/tmp/spec089-evidence/r1-default-demo-quicklog-rpe.jpg`。未修改 Demo 数据或默认首屏。
2. 重新启动 `--spec089-accessory` 后进入 Training，三组未记录 RPE 输入为空，浅灰 **8** 为教练处方占位，与黑色重量/次数区分。截图 `/tmp/spec089-evidence/r1-accessory-empty-rpe-placeholder.jpg`。系统 accessibility 把 placeholder 也报为 value 8，是否空输入由 seam 2 / seam 4 的 input.rpe.isEmpty 与实际 nil 写入断言共同验证。

最终构建与保留产物：

- MeetPR-DemoStudent / DemoStudent 编译成功，`r1-build-final.log` 末尾 **BUILD SUCCEEDED**。build_run_sim 工具超过 300 秒等待上限；随后直接安装同一产物并 launch_app_sim，二者明确 SUCCEEDED（`r1-install-launch.log`、`r1-runtime-final.log`），未把工具超时冒称为组合调用成功。
- 最终 app 已保留：`/tmp/spec089-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`。仅删除同一 DerivedData 的 Intermediates.noindex、ModuleCache.noindex、Index.noindex，Build/Products 未删。模拟器停留在辅助项 hero，便于 Opus 继续软键盘验收。
- 本轮要求的两处实屏无未验项；软键盘避让仍按上一轮裁定交 Opus，其他上轮未覆盖项不因本次测试而冒称补齐。无需要 David 再裁定的问题。未 commit、未 push。
