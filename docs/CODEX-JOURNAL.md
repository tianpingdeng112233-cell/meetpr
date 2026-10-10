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

## 2026-10-10 · spec 085 iOS（开工核对阻塞，未实装）

- 工作树 `MeetPR-wt-085`，分支 `feat/085-today-final-walkthrough`，HEAD `a36e1f13`；开工工作区干净。第一条命令在当前目录以 `probe=$(mktemp "$PWD/.codex-write-probe.XXXXXX") && rm "$probe"` 试写并删除，exit 0、无输出。未转到其他目录写入，未 commit/push。
- 已读 CONTEXT、AGENTS、CLAUDE 发版路标、085–090 共同约定、085 SPEC 与 CARD-ios 全文；安卓 `137d816:src/domain/meet/weight-class.ts` 仅通过 `git show` 读取。

### 阻塞：指定训练日入口不能直接复用来满足验收 1b

卡片要求复用 `TodayWorkoutPlanHandoff` / `TodayWorkoutSelectionResolver`，且 SPEC §1 要求点概览卡后训练页选中同一天；SPEC Out of Scope 明确训练页本身不动，CARD-ios 文件范围只列 Dashboard、MyProfile、Onboarding、Shared、Resources 与对应 Tests。

现场代码证据（均为开工 HEAD，未修改）：

1. `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift:454` 的 `startWorkoutFromDashboard` 保存 handoff 后，无条件递增 `trainingJumpToken`；第 242 行将其传入训练页的 `jumpToTodayToken`。
2. `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift:115` 仅用 handoff 的 dayID 初始化 `@State selectedDayID`。
3. 同文件第 422 行监听 handoff 变化，却继续使用旧 `selectedDayID`；第 917 行要求旧选中日与新 handoff 日一致才能取得 handed-off plan，因此从已选 D1 切到 D2 的 handoff 不会在此更新选择。
4. 同文件第 428–433 行监听跳转 token，并调用 `returnToCurrentDay()`；第 597–598 行把选择设为 `sequencePage.currentSelection`（游标日）。这会把非当前日导航重置为当前日。
5. `StudentRootView.swift:213` 起以 ZStack 持有各 tab；`StudentTabAccessibilityHost.swift` 通过隐藏和固定 tab identity 切换，不能假设每次点卡都会重建训练页并重新执行 State 初始化。

以上为静态调用链证据，尚未运行模拟器复现。最小需要决策的范围调整：允许修复 `Features/TodayWorkout/TodayWorkoutView.swift` 的 handoff 接收与跳转处理，保证显式日选择优先，同时保留普通训练 tab / Start training 回当前日的行为；如增加接收端回归测试，需同时明确允许对应 TodayWorkout 测试 seam。未实施该调整，也未新建第二条导航路径。按 David「发现 SPEC 与 iOS 现状矛盾就停下来返回」的要求停止，未先做其余三项。

### 改动、测试与验收状态

- 改动文件：仅 `docs/CODEX-JOURNAL.md` 追加本节。Swift、资源、既有测试断言均未改；未改 SPEC、发布账本或 build 号。
- 五处 seam：级别表与格式、OnboardingDraft、DashboardProfileMetrics、ProfileSummaryFormatter、Today presentation，均未开始红/绿循环；新增测试 0，执行测试 0，无红/绿原始输出。
- 验收 1a 未实现/未测；1b 被上述入口阻塞；1c、1d 未实现/未测。
- 验收 2a、2b、2c 未实现/未测。
- 验收 3a、3b、3c、3d、3e、3f、3g 未实现/未测。
- 验收 4 未覆盖：五种老用户形态（手填级别、从未回答、有日期、备赛但无日期、体重一位小数）均未进行 Demo 或单测覆盖；留言保留与旧引导草稿恢复亦未验证。
- 验收 5 未覆盖：Light/Dark、中英文、最小屏及 accessibility-large 均未运行。
- 替换后的验收 6 未执行：未跑 StudentKit 全量、format、lint 或 DemoStudent 构建运行。未遇到 ModuleCache 报错，因此未使用缓存替代命令。
- 发现的卡外问题：上述 TodayWorkout handoff 接收行为；其余尚未完成调查。截图与构建/测试日志：无；本节保留静态证据路径及行号，不将代码检查写作实屏验证。

## 2026-10-10 · spec 085 iOS（实装与自测，待收货）

### 验收场景的最小范围补充（先记证据，后改）

- 默认 Demo 的 `StudentDemoSeed.makeOnboardingProfile` 固定 male / kg / 83 / 有比赛 / 已完成引导；`MeetPRApp.makeDemoRootView` 固定 accepted bond，无法经现有界面到达未填体重、other 男女表及第 7 步引导。共同约定允许启动参数 Demo 场景，David 修订一允许明确的小范围补充先记后做。
- 拟增加 `-spec085-profile <场景>`，只在 `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift` 的档案种子覆盖中生效；以及 `-spec085-onboarding`，只在 `MeetPR/Sources/MeetPRApp.swift` 的 DEMO seed 分支取消预置绑定，让现有邀请码→引导流程可到达。默认 Demo、线上依赖、存储结构和键保持原样。不修改 CoachKit。该补充不改变真实用户行为。

### 改动文件清单

本次共 36 个文件（包含本 JOURNAL）；CARD-ios.md 的修订一是用户已有改动，未由本轮编辑。

- `MeetPR/Sources/MeetPRApp.swift`
- `Modules/StudentKit/Sources/StudentKit/BodyWeightInput.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardDaySelection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardNutritionCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardOverviewCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardProfileMetrics.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardProfileMetricsView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardTodayPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardTodayScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardWeekCalendar.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileV3Presentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/OnboardingSummaryFormatter.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileCardsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/BodyWeightField.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/MeetFieldsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/OnboardingDraft.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/Steps/Step1BasicsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/Steps/Step7ExtrasSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/MeetClass.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/StudentSelectionBlock.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutSelectionResolver.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift`
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/DashboardProfileMetricsTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/DashboardProfileNavigationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/DashboardSelectionPresentationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/ProfileSummaryFormatterTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/MeetClassTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/OnboardingDraftTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutSelectionResolverTests.swift`
- `docs/CODEX-JOURNAL.md`

### 六处 seam 的红 → 绿

证据目录统一为当前工作树 `.build/spec085-evidence/`，下列日志均为当时原始 stdout/stderr，未覆盖为手写摘要；新增 10 个 Swift Testing `@Test`，未删除既有测试。

| seam | 红例原始日志与结果 | 绿例原始日志与结果 |
| --- | --- | --- |
| 1 级别表、格式、解析 | `seam1-red.log`：新 MeetClass / MeetFederation 接口不存在，编译失败 | `seam1-green.log`：2/2，四家×两性别逐格、120+ / 67.5 往返、旧文本与无效联盟级别 |
| 2 引导 / 保存隔离 / 体重 | `seam2-meet-red.log`：1 测试 5 条真实断言失败；`seam2-weight-red.log` / `seam2-patches-red.log`：新过滤、分字段 patch 接口缺失编译失败 | 对应三个 `*-green.log` 各 1/1；kg/lb/逗号地区、小数截断、kg 往返、移除、三编辑页字段隔离 |
| 3 Today metrics | `seam3-red.log`：缺 weightClassText 编译失败 | `seam3-green.log`：1/1，83.00 / 83.50、旧级别、空级别、不备赛与缺日期 |
| 4 Profile 摘要 | `seam4-red-corrected.log`：缺 note 摘要接口编译失败 | `seam4-green.log`：1/1，Meet 与留言分别展示，留言首行、原完整值保留 |
| 5 Today presentation | `seam5-red.log`：缺选择与概览 presentation 接口编译失败 | `seam5-green.log`：2/2，选择/游标独立、重置、名称/状态/计数/动作顺序 |
| 6 指定日接收 | `seam6-red.log`：缺 receive 接口编译失败 | `seam6-green.log`：1/1，显式日、再次换日、无显式日返回 cursor |

- 不把编译红例写成断言红例。`seam1-interface-red.log` 是独立编译探针缺 Testing 模块；`seam4-red.log` 含测试枚举值笔误及修改编译中文件的错误，均不是有效行为红例，正式 seam 4 红例为已纠正后重跑的 `seam4-red-corrected.log`。
- 实屏发现 SwiftUI TextField 在 setter 过滤成相同值时仍显示第三位；`weight-filter-83-25.jpg` 是失败状态（显示 83.256），改成 raw text 状态、onChange 回写过滤值后，`weight-filter-fixed.jpg/.json` 显示 83.25。原六 seam 中的纯过滤测试无法捕捉 UIKit 文本缓存，未加浅层测试冒充该 UI 回归。
- seam 2 后补旧草稿 nil / false / true Codable 往返，以及 Remove meet 不影响体重、伤病、原多行留言的断言，仍在原 seam 内，最终全量覆盖。

### 既有断言变更（逐条依据）

| 文件 / 测试 / 断言 | 原值 | 新值 | SPEC 依据 |
| --- | --- | --- | --- |
| OnboardingDraftTests / step7CompetitionDateIsConditionallyRequired / 空草稿 | `!isStepComplete(7)` | `isStepComplete(7)` | §3「第 7 步不再因没回答是否备赛拦截」，未展开提交 false |
| 同测试 / true 且只有日期 | `isStepComplete(7)` | `!isStepComplete(7)`，随后增加格式化级别后断言 true | §3「展开后三项同样必填，缺项时这一步不能继续」 |
| DashboardProfileMetricsTests / metricsShowWeightOnlyWhenPresent | `76 kg` | `76.00 kg` | §2「全端体重显示统一保留两位小数」 |
| DashboardProfileNavigationTests / metricCardsRouteToExistingEditors（hasValues false / true 两例） | `.basics` | `.weight` | §2 与 2a「体重卡有值、空态进入的页面只有一个体重输入框」 |
| ProfileSummaryFormatterTests / basicsSummaryFormatsGenderAgeHeightWeight | `男 · 25岁 · 178cm · 83kg` | `男 · 25岁 · 178cm · 83.00kg` | §2 Basic information「该行显示两位小数」 |
| 同文件 / competitionSummaryShowsDateAndClassOrOptOut / 有值 | `备赛: 日期 · IPF 83kg` | `日期 · IPF 83kg` | §3 Meet 行「值为日期 · 赛事方与级别」；旧手填文字原样保留 |
| 同测试 / opt-out | `暂不备赛` | `未填写` | §3 Meet 行「没有比赛显示现有的未填占位」 |

首轮 23 条 issue = 上表新口径 8 条（路由参数化两例计两条）+ 15 条视频编码 issue；修正后的沙箱全量仍留 15 条视频 issue。未通过删测试、放宽条件或改视频逻辑换取绿色。

### Basic information 空体重核对

只读安卓 `git -C ../meetpr-rn show 137d816:...`：`src/features/profile/ProfileEditor.tsx:37–44` 对 basics 执行 `invalidFieldsForStep(form, profileSteps[section])`，只对 injuries/note 清空错误、对 weight 过滤错误，没有对 basics 放行。`src/features/profile/model.ts:9` 指定 basics 为第 1 步；`src/features/onboarding/model.ts:277–284` 调用 `bodyWeightKgFromInput(form.weightKg, 'kg')`，空体重产生 `weightKg` 错误；ProfileEditor 在 mutateAsync 前 return。结论：安卓明确禁止空体重时只改身高保存。iOS 保留 `.basics && draft.weightKg == nil` gate，与此行为一致；不是自行扩大必填范围。

### 全量、格式与构建

- 仅改 StudentKit 包（Demo app 不是新 SPM 包；未改 CoreModels / DesignSystem / CoachKit / Networking）。StudentKit 原 932 项，本卡新增 10 项，最终 **942 passed / 0 failed / 0 skipped**。
- 沙箱内命令（通过 `.build/spec085-evidence/run-tests.sh`，filter 空字符串代表全量）：

  ```sh
  env CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/clang-module-cache" \
    swift test --disable-sandbox --skip-update \
    --package-path "$PWD/Modules/StudentKit" \
    --scratch-path "$PWD/.build/spec085-tests" \
    --cache-path "$PWD/.build/swift-cache" --filter ''
  ```

- 系统 cache 权限/依赖代理失败的原始输出在 `test-environment.log`、`test-mcp-environment.log`。依赖离线缓存只读复制本机既有 ViewInspector bare repo 到当前 `.build/swift-cache/repositories`，未更新依赖、未改 HOME。沙箱全量 `studentkit-full-final.log` 942 项有 14 个失败测试、15 条 `Cannot Encode` issue（audio 参数化两例），不称为通过。
- 依照 2026-10-04 的 MCP 方法，先将 session configuration 设 Debug，再调用 `swift_package_test({packagePath: 当前工作树/Modules/StudentKit})`，执行真实 `swift test --package-path ...`。`studentkit-mcp-full.log` 942/942；Demo 与兼容性补断言后，`studentkit-mcp-interrupted.log` 曾 signal 11 中断，不计通过、根因未定；源文件不再改动、构建结束后同命令重跑 `studentkit-mcp-final.log` **942/942，0 skipped**，包括之前全部视频导出用例。未申请沙箱外 shell、未 stash、未另建基线副本（视频在可运行环境已真实通过）。
- `swift-format lint --strict` 用 Xcode 工具链绝对路径；`swiftlint lint --strict --no-cache` 用 Homebrew 二进制，输入文件清单 `swift-files.txt`，34 个 Swift 文件 **0 违规**，日志 `format-final.log` / `lint-final.log`。`git diff --check` 通过。
- `i18n-check.log`：29 个新增双语键逐项匹配安卓 RnExtras / StudentKit 目录，旧键 0 修改；JSON 可解析。StudentKit / CoachKit 无互相 import，未改任何 Package.swift。
- `MeetPR-DemoStudent` / DemoStudent / iPhone 17e（iOS 26.5，可用最小屏 390×844；无 SE）经 XcodeBuildMCP `build_run_sim({extraArgs:["-skipPackageUpdates"]})` 构建、安装、运行成功，0 warnings；`build-final.log`。DerivedData 在本 worktree `.build/DerivedData`。未使用 `xcodebuild test -scheme <包>`。
- `code-review` Standards / Spec 两位独立只读 reviewer，初审与最后输入同步 / Demo / 兼容性增量复审均 **CLEAN，0 findings**；不代替 Opus 收货。

- 大字号实屏补修：`today-zh-dark-large.jpg` 暴露新增两位小数后数字被拆成 83. / 00 两行；仅给体重数值加单行与缩放下限，保留原字体 token、单位与卡片结构，后续复验截图见验收项。

- 上述布局补修后最后一轮 `studentkit-mcp-final-layout.log`：**942 项 / 44 suites 全通过，0 失败、0 跳过**（Swift Testing 用例运行 5.721 秒，含视频导出）。`build-final-layout.log`：DemoStudent **BUILD SUCCEEDED**、0 warnings；随后显式安装最终 `.build/DerivedData/Build/Products/DemoStudent-iphonesimulator/MeetPR.app` 并运行，以下末轮截图来自这份产物。
- 额外 Coach Demo 构建的 MCP 调用曾超过 300 秒返回超时，但后台 xcodebuild 随后正常完成，`build-coach.log` 末尾为 **BUILD SUCCEEDED**；产物实际安装运行并拍到新格式。该构建未退出时，一次学生构建遇到 build.db 锁，随后等其结束再重跑成功。超时和锁冲突不计作成功构建，也未据此修改源文件。

### 验收清单逐项自测

以下是开发自测，不代替 Opus 按 CARD 收货。截图和同名 `.json` 均在 `.build/spec085-evidence/`；仅有 jpg 的早期截图用实屏记录和对应单测补证。Demo 数据为本地内存种子，没有操作线上账号。

| 原验收项 | 自测结论与证据 |
| --- | --- |
| 1a 周条选中 / 当前标记分开 | 通过。Demo 当前为 D3：默认 D3 粗框与金底；点 D2 粗框移动、D3 保留当前标记，返回重置。`today-en-light.jpg`、`today-selected-d2.jpg`；seam 5 同时断言选择与 cursor 状态。 |
| 1b 概览与指定日跳转 | 通过。名称、状态、全天动作/组数与单行动作名按所选日更新；D2 完成只读、再从 Today 点 D4 时内存中的训练页切到 D4 只读，返回 Today 重置 D3。`training-handoff-d2.jpg`、`training-handoff-d4.jpg`；seam 5/6。 |
| 1c Start training 不跟点选走 | 通过。点非当前日后页头与底部动作不变。训练页先翻到 W2，再从 Today 点 Start training 回 W1D3；普通 Training tab 同样回当前周当前日。`training-week2-before-start.jpg`、`training-week1-after-start.jpg`、`training-tab-resets-week.jpg`。 |
| 修订一 通知跳转 | 静态调用链和 seam 6 的 nil handoff 返回 cursor 通过；本轮未实际投递并点开系统通知，不写成通知端到端通过。TodayWorkoutView 只改 handoff / token 接收，通知发起处未改。 |
| 1d 已完成日 / 当天完成后概览 | 通过。先验证 D2 Completed；再用已有 `-student-empty-state next-plan-pending` 场景，在训练页长按完成已有三组日志的 D3，关闭完成页返回 Today，概览仍为 D3 / Completed，cursor 为 D4。`today-completed-overview-final.jpg/.json`。`today-completed-overview.jpg` 是尚未真正完成的前置状态，不作通过证据。 |
| 2a 单项体重、两位输入与补零 | 通过。有值/空态均仅一个体重框；第三位回写过滤，83.25 保存后 Today 显示 83.25 kg，整数保存显示 83.00 kg。`weight-en-light.jpg`、`weight-empty-editor.jpg`、`weight-filter-fixed.jpg/.json`、`weight-integer-saved.jpg/.json`。 |
| 2b lb 转换与再次保存 | 英文实屏通过：183.25 lb → Today 83.12 kg → 重开 183.25，再保存仍 83.12。`weight-lb-en.jpg/.json`、`weight-lb-stored-kg.jpg/.json`、`weight-lb-readback.jpg/.json`；seam 2 覆盖 183.26 的稳定往返。中文自动输入存在未解决验证缺口，见下节，不将英文结果外推为中文键盘通过。 |
| 2c Basic information | 通过英文实屏：同一组件过滤 83.256 为 83.25；Profile 摘要两位，保存后 Today 同步。`basics-weight-filter.jpg`、`today-after-basics.jpg/.json`、`profile-split-rows.jpg/.json`。空体重 gate 与安卓一致，依据见上节。 |
| 3a Meet 三字段、保存与教练显示 | 通过各端 Demo 展示：无是/否、无留言框；IPF + 83 kg 保存后 Today 倒数与新格式同时在。`meet-saved-today.jpg/.json`；教练 Demo 的申请档案显示 `2026-10-13 · IPF · 83 kg`，`coach-meet-formatted.jpg/.json`。两端是独立内存种子，未把该证据称为真实服务端跨端同步。 |
| 3b 四家 × 男女 | 通过。纯逻辑逐格断言全 8 张表；other 档案可点 Men / Women，中文深色大字号逐表截图 `meet-{cpa,ipf,ipl,wp}-{men,women}-zh-dark-large.jpg/.json`。 |
| 3c 必填与清选择 | 通过。缺赛事方点 Save 显示红色缺项和提示：`meet-validation-final.jpg/.json`。先选 IPF / 83 kg，再换 IPL，级别全部未选，滚到 Save 点后仍留编辑页并提示：`meet-switch-clears-class.jpg/.json`。三字段 patch / 缺项在 seam 1/2 覆盖。旧 `meet-reset-class-validation.jpg` 实际误点到了 Progress，不用作本项证据。 |
| 3d Remove meet | 学员路径通过：确认框 → 确认 → Not scheduled，`meet-remove-confirm.jpg`、`meet-removed.jpg/.json`；seam 2 断言只清比赛三字段且保留留言等。教练无比赛显示 `—`：`coach-no-meet-unanswered.jpg/.json`（nil 种子）；未在同一后台账号实测 false + null 日期/级别同步到教练，教练读取空字段路径静态核对。 |
| 3e Meet / Note to coach | 通过。两行独立入口，原留言完整可见；改为两行留言后摘要只显示首行，比赛不变。`profile-split-rows.jpg/.json`、`note-original.jpg/.json`、`note-saved-profile.jpg/.json`；seam 2/4 验证字段隔离与完整值。 |
| 3f 第 7 步 | 不展开完成、展开缺项拦截、选齐完成均实屏通过：`onboarding-step7-collapsed.jpg/.json`、`onboarding-step7-incomplete.jpg/.json`、`onboarding-step7-complete-selection.jpg/.json`、`onboarding-without-meet-completed.jpg/.json`、`onboarding-with-meet-completed.jpg/.json`。完成后现有 coached 流程进入待教练接受页，未继续到该新用户的 Today；false / null 和 true / 格式化级别写入由 seam 2 验证，Today 展示由 seam 3 / 已绑定 Demo 验证。此替代不算“新用户完成后 Today”端到端实屏通过。 |
| 3g 营养占位 | 中英位置与四格文案通过：`today-en-light.jpg`、`today-zh-dark-large-fixed.jpg/.json`。组件无 Button / gesture，运行时快照无可点击目标；自动化无法对非交互语义目标发送 tap，因此无反应以静态与语义树核对，未声称做过坐标点击。 |
| 4 老用户升级第一屏 | 按 CARD 允许的 Demo + 单测替换，五种形态逐条见下表；无迁移或回填，没有重新注册旧用户。 |
| 5 主题 / 语言 / 小屏大字号 | 用可用最小 iPhone 17e 390×844（未安装 SE）；英文 Light 普通字号检查 Today / 体重 / Meet，英文 Light accessibility-large 检查 Meet，中文 Dark accessibility-large 检查 Today / 体重 / 全部 8 张级别表。级别文本可按组件布局将 kg 换行，完整可见；修正后的 Today 83.00 保持单行。`meet-accessibility-before.jpg`、`meet-*-zh-dark-large.jpg`、`today-zh-dark-large-fixed.jpg`。未穷举语言×主题×字号所有交叉组合，也未做真实 SE 验证；共同约定允许无 SE 时替换。 |
| 6 iOS 替换验证 | StudentKit 942/942，34 个 Swift 文件 format / lint 0 违规；DemoStudent 最终构建、安装、运行通过。未改其他 SPM 包。 |

### 存量数据五种形态与额外数据保留

| 存量形态 | 覆盖方式与结论 |
| --- | --- |
| 手填级别 83kg / -93 | Demo `-spec085-profile legacy`：Today 83kg 与倒数，编辑灰字 Previously entered: 83kg，返回未变，重新选齐后新格式；`legacy-first-screen`、`legacy-edit-cancel-before`、`legacy-cancel-preserved` 三组 jpg/json。seam 1 拒绝把旧文字误解析成新选项，seam 3/4 原样显示；-93 作为原文字路径，未单独拍实屏。 |
| true 且有日期 | 默认 Demo + legacy 场景直接带回日期，Today 倒数原样；`meet-legacy-en.jpg`、`legacy-first-screen.jpg`；seam 3 用固定日期断言倒数为 2。 |
| false 或 nil | nil 用 `-spec085-profile unanswered`，首屏 Not scheduled，进入默认今天；`unanswered-first-screen`、`unanswered-add-default-date`。false 用 Remove meet 实屏；seam 2/3 各覆盖 false / nil，打开和取消不调用保存路径。 |
| true 但无日期 | `-spec085-profile no-date` 首屏 Not scheduled：`no-date-first-screen.jpg/.json`；seam 3 明确 nil 日期没有 competition metric，正常编辑可补全。 |
| 整数 / 一位小数体重 | 默认 83 显示 83.00，legacy 83.5 显示 83.50；seam 3 断言原 snapshot.weightKg 不变，组件初始化只格式化字符串，不回写 kg。只有保存才 patch。 |

- 留言：上述 Demo 种子覆盖只变目标字段，旧留言保持原值；`note-original` 与教练两组截图可见原文。seam 4 检查摘要首行但保留整段，seam 2 对 nil / false / true 存量档案应用 Remove patch 后逐项断言留言、体重、伤病不变。
- 引导旧草稿：seam 2 以 nil / false / true、旧日期、83kg、多行留言和 83.5 做 Codable 往返，完整 equality；nil / false 收起可过第 7 步、true 必须选齐新格式。`LocalOnboardingDraftStore`、存储键、Codable 字段均未改。未从真实旧版安装提取草稿，覆盖方式为单测。

### 验证缺口、卡外发现与交付状态

- **中文小数输入待复核**：同一最终 app 在英文 en_US 的 MCP `type_text` 能输入并保存 183.25；中文 zh-Hans / zh_CN 下整串输入分别只留下 183、1832，单独追加 `.` 也未出现。`weight-lb-zh-dark-large.jpg/.json`、`weight-lb-zh-final-attempt.jpg/.json` 保留失败状态。不能据此区分 MCP 键盘注入、系统输入法或组件问题；未把原因断言为工具限制，也未按猜测改过滤规则。需要原生键盘或真机复核，中文输入验收不通过。
- 为交叉验证而调用 Computer Use 获取 Simulator，被自动审批拒绝，未提供原因；未重试或绕过该拒绝。后续只继续已有 XcodeBuildMCP 验证。此处阻止了原生键盘交叉验证，不影响此前真实英文往返与全量单测结果。
- 未完成的端到端项：实际系统通知跳转；新引导完成并获教练接受后直接进入 Today；同一后端账号 Remove 后教练同步。以上替代证据已在逐项表注明，不冒充全验收通过。没有新增需要产品裁定的行为分支。
- 卡外既有问题未改：英文 accessibility-large 的 Today 旧 Weekly progress / Coach-recommended date 标题挤压；CoachKit 既有 Basic Info 体重仍显示整数（CARD 明确教练代码不改）；旧 Demo feedback-pending / next-plan-pending 只预填日志、不预置 sequence completion，不能仅凭场景名当作当天完成，需要实际长按完成。上述均未扩大改动。
- 首次 SwiftPM 编译可见既有 `TrainingReminderScheduling.swift:122` 未使用 Bool? 及旧测试并发 warning；未改其源文件。最终学生模拟器构建 0 warnings。MCP 的 signal 11 中断和沙箱视频编码失败作为原始失败日志保留，后续真正全量绿例独立保存。
- 两轴只读复审均无新 finding；末轮 reviewer 额外查看 `coach-meet-formatted`、`coach-no-meet-unanswered`、`meet-switch-clears-class`、`today-completed-overview-final` 的截图与 JSON，未发现新问题。截图证明最终画面，不替代操作链与数据断言。
- 日志、截图统一路径：当前工作树 `.build/spec085-evidence/`（ignored，不加入版本库）；核心最终日志 `studentkit-mcp-final-layout.log`、`build-final-layout.log`、`build-coach.log`、`format-final.log`、`lint-final.log`、`i18n-check.log`；六 seam 原始红绿文件见上表。`.build/opus/` 未动。
- 交付为当前 feature 分支的未提交工作区改动；未 commit、未 push，未改任何 SPEC、NEXT-RELEASE、RELEASES、build 号或后端；安卓仓全程只读。CARD-ios 修订一保留用户已有改动。

### 返修一（2026-10-10，Opus 收货两项）

- 仅返修 Remove meet 颜色与体重单项页字段标题。本轮改动 5 文件：`Features/MyProfile/ProfileCardsSection.swift`、`Features/Onboarding/BodyWeightField.swift`、`StudentStrings.swift`、`Resources/Localizable.xcstrings`（均在 StudentKit），以及本 JOURNAL；没有改测试或扩大功能范围。
- Remove meet 的 label 显式设置 `Color.MeetPR.dangerMuted`，与 `AccountSecuritySheets.swift` 的 Delete account 行同源，避免依赖外层可能覆盖的系统 destructive 着色；仍居中。确认框内 Remove 的系统 destructive role 与删除行为不变。
- 安卓依据：只读 `137d816:src/features/profile/ProfileEditor.tsx`，weight 映射到 `WeightSection`；`src/features/onboarding/OnboardingSteps.tsx:104–110` 默认 `labelKey = 'student.rn.weight.label'`；`src/i18n/catalog/RnExtras.json:242` 对应英文 **Weight**、中文 **体重**。BasicStep 第 98 行单独传旧 `student.step1BasicsSection.copy003`。原始摘录保存在 `.build/spec085-evidence/r1-android-reference.log`。
- iOS 为 BodyWeightField 增加带默认值的 labelKey，仅单项 `.weight` 分支指定新增的 `bodyWeightLabel`（Weight / 体重，逐字取安卓）；Basic information 和引导第 1 步继续用原默认标题。单项页导航标题仍为 Body weight / 体重，输入、精度、存储规则未改。
- 验证：XcodeBuildMCP `swift_package_test({packagePath: 当前工作树/Modules/StudentKit})`，Debug，**942 passed / 0 failed / 0 skipped**；`r1-studentkit-full.log` 与 `r1-test-result.json`。既有 `TrainingReminderScheduling.swift:122` unused Bool? warning 仍在，未顺手改。34 个改动 Swift 文件重新跑 `swift-format lint --strict`、`swiftlint lint --strict --no-cache`，均 **0 违规**（`r1-format.log/.exit`、`r1-lint.log/.exit`）。`git diff --check` 通过；既有断言未改，无新增样式测试。
- `MeetPR-DemoStudent` / DemoStudent 在 **iPhone Air、iOS 26.5** 重新 build_run_sim，158.3 秒，**BUILD SUCCEEDED、0 warnings**，安装并运行成功；日志 `.build/spec085-evidence/r1-build.log`。启动参数为 `-spec085-profile legacy`；英文 `-AppleLanguages '(en)' -AppleLocale en_US -meetpr.appearance light`，中文 `-AppleLanguages '(zh-Hans)' -AppleLocale zh_CN -meetpr.appearance dark`。
- 已亲看两种主题：Meet 移除入口浅色为深红、深色为浅红；英文体重页为 Body weight 导航标题 / Weight 字段标题，中文字段为体重。四张截图及同名语义快照：`.build/spec085-evidence/r1-meet-en-light.jpg`、`r1-meet-zh-dark.jpg`、`r1-weight-en-light.jpg`、`r1-weight-zh-dark.jpg`。未在本轮保存或移除 Demo 档案。
- 本轮增量只读复审 **0 findings**。两项返修均完成，无新增待决策问题；先前记录的其他验证缺口不在本轮范围。未 commit、未 push，未改发布文件、build 号或 SPEC。
## spec 087 iOS

### 开工基线（2026-10-10，代码修改前）

- 工作树 `MeetPR-wt-085`，分支 `feat/087-progress-menu`，HEAD `d07e328c`，开工工作区干净；临时文件试写并删除成功。
- 默认 MeetPR-DemoStudent，iPhone 17e / iOS 26.5：Squat **187.5 kg**、Bench press **118.6 kg**、Deadlift **178.5 kg**；Big-three e1RM total **484.6 kg**；Training 1RM total **520 kg**；训练次数 **2**、训练周 **1**、总容量 **3,525 kg**；反馈 **3 条 / 2 未读**。强度未解锁，原页显示 Complete 3 workouts to unlock trends。
- 截图与原始 UI 快照：`.build/spec087-evidence/baseline-progress-top.jpg`、`baseline-comparison.jpg`、`baseline-stats.jpg`、`baselineTop.json`、`baselineBottom.json`、`baselineStats.json`。默认 Demo 有多周 e1RM 点，但训练日志只有一周两次；多周训练验收需额外启动参数场景，不能把默认 Demo 称作多周训练。
- 安卓只读参照 `meetpr-rn@137d816`。iOS 原对比卡还有逐项比较条，原强度图也保留本平台画法，按卡的“现有 / 原样”边界保留；三段大号值、主线、低置信度与来源详情不改。

### 已确认的实现边界

- `StudentStrings.swift` 是现有本地化唯一边界，卡的 Resources 新增词条必须在那里增加 typed key 与复数入口，属于明确的小范围接线扩展。新增 sessions / new 使用 xcstrings plural 变体，不用英文拼接判断；macOS SwiftPM 未编译 xcstrings，沿现有 catalog fallback 路径读取复数变体。
- Demo 参数场景需要在现有 `Demo/` 种子和 `MeetPR/Sources/` 的 DEMO_MODE 依赖装配接入；计划只加参数分支，默认种子、线上依赖、存储键与结构不变。此为共同约定明确授权的验证场景扩展，不改 CoachKit。
- seam 5 的原要求是“现有测试不改断言而保持通过”；不故意破坏既有源码或断言制造红例，将保存修改前与修改后的原始回归输出，明确它是兼容性绿→绿，非新增行为红→绿。

### 改动文件与复用接口

以下均为本次未提交工作区改动，节奏 T2 / P1；未 commit / push，未改 SPEC、发版台账、build 号、后端或 CoachKit。

- `MeetPR/Sources/MeetPRApp.swift`：仅 DEMO_MODE 的日志仓储参数场景装配。
- `Modules/StudentKit/Sources/StudentKit/Demo/{StudentDemoSeed,ProgressDemoScenario}.swift`：默认种子保持原值，显式参数才注入边界场景。
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/StudentMenuRow.swift`：供 087 / 088 共用的导航行。
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/TrainingHistoryView.swift`：根页变为四行，NavigationStack 推入各目的页，保留刷新和通知入口。
- 同目录 `ProgressMenuContent.swift`、`ProgressMenuValues.swift`、`ProgressDataModel.swift`：菜单顺序 / 路由、值派生、共享现有 history / growth / feedback view model。
- 同目录 `ProgressE1RMPage.swift`、`ProgressE1RMSelection.swift`、`GrowthTotalPresentation.swift`、`GrowthTotalCard.swift`：四段与共用范围、Total 每日沿用求和及展示；单项仍调用原卡与原来源弹层。
- 同目录 `ProgressDetailPage.swift`：二级页共同加载 / 重试外壳与强度页，直接使用原 `VolumeIntensityChart`。
- 同目录 `GrowthComparisonCard.swift`、`GrowthHistoryStatsCard.swift`、`GrowthScreenHeader.swift`：从原根页提取现有组件；统计零训练显示 `—`，页头释义移入 e1RM 页。
- 同目录 `AllHistoryScreen.swift`：原列表前放三格统计；`GrowthE1RMCard.swift`：仅去掉零训练按钮限定为 squat 的条件。
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`、`Resources/Localizable.xcstrings`：新增 11 个安卓同文案词条，sessions / new 用 plural；既有词条语义改动 0（`localization-audit.json`）。
- `Modules/StudentKit/Tests/StudentKitTests/Features/TrainingHistory/{GrowthTotalTests,ProgressMenuTests,ProgressMenuNavigationTests,ProgressE1RMSelectionTests}.swift`：6 个新增 Swift Testing 测试，限卡指定的五个 seam。
- `docs/CODEX-JOURNAL.md`：本节。

088 直接调用 `StudentMenuRow(icon:title:value:valueColor:action:)`：`icon` 为 SF Symbol 名，`title` 为已经本地化的名称，`value: String?` 默认 nil，`valueColor: Color` 默认 `.MeetPR.textMuted`，`action: () -> Void`。名称与值各自按完整单行测量；总宽放不下时只把值整体放到名称下面并左对齐，无截断、词内折行、缩小。整行 Button，读屏合并“名称，值”；图标 / 箭头不重复朗读。无路由、数据源或 Profile 专属逻辑。

### 五处 seam 与原始输出

证据根目录均为 `.build/spec087-evidence/`，不是发布资产；既有测试断言删改 **0**，不存在需说明“旧值→新值”的条目。

| seam | 红与绿 | 结果与边界 |
| --- | --- | --- |
| 1 Total 纯函数 | `seam1-red.log` → `seam1-green.log` | 新类型未实现先编译红，1 个测试绿；`seam1-date-red.log` 记录日期被错误归零的失败，修为保留当日最后更新点时间戳。覆盖缺项、齐全日起、沿用、同日合并、低置信度与当前值。 |
| 1 真实打卡补验 | `seams-integration.log` → `seams-integration-green.log` | 新增真实 `E1RMRecorder` → repository → `GrowthCurveViewModel` → snapshot 路径。首轮 fixture 未使用计划内 exercise ID 导致零点，修正 fixture 后 6 个新增测试全部绿；未改生产算法。正常点逐日为 450 / 460 / 450 / 460，低置信度 900 不参与；headline 475 与 comparison 相等。 |
| 2 菜单值 | `seam2-red.log` → `seam2-green.log` | 新类型缺失红 → 1 个测试绿，涵盖中英文、单 / 复数、空 / 未读 / 全读、RPE 有 / 无 / 未解锁。 |
| 3 入口渲染与路由 | `seam3-red.log` → `seam3-green.log` | 新类型缺失红 → 1 个参数化测试（2 cases）绿；挂载真实四行组件，检查顺序 / 名称、四个点击目标、无图表、加载 / 失败仍可点。 |
| 4 e1RM 状态 | `seam4-red.log` → `seam4-green.log` | 新状态类型缺失红 → 2 个测试绿；默认 Total、范围循环且切段保持、对比 / 来源策略、三个 lift 的零训练 Today 按钮（3 cases）。 |
| 5 既有回归 | `seam5-before.log` → `studentkit-native-final.log` | 修改前相关子集 42/42；修改后纳入全量 948/948。此 seam 按卡“不改断言保持通过”，记录绿→绿，不伪造红例。 |

- 最终 StudentKit：XcodeBuildMCP `swift_package_test(packagePath: …/Modules/StudentKit)`，**948 passed / 0 failed / 0 skipped，44 suites**；`studentkit-native-final.log`、`studentkit-native-result.json`。其余 SPM 包未改源文件，无需新增包级测试。
- 沙箱 shell 全量原始结果：`studentkit-shell-full.log`，948 项中出现 15 个 `Cannot Encode` 视频编码 issue；原生入口最终全部通过，不豁免 / 删除这些测试。初次 native 调用因配置 DemoStudent 不适用 SwiftPM 而校验失败，随后切 Debug；缓存路径别名曾导致 Clang module 重复，清理生成缓存后重跑通过，均非代码测试失败。
- 复用 `.build/DerivedData` 与 `.build/spec085-tests`。为工具没有 scratch 参数的入口，包内既有 `.build` 仅保留指向指定 scratch 内容的链接；删除重复的约 746 MB 缓存，没有再建一套编译缓存。
- 最终 23 个变更 Swift 文件：`swift-format lint --strict` 与 `swiftlint lint --strict` **0 违规**，`format-final.log`、`lint-final.log`；文件表 `swift-files.txt`，`git diff --check` 通过。原生包编译有既有 Reminder / Video / Onboarding 测试警告，未扩范围修改。
- MeetPR-DemoStudent / DemoStudent，iPhone 17e / iOS 26.5，最终 `build-final.log` 构建成功、0 build warnings。
- 独立只读 Standards 与 Spec 审查均 0 findings；图表修正后两路定向复审仍 CLEAN。这是开发自审，不代替 Opus 按原验收清单收货。

### 实屏发现与修复

Total 的 Swift Charts 节点 overlay annotation 在 iOS 26.5 上稳定造成界面无响应：默认 Total 30 天→90 天即可复现，或单项 All history→Total；`total-chart-repro.json` / `total-all-settled.json` 为 AX 0 targets 的红例。按 diagnosing-bugs 流程先验证固定高度（仍卡，`total-fixed-height-chart.json`），再单独移除 annotation（恢复，`total-no-annotation.json`）。最终用同坐标两层 PointMark 画空心历史点，末点保持实心，恢复原宽高比；`total-chart-final` / `total-all-final` 证明原路径恢复、切段后范围保持。没有临时日志或算法改动；此为卡内新图表渲染问题，回归 seam 是实际 iOS UI，纯状态单测无法捕获 Swift Charts 布局挂起。系统 `sample` 被沙箱拒绝，未声称取得堆栈定位。

### Demo 参数

仅 `MeetPR-DemoStudent` 显式加 `-spec087-progress <值>` 才生效；不带参数仍是开工默认 Demo，无线上数据 / 存储结构变化。

| 值 | 场景 |
| --- | --- |
| `missing-lift` | 缺 Deadlift，Total 空态明确列缺项；有训练时单项零数据不出现 Today 按钮。 |
| `squat-only` | 四周 / 4 次，最近一天仅 Squat 160；Bench 最新 101、历史大号 102；Deadlift 最新 202、历史大号 205。Total 曲线末点 463、headline 467。 |
| `zero` | 零日志 / 零 e1RM，保留默认反馈 3 / 2，因此入口恰好三个 `—`。 |
| `single` | 一次日志，完整三项趋势；检验 `1 session` 和强度未解锁。 |
| `forming` | 一次日志、每项一个点，三项均为 1/3 成形中；Total 范围不足。 |
| `sparse` | 每项三个相同值，Total 及单项范围不足。 |
| `all-read` / `no-feedback` | 反馈全部已读 / 没有反馈。 |
| `multiweek` | 四周 / 4 次 / 2,000 kg，Total headline 462、曲线末点 455，RPE 8.0。 |
| `four-digit` | squat-only 重量乘 3，headline 1,401.0、曲线末点 1,389，用于大小屏 / 字号。 |
| `no-rpe` | 四周日志均无 RPE，强度入口 `—`，仍可进入现有柱图。 |
| `loading` / `load-failure` | 日志读延迟 8 秒 / 抛离线错误；失败持续存在直到去掉参数重启，供加载与重试观察。 |

语言 / 主题 / 字号使用进程参数，如 `-AppleLanguages (en) -AppleLocale en_US -meetpr.appearance light -UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`；中文为 `(zh-Hans)` / `zh_CN`，深色为 `dark`。未重置、关闭或操作 086 的模拟器。

### 第一步验收 1–12 开发自测

以下名称均指证据根目录下同名 `.jpg` 与 `.json`，除特别说明外为实际模拟器导航后的截图与 AX 快照。未改 SPEC 勾选项，不把开发自测称作终审。

| 项 | 自测结论与证据 |
| --- | --- |
| 1 四行入口 | 通过。仅页头与 e1RM / Training history / Coach feedback / Intensity metrics，顺序、图标、值、箭头完整，无图表 / 三格 / Body weight。`default-menu-en`、`default-menu-zh.jpg`。 |
| 2 右侧值各状态 | 通过。默认 484.6 / 2 sessions / 2 new / —；`forming-menu` 为 1 session；`missing-menu` Total —；`zero-menu` 三个 —；`feedback-read-complete` 与 `all-read-flag-menu` 为反馈总数 3；`no-feedback-menu` 为 —；`multiweek-menu` 为 RPE 8.0；`no-rpe-menu` 为 —。中文对应 `menu-zh-dark-large`。 |
| 3 四段与范围 | 通过。初进 / 返回再进 Total + 30 days；30→90→All history→30；90 天单项切 Total、All history 单项切 Total 均保留范围。`default-total`、`default-squat-90`、`range-all`、`total-chart-final`、`total-all-final`、`reentry-total`；纯状态测试另覆盖循环。 |
| 4 Total 口径 | 数值 / 序列 / 缺项自测通过。`squat-only-{total,squat,bench,deadlift}`：大号 160 + 102 + 205 = 467，入口与对比 467；曲线末点 160 + 101 + 202 = 463，相比首点 450，变化 +13。真实打卡 seam 验证每个更新日出点及低置信度不参与。`missing-total` 明确 Still missing: Deadlift；`zero-total` 列全部缺项；`constant-total-sparse` 为范围不足。Total 代码无手势 / 点选 callback，AX 无来源按钮；**未做曲线坐标点按实测**：MCP 只接受交互元素 ref，Computer Use 对 Simulator 返回未授权，因此未越过该权限边界。 |
| 5 对比仅 Total | 通过。Total 保留原 484.6 / 520 两值与逐项条，深蹲超过时原绿色 104% 行仍在；其他三段没有对比。`default-total`、`default-{squat,bench,deadlift}`、`total-chart-final`。 |
| 6 三段四态与来源 | 通过。三段均看过零数据（`zero-{squat,bench,deadlift}`）、成形中（`forming-{squat,bench,deadlift}`）、范围不足（`default-{squat,bench,deadlift}`）、曲线（`squat-only-{squat,bench,deadlift}`）。零训练三段均有 Today 按钮，有日志而缺硬拉则没有（`missing-deadlift`）。来源改前 / 改后 `baseline-source` / `default-source-after`：10/7、187.5 kg、深蹲第 3 组、142.5×5、RPE 7.5、76%、142.5÷0.76，逐项一致。 |
| 7 历史三格与双入口 | 通过。`default-history`、`training-history-entry` 都是 2 / 1 / 3,525 kg，与基线一致；列表内容和筛选保留。`zero-history` 三个 — 与既有空态；`multiweek-history` 为 4 / 4 / 2,000 kg。 |
| 8 反馈与已读回流 | 通过。新行推入现有 FeedbackInboxView，3 条；逐条进入详情后返回从 2 未读→1 未读→总数 3，`default-feedback`、`feedback-all-read-return`（中间态为 1）、`feedback-read-complete`。Today 仍按 iOS 原交互先展开卡，再进入同一 FeedbackDetailView（`today-feedback` / `today-feedback-open`）；未把 Today 改成安卓的整个收件箱入口，见差异说明。 |
| 9 强度页 | 通过。`intensity-en-large` 四周柱 + RPE 线 + 原图例；`default-intensity-locked` / `zero-intensity` 保留 Complete 3 workouts to unlock trends；`no-rpe-intensity` 保留原柱图无 RPE 数据的画法。原图源文件没有改动。 |
| 10 加载 / 失败 / 刷新 | 通过所要求的状态与点击自测。`loading-menu` 值留空、四行可点，`loading-e1rm` 等待态；注入 URLError 离线错误后 `failure-menu` 值留空 + Failed to load · Retry。四行逐个进入 `failure-{e1rm,history,feedback,intensity}` 均不崩溃，各自加载失败或已有数据。点击 Retry 和下拉后仍处持续离线态（`failure-after-retry-refresh`）；正常多周场景下拉后值保持（`multiweek-after-refresh`）。没有切断真实网络，也没有宣称验证同一进程断网再联网恢复。 |
| 11 升级第一屏 | **部分覆盖**。修改前默认 Demo 基线已在开工保存；构建覆盖安装而未卸载 / 清数据后，Total / 三段数值 / 2 次 / 1 周 / 3,525 kg / 3 反馈与 2 未读全部一致。零训练三个 — 和页面空态已验。默认 Demo 只有一周两次，新增 `multiweek` 证明四周场景的新页面派生值，但没有修改前同一多周场景的覆盖安装证据；因此不把“升级前已有多周训练”这一前提记为完成。 |
| 12 主题 / 小屏 / 字号 | 通过共同约定允许的替代设备检查：没有已安装 SE，使用可用最小 iPhone 17e（390×844）。英文 Light 普通字号 `default-menu-en`，英文 Light accessibility-large `menu-en-light-large`，中文 Dark accessibility-large `menu-zh-dark-large`；四位数 1,401.0 kg 入口值完整，名称不截 / 不缩，宽度不足时值整体下一行。未做真实 SE 或穷举所有语言×主题×字号组合。 |

大字号补修：`total-zh-dark-large` 暴露新增 Total 数字被 delta 挤成两行；仅新 Total 卡用 AnyLayout 在 accessibility 字号下把变化量放到数字下方，并令重量单行。`total-zh-dark-large-fixed` 的 1,401.0 kg 完整；普通字号仍同行。随后全量 948/948、严格 lint / format 与原生构建再次通过，Standards 定向复审 0 findings。原对比卡在此字号 / 四位数下仍会折行，按“原样搬入”边界记录，不在本卡改旧组件布局。

### 与安卓差异、范围外问题与待补验证

- 保留 iOS 原三段文案（包括英文 Bench press）、原四态 / 来源弹层与卡内轴线画法；切换按钮的 Bench 取安卓词条。既有 e1RM 释义和范围不足提示不替换成安卓排版文案。
- Total 对比两格继续使用 iOS 原卡，包含逐项对比条与逐项突破文案；没有换成 RN 两张独立 StatTile + 合计百分比的表现。强度图完整复用 iOS 原柱线与图例。二级页保留现有底部 Tab 栏。
- Today 反馈卡保留“展开→单条详情”现状；Progress 行进入现有反馈收件箱，再进入同一个详情。Today 详情路径的既有已读处理与收件箱路径不同，此次未动 Today / FeedbackInbox 功能。
- 原对比卡的大字号四位数折行、默认 Demo 仅一周两次的基线限制均未隐藏；多周 Demo 的历史统计来自四周日志，旧历史列表仍照原计划分组，未为场景改列表算法。
- 没有新增产品决策或接口 / 存储问题需要 David 裁决。待 Opus 补验的是第 4 项物理坐标点按，以及第 11 项严格的升级前多周训练前提；第 12 项采用共同约定的小屏替代。未扩到第二步体重、测试 seam 6–8 或验收 14–21。
- 证据根目录 `.build/spec087-evidence/`；核心日志为 `studentkit-native-final.log`、`studentkit-shell-full.log`、`build-final.log`、`format-final.log`、`lint-final.log`，五 seam 原始日志见上表；审查摘要 `review-results.txt`。截图仅存文件，不进入产品资源或正典发布台账。
- 最后复位：去掉所有场景 / 语言 / 字号参数重新启动，`final-default-menu` 仍为 484.6 / 2 次训练 / 2 未读 / —，`final-default-total-90` 可正常显示曲线；已实际点过零训练 Deadlift 的 Today 按钮（`zero-today-action`）。交付时停在默认 Progress 入口。分支仍 `feat/087-progress-menu` @ `d07e328c`，25 个工作区文件，提交数未增加；完整工作区补丁 `spec087-working-tree.diff`。
