# Valheim Full Screen

On a MacBook with a notch, Valheim's fullscreen leaves a black bar across the top of the screen. This makes the game use the **whole** display, including the area on either side of the notch.

## Install

1. Download [**Valheim-Full-Screen.zip**](https://github.com/hackworth/valheim-notch-fill/releases/latest/download/Valheim-Full-Screen.zip) and open it.
2. Drag **Valheim Full Screen** into your **Applications** folder.
3. Open it. macOS will refuse the first time because the app isn't signed by Apple. To allow it:
   1. Click **Done** in the warning.
   2. Open **System Settings → Privacy & Security**, scroll to the bottom, and click **Open Anyway** next to "Valheim Full Screen".
   3. Click **Open Anyway** again and enter your password.

That's it. Valheim starts and fills the screen.

**From now on, start Valheim with this app** instead of the Play button in Steam. Steam still needs to be installed, and the app opens it for you if it isn't running.

> Prefer Terminal? This does the same as step 3:
> ```
> xattr -dr com.apple.quarantine "/Applications/Valheim Full Screen.app"
> ```

## Good to know

- Needs an Apple Silicon Mac and the Steam version of Valheim.
- While Valheim is in front, the menu bar and Dock are hidden. They come back when you switch apps.
- Valheim's own Fullscreen setting is ignored, since macOS fullscreen is what causes the black bar.
- Playing from Steam's Play button still works and gives you the normal game without the mod.
- Want it in your Steam library? In Steam choose **Games → Add a Non-Steam Game to My Library** and pick **Valheim Full Screen**.
- It changes nothing about gameplay and only runs on your Mac, so you can join any server.

## Uninstall

1. Delete **Valheim Full Screen** from Applications.
2. In Steam, right-click Valheim → **Manage → Browse local files**, then delete `BepInEx/plugins/NotchFill.dll`.
   If you don't use any other Valheim mods, you can delete the `BepInEx` folder, `libdoorstop.dylib` and `.doorstop_version` instead.

## How it works

The first time you open the app, it copies [BepInEx](https://github.com/BepInEx/BepInEx), a common Unity mod loader, into your Valheim folder along with a small plugin. If you already have BepInEx, it only adds the plugin. Then it starts the game with BepInEx loaded. Steam on macOS can't do that from launch options, which is why this is an app.

Inside the game, the plugin replaces macOS fullscreen, which always sits below the notch, with a borderless window the exact size of the display, and hides the menu bar and Dock. Source: [`plugin/NotchFill.cs`](plugin/NotchFill.cs).

## Building

Requires the [.NET SDK](https://dotnet.microsoft.com/download) and Valheim installed through Steam:

```
./build.sh
```

The zip lands in `dist/`.

## License

MIT. The app bundles [BepInEx](https://github.com/BepInEx/BepInEx) (MIT) and [UnityDoorstop](https://github.com/NeighTools/UnityDoorstop) (LGPL-2.1), unmodified; their licenses are inside the app under `Contents/Resources/licenses`.

Not affiliated with Iron Gate or Coffee Stain.
