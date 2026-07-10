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

### F-030 — spec 045 solo 首轮明示缓交四项

- **触发条件**:U9 polish 批次动工,**或** U10 终验走查发现 solo 体验缺口时优先核对本条
- **动作**:①ExercisePickerSheet 加分类浏览段(主项/辅助,按 `main_lift_family`/`exercise_type`)②solo 会话接 RPE 驱动休息计时器(需把 RestTimerPolicy/Overlay 从 TodayWorkout VM 解耦或镜像)③会话级「未同步」横幅升级为行级角标(需 QueuedTrainingLogRepository 暴露 pending 键集)④solo 链路埋点挂点(`workout_log_start{source:adhoc}` / `set_logged` / `workout_log_save`,埋点 wave 实装时)⑤solo 疲劳自评/readiness 入口(spec 051 §3 核实 solo 无 readiness 采集点;若做,文案「用于你的疲劳走势与休息建议」,严禁「教练」字样)⑥「已超基线」徽标(spec 050 缓交)
- **上下文**:spec 045 §交付状态;缓交理由 = 首轮以主链路闭环优先,四项均不破坏可用性
- **创建于**:2026-07-04

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

> **🔄 进行中(2026-07-03 批注)**:PR [#184](https://github.com/tianpingdeng112233-cell/meetpr/pull/184) "Adopt Stacked Lockup logo for app icon and in-app mark" 正在推进 app icon + in-app mark 的真实 logo 落地,覆盖本条部分动作(占位资产替换)。触发条件视为已部分满足;#184 合并后复核剩余项(tinted AppIcon dark/light 渲染验证、onboarding splash)再决定整体关闭。

- **触发条件**:真实 MeetPR wordmark / app mark 设计定稿,或首个 onboarding / marketing / App Store 截图 spec 进入 Ready
- **动作**:
  1. 用真实 `meetpr-wordmark.svg` / `meetpr-mark.svg` 替换 design-bundle 占位资产
  2. 新增 DesignSystem logo/mark 原子组件或 asset catalog 条目(按当时 spec 决定)
  3. 验证 dark / light / small-size rendering,尤其是 onboarding splash 和 AppIcon 预览
  4. 替换 spec 021 落地的 tinted AppIcon 占位:`MeetPR/Assets.xcassets/AppIcon.appiconset/meetpr-icon-1024-tinted.png` 当前是 `#999` 实心方块,iOS 18 HIG 期望透明背景 + 暗色单色剪影(grayscale alpha mask);真 logo 定稿后重新导出 tinted 变体
- **验证**:Xcode asset preview + 模拟器 dark/light 截图都清晰;占位 logo 不再出现在 app UI;iOS 18 主屏幕 tinted appearance 显示为正确单色剪影,而非灰色实心方块
- **为什么等**:spec 003 只有占位 SVG,真实品牌资产未定稿;提前实现会把占位视觉固化进代码
- **创建于**:2026-04-27
- **最后修订**:2026-05-11(并入 spec 021 P3-1 tinted AppIcon `#999` 占位)

### F-021 — 候选:Step 7 row tap 直跳 Step 5 该 exercise 上下文

- **触发条件**:教练 dogfood 中 ≥3 次反馈"预览卡片里发现某动作强度要改, 但返回 Step 5 再找动作太慢"
- **动作**:
  1. 给 Step 7 `WeekCardView` 动作行增加 tap 行为
  2. NavigationStack 回到 Step 5 并定位到对应 `DraftPlanExercise.id`
  3. 保持长按 Peek 与横滑周卡片手势不冲突
- **验证**:从 W2/W3/W4 任一动作行 tap 后进入 Step 5 对应卡片;edge swipe back 与 card swipe 仍正常
- **为什么等**:V1 Step 7 行只读, 避免本 spec 扩大编辑状态与定位逻辑
- **创建于**:2026-05-09(spec 007)
- **⚠️ 坐标已过时(2026-07-03)**:本条 UI 坐标基于 spec 007 的 Step 5/7 界面;planning 界面已被 spec 038(planning-workspace)+ PR [#180](https://github.com/tianpingdeng112233-cell/meetpr/pull/180)(1:1 redesign)重构。触发时先对照 spec 038 + #180 现界面再定位改动点,勿照搬 007 的 Step 编号。

### F-022 — 候选:Step 7 per-cell W2-W4 单格手覆盖

- **触发条件**:教练 dogfood 中 ≥3 次明确需要"某一周某动作不按规则走, 手动改一次"
- **动作**:
  1. 引入 `ExerciseWeekOverride` 的 iOS draft 表达
  2. Step 7 支持对 W2-W4 单动作派生值手动覆盖
  3. 后续 publish spec 把 override 序列化进后端 payload
- **验证**:有 override 的格子优先显示手填值;无 override 的格子仍由 W1 + rules derive
- **为什么等**:V1 先保持 W2-W4 全 derive, 降低状态空间和发布 payload 复杂度
- **创建于**:2026-05-09(spec 007)
- **⚠️ 坐标已过时(2026-07-03)**:本条 UI 坐标基于 spec 007 的 Step 7 界面;planning 界面已被 spec 038(planning-workspace)+ PR [#180](https://github.com/tianpingdeng112233-cell/meetpr/pull/180)(1:1 redesign)重构。触发时先对照 spec 038 + #180 现界面再定位改动点,勿照搬 007 的 Step 编号。

### F-023 — 候选:Step 5 per-set 变化

- **触发条件**:教练 dogfood 中 ≥3 次要求同一动作内 warmup / top set / backoff / AMRAP 使用不同 reps 或 intensity
- **动作**:
  1. 将 Step 5 从 per-exercise 1 个 uniform `DraftSetSpec` 扩展为 per-set list
  2. UI 支持新增/删除 set row 与 set_type 选择
  3. DraftMapping 按 row 原样 expand 为 `PlanSet`
- **验证**:同一动作可保存不同 set type / reps / intensity;旧 uniform draft 可迁移为 N 个 working set
- **为什么等**:V1 只需要完整 W1 基线, uniform working sets 足够支撑 TestFlight happy path
- **创建于**:2026-05-09(spec 007)
- **⚠️ 坐标已过时(2026-07-03)**:本条 UI 坐标基于 spec 007 的 Step 5 界面;planning 界面已被 spec 038(planning-workspace)+ PR [#180](https://github.com/tianpingdeng112233-cell/meetpr/pull/180)(1:1 redesign)重构。触发时先对照 spec 038 + #180 现界面再定位改动点,勿照搬 007 的 Step 编号。

### F-024 — 候选:custom rule 复合多维度

- **触发条件**:教练 dogfood 中 ≥3 次需要同一 custom rule 同时改重量/RPE/组数/次数多个维度
- **动作**:
  1. 把 V1 `customDimension` 单选扩展为多维度 payload
  2. `customSequence` 改为按 week + dimension 的结构化矩阵
  3. WeekDerivation custom 分支支持多维度一次应用
- **验证**:一个 custom rule 可在同一周同时产生 e.g. +5kg 与 -1 rep;Codable round-trip 保持稳定
- **为什么等**:V1 custom = 1 维度 / 规则, 需要时可用多条规则表达复合效果
- **创建于**:2026-05-09(spec 007)

### F-029 — Coach 学员详情 V0.1.x polish backlog

- **触发条件**:spec 029 第一遍合并后,进入 V0.1.x polish / 性能 / 联调阶段,或教练端学员数 ≥ 5 后 roster/detail 明显变慢
- **动作**:
  1. 处理 StudentRoster / StudentDetail 的 N+1 fetch:增加批量 summary 或并发 fan-out + cache 策略,避免学员数上来后每行串行拉 plan/log/feedback
  2. 精炼"待关注"语义:排除热身/无效组,加"教练已看过该日 execution"或智能去重,再评估是否改文案为"待反馈"
  3. 补 review 剩余测试洞:空计划/空 feedback/error banner/retry/placeholder navigation 的 ViewModel 或 snapshot 覆盖
  4. 处理非 blocker nit:日期 formatter 缓存或 FormatStyle 化、细节文案/可访问性/列表空态 polish
- **验证**:≥5 学员 seed 下 roster 首屏无明显串行等待;待关注误报率在 dogfood 可接受;新增测试覆盖上述边界
- **为什么等**:PR #150 第一遍目标是打通教练端"看学员 + 写反馈"闭环;这些是 review 通过后的 polish/scale 工作,不阻塞 draft 第一遍合并
- **关联**:PR #150 review;spec 029
- **创建于**:2026-05-24(PR #150)

### F-027 — Stage 2 公测前收敛 RDS 白名单 + 关外网 + 开 SSL

> **补建于 2026-07-03**:[secrets-pointer.md §3](~/Brain/wiki/projects/MeetPR/secrets-pointer.md) 与 §4 backend 多处引用 "F-027" 作为上线前待办,但本条从未写入 FOLLOWUPS,属**悬空引用**。此次落地。

- **触发条件**:MeetPR 进入 Stage 2 公测前(内测 → 公测切换),或 RDS 开始承载非测试者的真实用户数据前(任一先到)
- **背景**:V0.1 内测期 RDS(`pgm-bp1h7t65b7if01rq`,单机版 2c2G)为开发便利,白名单 `0.0.0.0/0` + `172.16.0.0/12` 全开、外网地址开放(UK 本地开发用)、SSL 关。这三项在公测承载真实用户数据前是安全 blocker(per ADR-004 §6)。
- **动作**:
  1. **白名单收敛**:RDS 控制台 → 数据安全性 → 白名单,删 `0.0.0.0/0`,只留 VPC 网段 `172.16.0.0/12`(SAE 内网访问)+ 明确的运维出口 IP(如需)
  2. **关外网地址**:RDS 控制台 → 数据库连接 → 释放外网地址(`pgm-bp1h7t65b7if01rqxo...`);此后开发改走跳板 / VPN,不再直连
  3. **开 SSL**:RDS 控制台 → 数据安全性 → SSL → 开启;更新 backend `DATABASE_URL` 加 `?sslmode=require`(或等价),验证连接
  4. 更新 [secrets-pointer.md §3](~/Brain/wiki/projects/MeetPR/secrets-pointer.md) 三行状态(白名单 / 外网 / SSL)+ §4 backend「上线前待办(F-027)」勾除
- **验证**:白名单不含 `0.0.0.0/0`;外网地址已释放(公网 psql 直连超时);backend 用 `sslmode=require` 连通;secrets-pointer §3/§4 对应项已更新
- **为什么等**:内测期只有已知测试者 + 开发需要公网直连调试;过早收敛会阻塞 UK 本地开发。公测承载陌生用户数据才是真 gate。
- **不要做的事**:
  - ❌ 内测期就关外网(会阻塞 David 本地开发直连)
  - ❌ 只做白名单不开 SSL(明文传输仍是 blocker)
- **关联**:[secrets-pointer.md §3/§4](~/Brain/wiki/projects/MeetPR/secrets-pointer.md);ADR-004 §6 后端选型;[F-025 已完成](#f-025--v01-backend-启动前重新申请-rds-单机版--关闭于-2026-05-15)(RDS 重建时留下的收敛债)
- **创建于**:2026-07-03(补悬空引用)

### F-028 — build 号自动递增(agvtool / CI)

> **正式化于 2026-07-03**:此前散落在记忆与 ship 流程口头约定里(per [[meetpr_testflight_live]] "build号 per-branch 乱待 agvtool 根治"),从未落成 FOLLOWUPS 正式条目。此次立条。

- **触发条件**:下次备 ship 分支(archive + 传 ASC)时;或 build 号在多分支间再次出现冲突/倒退导致 ASC 上传被拒
- **背景**:当前 `CFBundleVersion`(build 号)手维护,per-branch 各自增,ship 分支之间容易乱(1.0(5) 线上、1.0(6) ship 分支待 archive)。ASC 要求同一 version 下 build 号单调递增,手维护迟早撞。
- **动作**:
  1. 评估 `agvtool next-version -all`(读 `CURRENT_PROJECT_VERSION`)在多 SPM module + app-target 结构下是否干净;或改用 CI 步骤按 `github.run_number` / ASC 最新 build +1 派生
  2. 选一种:**本地 agvtool 手动 bump**(ship 分支 archive 前跑)/ **CI 自动 bump**(archive workflow 里派生并回写);记进 CLAUDE.md §常用操作 或 ship SOP
  3. 若走 CI 自动:确保 build 号来源单一(ASC 查询或 run_number),避免再 per-branch 分叉
  4. 关掉「开着 Xcode 会回写 pbxproj build 号 churn」的噪声(per [[meetpr_ios_signing]]):bump 只在 ship 分支发生,日常分支不动
- **验证**:连续两次 ship 的 build 号严格递增且无需手数;ASC 上传不再因 build 号冲突/倒退被拒
- **为什么等**:内测期发版频次低,手 bump 尚可;真正痛点在 ship 分支多起来后。绑「下次备 ship 分支」触发,避免空转。
- **关联**:[[meetpr_testflight_live]];[[meetpr_ios_signing]](Xcode 回写 pbxproj);[[meetpr_ask_beta_inclusion]](备 ship 分支流程)
- **创建于**:2026-07-03(正式化口头约定)

---

## 已完成

_(执行完的触发条目移到这里,保留作历史。格式:日期 + 原触发条件 + 执行结果链接)_

### F-026 — Apple Developer membership 开通(V0 ship 前置)— **关闭于 2026-06-24**

- **原触发条件**:距 V0 hard deadline ≤ 7 天(2026-06-13)或 User 主动 ship intent
- **执行结果**:Apple Developer personal membership 已开通并投入使用;MeetPR 已上 TestFlight 内测(App id **6783772277**),首个 TestFlight build 上传**不晚于 2026-06-24**——membership、Bundle ID `com.meetpr.app`、App Store Connect App record 均已就位(否则 build 无法上传)。签名 team = **28JW4SA779**(tianpingdeng@126.com;旧 team `XV97B4R4RZ` 作废,per [[meetpr_ios_signing]])。
- **满足说明**:LAUNCH-CHECKLIST.md Stage A 环境前置全部实质满足(账号 active / Bundle ID register / App record 创建);TestFlight 已在分发内测包。
- **关联**:[LAUNCH-CHECKLIST.md](./LAUNCH-CHECKLIST.md) Stage A(已被 banner 标注为「现实取代」);[[meetpr_testflight_live]];[[meetpr_ios_signing]]
- **关闭决定**:Claude 2026-07-03 回填(实际完成不晚于 2026-06-24 首个 TestFlight build)

### F-025 — V0.1+ backend 启动前重新申请 RDS 单机版 — **关闭于 2026-05-15**

- **原触发条件**:V0.1+ 阶段任一 spec 需要 backend 真持久化(学员端 / 真注册 / 教练 publish / 视频上传 任一)
- **执行结果**:2026-05-15 重建单机版 RDS 实例 `pgm-bp1h7t65b7if01rq`(`meetpr-rds-v01-staging`),运行中;backend staging 已接入。详见 [secrets-pointer.md §3](~/Brain/wiki/projects/MeetPR/secrets-pointer.md)。
- **⚠️ 与原 F-025 文本的刻意偏差**(实建 ≠ 原条目规划,已确认为有意为之):
  | 项 | F-025 原文规划 | 2026-05-15 实建 |
  |---|---|---|
  | 引擎 | PostgreSQL **17** | PostgreSQL **18.0** |
  | 规格 | `pg.n2.2c.2m`(2c**4G**)| `pg.n1e.2c.1m`(2c**2G**;V0.2+ 公测前升 4G)|
  | 计费 | 包**年**包月 1 年 + **开**自动续费 | 包**月** 1 个月 ¥86 + **未开**自动续费(2 周稳定后切包年)|
  | 存储 | 50GB ESSD PL1 | 50GB 高性能云盘(V0.2+ 切 ESSD PL1)|
- **遗留债**:白名单 `0.0.0.0/0` + 外网开放 + SSL 关,均为开发便利,公测前需收敛 → 已立 [F-027](#f-027--stage-2-公测前收敛-rds-白名单--关外网--开-ssl)。
- **关联**:[secrets-pointer.md §3](~/Brain/wiki/projects/MeetPR/secrets-pointer.md);ADR-004 后端选型;[[meetpr_aliyun_arrears]] 网络拓扑
- **关闭决定**:Claude 2026-07-03 回填(实例 2026-05-15 建成运行至今)

### F-015 — 首个 coach planning spec 必须按 v4.4 设计写 — **关闭于 2026-07-03**

- **原触发条件**:写第一个 coach planning UI 相关 spec(涉及"教练排计划 / 4 周 / 周卡片 / cycle 历史 / Excel 预览")
- **执行结果**:specs **005 / 006 / 007** 已按 v4.4 设计实装并合并(周卡片横滑 `TabView(.page)`,非 4 周宏观视图);三者均已 ship 进 TestFlight。防误引用目的达成——V0 coach planning 未出现 v4.3 4 周扫视态 / v4.2 Excel grid / 波形图 / 变式矩阵 / 密度条。
- **满足说明**:触发条件在 spec 005 起草时即命中并正确执行;宏观分析能力按计划全部 defer 至网页端(PD-007)。
- **关联**:`~/Brain/wiki/projects/MeetPR/coach-planning.md` §7b/7c/7d v4.4;CLAUDE.md "Recent design changes (2026-04-28)";specs 005/006/007
- **关闭决定**:Claude 2026-07-03(v4.4 已被三个 coach planning spec 消费,防误引用使命完成)

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
