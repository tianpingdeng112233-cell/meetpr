# 下个 TestFlight 版本 — 进行中

> 本文件在 `release/1.0` 分支上,记录**下一个内测包**的内容与进度。
> ⚠️ 2026-07-10 David 拍板:1.0(8) 改走 **7 基底 + 小步直推**形态——基于 `1.0(7) @ 0ef0169`,
> 只叠 David 在 Codex 直驱的修复/小功能;**不带 main 大版本线**(solo/e1RM wave 等,那些在 main
> 上等下个大包)。main 上的 NEXT-RELEASE.md 与本文件各管各线。

## 🎯 目标:1.0 (8) — 基于 1.0(7) 的修复包
- 基底:`0ef0169`(= TestFlight 在测的 1.0(7))
- build 号:8(prep-beta 时统一 bump,平时不动)
- 切包:在本分支打 tag `beta/1.0-8`(7 基底形态的一次性安排)

## 本版将包含(直驱改动合入后追加到这里)

- **学员 tab 首载取消不再误报失败**(port #186):高延迟网络下加载 task 被取消时回到待重试态,不再显示“加载失败 / cancelled”
- **教练今日页分诊行一点直达**(port #212):点学员行直接进该学员详情页,不再绕花名册
- **成长页三处微修饰**(port #222):E1RM 首现配白话解释、曲线加 min/max 轴标和逐次数据点、杠片提示多片时换行不截断
- **动作库去重 10 组重复条目**(port #209):臀推→杠铃臀冲、绳索夹胸→绳索飞鸟等,旧叫法保留为别名可搜

- **[P0] 组记录失败防扩散**:重量/次数/RPE 保存失败时保留训练页和刚输入的值,
  sheet 不再提前关闭;视频前置写组失败会明确提示,不再把整页替换成“加载失败”。
  - staging 真环境复现:`POST /sets/log` 对全新已发布计划仍返回 `500 internal_error`,
    因而视频上传被共同前置阻断;恢复真实写入仍需 backend 迁移/部署修复。
  - 验证留痕(2026-07-10):StudentKit 265 tests 全绿;受影响文件 strict lint 0;
    `MeetPR-DemoStudent` / DemoStudent / iPhone 17 build+run 并目视保持 1.0(7) 形态。
- **内测前点名三项修复**(#231'/#232'/#233',已合入)
  - ①教练端学员执行页默认锚定当前计划周(原永远显示 cycle 第 1 周)
  - ②学员训练界面组数 1-based(录入 sheet 标题 / 当前组 hero / 组表序号)
  - ③闪退至登录:瞬时刷新失败(离线/超时/5xx)不再清会话踢登录(最小修)
  - 验证留痕(2026-07-10,三修分支上):DemoStudent build+run;app smoke 6/6;
    本周锚定 3/3;组号 3/3;会话恢复 14/14;Networking 全量通过

## 📋 进度:离 archive 还差几步
- [x] 三修合入 release/1.0(2026-07-10 merge,待 CI 绿)
- [x] #228/#229 port(死 INFOPLIST_KEY 清理 + build 号 apple-generic 单源)
- [ ] main 库存分诊捞回队列(10 项,序 1-10,依赖关系见 [AGENTS.md §发版直推流](./AGENTS.md) 捞回队列表)
- [ ] build 号 bump 8 + 打 tag `beta/1.0-8`(prep-beta)
- [ ] David:Archive → Upload → 分配 Neice

## 收尾约定
archive 上传后:把「本版将包含」挪进 RELEASES.md 作 1.0(8) 一节,清空本文件、目标号 +1。
