// brand-kit.jsx — NOBS brand book sections (cover → iconography)
// Editorial long-scroll. Warm cream / charcoal / amber / sage.
// Reuses NOBS tokens, logo-marks and app-icon components from window.

const BK = {
  cream: '#FAF8F5',
  paper: '#F2EEE7',
  card:  '#FFFFFF',
  ink:   '#1C1917',
  ink2:  '#57534E',
  ink3:  '#A8A29E',
  rule:  'rgba(60,40,20,0.10)',
  ruleSoft: 'rgba(60,40,20,0.06)',
  amber: '#D97706',
  amberDeep: '#B35914',
  amberSoft: '#F59E0B',
  sage:  '#65A36E',
  sageDeep: '#3F7E47',
  rose:  '#C75D5D',
  blue:  '#5680A8',
};

const mono = '"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace';
const sans = '"SF Pro Rounded", ui-rounded, Nunito, -apple-system, system-ui, sans-serif';
const display = '"Archivo Black", "Helvetica Neue", sans-serif';

// ── Shared chrome ───────────────────────────────────────────────
function SectionHead({ no, title, kicker, anchor }) {
  return (
    <div id={anchor} style={{
      borderTop: `1px solid ${BK.ink}`,
      paddingTop: 28, marginTop: 80, marginBottom: 32,
      display: 'grid', gridTemplateColumns: '120px 1fr', gap: 32, alignItems: 'baseline',
    }}>
      <div style={{ fontFamily: mono, fontSize: 12, letterSpacing: 1.4, color: BK.ink2, textTransform: 'uppercase' }}>
        {no}
      </div>
      <div>
        <div style={{ fontFamily: display, fontSize: 56, lineHeight: 1, color: BK.ink, letterSpacing: -1.2 }}>{title}</div>
        {kicker && (
          <div style={{ fontFamily: sans, fontSize: 17, lineHeight: '24px', color: BK.ink2, marginTop: 10, maxWidth: 720 }}>
            {kicker}
          </div>
        )}
      </div>
    </div>
  );
}

function Meta({ children, style }) {
  return (
    <div style={{
      fontFamily: mono, fontSize: 10.5, letterSpacing: 1.2, color: BK.ink2,
      textTransform: 'uppercase', ...style,
    }}>{children}</div>
  );
}

function Tile({ children, height = 280, background = BK.card, border = true, style }) {
  return (
    <div style={{
      background, height, borderRadius: 14, overflow: 'hidden', position: 'relative',
      border: border ? `1px solid ${BK.rule}` : 'none',
      boxShadow: '0 1px 2px rgba(60,40,20,0.04)',
      ...style,
    }}>{children}</div>
  );
}

// ── 00 — Cover ──────────────────────────────────────────────────
function CoverSection() {
  return (
    <section style={{ paddingTop: 24 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 32, marginBottom: 24 }}>
        <Meta>NOBS / brand kit / v1.0 — may 2026</Meta>
        <Meta style={{ textAlign: 'right' }}>private ai · no cloud · no compromise</Meta>
      </div>
      <div style={{ position: 'relative', background: BK.cream, borderRadius: 22, overflow: 'hidden',
                    border: `1px solid ${BK.rule}`, padding: '72px 64px 56px', minHeight: 560 }}>
        {/* faint corner registration marks */}
        <RegistrationMarks />
        <Meta style={{ position: 'absolute', top: 28, left: 32 }}>filed under · identity</Meta>
        <Meta style={{ position: 'absolute', top: 28, right: 32 }}>nobs.local · ed. 01</Meta>

        <div style={{ display: 'flex', alignItems: 'center', gap: 32 }}>
          <NobsIcon size={172} uid="cover" filterStrength={1}/>
          <div style={{ fontFamily: display, fontSize: 220, lineHeight: 0.88, letterSpacing: -8, color: BK.ink }}>
            NOBS
          </div>
        </div>

        <div style={{ marginTop: 36, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 32, alignItems: 'end' }}>
          <div style={{ gridColumn: 'span 2' }}>
            <div style={{ fontFamily: sans, fontSize: 32, lineHeight: '38px', color: BK.ink, fontWeight: 600, maxWidth: 560, textWrap: 'pretty' }}>
              Your private AI.<br/>No cloud. No compromise.
            </div>
            <div style={{ marginTop: 18, fontFamily: sans, fontSize: 16, lineHeight: '24px', color: BK.ink2, maxWidth: 540 }}>
              A personal assistant that lives on your wifi. This document is the operating manual for the brand —
              everything an editor, designer, engineer or LLM needs to keep NOBS sounding and looking like NOBS.
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, fontFamily: mono, fontSize: 11, color: BK.ink2 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: `1px solid ${BK.ruleSoft}`, paddingBottom: 6 }}>
              <span>NAME</span><span style={{ color: BK.ink }}>NOBS</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: `1px solid ${BK.ruleSoft}`, paddingBottom: 6 }}>
              <span>CATEGORY</span><span style={{ color: BK.ink }}>private ai</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: `1px solid ${BK.ruleSoft}`, paddingBottom: 6 }}>
              <span>SUBSTRATE</span><span style={{ color: BK.ink }}>local network</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: `1px solid ${BK.ruleSoft}`, paddingBottom: 6 }}>
              <span>VOICE</span><span style={{ color: BK.ink }}>warm · blunt</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span>EST.</span><span style={{ color: BK.ink }}>on your LAN</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function RegistrationMarks() {
  const m = { stroke: BK.ink2, strokeWidth: 1, opacity: 0.35, fill: 'none' };
  const Cross = ({ x, y }) => (
    <g {...m} transform={`translate(${x} ${y})`}>
      <path d="M 0 -10 L 0 10 M -10 0 L 10 0"/>
      <circle cx="0" cy="0" r="6"/>
    </g>
  );
  return (
    <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} width="100%" height="100%" preserveAspectRatio="none" viewBox="0 0 1000 600">
      <Cross x="22" y="22"/>
      <Cross x="978" y="22"/>
      <Cross x="22" y="578"/>
      <Cross x="978" y="578"/>
    </svg>
  );
}

// ── 01 — Essence ────────────────────────────────────────────────
function EssenceSection() {
  const pillars = [
    { tag: 'PRIVATE', body: 'Your data never leaves the building. The model runs on local hardware; the cloud is not a dependency.', accent: BK.amber },
    { tag: 'HUMAN',   body: 'It speaks plainly. It remembers what matters. It does not perform; it does the thing.', accent: BK.sage },
    { tag: 'HONEST',  body: 'No upsell. No telemetry. No “opt-out” buried six menus deep. The defaults are the product.', accent: BK.ink },
  ];
  return (
    <section>
      <SectionHead no="01 · essence" anchor="essence" title="What NOBS is."
        kicker="A private AI that lives on the same network as your lamps. Strip the marketing — that is the entire promise. Everything in this kit exists to keep that promise legible." />

      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 32, alignItems: 'start' }}>
        <div style={{ background: BK.ink, color: BK.cream, borderRadius: 18, padding: '40px 44px',
                      fontFamily: sans, fontSize: 22, lineHeight: '32px', textWrap: 'pretty' }}>
          <Meta style={{ color: 'rgba(245,241,234,0.5)', marginBottom: 18 }}>manifesto · read aloud</Meta>
          <p style={{ margin: 0 }}>
            We don't sell your data because <span style={{ color: BK.amberSoft }}>we never have it</span>. NOBS runs on the
            same wifi as your kettle. It encrypts at rest, encrypts in transit, and forgets on command.
          </p>
          <p style={{ margin: '20px 0 0' }}>
            It is the smart parts of a smart home without the surveillance parts. It is a notebook that listens. It is
            <span style={{ color: BK.amberSoft }}> your AI, in your house</span> — and that's the whole pitch.
          </p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {pillars.map(p => (
            <div key={p.tag} style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 22 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
                <span style={{ width: 10, height: 10, borderRadius: 2, background: p.accent, display: 'inline-block' }}/>
                <Meta>{p.tag}</Meta>
              </div>
              <div style={{ fontFamily: sans, fontSize: 16, lineHeight: '23px', color: BK.ink }}>{p.body}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ── 02 — Logo system ────────────────────────────────────────────
function LogoSection() {
  return (
    <section>
      <SectionHead no="02 · logo" anchor="logo" title="The mark."
        kicker="The wordmark is Archivo Black, displaced through fractal noise so it always reads as drawn, never as a font. The icon is a stamped amber square with a raw N." />

      {/* Hero: full wordmark + small marks */}
      <div style={{ background: BK.cream, borderRadius: 18, border: `1px solid ${BK.rule}`, padding: 56, marginBottom: 24, position: 'relative' }}>
        <Meta style={{ position: 'absolute', top: 18, left: 24 }}>primary wordmark</Meta>
        <Meta style={{ position: 'absolute', top: 18, right: 24 }}>archivo black · displaced</Meta>
        <svg viewBox="0 0 1200 360" width="100%" height="auto">
          <defs>
            <filter id="bk-wm" x="-3%" y="-15%" width="106%" height="130%">
              <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="3"/>
              <feDisplacementMap in="SourceGraphic" scale="3.2"/>
            </filter>
          </defs>
          <g filter="url(#bk-wm)">
            <text x="600" y="270" textAnchor="middle" fontFamily={display}
                  fontSize="320" fill={BK.ink} letterSpacing="-10">NOBS</text>
          </g>
        </svg>
      </div>

      {/* Variations */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 16 }}>
        <Tile height={260}>
          <CenteredLabel title="primary · light" note="default" />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <NobsIcon size={150} uid="lo-primary"/>
          </div>
        </Tile>
        <Tile height={260} background={BK.ink}>
          <CenteredLabel title="primary · dark" note="reversed" dark />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <NobsIcon size={150} bg={BK.cream} fg={BK.ink} uid="lo-dark"/>
          </div>
        </Tile>
        <Tile height={260}>
          <CenteredLabel title="sage variant" note="alt accent" />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <NobsIcon size={150} bg={BK.sageDeep} fg={BK.cream} uid="lo-sage"/>
          </div>
        </Tile>
      </div>

      {/* Lockups + scale */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 16, marginBottom: 16 }}>
        <Tile height={300}>
          <CenteredLabel title="horizontal lockup" note="icon + wordmark + tag" />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 24, padding: 32 }}>
            <NobsIcon size={120} uid="lk-h"/>
            <div>
              <svg viewBox="0 0 360 110" width="280" height="86">
                <defs>
                  <filter id="lk-h-f" x="-5%" y="-15%" width="110%" height="130%">
                    <feTurbulence type="fractalNoise" baseFrequency="0.06" numOctaves="2" seed="5"/>
                    <feDisplacementMap in="SourceGraphic" scale="2.4"/>
                  </filter>
                </defs>
                <g filter="url(#lk-h-f)">
                  <text x="0" y="84" fontFamily={display} fontSize="100" fill={BK.ink} letterSpacing="-2">NOBS</text>
                </g>
              </svg>
              <div style={{ fontFamily: mono, fontSize: 11, color: BK.ink2, letterSpacing: 3, textTransform: 'uppercase', marginTop: 4 }}>
                no cloud · no compromise
              </div>
            </div>
          </div>
        </Tile>
        <Tile height={300}>
          <CenteredLabel title="stacked lockup" note="centered" />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
            <NobsIcon size={110} uid="lk-s"/>
            <svg viewBox="0 0 360 70" width="200" height="40">
              <defs>
                <filter id="lk-s-f"><feTurbulence type="fractalNoise" baseFrequency="0.06" numOctaves="2" seed="7"/><feDisplacementMap in="SourceGraphic" scale="2"/></filter>
              </defs>
              <g filter="url(#lk-s-f)">
                <text x="180" y="56" textAnchor="middle" fontFamily={display} fontSize="60" fill={BK.ink} letterSpacing="-1">NOBS</text>
              </g>
            </svg>
          </div>
        </Tile>
      </div>

      {/* Scale and clear space */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 16, marginBottom: 16 }}>
        <Tile height={240}>
          <CenteredLabel title="scale stack" note="@1024 → @40" />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 24 }}>
            {[180, 120, 84, 56, 36].map((s, i) => (
              <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                <NobsIcon size={s} uid={`lsc-${i}`} filterStrength={s < 70 ? 0.4 : 1}/>
                <Meta>{s}px</Meta>
              </div>
            ))}
          </div>
        </Tile>
        <Tile height={240}>
          <CenteredLabel title="clear space" note="1×N keep-out" />
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <ClearSpaceDiagram />
          </div>
        </Tile>
      </div>

      {/* Don'ts */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
        {[
          { label: "don't stretch", render: (
              <div style={{ transform: 'scale(1.6,0.6)' }}><NobsIcon size={90} uid="dn-1"/></div>
            ) },
          { label: "don't recolor randomly", render: (
              <NobsIcon size={120} bg="#7B2D8E" fg="#FFE08A" uid="dn-2"/>
            ) },
          { label: "don't outline", render: (
              <div style={{ position: 'relative' }}>
                <NobsIcon size={120} bg="transparent" fg={BK.amberDeep} uid="dn-3" innerHighlight={false}/>
                <div style={{ position:'absolute', inset:0, border:`2px solid ${BK.amberDeep}`, borderRadius: 26, pointerEvents:'none' }}/>
              </div>
            ) },
          { label: "don't add gradient", render: (
              <div style={{ width: 120, height: 120, borderRadius: 26,
                            background: 'linear-gradient(135deg, #F59E0B, #C75D5D)' }}/>
            ) },
        ].map((d, i) => (
          <Tile key={i} height={220}>
            <CenteredLabel title={d.label} note="bad practice" warn />
            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {d.render}
            </div>
            {/* red X overlay */}
            <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} width="100%" height="100%">
              <line x1="0" y1="0" x2="100%" y2="100%" stroke={BK.rose} strokeWidth="2" opacity="0.55"/>
              <line x1="100%" y1="0" x2="0" y2="100%" stroke={BK.rose} strokeWidth="2" opacity="0.55"/>
            </svg>
          </Tile>
        ))}
      </div>
    </section>
  );
}

function ClearSpaceDiagram() {
  return (
    <svg viewBox="0 0 320 200" width="320" height="200">
      <defs>
        <pattern id="dots" width="6" height="6" patternUnits="userSpaceOnUse">
          <circle cx="3" cy="3" r="0.7" fill={BK.ink3}/>
        </pattern>
      </defs>
      <rect x="80" y="20" width="160" height="160" fill="url(#dots)"/>
      <rect x="80" y="20" width="160" height="160" fill="none" stroke={BK.amber} strokeDasharray="4 4" strokeWidth="1"/>
      <g transform="translate(120 60) scale(0.625)">
        <foreignObject width="160" height="160">
          <div xmlns="http://www.w3.org/1999/xhtml">
            <NobsIcon size={160} uid="cs-1" filterStrength={0.6}/>
          </div>
        </foreignObject>
      </g>
      <g stroke={BK.ink2} strokeWidth="1" fill="none">
        <path d="M 80 12 L 80 4 L 240 4 L 240 12"/>
        <path d="M 248 20 L 256 20 L 256 180 L 248 180"/>
      </g>
      <text x="160" y="0" textAnchor="middle" fontFamily={mono} fontSize="9" fill={BK.ink2} dy="-2">1 × N</text>
      <text x="266" y="100" textAnchor="start" fontFamily={mono} fontSize="9" fill={BK.ink2} transform="rotate(-90 266 100)">1 × N</text>
    </svg>
  );
}

function CenteredLabel({ title, note, dark, warn }) {
  const c = dark ? 'rgba(245,241,234,0.55)' : (warn ? BK.rose : BK.ink2);
  const c2 = dark ? 'rgba(245,241,234,0.4)' : BK.ink3;
  return (
    <>
      <Meta style={{ position: 'absolute', top: 14, left: 18, color: c }}>{title}</Meta>
      <Meta style={{ position: 'absolute', top: 14, right: 18, color: c2 }}>{note}</Meta>
    </>
  );
}

// ── 03 — Color ──────────────────────────────────────────────────
function ColorSection() {
  const brand = [
    { name: 'Amber',      hex: '#D97706', use: 'Primary action · CTA · brand accent', fg: '#FFFFFF' },
    { name: 'Amber Deep', hex: '#B35914', use: 'Pressed states · stamp ink',           fg: '#FFFFFF' },
    { name: 'Amber Soft', hex: '#F59E0B', use: 'Highlight on dark · marker accent',   fg: '#1C1917' },
    { name: 'Sage',       hex: '#65A36E', use: 'Done · safe · positive',               fg: '#FFFFFF' },
    { name: 'Sage Deep',  hex: '#3F7E47', use: 'Stamped marks · sage variant',         fg: '#FFFFFF' },
    { name: 'Rose',       hex: '#C75D5D', use: 'Danger · destructive · errors',        fg: '#FFFFFF' },
    { name: 'Blue',       hex: '#5680A8', use: 'Info · links · network state',         fg: '#FFFFFF' },
    { name: 'Charcoal',   hex: '#1C1917', use: 'Ink · primary text · dark surface',    fg: '#FAF8F5' },
    { name: 'Cream',      hex: '#FAF8F5', use: 'Paper · light surface · reversed fg',  fg: '#1C1917' },
  ];

  return (
    <section>
      <SectionHead no="03 · color" anchor="color" title="Warm palette."
        kicker="One ink, two accents, one neutral paper. Saturated only where it does work. Whites are warm (oklch-tinted) — never pure #FFFFFF on light surfaces." />

      <Meta style={{ marginBottom: 12 }}>brand</Meta>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 32 }}>
        {brand.map(c => (
          <div key={c.name} style={{ borderRadius: 14, overflow: 'hidden', border: `1px solid ${BK.rule}` }}>
            <div style={{ background: c.hex, height: 110, padding: 14, color: c.fg,
                          display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div style={{ fontFamily: sans, fontSize: 18, fontWeight: 700 }}>{c.name}</div>
              <div style={{ fontFamily: mono, fontSize: 11, opacity: 0.85 }}>{c.hex}</div>
            </div>
            <div style={{ background: BK.card, padding: '12px 14px', fontFamily: sans, fontSize: 13, color: BK.ink2, minHeight: 44 }}>
              {c.use}
            </div>
          </div>
        ))}
      </div>

      {/* Surfaces — light & dark */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <SurfaceStack mode="light" />
        <SurfaceStack mode="dark"  />
      </div>

      {/* Tint scale */}
      <Meta style={{ marginTop: 32, marginBottom: 12 }}>amber + sage tints — for backgrounds and chips</Meta>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
        <TintBar label="Amber" color="217,119,6" />
        <TintBar label="Sage"  color="101,163,110" />
      </div>
    </section>
  );
}

function SurfaceStack({ mode }) {
  const dark = mode === 'dark';
  const rows = dark ? [
    { name: 'bg',          hex: '#1C1917', label: 'App background' },
    { name: 'surface',     hex: '#28231F', label: 'Cards' },
    { name: 'surfaceAlt',  hex: '#221E1A', label: 'Sunken fills' },
    { name: 'text',        hex: '#F5F1EA', label: 'Primary text' },
    { name: 'textSec',     hex: '#A8A29E', label: 'Secondary text' },
    { name: 'textTer',     hex: '#78716C', label: 'Tertiary text' },
  ] : [
    { name: 'bg',          hex: '#FAF8F5', label: 'App background' },
    { name: 'surface',     hex: '#FFFFFF', label: 'Cards' },
    { name: 'surfaceAlt',  hex: '#F2EEE7', label: 'Sunken fills' },
    { name: 'text',        hex: '#1C1917', label: 'Primary text' },
    { name: 'textSec',     hex: '#57534E', label: 'Secondary text' },
    { name: 'textTer',     hex: '#A8A29E', label: 'Tertiary text' },
  ];
  return (
    <div style={{ background: dark ? '#1C1917' : BK.cream, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 20 }}>
      <Meta style={{ color: dark ? 'rgba(245,241,234,0.55)' : BK.ink2, marginBottom: 14 }}>{mode} surfaces</Meta>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {rows.map(r => (
          <div key={r.name} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 36, height: 36, borderRadius: 8, background: r.hex,
                          border: r.hex === '#FFFFFF' || r.hex === '#FAF8F5' ? `1px solid ${BK.rule}` : 'none' }}/>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: sans, fontSize: 14, fontWeight: 600, color: dark ? '#F5F1EA' : BK.ink }}>{r.label}</div>
              <div style={{ fontFamily: mono, fontSize: 10.5, color: dark ? 'rgba(245,241,234,0.55)' : BK.ink2 }}>
                {`NOBS.${mode}.${r.name}`}
              </div>
            </div>
            <div style={{ fontFamily: mono, fontSize: 11, color: dark ? 'rgba(245,241,234,0.7)' : BK.ink2 }}>{r.hex}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function TintBar({ label, color }) {
  const steps = [0.08, 0.14, 0.22, 0.35, 0.55, 0.85, 1];
  return (
    <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 18 }}>
      <Meta style={{ marginBottom: 12 }}>{label} tint</Meta>
      <div style={{ display: 'flex', gap: 6 }}>
        {steps.map((a, i) => (
          <div key={i} style={{ flex: 1, height: 64, borderRadius: 8, background: `rgba(${color},${a})`,
                                 display: 'flex', alignItems: 'flex-end', padding: 6 }}>
            <span style={{ fontFamily: mono, fontSize: 9, color: a > 0.5 ? '#fff' : BK.ink2 }}>{Math.round(a*100)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── 04 — Typography ─────────────────────────────────────────────
function TypeSection() {
  return (
    <section>
      <SectionHead no="04 · type" anchor="type" title="Type system."
        kicker={<>Three families. <b>Archivo Black</b> for the wordmark only. <b>SF Pro Rounded</b> (fallback Nunito) for every UI surface. <b>JetBrains Mono</b> for metadata, code, technical labels.</>} />

      {/* Family cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 32 }}>
        <FamilyCard label="display · wordmark only" name="Archivo Black" style={{ fontFamily: display, fontSize: 88, lineHeight: 0.95, letterSpacing: -3 }} sample="NOBS"/>
        <FamilyCard label="ui · everything" name="SF Pro Rounded / Nunito" style={{ fontFamily: sans, fontSize: 64, lineHeight: 0.95, fontWeight: 700, letterSpacing: -1.5 }} sample="Aa Gg"/>
        <FamilyCard label="meta · code · labels" name="JetBrains Mono" style={{ fontFamily: mono, fontSize: 48, lineHeight: 1, letterSpacing: -0.5 }} sample="01·BS"/>
      </div>

      {/* Scale */}
      <Meta style={{ marginBottom: 12 }}>scale · apple HIG aligned</Meta>
      <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: '8px 0' }}>
        {[
          { name: 'largeTitle', size: 34, weight: 700, sample: 'Memories' },
          { name: 'title1',     size: 28, weight: 700, sample: 'Tasks for today' },
          { name: 'title2',     size: 22, weight: 700, sample: 'Pending' },
          { name: 'title3',     size: 20, weight: 600, sample: 'No cloud, no compromise.' },
          { name: 'headline',   size: 17, weight: 600, sample: 'Connect your network' },
          { name: 'body',       size: 17, weight: 400, sample: 'Your AI runs on the same wifi as your kettle.' },
          { name: 'callout',    size: 16, weight: 400, sample: 'Pinned to Personal' },
          { name: 'subhead',    size: 15, weight: 500, sample: 'Personal · 3 items' },
          { name: 'footnote',   size: 13, weight: 500, sample: 'Updated 4 min ago' },
          { name: 'caption',    size: 12, weight: 500, sample: 'Encrypted on device' },
          { name: 'overline',   size: 11, weight: 700, sample: 'TOOLS', upper: true, track: 1.2 },
        ].map(t => (
          <div key={t.name} style={{ display: 'grid', gridTemplateColumns: '140px 80px 1fr', alignItems: 'baseline',
                                       gap: 16, padding: '14px 22px', borderBottom: `1px solid ${BK.ruleSoft}` }}>
            <div style={{ fontFamily: mono, fontSize: 11, color: BK.ink2, textTransform: 'uppercase', letterSpacing: 1 }}>{t.name}</div>
            <div style={{ fontFamily: mono, fontSize: 11, color: BK.ink3 }}>{t.size}pt · w{t.weight}</div>
            <div style={{ fontFamily: sans, fontSize: t.size, fontWeight: t.weight, color: BK.ink,
                          textTransform: t.upper ? 'uppercase' : 'none', letterSpacing: t.track || (t.size > 22 ? -0.4 : -0.1) }}>
              {t.sample}
            </div>
          </div>
        ))}
      </div>

      {/* Pairings */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginTop: 32 }}>
        <PairingCard
          eyebrow="MEMORIES · PERSONAL"
          title="Mum's bookshop closes early on Thursdays."
          body="NOBS remembers this so you don't have to. It will gently nudge before your usual visit." />
        <PairingCard
          eyebrow="STATUS · LOCAL"
          title="Running on basement.local"
          body="Last sync 2 min ago · 14.2 GB of memories · encrypted at rest with your device key." />
      </div>
    </section>
  );
}

function FamilyCard({ label, name, style, sample }) {
  return (
    <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 22, minHeight: 200,
                  display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
      <Meta>{label}</Meta>
      <div style={{ color: BK.ink, ...style, textWrap: 'pretty' }}>{sample}</div>
      <div style={{ fontFamily: mono, fontSize: 11, color: BK.ink2 }}>{name}</div>
    </div>
  );
}

function PairingCard({ eyebrow, title, body }) {
  return (
    <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 24 }}>
      <div style={{ fontFamily: mono, fontSize: 11, color: BK.amber, letterSpacing: 1.4, textTransform: 'uppercase', marginBottom: 10 }}>{eyebrow}</div>
      <div style={{ fontFamily: sans, fontSize: 22, fontWeight: 700, color: BK.ink, lineHeight: '28px', letterSpacing: -0.3, marginBottom: 8, textWrap: 'pretty' }}>{title}</div>
      <div style={{ fontFamily: sans, fontSize: 15, color: BK.ink2, lineHeight: '22px', textWrap: 'pretty' }}>{body}</div>
    </div>
  );
}

// ── 05 — Iconography ────────────────────────────────────────────
function IconSection() {
  const groups = [
    { tag: 'navigation', icons: ['chevronLeft','chevronRight','chevronDown','plus','close','check','search','ellipsis'] },
    { tag: 'tabs',       icons: ['memory','tasks','more','settings'] },
    { tag: 'actions',    icons: ['send','mic','lock','shield','edit','trash','download','link','eye'] },
    { tag: 'tools',      icons: ['home','heart','phone','contacts','bell','sparkle','calendar','clock','flag','sun','moon','folder','star','wifi','bolt','leaf','pin','cloud','user','server','waveform'] },
  ];
  return (
    <section>
      <SectionHead no="05 · icons" anchor="icons" title="Line set."
        kicker="1.7px stroke. Rounded caps and joins. 24px grid. Drawn at one weight — the only difference between active and inactive is color, never weight." />

      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {groups.map(g => (
          <div key={g.tag} style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 22 }}>
            <Meta style={{ marginBottom: 16 }}>{g.tag} · {g.icons.length}</Meta>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 14 }}>
              {g.icons.map(n => (
                <div key={n} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
                                       padding: 12, borderRadius: 10, background: BK.paper, color: BK.ink }}>
                  <Icon name={n} size={24} color={BK.ink} />
                  <span style={{ fontFamily: mono, fontSize: 9, color: BK.ink2, letterSpacing: 0.4 }}>{n}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

Object.assign(window, {
  BK, mono, sans, display,
  SectionHead, Meta, Tile, CenteredLabel,
  CoverSection, EssenceSection, LogoSection, ColorSection, TypeSection, IconSection,
});
