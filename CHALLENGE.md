## Challenge #1 — ScrollPosition is iOS 18+, not iOS 17+
- **目标文档**:AGENTS.md §Swift & SwiftUI 实操约定 / SwiftUI 约定 / ScrollView
- **原文**:定位用 `ScrollPosition` + `defaultScrollAnchor`,不用老的 `ScrollViewReader`
- **问题**:MeetPR 当前平台约束是 iOS 17+。`ScrollPosition` 类型以及 `View.scrollPosition(_ position: Binding<ScrollPosition>, ...)` 在当前 Xcode 26.4 iPhoneSimulator SDK interface 中标记为 `@available(iOS 18.0, ...)`。如果 implementer 在 iOS 17 target 下按此规则替换 `ScrollViewReader`,会产生编译错误或被迫加 availability 分支,但原文没有说明这一点。`defaultScrollAnchor(_:)` 本身 iOS 17 可用,但带 role 的 overload 也是 iOS 18+。
- **你的提案**:改为: "iOS 17 下定位仍允许使用 `ScrollViewReader` 或 `scrollPosition(id:)`; iOS 18+ 且 spec 明确允许时,优先 `ScrollPosition` + `defaultScrollAnchor`。不要把 `ScrollViewReader` 全局禁用。"
- **依据**:本机 SDK 只读核对:
  - `/Applications/Xcode.app/.../SwiftUICore.swiftmodule/arm64-apple-ios-simulator.swiftinterface` 中 `public struct ScrollPosition` 标记 `@available(iOS 18.0, ...)`
  - `/Applications/Xcode.app/.../SwiftUI.swiftmodule/arm64-apple-ios-simulator.swiftinterface` 中 `scrollPosition(_ position: Binding<ScrollPosition>, ...)` 标记 `@available(iOS 18.0, ...)`
  - 同文件中 `scrollPosition(id: Binding<(some Hashable)?>, ...)` 标记 `@available(iOS 17.0, ...)`
  - 同文件中 `defaultScrollAnchor(_:)` 标记 `@available(iOS 17.0, ...)`,但 `defaultScrollAnchor(_:for:)` 标记 `@available(iOS 18.0, ...)`

## Challenge #2 — String.replacing("x", with:) appears invalid for current toolchain
- **目标文档**:AGENTS.md §Swift & SwiftUI 实操约定 / Swift 语言约定 / 字符串
- **原文**:用 `"hello".replacing("x", with: "y")`,不用 `replacingOccurrences(of:with:)`。
- **问题**:当前 Xcode 26.4 toolchain / iPhoneSimulator SDK 的 Swift stdlib 和 Foundation swiftinterface 中没有找到 `String` 上的 `replacing(_:with:)` 方法。Foundation 暴露的是 `replacingOccurrences(of:with:options:range:)`。按原文写 `"hello".replacing("x", with: "y")` 很可能无法编译。即便未来 Swift 标准库存在类似 API,它也需要明确最低 Swift/Xcode 可用性,否则这条规则会诱导 implementer 写出当前 CI 不能过的代码。
- **你的提案**:删除这个硬性禁令,改为: "普通字符串替换允许使用 Foundation 的 `replacingOccurrences(of:with:)`; 只有当项目确认当前 Swift toolchain 支持并通过 CI 验证时,才优先使用标准库 `replacing` 风格 API。"
- **依据**:本机 SDK 只读核对:
  - `rg "func replacing\\(" /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift -g '*.swiftinterface'` 未发现 `String` 的 `replacing(_:with:)`
  - `Foundation.swiftinterface` 中存在 `public func replacingOccurrences<Target, Replacement>(of:with:options:range:) -> String`
