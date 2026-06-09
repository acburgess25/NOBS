// brand-assets.jsx — gallery page sections, styled to match brand-kit.jsx exactly.
// Depends on globals from brand-kit.jsx: BK, mono, sans, display, Meta, Tile,
// CenteredLabel, SectionHead.

const ASSET_FILES = [
  // [group, file, label, dim, bgKind]
  // bgKind: 'paper' | 'cream' | 'ink' | 'amber' — controls tile preview background.
  ['icon', 'assets/icon/nobs-mark-2048.png',  'app mark',  '2048 × 2048', 'ink'],
  ['icon', 'assets/icon/nobs-mark-1024.png',  'app mark',  '1024 × 1024', 'ink'],
  ['icon', 'assets/favicon/apple-touch-icon.png', 'touch icon', '180 × 180', 'ink'],
  ['icon', 'assets/favicon/favicon.ico', 'favicon', 'ico multi-size', 'ink'],

  ['wordmark', 'assets/wordmark/nobs-wordmark-modern-light.svg', 'light svg', '340 × 128', 'ink'],
  ['wordmark', 'assets/wordmark/nobs-wordmark-modern-dark.svg',  'dark svg',  '340 × 128', 'paper'],
  ['wordmark', 'assets/wordmark/nobs-wordmark-light-4096.png', 'light png', '12288 × 4096', 'ink'],
  ['wordmark', 'assets/wordmark/nobs-wordmark-dark-4096.png',  'dark png',  '12288 × 4096', 'paper'],

  ['lockup', 'assets/lockup/nobs-lockup-modern-horizontal.svg', 'horizontal svg', '560 × 128', 'paper'],
  ['lockup', 'assets/lockup/nobs-lockup-light-2200x620.png',   'light png',      '2200 × 620', 'paper'],
  ['lockup', 'assets/lockup/nobs-lockup-dark-2200x620.png',    'dark png',       '2200 × 620', 'ink'],

  ['banner', 'assets/banner/nobs-og-card-1200x630.png',          'og card',       '1200 × 630',  'ink'],
  ['banner', 'assets/banner/nobs-profile-header-1500x500.png',   'profile header','1500 × 500',  'ink'],
  ['banner', 'assets/banner/nobs-linkedin-banner-1584x396.png',  'linkedin',      '1584 × 396',  'ink'],
  ['banner', 'assets/banner/nobs-youtube-banner-2560x1440.png',  'youtube',       '2560 × 1440', 'ink'],
  ['banner', 'assets/banner/nobs-square-post-1080x1080.png',     'square post',   '1080 × 1080', 'ink'],
  ['banner', 'assets/banner/nobs-story-1080x1920.png',           'story',         '1080 × 1920', 'ink'],
  ['banner', 'assets/banner/nobs-app-store-feature-4320x2160.png', 'feature',     '4320 × 2160', 'ink'],
  ['banner', 'assets/banner/nobs-desktop-wallpaper-3840x2160.png','wallpaper',    '3840 × 2160', 'ink'],

  ['palette', 'assets/palette/nobs-modern-palette.png', 'palette', 'modern identity', 'paper'],
];

// Pick background for a tile based on its bgKind and user's tweak.
function tileBg(kind, surfaceMode) {
  // surfaceMode: 'native' (use kind) | 'paper' | 'cream' | 'ink' | 'amber'
  const k = surfaceMode === 'native' ? kind : surfaceMode;
  if (k === 'ink')   return BK.ink;
  if (k === 'cream') return BK.cream;
  if (k === 'amber') return BK.amberDeep;
  return BK.paper;
}

function AssetTile({ row, t, height, aspect }) {
  const [, file, label, dim, kind] = row;
  const bg = tileBg(kind, t.surface);
  const name = file.split('/').pop();
  // Center the SVG inside the tile, contained.
  return (
    <a href={file} target="_blank" rel="noopener" style={{ display: 'block', textDecoration: 'none' }}>
      <Tile height={height} background={bg}>
        {t.labels && <CenteredLabel title={label} note={dim} dark={kind === 'ink' && t.surface === 'native'} />}
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: t.padding,
        }}>
          <img src={file} alt={name} style={{
            maxWidth: '100%', maxHeight: '100%', display: 'block',
            filter: t.grain ? 'contrast(1.02) saturate(0.98)' : 'none',
          }}/>
          {t.grain && <GrainOverlay/>}
        </div>
        {t.filenames && (
          <div style={{
            position: 'absolute', left: 14, right: 14, bottom: 12,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10,
            fontFamily: mono, fontSize: 10, color:
              (kind === 'ink' && t.surface === 'native') ? 'rgba(245,241,234,0.6)' : BK.ink2,
            letterSpacing: 0.4,
          }}>
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{name}</span>
            <span style={{ flexShrink: 0, opacity: 0.65 }}>open ↗</span>
          </div>
        )}
      </Tile>
    </a>
  );
}

function GrainOverlay() {
  return (
    <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none', mixBlendMode: 'multiply', opacity: 0.35 }}
         width="100%" height="100%" preserveAspectRatio="none">
      <defs>
        <filter id="ga-grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/>
          <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.08 0"/>
        </filter>
      </defs>
      <rect width="100%" height="100%" filter="url(#ga-grain)"/>
    </svg>
  );
}

// ── Cover ──────────────────────────────────────────────────────
function AssetsCover({ t }) {
  return (
    <section style={{ paddingTop: 24 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 32, marginBottom: 24 }}>
        <Meta>NOBS / assets / modern wordmark — jun 2026</Meta>
        <Meta style={{ textAlign: 'right' }}>svg · png · ico · banners</Meta>
      </div>

      <div style={{ position: 'relative', background: BK.cream, borderRadius: 22, overflow: 'hidden',
                    border: `1px solid ${BK.rule}`, padding: '64px 56px 48px', minHeight: 460 }}>
        <CornerMarks/>
        <Meta style={{ position: 'absolute', top: 28, left: 32 }}>filed under · assets</Meta>
        <Meta style={{ position: 'absolute', top: 28, right: 32 }}>nobs.local · ed. 01</Meta>

        <div style={{ display: 'flex', alignItems: 'center', gap: 32, marginTop: 8 }}>
          <div style={{ flexShrink: 0 }}>
            <NobsIcon size={148} uid="ax-cover"/>
          </div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontFamily: display, fontSize: 160, lineHeight: 0.88, letterSpacing: -6, color: BK.ink }}>
              ASSETS.
            </div>
            <div style={{ fontFamily: sans, fontSize: 22, lineHeight: '30px', color: BK.ink2, marginTop: 6, maxWidth: 640 }}>
              Every logo, mark, lockup and banner — ready to drop into product, social, App Store,
              launch posts, profile headers, and decks.
            </div>
          </div>
        </div>

        <div style={{ marginTop: 36, display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12,
                       paddingTop: 24, borderTop: `1px solid ${BK.rule}` }}>
          {[
            ['ICONS',     '7'],
            ['WORDMARKS', '4'],
            ['LOCKUPS',   '4'],
            ['BANNERS',   '5'],
            ['+ palette', '+ JSON spec'],
          ].map(([k, v], i) => (
            <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <Meta>{k}</Meta>
              <div style={{ fontFamily: display, fontSize: 40, lineHeight: 1, color: BK.ink, letterSpacing: -1 }}>{v}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function CornerMarks() {
  const m = { stroke: BK.ink2, strokeWidth: 1, opacity: 0.35, fill: 'none' };
  const Cross = ({ x, y }) => (
    <g {...m} transform={`translate(${x} ${y})`}>
      <path d="M 0 -10 L 0 10 M -10 0 L 10 0"/>
      <circle cx="0" cy="0" r="6"/>
    </g>
  );
  return (
    <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} width="100%" height="100%"
         preserveAspectRatio="none" viewBox="0 0 1000 500">
      <Cross x="22" y="22"/><Cross x="978" y="22"/>
      <Cross x="22" y="478"/><Cross x="978" y="478"/>
    </svg>
  );
}

// ── Sections ────────────────────────────────────────────────────
function AssetsIconsSection({ t }) {
  const rows = ASSET_FILES.filter(r => r[0] === 'icon');
  const h = t.density === 'compact' ? 220 : t.density === 'comfy' ? 320 : 260;
  return (
    <section>
      <SectionHead no="01 · app icons" anchor="icons" title="Icon."
        kicker="Square mark — amber by default, with sage / ink / cream variants. Three accent options under the N: underline (default), tick, dot, or bare. 320×320 viewBox; renders crisply at any size from 24px to 1024px." />
      <div style={{ display: 'grid', gridTemplateColumns: `repeat(${t.cols}, 1fr)`, gap: 16 }}>
        {rows.map((row, i) => <AssetTile key={i} row={row} t={t} height={h}/>)}
      </div>
    </section>
  );
}

function AssetsWordmarksSection({ t }) {
  const rows = ASSET_FILES.filter(r => r[0] === 'wordmark');
  const h = t.density === 'compact' ? 200 : t.density === 'comfy' ? 320 : 260;
  return (
    <section>
      <SectionHead no="02 · wordmarks" anchor="wordmarks" title="Wordmark."
        kicker={<>Archivo Black, displaced through fractal noise so it always reads as drawn, never as a font. Light, dark, on-amber, and a clean transparent-background version without the tagline.</>} />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
        {rows.map((row, i) => <AssetTile key={i} row={row} t={t} height={h}/>)}
      </div>
    </section>
  );
}

function AssetsLockupsSection({ t }) {
  const rows = ASSET_FILES.filter(r => r[0] === 'lockup');
  return (
    <section>
      <SectionHead no="03 · lockups" anchor="lockups" title="Lockup."
        kicker="Icon + wordmark together. Horizontal for headers and email signatures, stacked for hero / centered use. Each in light and dark." />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16, marginBottom: 16 }}>
        {rows.slice(0,2).map((row, i) => <AssetTile key={i} row={row} t={t} height={240}/>)}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
        {rows.slice(2).map((row, i) => <AssetTile key={i} row={row} t={t} height={320}/>)}
      </div>
    </section>
  );
}

function AssetsBannersSection({ t }) {
  const rows = ASSET_FILES.filter(r => r[0] === 'banner');
  // Each banner uses its native aspect ratio. Wrap each tile in a sized grid cell.
  return (
    <section>
      <SectionHead no="04 · banners" anchor="banners" title="Banners."
        kicker="Five social and print templates at native dimensions. Replace the line, never the layout — the geometry is part of the brand." />
      {/* OG card — full width */}
      <div style={{ marginBottom: 16 }}>
        <BannerSlot row={rows[0]} t={t} aspect="1200 / 630"/>
      </div>
      {/* Profile header — full width */}
      <div style={{ marginBottom: 16 }}>
        <BannerSlot row={rows[1]} t={t} aspect="1500 / 500"/>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
        <BannerSlot row={rows[2]} t={t} aspect="1 / 1"/>
        <BannerSlot row={rows[3]} t={t} aspect="9 / 16"/>
        <BannerSlot row={rows[4]} t={t} aspect="1 / 1"/>
      </div>
    </section>
  );
}

function BannerSlot({ row, t, aspect }) {
  const [, file, label, dim, kind] = row;
  const bg = tileBg(kind, t.surface);
  const name = file.split('/').pop();
  return (
    <a href={file} target="_blank" rel="noopener" style={{ display: 'block', textDecoration: 'none' }}>
      <div style={{
        background: BK.card, border: `1px solid ${BK.rule}`, borderRadius: 14,
        padding: 18, position: 'relative',
      }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Meta>{label}</Meta>
          <Meta style={{ color: BK.ink3 }}>{dim}</Meta>
        </div>
        <div style={{
          aspectRatio: aspect, background: bg, borderRadius: 8, overflow: 'hidden',
          boxShadow: 'inset 0 0 0 1px rgba(60,40,20,0.08)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative',
        }}>
          <img src={file} alt={name} style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}/>
          {t.grain && <GrainOverlay/>}
        </div>
        {t.filenames && (
          <div style={{
            marginTop: 10,
            fontFamily: mono, fontSize: 11, color: BK.ink2, letterSpacing: 0.4,
            display: 'flex', justifyContent: 'space-between', gap: 10,
          }}>
            <span>{name}</span><span style={{ opacity: 0.65 }}>open ↗</span>
          </div>
        )}
      </div>
    </a>
  );
}

function AssetsTokensSection({ t }) {
  const palette = ASSET_FILES.find(r => r[0] === 'palette');
  return (
    <section>
      <SectionHead no="05 · tokens" anchor="tokens" title="Tokens."
        kicker="Visual swatch sheet, plus a machine-readable JSON of the entire brand — colors, type, radii, texture parameters, voice rules. Paste the JSON into a system prompt or build script." />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <AssetTile row={palette} t={t} height={320}/>
        <a href="assets/nobs.brand.json" target="_blank" rel="noopener" style={{ textDecoration: 'none' }}>
          <Tile height={320} background={BK.ink}>
            <CenteredLabel title="brand spec" note="json · machine-readable" dark/>
            <pre style={{
              position: 'absolute', inset: 0, padding: '52px 22px 36px', margin: 0,
              color: BK.cream, fontFamily: mono, fontSize: 11.5, lineHeight: '18px',
              overflow: 'hidden', whiteSpace: 'pre',
            }}>{`{
  "name": "NOBS",
  "version": "1.0.0",
  "tagline": "Your private AI...",
  "color": {
    "brand": { "amber": "#D97706", … },
    "light": { "bg":    "#FAF8F5", … },
    "dark":  { "bg":    "#1C1917", … }
  },
  "type":    { "display": "Archivo Black", … },
  "radius":  { "sm": 8, "md": 12, … },
  "texture": { "stamp": {…}, "marker": {…}, … },
  "voice":   { "tone": ["warm","blunt", … ] }
}`}</pre>
            <div style={{
              position: 'absolute', left: 22, right: 22, bottom: 14,
              display: 'flex', justifyContent: 'space-between',
              fontFamily: mono, fontSize: 10.5, color: 'rgba(245,241,234,0.55)', letterSpacing: 0.4,
            }}>
              <span>nobs.brand.json</span><span>open ↗</span>
            </div>
          </Tile>
        </a>
      </div>
    </section>
  );
}

function AssetsFooter() {
  return (
    <div style={{ marginTop: 80, padding: '32px 0',
                  borderTop: `1px solid ${BK.ink}`, display: 'flex',
                  justifyContent: 'space-between', alignItems: 'baseline' }}>
      <div>
        <div style={{ fontFamily: display, fontSize: 28, color: BK.ink, letterSpacing: -0.5 }}>NOBS.</div>
        <Meta style={{ marginTop: 4 }}>assets · v1.0 · 23 files</Meta>
      </div>
      <Meta style={{ color: BK.ink3 }}>all SVGs · scalable to any size · open source within the org</Meta>
    </div>
  );
}

Object.assign(window, {
  AssetsCover, AssetsIconsSection, AssetsWordmarksSection,
  AssetsLockupsSection, AssetsBannersSection, AssetsTokensSection,
  AssetsFooter, ASSET_FILES,
});
