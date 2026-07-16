# Security Policy

## Reporting a vulnerability

Please report vulnerabilities through the repository's private GitHub Security Advisory feature. Do not open a public issue containing credentials, cookies, storage state, browser profiles, private URLs, or CDP endpoint details.

Include the affected script or workflow, the operating system and PowerShell version, reproduction steps with secrets removed, and the expected safety boundary.

## Security boundaries

The project is designed to:

- bind its CDP endpoint to loopback;
- use a dedicated browser profile;
- require both the configured profile and port before terminating Chrome;
- leave CAPTCHA and login actions to the user;
- avoid persisting authentication artifacts in the repository.

No browser automation tool can guarantee that third-party pages are safe. Review the target URL and confirm irreversible actions before continuing.
