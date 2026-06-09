# NOBS Tank Beta Stack

This is the clean Tank app layer for NOBS beta testing and demos.

Protected infrastructure that this stack does not own:

- Tailscale and SSH access
- Cloudflared tunnel and credentials
- Host networking
- Host Ollama service

Runtime shape:

- Cloudflare tunnel routes `nobsdash.com` and `www.nobsdash.com` to `localhost:80`.
- Host Nginx serves the static NOBS website and proxies `/api/v1/` to the API.
- Docker Compose runs the NOBS API on loopback port `18080`.
- Ollama remains host-native on port `11434`.
- Optional LiteLLM can stay on port `4000` during beta if the app targets OpenAI-compatible chat completions.

Deploy target on Tank:

```sh
/opt/nobs-beta
```

The first deployment should archive the old `/opt/homelab` stack, stop its containers, install this Nginx site, then start the API.

