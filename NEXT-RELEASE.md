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
- **[P1] 视频挂点不再冲掉未保存输入 + 拍摄后弹层重弹修复(#246,spec 027 修缮)**:记录弹层
  输入未提交时挂视频,原会以旧草稿建档(服务端记默认值)并把弹层拆毁重弹(输入归零,拍摄路径必现)。
  四层修复:建档/选片前先刷入草稿;相机盖层改按自身 binding 关闭(环境 dismiss 多关一级是重弹真凶);
  .loaded/.recording 合并渲染分支保持弹层身份;persist 串行化 + 最新草稿合并 + 跨日 generation 护栏
  - 验证留痕:review-loop 6 轮 5 BLOCKER 全收敛;StudentKit 316 tests 绿;真机 iPhone 12/iOS 26.5
    「22.5×5@9 → 拍摄 → Use Video」亲测不重弹不重置(David 手测 + Codex 直驱复核)
- **[P1] 测试基建:StudentKit 跨午夜时区 flake 根治(#247,无 runtime 行为变化)**:demo seed 用
  UTC 日历锚定 plan-day、VM 用本地日历匹配,live `Date()` 在本地/UTC 日期错位窗口把"今天"解析成
  day[4],`TodayWorkoutPRHookTests.bufferSuppresses…` 稳定失败;`makePlanView(today:)` 注入锚点
  (默认参数,demo 路径不变),PRHook + RestTimer(同病潜伏,UTC 以西机器必发)两文件时钟冻结到
  seed 自身 UTC 午夜锚点,任意时区免疫
  - 验证留痕:失败窗口内(23:07 UTC)复现→修复后同窗口绿;`--filter` 10/10 连跑;五时区矩阵
    (UTC/上海/UTC+14/UTC-11/伦敦)全绿;全套件 316 绿;review-loop 2 轮 CLEAN(2 nit 均采纳)
  - 附带发现:同一日历错位对 UTC 以西时区是**产品级**风险(美洲用户白天"今天"解析成明天),
    中国/UK 因正偏移安全——已记海外 wave 记忆时区险 ④,本 PR 不动 runtime
- **[P1] 组行视频状态摄像头变色 + 失败直达重试 + 拍摄相册留底(#242,spec 027 修缮)**:组表格摄像头
  图标恒形只变描边色——无视频灰/上传中按真实进度从左到右提亮/成功绿/失败红;失败态点图标直接弹
  「重试上传·删除」不再绕记录弹层(一组神经消耗不可逆,素材不可再生);拍摄的视频在上传前先存进相册留底
  (add-only 授权,拒绝静默降级不阻断上传)
  - 验证留痕:真机 iPhone/iOS 26.5 David 亲验「没问题」(颜色四态 + 拍摄不重弹 + 数值不重置)+ Codex 直驱
    复核;CI 三绿;StudentKit 测试绿

## 📋 进度:离 archive 还差几步
- [ ] **⛔ 切包硬门:backend 0038 迁移(DMS)+ SAE 滚新镜像必须先部署**——iOS 顺延已是 V2
      计划级端点(backend PR #57 已合 staging),线上镜像还是 V1 端点,先发 iOS 会 404
- [ ] 捞回队列余项逐个落线(e1RM #227 / per-set / rename / #215'/#217' 裁剪卡 / #234a×3,
      依赖与状态见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表;#216/#220/#234b 已落)
- [ ] fadbc3a 的 review-loop 补审
- [x] build 号 bump 9(prep-beta,agvtool 单源)+ 打 tag `beta/1.0-9`
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(9) 一节,清空本文件、目标号 +1。
