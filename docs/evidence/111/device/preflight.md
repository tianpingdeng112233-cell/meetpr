# spec 111 iOS 真机前置取证（2026-11-17）

以下先记录初始前置失败，后续变化见末尾；功能结论及已取得截图/录像以同名验收报告为准。

- 验收代码：`origin/release/1.0@fe90f8a7`，包含 #480 合并 `9001234d`。
- 独立 worktree：`rest-ring-device-ios/MeetPR-release`；主树已有修改未动。
- XcodeBuildMCP `device list`：Tianping的iPhone，iPhone 12，iOS 26.5（23F77）。
- `devicectl device info details`：`developerModeStatus=enabled`、`pairingState=paired`、`transportType=localNetwork`、`tunnelState=disconnected`、`ddiServicesAvailable=false`。
- 查询 `com.meetpr.app` 现装版本失败：`CoreDeviceError 10003 / RemotePairingError 1016`，原文 `The device has not been unlocked recently`。因此不能把用户口述 TestFlight 包号补成已核实版本。
- QuickTime「新建影片录制」设备菜单仅有 iPhone 连续互通相机与 Mac 摄像头，没有 USB iPhone 屏幕源；未录制摄像头。
- vivo 设备使用权、iPhone 解锁与安卓本人签名已通过本会话异步请求交 David；未收到完成确认时不推断已完成。

## 构建环境排障

复现：XcodeBuildMCP device build，MeetPR / Debug，DerivedData 在本聊天 Documents/work 下；Widget CodeSign 报 `resource fork, Finder information, or similar detritus not allowed`。

缩小：单独重放同一 Widget codesign 命令仍 exit 1；`xattr` 发现 `.appex` 上有 `com.apple.FinderInfo` 和 fileprovider 属性。只去掉该产物的 FinderInfo，同命令 exit 0；再次构建又出现同一失败。将本任务 DerivedData 移到非 Documents 的 worktree/work 后重建。没有修改产品源码、签名身份或凭证。

这是构建环境问题，回归信号为原 codesign / device build；不在业务 seam 添加无关测试。最终构建结果见报告。

## 后续恢复与再次中断

- David 解锁并切到训练日后，已核实现装 com.meetpr.app 为 1.0(40)，取得旧历史页与 11 月 14 日截图；同 bundle id 开发 build 41 覆盖安装成功，未卸载，取得首次 R0 截图和启动录像。
- 浅色提示修复基于 release/1.0，代码 PR #483；David 复看最终间距/箭头后回复「没问题了」。临时展示包只强制显示视图，不写设置；随后从正常源码重新构建并成功覆盖安装，恢复首次提示生命周期。
- 后续 QuickTime 画面黑屏，并明确提示「已停止录制，因为设备 Tianping的iPhone 已关闭或断开连接」。最终提示截图未取得，未将工具启动成功当作 UI 可见证据。
- 没有完成任何训练日；没有改写训练历史，没有读取账号凭证。
