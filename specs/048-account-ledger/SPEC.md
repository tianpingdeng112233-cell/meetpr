# SPEC 048 — 账号台账:注销/改密/CSV 导出(iOS 半,wave A6)

- **状态**: Accepted(2026-07-04,与实现同 PR)
- **来源**: 自己练 Free 档 wave A6 商业化台账;backend 半 = spec 011(注销/改密端点)。
- **侦察(2026-07-04)**:APIClient 动词全齐(`deleteNoContent`/`put`);`Session.logout()` 已清 keychain+本地态+回登录页,注销成功后直接复用;我的页「更多」区现有 成长曲线/评估总结/退出登录 三行,新增「账号与安全」区自然落位;CSV 数据源 = `fetchLogs(scope: .all)` 宽窗。

## 1. 我的页「账号与安全」区

- 「更多」区之下新 section:改密码 / 导出训练数据 / 注销账号(红色,置底)。
- 三行均 coached+solo 通用(台账不分模式);文案零「教练/计划」依赖。

## 2. 注销账号(Apple 5.1.1(v))

- 入口 → 全屏 sheet:说明「账号与全部训练数据将**永久删除**,无法恢复」+ 数据点列举(训练记录/e1RM 历史/回顾/资料)。
- 二次确认:TextField 输入确认词「注销」才点亮红色「永久删除我的账号」按钮。
- 提交:`DELETE /me` → 204 → `session.logout()`(清 keychain/本地缓存/草稿)→ 登录页;失败(网络/5xx)留 sheet 提示重试,**不**本地清态(半删除态最伤信任)。
- `AccountRepository` 新协议:`deleteAccount()` / `changePassword(old:new:)`;Backend + InMemory 双实现。

## 3. 改密码

- Sheet:旧密码 / 新密码 / 确认新密码(SecureField ×3;新密码规则文案与注册一致)。
- 提交:`PUT /me/password` → 204 → toast「密码已更新,其他设备将退出登录」+ dismiss;403 PASSWORD_MISMATCH → 「旧密码不正确」留 sheet;两次新密码不一致 → 本地校验禁提交。

## 4. 导出训练数据(「永不锁数据」落地物)

- 客户端全量拉 `fetchLogs(scope: .all)`(宽窗:2000-01-01 至今,绕开 180 天产品窗——导出必须全量)→ 生成 CSV → `ShareLink` 系统分享单。
- 列(英文,便于再导入):`date,exercise,exercise_en,set_index,weight_kg,reps,rpe,completed,failed,adhoc`;动作名从 catalog map 解析(coached 用户拉不到 catalog?CatalogKit bundled 目录对两模式同在——用 bundled 目录+plan 树并集解析,查不到落 exercise_id 原文)。
- 文件名 `meetpr-training-log-YYYYMMDD.csv`;生成在临时目录,分享后不留存。
- 空数据:按钮可点,导出只含表头的 CSV(诚实,不假装失败)。
- 开放项:回顾/readiness 随导出(V1 sets-only,F-030 族记一条)。

## 非目标

忘记密码(SMS,post-incorporation);账号数据导入;coach 注销(backend 011 同款开放项);导出格式选择(V1 CSV 单一)。

## 测试

- AccountRepository 双实现:delete 后 InMemory 状态清;changePassword 旧密错误抛映射。
- 注销 VM:确认词不符禁提交;失败留态可重试;成功回调触发 logout。
- CSV 生成器:列序/转义(动作名含逗号/引号)/空数据表头/日期格式;100 行往返。
- 改密 VM:本地两次密码不一致禁提交;403 文案映射。

## 验收

1. 新账号记几组 → 注销 → 重新注册同手机号 = 全新空账号(staging 实测)。
2. 改密后旧密登录失败、新密成功;另一设备(或模拟器第二实例)被登出。
3. 导出 CSV 在 Numbers/Excel 打开列对齐,中文动作名正常。
