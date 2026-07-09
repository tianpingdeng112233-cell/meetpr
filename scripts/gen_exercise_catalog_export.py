#!/usr/bin/env python3
"""Export exercise-catalog-v2.json into a self-contained HTML browser + a CSV.

Chinese labels reuse the app's PlanningDisplay terms (so wording matches what the
coach sees in-app), but muscle groups the app collapses into 「其他」for compact
facet chips (trap/tibialis/grip/mobility/cardio) and 髋 (hip/hip_flexor) are split
back into precise labels here — an export should not lose information.
"""
import json, csv, datetime, html, pathlib

SRC = "/Users/david/Projects/apps/MeetPR/Modules/CoachKit/Sources/CoachKit/Resources/exercise-catalog-v2.json"
OUT_DIR = pathlib.Path("/Users/david/Projects/scratch")

TYPE_ZH = {
    "main_lift": "主项",
    "main_lift_variation": "主项变式",
    "accessory": "辅助动作",
}
FAMILY_ZH = {"squat": "深蹲", "bench": "卧推", "deadlift": "硬拉", None: "—"}
MUSCLE_ZH = {  # precise labels (app collapses the last group into 其他/髋)
    "chest": "胸", "shoulder": "肩", "back": "背", "biceps": "二头",
    "triceps": "三头", "forearm": "小臂", "core": "核心", "quad": "股四",
    "hamstring": "腘绳", "glute": "臀", "hip": "髋", "hip_flexor": "屈髋肌",
    "adductor": "内收", "calf": "小腿", "trap": "斜方", "tibialis": "胫前",
    "grip": "握力", "mobility": "灵活性", "cardio": "有氧",
}
EQUIP_ZH = {
    "barbell": "杠铃", "dumbbell": "哑铃", "machine": "器械", "bodyweight": "自重",
    "cable": "绳索", "band": "弹力带", "kettlebell": "壶铃",
    "specialty_bar": "特殊杆", "other": "其他",
}
PATTERN_ZH = {
    "squat": "蹲", "horizontal_push": "水平推", "vertical_push": "垂直推",
    "hip_hinge": "髋铰链", "horizontal_pull": "水平拉", "vertical_pull": "垂直拉",
    "warm_up": "热身", "other": "其他",
}

def zh_list(vals, m):
    out, seen = [], set()
    for v in vals or []:
        z = m.get(v, v)
        if z not in seen:
            seen.add(z); out.append(z)
    return out

items = json.load(open(SRC))
rows = []
for it in items:
    rows.append({
        "name": it["name"],
        "nameEn": it.get("nameEn") or "",
        "type": TYPE_ZH.get(it["exerciseType"], it["exerciseType"]),
        "family": FAMILY_ZH.get(it.get("mainLiftFamily"), it.get("mainLiftFamily") or "—"),
        "comp": it.get("isCompetitionLift", False),
        "muscles": zh_list(it.get("muscleGroups"), MUSCLE_ZH),
        "equipment": zh_list(it.get("equipment"), EQUIP_ZH),
        "patterns": zh_list(it.get("movementPattern"), PATTERN_ZH),
        "id": it["id"],
    })
# stable, readable order: 主项变式 first, then by family, then name
type_rank = {"主项": 0, "主项变式": 1, "辅助动作": 2}
rows.sort(key=lambda r: (type_rank.get(r["type"], 9), r["family"], r["name"]))

today = datetime.date.today().isoformat()

# ---------- CSV (Excel-friendly, UTF-8 BOM) ----------
csv_path = OUT_DIR / "exercise-catalog-v2.csv"
with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f)
    w.writerow(["中文名", "English", "类型", "主项归属", "比赛动作", "肌群", "器械", "动作模式", "id"])
    for r in rows:
        w.writerow([
            r["name"], r["nameEn"], r["type"], r["family"],
            "是" if r["comp"] else "",
            " / ".join(r["muscles"]), " / ".join(r["equipment"]),
            " / ".join(r["patterns"]), r["id"],
        ])

# ---------- HTML (self-contained browser) ----------
data_json = json.dumps(rows, ensure_ascii=False)

PAGE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeetPR 动作库 v2 (__TOTAL__ 条)</title>
<style>
  :root{
    --bg:#0f1115; --panel:#171a21; --panel2:#1d212b; --line:#2a2f3a;
    --txt:#e7eaf0; --muted:#9aa3b2; --accent:#5b8cff; --chip:#232838; --chip-b:#323a4e;
    --variation:#7c5cff; --accessory:#3aa0ff;
  }
  @media (prefers-color-scheme: light){
    :root{ --bg:#f6f7f9; --panel:#fff; --panel2:#f0f2f6; --line:#e2e5ec;
      --txt:#1b1f27; --muted:#6b7280; --chip:#eef1f7; --chip-b:#d8deea; }
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--txt);
    font:14px/1.5 -apple-system,BlinkMacSystemFont,"PingFang SC","Hiragino Sans GB","Microsoft YaHei",Segoe UI,sans-serif;}
  header{padding:20px 24px 12px;border-bottom:1px solid var(--line);background:var(--panel);position:sticky;top:0;z-index:5}
  h1{margin:0;font-size:19px;font-weight:650;letter-spacing:.3px}
  .sub{color:var(--muted);font-size:12.5px;margin-top:4px}
  .stats{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
  .stat{background:var(--panel2);border:1px solid var(--line);border-radius:8px;padding:6px 11px;font-size:12.5px}
  .stat b{font-size:15px;font-weight:650}
  .controls{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-top:14px}
  input[type=search],select{background:var(--panel2);color:var(--txt);border:1px solid var(--line);
    border-radius:8px;padding:8px 11px;font-size:13.5px;outline:none}
  input[type=search]{min-width:240px;flex:1 1 260px}
  input[type=search]:focus,select:focus{border-color:var(--accent)}
  .count{margin-left:auto;color:var(--muted);font-size:12.5px;white-space:nowrap}
  .reset{background:none;border:1px solid var(--line);color:var(--muted);border-radius:8px;padding:8px 11px;cursor:pointer;font-size:13px}
  .reset:hover{color:var(--txt);border-color:var(--accent)}
  .wrap{padding:0 24px 60px}
  table{width:100%;border-collapse:collapse;margin-top:14px;font-size:13.5px}
  thead th{position:sticky;top:0;background:var(--panel);text-align:left;font-weight:600;
    color:var(--muted);padding:9px 10px;border-bottom:1px solid var(--line);font-size:12px;
    white-space:nowrap;cursor:pointer;user-select:none}
  thead th.no-sort{cursor:default}
  thead th .arrow{opacity:.4;font-size:10px}
  tbody td{padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top}
  tbody tr:hover{background:var(--panel2)}
  .num{color:var(--muted);font-variant-numeric:tabular-nums;text-align:right;width:46px}
  .zhname{font-weight:600}
  .en{color:var(--muted);font-size:12.5px}
  .badge{display:inline-block;padding:1.5px 8px;border-radius:20px;font-size:11.5px;font-weight:600;white-space:nowrap}
  .b-var{background:color-mix(in srgb,var(--variation) 18%,transparent);color:var(--variation)}
  .b-acc{background:color-mix(in srgb,var(--accessory) 16%,transparent);color:var(--accessory)}
  .b-main{background:color-mix(in srgb,#ff7a59 18%,transparent);color:#ff7a59}
  .fam{color:var(--muted)}
  .tag{display:inline-block;background:var(--chip);border:1px solid var(--chip-b);border-radius:6px;
    padding:1px 7px;margin:1px 3px 1px 0;font-size:11.5px;color:var(--txt)}
  .empty{padding:40px;text-align:center;color:var(--muted)}
  mark{background:color-mix(in srgb,var(--accent) 35%,transparent);color:inherit;border-radius:3px;padding:0 1px}
</style>
</head>
<body>
<header>
  <h1>MeetPR 动作库 v2</h1>
  <div class="sub">来源 <code>CoachKit/Resources/exercise-catalog-v2.json</code> · 共 __TOTAL__ 条 · 导出 __DATE__</div>
  <div class="stats" id="stats"></div>
  <div class="controls">
    <input type="search" id="q" placeholder="搜索中文 / 英文动作名…">
    <select id="fType"></select>
    <select id="fFamily"></select>
    <select id="fMuscle"></select>
    <select id="fEquip"></select>
    <select id="fPattern"></select>
    <button class="reset" id="reset">重置</button>
    <span class="count" id="count"></span>
  </div>
</header>
<div class="wrap">
  <table>
    <thead><tr>
      <th class="no-sort num">#</th>
      <th data-sort="name">中文名 <span class="arrow">↕</span></th>
      <th data-sort="nameEn">English <span class="arrow">↕</span></th>
      <th data-sort="type">类型 <span class="arrow">↕</span></th>
      <th data-sort="family">主项归属 <span class="arrow">↕</span></th>
      <th class="no-sort">肌群</th>
      <th class="no-sort">器械</th>
      <th class="no-sort">动作模式</th>
    </tr></thead>
    <tbody id="tb"></tbody>
  </table>
  <div class="empty" id="empty" style="display:none">没有匹配的动作</div>
</div>
<script>
const DATA = __DATA__;
const $ = s => document.querySelector(s);
const badge = t => t==='主项变式' ? '<span class="badge b-var">'+t+'</span>'
                  : t==='辅助动作' ? '<span class="badge b-acc">'+t+'</span>'
                  : '<span class="badge b-main">'+t+'</span>';
const esc = s => s.replace(/[&<>]/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
function hl(s, q){ s=esc(s); if(!q) return s;
  try{ return s.replace(new RegExp('('+q.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&')+')','ig'),'<mark>$1</mark>'); }catch(e){ return s; } }

// build filter dropdowns
function uniq(key){ const s=new Set(); DATA.forEach(r=>{ if(Array.isArray(r[key])) r[key].forEach(v=>s.add(v)); else s.add(r[key]); }); return [...s].filter(v=>v&&v!=='—').sort((a,b)=>a.localeCompare(b,'zh')); }
function fill(sel, label, vals){ sel.innerHTML='<option value="">'+label+'</option>'+vals.map(v=>'<option>'+v+'</option>').join(''); }
fill($('#fType'),'全部类型',uniq('type'));
fill($('#fFamily'),'全部主项',uniq('family'));
fill($('#fMuscle'),'全部肌群',uniq('muscles'));
fill($('#fEquip'),'全部器械',uniq('equipment'));
fill($('#fPattern'),'全部模式',uniq('patterns'));

// stats
const byType = {}; DATA.forEach(r=>byType[r.type]=(byType[r.type]||0)+1);
$('#stats').innerHTML = '<span class="stat"><b>'+DATA.length+'</b> 总动作</span>' +
  Object.entries(byType).map(([k,v])=>'<span class="stat"><b>'+v+'</b> '+k+'</span>').join('');

let sortKey=null, sortDir=1;
function apply(){
  const q=$('#q').value.trim().toLowerCase();
  const ft=$('#fType').value, ff=$('#fFamily').value, fm=$('#fMuscle').value, fe=$('#fEquip').value, fp=$('#fPattern').value;
  let list = DATA.filter(r=>
    (!q || r.name.toLowerCase().includes(q) || r.nameEn.toLowerCase().includes(q)) &&
    (!ft || r.type===ft) && (!ff || r.family===ff) &&
    (!fm || r.muscles.includes(fm)) && (!fe || r.equipment.includes(fe)) && (!fp || r.patterns.includes(fp)));
  if(sortKey){ list=[...list].sort((a,b)=>String(a[sortKey]).localeCompare(String(b[sortKey]),'zh')*sortDir); }
  const tb=$('#tb');
  tb.innerHTML = list.map((r,i)=>'<tr>'+
    '<td class="num">'+(i+1)+'</td>'+
    '<td class="zhname">'+hl(r.name,q)+'</td>'+
    '<td class="en">'+hl(r.nameEn,q)+'</td>'+
    '<td>'+badge(r.type)+'</td>'+
    '<td class="fam">'+r.family+'</td>'+
    '<td>'+r.muscles.map(t=>'<span class="tag">'+t+'</span>').join('')+'</td>'+
    '<td>'+r.equipment.map(t=>'<span class="tag">'+t+'</span>').join('')+'</td>'+
    '<td>'+r.patterns.map(t=>'<span class="tag">'+t+'</span>').join('')+'</td>'+
  '</tr>').join('');
  $('#empty').style.display = list.length ? 'none':'block';
  $('#count').textContent = list.length===DATA.length ? (DATA.length+' 条') : (list.length+' / '+DATA.length+' 条');
}
['#q','#fType','#fFamily','#fMuscle','#fEquip','#fPattern'].forEach(s=>$(s).addEventListener('input',apply));
$('#reset').addEventListener('click',()=>{['#q','#fType','#fFamily','#fMuscle','#fEquip','#fPattern'].forEach(s=>$(s).value='');sortKey=null;apply();});
document.querySelectorAll('th[data-sort]').forEach(th=>th.addEventListener('click',()=>{
  const k=th.dataset.sort; if(sortKey===k){sortDir*=-1;}else{sortKey=k;sortDir=1;} apply();
}));
apply();
</script>
</body>
</html>"""

html_out = (PAGE
            .replace("__TOTAL__", str(len(rows)))
            .replace("__DATE__", today)
            .replace("__DATA__", data_json))
html_path = OUT_DIR / "exercise-catalog-v2.html"
html_path.write_text(html_out, encoding="utf-8")

print(f"rows: {len(rows)}")
print(f"HTML: {html_path}  ({html_path.stat().st_size//1024} KB)")
print(f"CSV : {csv_path}  ({csv_path.stat().st_size//1024} KB)")
