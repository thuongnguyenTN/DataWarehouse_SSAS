param(
 [ValidateSet('PublishedMonth','Demo201301')][string]$Mode='PublishedMonth',
 [ValidateRange(0,2147483647)][int]$MaxRows=0,
 [string]$TaskName='NYCTaxi Monthly ETL'
)
$ErrorActionPreference='Stop'
# COM avoids enumeration of unrelated tasks with malformed XML on this machine.
$scheduler=New-Object -ComObject 'Schedule.Service'
$scheduler.Connect()
$folder=$scheduler.GetFolder('\')
$exists=$null
try{$exists=$folder.GetTask($TaskName)}catch{
 if($_.Exception.HResult -ne -2147024894){throw}
}
if($exists){throw "Task already exists: $TaskName. Inspect it before replacing."}
$definition=$scheduler.NewTask(0)
$definition.RegistrationInfo.Description='NYC Taxi ETL: 15th of every month at 10:00 Bangkok. Interactive user must be logged in. Logs: etl/monthly-logs and etl/logs.'
$definition.Principal.UserId=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$definition.Principal.LogonType=3 # TASK_LOGON_INTERACTIVE_TOKEN; no saved password
$definition.Principal.RunLevel=0
$definition.Settings.Enabled=$true
$definition.Settings.StartWhenAvailable=$true
$definition.Settings.MultipleInstances=2 # IgnoreNew
$definition.Settings.ExecutionTimeLimit='PT24H'
$definition.Settings.DisallowStartIfOnBatteries=$false
$definition.Settings.StopIfGoingOnBatteries=$false
$trigger=$definition.Triggers.Create(4) # TASK_TRIGGER_MONTHLY
$trigger.StartBoundary='2026-11-15T10:00:00+07:00'
$trigger.DaysOfMonth=16384 # bit 14 => day 15
$trigger.MonthsOfYear=4095 # all 12 months
$trigger.Enabled=$true
$action=$definition.Actions.Create(0)
$action.Path=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$action.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Invoke-MonthlyPipeline.ps1')+'" -Mode '+$Mode+' -MaxRows '+$MaxRows
$action.WorkingDirectory=$PSScriptRoot
$task=$folder.RegisterTaskDefinition($TaskName,$definition,2,$definition.Principal.UserId,$null,3,$null)
[pscustomobject]@{Name=$task.Name;NextRunTime=$task.NextRunTime;State=$task.State;Mode=$Mode;MaxRows=$MaxRows}
$task.Xml | Set-Content (Join-Path $PSScriptRoot 'monthly-task.xml') -Encoding UTF8
