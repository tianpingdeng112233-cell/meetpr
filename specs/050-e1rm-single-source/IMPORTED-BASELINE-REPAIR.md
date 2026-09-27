# 修复导入估算锁死实练 e1RM

2026-09-27 David 在真实数据诊断后授权修复。T2 / P1，基底 origin/release/1.0@abc7154d。

## 目标与范围

实练异常基线只取同学员、同比赛主项的 normal + logged 点。导入/assumed 点保留展示和导入复核语义，不作为实练异常基线；首次实练沿用既有冷启动规则。10%/18% 阈值和组配入选、公式、主项解析、重量 PR 不变。

在既有 E1RMCoachRPEReconciler 刷新入口修复旧历史，并在 Progress 首次读取和刷新前调用同一入口：识别存在可信导入历史、最早合格实练被标 low 的主项，按完整实际日志时序重算该主项。保留导入点及人工复核状态、原 point ID、其他主项置信度、已有 PR；使用版本比较的原子替换，失败或并发写入留到下次重试。修复后的首个实练为 normal，自然解除修复条件，无须清空旧迁移标记或反复写盘。

## 验收与测试 seam

沿用已批准诊断中的 E1RMRecorder.record、E1RMHistoryReplayService.rebuild，以及 E1RMCoachRPEReconciler.reconcile → Repository / GrowthCurveViewModel.load / GrowthScreenPresentation.snapshot 的公开行为接口。真实案例按去身份化字段重放：38 组里 5 导入、2 高次数不入选、31 实练；升级刷新恢复可信实练和曲线。覆盖导入高值复核不被改写、实练误录继续隔离、不同主项不被误改、重复刷新零写、失败重试、并发写保护、持久化仓储重开后的首屏。

## Out of Scope

不改暂停变式的入选、不修平值曲线文案、不改公式/阈值、不改变后端/网页/Android、不迁移或删除服务器训练日志、不生成追溯 PR 或通知、不改 build/tag、不 Archive/Upload。main 的旧形态与独立算法波冻结，不借本次修复合入。
