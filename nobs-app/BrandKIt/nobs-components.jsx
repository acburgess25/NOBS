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

// ── Memory card (HealthLogCard) ──────────────────────────────────
function MemoryCard({ tag = 'Personal', body, date, pinned, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  
  // Choose tag colors based on health/wellness categories
  let tagColor = NOBS.brand.amber; // Rose/Coral
  let tagBg = dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint;
  
  if (tag === 'Meds' || tag === 'Work') {
    tagColor = NOBS.brand.sage; // Emerald Green
    tagBg = dark ? NOBS.brand.sageTintD : NOBS.brand.sageTint;
  } else if (tag === 'Wellness' || tag === 'Calm') {
    tagColor = NOBS.brand.blue; // Teal
    tagBg = dark ? 'rgba(13,148,136,0.18)' : 'rgba(13,148,136,0.12)';
  }
  
  return (
    <div style={{
      background: dark ? 'rgba(40, 35, 31, var(--glass-opacity, 0.66))' : 'rgba(255, 255, 255, var(--glass-opacity, 0.68))',
      backdropFilter: 'blur(28px) saturate(140%)',
      WebkitBackdropFilter: 'blur(28px) saturate(140%)',
      borderRadius: NOBS.r['2xl'],
      padding: 18, boxShadow: c.shadow,
      display: 'flex', flexDirection: 'column', gap: 12,
      border: dark ? '0.5px solid rgba(255,240,220,calc(var(--glass-opacity, 0.66) * 0.22))' : '0.5px solid rgba(60,40,20,calc(var(--glass-opacity, 0.68) * 0.18))',
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
const HealthLogCard = MemoryCard;

// ── Task row (MedicationRow) with animated circle checkbox ──────────────────────
function TaskRow({ title, done, due, tag, priority, dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  
  let dotColor = NOBS.brand.amber;
  if (tag === 'Meds' || tag === 'Work') {
    dotColor = NOBS.brand.sage;
  } else if (tag === 'Wellness' || tag === 'Calm') {
    dotColor = NOBS.brand.blue;
  }

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
                <div style={{ width: 6, height: 6, borderRadius: 3, background: dotColor }} />
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
const MedicationRow = TaskRow;

// ── Floating compose bar (memory / task) ────────────────────────
function ComposeBar({ placeholder = 'Capture a memory…', dark = false, value = '' }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{
      margin: '0 16px', display: 'flex', alignItems: 'center', gap: 8,
      background: dark ? 'rgba(40, 35, 31, var(--glass-opacity, 0.66))' : 'rgba(255, 255, 255, var(--glass-opacity, 0.68))',
      backdropFilter: 'blur(28px) saturate(140%)',
      WebkitBackdropFilter: 'blur(28px) saturate(140%)',
      borderRadius: NOBS.r.full, padding: 6,
      boxShadow: c.shadowLg,
      border: dark ? '0.5px solid rgba(255,240,220,calc(var(--glass-opacity, 0.66) * 0.22))' : '0.5px solid rgba(60,40,20,calc(var(--glass-opacity, 0.68) * 0.18))',
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
      background: dark ? 'rgba(28,25,23,calc(var(--glass-opacity, 0.66) * 1.3))' : 'rgba(250,248,245,calc(var(--glass-opacity, 0.68) * 1.3))',
      backdropFilter: 'blur(28px) saturate(140%)',
      WebkitBackdropFilter: 'blur(28px) saturate(140%)',
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
        background: dark ? 'rgba(40, 35, 31, var(--glass-opacity, 0.66))' : 'rgba(255, 255, 255, var(--glass-opacity, 0.68))',
        backdropFilter: 'blur(28px) saturate(140%)',
        WebkitBackdropFilter: 'blur(28px) saturate(140%)',
        borderRadius: NOBS.r['2xl'],
        boxShadow: c.shadow, overflow: 'hidden',
        border: dark ? '0.5px solid rgba(255,240,220,calc(var(--glass-opacity, 0.66) * 0.22))' : '0.5px solid rgba(60,40,20,calc(var(--glass-opacity, 0.68) * 0.18))',
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

// ── NOBS logomark — rounded square, rose background, N + pulse wave ───
function NobsLogo({ size = 64, radius }) {
  const r = radius || size * 0.21;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ display: 'block' }}>
      <rect width="100" height="100" rx={r * (100 / size)} fill="#E11D48"/>
      <rect x="1" y="1" width="98" height="98" rx={r * (100 / size) - 1} fill="none" stroke="rgba(255,255,255,0.18)" strokeWidth="2"/>
      <text x="50" y="42" fontFamily="'Archivo Black', sans-serif" fontSize="72" fontWeight="900" fill="#FFFFFF" textAnchor="middle" dominantBaseline="central" letterSpacing="-2">N</text>
      <path d="M 22 75 L 42 75 L 48 45 L 54 88 L 60 68 L 64 75 L 78 75" stroke="#FFFFFF" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" fill="none" opacity="0.95"/>
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

// ── Screen Time Meter (Digital Wellness Tracker) ──────────────────
function ScreenTimeMeter({ hours = 2.4, limit = 4.0, rule202020 = '12 min left', dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const percentage = Math.min((hours / limit) * 100, 100);
  const isOver = hours >= limit;
  const progressColor = isOver ? NOBS.brand.amber : NOBS.brand.blue; // Rose (amber variable) or Teal (blue variable)
  
  return (
    <div style={{
      background: dark ? 'rgba(40, 35, 31, var(--glass-opacity, 0.66))' : 'rgba(255, 255, 255, var(--glass-opacity, 0.68))',
      backdropFilter: 'blur(28px) saturate(140%)',
      WebkitBackdropFilter: 'blur(28px) saturate(140%)',
      borderRadius: NOBS.r['2xl'],
      padding: 18, boxShadow: c.shadow,
      border: dark ? '0.5px solid rgba(255,240,220,calc(var(--glass-opacity, 0.66) * 0.22))' : '0.5px solid rgba(60,40,20,calc(var(--glass-opacity, 0.68) * 0.18))',
      display: 'flex', flexDirection: 'column', gap: 14,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Icon name="eye" size={20} color={NOBS.brand.blue} />
          <div style={{ ...TYPE.headline, color: c.text }}>Screen Time</div>
        </div>
        <span style={{
          ...TYPE.caption, color: NOBS.brand.blue, background: dark ? 'rgba(13,148,136,0.18)' : 'rgba(13,148,136,0.12)',
          padding: '3px 10px', borderRadius: NOBS.r.full, fontWeight: 700,
        }}>{hours}h / {limit}h limit</span>
      </div>
      
      {/* progress bar */}
      <div style={{ height: 8, background: dark ? '#1E293B' : '#E2E8F0', borderRadius: 4, overflow: 'hidden', position: 'relative' }}>
        <div style={{ width: `${percentage}%`, height: '100%', background: progressColor, borderRadius: 4, transition: 'width 0.4s ease' }} />
      </div>
      
      {/* clinical research tip: 20-20-20 rule */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 2 }}>
        <div style={{
          width: 32, height: 32, borderRadius: 16,
          background: dark ? 'rgba(13,148,136,0.18)' : 'rgba(13,148,136,0.12)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0
        }}>
          <Icon name="clock" size={16} color={NOBS.brand.blue} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...TYPE.footnote, color: c.text, fontWeight: 600 }}>20-20-20 Rule rest break due:</div>
          <div style={{ ...TYPE.caption, color: c.textSecondary }}>{rule202020}</div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  NobsNavBar, NavIconButton, SegmentedToggle, SectionHeader,
  MemoryCard, HealthLogCard, TaskRow, MedicationRow, ScreenTimeMeter, ComposeBar, TabBar,
  GroupedList, GroupedRow, Switch,
  PrimaryButton, SecondaryButton, NobsLogo, EmptyState,
});
