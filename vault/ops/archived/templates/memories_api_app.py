



from fastapi import FastAPI, Depends, Header, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import List
import httpx
import json
import os
import socket
import urllib.request

import schemas, db, auth
from db import Memory, User, init_db, get_db
from auth import create_access_token, verify_password, get_password_hash

app = FastAPI()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login", auto_error=False)

# Dependency to get the current user
def get_current_user(token: str = Depends(oauth2_scheme), x_nobs_token: str | None = Header(default=None), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    raw_token = x_nobs_token or token
    if not raw_token:
        raise credentials_exception
    username = auth.verify_token(raw_token, credentials_exception)
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise credentials_exception
    return user

@app.on_event("startup")
def on_startup():
    init_db()
    
    # Setup local loopback SSH key inside container
    host_key_path = "/app/host_id_ed25519"
    container_ssh_dir = "/root/.ssh"
    container_key_path = "/root/.ssh/id_ed25519"
    if os.path.exists(host_key_path):
        try:
            os.makedirs(container_ssh_dir, exist_ok=True)
            import shutil
            shutil.copy2(host_key_path, container_key_path)
            os.chmod(container_key_path, 0o600)
            print("Successfully initialized loopback SSH key inside container")
        except Exception as exc:
            print(f"Failed to setup local loopback SSH key: {exc}")

    # Create a default user if not exists
    db_session = Session(bind=db.engine)
    if db_session.query(User).filter(User.username == "alex").first() is None:
        hashed_password = get_password_hash("x") # Placeholder password
        new_user = User(username="alex", hashed_password=hashed_password)
        db_session.add(new_user)
        db_session.commit()
    db_session.close()

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/api/v1/ping")
def ping():
    return {"ok": True, "service": "memories-api"}

@app.post("/api/v1/auth/register")
def register(form_data: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.username == form_data.username).first()
    if existing:
        raise HTTPException(status_code=409, detail="Username already exists")
    db.add(User(username=form_data.username, hashed_password=get_password_hash(form_data.password)))
    db.commit()
    return {"ok": True, "username": form_data.username}

@app.post("/api/v1/auth/login", response_model=schemas.Token)
def login(form_data: schemas.UserCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = create_access_token(data={"sub": user.username})
    return {"token": access_token, "username": user.username, "access_token": access_token, "token_type": "bearer"}

@app.get("/api/v1/auth/me", response_model=schemas.User)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.post("/api/v1/memories", response_model=schemas.Memory)
def create_memory(memory: schemas.MemoryCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_memory = Memory(**memory.dict())
    db.add(db_memory)
    db.commit()
    db.refresh(db_memory)
    return db_memory

@app.get("/api/v1/memories", response_model=List[schemas.Memory])
def list_memories(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Memory).all()

@app.get("/api/v1/memories/{memory_id}", response_model=schemas.Memory)
def get_memory(memory_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_memory = db.query(Memory).filter(Memory.id == memory_id).first()
    if db_memory is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    return db_memory

@app.put("/api/v1/memories/{memory_id}", response_model=schemas.Memory)
def update_memory(memory_id: str, memory: schemas.MemoryCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_memory = db.query(Memory).filter(Memory.id == memory_id).first()
    if db_memory is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    for key, value in memory.dict().items():
        setattr(db_memory, key, value)
    db.commit()
    db.refresh(db_memory)
    return db_memory

@app.delete("/api/v1/memories/{memory_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_memory(memory_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_memory = db.query(Memory).filter(Memory.id == memory_id).first()
    if db_memory is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    db.delete(db_memory)
    db.commit()
    return

@app.get("/api/v1/memories/search", response_model=List[schemas.Memory])
def search_memories(q: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Memory).filter(Memory.text.contains(q)).all()


@app.get("/api/v1/tank/scan")
def tank_scan(current_user: User = Depends(get_current_user)):
    checks = []

    def add(name, ok, detail):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    add("container", True, socket.gethostname())
    for name, host, port in [
        ("ollama", "host.docker.internal", 11434),
        ("llm-router", "llm-router", 8000),
        ("memories-api", "127.0.0.1", 8090),
    ]:
        try:
            with socket.create_connection((host, port), timeout=2):
                add(name, True, f"{host}:{port} listening")
        except OSError as exc:
            add(name, False, f"{host}:{port} {exc}")

    try:
        with urllib.request.urlopen("http://host.docker.internal:11434/api/tags", timeout=3) as response:
            add("ollama-api", response.status == 200, f"HTTP {response.status}")
    except Exception as exc:
        add("ollama-api", False, str(exc))

    return {"ok": all(item["ok"] for item in checks), "checks": checks}

@app.post("/api/v1/analyze", response_model=schemas.AnalyzeResponse)
async def analyze_text(request: schemas.AnalyzeRequest, current_user: User = Depends(get_current_user)):
    llm_router_url = "http://llm-router:8000/v1/chat/completions"
    headers = {"Content-Type": "application/json"}
    system_prompt = """
    You are a text analysis AI. Analyze the following text and return a JSON object
    containing the sentiment (a float between -1 and 1), a list of entities (people, places, organizations),
    a list of keywords, and a list of categories.
    Example:
    {"sentiment": 0.8, "entities": ["John Doe"], "keywords": ["meeting", "project"], "categories": ["work"]}
    """
    payload = {
        "model": "tier/local",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": request.text}
        ],
        "max_tokens": 500,
        "temperature": 0.7,
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(llm_router_url, headers=headers, json=payload)
        response.raise_for_status()
        llm_response = response.json()

    try:
        content = llm_response["choices"][0]["message"]["content"]
        analysis_result = json.loads(content)
        return schemas.AnalyzeResponse(**analysis_result)
    except (KeyError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse LLM response: {e}")




@app.get("/api/v1/autopilot/proposals")
def list_autopilot_proposals(current_user: User = Depends(get_current_user)):
    queue_path = "/autopilot/improvement-queue.jsonl"
    if not os.path.exists(queue_path):
        return []
    proposals = []
    with open(queue_path, "r", errors="replace") as f:
        for line in f:
            if not line.strip():
                continue
            try:
                proposals.append(json.loads(line))
            except Exception:
                continue
    return proposals

@app.post("/api/v1/autopilot/approve")
def approve_autopilot_proposal(payload: dict, current_user: User = Depends(get_current_user)):
    dedupe_key = payload.get("dedupe_key")
    if not dedupe_key:
        raise HTTPException(status_code=400, detail="Missing dedupe_key")
    
    queue_path = "/autopilot/improvement-queue.jsonl"
    approved_path = "/autopilot/approved-proposals.jsonl"
    
    proposal = None
    if os.path.exists(queue_path):
        with open(queue_path, "r", errors="replace") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    if data.get("dedupe_key") == dedupe_key:
                        proposal = data
                        break
                except Exception:
                    continue
                    
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")
        
    import time
    approved_rec = {
        "approved_at": int(time.time()),
        "approved_by": current_user.username,
        "proposal": proposal
    }
    
    with open(approved_path, "a") as f:
        f.write(json.dumps(approved_rec) + "\n")
        
    return {"ok": True, "message": "Proposal approved and dispatched", "dedupe_key": dedupe_key}


@app.get("/api/v1/autopilot/budget")
def get_autopilot_budget(current_user: User = Depends(get_current_user)):
    router_url = "http://llm-router:8000/budget"
    try:
        with urllib.request.urlopen(router_url, timeout=3) as r:
            return json.loads(r.read().decode())
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to query router budget: {exc}")


@app.websocket("/ws/voice")
async def websocket_voice(websocket: WebSocket, current_user: User = Depends(get_current_user)):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            if message.get("role") == "user" and message.get("content"):
                llm_router_url = "http://llm-router:8000/v1/chat/completions"
                headers = {"Content-Type": "application/json"}
                payload = {
                    "model": "auto",
                    "messages": [
                        {"role": "user", "content": message["content"]}
                    ],
                    "stream": True
                }

                async with httpx.AsyncClient() as client:
                    async with client.stream("POST", llm_router_url, headers=headers, json=payload, timeout=None) as response:
                        response.raise_for_status()
                        async for chunk in response.aiter_bytes():
                            # Each chunk might contain multiple SSEs or partial SSEs
                            for line in chunk.decode().splitlines():
                                if line.startswith("data: "):
                                    json_data = line[len("data: "):]
                                    if json_data.strip() == "[DONE]":
                                        break
                                    
                                    delta = json.loads(json_data)["choices"][0]["delta"]
                                    if "content" in delta:
                                        await websocket.send_json({"role": "assistant", "delta": delta["content"]})
    except WebSocketDisconnect:
        print("Client disconnected")
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()









# =====================================================================
#                      PREMIUM DASHBOARD ENDPOINTS
# =====================================================================

@app.get("/api/v1/dashboard/status")
def get_dashboard_status(current_user: User = Depends(get_current_user)):
    import shutil
    # Disk stats using shutil.disk_usage
    try:
        total, used, free = shutil.disk_usage("/")
        disk_total_gb = round(total / (1024**3), 1)
        disk_used_gb = round(used / (1024**3), 1)
        disk_free_gb = round(free / (1024**3), 1)
        disk_percent = round((used / total) * 100, 1)
    except Exception:
        disk_total_gb = disk_used_gb = disk_free_gb = disk_percent = 0.0

    # RAM stats using /proc/meminfo
    ram_total_gb = ram_used_gb = ram_free_gb = ram_percent = 0.0
    try:
        with open("/proc/meminfo", "r") as f:
            lines = f.readlines()
        mem_info = {}
        for line in lines:
            parts = line.split(":")
            if len(parts) == 2:
                mem_info[parts[0].strip()] = int(parts[1].split()[0])
        total_kb = mem_info.get("MemTotal", 0)
        available_kb = mem_info.get("MemAvailable", total_kb)
        used_kb = total_kb - available_kb
        ram_total_gb = round(total_kb / (1024 * 1024), 1)
        ram_used_gb = round(used_kb / (1024 * 1024), 1)
        ram_percent = round((used_kb / total_kb) * 100, 1)
    except Exception:
        pass

    # CPU load average
    cpu_percent = 0.0
    try:
        with open("/proc/loadavg", "r") as f:
            load = f.read().split()[0]
        cpu_percent = min(100.0, round(float(load) * 10.0, 1))
    except Exception:
        pass

    return {
        "cpu_percent": cpu_percent,
        "ram_percent": ram_percent,
        "ram_used_gb": ram_used_gb,
        "ram_total_gb": ram_total_gb,
        "disk_percent": disk_percent,
        "disk_used_gb": disk_used_gb,
        "disk_total_gb": disk_total_gb,
        "hostname": socket.gethostname()
    }


@app.get("/api/v1/dashboard/docker")
def get_docker_containers(current_user: User = Depends(get_current_user)):
    socket_path = "/var/run/docker.sock"
    if not os.path.exists(socket_path):
        return {"error": "Docker socket not mounted inside container"}
    try:
        transport = httpx.HTTPTransport(uds=socket_path)
        with httpx.Client(transport=transport) as client:
            response = client.get("http://localhost/containers/json?all=true")
            containers = response.json()
            
        result = []
        for c in containers:
            names = c.get("Names", [])
            name = names[0].lstrip("/") if names else "unnamed"
            status = c.get("Status", "")
            state = c.get("State", "")
            image = c.get("Image", "")
            
            ports = []
            for p in c.get("Ports", []):
                if "PublicPort" in p:
                    ports.append(f"{p.get('Type', '')}/{p.get('PublicPort', '')}->{p.get('PrivatePort', '')}")
                else:
                    ports.append(f"{p.get('Type', '')}/{p.get('PrivatePort', '')}")
            
            result.append({
                "name": name,
                "image": image,
                "status": status,
                "state": state,
                "ports": ", ".join(ports)
            })
        return result
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to query Docker socket: {exc}")


@app.get("/api/v1/dashboard/ollama")
def get_ollama_models(current_user: User = Depends(get_current_user)):
    url = "http://host.docker.internal:11434/api/tags"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=3) as r:
            data = json.loads(r.read().decode())
            models = data.get("models", [])
            
        result = []
        for m in models:
            size_bytes = m.get("size", 0)
            details = m.get("details", {})
            parameter_size = details.get("parameter_size", "")
            quantization_level = details.get("quantization_level", "")
            
            result.append({
                "name": m.get("name", "unknown"),
                "size": size_bytes,
                "parameter_size": parameter_size,
                "quantization_level": quantization_level,
                "modified_at": m.get("modified_at", "")
            })
        return result
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to query Ollama models: {exc}")


@app.get("/api/v1/dashboard/linkedin")
def get_linkedin_queue(current_user: User = Depends(get_current_user)):
    import sqlite3
    db_path = "/agency-data/agency.db"
    if not os.path.exists(db_path):
        return []
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM content_pieces WHERE platform='linkedin' ORDER BY created_at DESC;")
        rows = cursor.fetchall()
        posts = [dict(row) for row in rows]
        conn.close()
        return posts
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to query agency database: {exc}")


@app.patch("/api/v1/dashboard/linkedin/{post_id}")
def update_linkedin_post(post_id: int, payload: dict, current_user: User = Depends(get_current_user)):
    import sqlite3
    status = payload.get("status")
    if not status:
        raise HTTPException(status_code=400, detail="Missing status in payload")
    
    db_path = "/agency-data/agency.db"
    if not os.path.exists(db_path):
        raise HTTPException(status_code=404, detail="Agency database not found")
        
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT id FROM content_pieces WHERE id=?;", (post_id,))
        if not cursor.fetchone():
            conn.close()
            raise HTTPException(status_code=404, detail="Post not found")
            
        cursor.execute("UPDATE content_pieces SET status=? WHERE id=?;", (status, post_id))
        conn.commit()
        conn.close()
        return {"ok": True, "id": post_id, "status": status}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update post: {exc}")


@app.post("/api/v1/dashboard/teams/trigger/{team}")
def trigger_team_cycle(team: str, current_user: User = Depends(get_current_user)):
    import subprocess
    valid_teams = ["website-improve", "ios-improve", "rss-digest", "content-ideas", "seo-audit", "blog-draft"]
    if team not in valid_teams:
        raise HTTPException(status_code=400, detail=f"Invalid team identifier. Choose from: {valid_teams}")
        
    service_name = f"nobs-{team}.service"
    ssh_cmd = [
        "ssh",
        "-i", "/root/.ssh/id_ed25519",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=5",
        "alex@host.docker.internal",
        f"systemctl --user start {service_name}"
    ]
    
    try:
        res = subprocess.run(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
        if res.returncode == 0:
            return {"ok": True, "message": f"Successfully triggered manual cycle for {team} loop"}
        else:
            raise HTTPException(status_code=500, detail=f"SSH execution failed: {res.stderr.strip()}")
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Connection to host timed out")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to dispatch trigger: {exc}")



@app.get("/api/v1/public/brain-stats")
def get_public_brain_stats():
    import subprocess
    import json
    import os
    
    # 1. Count database campaign pieces
    db_path = "/agency-data/agency.db"
    campaign_pieces_count = 0
    if os.path.exists(db_path):
        try:
            import sqlite3
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT count(*) FROM content_pieces;")
            campaign_pieces_count = cursor.fetchone()[0]
            conn.close()
        except Exception:
            pass

    # 2. Local Ollama active models info
    ollama_models = []
    try:
        import httpx
        r = httpx.get("http://host.docker.internal:11434/api/tags", timeout=3.0)
        if r.status_code == 200:
            ollama_models = [m["name"] for m in r.json().get("models", [])]
    except Exception:
        pass

    # 3. SSH Host call to gather Obsidian stats, active loops, and latest proposals
    host_payload = {
        "brain_size_files": 0,
        "active_loops": [],
        "proposals": []
    }
    
    # Use pre-written helper script to gather brain stats from host
    shell_cmd = "/home/alex/bin/nobs-brain-stats.sh"

    ssh_cmd = [
        "ssh",
        "-i", "/root/.ssh/id_ed25519",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=5",
        "alex@host.docker.internal",
        shell_cmd
    ]
    
    try:
        res = subprocess.run(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=8)
        if res.returncode == 0:
            host_payload = json.loads(res.stdout)
    except Exception:
        pass
        
    return {
        "ok": True,
        "brain_size_files": host_payload.get("brain_size_files", 0),
        "campaign_pieces_count": campaign_pieces_count,
        "active_loops_count": len(host_payload.get("active_loops", [])),
        "active_loops": host_payload.get("active_loops", []),
        "ollama_models": ollama_models,
        "proposals": host_payload.get("proposals", []),
        "cal_stats": host_payload.get("cal_stats", {})
    }
