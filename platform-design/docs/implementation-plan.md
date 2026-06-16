# Implementation plan

**Document type:** Agile delivery plan
**Companion to:** `productivity-tools-platform-solution-architecture.md`
**Status:** Draft for planning
**Date:** 16 June 2026

---

## 1. How this plan works

The plan is organised into five phases (A–E), each a sequence of two-week increments. Three rules shape it:

- **Vertical slices, not horizontal layers.** Every increment cuts through all layers (UI → gateway → orchestrator → worker → storage) and ends in something a person can click and see. We never build "all of storage" then "all of orchestration".
- **Walking skeleton first.** The first real increment is the thinnest possible end-to-end path — one trivial tool, run through the whole stack — proven before anything is thickened.
- **Risk-first sequencing.** The integration risks that could invalidate the design are tackled early: the async job model, manifest-driven UI/SDK generation, and the governance gate. The lower-risk, additive work (more tools, more bindings) comes later.

Every increment below states a **Demo** (the visual, testable output) and every phase states its **Infrastructure**. Definition of Done for an increment: code + tests + manifest/config + the demo runs on the phase's current target + it's merged through CI.

**Team assumption.** A small core team — roughly two backend, one frontend, one platform/DevOps, one AI/ML engineer, plus a part-time architect/PM and part-time security/compliance partner. Durations are indicative for that team and should be re-estimated with the actuals.

---

## 2. Phase overview

| Phase | Goal | Headline demo | Build target | Indicative |
|---|---|---|---|---|
| A — Foundations | Walking skeleton through every layer | A trivial tool runs end-to-end via the API and a minimal page | docker-compose | ~1 month |
| B — Pilot MVP | A real, useful single-tool platform for ~10 users | Upload a PDF in the UI → download the Excel; browse a tool catalog | Pilot VM | ~2 months |
| C — Composition & intelligence | Chains, chatbot, evaluation | Build an app by chaining tools; ask the chatbot for a tool; see a scorecard | Pilot VM | ~2 months |
| D — Governance & extensibility | RBAC, data classification, external tools | A restricted tool is hidden from the wrong user; register an external API tool | Pilot VM | ~1.5 months |
| E — Scale to AKS | Production-grade, autoscaling, HA | Same platform at a real URL; workers autoscale under load | AKS | ~1 month |

The phases map onto the architecture document's rollout: A–B reach the "knows it works" pilot, C–D mature it, E is the VM→AKS step.

---

## 3. Phase A — Foundations & walking skeleton

**Goal:** prove the end-to-end path and the developer workflow before building anything real.

### A0 — Project setup
Build: monorepo with `contracts/`, the skeleton services (gateway, registry, orchestrator, one worker), CI pipeline, and a one-command local stack.
**Demo:** `docker compose up` brings the stack online; a health page shows every service green; the OpenAPI/Swagger UI is reachable.
Done when: any team member can clone, run one command, and see the stack healthy.

### A1 — Walking skeleton
Build: registry loads one manifest from the repo; orchestrator dispatches a trivial **internal** tool (e.g. "uppercase text") synchronously; gateway enforces basic SSO/OIDC login; metering counts the run.
**Demo:** log in, call the tool from the Swagger page and from a one-field web form, see input → output; the run appears in a metering counter.
Done when: a request flows UI → gateway → registry → orchestrator → worker → response, authenticated and counted.

**Infrastructure (Phase A):** developer laptops + a shared Git repo and CI runner. Local stack via docker-compose: Postgres, MinIO (object store), Redis (cache/queue). No cloud, no LLM yet.

**Exit criteria:** thinnest vertical slice works end-to-end; CI builds and tests every service; the local stack is reproducible.

---

## 4. Phase B — Pilot MVP

**Goal:** a genuinely useful platform a 10-person pilot can use daily, on one VM.

### B2 — Async jobs + the first real tool (PDF→Excel)
Build: the message queue and worker pool; async execution with job status; object store wired for file in/out; the PDF→Excel tool as a real worker.
**Demo:** in the web UI, upload a PDF, watch the job move queued → running → done, then download the generated Excel.
Done when: a long-running tool runs asynchronously with visible status and file download.

### B3 — Registry maturity + auto-generated UI
Build: manifest meta-schema validation in CI; the JSON-Schema → form renderer; a browsable tool catalog.
**Demo:** browse a catalog of tools; open any one and see a form generated from its schema; run it from the UI with no tool-specific frontend code.
Done when: adding a new tool's manifest makes it appear in the catalog with a working form, no UI changes.

### B4 — SDK + developer access
Build: the manifest-driven SDK generator and a published SDK package; API-key issuance; SSO for the UI, keys/tokens for the SDK.
**Demo:** a developer runs a tool from a notebook using the typed SDK (autocomplete on inputs); the SDK reference page renders from manifests; a self-service screen issues an API key.
Done when: a developer can go from "find a tool" to "call it from code" in minutes.

### B5 — Metering & observability
Build: usage/latency/cost capture surfaced as a dashboard; tracing across services.
**Demo:** a dashboard showing runs per tool, latency p50/p95, and cost attribution per tool and per user.
Done when: every run is measured and visible; this is the data the financial proposal will draw on.

**Infrastructure (Phase B):** one pilot VM (e.g. 8 vCPU / 32 GB) running the docker-compose stack — app services plus self-hosted Postgres, MinIO, Redis. SSO/OIDC provider connected. CI/CD pipeline pushing images to a container registry. No LLM required yet (PDF→Excel is deterministic).

**Exit criteria:** ~10 pilot users can log in, run real tools through UI and SDK, and usage is fully measured. This is the validation-gate checkpoint from the architecture doc.

---

## 5. Phase C — Composition & intelligence

**Goal:** move from single tools to composed apps, assisted discovery, and measured quality.

### C6 — Composition engine + chain builder
Build: the composition engine (linear chains, async steps, output→input mapping); the visual chain builder with live JSON-Schema validation; apps saved as composite tools.
**Demo:** drag two or three tools into a chain, wire outputs to inputs (invalid wiring flagged live), run it, see per-step results, save it as an app that then appears in the catalog.
Done when: a non-developer can compose, run, and save an app from existing tools.

### C7 — Chatbot discovery
Build: embeddings + vector store; RAG over manifests (name, description, keywords, examples).
**Demo:** type "I need to turn a PDF into a spreadsheet" in chat and get the right tool suggested, with a button to run it.
Done when: natural-language search reliably surfaces the right tool from its manifest.

### C8 — Chatbot chain planning
Build: the planner that composes a draft chain for a goal; hand-off into the chain builder for review/adjust; save as app.
**Demo:** ask for a multi-step task, see a proposed chain open in the builder, adjust a step, and save it as a new app.
Done when: a complex goal becomes a reviewed, saved app without hand-wiring from scratch.

### C9 — Two-sided evaluation
Build: developer test sets + scorecards (quality/latency/cost) gating promotion; user feedback (thumbs + implicit signals) aggregated per tool/version.
**Demo:** a tool's scorecard page; a thumbs-down on a result feeding the score; CI blocking promotion of a version that regressed the test set (a visibly red gate).
Done when: quality is measured from both sides and a regressed version cannot reach `stable`.

**Infrastructure (Phase C):** same pilot VM, resources bumped as needed. Add a vector DB container (pgvector or Qdrant) and access to an LLM provider / embeddings (e.g. Azure OpenAI or provider keys) for discovery, planning, and LLM-as-judge scoring.

**Exit criteria:** users compose and discover apps conversationally; every tool and app carries a quality scorecard.

---

## 6. Phase D — Governance & extensibility

**Goal:** make the platform safe to broaden — control who uses what, what data may flow where, and accept tools from beyond the repo.

### D10 — Role-based access + data classification
Build: `permissions.roles` enforced at invocation and at surface generation; the `data_handling` class gate; the two-dimensional check (roles AND data class).
**Demo:** as a user without the `hr` role, a payroll tool is absent from the catalog and chatbot; sending a PHI-classified input to a public-only tool is refused with a clear error; both checks shown on a tool's catalog page.
Done when: restricted tools are invisible to the wrong users and data-class mismatches are blocked before any work runs.

### D11 — External-API binding + registration
Build: the `external-api` binding; the self-service registration flow with reachability/auth/schema validation; egress allowlist and audit; default-deny on raising an external tool's data class.
**Demo:** register an external tool via a form (endpoint + contract), watch the platform validate it, then run it; attempt to send a disallowed data class and see it blocked, with an egress audit entry.
Done when: an external tool can be registered and run safely, with data-egress governed.

### D12 — Additional bindings (prompt, human task; MCP optional)
Build: the `prompt` binding (no-code LLM tools); the `human` binding (a step that routes to a person and resumes on their action); optionally the `mcp` binding.
**Demo:** author a prompt-only tool in minutes and run it; run a chain that pauses at a human-approval step until an approver clicks, then resumes.
Done when: tools can be authored without code, and human-in-the-loop steps work inside chains.

**Infrastructure (Phase D):** still the pilot VM. Add a secrets manager and an egress proxy/allowlist for external calls. Governance/compliance partner engaged for any data-class policy touching sensitive data.

**Exit criteria:** access and data flow are governed end-to-end; the platform accepts internal and external tools under the same contract.

---

## 7. Phase E — Scale to AKS

**Goal:** take the proven platform to production-grade, multi-tenant-ready infrastructure.

### E13 — Helm + managed services + autoscaling
Build: the Helm chart; swap self-hosted backing services for managed Azure equivalents via config (no app code change); KEDA autoscaling of workers on queue depth; ingress + TLS.
**Demo:** the same platform running at a real HTTPS URL on AKS; a load test drives the queue up and a dashboard shows worker pods scaling out and back in.
Done when: the identical images run on AKS against managed services, autoscaling under load.

### E14 — Migration, HA & operations
Build: data migration (Postgres → Azure Database for PostgreSQL; MinIO → Blob) and cutover; production observability and SLO dashboards; backup/restore and a DR runbook.
**Demo:** production dashboards and SLOs; a rehearsed cutover; a restore-from-backup drill.
Done when: production is highly available, observable, and recoverable, with a documented runbook.

**Infrastructure (Phase E):** Azure — AKS cluster, Azure Container Registry, Azure Blob Storage, Azure Database for PostgreSQL, Azure Cache for Redis, Azure Service Bus, Azure AI Search (or managed pgvector), Azure Key Vault, Azure OpenAI, KEDA, ingress controller + TLS, and monitoring (e.g. Azure Monitor / Prometheus + Grafana).

**Exit criteria:** production-grade platform on AKS; the VM↔AKS difference is confined to a values file, proving the architecture's portability claim.

---

## 8. Cross-cutting practices (from day one)

- **CI/CD:** every service and tool builds, tests, and (from Phase B) deploys through the pipeline; affected-only builds in the monorepo.
- **Automated testing:** manifest meta-schema validation, each tool's declared test cases, and contract tests for external bindings — all gating merges.
- **Observability & metering:** instrumented from A1, not retrofitted; it is also the evidence base for the financial proposal.
- **Infrastructure as code:** the docker-compose and Helm definitions are the source of truth; no hand-tweaked environments.
- **Security & governance:** auth from Phase A; full RBAC/data-class by Phase D; compliance partner engaged before any sensitive data.

---

## 9. Sequencing rationale & risks

- **The async job model (B2) is sequenced first among the hard parts** because it underpins every long-running tool; getting it wrong late would be expensive.
- **Manifest-driven UI and SDK generation (B3–B4) come early** because they are the central bet of the architecture; if generation doesn't hold up, we want to know before building breadth.
- **Governance (D) precedes external bindings (D11) deliberately** — external tools need the data-class gate to already exist, or data could leave the perimeter ungoverned.
- **Governance also precedes scale (E)** — broadening an ungoverned platform multiplies risk. Basic auth exists from A; the full gate lands before the platform widens.
- **Health-tech caveat:** if the pilot will touch PHI or other regulated data *before* Phase D, pull RBAC and data classification earlier. Capability must not reach sensitive data before its controls exist.

---

## 10. Summary

The platform is delivered in five phases, each a series of demoable two-week increments: a walking skeleton (A), a useful single-tool pilot on one VM (B), composition and conversational intelligence with measured quality (C), governance and external extensibility (D), and the move to autoscaling production on AKS (E). Infrastructure grows only as a phase requires it — docker-compose, then a pilot VM with vector and LLM services, then managed Azure on AKS — and every increment ends in something you can see and test, not just a layer that exists.
