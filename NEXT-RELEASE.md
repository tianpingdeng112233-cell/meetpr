# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (16)
- 基底:`beta/1.0-15`(= TestFlight 在测的 1.0(15),2026-07-29 上传)之后的 release/1.0 直推累积
- build 号:16(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-16`

## 本版将包含(落线后追加到这里)

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

## 🎯 已排上但未开工

- **登录页重做**(David 2026-07-29 提):登录页是 v3 唯一没覆盖的界面(#279 收据明写「教练端与登录流保持恒暗、全程零 diff」),现仍是 v2 旧 token——`brandRed`×2 / `fgPrimary` / `fgSecondary` / `fgTertiary` / `surface2` / `border` / `bg`,一个 v3 token 都没有,在新学员端旁边割裂。
  ⚠️ **两个待拍板**:①登录页**角色无关**(还不知道是教练还是学员),而 v3 正典只覆盖学员端且默认浅色、教练端恒暗——跟哪套?②v3 设计包里**没有登录页参照物**,是照 `DESIGN-SYSTEM-CANON.md` 推导还是另出稿?
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
