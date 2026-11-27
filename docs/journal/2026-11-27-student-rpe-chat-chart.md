# 学员端 RPE 表头、反馈视频与图表日期

工作树 `fix/student-rpe-chat-chart`，HEAD 与本地 `origin/release/1.0` 同为 `44ab7fb1`。工作树内临时文件写入、读回并删除成功。17e 的占用状态由 David 在宿主机确认。DemoStudent 的目标 UDID 为 `5D5FA360-BA49-48C6-A887-2F0D22F89749`。

## C · 强度指标横轴

1. 强度指标页实际创建 `VolumeIntensityChart`。临时 Swift 探针直接编译该文件的 `VolumeChartGeometry` 和真实的 `WeeklyProgressMetric`，读取传给 `Text` 的首个 `dateLabels` 字符串。UTC 中午固定为 2026-11-22。运行 `.sf27-tmp/probe-chart -AppleLocale zh_Hans_CN -AppleLanguages '(zh-Hans-CN)' 11/22`，输出 `locale=zh_CN buckets=2 axis=22/11 expected=11/22`，退出 1。
2. 同一二进制重跑结果相同。只删除第二个数据点（`--one`），两次均为 `locale=zh_CN buckets=1 axis=22/11 expected=11/22`，退出 1；英国对照输出 `locale=en_GB buckets=1 axis=22/11 expected=22/11`，退出 0。一个日期即可暴露倒置，无须拉取训练历史或渲染整页。
3. 最小化完成后、检验因果之前记录了以下排序。

| 排名 | 假设 | 可证伪预测 |
|---|---|---|
| 1 | 标签代码手动把日放在月之前 | 仅将标签组合换为随地区格式化同一个日期，中国会得到 11/22，英国仍为 22/11。 |
| 2 | 中国地区没有传到标签所用的格式器 | 仅显式把中国 locale 传给现有数字格式器，应能恢复月在前。 |
| 3 | 传入标签的日期或日历分量与样本不符 | 若是输入问题，仅把标签输入固定为已核对的公历 11 月 22 日即可恢复月在前。 |

4. 在探针内保持相同日期、日历、数据和启动参数，仅把标签的组合表达式换为 Foundation 双位月日格式。中、英各跑一次，分别得到 `11/22` 与 `22/11`（退出 0）。这证实排名 1。实际页面的旧实现先插入 day、再插入 month，地区只参与各数字的格式化。
5. 生产入口将 SwiftUI 的 `locale` 传入几何对象的标签方法。保留旧标签组合时先跑 `swift test --package-path Modules/StudentKit --filter volumeChartDateLabelsFollowRegion`，中国断言报 `"22/11" == "11/22"`，1 个测试失败。改用双位月日的本地化日期格式后通过。再跑第 1 步完整双数据点探针，中国 `axis=11/22 expected=11/22`，英国 `axis=22/11 expected=22/11`，均退出 0。

## A · RPE 对照表顶部 e1RM

先将原有表头表达式原样移至 `RPETable.headerText(e1RM:unit:)`，页面通过此入口展示。首次编译期间 C 的源文件正在改动，该次编译中止；等待源文件稳定后重跑。修前 `swift test --package-path Modules/StudentKit --filter RPETableHistoryTests` 执行 2 个测试，表头测试中两条 kg 断言失败，实际为 `178.3479349186484224` 与 `114.19753086419750912`。原 kg 显示路径直出 Decimal 的完整字符串。

修复后先按所选单位换算，再复用 `StudentFormatting.decimal` 的 0 至 1 位小数格式。表格格值和 e1RM 曲线继续各走原入口。回归覆盖两组非整 kg、整数 kg、两组非整 lb、换算后舍入为整数的 lb 和百分比回退。定向命令 `swift test --package-path Modules/StudentKit --filter 'RPETableHistoryTests|volumeChartDateLabelsFollowRegion'` 通过 3/3（包含原有历史数据测试）。

本次沙箱调用 SwiftPM 时，使用本工作树内的 scratch、模块和依赖缓存，并离线复用本机已有 ViewInspector 镜像。首次默认依赖解析失败，报 `Failed to connect to 127.0.0.1 port 18083`。以上红绿均来自 Swift Testing 断言。

## B · 反馈视频关闭后对话左移

1. 17e 实际进入教练 tab，上滑至反馈卡，打开低杠位深蹲视频，等播放进度到 `0:14 / 0:14` 后关闭。每次用 XcodeBuildMCP 截取打开前、关闭后、切成长再回教练的画面。仓内没有 MeetPRUITests target，使用一次性无人值守截图环。对 369 px 宽截图测卡片实体左缘：在对话区多条贯穿白色反馈卡的扫描线上取卡片起始横坐标的中位数；前后差超过 1 px 即失败，找不到卡片则报采样失败。截图中还人工核对了卡片、文字和时间戳。此量测单位是截图像素。

   原有安装先尝试提前关闭，再完整播完并切 tab。两次左缘都为 17 px。本工作树重新构建、安装 DemoStudent 后，又做 3 次完整循环，3 次均看到片尾。每轮运行 `python3 .sf27-tmp/chat-edge.py .sf27-tmp/build-bN-pre.png .sf27-tmp/build-bN-post.png`，再用 `-tab.png` 比较切页返回的结果（N 为 1 至 3）。

   | 轮次 | 打开前 | 关闭后 | 切 tab 返回 | 两次差值 |
   |---|---:|---:|---:|---|
   | 1 | 17 px | 17 px | 17 px | 0 / 0 px |
   | 2 | 17 px | 17 px | 17 px | 0 / 0 px |
   | 3 | 17 px | 17 px | 17 px | 0 / 0 px |

2–6. 本环境第 1 阶段未取得命中原症状的红例。根因未定，保留聊天和播放器原实现。

| 假设排名 | 理由 |
|---|---|
| — | 依任务卡，复现命令实际跑红后才进入第 3 阶段。 |

## 17e 视觉验收

| 单位 | 深蹲 | 卧推 | 硬拉 |
|---|---:|---:|---:|
| kg | 178.3 | 114.1 | 178.5 |
| lb | 393.2 | 251.5 | 393.5 |

六个表头都与单位同处一行。修前另在 17e 读到深蹲表头 `178.34793491864840192`。kg 使用默认 DemoStudent，lb 使用现成的 `-spec085-profile other-lb`。e1RM 曲线页同一组数据仍显示深蹲 178.3、卧推 114.1、硬拉 178.5 kg，合计 470.9 kg。

C 第 6 阶段：默认 Demo 只有两次训练，强度页显示「完成 3 次训练后解锁趋势」。用已有的 `-spec087-progress multiweek` 启动同一 App，配合下面两组启动参数，在 17e 打开成长下的三个入口并核对截图。

| 页面 | 中国（`-AppleLocale zh_Hans_CN -AppleLanguages '(zh-Hans-CN)'`） | 英国（`-AppleLocale en_GB -AppleLanguages '(en-GB)'`） |
|---|---|---|
| 强度指标 | 可见 11/01、11/15；轴文本含 11/22 | 可见 02/11、16/11；轴文本含 23/11 |
| E1RM 合计 | 11/06 | 06/11 |
| E1RM 深蹲 | 11/6、11/13、11/20 | 11/6、11/13、11/20 |
| 体重 | 10/29、11/27 | 29/10、27/11 |

中国三页均为月在前。英国的单项 E1RM 是已有的固定月/日显示（`GrowthE1RMCard.swift` 内的 `GrowthChartGeometry.monthDay`）；与同页按地区显示日期的合计曲线不同，本卡保留了其原行为。其余两页英国均为日在前。

本工作树的截图保存在 `.build/sf27-evidence/`（本机验收用）：`rpe-all.png`（上 kg、下 lb），`charts-cn.png`、`charts-gb.png`（强度、合计、深蹲、体重），`chat-before-after-tab.png`（打开前、关闭后、切 tab 返回）。

附加 locale 对照：同一个 11 月 22 日输入，`zh_Hans`、`en_CN` 均得到 `11/22`。对「简体中文语言 + 英国地区」按卡中英国跟随系统的验收口径处理，`zh_Hans_GB` 得到 `22/11`。

## 测试和清理

- 宿主机通过 XcodeBuildMCP 调用 `swift test --package-path Modules/StudentKit`，最终版本 **1374/1374**，跳过 0。沙箱直接跑同包全量时，视频测试报 17 个媒体编码问题（`Cannot Encode`、`HEVC writer start failed`）；宿主机使用同一工作树后全绿。将 C 回归日期固定到当地正午，并以 `TZ=Pacific/Auckland` 重跑两个相关测试入口，3/3 通过。
- `swiftlint lint --strict --no-cache`、`xcrun swift-format lint --strict` 核对五个改动的 Swift 文件均通过，`git diff --check` 通过。
- DemoStudent 原始命令如下。17e 发现 10 个主工程测试，在链接阶段失败，实际执行 0 个。缺少 `InMemoryVideoMarkerRepository` 和 `PendingVideoItem` 符号，与既有 2026-10-24-096-B JOURNAL 中记录的 Demo 链接问题相同。

```sh
xcodebuild test -project MeetPR.xcodeproj -scheme MeetPR-DemoStudent \
  -configuration DemoStudent -destination 'platform=iOS Simulator,id=5D5FA360-BA49-48C6-A887-2F0D22F89749' \
  -derivedDataPath "$PWD/.sf27-build" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
```

同一条命令追加 `-xcconfig "$PWD/.sf27-tmp/demo-test.xcconfig"` 后，17e **9/9** 通过，0 失败、0 跳过。发现列表另含仅在 `COMPLETION_HANG_PROBE` 条件下编译的旧探针。临时配置只给 MeetPR 主目标显式链接本次测试已构建的 RepositoryContracts framework，内容如下，验证后已删除。工程设置保留原值。

```xcconfig
OTHER_LDFLAGS = $(inherited) $(SF27_TEST_LINK_$(TARGET_NAME))
SF27_TEST_LINK_MeetPR = -framework RepositoryContracts_511EB1C754131204_PackageProduct
```

代码和本卡改动内的临时日志前缀扫描为 0。全树文字搜索仅命中原任务卡第 43、52 行的说明。已清除本次反馈环、临时链接配置和构建缓存；保留上列本地截图。工作树未暂存、提交或推送。

```text
 .../Features/TrainingHistory/RPETable.swift        |  6 ++++++
 .../Features/TrainingHistory/RPETablePage.swift    |  6 ++----
 .../TrainingHistory/VolumeIntensityChart.swift     | 23 ++++++++++------------
 .../TrainingHistory/ProgressMetricsTests.swift     |  9 +++++++++
 .../TrainingHistory/RPETableHistoryTests.swift     | 10 ++++++++++
 5 files changed, 37 insertions(+), 17 deletions(-)
```

上表是 `git diff --stat` 的已跟踪文件统计。JOURNAL 为本次新增，任务卡在开工前已是未跟踪文件。
