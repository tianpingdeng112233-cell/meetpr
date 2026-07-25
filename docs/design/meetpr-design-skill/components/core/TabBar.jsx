export function TabBar({ active = 0, theme = 'dark', onChange = () => {} }) {
  const light = theme === 'light';
  const on = light ? '#D97706' : '#F5A623';
  const off = light ? '#9CA3AF' : '#6A6A70';
  const items = [
    { label: '今日', d: 'M12 2a10 10 0 100 20 10 10 0 000-20zm0 5a5 5 0 100 10 5 5 0 000-10zm0 3.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3z' },
    { label: '训练', d: 'M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M6.5 12h11', stroke: true },
    { label: '成长', d: 'M3 17l6-6 4 4 8-8M15 7h6v6', stroke: true },
    { label: '我的', d: 'M12 12a4 4 0 100-8 4 4 0 000 8zm-7 9a7 7 0 0114 0', stroke: true }
  ];
  return (
    <div style={{ height: 83, borderTop: '1px solid ' + (light ? '#E5E7EB' : '#17171A'), display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start', paddingTop: 9, background: light ? '#fff' : '#0A0A0C', fontFamily: "'IBM Plex Sans','Noto Sans SC',sans-serif" }}>
      {items.map((it, i) => {
        const c = i === active ? on : off;
        return (
          <div key={i} onClick={() => onChange(i)} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, cursor: 'pointer', width: 64 }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill={it.stroke ? 'none' : c} stroke={it.stroke ? c : 'none'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={it.d} /></svg>
            <span style={{ fontSize: 10, color: c, fontWeight: i === active ? 700 : 500 }}>{it.label}</span>
          </div>
        );
      })}
    </div>
  );
}
