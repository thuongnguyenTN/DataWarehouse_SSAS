$ErrorActionPreference='Stop'
$etl=Split-Path $PSScriptRoot
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $etl 'Invoke-NYCTaxiPipeline.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw $errors[0]}
. (Join-Path $etl 'Pipeline.Progress.ps1')
foreach($statement in $ast.EndBlock.Statements){if($statement -is [Management.Automation.Language.FunctionDefinitionAst]){. ([scriptblock]::Create($statement.Extent.Text))}}
$RunId=[guid]::NewGuid();$InvocationId=[guid]::NewGuid();$runFolder=Join-Path $PSScriptRoot ('runner-fixture/'+$RunId);$null=New-Item -ItemType Directory -Path $runFolder -Force
$script:currentStage='Fixture';$script:currentTask='ReadOnlySql';$script:currentStatus='RUNNING';$script:taskStarted=[datetime]::UtcNow;$script:lastPulse=[datetime]::UtcNow;$script:lastStatusWrite=[datetime]::MinValue;$script:progressRows=0;$script:progressTotal=0
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
try{
 $c.Open();$value=Sql $c "WAITFOR DELAY '00:00:02'; SELECT CAST(42 AS int);"
 if($value -ne 42){throw 'Async scalar result mismatch'}
 if(-not (Test-Path (Join-Path $runFolder 'status.json'))){throw 'SQL heartbeat missing'}
 $cmd=$c.CreateCommand();$cmd.CommandText='SELECT CAST(7 AS int)';$reader=Wait-SqlTask ($cmd.ExecuteReaderAsync())
 try{if(-not $reader.Read() -or $reader.GetInt32(0) -ne 7){throw 'Reader mismatch'}}finally{$reader.Dispose();$cmd.Dispose()}
}finally{$c.Dispose()}
$value=Native 'C:\Users\ADMIN\AppData\Local\Programs\Python\Python310\python.exe' @('-u','-c','import time; print("first",flush=True); time.sleep(2); print("last",flush=True)') 'fixture-python'
if($value -notmatch 'first' -or $value -notmatch 'last'){throw 'Native stream mismatch'}
Write-Host 'PASS async SQL scalar, reader, heartbeat, native stdout'
$fake=Join-Path $runFolder 'structured-failure.ps1'
@'
@{InvocationId=$env:NYCTAXI_INVOCATION;Message='fixture deadlock';SqlNumber=1205}|ConvertTo-Json|Set-Content $env:NYCTAXI_ERROR_FILE -Encoding UTF8
exit 1
'@|Set-Content $fake
$caught=$false
try{$null=Native 'powershell.exe' @('-NoProfile','-File',$fake) 'structured-failure'}catch{
 $errorInfo=Get-ETLRootError $_
 if($errorInfo.SqlNumber -ne 1205 -or -not $errorInfo.Retryable){throw 'Structured SQL error was lost'}
 $caught=$true
}
if(-not $caught){throw 'Expected process failure'}
Write-Host 'PASS structured transient SQL error survives child process'
