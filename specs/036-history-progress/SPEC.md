# 036 — 历史 tab 升级为「进度」中心(e1RM 趋势 + 容量/强度图 + 逐次历史)

- **状态**:InReview
- **PR**:TBD
- **来源**:[[student-experience-redesign-wave]](~/Brain/wiki/projects/MeetPR/student-experience-redesign-wave.md) — David 2026-06-14;历史升级为分析中心。**不做** PR 表 / RPE 表(PR 仍在仪表盘"最新 PR"露出)。
- **上游/复用**:
  - `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/TrainingHistoryView.swift` + `TrainingHistoryViewModel`(现:`fetchCycleDays` → weeks/days + `fetchLogs` 范围 logs)
  - `GrowthCurveView` + `GrowthCurveViewModel`(e1RM 趋势,family + 时间窗 picker,在 MyProfile/)
  - `StudentTrainingLogRepository.fetchLogs(in:)`;`StudentSetLog`(weightKg/reps/rpe/completed/loggedAt;**无 catalog exerciseID**)

## 目标

把「历史」tab 从"按周列训练日"升级为**进度中心**,分两段:**进度**(e1RM 趋势 + 容量/强度图)与 **历史**(逐次训练 + 按动作筛选)。纯 iOS、零后端。

落地后学员看到啥:
```
历史/进度        [ 进度 | 历史 ]   ← 顶部分段
〈进度〉
  e1RM 趋势  [深蹲|卧推|硬拉] [1月|3月|6月|全部]   ← 复用成长曲线图
     ╱╲╱  (面积/折线)
  容量 & 强度  [周]
     ▮▮▮▮ 训练容量(kg) + ∙∙∙ 平均 RPE 线
〈历史〉
  第 2 周
   6月17 周三  深蹲日  3/4 动作完成 …       ← 现有列表
   [筛选:全部动作 ▾]                       ← 新:按动作筛选
```

## 范围

### 做什么

#### 1. tab 顶部分段「进度 / 历史」
- `TrainingHistoryView` 顶 `Picker(.segmented)` 切「进度」「历史」(`@State selectedTab`)。导航标题改「进度」(或保留「历史」,二选一对齐 mockup)。

#### 2. 进度 · e1RM 趋势
- **复用** `GrowthCurveView` 的图表段(family squat/bench/deadlift + 时间窗 picker)。最小改动:把 `GrowthCurveView` 的可复用图表抽成可嵌组件,或直接在进度页内嵌 `GrowthCurveView`(去掉其独立 navigationTitle)。勿重写 e1RM 图。
- 需 `e1rm: any E1RMRepository`(`TrainingHistoryView` init 新增;`StudentRootView` 透传,已持有)。

#### 3. 进度 · 容量/强度图(新)
- 从 logs 聚合(纯函数 + 单测):按**周**(对齐 `firstWeekday`)
  - 容量 Volume = Σ(weightKg × reps),仅 `completed == true` 组。
  - 强度 Intensity = 该周 完成组 平均 RPE(无 RPE 的组不计入均值;全无 → 不画强度线那点)。
- 图:容量柱(左轴 kg)+ 平均 RPE 线(右轴 0-10),按周。`Color.MeetPR.*`。
- **V1 = Total(不按主项拆)**:`StudentSetLog` 无 catalog exerciseID,按主项拆容量需 planExerciseID→catalog 映射(仅当前 cycle 投影可得)→ 真·按主项拆归 Wave B(后端给 logs 带 catalog id)。本 spec 只做 Total,**不做** Total/Squat/Bench/Deadlift 筛选 pill。
- 无 logs → 空态「还没有训练记录」。

#### 4. 历史 · 逐次 + 按动作筛选
- 保留现有 weeks/days 列表(`dayCard`)。
- 新增**按动作筛选**:顶部一个动作选择器(取自当前 cycle 所有 `day.exercises[].exercise.name` 去重),选某动作 → 列表只显含该动作的训练日(或高亮该动作组)。"全部动作"为默认。
- 筛选纯前端,基于已加载数据,无新请求。

### 不做什么
- **PR 表 / RPE 表**(David 明确不做)。
- 容量**按主项拆分**(需 catalog id on logs → Wave B)。
- Kg/Lbs 切换、自定义日期范围、MSB 那 9 维强度指标全套(V1 只 e1RM 趋势 + Total 容量/强度)。
- 进展照片/围度/营养等报告(砍)。

## 技术要求
- 模块:`Modules/StudentKit/`。`TrainingHistoryView` init 增 `e1rm: any E1RMRepository`;`StudentRootView` 透传(两个 init)。
- 容量/强度聚合 = `TrainingHistoryViewModel`(或独立 `ProgressMetrics` 纯函数)算好,UI 只读;**单测**覆盖:多周容量求和、平均 RPE(含无 RPE 组排除)、空数据。
- e1RM 图复用,勿重写(抽组件或内嵌 GrowthCurveView)。
- Decimal 求和注意:weightKg 是 `Decimal`,容量用 Decimal 累加再转显示,避免浮点漂移。
- 拆文件控 SwiftLint ≤400 行:`VolumeIntensityChart.swift`、`ProgressMetrics.swift` 独立。func body ≤50、params ≤5、isEmpty、无多尾随闭包。
- swift-format:push 前 docker `swift:6.1-jammy` 验。零后端。

## 验收清单
- [ ] 顶部分段切「进度/历史」
- [ ] 进度页 e1RM 趋势复用成长曲线(family + 时间窗 可切);无重写图表
- [ ] 容量/强度图:按周容量柱 + 平均 RPE 线;仅 completed 组计入;空态不崩
- [ ] 容量/平均RPE 聚合纯函数单测(多周求和 / 排除无RPE组 / 空数据)
- [ ] 历史页保留逐次列表 + 按动作筛选(去重动作名;选中只显含该动作日)
- [ ] `TrainingHistoryView` 增 e1rm 参数;StudentRootView 透传(含 demo init)
- [ ] 不出现 PR 表 / RPE 表 / 按主项容量拆分
- [ ] SwiftLint/swift-format 双过;StudentKit 单测全绿
- [ ] 双 sim 手测:有训练记录的学员 → 进度图有数据、历史可筛选

## 风险 / implementer 关注
1. **容量按主项拆 = Wave B**:logs 无 catalog id,V1 只做 Total,别硬接 e1rm history(那只覆盖出 e1RM 的完成组,不等于总容量)。
2. e1RM 图**复用** GrowthCurve,别重画;注意内嵌时去掉重复 navigationTitle。
3. 这条与 034/035 都改 `StudentRootView`(各自 tab 行)→ 合并按 034→035→036 顺序,冲突可自动解。
4. Decimal 容量累加,显示再转 Double/格式化。

## 修订记录
| 日期 | 版本 | 变更 | 作者 |
|---|---|---|---|
| 2026-06-14 | 0.1 | 起草。进度/历史分段;e1RM 趋势复用成长曲线 + Total 容量/强度图(logs 聚合)+ 逐次历史按动作筛选;PR/RPE 表与按主项拆均不做 | Claude |
