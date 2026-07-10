# CODEX-JOURNAL — David 直驱改动台账

> **用途**:David 在 Codex 直驱的每笔 commit 在这里留一行,新条目在最上。
> Claude 每次开工按全局规约读本文件 catch-up——**这里没有的改动等于不存在**。
> **格式**:`- YYYY-MM-DD <short-sha> — 一句话改了什么(牵动的模块)`
> 密钥/密码永不入此文件。

## release/1.0(1.0(8) 累积线)

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
