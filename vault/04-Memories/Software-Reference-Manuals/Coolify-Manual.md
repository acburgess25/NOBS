# Coolify Reference Manual

**Scope:** Standalone server deployment pipelines, Git webhooks configuration, REST API commands structure, Coolify CLI syntax, and database lifecycle management.

---

## 🔌 1. Webhook Deployments (GET Triggers)

Coolify generates unique webhooks for every application and database service. These do *not* require complex authorization payloads and can be fired with a simple HTTP GET request.

*   **Webhook Structure:** `https://your-coolify-domain.com/api/v1/deploy?uuid=<app-uuid>&force=true`
*   **Triggering via Curl:**
    ```bash
    curl -X GET "https://coolify.nobsdash.com/api/v1/deploy?uuid=e08e4f16-1f6e-4f0e-b8d2-8f92931a2380"
    ```
*   **Git Integration:** In your Git host (GitHub/Gitea), configure a Webhook pointing to this URL on `push` events. If the provider restricts Webhooks to POST requests, Coolify still accepts them, matching the payload to extract git hashes.

---

## 💻 2. The REST API Reference

Expose administrative control over your Coolify instance. Enable the API in **Settings > Advanced > API Settings** and include authorization header `Authorization: Bearer <API_TOKEN>`.

### A. List All Servers (`GET /api/v1/servers`)
*   **Request:**
    ```bash
    curl -H "Authorization: Bearer 1|coolify_api_token_here" \
         https://coolify.nobsdash.com/api/v1/servers
    ```

### B. List Applications (`GET /api/v1/applications`)
*   **Request:**
    ```bash
    curl -H "Authorization: Bearer 1|coolify_api_token_here" \
         https://coolify.nobsdash.com/api/v1/applications
    ```

### C. Trigger Programmatic Deployment (`POST /api/v1/deploy`)
Provides finer control over deployments compared to the simple GET webhook.
*   **Request:**
    ```bash
    curl -X POST https://coolify.nobsdash.com/api/v1/deploy \
         -H "Authorization: Bearer 1|coolify_api_token_here" \
         -H "Content-Type: application/json" \
         -d '{
           "uuid": "e08e4f16-1f6e-4f0e-b8d2-8f92931a2380",
           "force": true
         }'
    ```

---

## 🛠️ 3. Coolify CLI Reference (`coolify`)

The official Coolify CLI is a Go-based binary designed to streamline developer terminal commands.

### A. Download & Authentication
```bash
# Download binary (replace with your platform version)
curl -fsSL https://github.com/coollabsio/coolify-cli/releases/latest/download/coolify-linux-amd64 -o coolify
chmod +x coolify
sudo mv coolify /usr/local/bin/

# Login and save environment context
coolify login --host https://coolify.nobsdash.com --token "1|your-token"
```

### B. Command Syntaxes

```bash
# List all connected environments
coolify project list

# Check status of specific server resources
coolify server status --id 1

# Deploy application by UUID
coolify deploy --uuid "e08e4f16-1f6e-4f0e-b8d2-8f92931a2380"

# Stop a running application
coolify stop --uuid "e08e4f16-1f6e-4f0e-b8d2-8f92931a2380"

# Fetch build logs for the latest deployment cycle
coolify logs --uuid "e08e4f16-1f6e-4f0e-b8d2-8f92931a2380"
```

---

## 💾 4. Database Backups & Lifecycle

Coolify contains an integrated backup engine for PostgreSQL, MySQL, MariaDB, MongoDB, and Redis.

*   **Automated S3 Backups:** In the database settings tab, configure Cron schedules (e.g. `0 2 * * *` for 2 AM daily) and link an S3-compatible destination (MinIO on Tank, AWS S3, or Cloudflare R2). Coolify will execute `pg_dump` or target-specific dumps inside the container network and push the artifacts directly.
*   **Manual CLI Backup Trigger:**
    ```bash
    # Execute PG dump manually inside Coolify pg container
    docker exec -t coolify-db pg_dumpall -U postgres > backup.sql
    ```
