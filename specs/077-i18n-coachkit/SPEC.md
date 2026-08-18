# 077 — 英文化卡CoachKit(~736 行)

- 状态: InReview(2026-08-18;⚖️离线授权期按简报代拍,卡A(#325 已合)先行产出约定与术语表)
- 来源: 英文化拆卡简报 scratch/intl-auth/i18n-wave-briefing.md;⚖️08-12 手写 strings enum 活约定。

## 目标

CoachKit 全部用户可见中文字面量(~736 行)收进模块 strings enum + Localizable.xcstrings
(zh-Hans 源逐字节=原字面量,en 新增),翻译一律先查 docs/i18n-glossary.md(卡A 产出,
动作名以 catalog nameEn 为正典不重译)。

## 纪律(与卡A 同款,全部承袭)

1. zh 逐字节不变=红线,xcstrings zh 源串必须等于原字面量;插值/拼接场景逐个核。
2. enum 形制=StudentStrings 薄封装;不加运行时兜底进生产代码。
3. 线格式/正典串/持久化内容 locale 稳定,只在展示层本地化(卡A 的 SetRef 教训)。
4. Tests 与代码注释中文豁免;验收口径=Sources 用户可见字面量清零。
5. 单复数英文变体照卡A 手法处理。

## 验收

全模块 swift test 绿;swiftlint --strict/swift-format 零违规;Release+Global 双 build 过;
zh 逐字断言抽查关键页;en 无漏网中文。
