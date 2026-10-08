// Windows 10/11 x64, .NET Framework / PowerShell 5.1. External read-only probes.
// Always run in the disposable helper process: synchronous WCT can block.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
namespace CorelWatch2 {
 public class WaitNode {
  public string Type, Status;
  public uint ProcessId, ThreadId, WaitMilliseconds, ContextSwitches;
 }
 public class WaitResult {
  public uint ThreadId;
  public bool Success, Cycle;
  public int Error;
  public WaitNode[] Nodes;
 }
 public class ChildWindow {
  public long Handle; public uint ThreadId;
  public string ClassName; public bool Visible, Enabled;
  public bool? Replied; public int Error;
 }
 public class ChildResult {
  public ChildWindow[] Windows; public bool Truncated, ProbeBudgetExhausted;
 }
 public static class CaptureProbe {
  // WAITCHAIN_NODE_INFO x64: two DWORDs, followed by 272-byte aligned union.
  // Lock names are deliberately not copied into the report.
  [StructLayout(LayoutKind.Explicit, Size=280)] private struct NativeNode {
   [FieldOffset(0)] public uint Type;
   [FieldOffset(4)] public uint Status;
   [FieldOffset(8)] public uint ProcessId;
   [FieldOffset(12)] public uint ThreadId;
   [FieldOffset(16)] public uint WaitTime;
   [FieldOffset(20)] public uint ContextSwitches;
  }
  [DllImport("advapi32.dll", SetLastError=true)] private static extern IntPtr OpenThreadWaitChainSession(uint flags, IntPtr callback);
  [DllImport("advapi32.dll")] private static extern void CloseThreadWaitChainSession(IntPtr session);
  [DllImport("advapi32.dll", SetLastError=true)] private static extern bool GetThreadWaitChain(IntPtr session, UIntPtr context, uint flags, uint thread, ref uint count, [In,Out] NativeNode[] nodes, out int cycle);
  private delegate bool EnumProc(IntPtr hwnd, IntPtr param);
  [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr param);
  [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] private static extern bool IsWindowEnabled(IntPtr hwnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int size);
  [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SendMessageTimeout(IntPtr hwnd,uint msg,UIntPtr wp,IntPtr lp,uint flags,uint timeout,out UIntPtr result);
  public static int NodeSize() { return Marshal.SizeOf(typeof(NativeNode)); }
  public static uint WindowThread(long hwnd) { uint pid; return GetWindowThreadProcessId(new IntPtr(hwnd),out pid); }
  public static WaitResult WaitChain(uint thread) {
   var result=new WaitResult {ThreadId=thread,Nodes=new WaitNode[0]};
   IntPtr session=OpenThreadWaitChainSession(0,IntPtr.Zero);
   if(session==IntPtr.Zero){result.Error=Marshal.GetLastWin32Error();return result;}
   try {
    var raw=new NativeNode[16];uint count=16;int cycle;
    // No WCT_OUT_OF_PROC / COM callbacks: do not invoke Corel automation.
    result.Success=GetThreadWaitChain(session,UIntPtr.Zero,0,thread,ref count,raw,out cycle);
    if(!result.Success){result.Error=Marshal.GetLastWin32Error();return result;}
    result.Cycle=cycle!=0;var nodes=new List<WaitNode>();
    string[] types={"Invalid","CriticalSection","SendMessage","Mutex","ALPC","COM","ThreadWait","ProcessWait","Thread","ComActivation","Unknown","SocketIO","SMBIO"};
    string[] statuses={"Invalid","NoAccess","Running","Blocked","PidOnly","PidOnlyRpcss","Owned","NotOwned","Abandoned","Error"};
    for(int i=0;i<Math.Min(count,16);i++){
     var n=raw[i];var node=new WaitNode {Type=n.Type<types.Length?types[n.Type]:n.Type.ToString(),Status=n.Status<statuses.Length?statuses[n.Status]:n.Status.ToString()};
     if(n.Type==8){node.ProcessId=n.ProcessId;node.ThreadId=n.ThreadId;node.WaitMilliseconds=n.WaitTime;node.ContextSwitches=n.ContextSwitches;}
     nodes.Add(node);
    }result.Nodes=nodes.ToArray();return result;
   } finally { CloseThreadWaitChainSession(session); }
  }
  public static ChildResult Children(uint processId,long parent) {
   var result=new ChildResult();var children=new List<ChildWindow>();uint owner;
   if(parent==0 || GetWindowThreadProcessId(new IntPtr(parent),out owner)==0 || owner!=processId){result.Windows=children.ToArray();return result;}
   var timer=Stopwatch.StartNew();
   EnumProc callback=delegate(IntPtr hwnd,IntPtr unused){
    uint pid;uint thread=GetWindowThreadProcessId(hwnd,out pid);if(pid!=processId)return true;
    if(children.Count>=64){result.Truncated=true;return false;}
    var name=new StringBuilder(256);GetClassName(hwnd,name,256);
    var child=new ChildWindow {Handle=hwnd.ToInt64(),ThreadId=thread,ClassName=name.ToString(),Visible=IsWindowVisible(hwnd),Enabled=IsWindowEnabled(hwnd)};
    if(child.Visible && timer.ElapsedMilliseconds<1000){UIntPtr ignored;child.Replied=SendMessageTimeout(hwnd,0,UIntPtr.Zero,IntPtr.Zero,0x23,75,out ignored)!=IntPtr.Zero;if(child.Replied==false)child.Error=Marshal.GetLastWin32Error();}
    else if(child.Visible)result.ProbeBudgetExhausted=true;
    children.Add(child);return true;
   };
   EnumChildWindows(new IntPtr(parent),callback,IntPtr.Zero);GC.KeepAlive(callback);result.Windows=children.ToArray();return result;
  }
 }
}
