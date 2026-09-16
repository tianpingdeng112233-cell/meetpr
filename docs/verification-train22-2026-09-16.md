# 1.0(22) 五项整合验收 — 2026-09-16

## 批准范围与基线

David 明确批准 #339 / #342 / #341 / #340 / #343 进入下一班车。#339 已在 release/1.0@202e95db；本次以已审组合 chore/finish-1.0-22@ecfb7ae1 为基线，合入 #343@5fbe67b8（6ad6afd7），保留 73fea6d 两条失效 lint 豁免清理。#338 未加入。

## 两项组合修复

代码提交 3acc828：

1. #343 历史入口与详情关闭按钮使用 .plain，覆盖 #341 统一按压；两处改为 PressScaleButtonStyle，无新增触感。
2. Demo 上午补记后进入历史，刚保存的组显示 0/3。补记时间锚为当地正午，历史原查询上界为当前时刻，严格按时间过滤的 InMemory 仓储漏掉当天正午记录。上界改为 max(now, todayNoon)，保留下午普通记录且不包含明天。真实后端按日期查询，不把本次现象报告为已证实的线上数据丢失。

回归 seam 沿用 TrainingHistoryViewModel.load 与真实 InMemoryStudentTrainingLogRepository；先保存组，再加载历史。固定当地 02:00 / 09:00 / 18:00。修前测试在前两种场景失败，修后通过；另加入 17:00 普通记录与次日正午记录，核实下午正常记录可见、明天记录不出现。

## Standards

两名独立只读 reviewer 中 Standards 轴发现两处 .plain 的同一 P2 组合问题；定向返修复审 CLEAN。随后对历史查询修复单独审查，CLEAN，无未决项。

## Spec

Spec 轴独立发现同一按压反馈问题（spec 082 §B.2），定向复审 CLEAN。历史修复符合 spec 081 本地正午锚与 spec 083 历史入口；建议的下午记录、次日排除边界已补入回归。

本次沿用本地 review-loop 双轴收货；仓内未配置 Matt issue tracker，未声称运行其 tracker 工作流。配置该可选流程需调用 $setup-matt-pocock-skills，不影响本次已有 spec 收货。

## 本地验证

- StudentKit：最终 893 passed / 0 failed，含新增历史回归。
- DesignSystem：73 passed / 0 failed。
- 全仓 swift-format strict 与 SwiftLint strict 通过；新增历史修复文件另跑严格检查通过。
- DemoStudent 最终 build/run：MeetPR-wt-train22-integration / MeetPR-DemoStudent / DemoStudent / iPhone 17 Pro，0 warnings / 0 errors。
- 其余模块及主工程由整合 PR 的完整 CI 覆盖，不能把 09-14 的历史组合计数当作本次全套验证。

## 原生复走查

最终代码重新启动 DemoStudent，训练页 W1D3 同时可见历史入口与补记入口；进入补记、按预填 175kg × 3 @8.5 记录三组，长按完成后游标推进 W1D4；再进历史，D3 显示 3/3 及三组真实记录，原 0/3 现象消失。亲看截图确认布局。

- [训练入口](evidence/train22-2026-09-16/training.jpg)
- [补记表格](evidence/train22-2026-09-16/quicklog.jpg)
- [补记后历史 3/3](evidence/train22-2026-09-16/history-after-quicklog.jpg)

Demo 使用本机仓储，不作为线上部署、APNs 投递、真机触感或数据库持久化验收。

## 远端与发布门禁

09-16 重跑 #340/#341/#342/#343 原失败 hosted jobs 后，四项独立 PR 的 Swift Build & Test / swift-format / SwiftLint 全部成功。GitHub billing 不再阻塞本次 CI。最终整合 PR 仍须自身全绿后合入。

本次不改 build 号、不打 beta tag、不 Archive/Upload，也不执行数据库迁移或部署。#340 的 backend #276（0070、镜像、gate）与 web #101、APNs production 配置和实际送达仍待完成；不能把 iOS 落线表述为后移全链路上线。
