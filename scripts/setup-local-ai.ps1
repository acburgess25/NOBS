$ErrorActionPreference = "Stop"

$models = $env:NOBS_OLLAMA_MODELS
if ([string]::IsNullOrWhiteSpace($models)) {
    $models = "qwen3:8b qwen2.5-coder:14b"
}

$openWebUiVenv = $env:NOBS_OPEN_WEBUI_VENV
if ([string]::IsNullOrWhiteSpace($openWebUiVenv)) {
    $openWebUiVenv = Join-Path $HOME ".nobs/open-webui"
}

if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw "Python 3.11+ is required."
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    py -3.11 -c "import sys; exit(0 if sys.version_info >= (3,11) else 1)"
    if ($LASTEXITCODE -ne 0) { throw "Python 3.11+ is required." }
    $pythonCmd = "py -3.11"
} else {
    python -c "import sys; exit(0 if sys.version_info >= (3,11) else 1)"
    if ($LASTEXITCODE -ne 0) { throw "Python 3.11+ is required." }
    $pythonCmd = "python"
}

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    throw "Ollama is required. Install it first: https://ollama.com/download"
}

foreach ($model in $models.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)) {
    Write-Host "Pulling model: $model"
    ollama pull $model
}

if (-not (Get-Command aider -ErrorAction SilentlyContinue)) {
    Write-Host "Installing aider-chat"
    Invoke-Expression "$pythonCmd -m pip install --user --upgrade aider-chat"
}

if (-not (Test-Path $openWebUiVenv)) {
    New-Item -ItemType Directory -Path $openWebUiVenv -Force | Out-Null
}

$venvPython = Join-Path $openWebUiVenv "Scripts/python.exe"
if (-not (Test-Path $venvPython)) {
    Invoke-Expression "$pythonCmd -m venv `"$openWebUiVenv`""
}

& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install --upgrade open-webui

$openWebUiExe = Join-Path $openWebUiVenv "Scripts/open-webui.exe"
Write-Host ""
Write-Host "NOBS local AI stack is ready."
Write-Host "Open WebUI start command:"
Write-Host "  $openWebUiExe serve --host 127.0.0.1 --port 8080"
