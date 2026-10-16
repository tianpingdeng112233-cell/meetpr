# MeetPR Demo Build

MeetPR 有**两端 demo**:教练 demo 与学员 demo。它们都是本机演示 build,用固定 demo 账号绕过真实登录、不依赖 backend,让 Apple 审核和内测能直接进到对应角色的主界面。两端共用 `DEMO_MODE` 编译条件,靠一个额外开关 `DEMO_USER_STUDENT` 区分落哪个角色。

## 两端对照

| 端 | scheme | configuration | 编译开关 | 启动落点 | demo 账号 |
|---|---|---|---|---|---|
| **教练** | `MeetPR-Demo` | `Demo` | `DEMO_MODE` | `CoachRootView` 今日 dashboard(规划在「编排」tab) | `DemoUserSeed.coach`(演示教练) |
| **学员** | `MeetPR-DemoStudent` | `DemoStudent` | `DEMO_MODE` + `DEMO_USER_STUDENT` | 学员端主界面(已绑教练 + 已完成 onboarding,直接落 4 个 tab:今日/训练/成长/我的) | `DemoUserSeed.coachedStudent`(演示学员) |

两个 scheme 都是 shared scheme(在 `MeetPR.xcodeproj/xcshareddata/xcschemes/` 里),各自 Run/Test/Profile/Analyze **全部绑死各自的 configuration**:`MeetPR-Demo` 恒用 `Demo`,`MeetPR-DemoStudent` 恒用 `DemoStudent`。

### ⚠️ 别串 configuration(强设错会静默出错角色)

角色不是 scheme 名决定的,而是 configuration 带的编译开关决定的:

- configuration `Demo` → 编译条件含 `DEMO_MODE`、**不含** `DEMO_USER_STUDENT` → 落**教练**。
- configuration `DemoStudent` → 在 `DEMO_MODE` 基础上**再加** `DEMO_USER_STUDENT` → 落**学员**。

正常按 scheme 跑就对(scheme 已绑对 configuration)。但如果**显式覆写 configuration**(例如通过 XcodeBuildMCP `session_set_defaults` 传了 `configuration`),就必须传和 scheme 匹配的那个:拿 `MeetPR-DemoStudent` 却把 configuration 强设成 `Demo`,`DEMO_USER_STUDENT` 开关消失,会**静默 build 成教练**——不报错,角色却错了。

露馅点:build 产物路径。验 appPath 含 `Demo-iphonesimulator`(教练)还是 `DemoStudent-iphonesimulator`(学员),一眼看出跑的是哪端。

## 运行方式

在 Xcode 里选对应的 shared scheme 后跑 iPhone simulator 即可(scheme 自带 configuration,无需手动选)。通过 XcodeBuildMCP 时,逐端把 session defaults 指向:

```text
# 教练 demo
projectPath: MeetPR.xcodeproj
scheme: MeetPR-Demo
configuration: Demo
simulatorName: iPhone 17

# 学员 demo
projectPath: MeetPR.xcodeproj
scheme: MeetPR-DemoStudent
configuration: DemoStudent
simulatorName: iPhone 17 Pro
```

(simulator 名是建议,不是硬约束;两端并排各占一个 sim 就能同时看。)

普通调试真实 auth 时切回 `MeetPR` scheme——它走 `NetworkingAuthRepository` + `KeychainTokenStore`,不会实例化任何 Demo repository。

## Demo 行为(`DEMO_MODE`)

两端 demo 共用同一套 `DEMO_MODE` 绕过登录机制:

- `DemoAuthRepository` 的 signup/login/refresh 都返回固定 demo user 和固定 token。
- `DemoTokenStore` 启动即返回预置 access token、refresh token 和 seed user。
- `Session.bootstrap()` 因为 token 和 cached user 都存在,直接进入 `.authenticated`,所以 app 启动后落到对应角色的 root view。
- `save` 和 `clear` 是 no-op。当前 session 内调用 logout 后仍会被 `Session` 设为 anonymous;杀 app 重开后会再次读取预置 seed user 并回到 authenticated。

落哪个角色由 `DEMO_USER_STUDENT` 决定,且这个开关在 **app target(`MeetPR`,即 `@main` 的 `MeetPRApp`)里读、不在 `AppShell` 包内读**:Xcode 不会把 app target 的 compilation conditions 传播给它的 SPM package 依赖,所以选中的 `demoUser`(coach 或 coachedStudent)是在 app target 决定后**注入下去**的。

## Demo 账号

**演示教练**(`DemoUserSeed.coach`):

- name: 演示教练
- phone: 13800000000
- role: coach
- id: 00000000-0000-0000-0000-000000000001

**演示学员**(`DemoUserSeed.coachedStudent`):

- name: 演示学员
- phone: +15550102400
- role: coachedStudent
- id: 02400000-0000-0000-0000-000000000101

学员 demo 的 seed(计划/训练日志/反馈/绑定/onboarding)在 `StudentKit` 的 `StudentDemoSeed` 里独立播种:已接受的师生绑定 + 已完成的 onboarding profile,让 BindGate 直接落到主 tab 界面(无向导、无输入邀请码);计划锚在当前训练周,训练 tab 打开即落在一个真实训练日。

> **两端不是同一对师生**:教练 demo 与学员 demo 各自跑在自己进程的独立 seed 上,并排开两个 sim 也**不跨端联动**——教练端的操作不会同步到学员端。演示学员绑定的教练是 `StudentDemoSeed.coachID`(`…0201`),并非演示教练本人(`DemoUserSeed.coach`,`…0001`)。

## Demo 刷新纪律(2026-07-13 起)

**demo == 最新内测包。** 以前 demo 挂在旁支上没人同步,导致"每次打开都落后好多版本"。现在根治:

- demo 随**每次切内测包**从**发版线现建**,由 `/prep-beta` 的 **step 8** 自动完成——纯模拟器 build、Claude 全自动,不碰真机/archive,tag 一确认好就能跑(不等 David 上传 ASC)。
- demo 专用 worktree = `~/Projects/apps/MeetPR-demo-latest`,detach 到本次切包的 beta tag / 发版线 tip(非破坏性,不动任何分支)。
- 旧旁支 `build/demo-latest` **已弃用**,别再往它并东西——demo 只跟发版线。

> 权威流程见 [`~/ClaudeConfig/skills/prep-beta/SKILL.md`](~/ClaudeConfig/skills/prep-beta/SKILL.md) step 8(含两端 scheme×configuration 对照表和 appPath 验证)。本文件只讲 demo build 是什么、怎么跑;什么时候刷、跟发布怎么挂,以 prep-beta 为准。

## 维护

若后续决定删除 demo mode,应同步移除:两个 Demo repository / Demo token store / `DemoUserSeed` / `StudentDemoSeed` 等 demo seed、`Demo` 与 `DemoStudent` 两个 configuration、`MeetPR-Demo` 与 `MeetPR-DemoStudent` 两个 scheme、prep-beta step 8 的 demo 刷新逻辑,以及本文件。
