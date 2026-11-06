# 103 — iOS 聊天时间分隔与视频首图

日期：2026-11-06。分支 `feat/103-chat-time-poster`，基线 `e106803b`（发版线基底 `7bef3a2e`）。按 David 直接派卡执行；不 commit、不 push。唯一需求与验收来源：`specs/103-chat-timestamps-video-poster/SPEC.md`，未修改 SPEC 或正典发布台账。

## 实装

- ChatUI 共享 `ChatRelativeTime.separators`：第一条与相邻间隔 ≥300 秒插入时间；每次从完整可见时间线重算，支持补入历史。按设备日历/时区输出今天、昨天、7 天内、今年、往年，时钟遵循 locale 的系统 12/24 小时偏好。昨天新增简中/英文文案，繁体通过原有生成器生成。
- 两端使用同一时间行组件，保留既有字体、颜色与间距；学员时间线继续合并消息、计划与教练反馈。
- pending 在发送时记录本机时间，重试保留；按 clientID 保留本次会话的展示位置和分组时间。服务端确认后文案采用服务端时间，布局 ID 与分组不跳。退出账号时清理本机时间映射。
- ChatMessage / ChatMessageDTO、CoachFeedbackVideo / FeedbackVideoDTO 补可选 `posterURL`、`durationSeconds` 与 snake-case codec 映射；旧字段缺失与 null 兼容。
- 150pt 教练反馈封面与组分享卡使用相同首图加载器，等比裁切，保留原封面尺寸。缓存按完整签名 URL 隔离、内存限额 24MB / 64 项；空值、请求失败、403 和解码失败保留原背景，无错误 UI。
- 有时长显示 m:ss；缺失时不渲染角标。播放钮与角标有暗色底。

## 先红后绿记录

原始测试日志将保存在 `scratch/spec103/logs/`。开发时依次验证：

1. 时间分组：缺少 `separators` 编译红 → 第一条 / 299 秒 / 300 秒 / 历史边界重算绿。
2. 五档文案：只有小时分钟导致 9 项断言失败 → 简中/英文日期格式与昨天文案绿。英文使用系统的 narrow no-break space 分隔 AM/PM，测试保留该系统行为。
3. pending：缺少 `createdAt` 编译红 → 本机发送时间、失败与重试保留绿。
4. 封面 presentation：缺少类型编译红 → poster 有/无 × duration 有/无四种组合绿。
5. DTO → domain → presentation：缺少 poster/cover 编译红 → 新字段 / null / 旧响应 / 缓存 round-trip 绿。
6. 独立 Spec 审查指出确认跨组风险：4:59 本机发送、5:01 服务端确认，中间有新消息的测试先红 → 稳定 ID、位置、分组且采用服务端文案时间绿。

## 验证与截图

### 自动验证

- ChatUI：92 passed，0 failed。最终日志 `scratch/spec103/logs/swift_package_test_2026-11-06T03-57-29-847Z_pid54050_7c013ad5.log`。
- StudentKit：1181 passed，0 failed。最终日志 `scratch/spec103/logs/swift_package_test_2026-11-06T03-57-12-933Z_pid54050_0a2ddee5.log`。
- CoreModels：164 passed，0 failed。日志 `scratch/spec103/logs/swift_package_test_2026-11-06T03-43-11-983Z_pid54050_76de380e.log`。
- Networking：151 passed，0 failed。日志 `scratch/spec103/logs/swift_package_test_2026-11-06T03-42-56-825Z_pid54050_90e919a9.log`。
- 合计 1588 项通过；ChatUI 最终补测覆盖本地午夜和恰好 7 天的边界。StudentKit 初次完整重编译有既存并发/未用返回值警告，最后增量运行无新增警告。
- 24 个改动 Swift 文件 `swiftlint lint --strict --quiet` 通过；`git diff --check` 通过。
- `scripts/generate-zh-hant.py --check --keys chat.timestamp.yesterday` 通过（10 catalogs / 1 key）；应用代码检索 `—:—` 为零。
- 最终生产代码 `MeetPR-DemoStudent` / `DemoStudent` app build + install + launch 成功（91.4 秒，0 warnings/errors）；日志 `scratch/spec103/logs/build_run_sim_2026-11-06T03-57-39-162Z_pid54050_3e8268ca.log`。教练 Demo 截图构建已通过：`scratch/spec103/logs/build_run_sim_2026-11-06T03-50-43-186Z_pid54050_923d58be.log`。

### iPhone 17e 视觉证据

所有截图来自既有 `iPhone 17e`（iOS 26.5，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`），未使用或新建其它模拟器。

| 路径（仓根相对） | 观察 |
|---|---|
| `scratch/spec103/student-five-buckets-zh.jpg` | 学员端简中五档时间；第一条有时间，100 秒连续回复不加分隔，5 分钟边界有分隔 |
| `scratch/spec103/coach-five-buckets-poster-en.jpg` | 教练端英文五档、12 小时制、组视频首图和 1:05 |
| `scratch/spec103/student-time-poster-light.jpg` | 浅色组视频与 150pt 教练反馈首图 |
| `scratch/spec103/student-poster-fallback-light.jpg` | 浅色原背景回落，空时长无角标 |
| `scratch/spec103/student-five-buckets-en-dark-accessibility3.jpg` | 英文深色 Accessibility 3 时间行未截断 |
| `scratch/spec103/student-poster-en-dark-accessibility3.jpg` | 深色大字首图，播放钮清楚；44pt 缩略图时长经局部缩放后完整显示 1:05 |
| `scratch/spec103/student-fallback-en-dark-accessibility3.jpg` | 深色大字无首图/时长回落，播放钮保留 |
| `scratch/spec103/final-app-existing-demo-chat.jpg` | 移除临时 fixture 后重新构建的原 Demo 学员聊天：既有消息、计划卡、反馈卡显示正常 |

前七张是**本机 fixture**，首图使用公开图片 URL，不代表 staging 视频已产出首图；最后一张使用仓内原有 Demo 数据。临时 fixture 与两处接线在截图后全部移出 Modules，留档于 `scratch/spec103/fixture-harness/`（源文件和注入 patch）；最终测试与 app 构建针对移除 fixture 的生产代码。字体放大限定聊天页，避免既存 dashboard 大字体导航可达性问题影响本卡截图。

### 按原 SPEC 清单记录自测覆盖

1. 两端五档/首条/5 分钟：纯函数测试与双端截图覆盖。
2. 补历史边界：纯函数测试及现有 timeline 测试覆盖；本轮未用真实服务分页录像验证。
3. pending/确认：实际 coordinator 发送、失败重试与跨 5 分钟确认路径测试覆盖；稳定 ID、顺序、分组均保持，确认文案采用服务端时间。
4. staging 老视频：外部阻塞，见下节；fixture 只验证两种封面的渲染接线。
5. 空 poster 回落有截图；断网/403 走统一失败回落路径，真实网络故障与旧视频播放的联验尚未完成。
6. 有/无时长 × 有/无首图 presentation、DTO 兼容测试及截图覆盖；无占位符。
7. 深浅色、放大字体有截图；视觉发现的时长截断已修复并复验。
8. 旧 DTO 缺字段/null/codec round-trip 已测；真实老账号升级第一屏尚未联验。

以上为开发自测与原始证据，功能验收仍由 Opus 按原清单收货。

## 独立审查

使用本地 `review-loop`，以 HEAD 对未提交修改及新增文件分别进行 Standards / Spec 两路只读审查。仓内缺 `docs/agents/issue-tracker.md`，未运行依赖 tracker 的 Matt 流程，已提示 `$setup-matt-pocock-skills`；未私建配置。

- Standards 初审无 blocker；建议补 retry 时间保持断言，已补。
- Spec 初审发现 pending 确认跨组问题，已定向修复并补先红后绿回归。第二轮 Standards / Spec 均为 `VERDICT: CLEAN`；审查范围排除临时截图 fixture，并核查生产版 Student view。

## 未完成的外部验收

后端 `MeetPR-backend-wt-060/docs/journal/2026-11-06-060-video-poster-A.md` 现场记录：OSS 配置缺失，spike 请求未发起，业务代码尚未实装、未部署。因此 spec 验收④的 staging 老视频（包括 MonsterXTY）真实 poster 与播放、以及验收⑧的真实老账号升级第一屏不能在本轮声称通过。客户端先提供可选字段兼容与本机 fixture 渲染证据；后端恢复并部署后仍需按原清单联验。未访问凭证、未写入 staging 数据、未扩大后端任务范围。

## 交付边界

代码 diff（含新增文件）：`scratch/spec103/implementation.diff`。保持全部改动未提交；未 commit、未 push，未改 SPEC、导航/tab、依赖、pbxproj、build 号或发布台账。
