import { useEffect, useState } from "react";
import {
  ArrowRight,
  Check,
  Cloud,
  DeviceMobile,
  Copy,
  GithubLogo,
  HardDrives,
  Heart,
  List,
  LockKey,
  Monitor,
  Repeat,
  X,
} from "@phosphor-icons/react";

const githubUrl = "https://github.com/acburgess25/NOBS";
const testflightUrl = "";
const betaLive = Boolean(testflightUrl);

const navItems = [
  ["Vision", "vision"],
  ["Architecture", "architecture"],
  ["Work", "work"],
  ["Roadmap", "roadmap"],
  ["Support", "support"],
];

const milestones = [
  {
    label: "iPhone app",
    detail: "Chat-first SwiftUI shell with onboarding, Today briefing, widgets, and visible Local/Tank routing.",
    icon: DeviceMobile,
  },
  {
    label: "Day surface",
    detail: "Home Screen and Lock Screen plan widget, Siri shortcuts, Focus-aware priorities, evening wrap-up.",
    icon: DeviceMobile,
  },
  {
    label: "Tank agent",
    detail: "Allowlisted tools only. State changes wait for your approve or deny — atomic and audited.",
    icon: HardDrives,
  },
  {
    label: "Room dashboard",
    detail: "Always-on status for a shared screen. Private details stay on the phone.",
    icon: Monitor,
  },
  {
    label: "Local contract",
    detail: "Token-authenticated boundary. Anonymous requests rejected. Keys in the Keychain.",
    icon: LockKey,
  },
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
            <p className="hero-tagline">Your technology. Finally working for you.</p>
            <p className="hero-lede">
              A local-first personal assistant for Apple devices — realistic daily plans without turning your life into someone else’s dataset.
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

        <section className="architecture band" id="architecture" data-reveal>
          <div className="band-intro">
            <p className="eyebrow">Architecture</p>
            <h2>Local, by design.</h2>
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
              <p>Optional capacity when Tank is away — never silently required.</p>
            </li>
          </ol>
          <p className="band-aside">You’re always in control.</p>
        </section>

        <section className="work band" id="work" data-reveal>
          <div className="band-intro split">
            <div>
              <p className="eyebrow">Work so far</p>
              <h2>What exists today</h2>
            </div>
            <p>Real progress. Plain language. No vaporware.</p>
          </div>
          <ul className="work-list">
            {milestones.map(({ label, detail, icon: Icon }) => (
              <li key={label}>
                <Icon />
                <div>
                  <h3>{label}</h3>
                  <p>{detail}</p>
                </div>
              </li>
            ))}
          </ul>
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
            <p>I document decisions, share code as it’s ready, and welcome thoughtful feedback.</p>
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
