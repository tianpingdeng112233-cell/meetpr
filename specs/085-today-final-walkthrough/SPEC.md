> **iOS 落地说明（2026-10-10）**
>
> - 本文是安卓正典的逐字副本，取自 `meetpr-rn` `feat/demo-offline@137d816`；David 2026-10-10 定「以安卓为标准，把 iOS 推进到同一进度」，走原生 SwiftUI。
> - 文中「只做安卓」「iOS 原生不跟」「iOS 等走查完一起跟」「登记进 `PARITY.md`」等句子在 iOS 上不再适用；文中的 `src/...` 路径、`npx jest` 等命令是安卓的，iOS 的落点、测试 seam 与验收替换见同目录 [`CARD-ios.md`](./CARD-ios.md)，共同约定见 [`../085-090-android-parity/README.md`](../085-090-android-parity/README.md)。
> - iOS 本波范围：全部（§1–§4）。
> - 屏幕稿沿用文末 David 已「定稿」的那一套（稿只管布局、层级、间距与文案）；颜色、字号、圆角取 iOS `DesignSystem` 现有 token。
> - Status: Done（iOS 实装见同目录 `ACCEPTANCE-ios.md`）。

---

# Spec 085 · Today 定稿前走查四项（安卓）

- 来源：David 2026-10-09 模拟器走查 Today 页，当场提三条；同日 grill 两轮，第一轮答复「1A 2B 3A 4A」，看稿后第二轮答复「1B 2A」并给出 CPA 女子级别表；随后把 1a/1b 改为概览卡、追加营养占位（§4）、训练日命名维持现状，并对全部屏幕稿说「定稿」。
- 级别／节奏：T2 / P1。只做安卓（`meetpr-rn`），基线 `main@aeb1020`，分支 `feat/085-today-final-walkthrough`。iOS 原生不跟。
- 性质：David 批准的新口径，不属于"1:1 复刻 build 22"，不受身份卡"v1 严禁夹带新功能"约束；除本文四项外不得顺手改别的。
- 后端：**零改动**。不加字段、不迁移、不部署。
- 屏幕稿：David 2026-10-09 已「定稿」，结构与文案转写在文末「屏幕稿」。

## 已拍板口径

| 题 | 结论 |
|---|---|
| 1 D1/D2 点了看什么 | 留在 Today：选中框跟随点选，下方一张**概览卡**只给个大概（名称、动作数与组数、动作名一行）；细节去训练页看，点概览卡即进训练页的那一天。开练按钮仍只管当前训练日（10/09 看稿后 David 改：初稿逐动作列组数重量太细，Today 只让用户对训练有个概念） |
| 2 体重显示 | 一律两位小数（`83.00`） |
| 3 赛事方存哪 | 不动后端，按固定格式写进现有 `target_weight_class` 文本字段 |
| 4 去掉"是否备赛"后 | 选了日期即视为备赛；页内 Remove meet 清空；给教练的留言移回 Profile 单独一行；新用户引导第 7 步同步改 |
| 5 赛事方与级别是否必填（第二轮） | 必填：日期、赛事方、级别三项齐了才能保存 |
| 6 点选其他训练日时的页头（第二轮） | 页头大标题不变，始终是当前训练日 |
| 7 CPA 女子级别（第二轮） | David 提供：44 / 48 / 52 / 56 / 60 / 67.5 / 75 / 82.5 / 90 / 100 / 100+ |
| 8 营养占位 | 做。产品口径由"不做营养"改为"待开放方向"（Brain PRD 已同步，`5877433`）；位置在 Today 的体重 / Meetday 行下面 |
| 9 同一天多个主项时训练日怎么叫 | 维持现状不改：一项 `Squat day`，两项 `Squat / Bench press day`，三项窄位 `SBD day`、其余 `Squat·Bench·Deadlift`，无主项 `Training day` |

## §1 Today 周条：选中训练日并查看安排

现状：周条小卡已可点，点后下方的训练日名称与"N exercises · M sets"会换，但高亮框只标"今天该练的那天"，不随点选移动，也不列动作，看起来像点不动。

改为：

- **两种标记分开**（沿用 spec 084 §4 训练页周条定稿的手法）：
  - 选中的日子：深色 2pt 粗框、白底，跟随点选。
  - 当前训练日（今天该练的）：整格淡金底、金色实心圆点、序号加粗；不再用金色描边。
  - 两者可同时出现（淡金底 + 深色粗框）。进入 Today 时默认选中当前训练日。
  - 已完成的日子：绿色对勾，样式不变；可被选中。
- **所选日概览卡**：周条下方一张可点的卡，只给概览，不列组数与重量：
  1. 第一行：训练日名称（现有 `dayName`）＋状态小标：当前训练日显示 `Today's session`，已完成显示 `Completed`，其余显示 `Upcoming`。
  2. 第二行灰色等宽字：`N exercises · M sets`（现有文案）。教练推荐日期不在卡内重复（周条格子里已有）。
  3. 第三行：按计划顺序把动作名用 ` · ` 连成一行，如 `Squat · Pause squat · Leg press`；放不下以 `…` 截断，只占一行。
  4. 右侧一个 `›`。
- 点概览卡 → 切到训练页并选中那一天（复用训练页已有的"指定训练日"入口；非当前训练日在训练页是 084 §4 定稿的只读预览）。Today 本页不展开任何明细。页面底部的 `Start training` 按钮行为与文案不变，始终指向当前训练日。
- 页头大标题 `W3D1` 不随选中变化，始终是当前训练日。
- 下方"This session · e1RM chart"沿用现状（已随所选日的主项切换），只把小标题在所选日不是当前训练日时改为 `Selected day · e1RM chart`。
- 今天已完成当日训练时（现状此处不显示所选日摘要）：概览卡照常显示，默认选中刚完成的那天。
- 离开 Today 再回来，选中重置为当前训练日。

## §2 体重：单项编辑页，两位小数

- Today 体重卡（有值、空态都一样）点击后进入**只含一个体重输入框**的编辑页，标题 `Body weight`。页面内容：一个数字输入框＋单位（跟随单位偏好，`kg` 或 `lb`）、一行灰字说明 `Up to two decimal places`、`Save` 按钮、左上 `Cancel`。保存或取消后回到 Today，卡片即时更新。
- 输入规则：只收数字与一个小数点；小数点后最多两位，第三位不接收；`0`、空、≥ 500 kg（后端上限）不可保存，输入框标红。
- 存储：公制原样存两位；英制把输入的 lb 换算成 kg 后四舍五入到两位再存（现状是一位，改两位）。
- 显示（学员端所有展示体重的位置，现为 Today 卡与 Profile 的 Basic information 行）：固定两位小数，如 `83.00 kg`、`83.50 kg`。Today 卡的数字仍以 kg 显示（现状，不动）。
- Profile → Basic information 页保留体重输入框（那页仍是全量基础信息），输入规则与换算精度同上。
- 引导第 1 步的体重输入同一规则（同一个组件）。
- 教练端显示学员体重的位置不在范围内。

## §3 Meetday：直接选日期、赛事方、级别

### 页面

Today 的 Meetday 卡（有值、空态）点击后进入标题为 `Meet` 的编辑页，自上而下：

1. `Meet date`：现有的日期滚轮，范围不变（今天起至十年后）。
2. `Federation`：四个等宽单选块 `CPA` `IPF` `IPL` `WP`，**必选**。
3. `Weight class`：选了赛事方后才出现，是该赛事方级别表的单选块网格（每行 4 个，带 `kg`，如 `83 kg`、`120+ kg`）。换赛事方时清掉已选级别。**必选**。
   - 级别表按档案性别取：`male` 用男子表，`female` 用女子表。性别为 `other` 或未填时，级别网格上方多一个 `Men` / `Women` 两段切换，只决定显示哪张表，不写回档案。
4. `Save` 按钮：始终可点。赛事方或级别缺任一项时不保存，缺的那一段标题标红，按钮上方出现现有的校验失败提示（沿用 Profile 编辑页已有的那条文案与样式）。
5. 已有比赛时，按钮下方一个红色文字入口 `Remove meet`；点后弹确认框（`Remove this meet?` / `Remove` / `Cancel`），确认即清空并回到 Today。

不再出现"Are you preparing for a meet?"的是/否题，也不再有给教练的留言框。

### 写入口径（零后端改动）

- 保存：`is_competing = true`，`competition_date = 所选日期`，`target_weight_class` 按下表。
- Remove meet：`is_competing = false`，`competition_date = null`，`target_weight_class = null`。
- `target_weight_class` 的固定格式：

  赛事方代码、空格、间隔号 `·`、空格、级别数字、空格、`kg`，例：`IPF · 83 kg`、`WP · 120+ kg`、`IPL · 67.5 kg`。

  解析同一格式读回页面；赛事方代码只认 `CPA` `IPF` `IPL` `WP`，级别必须在该赛事方两张表之一里，否则视为"旧的手填值"。

### 级别表（公开组，kg）

| 赛事方 | 男子 | 女子 |
|---|---|---|
| IPF | 59 / 66 / 74 / 83 / 93 / 105 / 120 / 120+ | 47 / 52 / 57 / 63 / 69 / 76 / 84 / 84+ |
| WP | 62 / 69 / 77 / 85 / 94 / 105 / 120 / 120+ | 48 / 53 / 58 / 64 / 72 / 84 / 100 / 100+ |
| IPL | 52 / 56 / 60 / 67.5 / 75 / 82.5 / 90 / 100 / 110 / 125 / 140 / 140+ | 44 / 48 / 52 / 56 / 60 / 67.5 / 75 / 82.5 / 90 / 100 / 110 / 110+ |
| CPA | 52 / 56 / 60 / 67.5 / 75 / 82.5 / 90 / 100 / 110 / 125 / 140 / 140+ | 44 / 48 / 52 / 56 / 60 / 67.5 / 75 / 82.5 / 90 / 100 / 100+ |

来源：IPF 2026 Technical Rulebook p.5（男子 2011 版、女子 2021 版）；WP、IPL 取 OpenPowerlifting `opl-data` 各联盟 `CONFIG.toml` 现行段（WP 自 2018-08-01；IPL 女子自 2022-01-01）；CPA 男子取其赛事公告与 `chinapa/CONFIG.toml`；CPA 女子由 David 2026-10-09 提供（公开可查的赛事公告是 2019–2021 口径，只到 90 / 90+，已过时）。只做公开组级别，青年专属级别（如 IPF 的 53 / 43）不收。

### 入口与展示的连带改动

- Today 的 Meetday 卡：有值态在倒数天数下加一行灰字，显示 `target_weight_class` 的内容（如 `IPF · 83 kg`），没有就不显示这一行。空态不变（`Not scheduled` / `+ Add a meet`）。
- Profile 页原来的 `Meet / notes` 一行拆成两行：
  - `Meet`：值为 `日期 · 赛事方与级别`（没有比赛显示现有的"未填"占位），进本节的编辑页。
  - `Note to coach`：值为留言首行（没有显示占位），进一个只有多行输入框的编辑页，写 `note_to_coach`，输入规则与原来一致。
- 新用户引导第 7 步：去掉是/否题。改为一块可展开区域，收起时是一行 `+ Add a meet (optional)`；展开后出现与编辑页相同的日期、赛事方、级别三段（展开后三项同样必填，缺项时这一步不能继续），以及右上角 `Remove`（收起并清空）。给教练的留言框留在这一步的末尾（引导里只有这一处能写）。提交时：展开 → `is_competing = true`；未展开 → `is_competing = false`、日期与级别为空。第 7 步不再因"没回答是否备赛"拦截。
- 教练端不改：它原样显示 `target_weight_class`，现在会看到 `IPF · 83 kg`。

## §4 营养占位卡（暂未开放）

- 位置：Today 页，紧跟体重 / Meetday 那一行之后、"This session · e1RM chart"小标题之前。显示条件与体重 / Meetday 行相同（那一行出现它就出现，骨架屏阶段不出现）。
- 内容：一张与体重卡同款的白色卡片。
  - 标题行：左侧 `Nutrition`（样式同 `Body weight` 那个小标题），右侧灰色小标 `Coming soon`。
  - 下面一行四个等宽小格，从左到右 `Carbs` `Protein` `Fat` `Fiber`；每格上面是名称，下面是 `—` 加单位 `g`，整体用次要文字色。
  - 中文目录对应：`营养`、`暂未开放`、`碳水`、`蛋白质`、`脂肪`、`膳食纤维`。
- 纯展示：不可点、无按压反馈、不跳转、不请求任何接口、不存任何东西、不发埋点。无障碍上整张卡读作一句（`Nutrition, coming soon`）。
- 卡上不写任何关于将来怎么用的说明文字（形态未定，不提前承诺）。
- 教练端不出现。

## 存量数据与升级（带历史的老用户第一屏）

- 不迁移、不回填，老数据原样可读。
- 老用户手填过级别（如 `83kg`、`-93`）：Today 卡与 Profile 行原样显示这段文字。进编辑页时赛事方、级别都是未选状态，页面在 `Federation` 标题下多一行灰字 `Previously entered: 83kg`。只要不保存（取消返回），原文字不动；要保存就必须选齐赛事方与级别，保存后覆盖为新格式。
- 老用户 `is_competing = true` 且有日期：编辑页直接带出日期；Today 倒数不变。
- 老用户 `is_competing = false` 或从未回答（`null`）：Today 显示 `Not scheduled`；进编辑页日期默认今天，保存即新增比赛。只是打开再取消不写任何东西。
- 老用户 `is_competing = true` 但没有日期（旧数据可能出现）：按"没有比赛"展示；保存后补齐。
- 老用户体重存的是一位或整数（`83`、`83.5`）：显示补零成 `83.00`、`83.50`，不改存储；只有用户自己保存时才重写。
- 给教练的留言：原值原样出现在 Profile 新的 `Note to coach` 行，不丢。
- 引导中途退出、本地存了草稿的新用户（草稿里 `isCompeting` 可能是 `null` / `true` / `false`）：`true` → 第 7 步展开并带出日期；其余 → 收起。草稿存储结构不变。

## Out of Scope

- 后端任何改动；按赛事方筛选或统计；教练端与网页端的展示改动。
- iOS 原生端。
- Today 页头、Coach feedback 卡、e1RM 卡、底部按钮、Tab 栏。
- 训练页本身（084 已定稿，不动；本 spec 只从 Today 把所选日交给它）。
- 体重历史／趋势曲线、称重提醒。
- 营养的任何实际功能（目标、记录、餐食、后端字段）；本 spec 只放一张占位卡。
- 训练日命名规则（拍板维持现状）。
- 多场比赛、比赛名称、地点、试举计划。
- 青年／大师等年龄组专属级别；带装组别。
- CN 轨文案之外的本地化调整（新增文案中英文目录都要补齐，过 i18n 守卫）。

## 测试 seam（先红后绿，只在这些边界，越少越好）

1. **纯函数 `src/domain/meet/weight-class.ts`（新建）**：`formatMeetClass` / `parseMeetClass` 往返（含 `120+`、`67.5`；旧手填值、只有赛事方代码、级别不在该赛事方表内都判为不识别）；`weightClassesFor(federation, sex)` 四家 × 两性别的表与本文一致。
2. **`src/features/onboarding/model.ts` 的 patch 与校验**：保存 → `is_competing=true` + 日期 + 格式化级别；缺赛事方或级别时校验不通过；移除 → 三个字段清空；第 7 步不展开时不报错且 `is_competing=false`，展开后缺项报错；体重两位小数的输入过滤与英制换算精度（含读回值再保存 kg 不变）。
3. **`src/features/profile/__tests__/editor.test.tsx`（已有挂载方式）**：`weight`、`competition`、`note` 三个编辑页各自只发出自己那几个字段。
4. **`src/features/dashboard/__tests__/week-calendar.test.tsx` 与 `visual-parity.test.tsx`（已有）**：点选后 `selected` 状态跟随、当前训练日标记不随点选移动；概览卡对所选日显示名称、状态小标、动作数与组数、按计划顺序的动作名一行；点卡把所选日交给训练页；体重卡显示两位小数；两张卡的路由参数指向新的单项页；营养占位卡存在且不可点。

样式（颜色、间距）不写断言，由模拟器实屏验收。

## 验收清单（Opus 收货，逐项核；实装方不得自定验收范围）

- [ ] 1a 进入 Today 默认选中当前训练日（淡金底 + 深色粗框）；点 D2 → 粗框移到 D2，D1 仍是淡金底；再点 D1 复原。
- [ ] 1b 概览卡显示所选日的名称、状态小标、动作数与组数、一行动作名（过长截断、不换行）；卡内只有全天合计的那一处组数，没有逐个动作的组数、次数、重量。点卡进入训练页且选中的是同一天；从训练页回 Today，选中回到当前训练日。
- [ ] 1c 选中非当前训练日时，页头 `W#D#` 与底部 `Start training` 都不变；点 `Start training` 进入的仍是当前训练日。
- [ ] 1d 已完成的日子可选中并显示 `Completed`；当天已完成训练后概览卡仍在。
- [ ] 2a 体重卡（有值、空态）进入的页面只有一个体重输入框；`83.256` 输不进第三位；保存 `83.25` 后 Today 显示 `83.25 kg`；保存 `83` 显示 `83.00 kg`。
- [ ] 2b 单位偏好为 lb 时输入 `183.25`，存入的 kg 值为两位小数（`83.12`）；再次打开显示 `183.25`。说明：0.01 kg 约等于 0.022 lb，个别 lb 输入换算后再读回会差 0.01 lb（如 `183.26` 读回 `183.27`），这是两位 kg 精度的固有结果；要求是读回值不再变——原样再保存一次，kg 值不变。
- [ ] 2c Profile 的 Basic information 页体重输入同规则；该行显示两位小数。
- [ ] 3a Meetday 卡进入的页面没有是/否题、没有留言框；选日期 + `IPF` + `83 kg` 保存后，Today 显示倒数天数与 `IPF · 83 kg`；教练端学员详情显示同一段文字。
- [ ] 3b 四个赛事方 × 男女的级别表与本文逐项一致；性别为 `other` 的账号能切 `Men` / `Women`。
- [ ] 3c 换赛事方清掉已选级别；缺赛事方或缺级别时点 Save 不保存、缺的那段标红并出现提示；三项齐了才写入。
- [ ] 3d `Remove meet` 有确认框；确认后 Today 回到 `Not scheduled`，教练端不再显示级别。
- [ ] 3e Profile 出现 `Meet` 与 `Note to coach` 两行，各进各的编辑页；原有留言原样可见可改。
- [ ] 3f 新用户引导第 7 步：不展开直接下一步可完成引导（`is_competing=false`）；展开填写后完成，Today 显示比赛。
- [ ] 3g 营养占位卡在体重 / Meetday 行下面，四格名称与 `Coming soon` 正确，点按无任何反应；中文界面显示对应中文。
- [ ] 4 **老用户升级第一屏**（用升级前造好的三个账号，不重新注册）：① 手填级别 `83kg` + 有日期 → Today 倒数与 `83kg` 都在，进编辑页有 `Previously entered: 83kg`，取消返回后仍是 `83kg`，选齐保存后变为新格式；② 从未回答是否备赛 → `Not scheduled`，可新增；③ 体重存的是 `83.5` → 显示 `83.50 kg`。三者的留言都还在。
- [ ] 5 Light / Dark 两套主题；360×640 dp + 系统字体 1.3× 下级别网格不溢出、不截字。
- [ ] 6 `npx jest --runInBand` 全量、`npx tsc --noEmit`、`npm run lint` 通过；`PARITY.md` 登记这四处与 iOS 的授权差异（Opus 写）。

## 拆卡

两张，同一分支同一个 PR：

- 卡 A `CARD-A-data.md`（T1）：级别表与格式、比赛写入口径、体重两位小数的纯函数与测试，不接界面。不依赖屏幕稿，spec 定下即派。**2026-10-09 已收货**：Opus 读全量 diff（三个新源文件 + 三个测试），级别表逐格对过正文；本地 `156 suites / 1295 tests`、`tsc` 0 错、lint 0 警告。一处口径以正文为准：公制体重也固定存两位（`83` 存成 `83.00`），卡内"原样"的写法作废。留给卡 B 的注意点：`formatBodyWeightKg` 对空值会给出 `NaN`，调用处要先判空。
- 卡 B `CARD-B-ui.md`（T2）：四处界面接线与文案，以下面转写的屏幕稿为参照。2026-10-09 定稿后派出。**同日收货**（两轮返修后）：逐项结论、未覆盖项与截图见 `docs/verification-spec085-2026-10-09.md`。

## 屏幕稿（David 2026-10-09「定稿」）

画布 https://claude.ai/artifact/67Rjtcd9x5iUzkxTdsVfVa （9 张）。稿只管布局／层级／间距；颜色、字号、圆角一律用 `src/design` 现有 token 与现有组件，不照抄稿里的色值。以下是各张的结构与文案转写，实装以此为准。

**1a Today · 默认选中当前训练日**（自上而下，除标注外都是现状）
页头 `W3D1` + 消息按钮 → 本周进度条 → Coach feedback 卡 → `Weekly progress 0 / 2` 与 `Coach-recommended date` → 周条两格：D1 = 淡金底 + 深色 2pt 粗框 + 金色实心圆点 + `D1` 加粗 + `Mon, 9/21`；D2 = 浅灰底、无框、空心圆点、灰字 → **概览卡**（新）：左侧三行——`Squat day` 后跟淡金底小标 `Today's session`；灰色等宽字 `3 exercises · 9 sets`；`Squat · Pause squat · Leg press` 单行截断——右侧 `›` → 体重卡 `83.00 kg` 与 Meetday 卡（`23 days`，下面一行灰字 `IPF · 83 kg`）→ `This session · e1RM chart` → e1RM 卡 → 底部 `Start training / Squat day` 按钮 → Tab 栏。

**1b Today · 点选 D2**
与 1a 相同，区别：D1 仍是淡金底但没有框；D2 变白底 + 深色 2pt 粗框、字变深色；概览卡变为 `Bench day` + 灰底小标 `Upcoming`、`4 exercises · 14 sets`、`Bench press · Close-grip bench · Barbell row · Triceps pushdown`（截断）；小标题变为 `Selected day · e1RM chart`，下面是卧推的 e1RM 卡；页头仍是 `W3D1`，底部按钮仍是 `Start training / Squat day`。

**2 体重单项编辑页**
左上 `Cancel ›`（现有编辑页的写法）→ 标题 `Body weight` → 字段标题 `Weight` → 一行：数字输入框（示例值 `83.25`，聚焦态深色描边）+ 右侧单位 `kg` → 灰字 `Up to two decimal places` → 整宽深色按钮 `Save`。页面没有别的字段。

**3a Meet 编辑页 · 已选 IPF 83**
`Cancel ›` → 标题 `Meet` → `Meet date` + 现有日期滚轮 → `Federation` + 一行四个等宽块 `CPA` `IPF` `IPL` `WP`（选中项深色底白字，未选白底描边）→ `Weight class` + 每行 4 个的网格 `59 kg` `66 kg` `74 kg` `83 kg` `93 kg` `105 kg` `120 kg` `120+ kg`（选中项同样深色底白字）→ `Save` → 居中的红色文字按钮 `Remove meet`。

**3b 老用户 · 手填过级别**
同 3a，区别：`Federation` 标题下多一行灰字 `Previously entered: 83kg`（值用等宽字、深色）；四个赛事方都未选；没有 `Weight class` 区；`Save` 与 `Remove meet` 仍在。

**3c IPL · 性别未填时可切表**
同 3a，区别：选中 `IPL`；`Weight class` 标题行右侧多一个两段切换 `Men`（选中）/ `Women`；网格 12 格分三行，`52 kg` … `140 kg` `140+ kg`，选中 `82.5 kg`。

**3e Profile · 两行**
同一张分组卡里相邻三行，各带右侧 `›`：`Basic information`（值 `178 cm · 83.00 kg`）、`Meet`（值 `2026-11-01 · IPF · 83 kg`，日期格式沿用该行现状）、`Note to coach`（值为留言首行，单行截断）。行的位置：`Meet` 在原 `Meet / notes` 的位置，`Note to coach` 紧随其后。

**3f 引导第 7 步 · 比赛区块（收起）**
小标题 `Meet` → 一个整宽虚线描边按钮 `+ Add a meet (optional)`（金棕色字）→ 一行灰字 `Opens meet date, federation and weight class. Skip it if you are not competing.` → `Anything to tell your coach? (optional)` + 多行输入框（占位文字沿用现状）。展开态 = 把虚线按钮和那行灰字换成 3a 的日期、赛事方、级别三段，`Meet` 小标题右侧出现文字按钮 `Remove`。

**4 Today · 营养占位**
体重 / Meetday 行之下一张白卡：标题行左 `Nutrition`、右灰底小标 `Coming soon`；下面四个等宽浅灰小格 `Carbs` `Protein` `Fat` `Fiber`，每格名称在上、`— g` 在下。其下接 `This session · e1RM chart`。
