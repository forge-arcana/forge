# Versioning Standard

How every project built with the forge versions its units and shows which build is running. The HARD RULE "Every Unit Has a Version You Can Read" is the short form; this file is the detail. Tool facts verified 2026-10-06.

A unit is anything deployed or published on its own: a server or API, a web UI, a worker, a CLI, a published package, a mobile app, a container image.

## 1. Register the units

The project rules file carries a `## Versions` table, one row per unit:

| Unit | Kind | Version source | Surfaced at |
|------|------|----------------|-------------|
| api | server | `VERSION` | `GET /version`, `/health`, startup log |
| web | UI | `VERSION` (ships with api) | settings footer, `/version.json` |
| cli | published package | `packages/cli/package.json` | `--version` |

- Units that always ship together share one version and one row group. Do not invent a version per folder.
- Internal workspace packages that are never published are not units. Mark them `private` and leave them unversioned; a version on each means a bump per package per release and skew between them.
- A unit with no row is unversioned. That is a defect, not a default.

This table is the live register. Where the project has a Pattern, its Versioned Units table is the plan this one is built from.

## 2. One source of truth per unit

- The release version is SemVer `X.Y.Z` and lives in exactly one place: a root `VERSION` file, or the unit's single manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, the mobile app config).
- Prefer a root `VERSION` file. Every change to it is a version change, which keeps the build-identity arithmetic in section 3 exact.
- Anything else that needs the number reads it from the source at build time, or a test holds the two equal. Two hand-edited copies will drift.
- No version literals in code. A hardcoded `"0.0.0"` or `"1.0.0"` in a server banner or protocol handshake is the commonest form of this defect.
- Pre-release channels use SemVer pre-release identifiers on the release version: `1.5.0-rc.1`, `1.5.0-beta.2`.

Bumping:
- Patch for fixes, minor for backward-compatible features, major for a breaking change to anything a consumer depends on. Below `1.0.0`, a minor bump may break.
- Bumping by hand is fine for a single unit. Release tooling (changesets, release-please, release-it) earns its place when a repo publishes more than one package.

## 3. Build identity

The release version says which release; the build identity says which exact build. Both are always shown together, because a hash alone is unreadable and a release number alone cannot tell two builds apart.

Format:

| Build | String |
|-------|--------|
| Exactly at the commit that set the version | `1.4.0+a1b2c3d` |
| N commits after it | `1.4.1-dev.N+a1b2c3d` |
| Uncommitted changes in the tree | `1.4.1-dev.N+a1b2c3d.dirty` |
| Uncommitted changes at the commit that set the version | `1.4.1-dev.0+a1b2c3d.dirty` |

- `N` is the count of commits since the commit that last changed the version **value**: `git rev-list --count <that commit>..HEAD`. For a `VERSION` file that commit is `git log -1 --format=%H -- VERSION`. For a manifest, match the version line so an edit to dependencies or scripts does not reset the count, for example `git log -1 --format=%H -G'"version"' -- package.json`, or `-G'^version'` for `pyproject.toml`.
- If no commit has ever changed the version source (the file is new and not yet committed), or its value is edited but not yet committed, there is no baseline to count from. `N` is 0 and the build is dirty: `X.Y.(Z+1)-dev.0+<sha7>.dirty`, with `X.Y.Z` taken from the value on disk.
- The count needs full history. A shallow clone gives a wrong `N`: CI fetches full depth, and a build that finds a shallow repository (`git rev-parse --is-shallow-repository`) fails instead of guessing.
- Development builds are labelled against the **next patch** (`1.4.1-dev.N`, not `1.4.0-dev.N`). A pre-release sorts below its own release under SemVer precedence, so `1.4.0-dev.7` would rank as older than `1.4.0`.
- If the version source already has a pre-release part, append `.dev.N` to it instead: `1.5.0-rc.1.dev.N` sorts above `1.5.0-rc.1` and below `1.5.0-rc.2`. Only a plain `X.Y.Z` source is moved to the next patch. At the commit that set it, with a clean tree, the label is the source unchanged: `1.5.0-rc.1+a1b2c3d`.
- A dirty tree is never a release build. Release and deploy builds refuse to run on one. Before enforcing the refusal, look for tracked files that operators edit in place on the deploy host; one of those makes every deploy dirty. Ship such a file as an example plus a gitignored working copy.
- The part after `+` is SemVer build metadata: the 7-character commit SHA, then `.dirty` if the tree had uncommitted changes. Build metadata never affects ordering.
- A unit built from more than one repository lists each SHA, primary first: `+a1b2c3d.e4f5a6b`.
- Published packages and store builds carry only a release or pre-release version. No build whose version carries a `dev` identifier is ever published.
- Where a platform's grammar rejects SemVer (app-store version names, Python's PEP 440, image tags, which cannot contain `+`), map the string to the platform's form and keep the full SemVer string in the version object.

The version object, the same shape wherever a machine reads it:

```json
{
  "name": "api",
  "version": "1.4.1-dev.7",
  "build": {
    "sha": "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678",
    "short": "a1b2c3d",
    "dirty": false,
    "committedAt": "2026-10-06T09:12:44Z",
    "builtAt": "2026-10-06T09:20:01Z"
  },
  "startedAt": "2026-10-06T09:21:10Z"
}
```

`builtAt` is omitted by units that run from a checkout; `startedAt` is omitted by static assets and by runtimes with no long-lived process.

### Report what is loaded, not what is on disk

- Stamp the identity into the artifact at build time: a bundler `define`, a generated module, a build argument, or the platform's own version metadata.
- A build that runs without a repository (a pinned-commit sandbox, an image build with no `.git`) takes its identity from the tool that started it, as environment variables or build arguments: the full SHA, the commit time, `N` and the version label. The stamp reads a handed-in identity first and git second, checks that the version is valid SemVer, and fails if it has neither. The tool computes the identity from the full-history repository the commit came from.
- A service that runs straight from a checkout captures identity **once at process start** and caches it. Reading git when asked reports the newest commit in the repository, not the code in memory, and a process that was never restarted then claims a build it is not running.
- A deployable artifact must never carry a placeholder. If the build cannot determine a real identity (`dev`, `unknown`, `0.0.0`, an empty SHA), a deploy or release build fails. Local development builds may show `dev`, and any guard that compares identities must treat `dev` as "no comparison", never as a match.
- A state file that records the running version is believed only while the process that wrote it is alive.

## 4. Where the version is surfaced

| Unit | Required | Notes |
|------|----------|-------|
| Server / API / worker | `GET /version` returning the version object; the same object under `version` in `/health`; one startup log line with the full string | A unit that only receives a route prefix serves it under that prefix (`/api/version`). On Cloudflare Workers, the `version_metadata` binding (`id`, `tag`, `timestamp`) supplies the deployment identity; add it to the object, it does not replace the release version |
| Web UI | The full string visible to a signed-in user without developer tools: a footer, about or settings screen | Also serve it as a static `version.json` with `Cache-Control: no-store` so a stale tab can compare |
| Static site | The full string in the page (footer or an about page) and a static `version.json` | No endpoint, no startup log |
| CLI | `--version` printing the full string | Any `doctor` or `status` command prints it too |
| Published package | The manifest version; a changelog entry | |
| Library or data repository | The manifest version or a release tag, and a changelog entry | No endpoint |
| Container image | Labels `org.opencontainers.image.version`, `.revision` (full SHA), `.created`, `.source` | Tag images with the release version and the SHA, never only `latest` |
| Mobile app | Version name = release version; build number a monotonically increasing integer never reused; both shown in settings | |
| Error tracker | `release` set to `<name>@<version>+<short sha>` | Without it, an error cannot be tied to the build that raised it |
| Logs | The startup line; no per-line version. A runtime with no startup moment logs it once per instance, on first request | |

Unauthenticated responses carry only `name`, `version` and `build.short`: that covers `/version`, `/health` and a publicly served static `version.json`, and those three fields are enough for a stale tab to compare. The full SHA, the timestamps, `startedAt` and `dirty`, and anything about branches, filesystem paths, hostnames or dependencies, are served only to authenticated callers, or over a local socket that the network cannot reach. Never infer a local caller from the request address: behind a reverse proxy every request looks local.

## 5. Compatibility is a separate number

The release version is for people. Whether two things can talk to each other is decided by explicit contract versions.

- Every wire protocol, signed payload, stored record format and public API carries its own integer version, raised only when that contract changes.
- Each contract version is defined in exactly one place and imported everywhere else. The same constant typed into three files is a release blocker waiting to happen.
- Never compare release versions or SHAs to decide compatibility.
- A receiver states what it accepts as an explicit list or a minimum, and refuses the rest with a named error.
- Database schema version is the migration tool's own ledger. Do not keep a second one.
- A browser UI detects that it is older than the server it talks to (compare its stamped identity with `version.json` on load, on poll, and when the tab regains focus), tells the user in plain words, and disables actions that would be unsafe on a stale client until reload.
- Installed clients (mobile, desktop, CLI) send their version with each request; the server holds a configurable minimum and answers `426 Upgrade Required` below it.
- Local-first data stores stamp a format version and refuse to write over data from a newer format.

## 6. The release record

- Raising the version source is the release act. The same commit adds a `CHANGELOG.md` entry headed `## X.Y.Z — YYYY-MM-DD` (a hyphen in place of the dash is equally valid), one line per change a user or operator would notice.
- Tag the commit that raised the version: `vX.Y.Z`, or `<unit>-vX.Y.Z` in a repository with more than one unit. Where a tag push itself triggers publication, the tag is the publish step and is cut only when publishing.
- The record is the version and the changelog, not the SHA. Hashes change when history is rewritten; `1.4.0` does not.

## 7. A deploy proves itself

A deploy or update is done when the running unit reports the identity that was just shipped. The deploy script reads `/version` (or the platform equivalent) afterwards and fails on a mismatch. "The command exited zero" is not proof that the new build is serving.

A unit with no HTTP surface (a scheduled or queue worker), or one whose every route sits behind an access gate, is proven by the platform's own deployment or version identifier: the deploy confirms that the active one is the one it just uploaded. Where neither check can be scripted, the check is a recorded manual step, not a skipped one. A failed check reports the deploy as unverified and never rolls back on its own.

## Adoption

- New projects: the first foundation heat wires the version source, the build stamp, `/version`, and the visible UI string, before feature work.
- Existing projects: adoption is its own task, done before the next release or deploy. Inside unrelated work, report the gap and offer the task; do not start it. Order of work: register the units, set the source of truth, stamp identity, surface it, then the changelog. Compatibility numbers (section 5) are added when a contract next changes; do not retrofit them speculatively.
