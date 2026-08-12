# spec 073 — 休息倒计时 Live Activity（灵动岛 + 锁屏）

- **状态**：Draft（方向已拍板，待实装）
- **拍板**：2026-08-12 David 选 A = Live Activity 单做；本地通知兜底（选项 B）未选，
  V1 明确不做，防复活。
- **级别/节奏**：T2（新 target、跨 target 结构改动）；P1，目标 1.0(19) 班车。
- **范围**：纯 iOS 学员端，零 backend。

## 问题（为什么做）

组间休息倒计时（`RestTimerOverlay`，spec 030 §B3）是 app 内悬浮条：TimelineView 驱动
墙钟 `endsAt`，切回前台剩余时间是准的，但**切到后台期间什么都看不到**，且休息结束的
触觉反馈靠 app 内 `Task.sleep`，后台被挂起**根本不会触发**。学员组间刷微信/刷抖音是
常态，现状 = 后台零信号，只能自己估摸着切回来。

## 方案概览

新增 Widget Extension target，用 ActivityKit Live Activity 把倒计时投到灵动岛与锁屏：

- 记完一组休息计时开始 → 灵动岛（compact/minimal/expanded）与锁屏卡片实时显示剩余
  时间与进度条；
- 倒计时渲染用系统原生 `Text(timerInterval:countsDown:)` + `ProgressView(timerInterval:)`，
  系统进程自动跳秒——**零推送、零后台任务、零电耗担忧**；
- 与 app 内计时共用同一墙钟 `endsAt`（`TodayWorkoutRestTimerState` 现有结构），两处
  显示天然一致；
- iPhone 14 Pro 以下无灵动岛机型走锁屏卡片 + 状态栏药丸，覆盖不缺。

## 架构约束（硬）

1. **StudentKit 严禁 import ActivityKit**。仓 gotcha：SPM 单测跑 macOS host，而
   ActivityKit 无 macOS——一旦 import，`swift test` 直接编不过或被迫 `#if` 打洞。
   StudentKit 只定义纯 Swift 协议：

   ```swift
   public protocol RestTimerActivityControlling: Sendable {
     func start(endsAt: Date, totalSeconds: Int)
     func update(endsAt: Date, totalSeconds: Int)
     func end()
   }
   ```

   `TodayWorkoutViewModel` 经初始化注入（默认 no-op 实现，风格对齐现有
   `restTimerSettings` 注入）。
2. 具体实现 `RestTimerLiveActivityController` 与 `RestTimerActivityAttributes`
   （`ActivityAttributes`，ContentState 含 `endsAt` / `totalSeconds`）放 **app 侧新顶层
   `Widgets/Shared/` 目录**，文件 target membership = 主 app + widget extension 双挂，
   **不进 SPM Modules**（attributes 类型必须两个 target 都可见；不要为一个 struct 立
   新 module，也不要把整个 StudentKit 链进 extension）。
3. 新 target `MeetPRWidgets`（Widget Extension）：bundle id `com.meetpr.app.widgets`，
   automatic signing team `28JW4SA779`，deployment target 对齐主 app（iOS 17.0），
   embed 进主 app target。
4. **pbxproj 改结构必须走 ruby `xcodeproj` gem**（仓 gotcha，禁手编 diff）。extension
   在 pbxproj 现有**全部** build configuration（至少 Debug/Release/Demo/DemoStudent）
   都要有配置且可构建——Demo 线是 David 收货通道，缺配置 = 收货直接挂。
5. 主 app 各 configuration 加 `INFOPLIST_KEY_NSSupportsLiveActivities = YES`。
   不开 frequent updates（`NSSupportsLiveActivitiesFrequentUpdates` 不加）。

## 生命周期接线（TodayWorkoutViewModel）

现有四个改变 `restTimer` 的路径逐一接线，**不允许存在改了 `restTimer` 但没同步
activity 的路径**（实现上建议在 `restTimer` 赋值点收口，didSet 或私有 setter 均可，
Codex 自选，但测试必须覆盖全部路径）：

| 路径 | activity 动作 |
|---|---|
| `startRestTimer`（记完一组） | `start`；若已有活动 activity = 先 `end` 再 `start`（或语义等价的 update） |
| `adjustRestTimer(±30s)` | `update`（新 `endsAt`，`totalSeconds` 不变） |
| `skipRestTimer` / 悬浮条 3s 自动收起 | `end` |
| 全组记完导致 `restTimer = nil` | `end` |

- **自然到点（app 在后台）**：`staleDate = endsAt`，到点系统把 activity 标 stale，
  widget 以 `context.isStale` 切「休息结束 💪」态——**不需要 app 醒来**；倒计时
  `timerInterval` 文本本身由系统跳秒并停在 0:00。
  （⚖️ 2026-08-12 实装期修订，Codex CHALLENGE #1 采纳：Live Activity 不跑 widget
  timeline，`TimelineView` 条件分支渲染后不会重新求值，模拟器实测确认；原
  「`staleDate = endsAt + 60s` 供系统回收」依据不成立——stale 只标内容过时，不负责
  回收。）app 回前台时发现 activity 已过期 → `end`；app 冷启动时清理所有遗留
  activity（`Activity<RestTimerActivityAttributes>.activities` 全 end）。锁屏结束态
  残留到用户回 app 为止，属可接受行为（各大计时 app 同款）。
- **授权**：`ActivityAuthorizationInfo().areActivitiesEnabled == false` → 全链 no-op，
  不弹提示不做引导（V1 不做设置项，系统开关即开关）。
- 教练端 / coach demo 无休息计时，零接触。

## Widget UI（V1 收口）

- **锁屏卡**：timer 图标 + 「组间休息」标签 + 大号 monospaced 倒计时 + 进度条，
  品牌金 tint；到点切「休息结束 💪」。
- **灵动岛** compact：leading 金色 timer 图标，trailing 倒计时；minimal：倒计时；
  expanded：同锁屏卡布局。
- 配色优先 link DesignSystem（extension 可依赖 SPM module）；若依赖链在 extension
  内编译受阻，允许本地常量兜底，注释标明对应 DesignSystem token 名。
- 锁屏恒深底，对比度要过；app 内深浅色均验。
- **点击跳回 app**：灵动岛/锁屏卡点击任意位置回 app 前台 = 系统默认行为，零代码；
  用户切后台前就在今日训练页，回来原地续上即正确。V1 不做 `widgetURL` 深链。
- **V1 明确不做**（防 scope 爬行）：锁屏交互按钮（跳过/+30s 的 App Intents）、
  休息结束本地通知（拍板未选 B）、Apple Watch、教练端任何形态。

## 测试与验收标准

1. **StudentKit 单测**（spy `RestTimerActivityControlling`，纯 Swift，macOS host 可跑；
   **禁止 `#if os(iOS)` 包裹测试**——仓 gotcha，包了会静默不执行）：
   - 记一组 → `start` 恰一次，参数 = 计时器 `endsAt/totalSeconds`；
   - `adjustRestTimer` → `update` 且 `endsAt` 位移正确（含 clamp 到 0/900 边界）；
   - `skipRestTimer` → `end`；
   - 全组记完 → `end`；
   - 连续记两组 → 无 activity 泄漏（end/start 序列或等价 update）。
2. **构建**：`xcodebuild` Release、Demo、DemoStudent 三 configuration 全绿
   （Demo 线必须显式 `-configuration Demo`，仓 gotcha）；swiftlint --strict 过。
3. **模拟器走查**（交付必附证据截图）：iPhone 16 Pro 模拟器记一组 → 锁屏见倒计时卡、
   灵动岛见 compact 倒计时；+30s 后锁屏时间同步；跳过后 activity 即刻消失；
   放到自然到点 → 锁屏显示结束态。
4. **真机 smoke**：David 切包前亲验灵动岛（真机与模拟器行为有差异），列入 1.0(19)
   prep-beta 清单。

## 影响面

- 老包（≤1.0(18)）零影响；无数据、无迁移、无 backend。
- PrivacyInfo：ActivityKit 不属 required-reason API，预期无需改口径；若实装中发现
  需要动 `PrivacyInfo.xcprivacy`，停下来报（真 gate，仓既有裁决口径）。
- 新 target 进主 app scheme，self-hosted runner CI 构建即覆盖，无需新 workflow。
