#!/usr/bin/env bash
# preflight-check.sh — Dev environment preflight (macOS/Linux)
# READ-ONLY. Installs nothing, changes nothing, needs no admin/sudo.
# Usage:  bash preflight-check.sh         (basic checks)
#         bash preflight-check.sh --deep  (also test pulling from registries)

set -u
DEEP=0; [ "${1:-}" = "--deep" ] && DEEP=1
PASS=0; WARN=0; FAIL=0
GRN='\033[0;32m'; YEL='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

row() { # name status detail
  case "$2" in
    PASS) PASS=$((PASS+1)); c=$GRN;;
    WARN) WARN=$((WARN+1)); c=$YEL;;
    FAIL) FAIL=$((FAIL+1)); c=$RED;;
  esac
  printf "%b%-26s %-5s%b %s\n" "$c" "$1" "$2" "$NC" "$3"
}
have() { command -v "$1" >/dev/null 2>&1; }
num()  { echo "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }
ge()   { [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" = "$2" ]; }  # $1 >= $2 ?

echo ""
echo "=== Dev environment preflight (macOS/Linux) ==="
echo ""

# --- 1. Required tools + versions ---
have git  && row "git"  PASS "$(git --version)"  || row "git" FAIL "not found"

if have node; then
  V=$(num "$(node -v)"); if ge "$V" "20.0"; then row "node (>=20)" PASS "v$V"; else row "node (>=20)" FAIL "found v$V"; fi
else row "node (>=20)" FAIL "not found"; fi

have npm  && row "npm"  PASS "$(npm -v)"  || row "npm" FAIL "not found"

PY=""; have python3 && PY=python3 || { have python && PY=python; }
if [ -n "$PY" ]; then
  V=$(num "$($PY --version 2>&1)"); if ge "$V" "3.12"; then row "python (>=3.12)" PASS "$V"; else row "python (>=3.12)" WARN "found $V"; fi
else row "python (>=3.12)" FAIL "not found"; fi

have make && row "make" PASS "present" || row "make" WARN "not found (optional)"

# --- 2. Docker engine ---
if have docker; then
  if docker info >/dev/null 2>&1; then row "docker engine" PASS "daemon running"
  else row "docker engine" FAIL "installed but daemon not running / no access"; fi
  if docker compose version >/dev/null 2>&1; then row "docker compose v2" PASS "$(num "$(docker compose version)")"
  else row "docker compose v2" FAIL "not found"; fi
else row "docker engine" FAIL "not found (Docker Desktop / Podman / colima)"; fi

# --- 3. Local ports free ---
port_busy() { if have lsof; then lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; elif have nc; then nc -z 127.0.0.1 "$1" >/dev/null 2>&1; else return 1; fi; }
for p in 5432 6379 9000 9001 8080 8000 5173; do
  if port_busy "$p"; then row "port $p" WARN "in use — may clash with the stack"; else row "port $p" PASS "free"; fi
done

# --- 4. Proxy (informational) ---
if [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]; then row "proxy (env)" PASS "${HTTPS_PROXY:-$https_proxy}"
else row "proxy (env)" WARN "no HTTPS_PROXY — fine if direct egress is allowed"; fi

# --- 5. Registry reachability (the ISM crux) ---
fetch() { # url -> prints HTTP code or 000 on connection failure (proxy-aware via curl)
  if have curl; then curl -s -o /dev/null -m 12 -I -w '%{http_code}' "$1" 2>/dev/null
  elif have wget; then wget -q -S --timeout=12 --method=HEAD -O /dev/null "$1" 2>&1 | grep -oE 'HTTP/[0-9.]+ [0-9]+' | grep -oE '[0-9]+$' | head -1
  else echo "000"; fi
}
reach() { code=$(fetch "$2"); if [ -n "$code" ] && [ "$code" != "000" ]; then row "reach: $1" PASS "HTTP $code"; else row "reach: $1" FAIL "blocked/unreachable — request allowlist or use internal mirror"; fi; }
reach "Docker Hub"          "https://registry-1.docker.io/v2/"
reach "Quay (Keycloak img)" "https://quay.io/v2/"
reach "npm registry"        "https://registry.npmjs.org/"
reach "PyPI index"          "https://pypi.org/simple/"
reach "PyPI files"          "https://files.pythonhosted.org/"
reach "GitHub"              "https://github.com"
reach "GitHub codeload"     "https://codeload.github.com"
reach "Playwright CDN"      "https://cdn.playwright.dev/"

# --- 6. Disk space ---
FREE=$(df -Pg . 2>/dev/null | awk 'NR==2{print $4}'); FREE=${FREE:-0}
if [ "$FREE" -ge 15 ] 2>/dev/null; then row "disk free" PASS "${FREE} GB"; else row "disk free" WARN "${FREE} GB (>=15 GB recommended)"; fi

# --- 7. Deep tests (optional) ---
if [ "$DEEP" = "1" ]; then
  have npm    && { npm ping >/dev/null 2>&1 && row "deep: npm install path" PASS "npm ping ok" || row "deep: npm install path" FAIL "npm cannot reach registry"; }
  [ -n "$PY" ] && { $PY -m pip download --no-deps --dest /tmp/pf pip >/dev/null 2>&1 && row "deep: pip download" PASS "ok" || row "deep: pip download" FAIL "pip cannot reach index"; }
  have docker && { docker manifest inspect hello-world >/dev/null 2>&1 && row "deep: docker pull path" PASS "registry reachable" || row "deep: docker pull path" FAIL "cannot reach image registry"; }
  have git    && { git ls-remote https://github.com/git/git >/dev/null 2>&1 && row "deep: git clone path" PASS "ok" || row "deep: git clone path" FAIL "cannot reach GitHub over git"; }
fi

echo ""
echo "Summary: ${PASS} PASS  ${WARN} WARN  ${FAIL} FAIL"
if [ "$FAIL" -gt 0 ]; then echo "There are FAILs. See the remediation section of preflight-check.md."; exit 1; fi
echo "Environment looks ready for Phase A."; exit 0
