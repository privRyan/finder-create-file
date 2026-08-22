# Security Policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for [privRyan/finder-create-file](https://github.com/privRyan/finder-create-file/security/advisories/new). Do not include sensitive local paths or personal files in a public issue.

## Security boundaries

- The app has no network code, update service, telemetry, or privileged helper.
- Requests are accepted only through the `findercreatefile://` URL scheme. The direct-create operation accepts only the five fixed default types. The additional-type operation accepts a fixed catalog ID; both the URL parser and the app resolve it against the same compiled allowlist before use.
- Users cannot enter extensions or import templates. Settings contain only versioned allowlisted IDs; unknown and duplicate values are filtered and catalog order is enforced.
- Target paths are standardized, symlinks are resolved, the target must already be a directory, and it must be within the current user's home directory or `/Volumes`.
- The confirmation dialog displays the resolved target directory.
- All output files use `O_CREAT | O_EXCL`; an existing file is never overwritten. Name conflicts, including races, are retried with a numbered filename.
- If a low-level write fails after exclusive creation (for example, the disk becomes full), a partial newly created file may remain; the app reports the failure and never removes a path that another process could have replaced.
- The Finder extension is sandboxed. The containing app is not sandboxed because it must create files selected through Finder.
- The sandboxed extension cannot read its parent app bundle for runtime identity checks. It derives the containing app only from its own already-loaded bundle URL and accepts exactly the compile-time-fixed `FinderCreateFile.app/Contents/PlugIns/FinderCreateFileFinderSync.appex` hierarchy. Non-standardized or symlinked paths are rejected before `NSWorkspace` is asked to open the exact derived app URL. This protects against accidental or ambiguous LaunchServices selection; it is not a substitute for Developer ID signing and notarization against a deliberately repackaged local bundle.
- A local ad-hoc App Group probe terminated during sandbox initialization (`SIGTRAP`, no Team ID/code identity). The project therefore does not use App Groups: the Finder extension owns selection state in its standard sandboxed preferences and passes only a validated fixed ID to the containing app.
- macOS custom URL schemes do not authenticate callers. The Finder extension explicitly targets its own containing app, avoiding ambiguity from other registered copies, but another local app can still request one of these dialogs. Every creation requires visible user confirmation, and the app independently validates the operation, type allowlist, and destination before writing.

## Release and uninstall policy

The downloadable universal app is ad-hoc signed and is not Developer ID signed or Apple-notarized. Its installer neither disables Gatekeeper nor removes quarantine metadata; macOS may require an explicit first-open approval. A future polished binary distribution would require a controlled Developer ID build, hardened runtime, notarization, stapling, and published checksums.

Normal uninstall disables the official extension ID, unregisters available bundle paths, terminates the app and extension processes, refreshes Finder, and moves the verified app to Trash while preserving settings. `--purge` also attempts to move the official settings container to Trash and checks for remaining data. System-protected empty container metadata may remain. Unrecognized legacy data is reported and preserved for manual review; the public script never guesses that unrelated prototypes, Automator services, or user documents belong to this app.
