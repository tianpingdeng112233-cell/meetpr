# 交给 Claude Code 的清单

这个文件夹里的东西**互相自洽**，可以整包发过去，不会互相矛盾。

## 打开方式

所有 `.dc.html` 双击即可在浏览器打开（同目录的 `support.js` 是运行时，别删）。
不需要 npm、不需要构建。

## 文件

| 文件 | 是什么 | CC 拿它做什么 |
|---|---|---|
| `README.md` | 实装规格 | **先读这个**，全部规则在里面 |
| `tokens.css` | 设计 token | 整块拷进 `globals.css` |
| `MeetPR 组件库.dc.html` | 组件总览 | 打开看 7 个组件的全部状态，左暗右亮 |
| `DayChip / Badge / SetRow / StatTile / GoldCTA / ExerciseCard / NumberPad` `.dc.html` | 7 个组件 | 逐个映射成 React 组件；props 契约在文件末尾 `data-props` 的 JSON 里 |
| `MeetPR 学员端 双主题.dc.html` | 完整 App 样机 | 打开点一遍，理解流程与动效；右上角切暗/亮 |
| `MeetPR 学员端.dc.html` | 样机本体 | 被上一个引用，单独打开是暗色 |
| `support.js` | 运行时 | 别删，别改 |

## 建议的第一句话

> 读 README.md。先按 tokens.css 建主题，再把 7 个组件写成 React 组件（props 契约在各文件末尾的 data-props JSON 里），最后用这些组件拼出 README 第 4 节的 4 个屏幕。样机只作视觉参考，不要从里面复制 div。

## 故意没放进来的

- `MeetPR 学员端 亮色.dc.html` —— 已被 token 化取代，留着会让 CC 以为要维护两份
- `MeetPR 教练端 / 网页端` —— 不是这次的范围
- 离线版 HTML（25MB）—— 编译产物，对实装无用
- `meetpr-design-skill/`、`components/`、`guidelines/` —— 早期抽取的设计系统，token 已迭代过，与本包不完全一致，别一起发
