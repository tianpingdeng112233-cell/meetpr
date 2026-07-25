export function DayChip({ dow, day, state = 'default', dot = null, theme = 'dark' }) {
  const light = theme === 'light';
  const dots = { success: light ? '#15803D' : '#5E9E78', gold: light ? '#F59E0B' : '#F5A623', danger: '#E5484D' };
  const sel = state === 'selected';
  const dim = state === 'dim';
  const box = sel
    ? (light ? { background: '#111827', color: '#fff', border: '1.5px solid #D97706' } : { background: '#1B1B1E', color: '#fff', border: '1.5px solid #F5A623' })
    : (light ? { background: '#fff', boxShadow: '0 4px 18px rgba(17,24,39,.06)', color: dim ? '#9CA3AF' : '#111827' } : { background: '#141416', color: dim ? '#55555C' : '#fff' });
  const labelColor = sel ? (light ? '#fff' : '#fff') : dim ? (light ? '#9CA3AF' : '#55555C') : (light ? '#6B7280' : '#8A8A90');
  return (
    <div style={{ position: 'relative', overflow: 'hidden', borderRadius: 12, height: 44, flex: 1, minWidth: 44, padding: sel ? '4px 0 0' : '5px 0 0', display: 'flex', flexDirection: 'column', alignItems: 'center', fontFamily: "'IBM Plex Sans','Noto Sans SC',sans-serif", ...box }}>
      {dot && <span style={{ position: 'absolute', top: 5, right: 6, width: 5, height: 5, borderRadius: '50%', background: dots[dot] }}></span>}
      <div style={{ fontSize: 10, color: labelColor }}>{dow}</div>
      <div style={{ flex: 1 }}></div>
      <div style={{ fontSize: 13, fontWeight: 700, fontFamily: "'IBM Plex Mono',monospace", marginBottom: 5 }}>{day}</div>
    </div>
  );
}
