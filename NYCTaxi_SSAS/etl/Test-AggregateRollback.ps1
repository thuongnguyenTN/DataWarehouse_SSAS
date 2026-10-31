param([Parameter(Mandatory=$true)][guid]$RunId)
$ErrorActionPreference='Stop'
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10';$c.Open()
$signature="SELECT CONCAT((SELECT COUNT_BIG(*) FROM dbo.Fact_Daily_Financial_Snapshot),'|',(SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM dbo.Fact_Daily_Financial_Snapshot),'|',(SELECT COUNT_BIG(*) FROM dbo.Fact_Zone_Traffic_Snapshot),'|',(SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM dbo.Fact_Zone_Traffic_Snapshot),'|',(SELECT COUNT_BIG(*) FROM dbo.Fact_Base_Performance_Snapshot),'|',(SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM dbo.Fact_Base_Performance_Snapshot),'|',(SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM etl.AggregateWatermark));"
try {
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=300;$cmd.CommandText=$signature;$before=$cmd.ExecuteScalar()
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName='powershell.exe';$info.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1')+'" -Stage Aggregates -StartMonth 2025-01 -EndMonth 2025-01 -MaxRows 100000 -RunId '+$RunId+' -InjectFailure DuringAggregates'
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $process=New-Object Diagnostics.Process;$process.StartInfo=$info
 try {
  $null=$process.Start();$out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync();$process.WaitForExit()
  $out.Result|Set-Content (Join-Path $PSScriptRoot 'rollback-test.stdout.log') -Encoding UTF8
  $err.Result|Set-Content (Join-Path $PSScriptRoot 'rollback-test.stderr.log') -Encoding UTF8
  if($process.ExitCode -eq 0 -or $err.Result -notmatch 'Injected aggregate failure'){throw ('Expected injected error not observed: '+$err.Result)}
 }finally{$process.Dispose()}
 $cmd.CommandText=$signature;$after=$cmd.ExecuteScalar()
 if($before -ne $after){throw 'Snapshots/watermarks changed despite rollback'}
 [pscustomobject]@{Test='All three snapshots and watermarks rollback on injected SQL error';Passed=$true;RunId="$RunId";Before=$before;After=$after}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'rollback-test.json') -Encoding UTF8
 'PASS: injected failure rolled back all snapshots and watermarks. Resume Aggregates with same RunId.'
}finally{$c.Dispose()}
