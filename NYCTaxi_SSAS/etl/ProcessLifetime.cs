using System;
using System.Runtime.InteropServices;
using System.ComponentModel;
public sealed class PipelineJob : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct Basic { public long PerProcess,PerJob; public uint Flags; public UIntPtr Min,Max; public uint Active; public UIntPtr Affinity; public uint Priority,Scheduling; }
 [StructLayout(LayoutKind.Sequential)] struct Io {public ulong A,B,C,D,E,F;}
 [StructLayout(LayoutKind.Sequential)] struct Extended {public Basic Basic;public Io Io;public UIntPtr ProcessMemory,JobMemory,PeakProcess,PeakJob;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr a,string n);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr h,int c,IntPtr p,uint l);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr h,IntPtr p);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 IntPtr handle;
 public PipelineJob(){handle=CreateJobObject(IntPtr.Zero,null);if(handle==IntPtr.Zero)throw new Win32Exception();var x=new Extended();x.Basic.Flags=0x2000;int size=Marshal.SizeOf(x);var ptr=Marshal.AllocHGlobal(size);try{Marshal.StructureToPtr(x,ptr,false);if(!SetInformationJobObject(handle,9,ptr,(uint)size))throw new Win32Exception();}catch{Dispose();throw;}finally{Marshal.FreeHGlobal(ptr);}}
 public void Attach(IntPtr process){if(!AssignProcessToJobObject(handle,process))throw new Win32Exception();}
 public void Dispose(){if(handle!=IntPtr.Zero){CloseHandle(handle);handle=IntPtr.Zero;}}
}
