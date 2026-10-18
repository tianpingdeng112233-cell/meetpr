# Spec 093 iOS 收货记录（#366 + 返修 #367 / #368）· 2026-10-18

依据：meetpr-rn `specs/093-coach-beta-onboarding/SPEC.md`、`CARDS.md`、`IOS-HANDOFF.md`「验收（iOS 侧）」。收货人 Opus；真机项由 David 在 iPhone 12 上实测。

## 结论

**通过，可随 1.0(25) 上车**，但发 TestFlight 前有一道发包顺序闸门（见末节）。

## 证据

- 全量 diff 亲读（`f2d44394..06bf0e6d`，50 文件）。
- 本机 `swift test --package-path Modules/<module>`：AppShell 116、Networking 139、CoreModels 159、CoachKit 456、StudentKit 1021，共 1891 通过（#366 落线版）。返修后 AppShell 118、StudentKit 1023。#367 / #368 PR CI 三项全绿。
- CN Release 配置真机编译安装（`com.meetpr.app`，后端 `http://121.40.160.241:3000`），覆盖 TestFlight 1.0(24) 安装。
- 模拟器截图：[spec093-2026-10-17](evidence/spec093-2026-10-17/README.md)、[093-login-keyboard](evidence/093-login-keyboard/README.md)、#367 双轨绑定页。

## 验收清单逐项

| 项 | 结果 | 依据 |
|---|---|---|
| CN 全程无手机号输入、无 Apple / Google 按钮；中文系统下三屏除口号与字标外无英文 | 通过 | diff + 模拟器截图 + 真机 |
| 真邮箱注册收中文验证码 → 进入绑定教练 | 通过 | David 真机实测，验证码信未进垃圾箱（只测了一家邮箱，QQ / 163 分别验未做） |
| 错码、过期码、两次密码不一致有提示且不建号 | 通过（单测 + 截图） | `ChinaEmailRegistrationTests`；真机未逐一试 |
| 找回密码：收码 → 改密 → 新密码登录 | 通过 | David 真机实测 |
| 老账号邮箱 + 原密码登录看到原数据 | 通过 | B0 阶段 David 已确认（backend #298） |
| 从 1.0(24) 升级的已登录老用户直接进主界面 | 通过 | David 真机实测：TestFlight 24 登录后装新包，未掉登录 |
| 粘贴整段邀请消息或链接能填对码；教练复制出的消息链接与码正确 | 通过（模拟器） | 截图；真实 staging 绑定持久化未验 |

## 收货中发现并已修

- **Standards / 交付红线**：#366 把学员绑定页「粘贴」按钮限成仅 CN，删掉了 1.0(24) 已在 Global 上线的按钮 → #367 恢复（Global 原文案，CN「粘贴邀请码」）。
- **真机缺陷**：CN 登录页四行口号把表单挤到底部，键盘遮挡输入框且页面不能滚 → #368 三屏共用滚动容器，聚焦字段自动滚入可视区；David 真机复测通过。模拟器未复现「完全不能滚」，根因未点名。
- **David 改文案**：CN 口号改为「Meet Your / PR Here.」（#368，安卓 meetpr-rn#96 同步）。

## 未验到

- 真实 staging 上的邀请码绑定与教练接受全链路（依赖 backend #299 / plan-web #110 部署）。
- 键盘上方的系统密码自动填充仍提示老的手机号凭据，对邮箱框无效，只影响体验。

## 发包顺序闸门（SPEC §5）

带「复制整段邀请消息」的包发 TestFlight 之前，plan-web 的 `/i/<码>` 落地页（#110）必须已部署，否则学员点链接只看到教练登录页。
