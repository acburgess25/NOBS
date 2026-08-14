import { useEffect, useState } from "react";
import {
  ArrowRight,
  Bug,
  ChatCircleDots,
  Check,
  Cloud,
  Code,
  Cpu,
  DeviceMobile,
  Copy,
  Flask,
  GithubLogo,
  HardDrives,
  Heart,
  HouseLine,
  List,
  PenNib,
  Prohibit,
  Repeat,
  Star,
  Wrench,
  X,
} from "@phosphor-icons/react";

const githubUrl = "https://github.com/acburgess25/NOBS";
const testflightUrl = "";
const betaLive = Boolean(testflightUrl);

const navItems = [
  ["Why", "why"],
  ["Status", "work"],
  ["How", "architecture"],
  ["Roadmap", "roadmap"],
  ["Contribute", "contribute"],
  ["Support", "support"],
];

const whyStats = [
  ["$240/yr", "renting ChatGPT Plus, forever", "https://www.wheresyoured.at/openai-projects-chatgpt-plus-subscriptions-to-drop-by-80-from-44-million-in-2025-to-9-million-in-2026-made-up-using-cheaper-subscriptions-somehow/"],
  ["~$50–150/yr", "electricity to run local models hard", "https://codersera.com/blog/cheapest-way-to-run-local-llm-2026/"],
  ["52M", "Ollama downloads a month, early 2026", "https://gudz.ai/posts/local-ai-llm-tools-2026"],
];

const statusGroups = [
  {
    tag: "Works today",
    className: "works",
    icon: Check,
    note: "Running, tested, in the repo now.",
    items: [
      ["Tank — a server on your own PC or Mac", "FastAPI + Ollama chat with a tool-using agent, restricted to an allowlisted tool registry."],
      ["Approval-gated actions", "Every state change waits in a stored, atomic, non-replayable approval queue, with a full audit log."],
      ["Separate Personal, Business, and Shared contexts", "They never silently mix."],
      ["Daily briefing with a privacy receipt", "Detects schedule conflicts and overloaded days, suggests reversible fixes."],
      ["Home Assistant bridge", "Any state change still creates an approval."],
      ["iPhone ↔ Tank pairing over Bonjour", "No port forwarding, no cloud account."],
      ["The iPhone app", "Conversational onboarding, Today, Memory, Activity, Home, and Privacy — plus Siri, widgets, and a Lock Screen approval Live Activity."],
      ["246 deterministic backend tests", "CI green on Linux, macOS, and Windows."],
    ],
  },
  {
    tag: "Built, being verified",
    className: "verifying",
    icon: Flask,
    note: "The code exists and passes tests; it isn't in your hands yet.",
    items: [
      ["TestFlight beta", "The app is simulator-verified. TestFlight is opening soon — it is not live yet."],
      ["NOBScloud paid fallback", "Coded (StoreKit 2 + Apple Private Cloud Compute routing), gated off pending an Apple entitlement. When live, it routes through Apple's infrastructure — there is no NOBS server farm, and there isn't going to be one."],
    ],
  },
  {
    tag: "Coming soon",
    className: "coming",
    icon: ArrowRight,
    note: "Designed and documented, not built. Not a promise with a date.",
    items: [
      ["Google Home and Alexa unification", "The Home Assistant bridge works today; those two ecosystems don't yet."],
      ["Tank Research Library", "Overnight research with citations."],
      ["Custom skill generation", "Tank drafts, sandboxes, and scans new integrations."],
      ["NOBSbox", "Plug-in home hardware."],
    ],
  },
];

const contributorRoles = [
  {
    label: "Swift / SwiftUI developers",
    detail: "The app is the front door. Widgets, Live Activities, App Intents — and especially accessibility: Dynamic Type, VoiceOver, reduced motion, non-color state indicators.",
    icon: DeviceMobile,
  },
  {
    label: "Python / FastAPI developers",
    detail: "Tank's agent, tool registry, and approval queue. 246 deterministic tests, CI green on three OSes. New tools need denial, replay, and path-boundary tests.",
    icon: Code,
  },
  {
    label: "Home Assistant people",
    detail: "The bridge works; every state change creates an approval. It needs real, messy, multi-vendor houses telling me where it breaks.",
    icon: HouseLine,
  },
  {
    label: "People with spare hardware",
    detail: "Tank must run well on Windows/WSL2 and Linux, not just the Mac I develop on. A box and an evening is genuinely one of the most useful gifts.",
    icon: Cpu,
  },
  {
    label: "Writers and designers",
    detail: "Docs, onboarding words, the visual system. Making privacy-first feel warm rather than paranoid is an unsolved design problem.",
    icon: PenNib,
  },
];

const smallAsks = [
  [Star, "Star the repo — it's how anything gets found"],
  [Bug, "Open an issue — including “your README made no sense”"],
  [Wrench, "Try the Tank setup and tell me where it hurt"],
  [ChatCircleDots, "Tell me what you'd want it to do"],
];

const neverList = [
  ["Never sell your data.", "No ads, no ad tier, no “anonymized insights,” no brokers."],
  ["Never sell your attention.", "Nothing here is optimized for engagement."],
  ["Never lock you in.", "Open source, open formats, export everything and walk."],
  ["Never touch passwords or financial accounts.", "Categorically off-limits. Not a setting."],
  ["Never act without approval.", "State changes are stored, approved, executed once, logged."],
  ["Never fake a feature.", "If it doesn't work, NOBS says so and offers what it can do."],
];

const roadmap = [
  ["Ship the public beta", "TestFlight with Today, Chat, widget, onboarding — Tank optional.", "in progress"],
  ["Connect the private Tank", "Authenticated local-network routing with honest offline fallback.", "shipped"],
  ["Personalize on Apple", "Onboarding, briefing widget, Focus priorities, Siri shortcuts.", "shipped"],
  ["Earn trust through action", "Agent proposes; you approve. Activity and review keep maturing.", "in progress"],
  ["Understand the day", "Morning briefing and evening wrap-up from calendar and reminders.", "in progress"],
  ["Grow without lock-in", "Optional cloud capacity while useful local features stay free.", "later"],
];

function goTo(id, done) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
  done?.();
}

function hasSupportLinks(links) {
  return Boolean(links?.githubSponsors || links?.donateOneTime || links?.donateMonthly || links?.supportInApp);
}

function cardProcessorLabel(links) {
  const processor = (links?.cardProcessor || "card").toLowerCase();
  if (processor === "square") return "Square";
  if (processor === "stripe") return "Stripe";
  return "card checkout";
}

export function App() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [openRoadmap, setOpenRoadmap] = useState(0);
  const [activeSection, setActiveSection] = useState("vision");
  const [supportLinks, setSupportLinks] = useState(null);
  const [heroReady, setHeroReady] = useState(false);

  useEffect(() => {
    const frame = requestAnimationFrame(() => setHeroReady(true));
    return () => cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    fetch("/support.json")
      .then((response) => (response.ok ? response.json() : {}))
      .then((data) => setSupportLinks(data))
      .catch(() => setSupportLinks({}));
  }, []);

  useEffect(() => {
    const sections = navItems.map(([, id]) => document.getElementById(id)).filter(Boolean);
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.find((entry) => entry.isIntersecting);
        if (visible) setActiveSection(visible.target.id);
      },
      { rootMargin: "-22% 0px -65%", threshold: 0 },
    );
    sections.forEach((section) => observer.observe(section));
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const targets = document.querySelectorAll("[data-reveal]");
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) entry.target.classList.add("is-visible");
        });
      },
      { rootMargin: "0px 0px -10%", threshold: 0.12 },
    );
    targets.forEach((target) => observer.observe(target));
    return () => observer.disconnect();
  }, [supportLinks]);

  const copyHealth = async () => {
    await navigator.clipboard?.writeText("curl -fsS http://tank.local:8000/health");
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  };

  const primaryCta = betaLive
    ? { href: testflightUrl, label: "Join the TestFlight beta", icon: DeviceMobile, external: true }
    : supportLinks?.donateOneTime
      ? { href: supportLinks.donateOneTime, label: "Send a tip", icon: Heart, external: true }
      : { href: githubUrl, label: "Follow the build", icon: GithubLogo, external: true };

  const PrimaryIcon = primaryCta.icon;

  return (
    <div className={`site-shell${heroReady ? " is-ready" : ""}`}>
      <div className="atmosphere" aria-hidden="true">
        <div className="atmosphere-wash atmosphere-wash-a" />
        <div className="atmosphere-wash atmosphere-wash-b" />
        <div className="atmosphere-grain" />
      </div>

      <header className="site-header">
        <a
          className="builder-mark"
          href="#vision"
          onClick={(event) => {
            event.preventDefault();
            goTo("vision");
          }}
        >
          <span className="mark-n" aria-hidden="true">N</span>
          <span className="mark-text">
            <em>Alexander Burgess</em>
            <strong>NOBS</strong>
          </span>
        </a>
        <nav className="desktop-nav" aria-label="Primary navigation">
          {navItems.map(([label, id]) => (
            <button className={activeSection === id ? "active" : ""} onClick={() => goTo(id)} key={id}>
              {label}
            </button>
          ))}
          <a className="icon-link" href={githubUrl} target="_blank" rel="noreferrer" aria-label="NOBS on GitHub">
            <GithubLogo weight="fill" />
          </a>
        </nav>
        <button
          className="menu-button"
          onClick={() => setMenuOpen((value) => !value)}
          aria-expanded={menuOpen}
          aria-label="Toggle menu"
        >
          {menuOpen ? <X /> : <List />}
        </button>
        {menuOpen && (
          <nav className="mobile-nav" aria-label="Mobile navigation">
            {navItems.map(([label, id]) => (
              <button onClick={() => goTo(id, () => setMenuOpen(false))} key={id}>
                {label}
              </button>
            ))}
            <a href={githubUrl} target="_blank" rel="noreferrer">
              View GitHub <ArrowRight />
            </a>
          </nav>
        )}
      </header>

      <main>
        <section className="hero" id="vision">
          <div className="hero-plane" aria-hidden="true" />
          <div className="hero-copy">
            <p className="hero-kicker">Private by default · Built in the open</p>
            <h1>NOBS</h1>
            <p className="hero-tagline">Stop renting your AI.</p>
            <p className="hero-lede">
              A private, local-first assistant that runs on a gaming PC or Mac you already own — no ads, no tracking, no subscription required for the core. Open source, built in public by one person.
            </p>
            <div className="hero-cta">
              <a
                className="btn-primary"
                href={primaryCta.href}
                {...(primaryCta.external ? { target: "_blank", rel: "noreferrer" } : {})}
              >
                <PrimaryIcon weight="fill" />
                {primaryCta.label}
                <ArrowRight />
              </a>
              <a className="btn-ghost" href={githubUrl} target="_blank" rel="noreferrer">
                <GithubLogo weight="fill" />
                GitHub
              </a>
            </div>
          </div>
          <div className="hero-visual">
            <img
              className="hero-phone"
              src="/nobs-app-preview.png"
              alt="NOBS iPhone app showing a private morning briefing"
              width="700"
              height="1520"
              fetchPriority="high"
              decoding="async"
            />
          </div>
        </section>

        <section className="why band" id="why" data-reveal>
          <div className="band-intro split">
            <div>
              <p className="eyebrow">Why</p>
              <h2>The math stopped making sense.</h2>
            </div>
            <p>Pay, or be the product. NOBS refuses both.</p>
          </div>
          <div className="stat-grid">
            {whyStats.map(([value, label, source]) => (
              <div className="stat-tile" key={value}>
                <strong>{value}</strong>
                <span>{label}</span>
                <a href={source} target="_blank" rel="noreferrer">
                  source
                </a>
              </div>
            ))}
          </div>
          <div className="why-copy">
            <p>
              ChatGPT Plus is $20 a month — $240 a year, forever, to rent a model on someone else’s computer. And OpenAI is{" "}
              <a href={whyStats[0][2]} target="_blank" rel="noreferrer">
                reportedly projecting
              </a>{" "}
              most of those subscribers moving to an $8/month <em>ad-supported</em> tier. The mainstream answer to “I don’t want to pay” is now: <em>then watch ads.</em>
            </p>
            <p>
              Meanwhile the alternative got genuinely good. Running a capable model at home stopped being a hobbyist stunt — a $500 GPU, or the Mac already on your desk, runs everyday models fine.
            </p>
            <p className="why-honest">
              The honest ceiling: for everyday drafting, planning, and coding help, a good local model holds its own. For the hardest reasoning and the longest documents, frontier cloud models are still ahead. I’m not going to pretend otherwise.
            </p>
          </div>
        </section>

        <section className="work band" id="work" data-reveal>
          <div className="band-intro split">
            <div>
              <p className="eyebrow">Status</p>
              <h2>Exactly where this is.</h2>
            </div>
            <p>Three labels. Nothing on this page gets a fourth.</p>
          </div>
          <div className="status-columns">
            {statusGroups.map(({ tag, className, icon: Icon, note, items }) => (
              <div className={`status-group ${className}`} key={tag}>
                <h3>
                  <span className={`status-tag ${className}`}>
                    <Icon weight="bold" aria-hidden="true" /> {tag}
                  </span>
                </h3>
                <p className="status-note">{note}</p>
                <ul>
                  {items.map(([label, detail]) => (
                    <li key={label}>
                      <strong>{label}</strong>
                      {detail && <span>{detail}</span>}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
          <button className="terminal" onClick={copyHealth} aria-live="polite">
            <div className="terminal-bar">
              <span>Tank API</span>
              <em>
                <b /> Healthy
              </em>
            </div>
            <code>
              {"GET   /health              200 OK\nPOST  /chat     (no token) 401\nPOST  /chat     (with key) 200 OK"}
            </code>
            <span className="terminal-copy">
              {copied ? <Check /> : <Copy />}
              {copied ? "Copied" : "Copy health check"}
            </span>
          </button>
        </section>

        <section className="architecture band" id="architecture" data-reveal>
          <div className="band-intro">
            <p className="eyebrow">How it works</p>
            <h2>Three pieces. That’s the whole architecture.</h2>
            <p>Your data stays with you. Extra processing only when you choose it.</p>
          </div>
          <ol className="system-flow">
            <li>
              <DeviceMobile />
              <h3>Local</h3>
              <p>Conversation and planning on your Apple devices.</p>
            </li>
            <li>
              <HardDrives />
              <h3>Tank</h3>
              <p>Your private server for heavier work on your network.</p>
            </li>
            <li>
              <Cloud />
              <h3>NOBScloud</h3>
              <p>Optional burst you approve — coded, gated off today. Never silently required.</p>
            </li>
          </ol>
          <p className="band-aside">
            Every response carries a Local, Tank, or cloud badge — tap it for a privacy receipt: what data was used, where it was processed, why.
          </p>
        </section>

        <section className="roadmap band" id="roadmap" data-reveal>
          <div className="band-intro split">
            <div>
              <p className="eyebrow">Roadmap</p>
              <h2>Where it goes next</h2>
            </div>
            <p>No fixed dates. Steady, honest progress.</p>
          </div>
          <div className="roadmap-list">
            {roadmap.map(([title, copy, status], index) => {
              if (title === "Ship the public beta") status = betaLive ? "shipped" : "in progress";
              const open = openRoadmap === index;
              return (
                <button
                  className={open ? "roadmap-item open" : "roadmap-item"}
                  onClick={() => setOpenRoadmap(open ? -1 : index)}
                  aria-expanded={open}
                  key={title}
                >
                  <span className="step">{status === "shipped" ? <Check weight="bold" /> : String(index + 1).padStart(2, "0")}</span>
                  <span className="roadmap-copy">
                    <strong>
                      {title}
                      <em className={`status-tag ${status.replace(" ", "-")}`}>{status}</em>
                    </strong>
                    {open && <span>{copy}</span>}
                  </span>
                  <span className="toggle" aria-hidden="true">
                    {open ? "−" : "+"}
                  </span>
                </button>
              );
            })}
          </div>
        </section>

        <section className="contribute band" id="contribute" data-reveal>
          <div className="band-intro split">
            <div>
              <p className="eyebrow">Contribute</p>
              <h2>I’m one person. This is where you’d come in.</h2>
            </div>
            <p>The repo is the whole truth — including the parts that don’t work.</p>
          </div>
          <ul className="work-list">
            {contributorRoles.map(({ label, detail, icon: Icon }) => (
              <li key={label}>
                <Icon />
                <div>
                  <h3>{label}</h3>
                  <p>{detail}</p>
                </div>
              </li>
            ))}
          </ul>
          <div className="ask-row">
            {smallAsks.map(([Icon, label]) => (
              <span className="ask-chip" key={label}>
                <Icon aria-hidden="true" /> {label}
              </span>
            ))}
          </div>
          <a className="closing-link" href={githubUrl} target="_blank" rel="noreferrer">
            <GithubLogo weight="fill" />
            <span>
              <strong>Start with docs/CURRENT_STATE.md</strong>
              <small>The honest implemented-vs-planned boundary, written for someone with zero context</small>
            </span>
            <ArrowRight />
          </a>
        </section>

        <section className="never band" data-reveal>
          <div className="band-intro">
            <p className="eyebrow">The short list</p>
            <h2>What NOBS will never do.</h2>
            <p>These aren’t preferences.</p>
          </div>
          <ul className="never-list">
            {neverList.map(([rule, detail]) => (
              <li key={rule}>
                <Prohibit aria-hidden="true" />
                <div>
                  <strong>{rule}</strong>
                  <span>{detail}</span>
                </div>
              </li>
            ))}
          </ul>
          <p className="band-aside">
            And the free part stays free: local chat, the daily briefing, privacy controls, and your own Tank hardware. Not free-tier-until-we-raise-a-round. Free.
          </p>
        </section>

        {hasSupportLinks(supportLinks) && (
          <section className="support band" id="support" data-reveal>
            <div className="band-intro">
              <p className="eyebrow">Support the build</p>
              <h2>Help NOBS stay local-first.</h2>
              <p>
                Optional tips fund open development. They do not unlock features. Local chat, briefing, and your own Tank stay free.
              </p>
            </div>
            <div className="support-grid">
              {supportLinks.donateOneTime && (
                <a className="support-tile support-tile-primary" href={supportLinks.donateOneTime} target="_blank" rel="noreferrer">
                  <Heart weight="fill" />
                  <span>
                    <strong>Send a tip</strong>
                    <small>One-time via {cardProcessorLabel(supportLinks)}</small>
                  </span>
                  <ArrowRight />
                </a>
              )}
              {supportLinks.donateMonthly && (
                <a className="support-tile" href={supportLinks.donateMonthly} target="_blank" rel="noreferrer">
                  <Repeat />
                  <span>
                    <strong>Support monthly</strong>
                    <small>Recurring via {cardProcessorLabel(supportLinks)}</small>
                  </span>
                  <ArrowRight />
                </a>
              )}
              {supportLinks.githubSponsors && (
                <a className="support-tile" href={supportLinks.githubSponsors} target="_blank" rel="noreferrer">
                  <GithubLogo weight="fill" />
                  <span>
                    <strong>Sponsor on GitHub</strong>
                    <small>Enable the listing if the link still redirects</small>
                  </span>
                  <ArrowRight />
                </a>
              )}
              {supportLinks.supportInApp && (
                <div className="support-tile support-tile-static">
                  <DeviceMobile />
                  <span>
                    <strong>In the NOBS app</strong>
                    <small>Privacy → Account &amp; support for Apple tips and NOBScloud</small>
                  </span>
                </div>
              )}
            </div>
          </section>
        )}

        <section className="closing band" data-reveal>
          <div>
            <p className="eyebrow">Built by Alexander Burgess</p>
            <h2>
              A personal project,
              <br />
              built in the open.
            </h2>
            <p>Your technology. Finally working for you. I document decisions, share code as it’s ready, and welcome thoughtful feedback.</p>
          </div>
          <a className="closing-link" href={githubUrl} target="_blank" rel="noreferrer">
            <GithubLogo weight="fill" />
            <span>
              <strong>Follow the build on GitHub</strong>
              <small>Code, roadmap, and latest progress</small>
            </span>
            <ArrowRight />
          </a>
        </section>
        <section className="fine-print" aria-label="Honest fine print">
          <h2>Fine print, but the honest kind</h2>
          <ul>
            <li>TestFlight is not live. The iPhone app is simulator-verified; “opening soon” is the accurate phrasing.</li>
            <li>NOBScloud is gated off pending an Apple entitlement. When it ships it means Apple’s Private Cloud Compute with an honest label — not NOBS-operated servers.</li>
            <li>Google Home and Alexa are not unified yet. The Home Assistant bridge is what works today.</li>
            <li>Support is a one-time tip link only for now.</li>
          </ul>
        </section>
      </main>

      <footer>
        <span>© 2026 Alexander Burgess</span>
        <button onClick={() => goTo("vision")}>Back to top ↑</button>
        <span>
          <a href="/privacy.html">Privacy</a> · nobsdash.com
        </span>
      </footer>
    </div>
  );
}
