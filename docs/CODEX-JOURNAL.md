# CODEX-JOURNAL — David 直驱改动台账

> **用途**:David 在 Codex 直驱的每笔 commit 在这里留一行,新条目在最上。
> Claude 每次开工按全局规约读本文件 catch-up——**这里没有的改动等于不存在**。
> **格式**:`- YYYY-MM-DD <short-sha> — 一句话改了什么(牵动的模块)`
> 密钥/密码永不入此文件。

## release/1.0(1.0(8) 累积线)

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
