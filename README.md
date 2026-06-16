# ToolX — Productivity Tools Platform

ToolX is a health-tech internal AI-first tools platform. It provides a manifest-driven registry of tools, composed into applications and solutions, served via an SDK, web UI, and chatbot. It incorporates two-sided evaluation, governance, and a VM-to-AKS deployment architecture.

## Repository Structure

- **`platform-design/`**: The design bundle containing the core architecture, implementation guides, preflight checklists, and architecture diagrams.
  - `platform-design/docs/`: Comprehensive design documentation covering solution architecture, UI architecture, and delivery plans.
  - `platform-design/setup/`: Scripts and documentation for verifying the local development environment.
  - `platform-design/diagrams/`: PNG and SVG files for all system design diagrams.
  - `platform-design/tool-template/`: Scaffold templates for registering new tools.

## Dev Environment Setup

To verify your local development environment meets the prerequisites, run the preflight check script from the repository root:

```bash
bash platform-design/setup/preflight-check.sh
```

For detailed setup instructions and build steps, refer to:
- [Preflight Check Guide](platform-design/setup/preflight-check.md)
- [Phase A Implementation Guide](platform-design/docs/phase-a-implementation-guide.md)
