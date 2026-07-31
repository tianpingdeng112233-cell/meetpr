# SPEC 050 — e1RM 单一事实源

- **状态**: release/1.0 已实现 e1RM 组配入选、四周 rolling max、异常隔离、比赛主项解析及端上存量重算；2026-07-28 修订 e1RM RPE 口径、教练校准消费、实测重量 PR 与建议重量基准。
- **逻辑事实源**: 后端已上线的 competition-lift resolver；Swift 实现必须保持同一分支顺序与宽松兜底。

## 1. 入选规则（哪些组配进入 e1RM 估算）

一处定义，全端共用 `E1RMEligibility`：

- `completed == true && failed == false`；
- `reps > 10` 不入；
- 硬拉只信 `reps <= 5`。

RPE 不再设最低入选门（2026-07-28 拍板）。计算统一使用
`effectiveRPE = coach_rpe ?? rpe`，并沿用 `E1RMCalculator` 已落地的分段口径：

- `effectiveRPE == nil` 或 `< 6`：Epley；
- `6...10`：RTS table；
- `> 10`：拒收。

不合规组照常记录训练日志，入选门只管 e1RM；PR 另按 §2 的实测重量口径判定。

### 主项门（动作是否算该学员的比赛主项）

动作必须先通过共享纯函数 `resolveCompetitionFamily(exercise, onboarding)`，才进入上面的组配入选门。后端与 iOS 镜像以下同一裁决，并读取同一 catalog `competition_stance` 字段（`low_bar|high_bar|conventional|sumo|null`）：

1. `main_lift_family == null` → 不算主项。
2. `competition_stance == null` → 仅 `is_competition_lift == true` 的泛项竞技动作算其 `main_lift_family`；普通变式不算。
3. 有 `competition_stance` 时，深蹲对照学员 `squat_stance`，硬拉对照 `deadlift_style`；卧推没有站位分档。
4. 对应 onboarding 未填 → 宽松算该 family；硬拉 `deadlift_style == both` → 传统与相扑都算；其余只在 `competition_stance` 与 onboarding 值相等时算。

因此：竞技深蹲/竞技卧推恒算；低杠/高杠深蹲按个人杆位二选一；传统/相扑硬拉按个人 style 选择（`both` 时全算）；暂停深蹲、RDL、早安式等无 `competition_stance` 且非泛项竞技的变式永不产生 e1RM 点。后端 TypeScript 与 iOS Swift 两个解析器必须逐字保持同一分支顺序和宽松兜底。

## 2. 展示与 PR 口径

- 当前值与曲线统一消费 `E1RMSeries` 的四周 rolling max；Best/Last 只吃合规可信点。
- 教练校准是强覆盖：端上和教练成长曲线的 e1RM 计算均使用 `coach_rpe ?? rpe`；原始学员 RPE 仍保留供展示与审计。
- e1RM 曲线、头条、Best/Last 的展示口径不变；低 RPE（含 @6）可信点正常进入显示序列。
- 建议重量使用独立的可信 best：只有学员 `rpe >= 7`，或 `coach_rpe != nil` 的点可抬升建议基准。不得用这条更严口径过滤显示序列。
- 2026-07-31 修订：同日沿用重量只消费 `completed && !failed` 的上一组；失败组不得成为主项或变式/辅助项的沿用种子。主项无建议且处方未写死重量时，组录入面板必须用一行次要提示说明无合格历史或处方字段不支持；变式/辅助项无动作历史时同样提示，不能静默回落默认重量。
- PR 改为实测重量纪录（2026-07-28 拍板）：按 `student + competition family` 持久化一等重量基线
  `maxWeightKg + setLogID + achievedAt`。每个 `completed == true && failed == false` 且经共享 resolver
  解析为比赛主项的组都独立做严格单调更新，不受是否触发 PR、是否符合 e1RM 入选门或是否生成 point
  影响；本组重量严格大于 `max(该主项 onboarding 登记 1RM, 更新前持久重量基线)` 时才生成 banner /
  推送事件。重量基线不得从 `E1RMHistoryPoint` 扫描推导；e1RM anomaly confidence 也不得否决或抬高它。
- e1RM 外推值超过历史 e1RM 不再单独生成 PR；原有 e1RM 字段继续随事件保存，供 e1RM 头条维持既有展示。
- 次数 PR 展示不变。
- onboarding 1RM 仅作入门基线，不与实测序列混算。

## 3. 端上重算

升级后按学员执行一次新版 `E1RMCompetitionLiftMigration`：按时间顺序从零重放 canonical `set_logs`，每组使用 `coach_rpe ?? rpe` 并通过同一个 `E1RMRecorder` 同时重建 e1RM running best 与独立重量基线，再用一次 repository replacement 原子替换该学员的 points / 重量基线 / PR（旧 PR 清空）。因此 `220kg × 6` 硬拉即使不生成 e1RM point，也必须在重放后留下 220kg 重量基线。此前因 `RPE < 7` 被排除的历史组首次批量入选时必须按时序建立基线，不得把整批标为 low-confidence，也不得触发误记确认。迁移标记按 student ID + 本次口径版本存储；只有替换成功后才写入，确保失败可重试、成功不重复。旧版仅含 `planExerciseID` 的日志通过计划槽位或既有 `setLogId → exerciseId` 关联解析；既有点的 confidence 按 `setLogId` 原样保留，兼容 imported/assumed 点的人工复核结果。完整 catalog 中仍存在的旧动作可以重放；catalog 也无法识别的孤儿点因无法证明通过新主项门而有意丢弃。`ImportedHistoryBackfill` 写入 point 的 `family` 也必须使用 `resolveCompetitionFamily(exercise:onboarding:)`，不得直接落 catalog 原始 `mainLiftFamily`。评估期与正常 tabs 必须位于同一个迁移 gate 下，失败时阻塞并允许重试，不得静默消费旧历史。

2026-07-31 追加追更：一次性迁移完成后，学员端仍需在低频 set-log 刷新点对比 canonical log 的 `coach_rpe` 与本地点 `sourceCoachRPE`。指纹变化时按完整时间序列重放，confidence 必须逐点相对此前可信 running best 重建；既有 PR 事件按实测重量语义原样保留，不得因重放重新发 banner/推送。若新日志落库后追更抢先重放、实时 e1RM 派生随后恢复，实时路径必须按 `setLogID` 幂等补齐该组尚缺的 PR 事件；同一 `setLogID` 最多生成一次事件。相同指纹零写入，失败静默并留待下次刷新重试。
