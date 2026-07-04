# SPEC 045 — solo 随手记核心链路(自己练 Free 档主菜)

- **状态**: Draft
- **来源**: 自己练 Free 档商业化 wave(设计权威 `~/Brain/wiki/projects/MeetPR/self-train-free-tier-wave.md`,David 2026-07-04 拍板 C 形态「随手记+轻结构」)。backend 契约 = backend spec 010(PR #39):`POST /sets/log` adhoc 形态 + `GET /students/:id/sets?scope=all`。
- **范围**: 设计文档 A3(随手记核心)+ A4(轻结构)。**不含**:A2 注册/onboarding(046)、A5 成长/训练页适配(047)、比赛元素隐藏(049 一并)。
- **前置**: backend PR #39 合入 staging;iOS #209(catalog 去重)先行合入(见 §模块)。

## 用户可见行为(学员看到啥)

**今天 tab · solo 形态(扫视态)**
- 首屏 = 「开始训练」主 CTA + 今日已记摘要卡(动作 × 组数 × 当日最佳 e1RM 亮点;无记录时给空态引导,一句话 + CTA,不说教)。
- 今天已有记录时 CTA 文案变「继续训练」。

**训练会话(编辑态,全屏推入)**
- 空会话首屏:「重复上次」卡(展示上次训练日的动作+组×重量,一键带出全部草稿行)+「选动作」入口。
- 动作选择器(sheet):搜索(中英文/别名)+ 分类浏览(主项/辅助,按 `main_lift_family`/`exercise_type`)+「最近练过」置顶 +「常用动作」(按 90 天频次自动)。
- 选中动作 → 动作卡:逐组草稿行,**原样复用** `SetRecordRow`/`SetEntrySheet`/失败标记/RPE/配重可视化/RPE 驱动休息计时器(走查亮点 G-1..9 不回退是硬验收)。
- 可加组、加动作、换动作;「结束训练」→ 回扫视态并刷新摘要。
- 断网时照常记录,行尾出现「未同步」角标;恢复后自动上传消失。

**命名纪律**:全部文案不出现「计划」二字(Pro 词汇)。

## 模块与依赖(工程)

1. **新 SPM 模块 `CatalogKit`**(本 spec 的第一块砖):
   - `exercise-catalog-v2.json` + `exercise-aliases.json` 资源、`ExerciseCatalog` 加载器、目录模型、搜索/分类逻辑从 CoachKit **下沉**至 CatalogKit;CoachKit 改依赖 CatalogKit(调用点重指,行为零变化);StudentKit 新增依赖 CatalogKit。
   - ⚠️ 与 iOS #209(去重)同文件:**#209 先合**,本 spec 在其之上做搬移;若 #209 长期停滞,升级 David 裁决顺序。
2. **Networking**:新增 `CreateAdhocSetLogRequestDTO`(`exercise_id`/`logged_date`/`set_index`/`weight_kg`/`reps`/`rpe?`/`completed`/`failed`)与 `logAdhocSet()`;`SetLogDTO` 加可选 `exerciseID`/`loggedDate`/`adhoc` 解码(向后兼容);`studentSetLogs()` 加 `scope` 参数(默认 plan 不变,solo 路径显式 all)。
3. **StudentKit**:
   - `Features/SoloSession/`:`SoloTodayView`(扫视态)、`SoloSessionView`(编辑态)、`SoloSessionViewModel`(镜像 `TodayWorkoutViewModel` 的 SetRowDraft 形:draft 行 + commitSet → persist → e1RM/PR 副作用挂点)、`ExercisePickerSheet`。
   - `StudentTrainingLogRepository` 协议扩展:`recordAdhocSet(exerciseID:loggedDate:...)` + `fetchLogs(scope:)`;Backend/InMemory 双实现同步。
   - **断网重发队列** `QueuedTrainingLogRepository`(装饰器):磁盘持久(Application Support 下 JSONL),launch/前台恢复/重试冲洗(指数退避封顶),行级「未同步」状态发布给 UI。仅包 solo 写路径(coached 路径本 spec 不动,迁移到队列属后续)。
   - `StudentRootView` 按 `TrainingMode` 分叉:solo → 今天 tab 用 `SoloTodayView`;训练/成长/我的 tab 本 spec 不动(047 处理)。
4. **AppShell**:`RootView.studentRoot(for:)` 把 `user.trainingMode`(由 role 推导)传入 `StudentRootView`;组 solo 依赖(CatalogKit + queued repo)。

## 数据与会话模型

- **日即会话**:同一天同动作续 `set_index`;`set_index` 分配 = 本地当日该动作已有行数(含未同步),服务端 upsert 幂等兜底重复提交。
- `logged_date` = 设备本地日历日(`Calendar.current`,YYYY-MM-DD),随请求上送——跨午夜训练归属"开练那刻的日期"由 VM 在会话开始时锁定。
- 「重复上次」= `fetchLogs(scope: all)` 最近一个有记录的 `logged_date` → 按动作分组映射成草稿行(重量/次数带出,RPE 清空,completed=false)。
- 「常用动作」= 近 90 天 logs 按 exercise 频次 Top N(本地聚合,无新端点)。
- e1RM/PR:commitSet 后走既有 `recordE1RMPoint` 管线(单源纪律以 050 为准,本 spec 不新增第二套算法)。
- 埋点挂点(不实装,留契约名):`workout_log_start{source:adhoc}` / `set_logged` / `workout_log_save`——落地归埋点 wave。

## 错误处理

- 上传失败(网络/5xx)→ 入队重试,UI 乐观展示 + 未同步角标;4xx 校验类(理论不可达)→ 行标错并允许编辑重提。
- `SETS_EXERCISE_NOT_FOUND`(目录漂移)→ toast + 该行退回编辑态。
- 队列冲洗遇 401 → 走既有 token refresh 后重试一次,再失败保留队列(下次 launch 再冲)。

## 测试

- `SoloSessionViewModel`:草稿行构建/set_index 分配(含未同步行)/重复上次映射/跨午夜日期锁定。
- `QueuedTrainingLogRepository`:断网入队→恢复冲洗→幂等重放;磁盘持久 round-trip;401 刷新路径。
- `ExercisePicker` 搜索:中英/别名命中(用 CatalogKit 测试目标)。
- CatalogKit 搬移:CoachKit 既有搜索测试全绿(行为零变化回归)。
- UI 冒烟(XcodeBuildMCP 模拟器):solo 账号 开始训练→选深蹲→记 3 组→结束→摘要出现;Demo 构建记得 `configuration=Demo`。

## 验收

1. solo 新账号(staging)全程:开始训练 → 选动作 → 逐组记录(亮点组件全部在场)→ 结束 → 今日摘要正确;重启 app 数据仍在(后端拉回)。
2. 飞行模式记 5 组 → 退出飞行 → 角标消失,`GET ?scope=all` 可见 5 行。
3. 「重复上次」一键带出上次训练日全部动作组重;「常用动作」按频次置顶。
4. coached 学员(DemoStudent)回归:计划驱动今天页零变化;CoachKit 规划器搜索零变化。
5. 走查 G-1..9 亮点逐条确认未回退。
