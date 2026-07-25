export function SetTable({ rows = [], theme = 'dark' }) {
  const light = theme === 'light';
  const c = {
    card: light ? '#fff' : '#141416', border: light ? '#E9EBEE' : '#1E1E22',
    head: light ? '#9CA3AF' : '#6A6A70', done: light ? '#111827' : '#fff',
    pending: light ? '#9CA3AF' : '#5A5A60', ok: light ? '#15803D' : '#5E9E78',
    camOff: light ? '#9CA3AF' : '#5E5E64'
  };
  const mono = { fontFamily: "'IBM Plex Mono',monospace" };
  const cell = (w, extra = {}) => ({ ...mono, fontSize: 15, ...extra });
  return (
    <div style={{ background: c.card, borderRadius: 12, overflow: 'hidden', boxShadow: light ? '0 4px 18px rgba(17,24,39,.06)' : 'none' }}>
      <div style={{ display: 'flex', padding: '9px 15px', ...mono, fontSize: 10, color: c.head, letterSpacing: '.04em' }}>
        <span style={{ width: 24 }}>#</span><span style={{ flex: 1 }}>重量</span><span style={{ flex: 1, textAlign: 'center' }}>次数</span><span style={{ flex: 1, textAlign: 'center' }}>RPE</span><span style={{ width: 70 }}></span>
      </div>
      {rows.map((r, i) => {
        const txt = r.done ? c.done : c.pending;
        return (
          <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '12px 15px', borderTop: '1px solid ' + c.border }}>
            <span style={cell(24, { width: 24, fontSize: 13, fontWeight: 700, color: txt })}>{i + 1}</span>
            <span style={cell(0, { flex: 1, fontWeight: 700, color: txt })}>{r.w}</span>
            <span style={cell(0, { flex: 1, textAlign: 'center', color: txt })}>{r.r}</span>
            <span style={cell(0, { flex: 1, textAlign: 'center', color: txt })}>{r.rpe}</span>
            <span style={{ width: 70, display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 13 }}>
              {r.done && !r.failed && <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke={c.ok} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6L9 17l-5-5" /></svg>}
              {r.done && r.failed && <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#E5484D" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6L6 18M6 6l12 12" /></svg>}
              {!r.done && <span style={{ width: 15, height: 15, borderRadius: '50%', border: '1.5px solid ' + (light ? '#D1D5DB' : '#4A4A50'), display: 'inline-block' }}></span>}
              <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke={r.video ? c.ok : c.camOff} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2.5" y="7" width="12.5" height="10" rx="2.5" /><path d="M15 10.5l6-3v9l-6-3z" /></svg>
            </span>
          </div>
        );
      })}
    </div>
  );
}
