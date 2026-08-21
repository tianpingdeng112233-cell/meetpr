# 074 — Global 轨三通道登录(W4:SiwA + 邮箱密码 + Google)

- **状态**: InReview(2026-08-16 实装完成,等待 Claude review;⚖️David 授权今夜自主决策整波跑完,PR CI 绿自合;
  决策台账=`~/Projects/scratch/w4-login-ui-decisions-2026-08-16.md`)
- **来源**: ⚖️08-14 登录拍板(Global track = SiwA+邮箱+Google,无手机号);backend W1(#241)/
  W2(#244)/时区(#248)已全部上线 staging;#322 Global 构建轨已合(base 含 26d80307)。
- **级别**: T2(单模块 AppShell+Networking,无新依赖,无迁移;CN 零回归红线)

## 目标

`MeetPR-Global` scheme 打出的包,登录页=三通道(Sign in with Apple / 邮箱密码 / Google),
全英文;能注册(邮箱)、能登录(三通道)、能找回密码(6 位码);成功后 `session.state = .authenticated`
进既有 app。CN 四个 configuration(Debug/Release/Demo/DemoStudent)行为与 UI **逐字节零变化**。

## 范围

### A. Networking 层

1. `Endpoint` 枚举加 case:`/auth/challenge`、`/auth/apple`、`/auth/google`、
   `/auth/email/register`、`/auth/email/login`、`/auth/email/forgot`、`/auth/email/reset`、
   `PATCH /me/timezone`。
2. DTO 按后端线格式(⚠️仓内教训:snake_case 是 pin 死的线格式,AuthDTOs.swift:26-30 注释):
   - challenge 响应 `{ nonce, expiresAt }`;
   - apple 请求 `{ identityToken, nonce, role, authorizationCode?, timezone? }`(nonce **必带**,
     backend fail-shut);google 请求 `{ idToken, nonce?, role, timezone? }`;
   - email register `{ email, password, role, timezone? }` / login `{ email, password }` /
     forgot `{ email }` / reset `{ email, code, newPassword }`;
   - 三通道与 email 的成功响应复用既有 `AuthResultDTO`(线格式同 CN `/auth/login`,camelCase
     `accessToken`——**以 backend `global.ts` 实际序列化为准,实装时先 curl staging 核对一次**,
     staging=http://121.40.160.241:3000,可用假 token 打 401 面核对错误码形状)。
   - 错误码映射进既有 `AuthErrorCode` 面:`AUTH_INVALID_IDENTITY_TOKEN`、
     `AUTH_REGISTRATION_DISABLED`、`AUTH_REGISTRATION_NOT_ALLOWED`、`AUTH_EMAIL_TAKEN`、
     `AUTH_INVALID_RESET_CODE`、`INVALID_TIMEZONE`(新增枚举值,UI 给人话文案)。
3. `APIClient+Auth` 加对应方法,走既有 `postJSON` 私有通道;`PATCH /me/timezone` 带鉴权。

### B. AuthRepository / Session

4. `AuthRepository` 协议加方法(建议聚合为少数入口,如
   `signInWithApple(identityToken:nonce:authorizationCode:timezone:)`、
   `signInWithGoogle(idToken:timezone:)`、`registerWithEmail(...)`、`loginWithEmail(...)`、
   `requestPasswordReset(email:)`、`resetPassword(email:code:newPassword:)`、
   `fetchChallenge()`)。⚠️**雷**:协议一改,`InMemoryAuthRepository`、`DemoAuthRepository`
   (Demo/DemoStudent 编译门)必须同步实现——Demo 全部恒返 `fixedResult()` 与现状语义一致。
5. `Session` 加对应通道方法,复用 `persist(_:generation:)` 与代际守卫;成功路径与 CN login 同构。
6. **时区契约(spec 042)**:三通道注册/登录请求带 `TimeZone.current.identifier`;
   `Session.bootstrap()` 成功恢复会话后,若设备时区 ≠ 上次上报值(UserDefaults 记上次上报),
   `PATCH /me/timezone` 一次,静默失败不打扰用户。

### C. UI(全新文件,Global 轨专用,英文字面量)

7. `AuthFlowView` 按 `MeetPRBuildTrack` 分流:Global → `GlobalLoginView`,否则现有 `LoginView`
   (CN 文件一行不动)。
8. `GlobalLoginView`:沿用 v3 浅色视觉语言(hero=MeetPRMark+"Better than yesterday"+金杠,
   与 CN LoginView 同构);内容自上而下=SiwA 按钮(**系统 `ASAuthorizationAppleIDButton`**,
   SignInWithAppleButton SwiftUI 版,黑底 style,HIG 硬要求勿自绘)→ "Continue with Google"
   (自绘按钮,v3 卡片样式)→ 分隔 "or" → email+password 卡片(复用 `AuthSecureField`/卡片样式,
   AuthPhoneField 不用)→ 金色 CTA "Sign in" → 底行链接 "Create account" / "Forgot password?"
   → 隐私政策行(链接 https://meetpr.app/privacy/en)。
9. `GlobalRegisterView`:email / password(沿用 CN PasswordSchema 同规则提示)/ CTA "Create
   account"。**角色固定 `coached_student`,不出角色选择**(决策 8:UK 测试形态=教练带学员,
   教练号预置;「自己练」档是 CN 线 David 挂账待拍板项,Global 不出这档)。
10. `GlobalForgotPasswordView`:两步——①输 email → "Send code"(恒成功文案:If an account
    exists, we've sent a code,防存在性探测的 UI 面配合)→ ②输 6 位码+新密码 → "Reset
    password" → 成功回登录页 toast "Password updated, sign in with your new password"。
11. 错误 toast 沿用既有 toast 机制;网络错误/通道未配(503)给通用 "Sign-in is temporarily
    unavailable"。

### D. SiwA / Google 流程

12. SiwA:先 `fetchChallenge()` 拿 nonce → `SignInWithAppleButton` 的 request 里
    `nonce = SHA256(challengeNonce)`(hex)——**与 backend 校验口径一致:identityToken 内
    nonce=sha256(明文),请求体带明文 nonce**(以 spec 039/#241 实装为准,实装时读
    backend `global.ts` 的 challenge 校验逻辑核对 hash 方向,别猜);拿到
    `identityToken`+`authorizationCode` 透传 backend。
13. Google:PKCE 授权码流,零 SDK——`ASWebAuthenticationSession` 打
    `accounts.google.com/o/oauth2/v2/auth`(client_id=1070098660233-mntdt18uc68d9gdc3di1f07s2pbofncs
    .apps.googleusercontent.com,redirect=倒置 scheme `com.googleusercontent.apps.1070098660233-mntdt18uc68d9gdc3di1f07s2pbofncs:/oauth2redirect`,
    scope=`openid email profile`,code_challenge=S256)→ 换 token 端点
    `oauth2.googleapis.com/token`(无 secret)→ 取 `id_token` 交 backend。
    倒置 scheme 需在 **Global configuration 专属**注册(per-configuration
    `INFOPLIST_KEY_CFBundleURLSchemes` 或 Info.plist 变量注入,照 #322 的 per-config 手法,
    **CN 产物不得出现该 scheme**)。
14. 两个网络流的 OAuth 逻辑放 `Modules/AppShell/Sources/AppShell/Auth/Global/` 下独立文件,
    fetch 层可注入 mock。

### E. 配置与清理

15. 新建 `MeetPR/MeetPRGlobal.entitlements`(aps-environment + `com.apple.developer.applesignin`
    =Default),**仅 Global configuration** 覆写 `CODE_SIGN_ENTITLEMENTS`;CN 四配置仍指旧文件
    (决策 11:共享文件加 capability 会撞 CN 签名)。pbxproj 改动用 ruby xcodeproj gem 或
    直接手改并双向 build 验证(仓规:改结构优先 gem)。
16. **E.164 遗留清理**(决策 12,#322 是 08-13 拍板前设计):删 `PhoneValidationStyle.globalE164`
    分支、`AuthFormViewModel` 四条 Global 文案切换与 `phoneValidationStyle` 注入面、
    `AuthFormViewModelTests` 的 Global @Test、`BuildConfigTests` 对应断言;
    `MeetPRBuildTrack` 读取与 `BuildConfig` 保留(职责=AuthFlowView 分流)。
    `AuthFormViewModel.swift:122` 的 CN 硬编码 toast 保持原样(CN 行为零变化)。

## 不在范围

- CN 注册入口修复(#145 误删,已单列任务卡给 David);CN 任何 UI/文案改动;
- 「自己练」档拍板(CN 线挂账,David 的);AppShell 本地化基建(英文化卡 A 范围);
- Apple 授权吊销 UI(删号已有,backend 已接);磅制/教练端隐藏(后续卡);
- SiwA/Google 的真机端到端(需真 Apple ID/Google 账号,留 David 真机 smoke)。

## 验收标准

1. **CN 零回归(红线)**:Debug/Release/Demo/DemoStudent 四配置 build 过;AppShell+Networking
   全测试绿;CN LoginView/SignupView/AuthFlowSnapshotTests 既有断言零改动(E.164 清理涉及的
   Global-only 测试除外);`xcodebuild -configuration Release` 产物无新 URL scheme、无
   applesignin entitlement。
2. Global scheme build 过;模拟器跑起来登录页=三通道英文 UI(截图);email 注册/登录对
   staging 真后端全链路走通(造 is_test 邮箱号——staging 邮箱注册闸当前 fail-shut 关着,
   实装内用 mock 层单测覆盖全链;真后端实证以 401/403 错误面形状核对契约即可,别为测试开生产闸)。
3. SiwA/Google:单测覆盖(challenge→hash→请求构造/PKCE 参数与 token 换取解析,mock fetch);
   模拟器可点出 Apple 授权弹窗(能弹=entitlement+按钮接线对,授权本身不强求)。
4. 忘记密码两步 UI 流转与错误面(mock)全覆盖;`AUTH_INVALID_RESET_CODE` 有人话文案。
5. 时区:注册请求体带 timezone 的断言;bootstrap 时区漂移触发 PATCH 的单测。
6. swiftlint --strict + swift-format 零违规;spec 文件本身过 prettier。

## 参考

- backend 契约:MeetPR-backend `src/routes/auth/global.ts`、`email-recovery.ts`、`me.ts`
  (staging 已部署,可 curl 核对错误面);spec 039/040/042(backend 仓 specs/)。
- 视觉参照:`LoginView.swift`(v3 定稿)、`docs/design/login-v3/CARD.md`。
- 决策台账:`~/Projects/scratch/w4-login-ui-decisions-2026-08-16.md`(13 条,含每条原因)。
