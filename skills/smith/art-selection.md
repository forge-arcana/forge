# Art Selection Matrix

> Referenced by [SKILL.md](SKILL.md) — loaded during evaluation planning.

## Selection by Build Stage

| Build Stage | Default Art(s) | Triggered By | Phase Gate Art(s) |
|-------------|----------------|-------------|-------------------|
| Foundation (scaffolding, schema, auth) | `/poke` | UI components → add `/preen` | `/probe` |
| Core Workflow (each heat) | `/poke` | UI components → add `/preen` | `/probe` + `/press` |
| Supporting (payments, trust, admin) | `/poke` | UI → `/preen`; security-critical → `/press` | `/press` |
| Hardening (testing, CI/CD, compliance) | `/press` | Security areas → `/pound` | `/temper` |
| Final Gate | `/temper` + `/pound` | — | Convergence loop |

## Detection Rules for Triggered Arts

- **/preen trigger**: Heat creates or modifies files matching `*.tsx`, `*.vue`, `*.svelte` with JSX/template content, or files in `components/`, `pages/`, `views/`, `layouts/` directories
- **/press trigger on security-critical**: Heat touches auth, payment, encryption, session management, or files matching `*auth*`, `*pay*`, `*crypt*`, `*session*`, `*token*`
- **/pound trigger on security areas**: Heat modifies input validation, rate limiting, CORS, CSP, or any OWASP-relevant surface

## Escalation Ladder

Five rungs of increasing intensity. Smith starts at Rung 1 and escalates at defined trigger points. Intensity never decreases.

```
Rung 1: LIGHT         — /poke only (every heat)
Rung 2: LIGHT+DESIGN  — /poke + /preen (UI heats)
Rung 3: MEDIUM        — /poke + /press (unit boundaries)
Rung 4: HEAVY         — /temper (phase boundaries — 3x poke+press)
Rung 5: CONVERGENCE   — /temper + /pound loop (final gate)
```
