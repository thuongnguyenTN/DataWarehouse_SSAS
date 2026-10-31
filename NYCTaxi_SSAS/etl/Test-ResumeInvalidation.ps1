$ErrorActionPreference='Stop'
$quarantine=Get-Content (Join-Path $PSScriptRoot 'quarantine-test.json') -Raw|ConvertFrom-Json;$rid=$quarantine.RunId
$fixture=Join-Path $PSScriptRoot 'tests/quarantine-fixture';$runner=Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1'
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-ControlFlow.ps1'),[ref]$tokens,[ref]$errors)
foreach($node in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Run-Child'},$false)){Invoke-Expression $node.Extent.Text}
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10';$c.Open()
try{
 $cmd=$c.CreateCommand();$cmd.CommandText="INSERT etl.PipelineStep(RunId,Stage,TaskName,Status) VALUES('$rid','Transform','StageComplete','SUCCEEDED'),('$rid','Dwh','StageComplete','SUCCEEDED');";$null=$cmd.ExecuteNonQuery()
 $base=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-StartMonth','2025-01','-EndMonth','2025-01','-MaxRows','100000','-Offline','-DataRoot',$fixture,'-RunId',$rid)
 $result=Run-Child ($base+@('-Stage','Extract'))
 if($result.Code -eq 0 -or $result.Error -notmatch 'Invalid CSV metadata'){throw 'Expected fixture failure missing'}
 $cmd.CommandText="SELECT COUNT(*) FROM etl.PipelineStep WHERE RunId='$rid' AND TaskName='StageComplete' AND Stage IN('Transform','Dwh') AND Status='INVALIDATED';"
 if([int]$cmd.ExecuteScalar() -ne 2){throw 'Downstream completion markers were not invalidated'}
 $result=Run-Child ($base+@('-Stage','Dwh'))
 if($result.Code -eq 0 -or $result.Error -notmatch 'Previous stage Transform'){throw 'Stale Transform allowed DWH to run'}
 [pscustomobject]@{Test='Retrying an earlier stage invalidates downstream completion; stale progress cannot skip Transform';Passed=$true;RunId=$rid}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'resume-test.json') -Encoding UTF8
 [pscustomobject]@{RunId=$rid;Status='RESOLVED';Resolution='Expected resume/quarantine test; production data unchanged';Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot ('alerts/'+$rid+'.json')) -Encoding UTF8
 'PASS: retry invalidates downstream progress and blocks stale-stage execution.'
}finally{$c.Dispose()}
