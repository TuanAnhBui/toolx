# UI architecture

**Document type:** Frontend architecture and design
**Companion to:** `productivity-tools-platform-solution-architecture.md`, `implementation-plan.md`
**Scope:** Internal platform — one organization, many users and roles. **Multi-tenant is explicitly out of scope** (see §12).
**Status:** Draft for review
**Date:** 16 June 2026

---

## 1. Overview & scope

This document specifies the UI so it can grow from the Phase A walking skeleton to production **without being re-architected in between**. The guiding idea: across phases the UI gains *surfaces* (catalog, runner, chain builder, chatbot, dashboards, admin), but the *foundation beneath them never changes*. We build the foundation and an app shell in Phase A — even with a single screen — and every later phase plugs in a new module.

**In scope:** a single shared instance serving many internal **users** with **roles** (SSO identities, RBAC, per-user metering and access control). **Out of scope:** multi-tenancy — multiple isolated customer organizations. We do not build it, but we also do not design against it (§12).

---

## 2. Architecture principles

- **Shell + modules + shared foundation.** An app shell hosts pluggable feature modules over a shared foundation. New surfaces are *added as modules*, never grafted by changing the shell.
- **Foundation-first.** The six foundation pieces (§4) are built in Phase A and are the load-bearing decisions; getting them right is what prevents a rewrite.
- **Vertical slices.** Each increment delivers a usable surface end to end, not a half-built layer.
- **Schema-driven, not hand-coded.** Tool UIs are generated from manifests, not built per tool.

![UI architecture](diagrams/12_ui_architecture.png)

---

## 3. Recommended stack

| Concern | Choice | Why it won't need changing |
|---|---|---|
| Language | **TypeScript** | Type safety across a growing codebase; shared types with the generated client. |
| Framework | **React** | Largest ecosystem for every surface we need; lowest long-term risk. |
| Build / app | **Vite + React Router** (SPA) | An internal authenticated app is well served by a SPA for its whole life — no SSR switch to fear. (SSR via Next.js would only matter if we later productize externally — out of scope.) |
| Design system | **Tailwind + headless primitives** (Radix; shadcn/ui-style owned components) | Tokens-first styling; accessible primitives; components we own and can theme deeply. |
| Forms | **JSON-Schema renderer** (RJSF or custom over our components) | The catalog scales to many tools with zero per-tool UI work. |
| Server state | **TanStack Query** | One pattern for fetching, caching, polling, and streaming across every module. |
| Realtime | **SSE** (or WebSocket) behind the data layer | Job progress and chat streaming swap transport without touching components. |
| API client | **Generated typed client** (the SDK, from OpenAPI/manifests) | Frontend and backend never drift; new tools need no UI plumbing. |
| Auth | **OIDC/SSO** + roles context | RBAC rendering later is "read from context", not a re-plumb. |
| Charts | Recharts (or similar) | Dashboards and scorecards. |
| Canvas | React Flow | The chain builder's drag-and-wire surface. |
| Testing | Vitest + React Testing Library + Playwright | Unit, component, and end-to-end (the phase demos become e2e tests). |

The framework and patterns matter far more than any single library; libraries can be swapped behind the foundation seams, but the patterns are the rewrite insurance.

---

## 4. The shared foundation

These six pieces are built in Phase A and reused by every module. Each is something teams typically retrofit painfully — so we front-load them.

### 4.1 Design tokens & theming

All styling flows through CSS-variable design tokens (color, spacing, typography, radius, shadow). Components never hardcode values. Benefits *now*: visual consistency and light/dark mode (useful internally). Benefit *later*: any rebranding is a token swap, not a refactor. A `ThemeProvider` in the shell sets the active token set.

### 4.2 Generated API client (the SDK)

The UI consumes the same typed client generated from the platform's OpenAPI/manifests that developers use. No hand-written `fetch` calls in components. When a tool or endpoint is added, the client regenerates and the types flow through — drift is impossible by construction.

### 4.3 Auth & RBAC context

An `AuthProvider` handles the OIDC/SSO flow and exposes the current user and their roles via a `useAuth()` hook. A `useCan(permission)` helper and a `<RoleGate>` component conditionally render UI by role. Wired in Phase A with a single role; Phase D's role-aware rendering is then just reading this context. Roles come from the identity provider's groups — the UI never invents its own.

### 4.4 Server-state & data fetching

TanStack Query owns all server data: caching, background refetch, and polling. Mutations (e.g. "run this tool") return job handles that a query then polls or subscribes to. This single pattern covers job status (Phase B), live dashboards (Phase B/C), and chat (Phase C).

### 4.5 Realtime channel

A thin abstraction (`useStream` / a subscription hook) over SSE or WebSocket, sitting behind the server-state layer. Phase B may poll job status underneath; Phase C streams chatbot tokens — components don't change when the transport does.

### 4.6 Schema-driven rendering

The highest-leverage piece for this platform. A renderer turns a tool's `input_schema` (JSON Schema) into a form, and renders its output by `output_schema`. Mapping:

| Schema | Rendered control |
|---|---|
| `string` | Text input |
| `string` + `enum` | Select / dropdown |
| `string` + file ref (e.g. `format: uuid` for a `file_id`) | File-upload widget |
| `string` + `format: date` | Date picker |
| long-text hint | Textarea |
| `number` / `integer` (+ `min`/`max`/`step`) | Number input |
| `boolean` | Toggle |
| `array` | Repeatable list; multi-select when `enum` |
| `object` | Nested fieldset |
| `required` | Validation + required marker |
| `description` | Field help text / tooltip |
| `default` | Pre-filled value |
| `examples` | Placeholder / hint |

Two reusable pieces ride on this:

- **`<JobRunner>`** — submits a generated form, shows the async lifecycle (queued → running → succeeded/failed) via the server-state layer, then renders the result: a download link for file outputs (`result_file_id`), inline rendering for data, a clear error panel on failure.
- **File handling** — a file field uploads to the object store (presigned URL or via the gateway), receives a `file_id`, and fills the schema field; output file ids become download links. Built once, used by every file-based tool.

The same renderer powers the catalog's run forms, the chain builder's per-step configuration, and the chatbot's argument preview.

---

## 5. The app shell

The shell is the stable container every module mounts into. It owns:

- **Routing** — route-per-module, lazy-loaded (code-split), so heavy modules (chain builder, chatbot) load only when visited.
- **Layout** — a persistent frame: top bar (product name, user menu, role indicator), left navigation (filtered by role), and a content slot.
- **Providers** — `ThemeProvider`, `AuthProvider`, the query client, an error boundary, and a toast/notification host, composed once at the root.
- **Cross-cutting UX** — global loading, error, and empty states; a not-authorized view for role-gated routes.

Adding a surface means registering a route and a nav entry and dropping in a module — the shell itself doesn't change.

---

## 6. Feature modules

Each module is self-contained (its own routes, components, and queries) and depends only on the foundation — never on another module.

| Module | Purpose | Key components | Phase | Reuses |
|---|---|---|---|---|
| **Tool runner** | Run a single tool and see its result | generated form, `<JobRunner>`, result/error views | A → B | schema renderer, server-state, API client |
| **Catalog** | Browse, search, and open tools/apps | tool cards, filters, detail page (form + scorecard + permissions/data-class badges) | B | API client, auth context (role filtering) |
| **Dashboards** | Usage, latency, cost, and scorecards | charts, tables, filters | B → C | server-state, charts |
| **Chain builder** | Compose apps by wiring tools | React Flow canvas, step config (schema renderer), live validation, save-as-app | C | schema renderer, API client |
| **Chatbot** | Discover tools and plan chains | streaming chat, tool suggestion cards, hand-off to chain builder | C | realtime/streaming, API client, auth context |
| **Admin & RBAC** | External-tool registration, role/data-class views | registration form, validation status, tool governance panels | D | schema renderer, auth context, API client |

Role-aware rendering (Phase D) is not a new mechanism: the catalog and chatbot already read the roles context from §4.3, and the platform returns only tools the user may invoke, so restricted tools simply don't appear.

---

## 7. Cross-cutting UI concerns

- **Accessibility** — headless primitives (Radix) and token-driven styling give a strong baseline; schema field titles become proper labels; the chain-builder canvas needs explicit keyboard support.
- **Performance** — route-based code-splitting per module; server-state caching; virtualize long catalog/usage lists.
- **States** — every data view has explicit loading, empty, and error states (a shared set of components), not just the happy path.
- **Frontend observability** — capture client errors and key interactions; tie into the platform's metering where useful.
- **Internationalization** — not required now, but keep user-facing strings out of logic so it stays possible.

---

## 8. Project structure (in the monorepo, under `web/`)

```
web/
├── app/                  # the shell
│   ├── routes/           #   route definitions (lazy-loaded modules)
│   ├── layout/           #   frame: top bar, nav, content slot
│   └── providers.tsx     #   theme · auth · query · error boundary · toasts
│
├── foundation/           # built in Phase A, reused everywhere
│   ├── api/              #   generated client + typed query/mutation hooks
│   ├── auth/             #   OIDC, useAuth(), useCan(), <RoleGate>
│   ├── theme/            #   design tokens, ThemeProvider, light/dark
│   ├── forms/            #   JSON-Schema renderer, <JobRunner>, file field
│   ├── realtime/         #   useStream over SSE/WebSocket
│   └── query/            #   TanStack Query setup, keys, polling
│
├── ui/                   # design system — owned components on Radix + tokens
│
├── modules/              # feature modules (one folder each)
│   ├── runner/
│   ├── catalog/
│   ├── dashboards/
│   ├── chain-builder/
│   ├── chatbot/
│   └── admin/
│
└── tests/                # e2e (Playwright); unit/component live beside source
```

`foundation/` and `ui/` are the stable core; `modules/` is where the app grows.

---

## 9. Phase A foundation checklist

Build these before any real screens — they are the "set up once" investment:

- [ ] App shell: router, layout frame, root providers, error boundary
- [ ] Design tokens + light/dark `ThemeProvider`
- [ ] `AuthProvider` (OIDC/SSO), `useAuth()`, `useCan()`, `<RoleGate>` — with a single role
- [ ] Generated API client wired to TanStack Query
- [ ] JSON-Schema form renderer + `<JobRunner>` + file field — render the trivial tool's form through it
- [ ] Realtime abstraction (polling underneath is fine to start)
- [ ] One module (runner) proving the full path
- [ ] A Playwright e2e test of the A1 demo

---

## 10. Per-phase UI deliverables

| Phase | UI deliverable | Visual demo |
|---|---|---|
| A | Shell + foundation + runner module | The trivial tool's generated form runs end-to-end |
| B | Catalog, runner matured (async/upload/download), dashboards, SDK docs page | Upload a PDF → download Excel; browse a catalog of auto-generated forms |
| C | Chain builder, chatbot, scorecard views | Wire an app; ask the chatbot for a tool; view a scorecard |
| D | Admin/registration, role-aware rendering, data-class badges | A restricted tool is hidden from the wrong user; register an external tool |
| E | No structural change — deploy with the platform; tokens already in place | The same UI at the production URL on AKS |

Phase E needs no UI re-architecture: the build is containerized and deployed alongside the platform, and theming was token-driven from the start.

---

## 11. Testing strategy

- **Unit** (Vitest) — hooks and utilities.
- **Component** (React Testing Library) — modules and shared components, including schema-rendered forms.
- **Contract** — run the generated client against a mock (MSW) derived from the OpenAPI, so backend drift surfaces in the UI build.
- **End-to-end** (Playwright) — each phase's **Demo** becomes an e2e test, so "visually testable" is also "automatically tested".
- **Visual regression** (optional) — screenshot diffs against the design system for high-traffic screens.

---

## 12. Out of scope / deferred

- **Multi-tenancy** — multiple isolated organizations, per-tenant data isolation and branding. Not built. But we **don't design against it**: components get data through `foundation/api` and identity through `foundation/auth`, never assuming a hardcoded global org, so a future tenant context would slot into the foundation rather than requiring component changes.
- **SSR / meta-framework (Next.js)** — only relevant if we later productize externally; the modular foundation means adding it would change the shell/hosting, not the modules.
- **Micro-frontends** — premature for a small team. The module boundaries leave it available later (independent deploys for ~50 developers) without a rewrite.

---

## 13. Summary

The UI is an app shell hosting pluggable feature modules over a shared foundation of six pieces — design tokens, a generated API client, an auth/RBAC context, a server-state layer, a realtime channel, and a JSON-Schema form renderer — all built in Phase A. Every later phase adds a module (catalog, dashboards, chain builder, chatbot, admin) without touching the shell or the foundation, so the UI grows from the walking skeleton to production without a re-architecture. The stack is React + TypeScript on Vite, tokens-first styling, and a schema-driven approach that lets the tool catalog scale with zero per-tool UI work. Scope is internal — many users and roles in one organization; multi-tenancy is deliberately deferred but not designed against.
