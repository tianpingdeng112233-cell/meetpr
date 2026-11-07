# 105 iOS — 数字面板遮罩无障碍修复

状态：开发修复与本地验证完成，待 Opus 收货；iPhone 17e 的 AX 命中与 VoiceOver 尚未验收。未 commit、未 push。

## 范围与根因

- T1 / P1，随 iOS 1.0(33)。需求为 David 本卡与 [spec 105](../../specs/105-in-app-keypad/SPEC.md)，不修改原验收清单。
- 分支 `fix/105-keypad-scrim-a11y`，开工 HEAD 与本地 `origin/release/1.0` 均为 `c7af485785dae08daa368ebf4062e9acbb490df8`，包含 #421（`ee6ba980`）。开工工作区干净；未 merge/cherry-pick main。
- Opus 在 iPhone 17e 复现：主按钮坐标的 AX 命中返回全屏「取消」遮罩，AXPress 关闭面板。
- 代码对应原因：`WorkoutKeypadOverlay` 的全屏遮罩是带「取消」label 的 Button，没有 `accessibilityHidden`；视觉上位于面板之后仍会暴露覆盖整屏的无障碍命中区域。面板此前也没有 modal、escape 或初始无障碍焦点设置。
- 已有设备复现明确了目标和根因，本轮不重做多假设排查；用结构回归锁定遮罩暴露问题，实际坐标命中留给设备复验。

## 测试 seam 与边界

- 使用现有 StudentKit + ViewInspector 0.10.3，通过实际 `WorkoutKeypadOverlay` 检查遮罩隐藏，并调用原 Button 验证取消不提交。
- ViewInspector 的 Button 类型与 label 可检查；这些是 SwiftUI 结构测试，不是系统 AX 树或坐标命中测试。
- 该版本 `AccessibilityModifiers.swift` 的 `v3AccessibilityAction` 在 macOS 13+ 明确抛出不支持 action inspection；没有公开的 traits、child behavior 或 AccessibilityFocusState 读取接口。因此不伪造 escape/traits/焦点断言，也不新增镜像实现的测试元数据。escape 直接接 `session.cancel`，其无提交关闭语义已有 session 测试。
- 设备侧仍需按本卡要求复验：数字键、取消、下一项/确定的命中与 AXPress；打开面板后焦点位于面板且不能进入背后列表；双指 Z 取消；普通触摸空白取消；主项 SetEntrySheet 与视觉不变。

## 改动

- `WorkoutKeypadOverlay`：用 `accessibilityHidden(true)` 替代遮罩的「取消」label，保持原 Button 触摸回调与视觉。面板使用 `.contain` 保留子按钮，以上下文作为容器 label，增加 `.isModal` 与 `.escape → session.cancel()`。
- 面板的 `AccessibilityFocusState` 绑定当前 cell 地址；现有 `.id(cell.id)` 重建面板时，`onAppear` 将焦点设到新面板，覆盖首次打开与「下一项」切格。
- `StudentRootView`：在 keypad overlay 前，对底层页面（含 tab）设置 `accessibilityHidden(workoutKeypad.current != nil)`；面板关闭后自动恢复。不改变普通触摸、导航或布局。
- 新增 `WorkoutKeypadAccessibilityTests` 4 个测试。共享 `MeetPRNumberPad`、主项 `SetEntrySheet`、本地化资源、数据与保存逻辑均未修改。

## 验证记录

全部测试在 macOS SwiftPM / Swift 6.3.3 运行，不代表 iOS 模拟器或 CI 通过。

| 检查 | 结果 | 本机原始日志 |
| --- | --- | --- |
| 修改前遮罩结构回归 | **1 failed / 1 issue**：`Button ... does not have 'accessibilityHidden' modifier` | `/private/tmp/meetpr-105-a11y-red-scrim.log` |
| 修复后同一遮罩回归 | **1 passed**，同时检查触摸取消无提交 | `/private/tmp/meetpr-105-a11y-green-scrim.log` |
| DesignSystem 全量 | **80 passed / 18 suites** | `/private/tmp/meetpr-105-a11y-design.log` |
| StudentKit 相关集（含新增 4 个测试） | **262 passed / 33 suites，0 failures**；4 个新增测试全部通过 | `/private/tmp/meetpr-105-a11y-student-related.log` |
| SwiftLint strict、swift-format strict | **3 个 Swift 文件通过，0 violations** | `/private/tmp/meetpr-105-a11y-lint.log`、`/private/tmp/meetpr-105-a11y-format.log` |
| `git diff --check` | 通过 | 本轮 shell 退出码 0 |

StudentKit 相关集 filter：`WorkoutKeypad|[Aa]ccessory|[Ss]etEntry|[Tt]odayWorkout|[Ss]etSync|[Ss]tudentAdded|[Ll]oadType|StudentStringsTests`。

环境：MCP `session_show_defaults` 显示无项目/scheme/模拟器默认值；本卡只跑指定 package 的 macOS 测试，不设置或操作模拟器。首次 MCP SwiftPM 调用长时间未返回，终止等待后回退 CLI；复制发版工作树缓存中的同版本 ViewInspector 0.10.3 checkouts/repositories（revision `e9a06346499a3a889165647e3f23f8a7b2609a1c`），不修改依赖或其他工作树。CLI 使用独立 `/private/tmp/meetpr-105-a11y-{student,design}` scratch、`CLANG_MODULE_CACHE_PATH=/private/tmp/meetpr-105-a11y-clang`、`--cache-path /private/tmp/meetpr-105-a11y-cache --disable-sandbox --skip-update`。首次编译存在既有 `TrainingReminderScheduling.swift` 未使用结果和部分旧测试多余 `try` 警告；本卡文件没有新增 warning。

最后一轮编译 **756.79 秒**、测试 **46.961 秒**；等待期间本机 load average 曾达 230，内存压缩/换页压力高。该轮最终退出码 0，未把等待或未执行的测试记为通过。未运行 StudentKit 无关全量测试、iOS build 或模拟器验收。

## 独立审查

- 按 `review-loop` 对 HEAD `c7af4857` 上的未提交改动及新增测试进行一轮双轴只读审查；父代理是唯一写者。
- **Standards：CLEAN，0 findings**。复核最终两个生产文件与 4 个测试，无架构、依赖、视觉或实现规约问题。
- **Spec：CLEAN，0 findings**。覆盖本卡开发范围，无缺做、越界或错误实现；实际 AX 命中与 VoiceOver 验收保留给 Opus。
- 本仓没有 `docs/agents/issue-tracker.md`；本轮使用已批准 spec 与用户卡的本地审查入口，没有声称运行 Matt tracker 流程。若要启用后者，David 需调用 `$setup-matt-pocock-skills`。

## 代表性 diff

```diff
- .accessibilityLabel(StudentStrings.localized(.addedCancel))
+ .accessibilityHidden(true)

+ @AccessibilityFocusState private var focusedCell: WorkoutKeypadCell.Address?
+ .accessibilityElement(children: .contain)
+ .accessibilityLabel(cell.context)
+ .accessibilityAddTraits(.isModal)
+ .accessibilityAction(.escape) { session.cancel() }
+ .accessibilityFocused($focusedCell, equals: cell.id)
+ .onAppear { focusedCell = cell.id }
  .id(cell.id)

+ .accessibilityHidden(workoutKeypad.current != nil)
  .overlay(alignment: .bottom) {
    WorkoutKeypadOverlay(session: workoutKeypad)
  }
```

## 2026-11-07 Opus 设备复验
- 干净 DerivedData 重编 DemoStudent 装 iPhone 17e（上一轮共用 DerivedData 装到的是旧二进制，遮罩仍带「取消」标签，已排除）。
- 面板打开后在「下一项」位置做无障碍按压：修复前命中遮罩「取消」并关闭面板；修复后命中面板主按钮，面板跳到「坐姿划船 · 第 2 组 · 次数」。原缺陷关闭。
- XcodeBuildMCP 运行时快照里遮罩仍以无标签按钮出现（`workout.keypad.dismiss`），背后列表元素也仍在快照中；快照工具是否尊重 accessibilityHidden 未核实，VoiceOver 真机体验留待真机复核。
