# Art Selection Matrix

> Referenced by [SKILL.md](SKILL.md) — loaded during evaluation planning.

## Selection by Build Stage

| Build Stage | Default Art(s) | Triggered By | Phase Gate Art(s) |
|-------------|----------------|-------------|-------------------|
| Foundation (scaffolding, schema, auth) | `/poke` | UI components → add `/preen` | `/probe` |
| Core Workflow (each heat) | `/poke` | UI components → add `/preen` | `/probe` + `/press` |
| Supporting (payments, trust, admin) | `/poke` | UI → `/preen`; security-critical → `/press` | `/press` |
| Hardening (testing, CI/CD, compliance) | `/press` | Security areas → `/pound` | `/temper` |
| Final Gate | `/temper` + `/pound` (+ `/pitch --critique` when monetized) | — | Convergence loop |

## Detection Rules for Triggered Arts

- **/preen trigger**: Heat creates or modifies files matching `*.tsx`, `*.vue`, `*.svelte` with JSX/template content, or files in `components/`, `pages/`, `views/`, `layouts/` directories
- **/press trigger on security-critical**: Heat touches auth, payment, encryption, session management, or files matching `*auth*`, `*pay*`, `*crypt*`, `*session*`, `*token*`. This trigger is non-optional — a security-critical heat's gate includes `/press`; smith may not waive it.
- **/pound trigger on security areas**: Heat modifies input validation, rate limiting, CORS, CSP, or any OWASP-relevant surface

## Escalation Ladder

Per-heat review depth follows the heat's grade (SKILL.md → 2d): T1 → verify only, diff batched into the next phase gate; T2 → scoped `/poke` (+ `/preen` on UI, + `/press` when security-critical); T3 → full `/poke` + `/press` with the security dimension always on. Gate intensity rises with build position and never decreases: unit gates per SKILL.md Step 3, `/temper` at Hardening, and the `/temper` + `/pound` convergence loop (+ `/pitch --critique` when monetized) at the Final Gate.
