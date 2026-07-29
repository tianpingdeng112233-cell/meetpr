# Set-ref Bridge Phase 1 Receipt

日期：2026-07-29
分支：`feat/black-gold-ui-v3`
合入基线：`origin/release/1.0` @ `747de7e`

## 结果

黑金 v3 已接入发版线 spec 029 的组引用分享、卡片渲染、视频播放入口与「问教练」
流程。此阶段只保证功能完整、编译运行与测试通过；组引用相关 UI 沿用 ChatUI 现成
样式，未做黑金化。

由于当前工作区的 Git metadata 位于只读路径，直接执行
`git merge origin/release/1.0` 在写入 `ORIG_HEAD` 时被沙箱拒绝。为保持“不
commit/push”的约束，在临时 clone 中对相同的两端 commit 完成真实 merge 和冲突
处理，再把最终未提交 tree patch 应用到本工作区。当前工作区因此没有 `MERGE_HEAD`，
但文件内容是该 merge 结果加本卡最小接线，且未 commit、未 push。

## 8 个 merge conflict 的处理记录

1. `ChatTestSupport.swift`：以发版线实现为底，叠回 v3 Result 页队列与
   `enqueuePageFailure`。
2. `SetReadOnlyCell.swift`：完整采用发版线版本，保留 spec 029 C0 编号修复。
3. `StudentNotificationComponents.swift`：保留 v3 的 `fullScreenCover` 和黑金聊天
   视图，只接入并透传 `SetRefSharingContext`。
4. `SetRecordRow.swift`：保持 v3 删除状态；今日页继续使用 `SetRow`，编号由共享
   `SetIndexDisplay` / `SetDisplayNumber` 消费。
5. `TodayWorkoutView.swift`：保留 v3 页面结构，搬入 set-ref sharing 依赖、入口
   predicate、picker route、预选与聊天路由。
6. `DayDetailView.swift`：保留 v3 UI 结构，接入共享组序号显示语义。
7. `HistoryEntriesView.swift`：保留 v3 UI 结构，接入共享组序号显示语义。
8. `StudentStrings.swift`：两侧字符串取并集。

按既定方案同时完成的非冲突对齐：

- `CoachDayDetailView` 完整采用发版线版本。
- `W1ContractTests` 的断言改为
  `SetReadOnlyCell.setLabel(forZeroBasedIndex:)`。
- `StudentChatTimeline` 的组序号改为共享 `SetIndexDisplay`，补足自动 merge 未带入的
  C0 语义。

## 最小功能接线

- `StudentBlackGoldChatView` 直接复用 ChatUI 的 `ChatSetCardView` 与
  `ChatSetCardPresentation`；只提升必要的可见性，没有改动卡片行为或视觉。
- 有效 set-ref 在己方和对方消息侧都走同一卡片；坏载荷或 canonical body 不匹配时
  继续按 lossy 语义降级为纯文本 body。
- 黑金聊天复用既有 `ChatSendCoordinator`、`SetRefSharePicker` 和
  `SetRefSharingContext`，没有新增发送链路。
- Demo 使用的 `InMemoryChatRepository` 补充结构化 `sendSetRef` 保存，避免本地
  回显丢失 `setRef` 后退化成纯文本；新增测试覆盖 payload 与 client ID 幂等。
- 今日页「问教练」入口与选择器共用同一 predicate：当前可编辑训练日存在非
  assumed 的已完成组，并且存在活跃绑定与 sharing context。最近完成组默认预选；
  确认后冻结快照、打开黑金聊天并由既有 coordinator 发送。
- `SetNumberSurfaceTests` 改为验证 v3 等价面：
  `todayWorkout.set.<id>.number` 与 `todayWorkout.activeSet.position`。

## 红线核对

- Auth、Bind、Evaluation：相对本分支合并前零 diff。
- CoachKit：本次没有自定义修改；发版线变更文件逐文件与
  `origin/release/1.0` 一致，`CoachDayDetailView` 也完整采用发版线版本。
- CoreModels、Networking：spec 029 相关文件逐文件与
  `origin/release/1.0` 一致，没有改其实现。
- 未新增依赖，未改 build 号、签名、tag 或 pbxproj 结构。

## 自检

- `swiftlint lint --strict --quiet --config .swiftlint.yml`：通过。
- `swift-format lint --configuration .swift-format --recursive --strict`：通过。
- 全量 SPM：9 个 package、1,439 个 Swift Testing tests 全绿。
- 三配置模拟器 build/run，诊断均为 0 warning / 0 error：
  - `MeetPR` / `Debug`
  - `MeetPR-Demo` / `Demo`
  - `MeetPR-DemoStudent` / `DemoStudent`
- iPhone 17 模拟器实跑：
  1. 未完成任何组时不显示「问教练」。
  2. 完成一条非 assumed 训练组后入口出现。
  3. 选择器默认勾选最新完成组。
  4. 确认后进入黑金聊天，发送硬拉第 1 组 `175kg × 3 @RPE 8.5`。
  5. 学员己方消息显示为复用的红色 `ChatSetCardView`，不是纯文本。

## 留给下一张黑金化卡的视觉不一致

- `ChatSetCardView` 仍使用 ChatUI 的红色/中性 surface、字体、圆角、边框和宽度规则，
  与黑金聊天的墨色/金色体系不一致。
- `SetRefSharePicker` 的候选页、确认页仍是 ChatUI 现成样式。
- staged set-ref composer、字符计数、错误态和「分享今日训练」入口只做了最小接线，
  尚未按黑金稿统一间距与控件形态。
- 今日页「问教练」按钮是临时的 v3 兼容轮廓样式与位置，未做最终黑金视觉。
- 带视频的组引用继续使用共享 `FeedbackVideoPlayerView` 播放 chrome，未做黑金化。
