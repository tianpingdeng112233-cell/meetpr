# 039 — 学员记录「失败/未完成」一组(set outcome)

- **状态**:Ready
- **PR**:TBD(后端 1 PR + iOS 1 PR)
- **来源**:David dogfood 2026-06-15 #2「记录重量的时候,如果我失败了怎么办?」
- **跨仓**:`MeetPR`(iOS)+ `MeetPR-backend`。后端先合并部署,iOS 再合。

## 目标
学员记一组,现在只有"完成 ✓"一种结局。做了 3 次没顶上去(目标 5 次)无法表达。让学员能把一组记成**失败/未完成**(仍填实际做了几次),那组显示区别于"完成"和"没练"的第三种态。

落地后学员看到啥(锻炼 tab 执行卡,每组一行):
```
① 140kg  ⚖   140 × 5 @ 8  ✓     ← 完成(绿)
② 140kg  ⚖   140 × 3 @ 9  ✗     ← 失败/未完成(琥珀),实际只做了 3 次
③ 140kg  ⚖   140 × 5 @ 8  ✎     ← 没练(中性,待登记)
```

## 数据模型(三态语义,**必读**)
一组有两个布尔:`completed`(这组已登记) + 新增 `failed`(登记的这组是失败的尝试)。三态:
| 状态 | 持久化 | UI |
|---|---|---|
| 没练(未登记) | 无 log 行 / `completed=false` | 中性待登记(现有 ✎ pill) |
| 完成 | log 行,`completed=true, failed=false` | 绿 ✓ |
| 失败/未完成 | log 行,`completed=true, failed=true` | 琥珀 ✗ |

- `completed` 保持原义 = "这组已被学员登记/处理"(成功或失败都置 true);`failed` 仅在已登记时有意义,区分两种登记结局。
- 失败的一组**照常记实际 weight/reps/rpe**(学员填真做了几次,如 3)。
- **e1RM / PR 贡献**:失败的一组**不计入** e1RM 历史 / 不触发 PR(避免一次没顶上去的硬撑误报 PR)。`E1RMRepository` 写入点跳过 `failed=true` 的 log。这是默认安全语义,David 可后续调。

## 范围
### 做什么(后端,MeetPR-backend)
- **migration `db/migrations/0017-add-failed-to-set-logs.sql`**:`ALTER TABLE set_logs ADD COLUMN failed BOOLEAN NOT NULL DEFAULT FALSE;`
- `src/db/types.ts` `SetLogsTable`:加 `failed: Generated<boolean>`(line ~331 旁,跟 `completed` 并列)。
- `src/routes/sets.ts` `SetLogBodySchema`(line ~28-45):加 `failed: z.boolean().optional()`(默认 false;旧客户端不传 = 成功语义,向后兼容)。
- `src/handlers/sets-log.ts` `SetLogInput`(line ~7-14)加 `failed: boolean`;`upsertSetLog()` 的 `.values` + onConflict 更新列表(line ~56-63)都带上 `failed`。
- 若有返回 set log 的序列化(响应体含 `completed` 处),同步带 `failed`。

### 做什么(iOS,MeetPR)
- **CoreModels** `StudentSetLog.swift`:加 `public let failed: Bool`(默认参数 `failed: Bool = false` 保持现有构造点兼容);`CodingKeys` 加 `failed`(snake_case `failed`)。
- **Networking** `SetLogDTOs.swift`:`CreateSetLogRequestDTO` + `SetLogDTO`(响应)都加 `failed: Bool`,`CodingKeys` 对齐后端 `failed`。
- **StudentKit** `TodayWorkoutTypes.swift` `TodayWorkoutSetRowDraft`:加 `var failed: Bool`(默认 false)。
- **StudentKit** `TodayWorkoutViewModel.swift` `persist(rowIndex:completed:)`:扩成 `persist(rowIndex:completed:failed:)`(或加 `failed` 参数,默认 false),构造 `StudentSetLog` 时带上 `failed`;`recordSet` 调用不变。**注意**:本文件同期被 spec 040 改动 `startRestTimer`,040 iOS 在本 spec iOS 合并后再做以避冲突。
- **StudentKit** `SetEntrySheet.swift`:登记面板底部由单个「完成本组」改为**两个明确动作**——主按钮「完成本组」(绿,`completed=true, failed=false`)+ 次按钮「未完成 / 失败」(琥珀,`completed=true, failed=true`)。两者都先 commit 实际值再 persist 对应 flag。按钮要够明显(David 反馈过登记入口不够显眼)。
- **StudentKit** `SetRecordRow.swift`:结果 pill 增加第三种 = 失败态(琥珀 ✗:`Color.MeetPR` 加一个 amber/orange soft + 实心,`xmark` icon)。三态视觉互不撞色:完成绿 ✓ / 失败琥珀 ✗ / 没练(现有 brandRed 描边 ✎ pill,若与琥珀视觉太近则把"没练"降为中性灰,保证三态可区分)。
- **DesignSystem**:若没有 amber/orange token,加 `Color.MeetPR.amber` + `amberSoft`(跟现有 green/greenSoft/brandRed/brandRedSoft 同风格)。

### 不做
- 失败原因分类(漏举/力竭/伤痛)——本期只一个 failed 布尔。
- 失败不改动 `ExerciseExecutionView` 的"整动作完成"判定(`rows.allSatisfy(\.completed)`):失败仍 `completed=true`,动作头照常打勾(失败也算"这组处理过了")。
- 教练端对失败的可视化/聪明信号——另议(可喂未来 037 分诊"连续失败"信号)。

## 技术要求
- 后端先合并 + 部署 staging,iOS 再合(iOS DTO 的 `failed` 解析对旧响应缺字段要容错:`decodeIfPresent` 默认 false)。
- 三态判定逻辑(给 draft → 视觉态)抽纯函数 + 单测(完成/失败/没练 三态 + 失败仍 completed)。
- SwiftLint strict(文件≤400/函数体≤50/参数≤5)、`xcrun swift-format --strict` 干净;后端 `npm run lint` + 现有测试。
- 后端 upsert 幂等键不变 `(student_id, plan_exercise_id, set_index)`:同一组从"完成"改判"失败"= 覆盖更新 `failed`。

## 验收
- [ ] 后端:migration 加 `failed` 列;`POST /sets/log` 接受 `failed`(缺省 false 向后兼容);upsert 覆盖 `failed`;`npm test` 绿
- [ ] iOS:登记面板「完成本组」+「未完成/失败」两动作;失败组显示琥珀 ✗,三态可区分
- [ ] 失败组照常存实际 weight/reps;`failed=true` 的 log 不进 e1RM/PR
- [ ] 三态纯函数单测;旧响应缺 `failed` 字段解析为 false 不崩
- [ ] CoachKit ⊥ StudentKit 边界不破;swiftlint/swift-format strict 双绿;`MeetPR-DemoStudent` 模拟器手测三态

## 风险
1. `completed=true, failed=true` 语义("完成但失败")要在代码注释写清,避免后人误读 `completed` 为"成功"。
2. e1RM 跳过 `failed` 需找到写 e1RM 历史的点(`E1RMRepository` 或 log→e1rm 投影),别漏。
3. iOS 与 spec 040 同改 `TodayWorkoutViewModel.swift` → 040 iOS 顺序在本 spec 之后。
