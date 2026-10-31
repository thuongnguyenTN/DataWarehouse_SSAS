$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1'
$report=New-Object 'System.Collections.Generic.List[object]'
function Run-Child([string[]]$arguments) {
 $p=New-Object Diagnostics.ProcessStartInfo
 $p.FileName='powershell.exe';$p.Arguments=($arguments|ForEach-Object {'"'+$_+'"'}) -join ' '
 $p.UseShellExecute=$false;$p.CreateNoWindow=$true;$p.RedirectStandardOutput=$true;$p.RedirectStandardError=$true
 $child=New-Object Diagnostics.Process;$child.StartInfo=$p
 try {$null=$child.Start();$o=$child.StandardOutput.ReadToEndAsync();$e=$child.StandardError.ReadToEndAsync();$child.WaitForExit();return [pscustomobject]@{Code=$child.ExitCode;Out=$o.Result;Error=$e.Result}}finally{$child.Dispose()}
}
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10';$c.Open()
try {
 $cmd=$c.CreateCommand()
 $rid=[guid]::NewGuid().ToString()
 $result=Run-Child @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-Stage','Dwh','-RunId',$rid)
 if($result.Code -eq 0 -or $result.Error -notmatch 'Previous stage Transform'){throw "Stage guard test failed: $($result.Error)"}
 $cmd.CommandText="SELECT Status FROM etl.PipelineRun WHERE RunId='$rid'";$status=$cmd.ExecuteScalar()
 if($status -ne 'FAILED'){throw 'Failed run not recorded'}
 if(-not(Test-Path (Join-Path $PSScriptRoot ('alerts/'+$rid+'.json')))){throw 'Missing local failure alert'}
 $report.Add([pscustomobject]@{Test='Out-of-order stage stops and logs FAILED';Passed=$true;RunId=$rid})
 $cmd.CommandText="DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;SELECT @r;"
 if([int]$cmd.ExecuteScalar() -lt 0){throw 'Cannot acquire test lock'}
 try {
  $rid=[guid]::NewGuid().ToString()
  $result=Run-Child @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-Stage','Extract','-RunId',$rid)
  if($result.Code -eq 0 -or $result.Error -notmatch 'Another ETL run'){throw "Concurrency test failed: $($result.Error)"}
  $report.Add([pscustomobject]@{Test='Concurrent run rejected before data changes';Passed=$true;RunId=$rid})
 }finally{$cmd.CommandText="EXEC sys.sp_releaseapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockOwner='Session';";$null=$cmd.ExecuteNonQuery()}
}finally{$c.Dispose()}
$report|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'control-tests.json') -Encoding UTF8
$report|Format-Table -AutoSize
