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
