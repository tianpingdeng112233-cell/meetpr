# 075 — 英文化卡A:约定落地 + 小模块清零 + 时区雷修复

- **状态**: InReview(2026-08-18;实现与本地验证完成,待 Claude review)
- **来源**: 英文化拆卡简报 `~/Projects/scratch/intl-auth/i18n-wave-briefing.md`(08-14,基线核实过);
  ⚖️08-12 本地化活约定=手写 strings enum(AGENTS.md「symbol key 代码生成」是死条文,勿据此报阻);
  ⚖️08-17 美国主战场拍板——TodayWorkoutViewModel 时区雷升级出包前必修,并入本卡。
- **级别**: T2(六小模块+基建约定,零依赖新增;zh 逐字不变红线)

## 目标

真双语跟系统语言:per-module `Localizable.xcstrings`(zh-Hans 源 + en 译)+ 各模块 strings enum。
本卡吃掉六个小模块共 ~204 行用户可见中文,产出《术语表》,并修两颗与英文化同场的雷。
卡 B(StudentKit)/卡 C(CoachKit)吃本卡的约定与术语表后开工。

## 范围

1. **约定与基建**:AppShell 补 `defaultLocalization: "zh-Hans"` + resources(参照 StudentKit/
   ChatUI/CoachKit 的 Package.swift 与 `StudentStrings.swift` 形制);六模块各建/沿用
   `Sources/<M>/Resources/Localizable.xcstrings` 与 `<M>Strings.swift` enum
   (`String(localized:bundle:.module)`,dotted key;带参数用 `\(param)` 插值形制)。
2. **六小模块清零**(~204 行,分布见简报):DesignSystem 109 / AppShell 47 / ChatUI 20 /
   CoreModels 16 / RepositoryContracts 8 / Analytics 4。含 `AnalyticsPrivacyNotice`
   (「使用数据说明」弹窗,真机 smoke 实见 Global 轨中文)与 RootView「正在验证会话…」等。
   ⚠️W4 的 Global 登录三视图(GlobalLoginView 等)是英文字面量**保持原样**,不进 enum
   ——避免与刚合的 #323/#324 无谓搅动,收编留给后续维护窗口。
3. **5 处 `zh_CN` DateFormatter 改 locale 无关**(简报清单:StudentBlackGoldChatView ×2/
   FeedbackInboxView/OnboardingWizardView/WorkoutCompletionPresentation/StudentFormatting)
   ——改为跟随系统 locale;zh 设备输出与现状逐字一致(测试钉住)。
4. **TodayWorkoutViewModel 本地日历匹配修复**(07-12 侦察:UTC 以西时区白天「今天」匹配到
   明天的计划日)。正确契约:设备本地日历生成的 date-only 字符串必须等于 plannedDate 的
   date-only 字符串(plannedDate 是 UTC 午夜锚定的 date-only;「今天」以设备本地日历为准,
   保留可注入 calendar 语义),或等价的年月日分量比较;Asia/Shanghai / Europe/London /
   America/New_York 三时区从午夜到日末的全时段及换季日测试钉死。
5. **《术语表》** `docs/i18n-glossary.md`:动作名从 catalog `nameEn` 直出(1,219 条正典,
   不重译);力量举术语 ~50 条(RPE/e1RM/AMRAP/top set/back-off/顺延→shift 等)以
   `~/Brain/wiki/powerlifting/` 与 `~/.claude/skills/powerlifting/references/` 为准;
   通用 UI 词(保存/取消/删除/重试…)一并定调。卡 B/C 的翻译一律先查表。

## 不在范围

- StudentKit(卡B)/CoachKit(卡C);代码注释与 Tests 中文豁免;
- plan-web 英文化(独立卡);Global 登录视图收编。

## 验收(交付红线)

1. **zh 逐字不变**:zh-Hans 环境所有被改文案与现状逐字一致(xcstrings 的 zh 源串=原字面量,
   截图 diff 抽查高频页);DateFormatter 5 处在 zh 设备输出不变(单测断言)。
2. Sources 用户可见字面量清零(注释与 Tests 豁免);en locale 模拟器六模块界面无漏网中文、
   无溢出破版(截图留档)。
3. TodayWorkoutViewModel:Asia/Shanghai / Europe/London(GMT/BST) / America/New_York 三时区
   「今天」按设备本地 date-only 匹配;覆盖午夜两侧、00:00–07:59、20:00–23:59 与换季日。
4. 全模块 swift test 绿;swiftlint --strict / swift-format 零违规;Release 与 Global 双配置 build 过。
5. 术语表就位且卡A 内译文与表一致。
