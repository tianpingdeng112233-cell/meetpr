# 041 — 教练落地页厚化 + 统一品牌 hero(UI 一致性 pass)

- **状态**:Ready
- **PR**:TBD(iOS 1 PR,分支 `feat/coach-ui-consistency`,已含 tab tint 修复)
- **来源**:David 2026-06-16 dogfood:"学员端和教练端 UI 设计不一致,而且整体缺乏专业感"。诊断:① tab tint 蓝(已修:CoachRootView 加 `.tint(brandRed)`)② 教练落地页比学员仪表盘朴素 ③ 品牌色覆盖低。方向经 mockup 确认:**照 mockup 厚化,hero 用品牌红,两 tab 同语言**。
- **纯 CoachKit/StudentKit/DesignSystem UI,无后端,不改导航结构。**

## 目标
把教练「排计划」首页 + 「学员」tab 厚化到学员仪表盘的精致度,统一品牌红。复用现有 DesignSystem 组件(`Card`/`ElevatedCard`/`StatBlock`/`StatusBadge`/`Eyebrow`/`MeetPRListRow`),并抽一个**共享品牌红 hero 按钮**让两端 hero 真正用同一个组件。**优先复用,别重造。**

## 冻结决策
- hero CTA = **品牌红**(`BrandPrimaryButton`),教练「排新计划」+ 学员「继续训练/开始训练」共用。
- 037(人物分诊)仍只在「学员」tab、038(计划:草稿/需排/最近发布)仍只在「排计划」tab——**内容职责不变,只升级视觉**,不重复分诊。
- mockup 里的「今日概览统计行」是示意:学员侧不动;教练「排计划」首页**可选**加一条**计划相关**统计(草稿 N / 在跑 N / 本周到期 N),仅当数据现成且不啰嗦才加,拿不准就略。

## 范围
### DesignSystem
- **新增 `BrandPrimaryButton`**(`Components/Buttons/`):品牌红底(`Color.MeetPR.brandRed`)、白字(`Color.MeetPR.bg` 上的白 = `.white`/`fgPrimary` 视 token)、full-width 选项、按压态(opacity / `brandRedPress`)、`.sensoryFeedback` 轻震,API 仿现有 `PrimaryButton`(title/isDisabled/isLoading/isFullWidth/action)。这是把学员 `DashboardView.swift:205-210` 的内联红按钮抽成组件。
- **首字母头像**:若 DesignSystem/CoachKit 无现成圆形首字母头像组件,加一个小的 `InitialAvatar`(圆 + 1-2 字 + `surface2/3` 底);有现成就复用。
- 复用 `StatusBadge`(状态药丸)、`StatBlock`(统计)、`Card`/`ElevatedCard`、`Eyebrow`。不新造这些。

### StudentKit(统一 hero,行为不变)
- `Features/Dashboard/DashboardView.swift` 的「继续训练/开始训练」内联红按钮 → 换成 `BrandPrimaryButton`(同文案逻辑 `progress.completed == 0 ? "开始训练" : "继续训练"`、同 action)。纯组件替换,布局/行为不变。

### CoachKit — 排计划首页(`Features/PlanningWorkspace/`)
- `CoachPlanningHomeView` / `PlanningWorkspaceSections`:
  - hero「排新计划」:白 `PrimaryButton` → **`BrandPrimaryButton`**(full-width)。
  - **进行中草稿 / 谁需要排计划 / 最近发布** 三段:每行从平灰块 → `Card` + 首字母头像 + 学员名 + `StatusBadge` 状态药丸(如「计划本周结束」琥珀 / 「暂无在跑计划」中性 / 「编到一半」)+ 右侧红动作按钮(排/继续/查看,小号 `BrandPrimaryButton` 或品牌红文字按钮)。
  - 段标题用 `Eyebrow`;空段不显示(现状保留)。
  - (可选)顶部计划统计行用 `StatBlock`(见冻结决策,数据现成才加)。
- 不改 `PlanningWorkspaceViewModel` 的数据口径,只换视图层呈现(必要的展示字段如状态文案可在 VM/视图算)。

### CoachKit — 学员 tab(`Features/StudentRoster/` + 037 分诊条)
- 分诊条「今天 N 个需要你」:`ElevatedCard` 容器 + 每行彩点(没练 `brandRed` / 待回复 `amber`)+ 学员名 + 一句话原因 + chevron(`Card`/row 风格同 mockup)。N=0 隐藏(现状)。
- 花名册行 `StudentRosterRow`:`Card` + 首字母头像 + 名 + `StatusBadge`(本周完成 x/y、评估期等)+ chevron。视觉跟 mockup 统一。
- 导航/点击行为不变(点进 `StudentDetailView`)。

## 技术要求
- **CoachKit ⊥ StudentKit**:共享只经 DesignSystem(`BrandPrimaryButton`/`InitialAvatar`/现有组件)。两 Kit 不互引。
- 复用 > 新造:除 `BrandPrimaryButton`(+ 可能 `InitialAvatar`),不新增组件。
- SwiftLint strict(文件≤400→超了拆子视图/新文件;函数体≤50;参数≤5;无多尾随闭包;sorted_imports;无 `private extension`)、`xcrun swift-format --strict` 干净。
- 不动 037/038 的数据/职责、不动导航结构、不动 staging/后端。

## 验收
- [ ] 教练「排计划」首页:品牌红 hero + 三段富卡(头像/状态药丸/红动作)
- [ ] 教练「学员」tab:分诊条富卡 + 花名册富行,与排计划首页同语言
- [ ] `BrandPrimaryButton` 进 DesignSystem,教练 hero + 学员 hero 共用同一组件
- [ ] tab tint 品牌红(已);两端整体读着"一套 app、专业"
- [ ] DesignSystem/CoachKit/StudentKit 测试绿;swiftlint/swift-format strict 双绿;`MeetPR-Demo` 双机手测教练两 tab
- [ ] 不破现有功能(排计划向导/花名册/详情/分诊计数)

## 风险
1. 复用现有组件时注意 `Card` vs `ElevatedCard` 用法一致(别混)。
2. `BrandPrimaryButton` 抽出后学员 hero 行为必须零回归(同文案/同 action/同 full-width)。
3. 文件超 400 行拆子视图,别硬塞。
