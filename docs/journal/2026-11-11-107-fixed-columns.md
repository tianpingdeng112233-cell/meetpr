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
