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

### F-011 — 公司注册(杭州互联网科技)+ side letter + 银行开户

- **触发条件**:满足以下任一
  - 你确定了回国时间(用于回国前 1 个月启动远程工商注册)
  - 进入 Stage 5 Open Beta 前 2 个月(ICP 备案需要营业执照,反推时间)
  - 第一笔有意向收款 / 投资 / 任何对公需求出现
  - 三人 acknowledgment 对话约定推进时间表
- **前置确认**(走流程前必须答清):
  1. 邓天平是肖天宇 / 里欧 / 还是第三方?(目前阿里云实名主体是邓天平个人,影响 ICP / 微信支付 / Apple 公司账号绑定)
  2. David 持中国大陆身份证还是英国护照?决定走"内资有限公司"(¥2k-5k 代办)还是"WFOE 外商投资"(¥30k+ 法律费 + 1-3 月审批)
- **动作**:
  1. **三人 align 公司基本信息**(本周内): 公司名 3-5 候选 / 注册资本认缴 100 万 / 经营范围 "互联网科技 / 软件开发 / 健身咨询 / 体育赛事策划" / 注册区滨江(互联网创业政策最优)/ 法人 = David
  2. **联系杭州代办**(¥2000-5000 全套含核名 + 营业执照 + 印章 + 国税登记): 杭州金算盘 / 创鼎 / 鼎承类;微信沟通模板已存档于 PRD session(2026-04-26 16:28 archive),要点:海外远程注册 + 集群注册地址(滨江)+ 法人 N 个月内回国办银行 + 100 万认缴 + 三股东但起步 100% 法人持股需律师 side letter
  3. **联系律师起草 side letter**(¥3000-10000): 浙江凯麦 / 六和 / 天册;David 100% 持股 + 4y vesting + 1y cliff;T+0 = team-governance.md 三人签字日;T+9m = 评估期结束按 35/45/20 比例落地股权;含 leaver 条款
  4. **浙里办 APP 实名认证 + 公司设立电子签**(需大陆手机号 + 银行卡支付绑定 — 提前确认未停机/注销)
  5. **拿到营业执照后**(空窗期能做): Apple Developer 公司账号 ¥1948/年 + 邓白氏码 / 软著申请(用营业执照 + 代码) / 准备 ICP 备案材料 / 跟肖+里欧签草签 service 合同
  6. **回国后 1 周搞定**(必须本人到场): 银行基本户(招商 / 工商 / 杭州银行 / 浙商银行 任 1 家,1-3 小时面签)+ 税务报到 + 票据申请
- **验证**:营业执照 + 5 章(公章/财务章/法人章/合同章/发票章)+ 银行基本户全到位;team-governance.md 三人签字 + side letter 律师存档
- **为什么等**:
  - 你目前在英国,1-3 个月内回国;银行开户必须法人本人到场(反洗钱不可绕)
  - 现阶段 0 收入 0 收款需求,"成立但无对公账户"的空窗期没有直接价值,且每年要报税(即使无收入)
  - 实名认证主体目前是邓天平,在确认其身份前推进会带来未来公司过户复杂度
- **不要做的事**(防止过早动作):
  - ❌ 让代办公司起草 side letter(他们只是工商代理,股权法律不专业)
  - ❌ 注册资本写过高(如认缴 1000 万),未来融资 dilution 复杂
  - ❌ 无 acknowledgment 对话签字就推进 side letter(即使 David 100% 起步,肖+里欧也要确认内容)
- **成本预估**:¥5000-15000 全套(代办 ¥2000-5000 + 律师 ¥3000-10000 + 印章/快递杂费)
- **创建于**:2026-04-27

### F-012 — Bundle ID `com.meetpr.app` 公司账号迁移

- **触发条件**:Apple Developer 公司账号完成注册/迁移,且 App Store Connect 可创建正式 App ID
- **动作**:
  1. 在 Apple Developer / App Store Connect 用公司团队认领 `com.meetpr.app`
  2. Xcode Signing & Capabilities 切到公司 team,保留 bundle ID 不变
  3. 更新 `MeetPR.xcodeproj` signing 配置和 CI 签名策略(如需)
  4. 验证 simulator build/test 不受影响;真机签名 build 通过
- **验证**:公司 team 下 `com.meetpr.app` 可签名安装;CI simulator build/test 仍绿
- **为什么等**:当前 spec 001 只需要 placeholder bundle ID 和 simulator 验证;公司账号注册另议
- **创建于**:2026-04-27

### F-013 — Logo SVG / wordmark 真实资产落地

- **触发条件**:真实 MeetPR wordmark / app mark 设计定稿,或首个 onboarding / marketing / App Store 截图 spec 进入 Ready
- **动作**:
  1. 用真实 `meetpr-wordmark.svg` / `meetpr-mark.svg` 替换 design-bundle 占位资产
  2. 新增 DesignSystem logo/mark 原子组件或 asset catalog 条目(按当时 spec 决定)
  3. 验证 dark / light / small-size rendering,尤其是 onboarding splash 和 AppIcon 预览
- **验证**:Xcode asset preview + 模拟器 dark/light 截图都清晰;占位 logo 不再出现在 app UI
- **为什么等**:spec 003 只有占位 SVG,真实品牌资产未定稿;提前实现会把占位视觉固化进代码
- **创建于**:2026-04-27

### F-014 — 完整 SF Symbols ↔ Lucide mapping 表产品化

- **触发条件**:第二个 feature spec 需要新增超出 spec 003 的 icon,或任一 UI kit screen 开始实装 tab / chart / upload / settings 等 icon-heavy 视图
- **动作**:
  1. 从 `specs/003-design-system-foundation/design-bundle/project/assets/icons/MAPPING.md` 整理完整生产映射
  2. 在 DesignSystem 中提供受控 icon API 或文档(按当时 spec 决定)
  3. 补缺失映射,并确认每个 SF Symbol 在 iOS 17 可用
- **验证**:所有 feature 使用 SF Symbols,无 Lucide/SVG/emoji/custom icon 进入 SwiftUI 代码
- **为什么等**:spec 003 只锁 4 个 icon;完整 mapping 需要跟真实 feature 用例一起验证语义
- **创建于**:2026-04-27

### F-015 — 首个 coach planning spec 必须按 v4.4 设计写(防 v4.3/v4.2 误引用)

- **触发条件**:写第一个 coach planning UI 相关的 spec(很可能是 spec 004 或之后,任何涉及"教练排计划 / 4 周 / 周卡片 / cycle 历史 / Excel 预览"等关键字的 spec)
- **动作**:
  1. 阅读 `~/Brain/wiki/projects/MeetPR/coach-planning.md` §7b/7c/7d **v4.4**(2026-04-28 pivot 后版本)
  2. 阅读 `~/Brain/wiki/projects/MeetPR/meetings/2026-04-28-office-hours-iphone-macro-pivot.md` 了解决策原委
  3. spec SPEC.md 的"参考"段落显式引用 coach-planning v4.4 + 注明已废弃版本(v4.3 4 周扫视态 / v4.2 Excel grid)
  4. iPhone 实装的是 **周卡片横滑**(`TabView(.page)`),**不是** 4 周宏观视图
  5. spec 范围**不要**包含波形图 / 变式矩阵 / 密度条等组件——那些去网页端([PD-007](~/Brain/wiki/projects/MeetPR/product-decisions/007-web-companion-macro-analytics.md) V1.x defer)
- **验证**:spec SPEC.md 显式列出 v4.4 引用;扫一遍 spec 不出现"4 周扫视态" / "Excel grid" / "波形图" / "变式矩阵" / "密度条" 字眼
- **为什么记**:CLAUDE.md "Recent design changes (2026-04-28)" 已提示同样信息,但 spec 工作可能跨多个 session / 不同 implementer,FOLLOWUP 是双保险
- **关联**:CLAUDE.md "Recent design changes (2026-04-28)" 节
- **创建于**:2026-04-28

### F-016 — Spec 005 PR 必须 wire `onLogout` callback 到 DraftStore.deleteAll()

- **触发条件**:Codex 在起 `feat/005-coach-planning-step-0-3` PR 时,或在 spec 005 实装 PR (任何把 `DraftStore` / `DraftTrainingPlan` 等 SwiftData @Model class 引入仓库的 PR)
- **动作**:
  1. Spec 005 PR 须把 `MeetPR/Sources/MeetPRApp.swift`(spec 011 文中写作 `MeetPR/MeetPRApp.swift`) 中 `Session` 初始化的 `onLogout: nil` 替换为 `onLogout: { await DraftStore.shared.deleteAll() }`(或等价 DI 写法)
  2. 在 spec 005 实装 PR 的 PR description 显式列出此修改(避免 reviewer 漏检)
  3. 简单手测:教练 A signup → 写 1 个 draft → logout → 教练 B signup → 验证 B 看不到 A 的 draft (per ADR-009 §后续需回顾 #4 跨账号 leak 验证)
- **验证**:`MeetPR/MeetPRApp.swift` 不再含 `onLogout: nil`;手测 1 步通过
- **为什么记**:spec 011 ([SPEC.md](./specs/011-auth-ui-flow/SPEC.md) §3 + Notes) 显式 defer 此 wiring 到 spec 005 实装 PR — 单 spec 内部一致 (auth flow 不依赖 SwiftData),但跨 spec 边界容易遗漏。symptom = 跨账号 draft leak,只能手测发现,值得 trigger-based 提醒
- **关联**:[ADR-009 后果项](~/Brain/wiki/projects/MeetPR/decisions/009-swiftdata-exception-for-planning-draft.md) + [spec 011 §3 deferred wiring](./specs/011-auth-ui-flow/SPEC.md) + [spec 011 review P3 #9](./specs/011-auth-ui-flow/REVIEW.md)
- **创建于**:2026-04-29

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
