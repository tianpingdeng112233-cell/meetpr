# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (9)
- 基底:`beta/1.0-8`(= TestFlight 在测的 1.0(8),2026-07-11 上传)之后的 release/1.0 直推累积
- build 号:9(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-9`

## 本版将包含(落线后追加到这里)

- **[P0] 「我的」页退出登录始终可达**(fadbc3a,2026-07-11):资料未填/加载失败时也显示
  「更多 + 退出登录」逃生舱,账号不再被困登录态(落线晚于 1.0(8) tag,故随本包)
  - 验证留痕:lint 0;StudentKit 281 tests 绿;模拟器空白绑定号亲验;⚠️ review-loop 补审欠着
- **[P1] e1RM 单一真源(#216/spec 050 主体)**:完成组先过资格门,成长曲线与头条统一使用
  4 周滚动最大值,新 PR 必须越过 3% 噪声带;不含异常隔离与 solo/今日页新形态

## 📋 进度:离 archive 还差几步
- [ ] 捞回队列余项逐个落线(e1RM 域 #216→#220→#227 / per-set / rename / #215'/#217' 裁剪卡 /
      #234a×3 / #234b,依赖与状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表)
- [ ] fadbc3a 的 review-loop 补审
- [ ] build 号 bump 9 + 打 tag `beta/1.0-9`(prep-beta)
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(9) 一节,清空本文件、目标号 +1。
