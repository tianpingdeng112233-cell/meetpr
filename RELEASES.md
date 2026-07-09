# MeetPR 发布历史(TestFlight)

> 以每次 **archive** 为界,每个 build 一段,最新在最上面。
> 下个版本进行中的内容见 [NEXT-RELEASE.md](./NEXT-RELEASE.md);**archive 上传后**把那份的「本版包含」整段挪到这里。

## 版本号与切包规则(2026-07-09 起:main 打 tag 切包,ship 长命分支退役)

- **main 恒可发**:所有要发的东西合 main;不再维护 ship 长命分支往里并。
- **切包 = 在 main 打 tag**:确定要出包时,在 main 目标 commit 上打 **annotated tag**,命名
  `beta/<MARKETING_VERSION>-<build>`(例:`beta/1.0-8`),然后从该 tag checkout 出来 archive。
  tag 一经推送不移动、不复用;重打包 = bump build 号 + 新 tag。
  ```
  git tag -a beta/1.0-8 -m "TestFlight 1.0 (8)" <commit>
  git push origin beta/1.0-8
  ```
- **build 号单一真源**:`CURRENT_PROJECT_VERSION` 只存在于 pbxproj **project 级**(4 个 configuration
  各一行),target 级不再写;Info.plist 的 `CFBundleVersion` 引用 `$(CURRENT_PROJECT_VERSION)` 变量。
  已启用 `VERSIONING_SYSTEM = apple-generic`,读号/改号只走 agvtool:
  ```
  xcrun agvtool what-version -terse   # 读当前 build 号
  xcrun agvtool new-version <N>      # bump(在含 .xcodeproj 的目录跑)
  ```
  ⚠️ **禁用 `new-version -all`**:它会把 Info.plist 的 `$(CURRENT_PROJECT_VERSION)` 变量引用覆写成
  字面量数字,重新制造第二真源(2026-07-09 实测)。
- **build 号严格递增**:Apple 的硬性约束是「同一 app 版本下 build 号不可与已上传的重复/回退」;
  MeetPR **内部纪律取更严格口径**——全局严格递增、永不复用任何已上传号(避免跨版本换号踩坑)。
  从未上传的号不占坑,可以跳过。
- **app 版本**(`MARKETING_VERSION`)同样只在 project 级,当前 `1.0`。
  ⚠️ 升版本**别用 `agvtool new-marketing-version`**(同样会把 Info.plist 的 `$(MARKETING_VERSION)`
  覆写成字面量):手改 pbxproj project 级 4 处(或 Xcode GUI),改完验证 Info.plist 的
  `CFBundleShortVersionString` / `CFBundleVersion` 仍是变量引用。
- **archive + 上传 ASC 永远 David 手动**(Xcode → Product → Archive → Upload);机器侧到「tag 已打、
  CI 绿、四基线对照无异常」为止,流程见 `~/.claude/skills/prep-beta/`。

## 每版记录模板(新版照抄)
```
## 1.0 (N) — YYYY-MM-DD — 状态
- 打包来源:beta/1.0-N @ <commit>
### 本版包含
### 已知问题 / 局限
### 测试反馈
```

---

## 1.0 (7) — 目标日期待定 — 🟡 已备妥待 David archive(ship 分支模式的最后一包)

> **迁移期一次性例外**:按顶部规则,条目应在 archive+上传后才入档;此段是 ship 分支退役前的
> **预登记**(防删分支丢信息),上传后由 David/Claude 补日期与状态,不作为后续先例。

- **打包来源**:`ship/today-entry-video-scroll @ 0ef0169`,worktree `~/Projects/apps/MeetPR-ship`
  (此后发版改走 main tag,见顶部规则;build 6 从未 archive/上传,被 7 取代)

### 本版包含
- **多项目 e1RM 成长曲线**(#199)— 学员首页日卡显示每个练过项目的曲线
- **教练编排只显中文动作名**(#198)
- **教练 program-quality 分析数据层**(#196,A 组纯数据层,无 UI)
- **导入计划入口置灰封存**(#203)— in-app xlsx 导入冻结,网页编写端为唯一导入口
- **动作库 ontology 修正**(#204)— 单腿罗马尼亚硬拉别名/肌群纠错
- **学员 onboarding 小白化**(#205)— 生日中文轮盘 / 1RM 估算器 RPE 白话解释 / 恢复天数阶梯
- **器械词表 v2**(#206/#207/#208/#211)— Step 4 器械区 13→24 token 分 4 组,label 对齐中国健身房叫法
- **学员端走查 P0/P1 修复**(#213)— 完成态做实 / CTA 跳回今天 / 回顾持久化 / 数字键盘直输 /
  未来·过去日只读保护 / 基线 1RM vs E1RM 澄清标签

### 已知问题 / 局限
- E1RM 平滑/异常口径待 David 拍板(算法决策,任务卡已开;spec 050 Phase 1 已另行合 main,在 7 之后)

### 测试反馈
- (待填)

---

## 1.0 (5) — 2026-06-29 — 已上传,现行线上版(待 1.0(7) 上传后取代)
- **打包来源**:`ship/today-entry-video-scroll`(基于 `origin/main`)= [PR #197](https://github.com/tianpingdeng112233-cell/meetpr/pull/197)
- 签名 team `28JW4SA779`,arch arm64,build 5(> 已上传的 4)。

### 本版包含
- **训练 tab 弹窗记录流**(`462d9d3`):点「记录此组」弹出 `SetEntrySheet`(杠铃配重图 + 重量/次数/RPE 加减步进)、删除内联 RPE 横条、次数放大、摄像头按钮打开弹窗并滚到录像区。
- **动作库**(`2465d7c`):新增 低杠位暂停深蹲 / 低杠位节奏深蹲;所有 RDL → 「罗马尼亚硬拉」(catalog 1229 条)。
- **教练编排只留 4 周 + 内测停用评估期**(#190),以及 build 4 落后 `origin/main` 的其余主线更新(spec 043 收尾 / 埋点 spec / CI 调整)。
- 发版配置:签名 team `XV97B4R4RZ`(作废)→ `28JW4SA779`、build 号统一 `5`。

### 已知问题 / 局限
- 评估期相关代码保留但**休眠**(内测停用,见 spec 033 defer)。

---

## 1.0 (4) — 2026-06-27 — 前一线上版(被 1.0(5) 取代)
- **打包来源**:`feat/043-coach-plan-import @ a4bbdaa`(≈ 当时 main + spec 043 教练导入,本地分支版)

### 本版大致包含(累计至此的主线功能)
- 1:1 设计改版(reskin,#180)+ Stacked Lockup logo
- 学员端重做:仪表盘 / 锻炼周月日历 / 进度中心(spec 034/035/036)
- 教练端:分诊 strip + 规划工作区(spec 037/038)、训练视频反馈 inbox(spec 042)
- 卧推配重四则计算器、每组休息计时(spec 040)、失败/未完成组记录(spec 039)
- 学员 SBD 周徽章、e1RM 曲线、比赛倒计时
- spec 043 教练导入学员 Excel 计划(本地分支版)

### ⚠️ 已知问题 / 局限(均在 1.0(5) 修)
- 训练 tab 仍是旧记录流(1.0(5) 改成弹窗录入)。
- 动作库缺低杠位暂停/节奏深蹲;RDL 未统一改名。
- **build 号曾错乱(2→1→4)**:build 号写死在各分支 `pbxproj`,从不同 worktree 打包导致号不单调 →
  低号上传会被 Apple 拒。1.0(5) 统一为 5;2026-07-09 起 apple-generic + project 级单源根治(见顶部规则)。

---

## 1.0 (2) — 2026-06-24 — (已被取代)
- 打包于 06-24 15:55,首批内测 build(测试员 06-24 起先装此版)。

## 1.0 (1) — 2026-06-24 / 06-26 — (本地归档,未必上传)
- 06-24 12:08 与 06-26 14:48 各有一个 build 1 的本地归档;06-26 的号回退到 1 即上述「build 号错乱」现场。

---

## 项目演示与文档(非发版内容)
- `DEMO-SHOWCASE.html`(交互式原型)与 `USER-GUIDE.html`(教练+学员教程)**尚未迁入 main**,
  当前可在 `ship/today-entry-video-scroll @ 0ef0169` 取到;待迁 main 后再改回相对链接。
