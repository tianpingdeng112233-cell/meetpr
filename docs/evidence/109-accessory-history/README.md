# Spec 109 · iOS 原生验收

2026-11-13，iPhone17e / iOS26.5，MeetPR-DemoStudent，现有 --spec089-rpe fixture。仅演示fixture；真实历史读取边界由仓储/VM公开seam验证，不冒充线上账号验收。

## 最终批准截图

- [浅色编辑](ios-edit-light-final.jpg)：历史55右侧仅“上次”，当前次数12/RPE8不带历史。
- [深色编辑与保存](ios-edit-dark-final.jpg)：第3组55右侧“上次”；第2组仅改次数13后重量55普通色且无提示；第1组手改60，其余未联动。
- [浅色扫视](ios-browse-light.jpg)、[深色扫视](ios-browse-dark.jpg)、[手改](ios-edited-dark.jpg)：沿用原紧凑行，历史金色，点开才编辑。

旧 ios-edit-light.jpg / ios-edit-dark.jpg 是用户追加修订前的取证，仅保留过程，不是最终设计；reference原型同样以SPEC最新修订为准。

## 验收映射

| 项目 | 证据 |
|---|---|
| A1–A4 历史逐组、教练优先、null/零/缺组、最新session、跨计划与过滤 | AccessoryWeightHistory*Tests，03-boundaries.log；新增9执行case |
| A5 编辑与单位、右侧徽标 | 最终浅深截图；06-final-ui-regression.log（60tests）与已有AllDay单位测试 |
| A6 手改不联动、保存去标、原完成/视频规则 | 深色最终截图及05全量/06定向回归 |
| A7 刷新手改、旧缓存、隔离与失败降级 | Guards/Integration公开seam及原全量测试；离线本次不改契约 |
| A8 原生浅深色 | 最终截图，136.6s原生构建成功；仅允许的iPhone17e |
| A9 质量 | 1289tests/94suites串行全绿；60tests/6suites最新定向绿；strict lint/format；双轴CLEAN；PR CI待回填 |

全量首次并行21个旧视频等待超时，串行1289全过，未改超时/测试配置。00磁盘不足不是有效红测，01才是缺helper的有效红。日志为摘录，完整本地日志留本次会话work。键盘遮挡时沿用原页面滚动到目标组，未改导航/滚动/完成机制。
