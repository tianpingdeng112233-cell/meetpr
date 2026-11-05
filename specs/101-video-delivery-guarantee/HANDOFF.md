# Spec 101 交接单（2026-11-05，Opus → Codex）

先读同目录 `SPEC.md` 全文（含「屏幕稿」转写与验收清单）、仓根 `CONTEXT.md`。本文件只记**进度与剩余工作**；iOS（`MeetPR` 仓 `release/1.0`）与安卓（`meetpr-rn` 仓 `main`）两仓同目录各有一份，内容相同。

## 一、已完成

| 项 | 位置 | 状态 |
|---|---|---|
| P0 视频「被吞」修复（iOS） | meetpr#403 → `release/1.0@73ecbfc8` | 已合；登记为 1.0(32) 候选（NEXT-RELEASE，#407）。David 定「不单独切包，进下班车」 |
| spec 101 + 屏幕稿转写 | iOS #400/#402，RN #131/#133 | 已合 |
| 101 A 卡 · 安卓 | meetpr-rn#136（`feat/101-video-delivery`） | David 真机验过并「放行」，已开 auto-merge，等 CI 绿自合 |
| 101 A 卡 · iOS | meetpr#408（`feat/101-video-delivery-a`，叠 #403） | **等 David「放行」**。StudentKit 1117/1117、CoreModels 164/164、本机 generic 构建通过 |

P0 根因（已写进 #403 commit）：组保存未返回时相机回调拿不到组 id → 删录像；保存失败（断网/5xx/超时/换天）同样删。修复后拿不到 id 的录像持久挂起（`VideoUploadManager+PendingSet` / `VideoAttachmentViewModel+PendingSet`），组保存成功或回到原日后自动挂上。排障记录 `docs/diagnose/set-video-lost-2026-11-05.md`（iOS 仓）。

A 卡已拍板的口径：
- 失败色统一用现有 danger 系 token（iOS `danger`/`dangerSoft`/`dangerMuted`，RN `src/design` danger），**不是**稿上的橙色，不新增 token。
- 安卓失败通知新建渠道 `video-upload-v2`（DEFAULT），迁移时旧渠道若被用户关闭则新渠道也关闭，然后删旧渠道。

## 二、剩余工作（按顺序）

### 1. iOS A 卡收尾（#408）
- 补模拟器截图：之前 spec 102 的 iOS 作业占用 `iPhone 17e`，只截了一部分（见 `docs/journal/2026-11-05-101-card-a-ios.md`）。等 17e 空闲后补齐 SPEC 验收第 4、5、6、9、11 条截图，对照屏幕稿 A / B / 次要两张。只用 `iPhone 17e`，收尾 `xcrun simctl shutdown`。
- David「放行」后合入 `release/1.0`，并在 `NEXT-RELEASE.md`「本版将包含」登记为 1.0(32) 候选（参照 #403 那条的写法）。

### 2. 101 B 卡（两端，等 spec 102 先落地）
范围 = SPEC §2 全部 + 屏幕稿 C、D、E①②：
- 全部记完时长按按钮上方的视频汇总条（「{x} 条视频没传上 · {y} 条正在传 · 立即重试」）与按钮下小字。
- 长按后：先走 spec 102 的「正在同步训练记录…」（组同步完才出奖励页，20 秒/4xx 进失败态——102 负责）→ 奖励页 → 关闭后训练页底部「视频上传中 {done}/{total}」卡（稿 D）→ 视频全部送达后才调现有完成接口 → 完成通知「今日训练已完成，{n} 条视频已送达」；长按 30 分钟仍未送达发「还有 {n} 条视频没传上，点击重试」。
- 「等送达后完成」状态需持久化，杀进程后恢复；iOS 必须后台（background session 唤醒）也能完成，安卓后台尽力（vivo 冻结，不引导开高耗电）。
- **完成闸门由 spec 102 建**，留有「视频全部送达」输入；B 卡只接这个输入和 UI，**不另写闸门**。闸门接口签名见 102 交付的 JOURNAL：
  - RN：`meetpr-rn-wt-102`，分支 `feat/102-offline-set-sync`
  - iOS：`MeetPR-wt-102`，分支 `feat/102-offline-set-sync-ios`（叠 #403）
  - 102 由另一会话「✅ 按钮响应延迟」负责收货；B 卡分支要叠在 102 合入后的主干上开。
- 验收：SPEC 验收清单第 1、2、3、7 条，以及第 10 条中「升级前已完成的训练日不会被要求等送达」。
- 测试 seam：SPEC「测试 seam / 完成闸门」一条（注入上传状态流与时钟；完成接口只在全部送达后调一次；30 分钟只发一次超时通知）。
- 卡文件按 A 卡格式写（`CARD-b-ios.md` / `CARD-b-android.md`），JOURNAL 一卡一文件 `docs/journal/<日期>-101-card-b-<端>.md`。T2：PR 等 David「放行」。

### 3. 切 1.0(32) 前（陪跑）
- 陪 David 真机走一遍 #403 的直拍路径：断网时记一组 → 直接拍视频 → 联网 → 视频挂到这一组并能回看。
- 安卓 #136 随下一班 CN 包（走 `/android-cn-release`）。

## 三、仍待 David 补的信息（不阻塞上面工作）
- 受影响学员的账号与线上只读入口（Bitwarden 条目名），用于核对线上 11/1、11/3、11/4 三处缺视频是否就是这个根因。
- 已丢视频服务端与本机都没有，只能请学员在手机相册里找（相机直拍在有相册权限时会另存一份）。

## 四、资源与注意
- 屏幕稿（David 已定稿）：https://claude.ai/artifact/G9WZsVKcf8STMZfeTBbarn（Codex 打不开，结构与文案以 SPEC「屏幕稿」转写为准）。
- 本机磁盘曾满导致 CI 失败（11/05 清理后约 12–14G 空余）；跑大构建前先 `df -h`。iOS 自托管 CI 网络问题已由 #405 修。
- 安卓模拟器验收：Codex 沙箱起不了 adb；需要宿主机操作时由人或 Opus 做。演示测试包做法：临时改 `plugins/build-track.js` 包名为 `com.meetpr.app.v101` + `EXPO_PUBLIC_DEMO_MODE=1` 后 `scripts/pack-android.sh china <dir> --allow-debug-signing`，用完还原，**不得提交**。
