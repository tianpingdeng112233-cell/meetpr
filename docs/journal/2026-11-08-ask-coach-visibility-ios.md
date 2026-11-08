# 2026-11-08 · Ask coach visibility · iOS

- 来源：David 11/08 直接批准的 T1 卡，默认 P1。基线 `67c5dde0`，工作树 `MeetPR-wt-askcoach`，分支 `fix/ask-coach-visibility`。不 commit/push。
- 规则：开练前、训练中显示「问教练」；已结算或全部处方组已有结果后隐藏；浅/深一致。保留可编辑、非空计划、绑定教练、分享上下文等既有门控。按钮样式、文案、导航与点击回调不变。

## 实现与测试 seam

- `SetRefEntryVisibility.shouldShow(drafts:...)` 复用 `needsTrainingResult`，只检查处方组；失败组视为已有结果，assumed 仍待实际记录，额外组/自加动作不改变处方完成态。已结算日继续由 `FlexibleTrainingDay.canWrite` 拦截。
- 开练前汇总 hero 接入既有 `TodayWorkoutAskCoachCornerButton`；主项/辅助项 hero 继续消费同一个 `showsAskCoach`。预览同步新规则。
- `TodayWorkoutHero` 从 private 改为模块内部可见，供 ViewInspector 验证真实按钮接线。新增参数转发使既有大类型达到 251 行，仅局部豁免 `type_body_length`，未扩大拆分范围。
- 计算 seam 无主题输入。测试覆盖开练前/训练中/全部记录但未结算/手动结算但有未记录组 × 浅/深，并检查按钮存在性、原回调；另覆盖失败组、额外组、自加动作、assumed。既有无教练/无上下文/只读/无可用组测试保留。

## 先红后绿

证据目录：`scratch/ask-coach-visibility-ios/`。

1. `logs/red-all-recorded.log`：旧门控在全部组完成后仍返回 true，新增断言失败。
2. `logs/green-all-recorded.log`：加入未完成处方组判断后同一测试通过。
3. `logs/red-prestart.log`：旧汇总 hero 在浅/深两种主题均找不到按钮。
4. `logs/green-prestart.log`：接入原组件后两种主题均找到按钮，点击原回调恰好一次。

初次 XcodeBuildMCP SwiftPM 测试因 GitHub 拉取 ViewInspector 超时失败；使用本机相同版本缓存、独立 `/private/tmp/askcoach-spm` 跑上述 red/green。shell 全量测试中 15 个未改动视频编码断言报 `Cannot Encode`，本卡新增测试通过。将依赖缓存放入本工作树后，XcodeBuildMCP 首轮复跑因测试文件在编译中被格式化而中止；停止编辑后重跑，全量 1215 tests 绿，视频编码用例亦通过。未跳过或修改视频测试。

## 验证与审查

- StudentKit `swift test`：1215 passed / 0 failed / 0 skipped；`logs/studentkit-full-green.log`，XcodeBuildMCP，34.2 秒。新增 3 个测试函数（其中状态矩阵 8 个参数化 case）。
- `MeetPR-DemoStudent` / `DemoStudent` app build + 安装 + 启动成功；`logs/app-build.log`，281.5 秒，无 warnings/errors。project 为本工作树 `MeetPR.xcodeproj`，DerivedData 为 `/private/tmp/askcoach-derived`。
- 改动 5 个 Swift 文件 strict SwiftLint、`git diff --check` 通过。
- `review-loop` 独立只读审查一轮：Standards 0 findings；Spec 0 findings。两轴均检查最终逻辑与新增测试；未替代运行验证。
- 仓内缺 `docs/agents/issue-tracker.md`，未使用依赖 tracker 的 `code-review` 分支流程；本次使用支持未提交改动的本地 `review-loop`。后续需正式 tracker 工作流时先运行 `$setup-matt-pocock-skills`，不影响本卡本地审查。
- iPhone 17e / iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`；仅此模拟器安装运行。下表截图均已打开亲看。

## 模拟器截图

全部使用既有 Demo 场景，无新增 fixture 或临时生产代码。主题通过启动参数 `-meetpr.appearance light|dark` 指定，启动后点「训练」。

| 证据（相对 scratch/ask-coach-visibility-ios） | 场景与结果 |
| --- | --- |
| `prestart-light.jpg` | `--spec090-before`，开练前浅色，今日训练 hero 右上显示「问教练」。 |
| `prestart-dark.jpg` | 同场景深色，位置与显示规则一致。 |
| `recording-main-dark.jpg` | `--spec090-main-one`，主项已记录 1/3 组，按钮显示。 |
| `recording-accessory-light.jpg` | `--spec090-upgrade`，主项完成、辅助项已记录 2/3 组，按钮显示。 |
| `all-recorded-light.jpg` | `--spec090-all`，全部 8 组完成但尚未结算，只有完成卡和结算入口，无「问教练」。 |
| `settled-light.jpg` | 上述场景长按完成并回到当日训练详情，已完成汇总卡无「问教练」。 |

开练前实际点击「问教练」正常打开原选组提问 sheet，显示计划组；随后关闭，未发送消息。两种主题的主项训练/全部记录/已结算还由 8-case 渲染矩阵覆盖。

自测证据仅覆盖本卡 iOS 行为；未改 Android、正典发版台账或其他工作树。

完整交付补丁：`scratch/ask-coach-visibility-ios/implementation.diff`。HEAD 保持 `67c5dde0`，未 commit/push。
