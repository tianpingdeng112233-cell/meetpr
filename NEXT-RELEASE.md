# ⛔ 本文件已过时 — main 不是发版线(2026-07-10 David 拍板,读到这里就停)

> **发版线 = `release/1.0`**(1.0(7) @ 0ef0169 基底 + 小步直推)。`beta/1.0-8` **已经打在
> release/1.0 上**(4e2a0d6,tag CI 绿,待 archive)。**严禁在 main 打任何 `beta/*` tag、
> 严禁从 main 切包/跑 prep-beta、严禁把 main 当"下一个内测包"**——build 号 8 已被 release 线占用。
> 权威规则:release/1.0 分支的 `AGENTS.md` §发版直推流(含 P0–P2 优先级尺、捞回队列、失效保护);
> 发包相关工作一律去 `~/Projects/apps/MeetPR-release` worktree 做。
>
> **main 的现役身份 = 下个大包的待分诊库存**:David 三包同屏对比后裁决 coached 学员端形态正典
> = 1.0(7),main 独有 commit(solo 波/e1RM wave/页面重做)降级待分诊;已批准部分按捞回队列
> 在 7 基底**重做**进 release 线,不 cherry-pick、不整体回归。

## 以下为历史存档:main 侧库存清单(仅作分诊参考,不是发包清单)

以下为**自 main/ship 共同祖先起,main 侧新增**的全部 16 个 first-parent commit。
⚠️ 注意:main **不是** `ship@0ef0169`(build 7)的后继——ship 独有 #213(学员端走查六项修复)
在 main 上由 spec 049/050/051 重新落地,对应关系与复验门见下节。

**学员端(有教练线,对内测员生效)**
- 账号台账:注销/改密/CSV 导出(Apple 5.1.1(v))(spec 048,#221)— 不分 trainingMode,所有学员生效
- 训练页信任包:完成态真值 / 今日锁 / 重量录入 / 倒计时(spec 049,#215)
- 上行信号:回顾持久化 + PR 红点消费面(spec 051,#217)
- U9 polish 中的共享面:E1RM 说明 / 配重换行 / e1RM 曲线轴点标(#222)

**🚪 solo(自练)线——随包休眠,本版不启用(David 2026-07-10 拍板)**

> solo 代码已合 main 且与 e1RM 等交错,不 revert(defer≠delete,先例 spec 033 评估期停用)。
> 门 = 注册页隐藏「学员 · 自己练」角色卡(`SignupView.offeredRoles`),无入口即不可达;
> 恢复 solo = 该常量改回 `UserRole.allCases`。**prep-beta 圈选时勿把下列条目当上新写**:
- 自练核心循环:adhoc 记录 + 离线队列 + CatalogKit(spec 045,#214)— CatalogKit 仍被 e1RM/成长页共享使用
- solo 注册/onboarding 收口(spec 046,#218)— 入口已门
- solo 成长/训练页适配(spec 047,#219)
- solo honesty 修复 U11/U12(#223/#224)

**e1RM / 算法**
- e1RM 单一真源:资格门 + 滚动 max 序列 + 降噪 PR(spec 050,#216)
- e1RM 异常录入隔离(spec 050 §5 Phase 1,#220)
- 算法地基:iOS 只读训练标签(spec 052,#225)
- 导入历史纳入 e1RM(spec 053,#226)

**杂项**
- 教练今日分诊行直达 StudentDetailView(#212)
- 动作库 10 条重名去重(#209)
- 学员 tab 误报取消加载为错误修复(#186)

**发布前直修(2026-07-10,David 点名三项 + 顺入)**
- 教练看学员执行页锚定**本周**(原永远显示 cycle 第 1 周)(#231)
- 学员训练界面组数 1-based:录入 sheet 标题 / 当前组 hero / 组表序号(port 自 shift-day 栈 9188915 组号切片)(#232)
- 闪退至登录修复:token 过期前主动刷新 + 401 自动换 token 重试 + generation 竞态防护(port 自栈 d8cc8d0+00eb004)(#233)
- 启动加固顺入:瞬时刷新失败不清会话 + DraftStore 崩溃循环降级(#202)

## ⚠️ #213 六项修复 → main 对应关系(首个 main tag 前逐项复验,勿跳)

ship 独有的 #213 修了学员端走查六项;main 侧按 spec 重新实装(不是 cherry-pick,部分项按新产品
裁决**改写**,不是等价搬运)。打 `beta/1.0-8` 前必须逐项复验:

**复验基线(勿用错)**:从**目标 `origin/main` commit** 开隔离 worktree
(`git worktree add <path> --detach <目标commit>`),按项分两条路跑:
- **①②④⑤⑥**:`MeetPR-DemoStudent` scheme(DemoStudent 配置,学员端 demo)模拟器复验。
  注意 `MeetPR-Demo` 起的是**教练端**,别用错 scheme。
- **③**:DemoStudent 注入 `InMemorySessionReviewRepository`,重启即丢,**测不了持久化**;
  用 **Debug 配置 + staging 测试账号**(走 `BackendSessionReviewRepository`)复验重启不丢,
  或引用已有 staging 真机证据(注明出处)。

证据落盘:`~/Projects/scratch/<日期>-213-reverify-1.0-8.md`(SHA + 逐项截图/结论),
路径回填到下表说明行,别让证据只留在会话里。
⚠️ **别直接跑现行 `/walkthrough --verify`**——那个 skill 写死 `MeetPR-ship @ 0ef0169` 为 iOS
基线,照跑等于复验 build 7 自己;要么按上述手动复验,要么先改 walkthrough skill 支持显式指定
main 候选基线。

| # | #213 修复项 | main 对应 | 性质 | 验收行为(以此为准) | 复验 |
|---|---|---|---|---|---|
| ① | 练完后今日 tab 完成态做实 | spec 049(#215) | 等价 | 练完回今日 tab,CTA/进度条/日历点反映已完成 | [ ] |
| ② | 「开始/继续」CTA 跳回今天 | spec 049(#215) | 等价 | 浏览旧日期后点 CTA 回到今天 | [ ] |
| ③ | 训练回顾持久化 | spec 051(#217) | **改写** | 回顾改为一句话 + RPE,Repository 持久化,重启不丢 | [ ] |
| ④ | 录入数字直输 | spec 049(#215) | **部分覆盖** | 仅**重量**可键盘直输(产品裁决);次数/RPE 仍步进 | [ ] |
| ⑤ | 未来/过去日只读保护 | spec 049(#215) | **改写** | 过去日**默认只读**,补录需显式进入补录态;未来日只读 | [ ] |
| ⑥ | 基线 1RM vs E1RM 澄清标签 | spec 050(#216) | **改写** | 资料页数字明确标为「入门基线」并指向成长页;Dashboard/成长的当前 e1RM 不与基线混称 | [ ] |

## 📋 进度:离 archive 推 TestFlight 还差几步
- [x] 候选改动全部合 main(见上;含 2026-07-10 直修 #231/#232/#233/#202)
- [x] solo 注册入口门合 main(#230,拍板 2026-07-10)
- [ ] #213 六项对应关系逐项复验通过(上表打勾)
- [ ] build 号复核(规则见顶部「目标」节)
- [ ] main 目标 commit 打 tag `beta/1.0-8` 并推远端
- [ ] CI 绿 + 四基线对照无异常
- [ ] David:从 tag checkout → Xcode → Product → Archive → Upload
- [ ] 等 Apple 处理 → 分配内测组 Neice → 手机点更新

> 核心 3 步(David 手动):Archive → Upload → 等处理。

## 收尾约定(给未来的你)
1. archive+上传后:把「本版将包含」+ 最终 build 号写进 `RELEASES.md` 作为 1.0(N) 一节(打包来源写 tag)。
2. 清空本文件「本版将包含 / 进度」,目标号 +1。
