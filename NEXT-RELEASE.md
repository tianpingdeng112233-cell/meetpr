# 下个 TestFlight 版本 — 进行中

> 这份只记**还没 archive** 的东西 + 进度。**archive 上传后**:把「本版将包含」整段挪进 [RELEASES.md](./RELEASES.md) 作为该 build 一节,然后清空本文件、目标 build 号 +1。
> 上一个版本:**1.0 (5)** — 已 archive + 上传,待内测组生效(见 RELEASES.md)。

## 🎯 目标:1.0 (6)
- **承载 worktree / 分支**:(待定 —— 从 `origin/main` 拉新 ship 分支,或复用 `MeetPR-ship`)
- build 号:**≥ 6**(必须高于已上传的 5)

## 本版将包含
- (空 —— 下个 wave 的改动累积到这里)

## 📋 进度:离 archive 推 TestFlight 还差几步(模板)
- [ ] 改动合到 ship 分支(基于最新 `origin/main`)
- [ ] build 号设到 ≥ 6(确认 > App Store Connect 现有最高号)
- [ ] 编译 + 运行验证
- [ ] Xcode 打开 ship worktree → Product → Archive → Upload
- [ ] 等 Apple 处理 → 分配内测组 Neice → 手机点更新

> 核心 3 步:Archive → Upload → 等处理。

## 候选(已写好/在路上,但还没上车)
- `feat/coach-analytics-quickwins`(已推未合)— 教练 program-quality 分析数据层
- `spec/044-bench-grip-parameter`(已推未合)— 卧推握距参数(**仅 spec 文档,无实装**)
- ⚠️ `feat/043-import-format-hardening`(worktree `MeetPR-wt-043-hardening`,**仍未提交**)— 导入格式加固(WPS 清洗等);最该先 commit 保命

## 收尾约定(给未来的你)
1. archive+上传后:把「本版将包含」+ 最终 build 号写进 `RELEASES.md` 作为 1.0(N) 一节。
2. 清空本文件「本版将包含 / 进度」,目标号 +1。
3. 「候选」里已合并的删掉。
