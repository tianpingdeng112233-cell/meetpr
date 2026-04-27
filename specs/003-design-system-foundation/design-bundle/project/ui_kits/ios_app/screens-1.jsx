/* global React, MeetPR */
const { Icon, StatusBar, TabBar, COACH_TABS, STUDENT_TABS, Eyebrow, LoadingBar } = MeetPR;

// 中文版 tab 标签
const COACH_TABS_CN = COACH_TABS.map(t => ({ ...t, label: ({today:"今日",plan:"计划",athletes:"学员",inbox:"消息",profile:"我的"})[t.key] }));
const STUDENT_TABS_CN = STUDENT_TABS.map(t => ({ ...t, label: ({today:"训练",plan:"计划",history:"记录",profile:"我的"})[t.key] }));

// ============================================================
// 1) 教练端 · 今日仪表盘
// ============================================================
const CoachDashboard = () => (
  <div className="screen">
    <StatusBar />
    <div className="navbar-large" style={{ padding: "0 16px 12px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
        <div>
          <Eyebrow>周一 · 第 03 周</Eyebrow>
          <h1 style={{ fontSize: 34, fontWeight: 700, margin: "4px 0 0", letterSpacing: "-0.01em" }}>今日</h1>
        </div>
        <div style={{ display:"flex", gap: 8 }}>
          <button style={{ width: 36, height: 36, borderRadius: 999, background: "var(--surface-1)", border: "1px solid var(--border)", color: "#fff" }}><Icon name="bell" size={18}/></button>
          <button style={{ width: 36, height: 36, borderRadius: 999, background: "var(--surface-1)", border: "1px solid var(--border)", color: "#fff" }}><Icon name="plus" size={18}/></button>
        </div>
      </div>
    </div>
    <LoadingBar/>
    <div className="scroll" style={{ padding: "16px" }}>
      <div className="card elevated" style={{ marginBottom: 16, borderColor: "rgba(229,34,30,0.3)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
          <span style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--brand-red)" }}/>
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase", fontWeight: 500 }}>新学员请求 // 02</span>
        </div>
        <div style={{ fontSize: 17, fontWeight: 600, lineHeight: 1.3 }}>2 名新学员等待你接收</div>
        <div style={{ fontSize: 14, color: "var(--fg-secondary)", marginTop: 6, lineHeight: 1.4 }}>已等待 18 小时 · 已完成资料填写</div>
        <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
          <button style={{ flex:1, padding: "10px 12px", background: "#fff", color: "#000", border: "none", borderRadius: 10, fontWeight: 600, fontSize: 14 }}>查看队列</button>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", gap: 24 }}>
          <div style={{ flex:1 }}>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>学员</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 36, fontWeight: 800, fontVariantNumeric: "tabular-nums", letterSpacing: "-0.02em" }}>14</span>
              <span style={{ fontSize: 13, color: "var(--fg-tertiary)" }}>活跃</span>
            </div>
          </div>
          <div style={{ width: 1, background: "var(--border)" }}/>
          <div style={{ flex:1 }}>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>评估期</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 36, fontWeight: 800, fontVariantNumeric: "tabular-nums", letterSpacing: "-0.02em", color: "var(--amber)" }}>3</span>
              <span style={{ fontSize: 13, color: "var(--fg-tertiary)" }}>进行中</span>
            </div>
          </div>
          <div style={{ width: 1, background: "var(--border)" }}/>
          <div style={{ flex:1 }}>
            <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase" }}>待反馈</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 36, fontWeight: 800, fontVariantNumeric: "tabular-nums", letterSpacing: "-0.02em" }}>12</span>
              <span style={{ fontSize: 13, color: "var(--fg-tertiary)" }}>视频</span>
            </div>
          </div>
        </div>
      </div>

      <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-tertiary)", letterSpacing: "0.08em", textTransform: "uppercase", margin: "16px 4px 8px" }}>学员 — 今日</div>
      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        <AthleteRow name="陈磊" sub="W3D1 · 2 小时前已记录 · 3 视频待看" badge={<span className="badge badge-pr">e1RM PR</span>} dotColor="#fff"/>
        <AthleteRow name="张宇" sub="W3D1 · 第 3/4 组" badge={<span className="badge badge-live"><span className="dot-pulse"/>训练中</span>} dotColor="var(--brand-red)" border/>
        <AthleteRow name="马伟" sub="评估期 · 还剩 4 天 · 资料 6/9" badge={<span className="badge badge-pending" style={{ color: "var(--amber)", borderColor: "rgba(224,168,16,0.3)" }}>评估中</span>} dotColor="var(--amber)" border/>
        <AthleteRow name="严博" sub="W2D3 · 落后 5 天" badge={<span className="badge badge-overdue">逾期</span>} dotColor="var(--amber)" border/>
        <AthleteRow name="刘浩" sub="W3D1 · 已就绪 · 09:00" badge={<span className="badge badge-ready">就绪</span>} dotColor="var(--green)" border/>
      </div>
    </div>
    <TabBar items={COACH_TABS_CN} active="today"/>
  </div>
);

const AthleteRow = ({ name, sub, badge, dotColor, border }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 16px", minHeight: 56, boxSizing: "border-box", borderTop: border ? "1px solid var(--border)" : "none" }}>
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
// 2) 教练端 · 计划编辑器
// ============================================================
const PlanningEditor = () => {
  const [expanded, setExpanded] = React.useState(false);
  const days = ["一","二","三","四","五","六","日"];
  const weeks = [
    ["蹲 顶","—","卧","硬 顶","—","蹲 减","—"],
    ["蹲 顶","—","卧 +5","硬 顶","—","蹲 减","—"],
    ["蹲 顶+","—","卧 +5","硬 顶+","—","蹲 减","—"],
    ["蹲 极限","—","卧 极限","硬 极限","—","—","—"],
  ];
  const visibleWeeks = expanded ? weeks : [weeks[2]];
  const visibleStartIdx = expanded ? 0 : 2;
  return (
    <div className="screen">
      <StatusBar />
      <div className="navbar">
        <button style={{ background: "transparent", border: "none", color: "#fff", display:"flex", alignItems:"center", gap:4, fontSize:15, padding: 0 }}>
          <Icon name="chevL" size={18}/> 学员
        </button>
        <div className="navbar-title">中周期 · 陈磊</div>
        <button style={{ background: "transparent", border: "none", color: "var(--brand-red)", fontWeight: 600, fontSize: 15 }}>发布</button>
      </div>
      <div className="scroll" style={{ padding: 16 }}>
        <Eyebrow>中周期 · W3 / W4</Eyebrow>
        <h2 style={{ fontFamily: "var(--font-display-cn)", fontSize: 30, fontWeight: 900, margin: "6px 0 4px", letterSpacing: "-0.02em" }}>陈磊 · SBD 力量块</h2>
        <div style={{ color: "var(--fg-secondary)", fontSize: 14 }}>4 周 · 顶组 + 减载 · 第 03 周 编辑中</div>
        <button style={{ marginTop: 12, padding: "8px 12px", background: "var(--surface-1)", border: "1px solid var(--border)", borderRadius: 8, color: "#fff", fontSize: 13, fontWeight: 600, display: "inline-flex", alignItems: "center", gap: 6 }}>
          <Icon name="check" size={14}/> 复制上周计划
        </button>

        <div style={{ display: "flex", gap: 6, marginTop: 20 }}>
          {[1,1,0.4,0].map((p, i) => (
            <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: p === 1 ? "var(--green)" : p === 0 ? "transparent" : "linear-gradient(to right,#fff 40%,#262626 40%)", border: p === 0 ? "1px solid var(--border)" : "none" }}/>
          ))}
        </div>
        <div className="mono" style={{ display: "flex", justifyContent: "space-between", fontSize: 10, color: "var(--fg-tertiary)", letterSpacing: "0.08em", marginTop: 6 }}>
          <span>W1 ✓</span><span>W2 ✓</span><span>W3 · 40%</span><span>W4</span>
        </div>

        <div className="card" style={{ marginTop: 16, padding: 0, overflow: "hidden" }}>
          <div style={{ display: "grid", gridTemplateColumns: "32px repeat(7, 1fr)", gap: 1, background: "var(--border)", padding: 1 }}>
            <div style={{ background: "var(--surface-1)", padding: "8px 6px", fontSize: 9, fontFamily: "var(--font-mono)", color: "var(--fg-tertiary)", letterSpacing: "0.08em" }}></div>
            {days.map(d => (
              <div key={d} style={{ background: "var(--surface-1)", padding: "8px 6px", fontSize: 11, color: "var(--fg-tertiary)", textAlign: "center" }}>{d}</div>
            ))}
            {visibleWeeks.map((week, vi) => {
              const wi = visibleStartIdx + vi;
              return (
                <React.Fragment key={wi}>
                  <div style={{ background: "var(--surface-1)", padding: "12px 6px", fontSize: 10, fontFamily: "var(--font-mono)", color: wi === 2 ? "var(--brand-red)" : "var(--fg-tertiary)", letterSpacing: "0.08em", textAlign: "center", fontWeight: 600 }}>W{wi+1}</div>
                  {week.map((cell, di) => {
                    const isCurrent = wi === 2 && di === 0;
                    const empty = cell === "—";
                    return (
                      <div key={di} style={{ background: isCurrent ? "var(--surface-2)" : "var(--surface-1)", padding: "12px 4px", textAlign: "center", fontSize: 11, fontWeight: empty ? 400 : 600, color: empty ? "var(--fg-tertiary)" : "#fff", border: isCurrent ? "1px solid #fff" : "none", position: "relative" }}>
                        {cell}
                        {wi < 2 && !empty && (
                          <div style={{ position: "absolute", top: 2, right: 2, width: 0, height: 0, borderTop: "6px solid var(--brand-red)", borderLeft: "6px solid transparent" }}/>
                        )}
                      </div>
                    );
                  })}
                </React.Fragment>
              );
            })}
          </div>
          <button onClick={()=>setExpanded(e=>!e)} style={{ width: "100%", padding: "10px 12px", background: "var(--surface-1)", border: "none", borderTop: "1px solid var(--border)", color: "var(--fg-secondary)", fontSize: 12, fontFamily: "var(--font-mono)", letterSpacing: "0.06em", textTransform: "uppercase", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}>
            {expanded ? "收起 ↑" : `展开 4 周中周期 ↓`}
          </button>
        </div>

        <div className="mono" style={{ fontSize: 10, color: "var(--brand-red)", letterSpacing: "0.08em", textTransform: "uppercase", marginTop: 20 }}>已选 · W3 D1 — 深蹲</div>
        <div className="card" style={{ marginTop: 8, padding: 0 }}>
          <ExerciseRow name="深蹲" detail="顶组 @ RPE 8.5" sets="1 × 3"/>
          <ExerciseRow name="深蹲" detail="减载 −10%" sets="3 × 5" border/>
          <ExerciseRow name="暂停深蹲" detail="2 秒暂停 @ RPE 7" sets="3 × 5" border/>
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
