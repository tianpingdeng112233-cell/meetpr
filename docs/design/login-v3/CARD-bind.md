# 任务卡 · 学员端绑定教练流 v3 浅色换皮(设计稿 4b/4d)

> 派发人:Claude(Fable 判断层) · 2026-07-30 · 实装:Codex
> 分级:T1(单模块 StudentKit/Bind,无架构/迁移/后端) · 发布档:P1
> base:`origin/release/1.0`(发版线) · 分支:`feat/bind-flow-v3-light`
> 姊妹卡:`feat/login-page-v3-light`(登录页 4a,AppShell)。两卡文件零重叠,可并行、独立验收。

## 目标

把绑定教练流从 v2 旧 token 换成 v3 浅色,并把设计稿 4b/4d 里**纯前端能交付**的体验改进落地。

⚖️ **David 2026-07-30 拍板 A = 换皮**:保留现有机制不动——10 位邀请码、`displayName` 必填、
「提交 = 发出绑定申请,等教练在收件队列同意」。稿子里凡是要动机制/后端/产品主张的部分**一律不做**,
清单见下面 §有意偏离设计稿。

参照物:`../../../docs/design/login-v3/4a-login-light.html` 同源的原始设计稿(4b/4d 屏未入仓,
规格已逐条抄进本卡,以本卡为准)。

## 文件范围

- `Modules/StudentKit/Sources/StudentKit/Features/Bind/EnterCodeView.swift` —— 主体重做
- `Modules/StudentKit/Sources/StudentKit/Features/Bind/PendingBindView.swift` —— v3 换皮
- `Modules/StudentKit/Sources/StudentKit/Features/Bind/BindGateView.swift` —— 仅 `loadingView` /
  `failedView` / `GateLogoutButton` 三处的 v2 token 换成 v3
- 相应测试(`Modules/StudentKit/Tests/StudentKitTests/` 下 Bind 相关)

**不动**:`EnterCodeViewModel` / `BindGateViewModel` 的任何状态机与校验逻辑、`BindRepository`、
`InviteCodeFormat`、`CoreModels`、今日页、CoachKit、任何后端契约。

## 要做的(4b 换皮 + 体验改进)

### 版式(390 宽,左右 padding 24)

1. **标题** —— 「输入教练邀请码」,`Font.MeetPR.display` 30pt `.bold`、行高 1.1、字距 -.02em、
   `textPrimary`。
2. **副文案** —— 换成稿子那句(比现有的更说明价值):
   「绑定之后,教练排的计划会直接出现在你的「今日」,你的每组记录也会同步给他。」
   14pt / 行高 1.55 / `textSecondary`。
   ⚠️ 替换掉现有的「没有教练?请向你的教练索取邀请码」。
3. **分格码输入** —— 稿子画的是 6 格单行;**本仓的码是 10 位**,单行 10 格在 342pt 可用宽里
   每格只剩约 27pt,放不下 mono 26pt 字面。所以改 **两行 5 格**:
   - 每格宽 `(342 - 4*8) / 5 ≈ 62pt`,`aspect-ratio 1/1.18` → 高约 73pt,格间距 8,行间距 8
   - 已填格:`surfaceCard` 底、1px `borderDefault`、圆角 12、mono 26pt `.semibold` `textPrimary`、
     `MeetPRCardSurface(elevation:.card)` 的阴影
   - 当前格:1px `gold500` 描边 + `0 0 0 3px gold500@10%` 外发光,格内一条 2×24 的 `gold500` 光标
   - 未到达格:`surfaceRaised` 底、1px `borderSubtle`、无字
   - 输入行为沿用 `InviteCodeFormat.normalize`(自动转大写、忽略空格与连字符);字母表已排除
     I/O/0/1,不要另写规则。键盘 `.asciiCapable` + `.textInputAutocapitalization(.characters)` +
     `.autocorrectionDisabled()`(现有代码已有,保留)
   - 无障碍:整块分格框对 VoiceOver 暴露为**一个**文本输入元素(label「邀请码」),不要暴露 10 个格子
4. **格下一行** —— 左「10 位字母数字,不区分大小写」12pt `textMuted`;
   右「从剪贴板粘贴」12.5pt `.semibold` `goldText` + 剪贴板图标 13pt。
   粘贴按钮读 `UIPasteboard.general.string`,过 `InviteCodeFormat.normalize` 后填入;
   剪贴板空或 normalize 后不合法就不填,给一句轻提示。**这是新增能力**。
5. **说明卡** —— `surfaceRaised` 底、圆角 14、内距 14/15、`info` 图标 17pt `textTertiary` +
   12.5pt / 行高 1.6 / `textSecondary` 文案:
   「邀请码在教练那边:他打开 MeetPR 教练端 →「我的」→「我的邀请码」,会看到一串 10 位码。」
   ⚠️ 稿子原文写的是「「学员」→「加学员」…或者直接发你一个链接」——**两处都是错的**,已核实:
   实际入口是 `CoachMyProfileView` 里的「我的邀请码」(推 `InviteCodesView`),
   且全仓**零 deep link**(`onOpenURL` / URL scheme 均无命中),所以「发你一个链接」这半句必须删。
   照上面改写后的文案落。
6. **你的姓名** —— 保留现有 `MeetPRTextField`(稿子漏了这个必填字段),
   但外观跟上 v3(卡片式 + mono 小标签,与分格框同一视觉语言)。helper 保留
   「教练会在学员列表里看到这个名字」。
7. **提交按钮** —— `GoldCTA` / `gold500` 实底、高 54、圆角 14、`inkOnGold` 16pt `.bold`、
   阴影 `0 6px 18px gold500@22%`。文案从「提交」改成「**提交绑定申请**」——现有文案不说明后果,
   而真实机制是发出申请、等教练同意,按钮要说清。禁用态用 `surfaceRaised` 底 + `textDisabled` 字
   (照稿子的禁用样式)。

### 错误态(稿子 4d 上半)

- 校验失败时:**10 个格子的描边全转 `Color.MeetPR.danger`**,并且**不清空已输入内容**
  (现状是只在字段下挂一行文字)
- 提示行:`danger` 图标 15pt + 12.5pt / 行高 1.55 / `dangerMuted` 文案,内容要可执行:
  「这个码不存在或已过期。让教练在「我的」→「我的邀请码」里重新生成一个。」
  (同样按核实过的真实路径写,不要用稿子的「学员 → 加学员」)
- 提示行下面一排两个按钮:「清空重输」(透明底、1px `borderStrong`、高 48、圆角 13、
  14pt `.semibold` `textSecondary`)+「提交绑定申请」(禁用态)
- 错误来源沿用 `viewModel.fieldError` / `showsNetworkBanner`,**不改 ViewModel 的判定逻辑**;
  只把 `FieldError.invalidCode.message` 的文案改成上面那句可执行版本

### 换皮(纯 token 替换)

`EnterCodeView` / `PendingBindView` / `BindGateView` 里所有 v2 旧 token 换成 v3:
`fgPrimary`→`textPrimary`、`fgSecondary`→`textSecondary`、`fgTertiary`→`textTertiary`、
`brandRed`→`danger`、`surface2`→`surfaceRaised`、`bg`→`bgBase`、`border`→`borderDefault`。
卡片一律走 `MeetPRCardSurface`。**零硬编码 hex。**

## ⛔ 有意偏离设计稿(每条都要写进 PR 描述,别当成漏做)

| # | 稿子要求 | 为什么不做 |
|---|---|---|
| 1 | 6 格码 | 本仓码是 **10 位**(`InviteCodeFormat.length = 10`,文件注释明写与后端 spec 005 D4 逐字耦合,改位数是 breaking change 且会让教练已分发的码全失效)。改成两行 5 格,位数不动 |
| 2 | 右上「跳过」 | `BindGateView.needsCode` 屏零「跳过」实现,唯一出口是右上「登出」。稿子的落点要把 `coachedStudent` 改成 `selfTrainStudent`,而后者全仓只在**注册时**可选、Bind 目录零命中——需要角色变更能力(后端)。⚠️ 且「自己练」目前是待拍板空壳,对外文案不提自练 |
| 3 | 底部「先自己练,之后再绑」 | 同 #2 |
| 4 | 4c 整屏「码通过 · 确认是这位教练」 | 机制上不存在这一屏:码的有效性只有 POST 之后才知道,而 POST **就等于已经发出绑定申请**。要做「先校验码 + 回教练公开资料、不落申请」得新增后端接口 |
| 5 | 4c 教练卡的 已认证 / IPF 二级 / 场馆·城市 / 带训学员数 / 执教年数 | `CoachProfile` 全部字段只有 `id` / `userID` / `createdAt`,这六项后端零实现;「已认证」还是一套不存在的认证体系 |
| 6 | 4c「绑定后他可以…看不到你的手机号和体重记录」 | 教练端真实可见范围未核实。隐私承诺写进 UI 就是对外承诺,不凭猜写 |
| 7 | 4d 下半「跳过后今日页顶部常驻绑定卡」 | 没有 #2 的「跳过」就没有「跳过之后」;且今日页本卡零改动 |
| 8 | 步骤指示器「第 1/2 步」 | A 方案下只有一屏,两步条会误导 |
| 9 | 稿子没画 `displayName` 字段 | 它是现有必填字段(1–100 字符),不能删 —— 保留 |

## 约束

- 全部颜色走 `Color.MeetPR.*`,复用 `MeetPRCardSurface` / `GoldCTA` / `MeetPRSpacing` /
  `MeetPRRadius` / `Font.MeetPR`,不新造平行组件
- 保留全部 `Analytics` 调用点(`screen(.bindEnterCode)` / `bindCoachAction(.inviteOpen)` /
  `validationError(flow:.bind,field:.inviteCode)`),一个都不许丢
- 不改 `EnterCodeViewModel` 的 `submit()` 流程、`isSubmittable` 判据、stash 分支
- 不碰 `evaluationActive` 分支(评估期是硬封存件,`defer ≠ delete`)

## 验收标准

- `swift test` StudentKit 全绿;`xcodebuild -configuration Demo` 0 warning
- `swiftlint --strict` 干净(阈值以仓内 `.swiftlint.yml` 为唯一事实源)
- 模拟器截图四张:空态 / 输到第 6 位的中间态 / 填满可提交态 / 错误态(格子染红且未清空)
- grep 自证:三个文件里零 v2 旧 token、零硬编码 hex
- VoiceOver 走一遍分格框:读出来是一个「邀请码」输入项,不是 10 个格子
- **不 commit、不 push**,改动留在工作区等 Claude 跑 review-loop
