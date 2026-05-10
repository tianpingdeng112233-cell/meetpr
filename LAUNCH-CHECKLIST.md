# MeetPR — V0 Launch Checklist (TestFlight → App Store)

> **目的**:V0 ship 流程的 operational checklist。Spec 021 是构建 iOS bundle artifacts 的实装,本文档是把 build → archive → TestFlight → 审核 → ship 的**人工流程**串起来,避免 ship 时临时翻文档/抓瞎。
>
> **关联**:
> - [`specs/021-apple-readiness-assets-and-signing/SPEC.md`](./specs/021-apple-readiness-assets-and-signing/SPEC.md) — build artifacts (icon / launch / privacy / Info.plist / signing)
> - [`~/Brain/wiki/projects/MeetPR/roadmap.md`](~/Brain/wiki/projects/MeetPR/roadmap.md) — V0 6 周计划,本 checklist 服务 W23-25
> - [FOLLOWUPS.md F-002](./FOLLOWUPS.md) — 本文档落地 = F-002 action 完成
>
> **创建于**:2026-05-10

---

## Stage A — 环境前置(可现在 / 任意时刻验证)

- [ ] **Apple Developer 账号 active**(personal,$99/年)
  - 验证:登 https://developer.apple.com/account 看 Membership status = `Active` + Team ID 可读
  - 公司账号迁移走 [F-012](./FOLLOWUPS.md),V0 不强制
- [ ] **Xcode 16+ 安装**(Swift 6 + iOS 17 SDK 必需)
  - 验证:`xcodebuild -version` 输出 `Xcode 16.x`
- [ ] **`xcodebuild` 命令行 + signing keychain 工作**
  - 验证:`xcodebuild -project MeetPR.xcodeproj -scheme MeetPR-Demo -showBuildSettings | grep DEVELOPMENT_TEAM` 能找到 team ID,或在 Xcode GUI 选了 team 后再跑
- [ ] **Bundle ID `com.meetpr.app` 已 register**(Apple Developer Portal → Identifiers)
  - 验证:https://developer.apple.com/account/resources/identifiers/list 能看到 `com.meetpr.app`
  - F-012 触发后改公司账号
- [ ] **App Store Connect 账号 active**(personal Apple ID 同步)
  - 验证:https://appstoreconnect.apple.com 能登,Users and Access 你是 Admin
- [ ] **App Store Connect 已创建 App record**
  - App Store Connect → My Apps → + → New App
  - Platform: iOS
  - Name: `MeetPR`(若占用,试 `MeetPR Lifting` / `MeetPR 力量`)
  - Primary Language: Simplified Chinese (中文 - 简体)
  - Bundle ID: `com.meetpr.app`
  - SKU: `meetpr-ios-v0`(任意 unique)
  - User Access: Full Access

---

## Stage B — Build Artifacts 验证(spec 021 落地后跑)

- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo`(iPhone 17 simulator)home screen 见占位 AppIcon + launch 闪屏 brand-red 背景
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR`(non-Demo)build 通过
- [ ] **`xcodebuild archive -scheme MeetPR-Demo -configuration Demo -archivePath /tmp/MeetPR-Demo.xcarchive` 跑通**,输出 `** ARCHIVE SUCCEEDED **`
- [ ] archive 内 .app bundle 含 AppIcon 编译产物 + PrivacyInfo.xcprivacy 嵌入
  - `unzip -l /tmp/MeetPR-Demo.xcarchive/Products/Applications/MeetPR.app/Info.plist` 看到 INFOPLIST_KEY_* 全填
  - `find /tmp/MeetPR-Demo.xcarchive -name PrivacyInfo.xcprivacy` 找到 1 份
- [ ] `plutil -lint MeetPR/PrivacyInfo.xcprivacy` 通过
- [ ] spec 020 CHECKLIST.md 15 步 manual happy path 全过(spec 021 不破上游 happy path)

---

## Stage C — 产品 metadata(W23 准备)

App Store 上架要填一组 metadata + 图。这组**不进 build**,在 App Store Connect web 端填。

- [ ] **App Name**(中文):`MeetPR`(30 字内)
- [ ] **Subtitle**(中文,~30 字):待选,候选:
  - `力量举训练教练 + 学员双端`
  - `力量举:教练排计划,学员练得明白`
- [ ] **Promotional Text**(170 字,可随时改不需要重审):待写,V0 简短介绍
- [ ] **Description**(4000 字):待写
  - V0 重点功能:教练排计划 / 主项变式 / 辅助动作三标签 / W1 强度填写 / 9 类递进规则 / 周卡片横滑预览
  - 强调 dual-sided(教练 + 学员)+ 力量举专用(SBD)+ 中文力量举术语
- [ ] **Keywords**(100 字符):`力量举,powerlifting,深蹲,卧推,硬拉,训练计划,教练,SBD,RPE,周期化`
- [ ] **Support URL**:待建(可临时用 GitHub repo 或 simple landing page)
- [ ] **Marketing URL**(可选):暂留空
- [ ] **Privacy Policy URL**(必需):待建
  - V0 选项 a:简单 markdown 静态页 hosted GitHub Pages / Cloudflare Pages
  - V0 选项 b:用 https://app-privacy-policy-generator.firebaseapp.com 生成 boilerplate(需法律 review,V0.1+ 替换正式版)
- [ ] **App Category**:Primary `Health & Fitness`,Secondary `Sports`(已经在 INFOPLIST_KEY_LSApplicationCategoryType `public.app-category.healthcare-fitness` 锁定)
- [ ] **Content Rights**:check `Does Your App Contain, Show, or Access Third-Party Content?` → No(V0 no third-party content)
- [ ] **Age Rating**:跑 questionnaire,V0 答 No 全部(no violence / no sexual content / no profanity / no gambling)→ 4+

---

## Stage D — App Privacy(必填,与 PrivacyInfo.xcprivacy 互补)

App Store Connect 的 Privacy questionnaire 跟 build 内的 PrivacyInfo.xcprivacy 是**两个东西**,都要填。

- [ ] **Data Collection**(基于 questionnaire):
  - V0 选 `No, we do not collect data from this app`(因为 V0 demo build 不收集)
  - V0.1+ 接 backend 后改为 Yes 并按问卷填(NSPrivacyCollectedDataTypes 类别参考 [Apple 列表](https://developer.apple.com/app-store/app-privacy-details/))
- [ ] **Tracking**:V0 选 No(同 NSPrivacyTracking=false)

---

## Stage E — 截图 + 视频(W23 准备)

App Store 要求 6.7" iPhone(iPhone 15 Pro Max)+ 6.5" iPhone(iPhone 11 Pro Max,可选,Apple 现 deprecated 但有些 reviewer 还要)。

- [ ] iPhone 17 Pro Max simulator 跑 V0 happy path,**录 5-10 张截图**:
  1. Launch screen / 教练 home
  2. Step 0 选学员
  3. Step 4 添加辅助动作(三标签 facets 展示)
  4. Step 5 W1 强度(主项)
  5. Step 6 规则配置
  6. Step 7 周卡片横滑(W2 状态最有视觉冲击)
  7. (可选)长按 Peek 弹 contextMenu
- [ ] 截图编辑(可选):加 Apple Frames(`https://apps.apple.com/app/frames-app/id1487719414`)+ 中文标题层
- [ ] 6.5" 截图(降级):用 iPhone 11 Pro Max simulator 重跑同 happy path
- [ ] App Preview 视频(可选,V0 不必):30 秒 simulator 录屏
- [ ] **不要**:含真实学员名 / 真实电话号 / 真实头像(InMemoryPlanRepository.preview 的 fake names 是 OK 的)

---

## Stage F — 上传 build(W23 关键步骤)

- [ ] 切回 Xcode GUI(`xcodebuild` 命令行能跑 archive 但 upload 用 Xcode Organizer 最稳)
  - Xcode → Window → Organizer → Archives 看到刚 archive 的 build
- [ ] 点 `Distribute App` → `App Store Connect` → `Upload`
  - Distribution Options:Automatically manage signing(personal account)
  - Re-sign:Automatic
- [ ] 等 upload 完成(几分钟)+ Apple processing(10-30 分钟,看 App Store Connect → TestFlight tab Build status)
- [ ] **若 build status `Missing Compliance`**:在 build 详情里答 Export Compliance(本 spec 已设 ITSAppUsesNonExemptEncryption=NO,应自动通过免填)
- [ ] **若 build status `Invalid Binary`**:点详情看 Apple 反馈,常见原因:
  - PrivacyInfo.xcprivacy 缺 / 格式错 → 修 + 重 archive + 重 upload
  - AppIcon 缺 1024 尺寸 → 同上
  - Bundle ID 不匹配 → check pbxproj
- [ ] **若 build status `Ready to Submit`**:可以进 Stage G

---

## Stage G — TestFlight 内测(W23-24)

- [ ] App Store Connect → TestFlight → Internal Testing → 加测试者(David / 肖天宇 / 里欧 etc.)
- [ ] 每个测试者邮箱收到 TestFlight invite,在 iPhone 上装 TestFlight app + 接受 invite + 装 MeetPR
- [ ] 测试者跑 spec 020 CHECKLIST.md 15 步
- [ ] 收集 feedback(Slack / WeChat,**不**直接进 GitHub issue 防 dox 测试者)
- [ ] P0 bug → fix → archive → upload → 新 build,重复
- [ ] **3 天内拿到 ≥1 个测试者过完 happy path**(如果没人有 iPhone 装 TestFlight,这一步阻塞)

---

## Stage H — 提交 Apple 审核(W24-25)

- [ ] App Store Connect → 1.0 Prepare for Submission tab
- [ ] **必填项**全填(都从 Stage C / D / E 复制):
  - Promotional Text / Description / Keywords / Support URL / Privacy Policy URL
  - Screenshots × 6.7" + 6.5"(若 6.5" 占位用空白图,Apple 可能不通过)
  - Build:选 Stage F 上传的那个
  - Version Release:Manual(避免审核通过自动 release)/ Automatic(审核通过立刻上架)— V0 选 Manual
  - Sign-in required for review:**Yes**(Demo build 自动登录,跟 Apple reviewer 说"app 启动直接进教练界面,无 login UI")
  - Sign-in info:留空(或写 N/A)+ 在 `Notes for Reviewer` 解释
- [ ] **Notes for Reviewer**(关键!写明 V0 demo 性质 + happy path):
  ```
  This is V0 demo build for TestFlight evaluation. The app launches directly to the coach planning screen
  without login (DEMO_MODE compile flag bypasses auth for demonstration). Real backend integration is V0.1+.

  Happy path to evaluate:
  1. App launches to "教练端" home screen
  2. Tap "排新计划" button
  3. Step 0: select a demo student (5 pre-seeded Chinese names)
  4. Steps 1-3: choose 4-week plan duration / SBD frequency / main lift variants
  5. Step 4: add accessory exercises with 3-facet filtering
  6. Step 5: fill Week 1 intensity for each exercise
  7. Step 6: add a progression rule (e.g. weight +5kg)
  8. Step 7: swipe through Week 1 → Week 4 cards to preview the plan

  No data is collected (PrivacyInfo.xcprivacy declares NSPrivacyTracking=false / no NSPrivacyCollectedDataTypes).
  No camera / microphone / photo / location permissions requested.
  No third-party content / analytics / ad SDK.
  ```
- [ ] 点 `Add for Review` → 答几个 yes/no(Encryption Compliance / Idea Submission / Content Rights)→ 提交
- [ ] **审核期等待**:通常 24-48 小时,偶尔到 7 天
- [ ] 审核被拒 → 看 Resolution Center 反馈 → 修 → 重提

---

## Stage I — Release(V0 ship)

- [ ] 审核通过通知(邮件 + App Store Connect)
- [ ] 由于 Stage H 选 Manual release,需要手动点 `Release this Version`
- [ ] **2026-06-20 前**:V0 in App Store(不是 TestFlight)= V0 ship 完成
- [ ] FOLLOWUPS.md F-002 移到 已完成
- [ ] roadmap.md V0 路径 全部 ✅
- [ ] 通知 xty / 肖天宇 / 里欧 真实下载使用 + 收 feedback

---

## 已知风险 / 应对

| 风险 | 概率 | 应对 |
|---|---|---|
| Apple 审核拒绝(常见 reasons:no real value / clone of existing / metadata 不完整) | 中 | V0 demo path 完整可点,Notes for Reviewer 写清 demo 性质 + happy path,降低拒率。被拒先认真读 reason 修 |
| Bundle ID `com.meetpr.app` 已被人占用 | 低 | 提前在 Apple Developer Portal 查;占用就改 `com.meetpr.app1`(F-012 公司账号迁移时再换 final) |
| Personal Apple Developer 账号过期 | 低 | $99/年,提前续费 |
| App Store Connect API 工具链问题 | 低 | 全程走 Xcode Organizer GUI,不依赖 CLI tool |
| Privacy Policy URL 没准备好 | 中 | V0 用 GitHub Pages 一份简单 markdown 就够,V0.1+ 找律师写正式版 |
| 截图被拒(尺寸 / 含真人头像 / 含违规字眼)| 中 | 用 simulator 录,fake 学员名,review 一遍 |
| Reviewer 不会读中文 | 低 | App Store metadata 有"primary language",中文 reviewer pool 较活跃 |

---

## 已完成 ✅

- [x] **2026-05-10** 创建本 LAUNCH-CHECKLIST.md(F-002 触发后 action 落地)
