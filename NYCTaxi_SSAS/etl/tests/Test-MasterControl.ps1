$ErrorActionPreference='Stop'
$etl=Split-Path $PSScriptRoot
$env:NYCTAXI_TEST_LOG_ROOT=Join-Path $PSScriptRoot 'master-fixture-logs'
$cases=@(
 @{Mode='success';Exit=0;Calls=1;Stage='Dwh';Start='Extract'},
 @{Mode='permanent';Exit=1;Calls=1;Stage='Dwh';Start='Extract'},
 @{Mode='transient';Exit=0;Calls=2;Stage='Dwh';Start='Extract'},
 @{Mode='exhaust';Exit=1;Calls=2;Stage='Dwh';Start='Extract'},
 @{Mode='stale';Exit=1;Calls=1;Stage='Dwh';Start='Extract'},
 @{Mode='success';Exit=0;Calls=1;Stage='Extract';Start='Dwh'},
 @{Mode='skipfail';Exit=1;Calls=1;Stage='Extract';Start='Dwh'}
)
$results=@()
foreach($case in $cases){
 $run=[guid]::NewGuid();$env:NYCTAXI_TEST_MODE=$case.Mode;$ErrorActionPreference='Continue'
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $etl 'Invoke-SsisStage.ps1') -RunId $run -Stage $case.Stage -StartAt $case.Start -RunnerPath (Join-Path $PSScriptRoot 'Fake-StageRunner.ps1') -LogRoot $env:NYCTAXI_TEST_LOG_ROOT 2> (Join-Path $PSScriptRoot 'fixture-stderr.txt') | Out-Null
 $code=$LASTEXITCODE;$ErrorActionPreference='Stop';$folder=Join-Path $env:NYCTAXI_TEST_LOG_ROOT $run
 $calls=@(Get-Content (Join-Path $folder 'calls.txt')).Count
 if($code -ne $case.Exit -or $calls -ne $case.Calls){throw "FAIL $($case.Mode): code=$code calls=$calls"}
 if($case.Mode -eq 'permanent'){
  $err=Get-Content (Join-Path $folder 'master-error.json') -Raw|ConvertFrom-Json
  if($err.Message -ne 'fixture original SQL error' -or $err.Task -ne 'FixtureSql'){throw 'Original error was lost'}
 }
 $results += [pscustomobject]@{Mode=$case.Mode;Stage=$case.Stage;StartAt=$case.Start;ExitCode=$code;Calls=$calls;Passed=$true}
 Write-Host "PASS $($case.Mode) $($case.Stage) start=$($case.Start)"
}
$results|ConvertTo-Json|Set-Content (Join-Path $etl 'master-control-test-results.json') -Encoding UTF8
Remove-Item Env:NYCTAXI_TEST_LOG_ROOT,Env:NYCTAXI_TEST_MODE
