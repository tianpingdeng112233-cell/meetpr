# 黑金 v3 空状态交付回执

实现依据（两份内容一致，仅主题 token 不同）：

- `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
- `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 浅色.html`

实装沿用 StudentKit 既有页面骨架和 `DesignSystem` 自适应颜色 token；参考稿中的金色虚线框仅作槽位标注，没有画进产品界面。

## 场景与数据条件

| 场景 | 参考出处 | 实装槽位 | 真实数据条件与动态字段 |
|---|---|---|---|
| 今日 · 教练反馈未到 | 01「训练已提交 · 教练反馈未到」 | 今日页反馈卡 | 仅设备日历的「今天」可显示。当天每个 `(planExerciseID, setIndex)` 处方组均有唯一完成身份，且既没有同日点评、也没有关联当天任一 `planExerciseID` 的动作级点评时显示。重复日志不能凑齐完成数。「N 组」取去重后的完成身份；提交时间取最后一组 `loggedAt`；「N 小时」取历史带视频反馈从视频 `loggedAt` 到 `postedAt` 的中位响应时长。没有可计算历史时改为「下次训练前」，不伪造数字。 |
| 今日 · 下周计划未发布 | 04「下周计划未发布」 | CTA 槽位、本周小结、比赛瓦片 | 按 `PlanCalendarDayIdentity` 的 date-only 规则判断当前计划 `endDate` 已到今天，且周期里没有未来计划日时显示；UTC 日期不会在负偏移设备时区提前一天触发。WNN 由当前周号递增；完成天数、周总量来自本周计划日和完成日志；新 PR 来自未确认 PR 事件；绑定教练名动态读取。「给教练留言」打开现有聊天。未设置比赛时显示「未安排 / 填写比赛」，无金色发光。 |
| 今日 · 休息日 | 06「休息日」 | 原休息日卡 | 当天计划日没有动作时显示。下一训练日、周号、主项、动作数、处方组数均从周期计划计算；预计分钟按每组处方休息时间（缺省时采用现有 180 秒休息假设）加 60 秒执行时间汇总并按 5 分钟取整。月亮图标按参考补齐；次日写「明天见」，更晚则与预览标题一致写真实月日。 |
| 成长 · 曲线未成形 | 02「有训练记录但不足 3 次」 | 对应动作的 e1RM 图表区 | 同一动作族的 eligible e1RM 记录为 1…2 次时显示；深蹲、卧推、硬拉分别计数、互不解锁。阈值复用 `GrowthHistoryStats.trendUnlockThreshold`；已记录次数、剩余次数和动作名动态生成。该动作族恰好第 3 次记录后恢复正式曲线。 |
| 成长 · 零训练 | 03「完全没有训练」 | e1RM 曲线卡、历史入口、容量/强度区 | 完成训练日数为 0 时显示「未设定」「第一个数据点，等你练出来」和「第一次训练后解锁」；「去看今天的安排」切回今日 tab。训练少于 2 次时整张容量/强度区隐藏。 |
| 训练 · 计划未生效 | 07「第一周计划还没生效」 | 训练页内容区 | `fetchCurrentPlan` 返回 `nil` 时进入独立 `.noPlan` 状态；头部和日历保持原样。绑定教练名动态写入说明，「看看教练发来的消息」打开现有聊天。 |
| 消息 · 空对话 | 05「与教练的第一条消息」 | 消息滚动区 | `ConversationViewModel.didFinishInitialLoad` 只在首次成功抓取后置位；成功后服务端历史、待发送消息和更多历史都为空时才显示。首次加载失败进入带重试的错误态，不冒充空对话。头部和输入条保持原样；教练名来自真实绑定上下文，状态显示「今晚在线」。 |

所有新状态都避免「暂无数据」「空空如也」式文案，并分别说明为什么为空、何时会有内容、现在可执行的下一步。新图表状态没有循环动效；沿用的入场/切换动效继续受既有 `accessibilityReduceMotion` 分支控制。

## DemoStudent 空态开关

仅 `DEMO_MODE` 编译条件内解析 launch argument，不进入非 Demo 构建：

```text
-student-empty-state feedback-pending
-student-empty-state next-plan-pending
-student-empty-state rest-day
-student-empty-state growth-forming
-student-empty-state growth-zero
-student-empty-state plan-unavailable
-student-empty-state empty-conversation
```

在 Xcode 选择 `MeetPR-DemoStudent` scheme，把其中一组参数加入 Run Arguments 即可。每次只启用一个值；不传参数时保持原 DemoStudent 数据。

这些开关不直接覆写 View 状态，而是切换 `InMemoryStudentPlanRepository`、训练日志、反馈、e1RM、档案和聊天的 Demo seed，让七个界面继续通过与正式构建相同的 repository / view-model 条件进入空态。

## 定向返修第 1 轮

- **B1 撤回并更正**：撤回上一版「全局训练次数为 1…2」的表述。曲线解锁现在只看对应动作族的 eligible e1RM 记录数；已补恰好 3 次边界与深蹲/卧推动作族隔离测试。
- **B2**：待反馈使用 `(planExerciseID, setIndex)` 完整集合判定；动作级 `CoachFeedback.planExerciseID` 可直接压掉待反馈；历史日期永不触发。
- **B3 / B6**：聊天增加首次成功加载闸与错误态；反馈收件箱仅 `.loaded([])` 可称为空，`idle/loading/error` 不再驱动任何空态。删除了没有参考出处的 `DashboardFirstFeedbackCard` 第八态。
- **B4**：下周计划等待态改用 `PlanCalendarDayIdentity`，覆盖 UTC date-only 在负偏移时区尚未到边界的反例。
- **B5**：休息卡说明与下一训练预览共用同一日期标签：次日「明天见」，否则显示月日。
- **B7**：零训练补回 64pt 幽灵曲线；休息日补回月亮；计划未生效补回三条虚线动作骨架并移除自创左边线。

### 返修自检

- `swift-format lint --strict`：当前全部 Swift 改动通过。
- `swiftlint lint --strict`：当前全部 Swift 改动 0 violation。
- SPM：9 个 package 共 1340 项测试通过，0 failed。
- simulator build：`MeetPR`（Debug）、`MeetPR-Demo`（Demo）、`MeetPR-DemoStudent`（DemoStudent）全部通过，0 warning。
- DemoStudent 逐态目检：7 个 launch argument 均在浅色、深色各启动并截图核对；反馈待到、下周计划、休息日、曲线未成形、零训练、计划未生效、空对话共 14 个组合通过。目检中发现并修正零训练 CTA 的固定深色 token，复核后浅色为深底白字、深色为金底深字。


## 定向返修第 3 轮(Claude 接管)

- scene 02 伪造刻度根除:轴标签抽成纯函数 `GrowthFormingAxis.labelValues(anchorKg:)`,
  无可信锚点(仅低置信记录)时返回 nil、不画数值刻度;补 187.5→200/190/180 与
  nil→nil 边界测试。
- 今日休息态不再泄漏:`DashboardRestDayCard` 仅今日渲染月亮恢复卡,历史/未来
  休息日回到原紧凑「休息日 · 无训练安排」卡(scene 06 槽位=今日专属)。
- 图标逐字:等待卡改纯日历(+ 徽章独立)、休息日预告改杠铃、比赛瓦片补前置 +。
- 移除 `hasFeedback` 的无效 `selectedCalendar` 参数。

## 定向返修第 4 轮(Claude 接管)

- 仅低置信记录时日期标签用真实 `computedAt`(latestRecordDate 回退
  rawEligiblePoints 最大值),不再显示 `—`。
- 进度行按参考拆 styled runs:基文 12px tertiary,`1/3` 与剩余次数 Mono+textPrimary;
  轴刻度上下 tertiary、中间 muted。
- PR 数值与比赛 CTA 用 gold500(参考浅色 #D97706);比赛 CTA 改独立 11pt 加号图标+文案。
