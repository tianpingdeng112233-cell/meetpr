# Spec 092 · iOS 卡 B(教练端):训练日详情显示学员自加记录、跳练按归属显示

开工先读仓内 `CONTEXT.md`、`AGENTS.md`、`specs/085-090-android-parity/README.md`(共同约定,全部适用)、`specs/092-flexible-day-self-added/SPEC.md` 全文(重点 §5、文末「屏幕稿」第 5 张与文案表)。

- 级别 / 节奏:T2 / P1。工作树 `/Users/david/Projects/apps/MeetPR-wt-092b`,分支 `feat/092-ios-coach`(基于 `origin/release/1.0`)。**先 `cd` 进这棵树再启动**,启动后试写并删除一个临时文件确认可写;不可写立刻带原始报错返回。本树里还没有 `specs/092-flexible-day-self-added/`,请从卡 A 的树只读取:`/Users/david/Projects/apps/MeetPR-wt-092a/specs/092-flexible-day-self-added/`(SPEC.md 与本卡)。
- **不 commit、不 push、不开 PR**;交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节(标题写明「iOS 卡 B」)。
- 模拟器只用 **iPhone 17 Pro `8F164D5D-A450-44FD-BDBF-BB351572CF6E`**(卡 A 用别的机器,不要碰其他模拟器);交付前 `xcrun simctl shutdown` 这台。
- 本卡只动教练端:`Modules/CoachKit`、`Modules/Networking`(只做加法,教练读取用到的部分)、教练 Demo 与它们的测试。`Modules/StudentKit` 归卡 A(另一棵树同时在改),不要碰;两张卡都可能动 `Modules/Networking` 的 `SetLogDTOs.swift`,只做加法、改动尽量小。

## 安卓实现是参照物(只读)

安卓教练端已实装、返修两轮后收货,规则以它为准:

```
git -C ../meetpr-rn-wt-092 show 02213e4:src/domain/coach/log-ownership.ts
git -C ../meetpr-rn-wt-092 show 02213e4:src/domain/coach/detail-week.ts
git -C ../meetpr-rn-wt-092 show 02213e4:src/domain/coach/triage.ts
git -C ../meetpr-rn-wt-092 show 02213e4:src/domain/coach/week-overview.ts
git -C ../meetpr-rn-wt-092 show 02213e4:src/features/coach/student-detail/CoachDayDetailView.tsx
```

## 目标

1. **训练日详情**(屏幕稿第 5 张):计划动作卡里处方组的只读行之后,若有额外组(组序号 ≥ 处方组数),先一行小灰字「学员自加」(英文 `Added by student`),再列额外组的只读行——与其他行同一样式,行上不加标签。「已记录 x / y 组」的 x 只数处方内的组。计划动作之后,该训练日每个自加动作一张卡:标题动作名(不带标签),副标题一行小灰字「学员自加 · 不在计划里 · 记录了 N 组」。页头在日期下显示 `W2D4 · 已完成 / 未开始`(与安卓一致)。
2. **读取**:教练读取学员记录改要 `scope=all`;`SetLogDTO` 加可选 `planDayID`(`decodeIfPresent`,老后端没有时为 nil,界面与今天一致、不报错)。自加动作行按 `plan_day_id` 归到训练日。
3. **「这一天练了没有」的统一规则**(安卓返修两轮后的定稿,iOS 照做,放在一个纯函数里,详情页、学员概览、名单周表、「没练」提醒共用):
   - 一个训练日算练了 = **已结算(`completed_at` 非空)或 有属于它的已完成记录**。练了但没结算的老数据照旧算练了。
   - 判断一条已完成记录是否属于训练日 D:记录没有归属(没有 `plan_exercise_id` 也没有 `plan_day_id`,或其计划动作不在当前计划里)→ 按 `logged_at` 当地日期与 D 的日期同一天才算;记录的归属日与 D **在同一计划周**(`week_number` 相同)→ 归属日就是 D 才算;归属日与 D **不在同一计划周** → 按日期,同第一种(保持改动前的行为,否则进度落后但在训练的学员会被误标「没练」)。
   - 周视图里记录的落位用同一条规则。「最近活动」取本次读取到的全部记录。
4. 核对教练端其余凡是假设「游标之前的天都已完成」或按日期判断完成的地方,有错的按上面的规则改,没错的在 JOURNAL 写一句核对结论。不加任何「跳练」标记、不发通知。

## iOS 落点(以现场为准)

`Modules/CoachKit/Sources/CoachKit/Features/StudentDetail/Execution/CoachDayDetailView.swift`、`StudentExecutionView.swift`、`StudentDetail/Overview/StudentOverviewSection.swift`、`StudentDetailViewModel.swift`,名单周表与「没练」提醒所在的 roster / triage 代码;`Modules/Networking` 的教练读取。教练 Demo 数据要能演示:一个有额外组的训练日、一个有自加动作的训练日、本周先结算 D4 后 D2 未练、一个进度落后但在训练的学员。

## 约束

- 只读展示,不加编辑 / 删除入口;待看视频、聊天组卡片、反馈流程不改。
- 不丢用户数据、不让已上线功能失效;既有测试断言不删不改(确需改的逐条在 JOURNAL 写原因;本卡自己新增的测试可直接改)。
- 不加依赖;守模块边界脚本;新 model `Sendable`;`swift-format lint --strict` 与 `swiftlint` 严格模式 0 违规。
- 文案取安卓目录 `02213e4:src/i18n/catalog/RnExtras.json` 的 `coach.execution.addedByStudent` 与 `coach.execution.studentAddedSets %lld`,中英逐字;进 `Localizable.xcstrings`。
- 工程细节自己定并在 JOURNAL 记一句;只有确属产品取舍才停。

## 测试 seam(先红后绿)

1. 归属 / 完成规则纯函数:练了没结算算练了;已结算无记录算练了;同周 D4 记录落在 D2 日期、D4 已结算 → D2 未练、D4 练了;跨周(日历 W4 练 W2 的天)→ W4 那几天按日期算练了、不触发「没练」提醒;无归属旧形态与改动前一致。
2. 训练日详情归集:处方组 / 额外组划分与排序、x / y 只数处方组、自加动作按 `plan_day_id` 分到训练日并按动作分组。
3. `Networking`:DTO 缺 `plan_day_id` 仍解码;教练读取带 `scope=all`。
4. 渲染层 presentation:有额外组时出现「学员自加」小字且行上无标签;有自加动作时出现卡与副标题;两者都没有时与改动前一致。

## 验收

`SPEC.md`「验收清单」教练端第 12、13 项;屏幕按共同约定(iPhone 17 Pro 本卡指定机 + `accessibility-large`,深色抽一屏),用教练 Demo 截图放 `specs/092-flexible-day-self-added/evidence/`(在本树里新建该目录)。工程闸:`swift test --package-path Modules/CoachKit`、`Modules/Networking` 及其他动到的包全量通过;`swift-format` 与 `swiftlint` 严格模式 0 违规;`MeetPR-DemoCoach`(或仓内教练 Demo scheme)能在指定模拟器构建运行。
