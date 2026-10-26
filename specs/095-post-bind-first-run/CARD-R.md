# 卡 R · 095 安卓（meetpr-rn）绑定后首次体验

先读仓根 `CONTEXT.md`（「一次绑定」「第一份计划」两条），再读同目录 `SPEC.md`（口径、验收、Out of Scope 以它为准）与 `DESIGN.md`（定稿屏幕稿转写，结构与文案照它做）。

## 目标
安卓两个构建轨都做：待接收页 30 秒轮询、欢迎页、新学员版等计划卡、第一份计划卡、埋点、三语文案。安卓不做任何通知权限按钮（DESIGN 里标「仅 iOS」的元素一律不出现）。

## 文件范围
- `src/navigation/BindGate.tsx`、`src/features/onboarding/bind-model.ts`（轮询、接受后进欢迎页）
- 新增欢迎页组件（放 `src/features/onboarding/` 或 `src/navigation/`，跟随现有结构）
- `src/features/dashboard/DashboardScreen.tsx`、`today-model.ts`、`use-dashboard.ts`（两种等计划卡、第一份计划卡、计划卡显示期间隐藏底部「开始训练」）
- 本地「已看过/已关闭」记录：沿用现有本地存储做法（参考 `src/features/dashboard/plan-seen.ts`），键 = 学员 id + bind_request id
- `src/i18n/catalog/` 新文案（简体、英文；繁体按 spec 094 生成脚本与覆写表生成）
- 对应测试

## 约束
- 判定口径严格按 SPEC「判定口径」；若现有 API 出参判断不了「本次绑定的计划」，在 JOURNAL 写明并回报，不改用别的口径、不改后端。
- 老学员（本次绑定已有结算过的训练日）首页与现状逐字一致；两周之间的原等计划卡逐字不变。
- 不改 tab 结构、不改资料向导、不加依赖。
- 不 commit、不 push（Opus 收货后提交）。

## 验收
SPEC「验收清单」中安卓适用的第 1、2、5、6、7、8、9 条。你负责：单测先红后绿 + 全量 Jest/tsc/lint 绿 + 在 AVD 上用本地 fixture 走一遍第 1、2、5 条并截图（存 `docs/evidence/spec095-<日期>/`）。fixture 可参考 `docs/evidence/spec093-2026-10-17/fixture-server.cjs`，需补 onboarding PUT/complete、bind-requests POST/mine 状态切换与计划列表。

## 测试 seam
- `resolveBindGateState`（bind-model.ts）与 `todayModel`（today-model.ts）作纯函数先红后绿：欢迎页判定、新/老等计划卡判定、第一份计划卡判定。
- `BindGate.test.tsx`：30 秒轮询（fake timers）与「accepted → 欢迎页 → 进入」。
- 首页组件测试：两种等计划卡、计划卡点 × 与点开始后不再出现、计划卡期间底部按钮隐藏。

## 交付
JOURNAL 写 `docs/journal/2026-10-26-095-R.md`（一卡一文件）。最后回报：改动文件列表、测试数字、截图路径、与 SPEC/DESIGN 不符或做不到的地方。
