# 003 — Design System Foundation (Tokens + Atomic Components)

- **状态**: Ready
- **PR**: (待填)
- **来源**:
  - Claude Design 产出的 **dev handoff bundle**:`specs/003-design-system-foundation/design-bundle/`
  - 该 bundle 是本 spec 的**视觉 ground truth**(46 个文件,含 `colors_and_type.css` 全部 token + 30+ 组件 HTML 预览 + voice/iconography README)
  - [ADR 005 §1 模块结构](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) — DesignSystem 是 6 个 SPM target 之一,纯 SwiftUI 模块
  - [信息架构 v1](~/Brain/wiki/projects/MeetPR/information-architecture.md) — 后续 feature spec 会大量引用本 spec 输出的组件

## 目标

把 `design-bundle/` 的视觉规范翻译成 `Modules/DesignSystem/` 的 Swift 实现,**替换** spec 001 留下的占位 stub(`Colors.swift` / `Typography.swift` / `PrimaryButton.swift` 当前仅 1-3 行内容)。落地后:
1. 所有 design token(颜色 / 字号 / 间距 / 圆角 / 动效)以 Swift 类型(`Color` extension / `Font` extension / `enum`)暴露,可被 AppShell / CoachKit / StudentKit / 后续 feature spec 直接引用
2. 14 个原子组件作为 SwiftUI `struct: View` 暴露,API 稳定后所有 feature spec 都基于它们组合,不再每屏自行决定视觉
3. `DesignSystemDemo` 屏(单屏 catalog)平铺所有 token + 组件,Xcode Canvas + 模拟器都能视觉走查

## 范围

### 做什么(本 spec / 一个 PR)

1. **删除** spec 001 留的 stub:`Modules/DesignSystem/Sources/DesignSystem/{Colors,Typography,PrimaryButton}.swift`
2. **新增 token 文件**(`Modules/DesignSystem/Sources/DesignSystem/Tokens/`)
   - `Colors.swift` — 严格按 `design-bundle/project/colors_and_type.css` `:root` + `[data-theme=light]` 翻译
   - `Typography.swift` — 字号梯度 + monoLabel + displayNumeral + displayUnit
   - `Spacing.swift` — 8pt grid token(xs/sm/md/base/lg/xl/2xl/3xl)
   - `Radius.swift` — sm/md/lg/xl/pill
   - `Motion.swift` — easing curve + durations
3. **14 个组件**(`Modules/DesignSystem/Sources/DesignSystem/Components/`,按子目录组织):
   | 组件 | 文件 | 视觉源 |
   |---|---|---|
   | `PrimaryButton` | `Buttons/PrimaryButton.swift`(替换 stub)| `design-bundle/project/preview/comp-buttons.html` |
   | `SecondaryButton` | `Buttons/SecondaryButton.swift` | 同上 |
   | `DangerButton` | `Buttons/DangerButton.swift` | 同上 |
   | `IconButton` | `Buttons/IconButton.swift` | 同上 + iconography 章节 README |
   | `Card` | `Cards/Card.swift` | `comp-cards.html` + `anatomy-card.html` |
   | `ElevatedCard` | `Cards/ElevatedCard.swift` | 同上 + `elevation.html` |
   | `Eyebrow` | `Labels/Eyebrow.swift` | `comp-stat-eyebrow.html`(下半部)|
   | `StatBlock` | `Labels/StatBlock.swift` | `comp-stat-eyebrow.html`(上半部)+ `type-display-numerals.html` |
   | `StatusBadge` | `Badges/StatusBadge.swift` | `comp-badges.html` |
   | `PRBadge` | `Badges/PRBadge.swift` | 同上(red filled pill 变体)|
   | `MeetPRTextField` | `Inputs/MeetPRTextField.swift` | `comp-textfield.html`(避免与 SwiftUI `TextField` 重名)|
   | `NumericInput` | `Inputs/NumericInput.swift` | `comp-numeric.html`(±/quick adjust/单位 toggle)|
   | `RPESlider` | `Inputs/RPESlider.swift` | `comp-rpe-slider.html`(5.0→10.0 / 0.5 步进)|
   | `MeetPRListRow` | `Lists/MeetPRListRow.swift` | `comp-listrow.html` |
4. **Demo 屏**:`Modules/DesignSystem/Sources/DesignSystem/Demo/DesignSystemDemo.swift`
   - 单一 SwiftUI `View` catalog,纵向滚动展示所有 14 组件 + 全部 token 样本
   - 顶部带"Light / Dark / System"切换器(`@State` 强制 colorScheme override)
   - 不接入 main app,仅供 Xcode Preview + 手动跑 simulator 视觉走查
5. **测试**(`Modules/DesignSystem/Tests/DesignSystemTests/`):
   - 每个组件 `#Preview` Macro 产物在 Canvas 渲染不崩
   - Token 数值断言:`Color.brandRed.toHex == "#E5221E"`、`Spacing.base == 16` 等(用 helper 读 SwiftUI Color 的 RGB 分量做近似断言)
   - `DesignSystemDemoTests.demoSmoke()` — 实例化 `DesignSystemDemo()` 不崩

### 不做什么(留后续 spec)

- ❌ `WeekPlanGrid`(`comp-week-plan.html`)— 教练编排器专用,与 feature spec 一起做
- ❌ `e1RMHistoryChart`(`comp-chart.html`)— 学员成长曲线专用
- ❌ `VideoUploadCell`(`comp-timer-upload.html`)— 视频上传 feature 专用
- ❌ `CustomTabBar`(`comp-tabbar.html`)— 评估后是否真需要自定义 vs SwiftUI 原生 `TabView` 默认 + `.tint(Color.brandRed)`,留 AppShell 重构 spec 决定
- ❌ `SetRow`(`comp-setrow.html`)— 训练日 feature 专用,逻辑跟数据模型耦合
- ❌ Empty state(`comp-empty.html`)— 留对应 feature spec
- ❌ Logo / wordmark assets — bundle 只有 SVG 占位,等真实 logo 再做(见 [F-013] 待加)
- ❌ Lucide → SF Symbols 完整 mapping 表 — bundle 提到 `assets/icons/MAPPING.md` 但 bundle 里没该文件;本 spec 只锁 4 个最常用 icon(见技术要求 §icon),完整 mapping 留下个 spec
- ❌ Localizable.xcstrings 中文化 — 本 spec 所有用户可见文本用英文 placeholder("Save Mesocycle" / "Discard"),i18n 留专门 spec

## 技术要求

### `design-bundle/` 是 ground truth — 先读再动手

实施前必读:
1. `design-bundle/README.md` — bundle 的 coding agent 须知
2. `design-bundle/project/README.md` — 完整 brand voice + visual rules + iconography
3. `design-bundle/project/SKILL.md` — 速查
4. `design-bundle/project/colors_and_type.css` — **token 数值唯一来源**,Swift 实现的 hex / pt / 比例必须与之**一字不差对齐**

如果 CSS 与本 SPEC 文字描述出现矛盾,**以 CSS 为准**,且写 `QUESTIONS.md` 通知 Claude review。

### Token Swift API 约定

#### `Colors.swift`

- 所有颜色作为 `Color` 静态属性 extension,命名空间 `Color.MeetPR.xxx`(避免污染全局 `Color` namespace):
  ```swift
  public extension Color {
      enum MeetPR {
          // Brand
          public static let brandRed = Color(red: 229/255, green: 34/255, blue: 30/255)
          public static let brandRedPress = Color(red: 184/255, green: 26/255, blue: 23/255)
          public static let brandRedSoft = Color.MeetPR.brandRed.opacity(0.12)
          // Semantic
          public static let green = Color(red: 31/255, green: 179/255, blue: 88/255)
          public static let amber = Color(red: 224/255, green: 168/255, blue: 16/255)
          // ...
      }
  }
  ```
- **Dynamic colors**(随 `@Environment(\.colorScheme)` 切换的颜色)用 `Color(light:dark:)` helper:
  ```swift
  public extension Color.MeetPR {
      static let bg = Color(light: Color(white: 250/255), dark: .black)
      static let surface1 = Color(light: .white, dark: Color(red: 14/255, green: 14/255, blue: 14/255))
      // surface2, surface3, border, borderStrong, fgPrimary, fgSecondary, fgTertiary, fgDisabled
  }
  ```
  Helper 实现:
  ```swift
  public extension Color {
      init(light: Color, dark: Color) {
          self = Color(UIColor { traits in
              traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
          })
      }
  }
  ```
- 完整列表逐字对照 `colors_and_type.css` 的 `:root` 和 `[data-theme="light"]` block,**18 个颜色 token 一个不能少**

#### `Typography.swift`

- 命名空间:`Font.MeetPR.xxx`
- 用 SwiftUI `Font.system(size:weight:)`,**不引入第三方字体**(保 ProMotion 兼容 + Dynamic Type)
- Display weight 用 `.heavy`(SF Pro Heavy);body emphasis 用 `.semibold`
- 单独提供 `monoLabel` / `displayNumeral` / `displayUnit`:
  ```swift
  public extension Font {
      enum MeetPR {
          public static let displayHero = Font.system(size: 44, weight: .bold).leading(.tight)
          public static let title1 = Font.system(size: 34, weight: .bold)
          // ...
          public static let monoLabel = Font.system(size: 12, weight: .medium, design: .monospaced)
          public static let displayNumeral = Font.system(size: 60, weight: .heavy).monospacedDigit()
          public static let displayUnit = Font.system(size: 24, weight: .heavy)
      }
  }
  ```
- monoLabel 用 `.tracking(0.96)`(0.08em × 12pt = 0.96)做字母 tracking;ALL CAPS 在使用处用 `.textCase(.uppercase)` 或 `Text("…").uppercase`(SwiftUI 没原生 uppercase modifier,用 `String(localized:)` + `.uppercased()` 转)
- 显式声明 `.monospacedDigit()` 在所有 numeric display 场景

#### `Spacing.swift` / `Radius.swift` / `Motion.swift`

```swift
public enum MeetPRSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let base: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64
}

public enum MeetPRRadius {
    public static let sm: CGFloat = 4
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
    public static let xl: CGFloat = 16
    public static let pill: CGFloat = 999
}

public enum MeetPRMotion {
    public static let easeIOS = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.24)
    public static let durationFast: Double = 0.20
    public static let durationBase: Double = 0.24
    public static let durationSlow: Double = 0.28
}
```

### 组件 SwiftUI 约定(每个组件统一)

1. **`public struct: View`**(不是 `ButtonStyle` 或 view modifier)。理由:flex 比 modifier 高,后续可以在 component 内部封装多状态。
2. **入口 init 是显式 public** 且参数最少;复杂场景留 builder/构造器。
3. **不持有 state**(stateless 偏好);需要交互的(NumericInput / RPESlider)用 `@Binding` 让外面控制。
4. **所有交互组件加 `.sensoryFeedback(...)` haptic**:
   - 普通按钮:`.sensoryFeedback(.impact(weight: .light), trigger: pressed)`
   - DangerButton:`.sensoryFeedback(.warning, trigger: pressed)`
   - RPE slider 每 0.5 step:`.sensoryFeedback(.selection, trigger: rpeValue)`
   - PRBadge 出现时:`.sensoryFeedback(.success, trigger: visible)`
5. **每个组件**附带 `#Preview` Macro,展示:
   - default state(dark mode,iPhone 15 Pro layout)
   - 同一组件在 light mode(用 `.preferredColorScheme(.light)` 覆盖)
   - 不同输入的关键 state(disabled / pressed / loading where applicable)
6. **VoiceOver / accessibility**:每个组件加 `.accessibilityLabel(...)` + `.accessibilityHint(...)`(如需);button 类用 `.accessibilityAddTraits(.isButton)`(SwiftUI Button 默认带,但自定义 hit area 的需要手动加)

### Native iOS primitives 严守(为保丝滑感)

Codex 实现时**严禁**:
- ❌ 自实现 transitions / push-pop animation;一律用 SwiftUI `NavigationStack` 默认或 `.sheet(...)` + `.presentationDetents()`
- ❌ 自实现 scroll spring / bounce;一律用 `ScrollView` / `List` / `LazyVStack`
- ❌ 自定义图标资源(SVG/PNG);一律用 SF Symbols,`Image(systemName: "...")`
- ❌ 引入第三方字体;一律用 `.system(size:weight:design:)`
- ❌ 用 `.scaleEffect(0.95)` 做按钮按下效果;按下用 `.opacity(0.6)` per design spec(see colors_and_type.css 末尾 + README §States)
- ❌ 用 spring 动画(`.animation(.spring())`);一律用 `MeetPRMotion.easeIOS`
- ❌ 用 shadow 表达 elevation(dark mode 看不到);用 1px hairline border `Color.MeetPR.border` 区分层级

允许的 native modifier(用之即可,不需要自实现):
- ✅ `.scrollTargetBehavior(.viewAligned)` — 列表吸附
- ✅ `.presentationDetents([.medium, .large])` — modal 多档高度
- ✅ `.symbolEffect(.bounce)` — SF Symbol 动画
- ✅ `.contextMenu { ... }` — 长按菜单
- ✅ `.sensoryFeedback(...)` — 触感(per 上)
- ✅ `.materials`(`.regularMaterial` 等) — **仅** nav bar / 键盘上方过渡区,不在 card / modal 上用

### Iconography(本 spec 锁定 4 个)

Bundle 提到 SF Symbols 是生产用的,Lucide 是 web preview proxy。本 spec **不实现完整 mapping 表**,但锁定本 spec 范围内组件用到的 4 个 SF Symbol:

| 用途 | SF Symbol name |
|---|---|
| IconButton 默认演示 | `ellipsis` |
| StatusBadge "ready" 状态 | `checkmark.circle.fill` |
| StatusBadge "live" 状态 | `record.circle` |
| MeetPRListRow 默认 trailing | `chevron.right` |

后续 feature spec 引入更多 icon 时,再起完整 mapping 文档。

### 文件结构

```
Modules/DesignSystem/Sources/DesignSystem/
├── Tokens/
│   ├── Colors.swift
│   ├── Typography.swift
│   ├── Spacing.swift
│   ├── Radius.swift
│   └── Motion.swift
├── Components/
│   ├── Buttons/
│   │   ├── PrimaryButton.swift       (替换 spec 001 stub)
│   │   ├── SecondaryButton.swift
│   │   ├── DangerButton.swift
│   │   └── IconButton.swift
│   ├── Cards/
│   │   ├── Card.swift
│   │   └── ElevatedCard.swift
│   ├── Labels/
│   │   ├── Eyebrow.swift
│   │   └── StatBlock.swift
│   ├── Badges/
│   │   ├── StatusBadge.swift
│   │   └── PRBadge.swift
│   ├── Inputs/
│   │   ├── MeetPRTextField.swift
│   │   ├── NumericInput.swift
│   │   └── RPESlider.swift
│   └── Lists/
│       └── MeetPRListRow.swift
└── Demo/
    └── DesignSystemDemo.swift

Modules/DesignSystem/Tests/DesignSystemTests/
├── ColorsTests.swift                  (扩展 spec 001 stub:对全 18 个颜色 token 断言)
├── TypographyTests.swift              (新增)
├── SpacingTests.swift                 (新增)
├── ComponentsSmokeTests.swift         (新增,每组件实例化不崩)
└── DesignSystemDemoTests.swift        (新增,Demo view 实例化)
```

`Modules/DesignSystem/Package.swift` 不需要改(无新依赖,仍只 import Foundation/SwiftUI/UIKit;UIKit 仅用于 `UIColor { traits in ... }` dynamic color helper)。

### Strict concurrency

继承 spec 001 的 `.enableUpcomingFeature("StrictConcurrency")`。所有组件结构体和 helper:
- struct `View`s 默认 `Sendable` + `@MainActor`(SwiftUI View 隐式 MainActor,但 Swift 6 需要显式标 `@MainActor`)
- Token enum 是 frozen-ish,`@frozen public enum MeetPRSpacing { ... }` 加上明确编译期常量

## 验收标准

- [ ] 所有列出的文件存在,目录结构如上
- [ ] spec 001 的 3 个 stub(`Colors.swift` / `Typography.swift` / `PrimaryButton.swift`)被替换或 move 到 `Tokens/` / `Components/Buttons/`,根目录干净
- [ ] **18 个颜色 token** 全部对齐 `colors_and_type.css` 的 `:root` 数值;light mode 18 个全部对齐 `[data-theme="light"]`(用 RGB 分量精度 ≤ 1/255 误差断言)
- [ ] **9 个字号 token** 全部对齐 CSS(displayHero/title1/title2/headline/body/footnote/caption/monoLabel/displayNumeral)
- [ ] **8 个 spacing token** 数值精确(4/8/12/16/24/32/48/64)
- [ ] **5 个 radius token** 数值精确(4/8/12/16/999)
- [ ] **easing curve** 是 `cubic-bezier(0.32, 0.72, 0, 1)`,用 SwiftUI `Animation.timingCurve(...)` 表达
- [ ] **14 个组件**全部存在,每个有至少 1 个 `#Preview`,Xcode Canvas 不报错
- [ ] **PrimaryButton** 视觉对照 `comp-buttons.html`:dark mode 白底黑字 + 12pt radius + 14×24 padding + Title Case 文本
- [ ] **SecondaryButton** 视觉:transparent 底 + 1px 白边 + 同 padding
- [ ] **DangerButton**:`Color.MeetPR.brandRed` 实心 + 白字
- [ ] **Card** 视觉:`Color.MeetPR.surface1` 底 + 1px `border` 边 + 12pt radius + 16pt padding
- [ ] **Eyebrow** 视觉:mono 红字 caps + 32pt 红色 trailing rule(用 `Rectangle().frame(width: 32, height: 1)`)
- [ ] **StatBlock**:小红 mono caps label + 60pt heavy tabular 数字 + 24pt heavy 小红单位
- [ ] **NumericInput**:- 圆角 button 44×44,中间大数字 + 单位,下排 −2.5/−5/+2.5/+5 + KG⇄LB toggle 5 个 mono 小 button(KG⇄LB 是白底黑字 inverse)
- [ ] **RPESlider**:0.5-step 5.0→10.0,顶部 RPE eyebrow + 大数字 + "/ 10",底部刻度 mono 灰字,thumb 24pt 白圆 + 4pt 半透白光晕
- [ ] **PRBadge**:red filled pill + 白 mono caps "NEW PR" / "PR"
- [ ] **DesignSystemDemo**:能在 Xcode Preview 跑 + 模拟器跑;顶部有 light/dark/system 切换器;纵滚平铺所有组件;每组件附 1 句 mono caps 描述
- [ ] **swift build** Modules/DesignSystem/ 单独跑通过,Swift 6 strict concurrency,0 warning
- [ ] **swift test** 通过,DesignSystemTests 至少 25 个测试(18 颜色 + 8 间距 + 14 组件 smoke 略有重叠)
- [ ] **xcodebuild build / test** 整个 MeetPR scheme 通过
- [ ] **CoachKit 不可 import StudentKit** 反向回归测试做(spec 001 验证步骤复用一遍)
- [ ] swiftlint + swift-format pre-commit pass(严禁 --no-verify)
- [ ] CI 在 `feat/003-design-system` 分支跑过,绿
- [ ] **手动 simulator 走查**:启动 app → 临时改 `MeetPRApp.swift` 入口 view 为 `DesignSystemDemo()`(commit 前改回 `RootView()`)→ 看 light + dark 两次 → 验证视觉上跟 `design-bundle/project/preview/*.html` 在浏览器渲染的视觉**95% 以上一致**(允许 SF Symbols vs Lucide / SF Pro vs system fallback 引起的 5% 差异)
- [ ] FOLLOWUPS 加新条目 F-013(logo SVG / wordmark 真实资产何时补)+ F-014(完整 SF Symbols ↔ Lucide mapping 表何时完成)

## 参考

- **设计 ground truth**:`specs/003-design-system-foundation/design-bundle/`(全 46 文件)
  - `project/colors_and_type.css` — token 唯一来源
  - `project/README.md` — voice + visual + iconography 规则
  - `project/preview/comp-*.html` — 14 个组件视觉源
- **架构基础**:[ADR 005](~/Brain/wiki/projects/MeetPR/decisions/005-ios-architecture.md) §1(模块切分)+ §3(SwiftUI + @Observable + 严格并发)
- **iOS 平台规范**:Apple HIG(SF Symbols / Dynamic Type / system materials)
- **前序 spec**:[001-bootstrap](../001-bootstrap/SPEC.md)— 创建 DesignSystem 模块骨架 + 3 个 stub 文件,本 spec 接力填实
- **后续 spec hint**:002-core-models-identity 跟本 spec 不冲突,可 parallel 实现;feature spec(教练 dashboard / 学员训练日 / Onboarding)依赖本 spec 完成

## Notes(给 Codex)

- **绝对不要**修改 `design-bundle/`下任何文件 — 它是 ground truth,只读不写
- **如果 bundle 与本 spec 冲突**,bundle 的 CSS 数值优先;但语义性规则(用 SF Symbols 不用 Lucide / 用 NavigationStack 不用自实现 transition)以本 spec 为准
- **Light mode 是 fallback**,但必须实装 — 用 `Color(light:dark:)` helper 一次写好,SwiftUI 会自动响应 `colorScheme` 切换。不要在每个组件内写 `if colorScheme == .dark { ... }` 分支
- **不要预加 i18n** — 文本用英文 placeholder("Save Mesocycle" 等),`Localizable.xcstrings` 留给单独 spec
- **不要引入任何第三方包** — UIKit / SwiftUI / Foundation 之外不允许
- **不要尝试做完所有 30 个 bundle 组件** — 本 spec 范围只有 14 个;bundle 里的 WeekPlanGrid / Chart / VideoUploadCell / SetRow / CustomTabBar / EmptyState 不在范围,不要顺手做
- **每个组件实现完写一句话 commit message**,一组组件一个 commit(不要一个 mega commit 1500 行),便于 review 拆 diff
- **PR description 必须**:
  - 列每个组件 + 该组件视觉源 HTML 文件名 + 你的 SwiftUI 实现文件路径(三列表)
  - 附 4 张 Xcode Canvas 截图:dark mode 全 catalog / light mode 全 catalog / NumericInput 各状态 / RPESlider 各状态
  - PR Verification 段把上面 acceptance 全打勾,**没做的不许打**
- **绝对不要 self-merge** — 等 Claude(David)review 过

## 后续(本 spec 之外)

- spec 003 merge 后 → 写 spec 004(剩余 6 个 bundle 组件:WeekPlanGrid / Chart / VideoUploadCell / SetRow / CustomTabBar / EmptyState — 但这些更适合跟对应 feature spec 一起做,本 spec 不预排期)
- spec 003 merge 后 → 002-core-models-identity 已草稿,改 Ready,派 Codex 落地(本 spec 与 002 互不依赖,parallel OK)
- spec 003 merge 后 → AppShell 的 `AuthFlowView` 第一次升级:替换 spec 001 stub 的 `Button("Sign in as Coach")` 为 `PrimaryButton("Sign in as Coach")`,`Button("Sign in as Student")` 为 `SecondaryButton(...)`(可在本 PR 里顺手做,或 next spec)
