/* global React, MeetPR */
const { Icon, StatusBar, TabBar, COACH_TABS, STUDENT_TABS, Eyebrow, LoadingBar } = MeetPR;

// ============================================================
// 1) COACH DASHBOARD
// ============================================================
const CoachDashboard = () => (
  <div className="screen">
    <StatusBar />
    <div className="navbar-large" style={{ padding: "0 16px 12px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
        <div>
          <Eyebrow>MONDAY · WEEK 03</Eyebrow>
          <h1 style={{ fontSize: 34, fontWeight: 700, margin: "4px 0 0", letterSpacing: "-0.01em" }}>Today</h1>
        </div>
        <div style={{ display:"flex", gap: 8 }}>
          <button style={{ width: 36, height: 36, borderRadius: 999, background: "var(--surface-1)", border: "1px solid var(--border)", color: "#fff" }}><Icon name="bell" size={18}/></button>
          <button style={{ width: 36, height: 36, borderRadius: 999, background: "var(--surface-1)", border: "1px solid var(--border)", color: "#fff" }}><Icon name="plus" size={18}/></button>
        </div>
      </div>
    </div>
    <LoadingBar/>
    <div className="scroll" style={{ padding: "16px" }}>
      {/* AI alert */}
      <div className="card elevated" style={{ marginBottom: 16, borderColor: "rgba(229,34,30,0.3)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
          <Icon name="sparkle" size={14} color="var(--brand-red)"/>
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase", fontWeight: 500 }}>AI_SUGGESTION //</span>
        </div>
        <div style={{ fontSize: 17, fontWeight: 600, lineHeight: 1.3 }}>Chen Lei hit RPE 10 across 3 sessions.</div>
        <div style={{ fontSize: 14, color: "var(--fg-secondary)", marginTop: 6, lineHeight: 1.4 }}>Reduce W4 backoff by 5%? Affects 4 lifts.</div>
        <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
          <button style={{ flex:1, padding: "10px 12px", background: "#fff", color: "#000", border: "none", borderRadius: 10, fontWeight: 600, fontSize: 14 }}>Apply</button>
          <button style={{ flex:1, padding: "10px 12px", background: "transparent", color: "#fff", border: "1px solid var(--border)", borderRadius: 10, fontWeight: 600, fontSize: 14 }}>Review</button>
        </div>
      </div>

      {/* Stats */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", gap: 24 }}>
          <div style={{ flex:1 }}>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>ROSTER</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 36, fontWeight: 800, fontVariantNumeric: "tabular-nums", letterSpacing: "-0.02em" }}>14</span>
              <span style={{ fontSize: 13, color: "var(--fg-tertiary)" }}>active</span>
            </div>
          </div>
          <div style={{ width: 1, background: "var(--border)" }}/>
          <div style={{ flex:1 }}>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>OVERDUE</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 36, fontWeight: 800, fontVariantNumeric: "tabular-nums", letterSpacing: "-0.02em", color: "var(--amber)" }}>2</span>
              <span style={{ fontSize: 13, color: "var(--fg-tertiary)" }}>need follow-up</span>
            </div>
          </div>
          <div style={{ width: 1, background: "var(--border)" }}/>
          <div style={{ flex:1 }}>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>PRs · 7D</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 36, fontWeight: 800, fontVariantNumeric: "tabular-nums", letterSpacing: "-0.02em", color: "var(--green)" }}>5</span>
            </div>
          </div>
        </div>
      </div>

      {/* Athletes */}
      <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-tertiary)", letterSpacing: "0.08em", textTransform: "uppercase", margin: "16px 4px 8px" }}>ATHLETES — TODAY</div>
      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        <AthleteRow name="Chen Lei" sub="W3D1 · logged 2h ago" badge={<span className="badge badge-pr">NEW PR</span>} dotColor="#fff"/>
        <AthleteRow name="Zhang Yu" sub="W3D1 · in session" badge={<span className="badge badge-live"><span className="dot-pulse"/>LIVE</span>} dotColor="var(--brand-red)" border/>
        <AthleteRow name="Ma Wei" sub="W3D1 · queued 9:00 AM" badge={<span className="badge badge-pending">PENDING</span>} dotColor="var(--fg-tertiary)" border/>
        <AthleteRow name="Yan Bo" sub="W2D3 · 5 days behind" badge={<span className="badge badge-overdue">OVERDUE</span>} dotColor="var(--amber)" border/>
        <AthleteRow name="Liu Hao" sub="W3D1 · ready" badge={<span className="badge badge-ready">READY</span>} dotColor="var(--green)" border/>
      </div>
    </div>
    <TabBar items={COACH_TABS} active="today"/>
  </div>
);

const AthleteRow = ({ name, sub, badge, dotColor, border }) => (
  <div style={{
    display: "flex", alignItems: "center", gap: 12,
    padding: "12px 16px", minHeight: 56, boxSizing: "border-box",
    borderTop: border ? "1px solid var(--border)" : "none"
  }}>
    <div style={{ width: 8, height: 8, borderRadius: "50%", background: dotColor }}/>
    <div style={{ flex: 1 }}>
      <div style={{ fontSize: 16, fontWeight: 600 }}>{name}</div>
      <div style={{ fontSize: 12, color: "var(--fg-tertiary)", marginTop: 2 }}>{sub}</div>
    </div>
    {badge}
    <Icon name="chevR" size={16} color="var(--fg-tertiary)"/>
  </div>
);

// ============================================================
// 2) PLANNING EDITOR (4-week excel-style preview)
// ============================================================
const PlanningEditor = () => {
  const days = ["MON","TUE","WED","THU","FRI","SAT","SUN"];
  const weeks = [
    ["SQ T", "—", "BP", "DL T", "—", "SQ B", "—"],
    ["SQ T", "—", "BP +5", "DL T", "—", "SQ B", "—"],
    ["SQ T+", "—", "BP +5", "DL T+", "—", "SQ B", "—"],
    ["SQ MAX", "—", "BP MAX", "DL MAX", "—", "—", "—"],
  ];
  return (
    <div className="screen">
      <StatusBar />
      <div className="navbar">
        <button style={{ background: "transparent", border: "none", color: "#fff", display:"flex", alignItems:"center", gap:4, fontSize:15, padding: 0 }}>
          <Icon name="chevL" size={18}/> Athletes
        </button>
        <div className="navbar-title">Mesocycle · Chen Lei</div>
        <button style={{ background: "transparent", border: "none", color: "var(--brand-red)", fontWeight: 600, fontSize: 15 }}>Publish</button>
      </div>
      <div className="scroll" style={{ padding: 16 }}>
        <Eyebrow>PROTOCOL 03 — STRENGTH</Eyebrow>
        <h2 style={{ fontSize: 28, fontWeight: 700, margin: "6px 0 4px", letterSpacing: "-0.01em" }}>The Kinetic Monolith</h2>
        <div style={{ color: "var(--fg-secondary)", fontSize: 14 }}>4 weeks · SBD · top set + backoff</div>

        {/* Week progress */}
        <div style={{ display: "flex", gap: 6, marginTop: 20 }}>
          {[1,1,0.4,0].map((p, i) => (
            <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: p === 1 ? "var(--green)" : p === 0 ? "transparent" : "linear-gradient(to right,#fff 40%,#262626 40%)", border: p === 0 ? "1px solid var(--border)" : "none" }}/>
          ))}
        </div>
        <div className="mono" style={{ display: "flex", justifyContent: "space-between", fontSize: 10, color: "var(--fg-tertiary)", letterSpacing: "0.08em", marginTop: 6 }}>
          <span>W1 ✓</span><span>W2 ✓</span><span>W3 · 40%</span><span>W4</span>
        </div>

        {/* Excel-style grid */}
        <div className="card" style={{ marginTop: 16, padding: 0, overflow: "hidden" }}>
          <div style={{ display: "grid", gridTemplateColumns: "32px repeat(7, 1fr)", gap: 1, background: "var(--border)", padding: 1 }}>
            <div style={{ background: "var(--surface-1)", padding: "8px 6px", fontSize: 9, fontFamily: "var(--font-mono)", color: "var(--fg-tertiary)", letterSpacing: "0.08em" }}></div>
            {days.map(d => (
              <div key={d} style={{ background: "var(--surface-1)", padding: "8px 6px", fontSize: 9, fontFamily: "var(--font-mono)", color: "var(--fg-tertiary)", letterSpacing: "0.08em", textAlign: "center" }}>{d}</div>
            ))}
            {weeks.map((week, wi) => (
              <React.Fragment key={wi}>
                <div style={{ background: "var(--surface-1)", padding: "12px 6px", fontSize: 10, fontFamily: "var(--font-mono)", color: wi === 2 ? "var(--brand-red)" : "var(--fg-tertiary)", letterSpacing: "0.08em", textAlign: "center", fontWeight: 600 }}>W{wi+1}</div>
                {week.map((cell, di) => {
                  const isCurrent = wi === 2 && di === 0;
                  const empty = cell === "—";
                  return (
                    <div key={di} style={{
                      background: isCurrent ? "var(--surface-2)" : "var(--surface-1)",
                      padding: "12px 4px", textAlign: "center",
                      fontSize: 11, fontWeight: empty ? 400 : 600,
                      color: empty ? "var(--fg-tertiary)" : "#fff",
                      border: isCurrent ? "1px solid #fff" : "none",
                      position: "relative"
                    }}>
                      {cell}
                      {(wi < 2 || (wi === 2 && di === 0)) && !empty && wi < 2 && (
                        <div style={{ position: "absolute", top: 2, right: 2, width: 0, height: 0, borderTop: "6px solid var(--brand-red)", borderLeft: "6px solid transparent" }}/>
                      )}
                    </div>
                  );
                })}
              </React.Fragment>
            ))}
          </div>
        </div>

        {/* Selected day detail */}
        <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase", marginTop: 20 }}>SELECTED · W3 D1 — SQUAT TOP+</div>
        <div className="card" style={{ marginTop: 8, padding: 0 }}>
          <ExerciseRow name="Squat" detail="Top set @ RPE 8.5" sets="1 × 3"/>
          <ExerciseRow name="Squat" detail="Backoff −10%" sets="3 × 5" border/>
          <ExerciseRow name="Pause Squat" detail="2s pause @ RPE 7" sets="3 × 5" border/>
        </div>
      </div>
    </div>
  );
};

const ExerciseRow = ({ name, detail, sets, border }) => (
  <div style={{ display: "flex", alignItems: "center", padding: "14px 16px", minHeight: 56, borderTop: border ? "1px solid var(--border)" : "none" }}>
    <div style={{ flex: 1 }}>
      <div style={{ fontSize: 16, fontWeight: 600 }}>{name}</div>
      <div style={{ fontSize: 12, color: "var(--fg-tertiary)", marginTop: 2 }}>{detail}</div>
    </div>
    <div className="mono" style={{ fontSize: 14, color: "#fff", marginRight: 8 }}>{sets}</div>
    <Icon name="chevR" size={16} color="var(--fg-tertiary)"/>
  </div>
);

window.Screens1 = { CoachDashboard, PlanningEditor };
