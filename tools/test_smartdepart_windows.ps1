# Native Windows loader/export smoke test; NEVER calls geometry or Corel APIs.
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess) { throw 'Use Windows PowerShell x64.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SmartDepartLoaderSmoke {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr LoadLibrary(string name);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi, SetLastError=true)]
    static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr module);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    delegate int Attach(out IntPtr plugin);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    delegate int TypeCount(IntPtr self, out int count);
    public static void Run(string file) {
        IntPtr module = LoadLibrary(file);
        if (module == IntPtr.Zero) throw new Exception("LoadLibrary failed: " + Marshal.GetLastWin32Error());
        try {
            IntPtr address = GetProcAddress(module, "AttachPlugin");
            if (address == IntPtr.Zero) throw new Exception("AttachPlugin not exported");
            Attach attach = (Attach)Marshal.GetDelegateForFunctionPointer(address, typeof(Attach));
            IntPtr plugin;
            if (attach(out plugin) != 256 || plugin == IntPtr.Zero) throw new Exception("AttachPlugin result invalid");
            IntPtr vtable = Marshal.ReadIntPtr(plugin);
            TypeCount getCount = (TypeCount)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtable, 3 * IntPtr.Size), typeof(TypeCount));
            int count;
            if (getCount(plugin, out count) != 0 || count != 1) throw new Exception("GetTypeInfoCount failed");
            GC.KeepAlive(attach); GC.KeepAlive(getCount);
        } finally { FreeLibrary(module); }
    }
}
'@
$file = Join-Path (Split-Path $PSScriptRoot -Parent) 'deliverables\SmartDepart.cpg'
[SmartDepartLoaderSmoke]::Run($file)
Write-Host 'PASS: Windows x64 LoadLibrary, AttachPlugin, GetTypeInfoCount and FreeLibrary. NOT a CorelDRAW/geometry test.'
