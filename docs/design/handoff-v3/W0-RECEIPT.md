# W0 地基卡回执 — 学员端黑金 UI v3

日期：2026-07-26
分支：`feat/black-gold-ui-v3`
基线：`release/1.0` @ `0c335ea`

## 搬运与接线

- 从 `origin/feat/black-gold-ui-r10` 精确搬运：
  - `Modules/DesignSystem/Package.swift`
  - `Modules/DesignSystem/Sources/DesignSystem/{Tokens,Motion,Extensions,Components}`
  - `Modules/DesignSystem/Tests`
  - `MeetPR/Resources/Fonts` 六个字体文件
- `MeetPR/Info.plist` 的 `UIAppFonts` 注册六个字体文件。
- 使用 `xcodeproj 1.28.1` 检查工程接线：
  - `MeetPR` 是 `PBXFileSystemSynchronizedRootGroup`，`MeetPR/Resources/Fonts` 下的六个字体由
    synchronized root 自动纳入 app target；显式再加 PBXBuildFile 会造成重复资源。
  - `Modules/DesignSystem` 的 `XCLocalSwiftPackageReference`、`DesignSystem` product dependency
    和 app target framework link 已存在且有效，因此 `project.pbxproj` 无需产生文本 diff。
- r10 的新 DesignSystem API 与发版线业务屏幕仍在使用的旧 API 并存；兼容别名只放在
  `DesignSystem/Tokens/LegacyColors.swift`，没有改业务视图。

## v3 token 全量对照

下表覆盖 `tokens.css` 的全部变量，以及 W0 明确要求补齐的四个视觉效果变量。颜色和 RGB
按源文件逐字记录；引用型变量写出解析后的主题值，并保留原始引用。

| token | dark | light | 唯一来源 |
|---|---|---|---|
| `--bg-deep` | `#050506` | `#EDEEF1` | `tokens.css:7,70` |
| `--bg-base` | `#0A0A0C` | `#F5F6F8` | `tokens.css:8,71` |
| `--bg-inset` | `#101014` | `#FAFAFB` | `tokens.css:9,72` |
| `--bg-stack` | `#121217` | `#EEF0F3` | `tokens.css:10,73` |
| `--surface-card` | `#141416` | `#FFFFFF` | `tokens.css:11,74` |
| `--surface-elevated` | `#161618` | `#FFFFFF` | `tokens.css:12,75` |
| `--surface-key` | `#1C1C20` | `#F3F4F6` | `tokens.css:13,76` |
| `--surface-raised` | `#232327` | `#EEF0F3` | `tokens.css:14,77` |
| `--border-hairline` | `#17171A` | `#E9EBEE` | `tokens.css:17,79` |
| `--border-subtle` | `#1E1E22` | `#E5E7EB` | `tokens.css:18,80` |
| `--border-default` | `#262629` | `#E5E7EB` | `tokens.css:19,81` |
| `--border-strong` | `#2E2E32` | `#D1D5DB` | `tokens.css:20,82` |
| `--text-primary` | `#EDEDED` | `#111827` | `tokens.css:23,84` |
| `--text-secondary` | `#C8C8CC` | `#4B5563` | `tokens.css:24,85` |
| `--text-tertiary` | `#A1A1A6` | `#5C6371` | `tokens.css:25,86` |
| `--text-muted` | `#8A8A90` | `#5C6371` | `tokens.css:26,87` |
| `--text-faint` | `#8A8A90` | `#5C6371` | `tokens.css:27,88` |
| `--text-dim` | `#8A8A90` | `#5C6371` | `tokens.css:28,89` |
| `--text-disabled` | `#55555C` | `#9CA3AF` | `tokens.css:29,90` |
| `--text-ghost` | `#3E3E44` | `#D1D5DB` | `tokens.css:30,91` |
| `--gold-cta` | `#FFB800` | `#B45309` | `tokens.css:33,93` |
| `--gold-500` | `#F5A623` | `#D97706` | `tokens.css:34,94` |
| `--gold-400` | `#FBBF3E` | `#F59E0B` | `tokens.css:35,95` |
| `--gold-200` | `#FFE28E` | `#FEF3C7` | `tokens.css:36,96` |
| `--gold-rgb` | `245, 166, 35` | `217, 119, 6` | `tokens.css:37,97` |
| `--gold-text` | `#F5A623` | `#9A4A06` | `tokens.css:38,98` |
| `--ink-on-gold` | `#141414` | `#FFFFFF` | `tokens.css:39,99` |
| `--gold-gradient` | `linear-gradient(90deg, #E08F0F, #FFC93C)` | `linear-gradient(90deg, #D97706, #F5B93C)` | `tokens.css:40,100` |
| `--success` | `#5E9E78` | `#15803D` | `tokens.css:43,102` |
| `--success-soft` | `#9FC7AE` | `#15803D` | `tokens.css:44,103` |
| `--success-rgb` | `94, 158, 120` | `21, 128, 61` | `tokens.css:45,104` |
| `--danger` | `#E5484D` | `#E5484D` | `tokens.css:46,105` |
| `--danger-rgb` | `229, 72, 77` | `229, 72, 77` | `tokens.css:47,106` |
| `--danger-muted` | `#C88888` | `#A33B40` | `tokens.css:48,107` |
| `--danger-fill` | `#C0343A` | `#C0343A` | `tokens.css:49,108` |
| `--chart-line` | `#DCE3EA` | `#9AA4B0` | `tokens.css:50,109` |
| `--cta-bg` | `var(--gold-cta)` → `#FFB800` | `#111827` | `tokens.css:53,112` |
| `--cta-text` | `var(--ink-on-gold)` → `#141414` | `#FFFFFF` | `tokens.css:54,113` |
| `--cta-fill` | `#111827` | `#111827`（亮色未覆盖） | `tokens.css:55` |
| `--text-body` | `var(--text-secondary)` → `#C8C8CC` | `var(--text-secondary)` → `#4B5563` | `tokens.css:58` |
| `--text-heading` | `var(--text-primary)` → `#EDEDED` | `var(--text-primary)` → `#111827` | `tokens.css:59` |
| `--accent` | `var(--gold-500)` → `#F5A623` | `var(--gold-500)` → `#D97706` | `tokens.css:60` |
| `--bezel` | `#1C1C1E` | `#1C1C1E`（亮色未覆盖） | `tokens.css:63` |
| `--bezel-edge` | `#2A2A2D` | `#2A2A2D`（亮色未覆盖） | `tokens.css:64` |
| `--desk-1` | `#1A1A1E` | `#E9E9EE` | `tokens.css:65,115` |
| `--desk-2` | `#050506` | `#D2D2D9` | `tokens.css:66,116` |
| `--card-shadow` | `none` | `0 4px 18px rgba(17,24,39,.06)` | `MeetPR 学员端.dc.html:23,39` |
| `--cta-mold` | `inset 0 1.5px 0 rgba(255,255,255,.55), inset 0 -2px 3px rgba(120,60,0,.25), 0 8px 26px rgba(var(--gold-rgb),.38)` | `0 6px 20px rgba(17,24,39,.18)` | `dc-tokens.css:16,33` |
| `--cta-mold-held` | `inset 0 1.5px 0 rgba(255,255,255,.55), inset 0 -2px 3px rgba(120,60,0,.25), 0 0 0 4px rgba(var(--gold-rgb),.28), 0 0 30px rgba(var(--gold-rgb),.45)` | `0 0 0 4px rgba(17,24,39,.14)` | `dc-tokens.css:17,34` |
| `--headline-emboss` | `0 2px 0 #000, 0 3px 3px rgba(0,0,0,.55), 0 -1px 0 rgba(255,255,255,.22)` | `0 1px 0 rgba(255,255,255,.9), 0 2px 4px rgba(17,24,39,.14)` | `MeetPR 学员端.dc.html:24,40` |

### 来源差异说明

任务卡称 `--cta-mold` / `--cta-mold-held` 位于主样机顶部 helmet；当前 handoff-v3 文件中，
这两个变量实际只出现在同目录 `dc-tokens.css:16-17,33-34`，主样机顶部没有定义。
实现逐字使用该 handoff 文件的现存值，没有推导或改写。`--card-shadow` 与
`--headline-emboss` 则按要求来自主样机顶部。

## 验证输出摘要

执行上下文：

- project：`MeetPR.xcodeproj`
- configuration：`Debug`
- simulator：`iPhone 17`（iOS Simulator，UDID
  `A5119984-9A8D-415C-83D4-E7145351FA79`）

结果：

| 闸门 | 结果 |
|---|---|
| `xcrun swift-format lint --strict --recursive Modules/DesignSystem MeetPRTests` | 通过，零输出 |
| `swiftlint lint --strict --quiet --config .swiftlint.yml` | 通过，零 violation |
| `Modules/DesignSystem` SwiftPM 测试（macOS host） | 40 passed / 0 failed / 0 skipped（收货修正后复跑） |
| `MeetPR` iOS Simulator Debug build | succeeded，0 warning / 0 error |
| `MeetPR-Demo` iOS Simulator Debug build | succeeded，0 warning / 0 error |
| `MeetPR-DemoStudent` iOS Simulator Debug build | succeeded，0 warning / 0 error |
| `MeetPRTests` iOS Simulator tests | 9 passed / 0 failed / 0 skipped（review-loop 后复跑） |
| `FontRegistrationTests` | 六文件注册断言 + 逐文件 PostScript 名 + Typography 请求的全部 10 个具名字面(含 VF named instances)`UIFont` 解析均通过 |
| `plutil -lint MeetPR/Info.plist` | OK |
| `git diff --check` | 通过 |

DesignSystem SPM 的 `ColorsTests` 在 dark/light 两主题覆盖全部 v3 表面、描边、文字、金色、
语义色、CTA 与 card shadow；`VisualEffectsTests` 覆盖 CTA mold/held 与 headline emboss
的层数和几何值。字体注册证据来自 iOS simulator test target，不使用 macOS-host
`#if os(iOS)` 测试替代。

## 范围说明

- 没有修改 `StudentKit`、`CoachKit`、`ChatUI`、`AppShell` 的任何视图或业务文件。
- 没有写 `docs/CODEX-JOURNAL.md` 或 `NEXT-RELEASE.md`。
- 没有 commit 或 push。
- 范围外最小接线：无。新增的 `MeetPRTests/FontRegistrationTests.swift` 是本卡字体冒烟
  验收测试，不是业务接线。

## 收货修正(Claude,2026-07-26)

亲读 diff 后对 Codex 交付做了以下返修,均以 v3 样机源码为据:

1. **删零消费投机 token**:`pendingText/pendingRing/microLabel/displayText/bodyStrong/
   borderControl/chatBubbleOutgoing/chatBubbleIncoming/plate25/20/15/10`——其中 pending 系列
   与 v3 冲突(样机 pending 行用 `--text-dim #8A8A90`、空心圆用 `--text-ghost`),plate 平色与
   样机渐变配片规格(`SE_SPEC`)不符,W3 按样机重建。
2. **`ctaTextSecondary` 删除**:亮色被自创为琥珀色,样机实为 `var(--cta-text)`(白)@ opacity .72;
   `BrandPrimaryButton` 副行改 `ctaText.opacity(0.72)`。
3. **`ctaGlow` 删除 + `GoldGlowModifier` 重写**:"亮色把 glow 重定义为中性投影
   `0 6px 18px rgba(17,24,39,.22)`"出自 **v2** 亮色样机(r10 仓 reference 目录),v3 的
   `@keyframes glow` 双主题统一走 `var(--gold-rgb)`。现按 v3 keyframe 实现(环 .5→.62,
   halo blur 16→23 / .24→.32,4.2s)。
4. **`unread`**:`#FF3B30`(iOS 系统红)→ `dangerFill #C0343A`(样机消息角标用色)。
5. **样机字面值 token 转单值**(样机内 SVG/内联硬编码,双主题同值):`gold300/gold700(修为
   #B8791A)/gold800/gold900/goldMuted/surfaceFocus/holdTrack/medalInset/shimmerHighlight/
   celebration*`;奖牌绶带渐变配对修正为 左 `#D89226→#9A6413`、右 `#B8791A→#7A4E0E`。
6. **新增 `goldBarDeep #A9731C`**(样机 volGrad/对比条深端),容量图渐变改用之(原误用 gold700)。
7. `CardSurface.inset` 描边 `borderControl`(无出处)→ `surfaceKey`(样机收纳堆叠描边用
   `var(--surface-key)`)。

保留项:`coachNoteText` 亮色采用 textSecondary 值(样机硬编码 `#C4C4C8` 在亮色下不足 4.5:1,
README §8 无障碍地板优先于样机字面值)——此为唯一一处有意偏离样机,记录在案。
