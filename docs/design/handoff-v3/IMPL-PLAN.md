# 学员端黑金 UI v3 实装蓝图(2026-07-26)

**背景**:handoff-v2 实装(PR #278,已关闭)效果不达标。本轮以 `handoff-v3` 为唯一标准从
`release/1.0` 现头(0c335ea)重做,分支 `feat/black-gold-ui-v3`。P1,随下一个内测包。

## 正典(优先级从高到低)

1. `MeetPR 学员端.dc.html` — 唯一标准。全部 DOM 结构、inline style、动效 JS(tween/morphLaunch/
   rollUp/riseIn/toggleFb/doneRef)逐字取值,**禁止蒸馏成文字卡再实装**(#278 首轮失真主因)。
2. `README.md`(同目录) — 实装规格。与样机冲突时以 README 为准。
3. 7 个组件 `*.dc.html` — props 契约在文件末尾 `data-props` JSON;对照 `MeetPR 组件库.dc.html` 逐状态核对。
4. `tokens.css` + `motion.css` — token/曲线唯一来源。注意:样机 helmet 另有 `--card-shadow`
   `--cta-mold(-held)` `--headline-emboss`(tokens.css 未含,以样机 helmet 为准补齐)。
5. `motion/01–05.html` — 动效可运行参考,参数与样机源码一致(已核对)。

## CSS → SwiftUI 翻译政策

- **Token**:`DesignSystem/Tokens` 双主题(dark = 默认,light = `.theme-light` 等价物),值逐字;
  组件永不接 theme 参数,只读 environment。半透明底用 gold/danger/success 的 rgb 分量 + opacity。
- **字体**:Archivo-VF / IBM Plex Mono / IBMPlexSans-VF 已在 #278 打包(搬运);中文回落系统
  PingFang(≈Noto Sans SC 用途)。**所有数字/代号(W1D4、175、8.5)一律 IBM Plex Mono**。
- **曲线**:`.timingCurve(0.22,0.61,0.36,1)` 常规 / `(0.34,1.36,0.64,1)` 弹性 / `(0.4,0,0.2,1)` 卷折
  620ms / `(0.2,0.7,0.2,1)` 屏切 280ms / `(0.2,0.8,0.2,1)` Sheet 340ms;JS 补间 easeOutCubic
  → SwiftUI 等价 timingCurve;数字滚动 quart。全部动效响应 `accessibilityReduceMotion`。
- **圆角只有** 4/10/12/16/20/999;字号无半像素;间距 4 的倍数;触摸目标 ≥44pt。

## 卡片序列(一卡 = 一个可 review 的原子 diff)

| 卡 | 内容 | 依赖 |
|---|---|---|
| W0 地基 | 从 `origin/feat/black-gold-ui-r10` 搬 DesignSystem 模块骨架 + 字体资源/注册,token 值全量对齐 v3(样机 helmet 为准),app 编译绿、不动屏幕 | — |
| W1 组件 | DayChip/Badge/SetRow/StatTile/GoldCTA/ExerciseCard/NumberPad + PlateVisual(纯函数 `plateBreakdown(totalKg,hasCollar)` + 展示件),逐状态 Preview 对照组件库 | W0 |
| W2a 今日 | Header/周进度条/教练反馈卡(收起+展开)/周日历/体重·距比赛/E1RM 横滑卡/CTA/顺延态 | W1 |
| W2b 训练 | 两态 hero(清单→记录)、周/月历(sticky 收起条)、动作卡列表、剩余提示、长按完成 | W1 |
| W2c 成长+我的 | E1RM 三卡(range 切换)/E1RM vs 1RM/反馈记录/全部历史/容量·强度图;我的全部分组 | W1 |
| W3 记录链路 | SetEntry 全屏(配片图/±步进/RPE 刻度/视频行)+ NumberPad sheet + 完成/失败写入与自动跳组 | W1 |
| W4 收官 overlay | 结算庆祝(sparks/stamp/ticker/错峰)+ 训练回顾 + 顺延弹窗 + 反馈档案 | W2/W3 |
| W5 动效精修 | morph 转场(01)、反馈展开(02)、卷折收纳(03)、错峰进场(04)、庆祝(05)逐参对齐 + reduced-motion 全覆盖 | 全部 |

聊天 overlay:样机的聊天/通知合流沿用 07-26 拍板;ChatUI(spec 058 W1)已随 1.0(14) 在
发版线上。本波**不动聊天内部 UI**(范围控制),顶栏气泡接现有入口,聊天黑金皮肤单独成卡后补。

## 收货闸门(每卡强制)

1. `swiftlint --strict` + build + 全量测试绿(SPM 测试跑 macOS host,`#if os(iOS)` 测试不执行,勿以此当证据)。
2. **像素基准**:样机 `双主题.dc.html` 开浏览器(390×844 视口)截图 vs 模拟器同屏截图,
   暗、亮两主题逐屏并排对比,偏差进当卡纠偏,收敛到零才算完成。基准图存 `~/Projects/scratch/ui-v3-baseline/`。
3. README §9 检查清单逐项过(零硬编码颜色/圆角档位/Mono 数字/44pt/reduced-motion/断网记录)。

## 待拍板(会末呈上,不阻塞 W0–W1)

- 样机训练页含周/月历(取代 07-25「训练页日历删除」裁决)——默认按样机做。
- README §5 的 API 契约(`GET /plan/today` 等)与现有 backend 路由不一致——本波 UI 先接现有
  DTO,离线优先记组是已拍板的独立子轮,不在本波。
- 包内矛盾:`--gold-cta` 暗色 #FFB800(tokens.css/样机一致,采用)vs 旧 README #FFC53D 之争已消——v3 双源一致,无需再问设计师。
