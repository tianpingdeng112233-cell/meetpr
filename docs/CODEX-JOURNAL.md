# CODEX-JOURNAL — David 直驱改动台账

> **用途**:David 在 Codex 直驱的每笔 commit 在这里留一行,新条目在最上。
> Claude 每次开工按全局规约读本文件 catch-up——**这里没有的改动等于不存在**。
> **格式**:`- YYYY-MM-DD <short-sha> — 一句话改了什么(牵动的模块)`
> 密钥/密码永不入此文件。

## release/1.0(1.0(8) 累积线)

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
