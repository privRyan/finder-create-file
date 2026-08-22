#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="FinderCreateFile"
APP="$DIST_DIR/$APP_NAME.app"
APPEX="$APP/Contents/PlugIns/FinderCreateFileFinderSync.appex"
VERSION="${VERSION:-1.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"
BUNDLE_ID_PREFIX="${BUNDLE_ID_PREFIX:-io.github.privRyan}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS="${ARCHS:-arm64 x86_64}"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}([-+][A-Za-z0-9.-]+)?$ ]] || [[ "$VERSION" == *".."* ]]; then
    echo "Invalid VERSION: $VERSION" >&2
    exit 64
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid BUILD_NUMBER: $BUILD_NUMBER" >&2
    exit 64
fi

rm -rf "$BUILD_DIR" "$APP"
mkdir -p \
    "$BUILD_DIR/icon.iconset" \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Helpers" \
    "$APP/Contents/Resources/Templates" \
    "$APPEX/Contents/MacOS"

cp "$PROJECT_DIR/Config/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_DIR/Config/ExtensionInfo.plist" "$APPEX/Contents/Info.plist"

/usr/bin/plutil -replace CFBundleIdentifier -string "$BUNDLE_ID_PREFIX.FinderCreateFile" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleIdentifier -string "$BUNDLE_ID_PREFIX.FinderCreateFile.FinderSync" "$APPEX/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$VERSION" "$APPEX/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APPEX/Contents/Info.plist"

app_binaries=()
extension_binaries=()
move_binaries=()
for arch in $ARCHS; do
    target="$arch-apple-macos13.0"
    /usr/bin/clang -target "$target" -mmacosx-version-min=13.0 -c \
        "$PROJECT_DIR/Sources/Shared/ExclusiveCreate.c" \
        -o "$BUILD_DIR/ExclusiveCreate-$arch.o"
    /usr/bin/swiftc -O -whole-module-optimization -target "$target" \
        -framework AppKit \
        "$PROJECT_DIR/Sources/Shared/FileCreation.swift" \
        "$PROJECT_DIR/Sources/Shared/FileTypeCatalog.swift" \
        "$PROJECT_DIR/Sources/App/AppMain.swift" \
        "$BUILD_DIR/ExclusiveCreate-$arch.o" \
        -o "$BUILD_DIR/FinderCreateFile-$arch"
    app_binaries+=("$BUILD_DIR/FinderCreateFile-$arch")
    /usr/bin/clang -target "$target" -mmacosx-version-min=13.0 \
        "$PROJECT_DIR/Sources/Shared/ExclusiveRename.c" \
        -o "$BUILD_DIR/AtomicInstallMove-$arch"
    move_binaries+=("$BUILD_DIR/AtomicInstallMove-$arch")
    /usr/bin/swiftc -O -whole-module-optimization -parse-as-library -target "$target" \
        -module-name FinderCreateFileFinderSync \
        -framework AppKit -framework FinderSync \
        "$PROJECT_DIR/Sources/Shared/FileTypeCatalog.swift" \
        "$PROJECT_DIR/Sources/Shared/ContainingAppLocator.swift" \
        "$PROJECT_DIR/Sources/FinderSync/FileTypeSettingsWindowController.swift" \
        "$PROJECT_DIR/Sources/FinderSync/FinderSyncExtension.swift" \
        -Xlinker -e -Xlinker _NSExtensionMain \
        -o "$BUILD_DIR/FinderCreateFileFinderSync-$arch"
    extension_binaries+=("$BUILD_DIR/FinderCreateFileFinderSync-$arch")
done
/usr/bin/lipo -create "${app_binaries[@]}" -output "$APP/Contents/MacOS/FinderCreateFile"
/usr/bin/lipo -create "${extension_binaries[@]}" -output "$APPEX/Contents/MacOS/FinderCreateFileFinderSync"
/usr/bin/lipo -create "${move_binaries[@]}" -output "$APP/Contents/Helpers/AtomicInstallMove"

/usr/bin/swiftc -O -target "$(uname -m)-apple-macos13.0" -framework AppKit \
    "$PROJECT_DIR/Tools/RenderAppIcon.swift" \
    -o "$BUILD_DIR/render-app-icon"

while read -r filename pixels; do
    "$BUILD_DIR/render-app-icon" "$BUILD_DIR/icon.iconset/$filename" "$pixels"
done <<'SIZES'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
SIZES
/usr/bin/iconutil -c icns "$BUILD_DIR/icon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

for type in docx xlsx pptx; do
    template_source="$PROJECT_DIR/Resources/OfficeTemplates/$type"
    template_stage="$BUILD_DIR/template-$type"
    template_output="$APP/Contents/Resources/Templates/blank.$type"
    mkdir -p "$template_stage"
    /usr/bin/ditto --noextattr --norsrc "$template_source" "$template_stage"
    /usr/bin/find "$template_stage" -exec /usr/bin/touch -t 202001010000 {} +
    (
        cd "$template_stage"
        if [[ "$type" == "docx" ]]; then
            /usr/bin/zip -X -q "$template_output" '[Content_Types].xml' '_rels/.rels' 'word/document.xml'
        elif [[ "$type" == "xlsx" ]]; then
            /usr/bin/zip -X -q "$template_output" '[Content_Types].xml' '_rels/.rels' 'xl/workbook.xml' 'xl/_rels/workbook.xml.rels' 'xl/worksheets/sheet1.xml'
        else
            /usr/bin/find . -type f -print | LC_ALL=C /usr/bin/sort | /usr/bin/zip -X -q "$template_output" -@
        fi
    )
done

sign_args=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    sign_args+=(--timestamp --options runtime)
fi
/usr/bin/codesign "${sign_args[@]}" "$APP/Contents/Helpers/AtomicInstallMove"
/usr/bin/codesign "${sign_args[@]}" --entitlements "$PROJECT_DIR/Config/Extension.entitlements" "$APPEX"
/usr/bin/codesign "${sign_args[@]}" "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built: $APP"
