# 任务卡 · 学员端登录页 v3 浅色重做(设计稿 4a)

> 派发人:Claude(Fable 判断层) · 2026-07-30 · 实装:Codex
> 分级:T1(单模块、无架构/迁移) · 发布档:P1(进 NEXT-RELEASE 候选,随下一班车)
> base:`origin/release/1.0`(发版线) · 分支:`feat/login-page-v3-light`

## 目标

把登录页从 v2 恒暗旧 token 重做成 v3 浅色定稿,**一比一**对齐 David 2026-07-30 的设计稿 4a 屏
(参照物:`./4a-login-light.html`,与本卡同目录,可直接在浏览器打开对照)。

登录页是 v3 黑金波**唯一没覆盖的界面**——PR #279 收据明写「教练端与登录流保持恒暗、全程零 diff」,
所以它至今一个 v3 token 都没有,夹在已经浅色化的学员端旁边割裂。本卡补上这一块。

## 文件范围

- `Modules/AppShell/Sources/AppShell/Auth/LoginView.swift` —— 主体重写
- `Modules/AppShell/Sources/AppShell/Auth/AuthSecureField.swift` —— 改卡片式 + 眼睛开关
  (或按需新建 `AuthPhoneField` / `AuthPasswordField`,同目录)
- `MeetPR/Sources/MeetPRApp.swift` —— 仅改 `preferredAppColorScheme` 未登录态那一行
- `Modules/AppShell/Tests/AppShellTests/Auth/` —— 相应测试
- `docs/design/login-v3/` —— 设计参照物 + 本卡(照常 commit,这是设计源入仓)

**不动**:`SignupView` / `AuthFormViewModel` 的校验逻辑 / `AuthRepository` / StudentKit / CoachKit
任何文件。

## 设计规格(390×844,左右 padding 24)

顶部叠一层 gold 微光:`radial-gradient(90% 44% at 50% 0%, gold500 @8%, transparent 70%)`。

### 上半 hero(`margin-top:44`,竖向 gap 18)

1. **字标** —— 用现成 `MeetPRMark(fontSize: 15)`。该组件**已经**实现了稿子那个「5px 描边 +
   底色挖空」的写法(八向偏移复制),不要另写。靠左。
2. **标题** —— 两行 `Better than` / `yesterday`,**同一档 44pt**、`.black`、行高 .96、
   字距 -.025em、`Color.MeetPR.textPrimary`。
   ⚠️ 现状是 `Better` 92pt + `than yesterday` 46pt **两档**,要改成单档两行。
3. **金色横杠** —— 44×3、圆角 2、`gold500`、距标题 16。

### 中间

`Spacer()` 撑开 —— 表单要被推到**屏幕下半**。
⚠️ 现状版式相反(表单紧贴 hero、空白留在按钮前),要对调。

### 下半(gap 14,底部留 26)

4. **说明文案** —— 「用手机号和密码登录。」13pt `textTertiary`。
   ⚠️ 现状文案是「**输**入手机号和密码登录。」,稿子去掉了「输」字。
5. **手机号卡片** —— 底 `surfaceCard`、1px `gold500` 描边、圆角 14、内距 12/14、
   外发光 `0 0 0 3px gold500@10%`(= 聚焦态)。内容:
   - 标签「手机号」mono 9.5pt / `.bold` / 字距 .14em / `goldText`
   - 一行:`+86`(mono 17 / `.medium` / `textTertiary`)│ 1px×18 竖线 `borderStrong`
     │ 输入框(mono 18 / `.medium` / 字距 .04em / `textPrimary`)
   - **`+86` 是纯展示前缀,不进 `viewModel.phone`**;校验仍是 `^1[3-9]\d{9}$` 的 11 位
6. **密码卡片** —— 底 `surfaceCard`、1px `borderDefault`、圆角 14、内距 12/14,
   阴影走 `MeetPRCardSurface(elevation: .card)`。内容:
   - 左:标签「密码」mono 9.5pt / `.bold` / 字距 .14em / `textMuted`;
     值 mono 18pt / `.semibold` / 字距 .14em
   - 右:34×34、圆角 9、底色 `surfaceRaised` 的眼睛按钮,切明文/密文(**新增能力**,现在没有)
7. **登录按钮** —— 高 54、圆角 14、`gold500` 实底、`inkOnGold` 文字 16pt `.bold` 字距 .02em、
   右侧 16pt 箭头、阴影 `0 6px 18px gold500@22%`。
   优先用现成 `GoldCTA`;对不上再自绘,并在 PR 里说明差在哪。
8. **条款行** —— 居中 12pt `textMuted`:「继续即表示同意 隐私政策」,
   「隐私政策」用 `goldText` + 下划线,指向 `AnalyticsPrivacyNotice.privacyPolicyURL`(仓内已有真 URL)。

### 交互态

- **聚焦态**:哪个字段获焦,哪个卡片走 `gold500` 描边 + 10% 外发光;另一个回 `borderDefault`。
  稿子画的是手机号聚焦。
- **错误态**:沿用 `viewModel.phoneError` / `passwordError` / `toastMessage`,
  颜色用 `Color.MeetPR.danger`,**不要**用已废的 `brandRed`。

## 约束

- ⚖️ **David 2026-07-30 拍板 A**:**删掉「忘记密码?」整行**(全仓零实现,不做死链);
  条款行**只写「隐私政策」,不写「服务条款」**(零 URL)。稿子上这两处按此裁剪——
  **这是有意偏离,不是漏做**,PR 里要写明。
- 按「一比一就是一比一」:**删掉 Apple Sign-In 灰态占位**、删掉手机号下面的 helper
  「中国大陆 11 位手机号」——稿子上都没有。
- 全部颜色走 `Color.MeetPR.*` v3 token。**禁止**出现 `brandRed` / `fgPrimary` / `fgSecondary` /
  `fgTertiary` / `surface2` / `border` / `bg` 这些 v2 旧 token,**禁止**硬编码 hex。
  稿子的浅色值与仓内 token 已逐个核对上:
  `#F5F6F8`=`bgBase`、`#FFFFFF`=`surfaceCard`、`#E5E7EB`=`borderDefault`、
  `#D1D5DB`=`borderStrong`、`#D97706`=`gold500`、`#9A4A06`=`goldText`、
  `#111827`=`textPrimary`、`#5C6371`=`textTertiary`/`textMuted`。
- **复用优先**:`MeetPRMark` / `MeetPRCardSurface` / `GoldCTA` / `MeetPRSpacing` / `MeetPRRadius` /
  `Font.MeetPR` 都已存在,不要新造平行组件。
- **保留全部** `accessibilityIdentifier`:`login.phone` / `login.password` / `login.submit` /
  `login.toast`(有测试依赖)。
- **主题只改未登录态**:`MeetPRApp.preferredAppColorScheme` 里 `guard case .authenticated` 那条
  fallback 从 `.dark` 改 `.light`。**不要动** coach 分支(恒暗)和 student 分支(读 `@AppStorage`
  外观偏好)。已知连带后果:教练登录会「浅→暗」闪一下,**David 已接受,不要为它加逻辑**。
- **不改** `AuthFormViewModel` 的任何校验规则。

## 验收标准

- `swift test` AppShell 全绿;`xcodebuild -configuration Demo` **0 warning**
- `swiftlint --strict` 干净(阈值以仓内 `.swiftlint.yml` 为唯一事实源)
- 模拟器截图四张:登录页浅色态 / 手机号聚焦态 / 密码明文态 / 手机号格式错误态
- grep 自证:`LoginView.swift` + `AuthSecureField.swift` 里零 v2 旧 token、零硬编码 hex
- 登录功能未回归(Demo 配置下走通登录路径)
- **不 commit、不 push**,改动留在工作区等 Claude 跑 review-loop
