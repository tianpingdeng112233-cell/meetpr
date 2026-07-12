# SPEC 050 — e1RM 单一事实源

- **状态**: release/1.0 已实现 e1RM 组配入选、四周 rolling max、异常隔离与 PR 噪声带；本补丁追加按学员 onboarding 解析比赛主项及端上存量重算。
- **逻辑事实源**: 后端已上线的 competition-lift resolver；Swift 实现必须保持同一分支顺序与宽松兜底。

## 1. 入选规则（哪些组配进入 e1RM 估算）

一处定义，全端共用 `E1RMEligibility`：

- `completed == true && failed == false`；
- 有 RPE 且 `RPE < 7` 时不入，RPE 为 nil 仍入；
- `reps > 10` 不入；
- 硬拉只信 `reps <= 5`。

不合规组照常记录训练日志，入选门只管 e1RM/PR。

### 主项门（动作是否算该学员的比赛主项）

动作必须先通过共享纯函数 `resolveCompetitionFamily(exercise, onboarding)`，才进入上面的组配入选门。后端与 iOS 镜像以下同一裁决，并读取同一 catalog `competition_stance` 字段（`low_bar|high_bar|conventional|sumo|null`）：

1. `main_lift_family == null` → 不算主项。
2. `competition_stance == null` → 仅 `is_competition_lift == true` 的泛项竞技动作算其 `main_lift_family`；普通变式不算。
3. 有 `competition_stance` 时，深蹲对照学员 `squat_stance`，硬拉对照 `deadlift_style`；卧推没有站位分档。
4. 对应 onboarding 未填 → 宽松算该 family；硬拉 `deadlift_style == both` → 传统与相扑都算；其余只在 `competition_stance` 与 onboarding 值相等时算。

因此：竞技深蹲/竞技卧推恒算；低杠/高杠深蹲按个人杆位二选一；传统/相扑硬拉按个人 style 选择（`both` 时全算）；暂停深蹲、RDL、早安式等无 `competition_stance` 且非泛项竞技的变式永不产生 e1RM 点。后端 TypeScript 与 iOS Swift 两个解析器必须逐字保持同一分支顺序和宽松兜底。

## 2. 展示与 PR 口径

- 当前值与曲线统一消费 `E1RMSeries` 的四周 rolling max；Best/Last 只吃合规可信点。
- `E1RMRecorder` 以插入前可信 best 为基线，沿用 release/1.0 的 `E1RMPolicy.anomalyVerdict` 与 PR 噪声带。
- onboarding 1RM 仅作入门基线，不与实测序列混算。

## 3. 端上重算

升级后按学员执行一次 `E1RMCompetitionLiftMigration`：按时间顺序重放 canonical `set_logs`，每组仍走 release/1.0 的 `E1RMRecorder`，再全量替换该学员历史并清空旧 PR。迁移标记按 student ID 存储；只有替换成功后才写入，确保失败可重试、成功不重复。旧版仅含 `planExerciseID` 的日志通过计划槽位或既有 `setLogId → exerciseId` 关联解析。
