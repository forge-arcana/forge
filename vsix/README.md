# VS Code Extensions (Built from Source)

## Claudemeter v2.0.3

Claude AI usage monitor — shows 5-hour session limit and weekly usage in the VS Code status bar.

- **Source:** https://github.com/hyperi-io/claudemeter
- **License:** MIT
- **Built from:** commit at time of build (2026-03-14)
- **Security audit:** No data exfiltration found. All network traffic goes to `claude.ai` and `status.claude.com` only. No telemetry.

### Install

From VS Code: `Ctrl+Shift+P` → **Extensions: Install from VSIX...** → select:

```
\\wsl$\Ubuntu\root\dev\forge\vsix\claudemeter-2.0.3.vsix
```

### Rebuild from Source (with Security Scan)

Before building, scan the source for backdoors. Do this every time you pull a new version.

```bash
cd /tmp
git clone https://github.com/hyperi-io/claudemeter.git
cd claudemeter
```

**1. Check for suspicious network destinations** — should only show `claude.ai` and `status.claude.com`:

```bash
grep -rn "https\?://" src/ --include="*.js" --include="*.ts" | grep -v node_modules | grep -v "claude.ai" | grep -v "status.claude.com" | grep -v "// "
```

**2. Check for credential/token access** — verify it only reads `organizationUuid`, `subscriptionType`, `rateLimitTier` from Claude credentials (not `accessToken` or `refreshToken` for storage/exfil):

```bash
grep -rn "accessToken\|refreshToken\|sessionKey\|cookie" src/ --include="*.js" --include="*.ts"
```

Review each match. `accessToken` should only appear in a `Bearer` header sent to `claude.ai/api/bootstrap`. `sessionKey`/cookie should only be saved locally to `~/.config/claudemeter/`.

**3. Check for data exfiltration patterns** — should return nothing:

```bash
grep -rn "fetch\|axios\|http\.request\|XMLHttpRequest\|WebSocket\|net\.connect" src/ --include="*.js" --include="*.ts" | grep -v "claude.ai" | grep -v "status.claude.com" | grep -v node_modules
```

**4. Check for code execution tricks** — should return nothing:

```bash
grep -rn "eval(\|Function(\|child_process\|exec(\|execSync\|spawn(" src/ --include="*.js" --include="*.ts" | grep -v node_modules
```

**5. Check for postinstall hooks** — should return nothing suspicious:

```bash
grep -A2 "postinstall\|preinstall\|prepare" package.json
```

**6. If all clean, build and package:**

```bash
npm install
npm run build
npx vsce package
# Output: claudemeter-X.X.X.vsix
```

**7. Copy to forge and install:**

```bash
cp claudemeter-*.vsix ~/dev/forge/vsix/
# Then in VS Code: Ctrl+Shift+P → "Extensions: Install from VSIX..."
```
