# Spec 088 · iOS 卡（第一步）：Profile 改版

开工先读仓内 `CONTEXT.md`、`AGENTS.md`、`specs/085-090-android-parity/README.md`（共同约定，全部适用）、本目录 `SPEC.md` 的「现状」「已拍板口径」§1–§3、「测试 seam」第一步、「验收清单」第一步、「屏幕稿」板 1–4。

- 级别／节奏：T2 / P1。分支 `feat/088-profile-redesign`，**叠在 `feat/087-progress-menu` 上**（其下是 085），工作树 `../MeetPR-wt-085`。
- **不 commit、不 push**；交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。
- **只做第一步**（零后端）。`SPEC.md` §4 头像上传、§5 教练端头像、测试 seam 5–7、验收 13–24、屏幕稿板 5 **不做**；头像位不可点、没有相机角标、没有任何上传暗示。

## 目标

学员端 Profile 首屏改成「身份摘要卡 + 五行列表」，原有内容收进三个二级页，行为与安卓一致：

1. 首屏：页头 + `My profile` + 身份摘要卡（头像位首字母、名字位、`Coach · 教练名`、训练 1RM 四格、锁定说明行）+ 五行（`About me` / `Health & recovery` / `Meet` / `Note to coach` / `Settings`）。
2. 三个二级页：`About me` 四行、`Health & recovery` 两行、`Settings`（偏好三行 + 账号三行 + `Sign out`）。点行打开**现有的**编辑页 / 设置页 / 弹层，这些页面除 §3 那一行灰字外一处不改。
3. 伤病编辑页与状态打卡弹层的保存按钮上方加一行灰字「改动会通知你的教练」；首屏与二级页不再出现 `Notify coach` 胶囊与副文。

## iOS 落点（以现场为准）

- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/`：`MyProfileView.swift`（含 `MyProfileOneRMCard`、各 section、`MyProfileFallbackRows`）、`MyProfileV3Presentation.swift`、`MyProfileViewModel.swift`、`ProfileCardsSection.swift`、`OnboardingSummaryFormatter.swift`、`AppearancePreferenceRow.swift`、`RestTimerPreferenceRow.swift`、`TrainingReminderPreferenceRow.swift`、`AccountSecuritySheets.swift`、`ExportDataSheet.swift`。
- 状态打卡弹层：`Features/Readiness/`；伤病编辑页在 `ProfileCardsSection` 一带。
- 五行复用 087 做的通用列表行组件，不另写一份。
- 外观三块复用 085 做的通用可选块样式。

## iOS 上要注意的地方

- **名字位**：第一步显示登录邮箱；没有邮箱显示手机号（CN 轨是手机号登录，绝大多数学员走这一支：名字位是手机号、头像位是人像图标）。取现有登录态里的标识，不新增接口。
- 教练行：取已通过的绑定记录里的教练名；没有已通过的绑定或教练名为空时这一行不出现，名字位垂直居中。
- 四格数值与取整沿用现有 1RM 卡的取法（现有 `MyProfileOneRMCard` 的数据来源），格内不写单位；点四格或锁定说明行弹出现有的 1RM 说明，文案不改。
- 二级页用 `NavigationStack` 推入，盖住 Tab 栏的做法与 iOS 现有整页编辑页一致；从 Today 带参直达编辑页的入口（体重卡、Meet 卡等，084 与 085 接的那些）行为逐一不变：直接打开对应编辑页，关闭后回来处，不经过二级页。
- `Sign out`：描边按钮，点击行为同现有（现状有没有二次确认就保持什么样，不新增不删除）。`Delete account` 名称用红色，流程不改。
- **Settings 行在任何状态下都可用**：加载中、加载失败、还没有档案三种状态下都能进 Settings 并退出登录。
- 加载失败时：手里没有档案数据则四格与右侧值留空；已显示过数据、只是刷新失败则保留已显示的值；两种情况列表下方都有现有的失败重试入口。
- 教练自己的 Profile 页（`CoachKit`）不动。
- 改前的 Profile 共有哪些行、各自的值，动手前先逐行记进 JOURNAL，验收第 10 项要逐项对照「没有任何一项信息在新结构里找不到入口」。

## 测试 seam（先红后绿，只在这些边界）

1. `MyProfileV3Presentation` 的现有测试旁：首屏派生纯函数——首字母规则（两个词 / 单个词 / 中文 / 邮箱 / 手机号 / 空）；名字位回落顺序（名字 → 邮箱 → 手机号；第一步名字恒为空）；五行右侧值各自的有值 / 无值；教练行在无绑定、绑定未通过、教练名为空三种情况下不出现。
2. Profile 首屏的 presentation 或 view model 测试（沿用现有方式）：身份卡 + 五行、顺序与名称；各行去向（两行进二级页、两行直接开编辑页、一行进 Settings）；加载中、加载失败、无档案三种状态下 `Settings` 行都在且可用；带编辑参数进入时直接打开编辑页并回来处。
3. 三个二级页各一组：行的顺序与值；Settings 的外观选中态、`Sign out` 调现有退出。
4. 现有编辑页、组间休息、训练提醒、账号安全的测试不改断言而保持通过。

## 验收

`SPEC.md`「验收清单」第一步第 1–11 项逐项成立，替换如下：

- 第 1 项「1080×2400 的模拟器上不用滚动就能看到全部五行」换成：iPhone 17 Pro 模拟器默认字号下不用滚动能看到全部五行。
- 第 2 项补一例 CN 轨手机号登录形态：名字位是手机号、头像位是人像图标。
- 第 11 项的屏幕与字号按共同约定换成 iPhone SE + `accessibility-large`，中文界面同查。
- 第 12 项换成：`swift test --package-path Modules/StudentKit` 及其他动到的包全量通过；`swift-format` 与 `swiftlint` 严格模式 0 违规；`MeetPR-DemoStudent` 能在模拟器构建运行。

## 文件范围

`Modules/StudentKit`（MyProfile、Readiness 的那一行灰字、Shared、Resources、对应 Tests）；确有需要时 `Modules/DesignSystem`。不动任何编辑页的字段、校验与保存行为，不动外观默认值、Tab 名称与顺序、`CoachKit`、`Networking`。
