import { useEffect, useState } from "react";
import { ArrowRight, Check, Cloud, DeviceMobile, Copy, GithubLogo, HardDrives, Heart, List, LockKey, Monitor, Repeat, X } from "@phosphor-icons/react";

const githubUrl = "https://github.com/acburgess25/NOBS";
const navItems = [["Vision", "vision"], ["Work so far", "work"], ["Architecture", "architecture"], ["Roadmap", "roadmap"], ["Support", "support"]];
const milestones = [
  { label: "iPhone app (SwiftUI)", detail: "Authenticated chat with visible Local/Tank routing, day-at-a-glance, privacy receipts, and conversational onboarding.", icon: DeviceMobile },
  { label: "Apple-native day surface", detail: "Home Screen and Lock Screen briefing widget, Siri shortcuts, and Focus-aware planning that respects Do Not Disturb.", icon: DeviceMobile },
  { label: "Tank agent core", detail: "A local model with allowlisted tools. Nothing state-changing runs without explicit approval.", icon: HardDrives },
  { label: "Room-safe dashboard", detail: "Always-on status display for a shared screen—live on Tank today, private details stay on the phone.", icon: Monitor },
  { label: "Local-first contract", detail: "Token-authenticated boundary between devices. Anonymous requests are rejected, keys live in the Keychain.", icon: LockKey },
];
const roadmap = [
  ["Make the conversation real", "The iPhone app talks to a local model on Tank with clear processing receipts—no cloud in the loop.", "shipped"],
  ["Connect the private Tank", "Authenticated local-network routing with honest offline fallback when Tank is unreachable.", "shipped"],
  ["Personalize on Apple", "Conversational onboarding, briefing widget, Focus-aware priorities, clarifying notifications, and Siri shortcuts.", "shipped"],
  ["Earn trust through action", "The agent core proposes, you approve. Approvals queue is live; the in-app review screen is being built now.", "in progress"],
  ["Understand the day", "Scheduled daily briefing from calendar and reminders, with progressive permission prompts.", "in progress"],
  ["Grow without lock-in", "Optional cloud capacity and integrations while useful local features stay free.", "later"],
];

function goTo(id, done) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
  done?.();
}

function hasSupportLinks(links) {
  return Boolean(links?.githubSponsors || links?.donateOneTime || links?.donateMonthly);
}

export function App() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [openRoadmap, setOpenRoadmap] = useState(0);
  const [activeSection, setActiveSection] = useState("vision");
  const [supportLinks, setSupportLinks] = useState(null);

  useEffect(() => {
    fetch("/support.json")
      .then((response) => (response.ok ? response.json() : {}))
      .then((data) => setSupportLinks(data))
      .catch(() => setSupportLinks({}));
  }, []);

  useEffect(() => {
    const sections = navItems.map(([, id]) => document.getElementById(id)).filter(Boolean);
    const observer = new IntersectionObserver((entries) => {
      const visible = entries.find((entry) => entry.isIntersecting);
      if (visible) setActiveSection(visible.target.id);
    }, { rootMargin: "-22% 0px -65%", threshold: 0 });
    sections.forEach((section) => observer.observe(section));
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const targets = document.querySelectorAll(".section:not(.hero)");
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => entry.isIntersecting && entry.target.classList.add("in-view"));
    }, { rootMargin: "0px 0px -12%" });
    targets.forEach((target) => observer.observe(target));
    return () => observer.disconnect();
  }, []);

  const copyHealth = async () => {
    await navigator.clipboard?.writeText("curl -fsS http://tank.local:8000/health");
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="site-shell">
      <header className="site-header">
        <a className="builder-mark" href="#vision" onClick={(event) => { event.preventDefault(); goTo("vision"); }}>
          <span>Alexander Burgess</span><i>/</i><strong>Building NOBS</strong>
        </a>
        <nav className="desktop-nav" aria-label="Primary navigation">
          {navItems.map(([label, id]) => <button className={activeSection === id ? "active" : ""} onClick={() => goTo(id)} key={id}>{label}</button>)}
          <a className="icon-link" href={githubUrl} target="_blank" rel="noreferrer" aria-label="NOBS on GitHub"><GithubLogo weight="fill" /></a>
        </nav>
        <button className="menu-button" onClick={() => setMenuOpen((value) => !value)} aria-expanded={menuOpen} aria-label="Toggle menu">{menuOpen ? <X /> : <List />}</button>
        {menuOpen && <nav className="mobile-nav" aria-label="Mobile navigation">
          {navItems.map(([label, id]) => <button onClick={() => goTo(id, () => setMenuOpen(false))} key={id}>{label}</button>)}
          <a href={githubUrl} target="_blank" rel="noreferrer">View GitHub <ArrowRight /></a>
        </nav>}
      </header>

      <main>
        <section className="hero section" id="vision">
          <div className="hero-copy reveal">
            <div className="status-pill"><span /> In development</div>
            <p className="eyebrow">A personal project, built in the open</p>
            <h1>NOBS</h1>
            <h2>Your technology.<br />Finally working for you.</h2>
            <p className="lede">I’m building a private, local-first personal assistant for Apple devices—one that runs on your terms, keeps your context under your control, and helps make everyday technology genuinely useful.</p>
            <p className="honesty-note">This is an ongoing prototype. Everything here reflects real work so far, not a finished product.</p>
            <a className="primary-link" href={githubUrl} target="_blank" rel="noreferrer"><GithubLogo weight="fill" /> Follow the build on GitHub <ArrowRight /></a>
          </div>
          <div className="hero-art reveal" aria-label="Current NOBS iPhone prototype">
            <div className="phone-frame"><img src="/nobs-app-preview.png" alt="NOBS running in the iPhone 17 Pro Simulator with a private morning briefing" /></div>
            <div className="annotation annotation-one"><span>Rendered from the live SwiftUI build</span><i /></div>
            <div className="annotation annotation-two"><span>Processing stays visible</span><i /></div>
          </div>
          <div className="code-window reveal" aria-label="SwiftUI code excerpt">
            <div className="window-bar"><span /><span /><span /><b>ConversationView.swift</b></div>
            <pre><code><em>struct</em> MorningHighlight: View {`{`}{"\n"}  <em>var</em> body: some View {`{`}{"\n"}    Label(<q>Morning highlight</q>,{`\n`}      systemImage: <q>sun.max</q>){`\n`}  {`}`}{"\n"}{`}`}</code></pre>
          </div>
          <p className="code-note">SwiftUI, in progress</p>
        </section>

        <section className="architecture section" id="architecture">
          <div className="section-intro"><p className="eyebrow">Architecture</p><h2>Local, by design.</h2><p>NOBS is built around a simple principle: your data stays with you. More processing is available only when you choose it.</p></div>
          <div className="system-map">
            <article><div className="system-icon"><DeviceMobile /></div><h3>Local <span>(You)</span></h3><p>Conversation, planning, and permitted context on your Apple devices.</p><small>Preferred by default</small></article>
            <div className="connector"><span /><LockKey /></div>
            <article><div className="system-icon"><HardDrives /></div><h3>Tank <span>(Private)</span></h3><p>Your own server for heavier models, research, and household services.</p><small>Your network</small></article>
            <div className="connector"><span /><LockKey /></div>
            <article><div className="system-icon"><Cloud /></div><h3>NOBScloud <span>(Optional)</span></h3><p>Extra capacity when local hardware needs help—never silently required.</p><small>Your choice</small></article>
          </div>
          <p className="control-note">You’re always in control.</p>
        </section>

        <section className="work section" id="work">
          <div className="section-heading"><div><p className="eyebrow">Work so far</p><h2>What exists today</h2></div><p>Real progress, plain language, no vaporware.</p></div>
          <div className="milestone-grid">{milestones.map(({ label, detail, icon: Icon }) => <article className="milestone" key={label}><Icon /><div><h3>{label}</h3><p>{detail}</p></div></article>)}</div>
          <button className="health-card" onClick={copyHealth} aria-live="polite">
            <span className="health-title">Tank API <i>live</i></span><span className="health-status"><b /> Healthy</span>
            <code>{"GET   /health              200 OK\nPOST  /chat     (no token) 401\nPOST  /chat     (with key) 200 OK"}</code>
            <span className="copy-label">{copied ? <Check /> : <Copy />} {copied ? "Copied" : "Copy health check"}</span>
          </button>
        </section>

        <section className="roadmap section" id="roadmap">
          <div className="section-heading"><div><p className="eyebrow">Roadmap</p><h2>Where it goes next</h2></div><p>No fixed dates. Steady, honest progress.</p></div>
          <div className="roadmap-list">{roadmap.map(([title, copy, status], index) => {
            const open = openRoadmap === index;
            return <button className={open ? "roadmap-item open" : "roadmap-item"} onClick={() => setOpenRoadmap(open ? -1 : index)} aria-expanded={open} key={title}>
              <span className="step">{status === "shipped" ? <Check weight="bold" /> : `0${index + 1}`}</span>
              <span className="roadmap-copy"><strong>{title} <em className={`status-tag ${status.replace(" ", "-")}`}>{status}</em></strong>{open && <span>{copy}</span>}</span>
              <span className="toggle">{open ? "−" : "+"}</span>
            </button>;
          })}</div>
        </section>

        {hasSupportLinks(supportLinks) && (
          <section className="support section" id="support">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Support the build</p>
                <h2>Help NOBS stay local-first.</h2>
              </div>
              <p>Optional tips and sponsorships fund open development. Core features stay free; paid NOBScloud subscriptions will come through the App Store later.</p>
            </div>
            <div className="support-grid">
              {supportLinks.donateOneTime && (
                <a className="support-card" href={supportLinks.donateOneTime} target="_blank" rel="noreferrer">
                  <Heart weight="fill" />
                  <span>
                    <strong>Send a tip</strong>
                    <small>One-time contribution through Stripe.</small>
                  </span>
                  <ArrowRight />
                </a>
              )}
              {supportLinks.donateMonthly && (
                <a className="support-card" href={supportLinks.donateMonthly} target="_blank" rel="noreferrer">
                  <Repeat />
                  <span>
                    <strong>Support monthly</strong>
                    <small>Recurring sponsorship through Stripe.</small>
                  </span>
                  <ArrowRight />
                </a>
              )}
              {supportLinks.githubSponsors && (
                <a className="support-card" href={supportLinks.githubSponsors} target="_blank" rel="noreferrer">
                  <GithubLogo weight="fill" />
                  <span>
                    <strong>Sponsor on GitHub</strong>
                    <small>Follow the build and back the project there.</small>
                  </span>
                  <ArrowRight />
                </a>
              )}
            </div>
          </section>
        )}

        <section className="closing section">
          <div><p className="eyebrow">Built by Alexander Burgess</p><h2>This is a personal project,<br />built in the open.</h2><p>I document decisions, share code as it’s ready, and welcome thoughtful feedback.</p></div>
          <a className="github-card" href={githubUrl} target="_blank" rel="noreferrer"><GithubLogo weight="fill" /><span><strong>Follow the build on GitHub</strong><small>See the code, roadmap, and latest progress.</small></span><ArrowRight /></a>
        </section>
      </main>
      <footer><span>© 2026 Alexander Burgess</span><button onClick={() => goTo("vision")}>Back to top ↑</button><span>nobsdash.com</span></footer>
    </div>
  );
}
