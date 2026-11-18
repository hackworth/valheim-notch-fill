using System;
using System.Runtime.InteropServices;
using BepInEx;
using BepInEx.Configuration;
using UnityEngine;

namespace NotchFill
{
    // Unity's macOS FullScreenWindow uses a native fullscreen Space, which macOS
    // always places below the camera housing. This swaps it for a borderless window
    // covering the whole panel, with the menu bar and Dock hidden while Valheim is
    // frontmost, so the game renders into the area beside the notch.
    [BepInPlugin("com.hackworth.notchfill", "Notch Fill", "1.0.0")]
    public class Plugin : BaseUnityPlugin
    {
        const string ObjC = "/usr/lib/libobjc.A.dylib";

        const ulong PresentationHideDock = 1 << 1;
        const ulong PresentationHideMenuBar = 1 << 3;

        [StructLayout(LayoutKind.Sequential)]
        struct CGRect
        {
            public double X, Y, W, H;
            public bool Same(CGRect o) =>
                Math.Abs(X - o.X) < 0.5 && Math.Abs(Y - o.Y) < 0.5 &&
                Math.Abs(W - o.W) < 0.5 && Math.Abs(H - o.H) < 0.5;
            public override string ToString() => $"({X},{Y} {W}x{H})";
        }

        [DllImport(ObjC)] static extern IntPtr objc_getClass(string name);
        [DllImport(ObjC)] static extern IntPtr sel_registerName(string name);
        [DllImport(ObjC)] static extern IntPtr object_getClass(IntPtr obj);
        [DllImport(ObjC)] static extern IntPtr class_getName(IntPtr cls);
        [DllImport(ObjC)] static extern IntPtr class_replaceMethod(IntPtr cls, IntPtr sel, IntPtr imp, string types);

        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern IntPtr Send(IntPtr recv, IntPtr sel);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern IntPtr Send(IntPtr recv, IntPtr sel, ulong arg);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern ulong SendULong(IntPtr recv, IntPtr sel);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern double SendDouble(IntPtr recv, IntPtr sel);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern CGRect SendRect(IntPtr recv, IntPtr sel);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")]
        [return: MarshalAs(UnmanagedType.I1)] static extern bool SendBool(IntPtr recv, IntPtr sel);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern void SendVoid(IntPtr recv, IntPtr sel, ulong arg);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern void SendVoid(IntPtr recv, IntPtr sel, long arg);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")] static extern void SendVoid(IntPtr recv, IntPtr sel, IntPtr arg);
        [DllImport(ObjC, EntryPoint = "objc_msgSend")]
        static extern void SendVoid(IntPtr recv, IntPtr sel, CGRect rect, [MarshalAs(UnmanagedType.I1)] bool display);

        [DllImport("/usr/lib/libSystem.B.dylib")] static extern int pthread_main_np();

        // Borderless NSWindows refuse key status by default, which would cut off
        // keyboard input; this IMP makes canBecomeKeyWindow/canBecomeMainWindow say YES.
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        delegate byte BoolImp(IntPtr self, IntPtr cmd);
        static readonly BoolImp ReturnYes = (self, cmd) => 1;
        static IntPtr patchedClass;

        static IntPtr Sel(string name) => sel_registerName(name);

        ConfigEntry<bool> fillEnabled;
        float nextCheck;
        int applies;
        float windowStart;

        void Awake()
        {
            fillEnabled = Config.Bind("General", "Enabled", true,
                "Fill the whole built-in display, including the area beside the camera housing.");

            if (RuntimeInformation.ProcessArchitecture != Architecture.Arm64)
            {
                // CGRect returns need objc_msgSend_stret on x86_64 (Rosetta); not handled.
                Logger.LogWarning($"Running as {RuntimeInformation.ProcessArchitecture}, not arm64; Notch Fill disabled.");
                fillEnabled.Value = false;
            }
            else if (pthread_main_np() != 1)
            {
                Logger.LogWarning("Unity scripts are not on the AppKit main thread; Notch Fill disabled.");
                fillEnabled.Value = false;
            }
        }

        void Update()
        {
            if (!fillEnabled.Value || Time.unscaledTime < nextCheck) return;
            nextCheck = Time.unscaledTime + 1f;

            if (Screen.fullScreenMode != FullScreenMode.Windowed)
            {
                Logger.LogInfo($"Switching from {Screen.fullScreenMode} to Windowed.");
                Screen.fullScreenMode = FullScreenMode.Windowed;
                nextCheck = Time.unscaledTime + 2f; // let the fullscreen exit animation finish
                return;
            }

            try { Apply(); }
            catch (Exception e)
            {
                Logger.LogError($"Notch Fill failed, disabling: {e}");
                fillEnabled.Value = false;
            }
        }

        void Apply()
        {
            IntPtr app = Send(objc_getClass("NSApplication"), Sel("sharedApplication"));
            if (!SendBool(app, Sel("isActive"))) return;

            IntPtr win = Send(app, Sel("mainWindow"));
            if (win == IntPtr.Zero) win = Send(app, Sel("keyWindow"));
            if (win == IntPtr.Zero) return;

            IntPtr screen = Send(win, Sel("screen"));
            if (screen == IntPtr.Zero) return;

            SendVoid(app, Sel("setPresentationOptions:"), PresentationHideDock | PresentationHideMenuBar);

            CGRect screenFrame = SendRect(screen, Sel("frame"));
            CGRect winFrame = SendRect(win, Sel("frame"));
            ulong mask = SendULong(win, Sel("styleMask"));

            if (mask != 0 || !winFrame.Same(screenFrame))
            {
                // Guard against fighting Unity forever if it keeps restoring its window.
                if (applies == 0 || Time.unscaledTime - windowStart > 30f) { windowStart = Time.unscaledTime; applies = 0; }
                if (++applies > 5)
                {
                    Logger.LogError("Window keeps reverting; disabling Notch Fill.");
                    fillEnabled.Value = false;
                    return;
                }

                MakeKeyable(win);
                SendVoid(win, Sel("setStyleMask:"), 0UL);
                SendVoid(win, Sel("setFrame:display:"), screenFrame, true);
                SendVoid(win, Sel("makeKeyAndOrderFront:"), IntPtr.Zero);
                Logger.LogInfo($"Window {winFrame} mask {mask} -> {screenFrame} borderless.");
            }

            double scale = SendDouble(screen, Sel("backingScaleFactor"));
            int w = (int)Math.Round(screenFrame.W * scale);
            int h = (int)Math.Round(screenFrame.H * scale);
            if (Screen.width != w || Screen.height != h)
            {
                Logger.LogInfo($"Render size {Screen.width}x{Screen.height} -> {w}x{h}.");
                Screen.SetResolution(w, h, FullScreenMode.Windowed);
            }
        }

        static void MakeKeyable(IntPtr win)
        {
            IntPtr cls = object_getClass(win);
            if (cls == patchedClass) return;
            IntPtr imp = Marshal.GetFunctionPointerForDelegate(ReturnYes);
            class_replaceMethod(cls, Sel("canBecomeKeyWindow"), imp, "B@:");
            class_replaceMethod(cls, Sel("canBecomeMainWindow"), imp, "B@:");
            patchedClass = cls;
            BepInEx.Logging.Logger.CreateLogSource("Notch Fill")
                .LogInfo($"Patched {Marshal.PtrToStringAnsi(class_getName(cls))} to accept key status.");
        }
    }
}
