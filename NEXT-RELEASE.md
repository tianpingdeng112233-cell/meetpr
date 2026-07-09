# 下个 TestFlight 版本 — 进行中

> 这份只记**还没 archive** 的东西 + 进度。**archive 上传后**:把「本版将包含」整段挪进
> [RELEASES.md](./RELEASES.md) 作为该 build 一节,然后清空本文件、目标 build 号 +1。
> 发版模型:**main 打 tag 切包**(`beta/<版本>-<build>`),规则见 RELEASES.md 顶部;不再并 ship 分支。

## 🎯 目标:1.0 (8) — 第一个从 main tag 切的包
- **前置**:1.0 (7) 仍压在 `ship/today-entry-video-scroll @ 0ef0169` 待 David archive(ship 模式尾包,
  内容见 RELEASES.md 1.0(7) 节);7 上传后本包才有意义。
- build 号:**8**(pbxproj project 级已设)。切包前复核规则:**本地号 > ASC 已有最高号 → 直接用本地号
  不 bump;否则取 `ASC 最高号 + 1`**(`xcrun agvtool new-version <N>` + commit 后再打 tag);
  tag 名与下方清单以最终实际 N 为准。

## 本版将包含(iOS 改动合 main 后追加到这里,prep-beta 时 David 一次圈选)

以下为**自 main/ship 共同祖先起,main 侧新增**的全部 16 个 first-parent commit。
⚠️ 注意:main **不是** `ship@0ef0169`(build 7)的后继——ship 独有 #213(学员端走查六项修复)
在 main 上由 spec 049/050/051 重新落地,对应关系与复验门见下节。

**自练(solo)wave 全量**
- 自练核心循环:adhoc 记录 + 离线队列 + CatalogKit(spec 045,#214)
- solo 注册/onboarding 收口:轻 onboarding 2 屏 + 基线补记(spec 046,#218)
- solo 成长/训练页适配:catalog 归桶 + 月分组历史(spec 047,#219)
- 账号台账:注销/改密/CSV 导出(Apple 5.1.1(v))(spec 048,#221)
- 训练页信任包:完成态真值 / 今日锁 / 重量录入 / 倒计时(spec 049,#215)
- 上行信号:回顾持久化 + PR 红点消费面(spec 051,#217)
- solo honesty 修复 U11/U12(#223/#224)、U9 polish(#222)

**e1RM / 算法**
- e1RM 单一真源:资格门 + 滚动 max 序列 + 降噪 PR(spec 050,#216)
- e1RM 异常录入隔离(spec 050 §5 Phase 1,#220)
- 算法地基:iOS 只读训练标签(spec 052,#225)
- 导入历史纳入 e1RM(spec 053,#226)

**杂项**
- 教练今日分诊行直达 StudentDetailView(#212)
- 动作库 10 条重名去重(#209)
- 学员 tab 误报取消加载为错误修复(#186)

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
- [ ] 候选改动全部合 main(见上)
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
