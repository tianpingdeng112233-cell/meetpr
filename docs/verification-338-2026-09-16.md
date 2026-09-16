# #338 追加进入 1.0(22) — 2026-09-16

David 明确要求将 #338 也加入下一班车。目标为 release/1.0 / 1.0(22)，不改 build 号、不切 tag、不 Archive/Upload。

## 组合基线

原 PR #338@8ba5b638 合入最新 release/1.0@7bf4a58b，组合提交 2e816526，无冲突。相对最新 release 的功能差异仍只有两份 JSON 与两份既有测试；未修改刚落线的 #339/#340/#341/#342/#343 实现。

## 数据范围

- 捆绑目录 1,219→1,212：增加 4 条，删除 11 条（0069 合并重复项 10 条、0025 已删项 1 条）。预览含 4 个合成主项，共 1,216。
- 别名 49→61，为旧模板保留 12 条旧名到保留动作的映射。
- 对保留 ID：分类变化 5 条，肌群变化 11 条，器械变化 21 条；完整数据差异包含 0025/0028 历史漂移修复。原 PR 摘要的肌群 9 条仅为原局部口径，完整 diff 是 11 条。
- 线上分类仍以 API 为准；正式 Excel 导入读取 API 目录并使用捆绑别名。此 PR 不写数据库、不重映射历史 ID、不重算历史 e1RM。

## 验证

- 本机最终组合 CoachKit：443 passed / 0 failed。日志：`/Users/david/Library/Developer/XcodeBuildMCP/workspaces/Projects-cf51cf27789e/logs/swift_package_test_2026-09-16T06-52-47-906Z_pid93432_89283863.log`。出现四处既有 Swift 6 并发预警，均不在本 PR 改动文件。
- Standards 独立只读审查：CLEAN；目录 ID/中文名唯一、移除 ID 无 Swift 硬编码引用，既有新功能未被覆盖。
- Spec 独立只读审查：CLEAN；0069 的 43 项字段赋值吻合，0025/0028 来源吻合，新增别名 canonical 均存在；#340–#343 消费路径兼容，分类调整不改变比赛动作资格门。
- [完整 CI run 35065922802](https://github.com/tianpingdeng112233-cell/meetpr/actions/runs/35065922802)：最新 PR head 766382ce 全绿，九包 1,922 测试（30/103/85/443/158/73/131/6/893）、主工程 9 测试、swift-format 与 SwiftLint 全部成功。

## 最终落线

[#338](https://github.com/tianpingdeng112233-cell/meetpr/pull/338) 于 2026-09-16T07:01:24Z 合入 release/1.0，merge SHA `24d47f657bf544efeea4a9adfefb5fb674618f73`。#338–#343 六项均已进入 1.0(22) 发版线。build 仍为 21；未切 beta/1.0-22，未 Archive/Upload，后端部署与 APNs 剩余项仍以 NEXT-RELEASE 为准。
