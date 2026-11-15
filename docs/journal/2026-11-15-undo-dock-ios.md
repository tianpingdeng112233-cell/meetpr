# iOS 训练页撤销完成固定底栏（T1 / P1）

任务源：David 2026-11-15「撤销完成挪进固定底栏」任务卡；沿用 spec 104 的撤销窗口与 spec 107 的全天一览。基线 `68787333cef39a9e5069601018a32d4b5db61cf6`，分支 `fix/undo-completion-dock`，与开工时本地 `origin/release/1.0` 一致。工作目录及产物均在 `/Users/david/Projects/apps/MeetPR-wt-undo-dock`；根目录临时文件试写、删除成功。按任务要求不 commit/push。

## 验收范围

- 可编辑未完成日：现有长按底栏。
- 已完成且 canUndo：原 DayCompletionBanner，下方居中 12pt 灰色 SF Symbol `arrow.uturn.backward` + 原文案 key；整行至少 44pt。
- 已完成不可撤销：仅横幅。
- 历史页 / 不可编辑未完成日：无底栏；视频等待沿用现有行为。
- 滚动区不再渲染完成横幅或撤销入口；末尾动作可完整滚动到可见区域。
- 原回顾与撤销路径、撤销防重入保持，`CompletedDayOverviewCard` 不动。

## 实现

- 新增 `TrainingCompletionDockContent` 与纯 presentation selector，统一选择长按、完成横幅+可选撤销、无底栏；历史页优先隐藏，视频等待路径保留。
- 完成态复用原 safeAreaInset / TrainingCompletionDock 容器的背景、上边线与内边距；从滚动内容删除原横幅和孤立撤销。
- 撤销行 12pt / textMuted / arrow.uturn.backward，44pt 整行热区；复用原异步撤销与防重入状态，mutation 期间 disabled，保留独立 accessibilityIdentifier。
- 测量底栏顶边与 ScrollView 底边，仅为实际覆盖部分补底部留白，避免 safeAreaInset 已缩小视口时重复 padding。
- 横幅外观不变；原生验收发现中心热区缺失，加 `.contentShape(.rect)` 后同坐标可打开原回顾。未改导航、tab、文案、依赖或 CompletedDayOverviewCard。

## 验证记录

首个测试：`TrainingFlowTests.completionDockShowsHoldForEditableDay`。XcodeBuildMCP `swift_package_test` 卡在 ViewInspector 缓存更新，日志出现 `RPC failed; curl 16 Error in the HTTP2 framing layer`，此环境错误不计作红测试。

本地测试使用已缓存的同版 ViewInspector，复制缓存到当前 worktree 的 `.build/undo-dock-cache`，无依赖清单改动：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/undo-dock-module-cache" swift test \
  --package-path Modules/StudentKit \
  --scratch-path "$PWD/.build/undo-dock-tests" \
  --cache-path "$PWD/.build/undo-dock-cache" \
  --disable-sandbox --skip-update --filter completionDockShowsHoldForEditableDay
```

完整日志保存在 `docs/journal/evidence/undo-dock/`。App 验证目标：本 worktree 的 `MeetPR.xcodeproj` / `MeetPR-DemoStudent`，仅 iPhone 17e（iOS 26.5，`5D5FA360-BA49-48C6-A887-2F0D22F89749`）。

现场代码确认：spec 107 已停用组间休息计时 UI，`RestTimerOverlay` 当前无调用；本任务不恢复它，也不改变原底栏所在层级。

### 先红后绿

| 阶段 | 结果 | 证据 |
| --- | --- | --- |
| 首个可编辑日 selector 测试 | RED：未实现 completionDock，编译失败 | evidence/undo-dock/red-hold.log |
| 最小 hold 实现 | GREEN：1 测试 | evidence/undo-dock/green-hold.log |
| 完成可撤销 / 不可撤销 / 历史与不可编辑 / 视频等待分支 | RED：8 个断言失败 | evidence/undo-dock/red-states.log |
| selector + UI 接线 | GREEN：相关 12 测试，含既有撤销防重入 | evidence/undo-dock/green-states.log |

Shell 沙箱内全量测试出现 15 个视频编码 `Cannot Encode` 错误，已记录 `studentkit-sandbox-failure.log`，未作为成功。后续改用 XcodeBuildMCP SwiftPM 工具在本 worktree 的真实 `.build` 运行；不使用指向另一构建目录的 symlink，避免 Clang 重复模块路径。

### 原生验收与修复

1. 初次完成态原生快照发现父容器 identifier 覆盖撤销 ID；将 `training.completionDock` 限定在长按分支，完成态原生按钮恢复 `training.completedDay.undo`。
2. 横幅中心点击未打开回顾；针对命中、phase 覆盖、展示失败三假设，只添加 label 的矩形热区进行对照。相同 x195/y678 点击成功，探针证实 callback -> phase review；最终移除全部临时日志。详见 `evidence/undo-dock/review-hit-test.txt`。SwiftPM/ViewInspector 调用 Button.tap 不能覆盖坐标命中，故此项使用原生回归。
3. 已实测撤销回到长按底栏且保留组记录，再次长按完成成功。

### 独立审查

review-loop 独立只读审查 Standards / Spec 两轴均 CLEAN（0 blocker）；最后的 identifier 修复、测试 helper 清理与横幅 contentShape 已复审。未运行 GitHub review、commit 或 push。Matt tracker 配置缺失，未建立私有替代 tracker；当前使用本地双轴 review-loop。

### 验证边界

- 历史 / canUndo=false / 不可编辑分支由 selector 单测覆盖，未另造超 7 天 UI fixture。
- 当前 spec 107 不渲染休息条，无法展示休息条与底栏同时在场；本卡保留其原有挂载层级和逻辑，不复活已停用 UI。
- 未验真机、其他机型、深色或 Dynamic Type 各档；本卡指定的 iPhone 17e 中文浅色布局已留截图。

## 最终结果（2026-11-15）

- `XcodeBuildMCP.swift_package_test({packagePath: "/Users/david/Projects/apps/MeetPR-wt-undo-dock/Modules/StudentKit"})`：**1291 tests / 94 suites，0 failed，0 skipped**，51.77s；新增两个测试方法覆盖任务卡全部四类状态及视频等待兼容分支。日志：[studentkit-final.log](evidence/undo-dock/studentkit-final.log)。
- `XcodeBuildMCP.build_run_sim`：`MeetPR.xcodeproj` / `MeetPR-DemoStudent` / iPhone 17e iOS 26.5，**BUILD SUCCEEDED**，90.424s，无工具报告的 warning/error。参数 `extraArgs: ["-skipPackageUpdates", "-packageCachePath", "<worktree>/.build/undo-dock-cache"]`；`launchArgs: ["-student-empty-state", "pct-anchors", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-meetpr.appearance", "light"]`。输出目录 `<worktree>/.build/undo-dock-app`；原始工具结果与日志路径：[final-validation.json](evidence/undo-dock/final-validation.json)。
- 对 9 个改动 Swift 文件逐个运行 `swiftlint lint --strict <file>`、`swift format lint --strict <file>`：全通过；`git diff --check` 通过；源码无诊断探针。
- 最终无探针 App 原生验收：长按完成→奖励自动关闭→固定完成底栏；横幅中心点击→回顾；返回→展开末张山羊挺身→滚到末尾，最后一组完整位于底栏上方；撤销→长按底栏恢复、组记录保留；再次长按完成成功。

截图（均为最终无探针构建，已亲眼检查）：

- [完成态固定底栏](evidence/undo-dock/completed-dock-iphone17e.jpg)
- [末张动作与组行不被遮挡](evidence/undo-dock/last-exercise-visible-iphone17e.jpg)
- [横幅打开训练回顾](evidence/undo-dock/review-opened-iphone17e.jpg)
- [撤销恢复长按底栏](evidence/undo-dock/undo-restores-hold-iphone17e.jpg)

仅修改 TodayWorkout 源码/测试及本 journal/evidence。分支未变，未 commit/push。
