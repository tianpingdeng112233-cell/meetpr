# iOS 追平安卓 · spec 085–090（波次总览与共同约定）

- 来源：David 2026-10-10「以最新的 rn 安卓端为标准，把苹果端也推进至同一进度」，同日定「走两套（RN 安卓 + 原生 iOS）」。
- 这六个 spec 是 10/09–10/10 在安卓端（`meetpr-rn`）走查后拍板、屏幕稿已「定稿」、已实装收货的内容。本波把它们原样做进原生 iOS 学员端。
- 级别／节奏：每个 spec 一张卡、一个 PR，全部 T2 / P1，base = 发版线 `release/1.0`，落线后是 1.0(24) 候选（落线不等于进包，合并等 David「放行」）。
- 后端：**零改动**。不加字段、不迁移、不部署。

## 追平的范围（＝安卓已做到的，不多不少）

| spec | 内容 | 本波做到哪 |
|---|---|---|
| 085 | Today：周条选中 + 概览卡；体重单项页两位小数；Meet 选日期 / 赛事方 / 级别；营养占位卡 | 全部 |
| 086 | Training：周条落后状态、周条压矮、教练备注上移 | 全部 |
| 087 | Progress 改列表入口：e1RM（含 Total）/ 历史 / 教练反馈 / 强度指标 | **只做第一步**（四行，零后端）；体重行与体重页安卓也没做 |
| 088 | Profile 改版：身份摘要卡 + 五行 + 三个二级页 | **只做第一步**（零后端）；头像上传与教练端头像安卓也没做 |
| 089 | 辅助项快速记录（行内表格、逐组 ✓、全部按计划完成、辅助项休息时长） | 全部 |
| 090 | Training：做完的动作上收、主项组进度分段条、完成按钮吸底、录入页压矮 | 全部 |

不在本波：086 文末的「Today 周条同口径显示落后」小卡（安卓未派）；安卓 PR #82 字标统一（安卓自己向 iOS 靠齐，iOS 无对应改动）；视频剪辑与休息倒计时通知（iOS 已有对应能力）。

## 正典与参照物

- 每个 spec 目录下的 `SPEC.md` = 安卓正典的**逐字副本**（取自 `meetpr-rn` `feat/demo-offline@137d816`，即含 085–090 全部内容的集成提交），顶部加了一段「iOS 落地说明」。
- 副本里凡写「只做安卓」「iOS 原生不跟」「iOS 等走查完一起跟」「登记进 `PARITY.md`」的句子，在 iOS 上由本波取代：现在就是 iOS 跟进。
- 平台落点、测试 seam、验收替换写在同目录 `CARD-ios.md`。两者冲突时：行为口径听 `SPEC.md`，平台做法听 `CARD-ios.md`；仍有矛盾就停下来问，不脑补。
- **安卓实现是参照物**，只读，取法（不 checkout、不在那个仓里写任何东西）：

  ```
  git -C ../meetpr-rn show 137d816:<路径>
  git -C ../meetpr-rn ls-tree -r --name-only 137d816 src/features
  ```

  安卓各 spec 的收货记录（含实屏后修订与截图说明）在 `137d816:docs/verification-spec08X-*.md`。

## 「一比一」的边界

照搬：页面结构、层级、行的顺序、文案（英文与中文）、各种状态与空态、规则与算法、写入的数据。

保留 iOS 做法，不照搬安卓：

- 导航用现有的 `NavigationStack` 推入与左滑返回、系统 sheet、`alert` / `confirmationDialog`、系统日期选择器；不做安卓的 toast 与硬件返回键逻辑。安卓 spec 里「左上 `Cancel`」「返回箭头 + 标题」按 iOS 现有同类页面的写法落。
- 颜色、字号、圆角、间距取 `DesignSystem` 现有 token 与现有组件；安卓稿上的数值是参考值，就近取 token，不写死色值。图标用 SF Symbols 里语义相同的。
- 动效守 spec 082：只留反馈与奖励类，系统「减少动态效果」开启时直接切换。
- 安卓验收里的「360×640 dp + 系统字体 1.3×」在 iOS 换成：最小在售屏（iPhone SE 第三代模拟器，没有就取可用的最小屏）+ Dynamic Type `accessibility-large`。

## 文案

- 英文与中文都要。iOS 的中文用户是真实内测用户，中文不是附带项。
- 中文一律取安卓目录里的中文值，逐字：`137d816:src/i18n/catalog/RnExtras.json` 与 `StudentKit.json`；英文同理。iOS 已有同义键的沿用现有键，不新建重复键。
- 进 `Localizable.xcstrings`，走现有 `StudentStrings` 取法；过仓内 i18n 守卫。

## 所有卡共同的约束

- CN 轨与 Global 轨都生效，除非 spec 明写某轨例外；不新增按轨分支。
- **不丢用户数据、不让已上线功能失效**。不改本地存储键与结构，除非卡里明写；每张卡的「存量数据与升级」一节是验收项，不是说明。
- 不加依赖；守模块边界检查脚本；所有新 model `Sendable`；View 不直接调网络。
- 守仓内 `.swiftlint.yml` 与 `swift-format lint --strict`。
- 测试用 Swift Testing，只在卡里列出的 seam 上先红后绿；既有测试的断言不删不改，确需改的逐条在 JOURNAL 写原因。
- 跑测试用 `swift test --package-path Modules/<包>`（与 CI 一致），动到的每个包都要跑完全量；`xcodebuild test -scheme <包>` 有与环境相关的假失败，不作数。
- 这是 Opus 派的任务卡，走 feature 分支 + PR，不是 `AGENTS.md` §发版直推流里的「David 直驱小修」，那一节「当前分支必须是发版线」的自检不适用。
- **不 commit、不 push**。不改 `NEXT-RELEASE.md`、`RELEASES.md`、build 号、`SPEC.md`。只在 `docs/CODEX-JOURNAL.md` 末尾追加本卡一节（改了哪些文件、seam 的红与绿、没做到的验收项、发现的 spec 外问题）。本仓已公开，不写账号、密钥、内网细节。
- spec 外的问题写进 JOURNAL，不顺手改。
- Demo 数据：验收场景在现有 Demo 里到不了时，可以加**启动参数开关的** Demo 场景；默认 Demo 首屏与现有 Demo 走查路径不得改变。

## 两条线与顺序

同一条线里后一张叠在前一张的分支上；两条线互不依赖，可并行。

| 线 | 顺序 | 工作树 | 为什么叠 |
|---|---|---|---|
| 一 | 085 → 087 → 088 | `MeetPR-wt-085`（依次切分支） | 088 建在 085 拆出的 Meet / Note to coach 两行上，并与 087 共用同一个列表行组件 |
| 二 | 086 → 089 → 090 | `MeetPR-wt-086`（依次切分支） | 三者都改训练页 hero 卡 |

拆成六张卡（多于默认的 1–2 张）的原因：六个 spec 各自有独立的验收清单、可以单独放行或单独退回，合并节奏不同。

## 进度（Opus 维护；交接只认这张表与各卡的 JOURNAL 一节）

| spec | 分支 | 卡 | 状态 |
|---|---|---|---|
| 085 | `feat/085-today-final-walkthrough` | `CARD-ios.md` | 未派 |
| 086 | `feat/086-training-strip-coach-note` | `CARD-ios.md` | 未派 |
| 087 | `feat/087-progress-menu`（叠 085） | `CARD-ios.md` | 未派 |
| 088 | `feat/088-profile-redesign`（叠 087） | `CARD-ios.md` | 未派 |
| 089 | `feat/089-accessory-quick-log`（叠 086） | `CARD-ios.md` | 未派 |
| 090 | `feat/090-training-flow`（叠 089） | `CARD-ios.md` | 未派 |

## 收货（Opus）

每张卡：亲读全量 diff；动到的包 `swift test` 全量；`MeetPR-DemoStudent` 上模拟器逐项过该 spec 的验收清单（Light / Dark、英文 / 中文、最小屏 + 大字号），含「带历史的老用户升级后第一屏」；Standards 与 Spec 两轴分开记；缺口回 Codex 返修，最多两轮。收货记录写 `specs/<spec>/ACCEPTANCE-ios.md`。
