// Read-only, out-of-process window observations. No DLL injection or hooks.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace CorelWatch {
    public class WindowSample {
        public long Handle;
        public long Owner;
        public uint ThreadId;
        public string ClassName;
        public bool Visible;
        public bool Enabled;
        public bool Minimized;
        public bool HungHint;
        public bool OffScreen;
        public int Left, Top, Right, Bottom;
    }
    public class ProbeResult {
        public long MainHandle;
        public long LastActivePopup;
        public bool IsForegroundProcess;
        public bool HasMainWindow;
        public bool MainEnabled;
        public bool MainReplied;
        public int ProbeError;
        public uint GuiFlags;
        public long ActiveWindow, FocusWindow, MenuOwner, CaptureWindow;
        public bool GuiInfoAvailable;
        public bool WindowListTruncated;
        public WindowSample[] Windows;
    }
    public static class NativeProbe {
        private delegate bool EnumProc(IntPtr hWnd, IntPtr parameter);
        [StructLayout(LayoutKind.Sequential)] private struct RECT { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)] private struct GUITHREADINFO {
            public int cbSize; public uint flags;
            public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret;
            public RECT rcCaret;
        }
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr param);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern bool IsWindowEnabled(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern bool IsHungAppWindow(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
        [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hwnd, uint command);
        [DllImport("user32.dll")] private static extern IntPtr GetLastActivePopup(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int size);
        [DllImport("user32.dll", SetLastError=true)] private static extern bool GetGUIThreadInfo(uint thread, ref GUITHREADINFO info);
        [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SendMessageTimeout(
            IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);

        public static ProbeResult Sample(uint processId, long mainHandle) {
            var result = new ProbeResult();
            var windows = new List<WindowSample>();
            EnumProc callback = delegate(IntPtr hwnd, IntPtr unused) {
                uint pid;
                uint thread = GetWindowThreadProcessId(hwnd, out pid);
                if (pid != processId) return true;
                if (windows.Count >= 64) { result.WindowListTruncated = true; return false; }
                RECT rect;
                GetWindowRect(hwnd, out rect);
                var name = new StringBuilder(256);
                GetClassName(hwnd, name, name.Capacity);
                windows.Add(new WindowSample {
                    Handle = hwnd.ToInt64(), Owner = GetWindow(hwnd, 4).ToInt64(), ThreadId = thread,
                    ClassName = name.ToString(), Visible = IsWindowVisible(hwnd), Enabled = IsWindowEnabled(hwnd),
                    Minimized = IsIconic(hwnd), HungHint = IsHungAppWindow(hwnd),
                    OffScreen = MonitorFromWindow(hwnd, 0) == IntPtr.Zero,
                    Left = rect.Left, Top = rect.Top, Right = rect.Right, Bottom = rect.Bottom
                });
                return true;
            };
            EnumWindows(callback, IntPtr.Zero);
            GC.KeepAlive(callback);
            result.Windows = windows.ToArray();
            uint foregroundPid;
            GetWindowThreadProcessId(GetForegroundWindow(), out foregroundPid);
            result.IsForegroundProcess = foregroundPid == processId;
            // Validate that a possibly stale MainWindowHandle still belongs to this process.
            IntPtr main = new IntPtr(mainHandle);
            uint ownerPid;
            uint mainThread = GetWindowThreadProcessId(main, out ownerPid);
            if (main != IntPtr.Zero && ownerPid == processId) {
                result.HasMainWindow = true;
                result.MainHandle = mainHandle;
                result.MainEnabled = IsWindowEnabled(main);
                result.LastActivePopup = GetLastActivePopup(main).ToInt64();
                UIntPtr ignored;
                // WM_NULL only. At most one bounded 150 ms probe per process/sample.
                result.MainReplied = SendMessageTimeout(main, 0, UIntPtr.Zero, IntPtr.Zero, 0x23, 150, out ignored) != IntPtr.Zero;
                if (!result.MainReplied) result.ProbeError = Marshal.GetLastWin32Error();
                GUITHREADINFO gui = new GUITHREADINFO();
                gui.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
                if (GetGUIThreadInfo(mainThread, ref gui)) {
                    result.GuiInfoAvailable = true;
                    result.GuiFlags = gui.flags;
                    result.ActiveWindow = gui.hwndActive.ToInt64();
                    result.FocusWindow = gui.hwndFocus.ToInt64();
                    result.MenuOwner = gui.hwndMenuOwner.ToInt64();
                    result.CaptureWindow = gui.hwndCapture.ToInt64();
                }
            }
            return result;
        }
    }
}
