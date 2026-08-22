# Security Policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for [privRyan/finder-create-file](https://github.com/privRyan/finder-create-file/security/advisories/new). Do not include sensitive local paths or personal files in a public issue.

## Security boundaries

- The app has no network code, update service, telemetry, or privileged helper.
- Requests are accepted only through the `findercreatefile://` URL scheme. The direct-create operation accepts only the four fixed default types; the extra-type operation accepts no type ID from IPC and instead requires a choice from the app's compiled allowlist.
- Users cannot enter extensions or import templates. Settings contain only versioned allowlisted IDs; unknown and duplicate values are filtered and catalog order is enforced.
- Target paths are standardized, symlinks are resolved, the target must already be a directory, and it must be within the current user's home directory or `/Volumes`.
- The confirmation dialog displays the resolved target directory.
- All output files use `O_CREAT | O_EXCL`; an existing file is never overwritten. Name conflicts, including races, are retried with a numbered filename.
- If a low-level write fails after exclusive creation (for example, the disk becomes full), a partial newly created file may remain; the app reports the failure and never removes a path that another process could have replaced.
- The Finder extension is sandboxed. The containing app is not sandboxed because it must create files selected through Finder.
- A local ad-hoc App Group probe terminated during sandbox initialization (`SIGTRAP`, no Team ID/code identity), so this source-build distribution deliberately uses the containing-app selection fallback instead of claiming that the extension can read dynamic settings.
- macOS custom URL schemes do not authenticate callers and can have competing handlers. Another local app can request one of these dialogs or intercept a path sent through the scheme. Every creation still requires visible user confirmation, and the app independently validates the operation, type allowlist, and destination before writing.

## Release policy

The default ad-hoc signature is for local builds only. Public binary releases require a controlled build, Developer ID signing, hardened runtime, Apple notarization, stapling, and published checksums. Until that process exists, releases should remain source-only.
