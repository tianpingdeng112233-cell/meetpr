# 学员端设计系统正典(2026-07-28 起生效)

⚖️ David 2026-07-28 拍板:**学员端黑金 v3 交付收尾;此后所有新设计一律按本设计系统来**。
新页面、新组件、新弹层、外部设计稿——先对照本文,不一致的以本文为准,或先经 David 拍板改本文。

## 1. 事实源顺序

1. `docs/design/handoff-v3/MeetPR 学员端.dc.html`(主样机,可交互)
2. `docs/design/handoff-v3/empty-states/*.html`(空状态规范,暗/浅双份)
3. `docs/design/handoff-v3/motion/01–05.html`(可运行动效参考)
4. 以上未覆盖的界面 → 本文 §2 的体系规则(⚖️ David:「样机没涉及的按现有体系改」)

**样机是暗色优先的**:凡样机写死的深色字面量,浅色一律换动态 token(见 §2.6)。这是本波
最高频的返工来源(goldText 对比度、回顾页 hero、RPE 刻度三次)。

## 2. 体系规则

### 2.1 颜色角色
- 选中态:`gold500` 文字/描边 + `goldRGB.opacity(0.12~0.14)` 底 + `goldRGB.opacity(0.3~0.5)` 描边
- **文字用金 → 一律 `goldText`(动态)**;`gold500` 只留给描边、图标、slider/progress tint
- 未选:`surfaceCard`/`surfaceElevated` 底 + `borderDefault` 描边 + `textMuted` 文字
- 危险语义(删除/失败)才用 `danger`;危险**文字**用 `dangerMuted`
- 页面底 `bgBase`、卡片 `surfaceCard`、内嵌 `bgInset`
- `LegacyColors.*` = v2 冻结区,**新代码禁止引用**(教练端/auth 未迁移面专用)

### 2.2 字体
- 标题/大数字:`.MeetPR.display`(Archivo)
- 正文:`.MeetPR.body`
- **一切数字、代号、日期:IBM Plex Mono**(`.MeetPR.mono`)
- 禁半像素字号;圆角只用 4/10/12/16/20/999

### 2.3 主要控件
- 主 CTA:`ctaBackground`/`ctaText` 胶囊(参照 `GoldCTA`/`SetEntryCompleteButton`)
- 触控目标 ≥44pt(图标按钮要显式 `frame` + `contentShape`)
- 列表长于一屏用 `LazyVStack`/`List`,不用 `VStack` 全量创建

### 2.4 动效
- 参数只能来自 `motion/01–05.html`,注释标出处行号
- 每条新动效必须有 reduced-motion 直达终态分支,且延迟任务在离场/取消时清理
- 入场态也要闩:Reduce Motion 在**首次出现时**就开启的场景不得留中间态

### 2.5 空状态
- 回答三件事:为什么空 · 什么时候有 · 现在能做什么;**禁止「暂无数据」类文案**
- 骨架不变,只换槽位;数字/教练名全部真算,不写死
- 移植参考图表**不得缩比例**(压高度会丢坐标轴/网格/标签)

### 2.6 双主题
- 学员端默认**浅色**(`MeetPRAppearance.defaultPreference`),用户可在 我的 → 外观 改
- 教练端与登录流恒暗(`MeetPRApp.preferredAppColorScheme` 按角色分域)
- 任何新颜色都要问一句"浅色下对比度够吗";正文对比度 ≥4.5:1

### 2.7 文案与本地化
- 用户可见文案进 `Localizable.xcstrings` + `StudentStrings` 门面
- **symbol key**(`student.x.y`),动态部分用 `String(localized:)` 原生插值
- 禁 `String(format:)` 等 C 风格格式化

### 2.8 日期口径(踩过三次的坑)
- 选中日/「今天」= 设备日历(`PlanCalendarDayIdentity.deviceDay`)
- 计划日匹配/格式化 = UTC 分量
- 顺延 mutation = UTC 锚(spec 054);跨时区判定一律走 `PlanCalendarDayIdentity`,不得
  把 UTC anchor 丢进设备日历 `startOfDay`

## 3. 交付纪律

- 每张卡:实装 → review-loop 收敛 `VERDICT: CLEAN` → 模拟器双主题目检 → 原子 commit
- 回执落 `docs/design/handoff-v3/*-RECEIPT.md`,互审 transcript 落
  `~/Brain/wiki/projects/MeetPR/reviews/`
- 视觉决策必须能追到出处行号;**注释声称「样机如此」但样机查无此值 = BLOCKER**

## 4. 本波遗留(记录在案,非缺陷)

| 事项 | 去向 |
|---|---|
| 结算 streak 胶囊接线 | 待 backend spec 028 / PR #106 |
| 顺延 `target_date` 接线(拆沪 00–08 隐藏窗) | 待 backend PR #107 部署 |
| 顶栏「填写今日状态」爱心去留 | 待 David(样机盲区件,现保留) |
| 「组间休息」与「外观」行序 | 待 David |
| 教练端黑金迁移 + `LegacyColors` 删除 | 后续 wave |
