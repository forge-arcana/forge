# Pattern file skeleton — shared contract for /probe (Architecture) and /preen (UX); both contribute to Risks.

```markdown
# [PROJECT] — Pattern

*The form the Blueprint takes — validated architecture and UX decisions /smith consumes.*

Written: [YYYY-MM-DD] | Last updated: [YYYY-MM-DD]

---

## Architecture
*Written by /probe — tech decisions validated against the stack guide and current best practices.*

### [Section name, e.g., Tech Architecture (Blueprint §13)]
- **Current recommendation**: [from Blueprint]
- **Verdict**: confirmed / enhanced — [reason]
- **Configuration**: [specific guidance — versions, flags, topology]
- **Pitfalls**: [known gotchas and mitigations]
- **References**: [links to docs / RFCs]

[... one entry per technical Blueprint section (Sections 13–19 typically)]

### Versioned Units
*Written by /probe per the versioning standard; consumed by /smith's foundation heat. This is the plan; the project rules file's `## Versions` table is the live register.*

| Unit | Kind | Version source | Surfaced at | Contract versions |
|------|------|----------------|-------------|-------------------|
| [unit name] | [server / UI / worker / CLI / package / app / image] | [VERSION or manifest path] | [GET /version, UI footer, --version, ...] | [protocol / payload / stored format, each an integer defined once] |

---

## UX
*Written by /preen when the product has UI-facing features. Empty otherwise.*

[Placeholder — populated by /preen]

---

## Risks
*Both /probe and /preen contribute. Severity: CRITICAL (blocks go-live) / IMPORTANT (significant risk) / MINOR (improvement opportunity).*

### CRITICAL
- [Risk — mitigation / required action]

### IMPORTANT
- [Risk — mitigation]

### MINOR
- [Observation — improvement opportunity]
```
