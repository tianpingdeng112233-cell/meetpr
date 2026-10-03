# 长按完成后立即弹奖励页（iOS）· 收货记录 · 2026-10-03

卡：[CARD-INSTANT-COMPLETION-ios](CARD-INSTANT-COMPLETION-ios.md)。分支 `fix/instant-completion-celebration`，叠在卡 C（PR #349）之上。实装方 Codex，收货方 Opus。

## 自动检查（收货方本机，叠加 7 格周条与中央播放按钮后）

ChatUI 84、StudentKit 929、AppShell 104 通过；SwiftLint 与 swift-format 严格模式 0 违规。

## 实屏（iPhone 17 模拟器，MeetPR-DemoStudent）

记完三组后长按完成：奖励页立即出现并显示教练已收到；Done 后回到 Today，当天标为已完成。[截图](evidence/instant-completion-celebration.jpg)

Demo 配置的完成请求是本地即时返回，"正在发送给教练…"的在途文案、失败回滚、30 秒超时在实屏上看不到，只有单测覆盖（Codex 自述在模拟器上用延迟注入验过，收货方未复核）。

## ⚠️ 未解决：一次主线程卡死

收货过程中出现过一次 App 卡死：三组记完后长按完成，画面停在动作列表展开到一半的状态，主线程 100% CPU 停在 SwiftUI 布局更新里（`LazySubviewPlacements.updateValue`），无障碍树为空。采样见 [docs/diagnose/hang-main-thread-sample-2026-10-03.txt](../../docs/diagnose/hang-main-thread-sample-2026-10-03.txt)。

同一构建上第二次走相同流程没有复现（奖励页正常弹出）。两次的差别：卡死那次在记完最后一组后没有手动折叠 / 展开过动作列表，且在组录入页收起动画未完全结束时就开始滚动。尚不能确定是本卡、7 格周条、还是原有代码引入的。**放行前需要先查清**，已另派排障。
