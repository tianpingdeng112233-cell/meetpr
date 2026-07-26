# UI Refresh 冲突记录

> 本文件只记录黑金 UI 样机与 `feat/black-gold-ui-r10` 现状之间的冲突、缺口和跳过项。
> 未经 David 拍板，不在本波擅自改变导航、业务逻辑、数据流或封存能力。

### C-01 Tab 结构已核实无冲突
- **样机位置**：`MeetPR 学员端.dc.html`「tab bar」L433–438；`MeetPR 教练端.dc.html`「tab bar」L221–228
- **样机内容**：学员端 4 tab（今日 / 训练 / 成长 / 我的），教练端 5 tab（今日 / 学员 / 编排 / 接收 / 我的）。
- **现状缺口**：无。代码中的 tab 集合与样机完全一致；开卡前预设的「样机 4 tab vs 现状不同」不成立。
- **建议选项**：A 保持现状，仅换视觉；无需 B / C。
- **状态**：已还原范围确认，无需处置

### C-02 学员端顶部聊天泡与通知铃语义不一致
- **样机位置**：`MeetPR 学员端.dc.html`「今日」L48–132
- **样机内容**：右上角 44pt 圆形消息气泡图标，红底数字徽章「3」。
- **现状缺口**：原 `StudentNotificationBell` 使用 `bell` / `bell.badge`；学员端点击后进入通知中心，教练端点击后进入聊天。
- **建议选项**：A 只换视觉并保留现有路由及未读数据源；B 改变入口语义或路由；C 保留通知与聊天双入口。
- **状态**：David 已拍板 A；两端均换为消息气泡 + 红色数字徽章，路由与数据源不变

### C-03 亮色主题本波不提供切换入口
- **样机位置**：`MeetPR 学员端 亮色.dc.html`、`MeetPR 教练端 亮色.dc.html`、`MeetPR 学员端 双主题.dc.html`
- **样机内容**：完整亮色令牌与双主题切换演示。
- **现状缺口**：App 根级固定 `.preferredColorScheme(.dark)`。
- **建议选项**：A 本波仅落亮色令牌并保持暗色；B 后续独立任务增加切换入口。
- **状态**：已跳过（本卡已定）

### C-04 样机存在但需逐项核实数据源的元素
- **样机位置**：`MeetPR 学员端.dc.html`「今日 / 成长 / 完成庆祝 / 训练回顾」；`MeetPR 教练端.dc.html`「接收 / 我的」
- **样机内容**：距比赛 N 天、体重、连续训练次数、教练已收日志、已通知教练、E1RM vs 训练 1RM、三格历史统计、等待时长、邀请码使用次数。
- **现状缺口**：部分数据源未见或尚未确认；`DashboardProfileMetricsView` 已有体重 / 比赛指标源。连续训练次数原无 iOS 数据源，本轮后端已提供 `GET /students/me/streak`。
- **建议选项**：A 有真实数据源则还原；B 无源则跳过；C 后续另开数据能力任务。
- **状态**：连续训练次数已按 David 拍板接线，404 / 错误 / 无数据隐藏，Demo 固定 12；其余无源元素继续按本卡跳过

### C-05 页面横向内边距令牌与样机实测不一致
- **样机位置**：两端暗色样机各主 tab 屏
- **样机内容**：主 tab 屏实测 `padding: 6px 20px 28px`，横向 20pt。
- **现状缺口**：设计令牌 `--page-x` 为 16px。
- **建议选项**：A 主 tab 以样机 20pt 为准并注释令牌差异；B 全部统一为 16pt，牺牲像素一致性。
- **状态**：待 David 拍板（任务卡要求本波以样机 20pt 为准）

### C-06 固定像素规格与 Dynamic Type 规范冲突
- **样机位置**：全部样机；任务卡附录 A
- **样机内容**：字号、间距和控件尺寸均为固定像素规格。
- **现状缺口**：`AGENTS.md` 要求 Dynamic Type 且避免硬编码字号 / 间距；像素级还原与其直接冲突。
- **建议选项**：A 本波按任务卡集中令牌并固定尺寸；B 后续补 `@ScaledMetric`；C 在设置中提供字号档位。
- **状态**：待 David 拍板；本波按任务卡执行，登记可访问性欠账

### C-07 无样机屏幕只套令牌不重排
- **样机位置**：暗色样机未覆盖登录 / 注册、BindGate、Onboarding、Readiness、计时器、视频选择与裁剪、教练规划向导、邀请码创建 sheet、账号安全、导出、历史明细、成长曲线及评估屏。
- **样机内容**：无可供一比一还原的新版式。
- **现状缺口**：无法从设计基准推导新布局。
- **建议选项**：A 仅替换颜色、字体和 DesignSystem 组件；B 后续补齐样机后再重排。
- **状态**：已跳过版式重排（本卡已定）

### C-08 App 字体资源无法覆盖独立 DesignSystem preview
- **样机位置**：设计总纲与字体令牌
- **样机内容**：Archivo / IBM Plex Mono / IBM Plex Sans 真字体。
- **现状缺口**：字体按任务卡放进 app resources + `UIAppFonts`；`Modules/DesignSystem` 无 resources 声明，因此独立 SPM preview / host 单测只能走系统回退。
- **建议选项**：A 接受 preview 回退；B 字体改入 DesignSystem 包并运行时注册。
- **状态**：待 David 拍板；本波按任务卡执行 A

### C-09 Archivo named instance 名称与早期描述不符
- **样机位置**：字体令牌；`docs/design/fonts-staging/Archivo-VF.ttf`
- **样机内容**：display 需要 Archivo 800 / 900。
- **现状缺口**：实测 PostScript 名为 `ArchivoRoman-ExtraBold` / `ArchivoRoman-Black`，VF 默认实例是 SemiBold 600。
- **建议选项**：A 先用实测 named instance；B 若 iOS 取不到则用 fonttools 抽 static。
- **状态**：已还原方案确定；若触发 B 将追加记录

### C-10 中文标题字重与 Archivo 西文不完全一致
- **样机位置**：全部中西文混排标题
- **样机内容**：Archivo 800 / 900 与 Noto Sans SC 中文组合。
- **现状缺口**：中文按任务卡只能回退系统苹方，最重字形与 Archivo 800 / 900 视觉不完全一致。
- **建议选项**：A 接受系统中文回退的字重差；B 引入中文字体，但违反本波不打包中文字体的裁决。
- **状态**：待 David 拍板；本波按任务卡执行 A

### C-11 零调用点死视图不纳入还原
- **样机位置**：不适用
- **样机内容**：样机只覆盖实际可达屏。
- **现状缺口**：`E1RMMiniTrendCard`、`DashboardComponents.DashboardSection`、`ProgressDashboardView`、`TrainingHistory/DayDetailView`、`TodayWorkout/ExerciseExecutionView`、`SetRecordRow`、`PlateMathSheet`、`WorkoutDayHeader`、`MyProfile/ProfileCardsSection` section struct 均无调用点。
- **建议选项**：A 本波不还原不删除；B 后续独立清理任务删除。
- **状态**：已跳过；清理时机待 David 拍板

### C-12 训练日历月视图缺失
- **样机位置**：`MeetPR 学员端.dc.html`「训练」L134–173
- **样机内容**：周 / 月切换以及完整月历。
- **现状缺口**：`TrainingCalendarView` 只有横向周日期条；增加月视图属于新功能。
- **建议选项**：A 本波只还原周视图视觉；B 后续独立实现月视图。
- **状态**：已跳过月视图；待 David 拍板后续

### C-13 完成训练交互是长按还是滑动
- **样机位置**：`MeetPR 学员端.dc.html`「训练」L281–287
- **样机内容**：长按 1100ms，金色进度填充和三段触觉。
- **现状缺口**：原 `SlideToCompleteButton` 使用拖拽滑动确认；样机要求长按确认。
- **建议选项**：A 保留拖拽，只换黑金皮肤；B 改成长按并保持完成回调不变。
- **状态**：David 已拍板 B；现为长按 1100ms 填充，提前松手 300ms 回弹，填满才触发原完成回调

### C-14 冻结或休眠能力不得随换皮放出
- **样机位置**：`MeetPR 教练端.dc.html`「编排 / 今日 / 学员详情」
- **样机内容**：导入计划 `.xlsx`、评估期统计和评估进度卡。
- **现状缺口**：`PlanImportCapability.isEnabled == false`；`evaluationSealed = true`，评估全链路休眠。
- **建议选项**：A 本波跳过；B 后续经独立产品 / 技术任务解除封存。
- **状态**：已跳过（本卡已定）

### C-15 我的页字段需逐项比对
- **样机位置**：`MeetPR 学员端.dc.html`「我的」L386–429
- **样机内容**：恢复评估、伤病记录、增强肌群、组间休息、比赛日期、身高体重、训练背景、训练环境、成长曲线、改密码、导出和退出登录。
- **现状缺口**：`MyProfileView` 当前分组与字段需在 W2 逐项核对；不得为贴样机擅自增删业务条目。
- **建议选项**：A 现有字段只换皮；B 缺失字段登记后另开功能任务；C 多余字段保留并换皮。
- **状态**：待 David 拍板（逐项核实中）

### C-16 今日主 CTA 副行数据源待核实
- **样机位置**：`MeetPR 学员端.dc.html`「今日」L48–132
- **样机内容**：主 CTA 副行显示当日主项列表，例如「蹲 · 推 · 拉」。
- **现状缺口**：当前 CTA 是否已有该行及可用的当日主项数据需在 W2 核实。
- **建议选项**：A 有真实当日计划数据则还原；B 无源则跳过副行；C 后续补 ViewModel 输出。
- **状态**：待核实

---
## 终局拍板（David 2026-07-26,「BC 全按最新 handoff 包做」）
- 主题:学员端暗/亮双主题上线(跟随系统+我的页三档);教练端与登录锁深色。
- 训练页:两态结构(态A清单/态B记录)按 §4.2;**周/月日历删除**(推翻此前「加月视图」——规格训练页无日历)。
- NumberPad 九宫格、金幕转场完整版、结算页舞台化、缺失态全套:已实装。
- CTA 副行:写死「蹲 · 推 · 拉」(推翻「保留真实数据」倾向)。
- 离线优先记组:确认要做;定位=UI 主线 PR 之后的独立收尾子轮(独立互审+PR)。
- token 正典=handoff-v2/tokens.css+README 表;包内矛盾 --gold-cta 暗色(README #FFC53D vs tokens.css #FFB800)按 tokens.css=#FFB800 执行,待设计师澄清。
- 旧 meetpr-design-skill/ 已被 handoff-v2 取代(设计师明示),仅存档。
