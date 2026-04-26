# FOLLOWUPS — 触发条件清单

> **目的**:解决"以后某某条件满足时再做 X"这类承诺被遗忘的问题。
>
> **机制**:
> 1. 每个新建的 session,Claude **必须读这个文件**(已写进 CLAUDE.md)
> 2. 逐条检查触发条件是否满足
> 3. 满足的 → 主动提醒用户:"FOLLOWUPS.md 中第 N 条触发,是否执行?"
> 4. 未满足的 → 跳过
> 5. 执行完的 → 移入本文件末尾的"已完成"区,保留作历史

---

## 待触发

### F-001 — log4brains 站点化

- **触发条件**:`~/Brain/wiki/projects/MeetPR/decisions/` 下 **ADR 数 ≥ 10**(不含 TEMPLATE.md 和 README.md)
- **动作**:
  ```bash
  cd ~/Brain/wiki/projects/MeetPR/decisions
  log4brains init        # 首次配置
  log4brains preview     # localhost:4004 本地预览
  ```
- **验证**:浏览器能看到 ADR 渲染后的目录 + 详情页
- **为什么等**:现阶段 ADR 少,手动目录够用;>10 个时站点才有价值
- **创建于**:2026-04-24

### F-002 — 生产发布 checklist 适配 iOS

- **触发条件**:MeetPR **首个功能具备 TestFlight 提交条件**(有可运行的 Xcode 项目 + 一次完整的 build/test 流程)
- **动作**:
  1. 参考 `~/Projects/experiments/production-launch-checklist/README.md`
  2. 抽出和 iOS app 相关的条目(跳过 web/CDN/SSL 等非 iOS 项)
  3. 合成 `~/Projects/apps/meetpr/LAUNCH-CHECKLIST.md`
  4. 针对 App Store 审核、TestFlight、crash reporting、privacy manifest、隐私协议等 iOS 特化补充
- **验证**:checklist 覆盖从 TestFlight 到 App Store 提交全流程
- **为什么等**:checklist 在 MVP 没雏形前没意义
- **创建于**:2026-04-24

### F-003 — Brain vault git 化

- **触发条件**:`~/Brain/wiki/projects/MeetPR/` 下文件数 > 30 **或** 出现第一次"找不到某个笔记在哪"的场景
- **动作**:
  1. 评估 Brain 多项目共存结构下 git 化的策略(整体一个 repo vs 分项目 repo)
  2. 处理 Obsidian `.obsidian/workspace.json` 等频繁变动文件的 gitignore
  3. 处理媒体文件(git-lfs 或独立目录)
  4. 决定要不要推 GitHub(全 private / 加密 / 本地 only)
- **验证**:Brain 有完整 git 历史,新增笔记有 commit 记录
- **为什么等**:现阶段笔记少,风险低;大了才值得花精力规划
- **创建于**:2026-04-24

### F-004 — Brain vault 推 GitHub(远端备份 / 跨机访问)

> **2026-04-26 重写**:原条目针对已废弃的 `~/Documents/AppDev/prds/` 仓库。PRD 迁到 Brain vault 后,远端备份目标改为 Brain。需先满足 F-003(Brain 本地 git 化),再推远端。

- **依赖**:F-003(Brain vault 本地 git 化)必须先完成
- **触发条件**:F-003 已完成 **且** 出现以下任一
  - 你开始跨机器工作(办公室 / 家 / 咖啡馆)
  - MeetPR 进入 beta 阶段,需要合作者(教练 / 测试者 / 设计师)访问 PRD 或决策文档
  - Brain 笔记量 > 100 个文件,本地丢失代价过高
- **动作**:
  ```bash
  cd ~/Brain
  gh repo create brain --private --source=. --remote=origin --push
  # 注意:Brain 含潜在敏感内容(用户访谈、商业策略、尚未发布的产品决策)
  # 必须 private;考虑 git-crypt 加密敏感目录
  ```
- **验证**:GitHub 上有 private repo;能从另一台机器 clone 回来并打开 Obsidian 正常
- **风险**:
  - 商业敏感内容(竞品分析、定价策略、用户研究原始数据)上云
  - GitHub 账号被攻破 = 全部商业机密泄漏
  - 缓解:推前过一遍 Brain 内容,把高度敏感的(访谈录音转录、未发布的定价数字)隔离到 git-crypt 加密分支或本地 only 目录
- **为什么等**:
  - F-003 还没完成(Brain 没 git 化)
  - 现阶段单机开发,本地够用
  - 加密 + 远端同步策略需要明确思考,不能为推而推
- **创建于**:2026-04-24
- **最后修订**:2026-04-26(PRD 迁移后重写)

### F-005 — swift-ios-skills 按 SPEC 按需 symlink

- **触发条件**:写第一个需要具体 Apple framework 的 SPEC(比如 SwiftData、SwiftUI Navigation、StoreKit 2 等)
- **动作**:
  1. 从 `~/Projects/experiments/swift-ios-skills/skills/` 挑出 SPEC 涉及的 framework
  2. `ln -sfn` 到 `~/.codex/skills/`
  3. 在 SPEC.md 里显式列出 "建议使用 skill: xxx"
- **验证**:Codex session 里 skill 被识别
- **为什么等**:现在还没第一个 SPEC;提前装 83 个 skill 会污染 context
- **创建于**:2026-04-24

### F-006 — CODEOWNERS + GitHub 合作者配置

- **触发条件**:首次有除你之外的人参与这个 repo(合伙人 / 测试者 / 设计师)
- **动作**:
  1. 创建 `.github/CODEOWNERS`
  2. 调整 branch protection,`required_approving_review_count` 从 0 改为 1
  3. 加合作者到 GitHub repo
- **为什么等**:solo dev 不需要,过早设置反而阻塞自己
- **创建于**:2026-04-24

### F-007 — CI 扩展:测试覆盖率 + build 时长追踪

- **触发条件**:项目有 **5 个以上 feature PR 合进 main**
- **动作**:
  1. CI 加 `swift test --enable-code-coverage`
  2. 输出覆盖率到 GitHub Actions summary
  3. 记录每次 build 时长,异常增长时告警
- **为什么等**:没代码没测试;太早配置等于空转
- **创建于**:2026-04-24

### F-010 — 评估迁移到 gbrain

- **触发条件**:满足以下任一
  - `~/Brain/wiki/projects/MeetPR/` 下文件数 > 100(当前约 11)
  - 关键字搜索常找不到东西(连续 3 次"我记得写过 X 但翻不到"的体验)
  - 想让 Codex / Claude 跨 session 自动检索 Brain(MCP server 需求)
  - Brain 里需要管理 50+ 个实体(人物 / 竞品 / 技术 / 用户访谈)且交叉引用变多
- **动作**:
  1. Clone [garrytan/gbrain](https://github.com/garrytan/gbrain) 到 `~/Projects/experiments/gbrain` 评估
  2. 跑 `gbrain init` 试搭一个 MeetPR 子集
  3. 读 [GBRAIN_SKILLPACK.md](https://github.com/garrytan/gbrain/blob/master/docs/GBRAIN_SKILLPACK.md),挑出用得上的 skill(创业家方向不要,知识检索方向要)
  4. 决定:**全迁移** / **混合**(Brain 写、gbrain 索引)/ **借鉴架构不迁移**
  5. 起 ADR 记录决策(无论选哪条)
- **验证**:决策落地为 ADR;迁移则 Brain 内容能在 Codex/Claude 里通过 MCP 搜到
- **为什么等**:
  - gbrain 设计规模是 17,000+ 页,你目前 11 页
  - Postgres + cron + 29 个 skill 的运维负担,小规模用不抵
  - 现有 Obsidian 关键字搜索 + wikilink 在你这个文件量下完全够用
- **不要做的事**(防止过早优化):
  - 在 Brain < 50 文件时强行迁移
  - 把 gbrain 整套 skill 全装到 ~/.claude/skills/(只挑相关的)
- **创建于**:2026-04-26

### F-008 — 定期 ADR review

- **触发条件**:距离上次 ADR review **满 30 天**(first review: 2026-05-24)
- **动作**:
  1. 过一遍 `~/Brain/wiki/projects/MeetPR/decisions/` 下所有 accepted ADR
  2. 对每个 ADR 的 "后续需回顾" 条件检查是否触发
  3. 触发的 → 起新 ADR 或 superseded 老的
  4. 未触发的 → frontmatter 更新 `reviewed: YYYY-MM-DD`
  5. 把下次 review 日期加进本文件(F-008 的触发日期 +30)
- **为什么**:屎山帖里作者最大的问题之一就是"决策从不 revisit" — 早期决策成了历史枷锁
- **创建于**:2026-04-24

---

## 已完成

_(执行完的触发条目移到这里,保留作历史。格式:日期 + 原触发条件 + 执行结果链接)_

### F-009 — 明确 SPM vs Xcode project(由 ADR-004 锁定)— **关闭于 2026-04-26**

- **原触发条件**:写 ADR-004 之前
- **关闭原因**:ADR-004 已写,内容是后端选型(阿里云 + 自建 Node.js),没在 ADR-004 中显式锁定 SPM vs xcodeproj。但当前 AGENTS.md §技术栈 仍写 "包管理:SPM",这是事实上的隐式锁定;CI 也按 SPM 假设设计。
- **遗留风险**:SPM 选型未走正式 ADR,只在 AGENTS.md 文本里。如未来需要 app-level xcodeproj(比如 widget extension、watchOS target),会需要新 ADR + CI 改造。
- **缓解**:如果 SPEC-001 bootstrap 时发现这是真问题,新起 ADR(ADR-007 或更靠后)正式锁定;CI 同时调整。届时可以从这条 history 反查 context。
- **关闭决定**:用户 2026-04-26

---

## 如何添加新 FOLLOWUP

1. 找到一个 "以后某条件满足时再做 X" 的想法
2. 在"待触发"下加新条目,编号 F-NNN(顺延)
3. 必须有:**触发条件**(可机器验证最好)、**动作**(具体命令或步骤)、**验证**、**为什么等**
4. commit

## 如何标记完成

1. 执行动作
2. 把 F-NNN 条目移到 "已完成" 区
3. 加一行 "完成日期 + 结果链接"
4. commit
