const POLL_MS = 2500;

const floor = document.getElementById("floor-grid");
const agentsLayer = document.getElementById("agents-layer");
const screenGrid = document.getElementById("screen-grid");
const displayName = document.getElementById("display-name");
const privacyCopy = document.getElementById("privacy-copy");
const sessionPill = document.getElementById("session-pill");
const sessionLabel = document.getElementById("session-label");
const sandboxMeta = document.getElementById("sandbox-meta");

const stationPositions = new Map();

function renderStations(stations) {
  floor.innerHTML = "";
  stationPositions.clear();
  for (const station of stations) {
    stationPositions.set(station.id, station);
    const node = document.createElement("div");
    node.className = "station";
    node.style.left = `${station.x}%`;
    node.style.top = `${station.y}%`;
    const shape = document.createElement("div");
    shape.className = station.has_screen ? "monitor" : "desk";
    shape.dataset.station = station.id;
    node.appendChild(shape);
    const label = document.createElement("div");
    label.className = "station-label";
    label.textContent = station.label;
    node.appendChild(label);
    floor.appendChild(node);
  }
}

function renderAgents(agents) {
  const existing = new Map([...agentsLayer.children].map((node) => [node.dataset.agentId, node]));
  for (const agent of agents) {
    let node = existing.get(agent.id);
    if (!node) {
      node = document.createElement("div");
      node.className = "agent";
      node.dataset.agentId = agent.id;
      node.innerHTML = `
        <div class="agent-bubble"></div>
        <div class="agent-name"></div>
      `;
      agentsLayer.appendChild(node);
    }
    const station = stationPositions.get(agent.station) || { x: 50, y: 50 };
    node.style.left = `${station.x}%`;
    node.style.top = `${station.y}%`;
    const bubble = node.querySelector(".agent-bubble");
    bubble.textContent = agent.icon;
    bubble.style.background = agent.color;
    node.querySelector(".agent-name").textContent = agent.name;
    existing.delete(agent.id);
  }
  for (const stale of existing.values()) {
    stale.remove();
  }
    for (const stationNode of floor.querySelectorAll(".monitor")) {
    const id = stationNode.dataset.station;
    const active = agents.some(
      (agent) => agent.station === id && ["browsing", "sandboxing"].includes(agent.activity),
    );
    stationNode.classList.toggle("active", active);
  }
}

function renderScreens(screens) {
  screenGrid.innerHTML = "";
  for (const screen of screens) {
    const card = document.createElement("article");
    card.className = `screen-card${screen.active ? "" : " empty"}`;
    const title = screen.active ? (screen.title || "Live monitor") : "Idle monitor";
    card.innerHTML = `<header>${title} · ${screen.station}</header>`;
    const img = document.createElement("img");
    img.alt = screen.active ? "Browser sandbox screenshot" : "Monitor idle";
    if (screen.screenshot_url) {
      img.src = `${screen.screenshot_url}?t=${Date.now()}`;
    }
    card.appendChild(img);
    screenGrid.appendChild(card);
  }
}

async function refresh() {
  try {
    const response = await fetch("/workplace/status");
    if (!response.ok) return;
    const payload = await response.json();
    displayName.textContent = payload.display_name || "Tank";
    privacyCopy.textContent = payload.privacy || "";
    renderStations(payload.stations || []);
    renderAgents(payload.agents || []);
    renderScreens(payload.screens || []);
    const dreamTeam = payload.dream_team;
    if (dreamTeam) {
      sessionPill.hidden = false;
      sessionLabel.textContent = `${dreamTeam.status}: ${dreamTeam.objective.slice(0, 48)}`;
    } else {
      sessionPill.hidden = true;
    }
    const domains = payload.browser_sandbox?.allowed_domains || [];
    sandboxMeta.textContent = `Allowlisted: ${domains.slice(0, 4).join(", ")}${domains.length > 4 ? "…" : ""}`;
  } catch (_error) {
    // Keep last good frame during transient network issues.
  }
}

refresh();
setInterval(refresh, POLL_MS);
