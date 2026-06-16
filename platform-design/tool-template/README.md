# Tool template

Copy this directory to `tools/<your-team>/<your-tool>/` and work the checklist.
CI handles the rest — there is no platform code to touch to add a tool.

## Checklist

- [ ] `manifest.yaml`: set `id`, `name`, `description`, `owner`, `maintainer`
- [ ] Define `input_schema` and `output_schema` (JSON Schema)
- [ ] Choose `execution.mode` — `sync` for fast tools, `async` for long jobs
- [ ] Declare `dependencies`, `permissions.scopes` (least privilege), `metering.unit`
- [ ] Implement `src/handler.py` — reach services only through `ctx`, never import infra
- [ ] Add at least one case to `tests/test_cases.yaml`
- [ ] Add your team to `CODEOWNERS` for this path (must match `manifest.owner`)
- [ ] Open a PR — affected-only CI validates the manifest, runs tests, builds the
      image, and registers the tool on merge

## What you get for free, from `manifest.yaml` alone

Request validation, a typed SDK method, an auto-generated web form, rendered docs,
and chatbot discovery. Define the schema once; every surface stays in sync.

## Rules of thumb

- **Stateless.** Keep no state in the handler between calls; durable state lives in
  the object store / metadata DB via `ctx`.
- **Least privilege.** Only request the scopes you actually use.
- **Version discipline.** Any change to `input_schema`/`output_schema` is a breaking
  change — bump the version; consumers pin versions.
