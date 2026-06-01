import { useState } from "react";
import {
  LineChart, Line, AreaChart, Area,
  BarChart, Bar, XAxis, YAxis,
  Tooltip, ResponsiveContainer, Cell
} from "recharts";

// ── THEME ────────────────────────────────────────────────────────────────────
const T = {
  bg:           "#050C08",
  card:         "rgba(14, 28, 20, 0.72)",       // стекло — изумруд
  cardRuby:     "rgba(22, 10, 14, 0.72)",       // стекло — рубин
  cardSolid:    "#0C1A10",
  border:       "rgba(255,255,255,0.07)",
  borderAccent: "rgba(22,168,115,0.25)",
  borderRuby:   "rgba(184,41,74,0.22)",
  accent:       "#0D7A58",
  accentBright: "#1DBF88",
  accentGlow:   "rgba(29,191,136,0.35)",
  ruby:         "#8B1F35",
  rubyBright:   "#C8304F",
  rubyGlow:     "rgba(200,48,79,0.35)",
  tsb:          "#C4923A",
  tsbGlow:      "rgba(196,146,58,0.35)",
  blue:         "#3A9ED4",
  purple:       "#7B58D8",
  text:         "#E8F2EC",                      // основной текст
  sub:          "#9DBFAA",                      // вторичный — хорошо читается
  muted:        "#5A8A70",                      // третичный
  dim:          "rgba(255,255,255,0.06)",        // фоновые элементы
  dimBorder:    "rgba(255,255,255,0.04)",
  glass:        "rgba(255,255,255,0.03)",
  glassTop:     "rgba(255,255,255,0.07)",       // блик сверху у карточек
};

// Неоновые свечения для чисел
const neon = (color, spread = 8) => `0 0 ${spread}px ${color}, 0 0 ${spread * 2}px ${color}`;
const neonText = (color) => `0 0 12px ${color}, 0 0 4px ${color}`;

// ── DATA ─────────────────────────────────────────────────────────────────────
const buildPMC = () => {
  let ctl = 38, atl = 42, arr = [];
  for (let i = 60; i >= 0; i--) {
    const t = i > 50 ? 0 : i > 38 ? 55 + Math.random() * 35
            : i > 28 ? 0 : i > 12 ? 75 + Math.random() * 45
            : i > 4  ? 20 + Math.random() * 15 : 0;
    ctl = +(ctl + (t - ctl) / 42).toFixed(2);
    atl = +(atl + (t - atl) / 7).toFixed(2);
    const d = new Date(); d.setDate(d.getDate() - i);
    arr.push({
      d: d.toLocaleDateString("ru", { day: "2-digit", month: "short" }),
      CTL: +ctl.toFixed(1), ATL: +atl.toFixed(1),
      TSB: +(ctl - atl).toFixed(1),
    });
  }
  return arr;
};
const PMC  = buildPMC();
const LAST = PMC[PMC.length - 1];

const HR_DATA = Array.from({ length: 21 }, (_, i) => ({
  km: (i * 0.5).toFixed(1),
  hr: Math.min(178, 136 + i * 1.9 + (Math.random() - 0.4) * 7),
  pace: +(4.75 + Math.random() * 0.45).toFixed(2),
}));

const WEEK = [
  { d: "Пн", km: 9.2 }, { d: "Вт", km: 0 },
  { d: "Ср", km: 12.5 }, { d: "Чт", km: 5.1 },
  { d: "Пт", km: 0 }, { d: "Сб", km: 18.3 }, { d: "Вс", km: 6.8 },
];
const ACTIVITIES = [
  { icon: "🏃", name: "Утренняя пробежка", date: "Сегодня · 07:15",  dist: "10.2 км", pace: "4:58 /км",  hr: 148, color: T.accentBright },
  { icon: "🚴", name: "Велотренировка",    date: "Вчера · 09:30",    dist: "42.8 км", pace: "27.4 км/ч", hr: 155, color: T.blue },
  { icon: "🏃", name: "Интервалы 10×400м", date: "28 мая · 06:45",  dist: "8.6 км",  pace: "4:22 /км",  hr: 169, color: T.rubyBright },
  { icon: "🚶", name: "Вечерняя прогулка", date: "27 мая · 19:10",  dist: "5.1 км",  pace: "8:12 /км",  hr: 112, color: T.tsb },
];

// ── PRIMITIVES ────────────────────────────────────────────────────────────────

// Glassmorphism card
const Glass = ({ children, style = {}, ruby = false }) => (
  <div style={{
    background:    ruby ? T.cardRuby : T.card,
    backdropFilter:"blur(24px) saturate(160%)",
    WebkitBackdropFilter: "blur(24px) saturate(160%)",
    borderRadius:  16,
    border:        `1px solid ${ruby ? T.borderRuby : T.border}`,
    borderTop:     `1px solid ${T.glassTop}`,
    boxShadow:     ruby
      ? `inset 0 1px 0 ${T.glassTop}, 0 4px 24px rgba(0,0,0,.4)`
      : `inset 0 1px 0 ${T.glassTop}, 0 4px 24px rgba(0,0,0,.4)`,
    ...style,
  }}>{children}</div>
);

const Chip = ({ label, active, onClick }) => (
  <button onClick={onClick} style={{
    padding: "5px 13px", borderRadius: 20, border: "none", cursor: "pointer",
    fontSize: 11, fontWeight: 600, transition: "all .18s",
    background:    active ? T.accent : "rgba(255,255,255,0.05)",
    color:         active ? "#D8F5EA" : T.sub,
    backdropFilter: "blur(10px)",
    boxShadow:     active ? `0 0 10px ${T.accentGlow}` : "none",
    borderTop:     active ? "none" : `1px solid ${T.glassTop}`,
  }}>{label}</button>
);

const MetCard = ({ label, value, unit, color = T.text, sub, glow }) => (
  <Glass style={{ padding: "11px 10px", flex: 1 }}>
    <div style={{ fontSize: 9, color: T.sub, textTransform: "uppercase", letterSpacing: ".6px", marginBottom: 3 }}>{label}</div>
    <div style={{ display: "flex", alignItems: "baseline", gap: 2 }}>
      <span style={{ fontSize: 22, fontWeight: 800, color, textShadow: glow ? neonText(glow) : "none" }}>{value}</span>
      <span style={{ fontSize: 10, color: T.muted }}>{unit}</span>
    </div>
    {sub && <div style={{ fontSize: 9, color: T.muted, marginTop: 2 }}>{sub}</div>}
  </Glass>
);

// ── MAP SVG ───────────────────────────────────────────────────────────────────
const MapView = ({ height = 160 }) => (
  <div style={{ borderRadius: 16, overflow: "hidden", position: "relative", height }}>
    <svg viewBox="0 0 340 160" style={{ width: "100%", height: "100%", display: "block" }}>
      <defs>
        <filter id="routeGlow">
          <feGaussianBlur stdDeviation="3" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <rect width="340" height="160" fill="#081410"/>
      {[0,1,2,3,4,5,6].map(i => <line key={`v${i}`} x1={i*57} y1={0} x2={i*57} y2={160} stroke="#0E1E18" strokeWidth={7}/>)}
      {[40,90,135].map(y => <line key={`h${y}`} x1={0} y1={y} x2={340} y2={y} stroke="#0E1E18" strokeWidth={6}/>)}
      <path d="M 30,130 Q 65,118 95,100 L 135,82 Q 162,70 188,50 L 212,36 Q 238,28 264,34 L 298,50 Q 318,66 305,92 L 284,118 Q 263,132 234,140 L 196,144 Q 165,147 138,142 L 98,133 Q 62,128 30,130"
        stroke={T.accentBright} strokeWidth={16} fill="none" opacity={.12} strokeLinecap="round"/>
      <path d="M 30,130 Q 65,118 95,100 L 135,82 Q 162,70 188,50 L 212,36 Q 238,28 264,34 L 298,50 Q 318,66 305,92 L 284,118 Q 263,132 234,140 L 196,144 Q 165,147 138,142 L 98,133 Q 62,128 30,130"
        stroke={T.accentBright} strokeWidth={2.5} fill="none" strokeLinecap="round" filter="url(#routeGlow)" opacity={.9}/>
      <circle cx={30} cy={130} r={10} fill={T.accentBright} opacity={.18}/>
      <circle cx={30} cy={130} r={5}  fill={T.accentBright}/>
      <circle cx={305} cy={92} r={10} fill={T.rubyBright} opacity={.18}/>
      <circle cx={305} cy={92} r={4.5} fill={T.rubyBright} stroke="#fff" strokeWidth={1.5}/>
      <text x={10}  y={155} fill={T.muted} fontSize={8} fontFamily="sans-serif">● Начало</text>
      <text x={260} y={85}  fill={T.muted} fontSize={8} fontFamily="sans-serif">■ Конец</text>
      <text x={250} y={28}  fill={T.sub}   fontSize={8} fontFamily="sans-serif">Душанбе</text>
    </svg>
    <div style={{
      position: "absolute", top: 8, right: 8,
      background: "rgba(5,12,8,.7)", backdropFilter: "blur(12px)",
      border: `1px solid ${T.border}`,
      borderRadius: 7, padding: "3px 8px", fontSize: 10, color: T.sub,
    }}>MapKit</div>
  </div>
);

// ── DASHBOARD ─────────────────────────────────────────────────────────────────
function Dashboard({ onActivity }) {
  const totalKm = WEEK.reduce((s, d) => s + d.km, 0);
  const tsb      = LAST.TSB;
  const tsbColor = tsb > 5 ? T.accentBright : tsb > -10 ? T.tsb : T.rubyBright;
  const tsbGlow  = tsb > 5 ? T.accentGlow   : tsb > -10 ? T.tsbGlow : T.rubyGlow;

  return (
    <div style={{ padding: "0 14px 110px", overflowY: "auto", height: "100%", scrollbarWidth: "none" }}>

      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 14 }}>
        <div>
          <div style={{ fontSize: 12, color: T.sub, letterSpacing: ".2px" }}>Доброе утро</div>
          <div style={{ fontSize: 20, fontWeight: 800, color: T.text }}>Abduhafiz 👋</div>
        </div>
        <button style={{
          background: "rgba(255,255,255,0.05)", backdropFilter: "blur(12px)",
          border: `1px solid ${T.border}`, borderTop: `1px solid ${T.glassTop}`,
          borderRadius: 10, padding: "7px 11px", color: T.sub, fontSize: 11, cursor: "pointer",
        }}>↻ Синх</button>
      </div>

      {/* Readiness card — glass emerald */}
      <Glass style={{ padding: 14, marginBottom: 10 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div>
            <div style={{ fontSize: 10, color: T.sub, textTransform: "uppercase", letterSpacing: ".6px", marginBottom: 2 }}>Готовность сегодня</div>
            <div style={{ fontSize: 52, fontWeight: 900, color: T.accentBright, lineHeight: 1,
              textShadow: neonText(T.accentGlow) }}>74</div>
            <div style={{ fontSize: 11, color: T.accentBright, marginTop: 4,
              textShadow: `0 0 8px ${T.accentGlow}` }}>● Хорошая форма</div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{ fontSize: 10, color: T.sub, marginBottom: 6 }}>HRV vs 30д</div>
            <div style={{ fontSize: 20, fontWeight: 800, color: T.text }}>+8%</div>
            <div style={{ fontSize: 10, color: T.sub, marginTop: 6 }}>Сон: 7ч 24мин</div>
            <div style={{ fontSize: 10, color: T.sub }}>HRV: 52 мс</div>
          </div>
        </div>
        <div style={{ marginTop: 10, background: "rgba(255,255,255,0.06)", borderRadius: 4, height: 5 }}>
          <div style={{ width: "74%", height: 5, background: T.accentBright, borderRadius: 4,
            boxShadow: `0 0 8px ${T.accentGlow}` }}/>
        </div>
      </Glass>

      {/* CTL / ATL / TSB */}
      <div style={{ display: "flex", gap: 7, marginBottom: 10 }}>
        <MetCard label="Фитнес CTL"   value={LAST.CTL.toFixed(0)} color={T.accentBright} glow={T.accentGlow} sub="↑2.1 за неделю"/>
        <MetCard label="Усталость ATL" value={LAST.ATL.toFixed(0)} color={T.rubyBright}   glow={T.rubyGlow}   sub="↓1.3 за неделю"/>
        <MetCard label="Форма TSB"    value={(tsb>=0?"+":"")+tsb.toFixed(0)} color={tsbColor} glow={tsbGlow}
          sub={tsb > 5 ? "Свежий" : tsb > -10 ? "Умеренно" : "Перегрузка"}/>
      </div>

      {/* Weekly volume */}
      <Glass style={{ padding: "11px 10px 7px", marginBottom: 10 }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 7 }}>
          <span style={{ fontSize: 13, fontWeight: 700, color: T.text }}>Эта неделя</span>
          <span style={{ fontSize: 14, color: T.accentBright, fontWeight: 800,
            textShadow: `0 0 8px ${T.accentGlow}` }}>{totalKm.toFixed(1)} км</span>
        </div>
        <ResponsiveContainer width="100%" height={55}>
          <BarChart data={WEEK} margin={{ top:0, bottom:0, left:0, right:0 }} barSize={18}>
            <Bar dataKey="km" radius={[4,4,0,0]}>
              {WEEK.map((d,i) => <Cell key={i} fill={d.km > 0 ? T.accent : "rgba(255,255,255,0.06)"}/>)}
            </Bar>
            <XAxis dataKey="d" tick={{ fontSize:9, fill: T.sub }} axisLine={false} tickLine={false}/>
          </BarChart>
        </ResponsiveContainer>
      </Glass>

      {/* AI Coach */}
      <div style={{
        background: "rgba(13,122,88,0.08)", backdropFilter: "blur(16px)",
        border: `1px solid rgba(29,191,136,0.2)`, borderTop: `1px solid rgba(29,191,136,0.3)`,
        borderRadius: 14, padding: 12, marginBottom: 10,
      }}>
        <div style={{ fontSize: 10, color: T.accentBright, marginBottom: 4,
          textTransform: "uppercase", letterSpacing: ".4px",
          textShadow: `0 0 6px ${T.accentGlow}` }}>🤖 ИИ-тренер</div>
        <div style={{ fontSize: 12, color: T.sub, lineHeight: 1.55 }}>
          TSB +{tsb.toFixed(0)} — хороший момент для темповой тренировки. Последняя была 12 дней назад.
        </div>
      </div>

      {/* Activities */}
      <div style={{ fontSize: 10, color: T.muted, textTransform: "uppercase",
        letterSpacing: ".6px", marginBottom: 7 }}>Последние активности</div>
      {ACTIVITIES.map((a, i) => (
        <Glass key={i} style={{ padding: "11px 13px", marginBottom: 7, cursor: i===0?"pointer":"default",
          borderColor: i===0 ? T.borderAccent : T.border,
        }}>
          <div onClick={() => i===0 && onActivity()}
            style={{ display:"flex", alignItems:"center", gap:11 }}>
            <div style={{ fontSize: 20 }}>{a.icon}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: T.text }}>{a.name}</div>
              <div style={{ fontSize: 10, color: T.sub, marginTop: 1 }}>{a.date}</div>
            </div>
            <div style={{ textAlign:"right" }}>
              <div style={{ fontSize:14, fontWeight:800, color:a.color,
                textShadow: i===0 ? neonText(T.accentGlow) : "none" }}>{a.dist}</div>
              <div style={{ fontSize:10, color:T.sub }}>{ a.pace} · ♥ {a.hr}</div>
            </div>
            {i===0 && <div style={{ color:T.muted, fontSize:12 }}>›</div>}
          </div>
        </Glass>
      ))}
    </div>
  );
}

// ── ACTIVITY DETAIL ───────────────────────────────────────────────────────────
function ActivityDetail({ onBack }) {
  const [chartTab, setChartTab] = useState(0);
  const splits = [
    { km:1,  time:"4:52", hr:142, elev:"+8м" },
    { km:2,  time:"4:58", hr:147, elev:"+2м" },
    { km:3,  time:"4:55", hr:149, elev:"-5м" },
    { km:4,  time:"4:48", hr:152, elev:"-3м" },
    { km:5,  time:"5:05", hr:154, elev:"+12м"},
    { km:6,  time:"4:58", hr:156, elev:"+4м" },
    { km:7,  time:"4:52", hr:158, elev:"-6м" },
    { km:8,  time:"4:46", hr:160, elev:"-2м" },
    { km:9,  time:"5:02", hr:162, elev:"+8м" },
    { km:10, time:"4:44", hr:165, elev:"+3м", best:true },
  ];
  return (
    <div style={{ height:"100%", overflowY:"auto", scrollbarWidth:"none", paddingBottom:110 }}>
      {/* Header */}
      <div style={{ padding:"6px 14px 10px", display:"flex", alignItems:"center", gap:10 }}>
        <button onClick={onBack} style={{
          background:"rgba(255,255,255,0.05)", backdropFilter:"blur(12px)",
          border:`1px solid ${T.border}`, borderTop:`1px solid ${T.glassTop}`,
          borderRadius:10, padding:"6px 10px", color:T.sub, cursor:"pointer", fontSize:13,
        }}>←</button>
        <div>
          <div style={{ fontSize:15, fontWeight:800, color:T.text }}>Утренняя пробежка</div>
          <div style={{ fontSize:10, color:T.sub }}>Сегодня · 07:15 · Душанбе</div>
        </div>
      </div>

      <div style={{ padding:"0 14px" }}>
        <MapView height={155}/>

        {/* Metrics grid */}
        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr 1fr", gap:7, marginTop:10 }}>
          {[
            { l:"Дистанция", v:"10.21", u:"км",      c:T.text        },
            { l:"Время",     v:"50:43", u:"",         c:T.text        },
            { l:"Темп",      v:"4:58",  u:"/км",      c:T.accentBright, g:T.accentGlow },
            { l:"Пульс",     v:"148",   u:"уд/мин",   c:T.rubyBright,   g:T.rubyGlow  },
            { l:"Подъём",    v:"124",   u:"м",        c:T.blue        },
            { l:"Каденс",    v:"172",   u:"шаг/м",    c:T.purple      },
          ].map((m,i) => (
            <Glass key={i} style={{ padding:"9px 8px", textAlign:"center" }}>
              <div style={{ fontSize:8, color:T.sub, textTransform:"uppercase", letterSpacing:".4px" }}>{m.l}</div>
              <div style={{ fontSize:18, fontWeight:800, color:m.c, lineHeight:1.25,
                textShadow: m.g ? neonText(m.g) : "none" }}>{m.v}</div>
              <div style={{ fontSize:8, color:T.muted }}>{m.u}</div>
            </Glass>
          ))}
        </div>

        {/* Chart */}
        <Glass style={{ padding:"10px 8px 6px", marginTop:10 }}>
          <div style={{ display:"flex", gap:7, paddingLeft:4, marginBottom:8 }}>
            {["Пульс","Темп","Высота"].map((t,i) => (
              <Chip key={i} label={t} active={chartTab===i} onClick={() => setChartTab(i)}/>
            ))}
          </div>
          <ResponsiveContainer width="100%" height={90}>
            <AreaChart data={HR_DATA} margin={{ top:0, bottom:0, left:0, right:0 }}>
              <defs>
                <linearGradient id="hrGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor={T.rubyBright} stopOpacity={.4}/>
                  <stop offset="95%" stopColor={T.rubyBright} stopOpacity={0}/>
                </linearGradient>
              </defs>
              <Area type="monotone" dataKey="hr" stroke={T.rubyBright} fill="url(#hrGrad)"
                strokeWidth={2} dot={false}/>
              <XAxis dataKey="km" tick={{ fontSize:8, fill:T.sub }} axisLine={false} tickLine={false} interval={4}/>
              <YAxis domain={["auto","auto"]} hide/>
              <Tooltip contentStyle={{ background:"rgba(10,20,14,.92)", backdropFilter:"blur(12px)",
                border:`1px solid ${T.border}`, borderRadius:8, fontSize:10, color:T.text }}/>
            </AreaChart>
          </ResponsiveContainer>
        </Glass>

        {/* Splits */}
        <Glass style={{ padding:"11px 12px", marginTop:10 }}>
          <div style={{ fontSize:13, fontWeight:700, color:T.text, marginBottom:8 }}>Сплиты по километрам</div>
          <div style={{ display:"grid", gridTemplateColumns:"24px 1fr 1fr 1fr" }}>
            {["км","темп","♥","↑↓"].map(h => (
              <div key={h} style={{ fontSize:9, color:T.muted, textTransform:"uppercase",
                padding:"0 0 5px", textAlign:"center", letterSpacing:".3px" }}>{h}</div>
            ))}
            {splits.map((s,i) => {
              const rowBg = s.best ? "rgba(29,191,136,0.07)" : "transparent";
              const rowRadius = s.best ? { borderRadius:7 } : {};
              return [
                <div key={`a${i}`} style={{ textAlign:"center", padding:"4px 0", fontSize:11,
                  color: s.best ? T.accentBright : T.sub, background:rowBg,
                  borderRadius:"7px 0 0 7px",
                  textShadow: s.best ? `0 0 6px ${T.accentGlow}` : "none" }}>
                  {s.best ? "🏆" : s.km}
                </div>,
                <div key={`b${i}`} style={{ textAlign:"center", padding:"4px 0", fontSize:11,
                  color: s.best ? T.accentBright : T.accentBright, fontWeight: s.best ? 800 : 400,
                  background:rowBg,
                  textShadow: s.best ? neonText(T.accentGlow) : "none" }}>{s.time}</div>,
                <div key={`c${i}`} style={{ textAlign:"center", padding:"4px 0", fontSize:11,
                  color:T.sub, background:rowBg }}>{s.hr}</div>,
                <div key={`d${i}`} style={{ textAlign:"center", padding:"4px 0", fontSize:11,
                  color:T.sub, background:rowBg, borderRadius:"0 7px 7px 0" }}>{s.elev}</div>,
              ];
            })}
          </div>
        </Glass>

        {/* HR Zones */}
        <Glass style={{ padding:"11px 12px", marginTop:10 }}>
          <div style={{ fontSize:13, fontWeight:700, color:T.text, marginBottom:9 }}>Зоны пульса</div>
          {[
            { z:"З1", l:"Восстановление", pct:8,  c:"#3A9ED4" },
            { z:"З2", l:"Аэробная",       pct:22, c:T.accentBright },
            { z:"З3", l:"Темп",           pct:35, c:T.tsb },
            { z:"З4", l:"Порог",          pct:28, c:"#D4783A" },
            { z:"З5", l:"VO₂max",         pct:7,  c:T.rubyBright },
          ].map((z,i) => (
            <div key={i} style={{ display:"flex", alignItems:"center", gap:8, marginBottom:6 }}>
              <div style={{ width:20, fontSize:9, color:T.sub }}>{z.z}</div>
              <div style={{ fontSize:9, color:T.sub, width:70 }}>{z.l}</div>
              <div style={{ flex:1, background:"rgba(255,255,255,0.06)", borderRadius:4, height:7 }}>
                <div style={{ width:`${z.pct}%`, height:7, background:z.c, borderRadius:4,
                  boxShadow:`0 0 6px ${z.c}44` }}/>
              </div>
              <div style={{ width:26, fontSize:10, color:z.c, fontWeight:700, textAlign:"right",
                textShadow:`0 0 6px ${z.c}66` }}>{z.pct}%</div>
            </div>
          ))}
        </Glass>
      </div>
    </div>
  );
}

// ── FORM / PMC ────────────────────────────────────────────────────────────────
function FormScreen() {
  const [period, setPeriod] = useState(1);
  const slices = [PMC.slice(-30), PMC.slice(-60), PMC, PMC];
  const data   = slices[period];
  const tsb    = LAST.TSB;
  const tsbColor = tsb > 5 ? T.accentBright : tsb > -10 ? T.tsb : T.rubyBright;
  const tsbGlow  = tsb > 5 ? T.accentGlow   : tsb > -10 ? T.tsbGlow : T.rubyGlow;
  const tsbText  = tsb > 10 ? "Свежий — готов к стартам" : tsb > 0 ? "Хорошая форма" : tsb > -10 ? "Умеренная усталость" : "Высокая нагрузка";

  return (
    <div style={{ padding:"0 14px 110px", overflowY:"auto", height:"100%", scrollbarWidth:"none" }}>
      <div style={{ fontSize:20, fontWeight:800, color:T.text, marginBottom:12 }}>Форма</div>

      {/* TSB status */}
      <Glass style={{ padding:14, marginBottom:10 }}>
        <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center" }}>
          <div>
            <div style={{ fontSize:10, color:T.sub, marginBottom:3 }}>Состояние сегодня</div>
            <div style={{ fontSize:14, fontWeight:700, color:tsbColor,
              textShadow:`0 0 8px ${tsbGlow}` }}>{tsbText}</div>
          </div>
          <div style={{ textAlign:"right" }}>
            <div style={{ fontSize:36, fontWeight:900, color:tsbColor, lineHeight:1,
              textShadow: neonText(tsbGlow) }}>
              {tsb >= 0 ? "+" : ""}{tsb.toFixed(0)}
            </div>
            <div style={{ fontSize:10, color:T.sub }}>TSB</div>
          </div>
        </div>
      </Glass>

      {/* Period chips */}
      <div style={{ display:"flex", gap:7, marginBottom:10 }}>
        {["1М","3М","6М","Всё"].map((p,i) => (
          <Chip key={i} label={p} active={period===i} onClick={() => setPeriod(i)}/>
        ))}
      </div>

      {/* PMC Chart */}
      <Glass style={{ padding:"11px 6px 7px", marginBottom:10 }}>
        <div style={{ display:"flex", gap:14, paddingLeft:10, marginBottom:7 }}>
          {[
            { l:"CTL", c:T.accentBright },
            { l:"ATL", c:T.rubyBright   },
            { l:"TSB", c:T.tsb          },
          ].map(({ l, c }) => (
            <div key={l} style={{ display:"flex", alignItems:"center", gap:5, fontSize:10 }}>
              <div style={{ width:14, height:2, background:c, boxShadow:`0 0 4px ${c}` }}/>
              <span style={{ color:T.sub }}>{l}</span>
            </div>
          ))}
        </div>
        <ResponsiveContainer width="100%" height={135}>
          <LineChart data={data} margin={{ top:2, bottom:0, left:0, right:6 }}>
            <XAxis dataKey="d" tick={{ fontSize:7, fill:T.muted }} axisLine={false} tickLine={false}
              interval={Math.floor(data.length/5)}/>
            <YAxis domain={["auto","auto"]} hide/>
            <Tooltip contentStyle={{ background:"rgba(10,20,14,.92)", backdropFilter:"blur(12px)",
              border:`1px solid ${T.border}`, borderRadius:8, fontSize:10, color:T.text }}/>
            <Line type="monotone" dataKey="CTL" stroke={T.accentBright} strokeWidth={2} dot={false}/>
            <Line type="monotone" dataKey="ATL" stroke={T.rubyBright}   strokeWidth={2} dot={false}/>
            <Line type="monotone" dataKey="TSB" stroke={T.tsb} strokeWidth={1.5} dot={false} strokeDasharray="4 3"/>
          </LineChart>
        </ResponsiveContainer>
      </Glass>

      <div style={{ display:"flex", gap:7, marginBottom:10 }}>
        <MetCard label="Фитнес CTL"    value={LAST.CTL.toFixed(1)} color={T.accentBright} glow={T.accentGlow}/>
        <MetCard label="Усталость ATL" value={LAST.ATL.toFixed(1)} color={T.rubyBright}   glow={T.rubyGlow}/>
        <MetCard label="Форма TSB"     value={(LAST.TSB>=0?"+":"")+LAST.TSB.toFixed(1)} color={tsbColor} glow={tsbGlow}/>
      </div>

      {/* Weekly bar */}
      <Glass style={{ padding:"11px 6px 7px" }}>
        <div style={{ fontSize:13, fontWeight:700, color:T.text, paddingLeft:8, marginBottom:7 }}>Объём по дням</div>
        <ResponsiveContainer width="100%" height={75}>
          <BarChart data={WEEK} margin={{ top:0, bottom:0, left:0, right:0 }} barSize={20}>
            <Bar dataKey="km" radius={[4,4,0,0]}>
              {WEEK.map((d,i) => <Cell key={i} fill={d.km>0 ? T.accent : "rgba(255,255,255,0.05)"}/>)}
            </Bar>
            <XAxis dataKey="d" tick={{ fontSize:9, fill:T.sub }} axisLine={false} tickLine={false}/>
            <Tooltip contentStyle={{ background:"rgba(10,20,14,.9)", backdropFilter:"blur(12px)",
              border:`1px solid ${T.border}`, borderRadius:8, fontSize:10, color:T.text }}/>
          </BarChart>
        </ResponsiveContainer>
      </Glass>
    </div>
  );
}

// ── RECORDS ───────────────────────────────────────────────────────────────────
function RecordsScreen() {
  return (
    <div style={{ padding:"0 14px 110px", overflowY:"auto", height:"100%", scrollbarWidth:"none" }}>
      <div style={{ fontSize:20, fontWeight:800, color:T.text, marginBottom:4 }}>Рекорды</div>
      <div style={{ fontSize:11, color:T.sub, marginBottom:14 }}>Лучшие результаты из всей истории</div>

      {/* Riegel */}
      <div style={{
        background:"rgba(139,31,53,0.1)", backdropFilter:"blur(20px) saturate(150%)",
        border:`1px solid ${T.borderRuby}`, borderTop:`1px solid rgba(200,48,79,0.3)`,
        borderRadius:16, padding:13, marginBottom:14,
      }}>
        <div style={{ fontSize:10, color:T.rubyBright, marginBottom:3,
          textTransform:"uppercase", letterSpacing:".5px",
          textShadow:`0 0 6px ${T.rubyGlow}` }}>⚡ Прогноз Riegel · на основе 10 км</div>
        <div style={{ display:"flex", gap:20, marginTop:6 }}>
          {[{ d:"5 км", t:"20:46" },{ d:"21.1 км", t:"1:36:12" },{ d:"Марафон", t:"3:22:08" }].map((r,i) => (
            <div key={i}>
              <div style={{ fontSize:10, color:T.sub }}>{r.d}</div>
              <div style={{ fontSize:16, fontWeight:800, color:T.rubyBright,
                textShadow: neonText(T.rubyGlow) }}>{r.t}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Running records */}
      <div style={{ fontSize:10, color:T.muted, textTransform:"uppercase", letterSpacing:".5px", marginBottom:7 }}>🏃 Беговые рекорды</div>
      {[
        { dist:"1 км",    time:"3:41",    date:"12 апр", pr:true  },
        { dist:"5 км",    time:"20:18",   date:"3 мар"            },
        { dist:"10 км",   time:"43:52",   date:"15 фев", pr:true  },
        { dist:"21.1 км", time:"1:38:24", date:"10 ноя"           },
        { dist:"Марафон", time:"—",       date:"—",      empty:true },
      ].map((r,i) => (
        <Glass key={i} ruby={r.pr} style={{
          padding:"11px 13px", marginBottom:7,
          borderColor: r.pr ? T.borderRuby : T.border,
        }}>
          <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between" }}>
            <div style={{ display:"flex", alignItems:"center", gap:9 }}>
              {r.pr && <span style={{ fontSize:14 }}>🏆</span>}
              <div>
                <div style={{ fontSize:14, fontWeight:600, color: r.empty ? T.muted : T.text }}>{r.dist}</div>
                <div style={{ fontSize:10, color:T.sub }}>{r.date}</div>
              </div>
            </div>
            <div style={{ fontSize:20, fontWeight:900,
              color: r.empty ? T.muted : r.pr ? T.rubyBright : T.text,
              textShadow: r.pr ? neonText(T.rubyGlow) : "none" }}>{r.time}</div>
          </div>
        </Glass>
      ))}

      {/* Power curve */}
      <div style={{ fontSize:10, color:T.muted, textTransform:"uppercase", letterSpacing:".5px", marginBottom:7, marginTop:12 }}>🚴 Кривая мощности</div>
      {[
        { d:"5 сек",       v:"892 Вт", date:"15 мар" },
        { d:"1 мин",       v:"512 Вт", date:"15 мар" },
        { d:"5 мин",       v:"378 Вт", date:"3 фев"  },
        { d:"20 мин (FTP)", v:"298 Вт", date:"10 янв", pr:true },
        { d:"60 мин",      v:"271 Вт", date:"10 янв" },
      ].map((r,i) => (
        <Glass key={i} style={{
          padding:"9px 13px", marginBottom:6,
          borderColor: r.pr ? T.borderAccent : T.border,
        }}>
          <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center" }}>
            <div>
              <div style={{ fontSize:13, color:T.text, fontWeight: r.pr ? 700 : 400 }}>{r.d}</div>
              <div style={{ fontSize:10, color:T.sub }}>{r.date}</div>
            </div>
            <div style={{ fontSize:17, fontWeight:800,
              color: r.pr ? T.accentBright : T.blue,
              textShadow: r.pr ? neonText(T.accentGlow) : "none" }}>{r.v}</div>
          </div>
        </Glass>
      ))}
    </div>
  );
}

// ── HEATMAP ───────────────────────────────────────────────────────────────────
function HeatmapScreen() {
  const [filter, setFilter] = useState(0);
  return (
    <div style={{ padding:"0 14px 110px", overflowY:"auto", height:"100%", scrollbarWidth:"none" }}>
      <div style={{ fontSize:20, fontWeight:800, color:T.text, marginBottom:4 }}>Тепловая карта</div>
      <div style={{ fontSize:11, color:T.sub, marginBottom:11 }}>Все маршруты на одной карте</div>
      <div style={{ display:"flex", gap:7, marginBottom:11, flexWrap:"wrap" }}>
        {["Все","Бег","Велосипед","Ходьба"].map((f,i) => (
          <Chip key={i} label={f} active={filter===i} onClick={() => setFilter(i)}/>
        ))}
      </div>

      <div style={{ borderRadius:16, overflow:"hidden", marginBottom:12,
        boxShadow:`0 0 0 1px ${T.border}` }}>
        <svg viewBox="0 0 340 240" style={{ width:"100%", display:"block" }}>
          <defs>
            <filter id="heatGlow">
              <feGaussianBlur stdDeviation="4" result="blur"/>
              <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
            </filter>
          </defs>
          <rect width="340" height="240" fill="#071210"/>
          {[0,1,2,3,4,5].map(i => <line key={`v${i}`} x1={i*68} y1={0} x2={i*68} y2={240} stroke="#0D1E18" strokeWidth={7}/>)}
          {[0,1,2,3].map(i => <line key={`h${i}`} x1={0} y1={i*62} x2={340} y2={i*62} stroke="#0D1E18" strokeWidth={6}/>)}
          {[
            { d:"M 25,205 Q 75,185 120,155 L 170,130 Q 210,110 250,80 L 290,55 Q 318,40 330,60 L 315,95 Q 290,130 255,148 L 210,162 Q 172,172 140,178 L 95,185 Q 58,196 25,205", w:20, op:.1  },
            { d:"M 25,205 Q 75,185 120,155 L 170,130 Q 210,110 250,80 L 290,55 Q 318,40 330,60 L 315,95 Q 290,130 255,148 L 210,162 Q 172,172 140,178 L 95,185 Q 58,196 25,205", w:3,  op:.9  },
            { d:"M 40,220 Q 95,200 145,172 L 195,152 Q 232,136 268,108 L 305,80",           w:3,  op:.5  },
            { d:"M 20,175 Q 55,158 90,138 L 145,115 Q 185,98 230,78 L 275,62 Q 308,52 320,68", w:2, op:.35 },
            { d:"M 55,228 Q 110,210 165,188 Q 220,166 270,150 L 325,140",                   w:2,  op:.28 },
            { d:"M 30,190 Q 70,172 115,150 L 168,128 Q 208,112 252,92 L 296,72",            w:4,  op:.55 },
            { d:"M 45,210 Q 85,195 125,172 Q 170,148 210,125 L 260,100 Q 295,82 310,95",    w:2,  op:.38 },
          ].map((r,i) => (
            <path key={i} d={r.d} stroke={T.accentBright} strokeWidth={r.w} fill="none"
              opacity={r.op} strokeLinecap="round"
              filter={r.w >= 3 ? "url(#heatGlow)" : "none"}/>
          ))}
          <text x={12}  y={16}  fill="rgba(255,255,255,0.2)" fontSize={9} fontFamily="sans-serif">Душанбе · Таджикистан</text>
          <text x={12}  y={232} fill="rgba(255,255,255,0.12)" fontSize={8} fontFamily="sans-serif">▬ 1 км</text>
        </svg>
      </div>

      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:7, marginBottom:12 }}>
        {[
          { l:"Маршрутов",     v:"847"  },
          { l:"Км² исследовано", v:"142" },
          { l:"Городов",       v:"8"    },
          { l:"Стран",         v:"3"    },
        ].map((s,i) => (
          <Glass key={i} style={{ padding:11 }}>
            <div style={{ fontSize:9, color:T.sub, marginBottom:3 }}>{s.l}</div>
            <div style={{ fontSize:22, fontWeight:800, color:T.text }}>{s.v}</div>
          </Glass>
        ))}
      </div>

      <Glass style={{ padding:13 }}>
        <div style={{ fontSize:13, fontWeight:700, color:T.text, marginBottom:9 }}>🌍 Личная география</div>
        {[
          { l:"Самая северная", v:"Москва, Россия"        },
          { l:"Самая восточная", v:"Алматы, Казахстан"    },
          { l:"Самая южная",    v:"Душанбе, Таджикистан"  },
          { l:"Самая западная", v:"Ташкент, Узбекистан"   },
        ].map((g,i) => (
          <div key={i} style={{ display:"flex", justifyContent:"space-between", padding:"6px 0",
            borderTop: i>0 ? `1px solid rgba(255,255,255,0.05)` : "none" }}>
            <span style={{ fontSize:11, color:T.sub }}>{g.l}</span>
            <span style={{ fontSize:11, color:T.text, fontWeight:600 }}>{g.v}</span>
          </div>
        ))}
      </Glass>
    </div>
  );
}

// ── PROFILE ───────────────────────────────────────────────────────────────────
function ProfileScreen() {
  const [proMode, setProMode] = useState(true);
  return (
    <div style={{ padding:"0 14px 110px", overflowY:"auto", height:"100%", scrollbarWidth:"none" }}>
      {/* User */}
      <div style={{ display:"flex", alignItems:"center", gap:13, marginBottom:18 }}>
        <div style={{
          width:56, height:56, borderRadius:28,
          background:`linear-gradient(135deg, ${T.accent}, ${T.accentBright})`,
          display:"flex", alignItems:"center", justifyContent:"center",
          fontSize:22, fontWeight:800, color:"#fff",
          boxShadow:`0 0 18px ${T.accentGlow}`,
        }}>A</div>
        <div>
          <div style={{ fontSize:17, fontWeight:800, color:T.text }}>Abduhafiz Hafizov</div>
          <div style={{ fontSize:11, color:T.accentBright,
            textShadow:`0 0 6px ${T.accentGlow}` }}>✓ Strava подключён</div>
          <div style={{ fontSize:10, color:T.sub }}>Душанбе, Таджикистан</div>
        </div>
      </div>

      {/* Pro / Casual */}
      <Glass style={{ padding:13, marginBottom:10 }}>
        <div style={{ fontSize:12, fontWeight:700, color:T.text, marginBottom:9 }}>Режим приложения</div>
        <div style={{ display:"flex", background:"rgba(255,255,255,0.04)", borderRadius:10, padding:3 }}>
          {["Про","Casual"].map((m,i) => (
            <button key={i} onClick={() => setProMode(i===0)} style={{
              flex:1, padding:"7px 0", borderRadius:8, border:"none", cursor:"pointer",
              fontSize:12, fontWeight:700, transition:"all .18s",
              background: (i===0)===proMode ? T.accent : "transparent",
              color:       (i===0)===proMode ? "#D8F5EA" : T.sub,
              boxShadow:   (i===0)===proMode ? `0 0 12px ${T.accentGlow}` : "none",
            }}>{m}</button>
          ))}
        </div>
      </Glass>

      {/* Stats */}
      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:7, marginBottom:10 }}>
        {[
          { l:"Активностей",  v:"847"   },
          { l:"Суммарно км",  v:"12 348"},
          { l:"Часов",        v:"1 024" },
          { l:"Активных дней",v:"312"   },
        ].map((s,i) => (
          <Glass key={i} style={{ padding:11 }}>
            <div style={{ fontSize:9, color:T.sub, marginBottom:3 }}>{s.l}</div>
            <div style={{ fontSize:20, fontWeight:800, color:T.text }}>{s.v}</div>
          </Glass>
        ))}
      </div>

      {/* Settings */}
      {[
        { title:"Пульсовые зоны",   items:["Макс. пульс: 192 уд/мин", "Режим: Авто (Friel 5 зон)"]     },
        { title:"Беговые пороги",   items:["LTHR темп: 4:45 /км", "ФТП бег: 4:38 /км"]                 },
        { title:"Велосипед",        items:["FTP: 298 Вт", "W/kg: 4.1 · Вес байка: 8.2 кг"]             },
        { title:"Цели",             items:["Недельный объём: 50 км", "Старт: Марафон · 15 сен 2026"]    },
      ].map((s,i) => (
        <Glass key={i} style={{ padding:13, marginBottom:8 }}>
          <div style={{ fontSize:12, fontWeight:700, color:T.text, marginBottom:7 }}>{s.title}</div>
          {s.items.map((item,j) => (
            <div key={j} style={{ fontSize:11, color:T.sub, padding:"4px 0",
              borderTop: j>0 ? `1px solid rgba(255,255,255,0.05)` : "none" }}>{item}</div>
          ))}
        </Glass>
      ))}

      {/* Gear */}
      <Glass style={{ padding:13 }}>
        <div style={{ fontSize:12, fontWeight:700, color:T.text, marginBottom:10 }}>Экипировка</div>
        {[
          { name:"Nike Pegasus 41",      km:648,  max:700,  c:T.rubyBright, g:T.rubyGlow   },
          { name:"Canyon Aeroad CF SLX", km:3240, max:5000, c:T.accentBright, g:T.accentGlow },
        ].map((g,i) => (
          <div key={i} style={{ marginBottom: i===0 ? 12 : 0 }}>
            <div style={{ display:"flex", justifyContent:"space-between", marginBottom:5 }}>
              <span style={{ fontSize:12, color:T.text }}>{g.name}</span>
              <span style={{ fontSize:11, color:g.c, fontWeight:700,
                textShadow:`0 0 6px ${g.g}` }}>{g.km} / {g.max} км</span>
            </div>
            <div style={{ background:"rgba(255,255,255,0.06)", borderRadius:5, height:7 }}>
              <div style={{ width:`${(g.km/g.max)*100}%`, height:7, background:g.c,
                borderRadius:5, boxShadow:`0 0 8px ${g.g}` }}/>
            </div>
          </div>
        ))}
      </Glass>
    </div>
  );
}

// ── BOTTOM BAR ────────────────────────────────────────────────────────────────
const TABS = [
  { icon:"⊞", label:"Главная"  },
  { icon:"◈", label:"Форма"    },
  { icon:"★", label:"Рекорды"  },
  { icon:"◉", label:"Карта"    },
  { icon:"◎", label:"Профиль"  },
];

function BottomBar({ active, onTab }) {
  return (
    <div style={{
      position:"absolute", bottom:0, left:0, right:0, zIndex:99,
      background:"rgba(5,12,8,0.80)",
      backdropFilter:"blur(28px) saturate(180%)",
      WebkitBackdropFilter:"blur(28px) saturate(180%)",
      borderTop:`1px solid ${T.glassTop}`,
      display:"flex", padding:"10px 0 26px",
    }}>
      {TABS.map((t,i) => (
        <button key={i} onClick={() => onTab(i)} style={{
          flex:1, border:"none", background:"none", cursor:"pointer",
          display:"flex", flexDirection:"column", alignItems:"center", gap:2,
          color: active===i ? T.accentBright : T.muted,
          transition:"all .15s",
        }}>
          <span style={{
            fontSize: active===i ? 21 : 18,
            textShadow: active===i ? `0 0 10px ${T.accentGlow}` : "none",
          }}>{t.icon}</span>
          <span style={{ fontSize:8, fontWeight: active===i ? 700 : 400 }}>{t.label}</span>
        </button>
      ))}
    </div>
  );
}

// ── ROOT ──────────────────────────────────────────────────────────────────────
export default function TezDavMockup() {
  const [tab, setTab]                 = useState(0);
  const [showActivity, setShowActivity] = useState(false);

  const LABELS = ["Dashboard","Активность","Форма","Рекорды","Карта","Профиль"];

  const content = () => {
    if (showActivity) return <ActivityDetail onBack={() => setShowActivity(false)}/>;
    switch (tab) {
      case 0: return <Dashboard onActivity={() => setShowActivity(true)}/>;
      case 1: return <FormScreen/>;
      case 2: return <RecordsScreen/>;
      case 3: return <HeatmapScreen/>;
      case 4: return <ProfileScreen/>;
      default: return <Dashboard onActivity={() => setShowActivity(true)}/>;
    }
  };

  const activeExt = showActivity ? -1 : tab;

  return (
    <div style={{
      background:"radial-gradient(ellipse at 30% 20%, rgba(13,90,60,0.18) 0%, transparent 60%), #040A07",
      minHeight:"100vh", display:"flex", flexDirection:"column", alignItems:"center",
      padding:"24px 0 48px",
      fontFamily:"-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif",
    }}>
      {/* Title */}
      <div style={{ textAlign:"center", marginBottom:18 }}>
        <div style={{ fontSize:30, fontWeight:900, letterSpacing:"-1px" }}>
          <span style={{ color:T.accentBright, textShadow:neonText(T.accentGlow) }}>Tez</span>
          <span style={{ color:T.rubyBright,   textShadow:neonText(T.rubyGlow)   }}>Dav</span>
        </div>
        <div style={{ fontSize:12, color:T.sub, marginTop:3 }}>
          Интерактивный макет · Тапни на активность в Dashboard
        </div>
      </div>

      {/* Screen switcher */}
      <div style={{ display:"flex", gap:6, marginBottom:18, flexWrap:"wrap",
        justifyContent:"center", padding:"0 16px" }}>
        {LABELS.map((l,i) => {
          const isActive = i===0 ? (tab===0 && !showActivity)
                         : i===1 ? showActivity
                         : tab===i-1 && !showActivity;
          return (
            <button key={i} onClick={() => {
              if (i===1) { setShowActivity(true); }
              else { setShowActivity(false); setTab(i===0 ? 0 : i-1); }
            }} style={{
              padding:"6px 14px", borderRadius:20, border:"none", cursor:"pointer",
              fontSize:11, fontWeight:700, transition:"all .18s",
              background:    isActive ? T.accent : "rgba(255,255,255,0.05)",
              color:         isActive ? "#D8F5EA" : T.sub,
              backdropFilter:"blur(10px)",
              boxShadow:     isActive ? `0 0 12px ${T.accentGlow}` : "none",
            }}>{l}</button>
          );
        })}
      </div>

      {/* iPhone frame */}
      <div style={{
        width:360, background:T.bg, borderRadius:52,
        border:"1.5px solid #1A2E22",
        boxShadow:[
          "0 0 0 7px #080E0A",
          "0 0 0 8.5px #1A2E22",
          "0 60px 120px rgba(0,0,0,.9)",
          `0 0 40px rgba(13,122,88,.08)`,
          "inset 0 1px 0 rgba(255,255,255,.04)",
        ].join(", "),
        position:"relative", overflow:"hidden",
        display:"flex", flexDirection:"column", height:760,
      }}>
        {/* Dynamic Island */}
        <div style={{ display:"flex", justifyContent:"center", paddingTop:13 }}>
          <div style={{
            width:120, height:33, background:"#000", borderRadius:18,
            display:"flex", alignItems:"center", justifyContent:"center",
            boxShadow:"inset 0 1px 3px rgba(0,0,0,.8)",
          }}>
            <div style={{ width:10, height:10, background:"#0A0A0A", borderRadius:"50%", marginRight:4 }}/>
            <div style={{ width:6,  height:6,  background:"#0A0A0A", borderRadius:"50%" }}/>
          </div>
        </div>

        {/* Status bar */}
        <div style={{ display:"flex", justifyContent:"space-between", padding:"10px 24px 6px",
          fontSize:11, fontWeight:700, color:T.text }}>
          <span>9:41</span>
          <span style={{ display:"flex", gap:5, alignItems:"center", fontSize:10, color:T.sub }}>
            <span>▲▲▲</span><span>WiFi</span><span>⚡ 87%</span>
          </span>
        </div>

        {/* Content */}
        <div style={{ flex:1, position:"relative", overflow:"hidden" }}>
          {content()}
        </div>

        {/* Tab bar */}
        <BottomBar active={activeExt} onTab={(i) => { setShowActivity(false); setTab(i); }}/>

        {/* Home indicator */}
        <div style={{
          position:"absolute", bottom:7, left:"50%", transform:"translateX(-50%)",
          width:110, height:4,
          background:"rgba(255,255,255,0.22)",
          borderRadius:2,
        }}/>
      </div>

      <div style={{ marginTop:16, fontSize:11, color:T.muted, textAlign:"center" }}>
        Все экраны интерактивны · Графики реагируют на наведение
      </div>
    </div>
  );
}
