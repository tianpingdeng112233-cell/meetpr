/* global React, MeetPR */
const { Icon, StatusBar, TabBar, STUDENT_TABS, Eyebrow, LoadingBar } = MeetPR;
const { useState } = React;

// ============================================================
// 3) STUDENT TRAINING DAY — set list + active set + RPE
// ============================================================
const StudentTrainingDay = () => {
  const [rpe, setRpe] = useState(8.5);
  return (
    <div className="screen">
      <StatusBar />
      <div className="navbar">
        <button style={{ background: "transparent", border: "none", color: "#fff", display:"flex", alignItems:"center", gap:4, fontSize:15, padding:0 }}><Icon name="chevL" size={18}/> Plan</button>
        <div className="navbar-title">W3D1 · Squat</div>
        <button style={{ background: "transparent", border: "none", color: "#fff", padding: 0 }}><Icon name="timer" size={20}/></button>
      </div>
      <div className="scroll" style={{ padding: 16 }}>

        {/* Active set hero */}
        <div className="card elevated" style={{ marginBottom: 16 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <Eyebrow>SET 03 / 04 — TOP</Eyebrow>
            <span className="badge badge-live"><span className="dot-pulse"/>LIVE</span>
          </div>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 6, marginTop: 12 }}>
            <span className="tab-num" style={{ fontSize: 72, fontWeight: 800, lineHeight: 0.95, letterSpacing: "-0.02em" }}>170</span>
            <span style={{ fontSize: 22, fontWeight: 800, color: "var(--brand-red)", letterSpacing: "0.04em", paddingBottom: 8 }}>KG</span>
            <div style={{ flex: 1 }}/>
            <span className="mono" style={{ fontSize: 14, color: "var(--fg-secondary)", paddingBottom: 8 }}>×3 @ RPE 8.5</span>
          </div>

          {/* RPE slider */}
          <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", marginTop: 16 }}>RPE</div>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 8 }}>
            <span className="tab-num" style={{ fontSize: 36, fontWeight: 800, lineHeight: 1 }}>{rpe.toFixed(1)}</span>
            <span style={{ fontSize: 12, color: "var(--fg-tertiary)", paddingBottom: 6 }}>/ 10</span>
          </div>
          <div style={{ position: "relative", height: 40, marginTop: 8 }}>
            <input type="range" min="5" max="10" step="0.5" value={rpe} onChange={(e)=>setRpe(parseFloat(e.target.value))}
              style={{ position: "absolute", inset: 0, width: "100%", opacity: 0, cursor: "pointer", zIndex: 2 }}/>
            <div style={{ position: "absolute", top: 18, left: 0, right: 0, height: 4, background: "var(--border)", borderRadius: 2 }}/>
            <div style={{ position: "absolute", top: 18, left: 0, width: `${((rpe-5)/5)*100}%`, height: 4, background: "#fff", borderRadius: 2 }}/>
            <div style={{ position: "absolute", top: 8, left: `calc(${((rpe-5)/5)*100}% - 12px)`, width: 24, height: 24, background: "#fff", borderRadius: "50%", boxShadow: "0 0 0 4px rgba(255,255,255,0.08)" }}/>
          </div>

          <div style={{ display: "flex", gap: 8, marginTop: 16 }}>
            <button className="btn-primary" style={{ flex: 1, padding: 14, fontSize: 16 }}>Log Set</button>
            <button style={{ width: 56, background: "transparent", border: "1px solid var(--border)", borderRadius: 12, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="video" size={20}/></button>
          </div>
        </div>

        {/* Set list */}
        <div className="card" style={{ padding: 0 }}>
          <div className="mono" style={{ display: "grid", gridTemplateColumns: "32px 1fr 1fr 1fr 32px", padding: "10px 16px", fontSize: 10, letterSpacing: "0.08em", color: "var(--fg-tertiary)", textTransform: "uppercase", borderBottom: "1px solid var(--border)" }}>
            <span>#</span>
            <span style={{ textAlign: "right" }}>WEIGHT</span>
            <span style={{ textAlign: "right" }}>REPS</span>
            <span style={{ textAlign: "right" }}>RPE</span>
            <span/>
          </div>
          <SetRowEl n="1" w="142.5" r="5" rpe="7.5" done/>
          <SetRowEl n="2" w="155.0" r="3" rpe="8.5" done/>
          <SetRowEl n="3" w="170.0" r="—" rpe="—" active/>
          <SetRowEl n="4" w="155.0" r="3" rpe="—" />
        </div>

        {/* Form note from coach */}
        <div className="card elevated" style={{ marginTop: 16 }}>
          <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>COACH NOTE — ZHANG, 14:02</div>
          <div style={{ fontSize: 14, color: "#fff", marginTop: 6, lineHeight: 1.4 }}>
            Set 2 — knees caved at lockout. Drive through outside of the foot on the next set.
          </div>
        </div>
      </div>
      <TabBar items={STUDENT_TABS} active="today"/>
    </div>
  );
};

const SetRowEl = ({ n, w, r, rpe, done, active }) => (
  <div className="mono" style={{
    display: "grid", gridTemplateColumns: "32px 1fr 1fr 1fr 32px",
    padding: "14px 16px", fontSize: 16, alignItems: "center",
    borderBottom: "1px solid var(--border)",
    background: active ? "var(--surface-2)" : "transparent",
    color: done ? "#fff" : active ? "#fff" : "var(--fg-tertiary)"
  }}>
    <span style={{ color: active ? "var(--brand-red)" : "var(--fg-tertiary)" }}>{n}</span>
    <span style={{ textAlign: "right", fontWeight: active ? 700 : 400 }}>{w}</span>
    <span style={{ textAlign: "right" }}>{r}</span>
    <span style={{ textAlign: "right" }}>{rpe}</span>
    <span style={{ textAlign: "right", color: done ? "var(--green)" : "var(--fg-tertiary)" }}>{done ? "✓" : "○"}</span>
  </div>
);

// ============================================================
// 4) STUDENT PLAN VIEW
// ============================================================
const StudentPlanView = () => (
  <div className="screen">
    <StatusBar />
    <div className="navbar-large" style={{ padding: "0 16px 12px" }}>
      <Eyebrow>PROTOCOL 03 · WEEK 03 / 04</Eyebrow>
      <h1 style={{ fontSize: 34, fontWeight: 700, margin: "4px 0 0", letterSpacing: "-0.01em" }}>The Kinetic Monolith</h1>
    </div>
    <div className="scroll" style={{ padding: 16 }}>

      {/* Week progress */}
      <div style={{ display: "flex", gap: 6 }}>
        {[1,1,0.6,0].map((p, i) => (
          <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: p === 1 ? "var(--green)" : p === 0 ? "transparent" : "linear-gradient(to right,#fff 60%,#262626 60%)", border: p === 0 ? "1px solid var(--border)" : "none" }}/>
        ))}
      </div>

      {/* This week grid */}
      <div className="mono" style={{ fontSize: 10, color: "var(--fg-tertiary)", letterSpacing: "0.08em", marginTop: 20, marginBottom: 8, textTransform: "uppercase" }}>THIS WEEK</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 6 }}>
        {[
          ["M","SQ",true,false],
          ["T","—",false,false],
          ["W","BP",true,false],
          ["T","DL",false,true],
          ["F","—",false,false],
          ["S","SQ",false,false],
          ["S","—",false,false],
        ].map(([d,e,done,active], i) => (
          <div key={i} style={{
            aspectRatio: "1",
            background: active ? "var(--surface-2)" : "var(--surface-1)",
            border: active ? "1px solid #fff" : "1px solid var(--border)",
            borderRadius: 8, padding: 8,
            display: "flex", flexDirection: "column", justifyContent: "space-between",
            position: "relative"
          }}>
            <span className="mono" style={{ fontSize: 10, color: active ? "#fff" : "var(--fg-tertiary)" }}>{d}</span>
            <span style={{ fontSize: 13, fontWeight: 600, color: e === "—" ? "var(--fg-tertiary)" : "#fff" }}>{e}</span>
            {done && <div style={{ position: "absolute", top: 0, right: 0, width: 0, height: 0, borderTop: "10px solid var(--brand-red)", borderLeft: "10px solid transparent" }}/>}
          </div>
        ))}
      </div>

      {/* e1RM chart */}
      <div className="card" style={{ marginTop: 24 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
          <div>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>SQUAT e1RM · 90D</div>
            <div style={{ display: "flex", alignItems: "flex-end", gap: 6, marginTop: 4 }}>
              <span className="tab-num" style={{ fontSize: 44, fontWeight: 800, lineHeight: 1, letterSpacing: "-0.02em" }}>218</span>
              <span style={{ fontSize: 16, fontWeight: 800, color: "var(--brand-red)", paddingBottom: 4 }}>KG</span>
            </div>
          </div>
          <span className="mono" style={{ fontSize: 13, color: "var(--green)" }}>+15 KG</span>
        </div>
        <svg viewBox="0 0 600 120" style={{ width: "100%", display: "block", marginTop: 12 }} preserveAspectRatio="none">
          <polyline fill="none" stroke="#fff" strokeWidth="1.5" points="0,90 50,88 100,82 150,84 200,72 250,66 300,68 350,54 400,48 450,40 500,30 550,28 600,12"/>
          <circle cx="600" cy="12" r="4" fill="#E5221E"/>
        </svg>
        <div className="mono" style={{ display: "flex", justifyContent: "space-between", fontSize: 9, color: "var(--fg-tertiary)", letterSpacing: "0.06em", marginTop: 8 }}>
          <span>203 KG · 28 JAN</span><span>218 KG · NOW</span>
        </div>
      </div>

      {/* Today CTA */}
      <button className="btn-primary" style={{ marginTop: 16 }}>Open W3D1 · Squat</button>
    </div>
    <TabBar items={STUDENT_TABS} active="plan"/>
  </div>
);

// ============================================================
// 5) AUTH FLOW — phone entry + role selection
// ============================================================
const AuthFlow = () => {
  const [step, setStep] = useState(0);
  return (
    <div className="screen" style={{ padding: 0 }}>
      <StatusBar />
      <div style={{ flex: 1, padding: "32px 24px", display: "flex", flexDirection: "column" }}>
        <img src="../../assets/logo/meetpr-mark.svg" style={{ width: 56, height: 56 }}/>
        {step === 0 ? (
          <>
            <Eyebrow>PROTOCOL 00 · ACCESS</Eyebrow>
            <h1 style={{ fontSize: 40, fontWeight: 800, margin: "8px 0 0", lineHeight: 0.95, letterSpacing: "-0.02em" }}>Train under tension.</h1>
            <div style={{ color: "var(--fg-secondary)", fontSize: 15, marginTop: 12, lineHeight: 1.4 }}>
              MeetPR is invitation-based. Enter the phone number on file with your coach.
            </div>

            <div style={{ marginTop: 32 }}>
              <div className="mono" style={{ fontSize: 10, color: "var(--fg-tertiary)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 8 }}>PHONE</div>
              <div style={{ display: "flex", gap: 8 }}>
                <div style={{ background: "var(--surface-1)", border: "1px solid var(--border)", borderRadius: 8, padding: 14, color: "#fff", fontSize: 17, fontFamily: "var(--font-mono)" }}>+86</div>
                <input defaultValue="138 0000 0000" style={{ flex: 1, background: "var(--surface-1)", border: "1px solid #fff", borderRadius: 8, padding: 14, color: "#fff", fontSize: 17, fontFamily: "var(--font-mono)", letterSpacing: "0.04em" }}/>
              </div>
            </div>

            <div style={{ flex: 1 }}/>
            <button className="btn-primary" onClick={()=>setStep(1)}>Send Code</button>
            <div style={{ textAlign: "center", marginTop: 16, fontSize: 13, color: "var(--fg-tertiary)" }}>
              No account? <span style={{ color: "var(--brand-red)" }}>Request access →</span>
            </div>
          </>
        ) : (
          <>
            <Eyebrow>PROTOCOL 00 · ROLE</Eyebrow>
            <h1 style={{ fontSize: 40, fontWeight: 800, margin: "8px 0 0", lineHeight: 0.95, letterSpacing: "-0.02em" }}>Who are you here as?</h1>
            <div style={{ color: "var(--fg-secondary)", fontSize: 15, marginTop: 12, lineHeight: 1.4 }}>
              Your number is registered for both. Pick the surface for this session — you can switch later.
            </div>

            <div style={{ marginTop: 32, display: "flex", flexDirection: "column", gap: 12 }}>
              <RoleCard active title="Athlete" sub="Log sets · upload form · follow your block" tag="STUDENT_MODE"/>
              <RoleCard title="Coach" sub="Build cycles · review athletes · publish updates" tag="COACH_MODE"/>
            </div>

            <div style={{ flex: 1 }}/>
            <button className="btn-primary">Continue</button>
            <button onClick={()=>setStep(0)} style={{ marginTop: 12, background: "transparent", border: "none", color: "var(--fg-tertiary)", fontSize: 14 }}>← Use different number</button>
          </>
        )}
      </div>
    </div>
  );
};

const RoleCard = ({ active, title, sub, tag }) => (
  <div style={{
    background: active ? "var(--surface-2)" : "var(--surface-1)",
    border: active ? "1px solid #fff" : "1px solid var(--border)",
    borderRadius: 12, padding: 16,
    display: "flex", alignItems: "center", gap: 12
  }}>
    <div style={{
      width: 22, height: 22, borderRadius: "50%",
      border: active ? "6px solid #fff" : "1.5px solid var(--fg-tertiary)",
      background: active ? "var(--bg)" : "transparent"
    }}/>
    <div style={{ flex: 1 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ fontSize: 18, fontWeight: 700 }}>{title}</span>
        <span className="mono" style={{ fontSize: 9, color: "var(--brand-red)", letterSpacing: "0.08em", padding: "2px 6px", border: "1px solid rgba(229,34,30,0.3)", borderRadius: 4 }}>{tag}</span>
      </div>
      <div style={{ fontSize: 13, color: "var(--fg-secondary)", marginTop: 4 }}>{sub}</div>
    </div>
  </div>
);

window.Screens2 = { StudentTrainingDay, StudentPlanView, AuthFlow };
