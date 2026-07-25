周历日期块：一行 7 个 flex:1 排列，gap 6。选中日 = 深底 + 1.5px 金描边 + 橙点；有训练的过去日打绿点；休息日与未来日期整体降灰且**不打点**。

```jsx
<div style={{display:'flex',gap:6}}>
  <DayChip dow="周一" day={20} dot="success" />
  <DayChip dow="周二" day={21} state="dim" />
  <DayChip dow="周三" day={22} state="selected" dot="gold" />
</div>
```
