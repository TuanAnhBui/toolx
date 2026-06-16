<#
  preflight-check.ps1 — Dev environment preflight (Windows)
  READ-ONLY. Installs nothing, changes nothing, needs no admin.
  Usage:   powershell -ExecutionPolicy Bypass -File .\preflight-check.ps1
  Deep:    add  -Deep   to also test actually pulling from registries.
#>
param([switch]$Deep)

$ErrorActionPreference = 'SilentlyContinue'
$results = @()
function Add-Result($name, $status, $detail) {
  $script:results += [pscustomobject]@{ Name = $name; Status = $status; Detail = $detail }
}
function Has-Cmd($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Num($s) { if ($s -match '(\d+\.\d+(\.\d+)?)') { return $matches[1] } return $null }
function MinVer($have, $min) { try { return [version](Num $have) -ge [version]$min } catch { return $false } }

function Test-Url($url) {
  try {
    $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 12
    return @{ ok = $true; code = [int]$r.StatusCode }
  } catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code) { return @{ ok = $true; code = [int]$code } }   # any HTTP response = reachable
    return @{ ok = $false; code = $null }
  }
}

Write-Host "`n=== Dev environment preflight (Windows) ===`n"

# --- 1. Required tools + versions ---
if (Has-Cmd git)    { Add-Result 'git'    'PASS' (git --version) }    else { Add-Result 'git' 'FAIL' 'not found' }

if (Has-Cmd node) {
  $v = node -v
  if (MinVer $v '20.0') { Add-Result 'node (>=20)' 'PASS' $v } else { Add-Result 'node (>=20)' 'FAIL' "found $v" }
} else { Add-Result 'node (>=20)' 'FAIL' 'not found' }

if (Has-Cmd npm)    { Add-Result 'npm'    'PASS' (npm -v) }           else { Add-Result 'npm' 'FAIL' 'not found' }

$py = $null
if (Has-Cmd python) { $py = 'python' } elseif (Has-Cmd py) { $py = 'py' }
if ($py) {
  $v = & $py --version 2>&1
  if (MinVer $v '3.12') { Add-Result 'python (>=3.12)' 'PASS' "$v" } else { Add-Result 'python (>=3.12)' 'WARN' "found $v" }
} else { Add-Result 'python (>=3.12)' 'FAIL' 'not found' }

if (Has-Cmd make)   { Add-Result 'make'   'PASS' 'present' }          else { Add-Result 'make' 'WARN' 'not found (optional; can use npm/uvx scripts)' }

# --- 2. Docker engine ---
if (Has-Cmd docker) {
  docker info *> $null
  if ($LASTEXITCODE -eq 0) { Add-Result 'docker engine' 'PASS' 'daemon running' }
  else { Add-Result 'docker engine' 'FAIL' 'installed but daemon not running / no access' }
  $cv = docker compose version 2>$null
  if ($cv) { Add-Result 'docker compose v2' 'PASS' (Num $cv) } else { Add-Result 'docker compose v2' 'FAIL' 'not found' }
} else { Add-Result 'docker engine' 'FAIL' 'not found (Docker Desktop / Podman / Rancher Desktop)' }

# --- 3. Local ports free ---
foreach ($p in 5432,6379,9000,9001,8080,8000,5173) {
  $c = Test-NetConnection -ComputerName 127.0.0.1 -Port $p -WarningAction SilentlyContinue
  if ($c.TcpTestSucceeded) { Add-Result "port $p" 'WARN' 'in use — may clash with the stack' }
  else { Add-Result "port $p" 'PASS' 'free' }
}

# --- 4. Proxy configuration (informational) ---
$proxy = $env:HTTPS_PROXY; if (-not $proxy) { $proxy = $env:https_proxy }
if ($proxy) { Add-Result 'proxy (env)' 'PASS' $proxy } else { Add-Result 'proxy (env)' 'WARN' 'no HTTPS_PROXY set — fine if direct egress is allowed' }

# --- 5. Registry reachability (the ISM crux) ---
$hosts = @(
  @{ n = 'Docker Hub';   u = 'https://registry-1.docker.io/v2/' },
  @{ n = 'Quay (Keycloak img)'; u = 'https://quay.io/v2/' },
  @{ n = 'npm registry'; u = 'https://registry.npmjs.org/' },
  @{ n = 'PyPI index';   u = 'https://pypi.org/simple/' },
  @{ n = 'PyPI files';   u = 'https://files.pythonhosted.org/' },
  @{ n = 'GitHub';       u = 'https://github.com' },
  @{ n = 'GitHub codeload'; u = 'https://codeload.github.com' },
  @{ n = 'Playwright CDN'; u = 'https://cdn.playwright.dev/' }
)
foreach ($h in $hosts) {
  $r = Test-Url $h.u
  if ($r.ok) { Add-Result ("reach: " + $h.n) 'PASS' ("HTTP " + $r.code) }
  else { Add-Result ("reach: " + $h.n) 'FAIL' 'blocked / unreachable — request allowlist or use internal mirror' }
}

# --- 6. Disk space ---
$free = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
if ($free -ge 15) { Add-Result 'disk free (C:)' 'PASS' "$free GB" } else { Add-Result 'disk free (C:)' 'WARN' "$free GB (>=15 GB recommended)" }

# --- 7. Deep tests (optional) ---
if ($Deep) {
  if (Has-Cmd npm)    { npm ping *> $null; if ($LASTEXITCODE -eq 0) { Add-Result 'deep: npm install path' 'PASS' 'npm ping ok' } else { Add-Result 'deep: npm install path' 'FAIL' 'npm cannot reach registry' } }
  if ($py)            { & $py -m pip download --no-deps --dest $env:TEMP\pf pip *> $null; if ($LASTEXITCODE -eq 0) { Add-Result 'deep: pip download' 'PASS' 'ok' } else { Add-Result 'deep: pip download' 'FAIL' 'pip cannot reach index' } }
  if (Has-Cmd docker) { docker manifest inspect hello-world *> $null; if ($LASTEXITCODE -eq 0) { Add-Result 'deep: docker pull path' 'PASS' 'registry reachable' } else { Add-Result 'deep: docker pull path' 'FAIL' 'cannot reach image registry' } }
  if (Has-Cmd git)    { git ls-remote https://github.com/git/git *> $null; if ($LASTEXITCODE -eq 0) { Add-Result 'deep: git clone path' 'PASS' 'ok' } else { Add-Result 'deep: git clone path' 'FAIL' 'cannot reach GitHub over git' } }
}

# --- Report ---
$results | Format-Table -AutoSize Name, Status, Detail
$fail = ($results | Where-Object Status -eq 'FAIL').Count
$warn = ($results | Where-Object Status -eq 'WARN').Count
Write-Host ("`nSummary: {0} PASS  {1} WARN  {2} FAIL" -f (($results|? Status -eq 'PASS').Count), $warn, $fail)
if ($fail -gt 0) { Write-Host "`nThere are FAILs. See the remediation section of preflight-check.md." ; exit 1 }
Write-Host "`nEnvironment looks ready for Phase A." ; exit 0
