# 交给 Claude Code 的清单

这个文件夹里的东西**互相自洽**，可以整包发过去，不会互相矛盾。
唯一标准是 `MeetPR 学员端.dc.html`；包里其他文件都与它对齐。

## 打开方式

所有 `.dc.html` 双击即可在浏览器打开（同目录的 `support.js` 是运行时，别删）。
不需要 npm、不需要构建。

## 文件

| 文件 | 是什么 | CC 拿它做什么 |
|---|---|---|
| `README.md` | 实装规格 | **先读这个**，全部规则在里面 |
| `tokens.css` | 设计 token | 与 `motion.css` 拼接成 `globals.css` |
| `motion.css` | 动效样式（@keyframes / .pb .scrn .shimmer .glow 等工具类 / reduced-motion 降级） | 与 `tokens.css` 拼接成 `globals.css` |
| `motion/01–05.html` | 5 个关键动效可运行参考（CTA 蓄力转场 / 反馈卡展开 / 卷折收纳 / 错峰进场 / 结算庆祝） | 双击打开看效果，直接抄里面的 JS/CSS |
| `dc-tokens.css` | 同一套 token 的紧凑版 | 组件预览用，内容与 `tokens.css` 等价 |
| `MeetPR 组件库.dc.html` | 组件总览 | 打开看 7 个组件的全部状态，左暗右亮 |
| `DayChip / Badge / SetRow / StatTile / GoldCTA / ExerciseCard / NumberPad` `.dc.html` | 7 个组件 | 逐个映射成 React 组件；props 契约在文件末尾 `data-props` 的 JSON 里 |
| `MeetPR 学员端 双主题.dc.html` | 完整 App 样机 | 打开点一遍，理解流程与动效；右上角切暗/亮 |
| `MeetPR 学员端.dc.html` | 样机本体（唯一标准） | 被上一个引用，单独打开是暗色 |
| `support.js` | 运行时 | 别删，别改 |

## 一条硬规则

组件里**零硬编码颜色**，全部走 `var()`。主题由祖先 `.theme-light` 决定，
组件**不接 `theme` 属性** —— 加了就等于把一份 UI 拆成两份维护。
包里 7 个组件已经是这个写法，照抄即可。

## 建议的第一句话

> 读 README.md。先把 tokens.css + motion.css 拼成主题，再把 7 个组件写成 React 组件（props 契约在各文件末尾的 data-props JSON 里，注意它们不接 theme 属性、只用 CSS 变量），然后用这些组件拼出 README 第 4 节的 4 个屏幕 —— 屏幕结构可以直接从样机翻译成 JSX。动效不要凭描述重写，拷 motion/ 目录里的参考实现。

## 故意没放进来的

- `MeetPR 教练端 / 网页端` —— 不是这次的范围（但用同一套 token）
- 离线版 HTML（25MB）—— 编译产物，对实装无用
- `meetpr-design-skill/`、`components/`、`guidelines/` —— 项目内的设计系统包，与本包同源但面向设计工具，别一起发
