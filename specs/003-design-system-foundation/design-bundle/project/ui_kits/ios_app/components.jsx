/* global React */
const { useState } = React;

// ---------- Tiny inline icon set (Lucide-flavored, stroked) ----------
const Icon = ({ name, size = 20, color = "currentColor", strokeWidth = 1.75, style }) => {
  const props = {
    width: size, height: size, viewBox: "0 0 24 24",
    fill: "none", stroke: color, strokeWidth, strokeLinecap: "round", strokeLinejoin: "round", style
  };
  const paths = {
    home:    <><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/></>,
    calendar:<><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></>,
    dumbbell:<><path d="M6.5 6.5l11 11"/><path d="M3 9l3-3 3 3-3 3z"/><path d="M15 15l3-3 3 3-3 3z"/><path d="M2.5 9.5l1-1M20.5 14.5l1-1"/></>,
    users:   <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></>,
    user:    <><circle cx="12" cy="8" r="4"/><path d="M4 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2"/></>,
    inbox:   <><polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/></>,
    plus:    <><path d="M12 5v14M5 12h14"/></>,
    chevR:   <><polyline points="9 18 15 12 9 6"/></>,
    chevL:   <><polyline points="15 18 9 12 15 6"/></>,
    check:   <><polyline points="20 6 9 17 4 12"/></>,
    x:       <><path d="M18 6L6 18M6 6l12 12"/></>,
    sparkle: <><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/></>,
    bell:    <><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></>,
    timer:   <><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M9 2h6"/></>,
    video:   <><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2"/></>,
    pencil:  <><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></>,
    trend:   <><polyline points="3 17 9 11 13 15 21 7"/><polyline points="14 7 21 7 21 14"/></>,
    play:    <><polygon points="6 4 20 12 6 20 6 4" fill="currentColor"/></>,
  };
  return <svg {...props}>{paths[name]}</svg>;
};

// ---------- Status bar ----------
const StatusBar = ({ time = "9:41", dark = true }) => (
  <div style={{
    display: "flex", justifyContent: "space-between", alignItems: "center",
    padding: "14px 24px 6px", color: dark ? "#fff" : "#000",
    fontFamily: "-apple-system, sans-serif", fontWeight: 600, fontSize: 15,
    fontVariantNumeric: "tabular-nums"
  }}>
    <span>{time}</span>
    <span style={{ display: "flex", gap: 5, alignItems: "center" }}>
      <span style={{ display: "inline-flex", gap: 2, alignItems: "flex-end" }}>
        {[3,5,7,9].map(h => <span key={h} style={{ width: 3, height: h, background: dark ? "#fff" : "#000", borderRadius: 1 }}/>)}
      </span>
      <svg width="16" height="11" viewBox="0 0 16 11" fill={dark?"#fff":"#000"}><path d="M8 2C5 2 2.5 3 .5 4.7l1 1.2C3.2 4.4 5.5 3.5 8 3.5s4.8.9 6.5 2.4l1-1.2C13.5 3 11 2 8 2zm0 3c-2 0-3.7.7-5 1.8l1 1.2c1-.9 2.5-1.5 4-1.5s3 .6 4 1.5l1-1.2C11.7 5.7 10 5 8 5zm0 3c-1 0-1.8.4-2.5 1l1 1.2c.4-.4.9-.7 1.5-.7s1.1.3 1.5.7l1-1.2c-.7-.6-1.5-1-2.5-1z"/></svg>
      <span style={{
        width: 26, height: 12, border: `1.5px solid ${dark?"#fff":"#000"}`, borderRadius: 3,
        position: "relative", display: "inline-block"
      }}>
        <span style={{ position: "absolute", top: 1, left: 1, bottom: 1, width: "85%", background: dark?"#fff":"#000", borderRadius: 1 }}/>
      </span>
    </span>
  </div>
);

// ---------- Tab bars ----------
const TabBar = ({ items, active }) => (
  <div className="tabbar" style={{ paddingBottom: 24 }}>
    {items.map((it) => (
      <div key={it.key} className={`tabbar-item ${active === it.key ? "active" : ""}`}>
        <div className="tabbar-icon"><Icon name={it.icon} size={22} /></div>
        <div className="tabbar-label">{it.label}</div>
      </div>
    ))}
  </div>
);

const COACH_TABS = [
  { key: "today", icon: "home", label: "Today" },
  { key: "plan", icon: "calendar", label: "Plan" },
  { key: "athletes", icon: "users", label: "Athletes" },
  { key: "inbox", icon: "inbox", label: "Inbox" },
  { key: "profile", icon: "user", label: "Profile" },
];
const STUDENT_TABS = [
  { key: "today", icon: "dumbbell", label: "Train" },
  { key: "plan", icon: "calendar", label: "Plan" },
  { key: "history", icon: "trend", label: "History" },
  { key: "profile", icon: "user", label: "Profile" },
];

// ---------- Eyebrow ----------
const Eyebrow = ({ children, color = "var(--brand-red)", trail = true }) => (
  <span style={{
    fontFamily: "var(--font-mono)", fontSize: 11, fontWeight: 500,
    letterSpacing: "0.08em", textTransform: "uppercase", color,
    display: "inline-flex", alignItems: "center", gap: 8
  }}>
    {children}
    {trail && <span style={{ width: 24, height: 1, background: color }}/>}
  </span>
);

// ---------- Loading bar ----------
const LoadingBar = () => <div className="loading-bar"/>;

window.MeetPR = { Icon, StatusBar, TabBar, COACH_TABS, STUDENT_TABS, Eyebrow, LoadingBar };
