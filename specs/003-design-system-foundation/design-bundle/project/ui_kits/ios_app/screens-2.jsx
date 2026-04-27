/* global React, MeetPR */
const { Icon, StatusBar, TabBar, STUDENT_TABS, Eyebrow, LoadingBar } = MeetPR;
const { useState } = React;

const STUDENT_TABS_CN = STUDENT_TABS.map(t => ({ ...t, label: ({today:"训练",plan:"计划",history:"记录",profile:"我的"})[t.key] }));

// ============================================================
// 3) 学员端 · 训练日
// ============================================================
const StudentTrainingDay = () => {
  const [rpe, setRpe] = useState(8.5);
  return (
    <div className="screen">
      <StatusBar />
      <div className="navbar">
        <button style={{ background: "transparent", border: "none", color: "#fff", display:"flex", alignItems:"center", gap:4, fontSize:15, padding:0 }}><Icon name="chevL" size={18}/> 计划</button>
        <div className="navbar-title">W3D1 · 深蹲</div>
        <button style={{ background: "transparent", border: "none", color: "#fff", padding: 0 }}><Icon name="timer" size={20}/></button>
      </div>
      <div className="scroll" style={{ padding: 16 }}>

        <div className="card elevated" style={{ marginBottom: 16 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <Eyebrow>第 03 / 04 组 — 顶组</Eyebrow>
            <span className="badge badge-live"><span className="dot-pulse"/>直播</span>
          </div>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 6, marginTop: 12 }}>
            <span className="tab-num" style={{ fontSize: 72, fontWeight: 800, lineHeight: 0.95, letterSpacing: "-0.02em" }}>170</span>
            <span style={{ fontSize: 22, fontWeight: 800, color: "var(--brand-red)", letterSpacing: "0.04em", paddingBottom: 8 }}>KG</span>
            <div style={{ flex: 1 }}/>
            <span className="mono" style={{ fontSize: 14, color: "var(--fg-secondary)", paddingBottom: 8 }}>×3 @ RPE 8.5</span>
          </div>

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
            <button className="btn-primary" style={{ flex: 1, padding: 14, fontSize: 16 }}>记录此组</button>
            <button style={{ width: 56, background: "transparent", border: "1px solid var(--border)", borderRadius: 12, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="video" size={20}/></button>
          </div>
        </div>

        <div className="card" style={{ padding: 0 }}>
          <div className="mono" style={{ display: "grid", gridTemplateColumns: "32px 1fr 1fr 1fr 32px", padding: "10px 16px", fontSize: 10, letterSpacing: "0.08em", color: "var(--fg-tertiary)", textTransform: "uppercase", borderBottom: "1px solid var(--border)" }}>
            <span>#</span>
            <span style={{ textAlign: "right" }}>重量</span>
            <span style={{ textAlign: "right" }}>次数</span>
            <span style={{ textAlign: "right" }}>RPE</span>
            <span/>
          </div>
          <SetRowEl n="1" w="142.5" r="5" rpe="7.5" done/>
          <SetRowEl n="2" w="155.0" r="3" rpe="8.5" done/>
          <SetRowEl n="3" w="170.0" r="—" rpe="—" active/>
          <SetRowEl n="4" w="155.0" r="3" rpe="—" />
        </div>

      <div className="card elevated" style={{ marginTop: 16 }}>
        <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>教练反馈 — 张教练 · 14:02</div>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: "50%", background: "var(--surface-1)", border: "1px solid var(--border)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18 }}>👍</div>
          <div className="mono" style={{ fontSize: 11, color: "var(--fg-tertiary)", letterSpacing: "0.06em", textTransform: "uppercase" }}>第 1 组</div>
        </div>
        <div style={{ height: 1, background: "var(--border)", margin: "12px 0" }}/>
        <div className="mono" style={{ fontSize: 11, color: "var(--fg-tertiary)", letterSpacing: "0.06em", textTransform: "uppercase" }}>第 2 组</div>
        <div style={{ fontSize: 14, color: "#fff", marginTop: 6, lineHeight: 1.4 }}>
          锁定时膝盖内扣。下一组用脚外侧发力。
        </div>
      </div>
      </div>
      <TabBar items={STUDENT_TABS_CN} active="today"/>
    </div>
  );
};

const SetRowEl = ({ n, w, r, rpe, done, active }) => (
  <div className="mono" style={{ display: "grid", gridTemplateColumns: "32px 1fr 1fr 1fr 32px", padding: "14px 16px", fontSize: 16, alignItems: "center", borderBottom: "1px solid var(--border)", background: active ? "var(--surface-2)" : "transparent", color: done ? "#fff" : active ? "#fff" : "var(--fg-tertiary)" }}>
    <span style={{ color: active ? "var(--brand-red)" : "var(--fg-tertiary)" }}>{n}</span>
    <span style={{ textAlign: "right", fontWeight: active ? 700 : 400 }}>{w}</span>
    <span style={{ textAlign: "right" }}>{r}</span>
    <span style={{ textAlign: "right" }}>{rpe}</span>
    <span style={{ textAlign: "right", color: done ? "var(--green)" : "var(--fg-tertiary)" }}>{done ? "✓" : "○"}</span>
  </div>
);

// ============================================================
// 4) 学员端 · 计划总览
// ============================================================
const StudentPlanView = () => (
  <div className="screen">
    <StatusBar />
    <div className="navbar-large" style={{ padding: "0 16px 12px" }}>
      <Eyebrow>中周期 · 第 03 / 04 周</Eyebrow>
      <h1 style={{ fontFamily: "var(--font-display-cn)", fontSize: 38, fontWeight: 900, margin: "4px 0 0", letterSpacing: "-0.02em" }}>SBD 力量块</h1>
      <div style={{ color: "var(--fg-secondary)", fontSize: 13, marginTop: 4 }}>张教练 · 顶组 + 减载</div>
    </div>
    <div className="scroll" style={{ padding: 16 }}>

      <div style={{ display: "flex", gap: 6 }}>
        {[1,1,0.6,0].map((p, i) => (
          <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: p === 1 ? "var(--green)" : p === 0 ? "transparent" : "linear-gradient(to right,#fff 60%,#262626 60%)", border: p === 0 ? "1px solid var(--border)" : "none" }}/>
        ))}
      </div>

      <div className="mono" style={{ fontSize: 10, color: "var(--fg-tertiary)", letterSpacing: "0.08em", marginTop: 20, marginBottom: 8, textTransform: "uppercase" }}>本周</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 6 }}>
        {[
          ["一","蹲",true,false],
          ["二","—",false,false],
          ["三","卧",true,false],
          ["四","硬",false,true],
          ["五","—",false,false],
          ["六","蹲",false,false],
          ["日","—",false,false],
        ].map(([d,e,done,active], i) => (
          <div key={i} style={{ aspectRatio: "1", background: active ? "var(--surface-2)" : "var(--surface-1)", border: active ? "1px solid #fff" : "1px solid var(--border)", borderRadius: 8, padding: 8, display: "flex", flexDirection: "column", justifyContent: "space-between", position: "relative" }}>
            <span style={{ fontSize: 11, color: active ? "#fff" : "var(--fg-tertiary)" }}>{d}</span>
            <span style={{ fontSize: 14, fontWeight: 600, color: e === "—" ? "var(--fg-tertiary)" : "#fff" }}>{e}</span>
            {done && <div style={{ position: "absolute", top: 0, right: 0, width: 0, height: 0, borderTop: "10px solid var(--brand-red)", borderLeft: "10px solid transparent" }}/>}
          </div>
        ))}
      </div>

      <div className="card" style={{ marginTop: 24 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
          <div>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>深蹲 e1RM · 90 天</div>
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
          <span>203 KG · 1 月 28</span><span>218 KG · 现在</span>
        </div>
      </div>

      <button className="btn-primary" style={{ marginTop: 16 }}>开始 W3D1 · 深蹲</button>
    </div>
    <TabBar items={STUDENT_TABS_CN} active="plan"/>
  </div>
);

// ============================================================
// 5) 登录流程
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
            <h1 style={{ fontFamily: "var(--font-display-cn)", fontSize: 30, fontWeight: 900, margin: "8px 0 0", lineHeight: 1.2, letterSpacing: "-0.02em" }}>今天,<br/>比昨天更强一点。</h1>
            <div style={{ width: 48, height: 3, background: "var(--brand-red)", marginTop: 16 }}/>
            <div style={{ color: "var(--fg-secondary)", fontSize: 15, marginTop: 12, lineHeight: 1.4 }}>
              输入手机号,我们将发送验证码。
            </div>

            <div style={{ marginTop: 32 }}>
              <div className="mono" style={{ fontSize: 10, color: "var(--fg-tertiary)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 8 }}>手机号</div>
              <div style={{ display: "flex", gap: 8 }}>
                <div style={{ background: "var(--surface-1)", border: "1px solid var(--border)", borderRadius: 8, padding: 14, color: "#fff", fontSize: 17, fontFamily: "var(--font-mono)" }}>+86</div>
                <input defaultValue="138 0000 0000" style={{ flex: 1, background: "var(--surface-1)", border: "1px solid #fff", borderRadius: 8, padding: 14, color: "#fff", fontSize: 17, fontFamily: "var(--font-mono)", letterSpacing: "0.04em" }}/>
              </div>
            </div>

            <div style={{ flex: 1 }}/>
            <button className="btn-primary" onClick={()=>setStep(1)}>发送验证码</button>
            <button disabled style={{ marginTop: 10, padding: "14px 20px", background: "transparent", border: "1px solid var(--border)", borderRadius: 10, color: "var(--fg-tertiary)", fontSize: 15, fontWeight: 600, display: "flex", alignItems: "center", justifyContent: "center", gap: 8, opacity: 0.55, cursor: "not-allowed" }}>
              <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516.024.034 1.52.087 2.475-1.258.955-1.345.762-2.391.728-2.43Zm3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422.212-2.189 1.675-2.789 1.698-2.854.023-.065-.597-.79-1.254-1.157a3.692 3.692 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56.244.729.625 1.924 1.273 2.796.576.984 1.34 1.667 1.659 1.899.319.232 1.219.386 1.843.067.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758.347-.79.505-1.217.473-1.282Z"/></svg>
              使用 Apple ID 登录
              <span className="mono" style={{ fontSize: 10, marginLeft: 4, padding: "2px 6px", background: "var(--surface-2)", borderRadius: 4, letterSpacing: "0.06em" }}>即将开放</span>
            </button>
          </>
        ) : (
          <>
            <Eyebrow>注册 · 角色</Eyebrow>
            <h1 style={{ fontSize: 36, fontWeight: 800, margin: "8px 0 0", lineHeight: 0.95, letterSpacing: "-0.02em" }}>选择你的角色</h1>
            <div style={{ color: "var(--fg-secondary)", fontSize: 14, marginTop: 12, lineHeight: 1.4 }}>
              注册后角色将锁定。<span style={{ color: "var(--fg-tertiary)" }}>多角色支持在 V1.5 评估。</span>
            </div>

            <div style={{ marginTop: 24, display: "flex", flexDirection: "column", gap: 10 }}>
              <RoleCard active title="学员 · 有教练" sub="接收计划 · 记录训练 · 上传视频" tag="COACHED"/>
              <RoleCard title="学员 · 自己练" sub="选择训练模板 · 自主跟练" tag="SELF_TRAIN"/>
              <RoleCard title="教练" sub="编排周期 · 审阅学员 · 反馈视频" tag="COACH"/>
            </div>

            <div style={{ flex: 1 }}/>
            <button className="btn-primary">继续</button>
            <button onClick={()=>setStep(0)} style={{ marginTop: 12, background: "transparent", border: "none", color: "var(--fg-tertiary)", fontSize: 14 }}>← 更换手机号</button>
          </>
        )}
      </div>
    </div>
  );
};

const RoleCard = ({ active, title, sub, tag }) => (
  <div style={{ background: active ? "var(--surface-2)" : "var(--surface-1)", border: active ? "1px solid #fff" : "1px solid var(--border)", borderRadius: 12, padding: 16, display: "flex", alignItems: "center", gap: 12 }}>
    <div style={{ width: 22, height: 22, borderRadius: "50%", border: active ? "6px solid #fff" : "1.5px solid var(--fg-tertiary)", background: active ? "var(--bg)" : "transparent" }}/>
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
