$ErrorActionPreference='Stop'
$etl=Split-Path $PSScriptRoot;$run=[guid]::NewGuid()
$env:NYCTAXI_TEST_LOG_ROOT=Join-Path $PSScriptRoot 'master-fixture-logs';$env:NYCTAXI_TEST_MODE='stream'
$runner=Join-Path $PSScriptRoot 'Fake-StageRunner.ps1';$controller=Join-Path $etl 'Invoke-SsisStage.ps1'
$psi=New-Object Diagnostics.ProcessStartInfo
$psi.FileName='powershell.exe';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
$psi.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$controller+'" -RunId '+$run+' -Stage Dwh -RunnerPath "'+$runner+'" -LogRoot "'+$env:NYCTAXI_TEST_LOG_ROOT+'"'
$p=[Diagnostics.Process]::Start($psi)
try{
 $file=Join-Path $env:NYCTAXI_TEST_LOG_ROOT ($run.ToString()+'/controller-Dwh-attempt1.stdout.log');$observed=$false;$deadline=(Get-Date).AddSeconds(8)
 while(-not $p.HasExited -and (Get-Date) -lt $deadline){
  if(Test-Path $file){$f=New-Object IO.FileStream($file,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{$r=New-Object IO.StreamReader($f);if($r.ReadToEnd() -match 'stream started'){$observed=$true;break}}finally{$f.Dispose()}}
  Start-Sleep -Milliseconds 100
 }
 $p.WaitForExit();if(-not $observed -or $p.ExitCode -ne 0){throw 'Output was not visible before process exit'}
 Write-Host 'PASS stdout visible while child is still running'
}finally{$p.Dispose();Remove-Item Env:NYCTAXI_TEST_LOG_ROOT,Env:NYCTAXI_TEST_MODE}
