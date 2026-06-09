#!/bin/bash
# =====================================================================
# NOBS Obsidian Vault Git Sync Setup
# =====================================================================
set -e

VAULT_DIR="/Users/alexburgess/Library/Mobile Documents/com~apple~CloudDocs/NOBS"

clear
echo "═════════════════════════════════════════════════════════"
echo "        NOBS OBSIDIAN VAULT GIT SYNC INITIALIZATION"
echo "═════════════════════════════════════════════════════════"
echo ""

if [ ! -d "$VAULT_DIR" ]; then
    echo "❌ ERROR: Obsidian folder not found at:"
    echo "   $VAULT_DIR"
    echo ""
    echo "Please verify that the folder exists and is named exactly 'NOBS' in your iCloud."
    exit 1
fi

echo "📂 Target Vault: $VAULT_DIR"
cd "$VAULT_DIR"

# Setup .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    echo "📝 Creating local .gitignore..."
    cat << 'EOF' > .gitignore
# Syncthing
.stfolder
.stversions

# OS metadata
.DS_Store
._*
.Spotlight-V100
.Trashes

# Obsidian system & caches
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache/
.obsidian/backups/
EOF
fi

# Init Git
if [ ! -d ".git" ]; then
    echo "⚙️ Initializing local Git repository..."
    git init
    git branch -M main
else
    echo "ℹ️ Git repository already initialized."
fi

# Configure Remote
echo "🔗 Connecting to GitHub (acburgess25/nobs-vault)..."
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:acburgess25/nobs-vault.git

# Pull
echo "📥 Pulling vault notes from Tank..."
git pull origin main --force

# Upstream
echo "🎯 Configuring upstream tracking..."
git branch --set-upstream-to=origin/main main || true

echo ""
echo "═════════════════════════════════════════════════════════"
echo "  ✅ SUCCESS! Your MacBook iCloud Vault is fully linked."
echo "═════════════════════════════════════════════════════════"
echo ""
echo "Next Steps:"
echo "1. Open Obsidian on your Mac."
echo "2. Install & Enable the 'Obsidian Git' plugin."
echo "3. In settings, set backup and pull intervals to 15 minutes."
echo "═════════════════════════════════════════════════════════"
