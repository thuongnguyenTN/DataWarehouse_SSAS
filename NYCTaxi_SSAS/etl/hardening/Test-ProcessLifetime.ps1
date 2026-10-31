$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path (Split-Path $PSScriptRoot) 'ProcessLifetime.cs')
$file=Join-Path $PSScriptRoot 'child.pid';$fixture=Join-Path $PSScriptRoot 'process-fixture.ps1'
@'
param($PidFile)
$p=Start-Process powershell.exe -ArgumentList '-NoProfile -Command Start-Sleep -Seconds 60' -WindowStyle Hidden -PassThru
$p.Id|Set-Content $PidFile
Start-Sleep -Seconds 60
'@|Set-Content $fixture
$job=New-Object PipelineJob;$p=$null;$child=$null
try{
 $p=Start-Process powershell.exe -ArgumentList ('-NoProfile -File "'+$fixture+'" -PidFile "'+$file+'"') -WindowStyle Hidden -PassThru
 $job.Attach($p.Handle);$deadline=(Get-Date).AddSeconds(10)
 while(-not(Test-Path $file) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 100}
 if(-not(Test-Path $file)){throw 'Child did not start'}
 $child=[Diagnostics.Process]::GetProcessById([int](Get-Content $file));$job.Dispose()
 if(-not $p.WaitForExit(5000) -or -not $child.WaitForExit(5000)){throw 'Job did not stop the process tree'}
 'PASS job close terminates runner and descendant'
}finally{$job.Dispose();foreach($proc in @($p,$child)){if($proc){if(-not $proc.HasExited){$proc.Kill()};$proc.Dispose()}}}
