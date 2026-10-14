# Spec 092 · iOS 卡 A(学员端):本周内换天练、额外组、自加动作、点 ✓ 震动

开工先读仓内 `CONTEXT.md`(「游标日」「额外组」「自加动作」「辅助项」词条)、`AGENTS.md`、`specs/085-090-android-parity/README.md`(共同约定,全部适用)、本目录 `SPEC.md` 全文(含文末「屏幕稿」与文案表),再读 `specs/089-accessory-quick-log/SPEC.md` 与 `CARD-ios.md`(iOS 行内表格的既有做法)。

- 级别 / 节奏:T2 / P1。工作树 `/Users/david/Projects/apps/MeetPR-wt-092a`,分支 `feat/092-ios-student`(基于 `origin/release/1.0`)。**先 `cd` 进这棵树再启动**,启动后试写并删除一个临时文件确认可写;不可写立刻带原始报错返回。
- **不 commit、不 push、不开 PR**;交付 = 工作区改动 + `docs/CODEX-JOURNAL.md` 末尾一节。`SPEC.md`、`CONTEXT.md`、`NEXT-RELEASE.md` 不要动。
- 模拟器只用 **iPhone 17e `BBE9EB95-01DE-452E-866C-3DD0B62F9BDA`**(卡 B 同时在用别的机器,不要碰其他模拟器);交付前 `xcrun simctl shutdown` 这台。
- 本卡只动学员端:`Modules/StudentKit`、`Modules/Networking`(只做加法)、`Modules/CoreModels`(只做加法)、学员 Demo 与它们的测试。`Modules/CoachKit` 归卡 B(另一棵树同时在改),不要碰。

## 安卓实现是参照物(只读)

安卓学员端已实装、本机全量通过,行为口径以它为参照(冲突时以 `SPEC.md` 为准):

```
git -C ../meetpr-rn-wt-092 show 02213e4:<路径>
git -C ../meetpr-rn-wt-092 show 02213e4 --stat
```

重点文件:`src/domain/plan/sequence.ts`(可写判定、默认选中、撤销取最新)、`src/features/training/drafts.ts` / `model.ts` / `accessory-quick-log.ts`(额外组与自加动作的行模型)、`exercise-picker.ts` / `StudentExercisePicker.tsx`(标签归类与选择页)、`TodayWorkoutView.tsx`(写入、删除、`logged_date` 钉住)、`src/features/history/`(历史 / 进步)。安卓 JOURNAL 里「Spec 092 Card A」一节记了实现时踩过的边界(`git -C ../meetpr-rn-wt-092 show 02213e4:docs/CODEX-JOURNAL.md`)。

## 目标

实现 `SPEC.md` 的 §1、§2、§3、§3b、§4 与「存量数据与升级」,界面按屏幕稿第 1–4 张。安卓收货时定下、iOS 一并照做的口径:

1. **换天练**:游标日所在计划周内任何未结算日可写;其他周只读、已结算只读(现状)。默认选中游标日;当天(gym-day)已在别的未结算日有真实记录时回到那一天(取最后记录的)。周历外观与交互不改,只把训练日卡上「完成 X 后解锁」换成「开始训练」主按钮。**撤销取实际结算时间(`completed_at`)最新的一条**,不再按计划顺序取最后一天;窗口规则不变。
2. **额外组**:coached 形态写入,组序号接在处方组之后;不计入进度 / 组进度条 / 「还差几组」/「全部按计划完成」;不顶替没做的处方组。主项走现有完整录入页(RPE 选填,纯 RPE 处方时重量不预填);辅助项在行内表格。可删除;上限每动作 10。
3. **自加动作**:adhoc 形态 + `plan_day_id`;同一张卡所有组钉住第一组写入时的 `logged_date`(网络错误时保留该日期以便幂等重试;删掉最后一行 / 整卡后清除)。选择页三行标签一屏全见(按 `SPEC.md` §3「筛选标签」的归类与并入规则,用 `CoreModels` 的 `Exercise.mainLiftFamily` 与 `muscleGroups`);搜索中英文名(动作库 DTO 没有别名字段就不做别名)。上限每日 10 个、每个 10 组。整卡移除 = 逐条删除,遇错停止,已删的不回滚。
4. **点 ✓ 震动**:行内表格里把一组记为完成的那次按下,给一次轻触感(iOS 用现有的触感做法,`DesignSystem` 里已有按钮触感的就沿用同一机制,强度取 light);取消、置灰、写入中的重复点击不震;「全部按计划完成」**保留它原有的按钮反馈**,只是不额外加这一下。
5. **历史 / 进步**:训练历史显示自加动作(「自加」标记)与额外组(「额外」标记);进步页 e1RM / PR 包含自加动作里属于三大项家族的记录。只在需要的读取处显式要 `scope=all`,不改其他调用方的默认。
6. **补记**(spec 081 的 Quick log):已有的额外组只读显示、不参与勾选。

## 后端契约(spec 050,PR 已开、尚未部署;按契约写,用假仓库验证)

- 额外组 = 现有 `POST /sets/log` coached 形态,`set_index` ≥ 处方组数。
- 自加动作 = 现有 adhoc 形态加可选 `plan_day_id`。错误:400 `SETS_PLAN_DAY_NOT_PUBLISHED`;409 `SETS_ADHOC_DAY_CONFLICT`。
- 删除 `DELETE /sets/:id` → 204;409 `SET_NOT_STUDENT_ADDED` / `SET_HAS_ATTACHMENT` / `SET_HAS_COACH_FEEDBACK`;404 `SET_NOT_FOUND` 当作已删。
- 读取 `scope=all` 才带回自加动作行;每行多 `plan_day_id`(老后端没有 → 解码为 nil,用 `decodeIfPresent`,不得让整体解码失败)。
- `Networking` 的错误码映射若有白名单 / 枚举,把上面六个新码加进去,让真实的 400 / 404 / 409 带着 code 到达界面的提示分支(安卓就是漏了这一处,收货时补的)。

## iOS 落点(以现场为准)

- 训练页:`Modules/StudentKit/Sources/StudentKit/Features/TodayWorkout/`(`TodayWorkoutScreen` / `TodayWorkoutView` / `TodayWorkoutViewModel` 及 `+DraftBuilding` / `TodayWorkoutPresentation` / `TodayWorkoutTypes`、089 的行内表格)、完整录入页 `SetEntry*`。可写判定与游标规则若在 `CoreModels`(如 `StudentPlanView`)就改在那里并补测试。
- 选择页:StudentKit 下新建,`sheet` 呈现;键盘与 Dynamic Type 按共同约定。
- 历史:`Features/TrainingHistory/`(`AllHistoryScreen` / `HistoryEntriesView` 等);进步页 e1RM 的读取处。
- 网络:`Modules/Networking/Sources/Networking/APIClient+Sets.swift`、`DTO/SetLogDTOs.swift` 与错误映射。
- Demo:`StudentDemoSeed` 与 Demo 仓库要能演示本卡全部行为(本周有一个已结算的靠后训练日、一个有额外组的动作、一个自加动作;Demo 仓库支持新写入与删除),**验收靠它在模拟器上走**。

## 约束

- 不丢用户数据、不让已上线功能失效;不改本地存储键与结构;既有测试断言不删不改(确需改的逐条在 JOURNAL 写原因;本卡自己新增的测试可直接改)。
- 不加依赖;守模块边界脚本;新 model `Sendable`;View 不直接调网络;`swift-format lint --strict` 与 `swiftlint` 严格模式 0 违规。
- 文案:英文与中文都取安卓目录 `02213e4:src/i18n/catalog/RnExtras.json` 里的同名键值,逐字;iOS 已有同义键的沿用。进 `Localizable.xcstrings`。
- 目录范围、文件归属、工程实现方式这类问题自己定并在 JOURNAL 记一句,不要为此停下;只有确属产品取舍才停。

## 测试 seam(先红后绿,只在这些边界)

1. 可写判定 / 默认选中 / 撤销取最新(纯函数,`CoreModels` 或 StudentKit 现有位置)。
2. 行模型(纯函数):处方组 + 已有额外组 + 新加额外组合并、进度只数处方组、额外组预填、自加动作行、`logged_date` 钉住、两个上限、「全部按计划完成」不含额外组。
3. 标签归类(纯函数):三个族、每个肌群标签、四条并入规则、多肌群动作、无肌群信息的动作。
4. 写入 / 删除(`TodayWorkoutViewModel` 现有测试方式,假仓库):额外组请求、自加动作请求带 `plan_day_id`、删除、六个错误码各自的提示、震动只在完成时触发一次。
5. `Networking`:DTO 缺 `plan_day_id` 仍解码;错误码映射;`scope=all` 进请求。
6. 历史 / 进步:显示标记、e1RM 包含自加的三大项记录。

## 验收

`SPEC.md`「验收清单」学员端第 1–11 项与 9b,替换如下:

- 屏幕与字号按共同约定换成 iPhone 17e(本卡指定机)+ `accessibility-large`;深色抽一屏。
- 第 9b 项:模拟器验触感调用(真机体感另验)。
- 第 10 项「老用户升级第一屏」:用 Demo 的「训练到一半」形态与从未有过学员自加记录的形态各看一次。
- 第 11 项断网:用假仓库注入失败验证保留输入与重试。
- 工程闸:`swift test --package-path Modules/StudentKit`、`Modules/Networking`、`Modules/CoreModels` 及其他动到的包全量通过;`swift-format` 与 `swiftlint` 严格模式 0 违规;`MeetPR-DemoStudent` 能在指定模拟器构建运行,并在 JOURNAL 附屏幕截图路径(放 `specs/092-flexible-day-self-added/evidence/`)。
