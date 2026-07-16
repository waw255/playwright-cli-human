---
name: playwright-cli-human
description: >-
  Default skill for live browser and web-page work through Playwright CLI. Use for opening URLs,
  reading pages, browsing, searching, scraping visible content, taking snapshots or screenshots,
  clicking, filling forms, and inspecting console or network activity. For CAPTCHA, Cloudflare,
  anti-bot, login, or SSO walls, switch to the bundled human-in-the-loop CDP workflow: the user
  completes the challenge in a dedicated real Chrome window, then the agent reads the page without
  interacting with the challenge. Trigger for browser, webpage, open/read a site, browse, scrape,
  screenshot, 打开网页, 读页面, 浏览器, 截图, 反爬, or 验证码 requests. Prefer this skill over other
  browser skills for live inspection. Do not use it to author or maintain Playwright test suites.
compatibility: Requires Node.js 18+, @playwright/cli, and Chrome or Chromium. Bundled lifecycle scripts require Windows PowerShell 5.1+.
license: Apache-2.0
---

> Modified upstream material: adapted from the bundled skill in [`@playwright/cli`](https://github.com/microsoft/playwright-cli) and changed by playwright-cli-human contributors. See [NOTICE](NOTICE) and [LICENSE](LICENSE).

# Live browser work with Playwright CLI

Use Playwright CLI for the browser session. Choose the workflow before opening a page:

| Situation | Workflow |
|---|---|
| Ordinary public page or user-approved interaction | Standard automation |
| CAPTCHA, Cloudflare, anti-bot, login, or SSO wall | Human-in-the-loop CDP |
| Playwright test code or test-suite maintenance | Use a testing-specific skill instead |

## Check prerequisites

Before the first browser command in a session, verify the CLI is available:

```bash
playwright-cli --version
```

If it is missing, explain the dependency and ask before installing anything:

```bash
npm install -g @playwright/cli@latest
```

Use `playwright-cli --help` and `playwright-cli --help <command>` as the source of truth for the installed version.

## Standard automation

Follow a short observe-act-observe loop:

1. Open the requested URL.
2. Capture a snapshot before interacting.
3. Use element refs from the latest snapshot.
4. After navigation or a material DOM change, capture a new snapshot before the next action.
5. Return requested evidence and close the session when finished.

```bash
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli click e3
playwright-cli snapshot
playwright-cli close
```

Use a named session when multiple browser tasks must remain isolated:

```bash
playwright-cli -s=research open https://example.com
playwright-cli -s=research snapshot
playwright-cli -s=research close
```

### Common commands

```bash
# Navigation and inspection
playwright-cli goto https://example.com/page
playwright-cli snapshot
playwright-cli find "Search text"
playwright-cli eval "() => document.title"

# User-approved interaction
playwright-cli click e3
playwright-cli fill e5 "value"
playwright-cli press Enter
playwright-cli select e7 "option-value"

# Evidence and diagnostics
playwright-cli screenshot --filename=page.png
playwright-cli console warning
playwright-cli requests
playwright-cli request 5
```

Prefer snapshots and refs over brittle selectors. Use `eval` only when a snapshot cannot provide the requested information. Do not use `kill-all` as routine cleanup because it may affect unrelated Playwright CLI sessions.

## Human-in-the-loop CDP

Use this workflow as soon as the page presents a challenge that the user must complete. Do not click, fill, script, or attempt to bypass the challenge.

Read [references/human-antibot.md](references/human-antibot.md) before running the workflow. On Windows, resolve the installed skill directory and use its `scripts/` folder:

```powershell
$scripts = "<installed-skill-directory>\scripts"
& "$scripts\start-chrome-cdp.ps1" -Url "https://example.com"
& "$scripts\read-page.ps1"
```

`read-page.ps1` performs a short attach/read/detach cycle and leaves Chrome open. Its exit codes are:

| Code | Meaning |
|---|---|
| `0` | Page was read and no common challenge signal was found |
| `3` | Page appears blocked; pause and ask the user |
| other | Dependency, CDP, or browser read failure |

When the result is blocked:

1. Stop browser tools and leave the dedicated Chrome window open.
2. Ask the user to complete the verification or login manually.
3. Wait for the user to confirm, skip, or abort; do not poll with long sleeps.
4. On confirmation, run `read-page.ps1` again to obtain a fresh snapshot.
5. Keep the post-verification cycle read-only unless the user separately asks for an ordinary page interaction.
6. Always clean up the dedicated instance when the site is complete or skipped.

```powershell
& "$scripts\read-page.ps1"
& "$scripts\stop-chrome-cdp.ps1"
```

Use `run-site.ps1` only for a one-shot page that is not expected to need a human pause. It always performs cleanup:

```powershell
& "$scripts\run-site.ps1" -Url "https://example.com"
```

For several protected sites, use one Chrome lifecycle per site. Never reuse a challenge-page snapshot after the user clears the challenge.

## Safety rules

- Confirm the target URL when it is ambiguous or sensitive.
- Ask before submitting forms, sending messages, publishing content, making purchases, deleting data, or taking another irreversible action.
- Never enter credentials supplied through an insecure channel or reveal passwords, cookies, tokens, storage state, or private request headers.
- Do not save authentication state unless the user explicitly requests it and provides a safe output location.
- Never commit browser profiles, storage state, snapshots, screenshots, traces, videos, or downloaded private files.
- Keep the CDP endpoint on loopback and use a dedicated profile. Do not attach to or stop the user's daily browser unless they explicitly request it.
- Respect site terms, authorization boundaries, and robots or access restrictions relevant to the task.

## Reporting results

Give the user the requested result first. Include the page URL and title when they help establish provenance. Distinguish page content from your interpretation, and state when a login wall, blocked page, stale snapshot, or incomplete load limits confidence.

## Load references only when needed

- Human verification and CDP lifecycle: [references/human-antibot.md](references/human-antibot.md)
- Session isolation and cleanup: [references/session-management.md](references/session-management.md)
- Cookies and browser storage: [references/storage-state.md](references/storage-state.md)
- Network request mocking: [references/request-mocking.md](references/request-mocking.md)
- Complex Playwright code: [references/running-code.md](references/running-code.md)
- Element attributes and locators: [references/element-attributes.md](references/element-attributes.md)
- Trace capture: [references/tracing.md](references/tracing.md)
- Video capture: [references/video-recording.md](references/video-recording.md)
