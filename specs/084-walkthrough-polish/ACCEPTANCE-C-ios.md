# Spec 084 · 卡 C（iOS）收货记录 · 2026-10-03

卡：[CARD-C-ios](CARD-C-ios.md)。分支 `feat/084c-chat-video-rest`，叠在卡 B（PR #348）之上。实装方 Codex（含返修 2 轮），第 3 处问题两轮未收敛后由 Opus 接手修复。

## 自动检查（收货方在本机复跑）

- `swift test`：ChatUI 84、StudentKit 920 全部通过。
- `swiftlint lint --strict` 与 `swift-format lint --strict`：0 违规。
- Opus 改动部分另经 Codex 只读审查：VERDICT CLEAN，一条小建议已采纳。

## 实屏（iPhone 17 模拟器，MeetPR-DemoStudent）

| 验收项 | 结论 |
|---|---|
| §7 Ask coach 选组 | 通过。训练页入口预选当前组，聊天页 "+" 入口未选组时发送不可用；一页内选组、写问题、发送；底部复述将发送的内容。[截图](evidence/c-ask-coach-picker.png) |
| §8 聊天训练卡 | 通过。一个气泡：问题在上、附件行在下（动作名；`Set 1 of 3 · 175kg × 3 · RPE 8.5`），气泡下 `时间 · Delivered`。[截图](evidence/c-chat-set-bubble.png) |
| §9 原地播放 | 通过（返修后）。内嵌播放器：播放 / 暂停、细进度条（金色已播）、四档倍速向上展开、放大；放大后铺满整屏，顶部条显示动作名与 `Set 1 · 175kg × 3 · RPE 8.5`；缩小回原位，进度、倍速、播放状态保持，页面停在播放器处。[内嵌](evidence/c-inline-player.jpg)、[放大](evidence/c-expanded-player.jpg) |
| §10 休息说明 | 通过。弹层三档 2:00 / 3:00 / 4:00 与默认规则一致；Got it 关闭；链接进入 Rest between sets。[截图](evidence/c-rest-explanation.jpg) |

## 返修经过

1. 第 1 轮（Codex）：放大态顶部条显示 "Set %@"（格式参数未代入）；放大 / 缩小后进度归零；进度条是大白色胶囊。三处均修好。
2. 第 2 轮（Codex）：第 1 轮带出回归——放大后画面全黑，缩小后内嵌也黑。第 2 轮未修好。
3. Opus 接手：加带前缀的临时日志在模拟器上复现，确认原因是放大时新图层先绑定播放器后，SwiftUI 又对即将移除的内嵌图层调用了一次更新，把播放器抢回去，随后拆除内嵌图层时把播放器清空，放大层手里为空。改为按"当前该显示的是内嵌还是放大"来绑定，与调用顺序无关；先写了复现这一调用顺序的回归测试（`staleUpdateFromOutgoingSurfaceDoesNotStealPlayer`）。临时日志已清除。

## 没验到的

- 教练端会话页的同一条气泡（Demo 教练配置未走）；两端共用 ChatUI 的同一组件。
- Dark、小屏与大字体。
- Replace 按钮文案沿用现有的 "Change"（两端一致），未按设计稿改为 "Replace"。
- 真实上传链路（Demo 下视频直接显示 Delivered）。

## 追加：中央播放按钮（2026-10-03）

David 真机反馈"播放器中间应该有一个播放按钮"。DemoStudent 实屏通过：暂停时画面中央显示圆形播放按钮，点它开始播放并隐藏。[截图](evidence/c-central-play-button.jpg)。放大态与播完重播由单测覆盖。
