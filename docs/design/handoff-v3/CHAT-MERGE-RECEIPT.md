# 黑金 v3 追加卡回执：通知并入聊天

## 唯一视觉标准

- 样机：`docs/design/handoff-v3/MeetPR 学员端.dc.html`
- helmet token：第 10–44 行
- `showChat` overlay：第 630–650 行
- 逻辑语义：`openChatScreen` / `markRead` / `checkVisible`，第 865–867 行

## 结构 → 样机行号对照

| 实装结构 | 样机行号 | 对照结果 |
|---|---:|---|
| 全屏 `bg-base` overlay | 630–632 | `StudentBlackGoldChatView` 使用 `Color.MeetPR.bgBase`；iOS 由 `fullScreenCover` 承载 |
| 返回圆钮、教练名、`● 在线` | 633–636 | 40pt `surface-card` 圆钮；16pt bold 教练名；11pt `success` 在线状态；底部 `border-hairline` |
| `chatScroll` | 637–639 | 18pt content inset、10pt item gap、隐藏 indicator、默认底部锚点 |
| 教练文本气泡 | 640 | 左对齐、`surface-elevated`、`16/16/16/5` 圆角、`11×14` 内边距 |
| 我的文本气泡 | 641 | 右对齐、`text-primary` 底、`bg-base` 字、`16/16/5/16` 圆角、medium 字重 |
| 新计划卡 | 642 | 40pt 日历 tile、金色 Mono「新计划」章、标题/副题/右箭头；点击关闭聊天并进入训练 tab |
| 教练反馈卡 | 643 | 3pt `gold-500` 左条、`5/16/16/5` 圆角、金点、未读/已读章、150pt 视频封面、播放钮、位置标签、时长、正文 |
| composer | 646–648 | 20pt 圆角输入框、34pt 圆形上箭头发送钮；调用 spec 058 `ConversationViewModel.sendText` → `ChatSendCoordinator` |

颜色优先取 helmet 对应的 DesignSystem token；样机第 642 行另写死
`rgba(230,190,85,.14)`，因此以注明出处的专用
`Color.MeetPR.chatPlanBadgeFill` 精确落值，不能用动态
`goldSoft = gold500.opacity(0.14)` 近似。Swift 文件头与各结构注释保留样机行号。

## 数据合流

- 会话、消息拉取、轮询、发送、outbox、送达/已读状态继续复用 spec 058 的 `ConversationViewModel`、`ChatInboxViewModel`、`ChatSendCoordinator` 与 `ChatRepository`。
- 客户端通过 `StudentChatTimeline.merged` 将以下来源按 `occurredAt` 升序合流：
  - `ChatMessage.createdAt`
  - 新计划通知的稳定时间锚点 `StudentPlanView.startDate`
  - `CoachFeedback.postedAt`
- 同时间戳以稳定 item id 排序，避免重绘时跳序。
- DemoStudent 的聊天消息和反馈时间改为相对当前时间；反馈视频 seed 补 8 秒时长，因此同一聊天流可展示教练文本、我的文本、新计划卡、教练反馈卡四类条目。

## 反馈已读语义

样机第 867 行的判定为：

`visibleHeight / feedbackCardHeight >= 0.55`

iOS 实装逐张反馈卡读取其在 `chatScroll` viewport 坐标系中的 frame，求卡片与 viewport 的垂直交集高度。只有比例达到或超过 `0.55` 才调用既有 `FeedbackInboxViewModel.markRead` → `StudentFeedbackRepository.markRead`。低于 55%、零高度、已读卡、正在提交已读的卡都不会重复提交。

单元测试覆盖恰好 55% 会读、54% 不会读、零高度不读。

## 入口替换清单

- 今日 tab 顶栏「消息与通知」气泡：直接打开学员黑金全屏聊天。
- 训练 tab 顶栏气泡：直接打开同一全屏聊天。
- 成长 tab 顶栏气泡：定向返修第 1 轮补入 `GrowthScreenHeader`，直接打开同一全屏聊天。
- 我的 tab 顶栏气泡：定向返修第 1 轮补入 `MyProfileHeader`，直接打开同一全屏聊天。
- 删除 `NotificationCenterSheet.swift`。
- 删除无其他消费者的 `StudentNotificationBell`、`MyCoachCard`、`StudentUnreadBadge` 红色 v2 组件。
- 学员 host 不再导航到共享 `ChatUI.ConversationView`；教练端仍使用原视图，`CoachKit` 零改动。

## 范围确认

- `CoachKit`：零 diff。
- 教练端聊天现有外观：零改动。
- 评估功能代码按 07-13「硬封存、defer ≠ delete」保留；本轮只移除学员 badge
  聚合与已无入口的 evaluation 路由接线，不删除评估数据模型/VM。
- 新增动效：无；在 Reduce Motion 开启时清空本视图 transaction animation。
- commit / push：未执行。

## 自检结果

环境：iPhone 17 Pro Simulator，iOS 26.5。

| 检查 | 结果 |
|---|---|
| 全仓 `swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` | 通过，零输出 |
| 全仓 `swiftlint lint --strict --quiet --config .swiftlint.yml` | 通过，零输出 |
| 全量 9 个 SPM 包测试 | 1,322 通过，0 失败 |
| `MeetPR` / `Debug` iOS Simulator build | succeeded，0 warning |
| `MeetPR-Demo` / `Demo` iOS Simulator build | succeeded，0 warning |
| `MeetPR-DemoStudent` / `DemoStudent` build + run | succeeded，0 warning |
| DemoStudent 顶栏入口 | 点按后直接进入学员黑金全屏聊天，无通知 sheet |
| 每 tab 聊天入口 | 今日、训练、成长、我的四个 tab 均通过 UI 自动化打开同一黑金聊天 host |
| 四类时间流 | 模拟器同流确认新计划、教练文本、我的文本、教练反馈（含视频封面与 `0:08`） |
| 视频组号 | DemoStudent 实际显示「我的 低杠位深蹲 · 第 1 组」，与反馈档案 1-based 契约一致 |
| 新计划跳转 | 点按计划卡关闭聊天并切到训练 tab 的 W1D1 |
| composer | 输入 `Will do tonight.` 后发送成功，右侧气泡出现并显示「已送达」 |
| 反馈已读 | 可见反馈卡自动从未读切至金色勾选「已读」，顶栏 badge 同步下降 |
| 教练端隔离 | `git diff -- Modules/CoachKit Modules/ChatUI` 为空 |
| `git diff --check` | 通过 |

## 定向返修第 1 轮

评审提出的 5 个 blocker 与 1 个 nit 已逐项处理：

| Finding | 修正 |
|---|---|
| B1 新计划徽章色 | 新增 `chatPlanBadgeFill = rgba(230,190,85,.14)`，注释直引样机第 642 行；计划章不再误用动态 `goldSoft` |
| B2 组号 off-by-one | `StudentBlackGoldChatView` 直用 `CoachFeedbackVideo.setIndex` 的 1-based 原值；Demo 视频 seed 恢复 `1`；测试同时断言聊天标签与反馈档案都显示第 2 组 |
| B3 评估幽灵 badge | `evaluationUnreadCount` 代码保留但从 `totalUnreadCount` 与「我的」tab badge 剔除；移除 Dashboard 的 `onOpenEvaluation` / pulse 死接线及 `MyProfileView` 被忽略的评估 VM 注入 |
| B4 历史分页 | 黑金聊天顶部 sentinel 接入 `hasMoreHistory` / `loadOlder()`；加载前首项作为 top anchor，prepend 后恢复该 anchor；测试覆盖 before 分页、顺序与稳定锚点 |
| B5 每 tab 入口 | 今日、训练沿用既有入口；成长、我的本轮补 `HeaderChatButton`，四个 tab 都打开同一 `StudentNotificationHostModifier` host |
| nit 协调器回归 | 新增恰好 55% 可见 → `StudentNotificationsCoordinator.markFeedbackRead` → 共享反馈档案 VM 未读清零测试 |

本轮仍遵守：

- `CoachKit` 与共享 `ChatUI` 零改动；
- `SetEntrySheet.swift` 的 Claude 留白改动未触碰、未回退；
- 未 commit、未 push。


## 定向返修第 2 轮(Claude 接管)

- 首条未读定位回到样机 865 底部语义:`scrollAnchor` 改为随赋值语义切换的状态——
  初始定位/新消息/发送用 `.bottom`(时间线底部留白供出 16pt 间隙),仅历史分页
  恢复用 `.top`,B4 引入的顶部锚回归修复。
- 视频标签对齐样机 643 固定文案:`我的深蹲 · 第 1 组`(移除「我的」后空格),
  一致性测试期望同步更新。
- 死接线清理:`onSeeAllFeedback` 全链、`coachMessagePreview`/`hasActiveCoach`、
  `StudentNotificationRoute` 的 feedback/evaluation/coachMessages 三案(注释注明
  合流吸收),相关测试同步收敛。StudentKit 526/526。
