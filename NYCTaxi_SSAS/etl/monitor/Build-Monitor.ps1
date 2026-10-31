$ErrorActionPreference='Stop'
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:winexe /platform:x64 /optimize+ /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll ('/out:'+(Join-Path $PSScriptRoot 'NYCTaxi ETL Monitor.exe')) (Join-Path $PSScriptRoot 'ETLMonitor.cs')
if($LASTEXITCODE -ne 0){throw 'Monitor build failed'}
