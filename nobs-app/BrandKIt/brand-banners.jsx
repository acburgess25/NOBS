// brand-banners.jsx — NOBS brand book: banners, texture, voice, components, spec
// Reuses BK/mono/sans/display, Meta, Tile, SectionHead, NobsIcon, NOBS, TYPE, Icon.

// ── Shared banner chrome ────────────────────────────────────────
function BannerFrame({ ratio, label, dim, children, scale = 1, background = '#FAF8F5' }) {
  // Render at a fixed CSS box; banner inside renders at "design" px then scales to fit.
  return (
    <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 18 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
        <Meta>{label}</Meta>
        <Meta style={{ color: BK.ink3 }}>{dim} · {ratio}</Meta>
      </div>
      <div style={{ background, borderRadius: 8, overflow: 'hidden', position: 'relative',
                    boxShadow: 'inset 0 0 0 1px rgba(60,40,20,0.08)' }}>
        {children}
      </div>
    </div>
  );
}

// Hand-roughened filter for banner display text
function BannerFilters({ id }) {
  return (
    <defs>
      <filter id={`${id}-disp`} x="-5%" y="-15%" width="110%" height="130%">
        <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="9"/>
        <feDisplacementMap in="SourceGraphic" scale="2.6"/>
      </filter>
      <filter id={`${id}-grain`}>
        <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/>
        <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.05 0"/>
      </filter>
      <pattern id={`${id}-paper`} width="180" height="180" patternUnits="userSpaceOnUse">
        <rect width="180" height="180" fill="transparent"/>
        <rect width="180" height="180" filter={`url(#${id}-grain)`}/>
      </pattern>
    </defs>
  );
}

// ── 06 — Banners ────────────────────────────────────────────────
function BannersSection() {
  return (
    <section>
      <SectionHead no="06 · banners" anchor="banners" title="Out in the world."
        kicker="Six approved compositions. Lockup positioning, copy length and palette are pre-set. Use them as templates — replace the line, never the layout." />

      {/* OG card — 1200×630 */}
      <div style={{ marginBottom: 16 }}>
        <BannerFrame ratio="1.91:1" label="og · social card" dim="1200 × 630" background={BK.cream}>
          <div style={{ aspectRatio: '1200 / 630', position: 'relative' }}>
            <svg viewBox="0 0 1200 630" width="100%" height="100%" style={{ display: 'block' }}>
              <BannerFilters id="og"/>
              <rect width="1200" height="630" fill={BK.cream}/>
              <rect width="1200" height="630" fill="url(#og-paper)"/>
              <g filter="url(#og-disp)">
                <text x="80" y="360" fontFamily={display} fontSize="220" fill={BK.ink} letterSpacing="-8">NOBS.</text>
              </g>
              <text x="80" y="440" fontFamily={sans} fontWeight="600" fontSize="38" fill={BK.ink2} letterSpacing="-0.5">
                Your private AI. No cloud. No compromise.
              </text>
              <g transform="translate(900 200)">
                <foreignObject width="220" height="220">
                  <div xmlns="http://www.w3.org/1999/xhtml" style={{ display: 'flex', justifyContent: 'center' }}>
                    <NobsIcon size={220} uid="og-mark"/>
                  </div>
                </foreignObject>
              </g>
              {/* meta strip */}
              <line x1="80" y1="540" x2="1120" y2="540" stroke={BK.ink} strokeWidth="1.5"/>
              <text x="80" y="572" fontFamily={mono} fontSize="14" fill={BK.ink} letterSpacing="3">RUNS · ON · YOUR · LAN</text>
              <text x="1120" y="572" textAnchor="end" fontFamily={mono} fontSize="14" fill={BK.ink2} letterSpacing="3">NOBS.LOCAL</text>
            </svg>
          </div>
        </BannerFrame>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        {/* Twitter / Linkedin header — dark variant */}
        <BannerFrame ratio="3:1" label="profile header · dark" dim="1500 × 500" background={BK.ink}>
          <div style={{ aspectRatio: '1500 / 500', position: 'relative' }}>
            <svg viewBox="0 0 1500 500" width="100%" height="100%" style={{ display: 'block' }}>
              <BannerFilters id="hdr"/>
              <rect width="1500" height="500" fill={BK.ink}/>
              <rect width="1500" height="500" fill="url(#hdr-paper)" opacity="0.6"/>
              <g filter="url(#hdr-disp)">
                <text x="80" y="320" fontFamily={display} fontSize="260" fill={BK.cream} letterSpacing="-10">NOBS</text>
              </g>
              <g filter="url(#hdr-disp)" stroke={BK.amberSoft} strokeWidth="8" fill="none" strokeLinecap="round">
                <path d="M 90 380 C 250 372, 700 392, 920 376"/>
              </g>
              <text x="980" y="220" fontFamily={mono} fontSize="22" fill="rgba(245,241,234,0.6)" letterSpacing="3">A PRIVATE AI</text>
              <text x="980" y="262" fontFamily={sans} fontSize="40" fontWeight="700" fill={BK.cream} letterSpacing="-0.5">No cloud.</text>
              <text x="980" y="306" fontFamily={sans} fontSize="40" fontWeight="700" fill={BK.cream} letterSpacing="-0.5">No compromise.</text>
              <text x="980" y="380" fontFamily={mono} fontSize="14" fill="rgba(245,241,234,0.55)" letterSpacing="3">EST · ON YOUR LAN</text>
            </svg>
          </div>
        </BannerFrame>

        {/* Square — 1080×1080 */}
        <BannerFrame ratio="1:1" label="instagram · feed" dim="1080 × 1080" background={BK.amberDeep}>
          <div style={{ aspectRatio: '1 / 1', position: 'relative' }}>
            <svg viewBox="0 0 1080 1080" width="100%" height="100%" style={{ display: 'block' }}>
              <BannerFilters id="sq"/>
              <rect width="1080" height="1080" fill={BK.amberDeep}/>
              <rect width="1080" height="1080" fill="url(#sq-paper)" opacity="0.8"/>
              <g filter="url(#sq-disp)">
                <text x="540" y="540" textAnchor="middle" fontFamily={display} fontSize="220" fill={BK.cream} letterSpacing="-8">NO</text>
                <text x="540" y="760" textAnchor="middle" fontFamily={display} fontSize="220" fill={BK.cream} letterSpacing="-8">BS.</text>
              </g>
              <g filter="url(#sq-disp)" stroke={BK.cream} strokeWidth="6" fill="none" strokeLinecap="round" opacity="0.9">
                <path d="M 300 810 C 460 802, 620 822, 780 808"/>
              </g>
              <text x="540" y="900" textAnchor="middle" fontFamily={mono} fontSize="22" fill="rgba(255,255,255,0.85)" letterSpacing="6">YOUR · AI · YOUR · HOUSE</text>
            </svg>
          </div>
        </BannerFrame>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginBottom: 16 }}>
        {/* Story 9:16 */}
        <BannerFrame ratio="9:16" label="story · vertical" dim="1080 × 1920" background={BK.cream}>
          <div style={{ aspectRatio: '9 / 16', position: 'relative' }}>
            <svg viewBox="0 0 1080 1920" width="100%" height="100%" style={{ display: 'block' }}>
              <BannerFilters id="st"/>
              <rect width="1080" height="1920" fill={BK.cream}/>
              <rect width="1080" height="1920" fill="url(#st-paper)"/>
              {/* corner ticks */}
              <g stroke={BK.ink} strokeWidth="2" fill="none">
                <path d="M 80 80 L 80 140 M 80 80 L 140 80"/>
                <path d="M 1000 80 L 1000 140 M 1000 80 L 940 80"/>
                <path d="M 80 1840 L 80 1780 M 80 1840 L 140 1840"/>
                <path d="M 1000 1840 L 1000 1780 M 1000 1840 L 940 1840"/>
              </g>
              <text x="540" y="240" textAnchor="middle" fontFamily={mono} fontSize="32" fill={BK.ink2} letterSpacing="8">A PRIVATE AI</text>
              <g transform="translate(420 360)">
                <foreignObject width="240" height="240">
                  <div xmlns="http://www.w3.org/1999/xhtml" style={{ display: 'flex', justifyContent: 'center' }}>
                    <NobsIcon size={240} uid="st-mark"/>
                  </div>
                </foreignObject>
              </g>
              <g filter="url(#st-disp)">
                <text x="540" y="900" textAnchor="middle" fontFamily={display} fontSize="220" fill={BK.ink} letterSpacing="-8">NOBS</text>
              </g>
              <text x="540" y="1050" textAnchor="middle" fontFamily={sans} fontSize="46" fontWeight="600" fill={BK.ink}>No cloud.</text>
              <text x="540" y="1110" textAnchor="middle" fontFamily={sans} fontSize="46" fontWeight="600" fill={BK.ink}>No compromise.</text>
              <line x1="380" y1="1180" x2="700" y2="1180" stroke={BK.amber} strokeWidth="3"/>
              <text x="540" y="1260" textAnchor="middle" fontFamily={sans} fontSize="34" fill={BK.ink2}>It runs on the same wifi</text>
              <text x="540" y="1310" textAnchor="middle" fontFamily={sans} fontSize="34" fill={BK.ink2}>as your kettle.</text>
              <text x="540" y="1810" textAnchor="middle" fontFamily={mono} fontSize="24" fill={BK.ink2} letterSpacing="6">NOBS.LOCAL · ED. 01</text>
            </svg>
          </div>
        </BannerFrame>

        {/* App store feature */}
        <BannerFrame ratio="9:16" label="app store · feature" dim="1080 × 1920" background={BK.ink}>
          <div style={{ aspectRatio: '9 / 16', position: 'relative' }}>
            <svg viewBox="0 0 1080 1920" width="100%" height="100%" style={{ display: 'block' }}>
              <BannerFilters id="as"/>
              <rect width="1080" height="1920" fill={BK.ink}/>
              <rect width="1080" height="1920" fill="url(#as-paper)" opacity="0.5"/>
              <text x="540" y="220" textAnchor="middle" fontFamily={mono} fontSize="28" fill="rgba(245,241,234,0.55)" letterSpacing="6">PRIVATE AI · iOS 18</text>
              <g filter="url(#as-disp)">
                <text x="540" y="500" textAnchor="middle" fontFamily={display} fontSize="200" fill={BK.cream} letterSpacing="-8">NOBS</text>
              </g>
              <g filter="url(#as-disp)" stroke={BK.amberSoft} strokeWidth="7" fill="none" strokeLinecap="round">
                <path d="M 280 560 C 480 552, 720 572, 820 558"/>
              </g>
              {/* device chrome stub */}
              <g transform="translate(240 700)">
                <rect x="0" y="0" width="600" height="1000" rx="80" fill="#0e0c0a" stroke="#2a2521" strokeWidth="4"/>
                <rect x="40" y="40" width="520" height="920" rx="50" fill={BK.cream}/>
                <foreignObject x="40" y="40" width="520" height="920">
                  <div xmlns="http://www.w3.org/1999/xhtml" style={{ width:'100%', height:'100%', padding: 40, boxSizing:'border-box', fontFamily: sans }}>
                    <div style={{ fontSize: 56, fontWeight: 700, color: BK.ink, lineHeight: 1.1 }}>Memories</div>
                    <div style={{ fontSize: 24, color: BK.ink2, marginTop: 10 }}>3 personal · 1 work</div>
                    {[
                      { tag: 'Personal', body: "Mum's bookshop closes early on Thursdays." },
                      { tag: 'Work',     body: 'Q3 plan due Friday. Draft is in /notes.' },
                      { tag: 'Personal', body: 'Sam is allergic to walnuts (not pecans).' },
                    ].map((m,i) => (
                      <div key={i} style={{ background: '#fff', borderRadius: 22, padding: 22, marginTop: 18,
                                              boxShadow: '0 1px 2px rgba(60,40,20,0.04), 0 4px 16px rgba(60,40,20,0.06)' }}>
                        <span style={{ fontSize: 18, fontWeight: 700, color: m.tag==='Work'?BK.sage:BK.amber,
                                       background: m.tag==='Work'?'rgba(101,163,110,0.12)':'rgba(217,119,6,0.10)',
                                       padding: '4px 12px', borderRadius: 999 }}>{m.tag}</span>
                        <div style={{ marginTop: 12, fontSize: 28, lineHeight: 1.3, color: BK.ink }}>{m.body}</div>
                      </div>
                    ))}
                  </div>
                </foreignObject>
              </g>
              <text x="540" y="1820" textAnchor="middle" fontFamily={sans} fontSize="38" fill={BK.cream} fontWeight="600">Your AI. Your house.</text>
            </svg>
          </div>
        </BannerFrame>

        {/* Sticker / Email signature */}
        <BannerFrame ratio="9:16" label="sticker sheet · vinyl" dim="for IRL print" background={BK.paper}>
          <div style={{ aspectRatio: '9 / 16', position: 'relative', padding: 40, boxSizing: 'border-box' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, height: '100%' }}>
              <Sticker bg={BK.amberDeep} fg={BK.cream}>NO CLOUD</Sticker>
              <Sticker bg={BK.cream} fg={BK.ink} border>NO BS.</Sticker>
              <Sticker bg={BK.sageDeep} fg={BK.cream}>YOUR LAN</Sticker>
              <Sticker bg={BK.ink} fg={BK.cream}>NOBS</Sticker>
              <Sticker bg={BK.cream} fg={BK.ink} border>LOCAL FIRST</Sticker>
              <Sticker bg={BK.amberSoft} fg={BK.ink}>EST · 2026</Sticker>
            </div>
          </div>
        </BannerFrame>
      </div>
    </section>
  );
}

function Sticker({ bg, fg, border, children }) {
  return (
    <div style={{
      background: bg, color: fg, borderRadius: 16,
      border: border ? `1.5px dashed ${BK.ink}` : 'none',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: display, fontSize: 28, letterSpacing: -0.5, textAlign: 'center', padding: 10,
    }}>{children}</div>
  );
}

// ── 07 — Texture / Filter recipes ──────────────────────────────
function TextureSection() {
  return (
    <section>
      <SectionHead no="07 · texture" anchor="texture" title="Texture & filters."
        kicker="The signature roughness comes from four SVG filter recipes. Copy these into any artwork — they make NOBS feel drawn, not designed." />

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
        {[
          { id: 'stamp',  label: 'Stamp',   note: 'rubber-stamp bleed',  baseFreq: 0.18, scale: 1.6, blur: 0.4, seed: 20 },
          { id: 'marker', label: 'Marker',  note: 'wobbly thick lines',  baseFreq: 0.05, scale: 2.2, blur: 0,   seed: 21 },
          { id: 'pencil', label: 'Pencil',  note: 'light scratchy edge', baseFreq: 0.30, scale: 0.6, blur: 0,   seed: 23 },
          { id: 'copy',   label: 'Photocopy', note: 'subtle roughen',    baseFreq: 0.12, scale: 0.9, blur: 0,   seed: 25 },
        ].map(r => (
          <Tile key={r.id} height={260}>
            <CenteredLabel title={r.label} note={r.note}/>
            <svg viewBox="0 0 320 240" width="100%" height="100%">
              <defs>
                <filter id={`tx-${r.id}`} x="-10%" y="-10%" width="120%" height="120%">
                  <feTurbulence type="fractalNoise" baseFrequency={r.baseFreq} numOctaves="2" seed={r.seed}/>
                  <feDisplacementMap in="SourceGraphic" scale={r.scale}/>
                  {r.blur > 0 && <feGaussianBlur stdDeviation={r.blur}/>}
                </filter>
              </defs>
              <g filter={`url(#tx-${r.id})`}>
                <text x="160" y="155" textAnchor="middle" fontFamily={display} fontSize="120" fill={BK.ink} letterSpacing="-3">NOBS</text>
              </g>
              <text x="160" y="208" textAnchor="middle" fontFamily={mono} fontSize="9" fill={BK.ink2} letterSpacing="0.8">
                baseFreq {r.baseFreq} · scale {r.scale}
              </text>
            </svg>
          </Tile>
        ))}
      </div>

      <pre style={{
        marginTop: 16, background: BK.ink, color: BK.cream, padding: 24, borderRadius: 14,
        fontFamily: mono, fontSize: 12, lineHeight: '20px', overflow: 'auto',
      }}>{`<filter id="stamp">
  <feTurbulence type="fractalNoise" baseFrequency="0.18" numOctaves="2" seed="20"/>
  <feDisplacementMap in="SourceGraphic" scale="1.6"/>
  <feGaussianBlur stdDeviation="0.4"/>
</filter>

// Reach for stamp on solid shapes (icon backs, frames).
// Reach for marker on outlined strokes & wordmarks at small/medium size.
// Pencil for handwritten accents (checkmarks, underlines).
// Photocopy for typewriter type (Special Elite, mono captions).`}</pre>
    </section>
  );
}

// ── 08 — Voice & copy patterns ─────────────────────────────────
function VoiceSection() {
  return (
    <section>
      <SectionHead no="08 · voice" anchor="voice" title="How it talks."
        kicker="Plain, short, and slightly dry. Address the user, not the room. Never use marketing words about how 'powerful' it is. Show, don't promise." />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 24 }}>
        <ValueCard tone="say">
          <li>"Saved. Only on this device."</li>
          <li>"I won't remember unless you ask me to."</li>
          <li>"Your network is offline. I'll keep working."</li>
          <li>"Done. No copies."</li>
          <li>"Tap any memory to make me forget it."</li>
        </ValueCard>
        <ValueCard tone="don't">
          <li>"Unlock your AI-powered future."</li>
          <li>"Our cutting-edge model leverages…"</li>
          <li>"Don't worry — it's totally secure!"</li>
          <li>"Sync with the cloud for the best experience."</li>
          <li>"By continuing, you agree to share usage data."</li>
        </ValueCard>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
        <Principle title="Lowercase the brand." body="When NOBS speaks, it doesn't shout its name. Reserve all-caps NOBS for marks, headlines and signage. In sentences, treat it as a name: 'I am NOBS.' not 'I AM NOBS.'" />
        <Principle title="Use contractions." body="'I won't.' 'You're.' 'It's.' Contractions are how real people talk; NOBS talks like a real person." />
        <Principle title="Name the thing." body="If it's encrypted, say so. If it's offline, say so. Avoid hedging words like 'may', 'might', 'could potentially'. Specificity is the brand." />
      </div>

      <div style={{ marginTop: 24, background: BK.ink, color: BK.cream, borderRadius: 14, padding: 28 }}>
        <Meta style={{ color: 'rgba(245,241,234,0.55)', marginBottom: 14 }}>tagline bank · pick one</Meta>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10,
                      fontFamily: sans, fontSize: 20, lineHeight: '28px', fontWeight: 500 }}>
          <div>· No cloud. No compromise.</div>
          <div>· Your AI. Your house.</div>
          <div>· A private AI, est. on your LAN.</div>
          <div>· Local first. Always was.</div>
          <div>· It remembers. You decide what.</div>
          <div>· The smart parts. None of the surveillance.</div>
        </div>
      </div>
    </section>
  );
}

function ValueCard({ tone, children }) {
  const isDo = tone === 'say';
  return (
    <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <div style={{ width: 28, height: 28, borderRadius: 999, background: isDo ? BK.sage : BK.rose,
                       display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          {isDo ? <Icon name="check" size={16} color="#fff" strokeWidth={3}/> : <Icon name="close" size={16} color="#fff" strokeWidth={3}/>}
        </div>
        <Meta>{isDo ? 'say this' : "don't say this"}</Meta>
      </div>
      <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 10,
                   fontFamily: sans, fontSize: 17, color: BK.ink, lineHeight: '24px' }}>
        {children}
      </ul>
    </div>
  );
}

function Principle({ title, body }) {
  return (
    <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 22 }}>
      <div style={{ fontFamily: sans, fontSize: 18, fontWeight: 700, color: BK.ink, marginBottom: 8 }}>{title}</div>
      <div style={{ fontFamily: sans, fontSize: 14, color: BK.ink2, lineHeight: '21px', textWrap: 'pretty' }}>{body}</div>
    </div>
  );
}

// ── 09 — Component callouts ────────────────────────────────────
function ComponentsSection() {
  return (
    <section>
      <SectionHead no="09 · components" anchor="components" title="UI primitives."
        kicker="These are the production patterns. Re-use them; do not invent new ones for the same job. Full source lives in nobs-components.jsx." />

      {/* Buttons */}
      <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 28, marginBottom: 16 }}>
        <Meta style={{ marginBottom: 18 }}>buttons</Meta>
        <div style={{ display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <button style={btn(BK.amber, '#fff')}>Continue</button>
          <button style={btn(BK.sage, '#fff')}>Mark done</button>
          <button style={btn('transparent', BK.amber, BK.amber)}>Add memory</button>
          <button style={btn(BK.ink, BK.cream)}>Open NOBS</button>
          <button style={btn(BK.rose, '#fff')}>Delete forever</button>
          <button style={btn('rgba(60,40,20,0.06)', BK.ink)}>Cancel</button>
        </div>
        <div style={{ marginTop: 18, fontFamily: mono, fontSize: 11, color: BK.ink2 }}>
          height 48 · radius 24 · SF Pro Rounded 17/22 weight 600 · min hit target 44pt
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        {/* Memory card */}
        <div style={{ background: BK.paper, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 28 }}>
          <Meta style={{ marginBottom: 18 }}>memory card</Meta>
          <div style={{ background: '#fff', borderRadius: 22, padding: 18,
                        boxShadow: '0 1px 2px rgba(60,40,20,0.04), 0 4px 16px rgba(60,40,20,0.06)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <span style={{ ...TYPE.caption, color: BK.amber, background: 'rgba(217,119,6,0.10)',
                              padding: '3px 10px', borderRadius: 999, fontWeight: 700 }}>Personal</span>
              <div style={{ flex: 1 }}/>
              <div style={{ ...TYPE.footnote, color: '#A8A29E' }}>2h ago</div>
            </div>
            <div style={{ ...TYPE.body, color: BK.ink, fontFamily: sans }}>
              Mum's bookshop closes early on Thursdays.
            </div>
          </div>
          <div style={{ marginTop: 14, fontFamily: mono, fontSize: 11, color: BK.ink2 }}>
            radius 22 · shadow 0 1 2 + 0 4 16 · warm tint · tag chip = brand color × tint
          </div>
        </div>

        {/* Task row */}
        <div style={{ background: BK.paper, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 28 }}>
          <Meta style={{ marginBottom: 18 }}>task row · checkbox states</Meta>
          <div style={{ background: '#fff', borderRadius: 18, overflow: 'hidden' }}>
            {[
              { title: 'Pick up keys from front desk', done: false },
              { title: 'Reply to Sam re: Friday',     done: false },
              { title: 'Q3 plan — draft outline',     done: true  },
            ].map((t, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 14,
                                      padding: '14px 16px', borderBottom: i<2 ? '1px solid rgba(60,40,20,0.06)' : 'none' }}>
                <div style={{ width: 24, height: 24, borderRadius: 12, flexShrink: 0,
                              border: t.done ? 'none' : '2px solid #D1C8BC',
                              background: t.done ? BK.sage : 'transparent',
                              display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: 1 }}>
                  {t.done && <Icon name="check" size={14} color="#fff" strokeWidth={3}/>}
                </div>
                <div style={{ ...TYPE.body, color: t.done ? '#A8A29E' : BK.ink,
                              textDecoration: t.done ? 'line-through' : 'none', fontFamily: sans }}>{t.title}</div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 14, fontFamily: mono, fontSize: 11, color: BK.ink2 }}>
            circle 24 · stroke 2 · sage fill on done · strikethrough text
          </div>
        </div>
      </div>

      {/* Switches + segmented + tab bar */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1.2fr', gap: 16 }}>
        <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 24 }}>
          <Meta style={{ marginBottom: 18 }}>switch</Meta>
          <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
            <Switch on/>
            <Switch />
            <Switch on color={BK.sage}/>
          </div>
        </div>

        <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 24 }}>
          <Meta style={{ marginBottom: 18 }}>segmented · pill</Meta>
          <div style={{ display: 'inline-flex', padding: 3, gap: 2, background: 'rgba(60,40,20,0.05)', borderRadius: 999 }}>
            <button style={segBtn(true)}>Personal</button>
            <button style={segBtn(false)}>Work</button>
          </div>
        </div>

        <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 24 }}>
          <Meta style={{ marginBottom: 18 }}>tab bar</Meta>
          <div style={{ display: 'flex', gap: 8, padding: '10px 12px', background: BK.cream, borderRadius: 18,
                        border: '1px solid rgba(60,40,20,0.06)' }}>
            {[
              { n: 'memory', l: 'Memories', a: true },
              { n: 'tasks',  l: 'Tasks' },
              { n: 'more',   l: 'More' },
              { n: 'settings', l: 'Settings' },
            ].map((t,i)=>(
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                <Icon name={t.n} size={22} color={t.a ? BK.amber : '#A8A29E'}/>
                <span style={{ fontFamily: sans, fontSize: 10, fontWeight: 600, color: t.a ? BK.amber : '#A8A29E' }}>{t.l}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function btn(bg, fg, border) {
  return {
    background: bg, color: fg, fontFamily: sans, fontSize: 17, fontWeight: 600,
    border: border ? `1.5px solid ${border}` : 'none',
    padding: '12px 22px', borderRadius: 24, cursor: 'pointer', letterSpacing: -0.1,
  };
}
function segBtn(active) {
  return {
    border: 'none', padding: '8px 18px', borderRadius: 999, cursor: 'pointer',
    background: active ? '#fff' : 'transparent',
    boxShadow: active ? '0 1px 3px rgba(60,40,20,0.08)' : 'none',
    color: active ? BK.ink : '#57534E', fontFamily: sans, fontSize: 15,
    fontWeight: active ? 600 : 500,
  };
}
function Switch({ on, color }) {
  const c = color || BK.amber;
  return (
    <div style={{ width: 52, height: 32, borderRadius: 16, padding: 3,
                  background: on ? c : '#D1C8BC', display: 'flex',
                  justifyContent: on ? 'flex-end' : 'flex-start', transition: 'all .15s' }}>
      <div style={{ width: 26, height: 26, borderRadius: 13, background: '#fff',
                     boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }}/>
    </div>
  );
}

// ── 10 — Machine-readable spec ─────────────────────────────────
function SpecSection() {
  const tokens = {
    name: 'NOBS',
    version: '1.0.0',
    tagline: 'Your private AI. No cloud. No compromise.',
    voice: {
      tone: ['warm', 'blunt', 'specific', 'dry'],
      avoid: ['marketing-speak', 'hedging', 'cloud-positive language', 'all-caps in sentences'],
      preferContractions: true,
      preferActiveVoice: true,
    },
    color: {
      brand: {
        amber:     '#D97706',
        amberDeep: '#B35914',
        amberSoft: '#F59E0B',
        sage:      '#65A36E',
        sageDeep:  '#3F7E47',
        rose:      '#C75D5D',
        blue:      '#5680A8',
      },
      light: {
        bg:'#FAF8F5', surface:'#FFFFFF', surfaceAlt:'#F2EEE7',
        text:'#1C1917', textSecondary:'#57534E', textTertiary:'#A8A29E',
        border:'rgba(60,40,20,0.08)', divider:'rgba(60,40,20,0.06)',
      },
      dark: {
        bg:'#1C1917', surface:'#28231F', surfaceAlt:'#221E1A',
        text:'#F5F1EA', textSecondary:'#A8A29E', textTertiary:'#78716C',
        border:'rgba(255,240,220,0.07)', divider:'rgba(255,240,220,0.05)',
      },
    },
    type: {
      display: { family: 'Archivo Black', use: 'wordmark only' },
      ui:      { family: 'SF Pro Rounded', fallback: 'Nunito, system-ui, sans-serif' },
      mono:    { family: 'JetBrains Mono', fallback: 'SF Mono, Menlo, monospace' },
      scale: {
        largeTitle:{size:34,weight:700,letterSpacing:-0.6},
        title1:{size:28,weight:700,letterSpacing:-0.4},
        title2:{size:22,weight:700,letterSpacing:-0.3},
        title3:{size:20,weight:600,letterSpacing:-0.2},
        headline:{size:17,weight:600},
        body:{size:17,weight:400},
        callout:{size:16,weight:400},
        subhead:{size:15,weight:500},
        footnote:{size:13,weight:500},
        caption:{size:12,weight:500},
        overline:{size:11,weight:700,letterSpacing:1.2,uppercase:true},
      },
    },
    radius: { sm:8, md:12, lg:16, xl:18, '2xl':22, '3xl':28, pill:9999 },
    spacing4pt: [4,8,12,16,20,24,32,40,48,64],
    shadow: {
      light: '0 1px 2px rgba(60,40,20,0.04), 0 4px 16px rgba(60,40,20,0.06)',
      dark:  '0 1px 2px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3)',
    },
    texture: {
      stamp:    { baseFrequency:0.18, numOctaves:2, displacementScale:1.6,  blur:0.4 },
      marker:   { baseFrequency:0.05, numOctaves:2, displacementScale:2.2 },
      pencil:   { baseFrequency:0.30, numOctaves:3, displacementScale:0.6 },
      photocopy:{ baseFrequency:0.12, numOctaves:2, displacementScale:0.9 },
    },
    logoRules: {
      clearSpace: '1 × cap-height of N',
      minimumSize: { icon: '24px', wordmark: '88px wide' },
      doNot: ['stretch','outline','recolor outside palette','add gradient','place on busy photo','rotate >5°'],
    },
  };
  const j = JSON.stringify(tokens, null, 2);
  return (
    <section>
      <SectionHead no="10 · spec" anchor="spec" title="Machine spec."
        kicker="The whole brand as one JSON blob. Paste into a system prompt, a token file, or a build script. If the AI only reads one section of this document, this is the one." />

      <div style={{ background: BK.ink, color: BK.cream, borderRadius: 14, padding: 0, overflow: 'hidden' }}>
        <div style={{ background: '#0e0c0a', padding: '12px 22px', display: 'flex', justifyContent: 'space-between',
                      borderBottom: '1px solid rgba(255,240,220,0.08)' }}>
          <Meta style={{ color: 'rgba(245,241,234,0.55)' }}>nobs.brand.json</Meta>
          <Meta style={{ color: 'rgba(245,241,234,0.4)' }}>v1.0 · {Math.ceil(j.length/1024)} kb</Meta>
        </div>
        <pre style={{ margin: 0, padding: 24, fontFamily: mono, fontSize: 12, lineHeight: '19px',
                       overflow: 'auto', maxHeight: 520 }}>{j}</pre>
      </div>

      {/* Asset checklist */}
      <div style={{ marginTop: 32 }}>
        <Meta style={{ marginBottom: 12 }}>asset checklist · what ships with the brand</Meta>
        <div style={{ background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14, padding: 24 }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '8px 32px' }}>
            {[
              ['Wordmark · light SVG',          'NOBS-wordmark-light.svg'],
              ['Wordmark · dark SVG',           'NOBS-wordmark-dark.svg'],
              ['App icon · 1024 PNG',           'NOBS-icon-1024.png'],
              ['App icon · 180 / 120 / 80 / 40','NOBS-icon-@iOS.zip'],
              ['Monogram · square SVG',         'NOBS-mark.svg'],
              ['Stacked lockup · SVG',          'NOBS-lockup-stacked.svg'],
              ['Horizontal lockup · SVG',       'NOBS-lockup-h.svg'],
              ['Color tokens (JSON)',           'nobs.tokens.json'],
              ['SwiftUI theme',                  'NOBSTheme.swift'],
              ['Tailwind preset',                'nobs.tw.config.ts'],
              ['Icon set · 24px line',          'nobs-icons.svg'],
              ['Filter recipes · 4 SVG defs',   'nobs-textures.svg'],
              ['OG card template · 1200×630',   'og-card.svg'],
              ['Story template · 1080×1920',    'story.svg'],
              ['Voice & copy patterns',          'nobs-voice.md'],
              ['This brand book',                'NOBS Brand Kit.html'],
            ].map(([label, file], i) => (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between',
                                      borderBottom: `1px solid ${BK.ruleSoft}`, padding: '8px 0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: sans, fontSize: 14, color: BK.ink }}>
                  <div style={{ width: 14, height: 14, borderRadius: 4, border: `1.5px solid ${BK.ink2}` }}/>
                  {label}
                </div>
                <div style={{ fontFamily: mono, fontSize: 11, color: BK.ink2 }}>{file}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Colophon */}
      <div style={{ marginTop: 64, padding: '32px 0',
                    borderTop: `1px solid ${BK.ink}`, display: 'flex',
                    justifyContent: 'space-between', alignItems: 'baseline' }}>
        <div>
          <div style={{ fontFamily: display, fontSize: 28, color: BK.ink, letterSpacing: -0.5 }}>NOBS.</div>
          <Meta style={{ marginTop: 4 }}>brand kit · ed. 01 · may 2026</Meta>
        </div>
        <Meta style={{ color: BK.ink3 }}>set in archivo black, sf pro rounded & jetbrains mono</Meta>
      </div>
    </section>
  );
}

Object.assign(window, {
  BannersSection, TextureSection, VoiceSection, ComponentsSection, SpecSection,
});
