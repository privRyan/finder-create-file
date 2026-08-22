#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.1.0}"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}([-+][A-Za-z0-9.-]+)?$ ]] || [[ "$VERSION" == *".."* ]]; then
    echo "Invalid VERSION: $VERSION" >&2
    exit 64
fi
PACKAGE_NAME="FinderCreateFile-v$VERSION-macos-universal"
PACKAGE_ROOT="$PROJECT_DIR/.build/package-root"
PACKAGE_DIR="$PACKAGE_ROOT/$PACKAGE_NAME"
ZIP_PATH="$PROJECT_DIR/dist/$PACKAGE_NAME.zip"
CHECKSUM_PATH="$PROJECT_DIR/dist/$PACKAGE_NAME.sha256"

"$PROJECT_DIR/scripts/build.sh"
rm -rf "$PACKAGE_ROOT" "$ZIP_PATH" "$CHECKSUM_PATH"
mkdir -p "$PACKAGE_DIR"
/usr/bin/ditto --noextattr --norsrc "$PROJECT_DIR/dist/FinderCreateFile.app" "$PACKAGE_DIR/FinderCreateFile.app"
cp "$PROJECT_DIR/scripts/install.sh" "$PACKAGE_DIR/安装 FinderCreateFile.command"
cp "$PROJECT_DIR/scripts/uninstall.sh" "$PACKAGE_DIR/卸载 FinderCreateFile.command"
cp "$PROJECT_DIR/Packaging/Quick Start.md" "$PACKAGE_DIR/Quick Start.md"
cp "$PROJECT_DIR/Packaging/快速使用说明.md" "$PACKAGE_DIR/快速使用说明.md"
cp "$PROJECT_DIR/CHANGELOG.md" "$PROJECT_DIR/SECURITY.md" "$PROJECT_DIR/LICENSE" "$PACKAGE_DIR/"
chmod +x "$PACKAGE_DIR/安装 FinderCreateFile.command" "$PACKAGE_DIR/卸载 FinderCreateFile.command"
/usr/bin/find "$PACKAGE_DIR" -exec /usr/bin/touch -t 202001010000 {} +
(
    cd "$PACKAGE_ROOT"
    /usr/bin/find "$PACKAGE_NAME" -type f -print | LC_ALL=C /usr/bin/sort | /usr/bin/zip -X -q "$ZIP_PATH" -@
)

zip_hash="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
/usr/bin/printf '%s  %s.zip\n' "$zip_hash" "$PACKAGE_NAME" > "$CHECKSUM_PATH"
/usr/bin/touch -t 202001010000 "$CHECKSUM_PATH"

echo "Packaged: $ZIP_PATH"
echo "Checksum: $CHECKSUM_PATH"
