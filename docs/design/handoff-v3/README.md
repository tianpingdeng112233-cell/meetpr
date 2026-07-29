# MeetPR 学员端 — 实装规格（Handoff Spec）

给 Claude Code / 前端工程师的实装说明。设计源文件：`MeetPR 学员端.dc.html`（单文件，暗亮双主题）。
本文档描述**该做成什么**，样机描述**长什么样**。二者冲突时以本文档为准。

---

## 0. 阅读顺序

1. 本文档第 1–3 节（主题、全局规范）
2. `MeetPR 组件库.dc.html` — 7 个组件的全部状态，左暗右亮；先把这 7 个写成 React 组件
3. `MeetPR 学员端 双主题.dc.html` — 在浏览器打开，右上角切换暗/亮，把 5 个流程点一遍
4. 第 4–6 节（屏幕、状态、动效）—— 用组件拼装屏幕
5. `motion/` — 5 个关键动效的可运行参考实现（纯 HTML/JS，双击打开），直接抄代码，不要凭文字重写
6. 第 7–9 节 收尾

样机已全部改用 CSS 变量：结构和内联样式**可以直接从样机翻译成 JSX**（class→className、style→对象），颜色保持 var()、不要写死。

---

## 1. 主题：只有一套 UI，两组变量

样机里没有"暗色版"和"亮色版"两份代码。**一份 DOM，切 `.theme-light` 类**即可换主题。
变量定义在 `MeetPR 学员端.dc.html` 的 `<helmet><style>` 里。你的 `globals.css` = `tokens.css` + `motion.css` 两个文件直接拼接（token、@keyframes、工具类、reduced-motion 降级都在里面）。

```
:root { /* 暗色，默认 */ }
.theme-light { /* 亮色覆盖 */ }
```

| Token | 暗色 | 亮色 | 用途 |
|---|---|---|---|
| `--bg-deep` | `#050506` | `#EDEEF1` | 页面最底层（手机外的桌面） |
| `--bg-base` | `#0A0A0C` | `#F5F6F8` | App 主背景 |
| `--bg-inset` | `#101014` | `#FAFAFB` | 内凹区（列表容器底） |
| `--bg-stack` | `#121217` | `#EEF0F3` | 堆叠/收纳区背景 |
| `--surface-card` | `#141416` | `#FFFFFF` | 卡片 |
| `--surface-elevated` | `#161618` | `#FFFFFF` | 浮层、Sheet |
| `--surface-key` | `#1C1C20` | `#F3F4F6` | 键盘按键、输入框、次级胶囊 |
| `--surface-raised` | `#232327` | `#EEF0F3` | 卡上之卡 |
| `--border-hairline` | `#17171A` | `#E9EBEE` | 表格行分隔 |
| `--border-subtle` | `#1E1E22` | `#E5E7EB` | 卡片描边 |
| `--border-default` | `#262629` | `#E5E7EB` | 分区线 |
| `--border-strong` | `#2E2E32` | `#D1D5DB` | 控件描边 |
| `--text-primary` | `#EDEDED` | `#111827` | 标题、大数字 |
| `--text-secondary` | `#C8C8CC` | `#4B5563` | 正文 |
| `--text-tertiary` | `#A1A1A6` | `#5C6371` | 次要说明 |
| `--text-muted` | `#8A8A90` | `#5C6371` | 标签、单位 |
| `--text-faint` | `#8A8A90` | `#5C6371` | 弱化信息（暗色与 muted 同值） |
| `--text-dim` | `#8A8A90` | `#5C6371` | 未完成态（亮色 4.5:1 是地板，tertiary 以下共用一个灰） |
| `--text-disabled` | `#55555C` | `#9CA3AF` | 禁用 |
| `--text-ghost` | `#3E3E44` | `#D1D5DB` | 占位骨架 |
| `--gold-500` | `#F5A623` | `#D97706` | 品牌强调：图标、激活态、发光 |
| `--gold-cta` | `#FFB800` | `#B45309` | 大按钮填充（见下方例外） |
| `--gold-400` | `#FBBF3E` | `#F59E0B` | 渐变高光 |
| `--gold-200` | `#FFE28E` | `#FEF3C7` | 最浅色阶 |
| `--gold-rgb` | `245,166,35` | `217,119,6` | 用于 `rgba(var(--gold-rgb), .12)` 类的半透明底 |
| `--ink-on-gold` | `#141414` | `#FFFFFF` | 金色上的字 |
| `--success` | `#5E9E78` | `#15803D` | 完成、达标 |
| `--danger` | `#E5484D` | `#E5484D` | 失败、异常、需紧急处理 |
| `--danger-muted` | `#C88888` | `#A33B40` | 失败组的数值（静音红；亮色下加深以保 ≥4.5:1） |
| `--chart-line` | `#DCE3EA` | `#9AA4B0` | RPE 折线 |
| `--desk-1` / `--desk-2` | `#1A1A1E` / `#050506` | `#E9E9EE` / `#D2D2D9` | 样机外壳桌面，App 内不用 |

**主 CTA 是唯一的主题例外。** 暗色是金色胶囊 + 深字（`--gold-cta` / `--ink-on-gold`）；
亮色下金色在白底上会"漂"，改为**深蓝黑胶囊 + 白字**（`#111827` / `#FFFFFF`）。
样机已定义 `--cta-bg` / `--cta-text` 承载这个差异（另有 `--cta-fill:#111827` 选中态深蓝黑，两主题同色），整块拷入即可，不要在组件里写 if。

**语义色纪律（重要）：** 金色 = 品牌强调、进行中、当前。红色**只**用于失败组、异常、缺席、清空这类需要用户处理的状态。不要用金色表示警告。

---

## 2. 全局规范

**圆角**（只有这几档，不要出现 9/11/13/15px）
- `4px` 微标记（进度条、色条）
- `10px` 小贴片（内嵌注释块、月历格）
- `12px` 小控件（键盘按键、chip、输入框）
- `16px` 卡片
- `20px` 弹窗、底部 Sheet
- `999px` 胶囊（按钮、标签、徽章）

**字号**（不要出现 12.5 / 13.5 这类半像素）
- `28–34px` 大数字（重量、E1RM、结算数字），`IBM Plex Mono` 800
- `21–22px` 页面主标题，`Archivo` + `Noto Sans SC` 800
- `16px` 卡片标题 700
- `14–15px` 正文 400/600
- `13px` 次要信息
- `11–12px` 标签、单位、Mono 小字（字距 `.04–.06em`）

**字体**
- 标题 `Archivo` 700/800（中文回落 `Noto Sans SC` 900）
- 正文 `IBM Plex Sans` + `Noto Sans SC`
- **所有数字、代号（W1D4、175、8.5、时间）一律 `IBM Plex Mono`** —— 这是这套设计的识别点，等宽数字不会在增减时跳动

**间距** 4 的倍数；卡片内边距 `14–16px`；卡片间距 `12px`；屏幕左右安全边距 `16px`

**触摸目标** 最小 44×44px，无例外

**动效曲线**
- 常规过渡 `cubic-bezier(.22,.61,.36,1)` 200–260ms
- 弹性（容器展开）`cubic-bezier(.34,1.36,.64,1)`，允许 2–3px overshoot
- 错峰步长 30–40ms，不超过 6 个元素
- 卷折收纳 `cubic-bezier(.4,0,.2,1)` 620ms（WAAPI 分段 rotateX，见 `motion/03`）
- JS 补间统一 easeOutCubic（1-(1-p)³）；数字滚动用 quart（1-(1-p)⁴）
- 所有动效必须响应 `prefers-reduced-motion: reduce` → 降级为透明度渐变或直接切换

---

## 3. 组件清单

**这些组件已经拆好了。** 每个是一个独立文件，可单独在浏览器打开；props 契约（含 TS 类型、枚举、默认值）写在文件末尾 `<script data-dc-script data-props="…">` 的 JSON 里，直接读那段就是接口定义。

| 组件 | 文件 | 关键约束 |
|---|---|---|
| `DayChip` | `DayChip.dc.html` | 休息日不显示状态点 |
| `Badge` | `Badge.dc.html` | danger 只给需处理的异常 |
| `SetRow` | `SetRow.dc.html` | 成功/失败与视频上传是两个独立图标 |
| `StatTile` | `StatTile.dc.html` | 大数字 Mono，delta 靠正负号表意 |
| `GoldCTA` | `GoldCTA.dc.html` | 纯色填充 + 蓄力按压态；亮色深蓝黑。斜向光泽是 App 级的，只给首屏 hero CTA |
| `ExerciseCard` | `ExerciseCard.dc.html` | 内部渲染 SetRow；全部完成后收成一行。动作名 prop 叫 `exercise` 不叫 `name` |
| `NumberPad` | `NumberPad.dc.html` | 次数模式禁用小数点；重量吸附 0.25kg |

**先打开 `MeetPR 组件库.dc.html`** —— 一页看完 7 个组件的全部状态，左暗右亮。照着它一对一映射成 React 组件；屏幕层面可以直接从整屏样机翻译 DOM，遇到这 7 个组件的重复结构就换成组件调用。

下面是每个组件的详细规格。

### `<DayChip>`
周日历里的一格。
```ts
interface DayChipProps {
  weekday: string;            // "一".."日"
  date: number;               // 22
  state: 'done' | 'missed' | 'rest' | 'today' | 'future';
  isSelected: boolean;
  onSelect(): void;
}
```
- 尺寸 `52×44`，圆角 `12`
- `done` 右上绿点 `--success`；`missed` 右上红点 `--danger`；`rest` 整体降到 `--text-faint` 且**不显示任何点**；`future` 降灰
- `today` 且选中：深底 `#111827`（亮色同色）+ 白字 + 金色描边 `1.5px --gold-500` + 右上金点，金点做 `pulseDot` 呼吸（1.8s）
- **规则：休息日不算未完成。** 只有"有计划但没练"才是 `missed`

### `<SetRow>`
训练明细里的一组。
```ts
interface SetRowProps {
  index: number;              // 1-based
  weight: number; reps: number; rpe: number;
  status: 'pending' | 'done' | 'failed';
  videoState: 'none' | 'uploading' | 'uploaded' | 'failed';
  onEdit?(): void;
}
```
- 网格 `22px | 1fr | 1fr | 1fr | 64px`，行高 44，分隔 `--border-hairline`
- 右侧两个图标彼此独立：**对勾/叉 = 这一组成功还是失败**；**相机 = 视频上传状态**。不要用一个图标同时表达两件事
- `done` → 绿勾；`failed` → 红叉 + 数值变 `#C88`；`pending` → 空心圆 + 全行 `--text-dim`

### `<NumberPad>`
点重量或次数弹出的九宫格。
```ts
interface NumberPadProps {
  field: 'weight' | 'reps';
  value: number;
  onCommit(v: number): void;
  onCancel(): void;
}
```
- 底部 Sheet，圆角 `20px 20px 0 0`
- 3 列网格，键高 52，间距 8
- `field='reps'` 时小数点键禁用（`opacity .25` + `pointer-events:none`）
- 提交时吸附：重量取 `0.25kg` 倍数、区间 `20–500`；次数整数、区间 `1–100`
- 点遮罩或"取消"关闭，不写入
- **实装时必须换成真 `<input inputMode="decimal">`**，样机里是 span

### `<PlateVisual>`
杠铃配片图。输入总重，输出左侧配片（含杠铃杆 20kg、卡箍可选 2×2.5kg）。
- 片规格按真实：25/20/15/10/5/2.5/1.25kg，直径与厚度按比例，25kg 最大最厚
- 杠铃右端是**平的**，不是尖的
- 选中卡箍时不得改变杆的几何
- 建议做成纯函数 `plateBreakdown(totalKg, hasCollar): Plate[]` + 一个展示组件，方便单测

### `<StatTile>` / `<SectionCard>` / `<GoldCTA>` / `<Badge>`
其余重复元素，按 token 实现即可，无特殊逻辑。
`<GoldCTA>` 需带按压态：`mousedown` 缩到 `.97` + 文字变暗 + 金色外发光增强；释放时向全屏扩散淡出。

---

## 4. 屏幕规格

底部 4 个 tab：**今日 / 训练 / 成长 / 我的**

### 4.1 今日
自上而下：
1. Header：`W1D4` + 金渐变进度条（**左橙右黄**，`linear-gradient(90deg,#E08F0F,#FFC93C)`），右上消息按钮（白底微阴影，不要浅灰底）
2. 周日历条（`DayChip` × 7）
3. 教练反馈卡 —— 收起时显示最新一条预览 + "展开全部 N 条反馈"
4. 体重 / 距比赛 双栏
5. E1RM 曲线卡（可切深蹲/卧推/硬拉）
6. 主 CTA「开始训练」+ 副标「蹲·推·拉」

### 4.2 训练（两态，这是核心）
**态 A — 今日清单**（进入时的第一眼）
- Hero 卡显示：`W1D4 力量提升`、共 N 个动作 / 约 X 分钟
- 下方**不显示任何具体组**，只有动作预览行
- 底部大按钮「开始第一组」，样式与「开始训练」完全一致

**态 B — 记录**（点「开始第一组」后）
- Hero 卡平滑过渡成当前动作记录界面（重量 ± 步进 + 可点输入、次数、RPE/RIR、杠铃配片、录像入口、「记录此组」）
- 过渡完成后，下方各动作卡**逐个错峰浮现**（延迟 360ms 起，步长 90ms）

**收纳**：一个动作的所有组都记录完后，该动作卡片**像护腕一样一圈圈向上卷起**，收成一行摘要（`3 组 · 175kg×3 @8.5`），可点击重新展开。

### 4.3 成长
容量柱状 + RPE 折线（折线 `1.2px`，圆点 `r=2.6`，底下有一层同形状的背景色描边做隔离）。可切时间范围。

### 4.4 我的
资料、1RM 登记、设置、退出。

### 4.5 结算页（完成全部动作后）
去卡片化，整屏即舞台：
- 底部向上发散的极淡金色光晕
- 🏅 奖牌徽章 + 「今日训练完成」
- 两个大金色数字：`W1D4` / 今日总容量（如 `21,000 KG`）
- 「连续第 N 次训练」
- 「教练李明已收到你的训练日志」+ 头像徽章
- 数字滚动（Ticker）+ 错峰滑入；最后淡入底部按钮

---

## 5. 状态与数据模型

样机的真实 state（可直接作为前端 store 的形状）：

```ts
interface StudentState {
  screen: 'today' | 'training' | 'growth' | 'me';
  overlay: null | 'done' | 'chat' | 'postpone' | 'rmInfo';
  exIdx: number;          // 当前动作
  currentIdx: number;     // 当前组
  exs: Exercise[];
  todayDone: boolean;
  postponed: boolean;
  selDay: number;         // 0-6
  readFb: Record<string, boolean>;
  // 录入暂存
  seW: number; seR: number; seRpe: number; seCollar: boolean;
}

interface Exercise {
  name: string;
  last: string;           // "上次 170kg×3 @8 · 最佳 175kg×3 @8.5"
  note: string;           // 教练备注
  sets: SetRecord[];
}

interface SetRecord {
  w: number; r: number; rpe: number;
  done: boolean;
  failed?: boolean;
}
```

**建议的 API 契约**（样机里是硬编码，需替换）

| 端点 | 作用 |
|---|---|
| `GET /plan/today` | 返回 `{code:'W1D4', title, estMinutes, exercises: Exercise[]}` |
| `POST /sets` | 提交一组 `{exerciseId, index, w, r, rpe, failed}` → 返回服务端 id |
| `POST /sets/:id/video` | 分片上传，返回 `uploading→uploaded/failed` |
| `POST /workouts/:id/complete` | 结算，返回 `{totalVolumeKg, streak, coachName}` |
| `GET /feedback` | 教练反馈列表 |
| `POST /plan/postpone` | 顺延今日计划 |

**离线优先**：`POST /sets` 必须本地先落库再同步 —— 健身房网络差。上传失败时相机图标转 `--danger`，行数据保留。

---

## 6. 关键交互动效时序

**以下每个动效都有可运行实现，见 `motion/` 01–05（双击打开）—— 抄代码优先于读文字，曲线与时长逐字取自样机源码。**

**「开始训练」→ 训练页（金幕扫过）**
1. `mousedown`：按钮缩到 `.97`，文字与副标变暗，金色边框发光增强（蓄力）
2. `mouseup`：按钮向全屏快速扩散放大并淡出，变成巨大金环消失在屏幕边缘；文字淡出并向上位移 8px
3. 一块金色能量幕从底部上掠盖住全屏，幕上闪出 `W1D4 · 蹲推拉`
4. 幕继续上掠，揭出已就位的训练页
总时长约 700ms。`prefers-reduced-motion` 下直接切换。

**教练反馈卡展开**
1. 预览文字 50ms 原地淡出
2. 容器 height 弹性延伸（overshoot 2–3px）
3. 4 条明细错峰滑入：延迟 20/50/80/110ms，`translateY(-8px)→0`，`opacity 0→1`
4. 箭头旋转 180°，文字切「收起」

**动作完成收纳** —— 卡片自上而下逐段卷起（transform-origin 顶部，分段 rotateX），最终收成一行摘要。

---

## 7. 缺失态（样机没画，必须实装）

| 场景 | 处理 |
|---|---|
| 今日无计划 | Hero 卡显示「今天是休息日」+ 本周下一次训练时间 |
| 计划加载中 | 骨架屏，用 `--text-ghost` 色块，不要 spinner |
| 提交组失败 | 行保留 + 红色重试角标，顶部 toast「已离线保存，联网后自动同步」 |
| 视频上传失败 | 相机图标转 `--danger`，点击重试 |
| 无教练反馈 | 卡片收起为一行「暂无新反馈」，不占位 |
| 无历史数据 | E1RM 曲线区显示「完成 3 次训练后解锁趋势」 |

---

## 8. 无障碍

- 所有可点元素用 `<button>` / `<a>`，不要 div + onClick
- 状态点（绿/红/金）必须**同时有文字或形状**，不能只靠颜色区分
- 大数字加 `aria-label`（`175 千克`），Mono 字体不影响朗读
- 亮色主题下所有文字对比度 ≥ 4.5:1；已按此调过金色（`#D97706` 而非 `#F5A623`）
- 主 CTA 需支持键盘 Enter/Space 触发，且蓄力动效不能阻塞提交

---

## 9. 实装检查清单

- [ ] token 块整体拷入，组件里**零硬编码颜色**
- [ ] 7 个组件都已建成真组件，屏幕由它们拼装而不是重复 div
- [ ] `.theme-light` 切换后全屏检查，无白底白字、无深底深字
- [ ] 圆角只出现 4 / 10 / 12 / 16 / 20 / 999
- [ ] 无 12.5px / 13.5px 这类半像素字号
- [ ] 所有数字用 Mono，增减时不跳动
- [ ] 重量/次数可点弹键盘，且是真 input
- [ ] 休息日不显示"未完成"
- [ ] 失败组显示叉不显示勾
- [ ] 触摸目标 ≥ 44px
- [ ] `prefers-reduced-motion` 全覆盖
- [ ] 断网下可完整记录一次训练
