# Spec 084 · 卡 C（iOS）：Ask coach 选组、聊天训练卡、组录入原地播放、休息说明

开工先读仓内 `CONTEXT.md`（如存在）、`AGENTS.md`、`specs/084-walkthrough-polish/SPEC.md` 的「设计定稿」§7–§10 与「设计项的验收清单」。

- 级别／节奏：T2 / P1。本分支 `feat/084c-chat-video-rest` 叠在卡 B（`feat/084b-week-strip-login`）之上，前序合入后 PR 指向发版线 `release/1.0`；目标 1.0(24) 候选（落线不等于进包）。
- 这是 Opus 派的任务卡，走 feature 分支 + PR，**不是** `AGENTS.md` §发版直推流里的"David 直驱小修"：那一节的开工自检不适用，就在当前分支实装。
- **不 commit、不 push**。不改 `NEXT-RELEASE.md`、`RELEASES.md`、build 号；只在 `docs/CODEX-JOURNAL.md` 末尾追加本卡一节。本仓已公开。
- 设计稿实装方打不开，下面的文字转写就是参照物：结构、层级、相对间距按转写，颜色字号间距用仓内现有 token。

## iOS 落点

- §7：`Modules/ChatUI/Sources/ChatUI/SetRefSharePicker.swift`、`SetRefPickerPresentation.swift`、`SetRefSharingContext.swift`、`SetRefSendIntent.swift`、`ChatSendCoordinator+SetRef.swift`；入口在 `StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`（`TodaySetRefSharingSource`）与 `ConversationView.swift` 的 "+"。
- §8：`ChatSetCardView.swift`、`ChatSetCardPresentation.swift`、`ConversationMessageRows.swift`、`ChatSetRefDisplayFormatter.swift`；教练端与学员端会话页共用 ChatUI。
- §9：`StudentKit/Features/VideoUpload/VideoAttachmentSection.swift`、`VideoAttachmentV3Controls.swift`、`SetVideoPlaybackView.swift`、`VideoAttachmentPlaybackSource.swift`，宿主是 `TodayWorkout/SetEntrySheet.swift`。`ChatUI` 的 `FeedbackVideoPlayerView` 及其打点、标注一律不动。
- §10：`StudentKit/Features/TodayWorkout/RestTimerExplanationView.swift`、`TodayWorkoutViewModel` 的 `showsRestTimerExplanation`；数值来源 `RestTimerPolicy` / `RestDefaults`。

## §7 Ask coach 选组（一页完成）

对应 SPEC「设计定稿 §7」。替代现在的"选组列表 → 写留言"两步：

- 页头 "Ask coach" + 右上关闭；提示语 "Which set is this about?"。
- 每个动作一张卡：动作名只出现一次，右侧 W#D#（走卡 A 的序号入口）；下面是该动作各组的小格，三列等宽网格，多于三组换行。每格三行：`Set n`、`重量 × 次数`、状态（`Logged · RPE x` / `Logged · video` / `Planned`）。选中的格：深色粗框、卡片表面色底。一次只能选一组。
- "Your question" 多行输入框，占位 "What do you want your coach to look at?"。
- 底部一行小字复述将发送的内容（"Sends Set 2 of <动作名> with your question"）+ 主按钮 "Send to coach"；未选组时主按钮不可用。有视频的组保留现有"是否带上视频"的开关及其禁用规则。
- 训练页的 Ask coach 与聊天页 "+" 两个入口都用这一页；从训练页当前组进入时预选该组。
- 发送走现有的发送通道：幂等键、失败重试、暂存（staging）与离线行为不变；线上的 set_ref 形状不变。

## §8 聊天里的训练卡

对应 SPEC「设计定稿 §8」。带训练组的消息渲染为**一个**气泡：

- 上方是发送者写的话，正文字号，与普通文字消息一致。
- 下方是嵌在气泡里的附件行（浅色内嵌块）：有视频时左侧一个带播放图形的方块；中间两行（动作名；`Set 2 of 3 · 50kg × 5 · RPE 8`，没有的字段省略）；右侧 chevron。点附件行进入现有的详情 / 播放（行为不变）。
- 气泡下方一行 `时间 · Delivered`（沿用现有的送达状态文案）。没有写话时只显示附件行，不留空白区域。
- 自己发的与对方发的用各自气泡配色，结构相同；学员端与教练端的会话页都适用。

## §9 组录入页的视频行（原地播放）

对应 SPEC「设计定稿 §9」。**范围只限训练页组录入里学员自己录完或选完视频后的回看；教练反馈、聊天、打点所用的独立全屏播放页不动。**

- 没有视频：维持现状（"Video" 标签 + Record + Photos）。
- 有视频：一块深色圆角的原地播放器。画面在上；底部一行控件从左到右：播放/暂停、进度条（下方两端是已播 / 总时长，可拖动）、倍速按钮、放大按钮。倍速按钮平时只显示当前倍速（如 `1×`），点击后向上展开四档（2× / 1.5× / 1× / 0.5×），选中项高亮，选完收起。放大按钮在最右下角。
- 播放器下方一行：左侧上传状态（Sending / Delivered to coach / 失败与重试，文案沿用现有），右侧 Replace、Delete 两个按钮，同一行、文字不折行；放不下时两个按钮整体换到下一行。
- 放大：播放器在当前页面上铺满整屏，**不发生页面跳转**；视频占满屏幕，顶部半透明条显示动作名与组信息，底部半透明条是同一组控件，最右下角的按钮变为缩小。系统返回（安卓返回键 / iOS 下滑或返回）先缩小、再走原有返回。缩小后回到原位继续播放，进度与倍速保持。
- 不自动播放；离开组录入页时停止播放并释放播放器。上传、替换、删除、失败重试的行为不变。

## §10 休息时间说明

对应 SPEC「设计定稿 §10」。首次出现的说明改为底部弹层：

- 标题 "Rest time follows your RPE"；一句说明。
- 三行对照表（左列条件、右列时长）：`RPE below 7`、`RPE 7 to below 9`、`RPE 9 or above`，右列数值**从现有的默认休息规则读取并格式化**，不在界面里写死数字。
- 一句 "If your coach set a rest time for a set, that one is used instead."
- 主按钮 "Got it"；其下文字链接 "Change in Profile → Rest between sets"，进入现有的休息设置页。
- 出现时机、只出现一次的规则、已看过的标记存储都不变（已看过的老用户升级后不再弹）。中英文文案同步更新。

## 约束

- 不改后端契约、set_ref 线上形状与本地持久化结构；不加依赖。
- 存量照护：历史消息（含旧版本发出的训练卡）在新气泡结构下正常显示；已看过休息说明的用户不再弹；上传中的视频在升级后状态不丢。
- 守仓内 `.swiftlint.yml` 与 `swift-format --strict`。

## 测试 seam（先红后绿，只在这些边界）

1. `SetRefPickerPresentation`：按动作分组、三列网格的格子内容与状态文案、预选、单选、未选时不可发送、底部复述文案。
2. `ChatSetCardPresentation` / 时间线 presentation：有话 + 附件、只有附件、有无视频、缺字段时的第二行文案。
3. 组录入视频行的播放状态模型（新增一个可测的状态对象）：播放/暂停、倍速四档、放大/缩小保持进度与倍速、返回先缩小。
4. 休息说明的三行数值由默认规则推导（改规则则文案随之变）。

视图样式不写镜像测试。

## 验收清单（Opus 收货，逐项核）

- [ ] §7：从训练页与聊天页两个入口都进入同一页；选组、写问题、发送一步完成；发送后聊天里出现 §8 的气泡；幂等与失败重试行为与现状一致。
- [ ] §8：自己写的话在气泡最上方；只发组不写话时不出现空白区域；点附件行能进详情或播放；教练端看到同一结构；历史消息显示正常。
- [ ] §9：原地播放、暂停、拖动、四档倍速、放大、缩小都可用；放大不发生页面跳转；缩小后进度与倍速保持；Replace / Delete / 上传状态行为与现状一致；独立全屏播放页及其打点、标注不受影响。
- [ ] §10：弹层三档数值与实际休息规则一致；Got it 关闭且不再出现；链接进入休息设置页。
- [ ] Light / Dark、小屏与大字体下不截断、不遮挡主按钮。
- [ ] 九个包的 `swift test`、主工程测试、`swiftlint lint --strict`、`swift-format lint --strict` 通过。

模拟器实屏由 Opus 收货时做（模拟器里 `canEditVideo` 恒为 false、相机不可用，视频行用相册样片验）；沙箱里跑不了模拟器就如实写"未做设备验证"。

## Out of Scope

SPEC §1–§6；独立全屏播放页、教练打点与标注；视频剪辑；上传机制；推送；build 号、tag、`NEXT-RELEASE.md`、Archive / Upload。

## 返修第 1 轮（Opus 收货，2026-10-03）

收货方复跑 ChatUI 84 / StudentKit 914、两个 lint 通过。DemoStudent 实屏通过的：Ask coach 选组页（两个入口同一页、训练页入口预选当前组、聊天入口未选时发送不可用、底部复述）、发送后聊天里的新气泡（问题在上、附件行在下、Delivered）、组录入页原地播放器（播放 / 暂停、四档倍速弹出与收起、放大后铺满整屏不跳页）、休息说明弹层（三档数值 2:00 / 3:00 / 4:00 与规则一致、Got it、链接进入休息设置页）。三处返修：

1. **放大态顶部条第二行显示成 "Set %@"**，格式参数没有代入。应为该组信息，形如 `Set 1 · 175kg × 3 · RPE 8.5`（字段缺失时省略），中英文同步。
2. **放大 / 缩小后播放进度回到 0:00。** 实测：放大前在 0:01 播放中，放大后显示 0:00；放大态里播到 0:01 暂停后缩小，回到原位显示 0:00、画面回到首帧。倍速保持是对的。SPEC 要求"缩小后回到原位继续播放，进度与倍速保持"——放大与缩小两个方向都要保住进度与播放 / 暂停状态（同一个 AVPlayer 跟着走，不要重建 item 或 seek 到 0）。另外缩小后整页滚回了顶部，应停在播放器所在位置。在 `SetEntryVideoPlaybackState` / `SetEntryVideoPlayer` 的测试里补"放大缩小保持进度"的断言（若现有断言只测状态对象而没测播放器，就补到播放器这一层能测的边界）。
3. **进度条观感与定稿不符。** 现在是一个很大的白色胶囊滑块压在细轨上，几乎看不出已播部分。定稿：细轨（约 4pt），已播部分金色，滑块小而不抢眼；内嵌与放大两态一致。仍需保证拖动的命中区不小于 44pt（用透明命中区，不靠放大滑块本身）。

返修后重跑 ChatUI、StudentKit 测试与两个 lint，JOURNAL 本卡一节追加一行。仍不 commit、不 push。

## 返修第 2 轮（Opus，2026-10-03）

第 1 轮三处都生效了：放大态第二行是 `Set 1 · 175kg × 3 · RPE 8.5`；放大 / 缩小时进度、播放状态、倍速都保住；缩小后页面停在播放器处；进度条是细轨 + 金色已播 + 小滑块。

但带出一个回归：**放大后视频画面全黑**（只有控件，进度在走），**缩小回内嵌后画面也变黑**，再也不出画；第 1 轮之前放大态是能出画的。复现：组录入页选样片 → 0.5× → 播放 → 2 秒后放大 → 黑；再缩小 → 内嵌也黑。推测是同一个 `AVPlayer` 被两个 `AVPlayerLayer` / `VideoPlayer` 表面争用，或图层在两个宿主视图之间搬动后脱离。要求：任何时刻只有一个画面宿主持有该播放器（放大时内嵌宿主释放，缩小时放大宿主释放并让内嵌宿主重新挂上），两态切换后都能立即出画；保留第 1 轮的进度 / 倍速 / 播放状态保持。若有可测边界（例如"同一时刻只有一个宿主绑定播放器"的状态），补一条测试；没有就在 JOURNAL 写明。

跑 ChatUI、StudentKit 测试与两个 lint，JOURNAL 追加一行。仍不 commit、不 push。
