#Requires -Version 5.1
<#
  Odysseus - native Windows launcher (no Docker).

  One command to: create a virtualenv, install dependencies, run first-time
  setup (prints an admin password on first run), and start the server.
  Safe to re-run - it skips whatever already exists.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 -Port 7000 -BindHost 127.0.0.1

  Tip: bind 127.0.0.1 (default) for local-only use. Use 0.0.0.0 only when you
  intentionally want other devices on your LAN to reach it.
#>
param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Write-Step($msg) { Write-Host ""; Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Fail($msg) {
    Write-Host ""
    Write-Host ("ERROR: " + $msg) -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

function Test-WindowsBashStub($path) {
    if (-not $path) { return $false }
    $lowered = $path.ToLowerInvariant()
    foreach ($stub in @("system32\bash.exe", "sysnative\bash.exe", "windowsapps\bash.exe")) {
        if ($lowered.Contains($stub)) { return $true }
    }
    return $false
}

function Find-GitBash {
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd -and -not (Test-WindowsBashStub $cmd.Source)) { return $cmd.Source }

    $roots = @()
    foreach ($name in @("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)", "LocalAppData")) {
        $base = [Environment]::GetEnvironmentVariable($name)
        if ($base) {
            $roots += (Join-Path $base "Git")
            if ($name -eq "LocalAppData") { $roots += (Join-Path $base "Programs\Git") }
        }
    }
    $roots += @("C:\Program Files\Git", "C:\Program Files (x86)\Git")

    foreach ($root in ($roots | Select-Object -Unique)) {
        foreach ($relative in @("bin\bash.exe", "usr\bin\bash.exe")) {
            $candidate = Join-Path $root $relative
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

# 1. Locate a Python interpreter (3.11+ required)
Write-Step "Checking for Python"
function Get-PythonVersionText($launcher, $launcherArgs) {
    try {
        return (& $launcher @launcherArgs -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>$null).Trim()
    } catch {
        return $null
    }
}

$pyExe = $null
$pyArgs = @()
$pyVersion = $null

$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pyLauncher) {
    foreach ($v in @("-3.13", "-3.12", "-3.11")) {
        $ver = Get-PythonVersionText $pyLauncher.Source @($v)
        if ($ver) {
            $pyExe = $pyLauncher.Source
            $pyArgs = @($v)
            $pyVersion = $ver
            break
        }
    }
}

if (-not $pyExe) {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $ver = Get-PythonVersionText $pythonCmd.Source @()
        if ($ver) {
            $versionParts = $ver.Split('.')
            $major = [int]$versionParts[0]
            $minor = [int]$versionParts[1]
            if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 11)) {
                $pyExe = $pythonCmd.Source
                $pyVersion = $ver
            }
        }
    }
}

if ($pyExe -like "*WindowsApps*python.exe") {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCmd) {
        $pyExe = $pyCmd.Source
        $pyArgs = @("-3.11")
    }
}

if (-not $pyExe) {
    Fail "Couldn't find Python 3.11+ for Windows setup. Install Python 3.11+ (or open the Python launcher with 'py -3.11') from https://www.python.org/downloads/, then re-run this script."
}
$pythonLabel = ("Using Python {0}: {1} {2}" -f $pyVersion, $pyExe, ($pyArgs -join ' ')).TrimEnd()
Write-Host $pythonLabel

# 2. Create the virtualenv if missing
$venvPy = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Write-Step "Creating virtual environment (venv)"
    & $pyExe @pyArgs -m venv venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPy)) { Fail "Failed to create the virtual environment." }
} else {
    Write-Host "venv already exists - skipping creation."
}

# 3. Install / update dependencies
Write-Step "Installing dependencies (first run can take a few minutes)"
& $venvPy -m pip install --quiet --require-hashes --only-binary=:all: --no-deps -r requirements-bootstrap.txt
if ($LASTEXITCODE -ne 0) { Fail "TLS dependency bootstrap failed." }
& $venvPy -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { Fail "Dependency install failed. Scroll up for the pip error." }

# 3b. ChromaDB backs the tool index, vector RAG and semantic memory. The full
# `chromadb` package conflicts with `chromadb-client` (requirements.txt), so it
# lives in its own venv and runs as a local server, like docker/start-macos.sh.
$chromaHost = if ($env:CHROMADB_HOST) { $env:CHROMADB_HOST } else { "localhost" }
$chromaPort = if ($env:CHROMADB_PORT) { [int]$env:CHROMADB_PORT } else { 8100 }
$chromaLocal = @("localhost", "127.0.0.1", "0.0.0.0") -contains $chromaHost
$chromaExe = Join-Path $PSScriptRoot "venv-chroma\Scripts\chroma.exe"
if ($chromaLocal -and -not (Test-Path $chromaExe)) {
    Write-Step "Installing ChromaDB server (venv-chroma)"
    & $pyExe @pyArgs -m venv venv-chroma
    $chromaPy = Join-Path $PSScriptRoot "venv-chroma\Scripts\python.exe"
    if ($LASTEXITCODE -eq 0 -and (Test-Path $chromaPy)) {
        & $chromaPy -m pip install --quiet chromadb
    }
    if (-not (Test-Path $chromaExe)) {
        Write-Host "WARNING: ChromaDB install failed; vector memory/RAG will be degraded." -ForegroundColor Yellow
    }
}

# 4. First-time setup (creates data dirs, DB, .env, admin user)
Write-Step "Running first-time setup"
& $venvPy setup.py
if ($LASTEXITCODE -ne 0) { Fail "setup.py failed." }

# 5. Friendly note about Git Bash (full Cookbook / agent-shell parity)
if (-not (Find-GitBash)) {
    Write-Host ""
    Write-Host "NOTE: Git Bash (bash.exe) was not found on PATH." -ForegroundColor Yellow
    Write-Host "      The core app works without it. For full Cookbook background" -ForegroundColor Yellow
    Write-Host "      downloads and the agent shell tool, install Git for Windows:" -ForegroundColor Yellow
    Write-Host "      https://git-scm.com/download/win" -ForegroundColor Yellow
}

# 6. Point CUDA_PATH at a real CUDA toolkit so GPU llama-cpp-python can import.
$cudaBase = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
if (Test-Path $cudaBase) {
    $cudaBest = Get-ChildItem $cudaBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "bin") } |
        Sort-Object { try { [version]($_.Name -replace "^v", "") } catch { [version]"0.0" } } -Descending |
        Select-Object -First 1
    if ($cudaBest) {
        $env:CUDA_PATH = $cudaBest.FullName
        Write-Host ("Using CUDA_PATH = " + $cudaBest.FullName) -ForegroundColor Cyan
    }
}

# 7. Start the server (use `python -m uvicorn` - bare `uvicorn` may not be on PATH)
# -Port only reaches uvicorn as a flag. Everything that builds a URL for this
# instance - internal_api_base(), companion pairing, the MCP OAuth callback -
# reads APP_PORT, so set it too or they all assume 7000.
$env:APP_PORT = $Port
# Windows defaults text I/O to the legacy ANSI codepage; the app reads/writes UTF-8.
$env:PYTHONUTF8 = "1"

# Start ChromaDB in the background unless one is already listening (or remote).
$chromaProc = $null
if ($chromaLocal -and (Test-Path $chromaExe)) {
    $chromaUp = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("127.0.0.1", $chromaPort)
        $tcp.Close()
        $chromaUp = $true
    } catch {}
    if ($chromaUp) {
        Write-Host "ChromaDB already running on 127.0.0.1:$chromaPort - using it."
    } else {
        $chromaBind = if ($chromaHost -eq "0.0.0.0") { "0.0.0.0" } else { "127.0.0.1" }
        $chromaData = Join-Path $PSScriptRoot "data\chroma"
        New-Item -ItemType Directory -Force $chromaData | Out-Null
        New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot "logs") | Out-Null
        Write-Step ("Starting ChromaDB on {0}:{1}" -f $chromaBind, $chromaPort)
        $chromaProc = Start-Process -FilePath $chromaExe `
            -ArgumentList @("run", "--host", $chromaBind, "--port", $chromaPort, "--path", "`"$chromaData`"") `
            -RedirectStandardOutput (Join-Path $PSScriptRoot "logs\chromadb.out.log") `
            -RedirectStandardError (Join-Path $PSScriptRoot "logs\chromadb.err.log") `
            -WindowStyle Hidden -PassThru
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $tcp.Connect("127.0.0.1", $chromaPort)
                $tcp.Close()
                break
            } catch {}
        }
    }
}

if (-not (Get-Command npx.cmd -ErrorAction SilentlyContinue)) {
    Write-Host "NOTE: Node.js (npx) not found; the built-in Browser MCP tool is unavailable." -ForegroundColor Yellow
    Write-Host "      Install it with: winget install OpenJS.NodeJS.LTS" -ForegroundColor Yellow
}

Write-Step ("Starting Odysseus at http://{0}:{1}" -f $BindHost, $Port)
Write-Host "Press Ctrl+C to stop."
Write-Host ""
try {
    & $venvPy -m uvicorn app:app --host $BindHost --port $Port
} finally {
    if ($chromaProc -and -not $chromaProc.HasExited) {
        Stop-Process -Id $chromaProc.Id -Force -ErrorAction SilentlyContinue
    }
}
