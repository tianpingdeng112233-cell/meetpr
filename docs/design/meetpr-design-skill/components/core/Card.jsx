export function Card({ theme = 'dark', accent = false, inset = false, style = {}, children }) {
  const base = theme === 'light'
    ? { background: inset ? '#F3F4F6' : '#fff', boxShadow: inset ? 'none' : '0 4px 18px rgba(17,24,39,.06)' }
    : { background: inset ? '#101014' : '#141416' };
  return (
    <div style={{ borderRadius: inset ? 10 : 16, padding: inset ? '10px 12px' : '14px 16px',
      borderLeft: accent ? '3px solid ' + (theme === 'light' ? '#D97706' : '#F5A623') : 'none',
      fontFamily: "'IBM Plex Sans','Noto Sans SC',sans-serif",
      color: theme === 'light' ? '#111827' : '#fff', ...base, ...style }}>
      {children}
    </div>
  );
}
