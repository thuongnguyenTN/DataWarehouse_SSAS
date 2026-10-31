param(
 [Parameter(Mandatory=$true)][ValidatePattern('^\d{2}:\d{2}$')][string]$DailyAt,
 [Parameter(Mandatory=$true)][ValidatePattern('^\d{4}-(0[1-9]|1[0-2])$')][string]$StartMonth,
 [Parameter(Mandatory=$true)][ValidatePattern('^\d{4}-(0[1-9]|1[0-2])$')][string]$EndMonth,
 [ValidateRange(0,2147483647)][int]$MaxRows=100000,
 [string]$TaskName='NYCTaxi Full ETL'
)
$ErrorActionPreference='Stop'
$when=[datetime]::ParseExact($DailyAt,'HH:mm',[Globalization.CultureInfo]::InvariantCulture)
if(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){throw 'Task already exists; inspect it before replacing.'}
$runner=Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1'
$action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "'+$runner+'" -StartMonth '+$StartMonth+' -EndMonth '+$EndMonth+' -MaxRows '+$MaxRows) -WorkingDirectory $PSScriptRoot
$trigger=New-ScheduledTaskTrigger -Daily -At $when
$settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
$principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'NYC Taxi ETL; requires logged-in user. Review etl/README.md for service-account scheduling.'
