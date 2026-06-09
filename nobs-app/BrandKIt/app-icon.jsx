// app-icon.jsx — NOBS app icon refinement
// Modern rounded square + minimal N + signal dot. Keep this aligned with
// BRAND-GUIDE.md and tools/generate_modern_brand_assets.py.

const APAL = {
  cream: '#FAF8F5',
  paper: '#F2EEE7',
  ink:   '#1C1917',
  ink2:  '#57534E',
  amber: '#D97706',
  amberDeep: '#B35914',
  amberBright: '#F59E0B',
  sage:  '#65A36E',
  sageDeep: '#3F7E47',
  rose:  '#C75D5D',
};

// Reusable filter pack — strength tunable so we can dial down at small sizes.
function IconFilters({ id, strength = 1 }) {
  return (
    <defs>
      <filter id={`${id}-stamp`} x="-8%" y="-8%" width="116%" height="116%">
        <feTurbulence type="fractalNoise" baseFrequency="0.18" numOctaves="2" seed="20"/>
        <feDisplacementMap in="SourceGraphic" scale={1.4 * strength}/>
        <feGaussianBlur stdDeviation={0.22 * strength}/>
      </filter>
      <filter id={`${id}-marker`} x="-8%" y="-8%" width="116%" height="116%">
        <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="21"/>
        <feDisplacementMap in="SourceGraphic" scale={2.0 * strength}/>
      </filter>
    </defs>
  );
}

// ── Core icon — parametric ──────────────────────────────────────
function NobsIcon({
  size = 220,
  bg = '#0A0D12',
  fg = APAL.cream,
  tick = false,
  letter = 'N',
  filterStrength = 0,
  cornerScale = 0.24,
  letterScale = 0.52,
  fontFamily = '-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif',
  underline = false,
  dot = true,
  innerHighlight = true,
  uid = 'i',
}) {
  const id = `${uid}-${size}-${bg.replace('#','')}`;
  const vb = 320;
  const r = vb * cornerScale;
  const fs = vb * letterScale;
  const letterCx = vb / 2;
  const letterCy = vb * 0.47;
  return (
    <svg viewBox={`0 0 ${vb} ${vb}`} width={size} height={size}>
      <IconFilters id={id} strength={filterStrength} />
      <g filter={filterStrength > 0 ? `url(#${id}-stamp)` : undefined}>
        <rect x="0" y="0" width={vb} height={vb} rx={r} fill={bg}/>
      </g>
      {innerHighlight && (
        <rect x="3" y="3" width={vb - 6} height={vb - 6} rx={r - 3}
              fill="none" stroke="rgba(255,255,255,0.18)" strokeWidth="2"/>
      )}
      <g filter={filterStrength > 0 ? `url(#${id}-marker)` : undefined}>
        <text x={letterCx} y={letterCy}
              textAnchor="middle"
              dominantBaseline="central"
              fontFamily={fontFamily}
              fontSize={fs} fill={fg}
              fontWeight="800"
              letterSpacing="0">{letter}</text>
      </g>
      {dot && (
        <circle cx={vb * 0.72} cy={vb * 0.72} r={vb * 0.055} fill={APAL.sage}/>
      )}
      {tick && (
        <g filter={filterStrength > 0 ? `url(#${id}-marker)` : undefined}
           stroke={fg} strokeWidth={vb*0.028} strokeLinecap="round" fill="none">
          <path d={`M ${vb*0.22} ${vb*0.25} L ${vb*0.245} ${vb*0.275} L ${vb*0.28} ${vb*0.235}`} />
        </g>
      )}
      {underline && (() => {
        // Controlled scribble — gentle even wave, no chaotic displacement.
        const cy = vb * 0.82;
        const x1 = vb * 0.24, x2 = vb * 0.76;
        const w = x2 - x1;
        const amp = vb * 0.012;
        const sw = vb * 0.026;
        // Three evenly-spaced humps: down-up-down-up baseline
        const d = `
          M ${x1} ${cy}
          C ${x1 + w*0.16} ${cy - amp}, ${x1 + w*0.34} ${cy + amp}, ${x1 + w*0.50} ${cy}
          S ${x1 + w*0.84} ${cy + amp}, ${x2}    ${cy}
        `;
        return (
          <g stroke={fg} strokeLinecap="round" strokeLinejoin="round" fill="none">
            <path d={d} strokeWidth={sw} opacity="0.95"/>
          </g>
        );
      })()}
    </svg>
  );
}

// Frame wrapper with consistent caption
function ArtFrame({ bg = APAL.paper, children, title, note }) {
  return (
    <div style={{ background: bg, width: '100%', height: '100%', position: 'relative',
                  overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      {children}
      <div style={{
        position: 'absolute', left: 24, bottom: 18, right: 24,
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        fontFamily: '"JetBrains Mono", ui-monospace, monospace',
        fontSize: 11, letterSpacing: 0.6, color: APAL.ink2,
        textTransform: 'uppercase',
      }}>
        <span>{title}</span>
        <span style={{ opacity: 0.65 }}>{note}</span>
      </div>
    </div>
  );
}

// ── A1 — Hero ────────────────────────────────────────────────────
function A1_Hero() {
  return (
    <ArtFrame bg={APAL.paper} title="A1 · Hero" note="1024 · production">
      <NobsIcon size={300} uid="hero" />
    </ArtFrame>
  );
}

// ── A2 — Scale stack ─────────────────────────────────────────────
function A2_Scales() {
  const sizes = [220, 140, 96, 60, 40];
  return (
    <ArtFrame bg={APAL.paper} title="A2 · Scale stack" note="@1024 → @40 · iOS sizes">
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 28 }}>
        {sizes.map((s, i) => (
          <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <NobsIcon size={s} uid={`sc-${i}`} filterStrength={s < 80 ? 0.5 : 1}/>
            <span style={{ fontFamily: '"JetBrains Mono", monospace', fontSize: 10, color: APAL.ink2 }}>{s}px</span>
          </div>
        ))}
      </div>
    </ArtFrame>
  );
}

// ── A3 — Color variations ────────────────────────────────────────
function A3_Colors() {
  const opts = [
    { bg: APAL.amberDeep, fg: APAL.cream, name: 'Amber' },
    { bg: APAL.sageDeep,  fg: APAL.cream, name: 'Sage' },
    { bg: APAL.ink,       fg: APAL.cream, name: 'Ink' },
    { bg: APAL.cream,     fg: APAL.ink,   name: 'Cream' },
  ];
  return (
    <ArtFrame bg={APAL.paper} title="A3 · Color" note="Pick your wallpaper">
      <div style={{ display: 'flex', gap: 36, alignItems: 'flex-end' }}>
        {opts.map((o, i) => (
          <div key={o.name} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <NobsIcon size={150} bg={o.bg} fg={o.fg} uid={`c-${i}`}/>
            <span style={{ fontFamily: '"JetBrains Mono", monospace', fontSize: 10, color: APAL.ink2,
                            letterSpacing: 1, textTransform: 'uppercase' }}>{o.name}</span>
          </div>
        ))}
      </div>
    </ArtFrame>
  );
}

// ── A4 — Mark variants ───────────────────────────────────────────
function A4_Marks() {
  const opts = [
    { tick: false, dot: false, underline: false, name: 'Bare' },
    { tick: true,  dot: false, underline: false, name: 'Tick' },
    { tick: false, dot: false, underline: true,  name: 'Underline' },
    { tick: false, dot: true,  underline: false, name: 'Dot' },
  ];
  return (
    <ArtFrame bg={APAL.paper} title="A4 · Mark" note="Accent on the N">
      <div style={{ display: 'flex', gap: 36, alignItems: 'flex-end' }}>
        {opts.map((o, i) => (
          <div key={o.name} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <NobsIcon size={150} tick={o.tick} dot={o.dot} underline={o.underline} uid={`m-${i}`}/>
            <span style={{ fontFamily: '"JetBrains Mono", monospace', fontSize: 10, color: APAL.ink2,
                            letterSpacing: 1, textTransform: 'uppercase' }}>{o.name}</span>
          </div>
        ))}
      </div>
    </ArtFrame>
  );
}

// ── A5 — Lockup (icon + wordmark) ────────────────────────────────
function A5_Lockup() {
  return (
    <ArtFrame bg={APAL.cream} title="A5 · Lockup" note="Icon + wordmark">
      <div style={{ display: 'flex', alignItems: 'center', gap: 28 }}>
        <NobsIcon size={132} uid="lk"/>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <svg viewBox="0 0 360 110" width="320" height="98">
            <IconFilters id="lk-wm" />
            <g filter="url(#lk-wm-marker)">
              <text x="0" y="84" fontFamily="Archivo Black, sans-serif"
                    fontSize="100" fill={APAL.ink} letterSpacing="-2">NOBS</text>
            </g>
          </svg>
          <span style={{ marginTop: 4, fontFamily: '"JetBrains Mono", monospace',
                          fontSize: 11, color: APAL.ink2, letterSpacing: 3, textTransform: 'uppercase' }}>
            no cloud · no compromise
          </span>
        </div>
      </div>
    </ArtFrame>
  );
}

// ── A6 — Stacked lockup ──────────────────────────────────────────
function A6_StackedLockup() {
  return (
    <ArtFrame bg={APAL.cream} title="A6 · Stacked" note="Centered lockup">
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
        <NobsIcon size={130} uid="st"/>
        <svg viewBox="0 0 360 70" width="220" height="44">
          <IconFilters id="st-wm" />
          <g filter="url(#st-wm-marker)">
            <text x="180" y="56" textAnchor="middle" fontFamily="Archivo Black, sans-serif"
                  fontSize="64" fill={APAL.ink} letterSpacing="-1">NOBS</text>
          </g>
        </svg>
      </div>
    </ArtFrame>
  );
}

// ── A7 — Clean / production version (no filter) ──────────────────
function A7_Clean() {
  return (
    <ArtFrame bg={APAL.paper} title="A7 · Clean" note="Same form · filter off">
      <div style={{ display: 'flex', alignItems: 'center', gap: 48 }}>
        <NobsIcon size={220} uid="cl-on"  filterStrength={1}/>
        <NobsIcon size={220} uid="cl-off" filterStrength={0}/>
      </div>
      <div style={{ position: 'absolute', bottom: 56, left: 0, right: 0,
                    display: 'flex', justifyContent: 'center', gap: 132,
                    fontFamily: '"JetBrains Mono", monospace', fontSize: 10,
                    color: APAL.ink2, letterSpacing: 2, textTransform: 'uppercase' }}>
        <span>raw</span>
        <span>clean</span>
      </div>
    </ArtFrame>
  );
}

// ── A8 — On a home screen (in situ) ──────────────────────────────
function A8_HomeScreen() {
  // generic placeholder app squares — not recreating any real brand
  const grid = [
    ['#3a78c6', '#e25b62', '#34a07a', '#nobs'],
    ['#7f4ad1', '#e2a23a', '#2bb6c2', '#5a6573'],
    ['#nobs',   '#3a78c6', '#c44a8a', '#34a07a'],
    ['#e25b62', '#5a6573', '#e2a23a', '#7f4ad1'],
  ];
  return (
    <ArtFrame bg="#1c2330" title="A8 · Home screen" note="In situ">
      {/* faux wallpaper */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(ellipse at 30% 20%, #3b4663 0%, #1c2330 60%, #0e131c 100%)',
      }}/>
      <div style={{ position: 'relative', zIndex: 1, display: 'flex',
                    flexDirection: 'column', alignItems: 'center', gap: 18, padding: '24px 0 64px' }}>
        <div style={{
          fontFamily: '-apple-system, "SF Pro", system-ui', fontWeight: 600, fontSize: 56,
          color: 'white', letterSpacing: -1, textShadow: '0 2px 12px rgba(0,0,0,0.4)',
        }}>9:41</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 64px)', gap: 22 }}>
          {grid.flat().map((c, i) => (
            <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              {c === '#nobs' ? (
                <NobsIcon size={64} uid={`hs-${i}`} filterStrength={0.5} innerHighlight={false}/>
              ) : (
                <div style={{ width: 64, height: 64, borderRadius: 14,
                              background: `linear-gradient(160deg, ${c}, ${c}cc)`,
                              boxShadow: '0 2px 6px rgba(0,0,0,0.25)' }}/>
              )}
              <span style={{ fontFamily: '-apple-system, system-ui', fontSize: 11, color: 'white',
                              opacity: 0.92, textShadow: '0 1px 2px rgba(0,0,0,0.5)' }}>
                {c === '#nobs' ? 'NOBS' : ''}
              </span>
            </div>
          ))}
        </div>
      </div>
    </ArtFrame>
  );
}

// ── A9 — Single huge icon (for splash / hero use) ────────────────
function A9_Splash() {
  return (
    <ArtFrame bg={APAL.cream} title="A9 · Splash" note="Use on launch / hero">
      <div style={{ position: 'relative' }}>
        <NobsIcon size={300} uid="sp" filterStrength={1.1}/>
      </div>
    </ArtFrame>
  );
}

Object.assign(window, {
  NobsIcon,
  A1_Hero, A2_Scales, A3_Colors, A4_Marks, A5_Lockup,
  A6_StackedLockup, A7_Clean, A8_HomeScreen, A9_Splash,
});
