# 094-iOS 开发证据（待收货）

工作树 `MeetPR-wt-094-zh-hant`，分支 `feat/094-zh-hant`，基线 `6c5466a0`。开工已在本根创建并删除临时文件，未换 checkout。

## 最终实装

- 依据 CARD、SPEC、GLOSSARY v2.1、AMEND-v2 与 AMEND-header。10 个 xcstrings 共 2344 key、权限 InfoPlist、目录动作展示表、繁简输入映射由固定 OpenCC 0.1.7 与覆写表生成。OpenCC LICENSE/NOTICE 随生成资源保留。
- zh-Hans/en 本地化树与基线一致；原动作 catalog 字节不变；原 61 条 alias 不变，按返修卡追加 17 条，共 78 条。
- 课表、反馈、杆类术语按 v2.1 生成；reps 语境使用 55 个显式 key 转换为「下數／下」，完整列表见 JOURNAL 与 `scripts/zh-hant/reps-keys.json`。次数频率、重试、上次等不转换。
- 目录动作展示、双字形及台湾别名搜索、数字规格括号消除、既有中文导入繁简规范化、週字星期与提醒。完整 Exercise 的来源标志传到训练行、组卡候选、待看影片，保护同名自建动作。
- APIClient、RealtimeClient、EventFlusher 使用 `X-MeetPR-Locale`，当前界面语言来自 `Bundle.main.preferredLocalizations.first`。不手动覆盖平台 `Accept-Language`；不改第三方 OAuth/OSS 请求。
- AMEND-v2 第 3 项「2下@8。80%」和 Excel 表头仅面向网页，未扩入 iOS。

## 可复现验证

```sh
python3 -m venv .build/zh-hant-tools
.build/zh-hant-tools/bin/pip install -r scripts/zh-hant/requirements.txt
.build/zh-hant-tools/bin/python scripts/generate-zh-hant.py --check
.build/zh-hant-tools/bin/python -m unittest discover -s scripts/zh-hant -p test_generation.py
swift test --package-path Modules/CoachKit --parallel --enable-code-coverage --disable-sandbox --disable-build-manifest-caching --cache-path .build/spm-cache --scratch-path .build/ci-tests
```

九包按 CI 的 `--parallel --enable-code-coverage` 逐包执行，替换上例模块名。额外参数用于环境限制：禁用嵌套 sandbox-exec、避免 manifest 缓存遗漏新增源文件；不修改测试或跳过用例。原始日志在 `.build/094-tests/`、`.build/094-v2-tests/`，本目录 `*-results.txt` 保留结果与失败断言摘录。

变更 Swift 文件执行 `swiftlint lint --strict --config .swiftlint.yml <files>` 和 `xcrun swift-format lint --strict --configuration .swift-format <files>`；40 文件均通过。生成器检查、4 个 Python 回归及 `git diff --check` 通过。

主工程使用 XcodeBuildMCP `test_sim`：MeetPR / Debug，指定 iPhone 17 Pro Max，`-enableCodeCoverage YES`，`-clonedSourcePackagesDirPath .build/xcode-packages`，`-resultBundlePath DerivedData/094-main-final-tests.xcresult`；最终 9 项通过。

## 九包结果

| 包 | 最后全量结果 | 说明 |
| --- | --- | --- |
| Analytics | 30 通过 | 最终自定义语言头 |
| AppShell | 118 项，2 个测试失败、3 个 issue | Keychain 写入受限；最小探针 `SecItemAdd: 100001 UNIX[Operation not permitted]` |
| ChatUI | 84 项，视频编码测试失败 | `AVFoundationErrorDomain -11800 / NSOSStatus -12903` |
| CoachKit | 480 通过 | v2.1、别名 78、历史 matcher 修复后 |
| CoreModels | 160 通过 | v2.1 |
| DesignSystem | 74 通过 | 全目录结构、占位符、简体特有字检查 |
| Networking | 141 通过 | 最终 API/WebSocket 自定义语言头 |
| RepositoryContracts | 6 通过 | 本卡接口变更后 |
| StudentKit | 1036 项、15 个 issue | 最后重跑仅视频导出相关问题 |

不能宣称九包全绿。StudentKit 初轮 33 issue 含上传超时，独立上传测试通过，最终全量已无上传超时。视频裁剪独跑仍失败。AppShell 先前已启动的 MCP 独立 Keychain 测试最后返回 2 项通过，仅说明不同进程环境表现不同，不替代全包结果。探针确认权限拒绝后未尝试绕过。

## 红绿与双轴审查

- `catalog/search/network/presentation-{red,green}.log` 是初轮 TDD，network 初轮针对当时的 Accept-Language 契约，已被下述返修替代。
- v2 生成回归先红（2 个断言失败及缺 key 参数），台湾别名先红（18 个断言）；修复后 Python 4 项、CoachKit 480 项全绿。原始日志在 `.build/`；全部为合成夹具。
- header API/WebSocket 红阶段 3 测试 75 issue；analytics 红阶段 1 测试 4 issue；实现后对应全量 141／30 通过。默认请求不设置 Accept-Language，调用者显式原值保留。
- 来源保护、tempo、Demo 待看影片来源、zh-Hans-TW 显式脚本优先都有回归。Demo 测试最初 Optional 编译错误修正后，才记录有效行为红例。
- Standards：同名自建动作初轮问题已修，最终定向 CLEAN。Spec：历史搜索、tempo、Demo 来源、别名计数均修复，最终定向 CLEAN。两位 reviewer 只读复核；不替代 Opus 正式验收。

## 亲眼核对的模拟器截图

同一独立 iPhone 17 Pro Max / iOS 26.5（`2B4DCD56-C0EB-4762-914A-1487A67196BA`），启动参数 `-AppleLanguages "(zh-Hant)" -AppleLocale zh_TW`。

- [学员今日训练](student-today-zh-Hant.jpg)：MeetPR-DemoStudent / DemoStudent；「硬舉」「下數」「週三」显示正常，教练备注保持原文。最终自定义语言头实现后构建。
- [教练首页](coach-home-zh-Hant.jpg)：MeetPR-Demo / Demo；「影片」「反饋」「本週概況」显示正常，用户姓名保持原文。v2.1 构建，随后仅请求头与资源归属说明变化。

本卡构建使用本树 `.build/094-simulator`，只在命令行指定 `SWIFT_OPTIMIZATION_LEVEL=-Onone SWIFT_COMPILATION_MODE=incremental`；未改工程优化配置。早期 Demo 构建超过 MCP 300 秒上限但最终成功，期间同缓存重试曾遇 build.db locked。最终增量构建教练 18.8s、学员 27.6s 通过。

## 待裁决与交付限制

1. SetRefV1 历史快照和 CoachFeedbackVideo 只有名称，无法区分目录动作与同名用户动作；现保持原文。保护用户内容与全覆盖要求的边界已提问，尚无裁决。
2. 九包未全绿，具体失败如表；不跳过、不宣称验收通过。
3. 初次部分资源暂存成功，后续 Git 写入被拒绝：`fatal: Unable to create '/Users/david/Projects/apps/MeetPR/.git/worktrees/MeetPR-wt-094-zh-hant/index.lock': Operation not permitted`。未绕过权限；无新 commit。后续两份 AMEND 已明确不 commit，保持当前工作区供收货。
4. GLOSSARY/SPEC 与两份 AMEND 是外部 Opus 更新，未覆盖；旧 CARD 中 aliases 不变与 Accept-Language 的要求已由 AMEND 覆盖。未改 NEXT-RELEASE、build 号、tag，未 push、未开 PR。

后续有 Git 写权限的交付会话应按逻辑原子提交，并在每笔末行保留 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。
