"""
Approval API — FastAPI service that receives approve/reject webhooks from ntfy
and queues approved tasks for the agent to execute.
"""

from __future__ import annotations

import json
import os
import sqlite3
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

DB_PATH   = Path("/data/tasks.db")
NTFY_URL   = "http://ntfy:5050"
NTFY_TOPIC = "proposals"
NTFY_USER  = os.getenv("NTFY_USER", "alex")
NTFY_PASS  = os.environ["NTFY_PASS"]  # required — no insecure default

# ---------------------------------------------------------------------------
# Database setup
# ---------------------------------------------------------------------------

def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id          TEXT PRIMARY KEY,
                category    TEXT NOT NULL,
                title       TEXT NOT NULL,
                summary     TEXT NOT NULL,
                payload     TEXT NOT NULL,
                status      TEXT NOT NULL DEFAULT 'pending',
                created_at  TEXT NOT NULL,
                resolved_at TEXT
            )
        """)
        conn.commit()


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="NOBS Approval API", lifespan=lifespan)


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class ProposalCreate(BaseModel):
    category: str          # "career" | "homelab" | "portfolio"
    title: str
    summary: str
    payload: dict          # arbitrary data the agent needs to execute


class Task(BaseModel):
    id: str
    category: str
    title: str
    summary: str
    payload: dict
    status: str
    created_at: str
    resolved_at: Optional[str] = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

CATEGORY_TAGS = {
    "career": "dart",
    "homelab": "wrench",
    "portfolio": "pencil",
    "learning": "books",
    "design": "palette",
    "engineering": "keyboard",
    "seo": "globe",
}

CATEGORY_EMOJI = {
    "career": "🎯",
    "homelab": "🛠️",
    "portfolio": "📝",
    "learning": "📚",
    "design": "🎨",
    "engineering": "💻",
    "seo": "🌐",
}


import logging as _logging
_ntfy_log = _logging.getLogger("approval-api.ntfy")

async def send_ntfy(task: dict) -> None:
    """Push an interactive notification to iPhone via ntfy. Never raises — a failed push is logged, not fatal."""
    tag = CATEGORY_TAGS.get(task["category"], "bulb")
    approve_url = f"http://100.96.97.50:5051/approve?task_id={task['id']}"
    reject_url  = f"http://100.96.97.50:5051/reject?task_id={task['id']}"

    actions = (
        f"http, Approve, {approve_url}, method=POST, clear=true; "
        f"http, Skip, {reject_url}, method=POST, clear=true"
    )

    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{NTFY_URL}/{NTFY_TOPIC}",
                content=task["summary"].encode("utf-8"),
                headers={
                    "Title":        task["title"],
                    "Priority":     "high",
                    "Tags":         tag,
                    "Actions":      actions,
                    "Content-Type": "text/plain; charset=utf-8",
                },
                auth=(NTFY_USER, NTFY_PASS),
                timeout=10,
            )
    except Exception as exc:
        _ntfy_log.warning("ntfy push failed for task %s: %s", task["id"], exc)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.post("/propose", response_model=Task, status_code=201)
async def create_proposal(body: ProposalCreate):
    """Agent calls this to submit a new proposal and send iPhone notification."""
    task_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    task = {
        "id": task_id,
        "category": body.category,
        "title": body.title,
        "summary": body.summary,
        "payload": body.payload,
        "status": "pending",
        "created_at": now,
        "resolved_at": None,
    }

    with get_db() as conn:
        conn.execute(
            """INSERT INTO tasks (id, category, title, summary, payload, status, created_at)
               VALUES (?, ?, ?, ?, ?, 'pending', ?)""",
            (task_id, body.category, body.title, body.summary,
             json.dumps(body.payload), now),
        )
        conn.commit()

    await send_ntfy(task)
    return Task(**task)


@app.post("/approve")
async def approve_task(task_id: str = Query(...)):
    """ntfy action button or dashboard calls this when you tap Approve."""
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Task not found")
        conn.execute(
            "UPDATE tasks SET status='approved', resolved_at=? WHERE id=?",
            (now, task_id),
        )
        conn.commit()
    return {"status": "approved", "task_id": task_id}


@app.post("/reject")
async def reject_task(task_id: str = Query(...)):
    """ntfy action button or dashboard calls this when you tap Skip."""
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Task not found")
        conn.execute(
            "UPDATE tasks SET status='rejected', resolved_at=? WHERE id=?",
            (now, task_id),
        )
        conn.commit()
    return {"status": "rejected", "task_id": task_id}


@app.post("/complete")
async def complete_task(task_id: str = Query(...)):
    """Mark a task as completed (executed by the agent)."""
    now = datetime.now(timezone.utc).isoformat()
    with get_db() as conn:
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Task not found")
        conn.execute(
            "UPDATE tasks SET status='completed', resolved_at=? WHERE id=?",
            (now, task_id),
        )
        conn.commit()
    return {"status": "completed", "task_id": task_id}


@app.post("/clear-resolved")
async def clear_resolved():
    """Delete all approved and rejected tasks from the database to clean up the queue."""
    with get_db() as conn:
        conn.execute("DELETE FROM tasks WHERE status != 'pending'")
        conn.commit()
    return {"status": "cleared"}


@app.get("/queue", response_model=list[Task])
async def get_queue(status: Optional[str] = None):
    """View all tasks, optionally filtered by status."""
    with get_db() as conn:
        if status:
            rows = conn.execute(
                "SELECT * FROM tasks WHERE status=? ORDER BY created_at DESC", (status,)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM tasks ORDER BY created_at DESC"
            ).fetchall()

    return [
        Task(
            id=r["id"],
            category=r["category"],
            title=r["title"],
            summary=r["summary"],
            payload=json.loads(r["payload"]),
            status=r["status"],
            created_at=r["created_at"],
            resolved_at=r["resolved_at"],
        )
        for r in rows
    ]


@app.post("/conflict-check")
async def conflict_check():
    """Evaluate pending proposals for resource and logical conflicts using local LLM."""
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM tasks WHERE status='pending' ORDER BY created_at DESC LIMIT 5"
        ).fetchall()

    if not rows:
        return {"analysis": "### ✅ No Pending Proposals\nThere are no pending proposals to evaluate at this time."}

    # Format the pending tasks list for the LLM
    proposals_text = ""
    for i, r in enumerate(rows, 1):
        payload = json.loads(r["payload"])
        proposals_text += (
            f"--- PROPOSAL {i} ---\n"
            f"ID: {r['id']}\n"
            f"Category: {r['category']}\n"
            f"Title: {r['title']}\n"
            f"Summary: {r['summary']}\n"
            f"Payload: {json.dumps(payload, indent=2)}\n\n"
        )

    prompt = (
        "You are an expert systems engineer and career advisor for an Information Systems student at UArk.\n"
        "Evaluate the following pending tasks for conflicts, resource bottlenecks, or contradictions.\n\n"
        "Check for:\n"
        "1. Resource conflicts (e.g. installing multiple heavy Docker services at the same time, VRAM limits on Ollama, or port overlaps).\n"
        "2. Redundant or duplicate actions (e.g. duplicate job entries, repeated scrape requests, or multiple updates for the same service).\n"
        "3. Career alignment issues (e.g. jobs that do not match the UArk IS major / Apple target or conflict with current focus).\n\n"
        "Here are the pending tasks:\n"
        f"{proposals_text}\n"
        "Provide a structured evaluation. Identify any conflicts. For each conflict, explain why it happens. "
        "At the end, provide recommendations on which tasks to Approve and which ones to Skip. "
        "Write your analysis in clear, professional Markdown."
    )

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                "http://litellm:4000/v1/chat/completions",
                headers={
                    "Authorization": "Bearer nobs_litellm_master_secret_8829401",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "local-coder-14b",
                    "messages": [
                        {"role": "system", "content": "You are a helpful assistant."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.2,
                    "num_ctx": 4096
                },
                timeout=120  # 2 min ceiling — local model should always respond within this
            )
            resp.raise_for_status()
            data = resp.json()
            analysis = data["choices"][0]["message"]["content"]
            return {"analysis": analysis}
    except Exception as e:
        return {"analysis": f"### ❌ AI Evaluation Failed\nCould not query the LLM router: {repr(e)}"}


@app.post("/trigger-scan")
async def trigger_scan():
    """Create a special system task that tells the agent to run scans immediately."""
    task_id = "system-scan-trigger"
    now = datetime.now(timezone.utc).isoformat()
    
    task = {
        "id": task_id,
        "category": "learning",
        "title": "System Trigger Scan",
        "summary": "Immediate scan requested via web console",
        "payload": {"action": "system_trigger_scan"},
        "status": "approved",
        "created_at": now,
        "resolved_at": None,
    }
    
    with get_db() as conn:
        existing = conn.execute("SELECT id FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if existing:
            conn.execute(
                "UPDATE tasks SET status='approved', created_at=?, resolved_at=NULL WHERE id=?",
                (now, task_id)
            )
        else:
            conn.execute(
                """INSERT INTO tasks (id, category, title, summary, payload, status, created_at)
                   VALUES (?, 'learning', 'System Trigger Scan', 'Immediate scan requested via web console', ?, 'approved', ?)""",
                (task_id, json.dumps(task["payload"]), now)
            )
        conn.commit()
        
    return {"status": "triggered"}


@app.get("/", response_class=HTMLResponse)
async def dashboard():
    """HTML dashboard for managing proposals with built-in AJAX and AI Conflict Checker."""
    with get_db() as conn:
        tasks = conn.execute(
            "SELECT * FROM tasks ORDER BY created_at DESC LIMIT 50"
        ).fetchall()

    # Calculate status counts
    pending_cnt = sum(1 for t in tasks if t["status"] == "pending")
    approved_cnt = sum(1 for t in tasks if t["status"] in ("approved", "completed"))
    rejected_cnt = sum(1 for t in tasks if t["status"] == "rejected")

    # Build task items
    cards_html = ""
    if not tasks:
        cards_html = """
        <div class="empty-state">
            <div class="empty-icon">📂</div>
            <h3>No proposals found</h3>
            <p>Once the agent generates ideas, they will appear here.</p>
        </div>"""
    
    for t in tasks:
        emoji = CATEGORY_EMOJI.get(t["category"], "💡")
        status = t["status"].lower()
        payload = json.loads(t["payload"])
        formatted_payload = json.dumps(payload, indent=2)
        
        # Color coding classes
        card_class = f"proposal-card {status}"
        badge_class = f"badge {status}"
        
        # Action buttons HTML
        actions_html = ""
        if status == "pending":
            actions_html = f"""
            <div class="actions">
                <button class="btn btn-approve" onclick="resolveTask('{t['id']}', 'approve')">Approve</button>
                <button class="btn btn-reject" onclick="resolveTask('{t['id']}', 'reject')">Skip</button>
            </div>"""
        else:
            resolved_str = t["resolved_at"][:16].replace('T',' ') if t["resolved_at"] else ""
            actions_html = f"""
            <div class="actions-resolved">
                <span class="resolved-label">Resolved at {resolved_str}</span>
            </div>"""

        cards_html += f"""
        <div class="card-wrapper" id="card-wrapper-{t['id']}">
            <div class="{card_class}">
                <div class="card-header">
                    <span class="category-tag">{emoji} {t['category'].upper()}</span>
                    <span class="{badge_class}" id="badge-{t['id']}">{status.upper()}</span>
                </div>
                <div class="card-body">
                    <h3>{t['title']}</h3>
                    <p>{t['summary']}</p>
                    
                    <details class="payload-details">
                        <summary>View Payload Parameters</summary>
                        <pre><code>{formatted_payload}</code></pre>
                    </details>
                </div>
                <div class="card-footer" id="actions-{t['id']}">
                    {actions_html}
                </div>
            </div>
        </div>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NOBS Proposal Queue</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <style>
        :root {{
            --bg-color: #0b0f19;
            --panel-bg: rgba(30, 41, 59, 0.4);
            --border-color: rgba(255, 255, 255, 0.08);
            --text-color: #f1f5f9;
            --text-muted: #94a3b8;
            
            --color-primary: #06b6d4;
            --color-success: #10b981;
            --color-warning: #f59e0b;
            --color-danger: #f43f5e;
            
            --shadow-premium: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.5;
            padding: 2.5rem;
            min-height: 100vh;
        }}

        /* Header Layout */
        header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 2rem;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 1.5rem;
        }}

        .logo-section {{
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }}

        .logo-icon {{
            font-size: 2rem;
        }}

        h1 {{
            font-size: 1.8rem;
            font-weight: 700;
            background: linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}

        .network-badge {{
            display: flex;
            align-items: center;
            gap: 0.5rem;
            background: rgba(16, 185, 129, 0.1);
            color: var(--color-success);
            padding: 0.4rem 0.8rem;
            border-radius: 9999px;
            font-size: 0.8rem;
            font-weight: 500;
            border: 1px solid rgba(16, 185, 129, 0.2);
        }}

        .status-dot {{
            width: 8px;
            height: 8px;
            background-color: var(--color-success);
            border-radius: 50%;
            box-shadow: 0 0 8px var(--color-success);
        }}

        /* Metrics Row */
        .metrics-row {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1.5rem;
            margin-bottom: 2.5rem;
        }}

        .metric-card {{
            background: var(--panel-bg);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 1.5rem;
            text-align: center;
            backdrop-filter: blur(16px);
            box-shadow: var(--shadow-premium);
        }}

        .metric-card h4 {{
            font-size: 0.85rem;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.5rem;
        }}

        .metric-card .number {{
            font-size: 2.2rem;
            font-weight: 700;
        }}

        .metric-card.pending .number {{ color: var(--color-warning); }}
        .metric-card.approved .number {{ color: var(--color-success); }}
        .metric-card.rejected .number {{ color: var(--color-danger); }}

        /* Main Workspace Grid */
        .workspace-grid {{
            display: grid;
            grid-template-columns: 3fr 2fr;
            gap: 2.5rem;
            align-items: start;
        }}

        /* Columns styling */
        .proposals-column, .ai-column {{
            display: flex;
            flex-direction: column;
            gap: 1.5rem;
        }}

        .section-header {{
            font-size: 1.2rem;
            font-weight: 600;
            color: var(--text-color);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}

        /* Proposal Card Styling (Glassmorphism) */
        .proposal-card {{
            background: var(--panel-bg);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 1.5rem;
            box-shadow: var(--shadow-premium);
            backdrop-filter: blur(12px);
            transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
            overflow: hidden;
        }}

        .proposal-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background-color: var(--text-muted);
        }}

        .proposal-card.pending::before {{ background-color: var(--color-warning); }}
        .proposal-card.approved::before {{ background-color: var(--color-success); }}
        .proposal-card.completed::before {{ background-color: var(--color-primary); }}
        .proposal-card.rejected::before {{ background-color: var(--color-danger); }}

        .proposal-card.approved {{
            background: rgba(16, 185, 129, 0.05);
            border-color: rgba(16, 185, 129, 0.2);
        }}
        .proposal-card.completed {{
            background: rgba(6, 182, 212, 0.03);
            border-color: rgba(6, 182, 212, 0.15);
        }}
        .proposal-card.rejected {{
            background: rgba(244, 63, 94, 0.03);
            border-color: rgba(244, 63, 94, 0.15);
        }}

        .card-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
        }}

        .category-tag {{
            font-size: 0.75rem;
            font-weight: 700;
            background: rgba(255, 255, 255, 0.05);
            padding: 0.3rem 0.6rem;
            border-radius: 6px;
            border: 1px solid var(--border-color);
            letter-spacing: 0.05em;
        }}

        .badge {{
            font-size: 0.7rem;
            font-weight: 700;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            text-transform: uppercase;
        }}

        .badge.pending {{ background: rgba(245, 158, 11, 0.15); color: var(--color-warning); }}
        .badge.approved {{ background: rgba(16, 185, 129, 0.15); color: var(--color-success); }}
        .badge.completed {{ background: rgba(6, 182, 212, 0.15); color: var(--color-primary); }}
        .badge.rejected {{ background: rgba(244, 63, 94, 0.15); color: var(--color-danger); }}

        .card-body h3 {{
            font-size: 1.15rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
        }}

        .card-body p {{
            font-size: 0.95rem;
            color: var(--text-muted);
            margin-bottom: 1rem;
        }}

        /* Expandable Payload Parameter block */
        .payload-details {{
            margin-top: 1rem;
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            overflow: hidden;
        }}

        .payload-details summary {{
            padding: 0.6rem 1rem;
            font-size: 0.8rem;
            font-weight: 600;
            color: var(--text-muted);
            cursor: pointer;
            outline: none;
            user-select: none;
        }}

        .payload-details pre {{
            padding: 1rem;
            overflow-x: auto;
            border-top: 1px solid var(--border-color);
            background: #090c15;
        }}

        .payload-details code {{
            font-family: 'Fira Code', monospace;
            font-size: 0.8rem;
            color: #38bdf8;
        }}

        /* Buttons & Actions */
        .card-footer {{
            margin-top: 1.25rem;
            border-top: 1px solid var(--border-color);
            padding-top: 1rem;
        }}

        .actions {{
            display: flex;
            gap: 1rem;
        }}

        .btn {{
            font-family: inherit;
            font-weight: 600;
            font-size: 0.85rem;
            padding: 0.5rem 1.25rem;
            border-radius: 8px;
            cursor: pointer;
            border: none;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            justify-content: center;
        }}

        .btn-approve {{
            background-color: var(--color-success);
            color: #ffffff;
        }}
        .btn-approve:hover {{
            background-color: #059669;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
        }}

        .btn-reject {{
            background-color: rgba(244, 63, 94, 0.1);
            color: var(--color-danger);
            border: 1px solid rgba(244, 63, 94, 0.2);
        }}
        .btn-reject:hover {{
            background-color: var(--color-danger);
            color: #ffffff;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(244, 63, 94, 0.3);
        }}

        .actions-resolved {{
            display: flex;
            align-items: center;
            color: var(--text-muted);
            font-size: 0.8rem;
        }}

        /* Empty state */
        .empty-state {{
            text-align: center;
            padding: 4rem 2rem;
            background: var(--panel-bg);
            border: 1px dashed var(--border-color);
            border-radius: 16px;
        }}
        .empty-icon {{
            font-size: 3rem;
            margin-bottom: 1rem;
        }}
        .empty-state p {{
            color: var(--text-muted);
        }}

        /* AI Side Terminal Container */
        .ai-terminal {{
            background: #090d16;
            border: 1px solid var(--border-color);
            border-radius: 16px;
            box-shadow: var(--shadow-premium);
            overflow: hidden;
            display: flex;
            flex-direction: column;
            height: 600px;
        }}

        .terminal-header {{
            background: #111827;
            padding: 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-color);
        }}

        .terminal-title {{
            font-size: 0.85rem;
            font-weight: 700;
            color: var(--text-muted);
            letter-spacing: 0.05em;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}

        .terminal-dots {{
            display: flex;
            gap: 0.35rem;
        }}
        .dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
        }}
        .dot.red {{ background-color: var(--color-danger); }}
        .dot.yellow {{ background-color: var(--color-warning); }}
        .dot.green {{ background-color: var(--color-success); }}

        .terminal-content {{
            padding: 1.5rem;
            overflow-y: auto;
            flex-grow: 1;
            font-family: 'Inter', sans-serif;
            font-size: 0.9rem;
            color: var(--text-color);
        }}

        .terminal-footer {{
            padding: 1rem;
            background: #111827;
            border-top: 1px solid var(--border-color);
            display: flex;
            justify-content: center;
        }}

        .btn-ai {{
            background: linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%);
            color: white;
            width: 100%;
            padding: 0.75rem 1.5rem;
            font-size: 0.9rem;
            box-shadow: 0 4px 12px rgba(6, 182, 212, 0.2);
        }}
        .btn-ai:hover {{
            box-shadow: 0 4px 16px rgba(6, 182, 212, 0.4);
            transform: translateY(-1px);
        }}
        .btn-ai:disabled {{
            background: #1f2937;
            color: var(--text-muted);
            box-shadow: none;
            transform: none;
            cursor: not-allowed;
        }}

        /* Markdown Analysis Styling inside Terminal */
        .analysis-output h3 {{
            color: var(--color-primary);
            margin: 1.5rem 0 0.75rem 0;
            font-size: 1.1rem;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 0.25rem;
        }}
        .analysis-output h3:first-of-type {{
            margin-top: 0;
        }}
        .analysis-output p {{
            margin-bottom: 1rem;
            color: var(--text-color);
            font-size: 0.9rem;
        }}
        .analysis-output ul {{
            margin-left: 1.5rem;
            margin-bottom: 1rem;
        }}
        .analysis-output li {{
            margin-bottom: 0.35rem;
        }}
        .analysis-output blockquote {{
            border-left: 3px solid var(--color-primary);
            background: rgba(6, 182, 212, 0.05);
            padding: 0.5rem 1rem;
            margin-bottom: 1rem;
            border-radius: 0 8px 8px 0;
            font-style: italic;
        }}

        /* Loading Spinner */
        .spinner-wrapper {{
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            gap: 1rem;
            color: var(--text-muted);
        }}

        .spinner {{
            width: 40px;
            height: 40px;
            border: 3px solid rgba(6, 182, 212, 0.1);
            border-radius: 50%;
            border-top-color: var(--color-primary);
            animation: spin 1s linear infinite;
        }}

        @keyframes spin {{
            0% {{ transform: rotate(0deg); }}
            100% {{ transform: rotate(360deg); }}
        }}

        /* Micro-Animations for Completed actions */
        .card-wrapper {{
            transition: all 0.5s ease;
        }}
    </style>
</head>
<body>

    <!-- Header -->
    <header>
        <div class="logo-section">
            <span class="logo-icon">🤖</span>
            <div>
                <h1>NOBS Proposal Console</h1>
                <p style="font-size: 0.8rem; color: var(--text-muted)">Workspace & Career Approvals Agent</p>
            </div>
        </div>
        <div style="display: flex; gap: 1rem; align-items: center;">
            <button class="btn" id="btn-trigger-scan" style="background: rgba(6, 182, 212, 0.1); color: var(--color-primary); border: 1px solid rgba(6, 182, 212, 0.2); padding: 0.4rem 1rem;" onclick="triggerScan()">Generate Proposals</button>
            <button class="btn" style="background: rgba(244, 63, 94, 0.1); color: var(--color-danger); border: 1px solid rgba(244, 63, 94, 0.2); padding: 0.4rem 1rem;" onclick="clearResolvedTasks()">Clear History</button>
            <div class="network-badge">
                <span class="status-dot"></span>
                <span>Agent Active (Tailscale)</span>
            </div>
        </div>
    </header>

    <!-- Metrics row -->
    <div class="metrics-row">
        <div class="metric-card pending">
            <h4>Pending Reviews</h4>
            <div class="number" id="count-pending">{pending_cnt}</div>
        </div>
        <div class="metric-card approved">
            <h4>Approved Tasks</h4>
            <div class="number" id="count-approved">{approved_cnt}</div>
        </div>
        <div class="metric-card rejected">
            <h4>Skipped Tasks</h4>
            <div class="number" id="count-rejected">{rejected_cnt}</div>
        </div>
    </div>

    <!-- Main Workspace Grid -->
    <div class="workspace-grid">
        
        <!-- Proposals List Column -->
        <div class="proposals-column">
            <div class="section-header">
                <span>📋</span> Active Proposals Queue
            </div>
            
            <div id="proposals-list" style="display: flex; flex-direction: column; gap: 1.5rem;">
                {cards_html}
            </div>
        </div>

        <!-- AI Control Center Column -->
        <div class="ai-column">
            <div class="section-header">
                <span>✨</span> Ollama Conflict Resolver
            </div>
            
            <div class="ai-terminal">
                <div class="terminal-header">
                    <div class="terminal-title">
                        <span>●</span> local-coder-14b
                    </div>
                    <div class="terminal-dots">
                        <span class="dot red"></span>
                        <span class="dot yellow"></span>
                        <span class="dot green"></span>
                    </div>
                </div>
                
                <div class="terminal-content" id="terminal-screen">
                    <div style="color: var(--text-muted); font-size: 0.9rem; text-align: center; margin-top: 6rem;">
                        <span style="font-size: 2rem; display: block; margin-bottom: 1rem;">🧬</span>
                        Ready to evaluate pending proposals.<br>
                        Click "Run AI Conflict Check" below to start.
                    </div>
                </div>
                
                <div class="terminal-footer">
                    <button class="btn btn-ai" id="btn-run-check" onclick="runConflictCheck()">
                        Run AI Conflict Check
                    </button>
                </div>
            </div>
        </div>

    </div>

    <script>
        async function resolveTask(taskId, action) {{
            const actionsDiv = document.getElementById('actions-' + taskId);
            const badge = document.getElementById('badge-' + taskId);
            const cardWrapper = document.getElementById('card-wrapper-' + taskId);
            const card = cardWrapper.querySelector('.proposal-card');
            
            // Save original buttons in case of failure
            const originalHTML = actionsDiv.innerHTML;
            
            // Set loading spinner state
            actionsDiv.innerHTML = '<span style="font-size: 0.8rem; color: var(--text-muted)">Resolving...</span>';
            
            try {{
                const response = await fetch(`/approve?task_id=${{taskId}}`, {{
                    method: 'POST'
                }});
                
                if (action === 'reject') {{
                    await fetch(`/reject?task_id=${{taskId}}`, {{ method: 'POST' }});
                }}
                
                if (!response.ok) throw new Error('API request failed');
                
                // Update Badge
                badge.innerText = action === 'approve' ? 'APPROVED' : 'REJECTED';
                badge.className = 'badge ' + (action === 'approve' ? 'approved' : 'rejected');
                
                // Animate card styles
                card.className = 'proposal-card ' + (action === 'approve' ? 'approved' : 'rejected');
                
                // Set resolved string
                const now = new Date();
                const resolvedStr = now.toISOString().slice(0,16).replace('T', ' ');
                actionsDiv.innerHTML = `<div class="actions-resolved"><span class="resolved-label">Resolved at ${{resolvedStr}}</span></div>`;
                
                // Adjust Counters
                updateCounters(action);
                
            }} catch (error) {{
                console.error(error);
                actionsDiv.innerHTML = originalHTML;
                alert('Failed to resolve proposal task.');
            }}
        }}

        function updateCounters(action) {{
            const pending = document.getElementById('count-pending');
            const approved = document.getElementById('count-approved');
            const rejected = document.getElementById('count-rejected');
            
            pending.innerText = Math.max(0, parseInt(pending.innerText) - 1);
            if (action === 'approve') {{
                approved.innerText = parseInt(approved.innerText) + 1;
            }} else {{
                rejected.innerText = parseInt(rejected.innerText) + 1;
            }}
        }}

        async function runConflictCheck() {{
            const screen = document.getElementById('terminal-screen');
            const button = document.getElementById('btn-run-check');
            
            // Setup loading screen
            button.disabled = true;
            screen.innerHTML = `
            <div class="spinner-wrapper">
                <div class="spinner"></div>
                <div style="font-weight: 500">Querying LiteLLM & Ollama...</div>
                <div style="font-size: 0.75rem; text-align: center;">Analyzing task parameters for conflicts and major fit</div>
            </div>`;
            
            try {{
                const response = await fetch('/conflict-check', {{
                    method: 'POST'
                }});
                
                if (!response.ok) throw new Error('AI analysis failed');
                
                const data = await response.json();
                
                // Render markdown via CDN marked.js
                screen.innerHTML = `
                <div class="analysis-output">
                    ${{marked.parse(data.analysis)}}
                </div>`;
                
            }} catch (error) {{
                screen.innerHTML = `
                <div style="color: var(--color-danger); padding: 1rem;">
                    <strong>Error:</strong> Failed to run conflict check. Make sure LiteLLM and Ollama are reachable.
                </div>`;
            }} finally {{
                button.disabled = false;
            }}
        }}

        async function clearResolvedTasks() {{
            if (!confirm('Are you sure you want to clear all resolved (approved/skipped) proposals?')) return;
            try {{
                const response = await fetch('/clear-resolved', {{ method: 'POST' }});
                if (!response.ok) throw new Error('API failed to clear history');
                window.location.reload();
            }} catch (error) {{
                console.error(error);
                alert('Failed to clear resolved tasks.');
            }}
        }}

        async function triggerScan() {{
            const btn = document.getElementById('btn-trigger-scan');
            const originalText = btn.innerText;
            btn.disabled = true;
            btn.innerText = 'Triggering Scan...';
            try {{
                const response = await fetch('/trigger-scan', {{ method: 'POST' }});
                if (!response.ok) throw new Error('API failed to trigger scan');
                btn.innerText = 'Scan Triggered!';
                btn.style.background = 'rgba(16, 185, 129, 0.2)';
                btn.style.color = 'var(--color-success)';
                btn.style.borderColor = 'rgba(16, 185, 129, 0.3)';
                setTimeout(() => window.location.reload(), 4000);
            }} catch (error) {{
                console.error(error);
                btn.innerText = 'Failed!';
                btn.style.background = 'rgba(244, 63, 94, 0.2)';
                btn.style.color = 'var(--color-danger)';
                btn.style.borderColor = 'rgba(244, 63, 94, 0.3)';
                setTimeout(() => {{
                    btn.disabled = false;
                    btn.innerText = originalText;
                    btn.style.background = 'rgba(6, 182, 212, 0.1)';
                    btn.style.color = 'var(--color-primary)';
                    btn.style.borderColor = 'rgba(6, 182, 212, 0.2)';
                }}, 3000);
            }}
        }}

        function addNewCard(task) {{
            const list = document.getElementById('proposals-list');
            const emptyState = list.querySelector('.empty-state');
            if (emptyState) emptyState.remove();

            const emojiMap = {{
                "career": "🎯",
                "homelab": "🛠️",
                "portfolio": "📝",
                "learning": "📚",
                "design": "🎨",
                "engineering": "💻",
                "seo": "🌐"
            }};
            const emoji = emojiMap[task.category] || "💡";
            const formattedPayload = JSON.stringify(task.payload, null, 2);
            
            let actionsHtml = '';
            if (task.status === 'pending') {{
                actionsHtml = `
                <div class="actions">
                    <button class="btn btn-approve" onclick="resolveTask('${{task.id}}', 'approve')">Approve</button>
                    <button class="btn btn-reject" onclick="resolveTask('${{task.id}}', 'reject')">Skip</button>
                </div>`;
            }} else {{
                const resolvedStr = task.resolved_at ? task.resolved_at.slice(0, 16).replace('T', ' ') : '';
                actionsHtml = `<div class="actions-resolved"><span class="resolved-label">Resolved at ${{resolvedStr}}</span></div>`;
            }}

            const wrapper = document.createElement('div');
            wrapper.className = 'card-wrapper';
            wrapper.id = 'card-wrapper-' + task.id;
            wrapper.innerHTML = `
                <div class="proposal-card ${{task.status}}">
                    <div class="card-header">
                        <span class="category-tag">${{emoji}} ${{task.category.toUpperCase()}}</span>
                        <span class="badge ${{task.status}}" id="badge-${{task.id}}">${{task.status.toUpperCase()}}</span>
                    </div>
                    <div class="card-body">
                        <h3>${{task.title}}</h3>
                        <p>${{task.summary}}</p>
                        
                        <details class="payload-details">
                            <summary>View Payload Parameters</summary>
                            <pre><code>${{formattedPayload}}</code></pre>
                        </details>
                    </div>
                    <div class="card-footer" id="actions-${{task.id}}">
                        ${{actionsHtml}}
                    </div>
                </div>
            `;
            list.insertBefore(wrapper, list.firstChild);
        }}

        // Poll for live status updates every 3 seconds
        setInterval(async () => {{
            try {{
                const response = await fetch('/queue');
                if (!response.ok) return;
                const tasks = await response.json();
                
                let pending = 0;
                let approved = 0;
                let rejected = 0;

                tasks.forEach(task => {{
                    const status = task.status.toLowerCase();
                    if (status === 'pending') pending++;
                    else if (status === 'approved' || status === 'completed') approved++;
                    else if (status === 'rejected') rejected++;

                    const badge = document.getElementById('badge-' + task.id);
                    const cardWrapper = document.getElementById('card-wrapper-' + task.id);
                    
                    if (!cardWrapper) {{
                        addNewCard(task);
                        return;
                    }}
                    
                    const card = cardWrapper.querySelector('.proposal-card');
                    const actionsDiv = document.getElementById('actions-' + task.id);
                    
                    if (badge) {{
                        const currentStatus = badge.innerText.toLowerCase();
                        if (currentStatus !== status) {{
                            badge.innerText = task.status.toUpperCase();
                            badge.className = 'badge ' + status;
                            card.className = 'proposal-card ' + status;

                            if (status !== 'pending') {{
                                const resolvedStr = task.resolved_at ? task.resolved_at.slice(0, 16).replace('T', ' ') : '';
                                actionsDiv.innerHTML = `<div class="actions-resolved"><span class="resolved-label">Resolved at ${{resolvedStr}}</span></div>`;
                            }} else {{
                                actionsDiv.innerHTML = `
                                <div class="actions">
                                    <button class="btn btn-approve" onclick="resolveTask('${{task.id}}', 'approve')">Approve</button>
                                    <button class="btn btn-reject" onclick="resolveTask('${{task.id}}', 'reject')">Skip</button>
                                </div>`;
                            }}
                        }}
                    }}
                }});

                const pElem = document.getElementById('count-pending');
                const aElem = document.getElementById('count-approved');
                const rElem = document.getElementById('count-rejected');
                
                if (pElem) pElem.innerText = pending;
                if (aElem) aElem.innerText = approved;
                if (rElem) rElem.innerText = rejected;

            }} catch (err) {{
                console.error('Error polling live tasks:', err);
            }}
        }}, 3000);
    </script>

</body>
</html>"""
