// nobs-screens.jsx — the six NOBS screens (light + dark)

// ── Layout helper: status-bar safe area + tab bar safe area ──────
function ScreenShell({ children, dark, tabActive = 'memories', noTabBar, footer, scroll = true }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      fontFamily: NOBS.font, position: 'relative',
      display: 'flex', flexDirection: 'column',
      paddingTop: 60, // dynamic island / status bar
      WebkitFontSmoothing: 'antialiased',
    }}>
      <div style={{
        flex: 1, minHeight: 0,
        overflow: scroll ? 'auto' : 'hidden',
        display: 'flex', flexDirection: 'column',
      }}>
        {children}
      </div>
      {footer && <div style={{ flexShrink: 0 }}>{footer}</div>}
      {!noTabBar && (
        <div style={{ flexShrink: 0, paddingBottom: 28 /* home indicator */ }}>
          <TabBar active={tabActive} dark={dark} />
        </div>
      )}
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// 1. Home / Memories
// ════════════════════════════════════════════════════════════════
function MemoriesScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const memories = [
    { tag: 'Personal', date: 'Just now', body: 'Sarah likes single-origin Ethiopian coffee with a touch of cinnamon, no sugar. Remember for the anniversary dinner.', pinned: true },
    { tag: 'Work', date: 'Yesterday', body: 'The Q2 board review went well — they want a deeper dive on retention by cohort next month. Pull data from Mixpanel before the 15th.' },
    { tag: 'Personal', date: 'Mon, May 19', body: 'Mom\u2019s blood pressure med is Losartan 50mg, mornings with food. Refill due first week of June.' },
    { tag: 'Personal', date: 'May 17', body: 'The little bookshop on Valencia and 16th sells signed first editions in the back room — only on Saturdays.' },
  ];
  return (
    <ScreenShell dark={dark} tabActive="memories" footer={
      <div style={{ padding: '10px 0 14px' }}>
        <ComposeBar dark={dark} placeholder="Capture a memory…" />
      </div>
    }>
      <NobsNavBar
        title="Memories"
        subtitle="Encrypted on your network"
        dark={dark}
        trailing={
          <>
            <NavIconButton name="search" dark={dark} />
            <NavIconButton name="plus" dark={dark} tinted />
          </>
        }
      />
      <div style={{ padding: '4px 20px 12px' }}>
        <SegmentedToggle dark={dark} value="Personal" />
      </div>
      <div style={{ padding: '8px 16px 4px' }}>
        <SectionHeader dark={dark}>Today</SectionHeader>
      </div>
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {memories.slice(0, 1).map((m, i) => <MemoryCard key={i} {...m} dark={dark} />)}
      </div>
      <div style={{ padding: '20px 16px 4px' }}>
        <SectionHeader dark={dark}>Earlier this week</SectionHeader>
      </div>
      <div style={{ padding: '0 16px 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {memories.slice(1).map((m, i) => <MemoryCard key={i} {...m} dark={dark} />)}
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 2. Tasks
// ════════════════════════════════════════════════════════════════
function TasksScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const pending = [
    { title: 'Order Sarah\u2019s coffee beans for Friday',     due: 'Today, 5pm',  tag: 'Personal', priority: true },
    { title: 'Review the Q2 cohort retention deck',             due: 'Tomorrow',    tag: 'Work' },
    { title: 'Call mom about her pharmacy refill',              due: 'Thu, May 22', tag: 'Personal' },
    { title: 'Confirm dinner reservation at Nopa',              due: 'Sat 7:30pm',  tag: 'Personal' },
  ];
  const completed = [
    { title: 'Pick up dry cleaning',                            tag: 'Personal', done: true },
    { title: 'Send investor update — May',                      tag: 'Work',     done: true },
  ];
  return (
    <ScreenShell dark={dark} tabActive="tasks" footer={
      <div style={{ padding: '10px 0 14px' }}>
        <ComposeBar dark={dark} placeholder="Add a task…" />
      </div>
    }>
      <NobsNavBar
        title="Tasks"
        subtitle="4 due this week"
        dark={dark}
        trailing={<>
          <NavIconButton name="calendar" dark={dark} />
          <NavIconButton name="plus" dark={dark} tinted />
        </>}
      />
      <div style={{ padding: '4px 20px 16px' }}>
        <SegmentedToggle dark={dark} value="Personal" />
      </div>
      <div style={{ padding: '0 16px' }}>
        <SectionHeader dark={dark} action="Sort">Pending · 4</SectionHeader>
        <div style={{
          background: c.surface, borderRadius: NOBS.r['2xl'], boxShadow: c.shadow,
          overflow: 'hidden',
          border: dark ? `0.5px solid ${c.border}` : 'none',
        }}>
          {pending.map((t, i) => (
            <React.Fragment key={i}>
              <TaskRow {...t} dark={dark} />
              {i < pending.length - 1 && (
                <div style={{ height: 0.5, background: c.divider, marginLeft: 54 }} />
              )}
            </React.Fragment>
          ))}
        </div>
      </div>
      <div style={{ padding: '20px 16px 24px' }}>
        <SectionHeader dark={dark}>Completed · 2</SectionHeader>
        <div style={{
          background: c.surface, borderRadius: NOBS.r['2xl'], boxShadow: c.shadow,
          overflow: 'hidden',
          border: dark ? `0.5px solid ${c.border}` : 'none',
        }}>
          {completed.map((t, i) => (
            <React.Fragment key={i}>
              <TaskRow {...t} dark={dark} />
              {i < completed.length - 1 && (
                <div style={{ height: 0.5, background: c.divider, marginLeft: 54 }} />
              )}
            </React.Fragment>
          ))}
        </div>
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 3. Onboarding (step 2 of 5 shown — private storage)
// ════════════════════════════════════════════════════════════════
function OnboardingScreen({ dark = false, step = 2 }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const steps = [
    {
      icon: 'leaf',
      title: 'A quieter kind of AI',
      body: 'NOBS is your private assistant. It runs on your own network and never sends a single byte to the cloud.',
    },
    {
      icon: 'shield',
      title: 'Encrypted memories,\nonly for you',
      body: 'Everything you tell NOBS — names, dates, secrets — is encrypted on-device with a key only you hold.',
    },
    {
      icon: 'home',
      title: 'Connects your\nhome and life',
      body: 'HomeKit, Apple Health, Reminders, and Contacts. All managed from one warm, fast assistant.',
    },
    {
      icon: 'bolt',
      title: 'Fast, local, always on',
      body: 'Replies in milliseconds. No subscription. Works on your home Wi-Fi, even when the internet doesn\u2019t.',
    },
    {
      icon: 'sparkle',
      title: 'You\u2019re in control',
      body: 'Export anything, delete everything in one tap. NOBS earns your trust, every single day.',
    },
  ];
  const s = steps[step];
  return (
    <ScreenShell dark={dark} noTabBar scroll={false}>
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 20px 0' }}>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: c.textSecondary, ...TYPE.headline, fontFamily: NOBS.font,
          padding: 0,
        }}>Back</button>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: c.textTertiary, ...TYPE.headline, fontWeight: 500, fontFamily: NOBS.font,
          padding: 0,
        }}>Skip</button>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '24px 32px', gap: 36, textAlign: 'center' }}>
        {/* Warm illustration mark — amber rounded square, layered glow */}
        <div style={{ position: 'relative', width: 168, height: 168 }}>
          {/* outer soft glow */}
          <div style={{
            position: 'absolute', inset: -32, borderRadius: 64,
            background: `radial-gradient(circle, ${dark ? 'rgba(245,158,11,0.18)' : 'rgba(245,158,11,0.22)'}, transparent 70%)`,
            filter: 'blur(8px)',
          }} />
          <div style={{
            position: 'relative', width: 168, height: 168, borderRadius: 44,
            background: `linear-gradient(155deg, #FBBF24 0%, ${NOBS.brand.amber} 55%, ${NOBS.brand.amberDeep})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 18px 40px rgba(217,119,6,0.32), inset 0 1px 0 rgba(255,255,255,0.3)',
          }}>
            {/* subtle highlight */}
            <div style={{
              position: 'absolute', inset: 0, borderRadius: 44,
              background: 'radial-gradient(circle at 28% 22%, rgba(255,255,255,0.35), transparent 50%)',
              pointerEvents: 'none',
            }} />
            <Icon name={s.icon} size={72} color="#fff" strokeWidth={1.5} />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ ...TYPE.largeTitle, fontSize: 32, lineHeight: '38px', color: c.text, whiteSpace: 'pre-line' }}>{s.title}</div>
          <div style={{ ...TYPE.body, fontSize: 17, lineHeight: '25px', color: c.textSecondary, textWrap: 'pretty', maxWidth: 320 }}>{s.body}</div>
        </div>
      </div>

      {/* Progress dots + CTA */}
      <div style={{ padding: '0 24px 36px', display: 'flex', flexDirection: 'column', gap: 24, alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {steps.map((_, i) => (
            <div key={i} style={{
              width: i === step ? 22 : 7, height: 7, borderRadius: 4,
              background: i === step ? NOBS.brand.amber : (dark ? '#3C3631' : '#E0DAD1'),
              transition: 'all .25s',
            }} />
          ))}
        </div>
        <PrimaryButton full dark={dark}>
          {step === steps.length - 1 ? 'Get Started' : 'Continue'}
        </PrimaryButton>
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 4. Settings
// ════════════════════════════════════════════════════════════════
function SettingsScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <ScreenShell dark={dark} tabActive="settings">
      <NobsNavBar title="Settings" dark={dark} />

      {/* Account card */}
      <div style={{ padding: '4px 16px 20px' }}>
        <div style={{
          background: c.surface, borderRadius: NOBS.r['2xl'], padding: 18,
          display: 'flex', alignItems: 'center', gap: 14, boxShadow: c.shadow,
          border: dark ? `0.5px solid ${c.border}` : 'none',
        }}>
          <div style={{
            width: 56, height: 56, borderRadius: 28,
            background: `linear-gradient(135deg, ${NOBS.brand.amberSoft}, ${NOBS.brand.amberDeep})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', ...TYPE.title2, fontWeight: 700,
            boxShadow: '0 4px 12px rgba(217,119,6,0.3)',
          }}>JM</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...TYPE.headline, color: c.text }}>Jordan Maris</div>
            <div style={{ ...TYPE.footnote, color: c.textSecondary, marginTop: 2, display: 'flex', alignItems: 'center', gap: 5 }}>
              <Icon name="server" size={12} color={NOBS.brand.sage} />
              nobs.local · 412 memories
            </div>
          </div>
          <Icon name="chevronRight" size={18} color={c.textTertiary} strokeWidth={2.2} />
        </div>
      </div>

      <GroupedList dark={dark} header="Privacy & security">
        <GroupedRow icon="shield" iconColor={NOBS.brand.sage} title="Encryption" detail="AES-256" dark={dark} />
        <GroupedRow icon="lock"   iconColor={NOBS.brand.amber} title="Face ID lock" switchOn={true} dark={dark} />
        <GroupedRow icon="eye"    iconColor={NOBS.brand.amber} title="Memory visibility" detail="Private" dark={dark} />
        <GroupedRow icon="wifi"   iconColor={NOBS.brand.blue}  title="Local network only" switchOn={true} dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Appearance">
        <GroupedRow icon={dark ? 'moon' : 'sun'} iconColor={NOBS.brand.amber} title="Theme" value={dark ? 'Dark' : 'Light'} dark={dark} />
        <GroupedRow icon="sparkle" iconColor={NOBS.brand.amber} title="Accent" value="Amber" dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Data">
        <GroupedRow icon="download" iconColor={NOBS.brand.sage} title="Export everything" dark={dark} />
        <GroupedRow icon="cloud"    iconColor={NOBS.brand.blue} title="Backup to home server" detail="Daily" dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Danger zone" footer="Deleting your memories is irreversible. NOBS keeps no copies — that\u2019s the point.">
        <GroupedRow icon="trash" iconColor={NOBS.brand.rose} title="Delete all memories" danger dark={dark} />
        <GroupedRow icon="close" iconColor={NOBS.brand.rose} title="Reset NOBS"            danger dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 28 }} />
      <div style={{ textAlign: 'center', ...TYPE.caption, color: c.textTertiary, padding: '0 24px 24px' }}>
        NOBS v1.4 · Build 412
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 5. More / Tools
// ════════════════════════════════════════════════════════════════
function MoreScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <ScreenShell dark={dark} tabActive="more">
      <NobsNavBar title="Tools" subtitle="What NOBS can do for you" dark={dark} />

      <GroupedList dark={dark} header="Quick actions">
        <GroupedRow icon="bell"     iconColor={NOBS.brand.amber} title="Reminders"        detail="3 due"   dark={dark} />
        <GroupedRow icon="calendar" iconColor={NOBS.brand.sage}  title="Calendar"         detail="2 today" dark={dark} />
        <GroupedRow icon="phone"    iconColor={NOBS.brand.amber} title="Phone"                              dark={dark} />
        <GroupedRow icon="contacts" iconColor={NOBS.brand.blue}  title="Contacts"         detail="412"     dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Home & health">
        <GroupedRow icon="home"     iconColor={NOBS.brand.amber} title="HomeKit"          detail="8 devices" dark={dark} />
        <GroupedRow icon="heart"    iconColor={NOBS.brand.rose}  title="Apple Health"     detail="Synced"    dark={dark} />
        <GroupedRow icon="leaf"     iconColor={NOBS.brand.sage}  title="Garden sensors"   detail="3 plants"  dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Integrations">
        <GroupedRow icon="sparkle" iconColor={NOBS.brand.amber} title="Siri shortcuts"   value="12"     dark={dark} />
        <GroupedRow icon="folder"  iconColor={NOBS.brand.amber} title="Files & notes"                  dark={dark} />
        <GroupedRow icon="link"    iconColor={NOBS.brand.blue}  title="Connected apps"   value="6"     dark={dark} />
        <GroupedRow icon="waveform" iconColor={NOBS.brand.sage} title="Voice triggers"   detail="On"   dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 32 }} />
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// Welcome (Onboarding step 0 — branded intro)
// ════════════════════════════════════════════════════════════════
function WelcomeScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <ScreenShell dark={dark} noTabBar scroll={false}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '24px 32px', gap: 32 }}>
        <NobsLogo size={112} />
        <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ ...TYPE.largeTitle, fontSize: 44, lineHeight: '48px', color: c.text }}>NOBS</div>
          <div style={{ ...TYPE.title3, color: c.textSecondary, fontWeight: 500, textWrap: 'pretty', maxWidth: 280 }}>
            Your private AI.<br/>No cloud. No compromise.
          </div>
        </div>
      </div>
      <div style={{ padding: '0 24px 36px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <PrimaryButton full dark={dark}>Get Started</PrimaryButton>
        <SecondaryButton full dark={dark} size="lg">I already have NOBS</SecondaryButton>
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 6. Empty Memories — first-run state
// ════════════════════════════════════════════════════════════════
function EmptyMemoriesScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <ScreenShell dark={dark} tabActive="memories" footer={
      <div style={{ padding: '10px 0 14px' }}>
        <ComposeBar dark={dark} placeholder="Tell NOBS something to remember\u2026" />
      </div>
    }>
      <NobsNavBar
        title="Memories"
        subtitle="Encrypted on your network"
        dark={dark}
        trailing={<NavIconButton name="plus" dark={dark} tinted />}
      />
      <div style={{ padding: '4px 20px 12px' }}>
        <SegmentedToggle dark={dark} value="Personal" />
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 32px' }}>
        <div style={{ position: 'relative', marginBottom: 28 }}>
          {/* outer soft glow */}
          <div style={{
            position: 'absolute', inset: -18, borderRadius: 44,
            background: dark ? 'rgba(245,158,11,0.16)' : 'rgba(245,158,11,0.20)',
            filter: 'blur(12px)',
          }} />
          <div style={{
            position: 'relative', width: 104, height: 104, borderRadius: 28,
            background: `linear-gradient(155deg, #FBBF24 0%, ${NOBS.brand.amber} 60%, ${NOBS.brand.amberDeep})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 12px 28px rgba(217,119,6,0.28), inset 0 1px 0 rgba(255,255,255,0.3)',
          }}>
            <Icon name="memory" size={48} color="#fff" strokeWidth={1.5} />
          </div>
        </div>
        <div style={{ ...TYPE.title2, color: c.text, textAlign: 'center', marginBottom: 10 }}>
          A blank slate
        </div>
        <div style={{ ...TYPE.body, color: c.textSecondary, textAlign: 'center', textWrap: 'pretty', maxWidth: 280 }}>
          Names, dates, preferences, anything.
          Capture your first memory below and NOBS will remember &mdash; privately.
        </div>
        <div style={{ marginTop: 32, display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'stretch', width: '100%', maxWidth: 300 }}>
          {[
            'Sarah likes Ethiopian coffee, no sugar',
            'Garage code is 4 7 1 2',
            'Quarterly board meeting first Tuesday',
          ].map((s, i) => (
            <button key={i} style={{
              cursor: 'pointer', textAlign: 'left', padding: '12px 16px',
              background: c.surface, borderRadius: NOBS.r.lg,
              ...TYPE.subhead, color: c.textSecondary,
              fontFamily: NOBS.font, fontWeight: 500,
              display: 'flex', alignItems: 'center', gap: 10,
              boxShadow: c.shadow,
              border: dark ? `0.5px solid ${c.border}` : 'none',
            }}>
              <Icon name="sparkle" size={14} color={NOBS.brand.amber} />
              &ldquo;{s}&rdquo;
            </button>
          ))}
        </div>
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 7. Add Memory — composer focused, keyboard up
// ════════════════════════════════════════════════════════════════
function AddMemoryScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <div style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      fontFamily: NOBS.font, display: 'flex', flexDirection: 'column',
      paddingTop: 60, WebkitFontSmoothing: 'antialiased',
    }}>
      {/* Sheet header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 20px 12px' }}>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: c.textSecondary, ...TYPE.headline, fontFamily: NOBS.font, padding: 0,
        }}>Cancel</button>
        <div style={{ ...TYPE.headline, color: c.text }}>New memory</div>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: NOBS.brand.amber, ...TYPE.headline, fontWeight: 700, fontFamily: NOBS.font, padding: 0,
        }}>Save</button>
      </div>

      {/* tag select */}
      <div style={{ padding: '4px 20px 12px', display: 'flex', gap: 8 }}>
        {[
          ['Personal', NOBS.brand.amber, dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint, true],
          ['Work',     NOBS.brand.sage,  dark ? NOBS.brand.sageTintD  : NOBS.brand.sageTint, false],
        ].map(([label, color, bg, active]) => (
          <span key={label} style={{
            ...TYPE.subhead, color: active ? color : c.textSecondary,
            background: active ? bg : 'transparent',
            border: active ? 'none' : `1px solid ${c.divider}`,
            padding: '6px 14px', borderRadius: NOBS.r.full, fontWeight: 700,
          }}>{label}</span>
        ))}
      </div>

      {/* composer textarea */}
      <div style={{ flex: 1, padding: '4px 24px', overflow: 'hidden' }}>
        <div style={{ ...TYPE.body, fontSize: 19, lineHeight: '28px', color: c.text }}>
          Sarah likes single-origin Ethiopian coffee with a touch of cinnamon, no sugar.
          <span style={{
            display: 'inline-block', width: 2, height: 22, background: NOBS.brand.amber,
            verticalAlign: 'text-bottom', marginLeft: 1, marginBottom: 1,
            animation: 'nobs-caret 1.05s steps(1) infinite',
          }} />
        </div>
        <style>{`@keyframes nobs-caret{50%{opacity:0}}`}</style>

        {/* AI suggestion chip */}
        <div style={{
          marginTop: 20, display: 'flex', alignItems: 'center', gap: 10,
          padding: '12px 14px', background: dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint,
          borderRadius: NOBS.r.lg, border: `1px dashed ${dark ? 'rgba(245,158,11,0.4)' : 'rgba(217,119,6,0.4)'}`,
        }}>
          <Icon name="sparkle" size={18} color={NOBS.brand.amber} />
          <div style={{ flex: 1, ...TYPE.subhead, color: c.textSecondary, lineHeight: '20px' }}>
            <span style={{ fontWeight: 700, color: NOBS.brand.amberDeep }}>NOBS · </span>
            Want me to add a Friday reminder to order beans?
          </div>
        </div>
      </div>

      {/* attach row above keyboard */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 14, padding: '10px 20px',
        borderTop: `0.5px solid ${c.divider}`, background: c.bg,
      }}>
        <NavIconButton name="mic" dark={dark} />
        <NavIconButton name="calendar" dark={dark} />
        <NavIconButton name="pin" dark={dark} />
        <div style={{ flex: 1 }} />
        <div style={{ ...TYPE.footnote, color: c.textTertiary }}>76 / 280</div>
      </div>

      <IOSKeyboard dark={dark} />
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// 8. Memory Detail
// ════════════════════════════════════════════════════════════════
function MemoryDetailScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <ScreenShell dark={dark} noTabBar>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 16px' }}>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 4,
          color: NOBS.brand.amber, ...TYPE.headline, fontFamily: NOBS.font, padding: 0,
        }}>
          <Icon name="chevronLeft" size={20} color={NOBS.brand.amber} strokeWidth={2.4} />
          Memories
        </button>
        <div style={{ display: 'flex', gap: 4 }}>
          <NavIconButton name="pin" dark={dark} tinted />
          <NavIconButton name="ellipsis" dark={dark} />
        </div>
      </div>

      <div style={{ padding: '12px 20px 24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
          <span style={{
            ...TYPE.caption, color: NOBS.brand.amber,
            background: dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint,
            padding: '4px 12px', borderRadius: NOBS.r.full, fontWeight: 700,
          }}>Personal</span>
          <div style={{ ...TYPE.footnote, color: c.textTertiary }}>Mon 19 May · 9:41 am</div>
        </div>
        <div style={{ ...TYPE.title2, color: c.text, lineHeight: '30px', marginBottom: 18, textWrap: 'pretty' }}>
          Sarah likes single-origin Ethiopian coffee with a touch of cinnamon,
          no sugar. Remember for the anniversary dinner.
        </div>

        {/* extracted entities */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 24 }}>
          {[
            ['user', 'Sarah'],
            ['heart', 'Coffee · Ethiopian'],
            ['calendar', 'Anniversary'],
          ].map(([icon, label]) => (
            <span key={label} style={{
              display: 'flex', alignItems: 'center', gap: 6,
              ...TYPE.footnote, color: c.textSecondary, fontWeight: 600,
              padding: '6px 12px 6px 10px', borderRadius: NOBS.r.full,
              background: c.surfaceAlt,
            }}>
              <Icon name={icon} size={14} color={c.textSecondary} />
              {label}
            </span>
          ))}
        </div>

        {/* metadata card */}
        <GroupedList dark={dark} header="Details">
          <GroupedRow icon="shield" iconColor={NOBS.brand.sage}  title="Encryption"     value="AES-256"      chevron={false} dark={dark} />
          <GroupedRow icon="server" iconColor={NOBS.brand.blue}  title="Stored on"      value="nobs.local"   chevron={false} dark={dark} />
          <GroupedRow icon="link"   iconColor={NOBS.brand.amber} title="Linked"         value="3 memories"   dark={dark} />
          <GroupedRow icon="clock"  iconColor={NOBS.brand.amber} title="Edited"         value="2 days ago"   chevron={false} dark={dark} isLast />
        </GroupedList>

        <div style={{ height: 16 }} />

        <GroupedList dark={dark} header="Related memories">
          <GroupedRow icon="memory" iconColor={NOBS.brand.amber} title="Sarah\u2019s anniversary is June 14" dark={dark} />
          <GroupedRow icon="memory" iconColor={NOBS.brand.amber} title="She prefers Nopa for dinners"        dark={dark} isLast />
        </GroupedList>

        <div style={{ height: 24 }} />

        <GroupedList dark={dark}>
          <GroupedRow icon="trash" iconColor={NOBS.brand.rose} title="Delete memory" danger dark={dark} isLast />
        </GroupedList>
      </div>
    </ScreenShell>
  );
}

// ════════════════════════════════════════════════════════════════
// 9. HomeKit quick sheet (bottom sheet over Tools)
// ════════════════════════════════════════════════════════════════
function HomeKitSheet({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const dim = dark ? 'rgba(0,0,0,0.5)' : 'rgba(60,40,20,0.35)';
  const devices = [
    { name: 'Kitchen',   sub: 'Lights · 80%',  icon: 'sun',    on: true,  tint: NOBS.brand.amber },
    { name: 'Front door', sub: 'Locked',       icon: 'lock',   on: true,  tint: NOBS.brand.sage },
    { name: 'Office',     sub: 'Lights · Off', icon: 'sun',    on: false, tint: NOBS.brand.amber },
    { name: 'Thermostat', sub: '21° · Auto',   icon: 'home',   on: true,  tint: NOBS.brand.amber },
    { name: 'Garage',     sub: 'Closed',       icon: 'shield', on: true,  tint: NOBS.brand.sage },
    { name: 'Garden',     sub: 'Watering',     icon: 'leaf',   on: true,  tint: NOBS.brand.sage },
  ];

  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      fontFamily: NOBS.font, color: c.text,
      // Dimmed Tools backdrop, simulated
      background: dim,
    }}>
      {/* faint blurred Tools backdrop */}
      <div style={{
        position: 'absolute', inset: 0, opacity: dark ? 0.35 : 0.45,
        background: c.bg, filter: 'blur(8px)',
      }} />

      {/* Sheet */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: c.bg,
        borderTopLeftRadius: NOBS.r['3xl'], borderTopRightRadius: NOBS.r['3xl'],
        boxShadow: '0 -20px 50px rgba(0,0,0,0.18)',
        padding: '12px 0 30px',
        maxHeight: '88%', display: 'flex', flexDirection: 'column',
      }}>
        {/* grabber */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '6px 0 14px' }}>
          <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? '#3C3631' : '#D6CFC4' }} />
        </div>

        <div style={{ padding: '0 20px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ ...TYPE.title2, color: c.text }}>HomeKit</div>
            <div style={{ ...TYPE.subhead, color: c.textSecondary, marginTop: 2 }}>8 devices · 6 active</div>
          </div>
          <NavIconButton name="plus" dark={dark} tinted />
        </div>

        <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {devices.map((d) => (
            <div key={d.name} style={{
              background: d.on ? c.surface : c.surfaceAlt,
              borderRadius: NOBS.r['2xl'], padding: 16,
              display: 'flex', flexDirection: 'column', gap: 16,
              boxShadow: d.on ? c.shadow : 'none',
              border: dark ? `0.5px solid ${c.border}` : 'none',
              opacity: d.on ? 1 : 0.65,
            }}>
              <div style={{
                width: 38, height: 38, borderRadius: 19,
                background: d.on ? d.tint : (dark ? c.surfaceAlt : '#EAE4DA'),
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: d.on ? `0 4px 12px ${d.tint}55` : 'none',
              }}>
                <Icon name={d.icon} size={20} color={d.on ? '#fff' : c.textTertiary} strokeWidth={1.8} />
              </div>
              <div>
                <div style={{ ...TYPE.subhead, color: c.text, fontWeight: 600 }}>{d.name}</div>
                <div style={{ ...TYPE.footnote, color: c.textTertiary, marginTop: 2 }}>{d.sub}</div>
              </div>
            </div>
          ))}
        </div>

        <div style={{ flex: 1 }} />
        {/* home indicator */}
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 18 }}>
          <div style={{ width: 139, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.2)' }} />
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenShell, MemoriesScreen, TasksScreen, OnboardingScreen, SettingsScreen, MoreScreen, WelcomeScreen,
  EmptyMemoriesScreen, AddMemoryScreen, MemoryDetailScreen, HomeKitSheet,
});