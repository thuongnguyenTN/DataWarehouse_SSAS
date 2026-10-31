param(
 [ValidateSet('PublishedMonth','Demo201301')][string]$Mode='PublishedMonth',
 [ValidateRange(0,2147483647)][int]$MaxRows=0,
 [switch]$PlanOnly
)
$ErrorActionPreference='Stop'
# TLC publishes with a delay. Resolve the target at execution time, not registration time.
$bangkok=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([datetime]::UtcNow,'SE Asia Standard Time')
$month=if($Mode -eq 'Demo201301'){'2013-01'}else{$bangkok.AddMonths(-2).ToString('yyyy-MM')}
if($PlanOnly){[pscustomobject]@{Month=$month;MaxRows=$MaxRows;Mode=$Mode} | ConvertTo-Json;exit 0}
$logRoot=Join-Path $PSScriptRoot 'monthly-logs'
$null=New-Item -ItemType Directory -Path $logRoot -Force
$log=Join-Path $logRoot ($bangkok.ToString('yyyyMMdd-HHmmss')+'.log')
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1') -StartMonth $month -EndMonth $month -MaxRows $MaxRows *> $log
$result=$LASTEXITCODE
exit $result
