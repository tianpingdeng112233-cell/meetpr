## V0 Happy Path Manual Checklist (iPhone 17 simulator)

每次 V0-related PR merge 后跑一次。每步预期截图(可选)放 `specs/020-v0-demo-orchestration/screenshots/`。

1. `xcodebuildmcp build_run_sim` with scheme `MeetPR-Demo` -> app 启动 -> splash 后跳过登录 UI，直接落 "教练端" 主页。
2. CoachRootView 显示 "教练端" + "排新计划" 按钮 -> 点击。
3. fullScreenCover 推上 PlanningCoordinatorView，Step 0 显示学员列表(>=3 中文名学员，S/B/D 1RM 数字可读) -> 选首位。
4. Step 1 显示 [1 周 / 4 周] segmented -> 选 4 周。
5. Step 2 SBD 频率 inputs -> S/B/D 各设 2 / 1 / 1，验证训练日分配预览。
6. Step 3 主项变式选择(3 列 chips) -> 各选 1 变式。
7. Step 4 辅助动作三标签筛选 -> 加 2 个不同 day 的 accessory。
8. Step 5 W1 强度填写 -> 主项填 100kg/4x5/RPE7，accessory 填 60kg/3x10。
9. WeightInputField %1RM 切换 -> 学员有 1RM 那位 segmented 可切，切到 50% 看到换算 = 50kg；无 1RM 学员 segmented 锁定 kg。
10. Step 6 加 1 条 weightInc 规则，绑定主项 squat，勾 W2/W3 -> 完成。
11. Step 7 周卡片横滑 -> W1 displays 100kg，swipe W2 displays 105kg，W3 displays 110kg，W4 displays 110kg。
12. 长按任一 exercise row -> contextMenu Peek 弹出 ExercisePeekView 显示动作名 + 强度详情。
13. 点 "进入发布 (TODO spec 008)" -> 无视觉变化，placeholder log warn `step8_pending`。
14. Regression: 边缘 swipe 测试。W2 卡片左约 10pt 起手 swipe -> 应 pop NavigationStack 回 Step 6；卡片中央 swipe -> 切 W1。
15. 杀 app + 重开 -> 应仍在 `.authenticated` 态，DemoTokenStore 重启后预置 fake user 仍生效。

预期通过率 = 15/15。任一失败 = 阻塞 V0 ship。
