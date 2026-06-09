#!/usr/bin/env bash
set -euo pipefail

if [[ $(hostname) != "tank" ]]; then
  echo "Run this on Tank." >&2
  exit 1
fi

cd /opt/nobs-beta

if [[ ! -f .env ]]; then
  cp .env.example .env
  secret=$(openssl rand -hex 32)
  sed -i "s/change-me-generate-with-openssl-rand-hex-32/$secret/" .env
  echo "Created /opt/nobs-beta/.env. Set NOBS_BOOTSTRAP_PASSWORD before first login." >&2
  exit 2
fi

docker compose up -d --build
sudo install -d -m 0755 /var/www/nobsdash
sudo cp -a site/. /var/www/nobsdash/
sudo install -m 0644 nginx/nobsdash.com.conf /etc/nginx/sites-available/nobsdash.com.conf
sudo ln -sfn /etc/nginx/sites-available/nobsdash.com.conf /etc/nginx/sites-enabled/nobsdash.com.conf
sudo nginx -t
sudo systemctl reload nginx

curl -fsS http://127.0.0.1:18080/healthz
curl -fsS http://127.0.0.1/healthz

