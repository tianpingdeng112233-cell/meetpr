# 下个 TestFlight 版本 — 进行中

> 这份只记**还没 archive** 的东西 + 进度。**archive 上传后**:把「本版将包含」整段挪进 [RELEASES.md](./RELEASES.md) 作为该 build 一节,然后清空本文件、目标 build 号 +1。
> 上一个线上版:**1.0 (4)**(见 RELEASES.md)。

## 🎯 目标:1.0 (5)
- **承载 worktree / 分支**:`/Users/david/Projects/apps/MeetPR-ship` @ `ship/today-entry-video-scroll`(基于 `origin/main`)
- **PR**:[#197](https://github.com/tianpingdeng112233-cell/meetpr/pull/197)

## 本版将包含

### A. 已合到 ship 分支(就绪)
- ✅ **训练 tab 弹窗记录流**(`64d9cb9`):放大次数显示、点「记录此组」弹出 `SetEntrySheet`、删除内联 RPE 横条、摄像头按钮打开弹窗并滚到录像区
- ✅ **动作库**(`f3c4399`):新增 低杠位暂停深蹲 / 低杠位节奏深蹲;所有 RDL → 「罗马尼亚硬拉」(catalog 共 1229 条)
- ✅ **发版配置**(`87b11ba`):签名 team → `28JW4SA779`(旧 `XV97B4R4RZ` 作废)、build 号统一 `5`

### B. 顺带带上(build 4 落后 origin/main 的主线更新,从 main 打自动包含)
- 教练编排只留 4 周 + 内测停用评估期(#190)
- spec 043 文档收尾 / 埋点 spec / CI 调整(#188/#191/#195 等)

## 📋 进度:离 archive 推 TestFlight 还差几步
- [x] 改动合到 ship 分支
- [x] 修签名 team(`XV97B4R4RZ` 作废 → `28JW4SA779`)
- [x] build 号设 5
- [x] 编译验证(`MeetPR-Demo` + `MeetPR-DemoStudent` 均 build SUCCEEDED)
- [x] 运行验证(DemoStudent app 启动正常 = catalog 1229 条运行时解码通过)
- [x] 开 PR #197 → main
- [ ] (可选)PR #197 合进 main(需 CI 绿 + 临时开 `enforce_admins`)
- [ ] 去 App Store Connect 看 `1.0` 下最高 build 号 → 若已 ≥5,把号调更高
- [ ] Xcode 打开 `MeetPR-ship` → Product → **Archive**
- [ ] Organizer → Distribute App → App Store Connect → **Upload**
- [ ] 等 Apple 处理(~5–15 分钟,状态变 *Ready to Test*)
- [ ] 分配到内测组 **Neice**
- [ ] 手机 TestFlight 点「更新」验证

> **核心就 3 步**:Archive → Upload → 等处理;加上「确认号 / 分组 / 手机更新」共 ~6 步,全是点几下。合进 main 是可选(不影响出包,从 `MeetPR-ship` 直接归档即可)。

## 想进这版、但还没上车(需各自整理)
- `feat/coach-analytics-quickwins`(已推未合)— 教练 program-quality 分析数据层
- `spec/044-bench-grip-parameter`(已推未合)— 卧推握距参数(**仅 spec 文档,无实装**)
- ⚠️ `feat/043-import-format-hardening`(worktree `MeetPR-wt-043-hardening`,**未提交**)— 导入格式加固(WPS 清洗等);最该先 commit 保命

## archive 之后要做(给未来的你)
1. 把「本版将包含」整段 + 最终 build 号写进 `RELEASES.md` 作为 1.0(5) 一节。
2. 清空本文件的「本版将包含 / 进度」,目标改 1.0(6)。
3. 把「还没上车」里已合并的项删掉。
