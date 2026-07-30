# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (16)
- 基底:`beta/1.0-15`(= TestFlight 在测的 1.0(15),2026-07-29 上传)之后的 release/1.0 直推累积
- build 号:16(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-16`

## 本版将包含(落线后追加到这里)

- **教练端 iOS 全量 v3 浅色迁移**(PR [#298](https://github.com/tianpingdeng112233-cell/meetpr/pull/298)
  合集,merge `9e86b3b`,P1):教练端此前**一个 v3 token 都没有**——`MeetPRApp` 把它钉在 `.dark`,
  黑金波 PR #279 的收据明写教练端全程零 diff。本波按 David 2026-07-30 交付的《MeetPR 教练端》样机,
  把四个 tab 全部做成 v3 浅色,四张卡收拢为单次合并(叠层 PR 逐个合会合进各自的 base):
  - **卡1**(#295)外壳 + 今日 + 学员:5 tab → **4 tab**(今日/消息/学员/我的),「编排」**只摘 tab 入口、
    `Planning/` 代码原样休眠**;原生 `TabView` → ZStack 分页 + 自绘 tab bar;今日页待办队列 + 本周概况热力卡。
  - **卡2**(#296)消息合流 + 学员详情五子 tab:三段式分段控件 → 单一会话列表(一个学员一行,
    姓名进聊天、深色胶囊进待反馈视频,两条路分开);详情用「资料」换掉「执行」;聊天/申请资料/视频列表
    改为**全屏、不显示 tab bar**;教练侧 Demo 聊天种子对齐花名册 UUID。
  - **卡3**(#297)我的 + 收尾:邀请码 / 帮助与反馈 / 隐私与条款 / 退出登录(**补了二次确认**);
    邀请码屏换皮保留全部能力;**教练侧评估期封存**(2026-07-13 那次只关了学员一半,教练仍能打开
    被封存的评估摘要编辑器)。
  - **卡4**(#298)视频反馈工作台:v2 纯文本框表单 → 深色播放器 + 进度条 + **0.5×–2× 倍速** +
    组信息四宫格(本组重量/次数/RPE/组序)+ 「跳过 · 看下一段」**全局队列并在末尾回卷**。零后端
    (`StudentVideo.setLogID` 本就链到 set log,队列只是没透传)。
  ⚖️ **四条产品拍板**(2026-07-30,勿翻案):4 tab / 教练端恒亮 / 「＋打点」仍 deferred / 1RM 教练可改
  学员只读(跨端卡,不在本波)。
  ⛔ **样机画了但故意不做的**(后端不存在,画了就是死链或编数):教练资料编辑、三宫格统计、动作库、
  提醒规则、导出执教数据、注销账号;用户服务协议无 URL 故为禁用态。
  证据:CoachKit 423 / DesignSystem 70 / ChatUI 67 / AppShell 66 / StudentKit 620 / RepositoryContracts 5
  全绿(合并后复跑)、`xcodebuild -configuration Demo` 0 warning、`swiftlint --strict` +
  `swift-format --strict` 干净;模拟器逐屏实点(四 tab 切换、消息两条路径、五子 tab、视频队列 1/6 与倍速改速率、
  退出确认、评估卡消失)。互审 10 轮 + 定向返修 7 轮,19 条 BLOCKER 全部处置,transcript 四份在
  `~/Brain/wiki/projects/MeetPR/reviews/2026-07-30-coach-v3-*.md`。
  ⚠️ **教练 Demo 种子没有在跑计划**,所以今日页「本周概况」在模拟器上恒空态、学员页全员「无计划 0/0」——
  这是种子缺口不是 bug,但也意味着**那一屏始终没能与样机同屏对照**,切包前建议 David 用真实教练账号走一遍。

- **App 图标换成定稿「片里的折线」**(P1):David 2026-07-30 定稿的杠铃片 + 折线标记落地——
  纸底 `#F5F6F8` + 金盘 `#D97706` + 走平后拐头冲上去的折线 + 42% 淡段 + 上弧 + 下沿
  PERSONAL RECORD,两色无渐变。light / dark 共用同一张 1024(无 alpha、3 通道),tinted 另出
  灰度挖空版(圆盘实心、盘内形状挖成透明,系统自己上用户色)。矢量真源 + SPEC + 重出 PNG 的命令
  在 `docs/brand/`,以后改图标从那儿改。
  证据:asset catalog 编译 0 警告、iPhone 17 模拟器主屏 Default / Dark / Tinted 三态亲验。
  这是内测用户**看得见的品牌变更**(旧图标是黑底 MEET PR 字标)——**David 2026-07-30 看过定稿对照与
  三处上屏截图后拍板「没问题,进下班车」,prep-beta 时不必再问一遍**。同时确认的还有两处定稿没写口径、
  由实装侧定的:dark slot 与 light 共用同一张;tinted 走灰度挖空版。
  ⚠️ 定稿里还有两项本包没做:**启动页/破 PR 的图标动效**(圆盘淡入 → 折线画出 → 圆点弹入 →
  上弧扫出,与学员端「新纪录」徽标同一动作)只写在 SPEC 里,未实装;**Watch 圆形遮罩变体**
  本仓无 watch target,不适用。

- **学员端首屏与切 tab 提速**(PR #289,`aa54155`,P1):David 在 1.0(15) 实机反馈「加载特别慢,
  骨架屏要看很久,开始训练跳转不丝滑」。三层根因逐条修:①9 个 ViewModel 改保鲜刷新——原先 `load()`
  首行无条件 `state = .loading`,手里有数据也先扔掉退回骨架;②串行瀑布压平——今日页 5 段串行 → 4 路
  并发 + 1 段真依赖,训练页 6 段 → 3 跳,周概览去掉重复投影;③切回今日 25 秒节流窗(窗口内只刷日志/
  反馈/聊天/PR 数,**下拉刷新永远强制全量**);④动作库落版本化磁盘缓存 + `If-None-Match`/304
  (此前只有随进程消亡的内存缓存,每次冷启动都在首屏关键路径上全量重下 518KB);⑤「开始训练」把已加载
  的 plan 交棒给训练页,首帧立即出内容。
  证据:StudentKit 615 + Networking 99 测试绿、`xcodebuild -configuration Demo` 0 warning、
  **2026-07-30 David 真机(iPhone 12,Release 配置连真实后端)验收通过**——「不再重新加载了」。
  配套后端 gzip 已于同日部署 staging(backend #141,`sha-6c65173`,JS bundle 实测省 69%),
  **本包发出后学员端冷启动还会再快一截**(动作库 518KB → 约 30KB)。
  ⚠️ 收货期两轮定向返修拦下的坑,改这块前必读:交棒路径最初写成 `if let preloadedPlan { return ... }`,
  直接跳过 `fetchCurrentPlan`——而那个方法的 cache-first 分支**顺带启动仓储后台刷新**,于是教练改的
  计划不会出现;修完又发现计划没变时会白白重取一轮当日快照,再加等值比较挡掉。
  ⚠️ 另一条别重走的弯路:我曾判定 `MeetPRRiseInModifier` 的 `guard !Task.isCancelled` 会让卡片
  **永久透明**并开了 fix 分支——**前提错误,已撤回**。`.task(id:)` 每次 view appear 都会执行,
  id 只是「值变化时额外重建」的附加触发;实测(delay 放大到 2s)切 tab 回来内容立即完整、零重播。
  详见 `~/Brain/wiki/projects/MeetPR/reviews/2026-07-29-rise-in-cancellation.md`。

- **登录页 v3 浅色重做**(PR #291,`dfc24a8` 前一个 merge,P1):兑现 David 2026-07-29 提的「登录页重做」,
  两个待拍板都由 David 2026-07-30 提供的《MeetPR 登录 + 绑定教练(浅色)》设计稿一并解掉——**登录页跟浅色**,
  参照物就是稿子的 4a 屏(已抽成 `docs/design/login-v3/4a-login-light.html` 入仓,原始导出是 7MB 的
  design-canvas HTML,内联了 gzip 运行时,不适合入仓)。
  版式对调成 hero 在上 / 表单在下,字段改卡片式(`AuthPhoneField` 新增,带纯展示的 `+86` 前缀),
  密码加明文开关,CTA 换扁平金色矩形。`preferredAppColorScheme` 未登录态 `.dark` → `.light`(**只此一行**),
  coach 恒暗与 student 读 `@AppStorage` 两条分支零改动。
  ⚠️ **已知连带**:教练登录会「浅→暗」闪一下(David 已接受,没为它加逻辑);学员那边原有的「暗→浅」闪反而被修掉。
  ⚖️ **David 拍板 A**:忘记密码整行删掉(全仓零实现,不做死链)、条款行只写「隐私政策」(服务条款零 URL)。
  ⚠️ **条款行的隐私政策当前打不开**:`https://meetpr.app/privacy` 实测 DNS 解析到 `192.64.119.206`
  (Namecheap 停放段)但 HTTPS 超时,同机 `apple.com` 200。死链在 production 本已存在(原先藏在
  「使用数据说明」sheet 里),本包把它提到了**人人必经的首屏**。⚖️ David 拍板 D:先留着不阻塞发版,
  域名上线单独跟进。**切包前值得再 curl 一次**。
  证据:AppShell 65/65、`swiftlint --strict` 0 违规、iPhone 17 模拟器四态亲验(浅色初始 / 手机号聚焦 /
  密码明文 / 格式错误)。
  ⚠️ 改这块前必读的两条:①自绘按钮只加 `.disabled()` **不会**改自绘背景,空表单下按钮会满亮可点
  (真回归,截图证实,已修成 `surfaceRaised` + `textDisabled`);②`MeetPRRadius.point14` 实际是 **16**、
  `point9` 是 **10** —— `Radius.swift` 声明了 `§2 radius canon: 4/10/12/16/20/999` 并把所有 `pointNN`
  别名 snap 到这六档,**这是文档化的既定量化不是 bug**(review-loop 就此对质,Codex `CONCEDE`)。
  名字骗人这件事已另开仓级重命名卡。
  详见 `~/Brain/wiki/projects/MeetPR/reviews/2026-07-30-login-page-v3-light.md`。

- **绑定教练流 v3 浅色换皮**(PR #292,`dfc24a8`,P1):同一份设计稿的 4b/4d 屏。
  ⚖️ **David 拍板 A = 换皮**:10 位邀请码、`displayName` 必填、「提交 = 发申请等教练同意」机制一律不动。
  邀请码改分格输入(**2×5**,稿子画的是 6 格单行但 10 格挤在 342pt 里每格只剩约 27pt、装不下 mono 26pt),
  加「从剪贴板粘贴」按钮(教练多半微信发码),错误态染红且**不清空已输入**且提交按钮仍可用(能直接重试)。
  顺手修掉两个输入缺陷:字母表外字符(`O`/`0`/`I`/`1`)能打进格子但永不可能通过校验、按钮永久禁用且零解释;
  格下提示丢了 `I/O/0/1` 排除规则(唯一携带该信息的 `codeFormatHint` 已成死代码)。
  ⛔ **九条有意偏离设计稿**(跳过出口 / 4c 教练确认屏 / 教练卡六个字段 / 隐私承诺文案 / 今日页常驻卡 /
  步骤条等)全部写进了 PR 描述与 `docs/design/login-v3/CARD-bind.md`,**别当成漏做**;其中「门口死路」
  已开成独立 T3 卡(要角色变更能力 + 自练形态先解禁)。
  证据:StudentKit 620/620、`xcodebuild -configuration Demo` 0 warning、lint 全干净。
  ⚠️ **验证缺口**:这一屏**没人在模拟器里亲眼看过**——Demo 模式按设计穿过绑定门直落 5 tab
  (`RootViewDemoDefaults.swift:7`,spec 031 D10),要看得在 staging 造未绑定的 coachedStudent 真账号
  (走 `/testacct`)。**prep-beta 走查时优先补这一屏。**
  ⚠️ 改分格框前必读:透明 `TextField` 盖在自绘视觉上时,**平台控件保留自己约 16pt 的 intrinsic height,
  hit-test 走它的真实 frame**——`ZStack` sibling 加 `maxHeight:.infinity` 和改 `.overlay` 都无效
  (三次实测恒为 `342×16 @ y=69`,而网格 154pt)。必须走显式 `tap → isFocused = true`。
  详见 `~/Brain/wiki/projects/MeetPR/reviews/2026-07-30-bind-flow-v3-light.md`。


## 不进 1.0(16) —— 留下一班车

⚖️ 2026-07-31 切包时核实后移出「本版将包含」。**登记在此不等于已排期**,下次切包前重新核。

- **spec 062 学员端统一收件口**:SPEC.md 已写好(19KB,Draft/T3,David 07-25 三拍)但**从未提交**,只存在于 `~/Projects/apps/MeetPR-release` 工作区,未跟踪。开工前先把它落进仓里。

## 🕐 已完工、等前置解锁(还没落线,落线后挪到上面)

- **学员端 wellness 五档量表 + energy 档**(PR #273,base 已是 `release/1.0`,CI 绿):睡眠/精力/压力/情绪
  四档逐档文案上屏,肌群酸痛扩到四档。**硬前置:backend PR #95(迁移 0047)必须先合并并部署 staging**
  ——后端 `ReadinessBodySchema` 用 `.strict()`,旧后端会把新增的 `energy` 字段当未知字段 400 掉,
  导致学员 readiness 提交全数失败。顺序:#95 合并 → 部署 staging → #273 合并 → 自动进本包。
  另有一处观感待 David 看截图定:第二步未选中的 chip 显示「完全无酸痛」偏吵,可改留白。

## 📋 进度:离 archive 还差几步
- [ ] 捞回队列余项逐个落线:per-set 逐组目标 / rename-student / #215'/#217' 裁剪卡(等 Claude)/
      #234a 非 UI 拆包(等 Claude),状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表
- [ ] 注册页「学员 · 自己练」空壳待拍板:发版线上是否先藏起这一档(solo 波冻结在 main,
      发版线上该角色进去是没有计划来源的学员壳子)。详见 RELEASES.md 1.0(14) §已知问题
- [ ] gym-day 残留对齐:今日 tab 头条/周历高亮仍午夜翻篇(纯视觉),待全量对齐 spec
- [ ] build 号 bump 15(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-15`
- [ ] David:Archive → Upload → 分配 Neice(+外测 Ceshi 视审核情况)

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(N) 一节,清空本文件、目标号 +1。

**移出理由**:
- **wellness**:硬前置 backend PR #95(迁移 0047)**仍是 OPEN、未部署 staging**。旧后端
  `ReadinessBodySchema` 走 `.strict()`,会把新增的 `energy` 字段当未知字段 **400 掉**,
  学员 readiness 提交将全数失败。顺序不变:#95 合并 → 部署 staging → #273 合并 → 进下一包。
- **spec 062**:SPEC 至今**未提交**,只存在于 `~/Projects/apps/MeetPR-release` 工作区(未跟踪),
  且是文档不影响包体。落进仓里之后再谈排期。

## 🎯 已排上但未开工
