# 107 · iOS 相册导入无反馈

## 范围与验收

- David 报告：iPhone TestFlight 学员从相册选完视频，停在录像页没有反应。build、原视频、iOS 版本尚未提供。
- 基线 origin/release/1.0 `93261af5`（iOS 40）；T1 单模块修复。仅恢复导入阶段的等待/错误反馈与关闭安全；不改编解码、上传、服务端、训练数据或发版号，不声称修好了未获得样本的原始兼容问题。
- 沿用 107 的真实训练页面交互 seam：AllDay camera → 系统 PhotosPicker → 导入/剪辑；故障只在系统媒体文件边界注入，不 mock App 内部状态。
- 验收：正常选片进剪辑；读取失败在录像页可见；关闭错误后可重新选片；导入时可见等待且能关闭；关闭后晚到结果不重开剪辑；取消/正常上传与原入口回归。

## 诊断证据

- iPhone 17e / iOS 26.5，MeetPR-DemoStudent，生产代码基线正常相册进入剪辑 4 次通过；Demo 点上传回到训练页显示已附视频。Demo 不证明真实服务器送达。
- 2 秒 H.264 合成视频导入 Photos，SHA256 `e939a2cdf22fc85b88f6ec8f87929d208fe8d3411e82f57e0b00cd1fb7f3fb58`。仅临时移走该哈希对应的模拟器素材，选片后 12 秒内无失败/重试可见，仍停留录像页；两次复现。每次 finally 恢复原文件并核验哈希，不碰真实视频。
- 最小反馈环：`python3 work/album-import/repro-missing-source.py`（本次 chat scratch）。输出 `RED: Photos source unavailable; no visible failure/retry; recorder=True`。
- 三个假设排序：失败反馈丢失、导入悬挂、剪辑 presentation 竞争。单点日志证实 `load started` 后立即 `load failed CoreTransferable.TransferableSupportError 0`，无 requested trim；本场景否定后两条。
- 原因：CameraRecorderView.importAlbumVideo 的 nil/throw 分支只调用外部 onFailure。全天一览外部仅设置 VideoAttachmentViewModel.lastErrorMessage，录像页不显示该状态，保持打开。
- 原问题设备的读取失败原因（iCloud、本地文件或格式等）未确定；不能以此受控复现替代原样本验证。

## 修复

- 录制器导入期间显示现有本地化「正在读取视频…」，保留关闭，挡住重复录制/选片。
- nil/throw 在当前录制器显示持久系统 alert，沿用现有本地化处理失败提示；关闭后能重新选择。
- 关闭取消导入 Task；异步完成检查取消/宿主关闭，并释放晚到的临时副本。
- 临时 `[DEBUG-album-1114]` 日志已移除，不采集路径、原异常内容或视频。

## 验证

最终回归与独立 Standards / Spec 审查记录见后文。未合并、未发布。

## 同链路补充复现：剪辑初始化拒绝素材

- 用 ffmpeg 合成一个包含两条视频轨的有效 MP4，原生 Photos 能读出；既有 VideoTrimView.prepare 要求恰好一条轨，拒绝后退回录制器。只修导入 throw/nil 后仍在该样本失败：`verify-camera-album-import.py --expect-failure` 报 `No import failure alert`。
- 同一相册流程的 session.onFailure 同样只通知外层。现在先标记失败并关闭剪辑，在 fullScreenCover.onDismiss 后显示本地错误，避免同时退场/弹窗竞争；不更改现有单轨限制或转码策略。

## 本机验收与审查

- StudentKit：`swift test --package-path Modules/StudentKit --parallel` 1289 tests / 94 suites 通过。iOS-only recorder 分支以实际 iPhone 17e build/native脚本为证，不能用 macOS 测试替代。
- 原生缺失文件测试先红后绿；修后显示系统「视频处理失败,请重试」alert。iOS 26.5 的 AX 类型是 Sheet，脚本初次按 Alert 单类型误报，已据实际截图/节点修正为 Alert/Sheet；旧代码没有错误文本，仍被该断言捕获。
- 双视频轨真实素材：`--expect-failure` 先红后绿；失败后留在录像页并显示相同提示。
- 关闭验证：在 Photos 已读出临时副本之后，临时延迟 provider continuation 8 秒（不可取消的独立 task，用于模拟取消后仍返回的系统调用），`--close-during-import` 见等待状态、点唯一 enabled 关闭按钮、回训练页，10 秒无剪辑/错误重新弹出。晚到结束后 app tmp 中该合成视频哈希匹配副本为 0。临时延迟未入最终源码。
- 独立双轴首轮各指出同一个忙态无障碍P2，已通过 Group disabled/accessibilityHidden + toggleRecording guard 修复。加载快照中旧录制器关闭/相册 disabled，新加载关闭 enabled。两轴复审 CLEAN；双轨失败补充路径定向复审也均 CLEAN。
- SwiftLint strict、swift-format、diff check 与 Python 语法检查通过；loading View 提取至已有 CameraRecorderComponents.swift，满足既有400行上限，视觉不变。
- 原生截图与脚本证据保存在 `/Users/david/Documents/Codex/2026-11-14/you/outputs/ios-album-import/` 及同 chat `work/album-import/`；使用合成视频、DemoStudent，不写真实账号训练数据。
- 原始学员的 build、iOS版本、问题素材仍待提供；本卡证明并修复失败无反馈，不证明原始素材现已能导入或上传。

## 最终代码验证

- 无插桩最终代码：XcodeBuildMCP build_run_sim，MeetPR-DemoStudent / iPhone17e / iOS26.5，BUILD SUCCEEDED（66.9秒）。仅Demo验收包，未生成发布包。
- 同一最终包连续链路：双轨失败 alert → 关闭重选 → 文件不可读失败 alert → 关闭重选 → 正常视频剪辑 → 点上传 → 原组「已附视频」，全部 PASS。媒体文件哈希恢复核验通过。
- 全仓 SwiftLint strict 零输出；变更 Swift 文件 swift-format lint strict 通过；git diff check 通过。代码无临时 DEBUG/delay。
- 原始相册文件保留；本任务两个合成样本留在17e供复验。未改两台demo机、MeetPR-CI或真用户数据。
- 本次提交交 PR（P1，未合并/未发布）；修复必须随新的 TestFlight build 分发才能到学员端。
