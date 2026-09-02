# spec 081 补记 · 屏幕稿正典(David 2026-09-02 拍板)

四块画板(iPhone 402×874,浅色),在线画布:https://claude.ai/code/artifact/1e74451f-818a-4d13-aad7-90056e7b886f

1. `Main.dc.html` — 训练 tab 未开始态汇总卡,主 CTA 下方次级入口「练完了?补记今天」
2. `QuickLogSheet.dc.html` — 补记 sheet:日期行 + 每动作一卡、卡内一组一行(重量/次数/RPE 格 + 「记」勾)
3. `QuickLogEditing.dc.html` — 点格子升起 MeetPRNumberPad;快捷「同步到全部 N 组」(仅重量列)与「下一格 →」
4. `QuickLogToast.dc.html` — 成功回汇总卡 + 顶部 toast「W#D# 已补记」

`canvas.json` 里的 annotations 是布局/层级说明。稿只管结构、层级、间距;像素与品牌素材走 DesignSystem 令牌。
