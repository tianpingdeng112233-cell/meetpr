# Spec 095 屏幕稿转写（David 2026-10-26「定稿」）

原稿：claude.ai/artifact/CpdVk49969WArhAjW74HeY 「屏幕稿」页（实装方打不开，以本文为准）。只定结构、层级、间距与文案；颜色、字体、圆角一律用各端现有 design token，不照抄稿里的色值。稿宽 390pt，下文尺寸按 pt/dp 理解。

## ① 待接收页（在现有 PendingBindView 上加一块）

现有元素与顺序不变：右上「登出 ›」；白卡里依次是标题「已发送绑定请求」、「等待教练 {教练} 接收」、等待时长条、「你已提交给教练的资料」、24-48 小时说明、「取消请求」。

新增「提醒」块，插在 24-48 小时说明与「取消请求」之间：
- 容器：品牌金描边（约 1.5）、浅金底、圆角约 14、内边距 14/16，内部纵向间距 10。
- 第一行：铃铛图标（20）+ 粗体「教练接受后提醒我」（15）。
- 第二行：次要色小字「不用一直开着 App，接受后会发一条通知给你。」（13）。
- 主按钮「开启提醒」：高 44、胶囊、深色实心。
- 只在 iOS 且通知权限「未决定」时出现；安卓、已允许、已拒绝都不出现。点后弹系统框，结果不论，块消失。

## ② 欢迎页（新，全屏，一次性）

自上而下，左对齐，页边距 24，顶部留白约 96，区块间距 32：
1. 头像 72 圆形：有教练头像用头像；没有则浅金底 + 金描边 + 显示名首字。
2. 小字「绑定成功」（等宽或强调小字，13，品牌金深色）；下方 10 处大标题（32，最粗）「你现在是{教练}的学员了」，可换行。拼名规则见 SPEC。
3. 三步列表，每行：28 圆形深色序号 + 右侧两行（粗体 16 标题 / 次要色 14 说明），行内边距上下 14：
   - 1「教练为你排计划」/「参考你填的资料和三大项成绩」
   - 2「计划出现在「今日」」/「每次打开 App，先看今天练什么」
   - 3「练完记录，教练就能看到」/「每组重量、次数和 RPE 同步给教练」
4. 弹性空白。
5. 底部按钮组，间距 12：
   - 次按钮「教练发计划时提醒我」：高 52、白底描边、左侧铃铛图标；只在 iOS 且权限「未决定」时出现。
   - 主按钮「进入」：高 56、胶囊、深色实心、字 18 粗。

## ③ 今日 · 新学员版等计划卡（替换 DashboardPlanWaitingState 的内容，仅新学员）

页面其它部分（顶栏、「W1 编排中」、进度条、体重/距比赛、营养、tab bar）保持现状。卡片内，内边距 20、纵向间距 14：
1. 标题（18 粗）「{教练}正在为你排第一份计划」。
2. 说明（14 次要色）「排好后会直接出现在这里。有想法可以先跟教练说。」
3. 次按钮「给教练留言」（高 46、白底描边，沿用现有跳转）。
4. 分隔线。
5. 小标签（12 次要色）「等计划的时候」。
6. 两行入口，每行最小高 44，左两行文字、右「›」：
   - 「完善资料」/「资料越全，计划越贴合你」→ 我的资料
   - 「填比赛日」/「有比赛计划？教练会按比赛日来排」→ 现有比赛日编辑入口；已有比赛日时整行隐藏。
- 不出现「本周小结」与任何发布时间。

## ④ 今日 · 第一份计划卡

放在进度条之下、周进度/周历之上；其余首页内容保持现状。
- 卡片：白底、品牌金描边（约 1.5）、圆角约 18、内边距 18/18/20，纵向间距 12。
- 顶行：左侧两行——小字「第一份计划」（12，品牌金深色）+ 标题（19 粗）「{教练}发布了你的第一份计划」；右上「×」关闭按钮，触控区 44。
- 中行：等宽次要色「W1 – W{n} · 共 {m} 节」。
- 主按钮「▶ 开始 W1D1」：高 50、胶囊、深色实心。
- 卡片显示期间，隐藏首页底部悬浮的「开始训练」按钮，避免一屏两个开始；卡片消失后恢复。

## 英文与繁体

英文（按 SPEC 拼名规则）：
- ①「Remind me when my coach accepts」/「No need to keep the app open — we'll notify you once you're accepted.」/「Turn on reminders」
- ②「You're in」/「You're now training with {name}」；三步「Your coach builds your plan」/「Based on your profile and big-three numbers」、「Your plan shows up in Today」/「Open the app to see what to train」、「Log it and your coach sees it」/「Weight, reps and RPE sync to your coach」；「Remind me when my plan is ready」/「Continue」
- ③「{name} is building your first plan」/「It'll show up right here. Have something in mind? Tell your coach.」/「Message coach」/「While you wait」/「Complete your profile」/「A fuller profile means a better-fit plan」/「Add a meet date」/「Your coach will plan around it」
- ④「First plan」/「{name} published your first plan」/「W1 – W{n} · {m} sessions」/「Start W1D1」

繁体按 spec 094 生成流程与覆写表出，不手写。
