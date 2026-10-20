$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
$server=New-Object Microsoft.AnalysisServices.Server;$server.Connect('THUONGNGUYEN\MSSQLSV')
$trace=$server.Traces.Add('Codex NYC Taxi processing diagnostics '+[guid]::NewGuid().ToString())
foreach($kind in @('ProgressReportBegin','ProgressReportCurrent','ProgressReportEnd')) {
 $event=$trace.Events.Add([Microsoft.AnalysisServices.TraceEventClass]::$kind)
 foreach($col in @('TextData','EventSubclass','ObjectPath')) {$null=$event.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::$col)}
}
$trace.Update()
$log=Join-Path $root 'evidence/processing-trace.txt'
$subscription=Register-ObjectEvent $trace OnEvent -MessageData $log -Action {
 $Event.SourceEventArgs.TextData | Add-Content -LiteralPath $Event.MessageData
}
try {
 $trace.Start()
 try {$server.Databases.Find('NYCTaxi_SSAS').Dimensions.Find('Dim Base').Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)} catch {Write-Output $_.Exception.Message}
 Start-Sleep -Seconds 2
} finally {$trace.Stop();$trace.Drop();Unregister-Event -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue;$server.Disconnect()}
Get-Content $log


