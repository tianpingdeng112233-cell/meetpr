# MeetPR Demo Build

`MeetPR-Demo` 是 V0 TestFlight 前的本机演示 build。它用固定教练账号绕过真实登录，让审核和内测可以直接进入教练端规划流程，不依赖 backend。

## 运行方式

在 Xcode 里选择 shared scheme `MeetPR-Demo` 后运行 iPhone simulator。通过 XcodeBuildMCP 时，将 session defaults 指向：

```text
projectPath: MeetPR.xcodeproj
scheme: MeetPR-Demo
simulatorName: iPhone 17
```

普通调试真实 auth 时切回 `MeetPR` scheme。`MeetPR` scheme 仍使用 `NetworkingAuthRepository` 和 `TokenStore`，不会实例化 Demo repository。

## Demo 行为

Demo build 通过 `DEMO_MODE` 编译条件启用：

- `DemoAuthRepository` 的 signup/login/refresh 都返回固定 coach user 和固定 token。
- `DemoTokenStore` 启动即返回预置 access token、refresh token 和 `DemoUserSeed.coach`。
- `Session.bootstrap()` 因为 token 和 cached user 都存在，会直接进入 `.authenticated`，所以 app 启动后落到 `CoachRootView`。
- `save` 和 `clear` 是 no-op。当前 session 内调用 logout 后仍会被 `Session` 设为 anonymous；杀 app 重开后会再次读取预置 demo user 并回到 authenticated。

Demo 教练：

- name: 演示教练
- phone: 13800000000
- role: coach
- id: 00000000-0000-0000-0000-000000000001

## V0.1+ 处置

真 backend wiring 进入 V0.1+ 后，`MeetPR` scheme 继续走真实 auth；`MeetPR-Demo` 可保留给集成测试、Apple review 演示和离线 smoke test。若后续决定删除 demo mode，应同步移除 Demo repository、Demo token store、Demo scheme 和本文件。
