// nobs-spec.jsx — Handoff sheets for Claude Code / SwiftUI

// ── Swift token export ───────────────────────────────────────────
const SWIFT_TOKENS = `// NOBSTheme.swift — generated from the NOBS UI Kit
import SwiftUI

enum NOBSColor {
    // ── Light ────────────────────────────────────────────────
    static let bgLight        = Color(hex: 0xFAF8F5)
    static let surfaceLight   = Color(hex: 0xFFFFFF)
    static let surfaceAltL    = Color(hex: 0xF2EEE7)
    static let textLight      = Color(hex: 0x1C1917)
    static let text2Light     = Color(hex: 0x57534E)
    static let text3Light     = Color(hex: 0xA8A29E)
    static let dividerLight   = Color(red: 60/255, green: 40/255,  blue: 20/255, opacity: 0.06)

    // ── Dark ─────────────────────────────────────────────────
    static let bgDark         = Color(hex: 0x1C1917)
    static let surfaceDark    = Color(hex: 0x28231F)
    static let surfaceAltD    = Color(hex: 0x221E1A)
    static let textDark       = Color(hex: 0xF5F1EA)
    static let text2Dark      = Color(hex: 0xA8A29E)
    static let text3Dark      = Color(hex: 0x78716C)
    static let dividerDark    = Color(red: 255/255, green: 240/255, blue: 220/255, opacity: 0.05)

    // ── Brand (mode-agnostic) ────────────────────────────────
    static let amber          = Color(hex: 0xD97706)
    static let amberDeep      = Color(hex: 0xB45309)
    static let amberSoft      = Color(hex: 0xF59E0B)
    static let sage           = Color(hex: 0x65A36E)
    static let sageDeep       = Color(hex: 0x3F7E47)
    static let rose           = Color(hex: 0xC75D5D)
    static let infoBlue       = Color(hex: 0x5680A8)
}

enum NOBSRadius {
    static let sm:  CGFloat =  8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 18
    static let xl2: CGFloat = 22
    static let xl3: CGFloat = 28
    static let pill: CGFloat = .infinity
}

enum NOBSSpace {
    static let s1: CGFloat =  4
    static let s2: CGFloat =  8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
}

enum NOBSFont {
    // SF Pro Rounded for warmth. Fall back to .rounded design.
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static let largeTitle = rounded(34, weight: .bold)
    static let title1     = rounded(28, weight: .bold)
    static let title2     = rounded(22, weight: .bold)
    static let title3     = rounded(20, weight: .semibold)
    static let headline   = rounded(17, weight: .semibold)
    static let body       = rounded(17)
    static let callout    = rounded(16)
    static let subhead    = rounded(15, weight: .medium)
    static let footnote   = rounded(13, weight: .medium)
    static let caption    = rounded(12, weight: .medium)
}

// Convenience init
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}`;

// ── Tokens artboard ──────────────────────────────────────────────
function SwiftTokensBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  // Code with simple token-tinted highlight using regex spans
  const render = (line) => {
    const tokens = [
      { re: /^(\s*)(\/\/[^\n]*)/,                      cls: ['_','com'] },
      { re: /^(\s*)(import)\s+(\w+)/,                   cls: ['_','kw','typ'] },
      { re: /^(\s*)(enum|struct|extension|static|let|var|func)\s+(\w+)/, cls: ['_','kw','typ'] },
    ];
    return line;
  };
  const COLORS = dark ? {
    bg: '#0F0D0B', text: '#F5F1EA', com: '#78716C', kw: '#F59E0B', typ: '#9DC4A6', num: '#E0BC8A', str: '#D9B884',
  } : {
    bg: '#FFFDF8', text: '#1C1917', com: '#A39A8E', kw: '#B45309', typ: '#3F7E47', num: '#6B7280', str: '#9C4A1A',
  };

  // Manual tokenize per line
  const tokenize = (line) => {
    const out = [];
    // comment
    const ci = line.indexOf('//');
    let code = ci === -1 ? line : line.slice(0, ci);
    const comment = ci === -1 ? '' : line.slice(ci);

    const kws = ['import','enum','struct','extension','static','let','var','func','init','return','case','self'];
    const types = ['Color','CGFloat','Font','UInt32','Double','Bool','Int','String'];
    const re = /([A-Za-z_]\w*|0x[0-9A-Fa-f]+|\d+(?:\.\d+)?|"[^"]*"|\s+|[^A-Za-z0-9_\s])/g;
    let m;
    while ((m = re.exec(code))) {
      const t = m[0];
      if (/^\s+$/.test(t)) out.push([t, 'text']);
      else if (kws.includes(t)) out.push([t, 'kw']);
      else if (types.includes(t)) out.push([t, 'typ']);
      else if (/^0x[0-9A-Fa-f]+$/.test(t)) out.push([t, 'num']);
      else if (/^\d/.test(t)) out.push([t, 'num']);
      else if (/^"/.test(t)) out.push([t, 'str']);
      else out.push([t, 'text']);
    }
    if (comment) out.push([comment, 'com']);
    return out;
  };

  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <SystemTitle dark={dark} sub="Copy this file into your Xcode project. Pair with NOBSTheme().preferredColorScheme to switch modes. All values match the kit pixel-for-pixel.">
        Swift tokens · NOBSTheme.swift
      </SystemTitle>
      <div style={{
        flex: 1, minHeight: 0, background: COLORS.bg, borderRadius: NOBS.r.xl,
        padding: '20px 22px', overflow: 'auto',
        border: dark ? `0.5px solid ${c.border}` : `0.5px solid ${c.divider}`,
        boxShadow: c.shadow,
        fontFamily: NOBS.fontMono, fontSize: 12.5, lineHeight: '20px',
        color: COLORS.text, whiteSpace: 'pre',
      }}>
        {SWIFT_TOKENS.split('\n').map((line, i) => (
          <div key={i} style={{ display: 'flex' }}>
            <span style={{ width: 28, color: dark ? '#3C3631' : '#D6CFC4', textAlign: 'right', marginRight: 14, flexShrink: 0, userSelect: 'none' }}>{i + 1}</span>
            <span>{tokenize(line).map(([t, k], j) => (
              <span key={j} style={{ color: COLORS[k] || COLORS.text }}>{t}</span>
            ))}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Component spec board (anatomy + props) ───────────────────────
function ComponentAnatomyBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;

  const SpecRow = ({ label, value }) => (
    <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 12, padding: '8px 0', borderBottom: `0.5px solid ${c.divider}` }}>
      <div style={{ ...TYPE.footnote, color: c.textTertiary, fontFamily: NOBS.fontMono }}>{label}</div>
      <div style={{ ...TYPE.footnote, color: c.text, fontFamily: NOBS.fontMono }}>{value}</div>
    </div>
  );

  const Block = ({ title, preview, specs }) => (
    <div style={{
      background: c.surface, borderRadius: NOBS.r['2xl'], padding: 24,
      boxShadow: c.shadow, marginBottom: 20,
      border: dark ? `0.5px solid ${c.border}` : 'none',
      display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: 32, alignItems: 'flex-start',
    }}>
      <div>
        <div style={{ ...TYPE.title3, color: c.text, marginBottom: 16 }}>{title}</div>
        <div style={{ background: c.bg, borderRadius: NOBS.r.lg, padding: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 100 }}>
          {preview}
        </div>
      </div>
      <div>
        <div style={{ ...TYPE.overline, color: c.textTertiary, marginBottom: 8 }}>Specs</div>
        {specs.map(([k, v]) => <SpecRow key={k} label={k} value={v} />)}
      </div>
    </div>
  );

  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 48, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub="Anatomy + measurements for the four most-used custom components. Everything else (rows, switches, pills) derives from these.">
        Component anatomy
      </SystemTitle>

      <Block title="Primary button"
        preview={<PrimaryButton dark={dark} icon="send">Save memory</PrimaryButton>}
        specs={[
          ['height',  '56pt (lg) · 48pt (md) · 36pt (sm)'],
          ['radius',  'pill (height / 2)'],
          ['padding', '0 28pt horizontal'],
          ['bg',      '$amber · #D97706'],
          ['shadow',  '0/3/10 amber@35% + 0/1/2 amber@25%'],
          ['typo',    'rounded 17 / .bold · letterSpacing -0.2'],
          ['hit',     '≥ 44pt always'],
        ]}
      />

      <Block title="Memory card"
        preview={<div style={{ width: 280 }}><MemoryCard dark={dark} tag="Personal" date="Just now" pinned body="Sarah likes Ethiopian coffee, no sugar." /></div>}
        specs={[
          ['radius',  '22pt'],
          ['padding', '18pt'],
          ['gap',     '12pt between tag-row and body'],
          ['shadow',  '0/1/2 + 0/4/16 warm @ 6–4%'],
          ['border',  '0.5px warm-tint in dark only'],
          ['tag',     'pill · 12/700 caps · amber|sage tint bg'],
          ['pinned',  'amber pin · top-right · 35° rotation'],
        ]}
      />

      <Block title="Task row"
        preview={<div style={{ width: 280 }}><TaskRow dark={dark} title="Order coffee beans" due="Today" tag="Personal" priority /></div>}
        specs={[
          ['minHeight','52pt (touch target)'],
          ['padding', '14/16 inside list'],
          ['checkbox','24×24 · 2px border @ #D1C8BC / sage fill done'],
          ['anim',    'spring 0.4 / 0.7 on check toggle'],
          ['strike',  'apply on done · text → textTertiary'],
          ['priority','amber flag · 16pt right-aligned'],
        ]}
      />

      <Block title="Tab bar"
        preview={<div style={{ width: 360 }}><TabBar dark={dark} active="memories" /></div>}
        specs={[
          ['height',  '50pt + safe-area inset'],
          ['bg',      'bg @ 90% + backdropBlur(20pt)'],
          ['border',  '0.5px divider on top edge'],
          ['icon',    '24×24 · stroke 1.7 (active 2)'],
          ['tint',    'amber active · textTertiary idle'],
          ['label',   'caption · 700 active / 500 idle'],
        ]}
      />
    </div>
  );
}

// ── README / handoff notes ───────────────────────────────────────
function HandoffBoard({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const Section = ({ title, children }) => (
    <div style={{ marginBottom: 28 }}>
      <div style={{ ...TYPE.title3, color: c.text, marginBottom: 10 }}>{title}</div>
      <div style={{ ...TYPE.body, color: c.textSecondary, textWrap: 'pretty' }}>{children}</div>
    </div>
  );
  const Code = ({ children }) => (
    <span style={{ fontFamily: NOBS.fontMono, fontSize: 14, background: c.surfaceAlt, padding: '2px 6px', borderRadius: 4, color: c.text }}>{children}</span>
  );
  return (
    <div style={{ background: c.bg, color: c.text, fontFamily: NOBS.font, padding: 56, height: '100%', boxSizing: 'border-box', overflow: 'auto' }}>
      <SystemTitle dark={dark} sub="What to know before lifting this kit into SwiftUI. Read top-to-bottom.">
        Handoff notes
      </SystemTitle>

      <Section title="1 · Type stack">
        Use SF Pro Rounded everywhere. In SwiftUI that&rsquo;s <Code>.system(size:, weight:, design: .rounded)</Code>.
        Don&rsquo;t set an explicit font family — the rounded design picks the right face per locale.
        Honor Dynamic Type by using the relative size modifiers (<Code>.title</Code>, <Code>.body</Code>) and matching the weights in <Code>NOBSFont</Code>.
      </Section>

      <Section title="2 · Color modes">
        Every color in the kit has a Light and Dark variant. Wire both via <Code>Color(uiColor:)</Code> with a dynamic provider, or use environment <Code>colorScheme</Code>.
        Amber and Sage are mode-agnostic — they shift slightly perceptually but use the same hex.
        Never use system blue for primary actions; amber is the brand action color.
      </Section>

      <Section title="3 · Radii are big, intentionally">
        Cards live at 22pt, rows at 16pt, buttons & pills at full radius. Avoid 4pt/8pt corners except for inline tags/icon badges (8pt).
        This is the single biggest knob that makes NOBS feel warm rather than utilitarian.
      </Section>

      <Section title="4 · Shadows over separators">
        For grouped content prefer warm soft shadows (see <Code>shadow</Code> / <Code>shadowLg</Code>) instead of 1px hairlines between cards.
        Inside one card, a 0.5px divider between rows is fine. Never use solid 1px lines as group dividers.
      </Section>

      <Section title="5 · Privacy iconography">
        Sage is reserved for &ldquo;done / safe / encrypted&rdquo;. Use it for: completed task checkboxes, encryption indicators, the
        green switch state, &ldquo;Local network only&rdquo;, and the &ldquo;synced&rdquo; light on the avatar.
        Don&rsquo;t use sage as a CTA — that&rsquo;s amber&rsquo;s job.
      </Section>

      <Section title="6 · Composer">
        The compose bar is the single most-touched element. Always at the bottom of Memories and Tasks, above the tab bar, with a 14pt drop shadow.
        Tapping it slides the keyboard up and reveals the AI suggestion chip (see <i>Add Memory</i> screen).
        Mic should support continuous listening; send button enables only when text is non-empty.
      </Section>

      <Section title="7 · Animations">
        Spring everywhere — <Code>.spring(response: 0.4, dampingFraction: 0.75)</Code> is the house spring.
        Checkbox toggle, segmented control thumb, tab switch, and sheet present/dismiss all use it.
        Avoid linear easings; they read as cold.
      </Section>

      <Section title="8 · What&rsquo;s missing on purpose">
        No onboarding for sign-in (NOBS has no cloud account). No notifications permissions screen (handle inline when the user first turns on a reminder).
        No share sheet (export is one-tap from Settings → Data). Keep the surface small — every screen earns its place.
      </Section>
    </div>
  );
}

Object.assign(window, { SwiftTokensBoard, ComponentAnatomyBoard, HandoffBoard });
