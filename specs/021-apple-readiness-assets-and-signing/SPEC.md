# 021 — Apple Readiness Assets + Signing(W22 关键路径)

- **状态**: InReview
- **PR**: [#44](https://github.com/tianpingdeng112233-cell/meetpr/pull/44)
- **来源**:
  - [`~/Brain/wiki/projects/MeetPR/roadmap.md`](~/Brain/wiki/projects/MeetPR/roadmap.md) §V0 周计划 W22 — App icon / Launch screen / Privacy manifest / Bundle ID + TestFlight signing 准备
  - 上游 [spec 020 V0 demo orchestration](../020-v0-demo-orchestration/SPEC.md) — Demo build / DEMO_MODE 已就位,本 spec 接力做 Apple-ready 资产
  - [FOLLOWUPS.md F-002](../../FOLLOWUPS.md) — TestFlight 提交条件已具备,本 spec 是 F-002 的物质前置(本 spec 完成后,F-002 LAUNCH-CHECKLIST.md 可以单独起草作为 ship 流程清单)
  - [FOLLOWUPS.md F-012](../../FOLLOWUPS.md) — Bundle ID 公司账号迁移(本 spec **不触发** F-012,仍用 personal Apple Developer 账号 + `com.meetpr.app` placeholder)
  - [FOLLOWUPS.md F-013](../../FOLLOWUPS.md) — Logo SVG 真实资产(本 spec **不触发** F-013,先用占位 SF Symbol 资产,真 logo 落定后再换)
  - [ADR-005 §iOS architecture](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — iPhone-first / 393pt 基线 → 本 spec 锁定 V0 portrait only
  - [Apple App Store Required Reasons API 文档(2024 强制)](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)
  - [Apple Privacy Manifest 文档](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## 目标

把 V0 demo build 从"simulator 跑通"升级到"**TestFlight 可提交 Apple 审核**"状态。具体地,补齐 Apple 必需的 build artifacts(icon / launch screen / privacy manifest)+ 锁定签名配置 + 调整 Info.plist 跟 V0 设计对齐。

落地后:

```
xcodebuildmcp build_run_sim Scheme=MeetPR-Demo  → simulator 跑通(spec 020 已做到)+ 真 AppIcon 显示
                                                +  真 LaunchScreen
                                                +  竖屏锁定(不再 landscape)
xcodebuild archive -scheme MeetPR-Demo -configuration Demo \
   -archivePath MeetPR-Demo.xcarchive            → archive build 成功(本 spec 验证目标)
                                                + 含 AppIcon.appiconset 编译产物
                                                + 含 PrivacyInfo.xcprivacy 嵌入 .app bundle
                                                + 签名链路通(personal Apple Developer team)
```

接 W23 release engineering(TestFlight upload / App Store Connect 配置 / Apple 审核提交)= 工程任务,**不在本 spec 范围**。

## 范围

### 做什么

#### 1. AppIcon.appiconset(`MeetPR/Assets.xcassets/AppIcon.appiconset/`)

| 文件 | 作用 |
|---|---|
| `Contents.json` | iOS 17+ single 1024×1024 + dark + tinted variants(Apple HIG 2024 推荐 — 单 size,系统自动 scale) |
| `meetpr-icon-1024.png`(占位)| 1024×1024 PNG, sRGB, no alpha. **不是真 logo**,而是占位:深红底(`#E5221E`,跟 design system brand-red 一致)+ 白色 SF Symbol 类似 "figure.strengthtraining.traditional" 渲染 + 留白 ≥ 10%. 真 logo 落定走 F-013 触发再换 |
| `meetpr-icon-1024-dark.png`(占位)| 同上 dark 变体(深底浅 mark)|
| `meetpr-icon-1024-tinted.png`(占位)| 同上 tinted 变体(灰度,iOS 18 system tint 用)|

> **iOS 17+ 单 size icon 模式**:Apple HIG 自 iOS 17 起,AppIcon.appiconset 只需 1024×1024 一份(系统 scale 出所有 device 尺寸)。比之前 12+ 个尺寸每个手 export 简化很多. Codex 用 `xcrun actool` 或直接在 Contents.json 声明 `"size": "1024x1024"` + `"idiom": "universal"` + `"platform": "ios"` 即可.

> **占位资产生成方法**(Codex 实装时 3 选 1):
> - **(a) 用 SF Symbol 渲染 1024 PNG**(`xcrun symbol` / Image Renderer),最简单
> - **(b) 用 Python PIL / SwiftUI ImageRenderer 程序化生成**,自动配色
> - **(c) 用 macOS Preview / Pixelmator 手画 1024×1024**(若 (a)(b) 都 stuck)
> 选 (a) 优先. 占位质量不需要 polish,真 logo F-013 后换.

#### 2. AccentColor 已存在,但**审视一遍**(`MeetPR/Assets.xcassets/AccentColor.colorset/`)

现有 AccentColor.colorset 是空 placeholder. V0 设为 brand-red `#E5221E`(跟 DesignSystem token 一致),light + dark 模式同色(brand color 不随系统变).

#### 3. LaunchScreen 配置(无 storyboard,用 Info.plist `UILaunchScreen` dict)

修 Info.plist / build settings:
- V0 使用显式 `MeetPR/Info.plist` 内的 `UILaunchScreen` dict,不使用 storyboard
- `UILaunchScreen` → `UIColorName = AccentColor` → launch 时背景 = AccentColor(brand-red)
- `INFOPLIST_KEY_UILaunchScreen_UIColorName = "AccentColor"` 仍保留在 build settings 作为 Xcode Info tab 对齐值,但最终落地以 `MeetPR/Info.plist` dict 为准
- (可选)`INFOPLIST_KEY_UILaunchScreen_UIImageName = "MeetPRWordmark"` — 居中显示 wordmark 图. **V0 不放图(占位资产质量低,空背景反而干净)**,留 F-013 后开

> **不用 storyboard**: 现代 iOS 17+ 项目优先 Info.plist UILaunchScreen dict,storyboard 已经 deprecated 了 launch screen 用法.
> **实现 note**:`INFOPLIST_KEY_UILaunchScreen_Generation = YES` 在本机 Xcode 仅生成空 `UILaunchScreen` dict;尝试 `INFOPLIST_KEY_UILaunchScreen_UIColorName` 会产出错误的嵌套空 dict. 为保证 archive 内最终 Info.plist 含 `UIColorName = AccentColor`,本 spec 实装改为显式 `MeetPR/Info.plist` + `GENERATE_INFOPLIST_FILE = NO`.

#### 4. PrivacyInfo.xcprivacy(`MeetPR/PrivacyInfo.xcprivacy`)

Apple 自 2024-05-01 强制要求所有 App Store 提交的 build 含 PrivacyInfo.xcprivacy(隐私清单). 内容声明:

##### 4.1 NSPrivacyTracking
```xml
<key>NSPrivacyTracking</key>
<false/>
```
V0 不做用户跟踪(无第三方 analytics / no ad SDK / no fingerprinting).

##### 4.2 NSPrivacyTrackingDomains
```xml
<key>NSPrivacyTrackingDomains</key>
<array/>
```
空数组(V0 no tracking).

##### 4.3 NSPrivacyCollectedDataTypes
V0 demo build 不收集任何个人数据(InMemoryPlanRepository + DemoTokenStore 全本机). 但**真上线 V0.1+ 接 backend 后会收集**:
- 训练数据(动作 / 重量 / 次数)— 关联 user account
- 健身房 / 训练时段(可选)
- 视频(学员录制,V0.1+)

V0 build 这个数组**先填空 + 加注释说明**,V0.1+ 真接 backend 时按 Apple [Privacy questionnaire](https://developer.apple.com/app-store/app-privacy-details/) 答案补.

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array/>
<!-- V0 demo build 不收集任何数据(本机 InMemoryRepository + DemoTokenStore).
     V0.1+ 接 backend 时,按 Apple Privacy questionnaire 答案补充:
     - NSPrivacyCollectedDataTypeOtherUserContent (训练数据)
     - NSPrivacyCollectedDataTypeUserID (account)
     - 等等 -->
```

##### 4.4 NSPrivacyAccessedAPITypes
Apple 2024 引入的 Required Reasons API 合规清单. 即便 V0 demo 不调网络,只要用了某些系统 API(File Timestamp / System Boot Time / User Defaults / Disk Space)就要声明 reason. 检查 V0 实际使用:

| API | V0 是否用 | reason code |
|---|---|---|
| File Timestamp APIs | 间接(SwiftData 内部用)| `C617.1` (App functionality) |
| System Boot Time APIs | 否(V0 no analytics / crash reporting)| 不声明 |
| Disk Space APIs | 否 | 不声明 |
| User Defaults | 是(`DraftStore` 用于本机草稿恢复状态)| `CA92.1` (app 自有 defaults) |
| Active Keyboard | 否 | 不声明 |

V0 PrivacyInfo.xcprivacy 声明 File Timestamp(SwiftData / DraftStore) + UserDefaults(`DraftStore` 本机草稿恢复状态):

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>C617.1</string>
        </array>
    </dict>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>
</array>
```

> Codex 实装时**必须扫一遍**实际代码用到的系统 API,验证是否需要追加声明. 用 `grep -r "Date()"`、`UserDefaults`、`FileManager` 等关键字定位.

#### 5. INFOPLIST_KEY 调整(在 `MeetPR.xcodeproj/project.pbxproj`)

| Key | 当前 | V0 应为 | 理由 |
|---|---|---|---|
| `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` | `Portrait + LandscapeLeft + LandscapeRight` | **`UIInterfaceOrientationPortrait`** | ADR-005 + 设计基线 393pt 竖屏锁定. V0 不支持横屏 |
| `INFOPLIST_KEY_UILaunchScreen_UIColorName` | (无)| **`AccentColor`** | launch 期间背景 brand-red |
| `INFOPLIST_KEY_CFBundleDisplayName` | `MeetPR` | 维持 `MeetPR` | OK |
| `INFOPLIST_KEY_NSHumanReadableCopyright` | (无)| **`© 2026 MeetPR. All rights reserved.`** | App Store 列出版权信息 |
| `INFOPLIST_KEY_LSApplicationCategoryType` | (无)| **`public.app-category.healthcare-fitness`** | App Store 分类 |
| `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` | (无)| **`<false/>`** | 我们不用 custom 加密(只用 HTTPS,Apple 标准库内的). 加这个 key 后 Apple 审核免填 export compliance 表 |

> **不加** 任何 NSCameraUsageDescription / NSMicrophoneUsageDescription / NSPhotoLibraryUsageDescription / NSLocationWhenInUseUsageDescription. V0 demo 不用相机 / 麦克风 / 相册 / 定位. 学员端视频上传走 V0.1+ 学员端 spec 触发后再加.

#### 6. 签名配置(在 `MeetPR.xcodeproj/project.pbxproj`)

| Key | 当前 | V0 应为 |
|---|---|---|
| `CODE_SIGN_STYLE` | `Automatic` | 维持 `Automatic`(personal Apple Developer 账号 Automatic 签名最简) |
| `DEVELOPMENT_TEAM` | (无) | **`XV97B4R4RZ`**(从本机 Apple Development 证书 CN `Apple Development: tianpingdeng@126.com (XV97B4R4RZ)` 解析) |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.meetpr.app` / `com.meetpr.app.tests` | 维持(F-012 公司账号迁移触发后再改) |
| `PROVISIONING_PROFILE_SPECIFIER` | (无) | 维持空(Automatic 模式下 Xcode 自管 profile) |

> **DEVELOPMENT_TEAM**(10 位字母数字 ID):Codex 先跑 `xcodebuild -showBuildSettings -scheme MeetPR-Demo`(未返回),再跑 `security find-identity -v -p codesigning`,从本机 Apple Development 证书 CN 解析到 `XV97B4R4RZ`,因此本 spec 直接写入该 team ID.

#### 7. 资产编译验证 + Archive build 跑通

merge 前必须:
- `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` 跑通(simulator,验证 AppIcon 在 home screen 显示 + LaunchScreen 闪一下 brand-red 背景)
- `xcodebuildmcp build_run_sim Scheme=MeetPR` 跑通(non-Demo 现有 scheme 不破)
- **`xcodebuild archive` 跑通**(关键!这是 TestFlight build 的前置). 命令:
  ```bash
  xcodebuild archive \
    -project MeetPR.xcodeproj \
    -scheme MeetPR-Demo \
    -configuration Demo \
    -archivePath /tmp/MeetPR-Demo.xcarchive \
    -destination 'generic/platform=iOS Simulator' \
    SKIP_INSTALL=NO
  ```
  期望:`** ARCHIVE SUCCEEDED **`. archive 内 .app bundle 含:
  - AppIcon.appiconset 编译产物
  - PrivacyInfo.xcprivacy 嵌入
  - Info.plist 含本 spec 加的所有 INFOPLIST_KEY_*
- `swift test --parallel` 全绿(不破上游 spec 测试)
- `swiftlint lint --strict` + `swift-format lint` 通过

#### 8. README + spec 内 V0 ship checklist 引用

更新 `MeetPR/README.md`(若没有则创建)加一段"V0 TestFlight 准备状态":
- AppIcon ✅(占位)
- LaunchScreen ✅(纯背景)
- PrivacyInfo.xcprivacy ✅
- Bundle ID ✅(personal account)
- DEVELOPMENT_TEAM ✅(`XV97B4R4RZ`)
- Info.plist 必需 key ✅
- → 接下来 W23 release engineering: archive → upload → TestFlight → Apple 审核

### 不做什么

| ❌ 留 spec / 留 follow-up |
|---|
| **真 logo SVG / wordmark 资产** — F-013 触发条件 = "真实 MeetPR wordmark / app mark 设计定稿". 本 spec 用占位资产(纯色背景 + SF Symbol),F-013 触发后单独起 docs PR 替换 |
| **公司 Apple Developer 账号迁移** — F-011 + F-012 触发条件 = "公司注册完成 / Bundle ID 可在公司 team 下创建". 本 spec 用 personal account |
| **App Store Connect 配置** — App 名 / Subtitle / 关键词 / 描述 / 截图 / Privacy questionnaire / 价格 → W23 release engineering(非 spec) |
| **TestFlight build upload + Apple 审核提交** — W23 release engineering |
| **Crash reporting / Sentry / Firebase Crashlytics** — V0.1+,Apple 系统级 crash log 够用 |
| **Push notification (APNs) capability** — V0 不用,V0.1+ 学员提醒 spec 触发后加 |
| **HealthKit capability** — V0 不读,V0.1+ 看是否要做"导入 1RM from Apple Health" |
| **Sign in with Apple / Google / 微信 / Apple Pay capability** — V0.1+ |
| **Camera / Microphone / Photos 权限** — 学员端视频上传 V0.1+ |
| **真用户隐私协议 / 服务条款 网页 URL**(NSPrivacyPolicyURL / EULA) — W23,需要法律 review,V0 走 Apple 默认 EULA + privacy questionnaire 答 |
| **Localizable.xcstrings 国际化扩展** — V0 中文 only,英文版 V0.1+ |
| **多 device family 支持(iPad / Mac Catalyst)** — V0 iPhone only(TARGETED_DEVICE_FAMILY = 1 不动) |
| **横屏支持** — V0 portrait only(本 spec 锁定),横屏需要重做大部分 view layout V0.1+ |
| **修改 spec 002-007 / 011 / 020 已合 view 内部** — 仅本 spec 范围 surfaces:Assets.xcassets / PrivacyInfo.xcprivacy / project.pbxproj INFOPLIST_KEY + signing 段 / MeetPR/README.md |
| **修改 ADR / PRD / coach-planning.md / data-model.md** — 不动设计层. 若 implementer 发现 V0 portrait-only 需要 ADR,走 §文档质疑权 协议 |
| **F-002 LAUNCH-CHECKLIST.md** — 是相邻 deliverable(operational ship 流程清单),本 spec **不合并**;F-002 会作为单独 docs PR 在本 spec close-out 后启动 |

## 技术要求

### 模块位置 + 修改 surface

本 spec 触动的文件:

| 路径 | 改动类型 |
|---|---|
| `MeetPR/Assets.xcassets/AppIcon.appiconset/` | 新建目录 + Contents.json + 3 个 PNG 占位资产 |
| `MeetPR/Assets.xcassets/AccentColor.colorset/Contents.json` | 改(填 brand-red `#E5221E`)|
| `MeetPR/Info.plist` | 新文件(显式 `UILaunchScreen` dict + V0 Info.plist keys) |
| `MeetPR/PrivacyInfo.xcprivacy` | 新文件 |
| `MeetPR.xcodeproj/project.pbxproj` | 改(加 6 条 INFOPLIST_KEY_* + DEVELOPMENT_TEAM + UIRequired/Supported orientation 改)|
| `MeetPR/README.md` | 新建或扩展 V0 ship 准备状态段 |
| `specs/021-apple-readiness-assets-and-signing/SPEC.md` | 状态 Draft → Done(merge 前最后一步,在同 impl PR 改) |

### 测试

本 spec 是 **build artifact** 性质,**不需要新增 Swift 单测 / ViewInspector 测试**. 验收靠:
- `swift test --parallel` 全绿(上游 spec 测试不破)
- `xcodebuildmcp build_run_sim` 两个 scheme 都通
- **`xcodebuild archive` 通**(本 spec 主要验证手段)
- AppIcon / LaunchScreen 视觉 manual check(simulator 看 home screen 图标 + launch 闪屏)
- PrivacyInfo.xcprivacy 解析正确(`plutil -lint MeetPR/PrivacyInfo.xcprivacy` 通过)

### CI 影响

`xcodebuild archive` 比 `xcodebuild build` 慢约 2-3 倍, **不**默认进 CI(避免 ci/cost-optimization 之后又涨 60% 成本). 仅本 spec impl PR 内 manual 验一次. 真 ship 流程(W23)再按需进 CI.

### iOS 17+ 单尺寸 AppIcon 用法

参考 [Apple HIG App Icon](https://developer.apple.com/design/human-interface-guidelines/app-icons):

```json
{
  "images" : [
    {
      "filename" : "meetpr-icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "meetpr-icon-1024-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "appearances" : [{"appearance" : "luminosity", "value" : "dark"}],
      "size" : "1024x1024"
    },
    {
      "filename" : "meetpr-icon-1024-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "appearances" : [{"appearance" : "luminosity", "value" : "tinted"}],
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

> Codex 首选 (a) SF Symbol 渲染;本机 Swift/AppKit RGB bitmap context 未可用且 PIL 未安装,因此实装用 ImageMagick 程序化 fallback 生成力量训练占位 mark. 渲染配色:
> - light variant: brand-red `#E5221E` 背景 + 白色 symbol
> - dark variant: deep-red `#7A1110` 背景 + 浅红 `#FF8B87` symbol
> - tinted variant: 灰度(系统会按 user 选的 tint 着色)— 中灰 `#999999` 背景 + 白色 symbol

### PrivacyInfo.xcprivacy 完整模板

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

> Codex 实装后用 `plutil -lint MeetPR/PrivacyInfo.xcprivacy` 验证 XML 语法 + 用 `xcodebuild archive` 跑通,验证 .app bundle 含此文件.

### Build settings 改动 sketch (project.pbxproj)

在 Debug / Release / Demo 三个 configuration 都加(共 9 处加,3 个 target × 3 configuration):

```
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;  // 改,锁竖屏
INFOPLIST_KEY_UILaunchScreen_UIColorName = AccentColor;  // 加
INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 MeetPR. All rights reserved.";  // 加
INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.healthcare-fitness";  // 加
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;  // 加
DEVELOPMENT_TEAM = XV97B4R4RZ;  // 加,本机 signing identity 解析
GENERATE_INFOPLIST_FILE = NO;  // app target 用显式 MeetPR/Info.plist,确保 UILaunchScreen UIColorName 落地
INFOPLIST_FILE = MeetPR/Info.plist;
```

> **关于 DEMO_MODE INFOPLIST**:Demo configuration 跟 Debug 一样的 INFOPLIST_KEY_*, **不需要**额外为 DEMO_MODE 加 plist 区分(scheme 切换 + DEMO_MODE flag 已经在 Swift 编译期 swap 出 Demo* 实装,plist 层不需要再分).

## 验收清单

- [ ] `MeetPR/Assets.xcassets/AppIcon.appiconset/Contents.json` 创建,含 3 entries(light / dark / tinted)
- [ ] `MeetPR/Assets.xcassets/AppIcon.appiconset/meetpr-icon-1024{,-dark,-tinted}.png` 占位资产创建(1024×1024 sRGB no-alpha,SF Symbol 渲染或程序生成)
- [ ] `MeetPR/Assets.xcassets/AccentColor.colorset/Contents.json` 填 brand-red `#E5221E`(light + dark 同色)
- [ ] `MeetPR/Info.plist` 创建,含 `UILaunchScreen` → `UIColorName = AccentColor` + V0 必需 Info.plist keys
- [ ] `MeetPR/PrivacyInfo.xcprivacy` 创建,内容跟 §技术要求 §PrivacyInfo template 一致(FileTimestamp + UserDefaults);`plutil -lint` 通过
- [ ] `MeetPR.xcodeproj/project.pbxproj` 加 6 条 INFOPLIST_KEY_*(UISupportedInterfaceOrientations 改竖屏 / UILaunchScreen_UIColorName / NSHumanReadableCopyright / LSApplicationCategoryType / ITSAppUsesNonExemptEncryption / DEVELOPMENT_TEAM)
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` iPhone 17 simulator 跑通,home screen 见占位 AppIcon,launch 闪屏 brand-red 背景
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR` iPhone 17 simulator 跑通(现有 scheme 不破)
- [ ] **`xcodebuild archive -scheme MeetPR-Demo -configuration Demo` 跑通**(关键),archive 内 .app bundle 含 AppIcon 编译产物 + PrivacyInfo.xcprivacy 嵌入(`unzip -l MeetPR-Demo.xcarchive` 验证)
- [ ] `swift test --parallel` 全绿(spec 020 等上游测试不破)
- [ ] `swiftlint lint --strict` + `swift-format lint` 通过
- [ ] V0 happy path manual checklist(spec 020 CHECKLIST.md 15 步)在 Demo build 上仍 100% 通过(本 spec 不破上游 happy path)
- [ ] `MeetPR/README.md` 新建或扩展 V0 ship 准备状态段
- [ ] F-015 红线 grep 0 命中(本 spec 不涉及 coach planning 设计层,自然 0)
- [ ] `specs/021-apple-readiness-assets-and-signing/SPEC.md` 状态 `Draft` → `Done`(review approve 后,**同 impl PR 内**改完最后一步,per AGENTS.md §交付检查清单 line 278)
- [ ] SPEC.md PR 字段填本 PR 链接(同上)
- [ ] **CLAUDE.md 项目阶段 + 下一步 表 sync**(per 2026-05-10 lesson — spec impl PR 必须同步刷主线状态文档,避免再开 follow-up sync PR);本 spec 把 W22 翻 ✅ DONE / W23-25 提示进 release engineering 阶段

## 估时(给 Codex 参考)

- AppIcon 占位资产生成(SF Symbol → 1024 PNG × 3 variants):1 小时
- AccentColor.colorset 改 brand-red:5 分钟
- PrivacyInfo.xcprivacy 创建 + plutil 验证:30 分钟
- project.pbxproj 6 条 INFOPLIST_KEY_* + DEVELOPMENT_TEAM:1 小时(pbxproj 手改风险)
- README.md V0 ship 状态段:30 分钟
- `xcodebuild archive` 跑通 + 修 archive 报错:1.5 小时(可能踩 codesign / entitlement 坑)
- buffer:1 小时

总:**~5 小时** Codex session(跟 spec 020 量级类似).

## 风险 / 待 implementer 关注

1. **DEVELOPMENT_TEAM ID 环境差异**:本机已从 code signing identity 解析并写入 `XV97B4R4RZ`;若换机或换 Apple team,需在 W23 release engineering 前重新确认 Xcode signing identity
2. **Archive build 可能首次失败**:常见坑 = entitlements / capabilities 不匹配 / signing 没配齐. Codex 按错误提示一一修. 若 archive 死活不通,fallback "本地 simulator build_run_sim 通 + 把 archive 验证留 NOTES.md WIP" 也接受(W23 release engineering 时再 polish)
3. **占位 AppIcon SF Symbol 渲染质量**:`xcrun symbol` 输出可能不是干净的 1024 PNG. 备选 swift script 用 `ImageRenderer<Image(systemName:)>` API 输出. Codex 找最 minimal 的方法
4. **iOS 17 单 size icon 模式**: `Contents.json` 不接受老的 `"size": "29x29"` + `"scale": "2x"` 格式. 新格式见 §技术要求 sketch. 用错格式 Xcode 不报错但 archive 阶段会编译失败
5. **Demo configuration 可能漏改 INFOPLIST_KEY**:spec 020 加 Demo configuration 时是基于 Debug 复制. 本 spec 加的 INFOPLIST_KEY_* 要确保 Demo 配置也含(共 9 处:3 target × 3 config)
6. **CLAUDE.md sync drift 风险**:见 2026-05-09 / 05-10 两次 drift 事件(#38 / #40). 本 spec 验收清单**已含** CLAUDE.md sync 一项,Codex 必须在 finalize commit 内同步刷,**不再开 follow-up PR**

## F-015 自检

`4 周扫视态` / `4 周宏观视图` / `波形图` / `变式矩阵` / `密度条` / `specificityBucket` / `waveformValue` / `accessoryDensityBucket` / `isDeloadWeek` / `Excel grid` — 本 spec 不涉及 coach planning 设计层,自然 0 命中.

## 上游 / 下游

- **上游(本 spec 落地依赖)**: 已合 spec 020 V0 demo orchestration(Demo build configuration / scheme 已就位,本 spec 在它基础上加资产)
- **下游(本 spec 落地后启用)**:
  - **F-002 LAUNCH-CHECKLIST.md**(相邻 deliverable):`~/Projects/apps/MeetPR/LAUNCH-CHECKLIST.md` operational ship 流程清单. 本 spec close-out 后单独 docs PR 起草(估时 ~1 小时)
  - **W23 release engineering**(非 spec,工程任务): TestFlight upload via `xcrun altool` / Transporter / `xcodebuild -exportArchive` → App Store Connect 配置 → Apple 审核提交
  - **F-013 触发**(真 logo 资产):本 spec 完成后,real wordmark / app mark 设计定稿即触发 F-013,起 docs PR 替换占位资产
  - **F-012 触发**(公司 Bundle ID):F-011 公司注册完成 + Apple Developer 公司账号 ready 即触发,本 spec 用 personal account 不阻塞
  - **V0.1+ 学员端 spec**:Camera / Photos / Microphone 权限会触发 PrivacyInfo.xcprivacy 扩展,届时本 spec 的 NSPrivacyAccessedAPITypes 数组扩

## 修订记录

- 2026-05-10: 创建(Draft). Claude 起草, Codex 接力实装. 跟 spec 020 V0 demo orchestration 同 W22 节奏(实际 5/10 起步,提前 W22 计划日 5/25)
- 2026-05-10: Codex implementation amend:状态改 InReview;`DEVELOPMENT_TEAM` 从本机 signing identity 解析为 `XV97B4R4RZ`;Required Reason API grep 发现 `DraftStore` 使用 `UserDefaults`,因此 `PrivacyInfo.xcprivacy` 追加 `NSPrivacyAccessedAPICategoryUserDefaults` + `CA92.1`;AppIcon 用 ImageMagick 程序化生成 RGB/no-alpha 占位 PNG,真 logo 仍由 F-013 后续替换;`UILaunchScreen_UIColorName` build setting 无法产出正确嵌套 plist,因此新增显式 `MeetPR/Info.plist` 保证 archive 内 `UILaunchScreen/UIColorName = AccentColor`.
