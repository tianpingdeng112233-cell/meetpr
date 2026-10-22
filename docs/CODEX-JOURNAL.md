## 2026-10-21 · P0 教练冷启动卡顿（开发修复与自测完成，未提交）

- 工作树 `MeetPR-wt-coach-launch-hang` / `fix/coach-launch-hang`，基线 `b2afd513`。David 明确要求不 commit/push、不改变导航/tab/视觉；本条只记录开发取证，不更新发布正典。
- Phase 1：真实 `MeetPRApp → RootView → CoachRootView → Today`，仅 Demo 仓库注入已有 092 两学员 fixture。首屏已画出空态后主线程不返回；3/3 次后台 watchdog 报 `mainResponse>3s`，自动化 0 targets。默认 Demo 周概况为空：主线程 0.043209 ms，Profile 点击至目标页 1015 ms。探针判定约 5 秒，截图/JSON 在 `docs/evidence/coach-launch-hang/`。初版 harness 过早读文件的三次结果明确标记 ERROR，不算红例。
- 已执行的单条 agent 命令（functions.exec）：`const s = await tools.exec_command({cmd:"cat scripts/diagnose-coach-launch-hang.js"}); text(await eval(s.output)(tools,{name:"baseline-red-1",screenshot:true}));`。脱敏输出：`exitCode=1, FAIL mainResponse>3s, watchdogWallMs=4886, targets=0`。无需账号/人工点击；后续绿色同时断言 Profile 页面可达。
- Phase 2：依次只减学员数、日志、训练日；1 学员 → 红，去日志 → 红，1 学员/1 日/0 日志 → 红；再去最后 1 日 → 绿（0.039125 ms / 点击 995 ms）。最小触发数据为真实首页路径的一名有训练日学员。无网络、实时服务或 Swift Charts 依赖参与此 fixture；生产账号/真机尚未复现。导航/tab 保持不变。

### Phase 3：排序假设（在实验前记录）

| 排序 | 假设 | 可证伪预测 |
| --- | --- | --- |
| 1 | 周概况比例条的 containerRelativeFrame 对外层容器尺寸形成布局反馈 | 只用父布局分配相同比例宽度替换该尺寸查询，watchdog 转绿；只移除其他数据无效 |
| 2 | 非空训练日触发周汇总/行模型计算不返回 | 若计算是原因，其返回探针不会出现；若返回用时短且显示前已完成则排除 |
| 3 | 保留的 tab host 与非空名单在尺寸更新时循环 | 若仅比例条替换后、完整原 tab host 与相同名单均恢复，可排除该结构是本次必要原因；不改导航来验证 |

### Phase 4–6：因果验证、修复与清理

- Phase 4 完成：只移除比例条的 `containerRelativeFrame` 祖先尺寸查询，完整 fixture 转绿（0.028292 ms / 点击 1059 ms）；恢复原语句再次红（>3000 ms）。假设 1 获支持；汇总算法与 tab host 原样保留仍恢复，假设 2/3 排除为本次必要原因。未取得 Instruments/sample 堆栈，不声称定位到 SwiftUI 内部具体函数。
- Phase 5 完成：把真实 App 冷启动 watchdog + fixture 已加载 + Profile 可达保留为回归 seam；修前 `regression-red` 明确 exit 1。最终用固定高度 GeometryReader 的局部可用宽度按原 count/span/spacing 公式分配比例条，未改导航、数据、颜色或内容。最终 3/3 绿：主线程 0.074542 / 0.047875 / 0.040083 ms，点击 2277 / 1572 / 1040 ms。截图亲看，四个 tab 与周表均在。
- 工程验证：CoachKit 472 + AppShell 118 + DesignSystem 73 全量通过，MeetPR / Debug 构建通过，宿主 9 项通过，共 672 项；严格 format/lint 和 diff check 通过。依赖下载受阻后在本树建立离线测试副本，1209 源码/资源逐字节校验，ViewInspector 0.10.3 的 126 个文件按 Git blob SHA 校验；只改生成副本依赖地址，正式 manifest 未改。shell 的两项 Keychain 测试读回失败，原生 MCP 全量重跑 118 项通过，未跳过/改弱测试。
- 独立 Standards：1 个 P2（watchdog 需显式比较 3s，而非仅检查返回）；修复后定向复核 CLEAN。Spec：CLEAN。没有未决实现 blocker；不代替真实设备验收。
- Phase 6 完成：完整最初 fixture 再跑通过；一次性最小化参数/等宽实验已移除；源码与回归脚本无临时调试前缀。原始证据保留旧日志字符串，未伪称整仓历史文本 grep 为空。回归 harness 明确标记且只在 `DEMO_MODE && COACH_LAUNCH_HANG_TESTING` 下启用，普通 Demo/正式包不运行 watchdog。
- 未验：David 真机、真实账号、iOS 17/26.4、多分组比例条实屏。此次完全离线即可复现，根因在 iOS SwiftUI 布局；未发现共享后端同步等待，Android RN 未读/未运行，不能推断同因。
- 完整命令、失败尝试、数字、截图、离线测试边界与审查记录：[证据 README](evidence/coach-launch-hang/README.md)。未来 commit message 草稿：`Fix coach cold-launch layout hang by sizing week legend locally [P0]`。没有 commit/push，没有改发布正典。

## 2026-10-14 · 1.0(24) 切包（P1）

David 下令「发车」。build 23→24（五处 `CURRENT_PROJECT_VERSION`），marketing 1.0 不变；基底发版线 `9935bd95`，NEXT-RELEASE 补登记 spec 092（#364 / #363）。annotated tag `beta/1.0-24` 指向本切包提交，tag CI 与 Archive / Upload 待完成。[切包记录](prep-beta-1.0-24-2026-10-14.md)。

## 2026-10-14 · Spec 092 · 训练历史行样式修复（P1）

按 David 截图与明确格式，额外组和学员自加组复用 `HistorySetRow`：左侧「额外」或「第 N 组」，右侧统一重量/次数/RPE，去掉独立勾号与 kg 前空格；自加动作标题沿用计划动作 body13 bold，附小灰字「自加」。原处方组的已记录、未记录状态样式保持一致。

两项渲染回归先红后绿，StudentKit 全量 1020 项、strict format/lint 通过；Standards 与 Spec 独立审查各 0 findings。MeetPR / Debug 已成功构建并安装运行到 iPhone 12（iOS 26.5）。David 已在真机查看目标记录并确认「修好了」；本轮未留存目标历史页截图。证据见 [验证摘要](evidence/092-history-style/verification.txt) 与 [审查摘要](evidence/092-history-style/review.txt)。本次不含既有 Xcode scheme/用户状态与 xcstrings 工作区改动。

## 2026-10-14 · Spec 092 · PR 整合修复（P1）

David 直接授权先合 #364，再把 `release/1.0` 合入 #363。#364 已合为 `c65795c2`；教练父提交 `69a327fd`。自动合并复现 Networking 的 `planDayID` 重复声明与 CodingKey 重复值编译错误；共享 `SetLogDTOs.swift` 恢复成 #364 的唯一版本（`exerciseID` 后接 `planDayID`）。教练实际调用独立的 `CoachSetLogDTO`，核对后无须修改调用点。两端 Demo 接线、JOURNAL 历史均保留，verification 冲突按两端历史摘要合并。

27 份入库原始日志（约 3.49 MB）换成简短结果摘要，保留原路径、截图、红阶段与未验边界；完整旧输出仍在父提交及仓外备份。九包全量 2169 项和 MeetPR / Debug 9 项通过，strict format/lint、模块边界与 diff check 通过；独立 Standards / Spec 各 0 findings。双端 Demo 构建与最终证据见 [整合验证](evidence/092-integration/verification.txt)，[审查记录](evidence/092-integration/review.txt)。本轮只更新 #363，未合并该 PR；产品正式验收仍由 Opus 按原清单执行。

# 2026-09-27 P0 发版推进

- David 授权 P0 加急，#345 已合并 release/1.0@03021ff6；此前待合并/P1 条目为历史状态。
- David 确认最高已上传 22；全新 1.0(23) tag 4e97a489、CI run 36330361925 全绿（1,930 + 9 测试），双端实装 23。可 Archive，尚未上传；不改原 22 tag。[记录](prep-beta-1.0-23-2026-09-27.md)。

# CODEX-JOURNAL — David 直驱改动台账

> **用途**:David 在 Codex 直驱的每笔 commit 在这里留一行,新条目在最上。
> 后续主代理每次开工按全局规约读本文件 catch-up——**这里没有的改动等于不存在**。
> **格式**:`- YYYY-MM-DD <short-sha> — 一句话改了什么(牵动的模块)`
> 密钥/密码永不入此文件。

## 2026-09-27 硬拉 e1RM 修复（待合并）

- 2026-09-27 `fix/050-imported-e1rm-baseline` — [Codex][CI] PR #345 首跑被上游 ViewInspector 新版 manifest 阻断；四模块统一固定原已验证的 0.10.3，窄范围双轴补审 CLEAN，StudentKit 901 复验绿，重新跑完整 CI。

- 2026-09-27 `fix/050-imported-e1rm-baseline` — [Codex][T2/P1] 实练异常基线排除 imported，Progress 首次读取前恢复受影响旧历史；保留导入复核、退役历史、PR 与不回退的重量基线。StudentKit 901 测试、strict lint/format、模拟器90天曲线/来源组亲验通过；独立 Standards/Spec 第二轮均 CLEAN。未改 build/tag，未合并/上传。[验证记录](verification-e1rm-imported-baseline-2026-09-27.md)。

## 2026-09-16 准备 1.0(22)

- 2026-09-16 07489315— [Codex][prep-beta] David 要求切包；核实 ASC 最高 21 与六项祖先关系，agvtool 升至 22、marketing 保持 1.0；使用独立取包树保留旧树修改。tag CI 九包 1,922 + 主工程 9 全绿，双端 demo 已装 22；Archive/Upload 尚未执行，Apple 新协议待本人处理。完整状态见 [切包记录](prep-beta-1.0-22-2026-09-16.md)。

## 2026-09-16 追加 #338（已落线）

- 2026-09-16 24d47f65（组合 2e816526，原实现 8ba5b638）— [Codex][T1/P1] David 追加批准动作库同步进入 1.0(22)；合入最新五项发版基线，功能差异仍为两 JSON 与两测试。CoachKit 443/443、最终 CI 九包 1,922 + 主工程 9、format/lint 全绿后合入；验证及最终 CI 见 [#338 验证记录](verification-338-2026-09-16.md)。

## 2026-09-16 下一班车整合（已落线）

- 2026-09-16 9a28115d（修复 3acc828）— [Codex][P1] 按 David 批准整合 #339/#342/#341/#340/#343 进入 1.0(22)，保留已有组合修复；修正 #343 两个新按钮绕过 #341 统一按压、上午补记被 Demo 历史时间窗口过滤的问题。当时 #338 留候选，后续追加见上；未切包、未执行线上迁移或部署。#344 全绿合入，九包 1,922 + 主工程 9 测试。证据见 [整合验证](verification-train22-2026-09-16.md)。

## 2026-09-14 收货历史（当时尚未落线）

- 2026-09-14 73fea6d — [Codex] 组合 #342/#341/#340，修复补记日期窗口、Gregorian 日期、部分写入重试、数字键盘小数及动作清理兼容；#342 修复已回推 c21a3d7/dbcf60fa。组合 1,913 个 SwiftPM + 主工程 9 测试、DemoStudent 实点及完整 lint/format 通过；GitHub billing 与阿里云登录阻塞合并/部署。详见 [验证记录](verification-finish22-2026-09-14.md)。

## 2026-09-14 独立实装历史（当时未进入发版线）

- 2026-09-14 cc8efa53 — [Codex][T2/P1] Add e1RM source details and training history navigation：学员端每日最佳节点可查来源组和原计算，训练页直达历史并保留活动组/休息计时；869 测试、DemoStudent 双主题实点、strict lint/format 通过；Standards/Spec 独立审查 CLEAN。分支 `feat/083-e1rm-history-impl` 待合并，证据 `docs/evidence/083-e1rm-history/`，原型保留设计分支。

## 独立设计分支（未进入发版线）

- 2026-09-14 876600a — [Codex][设计反馈] Spec 083 原型非末尾节点半径 4→2.7、描边 1.7→1.3；末点与点击范围保持，悬停仍维持大小层级；浏览器截图亲验，spec 同步。

- 2026-09-14 abdff9b — [Codex][P1][待看稿] Spec 083 e1RM 节点溯源与训练历史入口：产品行为写入 spec，ImageGen 概念稿与双主题交互 HTML 已浏览器实点；分支 `feat/083-e1rm-history`，等待 David 确认设计，无 Swift／后端／发布改动。

## release/1.0 历史落线记录

- 2026-08-20 bdc9ab45 — [Claude][P0] 修「记录完成后消失」:推进制下实际训练晚于排期,今日页/周历的计划内 set_logs 拉取窗口钉死在 [首排期日-1d, 末排期日+1d],越过排期终点后新记的组全落窗口外 → 显示 0/N 已记录、重量『丢失』(服务端数据全程完好,staging 已核实倪嘉骏 08-19/08-20 全部在库);窗口上界改 max(末排期日, 今天)+1d,WeekOverviewViewModel 注入可测时钟(StudentKit 2 源文件+2 回归测试;774 测试绿 + swiftlint strict;Global 配置同分支同覆盖,main 为 071 前旧形态无此病不落)
- 2026-08-12 a3273c0 — [Claude][P1] 今日页头部日期改恒显真实今天(TimelineView 跨午夜自翻篇):原钉在游标日教练排期 scheduledDate,学员落后/当日完成后整页看着冻在旧日期,外测学员 08-12 报「卡在 8.9」;设计正典 sequence-handoff todayStr 三场景均为真实今天,推荐日期只留训练日卡(StudentKit 3 源文件+1 测试 +36/-16;731 测试绿 + swiftlint strict;review-loop 1 轮 1 BLOCKER 修复收敛;DemoStudent 模拟器亲验落后盘头部显 8月12日·周三)
- 2026-08-01 59c66ae — [Claude][P0] 辅助项重量可设 20kg 以下:三条输入路径(弹窗初始 max(20)/步进器减号/数字键盘 snapped [20,500])全按 `draft.isAccessory` 分流,辅助项下限 0、杠铃主项/变式保留空杠 20 护栏;此前教练开 <20 处方被静默顶成 20 落库=数据不正确(StudentKit/DesignSystem 3 文件 +28/-6;DesignSystem 71 + StudentKit 638 测试绿 + swiftlint strict;DemoStudent 模拟器亲验:辅助项 15→减号 12.5→键盘 7.5 保存成功、主项输 15 仍钳回 20;P0 紧急直发,review-loop 欠账待补)
- 2026-07-30 560d840 — [Claude][P1] App 图标换成 David 定稿的「片里的折线」(纸底 #F5F6F8 + 金盘 #D97706 + 折线/淡段/上弧/下沿 PERSONAL RECORD,两色无渐变):主图与 dark 同一张 1024(无 alpha,3 通道),tinted 另出灰度挖空版(圆盘实心 + 盘内挖成透明,系统自己上用户色);矢量真源 + SPEC + 重出 PNG 命令落 docs/brand/(3 张 PNG + 3 个新文件;asset catalog 编译 0 警告,iPhone 17 模拟器主屏亲验 light/dark/tinted 三态)
- 2026-07-23 3808f44 — [Codex][P1] 当前组大卡摄像头改为未附视频时直达系统拍摄页,保留首次隐私确认/相册留底/上传链路;上传中与已上传仍进详情、失败仍直达重试,无视频摄像头能力时安全回退弹层并修 `UIImagePickerController` 媒体类型误报崩溃(StudentKit 5 文件;strict lint/format 0,467 测试绿;MeetPR-DemoStudent iPhone 17 模拟器构建绿并实点回退路径)
- 2026-07-18 5f34e96 — [Claude][P1] 回看也能看到动作备注(David 追加拍板):无活动组时(日练完/历史只读)动作卡头显示备注、全部训练历史动作块同步补;抽共享 CoachNotePill(surface2 变体防 surface1 卡上隐形)+ CoachNoteDisplay.reviewNote 纯函数策略,补 3 测(StudentKit 426);ExerciseSpec 移文件级解 type_body_length(StudentKit 5 文件;swiftlint strict 0,426+126 绿;review-loop 2 轮 3 BLOCKER 全修 CLEAN;模拟器亲验训练tab历史日+全部训练历史两路径)
- 2026-07-18 9c788a1 — [Claude][P1] 学员端动作级教练备注可见:StudentPlanExercise.notes 投影透传(backend plan_exercises.notes,web 备注列)+ 训练页当前组 hero 卡渲染(灰标签+正文独立换行,仅 hero 卡,David 三拍板),旧缓存缺 key 解码兼容测试 + 投影 passthrough 测试补齐(CoreModels/StudentKit 6 文件;swiftlint strict 0 + 双模块测试绿;review-loop 2 轮 3 BLOCKER 全修 CLEAN;DemoStudent 模拟器亲验)
- 2026-07-18 4958c1c — [Claude][P1] 组录入大卡片动作名升格白色标题:20pt heavy 白字动作名 + 15pt 灰色组数计数,撤红色等宽眼眉样式(David 看图反馈「太小」后二拍)(StudentKit 1 文件;swiftlint strict + 423 测试绿;DemoStudent 模拟器亲验)
- 2026-07-18 d40351f — [Claude][P1] 学员端组录入大卡片眼眉行改「动作名 X/X」(如「相扑硬拉 2/2」),替换原「第 02 / 02 组」——卡片此前不显示动作名,练到第二个动作起无从知道当前组属于哪个动作;顺删无引用 twoDigit(StudentKit 1 文件;swiftlint strict + 423 测试绿;DemoStudent 模拟器亲验)
- 2026-07-17 dff484c — [Claude][P1] 学员端视频时长裁剪(port of #260):相机 allowsEditing + 相册 UIVideoEditorController 前置裁剪,超长视频改「先裁再传」,VideoTrimCompletion/SingleShot 平台无关幂等+tmp 清理,与 e9ab0d8 enqueue 所有权互补(StudentKit VideoUpload 4 改 3 新;417 测试绿+build 零警告;review-loop main 3 轮+port 1 轮 CLEAN)
- 2026-07-17 56bf338 — [Claude][P1] #256 补审产出三修:赛扣偏好 key 按学员 UUID 分区(修跨账号继承,旧全局 key 弃用一次性重置)+ 配重数学抽 SetEntryPlateMath 纯函数补 8 测 + PlateLoadout VoiceOver 播报赛扣(StudentKit/DesignSystem 5 文件;407+29 测试绿 + DemoStudent Demo 构建绿;review-loop 2 轮收敛,2 存量 finding 对质 CONCEDE 另立 follow-up;fadbc3a 补审同日 1 轮 CONCEDE 收敛零改动——两笔 1.0(9)/(10) 补审欠账全清)
- 2026-07-17 e9ab0d8 — [Claude][P1] 视频上传源 tmp 文件泄漏修复(port of #263):enqueue 转移 source ownership,导出成功/失败/取消 + enqueue 抛错全路 best-effort 删源,retry nil 不碰导出产物(StudentKit VideoUpload 4 文件 + 台账;401 测试绿 + swiftlint strict;review-loop 1 轮 CLEAN)

- 2026-07-17 1bd39b7 — [Claude][P1] e1RM 曲线主线/纪录点改白色(fgPrimary,导入段维持灰虚线;迷你卡同步;E1RMChart 共用组件,教练端只读图同色)(DesignSystem/StudentKit 2 文件;27+399 测试绿;模拟器亲验)
- 2026-07-17 4207ca2 — [Claude][P1] e1RM 图表:最新突破点常显中文日期 + 点按任意突破点弹「日期·kg」标注(无外部 onSelect 时),红线降 1.5pt/80% 透明度、纪录点缩小(DesignSystem 1 文件;27+399 测试绿;模拟器亲验常显标签)
- 2026-07-17 418ee42 — [Claude][P1] e1RM 图表轴日期改中文「M月D日」(月前日后,locale 无关)+ 破纪录点实心标出(E1RMChartPoint.marksRecord,平延段不标;今日页 Sparkline 开点标)(DesignSystem/StudentKit 4 文件;DesignSystem 27 + StudentKit 399 测试绿;DemoStudent 模拟器亲验)
- 2026-07-17 385fa92 — [Claude][P1] 纪录轨迹渲染改上升斜线(David 二次拍板,阶梯观感否):纪录点间平滑斜线相连、平尾保持,撤 .step 插值与 sparkline 阶梯拐点,数据投影不变(StudentKit 4 文件;399 测试绿;DemoStudent 模拟器今日/成长两页亲验)
- 2026-07-17 120a5c4 — [Claude][P1] spec 053 修正案(David 拍板):学员端 e1RM 曲线改破纪录阶梯线——E1RMSeries 新增 records 投影 + 头/尾平延,E1RMChart 增线型参数(.stepEnd,教练端默认 .curve 不变),移除逐组散点(.low 隔离点保留),Dashboard/成长卡按 chartWindowDays=90 窗口裁剪、delta 同窗口,「历史最佳」=近 28 天无新纪录(StudentKit/DesignSystem 13 文件;review-loop 2 轮 2 BLOCKER 修复 CLEAN;StudentKit 399 + DesignSystem 27 绿;DemoStudent 模拟器亲验阶梯渲染)
- 2026-07-16 0ede4c1 — [Claude][P1] spec 053 图例消歧 + 文案裁剪(David 现场反馈):E1RMChart 图例改「虚线 = 导入的历史记录」并加虚线样本符号(原「浅色」在黑底上不自明);成长页 E1RM 说明行删「越高越强」(DesignSystem/StudentKit 2 文件;DesignSystem 27 + StudentKit 386 测试绿;DemoStudent 模拟器亲验)
- 2026-07-16 4c8af71 — [Claude][P1] Port #227/spec 053 导入历史 e1RM 回填 + review gate:assumed/origin/exerciseID 数据层透传、E1RMRepository upsert/confidence 改写 + ImportedHistoryReviewStore、ImportedHistoryBackfill actor(120 天窗/幂等/超 1RM 族问询/水位/per-student 串行)、E1RMSeries 赢家溯源 + E1RMChart 双层渲染(imported 虚线/低置信弱化/图例)、四处统计排除 assumed、StudentRootView 三触发接线 + alert 队列 + 「历史最佳」回退;迁移重放跳过 assumed(8 个原子 commit,0308f0f..4c8af71;review-loop 3 轮 3 BLOCKER 全修 CLEAN;CoreModels 125/Networking 71/DesignSystem 27/StudentKit 386 测试绿;DemoStudent 模拟器亲验问询/升格/隔离/图例)
- 2026-07-14 8040a70 — [Claude] 训练日切日改凌晨 4 点 gym-day 截断(镜像 backend spec 017):WorkoutDatePolicy -4h 位移 + gymDayToday() 锚点,selectedDate 初始化/回到今天/restTitle/readiness 刷新四处对齐,修内测反馈「晚上12点自动结束」(仅 StudentKit 3 文件;review-loop 2 轮 CLEAN,1 BLOCKER 修复;345 测试绿+模拟器白天路径亲验;残留=今日tab/周历午夜视觉翻篇待 spec)
- 2026-07-13 a051287 — [Codex][P1] spec 043 自建埋点:Analytics 叶子模块+21 事件接线+离线队列/崩溃补报/kill-switch/PIPL notice/摩擦反馈,Demo 双形态硬禁用(Analytics/AppShell/StudentKit/CoachKit;780 测试+正式/双 Demo 构建绿)
- 2026-07-13 94265e4 — [Claude] 学员端 EnterCodeView 姓名栏文案消歧:标签「你的姓名」/占位「填你自己的名字」/新增辅助行「教练会在学员列表里看到这个名字」,修复满屏"教练"语义场致学员误把教练名填进姓名栏(已两例);仅 StudentKit 1 文件 +3/-2;swiftlint --strict + StudentKit swift test 331 绿;纯文案,EnterCodeView 在 Demo 架构不可达(demo 学员预绑定)故未上模拟器
- 2026-07-13 adbce18 — [Codex] #251 review-loop 第 2 轮：迁移重放 confidence 同时服从旧信任档与本次 anomaly verdict，旧 `.normal` 尖峰仍降 `.low` 且不产 PR（StudentKit，972 测试）
- 2026-07-13 ea4c9b2 — [Codex] #251 review-loop 三 BLOCKER 返修：迁移按 setLogId 保真旧 confidence、旧 catalog 动作可重放/未知孤儿显式丢弃；迁移上提 AppShell 共同学员 gate 且失败阻塞重试；Today 低杠变式标题改走 onboarding resolver（AppShell/StudentKit/spec050，971 测试+双模拟器复验）
- 2026-07-12 e0e5074 — [Codex] Port #250/spec050 存量重算：canonical set_logs 按 release/1.0 E1RMRecorder 时序重放，逐学员替换历史并清旧 PR，UserDefaults 幂等且兼容仅 planExerciseID 日志；迁移对照/三项 DemoStudent 模拟器截图落证(StudentKit/RepositoryContracts/NEXT-RELEASE)
- 2026-07-12 3daee8b — [Codex] Port #250/spec050 主项门：competition_stance 解码+Swift/后端镜像解析器，Today/成长头条/教练三 gate 按学员 onboarding 统一裁决，bundled/demo catalog 补齐 stance(CoreModels/StudentKit/CoachKit/AppShell)
- 2026-07-11 bcf8826 — [Claude] 凭证失效兜底修复(port of #245):bootstrap fail-closed(瞬态/429 除外)+ 401 全码清 session 回登录 + 训练页/周历/组记录中文错误文案,「AuthRepositoryError error 0」天书糊屏根治(AppShell/Networking/StudentKit 8 文件 +160;三模块 435 测试绿;staging 双形态模拟器 E2E 亲验:服务端轮换凭证→冷启动→干净回登录页)
- 2026-07-11 601e093 — [Codex→Claude 收货] 顺延 V2(spec 054):整体计划后移替换 V1 挪休息日,计划级端点+撤销窗口(latest_shift_created_at)+≥3 天提示+教练累计徽标(21 文件;865 测试;模拟器全环亲验:确认→周条整体滑移→休息态→撤销复原);backend 侧 PR#57 已合 staging,**发包硬门=0038 迁移+滚镜像先部署**
- 2026-07-11 8ede34e — [Codex 写→Claude 接管验收] Port #234b 顺延 iOS:全栈(DTO/端点/契约/纯函数/教练标记)+入口接旧今日卡(25 文件 +590;5 模块测试绿;模拟器负向路径亲验);附带修 Demo 种子日期改 UTC 午夜锚(原本地锚使 UTC 门控行为与生产不一致)
- 2026-07-11 dee9e39 — [Codex 写→Claude 接管验收] Port #220/spec050§5 误记隔离:纯分类器(软 10%/硬 18% 跳幅门)+置信档持久化,低置信点保留散点不进头条/PR(15 文件 +294;Codex 沙箱跑不了测试卡死 2h 被取消,Claude 外部复验 116+299 测试绿)
- 2026-07-11 ee60951 — [Codex→Claude 收货] Port #216/spec050 e1RM 真源:资格门(RPE≥7/reps≤10/硬拉≤5)+28 天滚动 max+3% 噪声带 PR,阈值集中 E1RMPolicy(StudentKit 13 文件 +582;292 测试;成长页亲验;§5 留给 #220)
- 2026-07-11 fadbc3a — [Claude][P0] 「我的」空态死锁修复:资料空/加载失败时补渲染「更多+退出登录」逃生舱,账号不再被困登录态(仅 StudentKit MyProfileView +14;lint/281 测试/模拟器空白绑定号亲验;review-loop 补审欠着)
- 2026-07-10 e31dc93 — [Codex→Claude 收货] 教练备注学员可见修复(源自 #234):历史页 DayDetailView 补读 coachNote + CoachNoteDisplay helper;链路/训练页本就通(6 文件 +30;模拟器历史页亲验截图)
- 2026-07-10 7a7cb10 — [Codex→Claude 收货] Port #221 账号台账:注销/改密/CSV 导出挂旧「我的」页「账号与安全」卡(15 文件 +963;Apple 5.1.1(v);putNoContent 按本线 401 机制适配;solo 依赖跳过;NEXT-RELEASE 同步并收掉 P0 的 backend 尾注——staging 当晚已根治)
- 2026-07-10 b88ec76 — [Codex→Claude 收货] Port #186:学员 tab 取消不误报错误,统一 isTaskCancellation + 各 VM 取消分类 + 6 回归测试(StudentKit 15 文件+AppShell 测试;Session guard 已随 #233' 存在跳过;冻结的 #214 协议扩展未带)
- 2026-07-10 8c6baf2 — [Codex→Claude 收货] Port #222:E1RM 白话注释+杠片换行+曲线轴标/点标(DesignSystem Sparkline + StudentKit 2 文件;模拟器成长页亲验)
- 2026-07-10 bd49108 — [Codex→Claude 收货] Port #212:教练今日分诊行 NavigationLink 直推 StudentDetailView(仅 CoachKit 2 文件;模拟器 axe 实点验证跳转 OK)
- 2026-07-10 6c33faa — [Codex→Claude 收货] Port #209:动作库去重 10 组重复 nameEn,删除项转 alias,与 main 版逐字节一致(仅 CoachKit catalog/alias JSON + 2 测试)
- 2026-07-10 f34895e — [Claude] Port #202 差集:DraftStore 崩溃循环降级为内存兜底+日志(Session 半边已随 #233' 入包;仅 CoachKit DraftStore)+ 队列表加 per-set/rename 两行(David 拍板提前)
- 2026-07-10 780ea6d — [Claude] CI 加 beta/* tag 触发(David 拍板 B:切包点机器绿,日常直推零 CI)
- 2026-07-10 8ada119 — [Codex][P0] 写组失败保留训练页/录入值并阻止 sheet 提前关闭;视频前置失败明确提示(staging `/sets/log` 500 仍需 backend 修复;StudentKit + NEXT-RELEASE)
- 2026-07-10 37e9a50 — [Claude] Port #229:apple-generic versioning 单源(project 级=7,prep-beta 再 bump 8)+ 恢复 Info.plist 变量引用(仅 pbxproj/Info.plist)
- 2026-07-10 4081362 — [Claude] Port #228:清 pbxproj 死 INFOPLIST_KEY 设置(仅 pbxproj)
- 2026-07-10 01e2ebf — [Claude] Merge three-fix port #231'/#232'/#233' into release/1.0(AppShell/Networking/CoachKit/StudentKit + NEXT-RELEASE 更新)
- (示例,勿删)2026-07-10 0000000 — Fix xxx in TodayWorkoutView(仅 StudentKit)

## 2026-10-02 · spec 084 卡 A · Codex 实装交回 Opus

- T2 / P1；工作分支 `feat/084a-walkthrough-behaviors`，基准 `bcabd9a4`，目标 PR base 为 `release/1.0`。四项实装保留未提交工作区；未 commit / push / 开 PR，未改版本账本、build 号或 SPEC 状态。最终验收由 Opus 按卡 A 清单执行。
- §2：共享序号入口为 `StudentPlanSequence.dayNumbers(inWeek:)`，复用原有排序，已完成日占号。接入清单：Today 页头、Today 完成卡和下一练标签、Today 周条、训练页页头、训练页当前周条、计划周列表、补记 sheet / toast、训练奖励与总结页（消费同一 weekCode）、教练学员详情概览。全仓检索确认本线训练历史和聊天训练卡没有独立 W#D# / D# 展示入口；没有新增标签。教练排课 `DAY n`、日期投影、游标、完成推进、组录入及持久化结构未改。
- §3：体重与 Meetday 的空态、有值态均为带 `PressScaleButtonStyle` 的 Button，分别导航到既有 `.basics` / `.competition` 编辑器。每次导航独立加载 profile 后创建草稿；保存沿用 `MyProfileViewModel.save`，取消沿用返回，回 Today 重新读取指标。
- §5：删除 `pendingPRBanner` 与旧展示/手动确认方法；新 PR 记录后立即确认，进入训练页时确认积压事件，保留 PR 与 e1RM 历史。现场基准已不存在横幅视图及其专用文案键，因此没有额外视图或文案可删；Progress 未改。
- §6：未保存设置时，从当前游标周（全完成则最后周）的推荐日期按 UTC 日历身份取星期，包含已完成日与后移日期；回落档案训练日，再回落一三五。提醒页打开时刷新计划；已保存设置优先，加载期间禁用编辑，存储格式不变。

### 自测证据

四个约定 seam 逐项先红后绿，没有新增其他 seam。新增 6 个测试方法（导航按空/有值参数运行），同步旧标签及 PR 测试：

| seam | 红证据 | 绿证据 |
| --- | --- | --- |
| 序号函数 / 标签 presentation | `TrainingDayNumberTests` 因缺少序号函数与标签上下文失败 | D1–D4、补早日后 D1–D5、同槽排序、Dashboard / 训练页标签通过 |
| Today 卡片导航 | `DashboardProfileNavigationTests` 因缺少导航回调失败 | 空态与有值态的两个 Button 点击分别返回 `.basics` / `.competition` |
| 训练页 PR 处理 | 原 persist / 启动测试观察到横幅待展示状态及未确认事件，4 条断言失败 | 新事件记录与确认、积压确认、重进不再待确认、重复记录隔离通过 |
| 提醒默认星期 | `TrainingReminderDefaultTests` 因缺少计划 / 已存设置输入失败 | 推荐日期、当前周、三级回落、空星期的已保存设置不变通过 |

- 九个 SPM 包 `swift test` 全通过，共 1936 项：CoreModels 158、RepositoryContracts 6、Networking 131、DesignSystem 73、Analytics 30、ChatUI 85、CoachKit 443、StudentKit 907、AppShell 103。
- 全量首轮发现已有 `dashboardWeekCellsAreSequenceOrdinalsNotCalendarSlots` 仍断言 `[1, 4]`，按本卡更新为 `[1, 2]`；随后 StudentKit 全量通过。
- CoachKit / AppShell 初次依赖解析因 GitHub 连接失败中止，使用本机缓存及 `--skip-update` 完成。shell 沙箱下 AppShell 两项 Keychain 测试失败；经 XcodeBuildMCP 重跑 103 项全绿。未改变依赖版本或测试实现。
- 主工程 XcodeBuildMCP `test_sim`：`MeetPR.xcodeproj` / `MeetPR` / Debug / MeetPR-CI（iOS 26.5），9/9 通过；参数 `CODE_SIGNING_ALLOWED=NO -skipPackageUpdates`。首次网络解析失败，重跑跳过更新后通过。
- `swiftlint lint --strict`：全仓 1073 个 Swift 文件，0 violations。`swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules`：通过。`git diff --check`：通过。保留既有 Swift 并发等编译 warning，本卡未新增 warning。
- 本机原始日志：`/tmp/084a-coach-tests.log`、`/tmp/084a-swiftlint-final.log`、`/tmp/084a-format-final.log`；XcodeBuildMCP 本 worktree 日志中 StudentKit 为 `swift_package_test_2026-10-02T13-09-02-507Z_pid7167_945d2585.log`，AppShell 为 `swift_package_test_2026-10-02T13-11-00-051Z_pid7167_4b508db9.log`，主工程为 `test_sim_2026-10-02T13-09-49-406Z_pid7167_04b7057b.log`，同次 xcresult 已保留。

### 自审与待收货

- Standards 独立只读自审：CLEAN。
- Spec 独立只读自审：发现 1 项 P2（重开 Today 编辑器可能沿用旧草稿），已改为每次导航创建独立 ViewModel，定向复审 CLEAN。
- 未做设备验证：DemoStudent / Demo 的 Light / Dark、小屏、大字体与保存/取消实屏操作，按卡 A 交 Opus 收货。主工程自动测试通过不等于完成该视觉与交互验收。
- 2026-10-02 返修第 1 轮：仅修 `dayNumbers(inWeek:)` 重复 id 构造崩溃，保留排序后首次出现的序号；新增重复 id / 反转输入的稳定性回归，先复现 `Duplicate values for key` 崩溃，修后序号测试 3/3 通过。三包均以 `--skip-update` 复跑：CoreModels 158、CoachKit 443 全绿；StudentKit 跑 908 项，序号测试通过，视频测试报 15 个 `Cannot Encode` 问题，全量未绿。全仓 SwiftLint 严格模式 1073 文件 0 违规、swift-format 严格模式及 `git diff --check` 通过；本次未做设备验证，未 commit / push，其余既有改动保留。日志：`/tmp/084a-r1-{red,green,CoreModels,StudentKit,CoachKit,swiftlint,format}.log`。

## 2026-10-02 · spec 084 卡 B · Codex 实装交回 Opus

- T2 / P1；工作分支 `feat/084b-week-strip-login`，基准 `605d1243`（卡 A）。按 CARD-B-ios.md 在当前分支实装，未 commit / push / 开 PR；未改 SPEC、NEXT-RELEASE、RELEASES、build 号、依赖或工程结构。本节为末尾追加，前文保留；最终验收由 Opus 按卡 B 清单执行。
- §1：Global 登录页改为邮箱 → 密码 → Sign in → 两个文字链接 → or → Apple → Google → 法律文案。Apple / Google 同宽同高、描边次要样式，保留认证回调、错误、取消行为和原无障碍标识。GlobalRegisterView 无第三方入口，无需修改；CN 登录未动。
- §4：TrainingSequenceLayout 提供全部训练周、当前/可见周、每格序号与独立选中状态、完成计数、首尾边界及翻周默认选择。新 TrainingWeekStrip 接入箭头、横滑、状态胶囊、小点（超过 8 周隐藏）、深色选中框和淡金当前训练日。翻回当前周选游标日；全完成计划沿用最后一天回落。
- 页头非当前选择显示 Back to today；未来日用 TrainingDayPreview 只读展示推荐日期、日名、动作/组数与现有解锁提示。已完成/当前训练日继续走原展示。训练 tab 的用户点击复用 jump token 回当前；下拉刷新和完成流程结束回当前。记录、计时、补记、仓储与持久化结构未改。
- 删除 TrainingCalendarView、旧 CalendarContent 接线、按周折叠专用函数、旧日历预览及无用双语文案。新增七个周条中英文 symbol key；预览计数复用原有单复数文案。

### 自测证据

仅在卡约定 seam 新增 7 个测试方法（登录顺序 1、TrainingSequenceLayout 分页 6）。红 → 绿按行为逐步执行：

| seam / 行为 | 红证据 | 绿证据 |
| --- | --- | --- |
| GlobalLoginView 元素顺序 | `/tmp/084b-login-red.log`：文本/渠道顺序两条断言失败，Apple/Google 位于邮箱前 | `/tmp/084b-login-green.log`：顺序与既有 Apple 取消测试 2/2 通过 |
| 周分页默认选择 | `/tmp/084b-paging-red.log`：缺少 page 入口编译失败 | `/tmp/084b-paging-green.log`：全部周可访问、默认当前周/当前训练日通过 |
| 翻周默认选择及首尾边界 | `/tmp/084b-navigation-red.log`：缺少前后周选择入口 | `/tmp/084b-navigation-green.log`：含跳号周、过去/未来/返回当前周 2/2 通过 |
| 独立选中、当前状态和完成数 | `/tmp/084b-markers-red.log`：缺少状态/计数/小点入口 | `/tmp/084b-markers-green.log`：3/3 通过；后补空计划、失效选择、全完成、单周、8/9 周、完成后游标推进回归 |

- 删除仅针对旧 Plan summary 的两个测试及旧文案断言。全量初跑另外暴露两个 SetNumberSurfaceTests 的 fixture 用未来日期选日，却要求显示录入界面；按未来日只读约束改为选 StudentPlanSequence.cursorDay，保留原组号断言。定向复测分页/组号/本地化 21/21 通过（`/tmp/084b-review-green.log`）。
- 九包均尝试 `swift test --skip-update --disable-sandbox --cache-path /tmp/084b-swift-cache`；模块缓存通过 `CLANG_MODULE_CACHE_PATH` / `SWIFTPM_MODULECACHE_OVERRIDE` 指向 `/tmp/084b-module-cache`。首次依赖网络代理不可达，复制本机既有依赖缓存后成功解析，未更新依赖版本。XcodeBuildMCP 的 SwiftPM test 工具无 skip-update 参数，因此按用户约束使用 CLI。
- 六包全量通过：CoreModels 158、RepositoryContracts 6、Networking 131、DesignSystem 73、Analytics 30、CoachKit 443。日志 `/tmp/084b-full-<包名>.log`。
- 三包全量未绿：ChatUI 85 项有 1 个视频编码问题；StudentKit 912 项初跑有 15 个视频编码问题及上述 2 个 fixture 问题；AppShell 104 项有 2 个 Keychain 测试共 3 条失败断言。编码错误为 AVFoundation `Cannot Encode`，Keychain 失败发生于 shell 沙箱；前序卡 A 已记录同类环境限制，没有修改生产视频/Keychain 逻辑来规避。
- 修正 fixture 后，排除受限视频/Keychain 测试的可运行回归通过：StudentKit 896、AppShell 102、ChatUI 84（`/tmp/084b-available-<包名>.log`）。排除模式分别为 `AVFoundationVideoExporterTests|PassthroughVideoTrimExporterTests|realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer`、`keychainTokenStore`、`VideoBadgeExporterTests`；不将这些结果写成九包全绿。
- 主工程 `MeetPR` / Debug / MeetPR-CI（iOS 26.5）XcodeBuildMCP test_sim：9/9 通过，参数 `-skipPackageUpdates CODE_SIGNING_ALLOWED=NO`。xcresult：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084b-5377bbb74f9d/result-bundles/test_sim_2026-10-02T13-59-03-043Z_pid24316_8bd59943.xcresult`。
- 最终 DemoStudent 与 Global 构建启动均成功，使用同一 worktree、`/tmp/meetpr-084b-derived` 及 `-skipPackageUpdates`。最终全仓 `swiftlint lint --strict`：1075 文件 0 违规；工具链 `swift-format lint --recursive --strict --configuration .swift-format MeetPR MeetPRTests Modules` 与 `git diff --check` 通过（`/tmp/084b-lint-final.log`、`/tmp/084b-format-final.log`）。

### Standards 自审

- 独立只读 reviewer：CLEAN，0 finding。确认状态类型 Sendable、分页逻辑位于约定 seam、独立子视图、现有 token / Dynamic Type、中英文文案及范围约束；未发现值得报告的 Fowler smell。

### Spec 自审

- 独立只读 reviewer 初轮发现 P2：全完成计划切 tab 的旧 jump resolver 无游标可选；已统一调用分页 currentSelection，保留末日回落。另发现 P3：四个旧日历预览键残留；已删除。两项定向复核关闭，最终 CLEAN。
- 收尾的摘要文案复用、录入测试 fixture 修正、移除覆盖子按钮标识的父级 identifier，已再次定向复核 CLEAN。

### 模拟器证据与待收货

- 已做有限模拟器验证，并非“未做设备验证”：MeetPR-CI / iOS 26.5 / Light / 默认字体 / 英文，Global 登录页亲眼确认顺序与 Apple/Google 同等尺寸；DemoStudent 亲眼确认当前日淡金与选中框并存、未来周只读无开练按钮、首尾箭头状态、小点、同周选日、Back to today、切 tab 回当前，以及横向 drag 翻周、实际下拉 drag 刷新回 W1D3。
- 截图：`/tmp/084b-evidence/login-light.jpg`、`/tmp/084b-evidence/training-current-light.jpg`、`/tmp/084b-evidence/training-future-light.jpg`。当前周图采于最终文案/identifier 清理前，当前周布局未再改变；未来周与登录图来自最终行为版本。
- 未做真机、Dark、iPhone SE 尺寸、大字体、完整记组/计时/补记/完成流程及存量升级验收；交 Opus 按卡逐项核，不以自测代替收货。
- 范围外既有文案：英文训练日后缀 `trainingCalendarLogic.copy011` 被译为 `Sun`，Dashboard 同类拼接也显示 `DeadliftSun`；本卡复用日名/解锁提示后预览显示 `SquatSun`。没有扩展修改共享旧文案，交 Opus 分诊。此项也出现在上述未来周截图。
- 本次审查直接使用仓内卡与 spec，不依赖 tracker；仓内缺少 `docs/agents/issue-tracker.md`，将来使用依赖 tracker 的 Matt 流程前需由 David 调用 `$setup-matt-pocock-skills`。

- 2026-10-02 返修第 1 轮：仅将 TrainingWeekStrip、TrainingDayPreview 与 Back to today 的文字/图标改为 MeetPR 字体 token（预览标题 display 22、小结 mono 12），删除训练页新增 `.refreshable` / `onPullToRefresh` 及预览接线，保留页头刷新后回当前训练日。两包均以 `--skip-update` 全量复跑：StudentKit 912 项有 15 个既有视频 `Cannot Encode` 问题；AppShell 104 项有 2 个 Keychain 测试共 3 条断言失败，与本节前轮沙箱限制一致，全量未绿；按前轮同一模式排除受限测试后 StudentKit 896、AppShell 102 项通过。全仓 SwiftLint 严格模式 1075 文件 0 违规、swift-format 严格模式与 `git diff --check` 通过；Standards / Spec 独立只读复核均 CLEAN。对照开工快照确认只改本轮五个 Swift 文件并追加本行，其余改动保留；本轮未做设备验证，交 Opus 收货，未 commit / push。日志：`/tmp/084b-r1-{StudentKit,AppShell,available-StudentKit,available-AppShell,swiftlint,format}.log`。

## 2026-10-02 — Spec 084 Card C · iOS Ask coach / 聊天训练卡 / 组录入视频 / 休息说明

- Opus 派卡；T2 / P1；分支 `feat/084c-chat-video-rest`，起点 `0c9cafb7`（叠在卡 B）。未 commit、未 push、未开 PR；未改发版账本、SPEC 状态、build 号、依赖或线上数据结构。开工时 `CARD-C-ios.md` 已为 untracked，本次未修改该卡。交由 Opus 收货后提交并开 PR。
- §7：两入口复用单页 picker，动作卡按 exercise ID 分组、三列单选、W#D# 走卡 A 的 `TrainingSequenceText`；训练页预选当前组，聊天入口未选不可发送。问题与选组同页，保留带视频开关/失败禁用；确认后依次走现有 `makeSetRefIntent → stageSetRef → sendStagedSetRef`，outbox、幂等键、重试和 wire set_ref 不变。新增分组元数据只存在于 picker 内存候选。
- §8：留言在气泡上方，附件内嵌下方，空留言无占位；缺失指标省略；双方配色复用各自会话色与正文字体，时间/现有送达文案在气泡下方。带视频继续走原播放入口，无视频附件可展开只读详情；历史 canonical body 识别规则保留。
- §9：新增可测 `SetEntryVideoPlaybackState` 与组录入页持有的单一 `AVPlayer`，默认暂停，拖动、四档倍速、同页 overlay 放大/缩小；放大时顶部下滑/收起按钮/无障碍返回先缩小，进度倍速保留。加载重试随视图 task 取消，离开宿主停止并释放。视频下方状态与 Replace/Delete 用 `ViewThatFits` 整体换行；上传、替换、删除、重试入口继续复用原 VM。`SetVideoPlaybackView`、`FeedbackVideoPlayerView`、教练打点/标注未改。
- §10：底部说明三行由 `RestTimerPolicy` 默认规则计算并格式化；中英文同步，链接进入原 `RestTimerSettingsView` 并复用注入的设置 store。出现条件、用户级已读 key、已有偏好结构不变。新增文字全部使用 `Font.MeetPR` token。

### TDD 与验证证据

只在卡内四个 seam 加/更新 5 个行为测试；替换旧两步 picker 的 4 个测试，未写视图样式镜像测试。

| Seam | Red | Green |
| --- | --- | --- |
| Picker 无默认选择 / 显式预选 / 单选 | `/tmp/meetpr-084c-picker-red.log`：默认首项选择导致 2 条断言失败 | `/tmp/meetpr-084c-picker-green.log`：1/1 |
| Picker 动作分组 / 三列内容 / 发送摘要 | `/tmp/meetpr-084c-groups-red.log`：新 presentation 入口缺失，编译失败 | `/tmp/meetpr-084c-groups-green.log`：2/2（含上一行为） |
| 气泡留言 / 附件 / 视频 / 缺字段 | `/tmp/meetpr-084c-card-red.log`：新摘要入口缺失，编译失败 | `/tmp/meetpr-084c-card-green.log`：1/1；原历史 fixture 测试保留 |
| 视频暂停 / 播放 / 四档速率 / 放大返回 | `/tmp/meetpr-084c-video-red.log`：状态模型缺失，编译失败 | `/tmp/meetpr-084c-video-green.log`：1/1 |
| 休息默认规则与规则变化后的格式化 | `/tmp/meetpr-084c-rest-red.log`：presentation 缺失，编译失败 | `/tmp/meetpr-084c-rest-green.log`：2/2（含视频 seam） |

- 九包均执行 `swift test --skip-update --disable-sandbox`。SwiftPM MCP 无 skip-update 参数，按本卡要求使用 CLI；缓存/构建目录均在 `/tmp/meetpr-084c-*`，模块缓存用 `CLANG_MODULE_CACHE_PATH` / `SWIFTPM_MODULECACHE_OVERRIDE`。首跑系统缓存不可写、依赖代理不可达，改用 `/tmp` 缓存并复制本机卡 B 的既有依赖缓存，未更新版本。
- 六包全绿：Analytics 30、CoachKit 443、CoreModels 158、DesignSystem 73、Networking 131、RepositoryContracts 6。日志 `/tmp/meetpr-084c-test-<包名>.log`。
- 三包全量未绿：ChatUI 84 项有 1 条 AVFoundation `Cannot Encode`；StudentKit 914 项有 15 条视频编码失败；AppShell 104 项有 2 个 Keychain 测试共 3 条断言失败。与本文件卡 A/B 已记的 shell 沙箱限制一致；未修改这些生产逻辑或删除测试。AppShell 初跑曾因并行审查修复期间源文件变化而终止，静止代码后已重跑获得上述完整结果。
- 排除受限项的可运行回归：ChatUI 83、StudentKit 898、AppShell 102 全绿。排除模式分别为 `VideoBadgeExporterTests`、`AVFoundationVideoExporterTests|PassthroughVideoTrimExporterTests|realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer`、`keychainTokenStore`。日志 `/tmp/meetpr-084c-available-ChatUI-final.log`、`/tmp/meetpr-084c-available-StudentKit.log`、`/tmp/meetpr-084c-available-AppShell-final.log`；不视为九包全绿。
- 主工程 XcodeBuildMCP：`MeetPR` / Debug / MeetPR-CI（iOS 26.5），`-skipPackageUpdates`，9/9 通过。xcresult：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084c-67e6b5aceff6/result-bundles/test_sim_2026-10-02T14-59-55-588Z_pid47335_4c741608.xcresult`。
- 审查修复后 `MeetPR-DemoStudent` / DemoStudent 最终构建启动成功，无新增构建 warning。日志：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084c-67e6b5aceff6/logs/build_run_sim_2026-10-02T15-08-20-770Z_pid47335_76e9b8f6.log`。
- 全仓 `swiftlint lint --strict --no-cache`：1081 文件 0 违规；工具链 `swift-format lint --recursive --strict --configuration .swift-format MeetPR MeetPRTests Modules`、`git diff --check` 通过。日志 `/tmp/meetpr-084c-lint-final.log`、`/tmp/meetpr-084c-format-final.log`。

### Standards 自审

- 按 code-review 技能做独立只读 Standards 审查：发现 1 个 P2，关闭组录入后未取消的重试加载可能重建播放器，弱引用监控可能持续空转。已改为随视图取消的 `.task(id:)` 加取消检查，监控宿主释放即退出；复审 CLEAN，0 未解决项。
- 核对 Font.MeetPR、Sendable、单写者、无新依赖、无 wire / 持久化变更，未发现需单列的 Fowler smell。仓内缺 `docs/agents/issue-tracker.md`，已提示后续用 `$setup-matt-pocock-skills` 补配置；本次直接按任务卡审查，不依赖 tracker。

### Spec 自审

- 独立只读 Spec 审查：发现 1 个 P2，expanded 的 safeAreaInset 挤开视频、inline 仅背景有圆角。已改为 expanded 顶底半透明 overlay、inline 整体圆角裁剪，倍速菜单用向上 popover 避免被裁剪；复审撤销 finding，0 未解决静态项。
- 已在 DemoStudent 的 MeetPR-CI 上亲看 Light 界面：训练页当前组预选、动作三列卡、同页输入与发送（仅 InMemory demo）、新气泡上文下附件/送达脚注、聊天 + 进入同页且无预选不可发送。截图 `/tmp/meetpr-084c-evidence/ask-coach.jpg`、`/tmp/meetpr-084c-evidence/chat-set-bubble.jpg`。
- 视频控件尚未做带样片的设备验证：该模拟器 Photos 显示“无视频”（`/tmp/meetpr-084c-evidence/photos-no-video.jpg`），没有把状态单测当成实际播放/上传证据。Computer Use 读取 Simulator 未获访问，未继续该通道。
- 休息说明/设置链接的实屏、教练端与历史消息实屏、Light/Dark、小屏和大字体矩阵，以及视频播放/拖动/倍速/放缩/替换删除实屏仍留 Opus 按卡验收。保留本地限制，不勾选卡内验收清单；本次开发自测不等于功能验收。
- 2026-10-03 返修第 1 轮（未 commit/push）：仅修顶部组号 `{0}` 中英文插值并补重量/次数/RPE、保留同一 AVPlayer/item/AVPlayerLayer 与内嵌占位以保持进度和滚动位置、改 4pt 金色进度轨 + 10pt 滑块 + 44pt 命中区；不足 1 秒片段比例同步修正。新增 4 项测试，插值/完整组信息先红后绿；播放器层测试覆盖真实 AVPlayer seek 时间、item/layer 身份、双向缩放及播放意图（macOS 媒体读取受限，不代表解码播放验收）。全量 ChatUI 84 / StudentKit 918 已跑，既有编码测试报 Cannot Encode（分别 1 / 15 条 issue）；排除原有受限项后 83 / 902 通过，两项 strict lint 与 diff-check 通过，Standards / Spec 独立审查均无遗留项。DemoStudent / iPhone 17 构建启动成功；系统相册不在 MCP runtime snapshot 内，Computer Use 未获准访问 Simulator，未完成返修后带样片设备验证，留 Opus 收货。证据 `/tmp/084c-r1-{red,header-red,header-green,player-green,ChatUI,StudentKit,ChatUI-available,StudentKit-available,swiftlint-final,format-final}.log`，本轮增量 `/tmp/084c-r1-only.diff`。
- 2026-10-03 返修第 2 轮（未 commit/push）：仅修改 SetEntryVideoPlayer / SetEntryVideoPlayerView 及播放器测试；取消跨宿主搬动共享 AVPlayerLayer，改为宿主各自持有 layer、主线程交接时先解绑旧 layer 再绑定同一 AVPlayer，dismantle 显式解绑且迟到的旧宿主拆卸不影响新绑定；保留原 player/item、进度、播放意图、倍速及内嵌占位。新增单宿主绑定回归 1 项，覆盖双向交接、先建后拆/先拆后建与 stop 解绑（新增接口缺失编译红 → 5 项播放器测试绿；不代表黑屏设备复现已转绿）。两包使用 --skip-update 全量重跑：ChatUI 84 / StudentKit 919，既有 AVFoundation Cannot Encode 分别 1 / 15 条 issue；排除原受限项后 83 / 903 全绿。全仓 swiftlint lint --strict --no-cache（1083 文件）、工具链 swift-format lint --recursive --strict、git diff --check 通过；Standards / Spec 独立只读审查均 CLEAN。DemoStudent / iPhone 17（iOS 26.5）用 -skipPackageUpdates 构建启动成功（0 warning），日志 ~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084c-67e6b5aceff6/logs/build_run_sim_2026-10-03T02-16-53-072Z_pid21929_54cfaa1d.log。已进入组录入相册并见样片，但 MCP runtime snapshot 不含系统相册目标，Computer Use 自动审批未批准访问 Simulator（未给具体原因），未完成带样片放缩出画验证，仍留 Opus 按原复现收货。证据 /tmp/084c-r2-{red,green,ChatUI,StudentKit,ChatUI-available,StudentKit-available,swiftlint,format}.log；本轮增量 /tmp/084c-r2-only.diff。
- 2026-10-03 Opus 接手第 2 轮未收敛项（放大 / 缩小后画面黑）：模拟器日志确认是旧内嵌图层在拆除前又被更新一次、抢回并清空播放器。`SetEntryVideoPlayer` 改为按 `SurfaceRole`（inline / expanded）与展开状态绑定；新增回归测试 `staleUpdateFromOutgoingSurfaceDoesNotStealPlayer`，同角色图层替换时释放旧图层。ChatUI 84 / StudentKit 920、两个严格 lint 通过；模拟器放大与缩小均出画。

## 2026-10-03 — Spec 084 · iOS 即时奖励页 / 后台完成请求

- Opus 派卡 `specs/084-walkthrough-polish/CARD-INSTANT-COMPLETION-ios.md`；T1 / P1；分支 `fix/instant-completion-celebration`，基线 `baef8db7`（`feat/084c-chat-video-rest`）。本次未 commit、未 push、未开 PR；未改 SPEC、NEXT-RELEASE、build 号或依赖。开工时任务卡已为 untracked，原样保留。
- 完成动作在第一次网络等待前设置 VM 的奖励页与发送状态，局部乐观完成不提前推进计划游标；奖励页沿用现有 CoachReceiptLine / MeetPR 字体，仅通过 presentation 切换中英文发送文案。成功响应立即更新回执，再走原有刷新与 completionRevision；提前关闭奖励页时，成功后仍回到当前训练日。undo 与 quick-log 的请求路径保持原状。
- 失败 / 30 秒截止：关闭仍在展示的完成流程，清除发送状态，只还原当前日完成标记、保留组草稿，沿用完成失败提示。独立 request/deadline 竞速只交付第一个结果，超时不等待不响应取消的 repository，迟到结果不再操作 VM；成功时取消计时任务。

### 红绿与运行证据

- 在卡内 VM / 完成 presentation seam 新增 5 个测试函数：在途奖励与成功回执、失败回滚保留组并可重试、假定时器超时及迟到结果、提前关闭后成功/失败均不重开、中英文发送文案。原重复 complete/undo 与 projection 测试保留。
- 先红后绿：`/tmp/instant-completion-red.log`（新 seam 未实现编译红）→ `...-green.log`；`...-failure-red.log`（3 条断言失败）→ `...-failure-green.log`；`...-timeout-red.log`（注入 seam 缺失）→ `...-timeout-green.log`（6 项关联测试通过）。完整前缀均为 `/tmp/instant-completion`。
- 计时实现曾复现本机 Swift 运行时 `freed pointer was not the last allocation`：传递 Duration 的异步闭包在取消后返回处崩溃，单独成功测试也复现；去除取消可通过，换时钟或拆函数仍复现。将注入 seam 收窄为无参数截止等待（默认固定 30 秒，取消检查保留）后，原成功、失败、超时与全量测试均不再崩溃。调查日志 `...-crash-isolated.log`、`...-crash-probe.log`、`...-no-cancel-probe.log`；无临时诊断代码遗留。
- 九包全部执行 `swift test --skip-update --disable-sandbox`。SwiftPM MCP 没有 skip-update 参数，因此使用 CLI；依赖代理不可达，复用本机卡 C 的固定版本缓存，缓存/构建置于 `/tmp/instant-completion-*`，未更新依赖。
- 全绿六包：Analytics 30、CoachKit 443、CoreModels 158、DesignSystem 73、Networking 131、RepositoryContracts 6。日志 `/tmp/instant-completion-<包名>-full.log`。
- 全量未绿三包：StudentKit 925 项 / 15 条既有 AVFoundation Cannot Encode；ChatUI 84 项 / 1 条同类错误；AppShell 104 项 / 2 个 Keychain 测试共 3 条断言失败，另 1 项 push 时序测试初跑失败、复跑通过。没有修改相关生产逻辑或删除测试。
- 排除历史受限项后：StudentKit 909、ChatUI 83、AppShell 102 全绿，日志 `...-<包名>-available.log`。排除模式分别为 `AVFoundationVideoExporterTests|PassthroughVideoTrimExporterTests|realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer`、`VideoBadgeExporterTests`、`keychainTokenStore`；不视为九包全量通过。
- 全仓 SwiftLint strict：1084 文件 0 违规；工具链 swift-format recursive strict、JSON 解析及 `git diff --check` 通过。日志 `/tmp/instant-completion-lint-final.log`、`/tmp/instant-completion-format-final.log`。

### 双轴审查与模拟器自测

- `code-review` 两个独立只读 reviewer：Standards CLEAN / Spec CLEAN，均 0 findings；未把自测当作 Opus 收货。任务卡直接提供 spec，不依赖仓内尚缺的 `docs/agents/issue-tracker.md`；后续依赖 tracker 的流程仍需 David 调用 `$setup-matt-pocock-skills`。
- XcodeBuildMCP 使用本 worktree 的 MeetPR.xcodeproj / MeetPR-DemoStudent / DemoStudent / MeetPR-CI（iOS 26.5），`-skipPackageUpdates`，构建启动成功，无新增 warning。
- 亲看正常完成奖励页；Demo 仓储临时注入 8 秒等待后，长按调用约 3.6 秒内（含 1.3 秒长按和工具快照）已看到奖励页与发送中，服务器响应模拟完成后原位切为已收到。发送中/已收到截图：`/tmp/instant-completion-evidence/sending-delay8.jpg`、`received-delay8.jpg`；正常截图 `normal-receipt.jpg`。
- Demo 仓储模拟 HTTP 503 错误：奖励页关闭，原「保存失败 / 暂时无法完成训练，请稍后重试。」提示实际展示；W1D3 仍为游标、3 组记录保留、长按入口恢复；关闭提示再次长按可重进发送中奖励页。截图 `/tmp/instant-completion-evidence/failure-alert.jpg`。这是 repository 错误注入，不是线上服务返回 503 的证据。
- 临时注入仅用于本机 Demo，已逐字还原 InMemoryStudentPlanRepository，清除启动注入环境并重建最终版本。未做真机流量、真实 backend 503、30 秒实等或其他尺寸/语言设备矩阵；超时用卡内假定时器验证，中英文用 catalog/presentation 测试。交 Opus 按原卡收货。
- 移除注入后的最终 DemoStudent 构建/启动：`~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-complete-51fc02eb6290/logs/build_run_sim_2026-10-03T05-39-59-847Z_pid57019_0a2b64ef.log`，0 warning。最终产物再次完成 3 组→长按→奖励页→「完成」回到今日已完成卡；训练 tab 继续指向推进后的训练日。
- 2026-10-03 追加改动（David 真机反馈，未 commit/push）：仅在 SetEntryVideoPlayerView 的共用画面层增加暂停态中央播放按钮（56pt 命中区、仓内字体/颜色/尺寸 token、复用播放无障碍文案），内嵌与放大态一致；播放时隐藏，结尾复用既有暂停/从头播放逻辑，底部控件保留。新增 1 项参数化行为测试覆盖两种形态的按钮点击、显隐、暂停后重现和结尾重播归零；先红后绿，相关 8 项测试通过。StudentKit 使用 --skip-update 全量 921 项有既有 AVFoundation Cannot Encode 15 条 issue；沿用前轮受限项排除后 905 项通过，不视为全量绿。改动 Swift 文件的 swiftlint lint --strict --no-cache、工具链 swift-format lint --strict 与 git diff --check 通过；Standards / Spec 独立只读复核均 CLEAN。本轮未做设备验证，按卡由 Opus 实屏收货。证据 /tmp/meetpr-ios-084c-central-play-{red,green,StudentKit,available,lint,format}.log；增量 /tmp/meetpr-ios-084c-central-play.diff。
- 2026-10-03 追加「周条 7 天日历格」：仅改训练页周条及分页数据源，按 UTC 推荐日期 `day.date`（含后移）输出至少 7 天，训练格保留序号/状态/选中，空日期输出不可点的约 0.7 倍宽休息格；星期置顶、短日期单行，超 7 格及大字体放不下时使用横向 ScrollView，滚动不触发翻周，换周行仍可滑动。文字/图标全部使用 MeetPR token，新增 Rest/休及双语读屏键。执行中 Opus 更新卡面为「一天一练」，已删除开工版本要求的同日双练分支和测试。约定分页 seam 新增 3 测试：四练补休息日、后移跨月扩展两项逐项红→绿；七天全练/跨年/全完成补回归通过（前两项原始日志 `/tmp/084b-calendar-{red1,green1,red2,green2}.log`）。九包均带 `--skip-update` 全量复跑：CoreModels 158、RepositoryContracts 6、Networking 131、DesignSystem 73、Analytics 30、CoachKit 443 通过；StudentKit 915 项有 15 个既有 Cannot Encode 问题、ChatUI 85 项有 1 个同类问题、AppShell 104 项有 2 个 Keychain 测试共 3 条断言失败，全量未绿；按前轮相同排除模式复跑 StudentKit 899、ChatUI 84、AppShell 102 通过。日志 `/tmp/084b-calendar-{full,available}-<包名>.log`。主工程 MeetPR/Debug、MeetPR-CI/iOS 26.5，XcodeBuildMCP test_sim 加 `-skipPackageUpdates CODE_SIGNING_ALLOWED=NO`：9/9 通过，xcresult `~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-084b-5377bbb74f9d/result-bundles/test_sim_2026-10-03T04-21-48-633Z_pid41868_17b3942b.xcresult`。全仓 SwiftLint strict：1078 文件 0 违规，swift-format strict 通过；本轮 Modules/JOURNAL diff whitespace 检查通过（用户原有 SPEC.md 末尾空行未改）。Standards/Spec 独立只读复核均 CLEAN。DemoStudent 最终构建启动通过，中英文 Light 七格实屏及未来日点选/Back to today 已核，截图 `/tmp/084b-calendar-evidence/{chinese-light,english-light}.jpg`；未做 SE、Dark、大字体、超 7 格滚动及 VoiceOver 实屏验证（Dark 启动参数未实际改变外观），交 Opus 按卡收货。本轮未 commit/push，未改 spec/卡片、发布台账、build 或依赖。

## 2026-10-03 · completion-hang 排障（阶段 1 未通过）

- Opus 派单；当前 `diagnose/completion-hang`，基线 `2baeae10`。不 commit、不 push，未改业务源码、工程结构、依赖或发布账本。
- **未复现，未修复，根因未确定。成立的假设：无。** 遵守六阶段门槛，因没有稳定红例，未进入最小化/三项改动隔离、假设、埋点或试修。
- App 托管的真实 TodayWorkoutView 探针：无录入页 24 次、带真实 SetEntrySheet 收起及 1.1 秒等待 100 次、最终加编译开关后 6 次，均恢复主 RunLoop 空闲且呈现 controller。扫描 0/16/50/100/200/350 ms，8 秒独立看门狗。探针为 Debug configuration；直接调用完成入口、UIKit 呈现录入页，未覆盖真实 Hold 手势和私有 editing binding，不能替代原时序。100 次批次中通知授权弹窗已关闭，工具 300 秒超时但底层测试最终成功；详情见原始输出。
- 原 MeetPR-DemoStudent / DemoStudent / iPhone 17（iOS 26.5）build_run_sim 成功、0 warning；实屏逐组记完三组，未手动折叠/展开，滚动后长按 1300 ms，奖励页正常且无障碍树可读。工具会等待快照，未保证命中收起动画中途的窗口。
- 临时探针以 `COMPLETION_HANG_PROBE` + `HANG_PROBE=1` 双开关隔离，正常构建不编译；SwiftLint strict / swift-format strict / bash -n / diff whitespace 检查通过，无临时诊断日志遗留。没有业务修复，未声称回归红→绿或验收通过。
- 方法、命令、测试构建障碍、后续所需证据与六个改动文件见 [排障记录](diagnose/completion-hang-2026-10-03.md)，逐轮输出见 [probe output](diagnose/completion-hang-probe-output-2026-10-03.txt)，原 Demo 实屏见 [奖励页截图](diagnose/completion-hang-demo-not-reproduced-2026-10-03.jpg)。下一步需原容器 UI test 驱动真实保存→收起期间滚动→Hold，或补该时段录像、日志和连续主线程采样；没有红例前不试修。

- 2026-10-03 · T0/P1 Opus 文案卡，`fix/video-row-replace-copy`：仅将 StudentKit `student.videoAttachmentV3Controls.copy004` 英文 Change 改为 Replace，中文「更换」与布局不变；未 commit/push。
- 使用点核对：Localizable.xcstrings:16358 定义 → StudentStrings.swift:1117 映射 → VideoAttachmentV3Controls.swift:162 的 replace 按钮（上传中/已上传/失败状态、横纵布局共用）；上层为 VideoAttachmentSection → SetEntrySheet，另有 Preview，无异义复用，也无 Change 测试/快照断言需修改。
- 验证：StudentKit 首轮 928 过/1 项 retryAfterFailureReinitiatesFromScratch 超时，单项复跑 1/1、全包复跑 929/929 通过（0 skipped）；最终日志 `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-replace-99081fdce275/logs/swift_package_test_2026-10-03T09-40-41-282Z_pid28207_240bc866.log`。相关两份 Swift 的 SwiftLint strict、工具链 swift-format strict、catalog 唯一英文值差异检查及 diff --check 通过；catalog 的 "Change" 搜索为 0。未做模拟器实屏验证。


## 2026-10-03 · usage-notice-copy（T1/P1，Opus 派卡，待收货）

- 分支 `fix/usage-notice-copy`，开工 HEAD `033c9143`，基线 `release/1.0`。按 `specs/084-walkthrough-polish/CARD-USAGE-NOTICE-ios.md` 实装；不 commit、不 push。本节仅追加在 JOURNAL 末尾，未改历史内容、发布账本、任务卡、PrivacyInfo.xcprivacy、出现时机或确认持久化。
- 改动：`Modules/AppShell/Sources/AppShell/AnalyticsPrivacyNotice.swift`（默认读取 BuildConfig.buildTrack；正文独立 ScrollView、不限行、自然高度；标题与链接/确认按钮留在正文之外；测量三块高度适配 sheet），同目录 `AppShellStrings.swift`（可注入轨道的键选择/本地化 seam）、`Resources/Localizable.xcstrings`（CN 保留原键，Global 新键，四段定稿直接从卡复制；独立脚本逐字比对 4/4 相同）、`Modules/AppShell/Tests/AppShellTests/AnalyticsPrivacyNoticeTests.swift`（新增 3 测试），以及本 JOURNAL。
- 先红后绿：`analyticsPrivacyCopyUsesAccountLifetimeInBothTracksAndLanguages` 旧文案触发 7 条 issue（中英文仍含 90、缺账号存续与匿名化语句、Global 键不存在）→ 1/1 通过；`analyticsPrivacyBodySelectsTheRequestedBuildTrack` 缺少选择 seam 的编译错误 → 1/1 通过；`analyticsPrivacyBodyScrollsWithoutTruncationAndKeepsActionsOutside` 找不到 ScrollView → 1/1 通过，并覆盖正文无行数上限/按自然高度布局、标题和操作区在滚动正文之外、原隐私链接及确认回调。三项合跑 3/3 通过。红绿原始输出在 `/tmp/usage-notice-evidence/{copy,track,layout}-{red,green}.log`；轨道测试的红为缺 seam 的编译失败，不宣称是运行时断言失败。
- 最终验证：AppShell 全包 **107 passed / 0 failed / 0 skipped**（含既有 AuthFlowSnapshotTests，无基线更新）；3 个 Swift 文件 `xcrun swift-format lint --strict` **0 违规**、`swiftlint lint --strict --no-cache` **0 违规**。日志 `/tmp/usage-notice-evidence/{appshell-all-final,format,lint}.log`。初次依赖构建有 CoachKit 两条既有并发 warning、StudentKit 一条既有未使用表达式 warning，未修改范围外代码。独立只读 Standards / Spec 审查分别 CLEAN，0 findings；自测与审查不代替 Opus 验收。
- UI 证据：本 worktree `MeetPR.xcodeproj`，iPhone 17 / iOS 26.5（A5119984-9A8D-415C-83D4-E7145351FA79），DerivedData `/tmp/usage-notice-derived`。`MeetPR-Global / Global`、`MeetPR / Debug` 均 XcodeBuildMCP build_run_sim 成功、0 构建 warning。Global 英文默认字号末句完整；最大动态字体（启动参数 `UICTContentSizeCategoryAccessibilityXXXL`）可滚动到末句，标题、Privacy Policy、Got it 保持固定且可点。默认字号 Got it 后回登录页，停进程并去掉强制告知参数再启动，告知未再出现。CN 中文定稿完整可见。截图 `/tmp/usage-notice-evidence/global-en-default.jpg`、`global-en-ax5-top.jpg`、`global-en-ax5-bottom.jpg`、`cn-zh-default.jpg`，均已亲看。
- UI 验证限制：沿用模拟器既有安装/数据，通过进程参数 `-meetpr.analytics.privacy_notice_confirmed NO` 展示告知，未卸载或清空现有数据；因此**未覆盖卡验收 1/2 的全新安装前提**。无可用 iPhone SE（第 3 代），创建独立模拟器的 simctl 被沙箱拒绝（CoreSimulatorService / Operation not permitted），因此**验收 3 的 SE + 最大动态字体仍未覆盖**；iPhone 17 最大字号证据不能替代。最终两个测试进程均停止。
- “90 天 / 90 days / 90d TTL”全仓排查：运行时使用数据文案只命中原 AppShell 正文，现已替换；设置、帮助页、既有测试期望无其他同义副本。StudentKit `student.growthScreenPresentation.copy002`、USER-GUIDE/DEMO-SHOWCASE、设计稿/发版证据中的 90 天为成长曲线时间窗；spec 027 为 OSS 存储分层期限，均无关，保留。
- 文档交接：旧正典 `specs/043-analytics-instrumentation/SPEC.md` **317、351、413、422 行**仍写 90 天/90d TTL。新口径以本卡为准：账号存续期间保留，删除账号后与账号断开关联成为匿名记录，卸载清匿名安装标识，可删除账号或联系请求删除。按本轮正典文档归 Opus、JOURNAL 仅末尾追加的分工，未改旧 spec；这 4 处及相邻删除路径表述交 Opus 同步定稿，不能把本轮报告当作“全仓所有旧表述已清零”。

## 2026-10-04 · en-concatenated-labels（T1/P1，Opus 派卡，待收货）

- 按 `specs/084-walkthrough-polish/CARD-EN-LABELS-ios.md` 三项范围实装。分支 `fix/en-concatenated-labels`，开工/交付 HEAD `6c3f64b0`；与现场 `release/1.0` 的 merge-base 为 `202e95db`。未 commit、未 push；本节仅追加在 JOURNAL 末尾，未改任务卡、发布账本、Demo 数据、build 号或依赖。
- 中文硬约束：训练日原为「深蹲卧推日」，Dashboard 原为「深蹲、卧推日」；卡内「中文直接相连」与后者现状不一致，按 David 本轮“中文输出逐字不变”保留两处原输出。零/三主项分支保持原样。Dashboard 新增整句键 `student.dashboardTrainingDayName`，保留也用于星期日的 `student.dashboardTodayPresentation.copy011`（Sun/日）。英文单/双主项为 Deadlift day / Squat / Bench press day；恢复标签为 Medium Intensity / High Stress / About 2 days Recovery。

### 改动文件

均位于 `Modules/StudentKit/`（下列省略此前缀），加本 JOURNAL，共 11 文件：

- `Sources/StudentKit/Features/TodayWorkout/TrainingCalendarLogic.swift`：整句训练日名称；按 locale 连接主项。
- `Sources/StudentKit/Features/Dashboard/DashboardTodayPresentation.swift`：整句副标题；中文顿号、零/三主项原样。
- `Sources/StudentKit/Features/MyProfile/MainLiftExerciseFamilyResolver.swift`：主项名称 locale seam，原 property 继续默认当前语言。
- `Sources/StudentKit/Features/MyProfile/MyProfileV3Presentation.swift`：恢复标签整句占位符及可按语言验证的展示 seam。
- `Sources/StudentKit/Features/Onboarding/OnboardingLabels.swift`：三个恢复量表的 locale 重载；原公开属性/选项不变。
- `Sources/StudentKit/Features/MyProfile/MyProfileView.swift`：仅 recovery 标签允许换行、不缩字；injury 原行为不变。
- `Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`：抽出标题 View，普通字号保留原 HStack/Spacer；accessibility 字号用 VStack，让动作名占整行、单个 Ask coach 在下方。
- `Sources/StudentKit/StudentStrings.swift`、`Sources/StudentKit/Resources/Localizable.xcstrings`：新增 1 个双语手工键、4 个旧后缀改为整句模板；无其他 catalog 改动。
- `Tests/StudentKitTests/ConcatenatedLabelsTests.swift`：新增以下 3 个测试。

### 红 → 绿及检查条数

先写测试，再增加语言参数以运行旧逻辑取得真实断言红例，随后修复；未以编译/环境失败代替回归红例。

| 测试名 | 红例 | 绿例 |
| --- | --- | --- |
| `trainingDayNamesUseWholeLocalizedPhrases` | 1 测试失败、2 issues：DeadliftSun / SquatBench pressSun | 1/1；中英文单/双/零/三主项 |
| `dashboardLiftSubtitlesUseWholeLocalizedPhrases` | 1 测试失败、2 issues：DeadliftSun / Squat, Bench pressSun | 1/1；中英文单/双/零/三主项 |
| `recoveryChipsUseWholeLocalizedPhrases` | 1 测试失败、1 issue：三个标签数组缺空格 | 1/1；英文整句与中文原值 |

- 原始日志 `/tmp/en-labels-evidence/{training,dashboard,recovery}-{red,green}.log`。第一次直接 `swift test --package-path Modules/StudentKit --filter trainingDayNamesUseWholeLocalizedPhrases` 被沙箱 clang ModuleCache 写权限阻止；XcodeBuildMCP 首次随后报缺少 locale 参数的编译错误，补语言 seam 后才取得表中断言红例。首次 ViewInspector 更新网络有 HTTP2 warning，使用缓存后构建完成。
- StudentKit 首轮全量 932 项中 930 通过、2 失败：`inProgressHeroOwnsAskCoachEntry` / `completedSectionOwnsAskCoachEntry` 发现双候选 ViewThatFits 含两个 Ask coach 实例。保留原测试，改为单组视图后通过；实屏再发现自然宽度方案会提前改变默认字号布局，最终改用上文 AnyLayout。最终全量 **932 passed / 0 failed / 0 skipped**，XcodeBuildMCP `swift_package_test` 执行 `swift test --package-path .../Modules/StudentKit`，日志 `/tmp/en-labels-evidence/studentkit-final.log`（源日志 `swift_package_test_2026-10-04T03-29-41-779Z_pid31366_a7de3bf6.log`）。
- 最终工具链 `swift-format lint --strict`：**9 Swift 文件，0 违规，exit 0**；`swiftlint lint --strict --no-cache`：**9 文件，0 违规 / 0 serious，exit 0**。日志 `/tmp/en-labels-evidence/{format,lint}.log`。JSON 解析、仅 4 个模板及 1 个新增键的差异核对、中文后缀逐字核对、星期日旧键未变、`git diff --check` 均通过。
- `code-review` 独立只读 Standards / Spec 两轴及最终布局增量复审均 **CLEAN，0 findings**。未替代 Opus 收货，未改 SPEC 状态。

### 实屏证据与未覆盖验收

- XcodeBuildMCP：本 worktree `MeetPR.xcodeproj` / `MeetPR-DemoStudent` / `DemoStudent`，iPhone 17、iOS 26.5（A5119984-9A8D-415C-83D4-E7145351FA79），DerivedData `/tmp/en-labels-derived`。最终 `build_run_sim -skipPackageUpdates` 成功，0 warning，日志 `/tmp/en-labels-evidence/build-final.log`。
- 已亲看：英文 Today 的 Deadlift day；英文 Profile 三恢复标签完整可见、同字号自然换行；中文 Today 的「硬拉日」、Profile「中等强度 / 较高压力 / 约2天恢复」。截图 `/tmp/en-labels-evidence/{today-en,profile-en,today-zh,profile-zh}.jpg`。
- 最终标题：默认字号恢复 Competition / Deadlift 两行、右侧 Ask coach；accessibility-large（启动参数 `UICTContentSizeCategoryAccessibilityL`）完整显示 Competition / Deadlift，Ask coach 在下方。截图 `/tmp/en-labels-evidence/training-en-default.jpg`、`training-en-accessibility-large.jpg`。没有新增能准确测实际词内断行的布局单测，未用无关断言充数；原有唯一入口测试保留并通过。
- **未覆盖的卡验收**：验收 1/2 的“下一练”双主项卡片在中英实屏未到达（两处函数的双语输出已单测）；验收 3 指定的当前组 Competition Squat + Ask coach 未复现于最终 Demo（游标为 Deadlift，未改 Demo 数据），已用同样较长的 Competition Deadlift 验证；未做改前/改后默认字号截图逐像素对比。Opus 按原卡补验，不把这些替代证据写成完整验收通过。
- 无障碍大字号下的重量数字及其他卡外布局问题未改。模拟器只经正常导航与开始按钮，未录入/删除训练数据；测试进程已停止，语言/字号通过进程参数注入。

## 2026-10-10 · spec 085 iOS（开工核对阻塞，未实装）

- 工作树 `MeetPR-wt-085`，分支 `feat/085-today-final-walkthrough`，HEAD `a36e1f13`；开工工作区干净。第一条命令在当前目录以 `probe=$(mktemp "$PWD/.codex-write-probe.XXXXXX") && rm "$probe"` 试写并删除，exit 0、无输出。未转到其他目录写入，未 commit/push。
- 已读 CONTEXT、AGENTS、CLAUDE 发版路标、085–090 共同约定、085 SPEC 与 CARD-ios 全文；安卓 `137d816:src/domain/meet/weight-class.ts` 仅通过 `git show` 读取。

### 阻塞：指定训练日入口不能直接复用来满足验收 1b

卡片要求复用 `TodayWorkoutPlanHandoff` / `TodayWorkoutSelectionResolver`，且 SPEC §1 要求点概览卡后训练页选中同一天；SPEC Out of Scope 明确训练页本身不动，CARD-ios 文件范围只列 Dashboard、MyProfile、Onboarding、Shared、Resources 与对应 Tests。

现场代码证据（均为开工 HEAD，未修改）：

1. `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift:454` 的 `startWorkoutFromDashboard` 保存 handoff 后，无条件递增 `trainingJumpToken`；第 242 行将其传入训练页的 `jumpToTodayToken`。
2. `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift:115` 仅用 handoff 的 dayID 初始化 `@State selectedDayID`。
3. 同文件第 422 行监听 handoff 变化，却继续使用旧 `selectedDayID`；第 917 行要求旧选中日与新 handoff 日一致才能取得 handed-off plan，因此从已选 D1 切到 D2 的 handoff 不会在此更新选择。
4. 同文件第 428–433 行监听跳转 token，并调用 `returnToCurrentDay()`；第 597–598 行把选择设为 `sequencePage.currentSelection`（游标日）。这会把非当前日导航重置为当前日。
5. `StudentRootView.swift:213` 起以 ZStack 持有各 tab；`StudentTabAccessibilityHost.swift` 通过隐藏和固定 tab identity 切换，不能假设每次点卡都会重建训练页并重新执行 State 初始化。

以上为静态调用链证据，尚未运行模拟器复现。最小需要决策的范围调整：允许修复 `Features/TodayWorkout/TodayWorkoutView.swift` 的 handoff 接收与跳转处理，保证显式日选择优先，同时保留普通训练 tab / Start training 回当前日的行为；如增加接收端回归测试，需同时明确允许对应 TodayWorkout 测试 seam。未实施该调整，也未新建第二条导航路径。按 David「发现 SPEC 与 iOS 现状矛盾就停下来返回」的要求停止，未先做其余三项。

### 改动、测试与验收状态

- 改动文件：仅 `docs/CODEX-JOURNAL.md` 追加本节。Swift、资源、既有测试断言均未改；未改 SPEC、发布账本或 build 号。
- 五处 seam：级别表与格式、OnboardingDraft、DashboardProfileMetrics、ProfileSummaryFormatter、Today presentation，均未开始红/绿循环；新增测试 0，执行测试 0，无红/绿原始输出。
- 验收 1a 未实现/未测；1b 被上述入口阻塞；1c、1d 未实现/未测。
- 验收 2a、2b、2c 未实现/未测。
- 验收 3a、3b、3c、3d、3e、3f、3g 未实现/未测。
- 验收 4 未覆盖：五种老用户形态（手填级别、从未回答、有日期、备赛但无日期、体重一位小数）均未进行 Demo 或单测覆盖；留言保留与旧引导草稿恢复亦未验证。
- 验收 5 未覆盖：Light/Dark、中英文、最小屏及 accessibility-large 均未运行。
- 替换后的验收 6 未执行：未跑 StudentKit 全量、format、lint 或 DemoStudent 构建运行。未遇到 ModuleCache 报错，因此未使用缓存替代命令。
- 发现的卡外问题：上述 TodayWorkout handoff 接收行为；其余尚未完成调查。截图与构建/测试日志：无；本节保留静态证据路径及行号，不将代码检查写作实屏验证。

## 2026-10-10 · spec 085 iOS（实装与自测，待收货）

### 验收场景的最小范围补充（先记证据，后改）

- 默认 Demo 的 `StudentDemoSeed.makeOnboardingProfile` 固定 male / kg / 83 / 有比赛 / 已完成引导；`MeetPRApp.makeDemoRootView` 固定 accepted bond，无法经现有界面到达未填体重、other 男女表及第 7 步引导。共同约定允许启动参数 Demo 场景，David 修订一允许明确的小范围补充先记后做。
- 拟增加 `-spec085-profile <场景>`，只在 `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift` 的档案种子覆盖中生效；以及 `-spec085-onboarding`，只在 `MeetPR/Sources/MeetPRApp.swift` 的 DEMO seed 分支取消预置绑定，让现有邀请码→引导流程可到达。默认 Demo、线上依赖、存储结构和键保持原样。不修改 CoachKit。该补充不改变真实用户行为。

### 改动文件清单

本次共 36 个文件（包含本 JOURNAL）；CARD-ios.md 的修订一是用户已有改动，未由本轮编辑。

- `MeetPR/Sources/MeetPRApp.swift`
- `Modules/StudentKit/Sources/StudentKit/BodyWeightInput.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardDaySelection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardNutritionCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardOverviewCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardProfileMetrics.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardProfileMetricsView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardTodayPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardTodayScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Dashboard/DashboardWeekCalendar.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileV3Presentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/OnboardingSummaryFormatter.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileCardsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/BodyWeightField.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/MeetFieldsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/OnboardingDraft.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/Steps/Step1BasicsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Onboarding/Steps/Step7ExtrasSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/MeetClass.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/StudentSelectionBlock.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutSelectionResolver.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift`
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/DashboardProfileMetricsTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/DashboardProfileNavigationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/DashboardSelectionPresentationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/ProfileSummaryFormatterTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/MeetClassTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Onboarding/OnboardingDraftTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutSelectionResolverTests.swift`
- `docs/CODEX-JOURNAL.md`

### 六处 seam 的红 → 绿

证据目录统一为当前工作树 `.build/spec085-evidence/`，下列日志均为当时原始 stdout/stderr，未覆盖为手写摘要；新增 10 个 Swift Testing `@Test`，未删除既有测试。

| seam | 红例原始日志与结果 | 绿例原始日志与结果 |
| --- | --- | --- |
| 1 级别表、格式、解析 | `seam1-red.log`：新 MeetClass / MeetFederation 接口不存在，编译失败 | `seam1-green.log`：2/2，四家×两性别逐格、120+ / 67.5 往返、旧文本与无效联盟级别 |
| 2 引导 / 保存隔离 / 体重 | `seam2-meet-red.log`：1 测试 5 条真实断言失败；`seam2-weight-red.log` / `seam2-patches-red.log`：新过滤、分字段 patch 接口缺失编译失败 | 对应三个 `*-green.log` 各 1/1；kg/lb/逗号地区、小数截断、kg 往返、移除、三编辑页字段隔离 |
| 3 Today metrics | `seam3-red.log`：缺 weightClassText 编译失败 | `seam3-green.log`：1/1，83.00 / 83.50、旧级别、空级别、不备赛与缺日期 |
| 4 Profile 摘要 | `seam4-red-corrected.log`：缺 note 摘要接口编译失败 | `seam4-green.log`：1/1，Meet 与留言分别展示，留言首行、原完整值保留 |
| 5 Today presentation | `seam5-red.log`：缺选择与概览 presentation 接口编译失败 | `seam5-green.log`：2/2，选择/游标独立、重置、名称/状态/计数/动作顺序 |
| 6 指定日接收 | `seam6-red.log`：缺 receive 接口编译失败 | `seam6-green.log`：1/1，显式日、再次换日、无显式日返回 cursor |

- 不把编译红例写成断言红例。`seam1-interface-red.log` 是独立编译探针缺 Testing 模块；`seam4-red.log` 含测试枚举值笔误及修改编译中文件的错误，均不是有效行为红例，正式 seam 4 红例为已纠正后重跑的 `seam4-red-corrected.log`。
- 实屏发现 SwiftUI TextField 在 setter 过滤成相同值时仍显示第三位；`weight-filter-83-25.jpg` 是失败状态（显示 83.256），改成 raw text 状态、onChange 回写过滤值后，`weight-filter-fixed.jpg/.json` 显示 83.25。原六 seam 中的纯过滤测试无法捕捉 UIKit 文本缓存，未加浅层测试冒充该 UI 回归。
- seam 2 后补旧草稿 nil / false / true Codable 往返，以及 Remove meet 不影响体重、伤病、原多行留言的断言，仍在原 seam 内，最终全量覆盖。

### 既有断言变更（逐条依据）

| 文件 / 测试 / 断言 | 原值 | 新值 | SPEC 依据 |
| --- | --- | --- | --- |
| OnboardingDraftTests / step7CompetitionDateIsConditionallyRequired / 空草稿 | `!isStepComplete(7)` | `isStepComplete(7)` | §3「第 7 步不再因没回答是否备赛拦截」，未展开提交 false |
| 同测试 / true 且只有日期 | `isStepComplete(7)` | `!isStepComplete(7)`，随后增加格式化级别后断言 true | §3「展开后三项同样必填，缺项时这一步不能继续」 |
| DashboardProfileMetricsTests / metricsShowWeightOnlyWhenPresent | `76 kg` | `76.00 kg` | §2「全端体重显示统一保留两位小数」 |
| DashboardProfileNavigationTests / metricCardsRouteToExistingEditors（hasValues false / true 两例） | `.basics` | `.weight` | §2 与 2a「体重卡有值、空态进入的页面只有一个体重输入框」 |
| ProfileSummaryFormatterTests / basicsSummaryFormatsGenderAgeHeightWeight | `男 · 25岁 · 178cm · 83kg` | `男 · 25岁 · 178cm · 83.00kg` | §2 Basic information「该行显示两位小数」 |
| 同文件 / competitionSummaryShowsDateAndClassOrOptOut / 有值 | `备赛: 日期 · IPF 83kg` | `日期 · IPF 83kg` | §3 Meet 行「值为日期 · 赛事方与级别」；旧手填文字原样保留 |
| 同测试 / opt-out | `暂不备赛` | `未填写` | §3 Meet 行「没有比赛显示现有的未填占位」 |

首轮 23 条 issue = 上表新口径 8 条（路由参数化两例计两条）+ 15 条视频编码 issue；修正后的沙箱全量仍留 15 条视频 issue。未通过删测试、放宽条件或改视频逻辑换取绿色。

### Basic information 空体重核对

只读安卓 `git -C ../meetpr-rn show 137d816:...`：`src/features/profile/ProfileEditor.tsx:37–44` 对 basics 执行 `invalidFieldsForStep(form, profileSteps[section])`，只对 injuries/note 清空错误、对 weight 过滤错误，没有对 basics 放行。`src/features/profile/model.ts:9` 指定 basics 为第 1 步；`src/features/onboarding/model.ts:277–284` 调用 `bodyWeightKgFromInput(form.weightKg, 'kg')`，空体重产生 `weightKg` 错误；ProfileEditor 在 mutateAsync 前 return。结论：安卓明确禁止空体重时只改身高保存。iOS 保留 `.basics && draft.weightKg == nil` gate，与此行为一致；不是自行扩大必填范围。

### 全量、格式与构建

- 仅改 StudentKit 包（Demo app 不是新 SPM 包；未改 CoreModels / DesignSystem / CoachKit / Networking）。StudentKit 原 932 项，本卡新增 10 项，最终 **942 passed / 0 failed / 0 skipped**。
- 沙箱内命令（通过 `.build/spec085-evidence/run-tests.sh`，filter 空字符串代表全量）：

  ```sh
  env CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/clang-module-cache" \
    swift test --disable-sandbox --skip-update \
    --package-path "$PWD/Modules/StudentKit" \
    --scratch-path "$PWD/.build/spec085-tests" \
    --cache-path "$PWD/.build/swift-cache" --filter ''
  ```

- 系统 cache 权限/依赖代理失败的原始输出在 `test-environment.log`、`test-mcp-environment.log`。依赖离线缓存只读复制本机既有 ViewInspector bare repo 到当前 `.build/swift-cache/repositories`，未更新依赖、未改 HOME。沙箱全量 `studentkit-full-final.log` 942 项有 14 个失败测试、15 条 `Cannot Encode` issue（audio 参数化两例），不称为通过。
- 依照 2026-10-04 的 MCP 方法，先将 session configuration 设 Debug，再调用 `swift_package_test({packagePath: 当前工作树/Modules/StudentKit})`，执行真实 `swift test --package-path ...`。`studentkit-mcp-full.log` 942/942；Demo 与兼容性补断言后，`studentkit-mcp-interrupted.log` 曾 signal 11 中断，不计通过、根因未定；源文件不再改动、构建结束后同命令重跑 `studentkit-mcp-final.log` **942/942，0 skipped**，包括之前全部视频导出用例。未申请沙箱外 shell、未 stash、未另建基线副本（视频在可运行环境已真实通过）。
- `swift-format lint --strict` 用 Xcode 工具链绝对路径；`swiftlint lint --strict --no-cache` 用 Homebrew 二进制，输入文件清单 `swift-files.txt`，34 个 Swift 文件 **0 违规**，日志 `format-final.log` / `lint-final.log`。`git diff --check` 通过。
- `i18n-check.log`：29 个新增双语键逐项匹配安卓 RnExtras / StudentKit 目录，旧键 0 修改；JSON 可解析。StudentKit / CoachKit 无互相 import，未改任何 Package.swift。
- `MeetPR-DemoStudent` / DemoStudent / iPhone 17e（iOS 26.5，可用最小屏 390×844；无 SE）经 XcodeBuildMCP `build_run_sim({extraArgs:["-skipPackageUpdates"]})` 构建、安装、运行成功，0 warnings；`build-final.log`。DerivedData 在本 worktree `.build/DerivedData`。未使用 `xcodebuild test -scheme <包>`。
- `code-review` Standards / Spec 两位独立只读 reviewer，初审与最后输入同步 / Demo / 兼容性增量复审均 **CLEAN，0 findings**；不代替 Opus 收货。

- 大字号实屏补修：`today-zh-dark-large.jpg` 暴露新增两位小数后数字被拆成 83. / 00 两行；仅给体重数值加单行与缩放下限，保留原字体 token、单位与卡片结构，后续复验截图见验收项。

- 上述布局补修后最后一轮 `studentkit-mcp-final-layout.log`：**942 项 / 44 suites 全通过，0 失败、0 跳过**（Swift Testing 用例运行 5.721 秒，含视频导出）。`build-final-layout.log`：DemoStudent **BUILD SUCCEEDED**、0 warnings；随后显式安装最终 `.build/DerivedData/Build/Products/DemoStudent-iphonesimulator/MeetPR.app` 并运行，以下末轮截图来自这份产物。
- 额外 Coach Demo 构建的 MCP 调用曾超过 300 秒返回超时，但后台 xcodebuild 随后正常完成，`build-coach.log` 末尾为 **BUILD SUCCEEDED**；产物实际安装运行并拍到新格式。该构建未退出时，一次学生构建遇到 build.db 锁，随后等其结束再重跑成功。超时和锁冲突不计作成功构建，也未据此修改源文件。

### 验收清单逐项自测

以下是开发自测，不代替 Opus 按 CARD 收货。截图和同名 `.json` 均在 `.build/spec085-evidence/`；仅有 jpg 的早期截图用实屏记录和对应单测补证。Demo 数据为本地内存种子，没有操作线上账号。

| 原验收项 | 自测结论与证据 |
| --- | --- |
| 1a 周条选中 / 当前标记分开 | 通过。Demo 当前为 D3：默认 D3 粗框与金底；点 D2 粗框移动、D3 保留当前标记，返回重置。`today-en-light.jpg`、`today-selected-d2.jpg`；seam 5 同时断言选择与 cursor 状态。 |
| 1b 概览与指定日跳转 | 通过。名称、状态、全天动作/组数与单行动作名按所选日更新；D2 完成只读、再从 Today 点 D4 时内存中的训练页切到 D4 只读，返回 Today 重置 D3。`training-handoff-d2.jpg`、`training-handoff-d4.jpg`；seam 5/6。 |
| 1c Start training 不跟点选走 | 通过。点非当前日后页头与底部动作不变。训练页先翻到 W2，再从 Today 点 Start training 回 W1D3；普通 Training tab 同样回当前周当前日。`training-week2-before-start.jpg`、`training-week1-after-start.jpg`、`training-tab-resets-week.jpg`。 |
| 修订一 通知跳转 | 静态调用链和 seam 6 的 nil handoff 返回 cursor 通过；本轮未实际投递并点开系统通知，不写成通知端到端通过。TodayWorkoutView 只改 handoff / token 接收，通知发起处未改。 |
| 1d 已完成日 / 当天完成后概览 | 通过。先验证 D2 Completed；再用已有 `-student-empty-state next-plan-pending` 场景，在训练页长按完成已有三组日志的 D3，关闭完成页返回 Today，概览仍为 D3 / Completed，cursor 为 D4。`today-completed-overview-final.jpg/.json`。`today-completed-overview.jpg` 是尚未真正完成的前置状态，不作通过证据。 |
| 2a 单项体重、两位输入与补零 | 通过。有值/空态均仅一个体重框；第三位回写过滤，83.25 保存后 Today 显示 83.25 kg，整数保存显示 83.00 kg。`weight-en-light.jpg`、`weight-empty-editor.jpg`、`weight-filter-fixed.jpg/.json`、`weight-integer-saved.jpg/.json`。 |
| 2b lb 转换与再次保存 | 英文实屏通过：183.25 lb → Today 83.12 kg → 重开 183.25，再保存仍 83.12。`weight-lb-en.jpg/.json`、`weight-lb-stored-kg.jpg/.json`、`weight-lb-readback.jpg/.json`；seam 2 覆盖 183.26 的稳定往返。中文自动输入存在未解决验证缺口，见下节，不将英文结果外推为中文键盘通过。 |
| 2c Basic information | 通过英文实屏：同一组件过滤 83.256 为 83.25；Profile 摘要两位，保存后 Today 同步。`basics-weight-filter.jpg`、`today-after-basics.jpg/.json`、`profile-split-rows.jpg/.json`。空体重 gate 与安卓一致，依据见上节。 |
| 3a Meet 三字段、保存与教练显示 | 通过各端 Demo 展示：无是/否、无留言框；IPF + 83 kg 保存后 Today 倒数与新格式同时在。`meet-saved-today.jpg/.json`；教练 Demo 的申请档案显示 `2026-10-13 · IPF · 83 kg`，`coach-meet-formatted.jpg/.json`。两端是独立内存种子，未把该证据称为真实服务端跨端同步。 |
| 3b 四家 × 男女 | 通过。纯逻辑逐格断言全 8 张表；other 档案可点 Men / Women，中文深色大字号逐表截图 `meet-{cpa,ipf,ipl,wp}-{men,women}-zh-dark-large.jpg/.json`。 |
| 3c 必填与清选择 | 通过。缺赛事方点 Save 显示红色缺项和提示：`meet-validation-final.jpg/.json`。先选 IPF / 83 kg，再换 IPL，级别全部未选，滚到 Save 点后仍留编辑页并提示：`meet-switch-clears-class.jpg/.json`。三字段 patch / 缺项在 seam 1/2 覆盖。旧 `meet-reset-class-validation.jpg` 实际误点到了 Progress，不用作本项证据。 |
| 3d Remove meet | 学员路径通过：确认框 → 确认 → Not scheduled，`meet-remove-confirm.jpg`、`meet-removed.jpg/.json`；seam 2 断言只清比赛三字段且保留留言等。教练无比赛显示 `—`：`coach-no-meet-unanswered.jpg/.json`（nil 种子）；未在同一后台账号实测 false + null 日期/级别同步到教练，教练读取空字段路径静态核对。 |
| 3e Meet / Note to coach | 通过。两行独立入口，原留言完整可见；改为两行留言后摘要只显示首行，比赛不变。`profile-split-rows.jpg/.json`、`note-original.jpg/.json`、`note-saved-profile.jpg/.json`；seam 2/4 验证字段隔离与完整值。 |
| 3f 第 7 步 | 不展开完成、展开缺项拦截、选齐完成均实屏通过：`onboarding-step7-collapsed.jpg/.json`、`onboarding-step7-incomplete.jpg/.json`、`onboarding-step7-complete-selection.jpg/.json`、`onboarding-without-meet-completed.jpg/.json`、`onboarding-with-meet-completed.jpg/.json`。完成后现有 coached 流程进入待教练接受页，未继续到该新用户的 Today；false / null 和 true / 格式化级别写入由 seam 2 验证，Today 展示由 seam 3 / 已绑定 Demo 验证。此替代不算“新用户完成后 Today”端到端实屏通过。 |
| 3g 营养占位 | 中英位置与四格文案通过：`today-en-light.jpg`、`today-zh-dark-large-fixed.jpg/.json`。组件无 Button / gesture，运行时快照无可点击目标；自动化无法对非交互语义目标发送 tap，因此无反应以静态与语义树核对，未声称做过坐标点击。 |
| 4 老用户升级第一屏 | 按 CARD 允许的 Demo + 单测替换，五种形态逐条见下表；无迁移或回填，没有重新注册旧用户。 |
| 5 主题 / 语言 / 小屏大字号 | 用可用最小 iPhone 17e 390×844（未安装 SE）；英文 Light 普通字号检查 Today / 体重 / Meet，英文 Light accessibility-large 检查 Meet，中文 Dark accessibility-large 检查 Today / 体重 / 全部 8 张级别表。级别文本可按组件布局将 kg 换行，完整可见；修正后的 Today 83.00 保持单行。`meet-accessibility-before.jpg`、`meet-*-zh-dark-large.jpg`、`today-zh-dark-large-fixed.jpg`。未穷举语言×主题×字号所有交叉组合，也未做真实 SE 验证；共同约定允许无 SE 时替换。 |
| 6 iOS 替换验证 | StudentKit 942/942，34 个 Swift 文件 format / lint 0 违规；DemoStudent 最终构建、安装、运行通过。未改其他 SPM 包。 |

### 存量数据五种形态与额外数据保留

| 存量形态 | 覆盖方式与结论 |
| --- | --- |
| 手填级别 83kg / -93 | Demo `-spec085-profile legacy`：Today 83kg 与倒数，编辑灰字 Previously entered: 83kg，返回未变，重新选齐后新格式；`legacy-first-screen`、`legacy-edit-cancel-before`、`legacy-cancel-preserved` 三组 jpg/json。seam 1 拒绝把旧文字误解析成新选项，seam 3/4 原样显示；-93 作为原文字路径，未单独拍实屏。 |
| true 且有日期 | 默认 Demo + legacy 场景直接带回日期，Today 倒数原样；`meet-legacy-en.jpg`、`legacy-first-screen.jpg`；seam 3 用固定日期断言倒数为 2。 |
| false 或 nil | nil 用 `-spec085-profile unanswered`，首屏 Not scheduled，进入默认今天；`unanswered-first-screen`、`unanswered-add-default-date`。false 用 Remove meet 实屏；seam 2/3 各覆盖 false / nil，打开和取消不调用保存路径。 |
| true 但无日期 | `-spec085-profile no-date` 首屏 Not scheduled：`no-date-first-screen.jpg/.json`；seam 3 明确 nil 日期没有 competition metric，正常编辑可补全。 |
| 整数 / 一位小数体重 | 默认 83 显示 83.00，legacy 83.5 显示 83.50；seam 3 断言原 snapshot.weightKg 不变，组件初始化只格式化字符串，不回写 kg。只有保存才 patch。 |

- 留言：上述 Demo 种子覆盖只变目标字段，旧留言保持原值；`note-original` 与教练两组截图可见原文。seam 4 检查摘要首行但保留整段，seam 2 对 nil / false / true 存量档案应用 Remove patch 后逐项断言留言、体重、伤病不变。
- 引导旧草稿：seam 2 以 nil / false / true、旧日期、83kg、多行留言和 83.5 做 Codable 往返，完整 equality；nil / false 收起可过第 7 步、true 必须选齐新格式。`LocalOnboardingDraftStore`、存储键、Codable 字段均未改。未从真实旧版安装提取草稿，覆盖方式为单测。

### 验证缺口、卡外发现与交付状态

- **中文小数输入待复核**：同一最终 app 在英文 en_US 的 MCP `type_text` 能输入并保存 183.25；中文 zh-Hans / zh_CN 下整串输入分别只留下 183、1832，单独追加 `.` 也未出现。`weight-lb-zh-dark-large.jpg/.json`、`weight-lb-zh-final-attempt.jpg/.json` 保留失败状态。不能据此区分 MCP 键盘注入、系统输入法或组件问题；未把原因断言为工具限制，也未按猜测改过滤规则。需要原生键盘或真机复核，中文输入验收不通过。
- 为交叉验证而调用 Computer Use 获取 Simulator，被自动审批拒绝，未提供原因；未重试或绕过该拒绝。后续只继续已有 XcodeBuildMCP 验证。此处阻止了原生键盘交叉验证，不影响此前真实英文往返与全量单测结果。
- 未完成的端到端项：实际系统通知跳转；新引导完成并获教练接受后直接进入 Today；同一后端账号 Remove 后教练同步。以上替代证据已在逐项表注明，不冒充全验收通过。没有新增需要产品裁定的行为分支。
- 卡外既有问题未改：英文 accessibility-large 的 Today 旧 Weekly progress / Coach-recommended date 标题挤压；CoachKit 既有 Basic Info 体重仍显示整数（CARD 明确教练代码不改）；旧 Demo feedback-pending / next-plan-pending 只预填日志、不预置 sequence completion，不能仅凭场景名当作当天完成，需要实际长按完成。上述均未扩大改动。
- 首次 SwiftPM 编译可见既有 `TrainingReminderScheduling.swift:122` 未使用 Bool? 及旧测试并发 warning；未改其源文件。最终学生模拟器构建 0 warnings。MCP 的 signal 11 中断和沙箱视频编码失败作为原始失败日志保留，后续真正全量绿例独立保存。
- 两轴只读复审均无新 finding；末轮 reviewer 额外查看 `coach-meet-formatted`、`coach-no-meet-unanswered`、`meet-switch-clears-class`、`today-completed-overview-final` 的截图与 JSON，未发现新问题。截图证明最终画面，不替代操作链与数据断言。
- 日志、截图统一路径：当前工作树 `.build/spec085-evidence/`（ignored，不加入版本库）；核心最终日志 `studentkit-mcp-final-layout.log`、`build-final-layout.log`、`build-coach.log`、`format-final.log`、`lint-final.log`、`i18n-check.log`；六 seam 原始红绿文件见上表。`.build/opus/` 未动。
- 交付为当前 feature 分支的未提交工作区改动；未 commit、未 push，未改任何 SPEC、NEXT-RELEASE、RELEASES、build 号或后端；安卓仓全程只读。CARD-ios 修订一保留用户已有改动。

### 返修一（2026-10-10，Opus 收货两项）

- 仅返修 Remove meet 颜色与体重单项页字段标题。本轮改动 5 文件：`Features/MyProfile/ProfileCardsSection.swift`、`Features/Onboarding/BodyWeightField.swift`、`StudentStrings.swift`、`Resources/Localizable.xcstrings`（均在 StudentKit），以及本 JOURNAL；没有改测试或扩大功能范围。
- Remove meet 的 label 显式设置 `Color.MeetPR.dangerMuted`，与 `AccountSecuritySheets.swift` 的 Delete account 行同源，避免依赖外层可能覆盖的系统 destructive 着色；仍居中。确认框内 Remove 的系统 destructive role 与删除行为不变。
- 安卓依据：只读 `137d816:src/features/profile/ProfileEditor.tsx`，weight 映射到 `WeightSection`；`src/features/onboarding/OnboardingSteps.tsx:104–110` 默认 `labelKey = 'student.rn.weight.label'`；`src/i18n/catalog/RnExtras.json:242` 对应英文 **Weight**、中文 **体重**。BasicStep 第 98 行单独传旧 `student.step1BasicsSection.copy003`。原始摘录保存在 `.build/spec085-evidence/r1-android-reference.log`。
- iOS 为 BodyWeightField 增加带默认值的 labelKey，仅单项 `.weight` 分支指定新增的 `bodyWeightLabel`（Weight / 体重，逐字取安卓）；Basic information 和引导第 1 步继续用原默认标题。单项页导航标题仍为 Body weight / 体重，输入、精度、存储规则未改。
- 验证：XcodeBuildMCP `swift_package_test({packagePath: 当前工作树/Modules/StudentKit})`，Debug，**942 passed / 0 failed / 0 skipped**；`r1-studentkit-full.log` 与 `r1-test-result.json`。既有 `TrainingReminderScheduling.swift:122` unused Bool? warning 仍在，未顺手改。34 个改动 Swift 文件重新跑 `swift-format lint --strict`、`swiftlint lint --strict --no-cache`，均 **0 违规**（`r1-format.log/.exit`、`r1-lint.log/.exit`）。`git diff --check` 通过；既有断言未改，无新增样式测试。
- `MeetPR-DemoStudent` / DemoStudent 在 **iPhone Air、iOS 26.5** 重新 build_run_sim，158.3 秒，**BUILD SUCCEEDED、0 warnings**，安装并运行成功；日志 `.build/spec085-evidence/r1-build.log`。启动参数为 `-spec085-profile legacy`；英文 `-AppleLanguages '(en)' -AppleLocale en_US -meetpr.appearance light`，中文 `-AppleLanguages '(zh-Hans)' -AppleLocale zh_CN -meetpr.appearance dark`。
- 已亲看两种主题：Meet 移除入口浅色为深红、深色为浅红；英文体重页为 Body weight 导航标题 / Weight 字段标题，中文字段为体重。四张截图及同名语义快照：`.build/spec085-evidence/r1-meet-en-light.jpg`、`r1-meet-zh-dark.jpg`、`r1-weight-en-light.jpg`、`r1-weight-zh-dark.jpg`。未在本轮保存或移除 Demo 档案。
- 本轮增量只读复审 **0 findings**。两项返修均完成，无新增待决策问题；先前记录的其他验证缺口不在本轮范围。未 commit、未 push，未改发布文件、build 号或 SPEC。
## spec 087 iOS

### 开工基线（2026-10-10，代码修改前）

- 工作树 `MeetPR-wt-085`，分支 `feat/087-progress-menu`，HEAD `d07e328c`，开工工作区干净；临时文件试写并删除成功。
- 默认 MeetPR-DemoStudent，iPhone 17e / iOS 26.5：Squat **187.5 kg**、Bench press **118.6 kg**、Deadlift **178.5 kg**；Big-three e1RM total **484.6 kg**；Training 1RM total **520 kg**；训练次数 **2**、训练周 **1**、总容量 **3,525 kg**；反馈 **3 条 / 2 未读**。强度未解锁，原页显示 Complete 3 workouts to unlock trends。
- 截图与原始 UI 快照：`.build/spec087-evidence/baseline-progress-top.jpg`、`baseline-comparison.jpg`、`baseline-stats.jpg`、`baselineTop.json`、`baselineBottom.json`、`baselineStats.json`。默认 Demo 有多周 e1RM 点，但训练日志只有一周两次；多周训练验收需额外启动参数场景，不能把默认 Demo 称作多周训练。
- 安卓只读参照 `meetpr-rn@137d816`。iOS 原对比卡还有逐项比较条，原强度图也保留本平台画法，按卡的“现有 / 原样”边界保留；三段大号值、主线、低置信度与来源详情不改。

### 已确认的实现边界

- `StudentStrings.swift` 是现有本地化唯一边界，卡的 Resources 新增词条必须在那里增加 typed key 与复数入口，属于明确的小范围接线扩展。新增 sessions / new 使用 xcstrings plural 变体，不用英文拼接判断；macOS SwiftPM 未编译 xcstrings，沿现有 catalog fallback 路径读取复数变体。
- Demo 参数场景需要在现有 `Demo/` 种子和 `MeetPR/Sources/` 的 DEMO_MODE 依赖装配接入；计划只加参数分支，默认种子、线上依赖、存储键与结构不变。此为共同约定明确授权的验证场景扩展，不改 CoachKit。
- seam 5 的原要求是“现有测试不改断言而保持通过”；不故意破坏既有源码或断言制造红例，将保存修改前与修改后的原始回归输出，明确它是兼容性绿→绿，非新增行为红→绿。

### 改动文件与复用接口

以下均为本次未提交工作区改动，节奏 T2 / P1；未 commit / push，未改 SPEC、发版台账、build 号、后端或 CoachKit。

- `MeetPR/Sources/MeetPRApp.swift`：仅 DEMO_MODE 的日志仓储参数场景装配。
- `Modules/StudentKit/Sources/StudentKit/Demo/{StudentDemoSeed,ProgressDemoScenario}.swift`：默认种子保持原值，显式参数才注入边界场景。
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/StudentMenuRow.swift`：供 087 / 088 共用的导航行。
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/TrainingHistoryView.swift`：根页变为四行，NavigationStack 推入各目的页，保留刷新和通知入口。
- 同目录 `ProgressMenuContent.swift`、`ProgressMenuValues.swift`、`ProgressDataModel.swift`：菜单顺序 / 路由、值派生、共享现有 history / growth / feedback view model。
- 同目录 `ProgressE1RMPage.swift`、`ProgressE1RMSelection.swift`、`GrowthTotalPresentation.swift`、`GrowthTotalCard.swift`：四段与共用范围、Total 每日沿用求和及展示；单项仍调用原卡与原来源弹层。
- 同目录 `ProgressDetailPage.swift`：二级页共同加载 / 重试外壳与强度页，直接使用原 `VolumeIntensityChart`。
- 同目录 `GrowthComparisonCard.swift`、`GrowthHistoryStatsCard.swift`、`GrowthScreenHeader.swift`：从原根页提取现有组件；统计零训练显示 `—`，页头释义移入 e1RM 页。
- 同目录 `AllHistoryScreen.swift`：原列表前放三格统计；`GrowthE1RMCard.swift`：仅去掉零训练按钮限定为 squat 的条件。
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`、`Resources/Localizable.xcstrings`：新增 11 个安卓同文案词条，sessions / new 用 plural；既有词条语义改动 0（`localization-audit.json`）。
- `Modules/StudentKit/Tests/StudentKitTests/Features/TrainingHistory/{GrowthTotalTests,ProgressMenuTests,ProgressMenuNavigationTests,ProgressE1RMSelectionTests}.swift`：6 个新增 Swift Testing 测试，限卡指定的五个 seam。
- `docs/CODEX-JOURNAL.md`：本节。

088 直接调用 `StudentMenuRow(icon:title:value:valueColor:action:)`：`icon` 为 SF Symbol 名，`title` 为已经本地化的名称，`value: String?` 默认 nil，`valueColor: Color` 默认 `.MeetPR.textMuted`，`action: () -> Void`。名称与值各自按完整单行测量；总宽放不下时只把值整体放到名称下面并左对齐，无截断、词内折行、缩小。整行 Button，读屏合并“名称，值”；图标 / 箭头不重复朗读。无路由、数据源或 Profile 专属逻辑。

### 五处 seam 与原始输出

证据根目录均为 `.build/spec087-evidence/`，不是发布资产；既有测试断言删改 **0**，不存在需说明“旧值→新值”的条目。

| seam | 红与绿 | 结果与边界 |
| --- | --- | --- |
| 1 Total 纯函数 | `seam1-red.log` → `seam1-green.log` | 新类型未实现先编译红，1 个测试绿；`seam1-date-red.log` 记录日期被错误归零的失败，修为保留当日最后更新点时间戳。覆盖缺项、齐全日起、沿用、同日合并、低置信度与当前值。 |
| 1 真实打卡补验 | `seams-integration.log` → `seams-integration-green.log` | 新增真实 `E1RMRecorder` → repository → `GrowthCurveViewModel` → snapshot 路径。首轮 fixture 未使用计划内 exercise ID 导致零点，修正 fixture 后 6 个新增测试全部绿；未改生产算法。正常点逐日为 450 / 460 / 450 / 460，低置信度 900 不参与；headline 475 与 comparison 相等。 |
| 2 菜单值 | `seam2-red.log` → `seam2-green.log` | 新类型缺失红 → 1 个测试绿，涵盖中英文、单 / 复数、空 / 未读 / 全读、RPE 有 / 无 / 未解锁。 |
| 3 入口渲染与路由 | `seam3-red.log` → `seam3-green.log` | 新类型缺失红 → 1 个参数化测试（2 cases）绿；挂载真实四行组件，检查顺序 / 名称、四个点击目标、无图表、加载 / 失败仍可点。 |
| 4 e1RM 状态 | `seam4-red.log` → `seam4-green.log` | 新状态类型缺失红 → 2 个测试绿；默认 Total、范围循环且切段保持、对比 / 来源策略、三个 lift 的零训练 Today 按钮（3 cases）。 |
| 5 既有回归 | `seam5-before.log` → `studentkit-native-final.log` | 修改前相关子集 42/42；修改后纳入全量 948/948。此 seam 按卡“不改断言保持通过”，记录绿→绿，不伪造红例。 |

- 最终 StudentKit：XcodeBuildMCP `swift_package_test(packagePath: …/Modules/StudentKit)`，**948 passed / 0 failed / 0 skipped，44 suites**；`studentkit-native-final.log`、`studentkit-native-result.json`。其余 SPM 包未改源文件，无需新增包级测试。
- 沙箱 shell 全量原始结果：`studentkit-shell-full.log`，948 项中出现 15 个 `Cannot Encode` 视频编码 issue；原生入口最终全部通过，不豁免 / 删除这些测试。初次 native 调用因配置 DemoStudent 不适用 SwiftPM 而校验失败，随后切 Debug；缓存路径别名曾导致 Clang module 重复，清理生成缓存后重跑通过，均非代码测试失败。
- 复用 `.build/DerivedData` 与 `.build/spec085-tests`。为工具没有 scratch 参数的入口，包内既有 `.build` 仅保留指向指定 scratch 内容的链接；删除重复的约 746 MB 缓存，没有再建一套编译缓存。
- 最终 23 个变更 Swift 文件：`swift-format lint --strict` 与 `swiftlint lint --strict` **0 违规**，`format-final.log`、`lint-final.log`；文件表 `swift-files.txt`，`git diff --check` 通过。原生包编译有既有 Reminder / Video / Onboarding 测试警告，未扩范围修改。
- MeetPR-DemoStudent / DemoStudent，iPhone 17e / iOS 26.5，最终 `build-final.log` 构建成功、0 build warnings。
- 独立只读 Standards 与 Spec 审查均 0 findings；图表修正后两路定向复审仍 CLEAN。这是开发自审，不代替 Opus 按原验收清单收货。

### 实屏发现与修复

Total 的 Swift Charts 节点 overlay annotation 在 iOS 26.5 上稳定造成界面无响应：默认 Total 30 天→90 天即可复现，或单项 All history→Total；`total-chart-repro.json` / `total-all-settled.json` 为 AX 0 targets 的红例。按 diagnosing-bugs 流程先验证固定高度（仍卡，`total-fixed-height-chart.json`），再单独移除 annotation（恢复，`total-no-annotation.json`）。最终用同坐标两层 PointMark 画空心历史点，末点保持实心，恢复原宽高比；`total-chart-final` / `total-all-final` 证明原路径恢复、切段后范围保持。没有临时日志或算法改动；此为卡内新图表渲染问题，回归 seam 是实际 iOS UI，纯状态单测无法捕获 Swift Charts 布局挂起。系统 `sample` 被沙箱拒绝，未声称取得堆栈定位。

### Demo 参数

仅 `MeetPR-DemoStudent` 显式加 `-spec087-progress <值>` 才生效；不带参数仍是开工默认 Demo，无线上数据 / 存储结构变化。

| 值 | 场景 |
| --- | --- |
| `missing-lift` | 缺 Deadlift，Total 空态明确列缺项；有训练时单项零数据不出现 Today 按钮。 |
| `squat-only` | 四周 / 4 次，最近一天仅 Squat 160；Bench 最新 101、历史大号 102；Deadlift 最新 202、历史大号 205。Total 曲线末点 463、headline 467。 |
| `zero` | 零日志 / 零 e1RM，保留默认反馈 3 / 2，因此入口恰好三个 `—`。 |
| `single` | 一次日志，完整三项趋势；检验 `1 session` 和强度未解锁。 |
| `forming` | 一次日志、每项一个点，三项均为 1/3 成形中；Total 范围不足。 |
| `sparse` | 每项三个相同值，Total 及单项范围不足。 |
| `all-read` / `no-feedback` | 反馈全部已读 / 没有反馈。 |
| `multiweek` | 四周 / 4 次 / 2,000 kg，Total headline 462、曲线末点 455，RPE 8.0。 |
| `four-digit` | squat-only 重量乘 3，headline 1,401.0、曲线末点 1,389，用于大小屏 / 字号。 |
| `no-rpe` | 四周日志均无 RPE，强度入口 `—`，仍可进入现有柱图。 |
| `loading` / `load-failure` | 日志读延迟 8 秒 / 抛离线错误；失败持续存在直到去掉参数重启，供加载与重试观察。 |

语言 / 主题 / 字号使用进程参数，如 `-AppleLanguages (en) -AppleLocale en_US -meetpr.appearance light -UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`；中文为 `(zh-Hans)` / `zh_CN`，深色为 `dark`。未重置、关闭或操作 086 的模拟器。

### 第一步验收 1–12 开发自测

以下名称均指证据根目录下同名 `.jpg` 与 `.json`，除特别说明外为实际模拟器导航后的截图与 AX 快照。未改 SPEC 勾选项，不把开发自测称作终审。

| 项 | 自测结论与证据 |
| --- | --- |
| 1 四行入口 | 通过。仅页头与 e1RM / Training history / Coach feedback / Intensity metrics，顺序、图标、值、箭头完整，无图表 / 三格 / Body weight。`default-menu-en`、`default-menu-zh.jpg`。 |
| 2 右侧值各状态 | 通过。默认 484.6 / 2 sessions / 2 new / —；`forming-menu` 为 1 session；`missing-menu` Total —；`zero-menu` 三个 —；`feedback-read-complete` 与 `all-read-flag-menu` 为反馈总数 3；`no-feedback-menu` 为 —；`multiweek-menu` 为 RPE 8.0；`no-rpe-menu` 为 —。中文对应 `menu-zh-dark-large`。 |
| 3 四段与范围 | 通过。初进 / 返回再进 Total + 30 days；30→90→All history→30；90 天单项切 Total、All history 单项切 Total 均保留范围。`default-total`、`default-squat-90`、`range-all`、`total-chart-final`、`total-all-final`、`reentry-total`；纯状态测试另覆盖循环。 |
| 4 Total 口径 | 数值 / 序列 / 缺项自测通过。`squat-only-{total,squat,bench,deadlift}`：大号 160 + 102 + 205 = 467，入口与对比 467；曲线末点 160 + 101 + 202 = 463，相比首点 450，变化 +13。真实打卡 seam 验证每个更新日出点及低置信度不参与。`missing-total` 明确 Still missing: Deadlift；`zero-total` 列全部缺项；`constant-total-sparse` 为范围不足。Total 代码无手势 / 点选 callback，AX 无来源按钮；**未做曲线坐标点按实测**：MCP 只接受交互元素 ref，Computer Use 对 Simulator 返回未授权，因此未越过该权限边界。 |
| 5 对比仅 Total | 通过。Total 保留原 484.6 / 520 两值与逐项条，深蹲超过时原绿色 104% 行仍在；其他三段没有对比。`default-total`、`default-{squat,bench,deadlift}`、`total-chart-final`。 |
| 6 三段四态与来源 | 通过。三段均看过零数据（`zero-{squat,bench,deadlift}`）、成形中（`forming-{squat,bench,deadlift}`）、范围不足（`default-{squat,bench,deadlift}`）、曲线（`squat-only-{squat,bench,deadlift}`）。零训练三段均有 Today 按钮，有日志而缺硬拉则没有（`missing-deadlift`）。来源改前 / 改后 `baseline-source` / `default-source-after`：10/7、187.5 kg、深蹲第 3 组、142.5×5、RPE 7.5、76%、142.5÷0.76，逐项一致。 |
| 7 历史三格与双入口 | 通过。`default-history`、`training-history-entry` 都是 2 / 1 / 3,525 kg，与基线一致；列表内容和筛选保留。`zero-history` 三个 — 与既有空态；`multiweek-history` 为 4 / 4 / 2,000 kg。 |
| 8 反馈与已读回流 | 通过。新行推入现有 FeedbackInboxView，3 条；逐条进入详情后返回从 2 未读→1 未读→总数 3，`default-feedback`、`feedback-all-read-return`（中间态为 1）、`feedback-read-complete`。Today 仍按 iOS 原交互先展开卡，再进入同一 FeedbackDetailView（`today-feedback` / `today-feedback-open`）；未把 Today 改成安卓的整个收件箱入口，见差异说明。 |
| 9 强度页 | 通过。`intensity-en-large` 四周柱 + RPE 线 + 原图例；`default-intensity-locked` / `zero-intensity` 保留 Complete 3 workouts to unlock trends；`no-rpe-intensity` 保留原柱图无 RPE 数据的画法。原图源文件没有改动。 |
| 10 加载 / 失败 / 刷新 | 通过所要求的状态与点击自测。`loading-menu` 值留空、四行可点，`loading-e1rm` 等待态；注入 URLError 离线错误后 `failure-menu` 值留空 + Failed to load · Retry。四行逐个进入 `failure-{e1rm,history,feedback,intensity}` 均不崩溃，各自加载失败或已有数据。点击 Retry 和下拉后仍处持续离线态（`failure-after-retry-refresh`）；正常多周场景下拉后值保持（`multiweek-after-refresh`）。没有切断真实网络，也没有宣称验证同一进程断网再联网恢复。 |
| 11 升级第一屏 | **部分覆盖**。修改前默认 Demo 基线已在开工保存；构建覆盖安装而未卸载 / 清数据后，Total / 三段数值 / 2 次 / 1 周 / 3,525 kg / 3 反馈与 2 未读全部一致。零训练三个 — 和页面空态已验。默认 Demo 只有一周两次，新增 `multiweek` 证明四周场景的新页面派生值，但没有修改前同一多周场景的覆盖安装证据；因此不把“升级前已有多周训练”这一前提记为完成。 |
| 12 主题 / 小屏 / 字号 | 通过共同约定允许的替代设备检查：没有已安装 SE，使用可用最小 iPhone 17e（390×844）。英文 Light 普通字号 `default-menu-en`，英文 Light accessibility-large `menu-en-light-large`，中文 Dark accessibility-large `menu-zh-dark-large`；四位数 1,401.0 kg 入口值完整，名称不截 / 不缩，宽度不足时值整体下一行。未做真实 SE 或穷举所有语言×主题×字号组合。 |

大字号补修：`total-zh-dark-large` 暴露新增 Total 数字被 delta 挤成两行；仅新 Total 卡用 AnyLayout 在 accessibility 字号下把变化量放到数字下方，并令重量单行。`total-zh-dark-large-fixed` 的 1,401.0 kg 完整；普通字号仍同行。随后全量 948/948、严格 lint / format 与原生构建再次通过，Standards 定向复审 0 findings。原对比卡在此字号 / 四位数下仍会折行，按“原样搬入”边界记录，不在本卡改旧组件布局。

### 与安卓差异、范围外问题与待补验证

- 保留 iOS 原三段文案（包括英文 Bench press）、原四态 / 来源弹层与卡内轴线画法；切换按钮的 Bench 取安卓词条。既有 e1RM 释义和范围不足提示不替换成安卓排版文案。
- Total 对比两格继续使用 iOS 原卡，包含逐项对比条与逐项突破文案；没有换成 RN 两张独立 StatTile + 合计百分比的表现。强度图完整复用 iOS 原柱线与图例。二级页保留现有底部 Tab 栏。
- Today 反馈卡保留“展开→单条详情”现状；Progress 行进入现有反馈收件箱，再进入同一个详情。Today 详情路径的既有已读处理与收件箱路径不同，此次未动 Today / FeedbackInbox 功能。
- 原对比卡的大字号四位数折行、默认 Demo 仅一周两次的基线限制均未隐藏；多周 Demo 的历史统计来自四周日志，旧历史列表仍照原计划分组，未为场景改列表算法。
- 没有新增产品决策或接口 / 存储问题需要 David 裁决。待 Opus 补验的是第 4 项物理坐标点按，以及第 11 项严格的升级前多周训练前提；第 12 项采用共同约定的小屏替代。未扩到第二步体重、测试 seam 6–8 或验收 14–21。
- 证据根目录 `.build/spec087-evidence/`；核心日志为 `studentkit-native-final.log`、`studentkit-shell-full.log`、`build-final.log`、`format-final.log`、`lint-final.log`，五 seam 原始日志见上表；审查摘要 `review-results.txt`。截图仅存文件，不进入产品资源或正典发布台账。
- 最后复位：去掉所有场景 / 语言 / 字号参数重新启动，`final-default-menu` 仍为 484.6 / 2 次训练 / 2 未读 / —，`final-default-total-90` 可正常显示曲线；已实际点过零训练 Deadlift 的 Today 按钮（`zero-today-action`）。交付时停在默认 Progress 入口。分支仍 `feat/087-progress-menu` @ `d07e328c`，25 个工作区文件，提交数未增加；完整工作区补丁 `spec087-working-tree.diff`。

## spec 088 iOS

### 开工基线（2026-10-10，代码修改前）

- 临时文件在本工作树试写、删除成功；`feat/088-profile-redesign`，HEAD `99cf27b3`，初始工作区干净。默认 `MeetPR-DemoStudent` 构建运行成功，复用 `.build/DerivedData`。
- 原设备证据因并发占用作废。以下基线值已经在专属 iPhone 17 Pro / iOS 26.4（`8F164D5D-A450-44FD-BDBF-BB351572CF6E`）用原 HEAD 包重新确认；中文、浅色，无场景参数。
- 改前截图：`.build/spec088-evidence/baseline-top.jpg`、`baseline-middle.jpg`、`baseline-bottom.jpg`。

| 自上而下名称 | 改前实际值 / 行为 |
| --- | --- |
| 页头 | MeetPR、消息与通知（3） |
| 我的资料 | 副标题「训练基线 · 教练管理」 |
| 当前 1RM | 深蹲 180 kg / 卧推 120 kg / 硬拉 220 kg |
| SBD 总和 | 520 kg |
| 锁定说明 | 训练周期中无法修改 · 联系教练；说明当前 1RM 入口 |
| 恢复与伤病 | 小标题「恢复与伤病 · 改动通知教练」 |
| 恢复评估 | 通知教练；中等强度 / 较高压力 / 约2天恢复 |
| 伤病记录 | 通知教练；肩部伤病 |
| 偏好与基础信息 | 分组标题 |
| 想增强肌群 | 股四头 / 腘绳肌 / 肩 |
| 外观 | 浅色；跟随系统 / 浅色 / 深色 |
| 组间休息 | 自动 (按 RPE) |
| 训练提醒 | 关 |
| 比赛 | 2026-10-13 · IPF 83kg |
| 给教练的留言 | 想冲全国赛,请多关注深蹲底部速度 |
| 身高 / 体重 | 178 cm · 83.00 kg |
| 训练背景 · 环境 | 分组标题 |
| 训练背景 | 3 年 · 低杠深蹲 · 传统硬拉 |
| 训练环境 | 周一·三·五·六 (4天/周) · 商业健身房 |
| 账号与安全 | 分组标题 |
| 改密码 | 无值，打开现有弹层 |
| 导出训练数据 | 无值，打开现有弹层 |
| 退出登录 | 红色按钮，直接调用退出，无二次确认 |

### 实现边界与已核实差异

- iOS 原页未显示 Delete account（`showsDeleteAccount: false`），本卡明确要求展示，复用现有流程。
- `User.phone` 已同时承载 Global 邮箱 / CN 手机号（既有 Global auth 测试佐证）；从 AppShell 现有 session 传到 StudentRootView / MyProfileView，第一步不读取 `User.name`。需要在卡范围外给 `AppShell/RootView.swift` 增加一个参数接线，不改实体、接口协议、存储与网络。
- 教练使用现有 `ActiveCoachContext`（只由已通过绑定生成），不新增请求。
- seam 4 原要求是既有断言不改且保持通过：留改前 / 改后回归输出，不故意破坏既有实现制造红测试。CLI 初次运行被默认 ModuleCache 写权限挡住，原始报错保存为 `seam4-before.log`，改用已授权的 XcodeBuildMCP SwiftPM 入口。
- Today 原生路径直接在自己的 NavigationStack 打开 `DashboardProfileEditor`，不经过 Profile Tab；保持原状。

### 首轮 seam 证据

- seam 1：`seam1-identity-red.log`（新增类型缺失）、`seam1-values-red.log` → `seam1-green.log`（2 passed）。首字母 / fallback / accepted coach / 菜单有无值与中英文。
- seam 2：`seam2-red.log` → `seam2-green.log`（2 passed）。身份卡 + 五行、三种不可用状态 Settings 可点；旧快照保留、失败重试状态恢复。
- seam 4 改前：`seam4-before-mcp.log`（74 passed）。原 CLI 的缓存权限失败在 `seam4-before.log`。
- 一次测试构建期间误修改新增测试文件，SwiftPM 报 `input file ... was modified during the build`；该轮无效，随后串行重跑并得到上述绿结果。后续构建期间不修改源码。

- Demo 补充范围证据：默认 Demo 经过 BindGate，只能到完整已绑定档案，无法覆盖空档案 / 首次失败 / 无绑定。新增 `Demo/ProfileDemoScene.swift` 与 app 入口的显式 `-spec088-profile` 分支；只在 DemoStudent 且明确传参时使用内存依赖，退出仍调用真实 Session.logout。默认种子、存储与接口不变。异常场景不提供账号弹层（该流程在默认 Demo 验证）。

### 证据失效与重新采集

- David 确认另一工作树 spec 090 同时在 `D412AE31-0ED9-4A23-B0FD-FFFA4A5A5609` 安装同 bundle；本任务在该设备上的全部截图与实屏结论作废，已删除截图，不把旧 UI / 红屏误判为本次代码问题。
- 后续专属设备：iPhone 17 Pro / iOS 26.4，`8F164D5D-A450-44FD-BDBF-BB351572CF6E`，由宿主提前启动。先把当前工作区变更逐文件备份到 `.build/spec088-source-backup`，临时恢复 `99cf27b3` 构建改前包；构建后立即逐文件还原全部变更。无 checkout、commit、push、外仓写入。基线与新版使用同一 DerivedData，之后同 bundle 覆盖安装、不卸载、不清数据。

### 改前每一行 → 改后入口

| 改前行 / 信息 | 改后位置 |
| --- | --- |
| MeetPR、消息与通知（3） | 首屏页头保留 |
| 我的资料 + 训练基线副标题 | 首屏 My profile；副标题按 spec 去掉 |
| Current 1RM 三项 180 / 120 / 220 | 身份卡 Squat / Bench / Deadlift（省略格内 kg） |
| SBD total 520 | 身份卡 Total（金色数字） |
| 当前 1RM 说明与锁定提示 | 身份卡四格 / 小锁说明均打开原说明 |
| 恢复评估三项值 | Health & recovery → Recovery assessment → 现有状态打卡 |
| 伤病记录（肩部伤病） | Health & recovery → Injury history → 现有编辑 |
| Notify coach 胶囊 / 通知副文 | 按 spec 去掉；仅伤病编辑与打卡最终保存上方灰字 |
| 想增强肌群（股四头 / 腘绳肌 / 肩） | About me → Muscles to improve |
| 外观（浅色，跟随系统 / 浅色 / 深色） | Settings → Preferences → Appearance 三块 |
| 组间休息（自动按 RPE） | Settings → Preferences → Rest between sets |
| 训练提醒（关） | Settings → Preferences → Training reminders |
| Meet（日期与组别） | 首屏 Meet 右侧值；点开同一比赛编辑页 |
| Note to coach（完整留言） | 首屏 Note to coach 显示 Added；点开同一编辑页看全文 |
| 身高 / 体重（178 / 83.00） | 首屏 About me 摘要 + About me → Basic information |
| 训练背景（3年、低杠、传统） | About me → Training background |
| 训练环境（周一三五六、商业健身房） | About me → Training environment |
| Change password | Settings → Account → Change password |
| Export training data | Settings → Account → Export training data |
| Sign out（原为红字、无确认） | Settings 页底描边主文字色按钮；仍直接退出 |
| 原分组小标题 | 按 spec 收拢到二级页，不属于丢失的数据 |
| Delete account（原首屏隐藏） | 按本卡明确要求展示 Settings → Account → Delete account，原流程复用 |

- 工具选择器补记：首次切新设备同时传入名称与 UDID，XcodeBuildMCP 后台按名称又选中了同名 iOS 26.5 设备，基线构建误装旧设备；随后只传明确 UDID，安装、启动、截图返回均核实为 `8F164D5D-…`。`session_clear_defaults` 曾被自动审批拒绝（approval policy never），通过 `session_set_defaults` 只设 UDID 的正常入口完成替代，无绕过权限。

- 大字实屏返修：`large-pro-before.jpg` 在独占 Pro 的 accessibility-large 上复现长 Meet 值跨卡片右边界。087 共用 `StudentMenuRow` 原先对值 `.fixedSize()` 并无限宽测量，整体下移仍不足以容纳最长值。保持名称单行与共用组件，值先整体下移；超过整行宽时按可用宽度在词间折行，禁止截断。Settings 同用此 Layout。该改动属于共同约定明确要求的 087 / 088 共用行行为。

### 实屏自测（专属 Pro 上重跑，不等于 Opus 收货）

| 验收项 | 自测结果与证据（目录均为 `.build/spec088-evidence/`） |
| --- | --- |
| 1 | 通过：iPhone 17 Pro 默认字号，中英文不滚动可见完整五行；无分组标题/内嵌控件/退出。`home-en.jpg`、`home-zh.jpg`。页头原消息未读红点按现状保留，卡片及菜单没有红色元素。 |
| 2 | 通过：默认手机号 + 人像；`email` 为邮箱 + S；`no-coach` 隐藏教练行且名字垂直居中，头像均不可点、无上传暗示。`home-zh.jpg`、`identity-email.jpg`、`identity-no-coach.jpg`。 |
| 3 | 通过：180/120/220/520 对齐改前，格内无单位；`missing-lift` 为302.5/120/—/—，锁定说明与整组四格是同一按钮，打开原说明。`missing-lift.jpg`、`onerm-info-zh.jpg`。 |
| 4 | 通过：默认四项有值，`unanswered` 对应 — / No injuries / — / —；Settings 无值。`home-en.jpg`、`state-unanswered.jpg`。纯函数补中英文、有无值与 Other injury。 |
| 5 | 通过：两个二级页逐项对应原内容，四个 About 编辑入口全部实点；伤病与恢复均打开原编辑。把体重83改84保存，二级页与首屏立即更新。`about-en.jpg`、`health-en.jpg`、`editor-background.jpg`、`editor-environment.jpg`、`editor-muscles.jpg`、`about-saved-84.jpg`、`home-saved-84.jpg`。 |
| 6 | 通过：伤病保存按钮上方灰字；Profile 打卡与 Today → Training 的既有状态入口各进入最终保存步骤，均有灰字。其他编辑页没有。`editor-injuries.jpg`、`readiness-profile-save.jpg`、`readiness-today-save.jpg`。iOS 默认 Demo 的 Start training 先切 Training，状态打卡由该页既有心形入口进入，未改开练门禁。 |
| 7 | 通过：外观三块、Preferences 三行、Account 三行与描边退出；切 Dark 后立即生效，重启仍保持。休息改手动即时保存，再还原自动；提醒获系统授权后开启，返回摘要更新；密码弹层打开，导出 CSV ready，删号仅到输入确认前并取消；Sign out 直接回登录。`settings-en.jpg`、`settings-dark.jpg`、`home-dark-relaunch.jpg`、`settings-rest-saved.jpg`、`reminder-enabled.jpg`、`settings-reminder-saved.jpg`、`account-password.jpg`、`account-export.jpg`、`account-delete-before-confirmation.jpg`、`signout-login.jpg`。 |
| 8 | 通过：Today 体重卡直接到体重专用编辑，改84保存回Today；Meet 卡直接到原Meet编辑，选IPF/83kg保存回Today，无二级页绕行。`today-weight-editor.jpg`、`today-weight-saved.jpg`、`today-meet-editor.jpg`、`today-meet-saved.jpg`。 |
| 9 | 通过：`loading`、`failure`、`empty` 均可到Settings并调用真实Session退出；失败时其余四行分别进入带重试的目标页，不崩溃。刷新失败保留180/120/220/520与全部菜单值，点击重试恢复。`state-loading.jpg`、`loading-settings.jpg`、`loading-signout.jpg`、`state-failure.jpg`、`failure-settings.jpg`、`failure-signout.jpg`、`state-empty.jpg`、`empty-signout.jpg`、`refresh-before.jpg`、`refresh-failure-retained.jpg`、`refresh-retried.jpg`。网络错误在仓储边界注入URLError，不是真实关闭系统网络。 |
| 10 | 通过本地Demo覆盖：专属设备先安装HEAD原包并逐行记录，再同bundle覆盖安装新版，无卸载/清数据；默认完整档案/伤病/Meet/留言/绑定种子逐项保持（上表）。无绑定/未填档案见场景截图并可退出。Demo档案是现有内存种子，重启重新载入；没有声称覆盖真实后端账号或持久化服务端迁移。本次没有存储/接口变更。 |
| 11 | 未完成实屏复验：独占 Pro 上大字发现长值越界，已修复共用行并通过最终测试、lint 与构建；17e 的显示服务不可用，四种语言/主题组合均未取得有效截图。详见下方最终补验与原始错误。 |

### Demo 启动参数与已知差异

- 默认启动不带 spec 参数，仍为原 DemoStudent 完整种子。085 参数原样保留，可继续与本卡同时使用，不改变默认首屏。
- 显式 `-spec088-profile`：`email`、`phone`、`no-coach`、`loading`、`failure`、`empty`、`unanswered`、`missing-lift`、`refresh-failure`、`long-identity`。`refresh-failure` 第二次fetch失败，第三次成功；`loading` 持续挂起到退出/取消；`long-identity` 为长邮箱/长教练名及302.5与642.5。
- 语言 `-AppleLanguages (en) -AppleLocale en_US` / `(zh-Hans) zh_CN`；大字 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`；显式主题 `-meetpr.appearance light` / `dark` 仅作截图参数。默认外观偏好未改。
- iOS名字位取现有User.phone（Global可存邮箱）；手机号显示人像，与安卓登录轨不同；教练来自ActiveCoachContext。原编辑内容、摘要格式、提示/保存路径全沿用iOS，包括旧Meet自由文本显示与保存后规范化。
- iOS二级页用系统导航栏（标题居中），返回手势与原编辑页一致；不另做安卓导航组件。异常Demo直接展示Profile，因此不提供Tabs/消息/账号弹层依赖；正式Root与默认Demo均完整，账号流程在默认Demo验证。
- spec外观察：原英文训练环境摘要拼成 `weekMon·Wed·Fri·Sat`，原伤病摘要 `Shoulders injuries`，密码/删号sheet系统Cancel按钮窄时截断；均不在本卡编辑内容范围，记录而未改。

### 独立审查

- Standards 初轮0 blocker/1 nit（退出测试单次Task.yield不保证完成）；已改明确continuation，定向复审0 blocker/0 nit。
- Spec 初轮0 blocker/1 nit（Settings真实容器顺序覆盖不足）；补实际容器中休息/提醒顺序和值、三个Account按钮顺序、外观与退出存在性。相关2测试通过，定向复审CLEAN。
- 两个reviewer均只读、未启动构建或模拟器。大字排版finding依据主代理实屏红图返修；两轴确认同一共享行修复符合约定。代码未提交或推送，功能最终验收留给Opus。

### 改动文件清单

- `MeetPR/Sources/MeetPRApp.swift`
- `Modules/AppShell/Sources/AppShell/RootView.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/ProfileDemoScene.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/AccountSecuritySheets.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/AppearancePreferenceRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/MyProfileViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileCardsSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileDetailPage.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileHomeContent.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileIdentity.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileIdentityCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileMenuValues.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfilePageRows.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ProfileSettingsContent.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/RestTimerPreferenceRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/TrainingReminderPreferenceRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Readiness/ReadinessCheckinSheet.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/ProfileCoachNotificationNote.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/Shared/StudentMenuRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift`
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/ProfileDetailPagesTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/ProfileHomeNavigationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/ProfileHomePresentationTests.swift`
- `docs/CODEX-JOURNAL.md`

### 最终测试与原始日志

- StudentKit：956 passed / 0 failed / 0 skipped（原有948 + 本卡新增8）；`studentkit-native-final.log`、`studentkit-native-final-result.json`。四个批准seam之外未加测试。
- AppShell：107 passed / 0 failed / 0 skipped；`appshell-native-final.log`、`appshell-native-final-result.json`。唯一生产改动是现有User.phone传入StudentRootView。
- `swift-format lint --strict`、`swiftlint lint --strict --no-cache`：25个改动Swift文件，均exit0/0违规；`format-final.log`、`lint-final.log`、`swift-files.txt`。原大文件3条多余disable已删除。`git diff --check`通过。
- seam 3：`seam3-red.log`（新二级页组件缺失）→ `seam3-green.log`（前三seam共7测试passed）；审查补强后 `seam3-review-green.log`（Settings2测试passed）；最终8个新增测试在全量绿中。
- seam 4：改前 `seam4-before-mcp.log`（74 passed）→ 最终全量956 passed；既有测试断言0删除/0修改，无需断言迁移清单。此seam按卡要求保持既有断言，故为绿→绿，不伪造红。
- AppShell缓存路径别名曾触发重复Darwin模块/编译器signal11；移出旧ModuleCache并用原生入口在同一物理测试缓存重建后通过，未新建依赖缓存。沙箱CLI两项Keychain测试3条断言失败保留在 `appshell-sandbox-keychain.log`，原生107项全绿为最终结果。StudentKit沿用XcodeBuildMCP真实环境，视频导出用例亦在全量中通过。
- 现有非本卡测试的Swift6警告保留（VideoTrim/Bind/Onboarding测试辅助代码），本卡未新增编译warning。

### 最终排版修复与待补实屏

- `StudentMenuTextLayout` 改为按可用宽度测量和放置长值；放不下同行时先把完整值移到下一行，仍超过整行时自然折行。名称维持单行、不缩小，值不截断。该 Layout 同时供 Profile、087 Progress 菜单与 Settings 行使用。
- 身份卡锁定说明上方的分隔线移除额外左右缩进，铺满卡片内部宽度；四格、字号、取整和点击行为不变。
- 这些调整之后的 StudentKit 956 项、严格格式/静态检查与 DemoStudent 构建均通过。最终构建原始日志 `build-final.log` 结尾为 `BUILD SUCCEEDED`；随后安装/运行阶段超时，不能将构建成功记作 17e 运行成功。
- 宿主已关闭专属 Pro，改启动 iPhone 17e / iOS 26.4（`BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`）。MCP 默认设备已改成该 UUID，列表显示 Booted，但 screenshot 连续报 `Device does not have a 'default' display port`（NSPOSIXErrorDomain 22），Home 报 `Mach port not connected`，snapshot 无法取得 UI。`open_sim` 成功返回仍未恢复显示。原始结果保留 `17e-runtime-errors.json`；Computer Use 对 Simulator 返回未授权，未绕过权限。

| 第 11 项最终包组合（iPhone 17e，accessibility-large） | 结论 |
| --- | --- |
| English / Light | 未验到：设备显示服务不可用，无有效截图 |
| English / Dark | 未验到：同上 |
| 中文 / Light | 未验到：同上 |
| 中文 / Dark | 未验到：同上 |

- 最终排版变更影响第 1 项（默认五行布局）、第 3 项（身份卡分隔线）、第 4 项（菜单长值排版）、第 7 项（Settings 行）与第 11 项。**修复后均未在 Pro 默认字号重看**；前文第 1–10 项截图为修复前专属 Pro 的有效交互证据，不代表最终版排版已复验。共用组件的 Progress 长值排版也需随收货复看。
- 需要宿主启动专属 iPhone 17 Pro / iOS 26.4（`8F164D5D-A450-44FD-BDBF-BB351572CF6E`）时再补默认字号复核；17e 四组合需先恢复该设备显示服务。未操作其他设备，也未为本次失败换用 `D412AE31-…`。
- 没有待拍板的产品/接口/存储问题；剩余是上述实屏验证缺口。未宣称第一步验收全部通过，交 Opus 收货时补验。

### 交付产物

- 最终 App：`/Users/david/Projects/apps/MeetPR-wt-085/.build/DerivedData/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`（`MeetPR-DemoStudent`，含最后排版修复）。保留完整 bundle，未改 build 号。
- 截图、四 seam 红/绿日志、全量测试结果与构建日志：`/Users/david/Projects/apps/MeetPR-wt-085/.build/spec088-evidence/`。截图仅以文件交付，不贴图；`large-pro-before.jpg` 是修复前问题证据，不能当成修复通过截图。
- 模拟器：专属 Pro `8F164D5D-A450-44FD-BDBF-BB351572CF6E` 已由宿主关闭；专属 17e `BBE9EB95-01DE-452E-866C-3DD0B62F9BDA` 交宿主关闭。工具默认值留在 17e，不持久化到项目配置。
- 分支保持 `feat/088-profile-redesign`，未 commit、未 push；未改任何 SPEC、NEXT-RELEASE、RELEASES、后端或 CoachKit。
- 清理完成：本次源码临时备份、旧 ModuleCache、DerivedData 的编译/索引/模块缓存、除最终 App 外的构建产品、StudentKit 与复用 spec085 测试目录中的编译结果及构建数据库均已删除。保留依赖 checkouts/repositories、已有其他 spec 证据及本卡原始日志；没有新建第二份依赖缓存。最终 App 完整保留，约 63 MB；其 `MeetPR.debug.dylib` SHA-256 为 `c45496ff6eb113384a189bf1ebb547995e62a481d7acb0222e238b00d638749b`。
- 安装重试补记：独立 `install_app_sim` 最后返回 17e 安装成功（`17e-install-result.json`）；这只确认包已安装，不能替代启动、截图与第 11 项实屏验证。最终 bundle 的 `codesign --verify --deep` 亦通过。
- 最后一次 English / Light / accessibility-large 启动在 300 秒后超时，之后的 snapshot/screenshot 仍报相同系统显示错误，未取得 App 画面；原始返回文本及启动参数见 `17e-final-launch.log`。没有继续创建或启动其他模拟器。

### 返修一

- 来源：Opus 收货补验确认 Pro 默认字号首屏五行、身份卡与 Settings 符合屏幕稿，StudentKit 956/956 通过；在可用 17e 上发现大字号四格分别缩放，以及数值/单位断行两处问题。本轮只改这两处，不改数据来源、显示文案或默认种子。
- 本轮改动文件：`Features/MyProfile/ProfileIdentityCard.swift`、`Features/Shared/StudentMenuRow.swift`（均在 StudentKit），以及本 JOURNAL。
- 身份卡：标签与数字分为两排，分别顶部和首基线对齐；用当前 Dynamic Type 下四个原始数字的最大自然宽度与等宽列宽算出一个共同字号。能放下时比例为 1，继续用原 size22；不再给每格独立的 minimumScaleFactor。
- 共用列表：按原文的 ` · ` 分段，段内 Text 整体测量和放置，只在段间换行。`178 cm`、`83.00 kg`、`IPF 83kg` 和日期均不会拆开；可见文本与整行读屏原文保持不变，087 入口共用同一实现。
- 视觉红证据使用 Opus 提供的两张实屏，已复制为 `r1-opus-before-en-light-large.png`、`r1-opus-before-zh-dark-large.png`。这轮为两处排版修复，没有新增纯逻辑 seam 或修改任何既有测试断言；通过对应实屏前后对照和全量回归验证。
- Standards 与 Spec 两位 reviewer 分别只读审查相对本轮改前快照的两文件 diff，均为 0 blocker / 0 nit（CLEAN），未代跑模拟器或测试。
- 分段值另保留完整原文的 accessibilityLabel，实屏快照确认读屏标签仍为 `About me, 178 cm · 83.00 kg` / `关于我、178 cm · 83.00 kg`；Spec 对该两行补丁定向复审仍为 CLEAN。

| 返修一实屏项 | 设备 / 启动条件 | 结果与证据 |
| --- | --- | --- |
| Profile 英文浅色大字 | iPhone 17e / iOS 26.5，`-spec088-profile long-identity`，`UICTContentSizeCategoryAccessibilityL`，en / light | 通过。302.5 / 120 / 220 / 642.5 同字号、同基线，标签顶部对齐；About / Meet 的值在中点分隔处换行，单位不单独落行。`r1-17e-en-light-large.jpg` |
| Profile 中文深色大字 | 同一 17e，long-identity，accessibility-large，zh-Hans / dark | 通过。四格对齐；`178 cm`、`83.00 kg`、`IPF 83kg` 均保持整段，长邮箱/教练名正常截断。`r1-17e-zh-dark-large.jpg` |
| 默认 Profile 英文浅色 | iPhone 17 Pro / iOS 26.4，不带 spec 参数与字号覆盖，en / light | 通过。180 / 120 / 220 / 520 保留原 size22，首屏不滚动看到全部五行，默认值未变。`r1-pro-en-light-default.jpg` |
| 087 Progress 英文浅色大字 | 17e，`-spec087-progress squat-only`，accessibility-large，en / light，点 Progress Tab | 通过。四行依次 e1RM / Training history / Coach feedback / Intensity metrics，值 Total 467.0 kg / 4 sessions / 2 new / RPE 8.0；整段未拆、未重叠。`r1-17e-progress-squat-only-large.jpg` |

- 四张最终截图均来自最后同一 App；目录为 `.build/spec088-evidence/`，对应语义快照为 `r1-ui-snapshots.json`。前文“最终包未实屏复验”的历史缺口由 Opus 补验与本轮上述结果补上；本轮按返修要求复查英文浅色、中文深色两组合，未额外重跑其余组合。
- 最终 DemoStudent 构建日志 `r1-build-final.log` 为 `BUILD SUCCEEDED`。第二次 MCP 调用曾在 300 秒后返回等待超时，实际构建继续完成，随后自动安装/启动；通过中文场景与新读屏标签确认最终代码已运行，不把超时报错当作编译失败。
- 设备 UDID：17e `5D5FA360-BA49-48C6-A887-2F0D22F89749`，Pro `8F164D5D-A450-44FD-BDBF-BB351572CF6E`。两台 App 均已停止；MCP 无关机工具，沙箱 simctl 关机失败（`r1-shutdown.log`），交宿主关闭。本轮没有操作 `D412AE31-…` 或已弃用的 `BBE9EB95-…`。
- 最终 App 路径仍为 `/Users/david/Projects/apps/MeetPR-wt-085/.build/DerivedData/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`；签名完整校验通过，`MeetPR.debug.dylib` SHA-256 更新为 `2fc20c7450736ee99b629ada3a780cb8f76e0790bee4f1e320f84fb20608cbd1`。未 commit、未 push。
- 最终回归：XcodeBuildMCP `swift_package_test` 对 StudentKit 全量 **956 passed / 0 failed / 0 skipped**，日志 `r1-studentkit-full.log` / `r1-studentkit-result.json`。未改其他包，本轮不重复 AppShell 全量。25 个本卡改动 Swift 文件的 `swift-format lint --strict`、`swiftlint lint --strict --no-cache` 均 exit 0 / 0 违规（`r1-format.log`、`r1-lint.log`）；`git diff --check` 通过。
- 编译警告如实保留：测试输出包含本轮未改的 ProfileDetailPagesTests 多余 try 提示，以及原 Onboarding / Bind / VideoTrim 测试并发提示。本轮没有扩到这些文件；不宣称编译日志零 warning。
- 本轮要求的两处返修、四张截图和回归均已完成；没有未做到的实装项或待决策问题。设备关机受沙箱限制，已列 UDID 交宿主处理。
- 收尾再次清掉本轮编译/索引/模块缓存、除最终 App 外的构建产品与 StudentKit 测试编译结果；依赖下载缓存、全部原始证据和最终 App 保留。清理后再次通过 App 签名完整校验与 diff 空白检查。独立审查摘要另存 `r1-review-results.txt`。
## 2026-10-10 · spec 086 iOS（开工核对，因现状矛盾停止）

- 工作树：`MeetPR-wt-086`；分支：`feat/086-training-strip-coach-note`；HEAD：`a36e1f13`。启动时在当前目录用 `mktemp "$PWD/.codex-write-check.XXXXXX"` 创建临时文件并删除，退出码 0；初始工作区干净。未 commit、未 push。
- 改动文件清单：仅 `docs/CODEX-JOURNAL.md` 追加本节。代码、测试、Demo、SPEC、发布台账均未修改。

### 阻塞：只读 hero 备注的“保持改前行为”与 iOS 现状不符

- SPEC §3 与 CARD-ios「iOS 上要注意的地方」要求：只读态备注保持改前行为，即“组级备注，没有才显示动作备注”；测试 seam 3 同时要求只读态行为不变。
- 当前 iOS `TodayWorkoutPresentation.swift:257` 的 `Exercise.note` 仅取 `CoachNoteDisplay.text(exercise.notes)`；`TodayWorkoutScreen.swift:660–675` 的 hero 下方灰色备注块直接显示这个 `exercise.note`，没有按 `isEditable` 区分，也没有读取 `row.draft.prescribed.coachNote`。因此当前可编辑态及已完成只读 hero 都只显示动作备注，并不存在描述中的组级优先回落行为。
- `coachNote` 字段确实存在于 `StudentPrescribedSet`，`StudentPlanProjection.swift:101` 也保留了它；不是后端缺字段。历史详情 `Features/TrainingHistory/DayDetailView.swift:61` 另有逐组备注展示，不等于训练页 hero 的取值策略，且不在本卡修改范围。
- 待 David/Opus 裁定：A）“只读态不变”按当前 iOS 事实执行，继续只显示动作备注；可编辑 hero 才新增组级小灰块并上移动作备注。B）以安卓行为为最终口径，iOS 只读 hero 也改为组级优先、动作级兜底，明确这属于新增行为而非保持现状。未替用户选择。
- 按本次指令“发现 SPEC 与 iOS 现状矛盾时停下来”停止实装。未发现需要更换推荐日期算法的证据：现有周条消费 `StudentPlanDay.date`，已有后移日期的周条测试；本次不改派生。

### 测试、验收与证据状态

- seam 1（落后派生）：未新增测试，未执行红/绿。
- seam 2（周条 presentation）：未新增测试，未执行红/绿。
- seam 3（hero 备注）：因上述矛盾未新增测试，未执行红/绿。
- seam 4（既有训练页测试）：既有断言零修改，未运行；没有人为制造失败。
- 测试结果数字：新增 0，执行 0；未宣称通过。StudentKit 全量、其他包测试、swift-format、SwiftLint 均未执行。
- 原验收 1、2、3、3b、4、5、6、7、8、8b、9、10、替换后的 11：全部未实装、未验证。
- 老用户升级第一屏：落后两周以上、进度正常两种形态均未覆盖；未创建 Demo 开关，默认 Demo 未改变。
- 未构建或启动模拟器，未触碰另一工作树的模拟器或缓存。无截图及测试日志路径；本节源码路径与行号是此次核对证据。XcodeBuildMCP 仅查询 session defaults，未设置构建配置。
- spec 外问题：未展开调查或修改；本次唯一阻塞是本卡只读态行为定义与 iOS 基线不符。

## 2026-10-10 · spec 086 iOS（实装交付，修订一取 A）

本节接续上面的开工阻塞记录。David/Opus 已在 CARD-ios「修订一」裁定 A；按裁定实装。工作树 `MeetPR-wt-086`，分支 `feat/086-training-strip-coach-note`，基点 `a36e1f13`。各次续作均在工作树试写、删除临时文件成功。未 commit、未 push；没有修改 SPEC、NEXT-RELEASE、RELEASES、build 号、后端、存储结构/键、依赖或 Dashboard。CARD-ios 的修订一是用户交接时已有的改动，不是本次实现改写。

### 改动文件清单

以下路径均相对仓根；仅 StudentKit 与本 JOURNAL：

- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCalendarLogic.swift`：从现有有效推荐日期派生 isBehind / daysBehind，不改游标推进。
- 同目录 `TrainingWeekPresentation.swift`（新增）：格子文字、无障碍标签、当前周落后胶囊。
- 同目录 `TrainingWeekStrip.swift`：箭头移到格子两端，删除独立周行与小点；提供合并后的周标题。
- 同目录 `TrainingWeekCalendarRow.swift`：星期/图形/日期或 Behind；休息无日期；圆点 8、对勾 12；保持宽度比与横滚，横滚初始定位选中格。
- 同目录 `TrainingWeekHeaderLayout.swift`（新增）：单行宽度不足时按内容比例压缩，防三位数天数截断，历史入口靠右。
- 同目录 `TodayWorkoutScreen.swift`：周次/胶囊/进度与历史同排；可编辑 hero 动作备注上移、组备注下方独立显示。
- 同目录 `TodayWorkoutView.swift`：传递 gymDayToday，并在进入、前台、现有计划刷新触发时更新。
- 同目录 `TrainingDayPreview.swift`：已落后时隐藏推荐日期行，其他情况消费现有 `day.date`（含教练后移）。
- 同目录 `CoachNoteDisplay.swift`：纯函数区分可编辑/只读备注来源，新增淡金动作备注 View；只读仍只取动作备注。
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`：新文案访问及原有 macOS DEBUG 测试资源回退支持 xcstrings plural。
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`：中英逐字采用 Android `137d816` StudentKit/RnExtras 对应值，daysBehind 与读屏采用 plural one/other；休息读屏移除日期。
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift` 与新增 `TrainingStripDemoScenario.swift`：仅启动参数启用的正常、落后、三位数、长备注和后移场景。
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TrainingWeekCalendarTests.swift`：新增 1 项。
- 同目录 `TrainingWeekPresentationTests.swift`（新增）：新增 2 项。
- 同目录 `CoachNoteReviewDisplayTests.swift`：新增 2 项。既有断言零删除、零改写。
- `docs/CODEX-JOURNAL.md`：本次开发自测与原始证据记录。

### 四处 seam 与最终检查

全部证据目录 `/tmp/spec086-evidence/`；红阶段是先写测试、公开 seam 尚不存在造成的真实编译失败，未伪造 assertion failure。

| seam | 红 | 绿 |
| --- | --- | --- |
| 1 日期与落后天数 | `logic-red.log`，缺 isBehind/daysBehind | `logic-green.log`，新增 1 项通过；完成/同日/18 天/0 天/凌晨 03:59 与 04:00/后移 |
| 2 周条 presentation | `presentation-red.log`，缺 presentation 类型 | `presentation-green.log`，新增 2 项通过；三种训练格、休息无日期、读屏、当前/非当前、英文 1/18/123 与中文 |
| 3 备注取值 | `notes-red.log`，缺 heroExerciseNote/heroLowerNote | `notes-green.log`，新增 2 项通过；动作有/无/空白、组级有/无、互不影响、只读 iOS 旧取值 |
| 4 既有训练页回归 | 无独立人为制造的红；前述编译红阶段全套无法运行。卡要求既有断言不改，故不为了红灯破坏现有行为 | 全量 `studentkit-delivery.log`：937 passed / 0 failed / 0 skipped，45 suites，含既有保存、完成、补记、set-ref、周条及备注测试 |

最终全量是在行长修正之后重新执行；新增合计 5 项，既有 932 项保持通过。实际执行入口：XcodeBuildMCP `swift_package_test({packagePath:"/Users/david/Projects/apps/MeetPR-wt-086/Modules/StudentKit"})`，session configuration `Debug`，内部运行 `swift test --package-path .../Modules/StudentKit`。沿用 JOURNAL 2026-10-04 的 MCP 路径，不使用包 scheme 的 xcodebuild test；本轮未需另设 clang ModuleCache 权限绕行。最终原始源日志 `swift_package_test_2026-10-10T07-48-59-067Z_pid52792_17dbf7b8.log` 已复制到上述目录。其余包零改动，因此没有额外包测试。

最终 `swift-format lint --strict` 和 `swiftlint lint --strict` 均检查 `swift-files.txt` 所列 15 个 Swift 文件：各 exit 0、0 违规；日志 `swift-format.log`、`swiftlint.log`。格式化工具为 Xcode toolchain 内的 swift-format；SwiftLint 为 `/opt/homebrew/bin/swiftlint`。`git diff --check` 通过。`resource-boundary-check.log` 记录新增/调整键 manual、中英齐全、Android 文案逐字、plural 与 StudentKit 无 CoachKit import 的检查；既有 StudentStrings 本地化测试在全量内通过。

### 验收逐项开发自测

以下是开发自测，不代替 Opus 按卡收货。

| SPEC 项 | 结论与证据 |
| --- | --- |
| 1 | 实屏：训练格星期/图形/第三行，无 D 序号；休息星期+Rest/休，无日期。见正常与落后截图。 |
| 2 | 实屏：完成格保留日期、未到期和恰为今天显示日期、未完成过期为金棕 Behind。单测覆盖三分支。 |
| 3 | 实屏：过期预览无旧推荐日期（`behind-preview.jpg`），未到期预览仍有推荐日期（`normal-preview-zh-dark.jpg`）；落后 18 天能开始并记录 3 组，无落后弹窗/拦截。已完成日期按 §1 保留。 |
| 3b | 0/1/18/123 天文案有单测；正常/18/123 有实屏。翻其他周 Upcoming 不带天数。长按完成当前日后 18→16、2/4→3/4，见 `completion-cursor-16days.jpg`。 |
| 4 | 实屏符合 2B，同排周次/胶囊/进度/历史，左右箭头、无小点。源码格子 minHeight=64、箭头 height=64（均≥44）。 |
| 5 | 已实操首/末周箭头、Back to today、点选未完成预览与已完成日；选中框与当前淡金格分离，见 `behind-preview.jpg`、`completed-readonly.jpg`。 |
| 6 | `--spec086-shift` 将同周第 4 日后移 5 天，周跨度 12 天；在中文 accessibility-large 实操横滚到后移格，未挤压，见 `shifted-scroll-zh-light-large.jpg`。既有 shiftedRecommendationExtendsCalendarBeyondSevenDays 测试未改。 |
| 7 | 有备注的可编辑 hero 在动作名下展示金块，灰块仅为组级；无动作备注的当前 Squat 无金块；空白由纯函数测试覆盖。中英≥200字符备注均滚动到末尾，无截断，见 hero-long-* 上/下截图。 |
| 8 | Deadlift 第 1→2→3 组动作备注保持一致，各组下方小灰字为 3-second eccentric。只读完成日金块消失，原灰字动作备注保留，见 `completed-readonly.jpg`。 |
| 8b | 实屏完成绿色对勾、当前金色实心、未轮到空心可区分；源码分别 size12 / size8，格高未变。 |
| 9 | 以有两天完成历史的同构 Demo 数据覆盖正常和落后 18 天第一屏：normal-en-light / normal-zh-dark、behind-en-light。记录组、计时、结算与游标重算均实操（`recorded-set-rest-timer.jpg`、`completion-cursor-16days.jpg`）。这是存量形态模拟，不是对真实账号执行安装升级；未改存储键/结构。 |
| 10 | 无可用 iPhone SE runtime/device，按共同约定取现有最小 iPhone 17e（390pt 宽）+ accessibility-large；英文 Dark、中文 Light 均检查三位数与长备注。默认字号中英 Light/Dark 已看。滚动视口边缘可出现下一格的部分内容，格内文字完整；选中当前格进入时居中。 |
| 11 | StudentKit 937/0/0；两 lint 0 违规；DemoStudent 独立 DerivedData 构建与运行记录见下。 |

长按完成确认：模拟器实际录入 3 组，长按完成按钮 2200ms，进入原有完成弹层，Done 返回 Today，再进 Training 游标到 W1D4、落后为 16 天；回选 W1D3 为已完成只读。`HoldToCompleteButton`、gesture state、完成保存链路均零改动，原测试保留。工具曾提示快照未稳定，重新 snapshot 后确认成功，没有把工具超时误认成功。

### Demo、存量形态与复验方法

使用 `MeetPR-DemoStudent` / `DemoStudent`，向 app 进程传下列 launch args；默认不传任何 spec086 参数：

- `--spec086-normal`：两天已完成，第 3 天推荐日期恰为 gymDayToday，第 4 天未来，含休息格。
- `--spec086-behind`：相同完成历史，当前日落后 18 天；已完成格仍有合法历史日期，未完成过期格无旧日期。
- `--spec086-behind123`：三位数落后天数。
- 上述任一基础场景可再加 `--spec086-shift`：同周第 4 日后移 5 天，验证 >7 天横滚；可加 `--spec086-long-note`：重复现有 Demo 备注至 ≥200 字符，不引入新的产品文案。
- 英文 `-AppleLanguages (en) -AppleLocale en_US`；中文 `-AppleLanguages (zh-Hans) -AppleLocale zh_CN`；大字号 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`；默认字号 `UICTContentSizeCategoryL`；主题 `-meetpr.appearance light` / `dark`。

默认 Demo 首屏不改的代码证据：无参数时 scenario=nil，原 startDate/todayOffset/day offset/endDate、完成状态、notes、仅第一组 coachNote 均沿用原分支；shift helper 返回 nil，long-note 无参数原样返回。没有写新的 UserDefaults 键；上述 Demo 场景是进程参数，不持久化。原有 Demo tests 保留并在全量通过。

### 平台差异、范围外问题与验证边界

- 修订一：只读 iOS 从来只取动作备注，已原样保留。iOS 原有 Last time 参考行在重量上方，本卡未搬它；新小灰组备注位于下方、仍在该行之后。iOS hero 的 Ask coach 与标题布局、完成流程保留。
- 既有大字号 logo 显示成 ME…R、概览动作标题词内换行、重量 175 换成 17/5 的问题不在卡内，未改。见大字号截图。此前全量重编译出现 18 条既有 Bind/VideoUpload 等测试并发警告；最终增量全量无警告，未为清警告越界改测试。
- 未实测真实时间跨凌晨 4 点的驻留/后台全过程；03:59/04:00 算法有单测，前台/进入刷新有源码接线。未用真实线上账户安装升级，存量验证方式如上。未分别构建 CN/Global 正式包；实现无按轨分支。
- 开始选用的 iOS 26.5 iPhone 17e 安装包中途被并行作业覆盖，后切换先前 Shutdown 的 iOS 26.4 iPhone 17e（`BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`）继续；没有关闭、重置或清掉其他设备。DerivedData 始终 `/tmp/spec086-derived`。尝试 shell 创建 SE 时沙箱 CoreSimulatorService 连接被拒，未绕权限；故使用共同约定的最小可用设备替代。
- Standards / Spec 独立只读审查均无 blocker；Layout 非有限宽度 nit 已处理。自测不宣告 Opus 验收通过。不需要新增产品裁定。

### 最终构建与证据索引

- 最终 `build_sim`：`MeetPR-DemoStudent` / `DemoStudent`，`-skipPackageUpdates`，独立 `/tmp/spec086-derived`，成功（111.5 秒），工具返回 0 errors / 0 warnings；原始日志已复制为 `/tmp/spec086-evidence/build-delivery.log`。随后 install_app_sim + launch_app_sim 成功；运行源日志 `com.meetpr.app_2026-10-10T07-55-27-106Z_helperpid81663_ownerpid52792_4132f6ab.log`。
- 最终包复验截图：`final-normal-en-light.jpg`、`final-behind123-en-dark-large.jpg`、`final-behind123-zh-light-large.jpg`。正常时左侧周次/胶囊/进度紧凑、历史右对齐；大字号时三位数完整同排。
- 默认不传 spec086 参数的最终启动截图：`default-demo-first-screen.jpg`。首屏仍为 Today、W1D3 Deadlift、2/4、原始连续推荐日期与已完成历史。Dashboard 代码零变动；对照 Demo diff 的 nil 分支与原有测试，未把验证场景变成默认首屏。
- 其余截图均在同一目录：`behind-en-light.jpg`、`behind-preview.jpg`、`normal-en-light.jpg`、`normal-zh-dark.jpg`、`normal-preview-zh-dark.jpg`、`hero-en-light.jpg`、`hero-no-exercise-note.jpg`、`hero-long-en-dark-large-top.jpg`、`hero-long-en-dark-large-bottom.jpg`、`hero-long-zh-light-large-top.jpg`、`hero-long-zh-light-large-bottom.jpg`、`shifted-scroll-zh-light-large.jpg`、`recorded-set-rest-timer.jpg`、`completion-cursor-16days.jpg`、`completed-readonly.jpg`。`behind123-en-dark-large-before-fix.jpg` 是修正前失败证据，不能用于最终通过结论。
- 验收 8 的覆盖边界补充：已看同一 Deadlift 三组保持原动作备注、结算后下一个训练日 Squat 无动作备注时没有旧金块残留；未在同一训练日实屏跑出“两条不同非空动作备注”的切换（现有组合日三个动作的备注均为空）。取值每次直接消费当前 exercise.note、无缓存，且纯函数测试两来源互不影响；不把该源码证据写成已看过该形态。
- 无真实安装升级账户、没有 SE 设备、没有实时跨 4 点全过程的限制仍按上文保留；不需要用户作新的产品决定。功能代码交付待 Opus 收货，未修改任何 SPEC 验收勾选或状态。

## 2026-10-10 · spec 089 iOS（开工核对：休息偏好存储待裁定）

- 工作树 `MeetPR-wt-086`，分支 `feat/089-accessory-quick-log`，HEAD `36770eaa`，初始工作区干净。当前目录创建并删除临时文件成功，exit 0。已读共同约定、089 SPEC / CARD-ios、086 JOURNAL 与 ACCEPTANCE；未 commit、未 push。
- 改动文件清单：仅本 JOURNAL 末尾追加记录；尚未修改代码、测试、Demo、SPEC 或发布账本。

### 需要裁定：只追加一个字段不能表达现有自动模式

现场证据位于 `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/StudentRestTimerSettings.swift`：

- 第 109–120 行：`setPreference(.automatic)` 删除整个既有存储键；只有 custom 写入 JSON。
- 第 154–172 行：version 2 JSON 仅有 `version`、`lowSeconds`、`midSeconds`、`highSeconds`，解码后一律构造 custom；不存在 mode 字段。
- 第 85–106 行：无数据为 automatic；旧整数迁移成三个相同的 custom 分档。
- 所以在同一个键只加 `accessorySeconds`，无法无歧义地区分“自动 + 辅助项 90 秒”和“自定义 120/180/240 + 辅助项 90 秒”。沿用删除键会丢辅助项时长；把默认三档当自动会丢用户的模式选择；复用 version 或时长哨兵会改变既有字段含义。

拟议最小扩展（未实施）：允许在原 JSON 增加两个可选字段 `mode` 与 `accessorySeconds`，保持原存储键和原有字段。旧 version 2 JSON 缺 mode 按原语义 custom，缺 accessorySeconds 为 60；无存储仍为 automatic / 60；旧整数迁移继续保留原三档。新写入显式保存 automatic/custom，切模式保留辅助项时长。此方案超出本轮“只追加一个字段”限制，按用户规定的存储结构停问边界，等待 David/Opus 裁定。

### 测试与验收状态

- 六处 seam 均未开始红绿；新增测试 0、执行 0，既有断言零删改。未运行包全量、format 或 lint；不宣称通过。
- 验收 1–13 均未实装、未验证；老用户升级第一屏和旧格式解码验证尚未执行。
- 未新增 Demo 参数，默认 Demo 未修改；未构建运行模拟器，未生成 DerivedData，未触碰其他工作树的模拟器。
- 与安卓差异：安卓偏好已有 mode，iOS 以键缺失表示 automatic；本次发现的是存储表示差异，非产品行为裁决。其他差异与 spec 外问题尚未展开。
- 原始源码证据：`/tmp/spec089-evidence/rest-settings-baseline.txt`；无测试日志或截图。

## spec 089 iOS（实装交付，2026-10-10）

本节接续前面的「开工核对」：该节所述 JSON 扩展提议未实施，待裁定状态已由 CARD-ios「修订一」及 David 后续两次线程指令取代。工作树 `MeetPR-wt-086`，分支 `feat/089-accessory-quick-log`，基于 spec 086 提交 `36770eaa`。未 commit、未 push；自测结果供 Opus 收货，不宣告验收通过。

### 实现与裁定落实

- 仅动作库 `Exercise.exerciseType == .accessory` 进入辅助项卡，nil / 未知 raw value 返回 false；不读取计划主项标记。保留 iOS 对 catalog 缺失动作整项不展示的既有投影，不定义缺失动作模型、名字，不另开卡（David 第二处裁定）。
- 在现有 hero 内接入六列行内卡，保留 086 淡金动作备注与小灰字组级备注；自重行重量不可编辑、按 0 写入，RIR 仅作占位。常驻视频/失败入口提示；组号仍进原完整录入 sheet。数字输入有逐行 FocusState 与键盘工具条 Done / 完成按钮。
- 逐组写入、覆盖、取消及串行批量全部复用现有 `persist → recordSet` 路径；取消显式 `completed:false`、`failed:false`，保留原始重量次数。空 RPE 不写处方值，请求省略 RPE；批量只选未记录且合法行，空重量跳过、计数提示，失败停止、成功保留、可重试。无新增后端接口、DTO 字段或依赖。
- 存储按修订一采用独立整数键 `meetpr.student.rest_timer.accessory_seconds.<studentID>`；缺失、非法类型、越界或非 15 倍数均回退 60。主项 `fixed_seconds` 键的读写删、version 2 JSON、旧整数迁移及「键不存在 = 自动」实现逐字保留，未加 mode 或其他 JSON 字段。协议增加两方法，两个既有 preview/test 内存实现补齐。
- 设置页新增始终可调的辅助项段，30–300 秒、步进 15 秒；自动/自定义切换不影响辅助项值。24 个辅助项中英键逐字取 `meetpr-rn@137d816`，页底说明改为目录中的复数写法。
- 休息走教练明确值 → 辅助项偏好 → 60。主项原分支不变；辅助项不弹 RPE 说明；逐组覆盖也重新计时；末组与批量不起计时。计时条与 Live Activity 的 UI、+30/−30/Skip 均未改。

### 投影与范围扩展的证据

`StudentPlanProjection` 以前给所有 canonical load mode 注入主项 180/240 秒，导致辅助项偏好永远无法生效。本卡仅在辅助项投影时保留原始 `planSet.restSeconds`；该处 Repository 范围已由 David 明确允许。

1. `accessoryProjectionPreservesCoachRestAndMainLiftVariants` 用 JSON 解码带显式 75 秒的 PlanSet，确认辅助项保留 75，其余未设组为 nil；写入集成测试再确认偏好 90 时教练 75 仍优先。
2. 同一 10 组 fixture 的主项与主项变式投影逐字段全等，休息逐组为 `[75,180,180,180,240,180,240,180,nil,nil]`；原 `studentProjectionUsesCanonicalIntensityFieldsAndIgnoresLegacyProjection` 全部断言原样通过。原主项 `restSeconds(for:)` 一行未改。
3. `accessoryOverwriteRestMatchesLiveActivity` 对 `RestTimerActivityControlling` 注入 spy，逐组、覆盖时校验页面 `restTimer` 与 activity 的 `totalSeconds`、`endsAt` 完全相同；批量后两者为空。生产 `startRestTimer` 只构造一个 nextTimer，原计时条直接消费同一 state。没有修改 Widgets，也未做真机锁屏视觉复验。

另两处小范围协议兼容接线为 `GrowthProfileV3Previews`、`StudentEmptyStateViewTests`；Demo 带视频场景需在 `VideoUploadServices.demo()` 注入 fixture，默认仍为空。VideoUpload 的生产改动只在 `VideoAttachmentViewModel`：增加 `hasLoadedAttachments`，成功读取（含空列表）才设 true；原 `manager.attachments` 把异常折成空列表，无法作取消依据，故在这里调用同一 repository 的 throwing fetchAll，并保持原 recordedAt 排序。加载失败仍保持原界面表现，只让辅助项知道状态未知；上传、压缩、播放、重试管线均未动。既有 VideoUpload 测试文件零改动并全量通过。

### 独立审查与返修

- Standards 第一轮 P2：冷启动附件尚未读完可取消。初步加 VM 状态闸；依 David 最新要求补齐失败状态和提示：未知时点已完成 ✓ 显示既有「暂时无法撤销，请稍后重试」，在 persist 前返回，详情入口保留；已知且有视频用安卓目录提示。测试覆盖成功空列表、读取失败、未知禁止写入并有提示、已知无视频可取消、已知有视频不能取消。
- Standards 第一轮 P2：lb 显示回算导致未改 60 kg 写成 60.01 kg。修为未编辑重量直接取原处方/原记录 kg；仅编辑后的输入才换算。测试覆盖首次 lb 保存原值和取消保留原值，旧覆盖测试保持。
- 自查第三项：安卓 `TodayWorkoutView.tsx` 对辅助项已完成组覆盖也起休息，而 iOS 原完成边沿条件漏掉此情形。仅辅助项放开完成边沿；测试先失败，补齐后重计时并同步 Live Activity，主项原规则不变。
- Spec 第一轮 catalog 缺失 finding 按 David 第二次裁定撤回；平台差异见下。二轴第二轮均 CLEAN；读取失败/提示的追加改动又做了 Standards 定向只读复核，CLEAN。审查者未写文件。

### 六处 seam 与原始红绿

证据目录统一为 `/tmp/spec089-evidence/`；下列均为原始工具/测试日志，不以摘要代替原输出。新增 Swift Testing 16 个，既有测试行及断言零删改。

| seam | 覆盖 | 红 | 绿 |
|---|---|---|---|
| 1 判定 | accessory / mainLift / mainLiftVariation / nil / unknown raw value，只有 accessory 为真 | `seam1-red.log`（缺 API 编译失败） | `seam1-green.log`，最终全量 |
| 2 行模型/历史 | 处方/已有记录/上次同序号；同一次历史不混更早组；BW、RPE/RIR、空重量、选择与校验 | `seam2-red.log`、`seam2-history-red.log` | `seam2-green.log`、`seam2-history-green.log`，最终全量 |
| 3 休息/存储/投影 | 优先级、旧格式、模式切换、主项不变、教练 75、活动同源、末组 | `seam3-storage-red.log`、`seam3-policy-red.log`、`seam3-projection-red.log`（实际断言失败）、`seam3-overwrite-red.log`（实际断言失败） | 对应 `*-green.log`；`seam3-rest-integration-green.log`、`seam3-terminal-green.log`、`seam-review-green.log`、最终全量 |
| 4 写入 | 普通记录/显式取消/空 RPE/覆盖/视频保护/串行失败重试/磅原值/未知提示 | `seam4-red.log`、`seam4-batch-red.log`、`seam4-review-compile-red.log`、`seam4-review-red.log`（实际断言失败）、`seam4-video-snapshot-red.log`、`seam4-unknown-hint-red.log`（实际断言失败） | `seam4-green.log`、`seam4-batch-green.log`、`seam-review-green.log`、`seam4-video-snapshot-green.log`；未知提示的绿为 `studentkit-final.log` 对应 test passed 行 |
| 5 presentation | editable recording 辅助项才替换；main/readonly/planning 不替换；全部记完推进 | `seam5-red.log` | `seam5-green.log`，最终全量 |
| 6 原功能回归 | 记录、结算、补记、聊天引用、休息、视频等原测试 | 不制造功能红测或改旧断言；全量曾出现 3 个既有视频异步 TimeoutError，原始 `studentkit-timeouts.log` 保留（不能当功能测试的红） | `video-timeouts-recheck.log` 3/0；最终 `studentkit-final.log` 953/0、`coremodels-final.log` 158/0 |

补充投影的显式教练值/主项变式、失败组后的最后未记录组等是同 seam 内已实现行为的追加证明，加入即绿，未伪造失败。六处中的前五处有真实 red→green；第六处是原测试回归边界，未人为破坏旧断言来制造 red。全量中三个超时用例是 `persistedGenerationRejectsOlderEventThatArrivesFirstAfterRestart`、`sessionFinishedDuringPersistenceDoesNotRollBackMemoryGeneration`、`staleRecoveryLoopCannotInterfereWithImmediateRetryOfSameRecord`；停 UI 操作后的定向与完整复跑均通过，代码未针对超时改动。视频导出实际通过，没有把 Cannot Encode 当通过。

### 老用户与 Demo 覆盖

- `accessoryRestUsesIndependentKeyAndPreservesLegacyPreferences` 写入真实改前格式 `{"version":2,"lowSeconds":105,"midSeconds":195,"highSeconds":315}`，逐档读回 105/195/315 且原 JSON 字节未变；旧整数 195 按原迁移读回三档 195，两种均确认辅助项 60。另测新键缺失、90 写读、学生隔离、非法值/字符串回退、自动→自定义→自动保留 90。源码比较确认现有主项 preference 方法起至文件尾与 HEAD 逐字相同。
- `--spec089-upgrade`：主项三组已完成，辅助项第一组已完成且有 uploaded 视频 marker，其余两组可继续；这是加载已有日志与附件后的第一屏，不是先现场点完的替代。附件 fixture 不含真实可播放文件，覆盖 marker/禁止取消/覆盖，不冒充真实上传。
- `--spec089-accessory`：基础辅助项 hero，默认 60 kg / 12 次、RPE 8 占位，第二组带 3-1-1 备注。
- `--spec089-rpe`：纯 RPE 无处方重量；上次 55 kg / 10 次仅作占位，可点 Last 填入。
- `--spec089-bodyweight`：重量为空但备注 bodyweight，BW / RIR 2，占位不写实际 RPE。
- `--spec089-coach-rest`：教练明确 75 秒，覆盖已在设置页存入的 90 秒。
- `--spec089-lb`：可与上述任意场景组合，单位偏好 lb。
- 任一 `--spec089-` 参数才启用 fixture；默认不带参数时 Today 仍为 W1D3 Deadlift、1 动作/3 组、周进度 2/4。默认截图 `default-demo-first-screen.jpg`；未改导航或默认 Demo 入口。
- 语言/样式验证附加启动参数：`-AppleLanguages (en)` / `(zh-Hans)`，对应 locale；`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`（恢复常规为 `UICTContentSizeCategoryL`）；用已存在的 `-meetpr.appearance dark` / `light` 覆盖仅本次进程的样式。休息 1:30 是实际进入 Profile 页面按两次 + 设置，并非靠启动参数伪造。

### CARD-ios 验收逐项自测

| 项 | 自测结论与证据 |
|---|---|
| 1 | 辅助项六列表格与 086 两级备注实屏确认：`accessory-en-light.jpg`。主项原 hero、淡金备注、小灰字组备注：`main-hero-unchanged.jpg`。主项变式 classifier / projection 断言通过；未单独把变式推进到可编辑 hero，复用的非辅助项分支未改。 |
| 2 | 处方预填、纯 RPE 空重量/上次占位：`rpe-empty-weight.jpg`；BW 无重量输入：`bodyweight-en-dark-large-rows.jpg`。 |
| 3 | 逐组变绿、下方组表/Today 在结算后推进；普通 repository 日志与 DTO 假仓库断言证明与完整录入同路径，未改 CoachKit。`single-default60.jpg`、`completion-celebration.jpg`。未连接真实教练账号。 |
| 4 | 空 RPE 请求无键、日志 nil 的单测通过；实屏保存空 RPE 后行内为空；BW/RIR 2 占位手填 7.5 后保存：`bodyweight-rpe75-saved.jpg`。 |
| 5 | 取消后行不再绿，重量 55 / 次数 10 保留：`cancel-retains-values.jpg`；fake repo 两个 false，原聚合/Progress 回归通过。带视频取消提示且状态不变：`video-cancel-blocked-zh.jpg`。未知状态/读取失败禁止取消及提示由 seam 4 验证，未额外造 UI 故障场景。 |
| 6 | 已完成带视频行 lb 重量改为 143 后覆盖成功，视频 marker 保留、重起休息：`video-overwrite-lb.jpg`；fake repo 确认仍同一 log ID。 |
| 7 | 组号进入原完整录入：`full-entry.jpg`；点失败可返回，行仍为记录态；相册 consent 与系统 picker 可达：`photos-entry.jpg`、`photos-picker.jpg`。本模拟器相册为 No Videos、无实体摄像头，真实拍摄/选片上传再返回的完整往返未验到；上传生命周期/转码等既有单测通过，升级 fixture 的视频 marker 可见。提示行常驻见各行截图。 |
| 8 | 点击 Last 仅填重量次数；批量只完成合法行、提示缺重 2 组：`batch-skipped-two.jpg`；补齐后无计时、完整完成态：`batch-complete-no-timer.jpg`。中途失败/成功保留/重试不重复用假仓库第 2 次失败断言覆盖，未用真实断网模拟。 |
| 9 | 默认 60：`single-default60.jpg`；Profile 实调 1:30 与后续生效：`settings90-en.jpg`、`custom90-running.jpg`；教练 75 优先于 90：`coach75-priority.jpg`；最后一组清掉计时：`final-set-no-timer.jpg`；批量无计时。主项旧规则与模式保持的原测试全通过，Live Activity 同源用 spy 证明，锁屏 UI 未单独实屏复验。 |
| 10 | 老用户首屏含已记组、视频和剩余可写行：`upgrade-zh-lb-large-top.jpg`、`upgrade-zh-lb-large-rows.jpg`；设置旧 JSON/旧整数/从未设置均有解码测试。首次进入设置默认 1:00，之后实调 1:30；原主项自动设置保持。 |
| 11 | 全部辅助项完成后原长按结算、庆祝、Today 撤销入口走通：`completion-celebration.jpg`、`completion-undone.jpg`，原结算/撤销断言不改。 |
| 12 | Light 中文 lb 超大字号、Dark 英文 BW/RIR 超大字号、英文常规字号均亲眼检查六列完整、132.3/143 与 7.5 不截断。无 SE；17e 均已 Booted 且有并行作业，选空闲的 iPhone 17 / iOS 26.4 `CFAA1293-2795-45DC-A279-7012482F2716`，不停止/重置其他设备。软键盘避让未验到，按 David 最新指令交 Opus；详见下。 |
| 13（iOS 替换） | StudentKit **953 passed / 0 failed / 0 skipped**；CoreModels **158 / 0 / 0**，未改其他包。全仓 swift-format strict 0 违规；SwiftLint strict 1106 文件 0 违规。DemoStudent 最终构建运行成功，工具 0 errors / 0 warnings。 |

### 软键盘、未覆盖与平台差异

- 键盘避让：沿用 TodayWorkoutScreen 原 ScrollView 和 SwiftUI 自动 keyboard safe-area/focus 避让，未添加 ignoresSafeArea(.keyboard)。AccessoryLogRow 的每行 FocusState 绑定三个输入框；焦点存在时 `.toolbar` 的 `.keyboard` ToolbarItemGroup 提供 Done / 完成，点它把 focusedField 清为 nil。未加点空白收起，也未另加程序滚动定位。硬件键盘下实际输入并保存了第三组重量、第一组 lb 重量和 RPE 7.5，Done 可清焦点；硬件键盘工具条以系统浮动区域显示，按钮有时缩成 `D…`。软键盘没有弹出；CUA 原生 Simulator 控制被工具拒绝（`Computer Use was not approved to use Simulator`），XcodeBuildMCP 无切换软键盘入口。依 David 指令不等待人工，该项明确未验到，由 Opus 开软键盘收货。
- 其他未实屏覆盖：实体摄像头、从相册实际选择视频上传再返回（本机相册为空）、真实教练端/真实断网、真机锁屏 Live Activity。分别以入口实屏、原视频全量测试、假仓库与 activity spy 补充，不冒称完整端到端验过。
- 安卓类型无法解析 → 完整录入；iOS catalog 缺失 → 既有逻辑整项不展示，本卡未改（David 裁定）。仍以唯一 accessory 类型判真，未知绝不误进辅助项。
- 按 CARD-ios 保留 iOS 完整录入的 RPE 5–10、0.5 步进与现有 lb 换算精度（编辑输入换算到 kg 保留两位；未动重量保存原值）；不复制安卓 0–10 输入范围/另一精度。
- 休息偏好采用 iOS 独立新键（修订一），安卓仍为自身偏好结构；本地模式/后端形状不改。
- 现有下方组表/完成 hero 在日志 RPE 为空时仍可能显示处方 RPE；本卡只保证行内与写入为空，按「下方表维持现状」未顺手改。已有休息条在 accessibility-large 下数字和 ±30/Skip 会换行（见 `video-overwrite-lb.jpg` / `bodyweight-rpe75-saved.jpg`），属于本卡明确沿用的 iOS UI，未改。
- 默认 Demo、spec 081 补记、训练日结算撤销、e1RM、CoachKit、Widgets、发布台账和 build 号均未改。`CARD-ios.md` 工作区改动为用户提供的修订一，本实现未写该文件。无待 David 再裁定的问题。

### 改动文件清单

以下为本任务 33 个文件（不含用户提供的 CARD-ios 修订）：

- `Modules/StudentKit/Sources/StudentKit/Demo/AccessoryDemoScenario.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/AccessoryRestSettings.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/RestTimerPreferenceRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/RestTimerSettingsView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/StudentRestTimerSettings.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryClassification.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryHistory.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryWorkoutHero.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/RestTimerPolicy.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+DraftBuilding.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/GrowthProfileV3Previews.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoAttachmentViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/VideoUpload/VideoUploadServices.swift`
- `Modules/StudentKit/Sources/StudentKit/Repository/StudentPlanProjection.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/Dashboard/StudentEmptyStateViewTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/MyProfile/StudentRestTimerSettingsTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryClassificationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryPresentationTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessoryRowTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/AccessorySaveTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/RestTimerPolicyTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Repository/StudentPlanIntensityProjectionTests.swift`
- `docs/CODEX-JOURNAL.md`

### 最终证据与环境

- `/tmp/spec089-evidence/studentkit-final.log`：最终 953/0，包含原 VideoUpload、QuickLog、completion、set-ref、rest-timer 全部回归；`coremodels-final.log`：158/0。
- `swift-format-final.log` 为空（exit 0）；`swiftlint-final.log`：1106 文件 0 违规（exit 0）。`guards.log`：24 × 2 文案逐字比对与四项模块边界通过。源码保护检查确认旧主项偏好实现逐字未改、既有测试零删行、禁改文件未动。
- `build-final.log`：MeetPR-DemoStudent / DemoStudent，独立 `/tmp/spec089-derived`，`-skipPackageUpdates`，成功 180.6 秒；`runtime-final.log`：安装启动成功。首次 build_run_sim 超过工具 300 秒等待，`build-first-timeout.log` 自身最终 BUILD SUCCEEDED；后续完整构建运行已有明确成功结果。
- 上表截图全在 `/tmp/spec089-evidence/`，仅文件，不把图片贴进交付正文。`changed-files.txt` 为 33 个本任务文件清单（31 Swift、xcstrings、JOURNAL；不含用户 CARD 改动）。所有日志与截图都是 Demo/假数据，无账号、密钥、内网细节。
- 使用一份 DerivedData；交付前删除本任务 `/tmp/spec089-derived` 的构建中间产物与模块缓存，保留安装包产品便于复验，不清理其他工作树或模拟器。

### 返修一（共用草稿 RPE 回归，2026-10-10）

Opus 收货指出初版把所有辅助项共用草稿的实际 RPE 都设为 existingLog?.rpe，连带使 spec 081 补记的未记录辅助项初值与提交值变空。上一交付节「补记未改」仅能证明源文件未改，不能证明行为未改；该回归在本轮修复。

- 生产改动只有 `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+DraftBuilding.swift` 一处条件：仅在 `exercise.exercise.isAccessory && existingLog != nil` 时保留原记录 RPE（含 nil）；无已有记录时所有类型恢复 `set.rpe ?? 8`。主项与变式已有记录继续使用原 `existingLog?.rpe ?? set.rpe ?? 8`。
- `AccessoryRow` 的既有独立输入初始化保持不变：无 loggedSetID 时输入恒为空，教练 RPE / RIR 仅作占位；saveAccessoryRow 原 `updateRPE(rowIndex:rpe: row.rpe)` 继续把空输入写为 nil。QuickLogPlan / QuickLogSheet 源文件零改动，现有补记断言零删改。
- 本轮另改三个测试文件：`Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutQuickLogTests.swift` 新增未记录辅助项补记测试；同目录 `AccessoryRowTests.swift` 追加共用草稿默认值与已记录 nil 断言（seam 2）；`AccessorySaveTests.swift` 新增保存空 RPE→重新 load→只改重量覆盖的整条验证（seam 4）。加上本 JOURNAL，本轮共 5 文件，新增 Swift Testing 2 个。

先红后绿与最终结果：

- `r1-quicklog-red.log`：新补记测试 1 个失败、2 个断言失败，页面行初值与实际 repository 提交值均为 `[nil,nil]`，预期 `[7,8]`。工具摘要把两个 issues 算作 2 failed，原始 Swift Testing 明确为 1 test / 2 issues。
- `r1-quicklog-green.log`：修复后该测试 1/0，处方 7 和无处方默认 8 的初值、写入均正确。
- `r1-seam2-seam4-green.log`：2/0，未记录行在草稿为 8 时卡输入仍为空；已有记录 nil 经重载后仍为空；只改 60→65 kg 覆盖仍同一 log ID、RPE nil。这里是已满足行为的追加回归验证，没有伪造红测。
- 最终 StudentKit **955 passed / 0 failed / 0 skipped**（`r1-studentkit-final.log`）；CoreModels **158 / 0 / 0**（`r1-coremodels-final.log`）。既有视频测试及补记测试全量零改动通过。无其他包改动。
- 全仓 `swift-format lint --strict` exit 0、零违规（`r1-swift-format-final.log`）；`swiftlint lint --strict` exit 0、1106 文件零违规（`r1-swiftlint-final.log`）。`r1-guards.log` 记录补记源码未改、既有测试零删行。Standards / Spec 定向独立只读复核分别 CLEAN，见 `r1-review.txt`。

两处模拟器实屏均完成（iPhone 17 / iOS 26.4，同前轮专用模拟器，不碰其他工作树）：

1. 默认 Demo 无 spec089 参数：从 Training 的 W1D3 补记并完成，自动推进 W1D4，再打开补记页、滚动至 Seated Row。三组辅助项 RPE 都显示处方值 **8**；同屏主项处方 7、变式无处方默认 8 也保持。截图 `/tmp/spec089-evidence/r1-default-demo-quicklog-rpe.jpg`。未修改 Demo 数据或默认首屏。
2. 重新启动 `--spec089-accessory` 后进入 Training，三组未记录 RPE 输入为空，浅灰 **8** 为教练处方占位，与黑色重量/次数区分。截图 `/tmp/spec089-evidence/r1-accessory-empty-rpe-placeholder.jpg`。系统 accessibility 把 placeholder 也报为 value 8，是否空输入由 seam 2 / seam 4 的 input.rpe.isEmpty 与实际 nil 写入断言共同验证。

最终构建与保留产物：

- MeetPR-DemoStudent / DemoStudent 编译成功，`r1-build-final.log` 末尾 **BUILD SUCCEEDED**。build_run_sim 工具超过 300 秒等待上限；随后直接安装同一产物并 launch_app_sim，二者明确 SUCCEEDED（`r1-install-launch.log`、`r1-runtime-final.log`），未把工具超时冒称为组合调用成功。
- 最终 app 已保留：`/tmp/spec089-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`。仅删除同一 DerivedData 的 Intermediates.noindex、ModuleCache.noindex、Index.noindex，Build/Products 未删。模拟器停留在辅助项 hero，便于 Opus 继续软键盘验收。
- 本轮要求的两处实屏无未验项；软键盘避让仍按上一轮裁定交 Opus，其他上轮未覆盖项不因本次测试而冒称补齐。无需要 David 再裁定的问题。未 commit、未 push。

## spec 090 iOS（2026-10-10，工作区交付，待 Opus 验收）

### 范围与实现

- 当前树 `/Users/david/Projects/apps/MeetPR-wt-086`，分支 `feat/090-training-flow`，基线 `576729ac`（含 086、089 及返修）。开工在本目录创建并删除临时文件，写权限确认成功。未 commit、未 push；未修改任何 SPEC、NEXT-RELEASE、RELEASES、build 号、工程结构或依赖。
- 仅可编辑记录态消费新分区：真实结果包含 completed/failed，assumed 仍待记录；按计划序排列完成行、首个未完成 hero、其余动作。取消后重新分区。主项/变式 hero 显示分段条，失败弱灰，不向读屏暴露装饰分段。完成行复用原组编辑入口；辅助项展开复用 089 卡，未改其内部。
- 全记完时按钮与原休息条放在同一底部安全区容器，按钮在上；History 推入时隐藏按钮。未全记完仍是原滚动区按钮/剩余提示。HoldToCompleteButton 源码逐字未改，结算回调仅提取函数共用。重量/次数仅压缩间距、数字字号和数值框高度，各段顺序不变。
- 记录态使用 eager VStack，以解决完成主项末组时全屏录入关闭与 LazyVStack 重新分区造成的 SwiftUI 卡顿；其余路由保留原 LazyVStack。新完成行是唯一 scroll targets，等待 350ms 让录入关闭事务稳定后直接定位；完成行和 hero 只做局部 0.2s 淡入，已消费 trigger 不重播。初次加载/切日不触发，Reduce Motion 直接呈现；手动滚动/键盘条件中止定位并清理请求。

### 改动文件（19 个，含本节）

以下路径均相对仓根：

- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/SetEntrySheet.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingExerciseProgress.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingSetProgress.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCompletionAvailability.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingFlowPresentation.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingSetProgressBar.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/CompletedTrainingExercise.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingFlowScroll.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/TrainingFlowDemoScenario.swift`（新增）
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TrainingFlowTests.swift`（新增）
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutSetRefEntryLayoutTests.swift`
- `Modules/DesignSystem/Sources/DesignSystem/DesignSystemStrings.swift`（仅公开已有 expanded/collapsed 文案）
- `docs/CODEX-JOURNAL.md`

### S1–S4 先红后绿与最终测试

全部原始输出保存在 `/tmp/spec090-evidence/`。新增 5 个 Swift Testing 测试，只落 S1–S4；未加录入页快照测试。

| seam | 红 | 绿 |
|---|---|---|
| S1 分区 | `s1-red.log`：先写测试，TrainingExerciseProgress 尚不存在，编译失败 | `s1-green.log`：1/0；后续补齐的第二个 S1 测试覆盖部分、跳做、失败、代填、全完、撤销、输入逆序仍按计划排序 |
| S2 分段 | `s2-red.log`：缺 TrainingSetProgress，编译失败 | `s2-green.log`：累计 3/0，含 0/3、1/3、失败、全完及代填 |
| S3 按钮 | `s3-red.log`：缺 completionAvailability，编译失败 | `s3-green.log`：累计 4/0，全完吸底/无 pill、差一组不吸底、只读无按钮 |
| S4 页面 presentation | `s4-red.log`：缺 trainingFlow，编译失败 | `s4-green.log`：累计 5/0，完成行/hero/标记/撤销/模式隔离 |

- 最终 StudentKit **960 passed / 0 failed / 0 skipped**，`studentkit-final.log`；DesignSystem **73 / 0 / 0**，`designsystem-final.log`。使用 XcodeBuildMCP `swift_package_test`，默认包内缓存，没有改用 xcodebuild 包 scheme；视频导出用例全部真实通过。普通沙箱 swift test 的缓存权限失败未冒充测试红。
- 最终 `swift-format lint --strict --recursive Modules` 零违规（`swift-format-final.log` 为空）；全仓 `swiftlint lint --strict` **1115 文件、0 违规**（`swiftlint-final.log`）；`git diff --check` 通过。未改其他包。
- 唯一改动的既有断言：`TodayWorkoutSetRefEntryLayoutTests.completedSectionOwnsAskCoachEntry`，已有全记录 fixture `[0,1]` 的 `askCoachEntryCount` **原值 1 → 新值 0**，测试名改为 `allRecordedHidesHeroAskCoachEntry`。依据 SPEC §3「所有动作都做完时：hero 卡消失」；原唯一 Ask coach 位于该 hero，不能继续要求存在。原 fixture、进行中断言及其余既有断言保持不变。修改前全量 **959/960 通过、此项失败**，原始输出 `studentkit-before-assertion-update.log`。
- Standards / Spec 独立只读审查均收敛 CLEAN。定向发现并修复：展开辅助项漏备注、完成行间距、History 残留 dock、中止定位后同 UUID 无法重试、全屏返回可能重播反馈。静态审查不替代以下实屏自测或 Opus 验收。

### 验收清单逐项自测

目标设备：同一台 iPhone 17 Pro / iOS 26.5，竖屏、默认字号。下表所有截图路径均加前缀 `/tmp/spec090-evidence/`，不内嵌图片。

| 项 | 自测结论与证据 |
|---|---|
| 1 | 已看：开始前仍为原 summary，点击开始后无完成行、主项三段第一段高亮。`01-empty.jpg`、`dark-01.jpg`、`zh-01.jpg`、`lb-01.jpg`。 |
| 2 | 已实际保存首组：首段实心、次段高亮。三变体 `*-02.jpg`；另实际标第二组失败，`02-failed-segment.jpg` 显示弱灰而非红，第三段高亮。 |
| 3 | 已实际保存主项末组：完成行贴近可视区顶部、完整下一辅助 hero 同屏。`03-main-complete-final.jpg`、三变体 `*-03.jpg`。已排除中间版本卡顿，最终中文/磅完整链路复跑。 |
| 4 | 已展开并编辑完成主项第一组 175→177.5，保存后仍在完成区，收起正常。`04-edited-completed-final.jpg`；视频入口可达，但未完成视频选择/回放全链路。 |
| 5 | 已实际打辅助末组 ✓，也实际运行两个辅助项各自“全部按计划完成”；都上收且无分段条。`05-accessory-individual-final.jpg`、三变体 `*-03.jpg` / `*-08.jpg`。 |
| 6 | 已对第二动作取消第一组：完成区保留第 1、3 动作，第 2 动作恢复 hero。`06-09-cancel-final.jpg`。 |
| 7 | 用 `--spec090-skipped` 复现第三动作先全记完：它上收，hero 仍第一个。`07-skipped.jpg`；操作前后的分区含跳做及多个动作同批变完另由 S1/S4 覆盖，未逐次在 UI 手动填第三动作。 |
| 8 | 已看单一吸底按钮、无 hero、三行无遮挡；有休息条时按钮在其上方，见 `dark-08.jpg` / `zh-08.jpg` / `lb-08.jpg`。最终包实际长按结算出现庆祝页，`08-celebration-final.jpg`。 |
| 9 | 全记完后取消一组，dock 消失、hero 恢复，按钮回滚动区。`06-09-cancel-final.jpg`、`10-inline-no-rest.jpg`。 |
| 10 | 剩 1 动作 1 组时，原剩余提示及原长按按钮均在滚动区。`10-inline-no-rest.jpg`。与休息条同时存在时的内联按钮遮挡见下方待核实观察。 |
| 11 | 五组历史场景冷启动，第一屏即完成主项+辅助 2/3，无初始化自动定位；`11-upgrade-final.jpg`。没有新增存储/字段，覆盖方式是已有记录注入，不是从真实旧版安装包执行数据库升级。首次触发门控有源码核对，未录制逐帧动效测量。 |
| 12 | 默认 Today/summary、只读预览、已结算详情、History 均打开查看；对应 `12-default-today.jpg`、`12-default-summary.jpg`、`12-preview-final.jpg`、`12-completed-detail-final.jpg`、`12-history-final.jpg`。History 中确认无 dock；summary、Hold 组件源码逐字未改。旧版 .app 不在本机，未完成旧包并排/逐像素比对，因此不把“逐屏一致”标为完整验收通过。 |
| 13 | 目标机型不滚动可见完整 Record / Photos，`13-entry-final.jpg` 与三变体 `*-13.jpg`。实际点击加号 175→177.5，配片相应多 1.25；数字面板输入 180 正常；Photos 能打开系统视频选择器（`13-photos-picker.jpg`）。模拟器 Record 不可用；工具不能操作系统 picker 内目标，未选视频，未验已选视频显示；RPE 拖动、减号及长按连加未逐项实操。未使用第二台 SE。 |
| 14 | 深色、中文、磅偏好各完整跑过 1→2→3→8，且查看 13，文件分别为 `dark-*`、`zh-*`、`lb-*`。磅偏好下辅助卡 LB 换算正常；主项 hero/完整录入仍沿用 iOS 原有 KG，未扩改。 |

**结算后回训练页是否正常：正常。** 最终包长按结算→庆祝页 Done→重新点击 Training，直接显示 W1D4 汇总卡，无页头以下空白、无需拖动；`08-return-training-final.jpg`。

尚未现场覆盖：系统 Reduce Motion 开关、VoiceOver 实机朗读、软键盘开启/手动滚动与上收竞争、iOS 17 fallback。代码含相应门控，分段 accessibilityHidden，但不能将静态检查冒称实测。

### Demo、安卓参照与范围外观察

- 新增参数均显式开启，默认 Demo 首屏保持不变：`--spec090-empty`（0/8）、`--spec090-main-one`（1/8）、`--spec090-main-two`（2/8）、`--spec090-upgrade`（5/8）、`--spec090-all`（8/8）、`--spec090-skipped`（只记第 3 动作）、`--spec090-lb`（可与前述参数组合）。同一当天构造主项 3 组、辅助 3 组、辅助 2 组。前两天已有历史保留。086/089 场景不变；本次只复用其 seed/目录动作，不新增生产字段。
- 语言用启动参数 `-AppleLanguages (en)` / `(zh-Hans)`、`-AppleLocale en_GB` / `zh_CN`；主题用已有偏好参数域 `-meetpr.appearance dark` / `light`，无新增存储键。
- Android 仅通过 `git ls-tree`、`git show 137d816:...` 读取，没有 checkout/写入。四个新文案键的中英文（共 8 值）逐字取 RnExtras.json，复核见 `guards.log`。
- 保持 iOS 现状的差异：主项及完整录入页 KG 口径；未全记完按钮原位置/文案；完成主项展开的备注仍在原组表下方；配片说明与 collar 开关原本已同行；保留原数字面板、RPE、媒体入口和段间距，只缩重量/次数。与安卓既有形态不同处没有扩改。
- 待核实观察：休息条存在时，滚动区内联完成按钮可能被休息条覆盖（`10-inline-final.jpg`）；这一路保留原按钮、padding 与休息条实现，但旧包不可用，不能确认它是既有问题还是本轮记录态布局的回归。本卡要求未全完维持现状、休息计时不动，未扩改，需 Opus 对照旧包定性。新吸底状态的重叠已修复并实测。默认 Today 首屏与主项其他既有样式均未改。
- UI 调试原始过程 `flow-ui-repro.txt` 保留失败假设与逐轮结果；旧失败截图 `05-accessory-individual.jpg`、`flow-probe1.jpg`、`08-dock-with-rest-before-fix.jpg` 不是最终通过证据。最终修正为记录态 eager layout、唯一完成行 target、延后非动画定位、局部反馈，以及同一安全区排布 dock/rest。
- 无需要重新决定的产品方案；上述未验项、内联按钮遮挡的归属交 Opus 按既有验收清单定向复核，未自行宣布功能验收通过。

### 最终产物与资源清理

- `MeetPR-DemoStudent` / `DemoStudent` 构建安装运行成功，`build-final.log`、`runtime-final.log`；最终构建耗时 62.1 秒，无新增构建警告。`ui-captures.json` 保存三变体及场景的原始界面结构，`changed-files.txt` 保存文件清单。
- **最终 app 保留在 `/tmp/spec090-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`**。只用这一份 DerivedData；交付前删除其中除 app 以外的中间产物，以及本树 StudentKit/DesignSystem 默认 `.build` 缓存，未动其他项目产物。
- 只使用 iPhone 17 Pro（它在开工时已是 Booted），未操作另一台已运行设备。Demo 已停止。按要求执行所选设备的 `xcrun simctl shutdown`，但 shell 沙箱无法连接 CoreSimulatorService，返回 `Connection refused` / `Operation not permitted`；原始报错 `/tmp/spec090-evidence/simulator-shutdown.log`。现有 XcodeBuildMCP 未暴露 shutdown，未绕过权限；**不能声称模拟器已关闭，仍需在宿主侧关闭该设备**。
- 所有数据与截图均为 Demo，不含账号、密钥或内网信息。工作区保持未提交、未推送，等待 Opus 收货。

### 返修一（2026-10-10）

**既有问题，顺带修复（定性为代码推断，非旧包底部实测）。** 部分记录且休息条在场时，滚动区的长按完成按钮缺少足够底部留白。本次按收货指示补齐；旧包滚动卡死使底部遮挡的版本归属无法直接实测，不能排除 090 的布局变化对表现有影响。

- 旧包证据：安装 Opus 提供的 `576729ac` 包 `/tmp/spec090-baseline-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`。走默认 Demo → Training → Start first set → 主项首组 Complete set，计时开始后上滑，界面在到达底部前冻结；重启后尝试收起动作表、小幅上滑仍冻结。首次休息说明此前已关闭，本次未拦截。`/tmp/spec090-evidence/r1-baseline-089-main-bottom.jpg` 保存卡死位置，**不是旧包底部遮挡截图**；步骤和失败假设见 `r1-diagnosis.txt`。
- 代码对照依据：旧 `TodayWorkoutView.swift:233` 与 090 都将休息条的 `.safeAreaInset(edge: .bottom)` 放在 NavigationStack 外；旧 `TodayWorkoutScreen.swift:109` 与返修前 090 都只留固定 `point28`。090 的 TrainingContentStack 在记录态改用 eager VStack，spacing 仍为 point13；新增 scrollPosition、滚动/键盘观察未增加休息条等高留白。由共享的底部布局推断为既有问题；因旧版 LazyVStack 无法滚到底，这不是受控实测排除了 eager/scroll 修饰符影响。
- 补记 Opus 对照：089 的 `--spec089-accessory` 在点第一组 ✓ 后上滑，主线程在 `LazySubviewPlacements.placeSubviews` 空转、CPU 100%，原始采样 `/tmp/spec090-opus/baseline-089-hang-sample.txt`；同样步骤在 090 包上不卡。本次旧包主项路径也冻结，而 090 辅助项路径正常，支持保留记录态 eager VStack。

本轮仅追加修改以下三个文件（相对于已交付的 090 工作区）：

- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`：在现有 RestTimerOverlay 外测量其实际高度；计时不存在时向屏幕传 0。
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`：仅当滚动区完成按钮存在、且不是全完吸底状态时，在原 point28 上加测得的休息条高度。
- `docs/CODEX-JOURNAL.md`：追加本小节。定向差异保存为 `/tmp/spec090-evidence/r1-change.diff`。

休息条样式、时长、按钮、出现/消失逻辑及 RestTimerOverlay 源码未改；全完 dock 排布、判定和交互未改。没有新字段、存储键或依赖，未新增 Demo 参数；本轮没有新增测试或修改任何既有断言。此缺陷是实际 SwiftUI 遮挡，纯 padding 数值断言无法验证可见性，因此使用同场景实屏红→绿，并全量回归现有 Swift Testing。

| 自测 | 最终结果与证据（路径前缀 `/tmp/spec090-evidence/`） |
|---|---|
| 修改前红 | 090 旧产物 `--spec089-accessory` → 第一组 ✓ → 滚到底，计时中，提示可见而按钮被覆盖；`r1-before-partial-rest.jpg`。 |
| 部分记录 + 休息条 | 相同路径，按钮完整露在休息条上方；`r1-partial-rest-bottom.jpg`。 |
| 部分记录 + 无休息条 | 同页 Skip 后滚到底，额外留白消失，保留原底部间距；`r1-partial-no-rest-bottom.jpg`。 |
| 全部做完 + 休息条 | `--spec090-main-two` → 记录主项末组 → 两个辅助项各 Complete all as planned，计时仍走；只有一颗吸底按钮、无 hero、按钮与休息条无重叠；`r1-all-docked-rest.jpg`。 |
| StudentKit 全量 | **960 passed / 0 failed / 0 skipped**；XcodeBuildMCP `swift_package_test`，包内默认缓存，视频导出真实通过；`r1-studentkit-final.log`。 |
| 格式与静态检查 | `swift-format lint --strict --recursive Modules`：0 违规，`r1-swift-format-final.log` 为空；`swiftlint lint --strict`：1115 文件、0 违规，`r1-swiftlint-final.log`；`git diff --check` 通过。 |
| 构建与定向审查 | MeetPR-DemoStudent / DemoStudent 构建安装运行成功，122.3 秒，无构建 warning/error；`r1-build-final.log`、`r1-runtime-final.log`。Standards 与 Spec 两个独立只读 reviewer 均 CLEAN、0 findings。 |

实屏均在同一台 iPhone 17 Pro / iOS 26.5、竖屏默认字号、英文浅色完成。旧包和基线源码树只读使用，`/tmp/spec090-baseline-derived` 与 `/tmp/wt-089-baseline` 均保留，交由 Opus 清理。

最终 `.app`：**`/tmp/spec090-derived/Build/Products/DemoStudent-iphonesimulator/MeetPR.app`**。保留此包，清理本轮同一 DerivedData 中的其他产物及本树 StudentKit 默认 `.build`。仅复用开工时已 Booted 的 iPhone 17 Pro（`D412AE31-0ED9-4A23-B0FD-FFFA4A5A5609`），未启动第二台、未操作另一台设备。App 已停止；再次执行该设备的 `xcrun simctl shutdown` 被沙箱拒绝连接 CoreSimulatorService（`Connection refused`），原始错误 `r1-simulator-shutdown.log`。现有 MCP 无 shutdown，未绕过权限；**不能确认设备已关，仍需宿主侧关闭**。

无新增产品决策题；版本归属的证据限制如上，交 Opus 收货确认。本轮未 commit、未 push，未改发布文档、SPEC 或 build 号，未触碰 Opus 的 `specs/090-training-flow/evidence/`。


## 2026-10-14 · Spec 092 · iOS 卡 B · 教练自加记录与训练日归属（T2 / P1，未提交）

**交付状态：代码与开发自测完成，工作区待 Opus 收货；不代替 SPEC 验收。** 工作树 `MeetPR-wt-092b`，分支 `feat/092-ios-coach`，基线 `7acf289c8578663e3b8155544514f080f9795743`。启动第一步已在本目录创建并删除临时文件确认可写。SPEC/CARD-B 从卡 A 工作树只读读取，Android 仅 `git show 02213e4:<path>` 参照。没有 commit、push、PR；未修改 StudentKit、CoreModels、RepositoryContracts、CONTEXT、NEXT-RELEASE、依赖、工程结构或 build 号。既有测试文件与断言均未改动；新增 15 个 Swift Testing 测试。

### 实装与工程选择

- 计划动作内按处方范围和额外组分组、排序，额外组前只有一次灰色「学员自加」；行上无标签，x/y 只计处方组。自加动作按训练日及动作 ID 独立成卡，名称优先读取服务器目录、离线回退内置目录；中英文副标题与 Android 文案一致（英语补单数 plural 分支以遵守既有本地化测试）。没有新增编辑、删除、通知入口。
- `CoachDayActivity` 是归属与完成的唯一纯函数：已结算或已完成记录即算练了；同计划周按归属日，跨周、未知归属按当地日期。详情、概览、roster 周数据、没练提醒共用；最近活动读取全部日志。核对了执行周列表、概览状态和名单完成率，没有继续按游标之前全完成推断；视频、聊天、反馈流程保持既有 planned-log 映射。
- **工程决定：** 保留原 `SetLogDTO` 与 plan-only API 兼容形态，仅给 DTO 加 6 行可选 `planDayID`；新增教练只读 DTO/API（允许空 `planExerciseID`，`scope=all`）及可选仓储读取 seam，老 mock 回退既有 reader，避免改动学员端及跨模块合同。遗留重复动作 ID 无法唯一归属时回退日期。
- 大字号实屏发现原共享行会截断重量，因此在本卡教练详情以同一 `CoachSetReadOnlyRow` 对全部组使用 accessibility 纵排指标；普通字号复用原 `SetReadOnlyCell`。颜色、字体、间距均用已有 token，没有改共享 DesignSystem。
- 专用 Demo 参数 `-spec092-coach` 打开实际 `StudentRosterView`；名单 fixture 经实际 `makeRow` 计算，进入详情后走仓储读取。State 同时保留 repository/context/rows/roster，防 UUID 重建；注入同一 `coachNow`。可选 `-spec092-coach-day` 直达 D4，`-spec092-accessibility-large` 使用 `.accessibility2`，`-spec092-dark` 仅为该场景启用深色。默认 Demo/生产主题行为未改。

### 先红后绿与验收项对应

红阶段摘录在 `specs/092-flexible-day-self-added/evidence/red-phases.log`：先补测试再实现；先后复现缺少教练 API、可选 DTO 字段、归属函数与详情 presentation；consumer 红阶段实测 D4 日志落进 D2、D4 无日志、已结算空记录被判未练、误报没练；渲染红阶段缺少分组说明/自加卡；服务器新动作名渲染测试先失败后补目录读取；大字号行先缺少可读组件后实现。没有通过改旧断言消红。

| 验收 / seam | 测试名与结论 |
|---|---|
| SPEC 12：额外组、自加卡、分母与删除后刷新 | `extraSetsStayOutsidePrescribedFractionAndAddedExercisesGroupByOwner`、`rendersOneExtraGroupCaptionAndSeparateAddedCard`、`unchangedPlannedOnlyDetailHasNoAddedCaption`、`refreshShowsServerCatalogNameAndRemovesDeletedAddedSets` 全绿。最后一项在真实详情 VM/presentation seam 替换仓储响应，确认自加卡和额外组消失、处方计数保留；不是线上学员删除 E2E。 |
| SPEC 13：同周先 D4、D2 未练 | `sameWeekJumpDoesNotCompleteEarlierDay`、`detailOverviewRosterAndReminderShareCompletion` 全绿；指定模拟器实际从名单进入概览及 D4/D2，状态正确。 |
| 完成与兼容边界 | `unfinishedTrainingSettlementAndLegacyFallback`（练了未结算、结算无日志、未完成日志、无归属旧数据）、`crossWeekOwnershipFallsBackToCalendarDate`、`laggingStudentTrainsAcrossWeeksWithoutMissedReminder`、`adhocOwnershipUsesTheSameWeekRule`、`latestActivityIncludesLogsNotPlacedInDisplayedWeek` 全绿。 |
| Networking | `coachReadRequestsAllLogs` 验 `scope=all` 与日期参数；`plannedLogDecodesOptionalDayOwnership` 验字段缺失/存在；`coachReadDecodesUnplannedAndLegacyLogs` 验自加、旧记录解码，全部绿。 |
| 大字号只读指标 | `accessibleRowRetainsFullSetMetricsWithoutExtraLabel` 全绿；中文 accessibility-large 深色实屏滚动到额外组和自加动作，重量、次数、RPE 无截断。 |

### 最终工程检查

全部命令在本工作树运行。SwiftPM 默认缓存目录不可写且嵌套 sandbox 不可用，改用 `/tmp` 模块缓存、`--disable-sandbox`（SwiftPM 子沙箱）及已有依赖缓存；不是请求系统提权。网络受限，Xcode 使用本树 DerivedData 中已缓存依赖，禁自动解析/更新。没有读取任何凭证或 `.env`。

| 自检命令 / 工具 | 最后结果行（原文） |
|---|---|
| `CLANG_MODULE_CACHE_PATH=/tmp/092b-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/092b-swift swift test --disable-sandbox --cache-path /tmp/092b-spm-cache --skip-update --package-path Modules/CoachKit` | `✔ Test run with 455 tests in 11 suites passed after 1.742 seconds.` |
| `CLANG_MODULE_CACHE_PATH=/tmp/092b-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/092b-swift swift test --disable-sandbox --package-path Modules/Networking` | `✔ Test run with 134 tests in 3 suites passed after 0.049 seconds.` |
| `xcrun swift-format lint --strict --recursive Modules/CoachKit/Sources Modules/CoachKit/Tests Modules/Networking/Sources Modules/Networking/Tests MeetPR/Sources/MeetPRApp.swift` | 原命令无输出，exit 0；包装记录 `swift-format exit=0`。 |
| `swiftlint lint --strict --no-cache` | `Done linting! Found 0 violations, 0 serious in 1166 files.` |
| `.github/workflows/ci.yml` 的原 Module boundary checks 脚本 | 原脚本无输出，exit 0；包装记录 `Module boundary checks: PASS (exit 0)`。 |
| `git diff --check` | 无输出，exit 0。 |
| XcodeBuildMCP `build_run_sim`，scheme `MeetPR-Demo`，`-disableAutomaticPackageResolution -skipPackageUpdates` | `✅ Build & Run complete`；最终 build 日志最后非空行 `** BUILD SUCCEEDED **`，32.3 秒，0 warning/error。 |
| XcodeBuildMCP `stop_app_sim` | `✅ App stopped successfully`。 |
| `xcrun simctl shutdown 8F164D5D-A450-44FD-BDBF-BB351572CF6E` | exit 1，`Unable to locate device set: Error Domain=NSPOSIXErrorDomain Code=61 "Connection refused"`（完整原行及错误保存在 `simulator-shutdown.log`）。不能确认设备关闭。 |

日志均在本卡 `evidence/`：`coachkit-tests.log`、`networking-tests.log`、`swift-format.log`（空文件即零诊断）、`swiftlint.log`、`demo-build.log`、`simulator-shutdown.log`、`red-phases.log`、`verification.txt`。只改两个 SPM 包，因此全量测试范围是 CoachKit 与 Networking。Standards / Spec 独立只读审查最终均 CLEAN；审查指出的服务器动作名和 Demo 生命周期已返修，最终 Demo 入口及 clock 再经 Standards 定向复审。

### 指定模拟器截图

只使用 **iPhone 17 Pro `8F164D5D-A450-44FD-BDBF-BB351572CF6E` / iOS 26.4**，未操作其他设备。下列 10 张均亲眼查看，路径前缀 `specs/092-flexible-day-self-added/evidence/`；MCP 输出为 368×800 JPEG，非原生分辨率 PNG。

- `coach-roster-en-light.jpg`：D4 学员 2/4、跨周学员 2/2；仅既有 Awaiting Reply，没有没练提示（不把待反馈视作没练）。
- `coach-overview-en-light.jpg`：D1 结算无记录仍已完成，D2/D3 未开始，D4 已完成。
- `coach-detail-en-light.jpg`：通过实际名单→概览→D4 打开，4/4 + 第 5 额外组 + DB Curl 两组。
- `coach-d2-en-light.jpg`：实际点击 D2，0/4、Not Started、无串入 D4 记录。
- `coach-lagging-overview-en-light.jpg`：W4D1/W4D2 按当地日期完成，2/2。
- `coach-detail-zh-light.jpg`：中文小灰字、标题/副标题与只读行。
- `coach-detail-en-dark.jpg`：普通字号深色详情。
- `coach-detail-zh-accessibility-large-dark-top.jpg`：中文大字号深色，页头/处方组完整指标。
- `coach-detail-zh-accessibility-large-dark-extra.jpg`：同场景向下滚动，额外组前单一说明。
- `coach-detail-zh-accessibility-large-dark-added.jpg`：同场景自加卡、副标题自然换行，12.5 kg/12/RPE 完整显示。

### 现场问题、未验项与交接边界

- 曾在专用 Demo 用原 `CoachDashboardView` 挂载这批 fixture：冷启动为空态，日志确认任务已返回 2 行后画面停住/空白；预置数据也未解决，工具有一次长时间启动/停止等待及整屏红色。Home 后恢复，换用实际 StudentRosterView 后名单→详情正常。正式 Dashboard 文件未改；这只能隔离到该呈现路径，**没有证据证明是本卡回归或既有缺陷，也没有完成 Dashboard 七列周表的实屏验收**。对应周表纯函数及共享规则测试已绿；名单固定 rows 截图不证明名单网络加载/刷新成功。临时 `[DEBUG-092b]` 日志已全部删除。
- 详情空周的 Demo 问题有确定原因：没有注入 `coachNow`，默认值为 distantPast；已补同一 fixture clock，实屏复验 2/4 与 2/2 正常。大字号重量截断和专用场景深色被外层恒亮覆盖均已定向修复并实屏复验。
- 未验：真实后端学员删除→教练刷新 E2E、历史 1.0(23) 包兼容、iOS 17 真机/模拟器、VoiceOver 朗读。SPEC 15 不属于本卡 12/13 的验收范围；没有把 fixture 测试冒称服务器 E2E。
- 已停止 Demo；交付前再次执行指定设备 shutdown 仍被 shell 沙箱拒绝连接 CoreSimulatorService。Computer Use 访问 Simulator 也未获准，MCP 没有 shutdown 能力，未绕过权限。**设备关闭未验证，仍需宿主侧关闭该 UDID。**
- 没有产品取舍需要停等裁决；上述 Dashboard 现场观察与未验边界交 Opus 收货时复核。最终 `.app` 在本树 `DerivedData/Build/Products/Demo-iphonesimulator/MeetPR.app`。逐文件清单见本卡 evidence/changed-files.txt。

## 2026-10-14 · iOS 卡 B · 续接复验与 PR 交付

David 本轮直接授权保留上一轮工作区、完成全量测试和模拟器验证后 commit/push 开 PR、不合并。现场核实本树 `feat/092-ios-coach@7acf289c` 与 `origin/release/1.0` 同基底；`main@fbfc25c6` 与本树相差 539 个继承提交、1,287 个文件。David 随后明确将 PR base 改为 `release/1.0`，只交卡 B。spec 依据通过 `git show origin/feat/092-ios-student@2b647a13:specs/092-flexible-day-self-added/{SPEC.md,CARD-B-coach-ios.md}` 读取，参照 Android PR #92 的教练端 `02213e4`；未改 spec、发布台账、build 号或 StudentKit。

保留上一轮全部业务代码与先红后绿证据，本轮没有重写实现、修改既有断言或新增产品行为。重新读全部 diff 与新增文件，并经两名独立只读 reviewer：Standards CLEAN（0 硬违规/实质坏味道），Spec CLEAN（0 缺做/多做/做错），一轮，无返修。记录见 `docs/evidence/092-ios-coach/review.txt`。缺 Matt tracker 配置已告知；使用 review-loop 自身双轴审查，没有声称运行完整 tracker 流程。

### 本轮验证

- 全仓九个 SPM 包全量：Analytics 30、AppShell 107、ChatUI 84、CoachKit 455、CoreModels 158、DesignSystem 73、Networking 134、RepositoryContracts 6、StudentKit 984，共 **2,031** 条通过。
- DesignSystem 首次解析 ViewInspector 遇 GitHub TLS 失败；复用本树 CoachKit 已有同版本 Git 缓存后 `swift test --skip-update` 通过，未改依赖。首次 git fetch 也遇 TLS 失败，使用 HTTP/1.1 重试成功。
- `MeetPR-Demo` / `Demo` 的 `build_run_sim` 成功；正式 `MeetPR` / `Debug` 的 `test_sim` 成功，**9 passed / 0 failed**。诊断专用 `HANG_PROBE` suite 按现有条件未启用。
- Xcode 工具链 `swift-format lint --strict --recursive MeetPR MeetPRTests Modules` exit 0；SwiftLint 严格模式 1,166 文件 0 违规；CI 原模块边界脚本及 `git diff --check` 通过。原始日志与摘要在 `docs/evidence/092-ios-coach/`。
- 仅使用卡 B 指定 iPhone 17 Pro / iOS 26.4 / `8F164D5D-A450-44FD-BDBF-BB351572CF6E`。亲看中文名单、实际名单→概览→D4 详情及 D2、英文跨周概览与详情、中文 accessibility2 深色的顶部/额外组/自加卡，共 9 张新截图，均存于 `docs/evidence/092-ios-coach/`。D4 为完成且处方 4/4，D2 未开始且 0/4；跨周学员 2/2；自加卡为两组，长副标题自然换行，重量/次数/RPE 完整可读。
- MCP 整行中央 tap 曾未触发详情导航；改用 Simulator 辅助功能激活同一入口后 D4/D2 均正常进入，未据此改业务代码。MCP swipe 有快照超时，但随后实屏确认滚动成功。未操作其他模拟器。
- 本轮 `xcrun simctl shutdown` 成功；MCP 列表复核指定 UDID 为 **Shutdown**，关闭了上一轮的设备清理未验项。

### 证据边界

本轮是开发自测与自审，不替代 Opus 的 spec 清单终验。仍未验证真实后端学员删除→教练刷新 E2E、历史 1.0(23) 包升级、iOS 17、VoiceOver 朗读；Dashboard 七列周表实屏仍沿用上一节未验边界（规则有测试，名单不是 Dashboard）。上一节 Networking 测试描述中“与日期参数”不准确：`coachReadRequestsAllLogs` 实际断言 `scope=all`，本轮按真实测试范围记录。原先 `specs/092-flexible-day-self-added/evidence/` 保留为上一轮历史证据，新增证据以本节路径为准。

提交前仓内 hooks 自动清理了证据日志的尾随空白与 EOF 空行，日志内容与测试结论未变；重新暂存后检查。上述 diff-check 的最终核验包含新增文件。

## 2026-10-14 · Spec 092 Card A · iOS 学员端（T2 / P1，工作区交付）

工作树 `/Users/david/Projects/apps/MeetPR-wt-092a`，分支 `feat/092-ios-student`，基线 / 当前 HEAD 均为 `2b647a13`。启动首个操作已在本树试写并删除临时文件成功。按 CARD-A 执行，未 commit / push / 开 PR；未改 CoachKit、SPEC、CONTEXT、NEXT-RELEASE、依赖、工程结构或本地存储键。以下为开发自测证据，功能终验由 Opus 按既定清单收货。

### 实现与工程归属

- 可写、默认选中、撤销资格用 StudentKit 的纯函数 `FlexibleTrainingDay`，不更改共享 CoreModels 的原游标定义；本周未结算日使用原训练页，周历不改，摘要主按钮沿用已有「开始训练」文案键。实际换天后结束当前休息计时。
- 额外组仍用 coached 请求和计划动作 ID，序号接处方之后；所有处方进度、批量完成、还差组数均排除额外组 / 自加动作。主项走原完整录入页，辅助项走原行内表格；额外组 RPE / 处方休息不预填，纯 RPE 处方不注入空杠重量。Quick log 中额外组只读。
- 新增 `StudentAddedSetLog`（Sendable），不伪造 `planExerciseID`；StudentKit 增加可选能力仓库，Networking 增加 adhoc 请求、`scope=all` 响应与删除 API，原默认读取不变。`SetLogDTO.planDayID` 采用 `decodeIfPresent`。现有机器码没有白名单，六个码通过传输测试验证，404 `SET_NOT_FOUND` 在删除边界收敛成功。
- 日期钉住在第一次写入尝试前，失败保留；跨日切换的延迟响应写回原 owner 草稿及服务端 ID；最后一条成功删除后按原 owner 清钉。整卡串行删除遇错停止，已成功的事实不回滚。
- 历史、容量统计、CSV 和三大项家族 e1RM / PR 纳入自加记录；删除 / 取消后按剩余实录重算派生数据。网络事实与本地派生修复分开；缓存回退不能充当完整账本做删除推断，只有权威完整账本可在下次打开时修复遗漏。既有缓存键与磁盘结构不变。
- `--spec092-added` 为显式 Demo 场景：D1 已结算、靠后 D4 已结算且时间最新，D2 两个处方组 + 一个额外组 + 坐姿划船自加记录；D3 可演示非游标写入。默认 Demo 保持无自加历史形态。仓库支持新增和删除。
- 文案取只读 Android `02213e4:src/i18n/catalog/RnExtras.json`：37 个 `student.added.*` 键、74 个中英文值逐字一致；已有同义键复用，原本地化值未变。动作目录无 alias 字段，搜索只匹配中英文名。没有向 Android 工作树写入。
- 大字号实屏发现新增额外组横排挤压，改为只在 accessibility 字号下纵排，默认字号仍按屏幕稿。原组件的英文动作标题 / 完成按钮在大字号下仍有截断（见截图），未扩改已有组件设计。

### 先红后绿与回归纪律

完整日志在 `/Users/david/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-092a-6168730f39db/logs/`；仓内留关键原始摘录于 `specs/092-flexible-day-self-added/evidence/verification.txt`。

- seam 1：首次缺 `FlexibleTrainingDay` 编译红（04:29:51），随后次日默认返回错误的断言红（04:33:55），再绿。
- seam 2：缺 `isExtra` / 合并接口编译红（04:34:37）；Quick log 错把额外组纳入勾选与 entries 断言红（04:47:14）；最近实际记录预填错值（04:59:47）后修正。
- seam 3：`StudentExerciseTag` 缺失编译红（04:37:35），实现标签归类和双语搜索后绿。
- seam 4：写入 API 缺失编译红（04:39:18），取消触感、恢复 owner / 日期、错误提示仍落通用分支、删除后 e1RM 遗留分别出现断言红，再定向修复。断网、延迟响应、10/10 限制、非 PR baseline 回退及权威账本修复为审查后补充回归，加入时部分直接绿，不冒称这些补充测试都先红。
- seam 5：all-scope DTO / 请求缺失编译红（04:35:57 / 04:36:58），可选 `planDayID` 缺失编译红（04:50:24），实现后绿。
- seam 6：历史映射缺失编译红（04:48:28）；删除后派生数据未消失断言红（04:52:55）；统计 / CSV 新输入 seam 缺失编译红（05:03:50）；同组序上次记录 API 缺失红（05:19:23），随后绿。
- 模拟器新增发现：换天未结束休息计时。`changingFlexibleDayEndsRestAndPreservesRecordedSets` 在 05:38:15 明确断言红（`restTimer` 仍为 180 秒），05:38:42 绿。首次修复在全量中多发首次加载 `.end`，3 个既有计时测试失败；收窄为“存在计时且换天”后最终 1010 全绿，未改原断言。最新模拟器复走亦确认 D3 → D2 计时条消失、D2 仍 2/3。
- 直接 shell SwiftPM 的早期失败来自缓存写权限 / 嵌套 sandbox / 依赖网络限制（`/tmp/092-red-sequence*.log`），不计为行为红。最终各包通过 XcodeBuildMCP 的 `swift_package_test` 执行真实 SwiftPM 全量。

既有测试只改 fixture（`makePlanView()` → `StudentAddedTestPlan.unsettledDemo()`），所有 `#expect` / `#require` / `Issue.record` 断言均未删改。原默认 Demo 前两日已结算；新增写门禁后这些“可保存”场景必须使用未结算日，保留原测试意图。逐项如下：

| 原测试 | fixture 调整原因 |
|---|---|
| `todayWorkoutViewModelPersistsEditsToCompletedSet` | 已完成组仍属于未结算训练日，才能测试编辑保存。 |
| `todayWorkoutViewModelLoadsRecordsAndReturnsToLoaded` | 需要实际写入后检查 loaded 状态。 |
| `todayWorkoutViewModelUpdatesActualWeight` | 编辑场景使用可写训练日，与同组保存 fixture 一致。 |
| `todayWorkoutViewModelKeepsWorkoutAndDraftWhenRecordingFails` | 需到达假仓库失败，而非被已结算门禁提前拒绝。 |
| `todayWorkoutViewModelExplainsServerRecordingFailure` | 需执行请求以验证服务端失败提示。 |
| `todayWorkoutViewModelRestoresLoadedWhenRecordingURLCancelled` | 需执行请求以触发 URL 取消。 |
| `todayWorkoutViewModelRestoresLoadedWhenRecordingCancellationError` | 需执行请求以触发 Task 取消。 |
| `todayWorkoutViewModelMapsExpiredSessionDuringSaveToLoginMessage` | 需执行请求以触发会话过期映射。 |
| `ensureLoggedSetIDKeepsFlushedEditsWithoutCompleting` | 视频前置 flush 在可写日测试。 |
| `stalePersistDoesNotTouchReloadedState` | 需发出可挂起的写入再切换状态。 |
| `overlappingVideoMintAndCompleteApplyInOrder` | 需进入视频 ID 与完成写入的竞争路径。 |
| `recordingThatStartsDuringRefreshKeepsTheVisibleWorkoutGeneration` | 需真正开始写入以验证 generation 保护。 |
| `completionTimeoutRollsBackWithoutWaitingForUncooperativeRequest` | 结算前保存的 fixture 要可写，保留超时断言。 |
| `completionFailureClosesCelebrationPreservesSetsAndAllowsRetry` | 结算失败前真实组保存需成功。 |
| `realSaveOverAssumedRecordRestoresSharingImmediately` | assumed → real 的写回需发生于未结算日。 |

### 学员验收清单逐项对应（测试通过不代替终验）

截图均在 `specs/092-flexible-day-self-added/evidence/`，同一 iPhone 17e `BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`，未操作其他模拟器。

| SPEC 项 | 测试名 / 实屏证据 | 覆盖边界 |
|---|---|---|
| 1 本周非游标可写、切回保留 | `flexibleWeekAllowsUnsettledDaysOnly`、`changingFlexibleDayEndsRestAndPreservesRecordedSets`；`en-same-week-start.jpg`、`en-same-week-recorded.jpg`、`en-return-d2-preserved-no-rest.jpg` | Demo 用 D3（D4 已结算），实点完整录入成功，回 D2 仍 2/3。 |
| 2 先后结算 / 最新撤销 | `flexibleDefaultResumesLatestRealGymDayAndUndoUsesTimestamp`；既有 completion / undo 全量测试；`zh-completed-readonly.jpg` | 最新资格按时间验证；未在 UI 连续完成“双日结算再撤销”整条路径。 |
| 3 外周 / 已结算只读 | `flexibleWeekAllowsUnsettledDaysOnly`、`fullEntryRejectsOtherWeekWrites`；`en-other-week-readonly.jpg`、`zh-completed-readonly.jpg` | 实屏无新增入口，完整录入 public seam 也拦外周。 |
| 4 重进默认日 / 04:00 gym-day | `flexibleDefaultResumesLatestRealGymDayAndUndoUsesTimestamp`、`addedRowsRestoreOwnerAndPinnedDateAcrossDaySwitch` | 使用纯函数时钟与假仓库；未改系统时钟跨 04:00，Demo 进程重启会重新造 seed，不能当持久化升级证据。 |
| 5 主项额外组 | `addedWorkoutWritesExtraAndDayBoundAdhocAndDeletes`、`extraPrefillUsesMostRecentlyRecordedSet`、`extraCancellationRemovesE1RMAndPR`；`zh-added-and-extra.jpg`、`zh-extra-entry-optional-rpe.jpg` | 已实点加组、完整页预填 90×3 / 空 RPE 并保存，剩余仍 1 组；未实拍视频上传 / 教练待看联调。 |
| 6 辅助项额外组 / 批量排除 | `extraRowsNeverReplacePrescriptionProgressAndBatch`、`addedCancellationDoesNotRepeatCompletionFeedback`；既有 089 全量回归 | 行模型与共享行内写入 seam 覆盖；未逐点走完辅助项额外组的 UI 增删整链。 |
| 7 2 个处方 + 1 额外仍差 1 | `extraRowsNeverReplacePrescriptionProgressAndBatch`；`zh-added-and-extra.jpg`、`zh-added-saved.jpg` | 截图与录入后的运行时文本均仍显示差 1。 |
| 8 选择、自加卡、历史、进步 | `studentPickerMapsEveryMuscleAndFamily`、`studentPickerIncludesThreeFamiliesMultipleMusclesAndUnclassifiedExercises`、`addedWorkoutWritesExtraAndDayBoundAdhocAndDeletes`、`addedHistoryMarksExtraAndIncludesFamilyRecords`、`addedRecordsContributeToHistoryStatsAndCSV`；`zh-picker.jpg`、`zh-added-saved.jpg`、`en-history-added-extra.jpg`、`zh-history.jpg` | UI 已选硬拉、100×5 保存、确认整卡移除；历史显示双标记。e1RM / PR 纳入及删除由测试验证，未在 UI 完整走进步曲线变化。 |
| 9 两个 10 上限 | `quickLogKeepsExtraRowsReadOnlyAndEnforcesTenExtraLimit`、`addedExercisesAndRowsStopAtTenWithoutChangingPrescription` | 测试覆盖到 10 拒绝第 11；未在 UI 重复点击到两种上限。 |
| 9b 单组完成轻触感 | `addedCancellationDoesNotRepeatCompletionFeedback`、既有 accessory completion 回归；`.sensoryFeedback(.impact(weight: .light), trigger: inlineCompletionFeedback)` 接线自查 | 模拟器已点 ✓；事件只在有效完成递增，取消不增，批量保留原按钮反馈；未验真机体感。 |
| 10 老用户首屏 | `zh-old-user-no-added.jpg`、`zh-added-and-extra.jpg`、`en-return-d2-preserved-no-rest.jpg`；`plannedDTOAcceptsMissingPlanDayID` | 按卡看默认无自加记录与训练到一半两种 Demo；未安装真实 1.0(23) 旧二进制做升级。 |
| 11 断网保留 / 重试 | `addedFailureKeepsInputAndPinnedDateAcrossRetry`、`extraFailureKeepsInputAndCanRetry`、`addedWriteFinishingAfterDaySwitchKeepsCanonicalID`、`deletingLastAddedRowDuringDaySwitchClearsDatePin` | 假仓库注入错误 / 延迟响应，保留输入、跨日日期、成功重试；没有连接未部署的 spec 050 后端。 |
| 补记只读 | `quickLogKeepsExtraRowsReadOnlyAndEnforcesTenExtraLimit` | 额外组 visible / readonly / excluded，未单独截图补记页。 |
| 网络六码 / 可选 DTO | `studentAddedErrorCodesSurviveTransport`（六参数）、`addedErrorsHaveSpecificRecovery`（四提示）、`studentAddedResponseKeepsNullablePlanSlotAndOptionalDay`、`studentAddedRequestUsesDayAndAllScopeWithoutChangingPlanDefault`、`plannedDTOAcceptsMissingPlanDayID` | 未发布日复用既有提示；404 已删在网络删除边界验证。 |
| 派生修复 | `deletingAddedSetRemovesItsE1RMAndPR`、`deletedHighestAddedWeightRestoresNonPRBaseline`、`authoritativeLedgerRepairsDeletedSourceAfterReopening`、`previousAddedSessionUsesMatchingIndexAndIgnoresFailed`、`addedPreviousRecordCanFillWeightAndRepsWithoutRPE` | 权威 / 缓存区分、重新打开修复、同组序上次记录、失败组排除。 |
| 语言 / 大字号 / 深色 | `zh-picker.jpg`、`en-picker-accessibility-large-dark.jpg`、`en-extra-accessibility-large-dark.jpg` | 中英文实屏；三组标签在大字号各自换行，无横向滚动；新增额外组文字可读。 |

### 独立审查与本地处置

使用 code-review / review-loop 的只读 Standards 与 Spec 双轴，运行两轮（只读快照 `/tmp/092-review`、`/tmp/092-review2`）。仓库缺 `docs/agents/issue-tracker.md`，依赖该配置的 Matt tracker 工作流未运行；不妨碍本地独立审查。未自行创建 tracker 配置。

第一轮 Standards 5 项、Spec 8 项（存在重叠）：跨日服务端 ID、远端事实与派生失败、离线缓存、baseline 从 PR 错误重建、CAS 冲突静默、完整录入门禁、预填时间、上次记录、统计 / CSV。第二轮指出权威账本恢复、额外组重放、跨日删除最后行清钉、同组序历史等缺口。均已本地修复并对应新增回归，最终全量通过。第二轮 reviewer 的快照结论仍为 BLOCKERS；遵守技能两轮上限，没有发起第三轮，**不把后续本地修复冒称独立 reviewer 已给 CLEAN**。交 Opus 收货复核最终 diff。无待 David 决定的产品分叉。

### 自检最后结果、环境限制与清理

| 自检 | 最后结果行 / 结果 |
|---|---|
| `swift test --package-path Modules/StudentKit`（MCP SwiftPM） | `✔ Test run with 1010 tests in 46 suites passed`，0 failed / 0 skipped。 |
| `swift test --package-path Modules/Networking`（MCP SwiftPM） | `✔ Test run with 135 tests`，0 failed / 0 skipped。 |
| `swift test --package-path Modules/CoreModels`（MCP SwiftPM） | `✔ Test run with 158 tests`，0 failed / 0 skipped。 |
| `xcrun swift-format lint --strict <68 个改动 Swift 文件>` | exit 0，无输出；`/tmp/092-format.log`。 |
| `swiftlint lint --strict <同 68 文件>` | `Done linting! Found 0 violations, 0 serious in 68 files.` |
| 模块边界 CI 等价四项 rg 检查 | PASS：Coach/Student 无互相 import 或 Package 依赖。 |
| `git diff --check` | exit 0，无输出。 |
| `MeetPR-DemoStudent`，指定 UDID 构建运行 | `** BUILD SUCCEEDED **`；61.838 秒，0 warnings / 0 errors，已安装运行并实屏检查。 |
| `stop_app_sim` | `SUCCEEDED`，Demo 已停止。 |
| `xcrun simctl shutdown BBE9EB95-01DE-452E-866C-3DD0B62F9BDA` | exit 1：`CoreSimulatorService connection became invalid` / `Connection refused`。 |

完整命令结果与原始红阶段摘录见 `evidence/verification.txt`，不是只保留成功摘要。shell 对 CoreSimulator 的 XPC 连接被 sandbox 拒绝；Computer Use 也未获 Simulator 访问，未绕过权限。可用 XcodeBuildMCP 没有 shutdown 接口。**指定模拟器尚未确认关闭，须宿主侧关闭这一台**；没有碰其他设备。

最终已验证 `.app` 保留在 `/tmp/meetpr-spec092-student.app`，删除本任务独占 `.build-092/` 中间产物；未清理别人的工作树 / 模拟器 / 构建目录。测试、截图均用 Demo / 假仓库，不读取凭证。上述 UI 未走全的路径、后端联调、真机触感及旧二进制升级留待终验，未宣称功能验收通过。

### 本卡改动文件清单

- `MeetPR/Sources/MeetPRApp.swift`
- `Modules/CoreModels/Sources/CoreModels/Entities/Plan/StudentAddedSetLog.swift`
- `Modules/Networking/Sources/Networking/APIClient+StudentAddedSets.swift`
- `Modules/Networking/Sources/Networking/DTO/AllStudentSetLogsDTO.swift`
- `Modules/Networking/Sources/Networking/DTO/CreateStudentAddedSetRequestDTO.swift`
- `Modules/Networking/Sources/Networking/DTO/SetLogDTOs.swift`
- `Modules/Networking/Tests/NetworkingTests/StudentAddedSetDTOTests.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentAddedDemoScenario.swift`
- `Modules/StudentKit/Sources/StudentKit/Demo/StudentDemoSeed.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/ExportDataSheet.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/GrowthCurveViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/MyProfile/TrainingLogCSVExporter.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogCard.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryLogRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/AccessoryRow.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/CompletedTrainingExercise.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/ExtraSetControls.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/FlexibleTrainingDay.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/QuickLogPlan.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/QuickLogSheet.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/RemoveStudentSetButton.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/SetEntrySheet.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentAddedExerciseSection.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentAddedInlineRows.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentAddedPreviousSession.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentAddedRows.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentExercisePicker.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/StudentExerciseTag.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutTypes.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+DraftBuilding.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel+RecordingError.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TodayWorkoutViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingCompletionAvailability.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingExerciseProgress.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingFlowPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/TrainingSetProgress.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/AllHistoryScreen.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/GrowthScreenPresentation.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/HistoryEntriesView.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/ProgressDataModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/ProgressMetrics.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedDerivedHistory.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedHistory.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedHistoryRows.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/StudentAddedLedgerRepair.swift`
- `Modules/StudentKit/Sources/StudentKit/Features/TrainingHistory/TrainingHistoryViewModel.swift`
- `Modules/StudentKit/Sources/StudentKit/Repository/BackendStudentTrainingLogRepository.swift`
- `Modules/StudentKit/Sources/StudentKit/Repository/InMemoryStudentTrainingLogRepository.swift`
- `Modules/StudentKit/Sources/StudentKit/Repository/StudentAddedLogError.swift`
- `Modules/StudentKit/Sources/StudentKit/Repository/StudentAddedLogRepository.swift`
- `Modules/StudentKit/Sources/StudentKit/Resources/Localizable.xcstrings`
- `Modules/StudentKit/Sources/StudentKit/StudentFormatting.swift`
- `Modules/StudentKit/Sources/StudentKit/StudentRootView.swift`
- `Modules/StudentKit/Sources/StudentKit/StudentStrings.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/FlexibleTrainingDayTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/StudentAddedErrorTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/StudentAddedFailureTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/StudentAddedRowsTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/StudentAddedTestSupport.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/StudentAddedWriteTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/StudentExercisePickerTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutAssumedWriteBackTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutCompletionInFlightTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutPersistOrderingTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutRefreshTests.swift`
- `Modules/StudentKit/Tests/StudentKitTests/Features/TodayWorkout/TodayWorkoutViewModelTests.swift`
- `docs/CODEX-JOURNAL.md`
- `specs/092-flexible-day-self-added/evidence/en-extra-accessibility-large-dark.jpg`
- `specs/092-flexible-day-self-added/evidence/en-history-added-extra.jpg`
- `specs/092-flexible-day-self-added/evidence/en-other-week-readonly.jpg`
- `specs/092-flexible-day-self-added/evidence/en-picker-accessibility-large-dark.jpg`
- `specs/092-flexible-day-self-added/evidence/en-return-d2-preserved-no-rest.jpg`
- `specs/092-flexible-day-self-added/evidence/en-same-week-recorded.jpg`
- `specs/092-flexible-day-self-added/evidence/en-same-week-start.jpg`
- `specs/092-flexible-day-self-added/evidence/verification.txt`
- `specs/092-flexible-day-self-added/evidence/zh-added-and-extra.jpg`
- `specs/092-flexible-day-self-added/evidence/zh-added-saved.jpg`
- `specs/092-flexible-day-self-added/evidence/zh-completed-readonly.jpg`
- `specs/092-flexible-day-self-added/evidence/zh-extra-entry-optional-rpe.jpg`
- `specs/092-flexible-day-self-added/evidence/zh-history.jpg`
- `specs/092-flexible-day-self-added/evidence/zh-old-user-no-added.jpg`
- `specs/092-flexible-day-self-added/evidence/zh-picker.jpg`


## 2026-10-14 · Spec 092 卡 A 续作与 David 直驱交付

- 工作树：`MeetPR-wt-092a`，分支 `feat/092-ios-student`。接续原有未提交实现，未回滚或重建；David 本轮明确授权测试后 commit / push / PR，不合并，覆盖卡中原「不提交」限制。只改本工作树。
- 实现依据：本仓 spec 092 / 卡 A，Android PR #92（`meetpr-rn@e00edc5f7f3d0733f2e4ac9aa6f112c2020c48aa`），以及该 RN 分支 `docs/ios-handoff-2026-10-14-walkthrough.md` 第 3 项。后者在 iOS 树不存在，按 RN 原文读取，未另造正典。
- 已完成日改用与开始前概览一致的卡片：成功色左线、今日训练标题与完成标记、仅处方动作/组数；每动作已记 x/y，展开显示实际记录、未记组为 —、额外标记；自加动作末尾独立行；撤销保留原规则。移除原重复完成 notice 和记录卡。
- 审查修复：离线缓存账本显式非权威；抓远端账本前取 revision，私有重放后单次 CAS 提交，旧账本不重试覆盖新保存；处方重量基线沿用比赛动作/站姿解析，自加仍按三大项家族；目录失败保留已有行且后续重试，未完整读到目录不得全量重建 PB。
- UI 续测又修复两处 Demo 问题：固定 locale 不会覆盖 App 的资源语言，动作名改为显式 en / zh-Hans lproj 读取，确保中文环境英文搜索可用；预加载计划首次进入时，目录 fallback 使用传入计划，防止尚未赋值的 planDays 清空目录。
- 回归：缓存可信性、旧账本与并发保存、目录失败与恢复、目录缺失保留 PB、预加载计划动作名、已完成日处方/实际分离均有失败证据及修后验证；Demo 双语名称另有回归测试。既有断言的调整沿用前节逐项原因。

### 本轮验证证据

原始截图和测试输出放 `docs/evidence/092-student/`；上轮 `specs/092-flexible-day-self-added/evidence/` 保留。下列是开发自测，不替代 Opus 按 spec 的正式验收。

- 全量 SwiftPM：StudentKit **1018**、Networking **135**、CoreModels **158**、CoachKit **443**、AppShell **107**、RepositoryContracts **6**、DesignSystem **73**、ChatUI **84**、Analytics **30**，共 **2154** 通过。StudentKit 首轮并发负载下视频测试超时，串行全量重跑通过；CoachKit / AppShell 首轮 MCP 进程无法连接 GitHub，使用当前 shell 网络下载后完整测试通过。AppShell 曾因同时修改源码中断，最终稳定源码全量 107 再跑通过。
- 73 个变更 Swift 文件 `swift-format lint --strict`、仓 `swiftlint lint --strict`、模块边界检查和 `git diff --check` 通过。
- `MeetPR-DemoStudent` 最终 DemoStudent 配置模拟器构建通过，日志：`build_sim_2026-10-14T08-11-27-932Z_pid76155_1a9fe369.log`。仅指定 iPhone 17e / iOS 26.4（`BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`）用于本轮截图。工具早期按同名设备重新解析过目标，后续固定 UDID 并重新构建验证。
- 中文：同周 D3 开始并记 1 组，回 D2 原 2/3 保留；主项新增额外组、完整录入 RPE 留空保存、删除确认；D2 2/3 + 额外 + 自加结算，新卡展开显示正确，撤销只在最新结算日可用；新增窄握卧推保存；历史显示两类标记。
- 英文：最终二进制初次加载 Seated Row 名称恢复；选择页搜索 Close 命中，选中后新增自加卡，100 × 5 @8 保存；Progress 刷新后卧推 e1RM 从 118.6 到 128.2，历史显示 Close Grip Bench Press / Added by you / Extra。刻意输入 150 × 5 的异常估计值未抬升曲线，沿用既有异常值规则。
- 视觉：中文深色；英文浅色、accessibility-large 的选择页（所有筛选标签可见并按语义行换行）和完成日卡（长名称换行，撤销可达）。已亲眼查看截图。原主项 hero 在最大字号下重量会换行，这是既有布局，未在本卡扩大修改。
- 最终新增两处 Demo 返修经过 Standards 定向复核；Standards 与 Spec 独立结论另见本节后续记录。仓缺 `docs/agents/issue-tracker.md`，未伪称执行依赖 tracker 的 Matt 流程；本地双轴只读审查已执行，配置补齐需 David 调用 `$setup-matt-pocock-skills`。

### 未验证与保留边界

- 后端 spec 050 尚未部署：真实 adhoc 保存/删除、scope=all 联调、教练端实时读回及视频附件联动没有验证；网络契约和错误分支以假仓库/DTO 测试验证。
- 模拟器无法确认真机触感体感；只验证 light 触发门控与代码接线。没有执行旧发布二进制到新包的真实升级，按卡使用 Demo 的进行中/无自加形态验证。04:00 跨日与进程重入规则由单元测试覆盖，没有让模拟器跨日等待。
- 辅助项全部完成、上限 10、断网保留/重试等边界以本卡自动化回归与上轮证据为准，本轮未重新手点所有组合。

### 最终工程闸与独立审查

- Xcode MeetPR / Debug / 指定 iPhone 17e：9 项测试通过（test_sim_2026-10-14T08-22-07-424Z_pid76155_58f5dfd1.log），连同 SwiftPM 共 2163 项测试通过。
- Standards：初轮缓存权威性、旧账本覆盖并发保存两项 P1 修复，第二轮 CLEAN；Demo 双语资源、预加载目录和 SourceSnapshot 参数整理定向复核 CLEAN。
- Spec：初轮比赛动作基线、目录失败丢行两项修复；第二轮缺目录重建 PB 的 P2 补先红后绿回归并修复，定向复核 CLEAN。无未决 blocker；正式验收仍由 Opus 按原清单执行。
- David 最终确认 PR 指向 release/1.0，不合并；基线 7acf289c8578663e3b8155544514f080f9795743。未 rebase 或修改其他工作树。
- 指定模拟器已关机。生成目录移入本树 gitignore 的 .build/spec092-derived，最终 Demo app 位于其中 Build/Products/DemoStudent-iphonesimulator/MeetPR.app；未清理其他任务产物。

## 2026-10-17 · Spec 093 I1/I2 开发自测

- 工作树 `MeetPR-wt-093`，分支 `feat/093-cn-email-onboarding`，从 release/1.0 `f2d44394` 接续。依据 RN spec093 SPEC/CARDS/IOS-HANDOFF，SPEC 优先；不改 RELEASES/NEXT-RELEASE，本轮由主代理统一 commit/push/PR，不合并。
- I1：CN 复用 Global 邮箱页，4 字段注册 + 发码冷却/换邮箱/错误/返回登录；旧 Session/Keychain/主界面入口保留；Global 默认邮箱/OAuth行为保留。按 David 截图定向修正 CN 输入字体，未另做设计。
- I2：两轨识别完整邀请消息/链接，CN 点击粘贴、两处复制完整消息、永久码系统分享；Global 纯码。详见 [原始证据与复现](evidence/spec093-2026-10-17/README.md)。5 模块 1891 项通过，CN Xcode 编译通过；新行为先红后绿，独立双轴审查后的错误态/提交锁定/登录入口等已定向返修。
- 环境偏差已披露并只读审计：`build_run_sim` 未应用 localhost env，修正前的合成邮箱操作误请求国内 staging，确认新增注册验证码3条；同一邮箱新增重置码0条、两个合成邮箱新增 users 0条（2026-10-17 04:30 UTC 之后）。未提交注册/重置密码，未清理或回滚远端。邮件投递状态未核实。显式 `launch_app_sim(env:)` 并核对本地请求日志后重拍截图。详细边界、时间和私有原始记录指针见证据 README。
- 真实邮件、双端真实找回密码、beta24已登录升级由 David 按最新卡手测；staging全链路与旧账号数据留主流程部署批准后执行。本轮未发布。
- 补证完成：Global / Global 配置 Xcode 编译191.1s通过；Apple/Google/邮箱入口、Global无粘贴/无分享、复制纯码已亲看。CN整段消息/裸链接/无关文本粘贴、教练两处复制和系统分享预览都有实际模拟器图，索引见上述README。裸链接通过姓名框本地中转剪贴板，未提交绑定。后续全链路仍以部署后验收为准。


## 2026-10-22 · Spec 094-iOS 开发实装（未完成交付）

- 本树 `MeetPR-wt-094-zh-hant` / `feat/094-zh-hant`，基线 `6c5466a0`；按 Claude 卡执行，开工临时文件试写通过。不 push/PR，不动发布正典、build 号或 tag。
- 已实装 v1 术语表对应的十份 xcstrings（2344 key）、权限繁体、生成动作展示与输入映射、来源保护、双字形搜索/导入、週字星期、三条自有 API 通道 Accept-Language。zh-Hans/en 树与基线一致，原目录/aliases 未改。细节、命令、红绿断言和原始日志指针见 [开发证据](evidence/094-zh-hant/README.md)。
- CARD 三个 seam 均先红后绿；追加 tempo、同名用户动作、Demo 影片来源回归。CoachKit 最终478项全绿；另 Analytics30/CoreModels160/DesignSystem74/Networking141/RepositoryContracts6全绿。StudentKit新增3项独立通过。
- 九包未全绿：AppShell Keychain两测试失败，最小探针 `SecItemAdd: 100001 UNIX[Operation not permitted]`；ChatUI视频编码 -12903；StudentKit视频导出及后台上传超时共33 issue，两项上传用例独跑绿、视频独跑仍红。没有跳过失败后宣称通过。主工程初轮9项绿，最终改动后复验与截图结果待补。
- strict lint / swift-format 已在改动Swift文件通过，最终Demo fixture追加后还需一次复核。独立 Standards 二轮 CLEAN；Spec 二轮Demo来源标志漏接已定向修复并获测试绿。无来源的 SetRefV1 / CoachFeedbackVideo 原文保留，完整覆盖边界仍待裁决。
- 执行中外部把 GLOSSARY 更新为v2（課表/反饋/下數、别名/导入语法），与 CARD aliases 不变约束冲突，已请求确认。未覆盖外部文档；当前生成器 `--check` 对新v2报 Stale generated file（AppShell xcstrings），不宣称v2完成。
- 部分资源首次暂存成功，后续暂存/commit被沙箱拒绝：`fatal: Unable to create '/Users/david/Projects/apps/MeetPR/.git/worktrees/MeetPR-wt-094-zh-hant/index.lock': Operation not permitted`。无新增commit；没有绕过权限或换目录。未来每笔提交须包含 David 指定的 Claude Opus 5.5 Co-Authored-By 末行。

### v2 返修

- 收到并执行同目录 `AMEND-v2.md`，覆盖前述 v1 范围疑问；GLOSSARY v2.1 的課表、反饋、杆→槓、杠杆→槓桿已生成。长词先覆写；reps 用显式 key 白名单，其他「次」义保留。追加台湾动作别名 17 条，原 61 条逐项未变；原 catalog 字节不变，zh-Hans/en 树逐项未变。
- 搜索统一繁→简、杆字形与数字规格括号规范化；保留 PIN／纯单腿等语义括号。教练选择、现有导入 matcher、学员 tag 与历史筛选共用 matcher。AMEND 第 3 项解析／Excel 表头只适用于网页，iOS 未扩范围，Spec reviewer 已核实。
- 红阶段：v2 生成 2 个断言及新 key 参数失败，台湾别名 18 断言失败；v2.1 杆类名称覆写有合成输入回归。实现后 `.build/zh-hant-tools/bin/python -m unittest discover -s scripts/zh-hant -p test_generation.py` 4 项通过；`scripts/generate-zh-hant.py --check` 10 目录／2344 key 通过。CoachKit 全量 480 通过（旧别名数61断言已先失败后更新78）。
- 为生成字典数据保留 OpenCC LICENSE/NOTICE 到 CoreModels Resources；来源是固定的开发期 OpenCC 0.1.7，未增加运行时依赖。
- reps 命中的全部 55 个 key（实际转换仍基于 key 内的 reps 字词，不改变其他内容）：

```text
chat.load
coach.planning.common.reps
coach.planning.count.rep %lld
coach.planning.count.repPlural %lld
coach.planning.count.setsAndReps %lld %@ %lld
coach.planning.editor.addRepMaximum
coach.planning.editor.removeRepMaximum
coach.planning.editor.repMaximum
coach.planning.progression.repDecrease
coach.planning.progression.repIncrease
coach.planning.step4.setRepIntensity %lld %@ %@
coach.planning.step4.setRepsIntensity %lld %@ %@
coach.planning.step4.setsRepIntensity %lld %@ %@
coach.planning.step4.setsRepsIntensity %lld %@ %@
coach.planning.validation.incompleteWeekOneSetSpecs
coach.planning.validation.invalidWeekOneSetSpec
coach.videoFeedback.reps
coach.videoFeedback.repsValue %lld
designSystem.numberPad.enterReps
designSystem.preview.timesUnit
designSystem.reps
designSystem.repsUnit
designSystem.setRow.metrics %@ %@ %@
student.accessory.repsLabel
student.e1rmSourceRTS
student.exportDataSheet.copy005
student.feedbackVideoPresentation.copy002
student.feedbackVideoPresentation.copy002.one
student.feedbackVideoPresentation.copy003
student.feedbackVideoPresentation.copy003.one
student.growthCurveView.copy010
student.quickLog.copy009
student.quickLog.copy019
student.sessionSummaryView.copy008
student.setEntryRpe.copy001
student.setEntryRpe.copy002
student.setEntryRpe.copy003
student.setEntryRpe.copy004
student.setEntryRpe.copy005
student.setEntryRpe.copy006
student.setEntryRpe.copy007
student.setEntryRpe.copy008
student.setEntryRpe.copy009
student.setEntryRpe.copy010
student.setEntrySheet.copy003
student.setEntrySheet.copy004
student.step3StrengthSection.copy008
student.step3StrengthSection.copy009
student.step3StrengthSection.copy010
student.step3StrengthSection.copy014
student.todayWorkoutScreen.copy012
student.todayWorkoutTypes.copy003
student.todayWorkoutTypes.copy004
student.workoutCompletionPresentation.copy003
student.workoutCompletionPresentation.copy003.one
```

### 语言头返修

- 按 `AMEND-header.md` 和 SPEC 最新共享契约，把 APIClient／RealtimeClient／EventFlusher 显式语言头改为 `X-MeetPR-Locale`。未登录 auth、更新检查复用 APIClient；不手动覆盖 Accept-Language，不改 OAuth／OSS 第三方请求。语言 seam 覆盖 zh-Hans/Hant/en 及区域回退，显式 Hans 优先于 TW 区域。
- 先改断言跑红：API/WebSocket 3 测试共 75 issue，analytics 1 测试4 issue；实现后 Networking 141、Analytics 30 全量通过。验证默认请求未手动设 Accept-Language、传入值逐字保留、自定义头在401重试保留。日志摘录见 `docs/evidence/094-zh-hant/header-*-results.txt`。

### 最终开发验证与待收货

- 40 个变更 Swift 文件按仓配置 `swiftlint lint --strict`、`xcrun swift-format lint --strict` 通过，生成器检查、Python 4 项、`git diff --check` 通过。原始日志 `.build/094-lint-final.log`、`.build/094-format-final.log`。
- 最后全量：Analytics30／CoachKit480／CoreModels160／DesignSystem74／Networking141／RepositoryContracts6 通过。AppShell118项中Keychain两测试共3issue；ChatUI84项中视频编码失败；StudentKit1036项重跑仅剩15个视频导出issue，上传超时不再复现。保留原失败，不跳过测试。详见 [最终证据与命令](evidence/094-zh-hant/README.md)。
- 主工程最终 MeetPR / Debug / iPhone17ProMax iOS26.5，XcodeBuildMCP `test_sim` 9通过、0失败、0跳过，28.9s；`DerivedData/094-main-final-tests.xcresult`。这是最终代码与新增归属资源后的复验。
- 同模拟器用 `-AppleLanguages "(zh-Hant)" -AppleLocale zh_TW` 启动，亲眼核对并保存教练首页、学员今日训练两图到 `docs/evidence/094-zh-hant/`。Demo构建只用命令行关闭优化加速，工程配置未改。截图显示課表/反饋/週/下數等繁体用语，用户姓名与教练备注仍为原文。
- 双轴最终定向复核 Standards CLEAN、Spec CLEAN，无新增 finding；旧无来源快照／反馈名称边界仍待 Opus 裁决，本记录不代表正式验收。九包全绿要求尚未达成。
- 按两份 AMEND 的不 commit 要求保持未提交工作区。此前 Git 写权限原始拒绝仍见本卡首段，未再尝试 Git 写入；无 push／PR／build号／tag／NEXT-RELEASE改动。未来提交末行必须为 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。

### v2.2 返修（2026-10-22）

- 基于 Opus 提交 `1b985255`，本工作树临时文件试写成功。按 `AMEND-v22.md` 与已更新的术语表重跑生成器：AppShell／CoachKit／StudentKit 共 31 条繁体文案改用「發布／取得」，生成的搜索映射同步增加「取得→获取」。生成器逻辑无需修改；网页 title 项不适用于本仓。
- 沿用 Python 生成测试 seam，新增 1 项参数化回归覆盖两处「發布給學員」和「取得驗證碼」：旧产物 3 个断言失败，重新生成后 5 项全绿；[红阶段](evidence/094-zh-hant/v22-red-results.txt)、[绿阶段及生成检查](evidence/094-zh-hant/v22-green-results.txt)。`--check` 对 10 目录／2344 key 的占位符、术语、简体特有字与产物一致性校验通过。全部 zh-Hans/en 树与 HEAD 逐项一致；动作 catalog、aliases、展示名表字节不变。
- XcodeBuildMCP：DesignSystem `TraditionalChineseCatalogTests` 1 项通过；CoreModels 全量 160 项通过。MeetPR／Debug／iPhone 17 Pro Max iOS 26.5 编译并启动成功（41.4s，无 warning/error），使用本树 `.build/094-simulator`；以 `-AppleLanguages (zh-Hant) -AppleLocale zh_TW` 亲看注册页「取得驗證碼」，[截图](evidence/094-zh-hant/v22-register-zh-Hant.jpg)。未提交注册或请求验证码。
- 全仓 `swiftlint lint --strict --config .swiftlint.yml`：1220 文件零违规；`xcrun swift-format lint --configuration .swift-format --recursive --strict MeetPR MeetPRTests Modules` 通过；Python 编译与 `git diff --check` 通过。日志 `.build/094-v22-lint.log`、`.build/094-v22-format.log`；MCP 原始日志目录 `~/Library/Developer/XcodeBuildMCP/workspaces/MeetPR-wt-094-zh-hant-6bf212735501/logs/`，本轮 build `build_run_sim_2026-10-22T09-45-01-503Z_pid87085_8a9e3243.log`，目录测试 `swift_package_test_2026-10-22T09-45-42-937Z_pid87085_4455b78b.log`，CoreModels `swift_package_test_2026-10-22T09-46-33-656Z_pid87085_2ece3e6a.log`。
- 本轮为术语资源定向返修，未重跑上一轮九包全量，既有失败与待裁决事项仍按前文记录；开发自检不替代 Opus 验收。保留来时的 GLOSSARY／AMEND 改动，不 commit、不 push，不改发布正典。
