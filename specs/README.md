# specs/ — 实现规格

> 给 Codex(或任何 implementer agent)读的**原子任务规格**。一个 spec = 一个 PR。

## 目录结构

```
specs/
  NNN-short-slug/
    SPEC.md          # 主规格(必须)
    QUESTIONS.md     # implementer 遇到疑问回写这里(可选)
    REVIEW.md        # reviewer 留下的修改要求(可选)
```

## SPEC.md 格式

```markdown
# NNN — 任务标题

- **状态**:Ready / Blocked / InProgress / InReview / Done
- **PR**:(填入 PR 链接)
- **来源**:`~/Brain/wiki/projects/MeetPR/prd.md#section` 或 user-story ID

## 目标
_一句话_

## 范围
- 做什么
- **不做**什么

## 技术要求
- 模块位置:_待填_
- 接口 / API 签名:_待填_
- 数据结构:_待填_

## 验收标准
- [ ] _可测试的条件_
- [ ] 单元测试覆盖
- [ ] 手动走一遍:_具体步骤_

## 参考
- 相关 ADR:_链接_
- 相关 PRD 段落:_链接_
```

## 工作流

1. **Claude** 写 `SPEC.md`(基于 PRD + 架构)
2. **Codex** 读 SPEC,起 branch `feat/NNN-slug`,实现并提交 PR
3. **Codex** 遇到歧义 → 停下来写 `QUESTIONS.md`,不准自己脑补
4. **Claude** review PR:过 → merge + 标记 Done;不过 → 写 `REVIEW.md`
5. 合并后 SPEC 保留,成为项目历史

## 硬规矩

- **一个 spec 一个 PR**,不聚合
- **SPEC.md 一旦状态为 InProgress 不能改**,要改就创建新的 NNN+1
- **所有验收标准必须可测**(「看起来好」不算验收标准)
