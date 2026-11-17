# 返修 1 独立审查

范围：本轮开始时的未提交 iOS 卡为基线，仅检查返修增量。Standards 与 Spec 为两个独立只读 Codex reviewer；主代理为唯一写者。未运行需要 tracker 配置的完整 Matt 分支审查。

## Standards

首审发现 1 个 P2：旧 `conversationID` 赋值后无清理路径，不代表正在显示的模态，将它作为阻断会永久隐藏圆环。已从门禁移除该状态及未绑定呈现的 `showingNotifications`。

定向复审：CLEAN。补充视频 sheet 关闭回调与子行 Preference 合并后再次定向检查：CLEAN。

## Spec

首审发现 1 个 P2 BLOCKER：缺失视频 `missingAttachment` sheet 与删组 `showsRemoval` 确认框未纳入门禁。已接入这两个现有状态；视频回放／补选沿用实际 `onDismiss`，全天一览 OR 合并子行的 Preference。

定向复审：CLEAN。使用数据告知、绑定欢迎、周期接续、训练页可见性均复用现有状态，无延时猜测。

审查覆盖代码；构建、全量测试与模拟器取证由主代理单独执行，结果见同目录返修证据与 JOURNAL。
