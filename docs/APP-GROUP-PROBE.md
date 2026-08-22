# Ad-hoc App Group probe

The Finder extension is sandboxed, while the containing app performs file creation. This experiment originally tested whether both processes should share settings through an App Group.

On macOS 26.6.2 with Apple Swift 6.3.3, a minimal sandboxed helper was compiled, ad-hoc signed with these entitlements, and executed without installing a Finder extension:

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.application-groups</key>
<array><string>io.github.privRyan.FinderCreateFile.shared</string></array>
```

Observed evidence:

- `codesign -dv --verbose=4` reported `Signature=adhoc` and `TeamIdentifier=not set`.
- The process terminated before reaching `main` with exit status 133 (`SIGTRAP`).
- The system crash report recorded sandbox initialization in `libsystem_secinit` and: `Failed to create a code identity ... OSStatus 100001`.

The exact probe source and entitlement file are stored in [`probes/AppGroupProbe/`](probes/AppGroupProbe/). Build and execute it with:

```sh
swiftc -target "$(uname -m)-apple-macos13.0" docs/probes/AppGroupProbe/Probe.swift -o /tmp/finder-create-file-app-group-probe
codesign --force --sign - --entitlements docs/probes/AppGroupProbe/entitlements.plist /tmp/finder-create-file-app-group-probe
/tmp/finder-create-file-app-group-probe
```

The last command is expected to terminate during sandbox initialization on an ad-hoc build. It does not install or register an extension, but it does attempt to write the value `probe` to the named App Group defaults if the process reaches `main`.


Conclusion: App Group sharing is not reliable under this project's source-build/ad-hoc-signing model. The final architecture removes the need for cross-process settings:

1. Finder always displays the five default entries (TXT, Markdown, Word, Excel, and PowerPoint) directly and consecutively.
2. **管理文件类型…** opens a checkbox panel owned by the Finder extension.
3. The extension stores only versioned, fixed catalog IDs in `UserDefaults.standard` inside its own sandbox and renders enabled entries directly after the five defaults, without a separator.
4. Selecting an extra entry sends its fixed ID to the containing app; the app resolves that ID against the same compiled catalog before showing a filename dialog.

No arbitrary extension or template path is accepted from the URL request. A real Finder smoke test on the environment documented above confirmed that the extension-owned panel persisted JSON/XML IDs and that Finder rendered those entries in stable catalog order after reopening the menu. A future signed release does not need an App Group unless responsibilities change; any such change must add a real provisioned-extension integration test first.
