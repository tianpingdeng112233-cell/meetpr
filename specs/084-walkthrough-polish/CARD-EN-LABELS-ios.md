# 任务卡（iOS）：英文界面三处拼接 / 断词问题

开工先读仓内 CONTEXT.md（如存在）、AGENTS.md 与本卡。

- 级别：T1。基线 `release/1.0`，分支 `fix/en-concatenated-labels`。目标 1.0(24) 候选。
- 来源：Opus 2026-10-04 在 iPhone 17 模拟器（MeetPR-DemoStudent，英文界面）补验时发现，均已实屏看到。中文界面不受影响，**中文输出必须逐字不变**。
- **不 commit、不 push**。只在 `docs/CODEX-JOURNAL.md` 末尾追加本卡一节。本仓已公开。

## 要做的

### 1. 训练日标题把「日」译成了 "Sun"

- 现象：Today 页训练日标题显示 "DeadliftSun"、下一练卡片显示 "Squat, Bench pressSun"。
- 原因：`TrainingCalendarLogic.dayName`（`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCalendarLogic.swift`）与 `DashboardTodayPresentation.liftSubtitle`（`.../Features/Dashboard/DashboardTodayPresentation.swift`）都是"主项名拼接 + 后缀"，后缀键 `student.trainingCalendarLogic.copy011` / `student.dashboardTodayPresentation.copy011` 的中文是「日」（"硬拉日"的"日"），英文被误填成星期日的 "Sun"，且拼接时没有空格。
- 要求：改成带占位符的整句格式，与安卓一致（meetpr-rn 的 `student.progression.dayName`：中文 `{0}日`、英文 `{0} day`；两个主项时英文用 " / " 连接，中文直接相连）。英文结果例："Deadlift day"、"Squat / Bench press day"。三个主项与零主项的现有分支不变。两处调用都要改；不要再用"名词 + 后缀"拼字符串。

### 2. 恢复评估标签值与名词之间缺空格

- 现象：Profile 页 Recovery assessment 的三个标签显示 "MediumIntensity"、"HighStress"、"About 2 daysRecovery"（第三个还被截断）。
- 原因：`MyProfileV3Presentation.swift` 约 67–75 行把选项文案与后缀键 `student.myProfileV3Presentation.copy004/005/006`（Intensity / Stress / Recovery）直接相加。
- 要求：同样改成带占位符的格式键，英文结果为 "Medium Intensity"、"High Stress"、"About 2 days Recovery"（与安卓现有输出一致）。三个标签在 iPhone 17 宽度下应完整显示、字号一致；放不下时换行，不得截断成省略号。

### 3. 训练页当前动作标题在大字体下词内断开

- 现象：系统文字大小调到 accessibility-large 时，训练页当前组卡片的动作名 "Competition Squat" 被断成 "Compet / ition / Squat"，因为右侧 "Ask coach" 按钮不让宽。
- 要求：动作名不得在词内断开。标题与按钮一行放不下时，把 "Ask coach" 换到标题下方（或等价做法），默认字号下的现有布局不变。

## 测试 seam（先红后绿）

- StudentKit 单测：`dayName` / `liftSubtitle` 在英文下对一个主项、两个主项输出上述字符串，在中文下输出与现状逐字相同；恢复评估三个标签在英文下带空格、中文不变。本地化测试沿用仓内现有的按语言取文案的 seam（如 `LocalizationCatalogTestSupport`）。
- 第 3 项若没有合适的布局测试 seam，写明并交由 Opus 实屏验收，不要用无关断言充数。

## 验收（Opus 收货，实装方不得自定范围）

1. DemoStudent 英文界面：Today 页显示 "Deadlift day"，下一练卡片显示 "Squat / Bench press day"；Profile 页三个恢复标签带空格、完整可见。
2. 切到中文界面：上述位置与改动前逐字相同。
3. accessibility-large 下训练页动作名不在词内断开；默认字号外观不变。
4. StudentKit 测试全过，swift-format --strict 与 SwiftLint 0 违规。

## Out of Scope

安卓（已是正确输出）、其他文案、Demo 数据。
