# SPEC 046 — solo 注册/onboarding 收口(wave A2)

- **状态**: Accepted(2026-07-04,与实现同 PR)
- **来源**: 自己练 Free 档 wave 泳道 A2;走查「新 solo 用户从注册到第一组记录」链路缺口。
- **侦察(2026-07-04)**:注册页「学员 · 自己练」卡片已存在(SignupView 三角色遍历);selfTrainStudent 跳 BindGate(spec 031 D4)**但因此连 onboarding wizard 一起跳了**(wizard 长在 BindGate 流内)→ solo 用户零资料零基线。OnboardingProfile 29 字段全可选,partial 提交可行;基线展示 = MyProfileView 直读 profile.squat/bench/deadlift1RMKg + 「入门基线」注解(spec 050,永不入实测序列)——solo 只需写 profile,展示白拿。

## 1. 注册卡文案(拍板 C 红线)

- 「学员 · 自己练」副标题:~~「选择训练模板 · 自主跟练」~~(5 月旧文案,踩「模板」红线)→ **「随手记训练 · 看见成长」**。
- authTag `SELF_TRAIN` / 角色路由不动。

## 2. solo 轻 onboarding(≤2 屏,低摩擦)

- **触发**:selfTrainStudent 登录后 `fetchProfile` 无档或未完成 → `SoloOnboardingFlow`;完成或跳过 → 落「今天」页。probe 习语同 BindGate 的 isOnboardingComplete(fetch 失败视未完成,最坏多走一次恢复,无害)。
- **屏 1 · 单位与体重**:unitPreference(kg/lb,默认 kg 一键过)+ weightKg(可选)。
- **屏 2 · 三大项入门基线**(整屏可跳过,逐项可空):squat/bench/deadlift 1RM;辅文「不确定?先跳过,练几次成长页自然有走势」。
- **跳过语义**:跳过也写 `completedAt`(否则每次启动再弹)。跳过 = 提交 unitPreference 默认值 + completedAt。
- **组件复用**:spec 032 向导骨架(step chrome / Step3StrengthSection 的 1RM 输入行 + OneRMEstimatorSheet 估算器 / OnboardingNumberField / 单位选择控件);**不走绑定/评估分支**,不含 noteToCoach 等 coach 向字段。Step3 的警示句「⚠️ 1RM 一旦填写,完成后只有教练能改」是 coached 专属——solo 变体不显示(参数化 `lockWarning: String?`,solo 传 nil;backend 013 豁免后 solo 本就可改)。
- **后补入口**:我的页 1RM 区块空态 →「补记入门基线」按钮 → 屏 2 同款表单(设计文档写「成长页可补」,实施落我的页——1RM 区块住此,成长页只放走势;SPEC 记偏差理由)。
- 全流程文案**零「教练/计划/模板」字样**(拍板 C)。

## 3. backend 核实结论 → spec 013(2026-07-04 源码核实,已实装 PR #42)

- `POST /auth/register`:`USER_ROLES` 含 `self_train_student`(src/db/types.ts:3)→ 直接接受,零改动。
- onboarding 学员端点:`requireRole('coached_student','self_train_student')` 本就放行 solo。
- **两堵 coached 语义的墙,均落 backend spec `013-solo-onboarding-exemptions`(role 豁免,coached 零变化)**:
  1. **1RM 完成后锁**:completed 后 PUT 1RM → 403 ONE_RM_LOCKED,唯一合法写者是教练端点——solo 没有教练,跳过基线后永远无法补记 → solo 豁免。
  2. **完成必填集 18 字段**(coached 7 步全向导)——solo 两屏永远填不满 → 永不 completed → 每启动重弹 → solo 必填集 = `['unit_preference']`。
- 测试:solo 空档 complete 422 missing=[unit_preference] → 单位即 complete → 完成后补 1RM 200;coached 既有锁/18 字段测试零变化。
- 遗留:staging 端到端实测放进验收 3,不阻塞实施(#42 需先于本 spec 部署)。

## 4. 无资料兜底(收口另一半)

- DashboardProfileMetrics 已 `loaded(OnboardingProfile?)` 可空,不动。
- MyProfileView 1RM 区块 profile 空 → 「补记入门基线」空态入口(§2 后补入口同件事)。

## 非目标

改 coached 7 步向导;solo 训练偏好收集(疲劳自评等,F-030 ⑤);忘记密码(SMS,post-incorporation);模板/计划任何形态。

## 测试

- Flow VM:完成路径字段齐 + completedAt;跳过路径仅单位 + completedAt;partial(只填 squat)保存不炸。
- Gate:profile nil → flow;completed → 直落今天页;fetch 失败 → flow(恢复语义)。
- 文案断言:solo 流字符串无「教练/计划/模板」。

## 验收

1. 新注册 solo 账号 ≤2 屏落今天页;跳过后重启不再弹。
2. 填了基线 → 我的页 1RM 区块 + 「入门基线」注解立现;跳过 → 空态入口可后补。
3. staging 实测注册 self_train_student 全链。
