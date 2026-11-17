# 110 iOS 本地双轴审查

范围：`01050524...22ef3fd6`，再加本轮工作区返修与新增 `PlanHandoffRaceTests.swift`。仅当前工作树；reviewer 只读，不运行构建，主代理为唯一写者。用户批准 spec 为需求源，AGENTS / CLAUDE / engineering-workflow 为 Standards 源。未配置 Matt tracker，因此执行 review-loop 自身的本地双轴流程，不声称执行 tracker 工作流。

## Standards

独立 reviewer：`/root/standards_review`。

1. 首轮 P1：同一 VM 换账号时跨 cycle 保留逻辑误留前账号计划。已以双参数红测复现，resetPlanForAccountChange 清理计划/预览/UI；随后绿。
2. 首轮 P2：请求等待期间打开键盘/相机/输入，迟到 handoff 仍可换页。已以延迟仓储 + 输入 123 红测复现（下一计划显示且输入被覆盖）。导航 token、实时 isSafe、最终快照检查使回归绿；另外覆盖 plan/log 两个等待阶段及返回入口。
3. 复审剩余 P2：applyPlan 在派生数据修复 await 后仍返回 true，旧 caller 可清掉新导航。定向返修：尾部重新检查 token/isSafe，复用此前竞态验证；没有额外声称已做专门延迟 derived-repair harness。

## Spec

独立 reviewer：`/root/spec_review`。

1. 首轮 P1：handoff 任意错误回退列表并猜最新，可覆盖正确缓存。403/404/500 红测证明错误选择 Cycle 2；删除回退后保留缓存或抛错，绿。
2. 首轮 P1：异步返回时交互边界失效（C/I）；同上，有延迟 plan/log 及 View 实时闭包证据。
3. 首轮 P2：空计划挡掉定稿③提示。A 已完成 / 空 B / 当前 C 红测复现；前驱改为最近非空计划，绿。
4. 复审 P1：新加 pending 门禁导致预览后无法回到正在练。组记录/日结算两类 pending 红测复现；待同步只读缓存当前计划，禁止跨 cycle 接续。
5. 复审 P2：成功返回 nil 被 ?? 当作网络失败，恢复旧计划。另补权威空结果回归，区分 do/catch 与成功 nil。

## 验证边界

主代理负责本轮测试日志与最终结果；独立 reviewer 未执行测试。真实 API、整包构建、三态截图未通过前不宣称收货通过。

## 最终窄范围复核

- Standards：VERDICT: CLEAN。确认 derived repair 后重新检查 token / 安全边界；原 finding 均关闭，无新增阻断。没有独立 derived-repair 延迟测试。
- Spec：VERDICT: CLEAN。既有五项阻断全部关闭，亲读 `handoff-return-green.log`：两个 test（pending 含两个参数 case）全绿。
- Spec 提醒 `try? applyPlan` 的 unused-result warning；主代理改为显式 `_ = try?`，后续 `media-isolated.log` 编译已不含该 warning。
- StudentKit 全量 1322 tests 中 16 tests / 17 issues 为媒体编码失败；这不因代码审查 CLEAN 而豁免。其余测试、构建、截图以 journal 的实际结果为准。
