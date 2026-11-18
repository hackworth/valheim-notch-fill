#!/bin/sh
# Valheim Full Screen: installs the Notch Fill mod (BepInEx + plugin) into the
# Steam copy of Valheim, then starts the game with BepInEx loaded.
#
# Steam on macOS can't run BepInEx's run_bepinex.sh from launch options
# (AppError_46, "OS Error 0"), so the game is started through LaunchServices
# with Doorstop's environment instead.
set -u

RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
STEAM="$HOME/Library/Application Support/Steam"

fail() {
    osascript -e 'on run argv' \
        -e 'display alert "Valheim Full Screen" message (item 1 of argv) as critical' \
        -e 'end run' "$1" >/dev/null 2>&1
    exit 1
}

# The default Steam library first, then any extra libraries Steam knows about.
find_game() {
    {
        echo "$STEAM"
        sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
            "$STEAM/steamapps/libraryfolders.vdf" 2>/dev/null
    } | while IFS= read -r lib; do
        if [ -d "$lib/steamapps/common/Valheim/Valheim.app" ]; then
            echo "$lib/steamapps/common/Valheim"
            break
        fi
    done
}

V="$(find_game)"
[ -n "$V" ] || fail "Couldn't find Valheim. Install it with Steam, then open this app again."

if pgrep -x Valheim >/dev/null; then
    open -a "$V/Valheim.app"
    exit 0
fi

# Leave an existing BepInEx alone (it may be newer, or carry other mods); only add ours.
if [ ! -f "$V/BepInEx/core/BepInEx.Preloader.dll" ] || [ ! -f "$V/libdoorstop.dylib" ]; then
    ditto --noqtn "$RES/BepInEx-payload" "$V" || fail "Couldn't install BepInEx into $V."
fi
mkdir -p "$V/BepInEx/plugins"
ditto --noqtn "$RES/NotchFill.dll" "$V/BepInEx/plugins/NotchFill.dll" || fail "Couldn't install the Notch Fill plugin into $V."

# A downloaded copy carries the quarantine flag, and Gatekeeper would refuse
# to let the game load an unsigned, quarantined libdoorstop.dylib.
xattr -dr com.apple.quarantine "$V/libdoorstop.dylib" "$V/.doorstop_version" "$V/BepInEx" 2>/dev/null

# Without this the game asks Steam to relaunch it, which drops the mod.
[ -f "$V/steam_appid.txt" ] || echo 892970 > "$V/steam_appid.txt"

if ! pgrep -x steam_osx >/dev/null; then
    open -g -b com.valvesoftware.steam || fail "Steam isn't installed. Install Steam and Valheim, then open this app again."
    i=0
    while ! pgrep -x steam_osx >/dev/null && [ $i -lt 60 ]; do sleep 1; i=$((i + 1)); done
    sleep 15 # give Steam time to sign in before the game looks for it
fi

exec open -n -a "$V/Valheim.app" \
    --env DOORSTOP_ENABLED=1 \
    --env "DOORSTOP_TARGET_ASSEMBLY=$V/BepInEx/core/BepInEx.Preloader.dll" \
    --env DOORSTOP_IGNORE_DISABLED_ENV=0 \
    --env DOORSTOP_MONO_DEBUG_ENABLED=0 \
    --env "DYLD_INSERT_LIBRARIES=$V/libdoorstop.dylib"
