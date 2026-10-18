# 1.0(25) 切包记录 — 2026-10-18

## 授权与范围
David 2026-10-18「部署落地页，然后切 25 的包」。`NEXT-RELEASE.md`「本版将包含」全部进包：spec 093 国内邮箱注册与邀请消息分享（#366）、Global 粘贴按钮恢复（#367）、登录键盘遮挡修复与 CN 新口号（#368）。延期候选不进。Archive / Upload 保持 David 手动。

## 切包准备
- marketing version 1.0，build 25；`agvtool new-version 25`（不带 `-all`），五处 `CURRENT_PROJECT_VERSION` 24 → 25，Info.plist 仍引用变量。
- 基底：发版线 tip `7825ea7c`；切包提交只改版本号与台账，无产品代码差异。
- 新 annotated tag `beta/1.0-25` 指向切包提交；24 tag 保留。
- 取包 scheme `MeetPR`（CN 轨，后端 `121.40.160.241:3000`），Archive configuration `Release`。

## 门禁
| 项 | 状态 |
| --- | --- |
| #366 收货 | 通过，见 [收货记录](acceptance-spec093-ios-2026-10-18.md)；David iPhone 12 实测注册收信、找回密码、24 登录态升级不掉登录 |
| #367 / #368 PR CI | 均三项全绿后 squash 合入 |
| 真机 | David 2026-10-18 复测 #368 键盘遮挡已修 |
| 发包闸门（SPEC §5） | 已解除：国内后端 `e788574` 已部署（deploy run 39089552055），`/i/<码>` 落地页在线，失效码显示「邀请已失效」，页面带 TestFlight `join/aKmSgx4b` 与安卓 APK 链接 |
| tag CI | 推送后触发，结果待补 |
| ASC 最高上传 | 24（David 2026-10-18 截图） |

## 交付
tag CI 全绿后：Xcode 打开 `~/Projects/apps/MeetPR-release`（或任一检出 `beta/1.0-25` 的干净树），Scheme `MeetPR` / Any iOS Device (arm64) → Product → Archive → Distribute → Upload。上传后把 NEXT-RELEASE「本版将包含」挪入 RELEASES.md 作 1.0(25) 一节，目标号改 26。
