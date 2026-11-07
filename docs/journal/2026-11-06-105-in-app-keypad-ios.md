# 105 iOS — app 内数字面板实装记录

状态：实现待 Opus 收货；未 commit、未 push；主 scheme 构建与模拟器验收未完成，不能视为功能验收通过。

## 范围与现场

- 唯一需求：[SPEC](../../specs/105-in-app-keypad/SPEC.md)，以及 David 2026-11-06 已定稿屏幕稿转写；未修改验收清单。
- 分支 `feat/105-in-app-keypad`；开工 HEAD 与本地 `origin/release/1.0` 均为 `8f4fef4c0d36b3fa8670a89b5e789007f646d66c`。工作区开工干净。未从 main merge/cherry-pick。
- 目标 iOS 1.0(33)，P1。未改 build 号、scheme、pbxproj、依赖、正典发版账本或 SPEC 状态。
- 指定设备：iPhone 17e，`5D5FA360-BA49-48C6-A887-2F0D22F89749`。没有安装/操作 iPhone 17、17 Pro 或新建模拟器。

## 实现

1. `AccessoryLogRow`、`LoadTypeLogRow` 与 `StudentAddedInlineRows` 的组内数字输入改为按钮；原有方框保留，当前格品牌金 2pt 描边、数字正文色、所在行暖色底。
2. `WorkoutKeypadSession` 管理单动作内已排序的可编辑格与提交回调；只确认当前格，按重量→次数→RPE/RIR→下一组推进，末格收起。取消清掉会话而不提交当前格。必填空值保留原值，可选 effort 空值提交为空。
3. `MeetPRNumberPad` 新增文本模式 initializer，复用原键盘、按钮与配色；上下文和当前值同一行，单位由调用方提供，底部主按钮显示下一字段或确认。原 Double initializer、快捷按钮及 `snapped` 路径保留；`SetEntrySheet.swift` 无 diff。
4. 新文本模式第一位数字替换当前值；退格可删除已有值；重量最多一位小数、不套杠铃吸附；次数 1–99；RPE 5–10 且为 0.5 步进；RIR 0–9 整数，禁用小数键。非法值禁确认。尾随小数点在提交时规范化，避免 `7.` 无法保存。
5. 面板放在 `StudentRootView` tab inset 外层，以遮罩覆盖 tab；session 在 `TodayWorkoutView.studentTabLayer` 之前注入，穿过现有独立 UIHostingController 边界。滚动避让按面板上沿和内容底边测量 inset，并滚动当前 row ID；收起时去掉 inset，不恢复旧滚动目标。
6. 删除目标行的 `@FocusState`、键盘 toolbar/keyboardType，以及训练滚动页的系统键盘通知状态。主项独立 SetEntrySheet 的原有输入方式不在本卡修改范围。
7. LoadType 行与面板一致按用户 KG/LB 显示并沿用 `AccessoryRow` 的公斤转换；次数保留原行模型的 1–99 校验，与现有保存链路一致。新增 5 个简中/繁中/英文键。补数字按钮 VoiceOver label/value。

保存、离线队列和整日完成仍调用原来的 `saveAccessoryRow` / 批量保存链路，没有新增网络或持久化入口。

## 测试与证据

全部本地测试通过 Swift Testing 在 macOS SwiftPM 运行；不代表 iOS 模拟器或 CI 通过。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| DesignSystem 全量 | **80 passed**，含新文本模式 4 个测试和既有杠铃/快捷按钮测试 | [日志](../evidence/105-in-app-keypad-ios/design-system-tests.log) |
| StudentKit 相关集 | **258 passed**，含输入状态、Accessory、LoadType、自加动作、SetEntry、TodayWorkout、SetSync、本地化 | [日志](../evidence/105-in-app-keypad-ios/student-related-tests.log) |
| StudentKit 全量 | **1185 个测试，1171 passed / 14 failed，15 issues**；失败均为视频 fixture 编码 `.unavailable("Cannot Encode")`，未修改这些视频实现/测试，未将失败记为通过 | [完整日志](../evidence/105-in-app-keypad-ios/student-full-tests.log) |
| 已知本地化基线 | 本轮 macOS 的 `StudentKit localization` 套件通过，**未复现 22 个本地化失败**；iOS 构建未完成，不能断言其 iOS 基线消失 | 同上 |
| SwiftLint strict | **18 个 Swift 文件，0 violations** | [日志](../evidence/105-in-app-keypad-ios/swiftlint.log) |
| swift-format strict / git diff --check | 通过 | [format 日志](../evidence/105-in-app-keypad-ios/swift-format.log) |
| 主 scheme `MeetPR` build | **未通过：磁盘满导致 build database/disk full**；MCP 随后 `Transport closed` | [错误摘录](../evidence/105-in-app-keypad-ios/main-build-errors.log) |
| 指定 iPhone 17e 运行、截图 | **未完成，0 张**。工具断连，未将其他构建/旧包截图充当证据 | [待补说明](../evidence/105-in-app-keypad-ios/README.md) |

新增测试共 **8 个**：DesignSystem 4 个、StudentKit session 4 个；另更新既有次数边界测试。

先红后绿轨迹：

- NumberPad 辅助项文本规则：首轮缺类型编译红；随后 RPE/次数边界与 RIR 小数共 5 个失败断言；实现后绿。[规则红测](../evidence/105-in-app-keypad-ios/red-number-pad.log)
- 字段推进：缺 session/cell 编译红，实现后 1 项绿；取消/清空与非法值提交出现 3 个失败断言，修复后绿。[红测](../evidence/105-in-app-keypad-ios/red-session.log)
- 初轮次数 100（已被下述 99 次修订取代，仅保留历史）：旧 `AccessoryRow.reps` 拒绝 100，修改为 1–100 后绿。[红测](../evidence/105-in-app-keypad-ios/red-reps-100.log)
- review 回归：真实 AccessoryRow→cells→session→row 的 `7.` 提交无法保存，2 个断言红；提交规范化后绿。[红测](../evidence/105-in-app-keypad-ios/red-trailing-decimal.log)

最后使用的相关集 filter：`WorkoutKeypadSessionTests|[Aa]ccessory|[Ss]etEntry|[Tt]odayWorkout|[Ss]etSync|[Ss]tudentAdded|[Ll]oadType|StudentStringsTests`。

环境记录：最初 MCP 的 SwiftPM 拉取 ViewInspector 网络超时，复用发版工作树 `.build` 下第三方依赖缓存后继续（只复制 checkouts/repositories/workspace-state，路径改成本工作树，未复制业务实现）。磁盘耗尽后仅清理本轮 `/private/tmp/meetpr-105-derived` 的 Build/ModuleCache/Index；MCP 连接仍关闭。CLI SwiftPM 使用工作树内 clang module cache、临时 package cache 与 `--disable-sandbox` 避免嵌套 sandbox，仍受本会话文件系统限制。CLI 主构建回退仍因系统缓存目录写权限和 CoreSimulator 连接失败而未完成。

## 对照原验收清单

以下编号严格对应 SPEC 原有 10 项，未增减清单，也未替 Opus 宣布验收通过。

| 原编号 | 本卡证据与仍需验收的部分 |
| --- | --- |
| 1 | 三种行已接 app 内面板；目标行无 TextField/FocusState/keyboardType。全程无系统键盘待 iPhone 17e 实测。安卓由另一卡负责。 |
| 2 | 三语资源、上下文/单位组件单测通过；真实屏幕排版待截图。 |
| 3 | 推进、跨组、跳过不可编辑字段、末格收起单测通过；UI 待验。 |
| 4 | 取消与空值语义单测通过；遮罩绑定 cancel，UI 待验。 |
| 5 | 0/7.5、RPE/RIR 规则及主项原测试通过；实际键位交互待验。 |
| 6 | 高亮与滚动避让实现已接线；首/中/末辅助卡最后一组的可见性均待截图验证。 |
| 7 | 相关保存、离线同步与完成流程既有回归通过；本次完整手工录入→打勾→离线→完成整日待验。 |
| 8 | 面板在 tab inset 外覆盖；实际 tab 不上浮待 iOS 验证。 |
| 9 | 未改变历史数据结构或落库路径，既有已记录行测试通过；带历史升级第一屏待真实数据验收。 |
| 10 | 没有截图；指定设备截图由 Opus 在工具恢复后补，不能使用其他设备或旧包代替。 |

## 独立审查

按 `review-loop` 审未提交 diff + 新文件；`docs/agents/issue-tracker.md` 缺失，因此使用本地批准 SPEC 的双轴入口，未伪建 tracker。若要启用 Matt tracker 流程，应由 David 调用 `$setup-matt-pocock-skills`；不影响本次本地审查。

- **Standards**：初审 1 个 P2（数字按钮缺 accessibilityValue）和 1 条测试建议；补两类行 label/value、真实 row seam 测试后，定向复核 **CLEAN**。
- **Spec**：初审 2 个 P2（尾随小数点不能保存、LoadType 的 LB 输入却显示 kg）；修复、补红绿测试后，定向复核 **CLEAN**。同时核对 hosting 前注入与滚动 modifier 提取。
- 两位 reviewer 仅做只读审查，未运行 build/test；CLEAN 仅表示静态代码审查收敛，不替代上方未完成的 iOS 构建/视觉验收。

## 代表性 diff（完整改动保留工作区）

```diff
- TextField(placeholder, text: text)
-   .focused($focusedField, equals: field)
+ Button { onInput(resolvedField) } label: {
+   Text(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
+ }
+ .foregroundStyle(Color.MeetPR.textPrimary)
+ .accessibilityValue(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)

+ MeetPRNumberPad(
+   field: cell.field, text: cell.value,
+   contextText: cell.context, unit: cell.unit,
+   commitTitle: session.next.map {
+     StudentStrings.replacing(.keypadNext, values: [$0.fieldTitle])
+   },
+   onTextCommit: session.commit, onCancel: session.cancel
+ )
```

## 2026-11-06 续作：次数上限修订与工具重连

- David 最新明确次数 **1–99**，与现有保存链路和后端一致。现场仓内 SPEC 第 18 行仍写 1–100；执行以上述最新修订为准，未擅自修改正典 SPEC 或原验收清单，留 Opus 同步文本。
- 先改测试：NumberPadTextInput 拒绝 100；真实 row/session 输入 100 不提交、不推进，99 可提交；AccessoryRow 的 100 不可保存。两轮红测共 **4 个失败断言**：[面板红测](../evidence/105-in-app-keypad-ios/red-reps-99-number-pad.log)、[session/row 红测](../evidence/105-in-app-keypad-ios/red-reps-99-session.log)。随后辅助面板校验改为 99，AccessoryRow 恢复基线 99（该生产文件已无 diff）。
- 最终修订源码重跑：**StudentKit 相关 258 passed / 0 failed；DesignSystem 全量 80 passed / 0 failed；SwiftLint 18 文件 0 violations；swift-format 与 git diff --check 通过**。上表相关日志已替换为本轮结果。StudentKit 全量 1185 的结果属于上一轮；本轮只重跑受本次边界修订影响的相关集，未重复视频 fixture 失败。
- 主项原 Double initializer / snapped / 最小 20kg 规则未改，主项回归仍绿。
- 磁盘清理后再次调用 XcodeBuildMCP `session_show_defaults`，仍报 **Transport closed**。当前工具没有客户端重连接口；已请求 David 在客户端重连。不能用启动另一个孤立 stdio 服务替代当前 MCP 连接，也未操作其他模拟器。主 scheme build 与指定 iPhone 17e 截图仍未完成。
- 次数修订的 Spec 定向只读复核 **CLEAN**；review 提醒的旧 100 次最终态和代表 diff 已更新，历史红测明确标为被修订取代。
- 清理本轮生成的两模块 `.build`、唯一 DerivedData `/private/tmp/meetpr-105-derived` 和临时 SwiftPM cache，释放约 **1.3 GiB**；测试原始日志保留证据目录。未 commit、未 push。

## 2026-11-06 补验请求：基线视频失败核验

- 本轮仅执行验证、补证据与 JOURNAL；没有改实现、测试、demo fixture 或配置。没有 commit/push，也没有把更新后的发版线合入任务分支。
- 当前本地 `origin/release/1.0` 为 **`7b7d906747584af819606f95d9790a5ee4196d8c`**。用 `git archive origin/release/1.0 Modules` 导出纯基线源码至 `/private/tmp/meetpr105-baseline`，未混入本卡修改；仅复用第三方依赖 checkout。用与原失败相同的 macOS SwiftPM/sandbox 条件跑原先失败的 14 个测试函数。
- **基线编译通过（226.04 秒）；14 个测试全部失败，15 issues，全部 `.unavailable("Cannot Encode")`；失败名称集合与本卡全量日志完全一致。** 其中音频转码测试有 2 个声道参数，因此 14 函数产生 15 issues。可确认这些失败在该环境的发版基线上同样存在，不是本卡新增；这不等于已经定位或修复视频编码根因。[基线日志](../evidence/105-in-app-keypad-ios/baseline-video-tests.log)、[基线上下文](../evidence/105-in-app-keypad-ios/baseline-video-context.txt)。
- 主 scheme `MeetPR` Debug：**仍未完成构建**。本轮 MCP `session_show_defaults` 和 `session_set_defaults` 均直接返回 `Transport closed`，没有进入编译。目标明确为 iPhone 17e `5D5FA360-BA49-48C6-A887-2F0D22F89749`，唯一 DerivedData 预定 `/private/tmp/meetpr-105-derived`；最新要求允许保留，此轮因连接未恢复未生成。
- 官方 XcodeBuildMCP CLI 已按 CLI skill 的 help-first 入口尝试；`simulator list` 返回 CoreSimulatorService connection invalid / Operation not permitted。没有重启系统服务、操作其他设备或通过替代通道绕过权限。[MCP 记录](../evidence/105-in-app-keypad-ios/mcp-reconnect.log)、[CLI 记录](../evidence/105-in-app-keypad-ios/mcp-cli-simulator-connection.log)。需要客户端重建本会话的 MCP transport；当前可调用工具没有重连接口。
- 截图 **0 张**，因此 (a) 首卡最后组重量、(b) 中间卡、(c) 末卡末格确定、(d) 收起页面、(e) 导航不浮起，均没有可报告的截图路径。未启动旧包取证，不能宣布无系统键盘或布局验收通过。
- 读现有 `TrainingFlowDemoScenario` 确认专项 fixture 为主项 + 两张辅助卡；如连接恢复，按 David 授权临时扩为三张辅助卡取证，并在交付前还原。本轮尚未更改 fixture。
- 基线验证结束后已删除隔离基线源码及其 `.build`，只保留证据日志；主 scheme DerivedData 的最新保留要求未改变。

## 2026-11-06 Opus 模拟器收货

- Opus 本机（非沙箱）构建：主 scheme `MeetPR` Debug 与 `MeetPR-DemoStudent`（DemoStudent 配置）在 iPhone 17e 均 BUILD SUCCEEDED。
- iPhone 17e 学员 demo（`--spec090-start`，临时把演示日扩成 1 主项 + 3 辅助卡取证，已还原，不进 diff）：末张辅助卡第 3 组重量点开 → app 内面板，行浅暖底高亮、格子金边且数字保持深色、上下文「坐姿划船 · 第 3 组 · 重量」、右侧 60 KG、主按钮「下一项 · 次数」；底部导航栏不浮在面板上；全程无系统键盘。截图 `a-last-card-set3-weight.png`。
- 未在设备上逐格点完「下一项→确定」：模拟器自动化把面板按钮命中到遮罩的「取消」无障碍元素（遮罩覆盖全屏），无法可靠点击；该流程由 `WorkoutKeypadSessionTests` 等单测覆盖（StudentKit 相关 258 passed）。后续可补：遮罩的无障碍元素不应盖住面板按钮（VoiceOver 体验），列为跟进项。

## 2026-11-07 Opus 设备补验（全流程）

iPhone 17e 学员 demo（同上临时 fixture，源码已还原）：末张辅助卡第 3 组 重量 输入 65 →「下一项 · 次数」→ 12（小数点置灰）→「下一项 · RPE」→ 输入 9.5，主按钮变「确定」→ 确定后面板收起、底部导航栏复位，格内依次为 65 / 12 / 9.5，页面无空白（`b-after-confirm.png`）。第 2 组重量打开面板、键入 7 后点上方遮罩空白处 → 面板收起，值仍为 60（取消语义正确）。全程无系统键盘。上节「未逐格点」一项关闭。
