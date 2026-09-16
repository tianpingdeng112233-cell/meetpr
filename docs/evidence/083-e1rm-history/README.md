# Spec 083 原生验收 — 2026-09-14

范围：学员端 e1RM 节点来源详情、训练页历史入口。已批准设计保留在 `feat/083-e1rm-history` 的 `232b37f0`；实装分支为 `feat/083-e1rm-history-impl`，目标 `release/1.0`。未合并、未发布。

## 自动验证

- StudentKit 全包：869 passed / 0 failed / 0 skipped。
- 新增投影测试先 RED 再 GREEN：选中日赢家与 headline 分离、隔周记录、同值日期、精确组号、已编辑日志不篡改快照、教练 RPE、Epley fallback、不可复现旧值、缺失日志。历史空态和失败后重试成功另补边界测试。
- 修改的 Swift 文件通过 swift-format、swiftlint strict；git diff --check 通过。
- MeetPR-DemoStudent / DemoStudent / iPhone 17 Pro 模拟器 build & run 成功，0 warnings / 0 errors。
- 测试日志：`swift_package_test_2026-09-14T11-44-43-361Z_pid49938_dd2a0173.log`。
- 最终构建日志：`build_run_sim_2026-09-14T11-45-39-425Z_pid49938_aeeb644d.log`。
- 日志所在本机目录：`~/Library/Developer/XcodeBuildMCP/workspaces/Projects-cf51cf27789e/logs/`。

## 原生实点与截图

| 验收 | 证据 |
| --- | --- |
| 历史节点缩小、末点金色；任意节点 AX 可读独立日期及数值 | [亮色成长](lightGrowth.jpg)、[暗色成长](darkGrowth.jpg) |
| 点击 7 月 4 日节点显示 128.8kg，不误用卡片 137.6kg；关闭返回图表原位置 | [亮色详情](lightDetail.jpg)、[暗色详情](darkDetail.jpg) |
| 旧 Demo 点缺失 setLogId 对应日志且源数值无法复现，明确提示原始组及计算明细不可用 | 同上；没有用当前日志伪造组号或算式 |
| 训练顶部历史入口；历史的动作筛选选择“硬拉”后仅显示对应训练日，可正常返回 | [亮色历史](lightHistory.jpg)、[暗色训练](darkTraining.jpg)、[暗色历史](darkHistory.jpg) |
| 记录 2 组后进入历史再返回，仍在第 3 / 3 组，已记录 2 / 3 | [进入前](timerBefore.jpg)、[返回后](timerAfter.jpg) |
| 休息计时在导航期间连续运行，2:53 → 历史中 2:40 → 返回 2:37 | [原生 AX 快照](navigation-snapshots.json) |

模拟器使用本机 Demo 仓储，不代表真实后端验收。新记的 175kg × 3 @8.5 在既有重算后显示 203.5kg；Demo 重放后的该动作仅一个有效训练日，保持原有成形态门槛。完整组号／算式及持久化兼容由投影与 Codable 测试验证，未伪称该单点进入已解锁曲线。

## Pre-PR review loop

固定原生差异基线 `232b37f0`。主代理写代码，两位只读 Codex reviewer 分别审 Standards 和 Spec。

- Standards：CLEAN。初审后复核 AX 定位与低置信选中样式，无未决 blocker。
- Spec：CLEAN。初审建议低置信选中补金边，已保留弱化填充并补金边；AX 标签/定位复核通过。
- 共初审及一次增量复核；0 blocker，1 视觉建议已处理。主代理发现 AX 外层标签覆盖后修正，并在模拟器实际点击验证。最终仅追加空态/重试测试、表面颜色修正及 tuple → struct 的 lint 修正。
- 无待 David 裁决的产品分支；T2 合并仍待 David。
- 完整本机审查记录：`/Users/david/CodexConfig/reviews/2026-09-14-meetpr-083.md`。

仓内未配置 Matt issue tracker，本次采用本地 review-loop 对照已批准 spec。配置此可选工作流需调用 `$setup-matt-pocock-skills`。
