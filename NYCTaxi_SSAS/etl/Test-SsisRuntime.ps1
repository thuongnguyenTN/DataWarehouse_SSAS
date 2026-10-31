$ErrorActionPreference='Stop'
$bin='C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\SSIS\170\Binn'
Add-Type @'
using System; using System.IO; using System.Reflection;
public static class SsisResolver {
 public static string Bin;
 public static void Install(string bin) {Bin=bin; AppDomain.CurrentDomain.AssemblyResolve += Resolve;}
 static Assembly Resolve(object sender, ResolveEventArgs e) {string path=Path.Combine(Bin,new AssemblyName(e.Name).Name+".dll");return File.Exists(path)?Assembly.LoadFrom(path):null;}
}
'@
[SsisResolver]::Install($bin)
$env:PATH=$bin+';'+$env:PATH
$null=[Reflection.Assembly]::LoadFrom((Join-Path $bin 'Microsoft.SqlServer.ManagedDTS.dll'))
$app=New-Object Microsoft.SqlServer.Dts.Runtime.Application
$app.TargetServerVersion='SQLServer2025'
$pkg=$app.LoadPackage('E:\NYCTaxi\NYCTaxi_SSAS\etl\packages\PKG_00_Master.dtsx',$null)
'LOADED '+$pkg.Name
$pkg.Errors | Select-Object Description
