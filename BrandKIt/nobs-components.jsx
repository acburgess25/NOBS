// nobs-components.jsx — reusable components for NOBS screens

// ── NavBar — large title, amber tint actions ─────────────────────
function NobsNavBar({ title, dark = false, leading, trailing, subtitle, large = true }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{ padding: '8px 20px 8px', position: 'relative' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 32, marginBottom: large ? 8 : 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>{leading}</div>
        {!large && (
          <div style={{ ...TYPE.headline, color: c.text, position: 'absolute', left: '50%', transform: 'translateX(-50%)' }}>
            {title}
          </div>
        )}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>{trailing}</div>
      </div>
      {large && (
        <div>
          <div style={{ ...TYPE.largeTitle, color: c.text }}>{title}</div>
          {subtitle && <div style={{ ...TYPE.subhead, color: c.textSecondary, marginTop: 2 }}>{subtitle}</div>}
        </div>
      )}
    </div>
  );
}

// Round nav icon button (amber-tinted on press / interactive)
function NavIconButton({ name, dark = false, tinted = false, onClick }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const color = tinted ? NOBS.brand.amber : c.text;
  return (
    <button onClick={onClick} style={{
      width: 36, height: 36, borderRadius: 18, border: 'none', cursor: 'pointer',
      background: tinted ? (dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint) : 'transparent',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color,
    }}>
      <Icon name={name} size={22} color={color} />
    </button>
  );
}

// ── Segmented toggle: Personal / Work ────────────────────────────
function SegmentedToggle({ options = ['Personal', 'Work'], value = 'Personal', dark = false, onChange }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{
      display: 'flex', padding: 3, gap: 2,
      background: dark ? 'rgba(255,240,220,0.06)' : 'rgba(60,40,20,0.05)',
      borderRadius: NOBS.r.full, position: 'relative',
    }}>
      {options.map((opt) => {
        const active = opt === value;
        return (
          <button key={opt} onClick={() => onChange && onChange(opt)} style={{
            flex: 1, border: 'none', cursor: 'pointer',
            padding: '8px 16px', borderRadius: NOBS.r.full,
            background: active ? c.surface : 'transparent',
            ...TYPE.subhead, fontWeight: active ? 600 : 500,
            color: active ? c.text : c.textSecondary,
            boxShadow: active ? (dark ? '0 1px 3px rgba(0,0,0,0.4)' : '0 1px 3px rgba(60,40,20,0.08)') : 'none',
            fontFamily: NOBS.font, transition: 'all .15s',
          }}>{opt}</button>
        );
      })}
    </div>
  );
}

// ── Section header (small caps, tertiary color) ─────────────────
function SectionHeader({ children, dark = false, action }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 4px 8px' }}>
      <div style={{ ...TYPE.overline, color: c.textTertiary }}>{children}</div>
      {action && <div style={{ ...TYPE.footnote, color: NOBS.brand.amber, fontWeight: 600 }}>{action}</div>}
    </div>
  );
}

// ── Memory card ──────────────────────────────────────────────────
function MemoryCard({ tag = 'Personal', body, date, pinned, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const tagSage = tag === 'Work';
  const tagColor = tagSage ? NOBS.brand.sage : NOBS.brand.amber;
  const tagBg = tagSage
    ? (dark ? NOBS.brand.sageTintD : NOBS.brand.sageTint)
    : (dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint);
  return (
    <div style={{
      background: c.surface, borderRadius: NOBS.r['2xl'],
      padding: 18, boxShadow: c.shadow,
      display: 'flex', flexDirection: 'column', gap: 12,
      border: dark ? `0.5px solid ${c.border}` : 'none',
      position: 'relative', overflow: 'hidden',
    }}>
      {pinned && (
        <div style={{
          position: 'absolute', top: 14, right: 14,
          color: NOBS.brand.amber, transform: 'rotate(35deg)',
        }}>
          <Icon name="pin" size={16} color={NOBS.brand.amber} strokeWidth={2} />
        </div>
      )}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{
          ...TYPE.caption, color: tagColor, background: tagBg,
          padding: '3px 10px', borderRadius: NOBS.r.full, fontWeight: 700,
        }}>{tag}</span>
        <div style={{ flex: 1 }}></div>
        <div style={{ ...TYPE.footnote, color: c.textTertiary, marginRight: pinned ? 22 : 0 }}>{date}</div>
      </div>
      <div style={{ ...TYPE.body, color: c.text, textWrap: 'pretty' }}>{body}</div>
    </div>
  );
}

// ── Task row with animated circle checkbox ──────────────────────
function TaskRow({ title, done, due, tag, priority, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const tagSage = tag === 'Work';
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 14,
      padding: '14px 16px',
    }}>
      {/* circle checkbox */}
      <div style={{
        width: 24, height: 24, borderRadius: 12, flexShrink: 0,
        border: done ? 'none' : `2px solid ${dark ? '#5C544C' : '#D1C8BC'}`,
        background: done ? NOBS.brand.sage : 'transparent',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginTop: 1,
      }}>
        {done && <Icon name="check" size={14} color="#fff" strokeWidth={3} />}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          ...TYPE.body, color: done ? c.textTertiary : c.text,
          textDecoration: done ? 'line-through' : 'none',
          textDecorationColor: dark ? 'rgba(168,162,158,0.5)' : 'rgba(168,162,158,0.7)',
        }}>{title}</div>
        {(due || tag) && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 4 }}>
            {due && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, ...TYPE.footnote, color: c.textTertiary }}>
                <Icon name="clock" size={12} color={c.textTertiary} />
                {due}
              </div>
            )}
            {tag && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                <div style={{ width: 6, height: 6, borderRadius: 3, background: tagSage ? NOBS.brand.sage : NOBS.brand.amber }} />
                <div style={{ ...TYPE.footnote, color: c.textTertiary }}>{tag}</div>
              </div>
            )}
          </div>
        )}
      </div>
      {priority && (
        <Icon name="flag" size={16} color={NOBS.brand.amber} />
      )}
    </div>
  );
}

// ── Floating compose bar (memory / task) ────────────────────────
function ComposeBar({ placeholder = 'Capture a memory…', dark = false, value = '' }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{
      margin: '0 16px', display: 'flex', alignItems: 'center', gap: 8,
      background: c.surface, borderRadius: NOBS.r.full, padding: 6,
      boxShadow: c.shadowLg,
      border: dark ? `0.5px solid ${c.border}` : 'none',
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 18, flexShrink: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: c.textSecondary,
      }}>
        <Icon name="sparkle" size={20} color={NOBS.brand.amber} />
      </div>
      <div style={{
        flex: 1, ...TYPE.body, color: value ? c.text : c.placeholder,
        minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
      }}>{value || placeholder}</div>
      <button style={{
        width: 36, height: 36, borderRadius: 18, border: 'none', cursor: 'pointer', flexShrink: 0,
        background: dark ? 'rgba(255,240,220,0.08)' : 'rgba(60,40,20,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.textSecondary,
      }}>
        <Icon name="mic" size={18} color={c.textSecondary} />
      </button>
      <button style={{
        width: 36, height: 36, borderRadius: 18, border: 'none', cursor: 'pointer', flexShrink: 0,
        background: NOBS.brand.amber,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 2px 8px rgba(217,119,6,0.35)',
      }}>
        <Icon name="send" size={18} color="#fff" strokeWidth={2} />
      </button>
    </div>
  );
}

// ── Bottom Tab Bar ───────────────────────────────────────────────
function TabBar({ active = 'memories', dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const tabs = [
    { key: 'memories', label: 'Memories', icon: 'memory' },
    { key: 'tasks',    label: 'Tasks',    icon: 'tasks' },
    { key: 'more',     label: 'More',     icon: 'more' },
    { key: 'settings', label: 'Settings', icon: 'settings' },
  ];
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-around', alignItems: 'center',
      padding: '8px 8px 0px',
      background: dark ? 'rgba(28,25,23,0.9)' : 'rgba(250,248,245,0.9)',
      backdropFilter: 'blur(20px) saturate(180%)',
      WebkitBackdropFilter: 'blur(20px) saturate(180%)',
      borderTop: `0.5px solid ${c.divider}`,
    }}>
      {tabs.map((t) => {
        const isActive = t.key === active;
        const color = isActive ? NOBS.brand.amber : c.textTertiary;
        return (
          <button key={t.key} style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            padding: '6px 10px',
            color,
          }}>
            <Icon name={t.icon} size={24} color={color} strokeWidth={isActive ? 2 : 1.7} />
            <span style={{ ...TYPE.caption, fontWeight: isActive ? 700 : 500, color, fontFamily: NOBS.font }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ── Grouped list (NOBS flavored — warm card, no harsh separators) ──
function GroupedList({ children, dark = false, header, footer }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{ padding: '0 16px 4px' }}>
      {header && <SectionHeader dark={dark}>{header}</SectionHeader>}
      <div style={{
        background: c.surface, borderRadius: NOBS.r['2xl'],
        boxShadow: c.shadow, overflow: 'hidden',
        border: dark ? `0.5px solid ${c.border}` : 'none',
      }}>{children}</div>
      {footer && (
        <div style={{ ...TYPE.footnote, color: c.textTertiary, padding: '8px 4px 0', textWrap: 'pretty' }}>{footer}</div>
      )}
    </div>
  );
}

// One row inside a grouped list — icon badge + title + detail + chevron
function GroupedRow({ title, detail, icon, iconColor = NOBS.brand.amber, iconBg, chevron = true, isLast, dark = false, danger, value, switchOn }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const titleColor = danger ? NOBS.brand.rose : c.text;
  const bg = iconBg || (dark ? `${iconColor}24` : `${iconColor}1A`);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', minHeight: 52, padding: '10px 16px',
      position: 'relative',
    }}>
      {icon && (
        <div style={{
          width: 30, height: 30, borderRadius: 8, marginRight: 14, flexShrink: 0,
          background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name={icon} size={18} color={iconColor} />
        </div>
      )}
      <div style={{ flex: 1, ...TYPE.body, color: titleColor, fontWeight: 500 }}>{title}</div>
      {value && <span style={{ ...TYPE.body, color: c.textSecondary, marginRight: 8 }}>{value}</span>}
      {detail && <span style={{ ...TYPE.footnote, color: c.textTertiary, marginRight: 8 }}>{detail}</span>}
      {typeof switchOn === 'boolean' && <Switch on={switchOn} dark={dark} />}
      {chevron && typeof switchOn !== 'boolean' && (
        <Icon name="chevronRight" size={16} color={c.textTertiary} strokeWidth={2.2} />
      )}
      {!isLast && (
        <div style={{
          position: 'absolute', left: icon ? 60 : 16, right: 0, bottom: 0,
          height: 0.5, background: c.divider,
        }} />
      )}
    </div>
  );
}

// iOS-style switch
function Switch({ on = false, dark = false }) {
  return (
    <div style={{
      width: 51, height: 31, borderRadius: 15.5, padding: 2,
      background: on ? NOBS.brand.sage : (dark ? '#3C3631' : '#E0DAD1'),
      display: 'flex', alignItems: 'center', justifyContent: on ? 'flex-end' : 'flex-start',
      transition: 'background .2s',
    }}>
      <div style={{
        width: 27, height: 27, borderRadius: '50%', background: '#fff',
        boxShadow: '0 2px 4px rgba(0,0,0,0.18), 0 0 1px rgba(0,0,0,0.2)',
      }} />
    </div>
  );
}

// ── Primary CTA button — amber pill ─────────────────────────────
function PrimaryButton({ children, full, dark = false, size = 'lg', icon }) {
  const sizes = {
    lg: { height: 56, padding: '0 28px', fontSize: 17 },
    md: { height: 48, padding: '0 22px', fontSize: 16 },
    sm: { height: 36, padding: '0 16px', fontSize: 15 },
  }[size];
  return (
    <button style={{
      ...sizes, width: full ? '100%' : 'auto',
      borderRadius: NOBS.r.full, border: 'none', cursor: 'pointer',
      background: NOBS.brand.amber, color: '#fff',
      fontWeight: 700, fontFamily: NOBS.font, letterSpacing: -0.2,
      boxShadow: '0 3px 10px rgba(217,119,6,0.35), 0 1px 2px rgba(217,119,6,0.25)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    }}>
      {icon && <Icon name={icon} size={20} color="#fff" strokeWidth={2} />}
      {children}
    </button>
  );
}

function SecondaryButton({ children, full, dark = false, size = 'md' }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const sizes = {
    lg: { height: 56, padding: '0 28px', fontSize: 17 },
    md: { height: 48, padding: '0 22px', fontSize: 16 },
    sm: { height: 36, padding: '0 16px', fontSize: 15 },
  }[size];
  return (
    <button style={{
      ...sizes, width: full ? '100%' : 'auto',
      borderRadius: NOBS.r.full, border: 'none', cursor: 'pointer',
      background: dark ? 'rgba(255,240,220,0.06)' : 'rgba(60,40,20,0.05)',
      color: c.text,
      fontWeight: 600, fontFamily: NOBS.font, letterSpacing: -0.2,
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    }}>{children}</button>
  );
}

// ── NOBS logomark — rounded square, amber gradient, leaf/brain ───
function NobsLogo({ size = 64, radius }) {
  const r = radius || size * 0.24;
  const id = `nobs-grad-${size}`;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" style={{ display: 'block' }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#FBBF24" />
          <stop offset="55%" stopColor="#F59E0B" />
          <stop offset="100%" stopColor="#B45309" />
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx={r * (64 / size)} fill={`url(#${id})`} />
      {/* Soft inner highlight */}
      <rect x="1" y="1" width="62" height="62" rx={r * (64 / size) - 1} fill="none" stroke="rgba(255,255,255,0.25)" />
      {/* Leaf mark */}
      <g transform="translate(32 32)">
        <path d="M -13 13 C -13 -2, -2 -13, 13 -13 C 13 2, 2 13, -13 13 Z" fill="rgba(255,255,255,0.95)" />
        <path d="M -13 13 L 8 -8" stroke="rgba(180,83,9,0.7)" strokeWidth="1.6" strokeLinecap="round" fill="none" />
      </g>
    </svg>
  );
}

// ── Empty state ──────────────────────────────────────────────────
function EmptyState({ icon = 'memory', title, body, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, padding: '40px 24px', textAlign: 'center' }}>
      <div style={{
        width: 64, height: 64, borderRadius: 32,
        background: dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Icon name={icon} size={28} color={NOBS.brand.amber} strokeWidth={1.6} />
      </div>
      <div style={{ ...TYPE.title3, color: c.text }}>{title}</div>
      <div style={{ ...TYPE.subhead, color: c.textSecondary, maxWidth: 240, textWrap: 'pretty' }}>{body}</div>
    </div>
  );
}

Object.assign(window, {
  NobsNavBar, NavIconButton, SegmentedToggle, SectionHeader,
  MemoryCard, TaskRow, ComposeBar, TabBar,
  GroupedList, GroupedRow, Switch,
  PrimaryButton, SecondaryButton, NobsLogo, EmptyState,
});
