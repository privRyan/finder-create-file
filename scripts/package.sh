#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.1}"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}([-+][A-Za-z0-9.-]+)?$ ]] || [[ "$VERSION" == *".."* ]]; then
    echo "Invalid VERSION: $VERSION" >&2
    exit 64
fi
PACKAGE_NAME="FinderCreateFile-$VERSION"
PACKAGE_ROOT="$PROJECT_DIR/.build/package-root"
PACKAGE_DIR="$PACKAGE_ROOT/$PACKAGE_NAME"
ZIP_PATH="$PROJECT_DIR/dist/$PACKAGE_NAME.zip"

"$PROJECT_DIR/scripts/build.sh"
rm -rf "$PACKAGE_ROOT" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"
/usr/bin/ditto --noextattr --norsrc "$PROJECT_DIR/dist/FinderCreateFile.app" "$PACKAGE_DIR/FinderCreateFile.app"
/usr/bin/ditto --noextattr --norsrc "$PROJECT_DIR/docs" "$PACKAGE_DIR/docs"
cp "$PROJECT_DIR/scripts/install.sh" "$PACKAGE_DIR/install.command"
cp "$PROJECT_DIR/scripts/uninstall.sh" "$PACKAGE_DIR/uninstall.command"
cp "$PROJECT_DIR/README.md" "$PROJECT_DIR/README.zh-CN.md" "$PROJECT_DIR/CHANGELOG.md" "$PROJECT_DIR/SECURITY.md" "$PROJECT_DIR/LICENSE" "$PACKAGE_DIR/"
chmod +x "$PACKAGE_DIR/install.command" "$PACKAGE_DIR/uninstall.command"
/usr/bin/find "$PACKAGE_DIR" -exec /usr/bin/touch -t 202001010000 {} +
(
    cd "$PACKAGE_ROOT"
    /usr/bin/find "$PACKAGE_NAME" -type f -print | LC_ALL=C /usr/bin/sort | /usr/bin/zip -X -q "$ZIP_PATH" -@
)

echo "Packaged: $ZIP_PATH"
