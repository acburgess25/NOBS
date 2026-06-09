from __future__ import annotations

import json
import os
import secrets
import shutil
import socket
import sqlite3
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import httpx
import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, status
from passlib.context import CryptContext
from pydantic import BaseModel, Field


DATA_DIR = Path(os.getenv("NOBS_DATA_DIR", "/data"))
DB_PATH = DATA_DIR / "nobs-beta.sqlite3"
JWT_SECRET = os.environ["NOBS_JWT_SECRET"]
JWT_ALGORITHM = "HS256"
BOOTSTRAP_USERNAME = os.getenv("NOBS_BOOTSTRAP_USERNAME", "alex")
BOOTSTRAP_PASSWORD = os.getenv("NOBS_BOOTSTRAP_PASSWORD", "")
EXEC_TOKEN = os.getenv("NOBS_EXEC_TOKEN", "")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434").rstrip("/")
LITELLM_URL = os.getenv("LITELLM_URL", "http://host.docker.internal:4000").rstrip("/")
MAX_BETA_USERS = int(os.getenv("NOBS_MAX_BETA_USERS", "10"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
app = FastAPI(title="NOBS Beta API", version="0.1.0")


class Credentials(BaseModel):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=256)


class LoginResponse(BaseModel):
    token: str
    username: str


class SubscriptionPayload(BaseModel):
    tier: str = Field(default="server", max_length=80)


class ExecPayload(BaseModel):
    command: str = Field(min_length=1, max_length=400)


def db() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with db() as conn:
        conn.executescript(
            """
            create table if not exists users (
                id integer primary key autoincrement,
                username text not null unique,
                password_hash text not null,
                created_at text not null
            );
            create table if not exists subscriptions (
                username text primary key,
                tier text not null,
                updated_at text not null
            );
            create table if not exists settings (
                key text primary key,
                value text not null
            );
            """
        )
        if BOOTSTRAP_PASSWORD:
            existing = conn.execute(
                "select username from users where username = ?",
                (BOOTSTRAP_USERNAME,),
            ).fetchone()
            if existing is None:
                conn.execute(
                    "insert into users (username, password_hash, created_at) values (?, ?, ?)",
                    (
                        BOOTSTRAP_USERNAME,
                        pwd_context.hash(BOOTSTRAP_PASSWORD),
                        datetime.now(timezone.utc).isoformat(),
                    ),
                )
        
        existing_tf = conn.execute(
            "select value from settings where key = 'testflight_links'"
        ).fetchone()
        if existing_tf is None:
            default_links = ["https://testflight.apple.com/join/cs7znFqY"]
            conn.execute(
                "insert into settings (key, value) values ('testflight_links', ?)",
                (json.dumps(default_links),),
            )


@app.on_event("startup")
def startup() -> None:
    init_db()


def create_token(username: str) -> str:
    expires = datetime.now(timezone.utc) + timedelta(days=30)
    return jwt.encode({"sub": username, "exp": expires}, JWT_SECRET, algorithm=JWT_ALGORITHM)


def current_username(x_nobs_token: str | None = Header(default=None)) -> str:
    if not x_nobs_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
    try:
        payload = jwt.decode(x_nobs_token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    username = payload.get("sub")
    if not isinstance(username, str) or not username:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    with db() as conn:
        found = conn.execute("select username from users where username = ?", (username,)).fetchone()
    if found is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unknown user")
    return username


@app.get("/healthz")
def healthz() -> dict[str, Any]:
    return {"ok": True, "service": "nobs-api"}


@app.get("/api/v1/ping")
def ping() -> dict[str, Any]:
    return {"ok": True, "service": "nobs-api"}


@app.get("/api/v1/heartbeat")
def heartbeat() -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    checks: list[dict[str, Any]] = [
        {"name": "api", "ok": True, "detail": socket.gethostname()},
    ]

    try:
        with db() as conn:
            conn.execute("select 1").fetchone()
        checks.append({"name": "database", "ok": True, "detail": str(DB_PATH)})
    except Exception as exc:
        checks.append({"name": "database", "ok": False, "detail": str(exc)})

    try:
        usage = shutil.disk_usage(DATA_DIR)
        free_percent = round((usage.free / usage.total) * 100, 1)
        checks.append({
            "name": "storage",
            "ok": free_percent > 5,
            "detail": f"{free_percent}% free",
        })
    except Exception as exc:
        checks.append({"name": "storage", "ok": False, "detail": str(exc)})

    return {
        "ok": all(item["ok"] for item in checks),
        "service": "nobs",
        "heartbeat": "alive",
        "checkedAt": now,
        "checks": checks,
    }


@app.post("/api/v1/auth/register")
def register(credentials: Credentials) -> dict[str, Any]:
    with db() as conn:
        existing = conn.execute(
            "select username from users where username = ?",
            (credentials.username,),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="Username already exists")
        count = conn.execute("select count(*) from users").fetchone()[0]
        if count >= MAX_BETA_USERS:
            raise HTTPException(status_code=403, detail="Beta is full — contact the admin to request access")
        conn.execute(
            "insert into users (username, password_hash, created_at) values (?, ?, ?)",
            (
                credentials.username,
                pwd_context.hash(credentials.password),
                datetime.now(timezone.utc).isoformat(),
            ),
        )
    return {"ok": True, "username": credentials.username}


@app.post("/api/v1/auth/login", response_model=LoginResponse)
def login(credentials: Credentials) -> LoginResponse:
    with db() as conn:
        user = conn.execute(
            "select username, password_hash from users where username = ?",
            (credentials.username,),
        ).fetchone()
    if user is None or not pwd_context.verify(credentials.password, user["password_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    return LoginResponse(token=create_token(user["username"]), username=user["username"])


@app.post("/api/v1/auth/logout")
def logout(_: str = Depends(current_username)) -> dict[str, Any]:
    return {"ok": True}


@app.post("/api/v1/agency/subscription")
def sync_agency_subscription(
    payload: SubscriptionPayload,
    username: str = Depends(current_username),
) -> dict[str, Any]:
    with db() as conn:
        conn.execute(
            """
            insert into subscriptions (username, tier, updated_at)
            values (?, ?, ?)
            on conflict(username) do update set
                tier = excluded.tier,
                updated_at = excluded.updated_at
            """,
            (username, payload.tier, datetime.now(timezone.utc).isoformat()),
        )
    return {"ok": True, "username": username, "tier": payload.tier}


async def check_http(name: str, url: str) -> dict[str, Any]:
    try:
        async with httpx.AsyncClient(timeout=3) as client:
            response = await client.get(url)
        return {"name": name, "ok": response.status_code < 500, "detail": f"HTTP {response.status_code}"}
    except Exception as exc:
        return {"name": name, "ok": False, "detail": str(exc)}


def check_port(name: str, host: str, port: int) -> dict[str, Any]:
    try:
        with socket.create_connection((host, port), timeout=2):
            return {"name": name, "ok": True, "detail": f"{host}:{port} listening"}
    except OSError as exc:
        return {"name": name, "ok": False, "detail": f"{host}:{port} {exc}"}


@app.get("/api/v1/tank/scan")
async def tank_scan(_: str = Depends(current_username)) -> dict[str, Any]:
    required_checks = [
        {"name": "api", "ok": True, "detail": socket.gethostname()},
        check_port("ollama-port", "host.docker.internal", 11434),
        await check_http("ollama-api", f"{OLLAMA_URL}/api/tags"),
    ]
    optional_checks = [
        {**check_port("litellm-port", "host.docker.internal", 4000), "optional": True},
        {**await check_http("litellm-api", f"{LITELLM_URL}/health"), "optional": True},
    ]
    checks = required_checks + optional_checks
    return {"ok": all(item["ok"] for item in required_checks), "checks": checks}


SAFE_COMMANDS = {
    "disk": ["df", "-h", "/"],
    "uptime": ["uptime"],
    "ollama tags": ["curl", "-fsS", f"{OLLAMA_URL}/api/tags"],
}


@app.post("/api/v1/tank/exec")
def tank_exec(payload: ExecPayload, username: str = Depends(current_username)) -> dict[str, Any]:
    if not EXEC_TOKEN or not secrets.compare_digest(payload.command, EXEC_TOKEN):
        command = SAFE_COMMANDS.get(payload.command.strip())
        if command is None:
            allowed = ", ".join(sorted(SAFE_COMMANDS))
            raise HTTPException(status_code=403, detail=f"Command is not allowed. Allowed: {allowed}")
    else:
        command = ["uptime"]

    try:
        result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=10)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    return {
        "ok": result.returncode == 0,
        "username": username,
        "command": payload.command,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode,
    }


# --------------------------------------------------------------------------- testflight
TF_CACHE: dict[str, tuple[bool, float]] = {}
TF_CACHE_TTL = 300  # 5 minutes
MAILTO_FALLBACK = "mailto:hello@nobsdash.com?subject=NOBS%20beta%20access"

import time
from fastapi.responses import RedirectResponse

async def is_testflight_full(url: str) -> bool:
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        async with httpx.AsyncClient(timeout=3, headers=headers) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                html = resp.text
                if "This beta is full" in html or "not accepting any new testers" in html:
                    return True
                return False
    except Exception:
        pass
    return True # Assume full if checking fails to prevent sending users to broken links

async def check_link_status(url: str) -> bool:
    now = time.time()
    if url in TF_CACHE:
        val, expiry = TF_CACHE[url]
        if now < expiry:
            return val
    is_full = await is_testflight_full(url)
    TF_CACHE[url] = (is_full, now + TF_CACHE_TTL)
    return is_full

@app.get("/api/v1/testflight")
async def get_testflight_redirect() -> RedirectResponse:
    with db() as conn:
        row = conn.execute("select value from settings where key = 'testflight_links'").fetchone()
    
    links = []
    if row:
        try:
            links = json.loads(row["value"])
        except Exception:
            pass
            
    if not links:
        links = ["https://testflight.apple.com/join/cs7znFqY"]
        
    for link in links:
        if not await check_link_status(link):
            return RedirectResponse(url=link, status_code=status.HTTP_307_TEMPORARY_REDIRECT)
            
    return RedirectResponse(url=MAILTO_FALLBACK, status_code=status.HTTP_307_TEMPORARY_REDIRECT)

class TestflightLinksPayload(BaseModel):
    links: list[str]

@app.post("/api/v1/admin/testflight")
def update_testflight_links(
    payload: TestflightLinksPayload,
    username: str = Depends(current_username)
) -> dict[str, Any]:
    if username != BOOTSTRAP_USERNAME:
        raise HTTPException(status_code=403, detail="Only the admin can manage settings")
        
    for link in payload.links:
        if not link.startswith("https://testflight.apple.com/"):
            raise HTTPException(status_code=400, detail=f"Invalid TestFlight URL: {link}")
            
    with db() as conn:
        conn.execute(
            "insert into settings (key, value) values ('testflight_links', ?) "
            "on conflict(key) do update set value = excluded.value",
            (json.dumps(payload.links),)
        )
    return {"ok": True, "links": payload.links}

