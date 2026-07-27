# 057 — 驾驶舱 W1 发现层（iOS：今日看板 + 训练双页 + 推送接入 + 小件）

- **状态**: InProgress
- **来源**: CEO plan signal-loop W1 + David 2026-07-17/18 全部形态拍板（看板不划掉、显式开始训练、被压黄点、SBD 日名、v4 双页设计冻结——mock 为合同）。T2 / P1，随下一个内测班车。
- **依赖**: backend spec 018/019/020 已在 staging；分支叠在 spec/056 上（**合并序：PR #259 → 本 PR**）。
- **设计规则**（design-logo-ratio，全卡强制）：红仅点睛（小点/短划/小字）、禁大面积红填充、主 CTA 白底黑字、琥珀禁用（留意档 = 纯黄 #F5C518 仅 8pt 点）、数据小件灰白亮度分层。

## 1. 教练「今日」看板（CoachDashboardView 改造）

- 结构：日期眉标（灰字+红短划）→「今日」大标题 → **昨日摘要条**（mono 灰白：「昨天 · 3 练完 · 1 缺练 · 1 被压 · 1 破 PR」，零值段省略，数据源 = backend spec 021 的 `GET /coach/daily-digest`；021 未就绪前该条隐藏，feature-gate 于 repository 层）→ 新学员请求卡（现状保留）→ **信号区**「今天 N 个需要你」→ 两列统计卡（现状）。
- 信号区：`GET /coach/signals?status=open`，排序 红 > 黄 > 绿、同档 opened_at 倒序。行 = 8pt 实心点（红 brandRed / 黄 #F5C518 新增 DesignSystem token / 绿 green）+ 学员名 + mono 灰类型标（缺练/被压/PR）+ 留因全文（最多两行）+ chevron。点行 → StudentDetailView。**无任何处理控件**（ack 端点不接）。空态沿用「今天没有需要你处理的学员」。
- 旧 client-side triage 行（todayRows/dotColor/subtitle 一族）退役，由后端信号取代。

## 2. 学员「训练」tab 双页（TodayWorkoutView 改造，v4 冻结稿）

- **开练前 = 独立总览页**（当日有计划且未开练）：日历周条（现状保留，切日=现有只读回看）→ 日期眉标 →「W1D5 · {SBD}日」大标题 → 动作清单卡（计划 sort_order 原序；主项名 14pt 加重白、辅项 13pt 淡灰；每行右侧组×次·强度，副行 上次/最佳 参照，复用现有 last/best 数据源）→ 三格统计（动作 / 总组数 / 上次时长——上次时长取该生最近一次 completed 会话 duration，`GET /students/me/session?date=` 或本地缓存，取不到显示「—」）→ 白色大 CTA「开始训练」钉底。
- **日名规则**：当日主项（is_main_lift）的 competition family 集合 → S/B/D 字母按 S,B,D 固定序拼接（「S 日」「BD 日」「SBD 日」）；无主项 =「辅助日」。与周条角标同一推导函数（抽共享）。
- **点开始** → `POST /students/me/session/start`（201/200 均进入）→ 整页切换现有逐组训练界面。网络失败：本地照常进入训练界面 + 静默重试（打卡本身会隐式开始会话，不阻断训练）。
- **训练中**：头部右侧常驻 mono 计时 chip（红点 ● + mm:ss，源 = session.started_at 本地推秒）；组表上方进度条「已完成 n/m 组 · 下一组：X」；其余交互零改动。练完接现有完成 banner，计时 chip 定格总时长。
- 无计划日/休息日：现状空态不动。

## 3. 学员「今日」tab 状态条

- 原「开始 W1D5 · 深蹲」CTA 区替换为三态状态条（点击均跳训练 tab，**不**触发 start）：未开练「今日 · BD 日 · 9 组 › 开始训练」/ 训练中「● 训练中 · 48:12」（红点+mono，本地推秒）/ 已完成「✓ 今日已完成 · 58 分钟」（绿勾小字）。
- 其余今日页内容零改动。

## 4. 推送接入 + device token

- `MeetPRApp` 加 `UIApplicationDelegateAdaptor`：登录态建立后请求通知授权（每账号只主动弹一次，拒绝后不纠缠），`registerForRemoteNotifications` → token 上报 `POST /devices/token`（`APIClient+Devices.swift` 新增，token 变更/前台激活时重报）。
- **Demo 硬禁用（红线执行点）**：DEMO_MODE 构建下整个注册管线短路——不请求授权、不注册、不上报（backend spec 019 依赖此保证）。
- 收推送点击 → 路由到教练「今日」tab。前台收到仅更新角标/静默，不弹窗。

## 5. 小件

- **备赛倒计时**：花名册行学员名旁 + 学员详情头部，中性描边胶囊「D-{n}」（灰白；无比赛日期不显示）。数据源 = backend spec 021 在 `/coach/students` 补 `competition_date`；021 未就绪前不显示（gate 同 §1）。
- **出勤迷你图**：花名册行尾 4 根竖条（近 4 周 完成/计划：达标亮白、部分中灰、零暗灰、无计划空位），30pt 宽。数据源 = 021 在 `/coach/students` 补 `recent_4w`；未就绪前不显示。

## 6. 测试与验收

- 单元：SBD 日名推导（S/B/D/BD/SBD/辅助/无计划）、状态条三态、计时推秒（fake clock）、信号排序与三档点色、Demo 短路守卫（DEMO_MODE 下零注册调用）。
- 快照/结构：总览页、看板信号区（红黄绿混排）、空态。
- 模拟器亲验（收货闸门）：Demo 双端逐屏对照 v4 mock；真机 sandbox 推送（token 注册→backend 019 卡 4 联测）。
- 设计规则审查：新增 UI 零琥珀、红色仅点睛清单逐屏核对。

## 7. 拆卡

| # | 卡 | 范围 |
|---|---|---|
| 1 | 训练 tab 双页 + session start + 计时 | §2 |
| 2 | 教练今日看板 + 学员今日状态条 | §1 + §3（摘要条 gate 021） |
| 3 | 推送接入 + Demo 守卫 | §4 |
| 4 | 小件两件 | §5（依赖 backend 021） |

（backend spec 021 = digest 读端点 + /coach/students 补 competition_date/recent_4w，另仓另 PR；存量琥珀清退为独立 T1 卡不入本 spec。）

## 变更记录

| 日期 | 版本 | 说明 | 作者 |
|---|---|---|---|
| 2026-07-18 | 0.1 | 初稿（v4 设计冻结稿为合同） | Claude |
