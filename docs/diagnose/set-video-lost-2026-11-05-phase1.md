# 视频回看缺失：反馈环与修复记录

状态：本地 Phase 1–5 已完成，H1（组保存中 ID 解析过早返回 nil）经先红后绿证实；Phase 6 代码清理、StudentKit 全量与应用构建已通过，关模拟器命令受本机权限限制失败。线上三次事故是否同因仍待账号/日志核对。

完整证据、假设排序、逐阶段判据、存量找回与只读查询/回填方案，见 [本卡 JOURNAL](../journal/2026-11-05-diagnose-set-video-lost.md)。

原 Phase 1 命令已在修前连续红、修后绿：

```sh
swift test --package-path Modules/StudentKit --skip-build --filter 'VL05VideoLossHarnessTests.cameraReturnOverlappingSetSaveKeepsAllThreeVideos'
```

修前：exit 1，首组 `[false,true,true]`、末组 `[true,true,false]`；顺序对照通过。修后：exit 0，4 个参数组合全绿。随后一次性 Debug harness 已删除，**最终工作树复跑应使用以下正式回归命令，不再使用旧过滤器**：

```sh
swift test --package-path Modules/StudentKit --filter CameraReturnDuringPersistenceTests
```

正式回归同样观察到修前 3 个 issue、修后全绿。初轮仅改 TodayWorkoutViewModel.ensureLoggedSetID；返修第 1 轮已扩展为先持久挂起视频、保存成功后绑定，并消除 nil 删除分支。StudentKit 1105 项、CoreModels 164 项及 iPhone 17e build 全绿，文件清单、恢复边界与新红绿证据见 JOURNAL。没有线上写入，没有 commit/push。
