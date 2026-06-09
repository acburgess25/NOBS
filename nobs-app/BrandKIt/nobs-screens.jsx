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
  const logs = [
    { tag: 'Diet', date: 'Just now', body: 'Logged lunch: Grilled salmon salad with avocado and wild rice. Est. 540 kcal, 42g protein, 15g carbs. Macro goals are 68% completed.', pinned: true },
    { tag: 'Meds', date: '8:15 AM', body: 'Morning prescription doses taken: Losartan 50mg (Blood Pressure) & Multivitamin. HealthKit synced.' },
    { tag: 'Wellness', date: 'Yesterday', body: 'Eye strain alert: Screen time exceeded 3 hours. Took a clinical 20-20-20 rule break (20 seconds looking 20 feet away).' },
    { tag: 'Wellness', date: 'May 17', body: 'Sleep quality rating: 88%. Logged 7h 45m sleep. Resting heart rate stable at 62 bpm.' },
  ];
  return (
    <ScreenShell dark={dark} tabActive="memories" footer={
      <div style={{ padding: '10px 0 14px' }}>
        <ComposeBar dark={dark} placeholder="Log meal, symptom, or ask NOBS AI…" />
      </div>
    }>
      <NobsNavBar
        title="Health"
        subtitle="Secure local health vault"
        dark={dark}
        trailing={
          <>
            <NavIconButton name="search" dark={dark} />
            <NavIconButton name="plus" dark={dark} tinted />
          </>
        }
      />
      <div style={{ padding: '4px 20px 12px' }}>
        <SegmentedToggle dark={dark} options={['All', 'Meds', 'Wellness', 'Diet']} value="All" />
      </div>
      
      {/* Top dashboard widget: Screen time eye strain rest */}
      <div style={{ padding: '4px 16px 14px' }}>
        <ScreenTimeMeter hours={2.4} limit={4.0} rule202020="12 min until 20-20-20 break" dark={dark} />
      </div>

      <div style={{ padding: '8px 16px 4px' }}>
        <SectionHeader dark={dark}>Today's Logs</SectionHeader>
      </div>
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {logs.slice(0, 2).map((m, i) => <MemoryCard key={i} {...m} dark={dark} />)}
      </div>
      <div style={{ padding: '20px 16px 4px' }}>
        <SectionHeader dark={dark}>Earlier this week</SectionHeader>
      </div>
      <div style={{ padding: '0 16px 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {logs.slice(2).map((m, i) => <MemoryCard key={i} {...m} dark={dark} />)}
      </div>
    </ScreenShell>
  );
}
const HealthOverviewScreen = MemoriesScreen;

// ════════════════════════════════════════════════════════════════
// 2. Medications
// ════════════════════════════════════════════════════════════════
function TasksScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const pending = [
    { title: 'Lipitor 20mg (Cholesterol)',    due: '9:00 PM',  tag: 'Meds', priority: true },
    { title: 'Magnesium Glycinate 400mg',     due: '10:00 PM', tag: 'Meds' },
  ];
  const completed = [
    { title: 'Losartan 50mg (Blood Pressure)', tag: 'Meds', done: true, due: '8:00 AM' },
    { title: 'Vitamin D3 2000IU (Supplement)', tag: 'Meds', done: true, due: '8:00 AM' },
  ];
  return (
    <ScreenShell dark={dark} tabActive="tasks" footer={
      <div style={{ padding: '10px 0 14px' }}>
        <ComposeBar dark={dark} placeholder="Add a medication…" />
      </div>
    }>
      <NobsNavBar
        title="Meds"
        subtitle="2 doses remaining today"
        dark={dark}
        trailing={<>
          <NavIconButton name="calendar" dark={dark} />
          <NavIconButton name="plus" dark={dark} tinted />
        </>}
      />
      <div style={{ padding: '4px 20px 16px' }}>
        <SegmentedToggle dark={dark} options={['Today', 'Schedule', 'History']} value="Today" />
      </div>
      <div style={{ padding: '0 16px' }}>
        <SectionHeader dark={dark} action="Logs">Pending Doses</SectionHeader>
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
        <SectionHeader dark={dark}>Taken Doses</SectionHeader>
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
const MedsScreen = TasksScreen;

// ════════════════════════════════════════════════════════════════
// 3. Onboarding (step 2 of 5 shown — private storage)
// ════════════════════════════════════════════════════════════════
function OnboardingScreen({ dark = false, step = 2 }) {
  const c = dark ? NOBS.dark : NOBS.light;
  const steps = [
    {
      icon: 'leaf',
      title: 'Private health AI',
      body: 'NOBS is your local-first health assistant. It runs entirely on-device and never sends your medical logs to the cloud.',
    },
    {
      icon: 'shield',
      title: 'Encrypted health vault',
      body: 'Everything you track — prescription times, screen usage, meal logs — is encrypted with a key only you hold.',
    },
    {
      icon: 'heart',
      title: 'Apple Health integration',
      body: 'Syncs seamlessly with Apple Health and Siri AI commands, providing a unified view of your vitals and activity.',
    },
    {
      icon: 'clock',
      title: 'Digital eye rest & wellness',
      body: 'Tracks screen time limits and prompts you with the clinical 20-20-20 rule to reduce cognitive overload and eye strain.',
    },
    {
      icon: 'sparkle',
      title: 'On-device AI coach',
      body: 'Ask diet questions, review wellness trends, and plan meals without sacrificing your personal data privacy.',
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
            background: `radial-gradient(circle, ${dark ? 'rgba(250,92,92,0.18)' : 'rgba(250,92,92,0.22)'}, transparent 70%)`,
            filter: 'blur(8px)',
          }} />
          <div style={{
            position: 'relative', width: 168, height: 168, borderRadius: 44,
            background: `linear-gradient(155deg, #FB7185 0%, ${NOBS.brand.amber} 55%, ${NOBS.brand.amberDeep})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 18px 40px rgba(250,92,92,0.32), inset 0 1px 0 rgba(255,255,255,0.3)',
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
            boxShadow: '0 4px 12px rgba(250,92,92,0.3)',
          }}>JM</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...TYPE.headline, color: c.text }}>Jordan Maris</div>
            <div style={{ ...TYPE.footnote, color: c.textSecondary, marginTop: 2, display: 'flex', alignItems: 'center', gap: 5 }}>
              <Icon name="server" size={12} color={NOBS.brand.sage} />
              nobs.local · 184 health logs
            </div>
          </div>
          <Icon name="chevronRight" size={18} color={c.textTertiary} strokeWidth={2.2} />
        </div>
      </div>

      <GroupedList dark={dark} header="Privacy & security">
        <GroupedRow icon="shield" iconColor={NOBS.brand.sage} title="Encryption" detail="AES-256" dark={dark} />
        <GroupedRow icon="lock"   iconColor={NOBS.brand.amber} title="Face ID lock" switchOn={true} dark={dark} />
        <GroupedRow icon="eye"    iconColor={NOBS.brand.amber} title="Health logs visibility" detail="Private" dark={dark} />
        <GroupedRow icon="wifi"   iconColor={NOBS.brand.blue}  title="Local network only" switchOn={true} dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Appearance">
        <GroupedRow icon={dark ? 'moon' : 'sun'} iconColor={NOBS.brand.amber} title="Theme" value={dark ? 'Dark' : 'Light'} dark={dark} />
        <GroupedRow icon="sparkle" iconColor={NOBS.brand.amber} title="Accent" value="Rose Pulse" dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Data">
        <GroupedRow icon="download" iconColor={NOBS.brand.sage} title="Export everything" dark={dark} />
        <GroupedRow icon="cloud"    iconColor={NOBS.brand.blue} title="Backup to home server" detail="Daily" dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Danger zone" footer="Deleting your health logs is irreversible. NOBS keeps no copies — your data remains yours.">
        <GroupedRow icon="trash" iconColor={NOBS.brand.rose} title="Delete all health logs" danger dark={dark} />
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
// 5. More / Tools (Health Tools)
// ════════════════════════════════════════════════════════════════
function MoreScreen({ dark = false }) {
  const c = dark ? NOBS.dark : NOBS.light;
  return (
    <ScreenShell dark={dark} tabActive="more">
      <NobsNavBar title="Health Tools" subtitle="On-device diagnostics & sync" dark={dark} />

      <GroupedList dark={dark} header="Clinical & Vitals">
        <GroupedRow icon="heart"    iconColor={NOBS.brand.rose}  title="Apple HealthKit Sync" detail="Active" dark={dark} />
        <GroupedRow icon="leaf"     iconColor={NOBS.brand.sage}  title="Diet & Nutrition Coach" detail="Offline Model" dark={dark} />
        <GroupedRow icon="eye"      iconColor={NOBS.brand.blue}  title="Eye Strain Rest breaks" detail="20-20-20 rule" dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Schedules & Reminders">
        <GroupedRow icon="bell"     iconColor={NOBS.brand.amber} title="Medication Reminders"  detail="1 pending"   dark={dark} />
        <GroupedRow icon="calendar" iconColor={NOBS.brand.sage}  title="Wellness Calendar"   detail="Synced"    dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 24 }} />

      <GroupedList dark={dark} header="Device & Integrations">
        <GroupedRow icon="sparkle"  iconColor={NOBS.brand.amber} title="Siri AI voice commands" detail="Active"     dark={dark} />
        <GroupedRow icon="folder"   iconColor={NOBS.brand.amber} title="iCloud health folder"                  dark={dark} />
        <GroupedRow icon="link"     iconColor={NOBS.brand.blue}  title="Connected apps"      value="6"         dark={dark} isLast />
      </GroupedList>

      <div style={{ height: 32 }} />
    </ScreenShell>
  );
}
const HealthToolsScreen = MoreScreen;

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
            Private personal health AI.<br/>No cloud. No compromise.
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
        <ComposeBar dark={dark} placeholder="Tell NOBS something to log…" />
      </div>
    }>
      <NobsNavBar
        title="Health Logs"
        subtitle="Encrypted on your network"
        dark={dark}
        trailing={<NavIconButton name="plus" dark={dark} tinted />}
      />
      <div style={{ padding: '4px 20px 12px' }}>
        <SegmentedToggle dark={dark} options={['All', 'Meds', 'Wellness', 'Diet']} value="All" />
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 32px' }}>
        <div style={{ position: 'relative', marginBottom: 28 }}>
          {/* outer soft glow */}
          <div style={{
            position: 'absolute', inset: -18, borderRadius: 44,
            background: dark ? 'rgba(250,92,92,0.16)' : 'rgba(250,92,92,0.20)',
            filter: 'blur(12px)',
          }} />
          <div style={{
            position: 'relative', width: 104, height: 104, borderRadius: 28,
            background: `linear-gradient(155deg, #FB7185 0%, ${NOBS.brand.amber} 60%, ${NOBS.brand.amberDeep})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 12px 28px rgba(250,92,92,0.28), inset 0 1px 0 rgba(255,255,255,0.3)',
          }}>
            <Icon name="memory" size={48} color="#fff" strokeWidth={1.5} />
          </div>
        </div>
        <div style={{ ...TYPE.title2, color: c.text, textAlign: 'center', marginBottom: 10 }}>
          A blank slate
        </div>
        <div style={{ ...TYPE.body, color: c.textSecondary, textAlign: 'center', textWrap: 'pretty', maxWidth: 280 }}>
          Meds, wellness activities, nutrition logs.
          Capture your first health entry below and NOBS will save it &mdash; privately.
        </div>
        <div style={{ marginTop: 32, display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'stretch', width: '100%', maxWidth: 300 }}>
          {[
            'Took morning dose of Losartan 50mg',
            'Logged grilled chicken salad for lunch',
            'Completed 20-20-20 rule eye rest break',
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
        <div style={{ ...TYPE.headline, color: c.text }}>New health log</div>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: NOBS.brand.amber, ...TYPE.headline, fontWeight: 700, fontFamily: NOBS.font, padding: 0,
        }}>Save</button>
      </div>

      {/* tag select */}
      <div style={{ padding: '4px 20px 12px', display: 'flex', gap: 8 }}>
        {[
          ['Diet',     NOBS.brand.amber, dark ? NOBS.brand.amberTintD : NOBS.brand.amberTint, true],
          ['Meds',     NOBS.brand.sage,  dark ? NOBS.brand.sageTintD  : NOBS.brand.sageTint, false],
          ['Wellness', NOBS.brand.blue,  dark ? 'rgba(13,148,136,0.18)' : 'rgba(13,148,136,0.12)', false],
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
          Logged lunch: Grilled salmon salad with avocado and wild rice.
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
          borderRadius: NOBS.r.lg, border: `1px dashed ${dark ? 'rgba(250,92,92,0.4)' : 'rgba(250,92,92,0.4)'}`,
        }}>
          <Icon name="sparkle" size={18} color={NOBS.brand.amber} />
          <div style={{ flex: 1, ...TYPE.subhead, color: c.textSecondary, lineHeight: '20px' }}>
            <span style={{ fontWeight: 700, color: NOBS.brand.amberDeep }}>NOBS · </span>
            Want me to add 42g of protein and 15g of carbs to your daily macro goals?
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
        <div style={{ ...TYPE.footnote, color: c.textTertiary }}>64 / 280</div>
      </div>

      <IOSKeyboard dark={dark} />
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// 8. Memory Detail (Health Log Detail)
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
          Health Logs
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
          }}>Diet</span>
          <div style={{ ...TYPE.footnote, color: c.textTertiary }}>Today · 12:45 pm</div>
        </div>
        <div style={{ ...TYPE.title2, color: c.text, lineHeight: '30px', marginBottom: 18, textWrap: 'pretty' }}>
          Logged lunch: Grilled salmon salad with avocado and wild rice. Est. 540 kcal, 42g protein, 15g carbs. Macro goals are 68% completed.
        </div>

        {/* extracted entities */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 24 }}>
          {[
            ['heart', 'Salmon Salad'],
            ['sparkle', '42g Protein'],
            ['leaf', '540 kcal'],
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
          <GroupedRow icon="server" iconColor={NOBS.brand.blue}  title="Stored on"      value="nobs.local"  chevron={false} dark={dark} />
          <GroupedRow icon="link"   iconColor={NOBS.brand.amber} title="Linked logs"    value="2 entries"    dark={dark} />
          <GroupedRow icon="clock"  iconColor={NOBS.brand.amber} title="Edited"         value="Just now"     chevron={false} dark={dark} isLast />
        </GroupedList>

        <div style={{ height: 16 }} />

        <GroupedList dark={dark} header="Related health logs">
          <GroupedRow icon="memory" iconColor={NOBS.brand.amber} title="Morning dose of Losartan 50mg" dark={dark} />
          <GroupedRow icon="memory" iconColor={NOBS.brand.amber} title="Wellness score: 92%"          dark={dark} isLast />
        </GroupedList>

        <div style={{ height: 24 }} />

        <GroupedList dark={dark}>
          <GroupedRow icon="trash" iconColor={NOBS.brand.rose} title="Delete health log" danger dark={dark} isLast />
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