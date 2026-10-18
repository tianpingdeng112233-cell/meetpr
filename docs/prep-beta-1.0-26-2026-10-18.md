# 1.0(26) 切包记录 — 2026-10-18

## 授权与范围
David 2026-10-18「ios切包发步」。`NEXT-RELEASE.md`「本版将包含」全部进包：教练退出登录弹窗去掉「手机号」（#369）、下拉刷新不再误报「加载失败」（#370）。延期候选不进。Archive / Upload 保持 David 手动。

## 切包准备
- marketing version 1.0，build 26；`agvtool new-version 26`（不带 `-all`），五处 `CURRENT_PROJECT_VERSION` 25 → 26，Info.plist 仍引用变量。
- 基底：发版线 tip `b25a6883`（`beta/1.0-25` 之后只多 #369、#370 两个产品提交，其余为台账）；切包提交只改版本号与台账。
- 新 annotated tag `beta/1.0-26` 指向切包提交；25 tag 保留。
- 取包 scheme `MeetPR`（CN 轨，后端 `121.40.160.241:3000`），Archive configuration `Release`。

## 门禁
| 项 | 状态 |
| --- | --- |
| #369 / #370 PR CI | 均三项全绿（Swift Build & Test / swift-format / SwiftLint）后合入 |
| 真机 | #370 David iPhone 12（Release 构建）反复下拉刷新复测通过 |
| tag CI | 见下方补记 |
| ASC 最高上传 | 25（David 2026-10-18 截图确认） |

## 交付
tag CI 全绿后：Xcode 打开 `~/Projects/apps/MeetPR-release`，Scheme `MeetPR` / Any iOS Device (arm64) → Product → Archive → Distribute → Upload。上传后把 NEXT-RELEASE「本版将包含」挪入 RELEASES.md 作 1.0(26) 一节，目标号改 27。
