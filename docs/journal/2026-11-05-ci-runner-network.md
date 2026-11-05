# iOS CI 网络修复与海外镜像暂停（运维证据）

## 范围

David 2026-11-05 授权暂停海外镜像 workflow，并修复 iOS 网络超时。没有修改 App、测试门禁、依赖版本或发版线代码。当前基线 `dfc67e368a66e16b913686b7b5dc75dac373f9e0`（release/1.0）。

## 现场与定位

- 海外 workflow：backend `.github/workflows/build-push-global.yml` 的 doctl 验证 `DO_ACCESS_TOKEN` 返回 401；运行 41782292497、41781805800、41455214763 均同样失败。仅停用此 workflow，回读 state=`disabled_manually`。国内 CI 和 ACR 保持启用。恢复命令：`gh workflow enable build-push-global.yml -R tianpingdeng112233-cell/MeetPR-backend`。
- iOS 原网络失败：run 41778531606 / job 126404443188、run 41411283354 / job 125765577432，SwiftPM 拉取 ViewInspector 连 GitHub 443 超时（约 75 秒/次）。
- 最小复现：在子进程移除所有代理环境变量后执行 `git ls-remote https://github.com/nalexn/ViewInspector.git HEAD`，两次均 12 秒超时；仅加入当前正常工作的本机代理后分别 2.2s、2.1s 返回同一 HEAD。
- 假设排序：① launchd runner 没继承 shell 代理；②代理自身不稳；③SwiftPM 缓存坏。runner 实际进程无代理，`.env` 为空，launchd 只含 ACTIONS_RUNNER_SVC；差分探针支持①。

## 操作

- 在 runner 应用目录 `.env` 持久设置 lowercase `http_proxy`、`https_proxy` 指向已运行的本机 HTTP 代理 `http://127.0.0.1:18083`，`no_proxy=localhost,127.0.0.1,::1,.local`。该代理由既有 launchd 服务管理，未改变路由配置。
- 原 `.env` 已备份到`/Users/david/Documents/Codex/2026-11-05/zui-j/work/ci-fixes/runner.env.before`；文件权限 0600。回滚：恢复备份，在 runner 无任务时重启服务。
- GitHub API 确认 runner online/busy=false，且无 Runner.Worker 后重启既有服务；保留 SessionCreate、签名、钥匙串和模拟器配置。
- 启动日志 `Runner_20261105-041350-utc.log` 明确记录配置 HTTP/HTTPS 代理，04:14:01Z Listening for Jobs。
- 从空代理子环境仅加载新 `.env` 后，ViewInspector、CoreXLSX 两个 `git ls-remote ... HEAD` 均返回 0。
- 配置方式依据：https://docs.github.com/en/actions/how-tos/manage-runners/use-proxy-servers#using-a-env-file-to-set-the-proxy-configuration 。

## 附带发现与验证

最新 run 41963179738 的失败已变为磁盘耗尽，独立于上述网络失败。现场可用空间约 4GiB。为完整 CI 重跑只清理已确认工作树干净、无打开文件、至少一天未动且 git 不跟踪的 `.build` 缓存（095/098/100；另补清 056-load-types 中超过 7 天的缓存，为 Xcode 阶段预留空间）；不清理模拟器、源文件、用户数据或正在使用的工作树。

清理后可用空间恢复到 9.5GiB。原网络失败 run 41778531606 已重跑，工作进程确认继承三项代理变量；AppShell 的 ViewInspector / CoreXLSX 分别 5.13s / 5.08s 拉取成功，ZIPFoundation / XMLCoder 也成功。九个 Swift 包 2219 tests 与主工程 9 tests 全部通过，Xcode 输出 `TEST SUCCEEDED`；SwiftLint 与 swift-format 也通过。证据：[原失败 run 的修后重跑](https://github.com/tianpingdeng112233-cell/meetpr/actions/runs/41778531606/job/127046270255)。

独立 review-loop 配置审查一轮：Standards CLEAN（0），Spec CLEAN（0 blocker）。审查覆盖 `.env` 与原备份、持久化、作用域和回滚，不把配置审查等同于 CI 绿。代理不可用时网络仍可能失败；本次修复解决服务遗漏代理这一确定原因，不承诺外部网络永不故障。
