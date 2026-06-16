# Environment preflight check

**Document type:** Setup / environment verification
**Companion to:** `phase-a-implementation-guide.md`
**Purpose:** confirm a developer's company laptop has everything Phase A needs — *before* they start — and surface anything blocked by ISM policy so it can be requested through proper channels.
**Status:** Draft
**Date:** 16 June 2026

---

## 1. What this is for

On a locked-down (ISM) laptop, the usual blocker is not whether a tool is installed — it's whether the laptop can **reach the registries** to pull dependencies (npm packages, PyPI packages, container images, browser binaries). A developer can have Docker, Node, and Python all installed and still be unable to run the stack because egress to Docker Hub or npm is blocked by policy.

The two scripts in this folder check both: presence/versions of the tools, **and** real reachability of every registry the stack needs. They are **read-only** — they install nothing, change nothing, and need no admin rights — so they are safe to run on a managed laptop.

- `preflight-check.ps1` — Windows (PowerShell)
- `preflight-check.sh` — macOS / Linux (Bash)

---

## 2. How to run

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File .\preflight-check.ps1
```

**macOS / Linux:**
```bash
bash preflight-check.sh
```

Add `-Deep` (Windows) or `--deep` (macOS/Linux) to go beyond reachability and actually exercise the install paths (an `npm ping`, a tiny `pip download`, a `docker manifest inspect`, and a `git ls-remote`). The deep mode pulls only metadata or tiny payloads — it does not download large images — so it stays friendly to metered or proxied networks.

Each line reports **PASS**, **WARN**, or **FAIL**, and the script ends with a summary and a non-zero exit code if anything FAILed.

---

## 3. What it checks

| Check | Why it matters | Pass criteria |
|---|---|---|
| git, node (≥20), npm, python (≥3.12), make | The Phase A toolchain | Present and version meets the floor |
| Docker engine + Compose v2 | Runs the local stack (Postgres, MinIO, Redis, Keycloak) | `docker info` works; `docker compose version` works |
| Local ports 5432/6379/9000/9001/8080/8000/5173 | The stack binds these | Free (WARN if already in use) |
| Proxy env (`HTTPS_PROXY`) | ISM networks usually require a proxy | Informational — flagged so misconfig is visible |
| Reachability: Docker Hub, Quay, npm, PyPI (index + files), GitHub, GitHub codeload, Playwright CDN | The registries the stack pulls from | An HTTP response comes back (not blocked/timeout) |
| Disk free | Images + node_modules + venv need room | ≥ 15 GB recommended |
| *(deep)* npm / pip / docker / git pull paths | Confirms not just reachability but that policy *allows* the pull | The operation succeeds |

A `FAIL` on a reachability row is the signal that ISM is blocking that registry — that's what §5 is for.

---

## 4. Interpreting results

- **All PASS** → ready for Phase A.
- **WARN on ports** → something else is using a port; stop it, or remap the port in `docker-compose.yml`.
- **WARN on python/make** → `make` is optional; a too-old Python should be raised with IT (see §5).
- **FAIL on a tool** → it isn't installed (or not on PATH). Request it from the approved software catalog — do **not** download installers from the web on an ISM laptop.
- **FAIL on reachability** → the registry is blocked. Either point the tool at the company's internal mirror, or request the host be allowlisted (§5 and §6).

---

## 5. Remediation on an ISM laptop

Two routes, in order of preference:

**A. Use the company's internal mirrors (preferred).** Most ISM-managed orgs run an internal artifact proxy (Artifactory, Nexus, or similar) that mirrors public registries through an approved path. If yours does, point the tools at it rather than the public registries — typically:

- npm → set the registry to the internal mirror (a project-level `.npmrc`).
- pip → set the index URL to the internal mirror (a `pip.conf` / `PIP_INDEX_URL`).
- Docker → configure the daemon to pull through the internal registry mirror.
- Git → use the internal Git host or the approved HTTPS proxy.

Ask your platform/IT team for these URLs; bake them into the repo's config so every developer inherits them and no one points at a blocked public host by accident.

**B. Request an allowlist or software via IT.** For anything that must come from a public source and has no internal mirror, raise a request through the normal channel. Use the concrete lists in §6 — they are written so IT can action them directly. Install tools (Docker Desktop, Node, Python) only from the **approved software catalog** (Company Portal / Jamf / SCCM), never from a web download.

> **Docker Desktop note:** some organizations restrict Docker Desktop (licensing or policy). If it isn't approved, the same stack runs on **Podman Desktop**, **Rancher Desktop**, or **colima** (macOS) — check which your org approves before assuming Docker Desktop.

---

## 6. The request package for IT

Hand these two lists to IT so the environment can be approved in one pass.

### 6.1 Software (from the approved catalog)

- Docker Desktop (or approved alternative: Podman Desktop / Rancher Desktop / colima)
- Node.js 20 LTS (or newer)
- Python 3.12 (or newer)
- Git
- A code editor (e.g. VS Code)
- (optional) `make`

### 6.2 Network egress to allowlist (or mirror internally)

| Purpose | Hosts |
|---|---|
| Container images (Docker Hub) | `registry-1.docker.io`, `auth.docker.io`, `index.docker.io`, `production.cloudflare.docker.com` |
| Container images (Keycloak, via Quay) | `quay.io`, `cdn.quay.io`, `cdn0?.quay.io` |
| npm packages | `registry.npmjs.org` |
| Python packages | `pypi.org`, `files.pythonhosted.org` |
| Source / actions | `github.com`, `codeload.github.com`, `raw.githubusercontent.com`, `objects.githubusercontent.com` |
| Playwright browser binaries | `cdn.playwright.dev`, `playwright.download.prss.microsoft.com` |
| *(optional) editor extensions* | `marketplace.visualstudio.com`, `*.vscode-unpkg.net` |

All over HTTPS (443). If the org provides internal mirrors for any of these, prefer the mirror and omit the public host from the request.

> **Playwright is the most common surprise.** It downloads browser binaries (Chromium etc.) from a Microsoft/Playwright CDN on first install — a path that is frequently blocked even when npm itself is allowed. If that host can't be opened, Playwright supports pointing `PLAYWRIGHT_DOWNLOAD_HOST` at an internal mirror, or vendoring the browsers through the artifact proxy. Flag this explicitly in the request.

---

## 7. Suggested workflow

1. Every new developer runs the preflight script on day one, before cloning anything.
2. Any FAIL is raised with IT using the §6 package (ideally batched for the whole team once, not per person).
3. Once the script is all-PASS, follow `phase-a-implementation-guide.md`.
4. Re-run after any IT change to confirm the fix, and keep the script in the repo so it stays current as the stack grows (add new registries/ports to it in later phases).

---

## 8. Summary

The preflight scripts verify both the toolchain and — crucially for an ISM laptop — real reachability of every registry Phase A pulls from, without installing or changing anything. A reachability FAIL means policy is blocking that registry; resolve it by pointing at the company's internal mirror or by requesting the specific hosts in §6 through IT. Get the environment to all-PASS once, ideally as a one-time team-wide IT request, and every developer can then follow the Phase A guide without hitting a wall mid-build.
