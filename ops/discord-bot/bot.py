"""Tank AI Discord bot — thin wrapper over OpenHands API.

Each mapped channel has a persistent background watcher that pushes every new
OpenHands event to Discord as it appears, independent of user messages.
"""
import asyncio, json, logging, os, re, time
from pathlib import Path
import urllib.request, urllib.error
import discord

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("nobs")

OPENHANDS_URL = os.environ.get("OPENHANDS_URL", "http://openhands:3000")
ROUTER_URL    = os.environ.get("ROUTER_URL", "http://llm-router:8000")
OLLAMA_URL    = os.environ.get("OLLAMA_URL", "http://host.docker.internal:11434")
MEMORIES_URL  = os.environ.get("MEMORIES_URL", "http://memories-api:8090")
TOKEN         = os.environ["DISCORD_TOKEN"]
CHANNEL_IDS   = {int(x) for x in os.environ.get("CHANNEL_IDS","").split(",") if x.strip()}
STATE_FILE    = Path("/state/channel-conversations.json")
LAST_ID_FILE  = Path("/state/channel-last-event.json")
ALERTS_FILE    = Path("/state/budget-alerts.json")
SUMMARIES_FILE = Path("/state/summaries.jsonl")
SUMMARY_CURSOR = Path("/state/summary-cursor.json")
AUTOPILOT_DIR = Path(os.environ.get("AUTOPILOT_DIR", "/autopilot"))
AUTOPILOT_QUEUE = AUTOPILOT_DIR / "improvement-queue.jsonl"
AUTOPILOT_STATE = AUTOPILOT_DIR / "state.json"
AUTOPILOT_CURSOR = Path("/state/autopilot-cursor.json")
PROPOSAL_ACTIONS = Path("/state/proposal-actions.json")
APPROVED_QUEUE = AUTOPILOT_DIR / "approved-proposals.jsonl"
BUDGET_POLL_S = 300  # 5 minutes
BUDGET_THRESHOLDS = [(15, "🟡", "warning"), (20, "🟠", "alert"), (23, "🔴", "near-cap")]
DISCORD_LIMIT = 1900
POLL_S        = 3

def _load(p):
    if p.exists():
        try: return json.loads(p.read_text())
        except: return {}
    return {}

def _save(p, d):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(d, indent=2))

channel_conv = _load(STATE_FILE)
channel_last = _load(LAST_ID_FILE)
watchers: dict[str, asyncio.Task] = {}
proposal_actions = _load(PROPOSAL_ACTIONS)
approval_watchers: dict[str, asyncio.Task] = {}

def _start_bg(name, coro):
    task = asyncio.create_task(coro)
    def _done(t):
        try:
            exc = t.exception()
        except asyncio.CancelledError:
            log.info(f"{name} cancelled")
            return
        except Exception as ex:
            log.warning(f"{name} done-check error: {ex}")
            return
        if exc:
            log.warning(f"{name} crashed: {exc}")
        else:
            log.info(f"{name} exited")
    task.add_done_callback(_done)
    log.info(f"{name} started")
    return task

def _http(method, path, body=None, timeout=30):
    url = f"{OPENHANDS_URL}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                  headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def create_conversation(initial_msg):
    return _http("POST", "/api/conversations", {"initial_user_msg": initial_msg})

def send_message(cid, msg):
    return _http("POST", f"/api/conversations/{cid}/message", {"message": msg})

def get_events(cid, limit=100):
    return _http("GET", f"/api/conversations/{cid}/events?limit={limit}")

THINK_RE = re.compile(r"<think>.*?</think>\s*", re.DOTALL | re.IGNORECASE)
LEAD_GARBAGE_RE = re.compile(r"^[\s　-俿　\W_]{1,3}(?=[A-Za-z])")

def clean(text):
    text = THINK_RE.sub("", text)
    text = LEAD_GARBAGE_RE.sub("", text)
    return text.strip()

MCP_CALL_RE = re.compile(r"MCP server with name:\s*```\s*([^`]+?)\s*```.*?arguments:\s*```\s*(\{.*?\})\s*```", re.DOTALL)

def _summarize_mcp(msg):
    m = MCP_CALL_RE.search(msg or "")
    if not m: return None
    tool = m.group(1).strip()
    raw_args = m.group(2).strip()
    try:
        args = json.loads(raw_args.replace(chr(39), chr(34)))
    except Exception:
        args = {}
    hint = args.get("path") or args.get("pattern") or args.get("query") or args.get("name") or ""
    hint = str(hint)[:120]
    return f"🔧 `{tool}`" + (f" — {hint}" if hint else "")

def fmt_event(e):
    src = e.get("source","?")
    typ = e.get("action") or e.get("observation") or "msg"
    msg = (e.get("message") or e.get("content") or "")
    args = e.get("args",{}) if isinstance(e.get("args"),dict) else {}
    cmd  = args.get("command","")
    thought = args.get("thought","")
    if cmd:    return f"`$ {cmd[:300]}`"
    if e.get("observation") == "run":
        body = (e.get("content") or "").strip()
        ex = e.get("extras",{}).get("metadata",{}) if isinstance(e.get("extras"),dict) else {}
        code = ex.get("exit_code")
        head = f"exit={code}" if code is not None else "output"
        if not body: body = "(no output)"
        return f"```\n[{head}]\n" + body[:1500] + "\n```"
    if src == "agent" and typ == "message":
        cleaned = clean(msg)
        return cleaned[:1500] if cleaned else None
    if typ == "call_tool_mcp":
        out = _summarize_mcp(msg)
        if out: return out
    if typ == "think" and thought:
        return f"💭 _{thought[:600]}_"
    if typ == "edit":
        path = args.get("path","?")
        cmd = args.get("command","")
        ed_thought = args.get("thought","")
        verb = {"create":"📝 create","str_replace":"✏️ edit","insert":"➕ insert"}.get(cmd, f"📝 {cmd}")
        line = f"{verb} `{path}`"
        if ed_thought: line += f"\n_{ed_thought[:400]}_"
        return line
    if e.get("observation") == "edit":
        # observation comes after edit action; usually just "File created/edited successfully"
        body = (e.get("content") or "").strip()
        if body and "successfully" not in body.lower():
            return f"`{body[:200]}`"
        return None
    if typ == "finish":
        final = args.get("final_thought","") or args.get("message","")
        return f"🏁 **finished** — {final[:500]}" if final else "🏁 **finished**"
    if typ == "browse":
        url = args.get("url","")
        return f"🌐 browse `{url[:120]}`"
    extras = e.get("extras",{}) if isinstance(e.get("extras"),dict) else {}
    new_state = extras.get("agent_state","")
    if typ == "agent_state_changed" and new_state in ("finished","awaiting_user_input","error","stopped"):
        emoji = {"finished":"✅","awaiting_user_input":"💬","error":"⚠️","stopped":"⏹️"}.get(new_state,"•")
        return f"_{emoji} agent: {new_state}_"
    return None

async def send_long(channel, text):
    for i in range(0, max(len(text),1), DISCORD_LIMIT):
        chunk = text[i:i+DISCORD_LIMIT] or "(empty)"
        try:
            await channel.send(chunk)
        except Exception as ex:
            log.warning(f"send err: {ex}")
            break

def _read_json_file(path: Path):
    try:
        return json.loads(path.read_text())
    except Exception:
        return {}

def _proposal_line(rec):
    area = rec.get("area", "?")
    pri = rec.get("priority", "medium")
    title = rec.get("title", "Untitled")
    files = rec.get("files") or []
    mission = rec.get("mission", "")
    file_part = f"\n`{', '.join(files[:3])}`" if files else ""
    return f"**[{area}/{pri}] {title}**{file_part}\n{mission[:900]}"

def _load_recent_proposals(limit=5):
    if not AUTOPILOT_QUEUE.exists():
        return []
    lines = AUTOPILOT_QUEUE.read_text(errors="replace").splitlines()
    out = []
    for line in lines[-max(limit, 1):]:
        try:
            out.append(json.loads(line))
        except Exception:
            continue
    return out

def _save_actions():
    _save(PROPOSAL_ACTIONS, proposal_actions)

def _build_mission(rec):
    area = rec.get("area", "website")
    files = rec.get("files") or []
    repo_path = "/workspace/nobs-app" if area == "ios" else "/workspace/nobsdash-web"
    file_hint = ", ".join(files[:6]) if files else "(unspecified files)"
    return (
        f"Implement this approved {area} proposal in {repo_path}.\n\n"
        f"Title: {rec.get('title','Untitled')}\n"
        f"Mission: {rec.get('mission','')}\n"
        f"Target files: {file_hint}\n\n"
        "Constraints:\n"
        "- Make minimal safe edits only.\n"
        "- Validate by running relevant checks and summarizing what changed.\n"
        "- Do not expose secrets.\n"
        "- If blocked, report exact blocker."
    )

async def _handle_proposal_decision(message, rec, user_label, approved):
    message_id = str(message.id)
    action = proposal_actions.setdefault(
        message_id,
        {"status": "pending", "proposal": rec, "channel_id": message.channel.id},
    )
    if action.get("status") != "pending":
        return False

    action["handled_by"] = user_label
    action["handled_at"] = int(time.time())
    if not approved:
        action["status"] = "rejected"
        _save_actions()
        return True

    action["status"] = "approved"
    _save_actions()
    approved_rec = {
        "approved_at": int(time.time()),
        "approved_by": user_label,
        "proposal": rec,
    }
    try:
        with APPROVED_QUEUE.open("a") as f:
            f.write(json.dumps(approved_rec) + "\n")
    except Exception as ex:
        log.warning(f"approved queue write failed: {ex}")

    mission = _build_mission(rec)
    resp = await asyncio.to_thread(create_conversation, mission)
    cid = resp.get("conversation_id", "unknown")
    if cid != "unknown":
        key = f"{message.id}:{cid}"
        task = asyncio.create_task(
            watch_approved_job(message.channel.id, cid, rec.get("title", "approved-proposal"))
        )
        approval_watchers[key] = task
    return cid

async def reconcile_proposals():
    """Import existing proposal posts and backfill approvals from channel history."""
    for ch_id in CHANNEL_IDS or [int(x) for x in channel_conv.keys()]:
        try:
            ch = client.get_channel(int(ch_id)) or await client.fetch_channel(int(ch_id))
            async for msg in ch.history(limit=200):
                if msg.author != client.user:
                    continue
                if "New Tank Proposal" not in (msg.content or ""):
                    continue
                message_id = str(msg.id)
                if message_id not in proposal_actions:
                    lines = [line.strip() for line in (msg.content or "").splitlines() if line.strip()]
                    title = ""
                    if len(lines) > 1:
                        title = lines[1].strip("* ")
                    proposal_actions[message_id] = {
                        "status": "pending",
                        "proposal": {"title": title or f"proposal-{msg.id}", "mission": msg.content[:900]},
                        "channel_id": int(ch_id),
                        "source": "history-import",
                    }
                action = proposal_actions.get(message_id, {})
                if action.get("status") != "pending":
                    continue
                approved_by = None
                rejected_by = None
                for reaction in msg.reactions:
                    emoji = str(reaction.emoji)
                    if emoji not in ("✅", "❌"):
                        continue
                    users = []
                    async for u in reaction.users():
                        if u != client.user:
                            users.append(u)
                    if emoji == "✅" and users:
                        approved_by = users[0]
                        break
                    if emoji == "❌" and users:
                        rejected_by = users[0]
                rec = action.get("proposal", {})
                if approved_by:
                    try:
                        cid = await _handle_proposal_decision(msg, rec, str(approved_by), True)
                        if cid:
                            await msg.reply(f"Backfilled approval from {approved_by.mention}. Dispatched to Tank worker `{str(cid)[:8]}...`.")
                    except Exception as ex:
                        log.warning(f"proposal reconcile approve err: {ex}")
                elif rejected_by:
                    try:
                        changed = await _handle_proposal_decision(msg, rec, str(rejected_by), False)
                        if changed:
                            await msg.reply(f"Backfilled rejection from {rejected_by.mention}.")
                    except Exception as ex:
                        log.warning(f"proposal reconcile reject err: {ex}")
            _save_actions()
        except Exception as ex:
            log.warning(f"proposal reconcile err ch={ch_id}: {ex}")

async def autopilot_tailer():
    """Post new Tank Autopilot proposals into wired Discord channels."""
    cursor = _load(AUTOPILOT_CURSOR)
    pos = int(cursor.get("pos", 0))
    while True:
        await asyncio.sleep(20)
        try:
            if not AUTOPILOT_QUEUE.exists():
                continue
            size = AUTOPILOT_QUEUE.stat().st_size
            if size < pos:
                pos = 0
            if size == pos:
                continue
            with AUTOPILOT_QUEUE.open(errors="replace") as f:
                f.seek(pos)
                lines = f.readlines()
                pos = f.tell()
            proposals = []
            for line in lines:
                try:
                    proposals.append(json.loads(line))
                except Exception:
                    continue
            if proposals:
                for ch_id in CHANNEL_IDS or [int(x) for x in channel_conv.keys()]:
                    try:
                        ch = client.get_channel(int(ch_id)) or await client.fetch_channel(int(ch_id))
                        for rec in proposals[:12]:
                            post = "🧠 **New Tank Proposal**\n" + _proposal_line(rec) + "\n\nReact ✅ to approve, ❌ to reject."
                            msg = await ch.send(post[:DISCORD_LIMIT])
                            try:
                                await msg.add_reaction("✅")
                                await msg.add_reaction("❌")
                            except Exception:
                                pass
                            proposal_actions[str(msg.id)] = {
                                "status": "pending",
                                "proposal": rec,
                                "channel_id": int(ch_id),
                            }
                        _save_actions()
                    except Exception as ex:
                        log.warning(f"autopilot post err: {ex}")
            cursor["pos"] = pos
            _save(AUTOPILOT_CURSOR, cursor)
        except Exception as ex:
            log.warning(f"autopilot tailer err: {ex}")

async def tank_doctor_summary():
    checks = []
    for name, url in [
        ("memories-api", f"{MEMORIES_URL}/healthz"),
        ("llm-router", f"{ROUTER_URL}/healthz"),
        ("ollama", f"{OLLAMA_URL}/api/tags"),
    ]:
        try:
            with urllib.request.urlopen(url, timeout=6) as r:
                checks.append(f"✅ {name}: HTTP {r.status}")
        except Exception as ex:
            checks.append(f"⚠️ {name}: {str(ex)[:120]}")
    state = _read_json_file(AUTOPILOT_STATE)
    if state:
        checks.append(f"🧠 autopilot: last run `{state.get('last_run','?')}`, new proposals `{state.get('proposals_new','?')}`")
    return "\n".join(checks)

async def ask_tank_ai(prompt, model="llama3.2:3b"):
    payload = {
        "model": model,
        "prompt": prompt,
        "system": "You are Tank, Alex's local AI ops assistant. Be concise, practical, and use no paid services.",
        "stream": False,
        "keep_alive": "90m",
        "options": {"temperature": 0.25, "num_predict": 900},
    }
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read().decode())
        return clean(data.get("response", "").strip()) or "(Tank returned an empty response.)"
    except Exception as ex:
        return f"⚠️ Tank AI error: {ex}"

async def list_tank_models():
    try:
        with urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=8) as r:
            data = json.loads(r.read().decode())
        models = [m.get("name", "?") for m in data.get("models", [])]
        return "🧠 **Tank models**\n" + "\n".join(f"- `{m}`" for m in models)
    except Exception as ex:
        return f"⚠️ model list failed: {ex}"

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

async def watch_channel(channel_id_int: int, cid: str):
    """Persistent watcher: poll OpenHands and push every new event to the channel."""
    channel = client.get_channel(channel_id_int)
    if channel is None:
        try:
            channel = await client.fetch_channel(channel_id_int)
        except Exception as ex:
            log.warning(f"cannot fetch channel {channel_id_int}: {ex}"); return
    key = str(channel_id_int)
    last_id = channel_last.get(key, -1)
    log.info(f"watch start ch={channel_id_int} cid={cid[:8]} from id>{last_id}")
    while True:
        try:
            cur_cid = channel_conv.get(key)
            if cur_cid != cid:
                log.info(f"watch stop ch={channel_id_int} cid changed {cid[:8]}->{(cur_cid or """none""")[:8]}")
                return
            data = await asyncio.to_thread(get_events, cid, 100)
            evs = sorted(data.get("events",[]), key=lambda e: e.get("id",0))
            new_evs = [e for e in evs if isinstance(e.get("id"),int) and e["id"] > last_id]
            for e in new_evs:
                text = fmt_event(e)
                if text:
                    await send_long(channel, text)
                last_id = e["id"]
                channel_last[key] = last_id
                _save(LAST_ID_FILE, channel_last)
        except asyncio.CancelledError:
            log.info(f"watch cancelled ch={channel_id_int}"); raise
        except Exception as ex:
            log.warning(f"watch err ch={channel_id_int}: {ex}")
        await asyncio.sleep(POLL_S)

async def watch_approved_job(channel_id_int: int, cid: str, label: str):
    """Transient watcher for one approved proposal conversation."""
    channel = client.get_channel(channel_id_int)
    if channel is None:
        try:
            channel = await client.fetch_channel(channel_id_int)
        except Exception as ex:
            log.warning(f"cannot fetch channel {channel_id_int}: {ex}")
            return
    last_id = -1
    await channel.send(f"🚀 **Tank started:** `{label}` (`{cid[:8]}…`)")
    while True:
        try:
            data = await asyncio.to_thread(get_events, cid, 100)
            evs = sorted(data.get("events", []), key=lambda e: e.get("id", 0))
            new_evs = [e for e in evs if isinstance(e.get("id"), int) and e["id"] > last_id]
            for e in new_evs:
                text = fmt_event(e)
                if text:
                    await send_long(channel, f"🛠️ `{label}`\n{text}")
                last_id = e["id"]
                extras = e.get("extras", {}) if isinstance(e.get("extras"), dict) else {}
                state = extras.get("agent_state")
                if state in ("finished", "error", "stopped"):
                    await channel.send(f"✅ **Tank job ended:** `{label}` ({state})")
                    return
        except asyncio.CancelledError:
            return
        except Exception as ex:
            log.warning(f"approved job watch err ({cid[:8]}): {ex}")
        await asyncio.sleep(POLL_S)

async def summary_tailer():
    """Tail summaries.jsonl and post new summaries to their channel."""
    cursor = _load(SUMMARY_CURSOR)
    pos = int(cursor.get("pos", 0))
    while True:
        await asyncio.sleep(10)
        try:
            if not SUMMARIES_FILE.exists():
                continue
            size = SUMMARIES_FILE.stat().st_size
            if size <= pos:
                if size < pos: pos = 0  # truncated
                continue
            with SUMMARIES_FILE.open() as f:
                f.seek(pos)
                lines = f.readlines()
                pos = f.tell()
            for line in lines:
                line = line.strip()
                if not line: continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                chan_id = rec.get("channel")
                summary = rec.get("summary", "")
                n = rec.get("n_events", 0)
                if not chan_id or not summary: continue
                try:
                    ch = client.get_channel(int(chan_id)) or await client.fetch_channel(int(chan_id))
                    body = f"📋 **agent update** ({n} events)\n{summary}"
                    await send_long(ch, body)
                except Exception as ex:
                    log.warning(f"summary post err: {ex}")
            cursor["pos"] = pos
            _save(SUMMARY_CURSOR, cursor)
        except Exception as ex:
            log.warning(f"summary tailer err: {ex}")

async def budget_watchdog():
    """Poll /budget every 5 min, post threshold-crossing alerts to all wired channels."""
    alerts = _load(ALERTS_FILE)
    while True:
        await asyncio.sleep(BUDGET_POLL_S)
        try:
            with urllib.request.urlopen(f"{ROUTER_URL}/budget", timeout=10) as r:
                b = json.loads(r.read().decode())
            u = float(b.get("usage_monthly_usd", 0))
            lim = float(b.get("limit_usd", 30))
            for thresh, emoji, label in BUDGET_THRESHOLDS:
                key = f"crossed_{thresh}"
                if u >= thresh and not alerts.get(key):
                    alerts[key] = time.time()
                    _save(ALERTS_FILE, alerts)
                    note = f"{emoji} **LLM budget {label}**: ${u:.2f} / ${lim:.0f} used. Cloud tiers force-local at $25."
                    for ch_str in channel_conv.keys():
                        try:
                            ch = client.get_channel(int(ch_str)) or await client.fetch_channel(int(ch_str))
                            await ch.send(note)
                        except Exception as ex:
                            log.warning(f"alert post err: {ex}")
        except Exception as ex:
            log.warning(f"watchdog err: {ex}")

def ensure_watcher(channel_id_int: int, cid: str):
    key = str(channel_id_int)
    existing = watchers.get(key)
    if existing and not existing.done():
        existing.cancel()
    watchers[key] = asyncio.create_task(watch_channel(channel_id_int, cid))

@client.event
async def on_ready():
    log.info(f"logged in as {client.user}")
    _start_bg("budget_watchdog", budget_watchdog())
    _start_bg("summary_tailer", summary_tailer())
    _start_bg("autopilot_tailer", autopilot_tailer())
    _start_bg("reconcile_proposals", reconcile_proposals())
    for ch_str, cid in channel_conv.items():
        try:
            ensure_watcher(int(ch_str), cid)
        except Exception as ex:
            log.warning(f"failed to start watcher for {ch_str}: {ex}")

@client.event
async def on_reaction_add(reaction, user):
    if user == client.user:
        return
    try:
        message_id = str(reaction.message.id)
        action = proposal_actions.get(message_id)
        if not action or action.get("status") != "pending":
            return
        emoji = str(reaction.emoji)
        if emoji not in ("✅", "❌"):
            return
        rec = action.get("proposal", {})
        if emoji == "❌":
            changed = await _handle_proposal_decision(reaction.message, rec, str(user), False)
            if changed:
                await reaction.message.reply(f"Rejected by {user.mention}.")
            return

        try:
            cid = await _handle_proposal_decision(reaction.message, rec, str(user), True)
            await reaction.message.reply(f"Approved by {user.mention}. Dispatched to Tank worker `{cid[:8]}…`.")
        except Exception as ex:
            await reaction.message.reply(f"Approved by {user.mention}, but dispatch failed: {ex}")
    except Exception as ex:
        log.warning(f"reaction handler err: {ex}")

@client.event
async def on_message(msg):
    if msg.author == client.user: return
    if CHANNEL_IDS and msg.channel.id not in CHANNEL_IDS: return
    text = msg.content.strip()
    if not text: return

    if text.lower() in ("/budget", "budget"):
        try:
            with urllib.request.urlopen(f"{ROUTER_URL}/budget", timeout=8) as r:
                b = json.loads(r.read().decode())
            u = b["usage_monthly_usd"]; lim = b["limit_usd"]; rem = b["remaining_usd"]
            cap = b["cap_usd"]; locked = b["locked"]; warn = b["warn_triggered"]
            bar_n = 20; filled = min(bar_n, int(u / lim * bar_n)) if lim else 0
            bar = "█" * filled + "░" * (bar_n - filled)
            status = "🔴 LOCKED (cloud disabled)" if locked else ("🟡 warn" if warn else "🟢 ok")
            msg = (
                f"**LLM budget** {status}\n"
                f"`{bar}` ${u:.2f} / ${lim:.0f} (cap ${cap:.0f})\n"
                f"remaining: **${rem:.2f}**"
            )
            await msg.channel.send(msg)
        except Exception as ex:
            await msg.channel.send(f"⚠ budget fetch failed: {ex}")
        return

    if text.lower() in ("/doctor", "doctor", "/tank"):
        await msg.channel.send("🩺 **Tank doctor**\n" + await tank_doctor_summary())
        return

    if text.lower() in ("/models", "models"):
        await msg.channel.send(await list_tank_models())
        return

    if text.lower().startswith("/asktank ") or text.lower().startswith("asktank "):
        prompt = text.split(" ", 1)[1].strip()
        if not prompt:
            await msg.channel.send("Usage: `/asktank what should Tank do next?`")
            return
        async with msg.channel.typing():
            answer = await ask_tank_ai(prompt)
        await send_long(msg.channel, "🧠 **Tank AI**\n" + answer)
        return

    if text.lower() in ("/autopilot", "autopilot"):
        state = _read_json_file(AUTOPILOT_STATE)
        if not state:
            await msg.channel.send("⚠️ no autopilot state found yet")
            return
        body = (
            "🧠 **Tank Autopilot**\n"
            f"last run: `{state.get('last_run','?')}`\n"
            f"model: `{state.get('model','?')}`\n"
            f"duration: `{state.get('duration_s','?')}s`\n"
            f"proposals: `{state.get('proposals_new','?')}` new / `{state.get('proposals_total','?')}` total\n"
            f"report: `{state.get('last_report','?')}`"
        )
        await msg.channel.send(body)
        return

    if text.lower().startswith("/proposals") or text.lower().startswith("proposals"):
        parts = text.split()
        limit = 5
        if len(parts) > 1:
            try:
                limit = max(1, min(10, int(parts[1])))
            except Exception:
                pass
        proposals = _load_recent_proposals(limit)
        if not proposals:
            await msg.channel.send("No autopilot proposals queued yet.")
            return
        body = ["📌 **Recent Tank proposals**"]
        for rec in proposals:
            body.append(_proposal_line(rec))
        await send_long(msg.channel, "\n\n".join(body))
        return

    if text.lower() in ("/reset","/new","reset"):
        key = str(msg.channel.id)
        if key in channel_conv:
            del channel_conv[key]; _save(STATE_FILE, channel_conv)
        if key in channel_last:
            del channel_last[key]; _save(LAST_ID_FILE, channel_last)
        w = watchers.pop(key, None)
        if w: w.cancel()
        await msg.channel.send("✓ conversation reset")
        return

    key = str(msg.channel.id)
    cid = channel_conv.get(key)
    async with msg.channel.typing():
        try:
            if not cid:
                primed = f"Respond in English. {text}"
                resp = await asyncio.to_thread(create_conversation, primed)
                cid = resp["conversation_id"]
                channel_conv[key] = cid; _save(STATE_FILE, channel_conv)
                channel_last.pop(key, None); _save(LAST_ID_FILE, channel_last)
                await msg.channel.send(f"_started conversation `{cid[:8]}…` — first response takes ~2 min for runtime startup_")
                ensure_watcher(msg.channel.id, cid)
            else:
                await asyncio.to_thread(send_message, cid, text)
                # watcher will pick up the response
        except urllib.error.HTTPError as e:
            await msg.channel.send(f"⚠ http {e.code}: {e.read().decode()[:200]}")
        except Exception as e:
            await msg.channel.send(f"⚠ error: {e}")

client.run(TOKEN)
