const root = document.documentElement;
root.dataset.theme = "dark"; // Force premium dark mode

function initQRCode() {
  const container = document.getElementById("qrcode");
  if (!container) return;
  // If we are on localhost, recommend tank.local or the actual IP
  const hostname = window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1" 
    ? "tank.local" 
    : window.location.hostname;
  
  const pairingUri = `nobs://pair?device=${hostname}`;
  new QRCode(container, {
    text: pairingUri,
    width: 72,
    height: 72,
    colorDark : "#101510",
    colorLight : "#ffffff",
    correctLevel : QRCode.CorrectLevel.L
  });
}

function setText(id, value) {
  document.getElementById(id).textContent = value;
}

function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (days) return `${days}d ${hours}h`;
  if (hours) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function updateClock() {
  const now = new Date();
  setText("clock-time", now.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }));
  setText("clock-date", now.toLocaleDateString([], { weekday: "long", month: "short", day: "numeric" }));
}

async function refresh() {
  const connection = document.getElementById("connection-state");
  try {
    const response = await fetch("/dashboard/status", { cache: "no-store" });
    if (!response.ok) throw new Error("Dashboard status unavailable");
    const data = await response.json();
    setText("display-name", data.display_name);
    setText("privacy-copy", data.privacy);
    setText("api-state", data.services.api.status);
    setText("ollama-state", data.services.ollama.status.replace("_", " "));
    setText("model-name", data.services.ollama.model);
    setText("uptime", formatUptime(data.system.uptime_seconds));
    setText("disk-free", `${data.system.disk_free_gb} GB`);
    setText("disk-used", `${data.system.disk_used_percent}% used`);
    setText("pending-approvals", data.agent.pending_approvals);
    setText("runs-count", data.agent.runs_24h);
    setText("completed-count", data.agent.completed_24h);
    setText("load-value", data.system.load_1m ?? "—");
    for (const context of ["personal", "business", "shared"]) {
      const count = data.workspaces[context];
      setText(`${context}-count`, `${count} item${count === 1 ? "" : "s"}`);
    }
    const attention = data.attention[0];
    const panel = document.querySelector(".attention-panel");
    panel.dataset.level = attention.level;
    setText("attention-heading", attention.title);
    setText("attention-detail", attention.detail);
    connection.textContent = "Live from Tank";
    setText("last-refresh", `Updated ${new Date(data.generated_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit", second: "2-digit" })}`);

    const gpu = data.gpu;
    if (gpu) {
      setText("gpu-utilization", `${gpu.utilization_percent}%`);
      setText("gpu-memory", `${(gpu.memory_used_mb / 1024).toFixed(1)} / ${(gpu.memory_total_mb / 1024).toFixed(1)} GB`);
      setText("gpu-temperature", `${gpu.temperature_c}°C`);
    } else {
      setText("gpu-utilization", "—");
      setText("gpu-memory", "— / — GB");
      setText("gpu-temperature", "—°C");
    }
  } catch {
    document.querySelector(".attention-panel").dataset.level = "urgent";
    setText("attention-heading", "Dashboard connection lost");
    setText("attention-detail", "This screen cannot reach Tank. It will keep trying automatically.");
    connection.textContent = "Reconnecting";
  }
}

function shiftForBurnIn() {
  const shell = document.querySelector(".dashboard");
  const offset = Math.floor(Date.now() / 120000) % 2 === 0 ? 0 : 1;
  shell.style.transform = `translate(${offset}px, ${offset}px)`;
}

initQRCode();
updateClock();
refresh();
shiftForBurnIn();
setInterval(updateClock, 1000);
setInterval(refresh, 15000);
setInterval(shiftForBurnIn, 120000);
