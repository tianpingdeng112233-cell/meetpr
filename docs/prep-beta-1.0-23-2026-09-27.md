# 1.0(23) P0 切包记录 — 2026-09-27

## 授权与范围
David 要求“p0问题，尽快上线”，并确认最高已上传 build 为 22。#345 已合入 `release/1.0@03021ff6cbe82aba26827df70b48fb6451105c6d`。仅追加 e1RM 修复及测试依赖固定，不带入延期候选。Archive / Upload 保持 David 手动。

## 切包准备
- marketing version 1.0，build 23；通过 agvtool 单源更新，不改 Info.plist 变量。
- 新 annotated tag `beta/1.0-23`；原 22 tag 保留。
- 专用取包树：`/Users/david/Projects/apps/MeetPR-release-1.0-23`，独立于已有脏树。
- 取包 scheme `MeetPR`，Archive configuration `Release`。
- PR CI run 36329108282 全绿：九包 1,930 测试、主工程 9 测试、format/lint。
- tag CI 已全绿、双端安装号与截图已核实，**代码侧可 Archive；尚未上传**。

## 四基线（最终验收）
| 基线 | 证据 |
| --- | --- |
| release/1.0 | 切包时 4e97a489；最终验收提交仅增加 docs/截图，无产品代码差异 |
| beta/1.0-23 | annotated tag 解引用 4e97a4894a0ef4625948877cb45b5ef60522b882，远端核实一致 |
| 模拟器安装 | 教练 iPhone 17、学员 iPhone 17 Pro，实际安装容器 Info.plist 均为 1.0(23)，见下方 |
| ASC 最高上传 | 22，David 2026-09-27 口报；23 未上传，内外测分发状态未核实 |

## 验收
修复细节与旧用户升级恢复证据见 [修复验证](verification-e1rm-imported-baseline-2026-09-27.md)。修复不要求后台改数据；真实学员手机升级后的效果仍待上传后确认。

## 已完成的切包证据
- annotated `beta/1.0-23` 解引用为 `4e97a4894a0ef4625948877cb45b5ef60522b882`；修复合并 SHA 为其祖先。
- 精确 tag 的 demo 树：`/Users/david/Projects/apps/MeetPR-demo-1.0-23`（detached，工作区干净）。
- 教练：`MeetPR-Demo` / `Demo` / iPhone 17；build/run 成功，实读已安装容器 `D3B693E9-F1C7-4311-9C83-D25472458BB3/MeetPR.app/Info.plist` 为 1.0(23)，工作台角色正确。[截图](evidence/beta-1.0-23/coach.jpg)。
- 学员：`MeetPR-DemoStudent` / `DemoStudent` / iPhone 17 Pro；build/run 成功，实读已安装容器 `CB03CE1B-B6BB-4580-87DD-2C99145FA8E6/MeetPR.app/Info.plist` 为 1.0(23)，进入成长页硬拉曲线正常。[截图](evidence/beta-1.0-23/student.jpg)。本图使用原 demo 数据；受影响旧数据的恢复证据见修复验证，不能把 demo 数值当作真实学员结果。
- Xcode 窗口已核实路径为本次 23 取包树，Active Scheme = MeetPR，Active Run Destination = Any iOS Device (arm64)。ArchiveAction = Release。
- 打开 Xcode 后自动写入本树 UserInterfaceState 与 TestAction 的 MacroExpansion XML 顺序；已核实 ArchiveAction 未变，并将本任务自动产生的 scheme 排序恢复至 tag，仅保留本机 UI 状态，不进入发布提交；其他已有脏树未动。
- [TestFlight 更新说明](evidence/beta-1.0-23/testflight-notes.txt)。23 尚未 Archive/Upload。

## 网络故障记录
首次 tag CI attempt 1 的 Swift Build & Test 在 AppShell 拉取 CoreXLSX/ViewInspector 时 GitHub 443 超时，尚未执行该包测试；format/lint 成功。使用系统已配置的 127.0.0.1:5780 代理临时修复 runner/SwiftPM 缓存的 git 连接，原 SHA 重跑失败任务，不改代码、不重打 tag。demo 同类依赖拉取超时通过已有依赖缓存及 skipPackageUpdates 恢复，随后两端实际 build/run 成功。最终原 SHA 的 attempt 2 全绿；临时 runner/SwiftPM cache 代理配置已恢复原值。

## 最终 CI 与交付
- [tag CI run 36330361925](https://github.com/tianpingdeng112233-cell/meetpr/actions/runs/36330361925) 全绿，匹配 `beta/1.0-23@4e97a489`；Swift Build & Test attempt 2 成功，format/lint 成功。
- 九包测试：Analytics 30、AppShell 103、ChatUI 85、CoachKit 443、CoreModels 158、DesignSystem 73、Networking 131、RepositoryContracts 6、StudentKit 901，合计 **1,930**；主工程 **9**，全部通过。
- 取包工程已打开：`/Users/david/Projects/apps/MeetPR-release-1.0-23/MeetPR.xcodeproj`；MeetPR / Any iOS Device (arm64) / Archive Release / 1.0(23)。David 手动 Product → Archive → Upload。
- 不把代码验收当作已上线；收到 David 上传完成后核实 23 状态，再将本包移入 RELEASES 并开启下一目标。
