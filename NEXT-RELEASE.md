# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> 发版模型:1.0(7) 基底小步直推,落线即候选,tag 切包;main = 大包待分诊库存,不进本线。
> 权威规则见 [AGENTS.md §发版直推流](./AGENTS.md)。

## 🎯 目标:1.0 (9)
- 基底:`beta/1.0-8`(= TestFlight 在测的 1.0(8),2026-07-11 上传)之后的 release/1.0 直推累积
- build 号:9(prep-beta 时统一 bump,平时不动)
- 切包:本分支打 tag `beta/1.0-9`

## 本版将包含(落线后追加到这里)

- **[P0] 「我的」页退出登录始终可达**(fadbc3a,2026-07-11):资料未填/加载失败时也显示
  「更多 + 退出登录」逃生舱,账号不再被困登录态(落线晚于 1.0(8) tag,故随本包)
  - 验证留痕:lint 0;StudentKit 281 tests 绿;模拟器空白绑定号亲验;⚠️ review-loop 补审欠着
- **[P1] e1RM 单一真源(#216/spec 050 主体)**:完成组先过资格门,成长曲线与头条统一使用
  4 周滚动最大值,新 PR 必须越过 3% 噪声带;不含异常隔离与 solo/今日页新形态
- **[P1] e1RM 误记隔离(#220/spec 050 §5 Phase 1)**:相对可信历史最佳跳升超过 10% 的
  记录保留为低置信散点,但不进入当前值、Best/Last 或 PR;确认流程留待 Phase 2
- **[P1] 学员整体顺延(spec 054)**:coached 学员可在今日训练未开始时点「今天有事」,
  将剩余计划整体后移一天并在 UTC 当天撤销;教练执行页显示计划累计顺延天数
- **[P1] 今日状态静默化 + 选择态改白(#241,2026-07-11 拍板 A)**:readiness 问卷不再在
  训练日自动弹,Today 顶栏心形为唯一入口(gate 加载改为"只要是今天",休息日心形已填态也准确);
  评分圆点/肌群 chip 选择态 brandRed→白色系,CTA 与错误文案保留品牌红
  - 验证留痕:review-loop 1 轮 CLEAN + 改色复审 CLEAN;CI 三绿;StudentKit 292 tests;
    Debug(真 staging)模拟器亲验(不弹/心形绿/预填/提交成功关 sheet)
  - 姊妹修复(不随本包,已上线):backend#52 POST readiness 返回完整行,随 2026-07-11
    SAE 滚镜像生效——提交假失败(030 §C 上线以来 100% 复现)对 1.0(7)/(8) 老包直接痊愈

- **[P1] 凭证失效不再天书报错(bcf8826,port of #245)**:很久没开 app/别端登录导致凭证失效时,
  冷启动直接干净回登录页,不再带死 token 进 app 后在训练页糊出
  「AppShell.AuthRepositoryError error 0」;训练页/周历/组记录错误文案中文化
  (「登录已过期,请重新登录」)
  - 验证留痕:review-loop 2 轮 CLEAN(main 侧同改动);AppShell 52/Networking 70/StudentKit 313 绿;
    Debug(真 staging)模拟器双形态(solo/带教)E2E 亲验:服务端轮换凭证→冷启动→干净回登录页
  - 姊妹修复(不随本包):backend#59 多设备会话(未合)——教练双端并行不互踢 + 刷新丢包宽限,
    合并部署后此类被动登出本身也大幅减少

## 📋 进度:离 archive 还差几步
- [ ] **⛔ 切包硬门:backend 0038 迁移(DMS)+ SAE 滚新镜像必须先部署**——iOS 顺延已是 V2
      计划级端点(backend PR #57 已合 staging),线上镜像还是 V1 端点,先发 iOS 会 404
- [ ] 捞回队列余项逐个落线(e1RM #227 / per-set / rename / #215'/#217' 裁剪卡 / #234a×3,
      依赖与状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表;#216/#220/#234b 已落)
- [ ] fadbc3a 的 review-loop 补审
- [ ] build 号 bump 9 + 打 tag `beta/1.0-9`(prep-beta)
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(9) 一节,清空本文件、目标号 +1。
