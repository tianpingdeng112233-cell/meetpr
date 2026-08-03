# Spec 069 — 视频后台无感上传

- **状态**: Approved（David 2026-08-03 拍板：成功路径零 UI；失败=时间盒 30 分钟冒头策略）
- **分级**: T2 / P1（NEXT-RELEASE 候选；PR 等 David 终审）
- **前置**: spec 065（8cb7b51 已含）+ 068 已合入 release/1.0。零 backend 改动。

## 背景与拍板

视频体验三波的收官：传得快（065）→ 录得快（068）→ **感知归零（本卡）**。
David 拍板的产品口径：

1. **成功路径零 UI**：录完 → 回放确认 → 「使用」后学员的事就结束了。附件行不展示任何
   上传状态语义（无进度条、无百分比、**无转圈/勾状态点**）——附件在就是在，可删除。
   上传、重试、完成全部后台静默。
2. **失败冒头策略（写死进验收）**：
   - **网络类失败**（超时/断网/5xx/OSS 签名过期）：指数退避静默重试约 1/2/5/10/15 分钟
     五轮，**网络恢复立即插队重传**；自首次失败起 **30 分钟**仍未成功 → 本地通知冒头
     「有 1 条训练视频没传成功，点击重试」。
   - **确定性失败**（4xx 业务拒绝：时长超限/文件损坏/鉴权失效等重试无意义者）：
     **第一次即冒头**，不进退避。
   - **兜底可见性**：学员主动打开 app 时，终态失败的附件永远显示失败态 + 重试按钮
     （不受 30 分钟约束）；退避重试进行中的附件显示为普通已挂载态（≠失败）。
3. **杀 app/锁屏/切后台不断传**：上传迁到 background `URLSession`（系统级续传）。

## 目标

### A. Background URLSession 传输层

- 分片 PUT 从进程内 `URLSession` 换 `URLSessionConfiguration.background`：
  - background session 只支持**基于文件**的 upload task —— `VideoFileChunker` 增加
    「切片落临时文件」模式（分片文件放导出目录旁，随附件清理一起删）；
  - `waitsForConnectivity` 语义生效（系统自动等网，覆盖死进程场景的「有网即传」）；
  - App 被杀后系统完成分片 → `handleEventsForBackgroundURLSession` 唤醒 app，
    重建 pipeline 状态，继续后续分片 / 发 `complete`。
- **分片进度持久化**：每片的 etag 落 repository（现只持久化整条 attachment 状态），
  唤醒/重启后从断点续传，不从第 1 片重来。
- **initiate/complete/delete** 仍走现有 `VideoUploadService`（快速 JSON 调用，在唤醒
  窗口内执行）；协议如需增补分片传输 seam 可以动（此前「协议不动」约束到本卡解除），
  但 initiate/complete/delete 的 DTO 形状与 backend 契约**零改动**。
- **OSS 签名过期**（长退避后 PUT 回 403）：删除远端旧 attachment → 整条重新 initiate
  （文件 20–40MB，重传成本可接受；**不给 backend 加重签端点**）。

### B. 重试调度器（决策表抽纯逻辑）

- `UploadRetryScheduler`（平台中立、macOS host 可测）：输入=失败类型/次数/首次失败
  时间戳/网络状态，输出=立即重试 | 定时退避(具体延时) | 终态失败。退避序列与 30 分钟
  时间盒是它的纯数据。
- 前台：定时器 + `NWPathMonitor` 网络恢复插队;后台：依赖 background session 的系统
  调度（时间盒后台为 best-effort，前台精确——验收按前台路径测）。
- 首次失败时间戳与重试计数持久化，app 重启后按剩余窗口继续。

### C. 失败冒头

- 本地通知走 `UNUserNotificationCenter`：首次视频上传时静默请求 **provisional**
  授权（无弹窗，通知安静进通知中心——与「无感」哲学一致）；若授权被拒则只靠
  打开 app 的失败态兜底。与在飞的 spec 067（APNs 注册）共享系统授权，互不冲突。
- 点通知 → 进 app 定位到失败附件（现有导航能力内实现，不新造深链系统）。
- 通知文案：「有 N 条训练视频没传成功，打开看看」（N 聚合，不逐条轰炸）。

### D. UI 降噪

- `VideoAttachmentSection`：砍掉 uploading（进度条+百分比+取消）与 uploaded（勾+已上传）
  两个状态行的视觉呈现——已挂载附件统一显示为中性态（可删除、可换）;失败终态保留
  现有「上传失败 + 重试/删除」行。pending「处理中」态因 068 直通已近乎瞬时,一并砍掉
  spinner（存留逻辑态但不渲染专门 UI）。
- `TodayWorkoutView` 相机直达入口同口径。
- consent 首次弹窗逻辑不变。

## 文件范围

- `VideoUploadManager*`（传输层替换+分片状态持久化）、`VideoFileChunker`（临时文件切片）、
  `VideoUploadServiceLive`（background session 适配）、新增 `UploadRetryScheduler` +
  通知助手、`VideoAttachmentSection`/`TodayWorkoutView`（UI 降噪）、AppShell 的
  background session 唤醒接线、repository 分片进度字段、单测。
- **不动**：backend、initiate/complete/delete DTO、consent、068 相机、065/068 导出器。

## 硬约束

1. **上传语义不变**：attach → export（直通/转码）→ 分片 → complete 的顺序与幂等语义
   照旧；删除附件仍能取消在途上传并清远端。
2. 分片临时文件必须随「上传成功 / 附件删除 / 终态失败清理」三条路径全部回收，
   不留孤儿文件。
3. 重试不无限：时间盒到期即终态，绝不静默永久重试（电量红线）。
4. 4xx 判定保守：无法归类的错误按网络类处理（宁可多试，不可误判终态）。
5. 通知授权失败不影响上传功能本身。
6. 平台隔离与测试布局守 065/068 样式（调度器等纯逻辑 macOS host 真测）。

## 验收标准

- 单测：`UploadRetryScheduler` 决策表（退避序列/网络恢复插队/4xx 直报/时间盒到期/
  重启后剩余窗口）；分片 etag 持久化 round-trip；临时分片文件三路径回收；
  签名过期→重新 initiate 路径；chunker 文件切片与内存切片逐字节一致。
- 模拟器实测：①上传中杀 app → 重启 → 续传完成且 complete 成功（background session
  模拟器可测）；②飞行模式开→关 → 自动续传；③成功路径全程无任何上传状态 UI（截图）；
  ④失败终态可见可重试。
- StudentKit 全量测试 + swiftlint --strict + swift-format --strict + Demo sim build 全绿。
- 真机 smoke（David，切包前）：健身房场景录完锁屏离开，到家视频已在教练端。
