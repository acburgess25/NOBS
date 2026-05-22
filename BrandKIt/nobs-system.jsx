// nobs-system.jsx — design system documentation artboards

function SystemTitle({ children, sub, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{ marginBottom: 28 }}>
      <div style={{ ...TYPE.title1, color: c.text, marginBottom: 6 }}>{children}</div>
      {sub && <div style={{ ...TYPE.body, color: c.textSecondary, maxWidth: 540 }}>{sub}</div>}
    </div>
  );
}
function SystemSection({ title, children, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{ marginBottom: 36 }}>
      <div style={{ ...TYPE.overline, color: c.textTertiary, marginBottom: 16 }}>{title}</div>
      {children}
    </div>
  );
}

// ── Color tokens artboard ────────────────────────────────────────
function ColorSystemBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const Swatch = ({ name, color, token, sub, big }) => (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{
        width: '100%', height: big ? 140 : 88,
        background: color, borderRadius: NOBS.r.xl,
        border: dark ? `0.5px solid ${c.border}` : 'none',
        boxShadow: c.shadow, position: 'relative',
      }}>
        {sub && (
          <div style={{
            position: 'absolute', inset: 'auto 12px 10px', ...TYPE.caption,
            color: 'rgba(255,255,255,0.85)', fontFamily: NOBS.fontMono,
          }}>{sub}</div>
        )}
      </div>
      <div>
        <div style={{ ...TYPE.subhead, color: c.text, fontWeight: 600 }}>{name}</div>
        <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono }}>{token}</div>
      </div>
    </div>
  );
  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub="Warm off-whites, deep warm charcoals, amber for action, sage for done. Built on oklch-adjacent hues for consistency across modes.">
        Color
      </SystemTitle>

      <SystemSection title={`Surfaces · ${dark ? 'Dark' : 'Light'}`} dark={dark}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          <Swatch dark={dark} name="Background" token={c.bg} color={c.bg} big sub={c.bg} />
          <Swatch dark={dark} name="Surface"    token={c.surface}    color={c.surface}    big sub={c.surface} />
          <Swatch dark={dark} name="Surface Alt" token={c.surfaceAlt} color={c.surfaceAlt} big sub={c.surfaceAlt} />
          <Swatch dark={dark} name="Divider"    token={c.divider}    color={c.divider}    big />
        </div>
      </SystemSection>

      <SystemSection title="Brand · Amber" dark={dark}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          <Swatch dark={dark} name="Amber"      token="#D97706" color={NOBS.brand.amber}     sub="#D97706" />
          <Swatch dark={dark} name="Amber Soft" token="#F59E0B" color={NOBS.brand.amberSoft} sub="#F59E0B" />
          <Swatch dark={dark} name="Amber Deep" token="#B45309" color={NOBS.brand.amberDeep} sub="#B45309" />
          <Swatch dark={dark} name="Amber Tint" token="10% / 14%" color={dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint} />
        </div>
      </SystemSection>

      <SystemSection title="Brand · Sage & state" dark={dark}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          <Swatch dark={dark} name="Sage"     token="#65A36E" color={NOBS.brand.sage}     sub="#65A36E" />
          <Swatch dark={dark} name="Sage Deep" token="#3F7E47" color={NOBS.brand.sageDeep} sub="#3F7E47" />
          <Swatch dark={dark} name="Rose (Danger)" token="#C75D5D" color={NOBS.brand.rose} sub="#C75D5D" />
          <Swatch dark={dark} name="Blue (Info)" token="#5680A8" color={NOBS.brand.blue} sub="#5680A8" />
        </div>
      </SystemSection>

      <SystemSection title="Text on background" dark={dark}>
        <div style={{
          background: c.surface, borderRadius: NOBS.r['2xl'], padding: 24,
          boxShadow: c.shadow, display: 'flex', flexDirection: 'column', gap: 12,
          border: dark ? `0.5px solid ${c.border}` : 'none',
        }}>
          <div style={{ ...TYPE.title3, color: c.text }}>Primary — for body & titles</div>
          <div style={{ ...TYPE.body, color: c.textSecondary }}>Secondary — supporting copy and metadata</div>
          <div style={{ ...TYPE.subhead, color: c.textTertiary }}>Tertiary — captions, timestamps, hints</div>
          <div style={{ ...TYPE.body, color: NOBS.brand.amber, fontWeight: 600 }}>Amber accent — interactive only</div>
          <div style={{ ...TYPE.body, color: NOBS.brand.sage, fontWeight: 600 }}>Sage accent — completed / safe</div>
        </div>
      </SystemSection>
    </div>
  );
}

// ── Typography artboard ──────────────────────────────────────────
function TypeSystemBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const rows = [
    ['Large Title', 'largeTitle', 'Memories', '34 / 40 · 700'],
    ['Title 1',     'title1',     'Your private AI',  '28 / 34 · 700'],
    ['Title 2',     'title2',     'Encrypted memories', '22 / 28 · 700'],
    ['Title 3',     'title3',     'Privacy & security', '20 / 25 · 600'],
    ['Headline',    'headline',   'Order Sarah\u2019s coffee beans', '17 / 22 · 600'],
    ['Body',        'body',       'Sarah likes single-origin Ethiopian.', '17 / 24 · 400'],
    ['Callout',     'callout',    'Memory captured at 9:41 am', '16 / 22 · 400'],
    ['Subhead',     'subhead',    'Encrypted on your network', '15 / 20 · 500'],
    ['Footnote',    'footnote',   'Today · 4 memories', '13 / 18 · 500'],
    ['Caption',     'caption',    '412 memories synced', '12 / 16 · 500'],
    ['Overline',    'overline',   'EARLIER THIS WEEK', '11 / 14 · 700 · tracked'],
  ];
  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub={`Type stack: ${NOBS.font.split(',')[0]}, with system rounded fallback. All sizes follow the iOS HIG; lineHeight tuned for warm rhythm.`}>
        Type scale
      </SystemTitle>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
        {rows.map(([label, key, sample, spec]) => (
          <div key={key} style={{
            display: 'grid', gridTemplateColumns: '160px 1fr 180px', alignItems: 'baseline', gap: 24,
            paddingBottom: 14, borderBottom: `0.5px solid ${c.divider}`,
          }}>
            <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono }}>{label}</div>
            <div style={{ ...TYPE[key], color: c.text }}>{sample}</div>
            <div style={{ ...TYPE.caption, color: c.textTertiary, fontFamily: NOBS.fontMono, textAlign: 'right' }}>{spec}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Spacing & radii artboard ────────────────────────────────────
function SpacingSystemBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const SpacingRow = ({ name, value }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 20, padding: '12px 0', borderBottom: `0.5px solid ${c.divider}` }}>
      <div style={{ width: 100, ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono }}>{name}</div>
      <div style={{ width: value, height: 14, background: NOBS.brand.amber, borderRadius: 4 }} />
      <div style={{ ...TYPE.subhead, color: c.text }}>{value} pt</div>
    </div>
  );
  const RadiusTile = ({ name, value }) => (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
      <div style={{ width: 96, height: 96, background: c.surface, borderRadius: value, boxShadow: c.shadow, border: dark ? `0.5px solid ${c.border}` : 'none' }} />
      <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono }}>{name} · {value}</div>
    </div>
  );
  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub="A 4pt grid with generous, warm spacing. Radii are intentionally large — 16 to 22pt for cards, full for pills.">
        Spacing & radii
      </SystemTitle>

      <SystemSection title="Spacing scale (4pt grid)" dark={dark}>
        <SpacingRow name="s.1" value={4} />
        <SpacingRow name="s.2" value={8} />
        <SpacingRow name="s.3" value={12} />
        <SpacingRow name="s.4" value={16} />
        <SpacingRow name="s.5" value={20} />
        <SpacingRow name="s.6" value={24} />
        <SpacingRow name="s.7" value={32} />
        <SpacingRow name="s.8" value={40} />
      </SystemSection>

      <SystemSection title="Corner radii" dark={dark}>
        <div style={{ display: 'flex', gap: 32, flexWrap: 'wrap' }}>
          <RadiusTile name="r.sm" value={8} />
          <RadiusTile name="r.md" value={12} />
          <RadiusTile name="r.lg" value={16} />
          <RadiusTile name="r.xl" value={18} />
          <RadiusTile name="r.2xl" value={22} />
          <RadiusTile name="r.3xl" value={28} />
          <RadiusTile name="r.full" value={48} />
        </div>
      </SystemSection>

      <SystemSection title="Shadow elevation" dark={dark}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
          <div style={{ background: c.surface, borderRadius: NOBS.r['2xl'], padding: 24, boxShadow: c.shadow, border: dark ? `0.5px solid ${c.border}` : 'none' }}>
            <div style={{ ...TYPE.headline, color: c.text }}>Elevation 1 · Card</div>
            <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono, marginTop: 4 }}>{dark ? 'shadow / dark' : '0 1px 2px + 0 4px 16px'}</div>
          </div>
          <div style={{ background: c.surface, borderRadius: NOBS.r['2xl'], padding: 24, boxShadow: c.shadowLg, border: dark ? `0.5px solid ${c.border}` : 'none' }}>
            <div style={{ ...TYPE.headline, color: c.text }}>Elevation 2 · Floating</div>
            <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono, marginTop: 4 }}>{dark ? 'shadowLg / dark' : '0 2px 6px + 0 12px 32px'}</div>
          </div>
        </div>
      </SystemSection>
    </div>
  );
}

// ── Components artboard ──────────────────────────────────────────
function ComponentsBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const Group = ({ label, children }) => (
    <div style={{ marginBottom: 32 }}>
      <div style={{ ...TYPE.overline, color: c.textTertiary, marginBottom: 14 }}>{label}</div>
      <div style={{
        background: c.surface, borderRadius: NOBS.r['2xl'], padding: 24, boxShadow: c.shadow,
        border: dark ? `0.5px solid ${c.border}` : 'none',
        display: 'flex', flexDirection: 'column', gap: 18,
      }}>{children}</div>
    </div>
  );
  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub="Every interactive shape in NOBS. Drop these into a SwiftUI implementation 1:1.">
        Components
      </SystemTitle>

      <Group label="Buttons">
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
          <PrimaryButton dark={dark} size="lg">Get Started</PrimaryButton>
          <PrimaryButton dark={dark} size="md" icon="send">Send</PrimaryButton>
          <PrimaryButton dark={dark} size="sm">Add</PrimaryButton>
          <SecondaryButton dark={dark} size="md">Skip</SecondaryButton>
        </div>
      </Group>

      <Group label="Segmented toggle">
        <SegmentedToggle dark={dark} />
        <SegmentedToggle dark={dark} options={['All', 'Personal', 'Work']} value="Work" />
      </Group>

      <Group label="Tag pills">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {['Personal', 'Work'].map((t) => {
            const sage = t === 'Work';
            const color = sage ? NOBS.brand.sage : NOBS.brand.amber;
            const bg = sage ? (dark ? NOBS.brand.sageTintD : NOBS.brand.sageTint) : (dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint);
            return <span key={t} style={{ ...TYPE.caption, color, background: bg, padding: '4px 12px', borderRadius: NOBS.r.full, fontWeight: 700 }}>{t}</span>;
          })}
        </div>
      </Group>

      <Group label="Compose bar">
        <ComposeBar dark={dark} placeholder="Capture a memory…" />
        <ComposeBar dark={dark} value="Mom's pharmacy refill due first week of June" />
      </Group>

      <Group label="Task row">
        <div style={{ background: dark ? c.surfaceAlt : c.bg, borderRadius: NOBS.r.lg, padding: '4px 0' }}>
          <TaskRow dark={dark} title="Order Sarah\u2019s coffee beans" due="Today, 5pm" tag="Personal" priority />
          <div style={{ height: 0.5, background: c.divider, marginLeft: 54 }} />
          <TaskRow dark={dark} title="Pick up dry cleaning" tag="Personal" done />
        </div>
      </Group>

      <Group label="Switches">
        <div style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
          <Switch on dark={dark} />
          <Switch dark={dark} />
        </div>
      </Group>

      <Group label="Tab bar">
        <div style={{ borderRadius: NOBS.r['2xl'], overflow: 'hidden' }}>
          <TabBar dark={dark} active="memories" />
        </div>
      </Group>
    </div>
  );
}

// ── App icon variants ────────────────────────────────────────────
function AppIconBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;

  // Stylized home-screen mockup with NOBS sitting among neighbors
  const HomeMock = () => {
    const wallpaperLight = 'linear-gradient(155deg, #F2D3A8 0%, #D4A574 35%, #B5814C 70%, #8B5A2B 100%)';
    const wallpaperDark  = 'linear-gradient(155deg, #2A1F18 0%, #3D2A1E 50%, #1A1108 100%)';
    const apps = [
      { name: 'Phone',     bg: '#22C55E', glyph: 'phone',    glyphColor: '#fff' },
      { name: 'Messages',  bg: '#22C55E', glyph: 'memory',   glyphColor: '#fff' },
      { name: 'Mail',      bg: '#0EA5E9', glyph: 'send',     glyphColor: '#fff' },
      { name: 'Camera',    bg: '#3F3F46', glyph: 'eye',      glyphColor: '#fff' },
      { name: 'NOBS',      isLogo: true },
      { name: 'Calendar',  bg: '#fff',    glyph: 'calendar', glyphColor: '#EF4444' },
      { name: 'Music',     bg: 'linear-gradient(135deg,#EC4899,#A855F7)', glyph: 'waveform', glyphColor: '#fff' },
      { name: 'Notes',     bg: 'linear-gradient(180deg,#FCD34D,#FBBF24)', glyph: 'edit',     glyphColor: '#9C4A1A' },
      { name: 'Maps',      bg: '#A7F3D0', glyph: 'pin',      glyphColor: '#16A34A' },
    ];
    return (
      <div style={{
        width: 280, height: 480, borderRadius: 32, overflow: 'hidden',
        background: dark ? wallpaperDark : wallpaperLight,
        position: 'relative', boxShadow: '0 20px 50px rgba(0,0,0,0.25), 0 0 0 8px #1c1917',
        padding: '36px 18px 16px',
      }}>
        {/* status */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: '#fff', ...TYPE.footnote, fontWeight: 700, marginBottom: 28 }}>
          <span>9:41</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <svg width="14" height="9" viewBox="0 0 14 9"><rect x="0" y="6" width="2" height="3" rx=".5" fill="#fff"/><rect x="3" y="4" width="2" height="5" rx=".5" fill="#fff"/><rect x="6" y="2" width="2" height="7" rx=".5" fill="#fff"/><rect x="9" y="0" width="2" height="9" rx=".5" fill="#fff"/></svg>
            <svg width="18" height="9" viewBox="0 0 18 9"><rect x="0" y="0.5" width="16" height="8" rx="2" stroke="#fff" strokeOpacity=".5" fill="none"/><rect x="1.5" y="2" width="13" height="5" rx="1" fill="#fff"/></svg>
          </span>
        </div>
        {/* widget — NOBS at-a-glance */}
        <div style={{
          background: 'rgba(255,255,255,0.18)', backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)', borderRadius: 22, padding: 16,
          border: '0.5px solid rgba(255,255,255,0.25)',
          marginBottom: 18, display: 'flex', flexDirection: 'column', gap: 8,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <NobsLogo size={20} />
            <div style={{ ...TYPE.caption, color: '#fff', fontWeight: 700, letterSpacing: 0.5 }}>NOBS</div>
            <div style={{ flex: 1 }} />
            <div style={{ ...TYPE.caption, color: 'rgba(255,255,255,0.7)' }}>3 today</div>
          </div>
          <div style={{ ...TYPE.subhead, color: '#fff', fontWeight: 600, lineHeight: '20px' }}>
            Order Sarah&rsquo;s coffee beans by 5pm
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, ...TYPE.caption, color: 'rgba(255,255,255,0.7)' }}>
            <Icon name="clock" size={11} color="rgba(255,255,255,0.7)" />
            in 3 hours
          </div>
        </div>
        {/* app grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, justifyItems: 'center' }}>
          {apps.map((a, i) => (
            <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, width: 52 }}>
              {a.isLogo ? <NobsLogo size={52} /> : (
                <div style={{ width: 52, height: 52, borderRadius: 12, background: a.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 4px rgba(0,0,0,0.15)' }}>
                  <Icon name={a.glyph} size={26} color={a.glyphColor} strokeWidth={1.8} />
                </div>
              )}
              <div style={{ ...TYPE.caption, color: '#fff', fontWeight: 500, fontSize: 10, lineHeight: '12px' }}>{a.name}</div>
            </div>
          ))}
        </div>
        {/* dock */}
        <div style={{ position: 'absolute', bottom: 14, left: 18, right: 18, height: 72, borderRadius: 24,
          background: 'rgba(255,255,255,0.16)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'space-around', padding: '0 14px',
        }}>
          {[
            { bg: '#22C55E', g: 'phone' },
            { bg: '#0EA5E9', g: 'send' },
            { bg: '#3F3F46', g: 'eye' },
            { bg: '#FF8C42', g: 'memory' },
          ].map((a, i) => (
            <div key={i} style={{ width: 50, height: 50, borderRadius: 11, background: a.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={a.g} size={24} color="#fff" strokeWidth={1.8} />
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub="A rounded square in warm amber, with a leaf mark for &lsquo;quiet, local, growing.&rsquo; The wordmark stands alone for splash and About.">
        App icon &amp; logomark
      </SystemTitle>

      <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: 32, marginBottom: 32, alignItems: 'flex-start' }}>
        <HomeMock />

        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div style={{
            background: c.surface, borderRadius: NOBS.r['2xl'], padding: 32, boxShadow: c.shadow,
            border: dark ? `0.5px solid ${c.border}` : 'none',
            display: 'flex', alignItems: 'center', gap: 28,
          }}>
            <NobsLogo size={140} />
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[180, 120, 80, 56, 36].map((s) => (
                <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  <NobsLogo size={s} />
                  <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono }}>{s}pt</div>
                </div>
              )).slice(1)}
            </div>
          </div>

          <div style={{
            background: c.surface, borderRadius: NOBS.r['2xl'], padding: 28, boxShadow: c.shadow,
            border: dark ? `0.5px solid ${c.border}` : 'none',
          }}>
            <div style={{ ...TYPE.overline, color: c.textTertiary, marginBottom: 14 }}>Wordmark lockup</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
              <NobsLogo size={64} />
              <div>
                <div style={{ ...TYPE.largeTitle, fontSize: 38, lineHeight: '42px', color: c.text }}>NOBS</div>
                <div style={{ ...TYPE.subhead, color: c.textSecondary, marginTop: 2 }}>Your private AI. No cloud. No compromise.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ColorSystemBoard, TypeSystemBoard, SpacingSystemBoard, ComponentsBoard, AppIconBoard });
