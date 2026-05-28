#!/usr/bin/env python3
"""Tank Autopilot: free local self-improvement loop for NOBS.

This agent uses only local Tank resources:
- Ollama models already installed on Tank
- Local repo/code samples
- Local JSONL + Markdown reports

It deliberately does not push, deploy, or rewrite product code. It keeps Tank
busy producing concrete, reviewable website and iOS improvement missions.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import urllib.error
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
ROUTER_URL = os.environ.get("ROUTER_URL", "http://127.0.0.1:4000")
FAST_MODEL = os.environ.get("TANK_FAST_MODEL", "qwen3:4b")
DEEP_MODEL = os.environ.get("TANK_DEEP_MODEL", "qwen3:14b")
SMALL_MODEL = os.environ.get("TANK_SMALL_MODEL", "llama3.2:3b")

SITE_DIR = Path(os.environ.get("TANK_SITE_DIR", "/var/www/nobsdash"))
APP_DIR = Path(os.environ.get("TANK_APP_DIR", "/home/alex/production/NOBS"))
LOG_DIR = Path(os.environ.get("TANK_AUTOPILOT_DIR", "/home/alex/logs/tank-autopilot"))
REPORT_DIR = LOG_DIR / "reports"
RAW_DIR = LOG_DIR / "raw"
QUEUE_FILE = LOG_DIR / "improvement-queue.jsonl"
MEMORY_FILE = LOG_DIR / "improvement-memory.jsonl"
STATE_FILE = LOG_DIR / "state.json"

LOG_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)
RAW_DIR.mkdir(parents=True, exist_ok=True)


@dataclass
class Proposal:
    ts: str
    area: str
    title: str
    mission: str
    files: list[str]
    priority: str
    confidence: str
    source_model: str


def log(message: str) -> None:
    line = f"[{datetime.now().isoformat(timespec='seconds')}] {message}"
    print(line, flush=True)
    with (LOG_DIR / "tank-autopilot.log").open("a") as handle:
        handle.write(line + "\n")


def run(cmd: list[str], cwd: Path | None = None, timeout: int = 20) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, timeout=timeout, text=True, capture_output=True)


def ask_ollama(model: str, prompt: str, system: str, *, timeout: int = 420, max_tokens: int = 2200) -> str:
    if model.startswith("qwen3"):
        prompt = "/no_think\n" + prompt
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system,
        "stream": False,
        "keep_alive": "90m",
        "options": {
            "temperature": 0.25,
            "num_predict": max_tokens,
        },
    }
    request = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "tank-autopilot/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read()).get("response", "")


def ask_router_tier(prompt: str, *, tier: str = "tier/cheap", timeout: int = 1200, max_tokens: int = 900) -> str:
    payload = {
        "model": tier,
        "messages": [
            {"role": "system", "content": "You are a senior product engineer. Output valid JSON only."},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": max_tokens,
        "temperature": 0.2,
    }
    request = urllib.request.Request(
        f"{ROUTER_URL}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "tank-autopilot/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = json.loads(response.read())
    return body.get("choices", [{}])[0].get("message", {}).get("content", "")


def extract_json_array(text: str) -> list[dict[str, Any]]:
    text = text.strip()
    if text.startswith("["):
        try:
            return json.loads(text)
        except Exception:
            pass
    for block in text.split("```"):
        block = block.strip()
        if block.startswith("json"):
            block = block[4:].strip()
        if block.startswith("["):
            try:
                return json.loads(block)
            except Exception:
                pass
    match = re.search(r"\[\s*\{.*\}\s*\]", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except Exception:
            return []
    return []


def extract_markdown_missions(text: str) -> list[dict[str, Any]]:
    missions: list[dict[str, Any]] = []
    blocks = re.split(r"\n\s*\*\*Mission\s+\d+[^*]*\*\*|\n\s*Mission\s+\d+[:.\-]", text, flags=re.IGNORECASE)
    for block in blocks:
        if not block.strip():
            continue
        title = ""
        mission = ""
        priority = "medium"
        confidence = "medium"
        files: list[str] = []
        for line in block.splitlines():
            clean = line.strip().lstrip("*- ").strip()
            match = re.match(r"\*\*(Title|Mission|Files|Priority|Confidence):\*\*\s*(.*)", clean, flags=re.IGNORECASE)
            if not match:
                match = re.match(r"(Title|Mission|Files|Priority|Confidence):\s*(.*)", clean, flags=re.IGNORECASE)
            if not match:
                continue
            key = match.group(1).lower()
            value = match.group(2).strip()
            if key == "title":
                title = value
            elif key == "mission":
                mission = value
            elif key == "files":
                files = [item.strip().strip("`") for item in re.split(r",|\n", value) if item.strip()]
            elif key == "priority":
                priority = value.lower()
            elif key == "confidence":
                confidence = value.lower()
        if title and mission:
            missions.append(
                {
                    "title": title,
                    "mission": mission,
                    "files": files,
                    "priority": priority,
                    "confidence": confidence,
                }
            )
    return missions


def git_snapshot(repo: Path) -> str:
    if not (repo / ".git").exists():
        return "not a git repo"
    status = run(["git", "status", "--short", "--branch"], cwd=repo, timeout=10)
    recent = run(["git", "log", "--oneline", "-5"], cwd=repo, timeout=10)
    return f"STATUS\n{status.stdout.strip()}\n\nRECENT COMMITS\n{recent.stdout.strip()}"


def sample_files(root: Path, patterns: tuple[str, ...], limit: int, chars_per_file: int) -> str:
    if not root.exists():
        return f"{root} missing"
    files: list[Path] = []
    for pattern in patterns:
        files.extend(root.rglob(pattern))
    clean = []
    for path in sorted(set(files), key=lambda item: (len(item.parts), str(item))):
        if any(part in {".git", ".build", "DerivedData", "node_modules", "venv", "__pycache__"} for part in path.parts):
            continue
        try:
            if path.stat().st_size > 180_000:
                continue
        except OSError:
            continue
        clean.append(path)
        if len(clean) >= limit:
            break

    chunks = []
    for path in clean:
        try:
            rel = path.relative_to(root)
            content = path.read_text(errors="replace")[:chars_per_file]
            chunks.append(f"### {rel}\n```\n{content}\n```")
        except Exception:
            continue
    return "\n\n".join(chunks) if chunks else "no files sampled"


def sampled_paths(sample: str) -> set[str]:
    return set(re.findall(r"^###\s+(.+)$", sample, flags=re.MULTILINE))


def load_memory(area: str, limit: int = 8) -> list[dict[str, Any]]:
    if not MEMORY_FILE.exists():
        return []
    out: list[dict[str, Any]] = []
    with MEMORY_FILE.open(errors="replace") as handle:
        for line in handle:
            try:
                item = json.loads(line)
            except Exception:
                continue
            if item.get("area") != area:
                continue
            out.append(item)
    return out[-limit:]


def append_memory(records: list[dict[str, Any]]) -> None:
    if not records:
        return
    with MEMORY_FILE.open("a") as handle:
        for item in records:
            handle.write(json.dumps(item) + "\n")


def website_sample() -> str:
    return sample_files(SITE_DIR, ("*.html", "*.css", "*.js"), limit=12, chars_per_file=4500)


def ios_sample() -> str:
    return sample_files(
        APP_DIR,
        ("*.swift", "Package.swift", "project.yml"),
        limit=14,
        chars_per_file=4200,
    )


def review_area(area: str, sample: str, repo_state: str, model: str, fallback_model: str) -> list[Proposal]:
    available_paths = sorted(sampled_paths(sample))
    memory = load_memory(area)
    prompt = f"""Tank Autopilot is improving NOBS using only local resources.

AREA: {area}

REPO STATE:
{repo_state}

CODE SAMPLE:
{sample}

AVAILABLE FILE PATHS:
{json.dumps(available_paths[:80], indent=2)}

RECENT MEMORY (what worked recently):
{json.dumps(memory, indent=2)}

Create concrete improvement missions that a coding agent or Alex can implement later.

Rules:
- Do not invent files. Use only AVAILABLE FILE PATHS unless the mission explicitly creates a new file.
- Prefer small, shippable improvements over vague rewrites.
- Include exact file paths/classes/selectors when possible.
- Do not recommend paid services.
- Do not recommend backups right now.
- Do not include secrets, tokens, or private values.
- Avoid purely cosmetic churn; connect each idea to stability, conversion, polish, performance, accessibility, or iOS quality.
- If the repo has uncommitted work, avoid missions that require broad refactors.
- Produce 3 to 6 proposals. Even if the code is healthy, identify incremental improvements.

Output ONLY valid JSON array:
[
  {{
    "title": "Short imperative title",
    "mission": "Specific implementation instructions and rationale",
    "files": ["path/or/component"],
    "priority": "high|medium|low",
    "confidence": "high|medium|low"
  }}
]"""
    raw = ""
    used_model = model
    try:
        raw = ask_ollama(
            model,
            prompt,
            "You are a senior product engineer. Output valid JSON only.",
            max_tokens=1500,
        )
    except Exception as exc:
        log(f"{area} primary model failed ({model}): {exc}")
    if not raw.strip():
        try:
            used_model = fallback_model
            raw = ask_ollama(
                fallback_model,
                prompt,
                "You are a senior product engineer. Output valid JSON only.",
                max_tokens=1200,
            )
            log(f"{area} used fallback model {fallback_model}")
        except Exception as exc:
            log(f"{area} fallback model failed ({fallback_model}): {exc}")
    raw_path = RAW_DIR / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{area}-{model.replace(':', '-')}.txt"
    raw_path.write_text(raw)
    proposals = []
    now = datetime.now(timezone.utc).isoformat()
    parsed = extract_json_array(raw)
    if not parsed:
        parsed = extract_markdown_missions(raw)
    if not parsed:
        log(f"{area} produced no parseable JSON; raw={raw_path}")
    for item in parsed:
        title = str(item.get("title", "")).strip()
        mission = str(item.get("mission", "")).strip()
        if not title or not mission:
            continue
        files = [str(path)[:220] for path in item.get("files", []) if str(path).strip()][:8]
        mission_lower = mission.lower()
        valid_files = [
            path for path in files
            if path in available_paths or "new file" in mission_lower or "create " in mission_lower
        ]
        if files and not valid_files:
            log(f"{area} rejected proposal with unknown files: {title} -> {files}")
            continue
        proposals.append(
            Proposal(
                ts=now,
                area=area,
                title=title[:180],
                mission=mission[:2200],
                files=valid_files,
                priority=str(item.get("priority", "medium")).lower() if str(item.get("priority", "")).lower() in {"high", "medium", "low"} else "medium",
                confidence=str(item.get("confidence", "medium")).lower() if str(item.get("confidence", "")).lower() in {"high", "medium", "low"} else "medium",
                source_model=used_model,
            )
        )
    return proposals


def refine_low_confidence(area: str, proposals: list[Proposal], sample: str) -> list[Proposal]:
    low = [p for p in proposals if p.confidence == "low"]
    if not low:
        return proposals
    out = list(proposals)
    for idx, prop in enumerate(low, start=1):
        prompt = f"""Improve this low-confidence proposal for NOBS {area}. Keep it small and concrete.

PROPOSAL:
{json.dumps(asdict(prop), indent=2)}

CODE SAMPLE:
{sample[:7000]}

Output JSON only:
{{
  "title": "improved title",
  "mission": "improved mission with exact steps",
  "files": ["path1", "path2"],
  "priority": "high|medium|low",
  "confidence": "high|medium|low"
}}"""
        try:
            raw = ask_router_tier(prompt, tier="tier/cheap", max_tokens=700)
            candidate = extract_json_array(raw)
            if candidate:
                item = candidate[0]
            else:
                parsed = json.loads(raw)
                item = parsed if isinstance(parsed, dict) else {}
            title = str(item.get("title", "")).strip()
            mission = str(item.get("mission", "")).strip()
            if title and mission:
                prop.title = title[:180]
                prop.mission = mission[:2200]
                prop.files = [str(x)[:220] for x in item.get("files", []) if str(x).strip()][:8] or prop.files
                prop.priority = str(item.get("priority", prop.priority)).lower() if str(item.get("priority", "")).lower() in {"high", "medium", "low"} else prop.priority
                prop.confidence = str(item.get("confidence", "medium")).lower() if str(item.get("confidence", "")).lower() in {"high", "medium", "low"} else "medium"
                prop.source_model = f"{prop.source_model}+tier/cheap"
                log(f"{area} refined low-confidence proposal {idx}/{len(low)} via tier/cheap")
        except Exception as exc:
            log(f"{area} low-confidence refinement failed: {exc}")
    return out


def dedupe_key(prop: Proposal) -> str:
    text = f"{prop.area}:{prop.title}".lower()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def load_seen() -> set[str]:
    if not QUEUE_FILE.exists():
        return set()
    seen = set()
    with QUEUE_FILE.open() as handle:
        for line in handle:
            try:
                data = json.loads(line)
                seen.add(data.get("dedupe_key", ""))
            except Exception:
                continue
    return seen


def save_proposals(proposals: list[Proposal]) -> list[Proposal]:
    seen = load_seen()
    new_items = []
    with QUEUE_FILE.open("a") as handle:
        for prop in proposals:
            key = dedupe_key(prop)
            if key in seen:
                continue
            record = asdict(prop)
            record["dedupe_key"] = key
            record["status"] = "proposed"
            handle.write(json.dumps(record) + "\n")
            seen.add(key)
            new_items.append(prop)
    return new_items


def write_report(proposals: list[Proposal], health: str) -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = REPORT_DIR / f"autopilot-{stamp}.md"
    lines = [
        "# Tank Autopilot Report",
        "",
        f"- Time: {datetime.now().isoformat(timespec='seconds')}",
        f"- Website: {SITE_DIR}",
        f"- iOS app: {APP_DIR}",
        f"- New proposals: {len(proposals)}",
        "",
        "## Health",
        "",
        "```text",
        health.strip()[:4000],
        "```",
        "",
        "## Proposals",
        "",
    ]
    for idx, prop in enumerate(proposals, start=1):
        lines.extend(
            [
                f"### {idx}. {prop.title}",
                "",
                f"- Area: {prop.area}",
                f"- Priority: {prop.priority}",
                f"- Confidence: {prop.confidence}",
                f"- Model: {prop.source_model}",
                f"- Files: {', '.join(prop.files) if prop.files else 'unspecified'}",
                "",
                prop.mission,
                "",
            ]
        )
    path.write_text("\n".join(lines))
    return path


def warm_models() -> None:
    for model in (SMALL_MODEL, FAST_MODEL):
        try:
            ask_ollama(model, "Reply with OK.", "Keep this model warm. Output OK only.", timeout=60, max_tokens=8)
            log(f"warmed {model}")
        except Exception as exc:
            log(f"warm failed for {model}: {exc}")


def run_tank_doctor() -> str:
    doctor = Path("/usr/local/bin/tank-doctor")
    if not doctor.exists():
        doctor = Path("/home/alex/tank-doctor.py")
    if not doctor.exists():
        return "tank-doctor not installed"
    result = run([str(doctor), "--no-public"], timeout=60)
    return (result.stdout + result.stderr).strip()


def run_cycle(deep: bool = False, warm_only: bool = False) -> int:
    started = time.time()
    log("cycle start")
    warm_models()
    if warm_only:
        log("warm-only complete")
        return 0

    health = run_tank_doctor()
    model = DEEP_MODEL if deep else FAST_MODEL
    fallback_model = SMALL_MODEL if model != SMALL_MODEL else FAST_MODEL
    proposals: list[Proposal] = []
    memory_records: list[dict[str, Any]] = []

    try:
        log("reviewing website")
        web_sample = website_sample()
        web_props = review_area("website", web_sample, git_snapshot(SITE_DIR), model, fallback_model)
        web_props = refine_low_confidence("website", web_props, web_sample)
        proposals.extend(web_props)
        memory_records.extend(
            {"ts": datetime.now(timezone.utc).isoformat(), "area": "website", "title": p.title, "priority": p.priority, "confidence": p.confidence, "files": p.files}
            for p in web_props
        )
    except Exception as exc:
        log(f"website review failed: {exc}")

    try:
        log("reviewing ios")
        app_sample = ios_sample()
        ios_props = review_area("ios", app_sample, git_snapshot(APP_DIR), model, fallback_model)
        ios_props = refine_low_confidence("ios", ios_props, app_sample)
        proposals.extend(ios_props)
        memory_records.extend(
            {"ts": datetime.now(timezone.utc).isoformat(), "area": "ios", "title": p.title, "priority": p.priority, "confidence": p.confidence, "files": p.files}
            for p in ios_props
        )
    except Exception as exc:
        log(f"iOS review failed: {exc}")

    new_items = save_proposals(proposals)
    append_memory(memory_records)
    report = write_report(new_items, health)
    STATE_FILE.write_text(
        json.dumps(
            {
                "last_run": datetime.now(timezone.utc).isoformat(),
                "duration_s": round(time.time() - started, 2),
                "model": model,
                "proposals_total": len(proposals),
                "proposals_new": len(new_items),
                "last_report": str(report),
            },
            indent=2,
        )
    )
    log(f"cycle complete: {len(new_items)} new proposals, report={report}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Tank local self-improvement autopilot.")
    parser.add_argument("--deep", action="store_true", help="Use the larger local model for this cycle.")
    parser.add_argument("--warm-only", action="store_true", help="Only keep local models warm.")
    args = parser.parse_args()
    return run_cycle(deep=args.deep, warm_only=args.warm_only)


if __name__ == "__main__":
    sys.exit(main())
