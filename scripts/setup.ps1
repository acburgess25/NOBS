$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (Get-Command py -ErrorAction SilentlyContinue) {
    py -3.11 scripts/dev.py setup
    exit $LASTEXITCODE
}

if (Get-Command python -ErrorAction SilentlyContinue) {
    python scripts/dev.py setup
    exit $LASTEXITCODE
}

Write-Error "Python 3.11 or newer is required. Install it from python.org or winget."

