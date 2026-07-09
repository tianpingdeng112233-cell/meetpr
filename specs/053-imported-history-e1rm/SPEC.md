# SPEC 053 — 导入历史进 e1RM 基线(imported-history → e1RM)

- **状态**: InReview
- **来源**: David 2026-07-09 两拍板,产品锚 `~/Brain/wiki/projects/MeetPR/domain/e1rm-headline-and-anomaly-guard.md` §④⑤:「④导入的完成记录计入 running best / PR 基线,导入成绩超自填 1RM 时问询一次;⑤完成率统计排除 imported」。
- **现状诊断**(2026-07-09 三路侦察 + review-loop 核):plan-web 导入过去日期计划时已问「是否推定完成」,确认后 backend `POST /plans/:id/imported-history` 为过去组合成 `set_logs` 行(`completed:true, assumed:true`,migration 0023,`logged_at` 回填计划日);学员真实录入永远强制 `assumed:false`,且**允许对同一条 assumed 行原地覆盖**(同 set log 身份)。backend 分支的 `sets-fetch.ts` 已在响应中返回 `assumed`(缺省 false)。**但 iOS 的 e1RM 点只在 app 内录组瞬间由 `E1RMRecorder` 生成**(TodayWorkout / SoloSession 两 VM 调用),assumed 日志从不经过这条路——导入历史对曲线、头条、PR 基线全部不可见。后果:老手新用户头几周在 app 里举早已举过的重量会连环触发假 PR;spec 050 §5 冷启动 `B == nil` 不设防的洞也没人填。
- **依赖**: `feat/050-anomaly-guard`(confidence 分级门)先合;本 spec 的 `origin` 轴与 confidence 轴**正交**(已核:该分支 `maxBefore`/best/current 只按 `confidence == .normal` 过滤,imported 点必须以 `.normal` 计入基线,故不能复用 `.low` 当来源标记)。本 spec 需要 repository 具备**按点改写 confidence / upsert** 的能力(现状 `recordPoint` 只 append),归本 spec 交付。

## 1. assumed 透传(backend → iOS)

- 确认既有 wire contract:`GET /students/:id/sets` 响应含 `assumed`(backend 已实现,本 spec 不动服务端);iOS 侧补契约回归测试。
- `StudentSetLog` 增 `assumed: Bool`,DTO 解码缺省 `false`。

## 2. 回填管线(assumed 日志 → e1RM 点)

- 新增 `ImportedHistoryBackfill`(StudentKit service):学员 root 启动后、**每次**进入成长页、下拉刷新时均触发——§3 的 upsert 幂等使重跑安全且零新增,不设"session 只跑一次"闸(否则 app 已启动后教练才导入的批要等重启才可见)。
- 拉取窗口 = `[today − backfillWindowDays, today]`,常量 `backfillWindowDays = 120`(plan-web 导入上限 12 周 = 84 天 + 余量);按既有 sets API 的日期范围参数分片拉取。
- 入选:`assumed == true && completed && !failed` 的日志过**同一套** `E1RMEligibility`(RPE nil 放行走 Epley、rep>10 拒、硬拉只信 r≤5);`exerciseID == nil` 的日志跳过。
- 生成点带 `origin: .imported`(`E1RMHistoryPoint` 增 `E1RMPointOrigin`,`.logged`/`.imported`,旧数据解码缺省 `.logged`);**点的日期取 `loggedAt`**(backend 已回填为计划日),严禁取回填执行时刻。
- 回填是批处理:**不触发** `PRBreakthroughEvent`、不发庆祝 banner、不打任何打卡/训练类埋点事件。

## 3. 幂等与覆盖语义(upsert by setLogID)

- repository 以 `(studentID, setLogID)` 为身份 **upsert**(接口从纯 append 扩展):同批重放 / 重进成长页 / 重启 → 零新增。
- 学员真实补录覆盖同一条 assumed 日志(同 `setLogID`,`assumed` 翻 `false`)→ 该点**替换**为 `origin: .logged` + 新数值,confidence 按 050 门重算;不得出现同 `setLogID` 双点,也不得保留旧 imported 数值。

## 4. 基线语义(拍板④的核心)

- imported 且 `confidence == .normal` 的点**计入** `maxBefore` / running best / 滚动窗口;imported 点**自身永不作为 PR 事件主体**(只当基线,不当成就)。
- PR 判定粒度**维持既有 per-exerciseId**:imported 计划与后续录组绑同一 catalog exerciseId 时阻断假 PR(plan-web 导入经 catalog 绑定,常态成立);跨变式(如 high-bar ↛ competition squat)不互为基线——这是 050 既有语义,非本 spec 回归,family 级基线不做(见非目标)。

## 5. 超自填 1RM 问询(拍板④的对冲)

- `L` 读取源 = `OnboardingRepository` → `OnboardingProfile.squat1RMKg / bench1RMKg / deadlift1RMKg`(optional;nil = 缺失,不问询直接纳入)。粒度 = 三大项动作族(`L` 只有三项;动作→族沿用 `mainLiftFamily` 既有映射,无族归属的动作不问询)。
- **问询/降级的作用域 = 该族 e1RM > `L` 的 imported 点**(既有 + 本批 + 未来批);≤ `L` 的 imported 点可信,始终 `.normal` 不受问询影响。
- 流程:回填批落库时,某族存在 e1RM > `L` 的 imported 点且无覆盖该 max 的已答记录 → 这些超 `L` 点先以 `confidence: .low` 入库(隔离态:不进 best/current/PR,弱化散点可见),并弹**一次性**问询:「导入的历史记录里有 {w}kg×{r}(约 e1RM {e}kg),超过你填写的 1RM {L}kg——当时确实完成了吗?」[确实]/[没有]。
  - [确实] → **回答时在库的**该族超 `L` imported `.low` 点批量升格 `.normal`(用 §依赖 的改写能力);
  - [没有] → **回答时在库的**该族超 `L` imported 点永久 `.low`,不因后续任何回答追溯升格(与 050 §5 同哲学:decision 只作用于它审视过的点);
  - 未回答期间维持 `.low`(基线语义 = 未确认不计入)。
- 答案持久化为记录 `(studentID, family, decision, reviewedMaxE1RM)`(本地 store,键含 studentID 防跨账号污染)。**新批**超 `L` 点的处置:新批 max ≤ `reviewedMaxE1RM` → 直接沿用最近 decision([确实] 入 `.normal` / [没有] 入 `.low`),不重问;新批 max > `reviewedMaxE1RM` → 对**新批**超 `L` 点重新问询(新回答只作用于新批,不改写旧批点)。
- 修改自填 1RM 不追溯已答;`L` 被清空(nil)后:既有 decision 与既有点状态不变,新批因 `L` 缺失不再触发问询、直接 `.normal`(nil = 用户主动放弃这道参照,可接受)。
- 问询对象是学员(教练导入时不问——真相只有学员知道)。

## 6. 聚合与渲染(origin/confidence 全程保真)

- `E1RMSeries` 输出**保留 origin 与 confidence**:smoothed 主线样本保留**自身唯一 `sampleID`**(时间轴身份,连续多日同一赢家也不重复),另携带赢家溯源三字段 `winnerPointID / winnerOrigin / winnerConfidence`(窗口内 max 赢家点,不是当前日期输入点——窗口内 `.imported` 165 压过当日 `.logged` 160 时,样本标 imported);点选主线样本的详情展示**赢家点**的原始组信息(训练日期/重量/次数),时间轴位置仍为样本日期。`rawEligible` 散点含 `.low`。禁止聚合层重建点时把 origin 抹回缺省。
- `E1RMChart` 分两层输入:主线 = smoothed(仅 `.normal`),线段样式按样本 origin(imported 段虚线/次级色);散点 = rawEligible 按 origin/confidence 分样式(`.low` 更弱);图例一行「浅色 = 导入的历史计划」。
- **「历史最佳」回退(050 §2 的 age-aware 增强,归本 spec 交付)**:滚动窗口相对**当前日期**判空(刚导入、app 内无近期记录的典型态)→ 显示全期 `.normal` best + 标签「历史最佳」。消费面 = Dashboard 头条(`DashboardE1RMTrendViewModel`)与训练历史/成长页**既有** trend 展示;成长页不新增 headline,其交付 = 图表默认时间范围自动扩到含最早点(不得默认隐藏 imported 段)。

## 7. 统计排除(拍板⑤)

- 过滤在**消费/reducer 层**,逐个落:`CompletionHistory`、`ProgressMetrics`、`StudentFormatting.completedCount`、成长页 session 计数、solo 本月次数计数——一律排除 `assumed == true`;**禁止在 fetch 层全局过滤**(回填依赖 fetch 拿到 assumed)。注:solo 月分组**列表条目**属归档展示、仍显示 assumed 日(见下条),排除的只是它旁边的次数统计。
- 历史列表/训练详情**仍显示** assumed 记录(归档语义,导入的历史本来就该能翻);只有统计口径排除。
- CoachKit 教练侧 reducer(roster/detail/triage)本 spec 不改,follow-up 教练 wave。

## 非目标

- 不改 plan-web 导入流程与 backend(`imported-history` 端点、`sets-fetch` 序列化均已就位)。
- 不对 imported 批做 050 §5 式逐点分级门追溯(导入批的异常保护 = §5 问询,粒度是动作族)。
- 不新增 `plans.source` 枚举值(imported 判别锚 = `set_logs.assumed`,计划树不动)。
- 不做 family 级 PR 基线(跨变式互为基线是另一个产品决策,未拍板)。
- 教练端 StudentGrowth 视图不改(与 050 同批 follow-up)。

## 测试

- DTO/codec:`assumed` 缺省解码 `false`;`E1RMHistoryPoint` 旧 JSON 无 origin → `.logged`,新值 round-trip 保真。
- 回填:assumed 合格组生成 `.imported` 点且日期 = `loggedAt`;不合格组(RPE<7 / rep>10 / 硬拉 r6)与 `exerciseID == nil` 不生成;重复回填零新增;全程无 `PRBreakthroughEvent`。
- 覆盖:同 `setLogID` 由 assumed 翻真实录组 → 点替换为 `.logged` + 新数值,无双点。
- 基线:imported best 165(同 exerciseId)时录 160 → 不判 PR;录 172(+4.2%)→ 判。
- 问询:族内超 `L` 点入库即 `.low` + 弹一次(≤`L` 点同批保持 `.normal`);[确实] → 在库超 `L` 点升格 `.normal` 且 best/current 立即含;[没有]/未答 → 维持 `.low`;`L` nil → 直接 `.normal` 不弹;同批重放与新批 max ≤ `reviewedMaxE1RM` 的沿用 decision 不重问;新批 max > `reviewedMaxE1RM` → 重问且新回答不改写旧批点([没有] 旧批 + [确实] 新批 → 旧批仍 `.low`、新批 `.normal`);[没有] 后清空 `L` → 既有点不变,再新批直接 `.normal`。
- 聚合/渲染:`E1RMSeries` 投影后 origin 保真;混合窗口(imported 165 + logged 160)的主线样本取赢家溯源且 `sampleID` 逐日唯一(连续同赢家不重复 ID);点选样本详情 = 赢家点原始组;`.low` 点出现在 rawEligible 且不入 best/current;窗口(相对今日)空 → 回退全期 best + 「历史最佳」标签。
- 触发:app 保持前台期间教练侧新导入 → 学员下次进成长页(不重启)即回填可见。
- 统计:同一数据集加入 assumed 日志后,五处统计消费者输出不变;历史列表可见条目数增加。

## 验收

1. 导入 12 周过去计划并推定完成后:学员成长页出现弱化历史段(默认范围可见),头条显示「历史最佳」且数值含 imported 点。
2. 老手新用户 app 内首周举历史举过的重量(同动作)→ 零假 PR 庆祝;超 imported best+3% → 正常庆祝。
3. imported 成绩超自填 1RM → 一次性问询;[没有] 后头条/best 不含该族**超 `L` 的** imported 点(≤`L` 的照常计入),散点仍可见;[确实] 后立即计入。
4. 学员对着导入计划的某组真实补录 → 该点 origin 变 `.logged`、数值取实测、总点数不变;confidence 按 050 门重算——重算 `.normal` 则入主线,重算 `.low` 则为实测来源的弱化散点(不绕过 050)。
5. 完成率/打卡类统计在导入前后不变;历史列表能翻到导入记录。
6. 反复进出成长页/重启 app,点数不膨胀、问询不重复。
