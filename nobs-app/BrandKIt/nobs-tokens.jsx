// nobs-tokens.jsx — NOBS design tokens + icon set
// Warm & Human direction. SF Pro Rounded type, amber + sage accents.

const NOBS = {
  // ── Colors ───────────────────────────────────────────────────
  // Light palette: slate grays and clean whites
  light: {
    bg: '#F8FAFC',          // app background
    surface: '#FFFFFF',     // cards
    surfaceAlt: '#F1F5F9',  // sunken / subtle fills
    border: 'rgba(15,23,42,0.08)',
    divider: 'rgba(15,23,42,0.06)',
    text: '#0F172A',        // primary text
    textSecondary: '#64748B',
    textTertiary: '#94A3B8',
    placeholder: '#CBD5E1',
    shadow: '0 1px 2px rgba(15,23,42,0.04), 0 4px 16px rgba(15,23,42,0.06)',
    shadowLg: '0 2px 6px rgba(15,23,42,0.05), 0 12px 32px rgba(15,23,42,0.08)',
  },
  // Dark palette: deep slate
  dark: {
    bg: '#0F172A',
    surface: '#1E293B',
    surfaceAlt: '#1E293B',
    border: 'rgba(248,250,252,0.07)',
    divider: 'rgba(248,250,252,0.05)',
    text: '#F8FAFC',
    textSecondary: '#94A3B8',
    textTertiary: '#64748B',
    placeholder: '#475569',
    shadow: '0 1px 2px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3)',
    shadowLg: '0 2px 6px rgba(0,0,0,0.5), 0 12px 32px rgba(0,0,0,0.4)',
  },
  // Brand accents (same in both modes; alpha-tinted for backgrounds)
  brand: {
    amber:      '#FA5C5C',   // rose pulse
    amberDeep:  '#E11D48',
    amberSoft:  '#FB7185',
    amberTint:  'rgba(250,92,92,0.10)',
    amberTintD: 'rgba(250,92,92,0.14)',
    sage:       '#10B981',   // emerald compliance
    sageDeep:   '#059669',
    sageTint:   'rgba(16,185,129,0.12)',
    sageTintD:  'rgba(16,185,129,0.18)',
    rose:       '#EF4444',   // danger
    roseTint:   'rgba(239,68,68,0.10)',
    blue:       '#0D9488',   // wellness teal
  },

  // ── Type ─────────────────────────────────────────────────────
  font: '"SF Pro Rounded", ui-rounded, "Nunito", -apple-system, BlinkMacSystemFont, system-ui, sans-serif',
  fontMono: '"SF Mono", ui-monospace, "JetBrains Mono", Menlo, monospace',

  // ── Radii ────────────────────────────────────────────────────
  r: { sm: 8, md: 12, lg: 16, xl: 18, '2xl': 22, '3xl': 28, full: 9999 },

  // ── Spacing (4pt grid) ───────────────────────────────────────
  s: { 1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 7: 32, 8: 40, 9: 48, 10: 64 },
};

// Type scale — sizes follow Apple HIG conventions
const TYPE = {
  largeTitle: { fontSize: 34, lineHeight: '40px', fontWeight: 700, letterSpacing: -0.6 },
  title1:     { fontSize: 28, lineHeight: '34px', fontWeight: 700, letterSpacing: -0.4 },
  title2:     { fontSize: 22, lineHeight: '28px', fontWeight: 700, letterSpacing: -0.3 },
  title3:     { fontSize: 20, lineHeight: '25px', fontWeight: 600, letterSpacing: -0.2 },
  headline:   { fontSize: 17, lineHeight: '22px', fontWeight: 600, letterSpacing: -0.1 },
  body:       { fontSize: 17, lineHeight: '24px', fontWeight: 400, letterSpacing: -0.1 },
  callout:    { fontSize: 16, lineHeight: '22px', fontWeight: 400, letterSpacing: -0.05 },
  subhead:    { fontSize: 15, lineHeight: '20px', fontWeight: 500, letterSpacing: 0 },
  footnote:   { fontSize: 13, lineHeight: '18px', fontWeight: 500, letterSpacing: 0 },
  caption:    { fontSize: 12, lineHeight: '16px', fontWeight: 500, letterSpacing: 0.1 },
  overline:   { fontSize: 11, lineHeight: '14px', fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase' },
};

// ── SF-style line icons (1.6 stroke, rounded caps) ─────────────
const Icon = ({ name, size = 22, color = 'currentColor', strokeWidth = 1.7 }) => {
  const s = { stroke: color, strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round', fill: 'none' };
  const f = { fill: color, stroke: 'none' };
  const paths = {
    // navigation
    chevronRight: <path d="M9 6l6 6-6 6" {...s} />,
    chevronLeft:  <path d="M15 6l-6 6 6 6" {...s} />,
    chevronDown:  <path d="M6 9l6 6 6-6" {...s} />,
    plus:         <path d="M12 5v14M5 12h14" {...s} />,
    close:        <path d="M6 6l12 12M18 6L6 18" {...s} />,
    check:        <path d="M5 12.5l4.5 4.5L19 7" {...s} />,
    search:       <g {...s}><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></g>,
    ellipsis:     <g {...f}><circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/></g>,
    // tabs
    memory:       <g {...s}><path d="M5 7c0-1.7 1.3-3 3-3h8c1.7 0 3 1.3 3 3v10c0 1.7-1.3 3-3 3H8c-1.7 0-3-1.3-3-3V7z"/><path d="M9 9h6M9 13h6M9 17h3"/></g>,
    tasks:        <g {...s}><rect x="4" y="5" width="16" height="14" rx="3"/><path d="M8 10.5l2 2 4-4"/><path d="M14.5 15.5h2.5"/></g>,
    more:         <g {...s}><circle cx="6.5" cy="6.5" r="2"/><circle cx="17.5" cy="6.5" r="2"/><circle cx="6.5" cy="17.5" r="2"/><circle cx="17.5" cy="17.5" r="2"/></g>,
    settings:     <g {...s}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.6 1.6 0 00-1.8-.3 1.6 1.6 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.6 1.6 0 00-1-1.5 1.6 1.6 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1A1.6 1.6 0 005 15a1.6 1.6 0 00-1.5-1H3a2 2 0 110-4h.1A1.6 1.6 0 004.6 9a1.6 1.6 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.6 1.6 0 001.8.3H9A1.6 1.6 0 0010 3.5V3a2 2 0 114 0v.1A1.6 1.6 0 0015 4.6a1.6 1.6 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.6 1.6 0 00-.3 1.8V9a1.6 1.6 0 001.5 1H21a2 2 0 110 4h-.1a1.6 1.6 0 00-1.5 1z"/></g>,
    // actions
    send:         <g {...s}><path d="M21 3l-9 18-2-8-8-2 19-8z"/></g>,
    mic:          <g {...s}><rect x="9.5" y="3" width="5" height="11" rx="2.5"/><path d="M6 11a6 6 0 0012 0M12 17v4M9 21h6"/></g>,
    lock:         <g {...s}><rect x="5" y="11" width="14" height="9" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/></g>,
    shield:       <g {...s}><path d="M12 3l8 3v6c0 4.5-3.5 8.5-8 9-4.5-.5-8-4.5-8-9V6l8-3z"/><path d="M9 12l2.5 2.5L15 11"/></g>,
    // tools
    home:         <g {...s}><path d="M4 11l8-7 8 7v8a2 2 0 01-2 2h-3v-6H9v6H6a2 2 0 01-2-2v-8z"/></g>,
    heart:        <g {...s}><path d="M12 20s-7-4.5-7-10a4.5 4.5 0 018-3 4.5 4.5 0 018 3c0 5.5-7 10-7 10h-2z"/></g>,
    phone:        <g {...s}><path d="M5 4h3l2 5-2.5 1.5a11 11 0 006 6L15 14l5 2v3a2 2 0 01-2 2 16 16 0 01-15-15 2 2 0 012-2z"/></g>,
    contacts:     <g {...s}><circle cx="12" cy="9" r="3.5"/><path d="M5 20c1-3.5 3.8-5.5 7-5.5s6 2 7 5.5"/></g>,
    bell:         <g {...s}><path d="M6 16V11a6 6 0 0112 0v5l1.5 2.5h-15L6 16zM10 20a2 2 0 004 0"/></g>,
    sparkle:      <g {...s}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.5 5.5l2.8 2.8M15.7 15.7l2.8 2.8M5.5 18.5l2.8-2.8M15.7 8.3l2.8-2.8"/></g>,
    sun:          <g {...s}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></g>,
    moon:         <g {...s}><path d="M20 14.5A8 8 0 1110 4.5a6 6 0 0010 10z"/></g>,
    calendar:     <g {...s}><rect x="4" y="5" width="16" height="15" rx="2.5"/><path d="M4 10h16M9 3v4M15 3v4"/></g>,
    clock:        <g {...s}><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/></g>,
    flag:         <g {...s}><path d="M5 21V4h11l-2 4 2 4H5"/></g>,
    trash:        <g {...s}><path d="M4 7h16M9 7V4h6v3M6 7l1 13a2 2 0 002 2h6a2 2 0 002-2l1-13M10 11v7M14 11v7"/></g>,
    download:     <g {...s}><path d="M12 4v12M7 11l5 5 5-5M5 20h14"/></g>,
    cloud:        <g {...s}><path d="M7 18a4 4 0 010-8 6 6 0 0111.5 1.5A3.5 3.5 0 0118 18H7z"/></g>,
    user:         <g {...s}><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/></g>,
    edit:         <g {...s}><path d="M4 20h4l11-11-4-4L4 16v4z"/></g>,
    folder:       <g {...s}><path d="M4 7a2 2 0 012-2h3.5l2 2H18a2 2 0 012 2v8a2 2 0 01-2 2H6a2 2 0 01-2-2V7z"/></g>,
    star:         <g {...s}><path d="M12 3l2.7 6 6.3.6-4.8 4.3 1.5 6.3L12 17l-5.7 3.2L7.8 14 3 9.6l6.3-.6L12 3z"/></g>,
    wifi:         <g {...s}><path d="M2 9a14 14 0 0120 0M5.5 12.5a9 9 0 0113 0M9 16a4.5 4.5 0 016 0"/><circle cx="12" cy="19.5" r="1" {...f}/></g>,
    bolt:         <g {...s}><path d="M13 3L4 14h7l-1 7 9-11h-7l1-7z"/></g>,
    leaf:         <g {...s}><path d="M5 19c0-8 6-14 14-14 0 8-6 14-14 14zM5 19l8-8"/></g>,
    pin:          <g {...s}><path d="M12 22s-6-5.5-6-11a6 6 0 0112 0c0 5.5-6 11-6 11z"/><circle cx="12" cy="11" r="2.2"/></g>,
    link:         <g {...s}><path d="M10 14a4 4 0 005.6 0l3-3a4 4 0 10-5.6-5.6L11 7"/><path d="M14 10a4 4 0 00-5.6 0l-3 3A4 4 0 1011 18.6L13 17"/></g>,
    eye:          <g {...s}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></g>,
    server:       <g {...s}><rect x="4" y="4" width="16" height="7" rx="2"/><rect x="4" y="13" width="16" height="7" rx="2"/><circle cx="8" cy="7.5" r="0.8" {...f}/><circle cx="8" cy="16.5" r="0.8" {...f}/></g>,
    waveform:     <g {...s}><path d="M3 12h2M7 8v8M11 5v14M15 9v6M19 11v2"/></g>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: 'block', flexShrink: 0 }}>
      {paths[name] || <circle cx="12" cy="12" r="6" {...s}/>}
    </svg>
  );
};

Object.assign(window, { NOBS, TYPE, Icon });
