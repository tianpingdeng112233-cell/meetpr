# 098 — 被教练解绑后，绑定页说明原因

- **状态**: Ready（2026-10-30 /grill 共识「确认」）
- **产品正典**: `meetpr-plan-web` 仓 `specs/021-student-rail-unbind/SPEC.md`；后端 `MeetPR-backend` 仓 `specs/057-coach-unbind-alias`。本文件只定学员端（安卓 RN 与 iOS 同批，iOS 仓同目录镜像本文件）。
- **级别 / 节奏**: T1 / P1。两端同批派卡、同批验收。依赖后端 057 部署后才能端到端验；后端未部署时客户端行为与现在完全一致（`ended_at` 不存在）。

## 现状（已核实）

- 两端学员 App 都有绑定关卡：最近一条绑定申请不是 accepted 时停在输入邀请码页；rejected / expired 有提示文案，cancelled 没有。
  - RN：`src/features/onboarding/bind-model.ts` 的 `resolveBindGateState` + `BIND_NOTICES`。
  - iOS：`Modules/StudentKit/.../Bind/BindGateViewModel.swift`（notice 映射在 `.rejected` / `.expired` 分支）；`BindRequest` 模型在 CoreModels。
- 后端 057 起，教练解绑后学员拿到的绑定申请是 `status: 'cancelled'` + 新字段 `ended_at`（非空）+ `coach_display_name`。
- 推送 `bind_ended`：iOS 旧版对未知 kind 只打开 App，正好落在绑定页，不需要路由；安卓 RN 未接推送。

## 变更

1. 两端绑定模型接收可选字段 `ended_at`（缺省为 null，旧后端兼容）。
2. 当最近一条申请 `status === 'cancelled'` 且 `ended_at` 非空：输入邀请码页顶部显示提示（与 rejected/expired 同一位置与样式）：
   - 中文：「{教练显示名}已与你解绑」，第二行「训练记录都还在，输入邀请码可重新绑定」。教练名为空时第一行「教练已与你解绑」。
   - 英文：「{coach} has unlinked you」/「Your coach has unlinked you」；「Your training history is kept. Enter an invite code to link again.」
   - 繁体：走现有繁体生成流程，不手写。
3. 学员已填过入学问卷时，重新输入邀请码后跳过问卷直接提交申请（现有逻辑，验收时确认，不改）。
4. 普通 cancelled（`ended_at` 为 null，即学员自己撤回申请）行为不变，不显示提示。

## 验收清单

1. 两端：被解绑学员冷启动 → 停在输入邀请码页，提示文案正确（三语 + 空名兜底）。
2. 学员自己撤回申请的 cancelled 不显示提示。
3. 输入原教练邀请码 → 不再走问卷 → 等待接受；教练接受后进入 App，历史训练记录都在。
4. 后端未部署 057 时，两端行为与现网一致。
5. 两端单测全绿；iOS 在 `iPhone 17e` 模拟器、安卓在模拟器亲验第 1、3 条。

## 测试 seam

- RN：`resolveBindGateState` 现有测试补「cancelled + ended_at → 解绑提示」「cancelled 无 ended_at → 无提示」。
- iOS：`BindGateViewModel` 现有测试同样两条；`BindRequest` 解码测试补 `ended_at` 有/无。

## Out of Scope

- 学员主动解绑 / 换教练。
- 解绑后放行学员继续练剩余计划。
- 推送路由与安卓推送通道。
