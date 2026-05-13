# 023 — Planning numeric input(Step 5 转盘 picker + Step 6 `[ - ] [ TextField ] [ + ]` sandwich)

- **状态**: Draft
- **PR**: TBD
- **触发**: User 2026-05-13 dogfood 反馈 — Step 6 custom 规则 W2/W3/W4 重量值 Stepper-only 设到 100kg 要 ~40 次点,300kg 要 ~120 次点,极不顺手。Step 5 set count / 次数 / RPE / repsMax stepper 同问题(范围小但同 friction)。Layout 决策 (C):**Stepper 拆 -/+ 包夹 TextField**(用户拍板)
- **来源**:
  - 已合 [spec 005-007](../) coach planning Step 0-7(本 spec 改 Step 5 ExerciseSetEditorCard + Step 6 ProgressionRuleEditorCard 内部 input UI,**不动** state machine / business logic)
  - [WeightInputField.swift](../../Modules/CoachKit/Sources/CoachKit/Planning/Views/WeightInputField.swift) — Step 5 W1 重量已是 TextField + 段控 pattern,**本 spec 不改它**(已 OK)
  - [PlanningDecimal.swift](../../Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningDecimal.swift) — `.planningRounded(_:increment:)` / `.roundedToPlanningIncrement(_:)` helpers 复用

## 目标

把 Step 5 + Step 6 内部 6 处 bare `Stepper` **按场景分两个组件**替换(2026-05-13 用户 dogfood feedback:窄范围整数用转盘比 sandwich 更直觉,范围宽 decimal 用 sandwich 比转盘高效):

- **`PlanningCountPicker`**(新组件,iOS 转盘 picker,inline 展开 pattern)— Step 5 内 4 处:**组数 / 次数 / 次数上限 / RPE**
- **`PlanningNumberField`**(原 spec 设计,layout C `[ - ] [ TextField ] [ + ]`)— Step 6 内 2 处:**weekly increment / custom 周值**

教练能感知的差异:
- **Step 5(转盘 picker)**:点 "组数 3" 行 → 行下方 inline 展开 iOS 转盘 → 上下滑选 3→12 即用,**不调键盘**;次数 / 次数上限 / RPE 同 pattern
- **Step 6(sandwich)**:weekly increment / custom 周值 范围宽(0-300 kg)且 decimal,**打字直接到目标**(100kg 由"按 40 次 +" → "打 100"),旁边 `+` / `-` 微调还在
- **Step 5 主项 W1 重量栏不动**:WeightInputField 已是 TextField + 段控 pattern,本 spec 不动

为什么分两个控件而不是一刀切:
- 转盘 wins 在窄范围整数(组数 1-20 / 次数 1-50 / RPE 1-10 步 0.5)— 滑动到位 + 无键盘 + 常用值就那几档
- sandwich wins 在范围宽 + decimal(weight 0-300 / weekly increment 0-100 任意小数)— 转盘滑 100 下太慢
- 同一卡片混用两种控件可接受:Step 5 卡片内 4 个字段全转盘(视觉一致);Step 6 卡片内 2 个字段全 sandwich(视觉一致);两 Step 间用户做的是不同动作(Step 5 = 填 baseline,Step 6 = 写规则),控件不同合理

## 范围

### 做什么

#### 1. 新加 `PlanningNumberField` View(sandwich 式,for Step 6 范围宽 decimal)

**位置**: `Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningNumberField.swift`(feature-local, V0.1+ 视复用需要再 promote 到 DesignSystem)

**用在**:Step 6 `ProgressionRuleEditorCard` 的 weekly increment + custom 周值 2 处(范围宽 / decimal)。Step 5 4 处 numeric input **不用** PlanningNumberField,改用 `PlanningCountPicker`(§1.7)。

**API**:

```swift
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningNumberField: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  let decimalIncrement: Decimal  // for round-on-blur via PlanningDecimal helpers
  let unitLabel: String?         // "kg" / "RPE" / nil(组数 / 次数 等无单位)
  let formatStyle: FloatingPointFormatStyle<Double>  // 默认 .number.precision(.fractionLength(0...1))

  init(
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    decimalIncrement: Decimal,
    unitLabel: String? = nil,
    formatStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...1))
  )
}
```

**Layout(C)**:

```
┌─┐ ┌──────┐ ┌─┐  kg
│-│ │ 100  │ │+│
└─┘ └──────┘ └─┘
```

- `-` Button(disabled if value <= range.lowerBound)
- `TextField`(`.keyboardType(.decimalPad)` / `.multilineTextAlignment(.center)` / 固定宽度 ~70-90pt)
- `+` Button(disabled if value >= range.upperBound)
- `unitLabel` Text(可选,跟在右侧)

**Behavior**(per Codex review PR #52 finding #1 + #2):
- 内部 `@State private var textInput: String` 缓存当前输入文本(空字符串 / "1" / "10" / "100" 都合法的中途态)
- 内部 `@FocusState private var isFocused: Bool` 跟踪焦点
- 用户打字时:textInput 实时更新,**不动 binding**(避免中途 round)
- **失焦或 keyboard toolbar Done tap 时**(详情见 §做什么 #1.5):
  1. parse textInput 为 Double(空 / 非法 → 0)
  2. round 到 step(`Decimal.planningRounded(_, increment: decimalIncrement)`)
  3. clamp 到 range
  4. write 回 Binding<Double>
  5. textInput sync 回 formatted display(e.g. "100" / "100.5")
- `-` Button:`value = max(value - step, range.lowerBound)`,然后 textInput sync 到 formatted display
- `+` Button:`value = min(value + step, range.upperBound)`,然后 textInput sync 到 formatted display
- Button styling 用 DesignSystem `MeetPRRadius` / `Color.MeetPR.surface2` 跟现有控件视觉一致

**约束**:
- `nonisolated` 不需要(View 本身是 @MainActor)
- 不引入新依赖
- **允许内部 `@State private var textInput: String` + `@FocusState`**(per finding #1 — 用户打"100"中间状态"1"/"10"必须暂存,不能直接 round 到 binding;textInput 是 mid-typing 缓冲)
- 外部 API 仍是 `Binding<Double>`,内部 state 不暴露
- value 类型对外保持 Double(跟现有 Stepper 调用方对齐;Decimal round-trip + textInput String parse 在内部完成)

#### 1.5. Keyboard toolbar Done button(per Codex review PR #52 finding #2)

**为什么必加**:`.decimalPad` keyboard 没有 Return 键,blur 仅靠"点别处"触发不可靠(用户在 input 上方 / 下方挤的卡片上点也不一定捕获到)。Apple HIG 也推荐 decimalPad 配 toolbar Done button。

**实装**:

```swift
TextField(/* ... */, text: $textInput)
  .keyboardType(.decimalPad)
  .focused($isFocused)
  .toolbar {
    ToolbarItemGroup(placement: .keyboard) {
      Spacer()
      Button("完成") { isFocused = false }  // 触发 normalize 流程
    }
  }
  .onChange(of: isFocused) { _, focused in
    if !focused { normalize() }
  }
```

`normalize()` 走 §Behavior 失焦流程(parse → round → clamp → write binding → sync textInput)。

**Toolbar styling**:placement `.keyboard`,Done button 默认右侧,`.bold()` 视觉清晰。

#### 1.7. 新加 `PlanningCountPicker` View(转盘式,for Step 5 窄范围整数 / RPE)

**位置**: `Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningCountPicker.swift`(feature-local,同 PlanningNumberField defer 规则)

**用在**:Step 5 `ExerciseSetEditorCard` 的 **组数 / 次数 / 次数上限 / RPE** 4 处(窄范围 + step-snap 离散值,转盘比 sandwich 更直觉)。

**为什么独立组件而不是 PlanningNumberField 的 wheel variant**:
- 控件交互模型差异本质:wheel 只接受离散合法值(snap to step),NumberField 接受任意输入(失焦才 round/clamp)。混进一个组件会增加内部分支 + 测试矩阵
- API 不同:wheel 不需要 keyboard toolbar / textInput / @FocusState / decimalPad / normalize 那一套
- 用户心智:Step 5 vs Step 6 是两种填表心智(baseline 选档 vs 增量调整),控件分开反而更清晰

**API**:

```swift
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningCountPicker: View {
  let label: String           // "组数" / "次数" / "次数上限" / "RPE"
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double            // 1 for counts, 0.5 for RPE
  let unitLabel: String?      // 默认 nil(组数 / 次数 等;RPE 也可不带,UI 上 label 已说明)
  let formatStyle: FloatingPointFormatStyle<Double>  // 默认 .number.precision(.fractionLength(0...1))
  @Binding var isExpanded: Bool  // parent 控制单展开(同卡片只展开一个 wheel)

  init(
    label: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    unitLabel: String? = nil,
    formatStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...1)),
    isExpanded: Binding<Bool>
  )
}
```

**Layout(inline expand)**:

```
Collapsed(平时):                       Expanded(点开):
┌─────────────────────────┐            ┌─────────────────────────┐
│ 组数              3  ▾ │            │ 组数              3  ▴ │
└─────────────────────────┘            ├─────────────────────────┤
                                       │           1            │
                                       │           2            │
                                       │ ━━━━━━━ 3 ━━━━━━━━━   │ ← iOS Picker(.wheel)
                                       │           4            │
                                       │           5            │
                                       └─────────────────────────┘
```

- Collapsed 行:`Button { isExpanded.toggle() } label: { HStack { Text(label); Spacer(); Text(formattedValue); chevron } }` — 整行可点,大 hit area
- Chevron:`Image(systemName: isExpanded ? "chevron.up" : "chevron.down")` — `foregroundStyle(.secondary)`
- Expanded 时 collapsed 行不消失,wheel append 到行下方:
  ```swift
  if isExpanded {
    Picker("", selection: $value) {
      ForEach(values, id: \.self) { v in
        Text(formattedDisplay(v)).tag(v)
      }
    }
    .pickerStyle(.wheel)
    .frame(height: 150)
  }
  ```

**Behavior**:
- `values: [Double]` 由 `stride(from: range.lowerBound, through: range.upperBound, by: step)` 生成
- Picker 直接 bind `$value` — SwiftUI Picker(.wheel) 内置 snap-to-tag,滑动 / 松手都立即写 binding,**不需要** 额外 normalize / clamp / debounce
- 不接受任意输入(没有 TextField),也就 **没有** textInput / @FocusState / keyboard toolbar / decimalPad —— wheel 物理上只能停在合法值上
- 展开 / 收起由 parent 的 isExpanded binding 驱动(SwiftUI 动画自动 `.animation(.easeInOut(duration: 0.2), value: isExpanded)`,可加在 expanded `if` block 外)
- 外部 binding change(e.g., targetReps clamp targetRepsMax)→ wheel 自动 reflect 新 value(Picker 用 `selection: $value` 双向 sync)

**约束**:
- 不引入新依赖
- value Binding<Double> 跟 PlanningNumberField 一致(parent 调用方传 Double-wrapping binding;Int↔Double 转换在 parent)
- range/step 必须满足 `(range.upperBound - range.lowerBound).truncatingRemainder(dividingBy: step) == 0`(否则 stride 末尾跳过 upperBound),Codex 实装前断言或测试覆盖
- 若 init 时 value 落在 step grid 之外(e.g., legacy draft value = 7.3 但 range step=0.5)→ Picker 自动选中 nearest valid tag(SwiftUI 行为),不 crash;同时建议 parent 调用前用 `.planningRounded` snap 一次

**单展开模式(单卡片一次只展开一个)**:

parent (`ExerciseSetEditorCard`) 持:
```swift
private enum ExpandedField: Hashable {
  case setCount, targetReps, targetRepsMax, rpe
}
@State private var expandedField: ExpandedField?
```

每个 PlanningCountPicker 的 `isExpanded` 用如下 binding wrap:
```swift
PlanningCountPicker(
  label: "组数",
  value: $setCountDouble,
  range: 1...20,
  step: 1,
  isExpanded: Binding(
    get: { expandedField == .setCount },
    set: { expandedField = $0 ? .setCount : nil }
  )
)
```

效果:
- 点 "组数" 行 → expandedField = .setCount → 组数 wheel 展开
- 再点 "次数" 行 → expandedField = .targetReps → 组数 wheel 自动收起(组数 isExpanded == false),次数 wheel 展开
- 再点 "次数" 行(同一行)→ expandedField = nil → 次数 wheel 收起
- 点卡片外别处(card-level `.contentShape(.rect).onTapGesture { expandedField = nil }`)→ 全收起(可选,Codex 视视觉决定要不要加)

#### 2. 替换 Step 5 `ExerciseSetEditorCard` 4 处 Stepper(全部用 PlanningCountPicker)

**文件**: `Modules/CoachKit/Sources/CoachKit/Planning/Views/ExerciseSetEditorCard.swift`

新增 parent state(per §1.7 单展开模式):
```swift
private enum ExpandedField: Hashable {
  case setCount, targetReps, targetRepsMax, rpe
}
@State private var expandedField: ExpandedField?
```

| 现有 | 改为 |
|---|---|
| `CountStepper(title: "组数", value: $setCount, range: 1...20)`(line 60) | `PlanningCountPicker(label: "组数", value: $setCountDouble, range: 1...20, step: 1, isExpanded: .init(get: { expandedField == .setCount }, set: { expandedField = $0 ? .setCount : nil }))` + Int↔Double wrap binding |
| `CountStepper(title: "次数", value: $targetReps, range: 1...50)`(line 61) | 同上,label "次数",range 1...50,isExpanded → `.targetReps` case |
| `OptionalRepsMaxStepper(value: $targetRepsMax, minimum: targetReps)`(line 66) | PlanningCountPicker + Optional handling(下面说) |
| `Stepper(value: $value, in: 1...10, step: 0.5)` RPE(line 139) | `PlanningCountPicker(label: "RPE", value: $rpe, range: 1...10, step: 0.5, isExpanded: ... case .rpe)` |

**Optional reps max** 处理:跟原 spec 同样的 nil/value 二态 + clamp,只是控件换成 PlanningCountPicker:
- 如果 `targetRepsMax == nil`:显示 "+ 添加上限" Button(text button,点击后 `targetRepsMax = targetReps` + 自动展开)
- 如果 `targetRepsMax != nil`:显示 PlanningCountPicker(label "次数上限", range `Double(targetReps)...60`, step 1) + 旁边 ✕ 删除 Button 把 max 设回 nil
- 内部 binding wrap nil-vs-Int 转换(Double getter 返回 `Double(targetRepsMax ?? 0)`,setter 写回 `Int($0)`)
- `targetReps` change 同步 clamp `targetRepsMax`(per Codex review PR #52 finding #3,行为不变,只是控件换了 — wheel 接到新 binding value 自动 reflect)

**删除**: `ExerciseSetEditorCard.swift` 内 `private struct CountStepper` + `private struct OptionalRepsMaxStepper`(替换后无引用)

#### 3. 替换 Step 6 `ProgressionRuleEditorCard` 2 处 Stepper

**文件**: `Modules/CoachKit/Sources/CoachKit/Planning/Views/ProgressionRuleEditorCard.swift`

| 现有 | 改为 |
|---|---|
| `Stepper(value: incrementBinding, in: 0...100, step: incrementStep)`(line 98)| `PlanningNumberField(value: incrementBinding, range: 0...100, step: incrementStep, decimalIncrement: incrementDecimalStep, unitLabel: incrementUnitLabel)` |
| `Stepper(value: customValueBinding(index: index), in: 0...300, step: customStep)`(line 123) | `PlanningNumberField(value: customValueBinding(...), range: 0...300, step: customStep, decimalIncrement: customDecimalStep, unitLabel: customUnitLabel)` |

`unitLabel` 按 dimension 派生:
- weight → `"kg"`
- RPE → `"RPE"`(或 nil,因为 RPE 通常无 suffix)
- reps / sets → nil

step / decimalIncrement 沿用现 `incrementStep` / `customStep` / `incrementDecimalStep` / `customDecimalStep` private vars(不改)。

#### 4. 测试

新加**两个**测试文件:

**A. `Modules/CoachKit/Tests/CoachKitTests/Planning/PlanningNumberFieldTests.swift`(Swift Testing,@MainActor)** — 10 个 @Test(原 8 base + 2 lifecycle,**仅 PlanningNumberField API 行为**,不涉及具体 callsite):
- `planningNumberFieldTextFieldUpdateRoundsToIncrement` — 输 100.7 + step=0.5 → 失焦后 binding == 100.5
- `planningNumberFieldTextFieldClampsBelowRange` — 输 -5,range 0...100 → binding == 0
- `planningNumberFieldTextFieldClampsAboveRange` — 输 999,range 0...100 → binding == 100
- `planningNumberFieldEmptyInputResetsToZero` — 输 "" → binding == 0
- `planningNumberFieldIncrementButtonAddsStep` — value=100, step=2.5 → tap + → binding == 102.5
- `planningNumberFieldDecrementButtonSubtractsStep` — value=100, step=2.5 → tap - → binding == 97.5
- `planningNumberFieldIncrementDisabledAtUpperBound` — value=100, range upper=100 → + disabled
- `planningNumberFieldDecrementDisabledAtLowerBound` — value=0, range lower=0 → - disabled
- `planningNumberFieldTextInputSyncsOnExternalBindingChange` — value 外部从 100 变 200 + isFocused = false → textInput 跟着变 "200"(per §textInput 生命周期 #2)
- `planningNumberFieldIncrementButtonCommitsPendingTextFirst` — 用户打 "100" 还没失焦 + tap + → binding == 102.5(per §textInput 生命周期 #3,不是 oldValue+step)

**B. `Modules/CoachKit/Tests/CoachKitTests/Planning/PlanningCountPickerTests.swift`(Swift Testing,@MainActor)** — **5 个 @Test**(wheel 行为 + 单展开):
- `planningCountPickerInitialValueShowsInCollapsedLabel` — value=5 → collapsed label 行渲染含 "5"
- `planningCountPickerLabelTapTogglesIsExpandedBinding` — tap label row → isExpanded binding 从 false → true(再 tap → true → false)
- `planningCountPickerWheelSelectionWritesValueBinding` — programmatic select 7(via Picker selection) → binding == 7
- `planningCountPickerEnumeratesValuesByStepWithinRange` — range 1...10 step 0.5 → values 数组 == [1.0, 1.5, 2.0, ..., 10.0](19 个)
- `planningCountPickerExternalValueChangeSyncsWheelSelection` — value 外部从 5 → 8(模拟 targetReps clamp targetRepsMax 场景) → Picker selection 跟着 8

ViewInspector 用法参考现有 `weightInputFieldShowsPercentConversionWhenOneRMExists` test;wheel picker 的 ViewInspector pattern 见 [ViewInspector docs](https://github.com/nalexn/ViewInspector) §Picker section,主要 `inspect().picker()` + 模拟 selection 写入。

现有测试 update:
- `Step5IntensityViewModelTests.swift` 内 hardcode "Stepper" / "CountStepper" 引用 → 改 "PlanningCountPicker"
- `Step6ProgressionRulesViewModelTests.swift` 内 hardcode "Stepper" 引用 → 改 "PlanningNumberField"
- 行为测试(value binding round-trip)应自然过(value 类型 + clamp 行为对调用方等价)

#### 5. spec 020 CHECKLIST.md happy path 不破

15 步 happy path 走完仍 100% 通过。Step 5 + Step 6 内部 input UI 视觉差异是 expected,不算 regression。

### 不做什么

| ❌ 留 spec / 留 follow-up |
|---|
| **抽 PlanningNumberField / PlanningCountPicker 到 DesignSystem 模块** — V0 仅 CoachKit/Planning 用;V0.1+ 学员端 SetRecord / 视频记录 可能复用,届时 promote |
| **改 Step 5 W1 重量 WeightInputField** — 已是 TextField + 段控 pattern,UX 已 OK |
| **改 ProgressionRuleType / Dimension picker** — 不在本 spec 范围 |
| **改 Step 0-3 / Step 4 / Step 7** — 无 numeric stepper 友 friction(Step 4 facet chip / Step 7 周卡片横滑都是不同交互)|
| ~~加 keyboard "Done" toolbar 按钮~~ — **2026-05-13 移到 §做什么 #1.5**(per Codex review PR #52 finding #2) |
| **改 ExerciseSetEditorCard intensityMode toggle** — 段控 OK |
| **CoreModels / Repository / 业务逻辑** — 仅 View 层 input 替换,model + state machine 不动 |
| **改 spec 022 已合的 InMemoryPlanRepository / catalog JSON** — 0 干扰 |

## 技术要求

### Layout sketch — PlanningNumberField(Step 6 sandwich)

iPhone 17 Pro Max width = 430pt;Step 6 卡片内宽估 ~370pt。Layout C 横向布局:

```
[ Eyebrow label "每周加" ]
[ - 28pt ] [ TextField 70pt ] [ + 28pt ]   [ unit label "kg" ~ 20pt ]
   |         center align        |
   |         decimal pad         |
   ↓                              ↓
   spacing 8pt                    spacing 6pt
```

- `-` Button: `Image(systemName: "minus")` 14pt + `frame(width: 28, height: 28)` + circle background
- TextField: `frame(width: 70)` + `multilineTextAlignment(.center)` + monospacedDigit + `padding(MeetPRSpacing.sm)` + `background(Color.MeetPR.surface2)` + `clipShape(.rect(cornerRadius: MeetPRRadius.sm))`
- `+` Button: 同 -

或 stacked layout(若 horizontal 卡片内挤):

```
[ Eyebrow label "每周加" ]
[ - ] [   TextField   ] [ + ]   kg
```

实装时 Codex 跑 simulator visual sanity:不严重 overflow / 不挤 / 字号可读。

### Layout sketch — PlanningCountPicker(Step 5 inline-expand wheel)

iPhone 17 Pro Max width = 430pt;Step 5 卡片内宽估 ~370pt。

Collapsed 行(整行可点,大 hit area):

```
┌─────────────────────────────────────┐
│ 组数                       3   ▾   │   height ~44pt(iOS HIG min tap target)
└─────────────────────────────────────┘
   ↑                          ↑   ↑
   left padding 16pt        value chevron
                            font: .body  monospacedDigit
                            color: .primary
```

Expanded(行下面 append wheel):

```
┌─────────────────────────────────────┐
│ 组数                       3   ▴   │
├─────────────────────────────────────┤
│                  1                  │
│                  2                  │
│ ━━━━━━━━━━━━━━━ 3 ━━━━━━━━━━━━━━━ │   height = 150pt(iOS Picker default)
│                  4                  │
│                  5                  │
└─────────────────────────────────────┘
```

- Collapsed 行:`HStack { Text(label).font(.body); Spacer(); Text(formattedValue).font(.body).monospacedDigit().foregroundStyle(.primary); chevronImage.foregroundStyle(.secondary) }` 全包在 `Button`,`.contentShape(.rect)` 整行可点
- Chevron:`Image(systemName: isExpanded ? "chevron.up" : "chevron.down")` size 12pt
- Wheel:`Picker("", selection: $value) { ForEach(values, id: \.self) { Text(formattedDisplay($0)).tag($0) } }.pickerStyle(.wheel).frame(height: 150)`
- 展开 / 收起加 `.animation(.easeInOut(duration: 0.2), value: isExpanded)` 平滑过渡
- 多个 PlanningCountPicker 在同卡片中纵向堆叠(组数 / 次数 / 次数上限 / RPE 四行),展开时只长这一行,其他行不动

实装时 Codex 跑 simulator visual sanity:wheel 展开 / 收起动画无 layout jank;切换字段(组数 → 次数)时旧 wheel 收 + 新 wheel 展开应顺滑(SwiftUI default animation 应该自动处理)。

### Optional reps max 处理(Step 5,用 PlanningCountPicker)

`OptionalRepsMaxStepper` 当前是 nil/value 二态。本 spec 改为:

```swift
if targetRepsMax == nil {
  Button("+ 添加上限") {
    targetRepsMax = targetReps
    expandedField = .targetRepsMax  // 加完即展开 wheel,省一次 tap
  }
} else {
  HStack {
    PlanningCountPicker(
      label: "次数上限",
      value: Binding(
        get: { Double(targetRepsMax ?? 0) },
        set: { targetRepsMax = Int($0) }
      ),
      range: Double(targetReps)...60,
      step: 1,
      isExpanded: Binding(
        get: { expandedField == .targetRepsMax },
        set: { expandedField = $0 ? .targetRepsMax : nil }
      )
    )
    Button(role: .destructive) {
      targetRepsMax = nil
      if expandedField == .targetRepsMax { expandedField = nil }
    } label: {
      Image(systemName: "xmark.circle.fill")
    }
  }
}
```

**`targetReps` change 时同步 clamp `targetRepsMax`**(per Codex review PR #52 finding #3 — 用户先 reps=10 + max=15,改 reps=20 → 此时 max=15 < reps,SPEC 之前没说怎么处理):

```swift
.onChange(of: targetReps) { _, newReps in
  if let currentMax = targetRepsMax, currentMax < newReps {
    targetRepsMax = newReps  // raise max to match new reps floor
  }
  // 若 currentMax 仍 ≥ newReps,不动(用户已设的 max 仍合理)
  // wheel binding 接到新 value 自动 reflect — Picker(.wheel) 内置 selection 同步
}
```

不缩 max 上限(60)— 上限是产品层选定的硬封顶,reps 涨了 max 也只在 reps...60 范围内动。

### CountStepper / OptionalRepsMaxStepper 删除

确认无其他引用后删 private struct(grep `CountStepper` / `OptionalRepsMaxStepper` 仅 ExerciseSetEditorCard 内)。

### KeyboardType + Submit Label(仅 PlanningNumberField,Step 6 sandwich)

> ⚠️ PlanningCountPicker(Step 5)**没有 TextField / 没有键盘**(wheel-only),本节不适用。

- 数字 input(Step 6 weekly increment / custom 周值):`.keyboardType(.decimalPad)`
- 失焦或 keyboard toolbar Done tap 触发 normalize(parse → round → clamp → write Binding → sync textInput),per §做什么 #1.5
- **输入中只更新 `textInput` 内部 @State,**不动 binding**(per Codex review PR #52 second-pass BLOCKER #1 — 之前写的"binding 实时更新"跟新行为矛盾,会重新引入 mid-typing round bug)
- binding 写入仅发生在三个 commit 点:① 失焦 ② keyboard toolbar Done tap ③ `+` / `-` button tap(具体路径见 §技术要求 §textInput 生命周期)

### textInput 生命周期(仅 PlanningNumberField,per Codex review PR #52 second-pass BLOCKER #2)

引入 `@State textInput` 后,必须明确以下 4 个 sync 点(否则 textInput 跟外部 binding 漂移):

1. **初始化**(组件首次 render):`init` 时 `_textInput = State(initialValue: formattedDisplay(value.wrappedValue))`,用同一个 display formatter(`.number.precision(.fractionLength(0...1))`)生成初始字符串
2. **外部 binding 改变 + 用户没在打字**:`.onChange(of: value) { _, newValue in if !isFocused { textInput = formattedDisplay(newValue) } }` — 防止 ProgressionRuleEditorCard `syncFromViewModel()` async save 后或 ExerciseSetEditorCard `targetReps` clamp 后 textInput 还是旧值(注:`@Binding var value: Double` 在 view body 内 `value` 已是 `Double`;init/property-wrapper 上下文才用 `value.wrappedValue`)
3. **`+` / `-` button tap**:**先 commit 当前 textInput**(走 normalize)再 apply ±step,否则用户刚打完"100"还没失焦就 tap `+`,会用旧 binding value 计算成 `oldValue + step` 而不是 `100 + step`。实装:
   ```swift
   private func incrementTapped() {
     normalize()  // commit textInput first
     let next = min(value + step, range.upperBound)
     value = next
     textInput = formattedDisplay(next)
   }
   ```
4. **失焦 / Done tap**:走 `normalize()` 流程(parse → round → clamp → write Binding → sync textInput)— 同 §Behavior

> 测试覆盖已在 §做什么 #4 List A `PlanningNumberFieldTests.swift` 后 2 项(`...TextInputSyncsOnExternalBindingChange` / `...IncrementButtonCommitsPendingTextFirst`)。

### Accessibility

**PlanningNumberField(Step 6 sandwich)**:
- VoiceOver 读 "value: 100, kg, adjustable"
- `+` / `-` Button 加 `.accessibilityLabel("增加" / "减少")`
- 整体 group 用 `.accessibilityElement(children: .combine)` 或 `.accessibilityRepresentation { Stepper(...) }`(替代物语义)

**PlanningCountPicker(Step 5 wheel)**:
- Collapsed 行的 Button 加 `.accessibilityLabel("\(label) \(formattedValue), \(isExpanded ? "已展开" : "未展开")")`,VoiceOver 读出当前 label / value / 状态
- Wheel 本身用 SwiftUI 内置 `Picker` accessibility(VoiceOver 滑动选项 / 朗读 selected,SwiftUI 自动处理)
- 展开 / 收起触发 `.accessibilityAnnouncement` 朗读 "组数已展开,可上下滑选" / "组数已收起"(可选,Codex 视体验决定)

## 验收清单

- [ ] `Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningNumberField.swift` 创建,public API 跟 §做什么 #1 一致
- [ ] `Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningCountPicker.swift` 创建,public API 跟 §做什么 #1.7 一致
- [ ] `Modules/CoachKit/Tests/CoachKitTests/Planning/PlanningNumberFieldTests.swift` 创建,**10 个 @Test** 全过(per §做什么 #4 List A — 原 8 base + 2 lifecycle)
- [ ] `Modules/CoachKit/Tests/CoachKitTests/Planning/PlanningCountPickerTests.swift` 创建,**5 个 @Test** 全过(per §做什么 #4 List B — wheel 选值 / 单展开 / external sync)
- [ ] `ExerciseSetEditorCard.swift` 4 处 Stepper / CountStepper / OptionalRepsMaxStepper 替换为 **PlanningCountPicker**(per §做什么 #2 + §技术要求 §单展开 ExpandedField enum)
- [ ] `ExerciseSetEditorCard.swift` 删除 `private struct CountStepper` + `private struct OptionalRepsMaxStepper`(grep 确认无其他引用)
- [ ] `ProgressionRuleEditorCard.swift` 2 处 Stepper 替换为 **PlanningNumberField**(per §做什么 #3)
- [ ] `swift test --parallel` 在 `Modules/CoachKit` 全绿(含新 15 个 = 10 NumberField + 5 CountPicker + 现有测试)
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` iPhone 17 simulator 跑通,Step 5 + Step 6 visual sanity:
   - Step 5 wheel collapsed/expanded 切换顺滑,展开高度 ~150pt 无 layout jank;切换字段时旧 wheel 收 + 新 wheel 展开 animation 不撕裂
   - Step 6 sandwich 控件不严重 overflow / 字号可读 / `-` / `+` Button hit area ≥ 28pt
- [ ] spec 020 CHECKLIST.md 15 步 manual happy path 全过
- [ ] `swiftlint lint --strict` + `swift-format lint` 通过(注意 swiftlint identifier_name — `value` 5 字符 OK,但 `step` 4 字符 < 5 也 OK,内部 `kg` 等 < 3 字符要 disable comment)
- [ ] F-015 红线 grep 0 命中(本 spec 不涉及 coach planning 设计层)
- [ ] `specs/023-planning-numeric-input/SPEC.md` 状态 `Draft` → `Done` + PR 字段填本 PR 链接(同 impl PR 内,per AGENTS.md §交付检查清单)
- [ ] **CLAUDE.md "当前完成态" 段加 spec 023 一行** — per AGENTS.md §例外:spec impl PR 的 CLAUDE.md 当前完成态段 sync(PR #53 已合 main,本规则 live)

## 估时(给 Codex 参考)

- `PlanningNumberField` View 实装(layout C + binding + clamp + round + textInput lifecycle):1.5 小时
- `PlanningNumberFieldTests.swift` 10 个 @Test:1 小时 15 分
- `PlanningCountPicker` View 实装(wheel + inline expand + values stride):**1 小时**
- `PlanningCountPickerTests.swift` 5 个 @Test:**45 分钟**
- `ExerciseSetEditorCard.swift` 替换 4 处 + 删 2 个 private struct + Optional reps max 处理 + ExpandedField enum + binding wrap:1.5 小时
- `ProgressionRuleEditorCard.swift` 替换 2 处 + unit label 派生:30 分钟
- `xcodebuildmcp build_run_sim` 视觉 sanity check + wheel animation 微调 + 修 layout iterate:1.5 小时
- buffer:1 小时(SwiftUI focus state edge case / wheel snap edge case / Picker(.wheel) in ScrollView 行为 / accessibility VoiceOver 测)

总:**~9 小时** Codex session(原 sandwich-only ~6h,加 wheel 组件 +3h)

## 风险 / 待 implementer 关注

**PlanningNumberField 相关(Step 6)**:

1. **TextField focus + onChange 时机** — `.onChange(of: value)` 在每次按键时触发(包括打 "1" → "10" → "100" 中间态)。round + clamp **必须延迟到失焦**,否则用户打"100" 时中间"1"/"10"会被 round → 不可用。建议:用 `@FocusState` + `.onChange(of: focusState)` 在失焦时 normalize
2. **Decimal pad 没小数点(e.g., 中文键盘 . 在某些 locale 不显示)** — `.keyboardType(.decimalPad)` 在简体中文 locale 应该有 .,但若发现没,fallback `.numbersAndPunctuation`
3. **`-` / `+` Button hit area** — 28pt 偏小,iOS HIG 推荐 ≥ 44pt。可用 `.contentShape(.rect)` 扩大 hit area 不改视觉
4. **swift-format / swiftlint 对 PlanningNumberField init 多参数** — 7 参数可能触 `function_parameter_count` lint。考虑 builder pattern 或 `// swiftlint:disable:next`

**PlanningCountPicker 相关(Step 5)**:

5. **Picker(.wheel) 在 ScrollView / Form 内行为** — Step 5 整屏是 ScrollView,wheel 是 vertical scroll 控件,**嵌套 vertical scroll 可能冲突**(用户拖 wheel 时外层 ScrollView 跟着滚)。SwiftUI Picker(.wheel) 已知会自己拦截 vertical drag(应该 OK),但 Codex 跑 simulator 验证;若有冲突 → 加 `.scrollDisabled(true)` 在 wheel 容器外 / 或换 `.simultaneousGesture` 拦截
6. **单展开 ExpandedField enum 跨字段状态机** — 4 个 PlanningCountPicker 共享 parent 一个 `@State expandedField: ExpandedField?`,字段切换时 wheel A 收 + wheel B 展开同帧发生,SwiftUI 动画可能撕裂。Codex 实装时观察,可加 `withAnimation(.easeInOut(duration: 0.2))` 包裹 setter,或显式 sequence(A 收 → 短延迟 → B 展)
7. **Optional reps max nil ↔ value 切换** — 点 "+ 添加上限" 后 `targetRepsMax = targetReps` 同时 `expandedField = .targetRepsMax`,wheel 应 immediate render expanded。Codex 跑 simulator 验。若严重撕裂 → NOTES.md 留 small follow-up
8. **wheel value 落在 step grid 外** — legacy draft 万一存了 targetReps=7.3(理论不该,但防御):init 时 Picker 自动 select nearest tag(SwiftUI 行为),不 crash;但若担心 → parent 调用前用 `.planningRounded(_:increment:)` snap

**通用**:

9. **F-015 grep 自检**:见 [FOLLOWUPS.md F-015](../../FOLLOWUPS.md) 完整 forbidden term list — Codex 实操 grep 时**排除 SPEC.md 自身**(`rg -g '!specs/023-planning-numeric-input/SPEC.md' <terms>`),否则本 spec 引用 F-015 的 metadata 行会自检失败(per Codex review PR #52 finding #5)。本 spec 不涉及 coach planning 设计层,实际 Swift / 测试代码自然 0 命中
10. **现有 Step5IntensityViewModelTests / Step6ProgressionRulesViewModelTests** — 多数测 ViewModel 行为(非 UI),应自然不破。若有 ViewInspector 测 Stepper 渲染的,Step 5 改 PlanningCountPicker / Step 6 改 PlanningNumberField

## PR 间依赖

- ~~**PR #53 必须先 merge into main**~~ — **已解除**(PR #53 已合 main, commit `ab7a504`,2026-05-13)。本 spec 023 impl PR 可直接同 PR sync CLAUDE.md "当前完成态" 段,per AGENTS.md §例外:spec impl PR 的 CLAUDE.md 同 PR sync 允许。

## 上游 / 下游

- **上游**(本 spec 落地依赖):
  - 已合 spec 005-007(Step 5/6/7 view 在,本 spec 改它们内部 input UI)
  - 已合 spec 022 catalog v2 import(0 干扰本 spec)
  - PlanningDecimal helpers(planningRounded / roundedToPlanningIncrement)直接复用
- **下游**(本 spec 落地后启用):
  - V0 demo dogfood / TestFlight 内测体验改善:
    - Step 5 组数/次数/次数上限/RPE 由 ±step tap → 滑转盘到位,无需键盘(常用 3→12 由 9 次点 → 1 滑)
    - Step 6 weekly increment / custom 周值 由 ±step tap → 打字直接到目标(100kg 由 40 次 +→ 1 type)
  - V0.1+ 学员端 SetRecord(PRD §5 #13)若也用 numeric input,可复用 PlanningNumberField + PlanningCountPicker(+ promote 到 DesignSystem 候选)
  - V0.1+ 起新 spec 加 keyboard toolbar "Done" / "Next field" navigation(若用户反馈)
  - V0.1+ 起新 spec 加 keyboard toolbar "Done" / "Next field" navigation(若用户反馈)

## 修订记录

- 2026-05-13: 创建(Draft)。Claude 起草, Codex 接力实装。触发:用户 dogfood Step 6 custom 规则 W2/W3/W4 重量值 ~120 tap friction 反馈;layout 决策 C(`[ - ] [ TextField ] [ + ]` 沙拼)+ Step 5 set count / 次数 / RPE / repsMax 顺带改。
- 2026-05-13 amendment(per Codex review PR #52,5 个 findings 全采纳):
  - **#1**:`@State` 禁约束放开 — 加内部 `@State private var textInput: String` + `@FocusState`,mid-typing 缓冲文本,只在失焦/Done commit 到 Binding(原"无 @State"约束 over-restrictive)
  - **#2**:keyboard toolbar Done button 从 §不做什么 移到 §做什么 #1.5(`.decimalPad` 没 Return 键,blur 仅靠点别处不可靠)
  - **#3**:Optional reps max 加 `.onChange(of: targetReps)` 同步 clamp `targetRepsMax`(用户 reps=10+max=15→reps=20 时 max 升到 reps)
  - **#4**:CLAUDE.md sync 验收项加 cross-link 到 PR #53 即将加的 §Review 矩阵 spec impl PR sync exception
  - **#5**:F-015 grep 自检改 reference FOLLOWUPS.md 不 inline 列 forbidden terms,加 `rg -g '!specs/023-.../SPEC.md'` exclude self
- 2026-05-13 amendment 2(per Codex re-review PR #52 second pass,2 BLOCKER + 1 P2 全采纳):
  - **BLOCKER #1**:删旧 KeyboardType 段 "输入中 binding 实时更新" 矛盾文本,改为 "输入中只更新 textInput,不动 binding;commit 仅在失焦/Done/+/- tap 三个点"
  - **BLOCKER #2**:加新 §技术要求 §textInput 生命周期 段,明确 4 个 sync 点(init / 外部 binding change + !isFocused / +-button commit 当前 textInput 后再 step / 失焦 normalize)+ 加 2 个新 @Test(external sync / increment-commits-pending-text)
  - **P2**:验收清单 "CLAUDE.md sync" 项加 ⚠️ "依赖 PR #53 先合"标注,新加 §PR 间依赖 段说明 Codex impl 顺序判断逻辑
- 2026-05-13 amendment 3(用户 dogfood feedback after spec PR #52 合 main + Demo build dogfood Step 5):**按场景分两个控件**
  - 用户截图反馈 Step 5 组数 / 次数 ±step CountStepper 慢,要求"上下滑动选择" = iOS 转盘 picker(inline 展开 pattern)
  - 分析:窄范围整数(组数 1-20 / 次数 1-50 / 次数上限 / RPE 1-10 步 0.5)用转盘 wins;范围宽 decimal(weight 0-300 / 增量 0-100)用 sandwich wins
  - 决策:新加 `PlanningCountPicker` 用于 Step 5 内 4 处 input;原 `PlanningNumberField` 缩小 scope 到 Step 6 内 2 处(weekly increment / custom 周值)
  - 影响:
    - §做什么 #1 PlanningNumberField scope 加 "for Step 6 范围宽 decimal" 注
    - 新加 §做什么 #1.7 PlanningCountPicker(API / Layout / Behavior / 约束 / 单展开模式)
    - §做什么 #2 ExerciseSetEditorCard 替换 全 PlanningCountPicker(原 PlanningNumberField → PlanningCountPicker)
    - §做什么 #4 测试 拆 List A PlanningNumberFieldTests(10) + List B PlanningCountPickerTests(5),共 15 个新 @Test
    - §技术要求 加 "Layout sketch — PlanningCountPicker(inline-expand wheel)" + §单展开 ExpandedField enum 模式
    - §Optional reps max 处理 改用 PlanningCountPicker code 示例
    - §KeyboardType + textInput 生命周期 段加 "仅 PlanningNumberField" scope 标注(wheel 无键盘)
    - §Accessibility 拆两个组件分别说
    - §估时 +3h(总 6h → 9h)
    - §风险 拆 NumberField / CountPicker 分类,新加 5 / 6 / 7 / 8 项 wheel 特定风险
    - §PR 间依赖 中 PR #53 依赖 strike-through(已合)
    - §下游 改 "120 tap → 1 type" → "Step 5 滑转盘 + Step 6 打字" 两路改善
