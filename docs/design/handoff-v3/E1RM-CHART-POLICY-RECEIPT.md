# E1RM Chart Policy Receipt

> 2026-07-28 · 定向返修第 2 轮最终版
> Branch: `feat/black-gold-ui-v3`
> Delivery mode: working-tree only; no commit, no push

## 结果

成长页深蹲、卧推、硬拉三张 E1RM 卡现在统一消费同一个数据点身份与纯策略。

### 数据点身份正典（定向返修第 1 轮）

**一个数据点 = 一个有 eligible e1RM 估算的不同训练日。**

- 同一训练日有多条 eligible 估算时，只保留当日最高 e1RM。
- 同值发生在不同训练日时，仍是不同数据点。
- `.low` 低置信估算计入训练日点身份；若它是当日最佳，值仍按既有规则只进入弱化散点，不进入可信主线或 headline。
- 同日最高值相同时优先 `.normal`，避免等值低置信记录把可信日点降成散点。
- 唯一聚合纯函数：
  `E1RMSeries.dailyBestEligible(points:family:calendar:)`。
- 解锁总数、成形态 `N/3`、窗口点数都从该函数产出的同一份
  `dailyBestEligible` 数组派生，不再分别使用 raw record 数、破纪录点或合成 continuation sample。

| 当前窗口内每日点 | 动作族每日点总数 | 窗口可信主线 | 输出 | 渲染 |
|---:|---:|---|---|---|
| 任意 | 0 | 任意 | `zero` | scene 03「第一个数据点·等你练出来」 |
| 任意 | 1–2 | 任意 | `formingProgress` | scene 02 成形态；真实显示「已记录 N/3」 |
| 任意 | ≥3 | 每日点 < 3 | `formingWindowSparse` | scene 02 幽灵曲线；不显示 N/3 进度点 |
| 任意 | ≥3 | 每日点 ≥3、`range == 0` | `formingWindowSparse` | David「没趋势不画」：可信主线全平时继续成形 |
| 任意 | ≥3 | 每日点 ≥3、`range > 0` | `chart` | 正式曲线 |

- 纯策略：
  `GrowthE1RMCardPolicy.state(windowDataPointCount:familyTotalDataPointCount:windowMainLinePointCount:windowMainLineValueRangeKg:)`
- 状态输出：`chart / formingProgress / formingWindowSparse / zero`
- 图表 series 绘制窗口内可信的「每日最佳估算」；不再只画严格破纪录点，也不添加窗口边界 carry 或延长到今天的 continuation sample。
- `.chart` 门禁只看实际绘制的窗口可信主线：可信主线每日点至少 3 个且值域大于 0。
- 低置信每日点继续计入解锁数、窗口数与 `N/3`，但绝不计入可信主线点数或主线值域，不能单独或借高值撑起 `.chart`。
- 低置信点沿用 spec 050/053 的弱化菱形散点样式，只在已经通过可信主线门禁的 `.chart` 上叠加。
- headline 数值独立继续消费 spec 050 可信 rolling-window max；series 改口径不改变 headline canon。
- 输入防御：窗口数会收敛到 `0...familyTotalDataPointCount`，可信主线点数再收敛到 `0...windowDataPointCount`；不一致输入不会绕过任一门槛。
- 时间窗只保留 `30天 / 90天 / 历史总览`；三张卡没有动作族特判。

## 稀疏窗口文案（待 David 复核）

当前暂定口径：

> 近 {窗口} 数据不足 · 切到更长时间范围查看

单点修改位置：

`GrowthE1RMCardCopy.windowSparseMessageTemplate`

实现仅在一个模板常量里保存产品文案，再用窗口名替换 `{window}`。本次按 David 指令落地，但仍标记为待 David 复核。

## Headline、金点与日期轴

- 起点、中点、终点标签统一由每日最佳 series 的同一时间域生成，天然单调递增。
- 右端标签现在一定是时间域终点，不再拿最新 record 的日期冒充轴终点。
- headline 文本继续来自全历史构建的可信 rolling-max 最新赢家，不受当前图表窗口裁剪影响。
- 图上金点、垂直引导线与当前日期标签只绑定「窗口内可信主线最后一点」；不再复用 headline 赢家。
- 窗外 rolling-max 候选不会被夹到 X 轴边界、越过 Y 轴域，也不会生成窗外日期标签。
- demo 实测：深蹲轴 `5/11 → 5/23 → 6/4`，卧推/硬拉轴
  `5/11 → 5/20 → 5/29`；没有合成的今天端点。

## 测试

新增或修订覆盖：

- 纯策略全矩阵：窗口 `0/1/2/3` × 总点数 `0/1/2/3+`
- 同一训练日多条记录收敛为当日最高估算
- 同值发生在三个不同训练日时计为三个点
- `150 / 150 / 150`：总数 3、窗口 3、值域 0，不画图
- `150 / 145 / 155`：总数 3、窗口 3、有波动，绘制每日最佳曲线
- `normal 150 / low 190 / normal 150`：计数解锁，但可信主线仅 2 点且全平，不画图
- 三个不同值的纯低置信训练日：计数解锁，但可信主线为空，不画图
- 低置信训练日计入点数，但仍只在 `.chart` 的弱化散点层渲染，不影响可信 headline
- 窗内 `150 / 145 / 155` 加窗外 100 天前 `200`：headline 口径不变；金点为窗内 `155`，标签取该点日期，日期轴域不含窗外日期
- 动作族计数隔离
- 深蹲 / 卧推 / 硬拉 × 30 / 90 / 全部的窗口状态迁移
- 日期轴起 / 中 / 止单调性与当前点日期一致性
- demo 种子中，任何进入 `chart` 的窗口都有非零值域

验证结果：

| Gate | Result |
|---|---|
| StudentKit | 566 passed |
| 全量 SPM（9 packages） | 1365 passed, 0 failed |
| DemoStudent simulator build (`DemoStudent`) | 0 warning, 0 error |
| swift-format strict | passed |
| SwiftLint strict | passed |

最终 StudentKit 测试与正确 `DemoStudent` configuration 的 iOS 构建诊断均为 0 warning。

## 双主题模拟器目检

设备：iPhone 17 simulator，iOS 26.5。

| Theme | 30 天 | 90 天 | 历史总览 |
|---|---|---|---|
| Dark | 三卡幽灵稀疏态；无 N/3；无平线 | 三卡每日最佳曲线 | 三卡每日最佳曲线 |
| Light | 三卡幽灵稀疏态；无 N/3；无平线 | 三卡每日最佳曲线 | 三卡每日最佳曲线 |

浅色和暗色下，幽灵线、坐标轴、正文、卡面均可辨识；切窗后没有动作族分裂。

## Scope / 红线

- 改动仅限 StudentKit 成长页 presentation、卡片、空态复用、对应测试和本回执。
- `CoachKit / ChatUI / auth / Bind / Evaluation`：零 diff。
- 未修改 build number、tag、archive、pbxproj、签名、依赖或模块结构。
- 未 commit，未 push。


## 定向返修第 3 轮(Claude 接管)

- 窗外赢家回归测试重构:末样本改 -80 天使 -100 天的 200 真实进入其 28 天滚动窗成为 headline 赢家,断言 headline 200/金点 155/轴域排除 -100 天(原场景 200 永远赢不了,测试对旧实现也通过)。
