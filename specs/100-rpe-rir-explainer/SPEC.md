# 100 — 学员端 RPE / RIR 说明卡片

- **状态**: Ready（2026-11-02 /grill 共识「确认」；屏幕稿待「定稿」）
- **来源**: 用户反馈 #6「RPE/RIR 需要向小白解释」（2026-11-02 反馈 PDF）。
- **范围**: 学员端，安卓 RN（本仓 `main`）与 iOS（`MeetPR` 仓 `release/1.0`）同批派卡、同批验收；iOS 仓同目录镜像本文件。
- **级别 / 节奏**: T1 / P1。纯客户端，无后端、无数据模型改动。
- **术语口径**: Zourdos et al., 2016, JSCR 30(1):267–275, Table 1（RIR-based RPE 量表）。App 内不标出处。

## 现状（已核实，RN `origin/main` 22eaa42 / iOS `origin/release/1.0` e22302fe）

- 记录弹窗（RN `SetEntrySheet.tsx` / iOS `SetEntrySheet.swift`）：RPE 刻度 5–10、0.5 一档，每档下方小字来自 `student.setEntryRpe.copy001…011`（RN `rirCopy` in `policy.ts`；iOS `SetEntryRPE.descriptions`）。辅助项可切到 RIR，RIR 是 0–9 步进器，没有小字。
- 辅助项记录卡（RN `AccessoryLogCard.tsx` / iOS `AccessoryLogCard.swift`）表头 RPE/RIR 切换，没有解释。
- 补记（RN `QuickLogSheet.tsx` / iOS `QuickLogSheet.swift`）表头 RPE 列（辅助项可切 RIR），没有解释。
- 全 app 唯一现成解释是入门问卷 Step3 的一句话（`student.step3StrengthSection.copy010`），本 spec 不动它。

## 变更

### 1. 「?」入口
在下面三处的 RPE / RIR 字样旁加一个「?」图标按钮（命中区 ≥ 44pt/dp，不挤占现有切换按钮的命中区）：

| 位置 | 显示 RPE 时 | 显示 RIR 时 |
|---|---|---|
| 记录弹窗的强度区标题 | 打开 RPE 卡片 | 打开 RIR 卡片 |
| 辅助项记录卡表头 | 打开 RPE 卡片 | 打开 RIR 卡片 |
| 补记表头强度列 | 打开 RPE 卡片 | 打开 RIR 卡片 |

主项没有 RIR 模式，只会出现 RPE 卡片。新老用户一样：不自动弹出，不做「首次」引导，不存任何已读状态。

### 2. 说明卡片
- 两张卡片，**RPE 一张、RIR 一张**，各讲各的，互不提及对方。
- 形态：点「?」浮出一张卡片，点卡片外或关闭按钮收起。具体样式（居中浮起 / 贴底）、字号、间距以「定稿」屏幕稿为准。
- 不跳页、不打断当前输入：收起后刚才填的值原样保留。
- 支持深浅色两套主题、动态字体放大后不截断。

**RPE 卡片**

| | 简中 | English |
|---|---|---|
| 标题 | RPE · 这组有多吃力 | RPE · How hard was that set |
| 副标题 | 满分 10，越高越吃力 | Out of 10. Higher means harder. |
| 10 | 做不动了 | Couldn't do another rep |
| 9.5 | 做不了下一次，但能再加点重 | No more reps, but could add a little weight |
| 9 | 还剩 1 次 | 1 rep left |
| 8.5 | 还剩 1–2 次 | 1–2 reps left |
| 8 | 还剩 2 次 | 2 reps left |
| 7.5 | 还剩 2–3 次 | 2–3 reps left |
| 7 | 还剩 3 次 | 3 reps left |
| 5–6 | 还剩 4–6 次 | 4–6 reps left |
| 结尾 | 估不准没关系，选最接近的就行 | Not sure? Pick the closest one. |

**RIR 卡片**

| | 简中 | English |
|---|---|---|
| 标题 | RIR · 还能再做几次 | RIR · Reps left in the tank |
| 正文 | 这组做完，同样的重量还能再做几次，就填几 | After the set, how many more reps could you do with the same weight? Enter that number. |
| 例子 | 例：做了 6 次，觉得最多能做 8 次 → 填 2 | Example: you did 6 and could have done 8 → enter 2 |
| 结尾 | 一次也做不动了就填 0 | Couldn't do another rep? Enter 0. |

繁体中文走现有繁体生成流程，不手写。

### 3. RPE 刻度小字改口径（与 RPE 卡片逐档一致）

| RPE | 现在 | 改为（简中 / English） |
|---|---|---|
| 5、5.5、6 | 还能多做 5 次 / 4-5 次 / 4 次 | 还剩 4–6 次 / 4–6 reps left |
| 6.5 | 还能多做 3-4 次 | 还剩 3–4 次 / 3–4 reps left |
| 7 | 还能多做 3 次 | 还剩 3 次 / 3 reps left |
| 7.5 | 还能多做 2-3 次 | 还剩 2–3 次 / 2–3 reps left |
| 8 | 还能多做 2 次 | 还剩 2 次 / 2 reps left |
| 8.5 | 还能多做 1-2 次 | 还剩 1–2 次 / 1–2 reps left |
| 9 | 还能多做 1 次 | 还剩 1 次 / 1 rep left |
| 9.5 | 或许还能多做 1 次 | 做不了下一次，但能再加点重 / No more reps, but could add a little weight |
| 10 | 力竭，无保留 | 做不动了 / Couldn't do another rep |

6.5 原表没有，取 7 与 5–6 之间的插值，只出现在刻度上，不进卡片。刻度条上金色气泡里的小字空间有限，长文案（9.5）允许缩字号，不允许截断。

### 4. RIR 步进器小字
记录弹窗 RIR 模式下，步进器下方加一行小字（位置对齐 RPE 刻度小字）：RIR 0 →「做不动了 / Couldn't do another rep」；RIR 1–9 →「还剩 N 次 / N rep(s) left」（英文单复数）。不给 RPE 换算。未填时不显示。

## 验收清单

1. 两端：主项记录弹窗 RPE 旁「?」→ RPE 卡片，文案与上表逐字一致；收起后已选 RPE 不变。
2. 两端：辅助项记录弹窗切到 RIR →「?」打开 RIR 卡片；切回 RPE →「?」打开 RPE 卡片。
3. 两端：辅助项记录卡表头、补记表头的「?」按当前显示的 RPE/RIR 打开对应卡片；表头原有 RPE/RIR 切换照常可点。
4. 两端：RPE 刻度从 5 拖到 10，每档小字与第 3 节表格一致（含 9.5 长文案不截断）。
5. 两端：RIR 步进器 0、1、2、9 的小字正确；未填时无小字。
6. 两端：简中、英文、繁体三种语言各看一遍两张卡片；深色、浅色各看一遍；最大动态字体下不截断。
7. 带历史的老用户升级后：已有的 RPE/RIR 记录、回顾页、完成页数值显示不变（本 spec 不改任何存储与展示数值）。
8. 两端单测全绿；iOS 在 `iPhone 17e` 模拟器、安卓在模拟器亲验第 1–6 条并截图。

## 测试 seam

- RN：`src/features/training/__tests__/training-policy.test.ts` 现有 `rirCopy` 逐档表测试改成新口径（先红后绿）；新增一个纯函数（如 `effortExplainerFor(kind)` 返回卡片文案 key 列表）及其测试，「?」入口在三处共用它；RIR 小字纯函数 `rirStepperCopy(n)` 测 0/1/2/9/空。
- iOS：`SetEntryRPEScaleTests.swift` 补 `SetEntryRPE.descriptions` 新口径逐档断言；同样的卡片内容与 RIR 小字纯函数各一组测试。
- 卡片本体是展示层，不写 UI 快照测试，靠第 8 条模拟器亲验。

## Out of Scope

- 教练端（iOS 教练模式、plan-web 网页）任何 RPE 说明。
- 今日卡处方「@8」「目标 RPE」的解释入口（今日卡另有 #7/#8 修复卡在改）。
- 回顾页、完成页、总结页、成长曲线、容量强度图、休息设置里的 RPE 字样。
- 首次自动弹出 / 新手引导 / 已读状态。
- 入门问卷 Step3 那句解释的去留（归 onboarding 那条线）。
- 卡片里标出处、写证据句（如「多数人会低估余力」）、讲 RPE 与 RIR 的换算关系。
- 修改 RPE 取值范围、步进、RIR 取值范围、任何存储字段。
