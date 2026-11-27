# iOS 隐私政策重新同意与用户协议入口

- 任务卡：`/Users/david/Projects/scratch/legal-company-20261124/card-ios.md`（T2）。
- 工作树：`MeetPR-wt-legal`，分支 `feat/legal-consent`，起点 `853f2f31`。
- 开工试写 `.codex-write-test` 后删除成功；未 commit、push 或开 PR。
- 范围按卡执行，未修改政策/协议正文、App 版本、工程签名或构建设置。

## 实装

- `Modules/AppShell/Sources/AppShell/AnalyticsPrivacyNotice.swift`：集中定义 `legalVersion = "2026-12-01"`、`termsURL` 和接受版本键；同意时持久化版本并触发回调。弹窗含两份协议链接，保留原有两种 build track 的使用分析正文，新增拒绝说明与“再看看”返回路径，禁止交互式关闭。
- `Modules/AppShell/Sources/AppShell/AnalyticsRootModifier.swift`：`shouldShowNotice(mode:defaults:)` 注入 UserDefaults，仅 live 且版本不匹配时展示；旧确认键不再豁免。原 `Analytics.shared.confirmPrivacyNotice()` 和上报闸门保留。
- `Modules/AppShell/Sources/AppShell/AppShellStrings.swift`、`Resources/Localizable.xcstrings`：新增简体、繁体、英文文案；登录条款更新。使用分析正文逐值比对原版本，未变。
- `Modules/AppShell/Sources/AppShell/Auth/LoginView.swift`、`Auth/Global/GlobalLoginView.swift`：用户协议与隐私政策均可点；条款分成引导文字和链接行，保留 Global `/privacy/zh`、`/privacy/en`。
- `Modules/AppShell/Sources/AppShell/RootView.swift`、`Modules/CoachKit/Sources/CoachKit/CoachRootView.swift`、`Features/MyProfile/CoachMyProfileView.swift`：沿现有隐私 URL 注入路径传递唯一来源的 `termsURL`。只压缩既有初始化表达式的排版以满足文件长度 lint，未改其他逻辑。
- `Modules/CoachKit/Sources/CoachKit/Features/MyProfile/CoachPrivacyTermsSheet.swift`：两份文档使用同样的 Link 行，用户协议不再标为 unavailable。
- 检查 StudentKit 后没有找到隐私政策入口，按卡不新增学员入口。

## 先红后绿证据

原始测试日志已复制到 `/Users/david/Projects/scratch/legal-company-20261124/ios-logs/`；以下为文件名时间片段（均为 2026-11-24 UTC）。

| 测试文件 / 行为 | 红测证据 | 绿测证据 |
| --- | --- | --- |
| `AppShellTests/AnalyticsPrivacyNoticeTests.swift` / 版本判断四种情况 | `08-52-33`：原 seam 私有且未接受 defaults；只开放注入、保留旧逻辑后 `08-54-06` 出现两处断言失败（旧用户、旧版本） | `08-54-24`：1 项通过；含非 live 不弹断言 |
| 同文件 / 协议链接、点击同意写版本并回调一次 | `08-54-46`：缺少新参数、常量和按钮文案；`08-55-35` 检出正文 fixedSize 回归 | `08-55-55`：1 项通过，保留滚动正文和外部操作按钮 |
| 同文件 / 拒绝、唯一“再看看”、返回两链接 | `08-56-17`：找不到拒绝操作；`08-56-47`：ViewInspector 未观察到值类型 State 变化 | `08-57-34`：1 项通过；使用 Observable 状态，实际点击两个按钮，拒绝及返回均不写入版本、不调用同意回调 |
| `AppShellTests/Auth/AuthFlowSnapshotTests.swift` / 手机号登录协议 | `08-58-34`：找不到用户协议 Link | `08-59-40`：与下项合计 2 项通过 |
| `AppShellTests/Auth/GlobalAuthViewTests.swift` / 邮箱登录 China、Global | `08-59-07`：两个参数化场景均找不到用户协议 Link | `08-59-40`：通过，并验证原隐私 URL |
| `CoachKitTests/Features/MyProfile/CoachMyProfileViewModelTests.swift` / 两份协议 | `08-57-52`：找不到用户协议 Link | `09-00-12`：1 项通过；同时断言 unavailable 标识消失 |

## 验证

- `swift test --package-path Modules/AppShell`：**129 tests passed，0 failures**；日志 `swift_package_test_2026-11-24T09-01-15-087Z_pid93153_968faa06.log`。
- `swift test --package-path Modules/CoachKit`：**497 tests in 14 suites passed，0 failures**；日志 `swift_package_test_2026-11-24T09-01-26-016Z_pid93153_4893f154.log`。
- 通过 XcodeBuildMCP 的 SwiftPM 工具执行上述测试，计数以原始 Swift Testing 汇总为准。
- 改动的 13 个 Swift 文件：`swiftlint lint --strict` 和 `swift-format lint --strict` 均通过；`git diff --check` 通过。
- 初次编译报告了既有 `PlanImportCapability`、`WeightPercentPresets`、`TrainingReminderScheduling` 和 `ImportAssemblerTests` 警告；不在卡内，未顺手修改。
- `xcodebuild`：**未通过验收**。先通过 XcodeBuildMCP `build_sim` 执行 `MeetPR-Demo`，目标为 iPhone 17e（iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`），300 秒后工具调用超时。原始结果：`timed out awaiting tools/call after 300s`。日志停在构建准备阶段，没有 Swift 编译错误或成功产物；不能据此断言代码的 iOS 构建结果。
- 工具未完成后直接重试命令如下，**xcodebuild 退出码 74**：

  ```sh
  xcodebuild build -scheme MeetPR-Demo -destination 'platform=iOS Simulator,name=iPhone 17e' -derivedDataPath /Users/david/Projects/scratch/legal-company-20261124/DerivedData-direct
  ```

  原始错误节选：

  ```text
  CoreSimulatorService connection became invalid. Simulator services will no longer be available.
  Error Domain=NSPOSIXErrorDomain Code=61 "Connection refused"
  xcodebuild: error: Could not resolve package dependencies:
  <unknown>:0: error: error opening '/Users/david/.cache/clang/ModuleCache/Swift-1IEYM950OGIQC.swiftmodule' for output: /Users/david/.cache/clang/ModuleCache: Operation not permitted
  <unknown>:0: error: unable to load standard library for target 'arm64-apple-macos14.0'
  <unknown>:0: error: cannot open file '/Users/david/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/appshell.dia' for diagnostics emission (Operation not permitted)
  ```

- 构建日志：`/Users/david/Projects/scratch/legal-company-20261124/ios-logs/build_sim_2026-11-24T09-01-35-453Z_pid93153_e7456985.log` 与 `ios-logs/xcodebuild-direct.log`。诊断时单独执行日志末尾的 `xcstringstool --dry-run` 和 clang 宏探针，分别约 0.01 / 0.04 秒退出 0；未复现 MCP 停滞，**其根因未确定**。未修改工程、缓存权限或系统服务。
- **截图未生成，由 Claude 补**：没有本次修改的成功 iOS 构建产物，不能拿旧安装包截图充当证据。预期路径为 `/Users/david/Projects/scratch/legal-company-20261124/ios-consent.png`、`ios-declined.png`（当前不存在）。仅查询了模拟器清单并将执行目标设为 iPhone 17e；未操作其他模拟器。
- 待补验收：先完成卡指定的 `MeetPR-Demo` 构建，再用 live 的 `MeetPR` scheme 在 iPhone 17e 检查同意弹窗、不同意后的说明、再看看返回，并保存上述两张截图。Demo 不弹是既定行为，不应为截图临时更改。

## 交接说明

- 没有待裁决的产品分歧。常量留在 AppShell，通过参数注入 CoachKit，避免反向模块依赖与重复定义。
- Demo 维持不弹；视觉验收需用 live 的 MeetPR scheme。独立收货由 Claude 继续，本文不将本地自测写成独立 review 或 CI 通过。


## 返修第 1 轮（2026-11-25）

- 返修依据：`/Users/david/Projects/scratch/legal-company-20261124/rework-ios-1.md`（全文及末尾补充已读）。本轮仅执行第 1、3、4 条；第 2 条已作废，不改标题或已验收的同意、拒绝、再看看流程。
- 开工成功写入并删除 `.codex-write-test`。保留上一轮工作区实现，未 commit、push 或开 PR；未运行 xcodebuild、模拟器或截图。本轮只运行 SwiftPM 测试，iOS 构建与截图继续由 Claude 收货；卡片末尾记载其已在 iPhone 17e 验过的部分，不冒充本轮自验。

### 本轮改动

- 第 1 条：`Auth/Global/GlobalLoginView.swift` 的 China 隐私链接修为 `/privacy`；Global 仍为 `/privacy/en`。`GlobalAuthViewTests.swift` 新增 `chinaEmailLoginUsesCanonicalPrivacyPolicyURL`，验证实际 Link 与 `AnalyticsPrivacyNotice.privacyPolicyURL` 一致；原双轨断言同步正确国内地址。
- 第 3 条：新增 `Modules/AppShell/Sources/AppShell/LegalDocuments.swift`，集中 `privacyPolicyURL`、`termsURL`、`version`、`acceptedVersionKey`。`AnalyticsPrivacyNotice`、`AnalyticsRootModifier`、`RootView` 与两个登录页改从它取常量；`AnalyticsPrivacyNotice.privacyPolicyURL` 保留转发。三个受影响测试文件仅同步用户协议常量引用，保留既有行为断言；CoachKit 沿用原有参数注入，本轮没有修改 CoachKit。
- 第 4 条：`Resources/Localizable.xcstrings` 仅删除国内正文简繁两处「、不出境」及英文「transferred overseas」和对应多余标点。逐值对比返修前快照，确认只有这三处删除，Global 正文、标题和其他文案完全不变。

### 第 1 条先红后绿

测试 seam 为卡片指定的 `GlobalLoginView(buildTrack: .china)` 实际 Link（ViewInspector），先添加断言并运行，再修改生产代码。

- 红：`swift test --package-path Modules/AppShell --filter chinaEmailLoginUsesCanonicalPrivacyPolicyURL`，1 test failed / 0 passed。原始失败：`Caught error: Search did not find a match.`（`GlobalAuthViewTests.swift:11:2`）。日志：`swift_package_test_2026-11-25T07-59-29-056Z_pid72041_58a540fc.log`。
- 绿：修复 China URL 后运行 `swift test --package-path Modules/AppShell --filter 'chinaEmailLoginUsesCanonicalPrivacyPolicyURL|emailLoginIncludesTermsAndPreservesLocalizedPrivacyURL'`，2 tests passed / 0 failures，含双轨参数化场景。日志：`swift_package_test_2026-11-25T07-59-54-388Z_pid72041_5c1e6fba.log`。

### 最终验证

通过 XcodeBuildMCP `swift_package_test` 执行 `swift test`；session defaults 为空，测试使用显式 packagePath，不涉及 scheme 或模拟器。原始日志均已复制到 `/Users/david/Projects/scratch/legal-company-20261124/ios-logs/`。

- `swift test --package-path Modules/AppShell`：**130 tests passed，0 failures**。最终日志：`swift_package_test_2026-11-25T08-01-03-577Z_pid72041_d982379d.log`。
- `swift test --package-path Modules/CoachKit`：**497 tests in 14 suites passed，0 failures**。日志：`swift_package_test_2026-11-25T08-00-28-648Z_pid72041_2538a125.log`。
- `git grep -n "privacy/zh" -- Modules`：无命中（exit 1）；旧 `AnalyticsPrivacyNotice.termsURL/legalVersion/acceptedVersionKey` 引用无残留；`git diff --check` 通过。
- 最终按开工快照核对本轮差异，变更仅覆盖返修卡第 1、3、4 条及所需测试引用迁移；未重写上一轮已通过的实现。未运行额外 lint/build 命令，未将本地自测计为独立验收。
