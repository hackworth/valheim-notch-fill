#!/bin/sh
# Builds dist/Valheim-Full-Screen.zip: the launcher app with BepInEx and the
# Notch Fill plugin inside. Needs the .NET SDK and a Steam install of Valheim
# (the plugin compiles against the game's Unity assemblies).
set -eu
cd "$(dirname "$0")"

VERSION=1.0.0
BEPINEX_VERSION=5.4.23.6
BEPINEX_SHA256=2e711e21f6570da964fce4654b1976500dbe043f61778bce0008500078564638

BUILD=build
APP="$BUILD/Valheim Full Screen.app"
mkdir -p "$BUILD" dist

zip="$BUILD/BepInEx_macos_universal_$BEPINEX_VERSION.zip"
if [ ! -f "$zip" ]; then
    curl -fsSL -o "$zip" "https://github.com/BepInEx/BepInEx/releases/download/v$BEPINEX_VERSION/BepInEx_macos_universal_$BEPINEX_VERSION.zip"
fi
echo "$BEPINEX_SHA256  $zip" | shasum -a 256 -c -
rm -rf "$BUILD/bepinex" && mkdir "$BUILD/bepinex" && unzip -q "$zip" -d "$BUILD/bepinex"

dotnet build plugin -c Release -p:BepInExCore="$PWD/$BUILD/bepinex/BepInEx/core" -o "$BUILD/plugin"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/BepInEx-payload" "$APP/Contents/Resources/licenses"
sed "s/@VERSION@/$VERSION/g" app/Info.plist > "$APP/Contents/Info.plist"
cp app/launch.sh "$APP/Contents/MacOS/launch" && chmod +x "$APP/Contents/MacOS/launch"
cp app/AppIcon.icns "$APP/Contents/Resources/"
cp "$BUILD/plugin/NotchFill.dll" "$APP/Contents/Resources/"
cp -R "$BUILD/bepinex/BepInEx" "$BUILD/bepinex/libdoorstop.dylib" "$BUILD/bepinex/.doorstop_version" \
    "$APP/Contents/Resources/BepInEx-payload/"
cp LICENSE "$APP/Contents/Resources/licenses/NotchFill-LICENSE.txt"
curl -fsSL -o "$APP/Contents/Resources/licenses/BepInEx-LICENSE.txt" \
    "https://raw.githubusercontent.com/BepInEx/BepInEx/v$BEPINEX_VERSION/LICENSE"
curl -fsSL -o "$APP/Contents/Resources/licenses/UnityDoorstop-LICENSE.txt" \
    "https://raw.githubusercontent.com/NeighTools/UnityDoorstop/master/LICENSE"

out="dist/Valheim-Full-Screen.zip"
rm -f "$out"
ditto -c -k --keepParent "$APP" "$out"
echo "Built $out"
