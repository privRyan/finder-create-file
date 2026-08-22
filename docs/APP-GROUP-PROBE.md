# Ad-hoc App Group probe

The Finder extension is sandboxed, while the containing app performs file creation. Directly expanding enabled catalog entries in the Finder menu would require the two processes to share settings.

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


Conclusion: App Group sharing is not reliable under this project's source-build/ad-hoc-signing model. The project therefore uses an explicit containing-app fallback:

1. Finder always displays the four default entries directly.
2. **更多文件类型…** opens the app, which reads the versioned allowlist settings and displays enabled entries.
3. **管理文件类型…** opens the app's fixed-catalog checkbox UI.

No type or extension is accepted from the extra-type URL request. A future Developer ID and provisioned App Group release can revisit direct dynamic Finder entries, but must add an integration test using the real signed extension before changing this architecture.
