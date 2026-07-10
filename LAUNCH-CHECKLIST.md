# MeetPR — Launch Checklist

> ## ⚠️ 现状 banner(2026-07-03)
>
> **本文件原为 V0 首次上 TestFlight 的一次性 operational checklist。TestFlight 路径(Stage A / B / F / G)已被现实取代** —— MeetPR 已上 TestFlight 内测(App id **6783772277**,1.0(5) 线上)。**日常发版不再走这套逐格勾选流程**,见仓库根 `RELEASES.md`(发布史)/ `NEXT-RELEASE.md`(进行中版本;二者随 PR #197 进 main)。
>
> **不要逐格勾选 A/B/F/G**:这些 stage 从未按字面逐条执行(实际发版走的是 archive + Xcode Organizer 上传 ASC 的简化流程),打勾 = 伪造记录。故全部保留未勾 + 标 `[SUPERSEDED]`,仅作历史存档。
>
> 本文件现分两部分:
> - **Part 1 — App Store 正式上架 checklist**:原 Stage C/D/E/H/I 提炼而成,**仍 forward-looking**(MeetPR 目前在 TestFlight,尚未上 App Store 正式版)。真要上架 App Store 时执行这部分。
> - **Part 2 — 历史 TestFlight 路径(superseded 存档)**:原 Stage A/B/F/G,一次性首上流程,已于 2026-06 完成,保留作历史。
>
> **关联**:
> - [`specs/021-apple-readiness-assets-and-signing/SPEC.md`](./specs/021-apple-readiness-assets-and-signing/SPEC.md) — build artifacts(icon / launch / privacy / Info.plist / signing)
> - [FOLLOWUPS.md F-002](./FOLLOWUPS.md)(本文档落地)/ [F-026 已完成](./FOLLOWUPS.md)(Apple Developer 已开通,TestFlight 已上)
>
> **创建于**:2026-05-10 · **现实取代 banner 加于**:2026-07-03

---

# Part 1 — App Store 正式上架 checklist（仍有效）

> MeetPR 已在 TestFlight,下面是从 TestFlight 走向 **App Store 正式上架** 还需要完成的部分(原 Stage C/D/E/H/I)。以下均为 forward-looking,**尚未执行**,保持未勾,真正上架时逐项完成。

## 上架-1 — 产品 metadata（原 Stage C）

App Store 上架要填一组 metadata + 图。这组**不进 build**,在 App Store Connect web 端填。

- [ ] **App Name**(中文):`MeetPR`(30 字内)
- [ ] **Subtitle**(中文,~30 字):待选,候选:
  - `力量举训练教练 + 学员双端`
  - `力量举:教练排计划,学员练得明白`
- [ ] **Promotional Text**(170 字,可随时改不需要重审):待写,简短介绍
- [ ] **Description**(4000 字):待写
  - 重点功能:教练排计划 / 主项变式 / 辅助动作三标签 / 强度填写 / 递进规则 / 周卡片横滑预览 / 学员端记录 + e1RM 曲线 + PR 推送
  - 强调 dual-sided(教练 + 学员)+ 力量举专用(SBD)+ 中文力量举术语
- [ ] **Keywords**(100 字符):`力量举,powerlifting,深蹲,卧推,硬拉,训练计划,教练,SBD,RPE,周期化`
- [ ] **Support URL**:待建(可临时用 GitHub repo 或 simple landing page)
- [ ] **Marketing URL**(可选):暂留空
- [ ] **Privacy Policy URL**(必需):待建
  - 选项 a:简单 markdown 静态页 hosted GitHub Pages / Cloudflare Pages
  - 选项 b:用 boilerplate 生成器(需法律 review,后续替换正式版)
- [ ] **App Category**:Primary `Health & Fitness`,Secondary `Sports`(已在 INFOPLIST_KEY_LSApplicationCategoryType `public.app-category.healthcare-fitness` 锁定)
- [ ] **Content Rights**:`Does Your App Contain, Show, or Access Third-Party Content?` → 按上架时实际情况答
- [ ] **Age Rating**:跑 questionnaire(no violence / no sexual content / no profanity / no gambling)→ 预期 4+

## 上架-2 — App Privacy（原 Stage D，必填，与 PrivacyInfo.xcprivacy 互补）

App Store Connect 的 Privacy questionnaire 跟 build 内的 `PrivacyInfo.xcprivacy` 是**两个东西**,都要填,且**必须口径一致**。

- [ ] **Data Collection**(基于 questionnaire):
  - ⚠️ **埋点上线后必须改口径**:V0 demo build 不收集数据时选 `No`。但**一旦自建埋点上线**(analytics 事件 → `POST /events`,见 spec 043-analytics + backend spec 008),App Store Connect 的 Data Collection **必须改为 `Yes`** 并按问卷勾选采集的数据类别(`NSPrivacyCollectedDataTypes`),**同时同步更新 build 内 `MeetPR/PrivacyInfo.xcprivacy`** —— 两处口径不一致是 Apple 审核拒因,也是合规红线(真 gate)。
  - 数据类别参考 [Apple 列表](https://developer.apple.com/app-store/app-privacy-details/)
- [ ] **Tracking**:当前无跨 app 追踪 → 选 No(同 `NSPrivacyTracking=false`);若未来接入归因 SDK 再改

## 上架-3 — 截图 + 视频（原 Stage E）

App Store 要求 6.7" iPhone + 6.5" iPhone(可选,Apple 现 deprecated 但有些 reviewer 还要)。

- [ ] 用最新 simulator 跑真实 happy path,**录 5-10 张截图**(教练排计划 + 学员端记录/进度,以现界面为准 —— 注意界面已经过 spec 034-042 + PR #180 1:1 redesign 重构,**不要沿用 V0 老截图脚本的 Step 编号**)
- [ ] 截图编辑(可选):加 Apple Frames + 中文标题层
- [ ] 6.5" 截图(降级):用对应 simulator 重跑同 happy path
- [ ] App Preview 视频(可选):30 秒 simulator 录屏
- [ ] **不要**:含真实学员名 / 真实电话号 / 真实头像(注入的 fake demo 数据是 OK 的)

## 上架-4 — 提交 Apple 审核（原 Stage H）

- [ ] App Store Connect → 1.0 Prepare for Submission tab
- [ ] **必填项**全填(从 上架-1/2/3 复制):Promotional Text / Description / Keywords / Support URL / Privacy Policy URL / Screenshots / Build
- [ ] Version Release:Manual(审核通过后手动 release)/ Automatic —— 首次正式上架建议 Manual
- [ ] **Sign-in required for review**:**Yes**
  - ⚠️ **已改真 auth**:app 现在是真实登录(spec 025 real-auth-login-keychain 已合),**不再是** DEMO_MODE 自动登录的 demo build。因此**必须给 Apple reviewer 一个可登录的 demo 账号**(用户名 + 密码填进 `Sign-in info` 字段),否则 reviewer 进不去会直接拒。
  - demo 账号:用一个 staging 测试账号(教练或学员端择一,或各给一个),密码在 Bitwarden(**不写进本文件**);上架前确认该账号在生产/staging 后端可登录且有种子数据可看。
- [ ] **Notes for Reviewer**(真 auth 版模板,替换原 DEMO_MODE 版):
  ```
  MeetPR is a dual-sided powerlifting app (coach + student). This build uses real
  authentication against our backend.

  Demo accounts for review (also entered in the Sign-in Information field):
    Coach account —  <username> / <password>
    Student account — <username> / <password>

  Suggested review path (coach):
  1. Log in with the coach account.
  2. Open a student, tap 排新计划 (create plan).
  3. Pick main-lift variants and accessory exercises, fill Week 1 intensity, add a
     progression rule, then swipe through the Week 1 → Week 4 preview cards.
  4. Publish the plan to the student.

  Suggested review path (student):
  1. Log in with the student account.
  2. Open today's workout, log a set (weight / reps / RPE), see the e1RM curve update.

  Data collection & privacy: see the App Privacy section. Camera/microphone are used
  only for optional set-video upload (student side), gated behind an explicit action.
  ```
  > 上架前把 `<username>/<password>` 换成真实 demo 账号,并再核对一遍当前 happy path 与界面(spec 034-042 / #180 之后 UI 已变)。
- [ ] 点 `Add for Review` → 答 Encryption Compliance / Content Rights 等 → 提交
- [ ] **审核期等待**:通常 24-48 小时,偶尔到 7 天;被拒 → 看 Resolution Center → 修 → 重提

## 上架-5 — Release（原 Stage I）

- [ ] 审核通过通知(邮件 + App Store Connect)
- [ ] 若选 Manual release,手动点 `Release this Version`
- [ ] App Store 正式版上线 = 正式上架完成(区别于 TestFlight 内测)
- [ ] 通知测试者 / 种子用户真实下载使用 + 收 feedback

---

# Part 2 — 历史 TestFlight 路径（superseded 存档）

> **这套 Stage A/B/F/G 是首次上 TestFlight 的一次性流程,已于 2026-06 完成(App id 6783772277,1.0(5) 线上)。日常发版不再走这里 —— 见 `RELEASES.md` / `NEXT-RELEASE.md`。以下全部保留未勾,仅作历史存档,不要逐格补勾。**

## Stage A — 环境前置 `[SUPERSEDED]`

> 已完成:Apple Developer 账号 active、Bundle ID `com.meetpr.app` register、App Store Connect App record 均已就位(否则 TestFlight build 传不上去)。见 [FOLLOWUPS.md F-026 已完成](./FOLLOWUPS.md)。签名 team = `28JW4SA779`。

- [ ] **Apple Developer 账号 active**(personal,$99/年)
- [ ] **Xcode 16+ 安装**(Swift 6 + iOS 17 SDK)
- [ ] **`xcodebuild` 命令行 + signing keychain 工作**
- [ ] **Bundle ID `com.meetpr.app` 已 register**(公司账号迁移走 [F-012](./FOLLOWUPS.md))
- [ ] **App Store Connect 账号 active**
- [ ] **App Store Connect 已创建 App record**

## Stage B — Build Artifacts 验证 `[SUPERSEDED]`

> spec 021 已落地(AppIcon / LaunchScreen / PrivacyInfo / signing / archive path)。archive 流程现由 ship 分支实操,不再逐条跑本 stage。⚠️ **Demo 构建必须显式 `configuration=Demo`**(否则默认 Debug 无 `DEMO_MODE`,登录会撞真 backend 报网络异常)。

- [ ] `build_run_sim Scheme=MeetPR-Demo`(注意 `configuration=Demo`)home screen 见 AppIcon + launch 闪屏
- [ ] `build_run_sim Scheme=MeetPR`(non-Demo)build 通过
- [ ] `xcodebuild archive -scheme MeetPR-Demo -configuration Demo ...` 跑通
- [ ] archive 内 .app bundle 含 AppIcon 编译产物 + PrivacyInfo.xcprivacy 嵌入
- [ ] `plutil -lint MeetPR/PrivacyInfo.xcprivacy` 通过

## Stage F — 上传 build `[SUPERSEDED]`

> 现走 Xcode Organizer → Distribute App → App Store Connect,已实操多次(1.0(1)..1.0(5))。日常发版见 NEXT-RELEASE.md 的 ship 流程。

- [ ] Xcode → Window → Organizer → Archives 看到 archive 的 build
- [ ] `Distribute App` → `App Store Connect` → `Upload`(Automatically manage signing)
- [ ] 等 upload + Apple processing;`Missing Compliance` 已设 `ITSAppUsesNonExemptEncryption=NO` 应自动过
- [ ] build status `Ready to Submit`

## Stage G — TestFlight 内测 `[SUPERSEDED]`

> 已完成:内测者已在 TestFlight 装 MeetPR 并使用(Neice 免审 / Ceshi 需审组)。反馈走 WeChat/Slack,不进 GitHub issue。

- [ ] App Store Connect → TestFlight → Internal Testing → 加测试者
- [ ] 测试者装 TestFlight app + 接受 invite + 装 MeetPR
- [ ] 收集 feedback(WeChat / Slack)
- [ ] P0 bug → fix → 新 build,重复

---

## 已知风险 / 应对（App Store 正式上架时参考）

| 风险 | 概率 | 应对 |
|---|---|---|
| Apple 审核拒绝(no real value / clone / metadata 不完整 / reviewer 登不进) | 中 | happy path 完整可点;**给 reviewer 可用 demo 账号**(真 auth 后必须);metadata 齐全;被拒认真读 reason 修 |
| Privacy 口径不一致(App Privacy questionnaire vs PrivacyInfo.xcprivacy) | 中 | 埋点上线后两处同步改(上架-2 已标注);发版前 diff 一遍 |
| Bundle ID `com.meetpr.app` 公司账号迁移 | 低 | 走 [F-012](./FOLLOWUPS.md),迁移时保持 bundle ID 不变 |
| Personal Apple Developer 账号过期 | 低 | $99/年提前续费 |
| 截图被拒(尺寸 / 含真人头像 / 违规字眼)| 中 | simulator 录,fake 学员名,review 一遍 |
| Privacy Policy URL 没准备好 | 中 | 先 GitHub Pages 一份简单 markdown,后续找律师写正式版 |

---

## 已完成 ✅

- [x] **2026-05-10** 创建本 LAUNCH-CHECKLIST.md(F-002 触发后 action 落地)
- [x] **2026-06(不晚于 6/24)** 首次上 TestFlight(App id 6783772277)—— Stage A/B/F/G 一次性流程实质完成,日常发版转 RELEASES.md/NEXT-RELEASE.md 路径(见 [F-026 已完成](./FOLLOWUPS.md))
- [x] **2026-07-03** 加现实取代 banner + 拆分 Part 1(正式上架)/ Part 2(TestFlight 历史存档)
