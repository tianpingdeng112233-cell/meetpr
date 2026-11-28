# spec 111 · 移除休息设置操作提示

设置盘不再渲染盘下的操作说明。盘外按钮保留 VoiceOver 标签，倒计时盘继续显示自己的说明。

用 MeetPR-DemoStudent 在 iPhone 17e（iOS 26.5，简体中文）长按训练页圆环，确认盘下文字消失。关闭提示音、点背景保存，重开后读到「提示音 · 关」，随后恢复原设置。[模拟器截图](evidence/111-rest-hint/ios.png)

SwiftLint 严格模式及 swift-format 通过。首轮并行 StudentKit 测试在构建负载下报告 21 项问题，随后全模块串行复跑 1,374 项全部通过。DemoStudent 构建、安装和启动通过。
