# W1 组件卡回执 — 学员端黑金 UI v3

日期：2026-07-26
分支：`feat/black-gold-ui-v3`
基线：W0 `2e46d52`

## 交付清单

| 契约角色 | DesignSystem 真组件 | 文件 |
|---|---|---|
| DayChip | `MeetPRDayChip` | `Components/Chips/DayChip.swift` |
| Badge | `StatusBadge` | `Components/Badges/StatusBadge.swift` |
| SetRow | `SetRow` | `Components/Sets/SetRow.swift` |
| StatTile | `StatTile` | `Components/Labels/StatTile.swift` |
| GoldCTA | `GoldCTA` | `Components/Buttons/GoldCTA.swift` |
| ExerciseCard | `ExerciseCard` + `ExerciseSetRecord` | `Components/Cards/ExerciseCard.swift` |
| NumberPad | `MeetPRNumberPad` | `Components/Inputs/MeetPRNumberPad.swift` |
| PlateVisual | `plateBreakdown(totalKg:hasCollar:)` + `PlateVisual` | `Components/Brand/PlateVisual.swift` |

所有组件只从 `Color.MeetPR` 读取颜色，不接 theme 参数。暗/亮主题完全由 SwiftUI
`colorScheme` environment 驱动。PlateVisual 的样机字面色集中在 `Tokens/Colors.swift`
的 `PlateVisual` 段，每组 token 的注释追溯到主样机 SetEntry DOM 与 `SE_SPEC` /
`SE_DIM`；组件文件没有就地颜色字面量。

## dc props → Swift 属性映射

| dc 文件 | `data-props` | Swift 接口 | renderVals 落地 |
|---|---|---|---|
| `DayChip.dc.html` | `weekday/date/state/selected/onSelect` | `weekday/date/state/isSelected/onSelect` | 52×44、12 radius；任何 selected 都用 `ctaFill`、1.5px `gold500` 描边与白字；rest 无点；today 或 selected 点使用 1.8s pulseDot |
| `Badge.dc.html` | `text/tone/dot` | `init(_:tone:dot:)`（`dot` 必传） | gold/success/danger 的 RGB token 14% 底；neutral=`surfaceKey/textMuted`；4×12 padding；11px Mono semibold、`.04em` |
| `SetRow.dc.html` | `index/weight/reps/rpe/status/videoState` | 同名属性与 `SetRow.Status/VideoState` | 22/1fr/1fr/1fr/64、44pt 行高、14pt 横 padding、hairline；组结果图标与视频图标独立 |
| `StatTile.dc.html` | `label/value/unit/delta/accent` | 同名属性与 `StatTile.Accent` | 14×16 padding、16 radius；28px IBM Plex Mono heavy；delta 仅按 `+/-` 定 success/danger，无箭头 |
| `GoldCTA.dc.html` | `label/sub/variant/icon/onPress` | `init(_:sub:variant:icon:showsShimmer:...action:)` | primary/secondary/danger/link 四态；play/logout/chevron 均由 dc SVG Path 实现；link 文字与箭头间距 3pt |
| 整屏样机 `exBlocks` | `exercise/meta/note/collapsed/sets/onToggle` | 同名属性；动作名保持 `exercise` | 展开态 16px/`textPrimary`；收纳态 14px/`textSecondary`、隐藏 meta、`bgStack`、92% 宽；完成摘要追加失败组计数 |
| `NumberPad.dc.html` | `field/value/onCommit/onCancel` | 同名属性与 `MeetPRNumberPad.Field` | 真 `TextField`；3 列、52pt 键、8pt gap、12 radius；reps 小数点禁用且 0.25 opacity；取消不写值 |

任务卡对 dc 源码的显式覆盖也已执行：NumberPad「确定」键使用
`gold400 → gold500` 渐变，而不是 `NumberPad.dc.html` 当前的纯 `cta-bg`。

## dc 默认值处置

只把具有产品决策或展示语义的默认值放进生产 Swift API：

| 组件 | 采纳的默认值 | 理由 |
|---|---|---|
| `GoldCTA` | label=`开始训练`、sub=`蹲·推·拉`、variant=`.primary`、icon=`.play` | 这是产品主行动的完整默认语义 |
| `StatTile` | unit=`kg`、delta=`""`、accent=`.neutral` | `unit` 是重量统计的产品单位默认；空 delta 与 neutral accent 是 dc 契约的展示型默认 |
| `MeetPRNumberPad` | field=`.weight` | 训练录入的默认字段类型 |

以下 dc 默认只服务组件预览器，生产 API **未采纳**，调用方必须显式提供，避免数据缺失被静默掩盖：

| 组件 | 未采纳的默认值 | 理由 |
|---|---|---|
| `MeetPRDayChip` | weekday / date / state / selected | 都是当天计划数据，缺失应在调用处暴露 |
| `SetRow` | index / weight / status / videoState | 都是单组训练记录，静默造值会伪造训练事实 |
| `StatusBadge` | text / tone | 都由业务状态决定，不能由预览器文案兜底 |
| `ExerciseCard` | collapsed | 展开/收纳由训练流程状态决定，调用方必须明确 |

## 组件 × 状态 × 主题核对表

每行都有独立 `#Preview`，暗/亮使用同一组件代码，只切 `preferredColorScheme`。

| 组件 | Preview 覆盖状态 | Dark | Light |
|---|---|---:|---:|
| DayChip | done / missed / rest / today+selected / future | ✅ | ✅ |
| Badge | gold / success+dot / danger+dot / neutral | ✅ | ✅ |
| SetRow | done+uploaded / failed+failed / pending+none / done+uploading | ✅ | ✅ |
| StatTile | neutral、gold、success、danger；负/正/空 delta | ✅ | ✅ |
| GoldCTA | primary / link / secondary / danger；shimmer light 降级 | ✅ | ✅ |
| ExerciseCard | 展开混合组态 / 全记录收纳摘要 / 失败组摘要 | ✅ | ✅ |
| NumberPad | weight / reps（小数点禁用） | ✅ | ✅ |
| PlateVisual | 空杠 / 175kg 无卡箍 / 175kg 有卡箍 | ✅ | ✅ |

### 逐项行为核对

- DayChip：rest 没有点；任何 selected 都反白并描金边；done/missed/today/selected
  点色与 `renderVals` 一致，pulseDot 在 Reduce Motion 下退化为静态点。
- Badge：四 tone 均为无边框胶囊；danger 不被其他状态复用。只有显式
  `init(_:tone:dot:)` 走 v3；W0 `init(_:tone:)` 与 `init(status:title:)` 都保持
  `2e46d52` 的边框、旧 padding、Bold 与图标规则。
- SetRow：done/failed/pending 与相机全部使用 dc SVG Path 的原始 frame/stroke；
  failed 数值走 `dangerMuted`；相机的 none/uploading/uploaded/failed 独立着色。
- GoldCTA：所有可点态 ≥44pt；primary/secondary 的 16px label 使用 `.01em`
  （0.16pt）tracking；primary 的正常/held mold 来自 W0 visual-effect token；
  shimmer 是 opt-in、默认关、Reduce Motion 隐藏、亮色环境隐藏。
- ExerciseCard：只要存在任一 done/failed 已记录组就生成
  `N 组 · Wkg×R @RPE`；存在 failed 时追加 `· N 组未完成`。渲染单源选定整屏样机
  `exBlocks`（主样机 1038–1058 行）；收纳圆角源码为 14px，但按 README §2 圆角正典
  有意收编为 16px，这是本组件唯一已记录的样机偏离。头部色条等价
  `align-self:stretch` 跟随 header 内容高度，并保留展开 26pt / 收纳 18pt 下限。
- NumberPad：weight 提交吸附 0.25kg 且 clamp 20–500；reps 整数且 clamp 1–100；
  空输入或取消走 `onCancel`，不调用 `onCommit`。显示值的 800 映射到
  IBM Plex Mono Bold；打包字体没有 Mono 800 字面，因此按 Typography 现有降级映射
  使用 Bold；退格键是 19px IBM Plex Mono Bold 字符 `⌫`，不使用 SF Symbol。
  「确定」使用 Archivo ExtraBold。
- PlateVisual：20kg 杆；25/20/15/10/5/2.5/1.25kg 贪心；卡箍按每侧 2.5kg 扣除；
  杆右端为平直 Rectangle；卡箍开关不修改 shaft/shoulder/sleeve 的尺寸与形状；
  shaft/sleeve、lever/knob stop location 与连续 1px 黑白螺纹均逐字锁定。lever
  在 35pt 卡箍容器内按 `left=8pt/top=17pt` 定位；shoulder 左高光 x=1pt；螺母
  叠加样机两层 inset shadow。无障碍文案分为空杠、仅赛扣、片组（可追加赛扣）
  三支，不再拼接空串。
- 无障碍增强默认不改变视觉：仅当 `accessibilityDifferentiateWithoutColor` 开启，
  DayChip missed 点改为空心环；SetRow 相机 failed 加 45° 斜杠、uploaded 加勾角标。

## r10 冻结并存

| W0/r10 角色 | W1 处置 |
|---|---|
| `MeetPRDayChip` | 原文件原位按 v3 重写；没有第二个 DayChip |
| `StatusBadge` | v3 `init(_:tone:dot:)` 与冻结的 W0 `init(_:tone:)` / `init(status:title:)` 并存；两个旧入口仍走旧图标、边框、padding、字重 |
| `SetReadOnlyCell` | 公开入口包装 internal `LegacySetReadOnlyCell`；nil 仍显示 `-`，布局/色彩保持 `2e46d52` |
| `StatBlock` | 公开入口包装 internal `LegacyStatBlock`；旧 Demo/消费方不换成 `StatTile` |
| `BrandPrimaryButton` | 公开入口包装 internal `LegacyBrandPrimaryButton`；subtitle/systemImage 默认、loading、充能与释放扩散动画全部保留 |
| `SecondaryButton` / `DangerButton` | 恢复 W0 独立渲染与原触觉反馈，不再委托 `GoldCTA` |
| `MeetPRNumberPad` | 原文件原位按 NumberPad v3 重写 |
| `PlateLoadout` | 公开入口包装 internal `LegacyPlateLoadout`，保持旧 208pt 杠铃图；新 `PlateVisual` 独立为 148pt v3 组件 |
| `CardSurface` / `GoldProgressBar` / `HeaderChatButton` 等 | 本卡没有对应 dc 角色，按任务卡保持不动 |

上述 Legacy 文件顶部都有与 `LegacyColors` 同款冻结声明：新代码禁用，教练波迁移后删除。
本轮不再宣称去重；结论改为 **冻结并存，去重推迟到教练波**，确保教练端和现有屏
一个像素不因 W1 改变。

## PlateVisual 单测

`PlateBreakdownTests` 覆盖：

- 空杠 20kg（卡箍开/关）
- 175kg：无卡箍每侧 `25×3 + 2.5`；有卡箍每侧 `25×3`
- 卡箍开关
- 20 / 500kg 边界与范围外 clamp
- 20...500kg 的每个 0.25kg 输入：合法片种、降序、贪心余量小于 1.25kg
- NumberPad weight 0.25kg 吸附及 reps 整数边界
- 产品默认值、SetRow/GoldCTA SVG frame/stroke 常量
- `SE_SPEC` / `SE_DIM` 全表与全部 PlateVisual gradient stop locations
- ExerciseCard 摘要格式（含失败后缀与部分记录收纳态）
- PlateVisual 空杠 / 仅赛扣 / 片组（含赛扣）三分支无障碍文案
- Legacy 入口的旧参数与可断言数据层

## 验证结果

执行上下文：

- project：`MeetPR.xcodeproj`
- configuration：`Debug`
- simulator：`iPhone 17`，iOS 26.5，UDID
  `A5119984-9A8D-415C-83D4-E7145351FA79`

| 闸门 | 结果 |
|---|---|
| Xcode toolchain `swift-format lint --configuration .swift-format --strict`（`Modules/DesignSystem` 全量 Swift 文件） | 通过，零输出 |
| `swiftlint lint --strict --quiet --config .swiftlint.yml Modules/DesignSystem` | 通过，零输出 |
| `Modules/DesignSystem` SwiftPM 测试 | 60 passed / 0 failed / 0 skipped |
| `MeetPR` iOS Simulator Debug build | succeeded，零 warning |
| `MeetPR-Demo` iOS Simulator Debug build | succeeded，零 warning |
| `MeetPR-DemoStudent` iOS Simulator Debug build | succeeded，零 warning |

## 范围说明

- 没有修改 `StudentKit`、`CoachKit`、`ChatUI`、`AppShell` 的业务视图。
- 没有写 `docs/CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。
- 没有修改 build number、tag、签名、依赖或 `project.pbxproj`。
- 范围外最小编译修正：`MeetPRTabBar` 的泛型约束补 `Sendable`，与其
  `MeetPRTabBarItem<ID: Hashable & Sendable>` 对齐，消除 strict-concurrency warning；
  没有改变渲染或调用接口。
- 没有 commit 或 push。
