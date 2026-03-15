# Global Patterns

> Cross-cutting patterns merged from all learning sources by `/reforge`.

<!-- Add patterns below this line -->

## WSL Path Compatibility (2026-03-15)
**Learning**: When running across Windows + WSL2, tool configuration that references directories must include all 3 path formats: Windows (`D:\`), WSL-mount (`/mnt/d/`), native Linux (`/root/dev/`). Without all three, permission prompts re-appear depending on which environment the session runs from.
**Apply when**: Setting up any tool that uses directory allow-lists on a WSL2 machine.

## Configurable Paths via Resolution Chain (2026-03-15)
**Learning**: Never hardcode absolute paths in portable tools or skills. Use a resolution chain: (1) env var, (2) config file entry, (3) fallback default. This makes tools portable across machines and environments.
**Apply when**: Any tool or skill references a directory that varies by machine (repos, config dirs, data dirs).

## Global Config Over Per-Project Duplication (2026-03-15)
**Learning**: When a tool supports both global and per-project configuration, put all standard settings in the global config. Only create per-project config for overrides. Duplicating the full config into every project is a DRY violation that creates drift and maintenance burden.
**Apply when**: Setting up project-level configuration files for tools that also have a global config.
