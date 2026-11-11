# 087 第二步：iOS 体重页

- 工作树：`MeetPR-wt-087w`；分支：`feat/087-weight-page`；起点：`67c5dde0`。
- 授权：David 直驱；T2 / P1；不 commit / push。后端 spec 046 只读；不改发布台账。
- 需求：成长页第 4 行、体重曲线与记录列表、删除、复用现有单项体重输入；Today / Profile 接新写入接口，404 回落旧档案接口。
- 正典：`specs/087-progress-menu/SPEC.md` §5、决策 2/7/8/9/10、入口第 4 行；后端 `MeetPR-backend-wt-046/specs/046-body-weight-records/SPEC.md` §2–3。
- 测试 seam：Networking DTO / Repository；体重页 presentation；入口行格式。保存日期取设备本地日历日，不用训练日界线；Profile 未改体重不产生记录。

## 交付状态

实现与开发自测已完成，工作区未提交，待 Opus 按 spec 收货；不把本记录视为产品验收结论。重启后先核对 git status 和本 JOURNAL，保留此前 DTO 与测试改动继续执行。此前磁盘耗尽导致的中断不再阻塞本轮。

### 实现

- Networking 新增体重 GET / PUT / DELETE 与 DTO；日期保持 `YYYY-MM-DD` 字符串，重量按 Decimal 解码，PUT 两位小数字符串；DELETE 正确处理 `current_weight_kg: null`。
- StudentKit 的 `BodyWeightRepository` 由现有 Backend / InMemory onboarding repository 实现。写入时取设备 Gregorian 本地日历日；仅新 PUT 的 HTTP 404 回落旧 onboarding PUT，其他错误正常返回。
- 成长页第 4 行独立读取最新记录；加载中不闪旧档案值，空数据或接口失败显示 `—`，体重读取失败不影响其余行。下拉刷新包含体重。
- 新体重页复用既有导航、DesignSystem、Swift Charts：30 / 90 天 / 历史总览，最新值、灰色带符号变化量、曲线首尾日期、单点提示、倒序列表、删除确认与失败重试、空态和页面失败重试。
- Today 体重卡和本页按钮继续进入现有单项输入；Profile Basics 仅体重相对编辑开始时改变才写今天。`BodyWeightInput.swift` / `BodyWeightField.swift` 已先读，保持原有输入、精度与单位换算行为；首次 onboarding 的旧写入口保持原接口。
- 成功写入 / 删除通过按 student ID 限定的通知刷新已保留的 Today、Profile 和成长页；删除最新回退，最后一条删完清空当前体重。档案读取加请求版本检查，避免较早响应覆盖新状态。
- 新增文案提供 zh-Hans / en / zh-Hant。无新增依赖，无 pbxproj / 导航结构 / 后端 / 发布台账改动。

### 先红后绿

新增 17 个 Swift Testing 测试函数（含参数化用例），调整已有入口导航测试。逐个 seam 补测试，再补对应实现：

| Seam | Red | Green 覆盖 |
| --- | --- | --- |
| DTO | 缺少 records / write / delete DTO，编译失败 | 日期、Decimal 字符串、删除最后一条 null |
| Repository 写入 | 缺少 `saveTodaysWeight`、时钟 / 时区注入 | 新 PUT 404 后旧 PUT、400/401/403/500 不回落、两位小数请求、本地日历日及 UTC−12/+14 边界 |
| Repository 读取 / 删除 | 缺少 fetch/delete 方法 | wire 路径、删除返回当前值、重取无旧缓存；实际 GET 404 映射失败 / `—` |
| Presentation / ViewModel | 缺少 presentation / model；旧 demo 写入联动测试有 2 个断言失败 | 曲线升序、列表倒序、30/90/全部、范围边界、单点 / 空态、最新值不随范围消失、同日覆盖、删最新 / 删最后、失败保留记录 |
| 写入口径 / 入口 | 缺少 `saveCard` 和第五行 | Basics 未改体重不记、单项输入总记今天、已改覆盖今天；两位小数与 `—`；五行顺序及可导航 |
| 审查回归 | 缺少 `retryDelete`；乱序 GET 的两个参数化分支实测失败 | 重试始终删除原失败记录；Today / Profile 忽略删除前启动、删除后才返回的旧档案 |

原始 Red 日志在 [red-green](../../scratch/087-weight-page/red-green/)；乱序响应独立 [Red](../../scratch/087-weight-page/stale-profile-red.log) / [Green](../../scratch/087-weight-page/stale-profile-green.log)。完整 Green 见下表。

### 最终验证

| 检查 | 结果与证据 |
| --- | --- |
| `swift test --package-path Modules/Networking`（XcodeBuildMCP） | **153 passed**，0 failed；[日志](../../scratch/087-weight-page/networking-test.log) |
| `swift test --package-path Modules/StudentKit`（XcodeBuildMCP） | 最后一次视图修复后 **1227 passed**，0 failed；[日志](../../scratch/087-weight-page/studentkit-test.log) |
| App build / run | `MeetPR.xcodeproj` / `MeetPR-DemoStudent` / iPhone 17e / iOS 26.5；最终 **SUCCEEDED**，0 warning；[日志](../../scratch/087-weight-page/app-build.log) |
| lint / format | 25 个本卡 Swift 文件，`swiftlint lint --strict` 和 `xcrun swift-format lint --strict` 均 exit 0；[lint](../../scratch/087-weight-page/lint.log)、[format](../../scratch/087-weight-page/format.log) |
| diff | `git diff --check` 通过；未 commit / push |

模拟器全程仅 `iPhone 17e`，UDID `5D5FA360-BA49-48C6-A887-2F0D22F89749`。DerivedData `/private/tmp/meetpr-087w-derived`；bundle `com.meetpr.app`。没有新建或使用其他模拟器。

### UI 原始证据（均已亲看）

截图目录：[scratch/087-weight-page](../../scratch/087-weight-page/)。DemoStudent 内存数据，不操作真实账号。

| 截图 | 核查 |
| --- | --- |
| [01-growth-weight.jpg](../../scratch/087-weight-page/01-growth-weight.jpg) | 深色成长入口，第 4 行 `83.00 kg`，原四行保留 |
| [02-weight-single.jpg](../../scratch/087-weight-page/02-weight-single.jpg) | 单条历史回填示例，单点与提示、记录按钮 |
| [03-weight-records.jpg](../../scratch/087-weight-page/03-weight-records.jpg) | 最终深色多条曲线，`81.00` / `−2.00`，首尾日期、最新实心点、倒序列表、修改今天按钮 |
| [04-weight-empty.jpg](../../scratch/087-weight-page/04-weight-empty.jpg) | 实际逐条删除后零记录，当前体重为空，仍可记录今天 |
| [05-growth-empty.jpg](../../scratch/087-weight-page/05-growth-empty.jpg) / [06-today-cleared.jpg](../../scratch/087-weight-page/06-today-cleared.jpg) | 删最后一条后入口 `—`，Today 未填写 |
| [07-weight-records-final-light.jpg](../../scratch/087-weight-page/07-weight-records-final-light.jpg) / [08-growth-final-light.jpg](../../scratch/087-weight-page/08-growth-final-light.jpg) | 最终浅色多条页与入口 |
| [09-growth-large-light.jpg](../../scratch/087-weight-page/09-growth-large-light.jpg) / [10-weight-empty-large-light.jpg](../../scratch/087-weight-page/10-weight-empty-large-light.jpg) | 中文 XXXL 系统字体、浅色入口空值 / 页面空态 |
| [11-weight-single-large-light.jpg](../../scratch/087-weight-page/11-weight-single-large-light.jpg) / [12-growth-value-large-light.jpg](../../scratch/087-weight-page/12-growth-value-large-light.jpg) | 中文 XXXL 下记录今天成功，`82.00 kg` 和单点状态，无文字重叠 |

实走：默认种子仅 2026-01-13 的 83 kg → 本页记今天 82 kg → 同日改为 81 kg（仍仅两行）→ 删今天回退 83 kg → 删旧记录清空 → Today 卡重新写 82 kg。另在最终构建中，Profile Basics 仅改身高（滚动生日控件时也改变了生日）保存后仍仅旧体重记录，见 [快照](../../scratch/087-weight-page/profile-unchanged-weight.txt)；随后改体重为 81 kg，成长页出现今天记录。删除确认取消后记录不变。

大字截图参数：`-meetpr.appearance light -UIPreferredContentSizeCategoryName UICTContentSizeCategoryXXXL`；空档案复用既有 `-spec085-profile empty-weight`。仅使用 iPhone 17e 的实际尺寸；未声称完成 Web 的 360×640 / jest / tsc 验收。

### 自审与独立审查

- 按 code-review / review-loop 进行只读双轴审查。仓内缺 `docs/agents/issue-tracker.md`，本轮用独立本地 review-loop，不创建 tracker 配置；已告知该专属流程需 `$setup-matt-pocock-skills`，不阻塞本卡。
- **Standards**：发现删除失败后再次选择其他记录可能使重试目标改变。移入 ViewModel 保存失败目标、无参 `retryDelete()`，回归测试通过；复审 **CLEAN**。
- **Spec**：发现成长下拉刷新漏取体重、保留页的旧档案请求可晚到覆盖新状态。补刷新和请求版本保护，乱序回归先红后绿；复审 **CLEAN**。编辑基线改为 `@State` 的定向复审同为 **CLEAN**。
- UI 自测发现 Swift Charts 自动省略曲线末尾日期；将首尾轴标签朝图内锚定。重新构建、回归、深浅色截图确认两端均可见；Standards 定向复审 **CLEAN**。

### 收货边界

本卡的网络故障 / 404 回落由真实 APIClient + 注入 Transport 的 Repository 测试覆盖，页面重试由 ViewModel 测试覆盖；未连接 staging 做体重接口联调，未部署后端、执行迁移或验证真实老账号回填。spec 验收第 19 条中的后端迁移、以及两端总体放行仍由后端证据与 Opus 收货确认。RELEASES / NEXT-RELEASE / SPEC 状态未改。
