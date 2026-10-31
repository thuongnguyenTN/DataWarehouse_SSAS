$ErrorActionPreference='Stop'
$rid=[guid]::NewGuid().ToString()
$fixture=Join-Path $PSScriptRoot 'tests/quarantine-fixture'
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_Staging;Integrated Security=True;Connect Timeout=10';$c.Open()
try{
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=120;$cmd.CommandText='SELECT COUNT_BIG(*) FROM stg.YellowTrip';$before=$cmd.ExecuteScalar()
 $p=New-Object Diagnostics.ProcessStartInfo;$p.FileName='powershell.exe'
 $p.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1')+'" -Stage Extract -StartMonth 2025-01 -EndMonth 2025-01 -MaxRows 100000 -Offline -DataRoot "'+$fixture+'" -RunId '+$rid
 $p.UseShellExecute=$false;$p.CreateNoWindow=$true;$p.RedirectStandardOutput=$true;$p.RedirectStandardError=$true
 $process=New-Object Diagnostics.Process;$process.StartInfo=$p
 try{
  $null=$process.Start();$o=$process.StandardOutput.ReadToEndAsync();$e=$process.StandardError.ReadToEndAsync();$process.WaitForExit()
  $o.Result|Set-Content (Join-Path $PSScriptRoot 'quarantine-test.stdout.log') -Encoding UTF8
  $e.Result|Set-Content (Join-Path $PSScriptRoot 'quarantine-test.stderr.log') -Encoding UTF8
  if($process.ExitCode -eq 0 -or $e.Result -notmatch 'Invalid CSV metadata'){throw ('Expected metadata failure missing: '+$e.Result)}
 }finally{$process.Dispose()}
 $after=$cmd.ExecuteScalar();if($before -ne $after){throw 'Invalid file changed staging'}
 $rejected=Join-Path $fixture ('quarantine/'+$rid+'/yellow/yellow_tripdata_2025-01.csv')
 foreach($file in @($rejected,($rejected+'.meta.json'),($rejected+'.error.json'))){if(-not(Test-Path -LiteralPath $file)){throw "Missing quarantine evidence: $file"}}
 [pscustomobject]@{Test='Bad metadata stops before staging mutation and quarantines CSV+metadata+error';Passed=$true;RunId=$rid;StagingBefore=$before;StagingAfter=$after}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'quarantine-test.json') -Encoding UTF8
 [pscustomobject]@{RunId=$rid;Status='RESOLVED';Resolution='Expected negative integration test; production data unchanged';Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot ('alerts/'+$rid+'.json')) -Encoding UTF8
 'PASS: invalid metadata quarantined; production staging unchanged.'
}finally{$c.Dispose()}
