# Human-in-the-loop browser workflow

Use this reference for CAPTCHA, Cloudflare, anti-bot, login, or SSO walls that require the user to act in a real browser window.

## Boundary

The workflow does not solve or bypass challenges. It separates responsibilities:

- The user completes verification or authentication in a dedicated Chrome window.
- The agent attaches briefly through a loopback CDP endpoint, reads the resulting page, and detaches.
- The dedicated browser uses its own profile and is removed from the lifecycle without touching the user's daily browser.

Chrome 136 and later require remote debugging to use a non-default user data directory. The scripts already create a dedicated profile for this reason.

## Windows scripts

| Script | Contract |
|---|---|
| `scripts/start-chrome-cdp.ps1` | Start visible Chrome with loopback CDP and a dedicated profile |
| `scripts/read-page.ps1` | Attach, read title/URL/snapshot, detect common block hints, detach |
| `scripts/stop-chrome-cdp.ps1` | Stop Chrome only when both configured port and profile identify it |
| `scripts/run-site.ps1` | One-shot start/read/stop for pages that need no human pause |

Defaults:

- Profile: `%USERPROFILE%\.playwright-cli\profiles\human-chrome`
- CDP endpoint: `http://127.0.0.1:9222`
- Playwright CLI session: `human`

Resolve the scripts directory from the installed skill, not from a hard-coded repository path:

```powershell
$scripts = "<installed-skill-directory>\scripts"
```

### Lifecycle

Start a visible browser:

```powershell
& "$scripts\start-chrome-cdp.ps1" -Url "https://example.com"
```

Read once:

```powershell
& "$scripts\read-page.ps1"
```

The read script exits with code `3` when the URL, title, or snapshot contains common challenge hints. It always detaches before returning.

If blocked, end the browser-tool turn and ask the user to finish or skip the challenge. Do not poll, sleep for minutes, or interact with the challenge widget. After confirmation, read again and use the new snapshot:

```powershell
& "$scripts\read-page.ps1"
```

Clean up after success, skip, or abort:

```powershell
& "$scripts\stop-chrome-cdp.ps1"
```

The stop script refuses to terminate a browser that cannot be matched to both the configured CDP port and dedicated profile.

### Custom port or profile

Use the same values for every script in the lifecycle:

```powershell
$profile = "$env:USERPROFILE\.playwright-cli\profiles\project-a"
$port = 9333

& "$scripts\start-chrome-cdp.ps1" -Url "https://example.com" -Port $port -Profile $profile
& "$scripts\read-page.ps1" -Port $port -Session project-a
& "$scripts\stop-chrome-cdp.ps1" -Port $port -Profile $profile -Session project-a
```

## Linux and macOS equivalent

The bundled lifecycle scripts target Windows. On Linux or macOS, use the same dedicated-profile and loopback-CDP model.

```bash
PROFILE="$HOME/.playwright-cli/profiles/human-chrome"
PORT=9222
URL="https://example.com"

CHROME="$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser || true)"
if [ -z "$CHROME" ] && [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
fi
test -n "$CHROME" || { echo "Chrome or Chromium was not found" >&2; exit 1; }

mkdir -p "$PROFILE"
nohup "$CHROME" \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$PORT" \
  --user-data-dir="$PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  "$URL" >/tmp/playwright-cli-human-chrome.log 2>&1 &

until curl -fsS "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; do sleep 0.3; done

playwright-cli attach --cdp="http://127.0.0.1:$PORT" --session=human
playwright-cli -s=human --raw eval "() => document.title"
playwright-cli -s=human snapshot
playwright-cli -s=human detach
```

Before cleanup, inspect the matching processes. Terminate only processes using the dedicated profile:

```bash
pgrep -af -- "--user-data-dir=$PROFILE" || true
PIDS="$(pgrep -f -- "--user-data-dir=$PROFILE" || true)"
test -z "$PIDS" || kill $PIDS
```

Never use `killall chrome` or another broad process match.

## Challenge signals

Treat the page as blocked when its URL, title, or visible snapshot suggests:

- `Just a moment`, `Checking your browser`, or `Attention Required`
- CAPTCHA, hCaptcha, reCAPTCHA, or `verify you are human`
- unusual traffic or a `/sorry/` URL
- a login or SSO wall that the user must complete
- `正在确认`, `机器人`, or `请完成安全验证`

Heuristics can produce false positives or miss a customized challenge. Use page context and user instructions rather than relying only on the exit code.

## Troubleshooting

### CDP port is already in use

Choose another port or close the known dedicated instance. The start script does not stop an unknown browser merely because it owns the same port.

### Browser opens but CDP is unavailable

- Confirm the profile is not Chrome's default profile.
- Confirm local security software permits loopback connections.
- Try a different port.
- Pass the browser executable explicitly with `-ChromePath` on Windows.

### Browser session is not open

Do not depend on a Playwright CLI daemon surviving an agent shell boundary. Keep the real Chrome process alive, then use a fresh `attach` / read / `detach` cycle.

### The page remains blocked after user confirmation

Ask the user whether the page visibly finished loading. Then perform a new read cycle. Do not reuse the pre-verification snapshot or attempt automated challenge interaction.

## Manual smoke test

Use `https://example.com` to verify start/read/stop without a challenge. For challenge behavior, use only sites you are authorized to access and let the user perform every verification step.
