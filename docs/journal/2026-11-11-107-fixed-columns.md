# 107 固定数据列返修

David 拒收仅上下排布，要求如 Excel 同类数据固定位置，并统一字号与颜色。先改完再上模拟器，确认前不再切包/发布。遵循 SPEC 最新修订；测试沿用摘要纯函数和训练页面组件 seam。

## 本轮实现与自测

- 按 David 现场反馈落地固定三列，动作名 T1 15 bold、数据 T2 13 regular；普通动作一条数据行，仅显示次数不同才分段。
- 操作按钮移到标题行；数据间距 4、右侧保留 44，统一列比例 .87:1.79:1.34。空强度显示 RPE —。
- 新增先红后绿回归：同次数部分录入不额外拆行；纯 RPE 部分录入后保留未录入组强度与对应占位。
- iOS StudentKit 全量 1269 tests / 89 suites 通过；最终强度压缩后 AllDay 定向 40 tests 通过。RN 摘要与训练页 68 tests 通过；此前全量 2291 tests 通过。最终 TS 类型检查、目标 ESLint、SwiftLint 与 diff whitespace 检查通过。
- 独立 Standards 审查 CLEAN；Spec 审查指出同次数拆行与部分 RPE 丢失，修复后复审 CLEAN。视觉验收由 David 决定，不据此宣告收货。
- 原生验证使用 iPhone 17e + Android emulator-5570 独立 feedbackqa 包，真实组件及合成测试数据；截图在会话 outputs/fixed-columns。正式包与用户数据未清空。
- 临时画廊仅用于验收，不进提交：iOS MeetPRApp.swift/StudentDemoSeed.swift；RN src/app/_layout.tsx/src/qa-summary.tsx。RN Metro 8093 保持验收画面；打包前须恢复临时代码。
- iOS38/CN12 已有产物保留。本分支未合入发版线，未切新包、未发布。大字号/极长列表与最终全场景收货仍须继续核对，不能用当前截图代替全部验收。

## 现场追加返修：直达编辑、说明入口与原值提示

- David 已明确：可直接点强度进入编辑，键盘打开时可切其他字段；RPE/RIR 标签恢复切换。问号置于标签正右侧、同基线，间距 8，不增加行高。
- 两端复用已有说明内容。inline 图标 14，命中区 24×22，负边距补偿保持布局；RN 标题父容器同步扩展，避免命中被裁剪。
- 原计划有具体值且与实际不一致才显示原值；10pt。无计划值不显示“原 —”；RPE 在计划区间内视为一致。已有差异色语义保留。
- iOS 去除 allDay 键盘遮挡字段的蒙层，其他入口仍保留原行为。空白收起由训练内容背景 Button 处理；普通父 onTapGesture 在原生未触发，已替换。
- 测试：iOS StudentKit 全量 1272 tests / 90 suites；RN 2297 tests / 218 suites。点击区域调整后 RN 45 项定向通过；原值条件先红后绿，覆盖缺失、相等、不同、RPE区间、RIR。
- iPhone 17e 原生验证：直达 RPE；标签切 RIR；点重量再回 RIR；问号打开/关闭保留会话；图标外缘命中；点空白收起后可再直接编辑。证据：会话 outputs/fixed-columns/ios-final-direct.png，work/fixed-columns/ios-native-final-direct.txt、ios-native-blank-button.txt、ios-native-help-edge.txt。
- 两轴定向复审 CLEAN；只覆盖本轮工程返修，不代替 David 视觉收货。未合并、未切包、未发布。相机真机取景及完整大字号/极长列表验收仍不能据本轮结果宣布通过。
- Android 5570 原生补验通过：图标右外缘打开说明；关闭后标签切 RIR，键盘仍为第1组 RIR。命中区 UI hierarchy 实读 72×66 px（24×22 dp）；截图 outputs/fixed-columns/android-final-direct.png。5570 曾短暂 System UI 无响应，选择 Wait 后恢复，未清除应用数据。

## 删除重复键盘确认入口

- David 现场要求删除 iOS 键盘右上“确定”。text 模式只在显式下一项标题存在时显示顶部动作；普通键盘不改，右侧“完成”及下一项保留。
- 先红后绿：DesignSystem 全量81项通过；StudentKit相应可访问性测试改验下一项推进、完成保存编辑值、无重复确定。iPhone17e原生已核实顶部无确定、右侧完成仍在，截图 outputs/fixed-columns/ios-no-confirm.png。
- 定向审查CLEAN，未切包/发布。

## 勾选完成后自动展开下一动作（David 现场明确要求）

- 已定行为：初次进入仍全部折叠，第一个动作手动展开。完成某动作并成功保存后，收起该动作、展开按显示顺序紧接的下一动作；最后一个完成后无下一项。取消勾选仍展开自身。保留手动展开任意动作。
- 范围仅同日动作展开状态；不自动勾选、不改记录口径、不自动跨日、不新增导航或滚动规则。测试沿用本卡既有 TodayWorkoutView 页面与 TodayWorkoutViewModel seam。
- iOS 在 toggleAllDayExercise 成功保存且日期仍一致后设置下一项；原 allDayWriting 防重入保留。RN 在 saveRow 成功后推进；日级操作版本阻止较早保存覆盖后续勾选，动作级版本确保失败仅撤销该次仍有效的本项勾选。
- 先红后绿：iOS 顺序推进测试旧行为为 nil，新行为为第二项；AllDay 46项通过。RN页面49项通过，包含初始折叠、手动首项、推进、末项收起、取消；存储挂起→取消→旧保存成功/失败的交错回归。TS、ESLint通过。
- 原生：iPhone17e Demo真实VM勾选深蹲后下一条自加动作展开；Android5570真实AllDayBody画廊演示深蹲勾选后竞技卧推展开。Android画廊用本地状态模拟勾选，不写真实训练数据；实际保存路径由页面集成回归覆盖。截图 outputs/fixed-columns/ios-auto-expand.png 与 android-auto-expand.png。
- 定向独立审查指出RN取消竞态，修复并补回归后CLEAN。验收仍由David决定，未合入发版线、未打包发布。
- 最终 iOS StudentKit 全量1272项/90套件通过，目标SwiftLint通过。

## 摘要强度列改金色（David 10:49截图要求）

- 截图对应的摘要 RPE/RIR 整列统一使用 goldText，包含标签、数值、范围、缺值占位；保持T2字号、固定列位。此条覆盖此前摘要统一基准颜色的约定，仅限摘要强度列。
- T0局部样式调整，无数据或交互变化。RN既有样式测试同步预期，训练页49项通过；原生截图 outputs/fixed-columns/android-gold-effort.png、ios-gold-effort.png。未发布。
- iOS StudentKit全量1272项通过，SwiftLint通过，模拟器更新完成。

## 已录入逐组强度未出现在摘要（收货后发现，重新暂停发版）

- David 截图：低杠深蹲各组RPE6/7/8/8，摘要仍为RPE—。两端旧1A规则仅在有重量且全动作强度一致时展示，错误隐藏逐组不同的实际强度。
- 删除共同强度过滤，每组始终贡献实际/计划RPE/RIR，再按次数分段压缩；保留缺项位置、重量和保存逻辑。此项按最新固定列与本次反馈覆盖旧1A隐藏规则。
- 先红后绿：旧代码对截图数据返回—，新代码返回RPE6/7/8/8；另覆盖6/—/8/8、RIR3/2/1/1。RN真实页面逐组输入后逐次检查摘要，mock保存为每组独立logID，避免假ID碰撞。
- iOS全量1273项通过；RN摘要+页面79项通过；SwiftLint/ESLint/tsc通过。定向独立审查CLEAN。
- 原生已看到两端6/7/8/8与展开行一致，证据 outputs/fixed-columns/ios-effort-summary-fixed.png、android-effort-summary-fixed.png。iOS保留用户已录入的演示记录；后续临时改值试验因当前页面已切换，未执行成功，不计入验证。Android画廊增加仅内存草稿用于录入演示，不进提交。
- David“等等”撤回本轮放行，发版继续暂停。上轮收货后的发版准备只有口头说明，未执行合并/bump/tag/上传操作。本次修复待重新确认。
