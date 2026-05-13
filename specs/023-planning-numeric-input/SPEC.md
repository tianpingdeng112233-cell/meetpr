# 023 — Planning numeric input(replace bare Stepper with `[ - ] [ TextField ] [ + ]` sandwich)

- **状态**: Draft
- **PR**: TBD
- **触发**: User 2026-05-13 dogfood 反馈 — Step 6 custom 规则 W2/W3/W4 重量值 Stepper-only 设到 100kg 要 ~40 次点,300kg 要 ~120 次点,极不顺手。Step 5 set count / 次数 / RPE / repsMax stepper 同问题(范围小但同 friction)。Layout 决策 (C):**Stepper 拆 -/+ 包夹 TextField**(用户拍板)
- **来源**:
  - 已合 [spec 005-007](../) coach planning Step 0-7(本 spec 改 Step 5 ExerciseSetEditorCard + Step 6 ProgressionRuleEditorCard 内部 input UI,**不动** state machine / business logic)
  - [WeightInputField.swift](../../Modules/CoachKit/Sources/CoachKit/Planning/Views/WeightInputField.swift) — Step 5 W1 重量已是 TextField + 段控 pattern,**本 spec 不改它**(已 OK)
  - [PlanningDecimal.swift](../../Modules/CoachKit/Sources/CoachKit/Planning/State/PlanningDecimal.swift) — `.planningRounded(_:increment:)` / `.roundedToPlanningIncrement(_:)` helpers 复用

## 目标

把 Step 5 + Step 6 内部 6 处 bare `Stepper` 替换成新组件 **`PlanningNumberField`**,layout = `[ - ] [ TextField ] [ + ]`(用户决策 layout C)。

教练能感知的差异:
- **打字直接到目标**:Step 6 W2 = 100kg 由"按 40 次 +" → "打 100";custom W2/W3/W4 长 sequence 同样
- **Stepper 微调还在**:旁边 -/+ button 仍可点,微调 ±2.5kg / ±0.5RPE / ±1 reps&sets 不丢
- **Step 5 set count / 次数 / RPE / repsMax** 同 pattern,统一 input 体验

不改:Step 5 W1 重量(WeightInputField 已是 TextField pattern,UX OK);其他 view 内 stepper(无)。

## 范围

### 做什么

#### 1. 新加 `PlanningNumberField` View

**位置**: `Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningNumberField.swift`(feature-local, V0.1+ 视复用需要再 promote 到 DesignSystem)

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

#### 2. 替换 Step 5 `ExerciseSetEditorCard` 4 处 Stepper

**文件**: `Modules/CoachKit/Sources/CoachKit/Planning/Views/ExerciseSetEditorCard.swift`

| 现有 | 改为 |
|---|---|
| `CountStepper(title: "组数", value: $setCount, range: 1...20)`(line 60) | `PlanningNumberField(value: $setCountAsDouble, range: 1...20, step: 1, decimalIncrement: .whole, unitLabel: nil)` + double ↔ Int 转换 binding |
| `CountStepper(title: "次数", value: $targetReps, range: 1...50)`(line 61) | 同上,range 1...50 |
| `OptionalRepsMaxStepper(value: $targetRepsMax, minimum: targetReps)`(line 66) | `PlanningNumberField(...)` + Optional handling(下面说) |
| `Stepper(value: $value, in: 1...10, step: 0.5)` RPE(line 139) | `PlanningNumberField(value: $rpe, range: 1...10, step: 0.5, decimalIncrement: .half, unitLabel: nil)` |

**Optional reps max** 处理:复杂一点,UI 可能要保留"添加上限"toggle + 出现 PlanningNumberField。建议:
- 如果 `targetRepsMax == nil`:显示 "+ 添加上限" Button
- 如果 `targetRepsMax != nil`:显示 PlanningNumberField + 删除按钮把 max 设回 nil
- 内部 binding wrap nil-vs-Int 转换

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

新加 `Modules/CoachKit/Tests/CoachKitTests/Planning/PlanningNumberFieldTests.swift`(Swift Testing,@MainActor):
- `planningNumberFieldTextFieldUpdateRoundsToIncrement` — 输 100.7 + step=0.5 → 失焦后 binding == 100.5
- `planningNumberFieldTextFieldClampsBelowRange` — 输 -5,range 0...100 → binding == 0
- `planningNumberFieldTextFieldClampsAboveRange` — 输 999,range 0...100 → binding == 100
- `planningNumberFieldEmptyInputResetsToZero` — 输 "" → binding == 0
- `planningNumberFieldIncrementButtonAddsStep` — value=100, step=2.5 → tap + → binding == 102.5
- `planningNumberFieldDecrementButtonSubtractsStep` — value=100, step=2.5 → tap - → binding == 97.5
- `planningNumberFieldIncrementDisabledAtUpperBound` — value=100, range upper=100 → + disabled
- `planningNumberFieldDecrementDisabledAtLowerBound` — value=0, range lower=0 → - disabled

ViewInspector 用法参考现有 `weightInputFieldShowsPercentConversionWhenOneRMExists` test(InMemoryAccessoryRepositoryTests / weightInputField tests 已有 ViewInspector pattern)。

现有测试 update:
- `Step5IntensityViewModelTests.swift` 内若有 hardcode "Stepper" reference → 改 "PlanningNumberField"
- `Step6ProgressionRulesViewModelTests.swift` 同上
- 行为测试(value binding round-trip)应自然过

#### 5. spec 020 CHECKLIST.md happy path 不破

15 步 happy path 走完仍 100% 通过。Step 5 + Step 6 内部 input UI 视觉差异是 expected,不算 regression。

### 不做什么

| ❌ 留 spec / 留 follow-up |
|---|
| **抽 PlanningNumberField 到 DesignSystem 模块** — V0 仅 CoachKit/Planning 用;V0.1+ 学员端 SetRecord 可能复用,届时 promote |
| **改 Step 5 W1 重量 WeightInputField** — 已是 TextField + 段控 pattern,UX 已 OK |
| **改 ProgressionRuleType / Dimension picker** — 不在本 spec 范围 |
| **改 Step 0-3 / Step 4 / Step 7** — 无 numeric stepper 友 friction(Step 4 facet chip / Step 7 周卡片横滑都是不同交互)|
| ~~加 keyboard "Done" toolbar 按钮~~ — **2026-05-13 移到 §做什么 #1.5**(per Codex review PR #52 finding #2) |
| **改 ExerciseSetEditorCard intensityMode toggle** — 段控 OK |
| **CoreModels / Repository / 业务逻辑** — 仅 View 层 input 替换,model + state machine 不动 |
| **改 spec 022 已合的 InMemoryPlanRepository / catalog JSON** — 0 干扰 |

## 技术要求

### Layout sketch(详细)

iPhone 17 Pro Max width = 430pt;Step 5/Step 6 卡片内宽估 ~370pt。Layout C 横向布局:

```
[ Eyebrow label "组数" ]
[ - 28pt ] [ TextField 70pt ] [ + 28pt ]   [ unit label ~ 20pt ]
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
[ Eyebrow label "组数" ]
[ - ] [   TextField   ] [ + ]
```

实装时 Codex 跑 simulator visual sanity:不严重 overflow / 不挤 / 字号可读。

### Optional reps max 处理(Step 5)

`OptionalRepsMaxStepper` 当前是 nil/value 二态。本 spec 改为:

```swift
if targetRepsMax == nil {
  Button("+ 添加上限") { targetRepsMax = targetReps }
} else {
  HStack {
    PlanningNumberField(
      value: Binding(
        get: { Double(targetRepsMax ?? 0) },
        set: { targetRepsMax = Int($0) }
      ),
      range: Double(targetReps)...60,
      step: 1,
      decimalIncrement: .whole,
      unitLabel: nil
    )
    Button(role: .destructive) { targetRepsMax = nil } label: {
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
}
```

不缩 max 上限(60)— 上限是产品层选定的硬封顶,reps 涨了 max 也只在 reps...60 范围内动。

### CountStepper / OptionalRepsMaxStepper 删除

确认无其他引用后删 private struct(grep `CountStepper` / `OptionalRepsMaxStepper` 仅 ExerciseSetEditorCard 内)。

### KeyboardType + Submit Label

- 数字 input(weight / RPE / reps / sets):`.keyboardType(.decimalPad)`
- 失焦或 keyboard toolbar Done tap 触发 normalize(parse → round → clamp → write Binding → sync textInput),per §做什么 #1.5
- **输入中只更新 `textInput` 内部 @State,**不动 binding**(per Codex review PR #52 second-pass BLOCKER #1 — 之前写的"binding 实时更新"跟新行为矛盾,会重新引入 mid-typing round bug)
- binding 写入仅发生在三个 commit 点:① 失焦 ② keyboard toolbar Done tap ③ `+` / `-` button tap(具体路径见 §技术要求 §textInput 生命周期)

### textInput 生命周期(per Codex review PR #52 second-pass BLOCKER #2)

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

测试覆盖(加进 §做什么 #4 现有 8 测试):
- `planningNumberFieldTextInputSyncsOnExternalBindingChange` — value 外部从 100 变 200(模拟 viewmodel save) + isFocused = false → textInput 跟着变成 "200"
- `planningNumberFieldIncrementButtonCommitsPendingTextFirst` — 用户打 "100" 还没失焦 + tap + → binding == 102.5(不是 oldValue+step)

### Accessibility

- VoiceOver 读 "value: 100, kg, adjustable"
- `+` / `-` Button 加 `.accessibilityLabel("增加" / "减少")`
- 整体 group 用 `.accessibilityElement(children: .combine)` 或 `.accessibilityRepresentation { Stepper(...) }`(替代物语义)

## 验收清单

- [ ] `Modules/CoachKit/Sources/CoachKit/Planning/Views/PlanningNumberField.swift` 创建,public API 跟 §做什么 #1 一致
- [ ] `Modules/CoachKit/Tests/CoachKitTests/Planning/PlanningNumberFieldTests.swift` 创建,10 个 @Test 全过(per §做什么 #4 原 8 个 + §textInput 生命周期 新增 2 个 lifecycle test)
- [ ] `ExerciseSetEditorCard.swift` 4 处 Stepper / CountStepper / OptionalRepsMaxStepper 替换为 PlanningNumberField
- [ ] `ExerciseSetEditorCard.swift` 删除 `private struct CountStepper` + `private struct OptionalRepsMaxStepper`(grep 确认无其他引用)
- [ ] `ProgressionRuleEditorCard.swift` 2 处 Stepper 替换为 PlanningNumberField
- [ ] `swift test --parallel` 在 `Modules/CoachKit` 全绿(含新 10 个 + 现有测试)
- [ ] `xcodebuildmcp build_run_sim Scheme=MeetPR-Demo` iPhone 17 simulator 跑通,Step 5 + Step 6 visual sanity:input 控件不严重 overflow / 字号可读 / `-` / `+` Button hit area ≥ 28pt
- [ ] spec 020 CHECKLIST.md 15 步 manual happy path 全过
- [ ] `swiftlint lint --strict` + `swift-format lint` 通过(注意 swiftlint identifier_name — `value` 5 字符 OK,但 `step` 4 字符 < 5 也 OK,内部 `kg` 等 < 3 字符要 disable comment)
- [ ] F-015 红线 grep 0 命中(本 spec 不涉及 coach planning 设计层)
- [ ] `specs/023-planning-numeric-input/SPEC.md` 状态 `Draft` → `Done` + PR 字段填本 PR 链接(同 impl PR 内,per AGENTS.md §交付检查清单)
- [ ] **CLAUDE.md "当前完成态" 段加 spec 023 一行** — ⚠️ **依赖 PR #53 先 merge into main**(PR #53 加的 §Review 授权矩阵 spec impl PR sync exception 必须 live;若 PR #53 未合,本项 process 冲突,Codex impl PR 应 deferred 此 sync 直到 PR #53 合后另起小 chore PR);per 2026-05-10 lesson + Codex review PR #52 finding #4 + second-pass P2

## 估时(给 Codex 参考)

- `PlanningNumberField` View 实装(layout C + binding + clamp + round):1.5 小时
- `PlanningNumberFieldTests.swift` 10 个 @Test:1 小时 15 分
- `ExerciseSetEditorCard.swift` 替换 4 处 + 删 2 个 private struct + Optional reps max 处理:1 小时
- `ProgressionRuleEditorCard.swift` 替换 2 处 + unit label 派生:30 分钟
- `xcodebuildmcp build_run_sim` 视觉 sanity check + 修微调(布局可能需要 iterate):1 小时
- buffer:1 小时(SwiftUI focus state edge case / decimalPad 行为差异 / accessibility VoiceOver 测)

总:**~6 小时** Codex session

## 风险 / 待 implementer 关注

1. **TextField focus + onChange 时机** — `.onChange(of: value)` 在每次按键时触发(包括打 "1" → "10" → "100" 中间态)。round + clamp **必须延迟到失焦**,否则用户打"100" 时中间"1"/"10"会被 round → 不可用。建议:用 `@FocusState` + `.onChange(of: focusState)` 在失焦时 normalize
2. **Decimal pad 没小数点(e.g., 中文键盘 . 在某些 locale 不显示)** — `.keyboardType(.decimalPad)` 在简体中文 locale 应该有 .,但若发现没,fallback `.numbersAndPunctuation`
3. **Optional reps max 状态切换** — nil → value 切换时 TextField focus 行为可能怪。Codex 跑 simulator 验,若严重 → NOTES.md 留 small follow-up
4. **`-` / `+` Button hit area** — 28pt 偏小,iOS HIG 推荐 ≥ 44pt。可用 `.contentShape(.rect)` 扩大 hit area 不改视觉
5. **swift-format / swiftlint 对 PlanningNumberField init 多参数** — 7 参数可能触 `function_parameter_count` lint。考虑 builder pattern 或 `// swiftlint:disable:next`
6. **F-015 grep 自检**:见 [FOLLOWUPS.md F-015](../../FOLLOWUPS.md) 完整 forbidden term list — Codex 实操 grep 时**排除 SPEC.md 自身**(`rg -g '!specs/023-planning-numeric-input/SPEC.md' <terms>`),否则本 spec 引用 F-015 的 metadata 行会自检失败(per Codex review PR #52 finding #5)。本 spec 不涉及 coach planning 设计层,实际 Swift / 测试代码自然 0 命中
7. **现有 Step5IntensityViewModelTests / Step6ProgressionRulesViewModelTests** — 多数测 ViewModel 行为(非 UI),应自然不破。若有 ViewInspector 测 Stepper 渲染的,改 PlanningNumberField

## PR 间依赖

- **PR #53 必须先 merge into main**(per Codex review PR #52 second-pass P2):它加 §Review 授权矩阵 spec impl PR sync exception。本 spec 023 impl PR 的 §验收清单 含 "CLAUDE.md 当前完成态 sync" 项,该项依赖 PR #53 的 exception 才合规。**Codex impl 顺序**:看 main 是否已含 PR #53 的 exception → 是 → impl PR 同 PR sync CLAUDE.md;否 → impl PR 跳过 sync,留单独 chore PR 等 PR #53 合后做(此时 spec 023 impl PR 验收清单标 "deferred to follow-up,blocked by PR #53")

## 上游 / 下游

- **上游**(本 spec 落地依赖):
  - 已合 spec 005-007(Step 5/6/7 view 在,本 spec 改它们内部 input UI)
  - 已合 spec 022 catalog v2 import(0 干扰本 spec)
  - PlanningDecimal helpers(planningRounded / roundedToPlanningIncrement)直接复用
- **下游**(本 spec 落地后启用):
  - V0 demo dogfood / TestFlight 内测体验改善(120 tap → 1 type)
  - V0.1+ 学员端 SetRecord(PRD §5 #13)若也用 numeric input,可复用 PlanningNumberField(+ promote 到 DesignSystem 候选)
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
