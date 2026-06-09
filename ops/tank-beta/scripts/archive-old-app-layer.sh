#!/usr/bin/env bash
set -euo pipefail

if [[ $(hostname) != "tank" ]]; then
  echo "Run this on Tank." >&2
  exit 1
fi

stamp=$(date +%Y%m%d-%H%M%S)
out="/home/alex/tank-app-layer-archive-$stamp"
mkdir -p "$out"

docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" > "$out/docker-ps.txt" 2>&1 || true
docker volume ls > "$out/docker-volumes.txt" 2>&1 || true
docker network ls > "$out/docker-networks.txt" 2>&1 || true
systemctl list-units --type=service --all --no-pager > "$out/systemd-services.txt" 2>&1 || true
find /opt /home/alex -maxdepth 4 \( -name "compose.yml" -o -name "docker-compose.yml" -o -name "compose.yaml" -o -name "docker-compose.yaml" -o -name ".env" \) -print > "$out/compose-and-env-paths.txt" 2>/dev/null || true

sudo tar -C / -czf "$out/opt-homelab.tgz" opt/homelab 2>/dev/null || true
sudo tar -C / -czf "$out/var-www-nobsdash.tgz" var/www/nobsdash 2>/dev/null || true
sudo tar -C / -czf "$out/etc-nginx.tgz" etc/nginx 2>/dev/null || true

echo "$out"

