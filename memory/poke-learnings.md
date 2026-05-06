# /poke Learnings

> Populated by `/poke` runs against the forge repo itself. Absorbed into forge by the `/forge` cycle.

<!-- Add learnings below this line -->

## Bash Script Exit Code Semantics — Always Exit 0 Masks Failures (2026-05-06)
**Learning**: When a bash script always exits 0 regardless of outcome (to "never fail the caller"), it prevents the caller from distinguishing success, no-op, transient failure, and permanent failure. Use exit codes to signal outcome: 0=success/no-op, 1=transient failure (retry later), 2=permanent failure (missing dependency, corrupt config). Callers can then decide whether to retry, escalate, or ignore. The "always exit 0" pattern is appropriate only for optional enhancements (e.g., a cache warmup that shouldn't block the main workflow), not for critical operations where the caller needs to know if the action succeeded.
**Forge-worthy**: yes — universal pattern for any scripting language with exit codes
**Apply when**: Writing bash scripts that are invoked by other scripts or automation, especially for operations with multiple failure modes (missing dependencies, network errors, corrupt state).

## Bash Function Decomposition — Extract Before 200 Lines (2026-05-06)
**Learning**: Bash scripts that exceed 200 lines with multiple responsibilities (path resolution, remote sync, drift detection, status reporting) become hard to test, debug, and reuse. Extract each responsibility into a named function that outputs its section independently. The main script becomes an orchestrator. This mirrors the Single Responsibility Principle from OOP but applies to procedural scripts. Functions enable: (1) testing individual pieces in isolation, (2) reusing logic across scripts, (3) clearer error handling (each function can exit with its own code), (4) easier debugging (set -x on one function, not the whole script).
**Forge-worthy**: yes — universal pattern for any procedural scripting language
**Apply when**: Writing bash scripts longer than 100 lines, or when a script does more than one conceptually distinct thing (e.g., "check status AND deploy" should be two functions).

## Bash Shared Utilities — Extract Duplicate Functions to lib/ (2026-05-06)
**Learning**: When multiple bash scripts define identical utility functions (Windows path conversion, JSON parsing wrappers, verification patterns), extract them to a shared `lib/` directory and source them. This prevents drift where one script's version gets a bug fix but others don't. The pattern: create `scripts/lib/utils.sh` with shared functions, then `source "$SCRIPT_DIR/lib/utils.sh"` at the top of each script. For portability, resolve `$SCRIPT_DIR` with `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` so sourcing works regardless of how the script is invoked.
**Forge-worthy**: yes — universal pattern for any bash project with multiple scripts
**Apply when**: Writing the second script that needs a function you already wrote in another script (DRY principle).

## Bash Dependency Checks — Fail Fast with Clear Error Messages (2026-05-06)
**Learning**: When a bash script depends on external tools (jq, python3, gh, rg), check for them at script start and exit with a clear error message if missing. Silent degradation (outputting empty strings or "0" when the tool is missing) makes debugging hard — the user sees "No results found" when the real issue is "jq not installed". The pattern: `if ! command -v jq >/dev/null 2>&1; then echo "ERROR: jq not found. Install with: sudo apt-get install jq"; exit 2; fi`. Use exit code 2 for missing dependencies (permanent failure), not 1 (transient failure).
**Forge-worthy**: yes — universal pattern for any script with external dependencies
**Apply when**: Writing any bash script that calls external tools (not just built-ins like grep, awk, sed).
