# Cosmos Cloud Reference Manual

**Scope:** Secure home server routing, Cosmos-Compose specification syntax, network isolation rules, Smart Shield configurations, and integrated WireGuard/SSO security policies.

---

## 🔒 1. Security Architecture & Internal Networking

Cosmos Cloud acts as a security gateway. It sits on ports `80` and `443`, routing all incoming traffic to isolated container networks.

*   **Zero Port Exposure Principle:** Containers managed by Cosmos do *not* expose port mappings to the host (e.g. no `ports: - 8080:8080` in Compose). This prevents direct external access to databases or backend APIs.
*   **The Shared Network:** Cosmos creates an internal docker network named `cosmos-network` (or similar). All application containers connect to this network, allowing Cosmos to proxy traffic to their internal ports.
*   **Smart Shield Protection:** Built-in rate limiting, request validation, automated failban (brute force block), and geo-IP blocking.

---

## 🛠️ 2. Docker Installation & Bootstrap

Run this command on Tank to install and run the Cosmos administration gateway.

```bash
docker run -d \
  --name cosmos-server \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/cosmos:/var/lib/cosmos \
  --privileged \
  cosmos-cloud/cosmos-server:latest
```

---

## 📝 3. Cosmos-Compose Schema Specs

When deploying containers in Cosmos using its YAML parser, routes are defined as application metadata.

```yaml
version: '3.8'

services:
  nobs-dashboard:
    image: nginx:alpine
    container_name: nobs-dashboard
    restart: unless-stopped
    networks:
      - cosmos-network # Bind container to the secure proxy network

networks:
  cosmos-network:
    external: true
    name: cosmos-network

# Cosmos-specific routing configuration
routes:
  - name: "nobs-dashboard"
    # Internal address of the container (uses Docker service DNS)
    target: "http://nobs-dashboard:80"
    # Target domain (mapped locally in Tailscale DNS)
    domain: "dash.nobsdash.com"
    # Enable automatic Let's Encrypt certificate acquisition
    ssl: true
    # Enforce authentication (requires user login via Cosmos portal)
    auth: true
    # Enable Smart Shield (rate limit, anti-DDoS filters)
    smartShield:
      enabled: true
      rateLimitRequests: 100
      rateLimitPeriod: 60 # 100 requests per 60 seconds limit
      policy: "block"
```

---

## 🔌 4. URL & Routing Rules Reference

Proxy routes are managed programmatically or in the **URLs** tab of the Cosmos GUI.

### A. Routing Policies

*   **Public Route:** Domain routes directly to the application target without authentication checks. (Best for public APIs or static sites).
*   **Authenticated Route (Cosmos SSO):** Requires user registration/login via Cosmos before requesting the endpoint. Protects sensitive apps (like Portainer or Gitea) without configuring app-specific OAuth.
*   **VPN Restricted Route:** Limits route resolution exclusively to clients connected via the Cosmos-integrated WireGuard VPN or the local network segment.

### B. Configuring DNS-01 SSL Verification
For local-only networks (Tailscale IPs):
1.  Go to **Settings** > **DNS Setup** in Cosmos.
2.  Enable **DNS-01 Challenges**.
3.  Input your DNS API credentials (e.g. Cloudflare token) to acquire valid HTTPS SSL certificates for `*.nobsdash.com` without exposing ports `80` or `443` to the public web.

---

## ⚙️ 5. Troubleshooting Gateway Failures

*   **`502 Bad Gateway`**: Cosmos cannot reach the internal port.
    *   Verify the container is connected to the same network as Cosmos:
        ```bash
        docker network inspect cosmos-network
        ```
    *   Ensure the target port matches the internal port the container list is listening on (e.g. `http://container-name:8080`, not the host-exposed port).
*   **`504 Gateway Timeout`**: The application container is crashing or stuck in an infinite processing loop. Check container logs:
    ```bash
    docker logs -f container-name
    ```
*   **SSL Handshake Failures**: Check Cosmos console output for Let's Encrypt renewal errors. If utilizing HTTP-01 challenges, verify that port `80` is open and reachable from the public internet. If using Tailscale-only domains, switch to DNS-01 verification.
