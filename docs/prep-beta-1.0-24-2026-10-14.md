# 1.0(24) 切包记录 — 2026-10-14

## 授权与范围
David 2026-10-14 下令「发车」。`NEXT-RELEASE.md`「本版将包含」全部进包：spec 084 走查调整与配套修复（#347–#353）、iOS 追平安卓 085–090（#355–#360，含消除训练页滑动卡死的 090）、spec 092 学员端与教练端（#364 / #363）。延期候选不进。Archive / Upload 保持 David 手动。

## 切包准备
- marketing version 1.0，build 24；五处 `CURRENT_PROJECT_VERSION` 由 23 统一改为 24（等同 agvtool 单源更新，不改 Info.plist 变量）。
- 基底：发版线 tip `9935bd95`（#363 squash）；切包提交只改版本号与台账，无产品代码差异。
- 新 annotated tag `beta/1.0-24` 指向切包提交；原 23 tag 保留。
- 取包 scheme `MeetPR`（CN 轨，后端 `121.40.160.241:3000`），Archive configuration `Release`。

## 门禁
| 项 | 状态 |
| --- | --- |
| #363 PR CI | run 38546430481 第 2 次全绿（Swift Build & Test / swift-format / SwiftLint）；首次为自托管 runner 拉 ViewInspector 443 超时，未改代码重跑 |
| #364 PR CI | 合入前全绿（见 #364） |
| tag CI | 推送 `beta/1.0-24` 后触发，结果待补 |
| 真机 | David 2026-10-14 在 iPhone 12 走查 092 学员端与训练历史，确认「修好了」 |
| ASC 最高上传 | 23（David 2026-10-01 口报） |
| 后端 | spec 050 已部署国内 staging（`sha-1a1d6d7`，迁移 0074）；Global 生产未部署 |

## 切包后留意
- 真机留意长按完成流程是否卡死（#350 遗留观察项）。
- 登录弹窗问题与 iOS CN 轨邮箱登录（spec 091）不在本包，David 定下个版本一起做。

## 交付
tag CI 全绿后：在 Mac 上取 `beta/1.0-24` 干净树，打开 `MeetPR.xcodeproj`，Scheme `MeetPR` / Any iOS Device (arm64) → Product → Archive → Distribute → Upload。上传完成后把 NEXT-RELEASE「本版将包含」挪入 RELEASES.md 作 1.0(24) 一节，目标号改 25。
