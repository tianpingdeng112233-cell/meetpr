# 任务卡 · 教练端 v3 浅色迁移 卡1:外壳 + 今日 + 学员

> 派发人:Claude(Fable 判断层) · 2026-07-30 · 实装:Codex
> 分级:T2(跨模块:DesignSystem + CoachKit + app 主题) · 发布档:P1(进 NEXT-RELEASE 1.0(16) 候选)
> base:`origin/release/1.0`(发版线) · 分支:`feat/coach-v3-shell-light`
> 参照物:`./MeetPR 教练端.dc.html`(与本卡同目录,浏览器直接打开可交互)

## 目标

教练端至今**一个 v3 token 都没有**——`MeetPRApp.swift` 里写着 `case .coach: return .dark`
+ 注释「CoachKit has no audited light palette yet」,黑金波 PR #279 的收据也明写教练端全程零 diff。
它现在还挂在 LegacyColors v2 暗色板上,和已经浅色化的学员端割裂。

本卡按 David 2026-07-30 的教练端样机,把**外壳(主题 + tab bar)+ 今日页 + 学员页**做成 v3 浅色,
**一比一**对齐参照物。剩下的面(消息合流 / 学员详情五子 tab / 我的 / 各 sheet)是卡2 及后续卡,本卡不碰。

## ⚖️ David 2026-07-30 四条拍板(全部已定,不要翻案、不要重新征求意见)

1. **导航照样机改成 4 tab**:`今日 / 消息 / 学员 / 我的`。「编排」tab **删入口**,
   `CoachPlanningHomeView` 及整个 `Planning/` 目录的**代码原样保留休眠**(defer≠delete,
   和评估期硬封存同一套路)——只摘掉 tab,不删文件、不删测试。
2. **教练端恒亮**。dark-pin 分域改成:学员端跟 `@AppStorage` 外观偏好 / **教练端恒亮** /
   登录流按 PR #291 走浅色。教练端**不做**深色版(样机零深色稿,做了就是我们替设计师发明)。
3. **「＋打点」仍 deferred**,本波不做(backend PR #116 是 07-28 关掉的)。本卡范围内不涉及。
4. **1RM = 教练可改、学员只读**。这是跨端卡,**不在本卡**,本卡不碰任何 1RM 代码。

## 文件范围

- `MeetPR/Sources/MeetPRApp.swift` —— 只改 `preferredAppColorScheme` 的 `case .coach` 那一行
- `Modules/DesignSystem/Sources/DesignSystem/Components/Navigation/MeetPRTabBar.swift`
  —— 加 2 个图标 case + 2 个可选着色参数(**默认值必须保持现值**,见下「共享组件纪律」)
- `Modules/CoachKit/Sources/CoachKit/CoachRootView.swift` —— `TabView` → `ZStack` 分页 + `MeetPRTabBar`
- `Modules/CoachKit/Sources/CoachKit/Features/Dashboard/CoachDashboardView.swift` —— 今日页重做
- 新增 `Modules/CoachKit/Sources/CoachKit/Features/Dashboard/CoachTodayTodoList.swift` —— 待办排序纯函数
- 新增 `Modules/CoachKit/Sources/CoachKit/Features/Dashboard/CoachWeekOverview.swift` —— 本周概况聚合纯函数
- `Modules/CoachKit/Sources/CoachKit/Features/StudentRoster/StudentRosterView.swift` + `StudentRosterRow.swift`
- `Modules/CoachKit/Tests/CoachKitTests/` + `Modules/DesignSystemTests/`(相应测试)

**不动**:`Planning/` 全目录、`Features/Receiving/`、`Features/StudentDetail/`、`Features/MyProfile/`、
`Features/Chat/`、StudentKit 任何文件、`LegacyColors.swift`(卡末批统一删)。

## 色值 → token 映射表(**逐个核对过,禁止硬编码 hex**)

| 样机 | token | 出现处 |
|---|---|---|
| `#F5F6F8` | `bgBase` | 屏底 |
| `#FFFFFF` | `surfaceCard` | 卡片底、tab bar 底 |
| `#E5E7EB` | `borderDefault` | 卡片描边、tab bar 顶线 |
| `#E9EBEE` | `borderHairline` | 本周概况卡内 1px 分隔线(样机 505) |
| `#D1D5DB` | `borderStrong` | 未完成格描边、次要按钮描边 |
| `#EDEEF1` | `bgStack` | 非计划日的矮格底(样机 1247) |
| `#D97706` | `gold500` | 选中 tab、待反馈/新申请点与 tag、申请卡描边 |
| `#111827` | `textPrimary` | 正文、「接收」实底按钮底 |
| `#4B5563` | `textSecondary` | 申请卡副行 |
| `#5C6371` | `textTertiary` | 大部分 meta 文案 |
| `#9CA3AF` | `textDisabled` | 未选中 tab、chevron 描边、空态副文案、非今天的星期字 |
| `#E5484D` | `danger` | 未读/待关注/异常、badge 底 |
| `#15803D` | `success` | 已完成格、在练点、接收成功条 |

卡片阴影 `0 4px 18px rgba(17,24,39,.06)`:用现成 `MeetPRCardSurface(elevation: .card)`;
对不上先看 `cardShadow` token,**别自己写 `.shadow()` 字面量**;真对不上就在 PR 里写明差在哪。

**禁止**出现 v2 旧 token(`brandRed` / `fgPrimary` / `fgSecondary` / `fgTertiary` / `surface2` /
`border` / `bg`)与任何 `Color(hex:)` / `legacyPlateHex` 字面量。

## 1. 主题(`MeetPRApp.swift`)

`case .coach:` 从 `return .dark` 改 `return .light`,注释同步改成「⚖️ 2026-07-30:教练端恒亮
(样机只有浅色一版)」。**不动** `guard case .authenticated` 那条(PR #291 在改)和 student 分支。

## 2. tab bar(样机 731–737)

现状 = 原生 `TabView` + 5 个 `.tabItem`。改成学员端同一套路:**`ZStack` 分页 + 自绘 `MeetPRTabBar`**
——iOS 26 的 `toolbar(.hidden, for: .tabBar)` 不可靠,这是学员端已经踩过的坑,别重走原生路线。

四项、顺序**照样机**:`今日 / 消息 / 学员 / 我的`。

- 高度/内距:`MeetPRTabBarContract` 现值(49pt rail + safeAreaInset)已等于样机的 83pt 外壳,直接复用
- 顶线:样机是 `1px #E5E7EB`(= `borderDefault`);组件现在用 `borderSubtle`。浅色下两者同值
  (都是 229,231,235),**视觉零差,不要改组件默认值**
- 选中色:样机 `#D97706` = `gold500`;组件现在写死 `goldCTA`(浅色 = `#B45309`,**不是样机的值**)
- 未选中色:样机 `#9CA3AF` = `textDisabled`;组件现在写死 `textTertiary`(`#5C6371`)
- badge:样机 `#E5484D` = `danger`;组件的 `TabUnreadBadge` 用 `unread`(= `dangerFill` `#C0343A`)

### 共享组件纪律(**这条最容易出事**)

`MeetPRTabBar` / `TabUnreadBadge` 是学员端在用的共享件,而学员端 UI 已于 2026-07-28 交付收尾
(正典 `docs/design/handoff-v3/DESIGN-SYSTEM-CANON.md`)。所以:

> **三处着色一律改成"可选参数 + 默认值 = 现值"**,教练端在调用处传 `gold500` / `textDisabled` /
> `danger`。**严禁**直接改组件里写死的颜色——那会连带改掉学员端 tab bar,是本波最容易犯的越界。
> 交付时必须给出证据:`StudentRootView` 的 tab bar 视觉零 diff(学员端截图对照)。

新增两个 `MeetPRTabIcon` case:`message`(样机 734 的对话气泡 path)、`students`(样机 735 的双人 path)。
两条 SVG path **逐字从样机抄**,别自己画、别换 SF Symbol。

## 3. 今日页(样机 465–532)

顶部区(467–471):左「7月22日 · 星期三」mono 12 / letterSpacing .06em / `textTertiary`,
下面「今日」Archivo 800 / 38 / lineHeight .95;右「待办」11 / `textTertiary` + 数字 Archivo 800 / 28。
再下一行「按处理顺序排列」mono 12 / `textTertiary`。**字号字重逐个照样机,别就近取整**。

### 待办卡组(472–476 + 逻辑 1211–1216)

一张白卡包住 N 行,行间 `1px borderDefault` 上边线(第一行无),行高 = 14/16 内距。
每行:7pt 圆点(色 = 该项 dot)│ 标题 15/700 + 副行 12 `textTertiary` │ 右侧 tag 11/600(色 = dot)│ chevron。

**排序与内容严格照样机 1211–1216 的顺序**:

| 序 | 条件 | 标题 | 副行 | tag | dot | 点击 |
|---|---|---|---|---|---|---|
| 1 | 待反馈视频 > 0 | `N 段视频等你反馈` | `最早一段 <相对时间>` | 待反馈 | `gold500` | 跳消息 tab |
| 2 | 未读消息 > 0 | `N 条学员消息未读` | 学员名 ` · ` 连接 | 未读 | `danger` | 跳消息 tab |
| 3 | 每个异常学员各一条 | `<名字> 已 N 天未训练` | `发条消息问问情况` | 待关注 | `danger` | 开该学员聊天 |
| 4 | 有新学员申请 | 见下 | 见下 | 新申请 | `gold500` | 跳学员 tab |

- 序 3 的天数**用 `TriageSignal.notTrained(daysMissed:)` 的真值**,样机写死的「3 天」是假数据。
  只有 `.notTrained` 触发这一条;`.awaitingReply` 不进待办(样机没有这一档,**不要自己加**)。
- 序 4 样机只画了单个申请人。真实可能多人:**1 人时照样机** `<名字> 申请加入` / `已等待 <时长>`;
  **>1 人时** `N 位新学员申请加入` / `最早已等待 <时长>`。这是**有意扩展**,PR 里写明。
- 数据来源:待反馈视频 = `videoQueueViewModel.pendingCount`;未读 = `chat?.inbox`;
  异常 = `rosterViewModel.rows` 的 `triageSignals`;申请 = `queueViewModel.pendingCount`。
  **全走已有 VM,本卡不加任何新 repository / 新端点。**
- 全空时走样机 480–482 的空态:52pt 白圆 + `success` 对勾 + 「今天都处理完了」15/600 +
  「学员新上传视频或发消息时会出现在这里」12 `textDisabled`。**禁「暂无数据」式文案。**
- 接收成功条(477–479):`success@30%` 描边白卡 + 对勾 + `新学员 <名字> 已接收 · 已加入学员列表`。

### 本周概况卡(483–530 + 逻辑 1240–1265)

排序纯函数写进 `CoachWeekOverview`,**view 里不放算法**。数据全部由 `rosterViewModel.rows`
+ 各学员 plan/logs 推出——**不加新端点**(roster 已经把 plan + logs + feedback 都取回来了)。

- 头部:`weekPct` = `round(Σ完成 / Σ计划 × 100)%` Archivo 800/26;
  右边 `Σ完成 / Σ计划 训练日已完成` 12 `textTertiary`;最右 `W<ISO 周数>` mono 10 / .1em / `textDisabled`
- legend 条(494–503):三档 `按计划在练`(success)/ `还没开始`(textDisabled)/ `待关注`(danger),
  **flex 比例 = 该档人数**,人数为 0 的档**整条不显示**;下面一行圆点 + 标签 + `N 人`(人数 700 `textPrimary`)
- 学员分档:`triageSignals` 非空 → 待关注;完成 > 0 → 在练;否则 还没开始
- 星期表头(507–515):`一二三四五六日`,今天列 `textPrimary`/700,其余 `textDisabled`/400;
  左留 52pt 给姓名列、右留 30pt 给比值列
- 每行 7 格(517–527),**四种格态逐字照样机 1247–1251**:

  | 格态 | 高 | 上边距 | 底 | 描边 |
  |---|---|---|---|---|
  | 非计划日 | 4 | 6 | `bgStack` | 无 |
  | 计划日 · 已完成 | 14 | 0 | `success` | 无 |
  | 计划日 · 今天之前未完成 | 14 | 0 | 异常学员 `danger@16%`,否则 `bgBase` | 1px 实线,异常 `danger` 否则 `borderStrong` |
  | 计划日 · 今天及以后未完成 | 14 | 0 | `surfaceCard` | 1px **虚线** `borderStrong` |

- 右侧比值 `完成/计划` mono 11.5/600,色:全完成 `success` / 异常 `danger` / 否则 `textTertiary`
- 底部「看全部学员 ›」12.5 `textTertiary` → 跳学员 tab

**⚠️ 日期口径(最容易做错的一处)**:样机把「哪几天是计划日」写死在 `PLAN={3:[0,2,4],4:[0,1,3,5]}`
常量里,**那是假数据,不是契约**。真实实装:遍历 `StudentPlanView.days`,取每天的 `day.date`
(= `shiftedToDate ?? scheduledDate`),落在本周(设备日历的周一–周日)的映射到对应列;
`exercises.isEmpty` 的 planDay 算休息日 = 非计划日。判定一律用 **`CoachFeatureCalendar`**
(CoachKit 内已有,`Features/Shared/CoachStudentFormatting.swift:122`)——
**别引 StudentKit 的 `PlanCalendarDayIdentity`(它是 internal,跨模块引不到)、别自己 `Calendar(identifier:)`。**
完成判定沿用 roster 现成的写法:`logs.contains { $0.completed && CoachFeatureCalendar.isSameDay(...) }`。

## 4. 学员页(样机 534–580)

- 标题「学员」Archivo 800/34。**样机没有右上角按钮**,现状若有,删掉
- 搜索框(537):白底 + 1px `borderDefault` + 圆角 12 + 放大镜 17pt `textDisabled` +
  placeholder「搜索学员」14。接现成 `rosterViewModel.searchText` / `filteredRows`,**别新造过滤逻辑**
- 新学员申请卡(538–546):小标题 `新学员申请 · N` mono 12 `gold500`;
  卡为白底 + `gold500@35%` 描边 + 圆角 16;姓名 Archivo 800/18、右上「已等待 <时长>」11 `textTertiary`;
  副行 13 `textSecondary`(性别 · 年龄 · 体重 · 训练年限);自报 1RM 一行 mono 14/700
  `S:xxx　B:xxx　D:xxx`(**全角空格分隔,照样机**)+ `(kg)` 12 `textTertiary`;
  底部三件:`接收`(`textPrimary` 实底 + `inkOnGold`… 注意样机是白字 `#FFFFFF`,用 `inkOnCTAFill`)/
  `查看资料`(1px `borderStrong` 描边)/ 46pt 宽的 `×`(1px `borderDefault`)。
  三个动作全接现成 `queueViewModel`,`查看资料` 打开现成 `StudentOnboardingProfileView`。
  **多个申请时**:样机只画一张卡 → 按等待时长升序全部平铺(每张一卡),这是**有意扩展**,PR 写明
- 活跃分组(547–561):小标题 `活跃 · N` mono 12 `textTertiary`;每行白卡圆角 16:
  9pt 状态圆点 + 姓名 16/700 + 右侧最近活跃 mono 11 `textTertiary`(+ 无计划时 `gold500` 药丸);
  第二行:3 段 16×5 圆角进度段 + 周标签 mono 11 + 右侧「完成率」11 + 百分比 mono 14/700
- 异常分组(562–578):小标题 `异常 · N` mono 12 `danger`;行内容同上,圆点恒 `danger`,
  右侧改成 `danger`/600 的异常原因短句(`已 N 天未训练` 等,由 `TriageSignal` 推)
- 整行点击 → 学员详情(现成 `detailContext`)

## 约束

- **一比一就是一比一**:样机上没有的东西不要加(不加下拉筛选、不加排序菜单、不加右上角按钮);
  样机上有的不要漏。**有意偏离只允许下面「已授权偏离清单」里的项**,
  其余任何偏离都要在 PR 里单列一节说明理由,别默默处理。

### 已授权偏离清单(实装期追加,以此为准)

| # | 偏离 | 授权 |
|---|---|---|
| 1 | 多个新学员申请时:>1 人用 `N 位新学员申请加入`,样机只画了单人 | 派卡时 |
| 2 | 多个申请卡按等待时长升序全部平铺,样机只画一张 | 派卡时 |
| 3 | 「＋打点」不做 | ⚖️David 2026-07-30 拍板 |
| 4 | **未读口径按「消息条数」不是样机的「会话数」** —— 样机 1181 行 `unread` 是写死的名字数组,其数据模型里不存在「每会话未读条数」,对此无立场;照字面复刻会让「N 条消息未读」显示人数 | Claude 提出,review-loop 对质后 reviewer CONCEDE |
| 5 | **本周无计划时,概况卡收敛成「本周还没有训练安排」+ 看全部学员**,样机始终渲染完整结构 | Claude 在第 1 轮定向返修中授权(样机没画 0 计划态,原样渲染是「0% 0/0」空壳);reviewer 复议后 CONCEDE |
| 6 | 删除已成孤儿的 `TriageStripSection.swift`(base 上已零消费者,且阻塞本卡的周期字段清理) | Claude 收货时 |
- **像素闸门**:参照物用 `python3 -m http.server` 开浏览器,与模拟器同屏逐屏比对(今日 / 学员 /
  今日空态 三屏起)。**严禁"编造出处"**——注释里写「样机如此」的每一处,必须真在
  `MeetPR 教练端.dc.html` 里对得上行号(这是 v2 实装失败的根因,W0 抓到过三处)。
- **复用优先**:`MeetPRTabBar` / `MeetPRCardSurface` / `MeetPRSpacing` / `MeetPRRadius` /
  `Font.MeetPR` / `CoachFeatureCalendar` / 现有各 ViewModel 都已存在,不要造平行组件、
  不要新开 repository、不要加新后端调用。
- 算法(待办排序、周概况聚合)放**可单测的纯函数**里,view 只渲染。
- 文案走 `Localizable.xcstrings`,**禁 `String(format:)`**(仓内既有纪律)。
- 保留现有 `accessibilityIdentifier`;tab 切换的 accessibility 沿用学员端 `StudentTabAccessibilityHost` 的做法。
- **不 commit、不 push**,改动留在工作区等 Claude 跑 review-loop。

## 验收标准

- `swift test` CoachKit + DesignSystem 全绿;全量 SPM 不回归
- `xcodebuild -configuration Demo` **0 warning**;`swiftlint --strict` 干净(阈值以仓内配置为唯一事实源)
- 模拟器截图:①今日(有待办)②今日(全空态)③学员(含申请卡 + 活跃 + 异常)④tab bar 四态
  ⑤**学员端 tab bar 对照图(证明零 diff)**
- grep 自证:改动文件内零 v2 旧 token、零硬编码 hex
- 「编排」tab 入口已摘除,但 `Planning/` 目录文件数与测试数**与 base 完全一致**(`git diff --stat` 自证)
- 教练 Demo 路径能走通(`configuration=Demo`,否则默认 Debug 无 DEMO_MODE)
