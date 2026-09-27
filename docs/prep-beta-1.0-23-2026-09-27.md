# 1.0(23) P0 切包记录 — 2026-09-27

## 授权与范围
David 要求“p0问题，尽快上线”，并确认最高已上传 build 为 22。#345 已合入 `release/1.0@03021ff6cbe82aba26827df70b48fb6451105c6d`。仅追加 e1RM 修复及测试依赖固定，不带入延期候选。Archive / Upload 保持 David 手动。

## 切包准备
- marketing version 1.0，build 23；通过 agvtool 单源更新，不改 Info.plist 变量。
- 新 annotated tag `beta/1.0-23`；原 22 tag 保留。
- 专用取包树：`/Users/david/Projects/apps/MeetPR-release-1.0-23`，独立于已有脏树。
- 取包 scheme `MeetPR`，Archive configuration `Release`。
- PR CI run 36329108282 全绿：九包 1,930 测试、主工程 9 测试、format/lint。
- 本次 tag CI、最终 SHA、双端已安装号与截图待切 tag 后补证。当前不能据此条宣告可 Archive。

## 四基线（准备时）
| 基线 | 证据 |
| --- | --- |
| release/1.0 | 修复合并 03021ff6，待 build bump |
| beta/1.0-23 | 待新建 |
| 模拟器安装 | 待从本次 tag 构建、安装、读实际安装号 |
| ASC 最高上传 | 22，David 2026-09-27 口报；23 未上传 |

## 验收
修复细节与旧用户升级恢复证据见 [修复验证](verification-e1rm-imported-baseline-2026-09-27.md)。修复不要求后台改数据；真实学员手机升级后的效果仍待上传后确认。
