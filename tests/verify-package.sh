#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZIP_PATH="$PROJECT_DIR/dist/FinderCreateFile-1.0.0.zip"

VERSION=1.0.0 "$PROJECT_DIR/scripts/package.sh"
first_hash="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
VERSION=1.0.0 "$PROJECT_DIR/scripts/package.sh"
second_hash="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
[[ "$first_hash" == "$second_hash" ]]

/usr/bin/unzip -tq "$ZIP_PATH"
entries="$(/usr/bin/unzip -Z1 "$ZIP_PATH")"
if /usr/bin/grep -q '__MACOSX\|\.DS_Store' <<< "$entries"; then
    echo "Package contains macOS sidecar metadata" >&2
    exit 1
fi
for required in README.md README.zh-CN.md SECURITY.md LICENSE install.command uninstall.command; do
    /usr/bin/grep -qx "FinderCreateFile-1.0.0/$required" <<< "$entries"
done
/usr/bin/grep -qx 'FinderCreateFile-1.0.0/docs/APP-GROUP-PROBE.md' <<< "$entries"
/usr/bin/grep -qx 'FinderCreateFile-1.0.0/docs/probes/AppGroupProbe/Probe.swift' <<< "$entries"
/usr/bin/grep -qx 'FinderCreateFile-1.0.0/docs/probes/AppGroupProbe/entitlements.plist' <<< "$entries"

extract_directory="$PROJECT_DIR/.build/package-check"
rm -rf "$extract_directory"
mkdir -p "$extract_directory"
/usr/bin/ditto -x -k "$ZIP_PATH" "$extract_directory"
/usr/bin/codesign --verify --deep --strict "$extract_directory/FinderCreateFile-1.0.0/FinderCreateFile.app"
echo "Deterministic package verification passed: $first_hash"
