# Contributing

Thanks for improving `playwright-cli-human`.

## Scope

Keep the skill focused on live browser and web-page work. Normal pages may use Playwright CLI automation; CAPTCHA, anti-bot, and login walls must remain human-controlled. Playwright test-suite authoring belongs in a separate skill.

## Development setup

1. Install Node.js 18+ and `@playwright/cli`.
2. Install Google Chrome or a compatible Chromium browser.
3. Link `skill/` into your Agent Skills directory.
4. Run the repository validator:

```powershell
pwsh -NoProfile -File ./tools/validate.ps1
```

5. Confirm the public installer can discover the skill:

```bash
npx --yes skills add . --list
```

## Pull requests

- Keep `skill/SKILL.md` concise and route detailed material to `skill/references/`.
- Preserve the `playwright-cli-human` name and the two-mode behavior.
- Avoid absolute local paths, personal test queries, credentials, cookies, or browser profiles.
- Update README and references when changing commands or behavior.
- For script changes, run the validator and an `https://example.com` lifecycle smoke test.
- Describe any user-visible or security-relevant behavior change in the pull request.

## Manual browser checks

Use public pages you are authorized to access. Never automate challenge widgets. If a page requests verification or login, complete it manually in the dedicated Chrome window, then use a fresh read cycle.

## License and attribution

Contributions are accepted under the Apache License 2.0. Preserve the upstream attribution and modified-file notices described in `NOTICE`. Files adapted from `@playwright/cli` must continue to state that they were modified.
