MeetPR 的按钮：暗色主题主 CTA 为纯金 #FFB800 黑字胶囊（内高光+暗边+金投影），亮色主题主 CTA 为深蓝黑 #111827 白字。

```jsx
<Button variant="primary" shimmer sub="蹲 · 推 · 拉"
  icon={<svg width="13" height="13" viewBox="0 0 24 24" fill="#141414"><path d="M7 4.5v15c0 .8.9 1.3 1.6.9l12-7.5c.6-.4.6-1.4 0-1.8l-12-7.5c-.7-.4-1.6.1-1.6.9z"/></svg>}>
  开始训练
</Button>
```

- `shimmer` 只给页面最高层级入口（每页至多一个）
- `variant="secondary"`：暗 #141416 描边卡片；亮 白卡+弥散阴影
- `variant="ghost"`：灰色文字按钮（顺延一天、撤销）
