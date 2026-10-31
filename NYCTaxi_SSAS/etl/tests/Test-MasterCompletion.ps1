param([Parameter(Mandatory=$true)][guid]$SucceededRunId)
$ErrorActionPreference='Stop'
$etl=Split-Path $PSScriptRoot;$logs=Join-Path $PSScriptRoot 'completion-fixture-logs'
foreach($case in @(@{Run=$SucceededRunId;Code=0;State='SUCCEEDED'},@{Run=[guid]::NewGuid();Code=1;State='FAILED'})){
 $ErrorActionPreference='Continue'
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $etl 'Invoke-SsisStage.ps1') -Operation Complete -RunId $case.Run -LogRoot $logs 2> (Join-Path $PSScriptRoot 'completion-fixture-stderr.txt') | Out-Null
 $code=$LASTEXITCODE;$ErrorActionPreference='Stop'
 $state=Get-Content (Join-Path $logs ($case.Run.ToString()+'/status.json')) -Raw|ConvertFrom-Json
 if($code -ne $case.Code -or $state.Status -ne $case.State -or $state.Stage -ne 'Master'){throw 'Completion regression: exit/status/stage mismatch'}
 if($case.Code -eq 0 -and $state.Task -ne 'MasterComplete'){throw 'MasterComplete event missing'}
 Write-Host ('PASS Complete '+$case.State+' correctly attributed to Master')
}
