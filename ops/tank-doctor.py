#!/usr/bin/env python3
"""Free Tank health check.

Designed for SSH, cron, and Uptime Kuma command/push checks. It avoids secrets in
output and exits non-zero when critical checks fail.
"""
from __future__ import annotations

import argparse
import json
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any


CRITICAL_SERVICES = [
    "nginx",
    "cloudflared",
    "ollama",
    "docker",
    "syncthing@alex",
    "smbd",
    "ssh",
    "tailscaled",
]

OBSOLETE_UNITS = [
    "nobs-dashboard.service",
    "voice-chat-web.service",
    "self-agent-dashboard.service",
]

LOCAL_ENDPOINTS = {
    "memories-api": "http://127.0.0.1:8090/healthz",
    "llm-router": "http://127.0.0.1:4000/healthz",
    "ollama-tags": "http://127.0.0.1:11434/api/tags",
}

PUBLIC_ENDPOINTS = {
    "nobs-api-ping": "https://nobsdash.com/api/v1/ping",
}

COMPOSE_DIR = Path("/home/alex/nobs-stack")


@dataclass
class Check:
    name: str
    ok: bool
    detail: str
    severity: str = "critical"


def run(cmd: list[str], timeout: int = 8, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout)


def http_get(url: str, timeout: int = 8) -> tuple[bool, str]:
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "tank-doctor/1.0"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read(300).decode("utf-8", errors="replace").strip()
            return 200 <= response.status < 300, f"HTTP {response.status} {body[:120]}"
    except Exception as exc:
        return False, str(exc)


def port_open(host: str, port: int, timeout: float = 2.0) -> tuple[bool, str]:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, f"{host}:{port} listening"
    except OSError as exc:
        return False, f"{host}:{port} {exc}"


def check_system() -> list[Check]:
    checks: list[Check] = []
    try:
        load1, load5, load15 = Path("/proc/loadavg").read_text().split()[:3]
        checks.append(Check("load", True, f"{load1} {load5} {load15}", "info"))
    except Exception as exc:
        checks.append(Check("load", False, str(exc), "warning"))

    mem = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, value = line.split(":", 1)
            mem[key] = int(value.strip().split()[0])
        avail_gib = mem["MemAvailable"] / 1024 / 1024
        total_gib = mem["MemTotal"] / 1024 / 1024
        checks.append(Check("memory", avail_gib >= 2, f"{avail_gib:.1f}GiB available / {total_gib:.1f}GiB total"))
    except Exception as exc:
        checks.append(Check("memory", False, str(exc)))

    for path in ["/", "/mnt/training"]:
        try:
            usage = shutil.disk_usage(path)
            used_pct = (usage.used / usage.total) * 100
            checks.append(Check(f"disk:{path}", used_pct < 85, f"{used_pct:.1f}% used, {usage.free // (1024**3)}GiB free"))
        except Exception as exc:
            checks.append(Check(f"disk:{path}", False, str(exc)))

    return checks


def check_systemd() -> list[Check]:
    checks: list[Check] = []
    failed = run(["systemctl", "--failed", "--no-legend", "--plain"], timeout=8)
    failed_lines = [line for line in failed.stdout.splitlines() if line.strip()]
    checks.append(Check("systemd-failed", not failed_lines, "0 failed units" if not failed_lines else "; ".join(failed_lines[:5])))

    for service in CRITICAL_SERVICES:
        result = run(["systemctl", "is-active", service], timeout=5)
        state = result.stdout.strip() or result.stderr.strip()
        checks.append(Check(f"service:{service}", state == "active", state))

    for unit in OBSOLETE_UNITS:
        active = run(["systemctl", "is-active", unit], timeout=5)
        enabled = run(["systemctl", "is-enabled", unit], timeout=5)
        active_state = active.stdout.strip() or active.stderr.strip()
        enabled_state = enabled.stdout.strip() or enabled.stderr.strip()
        detail = f"active={active_state} enabled={enabled_state}"
        checks.append(Check(f"obsolete:{unit}", active_state != "active" and enabled_state != "enabled", detail, "warning"))

    return checks


def check_docker() -> list[Check]:
    checks: list[Check] = []
    if not COMPOSE_DIR.exists():
        return [Check("compose-dir", False, f"missing {COMPOSE_DIR}")]

    ps = run(["docker", "compose", "ps", "--format", "json"], cwd=COMPOSE_DIR, timeout=12)
    if ps.returncode != 0:
        return [Check("docker-compose", False, ps.stderr.strip() or "compose ps failed")]

    services = []
    unhealthy = []
    for line in ps.stdout.splitlines():
        if not line.strip():
            continue
        try:
            item: dict[str, Any] = json.loads(line)
        except json.JSONDecodeError:
            continue
        name = item.get("Name") or item.get("Service") or "unknown"
        status = item.get("Status", "")
        state = item.get("State", "")
        health = item.get("Health", "")
        services.append(f"{name}:{status}")
        if state != "running" or health == "unhealthy" or "Restarting" in status:
            unhealthy.append(f"{name}:{status}")

    checks.append(Check("docker-compose", not unhealthy, f"{len(services)} services; " + ("ok" if not unhealthy else "; ".join(unhealthy))))
    return checks


def check_endpoints(include_public: bool) -> list[Check]:
    checks: list[Check] = []
    for name, url in LOCAL_ENDPOINTS.items():
        ok, detail = http_get(url)
        checks.append(Check(f"local:{name}", ok, detail))

    for name, host, port in [
        ("ssh", "127.0.0.1", 22),
        ("samba", "127.0.0.1", 445),
        ("syncthing", "127.0.0.1", 8384),
    ]:
        ok, detail = port_open(host, port)
        checks.append(Check(f"port:{name}", ok, detail))

    if include_public:
        for name, url in PUBLIC_ENDPOINTS.items():
            ok, detail = http_get(url, timeout=10)
            checks.append(Check(f"public:{name}", ok, detail))

    return checks


def check_journal() -> list[Check]:
    result = run(["journalctl", "-p", "warning..alert", "--since", "15 min ago", "--no-pager", "-n", "40"], timeout=8)
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    noisy_veth = [line for line in lines if "Interface \"veth" in line and "not found" in line]
    known_noise = [
        line
        for line in lines
        if "systemd-sysv-generator" in line
        or any(unit in line for unit in OBSOLETE_UNITS)
    ]
    meaningful = [line for line in lines if line not in noisy_veth and line not in known_noise]
    if meaningful:
        return [Check("journal-warnings", False, f"{len(meaningful)} recent warnings; latest: {meaningful[-1][:160]}", "warning")]
    ignored = len(noisy_veth) + len(known_noise)
    return [Check("journal-warnings", True, f"0 meaningful warnings ({ignored} known-noise notices ignored)", "warning")]


def summarize(checks: list[Check]) -> dict[str, Any]:
    critical_failures = [c for c in checks if not c.ok and c.severity == "critical"]
    warnings = [c for c in checks if not c.ok and c.severity != "critical"]
    return {
        "ok": not critical_failures,
        "critical_failures": len(critical_failures),
        "warnings": len(warnings),
        "checks": [asdict(c) for c in checks],
        "timestamp": int(time.time()),
    }


def print_human(report: dict[str, Any]) -> None:
    status = "OK" if report["ok"] else "FAIL"
    print(f"Tank Doctor: {status} ({report['critical_failures']} critical, {report['warnings']} warnings)")
    for item in report["checks"]:
        mark = "OK" if item["ok"] else ("WARN" if item["severity"] != "critical" else "FAIL")
        print(f"[{mark}] {item['name']}: {item['detail']}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Tank health checks.")
    parser.add_argument("--json", action="store_true", help="Print JSON only.")
    parser.add_argument("--no-public", action="store_true", help="Skip public Cloudflare checks.")
    args = parser.parse_args()

    checks: list[Check] = []
    checks.extend(check_system())
    checks.extend(check_systemd())
    checks.extend(check_docker())
    checks.extend(check_endpoints(include_public=not args.no_public))
    checks.extend(check_journal())

    report = summarize(checks)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_human(report)
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
