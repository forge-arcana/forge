---
name: vsix
description: Publish a VS Code extension — bump version, update changelog, build VSIX, push tag, create GitHub release with VSIX attached, remind user to upload to marketplace. Use when user says "vsix" or wants to release a new VSIX version.
---

# /vsix — VS Code Extension Publish

Bump version, package, push, release. The user uploads to the marketplace manually.

## Arguments
`$ARGUMENTS` — optional version bump type: `patch` (default), `minor`, or `major`. E.g., `/vsix minor`

---

## Step 1: Run /wrap
Invoke the `/wrap` skill first to ensure learnings, context, docs, lint, and commit are all clean.

## Step 2: Bump Version
- Determine bump type from `$ARGUMENTS` (default: `patch`)
- Read current version from `package.json`
- Compute new version (semver bump)
- Update `version` field in `package.json`

## Step 3: Update CHANGELOG.md
- Add a new entry at the top of the changelog (below the `# Changelog` heading)
- Format: `## X.Y.Z — YYYY-MM-DD`
- Summarize changes since last version using `git log` between the last tag and HEAD
- Keep entries concise — one bullet per meaningful change

## Step 4: Commit Version Bump
- Stage `package.json` and `CHANGELOG.md`
- Commit with message: `vX.Y.Z: <one-line summary of changes>`
- Do NOT add AI/agent attribution metadata (no `Co-Authored-By` footers)

## Step 5: Create Git Tag
- Tag the commit: `git tag vX.Y.Z`

## Step 6: Build VSIX
- Run `npm run build` to compile
- Run `npm run package` to create the VSIX
- Verify the VSIX file exists: `<project-name>-X.Y.Z.vsix`

## Step 7: Push to GitHub
- Push commits and tags: `git push origin <branch> --tags`
- Confirm the remote URL is correct before pushing

## Step 8: Create GitHub Release
- Use `gh release create vX.Y.Z <vsix-file> --title "vX.Y.Z" --notes "<changelog entry>"`
- Attach the VSIX file to the release

## Step 9: Remind User
Tell the user:
```
Published to GitHub. Upload the VSIX to the marketplace:
https://marketplace.visualstudio.com/manage
```
