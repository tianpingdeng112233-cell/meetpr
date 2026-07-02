# 下个 TestFlight 版本 — 进行中

> 这份只记**还没 archive** 的东西 + 进度。**archive 上传后**:把「本版将包含」整段挪进 [RELEASES.md](./RELEASES.md) 作为该 build 一节,然后清空本文件、目标 build 号 +1。
> 上一个版本:**1.0 (5)** — 已 archive + 上传,待内测组生效(见 RELEASES.md)。

## 🎯 目标:1.0 (6)
- **承载 worktree / 分支**:复用 `MeetPR-ship`(`ship/today-entry-video-scroll`,同 PR #197)
- build 号:**6**(已 bump,高于已上传的 5)

## 本版将包含
- **多项目 e1RM 成长曲线**(#199)— 学员首页日卡显示每个练过项目的曲线
- **教练编排只显中文动作名**(#198)
- **教练 program-quality 分析数据层**(#196,A 组纯数据层,无 UI)
- **导入计划入口置灰封存**(#203)— in-app xlsx 导入冻结,网页编写端为唯一导入口;按钮首次可见,灰色不可点

## 📋 进度:离 archive 推 TestFlight 还差几步
- [x] 改动合到 ship 分支(#196/#198/#199 已合入;#203 待 CI 绿合 main 后 merge 进来)
- [x] build 号设到 6(> App Store Connect 现有最高号 5)
- [ ] 编译 + 运行验证(#203 合入后重跑)
- [ ] Xcode 打开 ship worktree → Product → Archive → Upload
- [ ] 等 Apple 处理 → 分配内测组 Neice → 手机点更新

> 核心 3 步:Archive → Upload → 等处理。

## 候选(已写好/在路上,但还没上车)
- `feat/coach-analytics-quickwins`(已推未合)— 教练分析后续(A 组数据层部分已以 #196 合 main 并进本版)
- `spec/044-bench-grip-parameter`(已推未合)— 卧推握距参数(**仅 spec 文档,无实装**)
- ~~`feat/043-import-format-hardening`~~ — **已推远端封存,不再上车**(2026-07-02 决策:web 编写端为唯一 xlsx 导入口,in-app 解析器休眠;入口置灰见 #203)

## 收尾约定(给未来的你)
1. archive+上传后:把「本版将包含」+ 最终 build 号写进 `RELEASES.md` 作为 1.0(N) 一节。
2. 清空本文件「本版将包含 / 进度」,目标号 +1。
3. 「候选」里已合并的删掉。
