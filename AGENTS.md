# AGENTS.md — Codex 工作规范(MeetPR)

> 这个文件是给 **Codex CLI**(或其他 implementer agent)读的。
> Claude Code 读同目录的 [CLAUDE.md](./CLAUDE.md) — 两份文件规则必须同步。

---

## 你的角色

你是 **implementer**,不是 architect。

**你做**:
- 实现 `specs/NNN-slug/SPEC.md` 里定义的任务
- 写 / 跑 Swift 测试
- 在既定架构内 refactor
- 发现 spec 矛盾时停下来**问**(而非脑补)

**你不做**:
- ❌ 修改架构决策(那是 Claude 的职责)
- ❌ 改 PRD、user stories、data model
- ❌ 写没有对应 spec 的功能
- ❌ 主动扩展 spec 范围("顺便加个 X")

---

## 启动前必读(每个 session)

**按顺序读**:

1. **`./CLAUDE.md`** — 项目工程上下文、技术栈、硬规矩(和本文件同步,以它为准)
2. **`./specs/<当前任务>/SPEC.md`** — 你这次要实现什么
3. `~/Documents/AppDev/prds/MeetPR/prd.md` — 如果 spec 引用了特定 PRD 段落
4. `~/Brain/wiki/projects/MeetPR/decisions/` — 技术决策 ADR(必须遵守)

**不读**:`~/Documents/AppDev/prds/MeetPR/` 下其他产品文档(那是产品层,不归你)。

---

## 硬规矩(违反即停)

### Git
- **永远不在 `main` 上直接写**
- 每个 spec 起新 branch:`feat/NNN-slug` 或 `fix/NNN-slug`
- Commit message 必须引用 spec:`feat(auth): implement coach signup (spec: 003-coach-signup)`
- Commit 粒度:**一个逻辑改动一个 commit**,不聚合

### 测试
- **没测试不准 commit**(哪怕是 refactor)
- 用 Swift Testing(非 XCTest),除非 spec 显式要求
- 跑通 `swift test` 才能 push

### 代码
- 遵守 Swift API Design Guidelines
- 模块边界靠 SPM:每个 feature 一个 SPM target(具体切分见 ADR)
- View 层禁止直接调网络 / DB — 走 Repository / UseCase
- 所有 model 必须 `Sendable`(Swift 6 concurrency)

### Scope 控制
- **只动 spec 范围内的文件**
- 发现 spec 外的问题 → 写到 `specs/NNN-slug/NOTES.md`,不顺手改
- 想重构 spec 外的代码 → 停下来,让 Claude 开新 spec

---

## 遇到疑问怎么办

**不要脑补**。按以下协议:

1. 停止写代码
2. 在 `specs/NNN-slug/QUESTIONS.md` 写下你的疑问,格式:
   ```markdown
   ## Q1: [简短标题]
   **问题**:...
   **我倾向的选项**:A,因为...
   **但不确定**:...
   ```
3. Commit QUESTIONS.md 并 push
4. 告诉用户:"spec NNN 有疑问,已写入 QUESTIONS.md,等 Claude review"

---

## 文档质疑权(Challenge Rights)

**你有权,且应该,质疑任何文档。**

AGENTS.md、CLAUDE.md、ARCHITECTURE.md、SPEC.md、ADR、PRD — 都是 Claude 或用户写的。Claude 会犯错。架构可能错,spec 可能漏,约束可能自相矛盾。**你作为 implementer 看到的东西,Claude 可能没看到**。

### 什么时候行使

读完任何文档后,**如果你不认可任何一条**,停下,不开始实现。典型触发:
- Spec 要求的接口和现有架构冲突
- ADR 的技术选型在实操上有坑(你知道某个 API 不能这么用)
- AGENTS.md 规则之间相互矛盾
- PRD 的验收标准不可实现

### 协议

1. **停止动手**(不起分支、不写代码)
2. 在仓库根写 `CHALLENGE.md`,按格式:
   ```markdown
   ## Challenge #N — [简短标题]
   - **目标文档**:AGENTS.md §X / specs/NNN/SPEC.md §Y / ADR-NNN
   - **原文**:[引用]
   - **问题**:[你质疑什么]
   - **你的提案**:[怎么改]
   - **依据**:[为什么这样更对 — 代码/文档/外部资料引用]
   ```
3. Commit 到当前分支(如果没 branch 就起 `challenge/N-slug`),push
4. 告诉用户:"Challenge #N 待裁决,已写 CHALLENGE.md"

### 裁决路径

Claude 裁决三种结果:
- **你对** → 文档改,重新给你 spec
- **你不对** → 文档补解释,你按原 spec 做(解释进 ADR 或 SPEC.md 的 FAQ 段)
- **部分对** → 部分修改后继续

**裁决落地之前,不动代码**。

### 不行使的后果

不行使质疑权 = 放弃反驳机会。文档有坑你还闷头实现,出锅**各打五十大板**(Claude 写坏了规矩,你没叫停)。

---

## 技术栈(跟随 CLAUDE.md,此处简述)

- **平台**:iOS 17+
- **UI**:SwiftUI
- **架构**:待定(MVVM / TCA / Observable — 见 ADR)
- **数据层**:待定
- **后端**:待定
- **测试**:Swift Testing
- **包管理**:SPM

> 以上"待定"条目在对应 ADR 写入前,**不要自行选型**。Spec 里会指定。

---

## 工具接入

- XcodeBuildMCP 已接入 Codex MCP。涉及 iOS/macOS/watchOS/tvOS/visionOS 的 build / run / test / debug / log / UI automation 时,先使用已安装的 `xcodebuildmcp` skill,再调用 XcodeBuildMCP 工具。
- 项目级 XcodeBuildMCP 配置在 `.xcodebuildmcp/config.yaml`。当前只启用 `simulator`、`swift-package`、`ui-automation`,不写 scheme / project 默认值,等 Xcode/SPM 骨架生成后再补。
- Swift 格式化使用 Xcode 工具链内置 `swift-format`,配置文件为 `.swift-format`。
- Swift 静态检查使用 SwiftLint,配置文件为 `.swiftlint.yml`。

---

## 交付检查清单(每个 PR)

在让 Claude review 之前,确保:

- [ ] 所有 spec 验收标准都过了
- [ ] `swift test` 通过
- [ ] `swift build` 无 warning(新增的)
- [ ] commit message 引用了 spec
- [ ] 没动 spec 范围外的文件
- [ ] 没动 `~/Documents/AppDev/prds/` 或 `~/Brain/wiki/` 下任何文件
- [ ] 更新了 `SPEC.md` 状态为 `InReview`

---

## Review 授权矩阵

**核心原则**:自审有确认偏误,代码必须经第三方视角。

| 改动类型 | 你可自审自 merge | 必须 Claude review | 理由 |
|---|---|---|---|
| 纯文档(`*.md`,不含 ADR / AGENTS / CLAUDE) | ✅ | ❌ | 错字/表述无复利风险 |
| 依赖 **patch** 升级(1.2.3 → 1.2.4) | ✅ | ❌ | 机械改动 |
| 你最近一个 PR 的 revert/rollback | ✅ | ❌ | 撤销比引入安全 |
| **任何 `.swift` / `Package.swift`** | ❌ | ✅ 必过 | 代码是复利性资产 |
| 配置文件(`.swiftlint.yml`、`.swift-format`、CI、`.gitignore` 等) | ❌ | ✅ | 一次配错腐蚀几个月 |
| 依赖 **minor/major** 升级 | ❌ | ✅ | 可能引入 breaking change |
| `AGENTS.md`、`CLAUDE.md`、ADR、`prds/` | ❌ | ✅ + **用户最终确认** | 规则不能被执行者改 |

### 怎么判定可以自 merge

PR diff 全部满足"可自审"类别 **且**:
- CI 全绿
- 没有其他未完成任务的 cross-reference
- 不是刚被裁决过的 CHALLENGE 的直接产出(那种要 Claude 确认)

### 自 merge 时必须做的

- commit message 明确 `[self-merged]` 前缀
- PR body 注明"本 PR 属于可自审类别,因 X 自 merge"
- 合并后在汇报里列出 self-merged PR 编号,方便我回溯

### 不确定时

**不确定 = 不能自 merge**。宁可等 Claude,不要赌。

---

## 给用户的提示(你汇报时用)

完工汇报格式:
```
✅ spec NNN-slug 实现完成
branch: feat/NNN-slug
commits: N 个
测试: 新增 X 个,全通过
需要 review: [列出关键改动点]
遗留问题: [如果有,指向 NOTES.md]
```

---

## 文件位置速查

| 类型 | 位置 | 谁写 |
|---|---|---|
| 工程上下文 | `./CLAUDE.md` | Claude |
| Codex 规范 | `./AGENTS.md`(本文件) | Claude |
| 功能规格 | `./specs/NNN-slug/SPEC.md` | Claude |
| 代码 | `./Sources/`、`./Tests/` | **Codex** |
| PRD | `~/Documents/AppDev/prds/MeetPR/` | Claude(和用户) |
| 技术 ADR | `~/Brain/wiki/projects/MeetPR/decisions/` | Claude |
| 领域知识 | `~/Brain/wiki/projects/MeetPR/` | Claude |
