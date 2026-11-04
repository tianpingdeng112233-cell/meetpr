# 卡 · spec 090 修订：辅助项在 hero 时下方不重复（iOS）

先读仓根 `CONTEXT.md`（有则读）与 `CLAUDE.md`，再读 `specs/090-training-flow/SPEC.md` 的 §1「分区」下新加的「辅助项在 hero 时下方不重复」一条与验收第 11 条（2026-11-04 修订，docs PR #397）。

- 级别：T1 / P1。分支 `fix/090-accessory-hero-dedupe`，工作树 `MeetPR-wt-090b`（基于 `origin/release/1.0`，不要用 main）。不 commit、不 push。
- 模拟器：只用 `iPhone 17e`，不新建、不换机型。
- 来源：David 安卓真机截图——辅助项 hero 已是整张可编辑组表，下方列表又列了一遍同一动作的组表卡。iOS 同规则：`TrainingFlowPresentation.belowHero` 把 `partition.active` 也放进了下方。两端同批改、同批验收。

## 目标

训练页记录态、可编辑、当天训练：当 hero 卡渲染的是 `AccessoryWorkoutHero`（`TodayWorkoutHero` 里 `presentation.accessoryExercise(isEditable:)` 命中那一支）时，hero 下方 `TodayWorkoutExerciseList` 不再包含这个动作，从下一个没做完的动作开始。主项 / 变式的 hero 下方保持原样，仍以它自己的 `ExerciseCard` 开头。

判定必须与 hero 实际选形态的那段逻辑同源（同一个函数或同一个谓词），不要另写一份"是不是辅助项"的判断，避免两边漂移。

## 文件范围

- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingFlowPresentation.swift`（`belowHero`）
- 如需要：`TodayWorkoutPresentation.swift`（只为复用 hero 形态谓词）
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TrainingFlowTests.swift`（加用例）
- 本卡 JOURNAL `docs/journal/2026-11-04-090-accessory-hero-dedupe-ios.md`

## 约束

- 只改"下方是否带当前 hero 动作"这一件事。上收、退回、跳着做、滚动定位（`TrainingFlowSnapshot`、scroll target）、吸底按钮、学员自加动作区一律不动。
- `flow == nil` 的路径（只读预览、已结算日、未开始汇总）不变。

## 验收标准（Opus 逐项收货）

1. 当前 hero 是辅助项：页面上这个动作的名字与组表只出现一次（在 hero 里）；hero 下方第一张卡是下一个没做完的动作。
2. 当前 hero 是主项 / 变式：下方第一张仍是它自己的组表卡（与修订前一致）。
3. 辅助项逐组打 ✓ 到最后一组、或「全部按计划完成」：它上收；下一个动作顶进 hero，若也是辅助项，下方同样不带它。
4. 对已上收的辅助项取消一组，它重新成为 hero：下方不出现它的重复卡。
5. 全部做完 / 部分做完时完成按钮位置不变。
6. 带历史的老用户（当天已记过若干组）升级后进训练页，第一屏按上述规则排好。
7. StudentKit 测试全绿、App 在 `iPhone 17e` 构建通过；截图为证：辅助项 hero 页、主项 hero 页、辅助项上收后的下一屏各一张，存 `specs/090-training-flow/evidence/dedupe-20261104/`。

## 测试 seam

复用 `TrainingFlowTests.swift`（`belowHero` 已有断言，最高层且纯数据）。先红后绿：
- 新用例：active 为辅助项（hero 走 accessory 形态）时，`belowHero` 不含它（先红）。
- 对照：active 为主项时，`belowHero` 首项是它（现有第 79 行那类断言，防回归）。
