# 全天一览组行视频上传填充

David 确认双端采用 HTML 预览的从下往上版本并随下一班车交付。本卡负责 iOS 的全天一览组行，Android 在 meetpr-rn 单独交付。拍摄、回放、失败重试与服务端送达协议沿用现有行为。

- 测试 seam 为正常组行按钮、传输字节统计与上传状态。按每个分片实际长度合计，已持久化 ETag 与进行中的 PUT 去重，含短尾片与重启恢复。旧记录无需迁移。
- iPhone 17e / iOS 26.5 / MeetPR-DemoStudent，通过临时验收宿主驱动原组行和 BackendVideoUploadService，对本机限速 HTTP 服务发出 15,206,421 字节的单分片文件。读到 44.8% 时确认图标下半部填黄，PUT 完成并收到 complete 响应后确认 100% 绿色实心。宿主与本地服务未进入提交。证据见本任务 outputs/ios-camera-uploading.jpg、ios-camera-delivered.jpg。
- 红绿覆盖旧版已送达仍为轮廓、上传中字节与百分比、读取缓存先于上传模型的恢复顺序，以及精简 VoiceOver 百分比。训练日完成后仍可点绿色摄像头回放。
- Standards 与 Spec 两轴均指出同一处恢复时序：回放缓存提前到位会让监听过早退出。已改为仅以就绪的实时上传记录启动监听，此前用持久化的分片字节回显。
- 收货复核：Standards 与 Spec 分别复核通过。实测部分的 VoiceOver 百分比按整数读出。最终 StudentKit 全套 1,302/1,302 通过（94 suites）。高负载运行曾出现超时，单项复测及最终串行整套通过。变更 Swift 文件的 swift-format lint 与 SwiftLint strict 均通过。
- 验收宿主移除后，MeetPR-DemoStudent 再次构建成功，已在 17e 打开正常训练页。NEXT-RELEASE 已登记 1.0(41) 候选。
