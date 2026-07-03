# specs/ — 实现规格

> 给 Codex(或任何 implementer agent)读的**原子任务规格**。一个 spec = 一个 PR。

## 索引（001–044）

> **本表是 spec 状态的权威视图。** 各 `NNN-slug/SPEC.md` front matter 里的「状态」字段大多停留在起草期(Draft / InReview / Ready)已过时,**以本表为准**。状态 = 相对 `main` 的真实态;impl PR = 主实现 PR(部分 spec 有 stacked / 二遍 / amend PR,只列代表性的)。

| NNN | slug | 状态 | impl PR |
|---|---|---|---|
| 001 | bootstrap | ✅ 已合并 | [#14](https://github.com/tianpingdeng112233-cell/meetpr/pull/14) |
| 002 | core-models-identity | ✅ 已合并 | [#17](https://github.com/tianpingdeng112233-cell/meetpr/pull/17) |
| 003 | design-system-foundation | ✅ 已合并 | [#18](https://github.com/tianpingdeng112233-cell/meetpr/pull/18) |
| 004 | core-models-training-plan | ✅ 已合并 | [#21](https://github.com/tianpingdeng112233-cell/meetpr/pull/21) |
| 005 | coach-planning-step-0-3 | ✅ 已合并 | [#25](https://github.com/tianpingdeng112233-cell/meetpr/pull/25) |
| 006 | coach-planning-step-4-accessories | ✅ 已合并 | [#34](https://github.com/tianpingdeng112233-cell/meetpr/pull/34) |
| 007 | coach-planning-step-5-7-week-card-swipe | ✅ 已合并 | [#37](https://github.com/tianpingdeng112233-cell/meetpr/pull/37) |
| 011 | auth-ui-flow | ✅ 已合并 | [#27](https://github.com/tianpingdeng112233-cell/meetpr/pull/27) |
| 020 | v0-demo-orchestration | ✅ 已合并 | [#41](https://github.com/tianpingdeng112233-cell/meetpr/pull/41) |
| 021 | apple-readiness-assets-and-signing | ✅ 已合并 | [#44](https://github.com/tianpingdeng112233-cell/meetpr/pull/44) |
| 022 | exercise-library-v2-import | ✅ 已合并 | [#51](https://github.com/tianpingdeng112233-cell/meetpr/pull/51) |
| 023 | planning-numeric-input | ✅ 已合并 | [#54](https://github.com/tianpingdeng112233-cell/meetpr/pull/54) |
| 024 | student-p0-views | ✅ 已合并 | [#140](https://github.com/tianpingdeng112233-cell/meetpr/pull/140) |
| 025 | real-auth-login-keychain | ✅ 已合并 | [#145](https://github.com/tianpingdeng112233-cell/meetpr/pull/145) |
| 026 | backend-wiring-deploy | ✅ 已合并 | [#140](https://github.com/tianpingdeng112233-cell/meetpr/pull/140)(backend [#114](https://github.com/tianpingdeng112233-cell/meetpr/pull/114)) |
| 027 | video-upload | ✅ 已合并 | [#158](https://github.com/tianpingdeng112233-cell/meetpr/pull/158) |
| 028 | e1rm-curve-pr-push | ✅ 已合并 | [#153](https://github.com/tianpingdeng112233-cell/meetpr/pull/153) |
| 029 | coach-student-detail-feedback | ✅ 已合并 | [#150](https://github.com/tianpingdeng112233-cell/meetpr/pull/150)(二遍 [#160](https://github.com/tianpingdeng112233-cell/meetpr/pull/160)) |
| 030 | jai-readiness-timer-platemath | ✅ 已合并 | [#155](https://github.com/tianpingdeng112233-cell/meetpr/pull/155)(§C [#157](https://github.com/tianpingdeng112233-cell/meetpr/pull/157)) |
| 031 | invite-bind-pending | ✅ 已合并 | [#159](https://github.com/tianpingdeng112233-cell/meetpr/pull/159) |
| 032 | onboarding-wizard | ✅ 已合并 | [#159](https://github.com/tianpingdeng112233-cell/meetpr/pull/159) |
| 033 | evaluation-funnel | ✅ 已合并(后 amend 内测停用评估期)| [#161](https://github.com/tianpingdeng112233-cell/meetpr/pull/161)(amend [#190](https://github.com/tianpingdeng112233-cell/meetpr/pull/190)/[#191](https://github.com/tianpingdeng112233-cell/meetpr/pull/191)) |
| 034 | training-tab-redesign | ✅ 已合并 | [#173](https://github.com/tianpingdeng112233-cell/meetpr/pull/173) |
| 035 | dashboard-enrich | ✅ 已合并 | [#172](https://github.com/tianpingdeng112233-cell/meetpr/pull/172) |
| 036 | history-progress | ✅ 已合并 | [#171](https://github.com/tianpingdeng112233-cell/meetpr/pull/171) |
| 037 | coach-triage-strip | ✅ 已合并 | [#176](https://github.com/tianpingdeng112233-cell/meetpr/pull/176) |
| 038 | planning-workspace | ✅ 已合并 | [#176](https://github.com/tianpingdeng112233-cell/meetpr/pull/176) |
| 039 | set-failed-outcome | ✅ 已合并 | [#177](https://github.com/tianpingdeng112233-cell/meetpr/pull/177) |
| 040 | coach-per-set-rest | ✅ 已合并 | [#178](https://github.com/tianpingdeng112233-cell/meetpr/pull/178) |
| 041 | coach-landing-polish | ✅ 已合并 | [#179](https://github.com/tianpingdeng112233-cell/meetpr/pull/179) |
| 042 | coach-video-feedback-inbox | ✅ 已合并 | [#181](https://github.com/tianpingdeng112233-cell/meetpr/pull/181) |
| **043-a** | **analytics-instrumentation** | 🟡 spec + A 组数据层已合,埋点 impl 待 | spec [#185](https://github.com/tianpingdeng112233-cell/meetpr/pull/185) / 数据层 [#196](https://github.com/tianpingdeng112233-cell/meetpr/pull/196) |
| **043-c** | **coach-plan-import** | 🧊 已合并 → 冻结(in-app 入口置灰,web 编写端为唯一导入口)| impl [#189](https://github.com/tianpingdeng112233-cell/meetpr/pull/189) / 冻结 [#203](https://github.com/tianpingdeng112233-cell/meetpr/pull/203) |
| 044 | bench-grip-parameter | ⏳ 待合并(尚未在 `main`) | PR [#194](https://github.com/tianpingdeng112233-cell/meetpr/pull/194) open |

> **⚠️ 043 撞号(历史遗留,不改目录名)**:`specs/` 下有**两个** 043 目录 —— `043-analytics-instrumentation`(埋点)与 `043-coach-plan-import`(教练导入存量计划)。二者是不同 session 独立起号撞车所致。目录名保持原样(改名会断已合并 PR / commit 的引用),本表用 **043-a / 043-c** 区分。引用时务必带 slug,勿只写「spec 043」。
>
> **编号缺口(008–010 / 012–019)**:iOS `specs/` 只放 **iOS 侧** spec,这些 NNN 或归 **MeetPR-backend** 仓的 spec 编号(如 backend spec 005 auth / 008 analytics-events),或从未分配。iOS commit 里出现的「spec 008」(教练 publish,PR #170)指的是 backend 侧 spec,不在本目录。

## 目录结构

```
specs/
  NNN-short-slug/
    SPEC.md          # 主规格(必须)
    QUESTIONS.md     # implementer 遇到疑问回写这里(可选)
```

> **不再有 `REVIEW.md`**:review 反馈走 GitHub PR review comment(直接进 impl PR 讨论),不再单独 commit `REVIEW.md` 文件。见下方「工作流」。

## SPEC.md 格式

```markdown
# NNN — 任务标题

- **状态**:Ready / Blocked / InProgress / InReview / Done
- **PR**:(填入 PR 链接)
- **来源**:`~/Brain/wiki/projects/MeetPR/prd.md#section` 或 user-story ID

## 目标
_一句话_

## 范围
- 做什么
- **不做**什么

## 技术要求
- 模块位置:_待填_
- 接口 / API 签名:_待填_
- 数据结构:_待填_

## 验收标准
- [ ] _可测试的条件_
- [ ] 单元测试覆盖
- [ ] 手动走一遍:_具体步骤_

## 参考
- 相关 ADR:_链接_
- 相关 PRD 段落:_链接_
```

## 工作流

1. **Claude** 写 `SPEC.md`(基于 PRD + 架构)
2. **implementer**(Codex 或 Claude)读 SPEC,起 branch `feat/NNN-slug`,实现并提交 PR
3. implementer 遇到歧义 → 停下来写 `QUESTIONS.md`,不准自己脑补
4. **review 走 GitHub PR review comment**:reviewer 直接在 **impl PR** 里 leave comment(`request changes` / `comment` / `approve`);`request changes` → implementer 在同 impl PR 的 feature branch push 修复 commit,reviewer 复审;approve → squash merge 时在同 PR 内把 SPEC.md 状态翻 `Done`(**不写 `REVIEW.md`,不开 review / finalize 独立 PR**)
5. 合并后 SPEC 保留,成为项目历史

> 完整 review 分工 / 授权矩阵见 [`../AGENTS.md` §PR review pass](../AGENTS.md) 与 [`../CLAUDE.md` §PR Codex review pass](../CLAUDE.md);Claude 起草的 PR 开 PR 前先跑 `/review-loop` 本地互审(真 gate)。上限 **2 PR/feature**(spec PR + impl PR),见 AGENTS.md §Spec 生命周期。

## 硬规矩

- **一个 spec 一个 PR**,不聚合
- **spec 修订走 amendment PR,不建 NNN+1**:SPEC.md 合并后要改(补细节 / 改范围 / 停用),开一个 **amendment PR** 直接改原 `NNN-slug/SPEC.md`(commit message 写 `Amend spec NNN: ...`),**不再新建 `NNN+1` 目录**。先例:spec 033 停用评估期走 amend PR [#190](https://github.com/tianpingdeng112233-cell/meetpr/pull/190)/[#191](https://github.com/tianpingdeng112233-cell/meetpr/pull/191)、spec 043 补别名表走 amend PR [#188](https://github.com/tianpingdeng112233-cell/meetpr/pull/188)。(原「一旦 InProgress 不能改、要改建 NNN+1」的规矩已废 —— 那会制造号段碎片,且与 043 撞号历史叠加更乱。)
- **所有验收标准必须可测**(「看起来好」不算验收标准)
