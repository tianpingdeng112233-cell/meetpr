# 分享标题与关闭回调验证（2026-10-22）

- 分支 `fix/invite-share-wechat`，HEAD `e65a9a6a`。保留上一轮所有未提交改动；本轮不 commit/push。
- 有名标题先改中英字面量断言，实际运行得到 2 个预期失败，再改 catalog 转绿：[red](title-named-red.txt)、[green](title-named-green.txt)。
- 缺名标题独立测试 nil / 空串 / 空白含换行，中英共 6 个预期失败，再实现 `shareTitleFallback` 整句分支：[red](title-fallback-red.txt)。
- 最终 CoachKit macOS 全量 **477 tests / 14 suites 通过，exit 0**：[green](title-coach-green.txt)。既有两处并发 warning 为 `PlanImportCapability.isEnabled`、`UserDefaultsWeightPercentPresetStore.defaults`，本轮未改。
- 全量日志亦有 CoreData 沙箱访问/通知诊断，未导致测试失败；本结果不代表持久化或 iOS 验收。
- 本轮 4 个 Swift 文件 `swift format lint --strict` exit 0、`swiftlint lint --strict` exit 0 / 0 violations：[format](title-swift-format.txt)、[lint](title-swiftlint.txt)。`git diff --check` exit 0。
- 全仓 `rg` 核查 shareTitle / fallbackName key 与旧中英文标题：运行代码和测试断言已更新；旧字面量只存在历史 README 证据与本轮红灯日志，保留历史原貌：[引用清单](title-reference-audit.txt)。原 `fallbackName` 仍供完整邀请语署名使用，不改其文案。
- `completionWithItemsHandler` 对完成、取消均调用 `onDismiss`，经 `Task { @MainActor in ... }` 将调用方 `isSharing` 设为 false。单 URL item source 保持原样。
- 关闭回调未新增单测：现有 seam 是 iOS-only 的 `UIViewControllerRepresentable.makeUIViewController(context:)`，macOS 测试不执行 UIKit，未为测试新增 controller 工厂或伪造 UIKit。iOS 编译及真机完成/取消后的 sheet 验证按任务交 Opus。

测试命令（在仓根运行；红绿定向测试追加对应 `--filter`，首次红灯复核使用 `--skip-build`）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/swift-module-cache" swift test --package-path Modules/CoachKit --cache-path .build/swiftpm-cache --config-path .build/swiftpm-config --security-path .build/swiftpm-security --disable-sandbox --skip-update
```

本轮首个定向红灯使用 XcodeBuildMCP `swift_package_test`；随后用上述命令记录完整断言及退出结果。未运行 iOS 编译、模拟器或真机。

独立只读复核：Standards 无发现；Spec 代码无发现，提醒补 JOURNAL，已追加本轮记录。未使用缺失的 issue-tracker 配置；需求来源为本轮用户明确任务。
