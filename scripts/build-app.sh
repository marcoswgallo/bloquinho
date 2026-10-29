#!/bin/sh
# Compila o Bloquinho (chip Apple + Intel) e monta o Bloquinho.app em ./build.
# Uso: scripts/build-app.sh [--install | --dmg]
#   --install  copia o app para /Applications
#   --dmg      gera build/Bloquinho.dmg para distribuir
set -e
cd "$(dirname "$0")/.."

ARCHS="--arch arm64 --arch x86_64"
swift build -c release $ARCHS
APP=build/Bloquinho.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release $ARCHS --show-bin-path)/Bloquinho" "$APP/Contents/MacOS/Bloquinho"

# Ícone. Com o Xcode instalado: Resources/Bloquinho.icon (versões clara, escura, tingida e transparente)
# vira Assets.car, mais um .icns para macOS 14 e 15. Sem o Xcode: só o ícone claro desenhado por
# scripts/make-icon.swift (PNG 1024 → iconset → .icns).
ICON_NAME=""
XCODE_DEV=/Applications/Xcode.app/Contents/Developer
if DEVELOPER_DIR=$XCODE_DEV xcrun --find actool >/dev/null 2>&1; then
    DEVELOPER_DIR=$XCODE_DEV xcrun actool Resources/Bloquinho.icon --compile "$APP/Contents/Resources" \
        --platform macosx --minimum-deployment-target 14.0 --app-icon Bloquinho \
        --output-partial-info-plist /dev/null --errors >/dev/null
    ICON_NAME="<key>CFBundleIconName</key><string>Bloquinho</string>"
else
    TMP=$(mktemp -d)
    swift scripts/make-icon.swift "$TMP/icon.png"
    mkdir "$TMP/Bloquinho.iconset"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$TMP/icon.png" --out "$TMP/Bloquinho.iconset/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/Bloquinho.iconset/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$TMP/Bloquinho.iconset" -o "$APP/Contents/Resources/Bloquinho.icns"
    rm -rf "$TMP"
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Bloquinho</string>
    <key>CFBundleDisplayName</key><string>Bloquinho</string>
    <key>CFBundleIdentifier</key><string>com.bloquinho.app</string>
    <key>CFBundleExecutable</key><string>Bloquinho</string>
    <key>CFBundleIconFile</key><string>Bloquinho</string>
    $ICON_NAME
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.3</string>
    <key>CFBundleVersion</key><string>4</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Licença MIT</string>
</dict>
</plist>
EOF

# Assinatura local (ad-hoc), necessária para rodar em Macs Apple Silicon.
codesign --force --sign - "$APP"
echo "Pronto: $APP"

if [ "$1" = "--install" ]; then
    rm -rf /Applications/Bloquinho.app
    cp -R "$APP" /Applications/
    echo "Instalado em /Applications/Bloquinho.app"
fi

if [ "$1" = "--dmg" ]; then
    # Imagem com o app e um atalho para Aplicativos (é só arrastar um para o outro).
    STAGE=$(mktemp -d)
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Aplicativos"
    rm -f build/Bloquinho.dmg
    hdiutil create -volname Bloquinho -srcfolder "$STAGE" -format UDZO -o build/Bloquinho.dmg >/dev/null
    rm -rf "$STAGE"
    echo "Pronto: build/Bloquinho.dmg"
fi
