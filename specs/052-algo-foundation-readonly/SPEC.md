# 052 — 算法计划引擎数据地基(iOS 只读展示层)

- **状态**: Accepted(2026-07-05,与实现同 PR)
- **PR**:
- **来源**: 算法计划引擎蓝图 W0 wave(只读标签展示层)。Brain wiki: [[W0-spec-draft]]。

## 背景

算法计划引擎需要在学员计划卡与 plan-web 教练端展示三个只读标签:训练块类型(block_type)、中周期相位(mesocycle_phase)、训练最大值(training_max)。现状 CoreModels 的 plan 模型无这些字段,backend 将新增对应 snake_case 列。本 wave 在 iOS 侧加 camelCase 镜像字段 + 三标签 UI,plan-web 同步只读展示。

老计划与 Free 档无这些字段(API 响应 NULL),标签整块隐藏,视觉零变化。

## 改动

### §1 模型层

CoreModels 的 `plan` 模型加 4 个 Optional 镜像字段(backend snake_case → Swift camelCase):

| Swift 字段 | 类型 | nullable | 语义 |
|---|---|---|---|
| `blockType` | String? | 是 | 训练块类型,枚举值 {hypertrophy, strength, peaking, active_rest} |
| `mesocyclePhase` | String? | 是 | 中周期相位,枚举值 {accumulation, intensification, realization, deload} |
| `trainingMax` | Decimal? | 是 | 训练最大值(TM = 0.9×近期 1RM 向上取 2.5kg,6 周时效),单位 kg |
| `tmSetAt` | Date? | 是 | TM 设定时间戳,用于判定 6 周时效 |

Repository 解码时 Codable 自动映射这 4 个字段;未知键忽略(老版本 App 对新 API 响应兼容)。

**其余新字段**(plan_sets / set_logs / exercises 的镜像字段)见 Brain wiki [[04-data-model-increments]] §3.3-§3.5,全 Optional,本 wave 只加解码不加 UI(C-2 支线消费)。

### §2 UI

**学员端计划卡**(计划详情头部)加三个只读标签,字段为 NULL 时整块隐藏:

1. **block_type 标签**:中文文案映射 {hypertrophy → 增肌块, strength → 力量块, peaking → 巅峰块, active_rest → 恢复块}
2. **mesocycle_phase 标签**:中文文案 {accumulation → 积累, intensification → 强化, realization → 实现, deload → 减载}
3. **training_max 标签**:显示「训练最大值 ≈ 0.9×1RM」+ 数值(kg);若 `tmSetAt` 距今超 6 周,灰显 + 附加「需复测」提示

**plan-web 教练端**:同三标签只读展示;Step 1 设 1RM 界面旁显示服务端返回的 TM(灰字,不可编辑)。

### §3 不碰的链路

- solo 随手记(spec 045)
- 任何编辑入口
- onboarding 问卷

## 非目标

- backend schema 细节(见 backend spec 014)
- 引擎逻辑:计划生成 / 四回路调整(W1+)
- plan_sets / set_logs / exercises 新字段的 UI 消费(C-2 支线)
- 教练端消费引擎(CHARTER 不进)

## 测试

- 三标签渲染:有值时正确显示中文文案、NULL 时整块隐藏、TM 超 6 周时灰显「需复测」
- Free 账号全链路一致:solo 随手记 → 历史 → 成长曲线,行为与 W0 前逐屏一致
- 老版本 App 对新 API 响应解码无害:Codable 未知键忽略,CI 回归显式覆盖
