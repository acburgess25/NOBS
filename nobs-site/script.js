const canvas = document.querySelector("#line-field");
const ctx = canvas.getContext("2d");
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

let width = 0;
let height = 0;
let points = [];
let lanes = [];
let pointer = { x: 0, y: 0, active: false };

function resize() {
  const scale = Math.min(window.devicePixelRatio || 1, 2);
  width = window.innerWidth;
  height = window.innerHeight;
  canvas.width = Math.floor(width * scale);
  canvas.height = Math.floor(height * scale);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  ctx.setTransform(scale, 0, 0, scale, 0, 0);

  const count = Math.max(38, Math.floor((width * height) / 28000));
  points = Array.from({ length: count }, (_, index) => ({
    x: (index * 181 + 37) % width,
    y: (index * 277 + 71) % height,
    vx: Math.sin(index * 1.9) * 0.18,
    vy: Math.cos(index * 1.4) * 0.15,
    r: 1 + (index % 4) * 0.28
  }));

  lanes = [
    { y: height * 0.18, speed: 0.42, hue: "13, 148, 136" },
    { y: height * 0.46, speed: -0.32, hue: "16, 185, 129" },
    { y: height * 0.74, speed: 0.26, hue: "250, 92, 92" }
  ];
}

function drawConnection(a, b, alpha, widthScale = 1) {
  const gradient = ctx.createLinearGradient(a.x, a.y, b.x, b.y);
  gradient.addColorStop(0, `rgba(13, 148, 136, ${alpha})`);
  gradient.addColorStop(0.55, `rgba(16, 185, 129, ${alpha * 0.72})`);
  gradient.addColorStop(1, `rgba(250, 92, 92, ${alpha * 0.46})`);
  ctx.strokeStyle = gradient;
  ctx.lineWidth = widthScale;
  ctx.beginPath();
  ctx.moveTo(a.x, a.y);
  ctx.lineTo(b.x, b.y);
  ctx.stroke();
}

function drawLane(lane, time) {
  const phase = (time * lane.speed * 0.035) % width;
  ctx.lineWidth = 1;

  for (let i = -1; i < 3; i += 1) {
    const start = i * width * 0.52 + phase;
    const end = start + width * 0.34;
    const y = lane.y + Math.sin(time / 1900 + i) * 18;
    const gradient = ctx.createLinearGradient(start, y, end, y);
    gradient.addColorStop(0, `rgba(${lane.hue}, 0)`);
    gradient.addColorStop(0.5, `rgba(${lane.hue}, 0.18)`);
    gradient.addColorStop(1, `rgba(${lane.hue}, 0)`);
    ctx.strokeStyle = gradient;
    ctx.beginPath();
    ctx.moveTo(start, y);
    ctx.bezierCurveTo(start + 90, y - 42, end - 110, y + 44, end, y);
    ctx.stroke();
  }
}

function tick(time) {
  ctx.clearRect(0, 0, width, height);

  for (const lane of lanes) {
    drawLane(lane, time);
  }

  for (const p of points) {
    if (!reduceMotion) {
      p.x += p.vx;
      p.y += p.vy;
    }

    if (p.x < -40) p.x = width + 40;
    if (p.x > width + 40) p.x = -40;
    if (p.y < -40) p.y = height + 40;
    if (p.y > height + 40) p.y = -40;
  }

  for (let i = 0; i < points.length; i += 1) {
    for (let j = i + 1; j < points.length; j += 1) {
      const a = points[i];
      const b = points[j];
      const distance = Math.hypot(a.x - b.x, a.y - b.y);

      if (distance < 142) {
        drawConnection(a, b, (1 - distance / 142) * 0.13);
      }
    }
  }

  if (pointer.active) {
    for (const p of points) {
      const distance = Math.hypot(pointer.x - p.x, pointer.y - p.y);

      if (distance < 240) {
        drawConnection(pointer, p, (1 - distance / 240) * 0.34, 1.2);
      }
    }
  }

  for (const p of points) {
    const pulse = reduceMotion ? 0.52 : 0.38 + Math.sin(time / 980 + p.x * 0.012) * 0.22;
    ctx.fillStyle = `rgba(52, 120, 246, ${pulse})`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
    ctx.fill();
  }

  if (!reduceMotion) {
    requestAnimationFrame(tick);
  }
}

window.addEventListener("resize", resize);
window.addEventListener("pointermove", (event) => {
  pointer = { x: event.clientX, y: event.clientY, active: true };
});
window.addEventListener("pointerleave", () => {
  pointer.active = false;
});

resize();
requestAnimationFrame(tick);

// Liquid Glass Transparency Slider
const slider = document.querySelector("#transparency-slider");
const valDisplay = document.querySelector("#transparency-val");
const phoneScreen = document.querySelector(".phone-screen");

if (slider && valDisplay && phoneScreen) {
  slider.addEventListener("input", (e) => {
    const val = e.target.value;
    valDisplay.textContent = `${val}%`;
    const opacity = val / 100;
    phoneScreen.style.setProperty("--glass-opacity", opacity);
  });
}
