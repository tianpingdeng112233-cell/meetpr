export function Badge({ tone = 'gold', theme = 'dark', children }) {
  const tones = {
    gold: theme === 'light' ? { bg: 'rgba(217,119,6,.12)', fg: '#D97706' } : { bg: 'rgba(245,166,35,.16)', fg: '#F5A623' },
    success: theme === 'light' ? { bg: 'rgba(21,128,61,.12)', fg: '#15803D' } : { bg: 'rgba(94,158,120,.16)', fg: '#5E9E78' },
    danger: { bg: 'rgba(229,72,77,.14)', fg: '#E5484D' },
    neutral: theme === 'light' ? { bg: '#F3F4F6', fg: '#6B7280' } : { bg: '#1C1C20', fg: '#8A8A90' }
  };
  const t = tones[tone];
  return <span style={{ fontFamily: "'IBM Plex Mono','Noto Sans SC',monospace", fontSize: 11, fontWeight: 700, letterSpacing: '.05em', background: t.bg, color: t.fg, padding: '4px 12px', borderRadius: 999, display: 'inline-block' }}>{children}</span>;
}
