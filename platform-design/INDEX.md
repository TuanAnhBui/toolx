# Productivity tools platform — design bundle

A health-tech internal AI-first tools platform: a manifest-driven registry of tools, composed into apps and solutions, served via SDK / web UI / chatbot, with two-sided evaluation, governance, and a VM→AKS deployment path.

## Contents

### docs/
- **productivity-tools-platform-solution-architecture.md** — the core solution architecture (start here). Versioned, with TOC, glossary, and changelog.
- **future-of-the-platform.md** — vision/roadmap: evolving into a company brain and a portfolio of AI-first solution suites.
- **implementation-plan.md** — agile delivery plan, phases A–E, each with a demoable output and infrastructure needs.
- **ui-architecture.md** — frontend architecture (internal, single-tenant): shell + modules + shared foundation.
- **phase-a-implementation-guide.md** — step-by-step Phase A build for a junior developer, with checkpoints and tests.

### setup/
- **preflight-check.md** + **preflight-check.ps1 / .sh** — read-only environment checker for ISM-managed laptops, plus the allowlist to hand to IT.

### diagrams/
- PNG (drop into Confluence) and SVG (editable) for all 12 architecture diagrams.

### tool-template/
- The new-tool scaffold (manifest, handler, tests, README) to copy into `tools/<team>/<tool>/`.

## Suggested reading order
1. solution-architecture → 2. ui-architecture → 3. implementation-plan → 4. phase-a-implementation-guide → 5. future-of-the-platform.
