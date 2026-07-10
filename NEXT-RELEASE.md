# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> ⚠️ 2026-07-10 David 拍板:1.0(8) 改走 **7 基底 + 小步直推**形态——基于 `1.0(7) @ 0ef0169`,
> 只叠 David 在 Codex 直驱的修复/小功能;**不带 main 大版本线**(solo/e1RM wave 等,那些在 main
> 上等下个大包)。main 上的 NEXT-RELEASE.md 与本文件各管各线。

## 🎯 目标:1.0 (8) — 基于 1.0(7) 的修复包
- 基底:`0ef0169`(= TestFlight 在测的 1.0(7))
- build 号:8(prep-beta 时统一 bump,平时不动)
- 切包:在本分支打 tag `beta/1.0-8`(7 基底形态的一次性安排)

## 本版将包含(直驱改动合入后追加到这里)

**待做(David 点名三修,任务卡已发)**
- [ ] #231' 教练看学员执行页锚定本周(原永远显示 cycle 第 1 周)
- [ ] #232' 学员训练界面组数 1-based(录入 sheet 标题 / 当前组 hero / 组表序号)
- [ ] #233' 闪退至登录:瞬时刷新失败(离线/超时/5xx)不再清会话踢登录(最小修)

## 📋 进度:离 archive 还差几步
- [ ] 三修合入 release/1.0,CI 绿
- [ ] build 号 bump 8 + 打 tag `beta/1.0-8`(prep-beta)
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(8) 一节,清空本文件、目标号 +1。
