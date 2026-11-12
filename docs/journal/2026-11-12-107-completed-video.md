# 107 完成日视频入口回归修复

- 授权：David 直接报告用户完成训练后看不到视频，重申上传中黄色、送达绿色，并要求立即修复。T1 / P1，依据 096 只读回看与 107 视频状态约定。
- 基线：`origin/release/1.0@c89bcff6b6873edceb4b09194579d8243255b131`。在独立工作树 `fix/107-completed-video` 实现；Archive 树与两台 demo 机未改。未调整 build/tag、未执行上传或部署。
- 根因：107 新组行将整个视频按钮放在 `if editable` 内，训练日结算后同时去掉上传状态和回看；旧 096 只读组件不再在新训练页被调用。
- 修复：组行始终接入视频控件；无视频的已完成组仍无拍摄入口。有视频时保持上传中黄、送达绿、失败红；完成日调用现有只读播放器，沿用签名续取、教练点评与视频角标。读取服务端历史视频；存在新远端片与旧本机片时按已解析的最新来源播放。未绑定到组的已上传文件不显示送达绿。

## 开发验证

- Seam：真实 `AllDaySetRow` 渲染接线、视频控件的用户操作、现有 VideoUploadManager/VideoAttachmentViewModel 上传事件与 CompletedVideoReplayModel。复用既有服务/仓储边界测试替身。
- Red：临时恢复 base 的 `AllDaySetRow`，执行 `swift test --package-path Modules/StudentKit --filter completedSetRowRetainsItsVideoControl`，缺少视频控件失败；同脚本 finally 恢复修复版本。证据 `docs/evidence/107-completed-video/video-baseline-red.log`。
- Review Red：旧本机失败片 + 较新服务端片测试先报 `Opened the obsolete local video` 与错误回看目标，修正按播放来源路由。证据同目录 `newer-video-red.log`。
- Green：5 个新增回归覆盖完成组入口、远端只读回看、真实上传事件黄→绿并完成后本机回看、无视频完成组无拍摄入口、最新远端片优先；StudentKit 全量 **1281 tests / 91 suites PASS**。`swiftlint --strict`、`swift format`、`git diff --check` 通过。
- 原生：iPhone 17e / iOS 26.5，MeetPR-DemoStudent / DemoStudent。已完成历史日展开，前两组绿色、无视频第三组无图标；点第一组全屏播放至 0:14，教练已点评与角标正常，无删除/重录。截图同目录 `01-completed-green.jpg`、`02-readonly-playback.jpg`。
- 证据边界：原生播放使用既有 Demo 素材及仓储，非用户账号真实 OSS 上传验证；用户所报视频本身是否送达未查证。无本机缓存的远端视频可回看，其可编辑日重拍/删除为既有缺口，本次未扩展服务端编辑能力。

## 独立审查

- review-loop，本地已固定 base 与本次 3 个代码/测试文件。仓缺 `docs/agents/issue-tracker.md`，未运行依赖 tracker 的 code-review 编排，未私建配置；本地双轴按批准 spec 执行。
- Standards（独立只读 reviewer）：CLEAN，0 实质 finding。
- Spec（独立只读 reviewer）：初审 1 项 P2（较新远端片被旧本机编辑路由截走），红测证实并修复；定向复审 CLEAN，0 未决项。
- 本记录为开发自测/自审证据，不替代 Opus 按 spec 的收货终审或真实账号验收。
