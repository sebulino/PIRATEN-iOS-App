# PIRATEN iOS App – Milestone Roadmap

This folder contains the **immutable roadmap milestones** for the PIRATEN iOS app.
Each milestone represents a **coherent, reviewable unit of progress** and is designed
to be executed autonomously using **Ralph + Claude Code**, with strict guardrails.

## How this works (important)

- Each subfolder contains exactly **one `prd.json`**
- A milestone PRD is **never edited after completion**
- To execute a milestone:
  1. Copy its `prd.json` to `scripts/ralph/prd.json`
  2. Run Ralph
  3. Review, merge, and move on

This design ensures:
- Auditability (what was planned vs. what was built)
- Reproducibility (rerun any milestone later)
- Safety for an *official* party tool

---

## Milestone Overview

### M3a – Authentication & Session Management
**Goal:** Establish real OAuth2 / OpenID Connect authentication using AppAuth‑iOS (Authorization Code + PKCE).

Key outcomes:
- Secure SSO login (Piratenlogin)
- Token storage & refresh
- Logout and session recovery
- Authenticated HTTP client foundation

This milestone unlocks all protected APIs.

---

### M3b – Authenticated Discourse APIs (Forum + Messages)
**Goal:** Replace fake forum data with real, authenticated Discourse access.

Key outcomes:
- Read‑only forum browsing
- Read‑only private messages
- Robust error handling and auth expiry recovery

No write actions yet.

---

### M4 – Messaging MVP (Reply Only)
**Goal:** Introduce the first controlled write action: replying to private messages.

Key outcomes:
- Reply composer for existing PM threads
- Conservative safeguards (rate limiting, validation)
- No message creation, no attachments

This milestone is intentionally narrow to reduce risk.

---

### M5 – Todos (Create, Claim, Complete)
**Goal:** Turn passive reading into low‑risk participation via Todos.

Key outcomes:
- Create Todos
- Ownership by Kreisverband / Landesverband / Bundesverband / Arbeitsgemeinschaft
- Claim, complete, and comment on Todos
- Deletion implemented at repository level but **not exposed in UI**

This is the primary participation lever for semi‑active members.

---

### M6 – Push Notifications
**Goal:** Deliver timely signals without violating trust or privacy.

Key outcomes:
- Opt‑in push notifications only
- Scope limited to Messages and Todos
- Deep linking into the correct screen
- Transparent settings and documentation

No analytics or tracking.

---

### M7 – Knowledge & Orientation Hub
**Goal:** Lower the activation threshold for semi‑active members.

Key outcomes:
- Curated knowledge articles
- Role‑based shortcuts (optional, local only)
- “Start here” orientation without pressure

This milestone focuses on belonging and clarity, not persuasion.

---

### M8 – Hardening & Governance Readiness
**Goal:** Prepare the app for long‑term, official use.

Key outcomes:
- Security and privacy hardening
- Accessibility improvements
- Resilience under poor network conditions
- Release and CI documentation

This milestone ensures the app can withstand scrutiny.

---

## Guiding Principles

- **Privacy first** – no dark patterns, no hidden tracking
- **Conservative write actions** – introduce risk gradually
- **Documentation is part of the product**
- **Automation-friendly** – filesystem-first, no brittle project mutations
- **Official-tool mindset** – assume public scrutiny

---

## Notes for Future Work

- Posting to forum topics
- Creating new message threads
- Voting / polling features
- Event and mandate tooling

These are intentionally **out of scope** until trust, stability, and governance are fully established.
