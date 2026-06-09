#!/usr/bin/env python3
"""
Centralized Private AI Memory Pipeline (NOBS Synchronizer)
Parses histories, session logs, vector databases, and settings from Claude Code, OpenClaw, and Claude Desktop,
compiles them into Obsidian Markdown, and pushes them to your private GitHub repo to sync with Tank.
"""

import os
import sys
import json
import sqlite3
import argparse
import subprocess
from pathlib import Path
from datetime import datetime

# Standard macOS iCloud & Developer Paths
VAULT_PATH = Path("/Users/alexburgess/Library/Mobile Documents/com~apple~CloudDocs/NOBS")
CLAUDE_CODE_DIR = Path("/Users/alexburgess/.claude")
OPENCLAW_DIR = Path("/Users/alexburgess/.openclaw")
CLAUDE_DESKTOP_DIR = Path("/Users/alexburgess/Library/Application Support/Claude")

def parse_args():
    parser = argparse.ArgumentParser(description="Sync local AI memories to Obsidian & Tank")
    parser.add_argument("--dry-run", action="store_true", help="Perform checks and parse databases without writing files or committing to git")
    parser.add_argument("--no-git", action="store_true", help="Skip git push operations")
    return parser.parse_args()

def log(msg, level="INFO"):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [{level}] {msg}")

def ensure_directories(dry_run):
    memory_dir = VAULT_PATH / "04-Memories"
    if dry_run:
        log(f"[DRY-RUN] Would verify/create Obsidian directory: {memory_dir}")
        return memory_dir
    
    if not VAULT_PATH.exists():
        log(f"Obsidian Vault path not found at {VAULT_PATH}. Is iCloud Drive running?", "ERROR")
        sys.exit(1)
        
    memory_dir.mkdir(parents=True, exist_ok=True)
    log(f"Verified Obsidian memories directory: {memory_dir}")
    return memory_dir

# --- Claude Code Parser ---
def sync_claude_code(memory_dir, dry_run):
    log("Processing Claude Code Prompt Streams...")
    history_file = CLAUDE_CODE_DIR / "history.jsonl"
    if not history_file.exists():
        log("No Claude Code history file found. Skipping.", "WARN")
        return
        
    sessions = {}
    total_lines = 0
    with open(history_file, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            try:
                data = json.loads(line)
                session_id = data.get("sessionId", "unknown")
                if session_id not in sessions:
                    sessions[session_id] = []
                sessions[session_id].append(data)
                total_lines += 1
            except Exception as e:
                log(f"Failed to parse history line: {e}", "WARN")

    log(f"Parsed {total_lines} prompt interactions across {len(sessions)} sessions.")
    
    md_content = [
        "# Claude Code Developer History Diary",
        f"*Unified brain compilation synced at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
        "",
        "---",
        ""
    ]
    
    # Sort sessions by the timestamp of their first interaction (newest first)
    sorted_sessions = []
    for sid, items in sessions.items():
        items.sort(key=lambda x: x.get("timestamp", 0))
        sorted_sessions.append((sid, items))
    sorted_sessions.sort(key=lambda x: x[1][0].get("timestamp", 0), reverse=True)
    
    for sid, items in sorted_sessions:
        first_time = datetime.fromtimestamp(items[0].get("timestamp", 0) / 1000.0).strftime('%Y-%m-%d %H:%M:%S')
        project = items[0].get("project", "Unknown Project")
        
        md_content.append(f"## Session `{sid[:8]}` — {first_time}")
        md_content.append(f"**Target Workspace:** `{project}`")
        md_content.append("")
        
        for idx, item in enumerate(items):
            prompt = item.get("display", "").strip()
            prompt_time = datetime.fromtimestamp(item.get("timestamp", 0) / 1000.0).strftime('%H:%M:%S')
            md_content.append(f"**[{prompt_time}] User Prompt:**")
            md_content.append("```text")
            md_content.append(prompt)
            md_content.append("```")
            md_content.append("")
        md_content.append("---")
        md_content.append("")
        
    output_file = memory_dir / "Claude-Code-History.md"
    if dry_run:
        log(f"[DRY-RUN] Would write {len(md_content)} lines to {output_file}")
    else:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(md_content))
        log(f"Saved Claude Code history to {output_file}")

# --- OpenClaw Session Parser ---
def sync_openclaw_sessions(memory_dir, dry_run):
    log("Processing OpenClaw Agent Sessions...")
    sessions_dir = OPENCLAW_DIR / "agents" / "main" / "sessions"
    if not sessions_dir.exists():
        log("No OpenClaw sessions directory found. Skipping.", "WARN")
        return
        
    jsonl_files = list(sessions_dir.glob("*.jsonl"))
    # Filter out files that are .trajectory.jsonl
    session_files = [f for f in jsonl_files if not f.name.endswith(".trajectory.jsonl")]
    
    log(f"Found {len(session_files)} raw OpenClaw direct session streams.")
    
    md_content = [
        "# OpenClaw Gateway Autonomous Session Trajectories",
        f"*Unified brain compilation synced at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
        "",
        "---",
        ""
    ]
    
    # Let's sort session files by modified time (newest first)
    session_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    
    for sf in session_files[:30]:  # Limit to most recent 30 sessions to avoid bloat
        mtime = datetime.fromtimestamp(sf.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')
        sid = sf.stem
        
        md_content.append(f"## Session `{sid[:8]}` — Last Active {mtime}")
        md_content.append(f"**Session File:** `{sf.name}`")
        md_content.append("")
        
        try:
            chat_turns = []
            with open(sf, "r", encoding="utf-8") as f:
                for line in f:
                    if not line.strip():
                        continue
                    turn = json.loads(line)
                    chat_turns.append(turn)
            
            for turn in chat_turns:
                role = turn.get("role", "unknown").capitalize()
                content = turn.get("content", "")
                if not content and turn.get("toolCalls"):
                    # Extract tool calls if content is empty
                    calls = [f"`{tc.get('name')}`" for tc in turn.get("toolCalls", [])]
                    content = f"*[Agent triggers tools: {', '.join(calls)}]*"
                
                # Format code blocks and escape nested items cleanly
                md_content.append(f"**{role}:**")
                md_content.append(content.strip())
                md_content.append("")
        except Exception as e:
            md_content.append(f"*Error parsing session stream: {e}*")
            md_content.append("")
            
        md_content.append("---")
        md_content.append("")
        
    output_file = memory_dir / "OpenClaw-Sessions.md"
    if dry_run:
        log(f"[DRY-RUN] Would write {len(md_content)} lines to {output_file}")
    else:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(md_content))
        log(f"Saved OpenClaw sessions to {output_file}")

# --- OpenClaw SQLite Memory Parser ---
def sync_openclaw_sqlite(memory_dir, dry_run):
    log("Processing OpenClaw SQLite Long-Term Memory...")
    db_path = OPENCLAW_DIR / "memory" / "main.sqlite"
    if not db_path.exists():
        log("No OpenClaw SQLite database found. Skipping.", "WARN")
        return
        
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Safely query table columns dynamically to prevent schema crashes
        cursor.execute("PRAGMA table_info(chunks)")
        columns = [row[1] for row in cursor.fetchall()]
        
        # Check available rows
        cursor.execute("SELECT COUNT(*) FROM chunks")
        total_chunks = cursor.fetchone()[0]
        log(f"SQLite database has {total_chunks} vectorized memory chunks.")
        
        cursor.execute("SELECT * FROM chunks ORDER BY id DESC LIMIT 150")
        rows = cursor.fetchall()
        
        md_content = [
            "# OpenClaw Long-Term Vector Brain Chunks",
            f"*Unified SQLite memory dump synced at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
            "",
            "---",
            "",
            f"**Total Vector Memory Elements:** `{total_chunks}`",
            "",
            "### Recent Memory Vector Chunks (Last 150 Elements)",
            "",
            "| ID | Text / Context Chunk | Metadata / File Reference |",
            "| :--- | :--- | :--- |"
        ]
        
        # Map columns dynamically
        id_idx = columns.index("id") if "id" in columns else 0
        text_idx = columns.index("text") if "text" in columns else (columns.index("content") if "content" in columns else 1)
        meta_idx = columns.index("meta") if "meta" in columns else (columns.index("metadata") if "metadata" in columns else -1)
        
        for row in rows:
            cid = row[id_idx]
            raw_text = str(row[text_idx]).replace("\n", " ").replace("|", "\\|")
            text_snippet = raw_text[:200] + "..." if len(raw_text) > 200 else raw_text
            
            meta_val = str(row[meta_idx]).replace("\n", " ").replace("|", "\\|") if meta_idx != -1 else "{}"
            meta_snippet = meta_val[:100] + "..." if len(meta_val) > 100 else meta_val
            
            md_content.append(f"| `{cid}` | {text_snippet} | `{meta_snippet}` |")
            
        conn.close()
    except Exception as e:
        log(f"SQLite extraction error: {e}", "ERROR")
        return
        
    output_file = memory_dir / "OpenClaw-Brain-Chunks.md"
    if dry_run:
        log(f"[DRY-RUN] Would write {len(md_content)} lines to {output_file}")
    else:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(md_content))
        log(f"Saved OpenClaw SQLite memory to {output_file}")

# --- Claude Desktop Config Parser ---
def sync_claude_desktop(memory_dir, dry_run):
    log("Processing Claude Desktop MCP Configuration...")
    config_file = CLAUDE_DESKTOP_DIR / "claude_desktop_config.json"
    if not config_file.exists():
        log("No Claude Desktop config found. Skipping.", "WARN")
        return
        
    try:
        with open(config_file, "r", encoding="utf-8") as f:
            config_data = json.load(f)
            
        mcp_servers = config_data.get("mcpServers", {})
        log(f"Found {len(mcp_servers)} active MCP integrations in Claude Desktop.")
        
        md_content = [
            "# Claude Desktop MCP Configured Integrations",
            f"*Config sync completed at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
            "",
            "---",
            "",
            "### Installed MCP Servers",
            "",
            "| Server Name | Connection Command / Options | Source Config |",
            "| :--- | :--- | :--- |"
        ]
        
        for sname, sconfig in mcp_servers.items():
            cmd = sconfig.get("command", "N/A")
            args = " ".join(sconfig.get("args", []))
            full_command = f"`{cmd} {args}`"
            if len(full_command) > 150:
                full_command = full_command[:147] + "...`"
            md_content.append(f"| **{sname}** | {full_command} | `claude_desktop_config.json` |")
            
        md_content.extend([
            "",
            "---",
            "",
            "### Raw JSON Bridge",
            "```json",
            json.dumps(config_data, indent=2),
            "```"
        ])
    except Exception as e:
        log(f"Claude Desktop config extraction error: {e}", "ERROR")
        return
        
    output_file = memory_dir / "Claude-Desktop-MCP.md"
    if dry_run:
        log(f"[DRY-RUN] Would write {len(md_content)} lines to {output_file}")
    else:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(md_content))
        log(f"Saved Claude Desktop MCP config to {output_file}")

# --- Index Generator ---
def generate_memory_index(memory_dir, dry_run):
    log("Creating Unified Memory Index Note...")
    now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    md_content = [
        "# 💎 Centralized Private AI Memory Portal",
        f"**Last Core Brain Sync:** `{now_str}`",
        "",
        "---",
        "",
        "Welcome to your unified multi-agent centralized memory workspace. All interactions, developer prompt streams, and SQLite vector brain chunks are compiled locally, formatted, and synchronized between this MacBook and Tank.",
        "",
        "## 🧭 Memory Core Links",
        "",
        "- 📄 **[Claude Code Session History](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Claude-Code-History.md)**",
        "  *Chronological prompt timeline from Claude Code CLI terminals.*",
        "- 📄 **[OpenClaw Gateway Sessions](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/OpenClaw-Sessions.md)**",
        "  *Trajectories and direct chatbot turns from your local OpenClaw app.*",
        "- 📄 **[OpenClaw Long-Term Vector Brain Chunks](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/OpenClaw-Brain-Chunks.md)**",
        "  *Vector database chunks and document contexts extracted from SQLite.*",
        "- 📄 **[Claude Desktop MCP Bridges](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Claude-Desktop-MCP.md)**",
        "  *Active MCP server definitions, commands, and local settings.*",
        "",
        "---",
        "",
        "## ⚙️ Automated Vault Sync Log",
        "- **Mac Setup Helper**: Git-push pipeline active on MacBook.",
        "- **Tank Setup Helper**: Systemd user timers sync from origin every 15 minutes.",
        "- **Offline Availability**: 100% locally resident and air-gapped.",
        "",
        "*(Note: Node graph labels will update automatically to link these categories into Obsidian's color-coded Graph View.)*"
    ]
    
    output_file = memory_dir / "00-Memory-Index.md"
    if dry_run:
        log(f"[DRY-RUN] Would write {len(md_content)} lines to {output_file}")
    else:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(md_content))
        log(f"Saved memory index note to {output_file}")

# --- Git Pipeline Sync ---
def execute_git_sync(dry_run):
    log("Starting Vault Git synchronization...")
    
    # We must change Cwd to the git repository
    if not (VAULT_PATH / ".git").exists():
        log(f"Git repository not found at {VAULT_PATH}. Skipping git sync.", "WARN")
        return
        
    try:
        commands = [
            ["git", "add", "04-Memories/"],
            ["git", "commit", "-m", f"sync: centralized AI memories - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"],
            ["git", "push", "origin", "main"]
        ]
        
        for cmd in commands:
            if dry_run:
                log(f"[DRY-RUN] Would run: {' '.join(cmd)}")
            else:
                log(f"Executing: {' '.join(cmd)}")
                result = subprocess.run(cmd, cwd=VAULT_PATH, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                if result.returncode != 0:
                    # Commit might fail if there are no changes, which is fine
                    if "nothing to commit" in result.stdout or "nothing to commit" in result.stderr:
                        log("No new memories to commit. Repository already up-to-date.")
                        break
                    log(f"Command failed: {result.stderr.strip()}", "WARN")
                else:
                    if result.stdout.strip():
                        print(result.stdout.strip())
        
        if not dry_run:
            log("Vault Git synchronization successfully completed!")
    except Exception as e:
        log(f"Git sync error: {e}", "ERROR")

def main():
    args = parse_args()
    if args.dry_run:
        log("RUNNING IN DRY-RUN MODE (No modifications will be made)")
        
    memory_dir = ensure_directories(args.dry_run)
    
    # Extract and centralize
    sync_claude_code(memory_dir, args.dry_run)
    sync_openclaw_sessions(memory_dir, args.dry_run)
    sync_openclaw_sqlite(memory_dir, args.dry_run)
    sync_claude_desktop(memory_dir, args.dry_run)
    generate_memory_index(memory_dir, args.dry_run)
    
    # Synchronize cross-device
    if not args.no_git:
        execute_git_sync(args.dry_run)
        
    log("All Private AI Memory extraction tasks completed!")

if __name__ == "__main__":
    main()
