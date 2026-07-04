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
