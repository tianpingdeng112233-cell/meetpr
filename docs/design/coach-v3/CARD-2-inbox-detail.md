# 任务卡 · 教练端 v3 浅色迁移 卡2:消息合流 + 学员详情五子 tab

> 派发人:Claude(Fable 判断层) · 2026-07-30 · 实装:Codex
> 分级:T2(跨 feature) · 发布档:P1
> base:`feat/coach-v3-shell-light`(**叠在卡1 上**) · 分支:`feat/coach-v3-inbox-detail`
> 参照物:`./MeetPR 教练端.dc.html`(同目录,浏览器直接打开可交互)
> **先读 `./CARD-1-shell.md`** —— 色值映射表、共享件纪律、像素闸门要求全部沿用,本卡不重复。

## 目标

卡1 已经把外壳 + 今日 + 学员做成 v3 浅色。本卡接着做**消息屏**与**学员详情**,
以及它们下挂的**聊天会话**与**申请资料屏**。做完后四个 tab 里三个是 v3,只剩「我的」留给卡3。

⚖️ **合并节奏**:卡1+卡2+卡3 全绿才一并进 1.0(16),本卡 PR 同样开着不合。

## 文件范围

- `Modules/CoachKit/Sources/CoachKit/Features/Receiving/CoachReceivingView.swift` —— 重做成会话列表
- `Modules/CoachKit/Sources/CoachKit/Features/StudentDetail/StudentDetailView.swift` —— 头部 + 计划卡 + 五子 tab
- `Modules/CoachKit/Sources/CoachKit/Features/StudentDetail/Overview/StudentOverviewSection.swift`
- `Modules/CoachKit/Sources/CoachKit/Features/BindQueue/StudentOnboardingProfileView.swift` —— 申请资料换皮
- `Modules/CoachKit/Sources/CoachKit/Features/Chat/ConversationListView.swift`(如需)
- 新增各 feature 目录下的 strings 文件(**沿用卡1 的 `CoachLocalization`,不要再造平行 helper**)
- 相应测试

**不动**:`Planning/`、`Features/MyProfile/`(卡3)、`Features/Dashboard/`、`Features/StudentRoster/`、
DesignSystem 共享件的**默认值**、StudentKit 任何文件。

## 1. 消息屏(样机 582–601)

现状 `CoachReceivingView` 是三段式分段控件(新学员 / 训练视频 / 消息)。样机把它合流成**单一会话列表**。

- **新学员那一段整段撤掉** —— 卡1 已经把申请卡挪到学员 tab 了,这里不再重复入口
- eyebrow `消息与视频 · {N}` mono 11 / `.semibold` / letterSpacing .06em / **`gold500`**;
  标题「消息」Archivo 800 / 34 / lineHeight 1
- 一张白卡包所有行,行间 1px 上边线(首行无)。每行 `padding: 12px 14px 12px 16px`:
  - **左侧可点区**(→ 开聊天):姓名 15/700 + 末条消息 12 `textTertiary`,**单行省略号**
  - 有未读:8pt `danger` 圆点
  - 有待反馈视频:**深色胶囊**(`textPrimary` 底,圆角 999)+ 播放三角 + 条数 mono 11/700 白字,
    **独立可点** → 直接进该学员的待反馈视频流(**不是**进聊天)
  - 末尾 16pt chevron `textDisabled`
- 卡下方提示 `点姓名进聊天 · 点黑色数字直接看待反馈的视频` 12 `textDisabled` / lineHeight 1.6
- 数据全走现成 `videoQueueViewModel` + `chat?.inbox`,**不加新端点**
- 空态:样机没画,按卡1 空态的做法给一个诚实的(禁「暂无数据」),并记进偏离清单

## 2. 学员详情(样机 638–730)

- 返回行「‹ 学员」14 `textSecondary` + 20pt chevron;右上 38pt 白圆卡(`.card` 阴影)+ 18pt 对话气泡 → 开聊天
- 姓名 Archivo 800/32 + 状态药丸(11/600,色与描边随状态)
- **计划卡**:`W{n} 在跑` 14/700 + `· {detailWeek}` 12 `textTertiary`;
  6pt 圆角进度条,底 `borderDefault`、填充 `success`;底部两个等宽描边胶囊(1px `borderStrong`,13/600)
- **五个 chip 子 tab**:概览 / 视频 / 成长 / 反馈 / 资料。`padding: 8px 11px`、圆角 12、13/600、
  横向可滚动、选中态底色与文字色照样机 651–655
- 现状子 tab 是 概览/执行/视频/成长/反馈:**「执行」并进概览的「本周训练」**,**新增「资料」**
- **概览**(657+):
  - 「本周训练」白卡:小标题 11/600 `gold500` + 右侧「点某天可微调」11 `textTertiary`;
    每天一行(1px `borderHairline` 上边线):日期标签 14/700 + 日期 12 `textTertiary` +
    「已调整」药丸(10/700 `gold500`,底 `gold500@12%`)+ 状态 11/600 + chevron
  - 「今日状态」卡:有填 → 15/700 显示;未填 → 「今日未填」15/700 `textTertiary` + 「提醒填写」描边胶囊
  - 「最近反馈」卡:有 → 正文 + meta;无 → 「还没有反馈」+「去视频页写第一条 →」
- **视频 / 成长 / 反馈 / 资料**:结构照样机对应块;资料页的注册问卷字段接现成 onboarding 数据

## ⚠️ 三个陷阱 —— 已定处置,照做,不要自由发挥

1. **「本周总结」不实装**。样机里它只是弹 toast(`toastSummary`),没有真行为。
   仓内 `EvaluationSummaryEditorView` 是 **2026-07-13 硬封存**的评估期组件(`evaluationSealed`)。
   → **按钮画出来但禁用**(或整个不画),**绝对禁止**接到评估摘要编辑器上,禁止翻 `evaluationSealed`。
   记进偏离清单。
2. **「点某天可微调」不许空头承诺**。样机点进去是日微调屏(数字键盘 / 2.5kg 一档 / 保存并通知学员),
   那要**后端写接口**,不在本卡。`CoachDayDetailView` 现在是纯只读。
   → 点某天**仍进只读日详情**,**提示文案改成不承诺编辑的说法**(别照抄「点某天可微调」)。记进偏离清单。
3. **「提醒训练」接现成聊天**:打开与该学员的会话并预填一条消息,由教练自己按发送。
   不要新建通知/推送链路(APNs 未开工)。

### 已授权偏离清单(实装期追加,PR body 照此列出)

| # | 偏离 | 授权 |
|---|---|---|
| 1 | 消息屏在聊天与视频均为空时显示诚实空态;样机未画空态 | 派卡时 |
| 2 | 「本周总结」保持禁用,不接硬封存的评估摘要编辑器 | 派卡时 |
| 3 | 「点某天查看详情」进入只读日详情,不承诺本卡没有后端能力的日微调 | 派卡时 |
| 4 | 消息行的视频胶囊先进入该学员的待反馈视频列表,不按样机直接打开第一段;当前直接打开会落到旧 v2 视频反馈屏,**视频列表屏与视频反馈屏的 v3 化是后续卡** | Claude 第 1 轮定向返修授权 |

## 沿用卡1 的全部纪律(不重复展开)

色值只走 CARD-1 的映射表 token、零硬编码 hex、零 v2 旧 token;算法进可单测纯函数;
日期一律 `CoachFeatureCalendar`(**不要引 StudentKit 的 `PlanCalendarDayIdentity`,它是 internal**);
共享件改色走「可选参数 + 默认值保持现值」;文案走 `CoachLocalization` + xcstrings,禁 `String(format:)`;
`now` 一律由上层传入,**禁止在 view 内部自取 `Date()`**(卡1 刚统一成 shell 单一时钟);
**样机里的假数据不是契约**(写死数组/常量要用真实数据源替代);
像素闸门:`python3 -m http.server` 开样机与模拟器同屏逐屏比对。

## 验收标准

- `swift test` CoachKit + DesignSystem 全绿;`xcodebuild -configuration Demo` **0 warning**
- `swiftlint --strict` + `swift-format lint --strict` 干净
- 模拟器截图:①消息屏(有未读+有视频胶囊)②消息屏空态 ③学员详情·概览 ④五个子 tab 各一张
  ⑤申请资料屏 ⑥聊天会话
- **模拟器实点**:消息屏点姓名进聊天、点胶囊进视频流(两条路径必须分开验);详情页五个 chip 能切换;
  返回行能回学员页 —— **渲染正常不等于能点,必须真点**
- grep 自证:改动文件内零硬编码 hex、零 v2 旧 token、零 `Date()` 直取
- 自证边界:`Planning/`、`Features/MyProfile/`、StudentKit **零 diff**
- **不 commit、不 push**,改动留在工作区等 Claude 跑 review-loop
