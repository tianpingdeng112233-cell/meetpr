# Spec 900 — Orchestrator Smoke Target (THROWAWAY, DO NOT MERGE)

## Acceptance criteria
- AC1: 计划列表展示 **438** 个动作（来源：spec 022 §目标 — `InMemoryPlanRepository.previewCatalog()` = 3 synthetic competition lifts + 435 imported from `exercise-library-v2.xlsx` = 438 条 total）。
- AC2: 用户点击「保存」后，编排器以下列顺序与失败语义写入：
  1. **先**写本地缓存（`InMemoryPlanRepository`，V0 唯一持久层 per spec 022 §范围 + ADR-005 §iOS architecture）。本地写入失败 → 整个保存动作失败，UI 报错，不进入下一步。
  2. **后**调用 `RemotePlanRepository.upload(...)` stub（V0 接口占位，无真实 HTTP；返回 `.success` 或 `.failure(.notImplemented)`）。stub 返回 `.failure` → 本地缓存保留，UI 显示「已本地保存，远端同步待 V0.1」提示，不回滚本地写入。
  3. 「同时写入」在 V0 语义下 = 本地写入成功后立即触发 remote stub；不要求事务一致性，不要求 remote 成功才算保存成功。

## Out of scope
- 真实 backend 接入（V0 仅 InMemory + Remote stub；真 HTTP 走 V0.1，per `MeetPR-backend/CLAUDE.md` ❄️ FROZEN callout）。
