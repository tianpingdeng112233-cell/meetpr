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

### F-025 — V0.1+ backend 启动前重新申请 RDS 单机版

- **触发条件**:V0.1+ 阶段任一个 spec 需要 backend 真持久化(具体场景:学员端 spec 启动 / 真注册流程 spec / 教练 publish 计划 spec / 视频上传 spec 任一)
- **背景**:试用版高可用系列 ¥580/月在 V0 阶段 overkill,2026-05-11 主动退订,实例 `pgm-bp1s6zj71e62vn01` 已释放
- **动作**:
  1. https://rdsnext.console.aliyun.com → 创建实例
  2. 引擎 **PostgreSQL 17**,**基础版 / 单机版**(不是高可用),华东 1(杭州),专有网络 VPC
  3. 规格 `pg.n2.2c.2m`(2 核 4G,跟原实例同款,V0.1+ 量级够)
  4. 存储 50GB ESSD PL1(高性能)
  5. **包年包月 1 年,开自动续费**(避免再次到期)
  6. 创建后:
     - 数据库名 `meetpr`(同原惯例)
     - 高权限账号 `meetpr`,密码 Bitwarden generator 生成 24 位字母数字(避开阿里云不允许的特殊符号 `! " ' / \ @ : space`)
     - 白名单先 `0.0.0.0/0` 开发用,**上线前收敛**
     - SSL ❌ 关(开发);上线前必开
  7. 更新 `~/Brain/wiki/projects/MeetPR/secrets-pointer.md` §3 用新实例 ID / 新 endpoint / 新创建日期 / 新到期日 替换被划掉的历史值,移除"已退订"banner
  8. 更新 Bitwarden `MeetPR RDS meetpr` 条目密码(从 Bitwarden 把新生成的密码 paste 进阿里云重置密码表单)
  9. 更新 backend `.env.example` 占位 + 提示 ops 设 backend `.env` `DATABASE_URL` 新 endpoint
- **预算**:单机版 2c4G + 50GB ESSD PL1 ≈ **¥150-200/月** ≈ **¥1800-2400/年**(比退订的高可用版 ¥6960/年 省 ~70%)
- **验证**:新实例运行中;backend `swift test` / `npm test` 用新 `DATABASE_URL` 通过;secrets-pointer.md §3 已无"已退订"banner,字段全用新值
- **为什么等**:V0 demo 完全不用 RDS,提前买 = 浪费
- **不要做的事**:
  - ❌ 再买高可用系列(V0.1+ 仍不需要,等 Stage 4+ 多教练用上再考虑)
  - ❌ 跨地域(数据库延迟,坚持 cn-hangzhou)
  - ❌ Serverless(V0.1+ 量级用包年包月稳定 + 计费可预期)
- **关联**:[secrets-pointer.md §3](~/Brain/wiki/projects/MeetPR/secrets-pointer.md);ADR-004 后端选型
- **创建于**:2026-05-11(RDS 试用退订同日)

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

### F-021 — 候选:Step 7 row tap 直跳 Step 5 该 exercise 上下文

- **触发条件**:教练 dogfood 中 ≥3 次反馈"预览卡片里发现某动作强度要改, 但返回 Step 5 再找动作太慢"
- **动作**:
  1. 给 Step 7 `WeekCardView` 动作行增加 tap 行为
  2. NavigationStack 回到 Step 5 并定位到对应 `DraftPlanExercise.id`
  3. 保持长按 Peek 与横滑周卡片手势不冲突
- **验证**:从 W2/W3/W4 任一动作行 tap 后进入 Step 5 对应卡片;edge swipe back 与 card swipe 仍正常
- **为什么等**:V1 Step 7 行只读, 避免本 spec 扩大编辑状态与定位逻辑
- **创建于**:2026-05-09(spec 007)

### F-022 — 候选:Step 7 per-cell W2-W4 单格手覆盖

- **触发条件**:教练 dogfood 中 ≥3 次明确需要"某一周某动作不按规则走, 手动改一次"
- **动作**:
  1. 引入 `ExerciseWeekOverride` 的 iOS draft 表达
  2. Step 7 支持对 W2-W4 单动作派生值手动覆盖
  3. 后续 publish spec 把 override 序列化进后端 payload
- **验证**:有 override 的格子优先显示手填值;无 override 的格子仍由 W1 + rules derive
- **为什么等**:V1 先保持 W2-W4 全 derive, 降低状态空间和发布 payload 复杂度
- **创建于**:2026-05-09(spec 007)

### F-023 — 候选:Step 5 per-set 变化

- **触发条件**:教练 dogfood 中 ≥3 次要求同一动作内 warmup / top set / backoff / AMRAP 使用不同 reps 或 intensity
- **动作**:
  1. 将 Step 5 从 per-exercise 1 个 uniform `DraftSetSpec` 扩展为 per-set list
  2. UI 支持新增/删除 set row 与 set_type 选择
  3. DraftMapping 按 row 原样 expand 为 `PlanSet`
- **验证**:同一动作可保存不同 set type / reps / intensity;旧 uniform draft 可迁移为 N 个 working set
- **为什么等**:V1 只需要完整 W1 基线, uniform working sets 足够支撑 TestFlight happy path
- **创建于**:2026-05-09(spec 007)

### F-024 — 候选:custom rule 复合多维度

- **触发条件**:教练 dogfood 中 ≥3 次需要同一 custom rule 同时改重量/RPE/组数/次数多个维度
- **动作**:
  1. 把 V1 `customDimension` 单选扩展为多维度 payload
  2. `customSequence` 改为按 week + dimension 的结构化矩阵
  3. WeekDerivation custom 分支支持多维度一次应用
- **验证**:一个 custom rule 可在同一周同时产生 e.g. +5kg 与 -1 rep;Codable round-trip 保持稳定
- **为什么等**:V1 custom = 1 维度 / 规则, 需要时可用多条规则表达复合效果
- **创建于**:2026-05-09(spec 007)

---

## 已完成

_(执行完的触发条目移到这里,保留作历史。格式:日期 + 原触发条件 + 执行结果链接)_

### F-002 — 生产发布 checklist 适配 iOS — **关闭于 2026-05-10**

- **原触发条件**:MeetPR 首个功能具备 TestFlight 提交条件(有可运行的 Xcode 项目 + 一次完整的 build/test 流程)
- **执行结果**:`~/Projects/apps/MeetPR/LAUNCH-CHECKLIST.md` 已写,9 stage(A 环境前置 / B build artifacts / C 产品 metadata / D Privacy questionnaire / E 截图 / F upload / G TestFlight 内测 / H Apple 审核提交 / I Release)。Source `production-launch-checklist` 是 web-focused, 大部分跳过, iOS 特化条目从头写(App Store Connect / TestFlight / privacy manifest / Notes for Reviewer 模板等)。
- **满足说明**:checklist 覆盖从 build artifact 验证 → TestFlight upload → Apple 审核提交 → V0 ship 全流程
- **关联**:spec 020 V0 demo orchestration(已合)+ spec 021 Apple readiness(SPEC 已合,impl 进行中)
- **关闭决定**:Claude 2026-05-10(同 PR 合 LAUNCH-CHECKLIST.md 落地)

### F-014 — 完整 SF Symbols ↔ Lucide mapping 表产品化 — **关闭于 2026-05-10(V0.1+ 重启)**

- **原触发条件**:第二个 feature spec 需要新增超出 spec 003 的 icon
- **触发实际状态**:spec 005/006/007/011/020 都有 ad hoc 用 SF Symbols(`Image(systemName:)` 散落在各 view + DemoUserSeed),满足触发
- **关闭原因**:V0 critical path 不要求"完整 mapping 表 + 受控 icon API"。当前各 feature spec 直接 import SwiftUI + 用 SF Symbols 没出问题,iOS 17 可用性也实操 OK。"完整 mapping 跟真实 feature 用例一起验证"在 V0.1+ DesignSystem 重整 spec 时再做更稳(那时全部 V0 feature 已 ship,真实用例齐全)
- **遗留风险**:无外露(短期)。V0.1+ 时若发现某 SF Symbol iOS 17 不可用 / 跨 view 重复 / 命名不一致,起 spec 集中处理
- **关闭决定**:Claude 2026-05-10. 重启条件:V0.1+ DesignSystem icon API spec 启动时复活本 followup 作为 input

### F-007 — CI 扩展:测试覆盖率 + build 时长追踪 — **关闭于 2026-04-30**

- **原触发条件**:项目有 5 个以上 feature PR 合进 main(实际触发时已合并 6 个 feat commit)
- **执行结果**:
  1. `swift test --parallel --enable-code-coverage` 已加到 SPM 测试循环;`xcodebuild test` 加 `-enableCodeCoverage YES -resultBundlePath TestResults.xcresult`
  2. 新增 "Coverage summary" step(`if: always()`),用 `swift test --show-codecov-path` 取每个 SPM module 的 codecov JSON,`jq` 解析 line coverage %;Xcode 总覆盖率从 `xcrun xccov view --report --json` 拿,details 折叠区展示 per-target breakdown
  3. 新增 "Build duration summary" step,用 `date +%s` 在第一个 build 步骤前后打点,wall time 输出到 `$GITHUB_STEP_SUMMARY`
- **验证**:CI 跑出绿色 + Actions run 页面 summary 区能看到覆盖率表格 + 总时长
- **未做的部分**:"异常增长时告警"——需要历史 baseline 对比,目前没数据。如果未来想做,起新 FOLLOWUP 单独跟踪(可选方案:CI 输出时长写到 GitHub Cache,跟历史对比;或接 Codecov 类外部服务)
- **commit ref**:见本 PR(stack 在 ci/cost-optimization 之上)

### F-016 — Logout 清 Coach Planning SwiftData draft，防跨账号 draft leak — **关闭于 2026-04-29**

- **原触发条件**:spec 005 把 `DraftStore` / `DraftTrainingPlan` / `DraftPlanDay` / `DraftPlanExercise` SwiftData draft 持久化引入仓库后，spec 011 auth flow 的 `Session.logout()` 必须清空本机 draft。
- **执行结果**:`DraftStore.deleteAll()` 已落地；`Session(auth:tokenStore:onLogout:)` 在 logout 时调用 cleanup；`MeetPRApp` 注入 `onLogout: { try? await DraftStore.shared.deleteAll() }`，并让 app + Coach Planning flow 共用 `DraftStore.shared` 的同一个 SwiftData container。
- **验证**:PR #27 的 `SessionTests.logoutClearsStoreAndCallsLogoutHookOnce` 覆盖 logout callback exactly once；新增 `DraftStoreTests.draftStoreDeleteAllRemovesEveryDraft` 覆盖全量删除所有 draft。
- **满足说明**:ADR-009 §后续需回顾 #4（跨账号 leak 验证前置工程要求）已满足；教练 A logout 后本机 SwiftData draft store 会清空，教练 B 进入规划器不会恢复 A 的 draft。
- **commit ref**:`9282274` (`fix(coach-planning): clear drafts on logout`)

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
