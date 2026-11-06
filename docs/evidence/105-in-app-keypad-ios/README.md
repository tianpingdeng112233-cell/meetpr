# 105 iOS 证据

此目录目前是测试日志和构建错误记录，**没有模拟器截图**。完整执行记录与验收对应关系见 [JOURNAL](../../journal/2026-11-06-105-in-app-keypad-ios.md)。

XcodeBuildMCP 主 scheme 构建因磁盘满失败，随后连接关闭；磁盘清理后重试仍为 `Transport closed`，待客户端重连。CLI 回退受系统缓存目录权限/CoreSimulator 连接限制。不能据此声称 build 或 UI 验收通过。

Opus 后续须用本工作树最终源码构建 `MeetPR`，并在指定 `iPhone 17e`（`5D5FA360-BA49-48C6-A887-2F0D22F89749`）运行学员端，补原卡指定的截图：

- 第一张辅助卡最后一组聚焦面板。
- 中间辅助卡最后一组聚焦面板。
- 最后一张辅助卡最后一组聚焦面板。
- RIR 最末格与「确定」。
- 面板收起后。

同时按原 SPEC 清单核对上下文/三语/单位、取消遮罩、连续录入、tab、保存与离线/整日完成，以及老用户历史第一屏。不得用其他模拟器或旧包截图代替。

补充：已在 `origin/release/1.0@7b7d9067` 复跑原 14 个视频失败测试，全部复现相同 `Cannot Encode`（15 issues），见 [基线日志](baseline-video-tests.log)。本轮 MCP transport 仍关闭，截图继续缺失；不能把基线 SwiftPM 编译通过算作主 scheme iOS 构建通过。
