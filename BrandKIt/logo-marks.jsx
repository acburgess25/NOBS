// logo-marks.jsx — NOBS logo explorations
// Hand-drawn / raw treatments. Real fonts + SVG turbulence/displacement filters.
// Palette: cream #FAF8F5, charcoal #1C1917, amber #D97706, sage #65A36E.

const PAL = {
  cream: '#FAF8F5',
  paper: '#F2EEE7',
  ink:   '#1C1917',
  ink2:  '#57534E',
  amber: '#D97706',
  amberDeep: '#B35914',
  sage:  '#65A36E',
  sageDeep: '#3F7E47',
  rose:  '#C75D5D',
};

// Shared filter set — one per artboard to avoid id collisions.
function RoughFilters({ id, baseFreq = 0.04, seed = 2, scale = 1.6 }) {
  return (
    <defs>
      {/* Inked / bled — bleeds outwards like a rubber stamp */}
      <filter id={`${id}-stamp`} x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency={baseFreq * 4} numOctaves="2" seed={seed} result="t"/>
        <feDisplacementMap in="SourceGraphic" in2="t" scale={scale * 1.4}/>
        <feGaussianBlur stdDeviation="0.35"/>
      </filter>
      {/* Marker — wobbly thick lines */}
      <filter id={`${id}-marker`} x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency={baseFreq} numOctaves="2" seed={seed + 1} result="t"/>
        <feDisplacementMap in="SourceGraphic" in2="t" scale={scale * 2.2}/>
      </filter>
      {/* Pencil — light scratchy edges */}
      <filter id={`${id}-pencil`} x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency={baseFreq * 6} numOctaves="3" seed={seed + 3} result="t"/>
        <feDisplacementMap in="SourceGraphic" in2="t" scale={scale * 0.6}/>
      </filter>
      {/* Photocopy — slight roughen */}
      <filter id={`${id}-copy`} x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency={baseFreq * 2.5} numOctaves="2" seed={seed + 5} result="t"/>
        <feDisplacementMap in="SourceGraphic" in2="t" scale={scale * 0.9}/>
      </filter>
      {/* Paper grain pattern */}
      <pattern id={`${id}-grain`} width="160" height="160" patternUnits="userSpaceOnUse">
        <rect width="160" height="160" fill="transparent"/>
        <filter id={`${id}-grain-f`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/>
          <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.06 0"/>
        </filter>
        <rect width="160" height="160" filter={`url(#${id}-grain-f)`}/>
      </pattern>
    </defs>
  );
}

// ── Caption strip under each artboard ────────────────────────────
function Caption({ title, note }) {
  return (
    <div style={{
      position: 'absolute', left: 24, bottom: 18, right: 24,
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      fontFamily: '"JetBrains Mono", ui-monospace, monospace',
      fontSize: 11, letterSpacing: 0.6, color: PAL.ink2,
      textTransform: 'uppercase',
    }}>
      <span>{title}</span>
      <span style={{ opacity: 0.65 }}>{note}</span>
    </div>
  );
}

// ── 01 — Marker scrawl ───────────────────────────────────────────
function L01_Marker() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m1" />
        <rect width="600" height="380" fill={`url(#m1-grain)`}/>
        <g filter="url(#m1-marker)">
          <text x="300" y="225" textAnchor="middle"
                fontFamily="Permanent Marker, cursive"
                fontSize="170" fill={PAL.ink} letterSpacing="-4">NOBS</text>
        </g>
        {/* underline scrawl */}
        <g filter="url(#m1-marker)" stroke={PAL.amber} strokeWidth="6" strokeLinecap="round" fill="none">
          <path d="M 170 258 C 260 254, 360 262, 440 254"/>
        </g>
      </svg>
      <Caption title="01 · Marker" note="Permanent Marker · displaced" />
    </div>
  );
}

// ── 02 — Inked rubber stamp ──────────────────────────────────────
function L02_Stamp() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m2" baseFreq={0.06} seed={4} scale={2.4} />
        <rect width="600" height="380" fill={`url(#m2-grain)`}/>
        {/* Outer rounded rect frame */}
        <g filter="url(#m2-stamp)" transform="rotate(-3 300 190)">
          <rect x="105" y="98" width="390" height="184" rx="18"
                fill="none" stroke={PAL.amberDeep} strokeWidth="9"/>
          <text x="300" y="220" textAnchor="middle"
                fontFamily="Archivo Black, sans-serif"
                fontSize="110" fill={PAL.amberDeep} letterSpacing="-1">NOBS</text>
          <text x="300" y="258" textAnchor="middle"
                fontFamily="Special Elite, monospace"
                fontSize="14" fill={PAL.amberDeep} letterSpacing="8">NO CLOUD · NO COMPROMISE</text>
        </g>
      </svg>
      <Caption title="02 · Stamp" note="Archivo Black · ink-bled" />
    </div>
  );
}

// ── 03 — Crossed-out cloud ───────────────────────────────────────
function L03_NoCloud() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m3" baseFreq={0.05} seed={6} scale={1.4} />
        <rect width="600" height="380" fill={`url(#m3-grain)`}/>
        {/* Cloud shape, hand-roughened */}
        <g filter="url(#m3-marker)" transform="translate(165 142)">
          <path d="M 30 60 C 12 60, 0 48, 4 32 C 8 18, 24 12, 36 16
                   C 38 4, 54 -4, 70 2 C 80 -8, 102 -6, 110 8
                   C 128 6, 142 18, 138 36 C 152 38, 158 52, 148 62 C 142 70, 130 70, 120 66 L 30 60 Z"
                fill="none" stroke={PAL.ink} strokeWidth="5" strokeLinejoin="round" strokeLinecap="round"/>
          {/* Big X */}
          <g stroke={PAL.rose} strokeWidth="9" strokeLinecap="round">
            <path d="M 12 0 L 150 70"/>
            <path d="M 150 0 L 12 70"/>
          </g>
        </g>
        {/* Wordmark */}
        <g filter="url(#m3-pencil)">
          <text x="370" y="230" textAnchor="start"
                fontFamily="Archivo Black, sans-serif"
                fontSize="92" fill={PAL.ink} letterSpacing="-2">NOBS</text>
        </g>
        <text x="370" y="262" textAnchor="start"
              fontFamily="JetBrains Mono, monospace"
              fontSize="11" fill={PAL.ink2} letterSpacing="2">YOUR AI · YOUR HOUSE</text>
      </svg>
      <Caption title="03 · No-cloud" note="Combination mark" />
    </div>
  );
}

// ── 04 — Monogram N (stenciled circle) ──────────────────────────
function L04_Monogram() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m4" baseFreq={0.07} seed={8} scale={1.8} />
        <rect width="600" height="380" fill={`url(#m4-grain)`}/>
        <g filter="url(#m4-stamp)">
          <circle cx="300" cy="180" r="118" fill={PAL.sageDeep}/>
          <text x="300" y="225" textAnchor="middle"
                fontFamily="Archivo Black, sans-serif"
                fontSize="180" fill={PAL.cream} letterSpacing="-6">N</text>
        </g>
        <text x="300" y="335" textAnchor="middle"
              fontFamily="JetBrains Mono, monospace"
              fontSize="13" fill={PAL.ink2} letterSpacing="6">N · O · B · S</text>
      </svg>
      <Caption title="04 · Monogram" note="Sage on cream · stamped" />
    </div>
  );
}

// ── 05 — Typewriter (NOBS.) ──────────────────────────────────────
function L05_Typewriter() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m5" baseFreq={0.12} seed={11} scale={0.9} />
        <rect width="600" height="380" fill={`url(#m5-grain)`}/>
        {/* paper register marks */}
        <g stroke={PAL.ink2} strokeWidth="1" opacity="0.4">
          <path d="M 84 90 L 84 110 M 74 100 L 94 100"/>
          <path d="M 516 270 L 516 290 M 506 280 L 526 280"/>
        </g>
        <g filter="url(#m5-copy)">
          <text x="300" y="220" textAnchor="middle"
                fontFamily="Special Elite, monospace"
                fontSize="140" fill={PAL.ink} letterSpacing="2">NOBS.</text>
        </g>
        <g filter="url(#m5-copy)">
          <rect x="142" y="252" width="316" height="3" fill={PAL.ink}/>
        </g>
        <text x="300" y="288" textAnchor="middle"
              fontFamily="Special Elite, monospace"
              fontSize="14" fill={PAL.ink2} letterSpacing="3">A PRIVATE AI · EST. ON YOUR LAN</text>
      </svg>
      <Caption title="05 · Typewriter" note="Special Elite · photocopy" />
    </div>
  );
}

// ── 06 — Pencil sketch wordmark with periods ────────────────────
function L06_Pencil() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m6" baseFreq={0.08} seed={14} scale={1.0} />
        <rect width="600" height="380" fill={`url(#m6-grain)`}/>
        {/* faint ruled lines */}
        <g stroke={PAL.ink2} strokeWidth="0.6" opacity="0.18">
          <line x1="80" y1="155" x2="520" y2="155"/>
          <line x1="80" y1="240" x2="520" y2="240"/>
        </g>
        <g filter="url(#m6-pencil)">
          <text x="300" y="228" textAnchor="middle"
                fontFamily="Caveat, cursive" fontWeight="700"
                fontSize="170" fill={PAL.ink} letterSpacing="2">n.o.b.s</text>
        </g>
        {/* hand-checked checkmark */}
        <g filter="url(#m6-pencil)" stroke={PAL.sageDeep} strokeWidth="6" strokeLinecap="round" fill="none">
          <path d="M 432 132 L 452 154 L 492 110"/>
        </g>
      </svg>
      <Caption title="06 · Pencil" note="Caveat · jotted on a pad" />
    </div>
  );
}

// ── 07 — Tape label ──────────────────────────────────────────────
function L07_Tape() {
  return (
    <div style={{ background: PAL.paper, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m7" baseFreq={0.05} seed={9} scale={1.3} />
        {/* torn paper tape */}
        <g transform="rotate(-4 300 190)">
          <g filter="url(#m7-stamp)">
            <rect x="90" y="128" width="420" height="120" fill={PAL.ink}/>
          </g>
          <text x="300" y="208" textAnchor="middle"
                fontFamily="Archivo Black, sans-serif"
                fontSize="92" fill={PAL.cream} letterSpacing="14">NOBS</text>
          {/* tape edges */}
          <g filter="url(#m7-stamp)" fill={PAL.ink}>
            <path d="M 92 128 L 88 120 L 96 122 L 100 116 L 104 124 L 110 118 L 114 128 Z"/>
            <path d="M 510 248 L 506 256 L 500 250 L 494 258 L 488 250 L 482 256 L 478 248 Z"/>
          </g>
        </g>
        <text x="300" y="310" textAnchor="middle"
              fontFamily="JetBrains Mono, monospace"
              fontSize="12" fill={PAL.ink2} letterSpacing="6">LABELED · SEALED · LOCAL</text>
      </svg>
      <Caption title="07 · Label" note="Punched tape on warm paper" />
    </div>
  );
}

// ── 08 — Dark mode, sage with leaf strike ───────────────────────
function L08_Dark() {
  return (
    <div style={{ background: PAL.ink, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m8" baseFreq={0.05} seed={16} scale={1.6} />
        <rect width="600" height="380" fill={`url(#m8-grain)`} opacity="0.5"/>
        <g filter="url(#m8-marker)">
          <text x="300" y="225" textAnchor="middle"
                fontFamily="Permanent Marker, cursive"
                fontSize="170" fill={PAL.cream} letterSpacing="-4">NOBS</text>
        </g>
        {/* sage swoosh */}
        <g filter="url(#m8-marker)" stroke={PAL.sage} strokeWidth="7" strokeLinecap="round" fill="none">
          <path d="M 160 270 C 220 264, 380 276, 444 264"/>
        </g>
      </svg>
      <Caption title="08 · Dark" note="Cream marker on charcoal" />
    </div>
  );
}

// ── 09 — Square mark (app icon candidate) ───────────────────────
function L09_AppIcon() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
                  display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg viewBox="0 0 320 320" width="220" height="220">
        <RoughFilters id="m9" baseFreq={0.05} seed={20} scale={2.0} />
        <g filter="url(#m9-stamp)">
          <rect x="20" y="20" width="280" height="280" rx="58" fill={PAL.amberDeep}/>
        </g>
        <g filter="url(#m9-marker)">
          <text x="160" y="220" textAnchor="middle"
                fontFamily="Archivo Black, sans-serif"
                fontSize="190" fill={PAL.cream} letterSpacing="-12">N</text>
        </g>
        {/* tick mark */}
        <g filter="url(#m9-marker)" stroke={PAL.cream} strokeWidth="9" strokeLinecap="round" fill="none">
          <path d="M 70 80 L 78 88 L 90 76"/>
        </g>
      </svg>
      <Caption title="09 · App icon" note="Amber square · raw N" />
    </div>
  );
}

// ── 10 — Bracketed wordmark [NOBS] ──────────────────────────────
function L10_Brackets() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m10" baseFreq={0.07} seed={22} scale={1.2} />
        <rect width="600" height="380" fill={`url(#m10-grain)`}/>
        <g filter="url(#m10-marker)" stroke={PAL.ink} strokeWidth="11" strokeLinecap="round" fill="none">
          <path d="M 130 130 L 110 130 L 110 240 L 130 240"/>
          <path d="M 490 130 L 510 130 L 510 240 L 490 240"/>
        </g>
        <g filter="url(#m10-marker)">
          <text x="300" y="215" textAnchor="middle"
                fontFamily="Archivo Black, sans-serif"
                fontSize="98" fill={PAL.ink} letterSpacing="2">NOBS</text>
        </g>
        <g filter="url(#m10-pencil)" stroke={PAL.amber} strokeWidth="3" fill="none">
          <line x1="160" y1="250" x2="440" y2="250"/>
        </g>
        <text x="300" y="278" textAnchor="middle"
              fontFamily="JetBrains Mono, monospace"
              fontSize="11" fill={PAL.ink2} letterSpacing="4">LOCAL · PRIVATE · YOURS</text>
      </svg>
      <Caption title="10 · Brackets" note="Held wordmark" />
    </div>
  );
}

// ── 11 — Just the dot (NO•BS) ───────────────────────────────────
function L11_Dot() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m11" baseFreq={0.05} seed={26} scale={1.6} />
        <rect width="600" height="380" fill={`url(#m11-grain)`}/>
        <g filter="url(#m11-stamp)">
          <text x="300" y="225" textAnchor="middle"
                fontFamily="Archivo Black, sans-serif"
                fontSize="140" fill={PAL.ink} letterSpacing="-1">NO<tspan fill={PAL.amber}>•</tspan>BS</text>
        </g>
      </svg>
      <Caption title="11 · NO·BS" note="Dot is the brand" />
    </div>
  );
}

// ── 12 — Lockup with leaf (refined raw) ─────────────────────────
function L12_Leaf() {
  return (
    <div style={{ background: PAL.cream, width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg viewBox="0 0 600 380" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        <RoughFilters id="m12" baseFreq={0.06} seed={31} scale={1.4} />
        <rect width="600" height="380" fill={`url(#m12-grain)`}/>
        {/* leaf icon — hand-roughened */}
        <g filter="url(#m12-marker)" transform="translate(135 130)">
          <path d="M 0 90 C 0 30, 50 0, 110 0 C 110 60, 60 90, 0 90 Z"
                fill={PAL.sageDeep}/>
          <path d="M 0 90 L 90 10" stroke={PAL.cream} strokeWidth="5" strokeLinecap="round" fill="none"/>
        </g>
        <g filter="url(#m12-marker)">
          <text x="285" y="230" textAnchor="start"
                fontFamily="Archivo Black, sans-serif"
                fontSize="110" fill={PAL.ink} letterSpacing="-1">NOBS</text>
        </g>
        <text x="285" y="262" textAnchor="start"
              fontFamily="JetBrains Mono, monospace"
              fontSize="11" fill={PAL.ink2} letterSpacing="3">PRIVATE AI · GROWS WITH YOU</text>
      </svg>
      <Caption title="12 · Lockup" note="Leaf + wordmark" />
    </div>
  );
}

Object.assign(window, {
  L01_Marker, L02_Stamp, L03_NoCloud, L04_Monogram, L05_Typewriter,
  L06_Pencil, L07_Tape, L08_Dark, L09_AppIcon, L10_Brackets,
  L11_Dot, L12_Leaf,
});
