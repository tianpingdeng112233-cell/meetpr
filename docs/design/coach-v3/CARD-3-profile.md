# 任务卡 · 教练端 v3 浅色迁移 卡3:我的 + 收尾项

> 派发人:Claude(Fable 判断层) · 2026-07-30 · 实装:Codex
> 分级:T2 · 发布档:P1
> base:`feat/coach-v3-inbox-detail`(**叠在卡2 上**) · 分支:`feat/coach-v3-profile`
> 参照物:`./MeetPR 教练端.dc.html` · **先读 `./CARD-1-shell.md`**(色值映射表与纪律,本卡不重复)

## 目标

卡1 做了外壳+今日+学员,卡2 做了消息+详情。本卡把**最后一个 tab「我的」**做成 v3,
外加三件走查(2026-07-30,报告 `~/Projects/scratch/2026-07-30-coach-walkthrough.md`)拍板的收尾项。
做完后**四个 tab 全部 v3**。

⚖️ 上车闸门:卡1+卡2+卡3+卡4 **加上 PR #291 / #292** 一并进 1.0(16);本卡 PR 同样开着不合。

## 文件范围

- `Modules/CoachKit/Sources/CoachKit/Features/MyProfile/CoachMyProfileView.swift` —— 主体重做
- `Modules/CoachKit/Sources/CoachKit/Features/InviteCodes/InviteCodesView.swift` —— 换皮(见 §3)
- `Modules/CoachKit/Sources/CoachKit/Features/StudentDetail/Evaluation/` —— 只加封存闸(见 §5)
- 新增:帮助与反馈 / 隐私与条款两个 sheet + 退出确认 + 对应 strings 文件
- 相应测试

**不动**:`Planning/`、`Features/Dashboard/`、`Features/StudentRoster/`、`Features/Receiving/`、
`Features/Chat/`、**StudentKit 任何文件**、DesignSystem 共享件的默认值。

## 1. 我的页(样机 602–637)

标题「我的」Archivo 800/34。**照样机排版,但下面「不画」的几项一个都不许画出来**。

### 要做的

- **邀请码卡**:小标题「永久邀请码」11 `textTertiary` + 右侧「复制」按钮;
  码本身 mono 大字;下面一行「已有 N 学员通过它加入 · 发给新学员即可申请」。
  点整卡仍进邀请码管理屏(§3)。**「复制」要真复制到剪贴板并给 toast 反馈。**
- **通用组**:帮助与反馈(→ §2 sheet)/ 隐私与条款(→ §2 sheet)/ App 版本(不可点,样机也不可点)
- **退出登录**:`danger` 色,点击弹**确认弹窗**(§4)

### ⛔ 不画的(后端不存在,画了就是死链或编数)

| 样机有 | 为什么不画 |
|---|---|
| 头像 + 头衔 + 编辑箭头 → 教练资料 sheet | 后端**没有**姓名以外的字段(头衔/场馆/简介/头像);挂账的 `GET /me display_name` 也还没做 |
| 三宫格统计(本月反馈 42 / 平均回复 6 小时 / 视频复盘 31 段) | **没有聚合端点**。禁止用本地数据凑一个近似值糊上去——那是编数 |
| 教练工具 · 动作库 | iOS 端无实装(仅 plan-web 有),1242 条 catalog 搬 iOS 是独立卡 |
| 教练工具 · 提醒规则 | 全仓零实现,依赖 APNs(聊天 W2 推送未开工) |

姓名行**只显示后端真给的东西**:有 display_name 就显示,没有就沿用现状的「教练」;
**不要**编造头衔、带训人数、入驻时长。以上四项全部写进 PR 偏离清单。

## 2. 帮助与反馈 / 隐私与条款(样机 shHelp / shTerms 段)

两个 sheet,标题 + 副标题走样机的 sheet header 样式。

- **帮助与反馈**:样机的 5 条 FAQ **逐字照抄**(问题 + 答案,行号在 `faqList` 定义处);
  底部「联系我们」+「工作日 10:00–19:00 · 通常 2 小时内回复」。
  ⚠️ FAQ 里有一条讲「为什么学员的 1RM 只能我改」——⚖️1RM 归属已拍板(教练可改、学员只读)
  但**跨端实装不在本波**,所以这条 FAQ **先不放**,免得文案承诺一个还没落地的行为。其余 4 条照放。
- **隐私与条款**:用户服务协议 / 隐私政策 两行 + 日期;「学员数据使用说明」整段照抄;
  底部「导出我的执教数据」「注销账号」两行。
  ⛔ **导出 / 注销都不实装**(前者无端点,后者是 spec 011 anonymized-delete,后端分支未上线)——
  **要么不画这两行,要么画成禁用态**,绝不能点了没反应或点了报错。写进偏离清单。
  🔗 **URL 只能复用 `AnalyticsPrivacyNotice.privacyPolicyURL` 这一个既有常量**,
  严禁再抄一份字面量 —— 该域名 `meetpr.app` 因 ICP 备案要迁 `.com`,单一事实源才改得动。
  服务协议若无既有 URL,**不要编一个**,那一行按不可点处理并申报。

## 3. 邀请码屏换皮(⚖️ David 2026-07-30 拍板:保留并换皮)

`InviteCodesView` 现在是一整套 v2 管理界面(复制 / 重新生成 / + 一次性码 / + 限时码 + 码列表)。
**样机的「我的」没画这一屏**——它是样机盲区的旧部件,但能力是真有用的(给单个学员发一次性码)。
所以:**保留全部功能,只套 v3 token**(色值走 CARD-1 映射表,零硬编码 hex、零 v2 旧 token)。
不要按「样机没有就删」处理。

## 4. 退出确认(样机 991–1000)

现状:点「退出登录」**立即登出,零确认**(走查 P-23)。
按样机补确认:标题「退出登录?」+ 正文「退出后需重新用手机号登录,草稿计划已自动保存。」
+ 取消 / 退出两键(退出为 `danger`)。
⚠️ 正文里「草稿计划已自动保存」是**事实声明**:确认 `DraftStore` 确实在登出前持久化了草稿,
**若不成立就改文案**,别让弹窗承诺一件没发生的事。

## 5. 教练侧评估期封存(⚖️ David 2026-07-30 拍板)

走查 P-22 实证:教练端学员详情顶部的「评估期 · 还剩 N 天」卡**三个按钮全活**,
「评估总结」直接打开 **2026-07-13 已硬封存**的 `EvaluationSummaryEditorView`。
`EvaluationStatusBanner` 在 base 上就已渲染,非本波引入,但方向与封存相反。

- 教练侧**隐掉整张卡**(banner + 三个按钮),**代码休眠不删**(defer≠delete,与评估期封存同套路)
- ⚠️ 学员端那个 `evaluationSealed` 是 `StudentKit/Features/Bind/BindGateViewModel.swift:134` 的
  **private static 常量,CoachKit 读不到**;而 StudentKit 要求零 diff。
  → 在 CoachKit 侧立一个**平行常量**(如 `CoachEvaluationSeal.isSealed = true`),
  注释里写明「与 StudentKit BindGateViewModel.evaluationSealed 成对,**解封要翻两处**」。
  **不要**为了共用去改 StudentKit 的可见性。
- 补测试:封存开启时详情页不渲染评估 banner。

## 沿用前两卡的全部纪律

色值只走 CARD-1 映射表 token、零硬编码 hex、零 v2 旧 token;算法进可单测纯函数;
日期一律 `CoachFeatureCalendar`;`now` 由上层传入,**禁止 view 内部自取 `Date()`**;
文案走 `CoachLocalization` + xcstrings,禁 `String(format:)`;
共享件改色走「可选参数 + 默认值保持现值」;**样机的假数据不是契约**;
**禁止画死链**——点了没反应 / 点了报错 / 显示编造的数,三者都不接受。

## 验收标准

- `swift test` CoachKit + DesignSystem + AppShell 全绿;`xcodebuild -configuration Demo` **0 warning**
- `swiftlint --strict` + `swift-format lint --strict` 干净
- 模拟器截图:①我的页 ②帮助与反馈 ③隐私与条款 ④退出确认弹窗 ⑤邀请码屏 ⑥学员详情(评估卡已消失)
- **模拟器实点**:每个可点项都点一遍,确认**没有一个是死链**;「复制」真进剪贴板;
  退出确认的「取消」能取消、「退出」能退出 —— **渲染正常不等于能点**
- grep 自证:改动文件内零硬编码 hex、零 v2 旧 token、零 `Date()` 直取、零新抄的 URL 字面量
- 自证边界:`Planning/`、`Features/Dashboard/`、`Features/StudentRoster/`、`Features/Receiving/`、
  `Features/Chat/`、**StudentKit** 全部零 diff
- **不 commit、不 push**,改动留在工作区等 Claude 跑 review-loop
