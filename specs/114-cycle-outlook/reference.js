// spec 114 本周期主项走势 · 参考实现（v2）
// 两端各自实现同样的纯函数，用 cycle-outlook-cases.json 逐项对齐。
// 输入是「一个主项一行」已经挑好的每周一组；挑组本身（每周取分数最高的工作组）
// 也用 score()，两端在各自代码里做。

const RTS = [ // 扩展版 RPE 表（spec 106），行=1–12 次，列=RPE 6.0–10.0 每 0.5
  [0.863, 0.878, 0.892, 0.907, 0.922, 0.939, 0.955, 0.978, 1],
  [0.837, 0.85, 0.863, 0.878, 0.892, 0.907, 0.922, 0.939, 0.955],
  [0.811, 0.824, 0.837, 0.85, 0.863, 0.878, 0.892, 0.907, 0.922],
  [0.786, 0.799, 0.811, 0.824, 0.837, 0.85, 0.863, 0.878, 0.892],
  [0.762, 0.774, 0.786, 0.799, 0.811, 0.824, 0.837, 0.85, 0.863],
  [0.739, 0.751, 0.762, 0.774, 0.786, 0.799, 0.811, 0.824, 0.837],
  [0.707, 0.723, 0.739, 0.751, 0.762, 0.774, 0.786, 0.799, 0.811],
  [0.68, 0.694, 0.707, 0.723, 0.739, 0.751, 0.762, 0.774, 0.786],
  [0.653, 0.667, 0.68, 0.694, 0.707, 0.723, 0.739, 0.751, 0.762],
  [0.626, 0.64, 0.653, 0.667, 0.68, 0.694, 0.707, 0.723, 0.739],
  [0.599, 0.6125, 0.626, 0.64, 0.653, 0.667, 0.68, 0.694, 0.707],
  [0.572, 0.5855, 0.599, 0.6125, 0.626, 0.64, 0.653, 0.667, 0.68],
];
const K = { weightExponent: 2, repBonus: 0.03, coachRpePenalty: 0.03, floorOfTop: 0.85, equalRatio: 0.6, increment: 2.5 };

function rts(reps, rpe) {
  if (!Number.isInteger(reps) || reps < 1 || reps > 12 || rpe < 6 || rpe > 10) return null;
  const row = RTS[reps - 1], p = (rpe - 6) / 0.5, i = Math.floor(p), f = p - i;
  return row[i] * (1 - f) + row[Math.min(i + 1, 8)] * f;
}
const floorTo = kg => Math.floor(kg / K.increment + 1e-6) * K.increment;
const epley = (kg, reps) => kg * (1 + reps / 30);

// 一组处方：{ kg|null, pct|null, reps, rpe|null, e1rmKg? }；kg 只放教练写死的重量（固定或区间上限）
// 一组实际：{ kg, reps, rpe|null }
// e1rmKg：学员当前 e1RM；oneRmKg：登记 1RM（百分比组用）
function resolveLoad(set, ctx) {
  if (set.kg != null) return { kg: set.kg, source: 'coach' };
  if (set.e1rmKg != null) return { kg: set.e1rmKg, source: 'e1rm' }; // 两端已算好的「约 X」，测试夹具直接给
  if (set.pct != null && ctx.oneRmKg) return { kg: floorTo(ctx.oneRmKg * set.pct / 100), source: 'pct' };
  if (set.rpe != null) {
    const e = ctx.e1rmKg ?? ctx.planEstimateKg; // M2：没有 e1RM 时用本行写了重量的周估一个
    const f = rts(set.reps, set.rpe);
    if (e && f) return { kg: floorTo(e * f), source: 'e1rm' };
  }
  return { kg: null, source: null };
}

function score(load, set, fixedRpe) {
  const intensity = load.kg != null ? load.kg : set.pct != null ? set.pct / 100 : rts(set.reps, set.rpe);
  if (intensity == null) return null;
  const penalty = fixedRpe && set.rpe != null ? K.coachRpePenalty * set.rpe : 0;
  return Math.pow(intensity, K.weightExponent) * (1 + K.repBonus * set.reps - penalty);
}

// weeks[i] = { state: 'unscheduled' } | { state: 'notTrained' } |
//            { state: 'scheduled', done: bool, plan: Set, actual: Set|null|'skipped' }
function cycleOutlookRow(weeks, { e1rmKg = null, oneRmKg = null, currentWeekIndex = -1 } = {}) {
  // M2：只有在没有 e1RM 时才用，取本行教练写死重量的周里 Epley 最大值
  const coachKg = weeks.filter(w => w.state === 'scheduled' && w.plan.kg != null).map(w => epley(w.plan.kg, w.plan.reps));
  const ctx = { e1rmKg, oneRmKg, planEstimateKg: e1rmKg ? null : coachKg.length ? Math.max(...coachKg) : null };

  const cells = weeks.map((w, i) => {
    const base = { state: w.state, isCurrent: i === currentWeekIndex };
    if (w.state !== 'scheduled') return base;
    if (w.done && w.actual === 'skipped') return { ...base, done: true, skipped: true, main: '没做', sub: '' };
    const useActual = w.done && w.actual;
    const set = useActual ? w.actual : w.plan;
    const load = useActual ? { kg: w.actual.kg, source: 'actual' } : resolveLoad(w.plan, ctx);
    const s = score(load, set, load.source === 'coach' || load.source === 'actual' && w.plan.kg != null);
    let main, sub;
    if (load.kg == null) {
      if (set.pct != null) { main = `${set.pct}%`; sub = `×${set.reps}`; }
      else { main = `${set.reps} @${set.rpe}`; sub = 'RPE'; }
    } else {
      main = `${load.source === 'e1rm' ? '约' : ''}${load.kg}`;
      const reps = useActual && w.actual.reps < w.plan.reps ? `${w.actual.reps}/${w.plan.reps}` : `${set.reps}`;
      sub = `×${reps}${set.rpe != null ? ` @${set.rpe}` : ''}`;
    }
    return { ...base, done: !!w.done, short: !!(useActual && w.actual.reps < w.plan.reps), main, sub, _score: s, _hasKg: load.kg != null };
  });

  // 已练完但没做的周：按处方算高度，不参与金色
  cells.forEach((c, i) => {
    if (c.skipped) {
      const load = resolveLoad(weeks[i].plan, ctx);
      c._score = score(load, weeks[i].plan, load.source === 'coach'); c._hasKg = load.kg != null; c._noTop = true;
    }
  });
  const scored = cells.filter(c => c._score != null);
  const anyKg = scored.some(c => c._hasKg);
  const cmp = scored.filter(c => !anyKg || c._hasKg);
  const v = cmp.map(c => c._score);
  const hi = Math.max(...v), mn = Math.min(...v), lo = Math.min(mn, hi * K.floorOfTop);
  let top = null;
  cmp.forEach(c => { if (!c._noTop && (top == null || c._score >= top._score - 1e-9)) top = c; });
  return cells.map(c => {
    const out = { ...c };
    if (c._score != null) {
      out.ratio = !cmp.includes(c) || hi - mn < 1e-9 ? K.equalRatio : Math.round((c._score - lo) / (hi - lo) * 1e4) / 1e4;
      out.isTop = c === top;
    }
    delete out._score; delete out._hasKg; delete out._noTop;
    return out;
  });
}

module.exports = { RTS, K, rts, score, resolveLoad, cycleOutlookRow };
