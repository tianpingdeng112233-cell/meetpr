export function Button({ variant = 'primary', theme = 'dark', shimmer = false, icon = null, sub = null, children, style = {}, ...rest }) {
  const pill = { position: 'relative', overflow: 'hidden', borderRadius: 999, padding: '15px 17px', textAlign: 'center', fontWeight: 800, fontSize: 16, cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, fontFamily: "'IBM Plex Sans','Noto Sans SC',sans-serif", userSelect: 'none' };
  const variants = {
    primary: theme === 'light'
      ? { background: '#111827', color: '#fff' }
      : { background: '#FFB800', color: '#141414', boxShadow: 'inset 0 1.5px 0 rgba(255,255,255,.55), inset 0 -2px 3px rgba(120,60,0,.25), 0 8px 26px rgba(245,166,35,.38)' },
    secondary: theme === 'light'
      ? { background: '#fff', color: '#111827', boxShadow: '0 4px 18px rgba(17,24,39,.06)', border: '1px solid #E5E7EB' }
      : { background: '#141416', color: '#C8C8CC', border: '1px solid #262629' },
    ghost: { background: 'transparent', color: theme === 'light' ? '#6B7280' : '#9A9AA0', fontWeight: 600, fontSize: 13, padding: '4px 10px' }
  };
  return (
    <div {...rest} style={{ ...pill, ...variants[variant], ...style }}
      onMouseDown={e => { e.currentTarget.style.transform = 'scale(.97)'; }}
      onMouseUp={e => { e.currentTarget.style.transform = ''; }}
      onMouseLeave={e => { e.currentTarget.style.transform = ''; }}>
      {shimmer && variant === 'primary' && theme !== 'light' && <span className="mp-shimmer"></span>}
      <span style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', gap: 7 }}>{icon}{children}</span>
      {sub && <span style={{ position: 'relative', fontFamily: "'IBM Plex Mono','Noto Sans SC',monospace", fontSize: 12, fontWeight: 700, letterSpacing: '.06em', opacity: .72 }}>{sub}</span>}
    </div>
  );
}
