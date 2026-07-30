# 任务卡 · 教练端 v3 浅色迁移 卡4:视频流(待反馈列表 + 视频反馈屏)

> 派发人:Claude(Fable 判断层) · 2026-07-30 · 实装:Codex
> 分级:**T2 偏重**(功能卡,不是换皮卡) · 发布档:P1
> base:`feat/coach-v3-profile`(**叠在卡3 上**) · 分支:`feat/coach-v3-video`
> 参照物:`./MeetPR 教练端.dc.html` **758–803 行** · **先读 `./CARD-1-shell.md`**(色值映射与纪律)

## 目标

走查 P-21 实证:消息屏点黑色胶囊 → **待反馈视频列表(v2 红播放图标)** → 点某段 →
**视频反馈屏是 v2 纯文本框表单**(eyebrow「视频反馈 //」+ textarea + 灰发送)。
样机 758–803 是一整屏工作台:深色播放器卡 + 进度条 + 0.5×–2× 倍速 + **组信息四宫格** +
反馈输入 + 「跳过 · 看下一段 →」。

⚖️ **David 2026-07-30 拍板 B「按样机做全」**——这是教练每天真正干活的那一屏,不是只换个色。

⚖️ 上车闸门:卡1+卡2+卡3+卡4 加 PR #291 / #292 一并进 1.0(16);本卡 PR 同样开着不合。

## ✅ 侦察结论:本卡零后端

组信息四宫格的四个值**全都拿得到**,不需要任何新端点:

```
PendingVideoItem.id == StudentVideo.id
StudentVideo.setLogID ──▶ StudentSetLog
                            ├─ weightKg : Decimal   → 本组重量
                            ├─ reps     : Int       → 次数
                            ├─ rpe      : Decimal?  → RPE
                            └─ setIndex : Int       → 组序
```

- `PendingVideoItem` 目前**没有** `setLogID`,但它是从 `StudentVideo` 组装的 → **纯增量**地把
  `setLogID: UUID?` 补进 `RepositoryContracts` 的 `PendingVideoItem`,并在各实现里透传。
  这是加字段不是改语义,不要顺手动其他字段。
- set log 走现成 `StudentTrainingLogRepository`(教练侧已在用),按 `setLogID` 匹配。
- **未链接的视频**(`setLogID == nil`,样机盲区)→ 四宫格**整卡不画**,不要显示 0 或「—」凑数。

## 🔥 三条最容易做错的

1. **`setIndex` 是 0-based,显示层 +1**。
   仓内 2026-07-27 的 C0 契约翻转过一次(更早的结论是「1-based 别 +1」,**已作废**),
   黑金波就差点显示成「第 0 组」。样机 `vSet` 显示的是「第 5 组」这种人读的序号。
2. **`rpe` 是 `Decimal?`**。nil 时**不要显示 0**;整值不要显示成 `8.0` 之外的浮点噪声
   (仓内既有 RPE 展示口径,照抄别自创)。
3. **「＋打点」不做**(⚖️07-30 拍板仍 deferred)。连带**不画**:
   - 样机 778 行的「＋ 打点」按钮
   - 样机 790–797 的「打点 · N」列表整块
   - 样机 770 行进度条上那两个 `#D97706` 琥珀色刻度(那是打点标记)
   进度条只留「已播时间 / 总时长 / 白色已播段」三件。

## 1. 待反馈视频列表(消息屏胶囊的落点)

现状 `StudentPendingVideosView` 是 v2(红播放图标、朴素卡)。**只换皮**:
色值走 CARD-1 映射表 token,零硬编码 hex、零 v2 旧 token;结构与现有一致。
样机没画这一屏(它是直接开第一段),保留列表是卡2 已申报的偏离,本卡沿用不翻案。

## 2. 视频反馈屏(样机 758–803)

整屏是 **`inset:0` 全屏遮罩**,底 `bgBase`,**不显示 tab bar**(沿用卡2 建好的全屏目的地机制)。

### 顶栏(761)
40pt 白圆返回键(`.card` 阴影)+ 中间两行:`{学员} · {动作}` 16/700 与
`{组序} · {相对时间} 上传` 11 `textTertiary`;右侧 mono 12 `textTertiary` 的队列位置 `{i}/{n}`。

### 播放器卡(763–780)
深色卡:底 `textPrimary`(`#111827`)、圆角 16、内距 12,内部竖向 gap 11。

- **画面区**:高 270、圆角 10、底 `#1B2534`、1px 描边 `#2A3646`。
  ⚠️ 这两个深色值**不在 CARD-1 映射表里**(样机的播放器专用色)。
  → **在 DesignSystem 里新增两个具名 token**(如 `videoStageFill` / `videoStageBorder`),
  **不要硬编码 hex**,也不要拿 bgStack 之类凑近似。
- **播放/暂停**:56pt 圆、底 `rgba(255,255,255,.14)`、白色图标(样机 766–767 两态)。
- **进度条**(770):左右 mono 11 `#9CA3AF`(= `textDisabled`)的当前/总时长;
  中间高 4、圆角 2、轨道 `#2A3646`、已播段白色。**琥珀刻度不画**(见上)。
- **倍速**(771–777):四档 0.5× / 1× / 1.5× / 2×,等宽分段控件,
  容器底 `rgba(255,255,255,.08)`、圆角 10、内距 3;选中档圆角 7。mono 11。
  ⚠️ 播放器复用现成 `FeedbackVideoPlayerView`(已与聊天组卡片共享)。
  **倍速能力按共享件纪律加**:可选参数 + 默认值 = 现有行为,学员端/聊天侧零 diff。

### 组信息四宫格(781–789)
白卡、圆角 16、内距 15,四等分 + 三条 1px `borderDefault` 竖分隔:
本组重量(Archivo 800/22 + `kg` 11)、次数、RPE、组序(14/700)。
标签 11 `textTertiary`。**数据来源见上「侦察结论」**;未链接视频整卡不画。

### 反馈输入(798)
白卡 + 1px `borderDefault` + 圆角 16,内距 `6px 6px 6px 14px`:
输入框 placeholder「写给 {学员} 的反馈」14;右侧「发送」深色实底(`textPrimary`)
圆角 12、内距 10/16、13/700。接现成 `videoQueueViewModel` 的发送路径(已有 spec 060 的
`feedback.video_id` 关联),**不要新建反馈端点**。

### 跳过(799)
1px `borderStrong` 描边胶囊、内距 14、14/600:「跳过 · 看下一段 →」。
点击在**全局未反馈视频队列**里推进到下一段(不按学员过滤);已是最后一段时按样机
1355 行 `pend[i+1] || pend[0]` **回卷到第一段**。顶栏 `{i}/{n}` 同样按全局队列计算。

## 沿用前三卡的全部纪律

零硬编码 hex(新色必须建 token)、零 v2 旧 token;`now` 由上层传入,禁 view 内自取 `Date()`;
文案走 `CoachLocalization` + xcstrings,禁 `String(format:)`;
共享件(播放器)改动走「可选参数 + 默认值保持现值」;**禁止画死链**;
样机的假数据不是契约;算法(队列推进、组信息解析)进可单测纯函数。

## 验收标准

- `swift test` CoachKit + DesignSystem + ChatUI + RepositoryContracts 全绿;
  `xcodebuild -configuration Demo` **0 warning**;`swiftlint --strict` + `swift-format --strict` 干净
- 模拟器截图:①待反馈列表 ②视频反馈屏(播放态)③暂停态 ④四档倍速各选中一次 ⑤未链接视频(四宫格不画)
- **模拟器实点**:播放/暂停真的生效;**四档倍速真的改变播放速率**(不是只换选中色);
  进度条随播放推进;发送反馈后该段从队列消失;「跳过」真的换到下一段 —— **渲染正常不等于能用**
- 单测:组序显示 = `setIndex + 1`(**专门锁 0-based → 显示 +1**);RPE 锁死整值/半值格式,
  `rpe == nil` 卡片显示破折号且不显示 0;未链接视频不画四宫格;全局队列末尾回卷边界
- grep 自证:零硬编码 hex(含 `#1B2534` / `#2A3646` —— 必须是 token)、零 v2 旧 token、零 `Date()` 直取
- 自证边界:`Planning/`、`Features/Dashboard/`、`Features/StudentRoster/`、`Features/MyProfile/`、
  **StudentKit** 全部零 diff;ChatUI 若动只加可选参数且默认值不变
- **不 commit、不 push**,改动留在工作区等 Claude 跑 review-loop
