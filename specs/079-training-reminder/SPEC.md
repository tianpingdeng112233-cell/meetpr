# spec 079 — 学员端训练日定时提醒(本地通知)

- **状态**:InReview(2026-08-20 David 拍板 A = 用户自选星期几+时间的纯本地闹钟,
  不从计划推断训练日——推进制下「下一练是哪天」本就不确定,猜错的提醒比没有更烦)。
- **级别/节奏**:T1;P1,目标 1.0(21) 班车。
- **范围**:纯 iOS 学员端,零 backend;教练端不做。

## 问题(为什么做)

学员没有任何训练提醒机制,想按计划练全靠自觉记得。需要一个可自控的轻量提醒:
自己开、自己定时间、随时关。

## 方案概览

「我的」新增「训练提醒」设置:总开关 + 星期几多选 + 时间点。开启后在所选周几的
该时刻发重复本地通知;默认关。纯 `UserNotifications` 本地实现,与将来的 APNs 远程
推送互不依赖(授权是同一个,先到先请求)。

## UI

- `MyProfileView` 现有分区结构中新增一行 NavigationLink「训练提醒」(位置放在训练相关
  分区,风格照既有 `MyProfileSectionLabel` + 行样式),副文案显示当前状态
  (关 / 「周一·三·五 20:00」式摘要)。
- 设置页:
  1. 总开关 Toggle;
  2. 星期几选择:一~日七个 chip 多选(开关开启时可用);
  3. 时间:`DatePicker`(`hourAndMinute`);
  4. 权限被拒时:行内提示「通知权限未开启」+「去设置」按钮
     (`UIApplication.openNotificationSettingsURLString`)。
- 开关首次打开时才请求通知权限 `requestAuthorization([.alert, .sound, .badge])`
  (不在启动时弹);拒绝则开关回落为关并显示上述提示。
- 默认值:关;首次进入预选 周一/三/五 + 20:00(仅作初始值,未开启不排程)。

## 排程逻辑(硬约束)

- 每个选中 weekday 一条 `UNCalendarNotificationTrigger`(weekday+hour+minute,
  `repeats: true`),系统按设备当地时区触发,时区迁移无需特殊处理。
- 通知 identifier 统一前缀 `training-reminder-`;**任何设置变更(开关/周几/时间)先
  removePendingNotificationRequests(该前缀全量)再重排**,不得残留旧排程。
- 登出时清除该前缀全部 pending 排程(避免换号后被上一账号的提醒骚扰);设置本身存
  `UserDefaults`(本地偏好,不上后端、不随账号漂移,V1 接受)。
- 通知文案鼓励式(标题+正文,如「训练日到了/该练了,今天的安排在等你」,不催打卡
  KPI 式措辞),中英双语。
- app 在前台时通知静默(不实现 `UNUserNotificationCenterDelegate`,V1 接受前台不弹;
  为将来 APNs 波留白,本波不动 App/AppDelegate 生命周期层)。

## 架构约束

1. 排程计算抽纯逻辑(给定 设置 → 期望的 trigger/identifier 列表),经协议注入
   notification center 的 fake 实现做单测(风格对齐仓内现有注入模式);
   ⚠️ SPM 单测跑 macOS host,`#if os(iOS)` 包住的测试静默不执行,测试须真的在跑。
2. i18n:所有新字符串进 StudentStrings enum 现行机制,中英双语。
3. 教练端零改动;StudentKit 外不引入 UserNotifications 依赖。

## 不做(防蔓延)

- 不从计划/推进制推断训练日(拍板 A 已否);不做「今天有课未打卡」智能提醒;
  不做后端偏好同步;不做教练端提醒;不实现前台通知横幅。

## 验收标准

1. 开启开关 → 权限弹窗出现;允许后按所选周几+时间产生对应条数 pending 排程
   (identifier 前缀正确);改周几/时间/关开关后 pending 集与设置严格一致、无残留。
2. 权限拒绝路径:开关回落、行内提示 +「去设置」可跳转。
3. 通知真触发一条(时间设近验证),文案与本地化正确。
4. 登出后 pending 清零(仅本前缀,不误删他人排程)。
5. build + 全量 `test_sim` 绿;排程纯逻辑单测覆盖(多选/单选/全不选/变更重排)。
6. 模拟器截图取证:设置页、权限提示态、通知横幅。
