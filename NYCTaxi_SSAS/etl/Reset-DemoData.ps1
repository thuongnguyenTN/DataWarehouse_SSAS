# Destructive reset, explicitly requested by user: preserve raw, code, models and backups.
param([switch]$Execute)
$ErrorActionPreference='Stop'
if(-not $Execute){throw 'Use -Execute only for the authorized clean-slate reset.'}
$dataRoot='D:\Kho_Du_lieu\NYCTaxi'
$raw=Join-Path $dataRoot 'raw'
$reportRoot=Join-Path $PSScriptRoot ('backups/reset-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $reportRoot -Force
$roots=@((Join-Path $dataRoot 'csv'),(Join-Path $dataRoot 'quarantine'),(Join-Path $dataRoot 'archive'),(Join-Path $dataRoot 'reject'),(Join-Path $PSScriptRoot 'logs'),(Join-Path $PSScriptRoot 'alerts'),(Join-Path $PSScriptRoot 'monthly-logs'))
# Resolve and check all recursive targets before any delete. Never traverse a link.
$resolved=@()
foreach($root in $roots){
 $absolute=[IO.Path]::GetFullPath($root).TrimEnd('\')
 $approved=$absolute.StartsWith($dataRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or $absolute.StartsWith($PSScriptRoot+'\',[StringComparison]::OrdinalIgnoreCase)
 if(-not $approved -or $absolute -eq $raw -or $absolute.StartsWith($raw+'\',[StringComparison]::OrdinalIgnoreCase)){throw ('Unsafe reset path: '+$absolute)}
 if(Test-Path -LiteralPath $absolute){
  $links=@(Get-Item -LiteralPath $absolute;Get-ChildItem -LiteralPath $absolute -Force -Recurse)|Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}
  if($links){throw ('Reparse point in reset target: '+$absolute)}
 }
 $resolved+=$absolute
}
function RawManifest {
 @(Get-ChildItem -LiteralPath $raw -File -Recurse | Sort-Object FullName | ForEach-Object {[pscustomobject]@{Path=$_.FullName;Length=$_.Length;MtimeTicks=$_.LastWriteTimeUtc.Ticks}})
}
$beforeRaw=RawManifest
$beforeRaw|ConvertTo-Json -Depth 4|Set-Content (Join-Path $reportRoot 'raw-before.json') -Encoding UTF8
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15';$c.Open()
function Exec($text){$q=$c.CreateCommand();$q.CommandText=$text;$q.CommandTimeout=1800;try{return $q.ExecuteScalar()}finally{$q.Dispose()}}
$deletedFolders=New-Object 'System.Collections.Generic.List[object]'
$dropped=@()
try{
 $lock=Exec "DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;SELECT @r;"
 if([int]$lock -lt 0){throw 'An ETL runner holds the lock. No reset performed.'}
 if((Exec "SELECT COUNT(*) FROM etl.PipelineRun WHERE Status='RUNNING'") -ne 0){throw 'Unfinished RUNNING history exists; inspect before reset.'}
 $active=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'powershell|python|DtsDebugHost' -and $_.CommandLine -match 'Invoke-NYCTaxiPipeline|download_nyc_parquet|convert_nyc_parquet|DtsDebugHost'})
 if($active.Count){throw 'ETL/debug process still exists. Stop it before reset.'}
 # Save schema-level metadata and seed counts; no data export is needed for requested deletion.
 $seedTables=@('Dim_Date','Dim_Time','Dim_PassengerGroup','Dim_ServiceType','Dim_Vendor','Dim_RateCode','Dim_PaymentType','Dim_TripType','Dim_HVFHSProvider','Dim_TaxiFlags','Dim_FHVFlags','Dim_HVFHVFlags')
 $seedBefore=@{}
 foreach($t in $seedTables){$seedBefore[$t]=[long](Exec "SELECT COUNT_BIG(*) FROM dbo.[$t]")}
 # Clear SSAS data only, retain the six-cube database and all metadata/roles.
 $amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
 $null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
 $null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
 $ssas=New-Object Microsoft.AnalysisServices.Server
 try{
  $ssas.Connect('THUONGNGUYEN\MSSQLSV');$db=$ssas.Databases.Find('NYCTaxi_SSAS')
  if(-not $db -or $db.Cubes.Count -ne 6){throw 'Unexpected SSAS model; reset refused.'}
  $expected=(Get-Content (Join-Path $PSScriptRoot '../scripts/cube-map.json') -Raw|ConvertFrom-Json).cubes.id
  if(@($db.Cubes|Where-Object {$_.ID -notin $expected}).Count){throw 'Unexpected cube IDs; reset refused.'}
  $batch='<Batch xmlns="http://schemas.microsoft.com/analysisservices/2003/engine" Transaction="true"><Process><Object><DatabaseID>NYCTaxi_SSAS</DatabaseID></Object><Type>ProcessClear</Type></Process></Batch>'
  $reply=$ssas.Execute($batch)
  foreach($r in $reply){foreach($m in $r.Messages){if($m -is [Microsoft.AnalysisServices.XmlaError]){throw $m.Description}}}
  $db.Refresh();$ssasState=[string]$db.State
  $processed=@($db.Dimensions|Where-Object {$_.State -eq 'Processed'})
  if($processed.Count){throw 'Some SSAS dimensions remained processed after ProcessClear'}
 }finally{if($ssas.Connected){$ssas.Disconnect()};$ssas.Dispose()}
 $sql=@'
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 TRUNCATE TABLE dbo.Fact_Daily_Financial_Snapshot;
 TRUNCATE TABLE dbo.Fact_Zone_Traffic_Snapshot;
 TRUNCATE TABLE dbo.Fact_Base_Performance_Snapshot;
 TRUNCATE TABLE dbo.Fact_YellowGreen_Trips;
 TRUNCATE TABLE dbo.Fact_FHV_Trips;
 TRUNCATE TABLE dbo.Fact_HVFHV_Trips;
 -- Dynamic dimension contents; retain key=0. Reference/seed dimensions remain intact.
 DELETE dbo.Dim_Location WHERE LocationKey<>0;
 DELETE dbo.Dim_Base WHERE BaseKey<>0;
 DELETE dbo.Dim_LoadBatch WHERE LoadBatchKey<>0;
 DBCC CHECKIDENT ('dbo.Dim_Location',RESEED,0) WITH NO_INFOMSGS;
 DBCC CHECKIDENT ('dbo.Dim_Base',RESEED,0) WITH NO_INFOMSGS;
 DBCC CHECKIDENT ('dbo.Dim_LoadBatch',RESEED,0) WITH NO_INFOMSGS;
 DECLARE @sql nvarchar(max)=N'';
 -- Explicitly limit deletion to this project's staging, clean and operational logs.
 SELECT @sql=@sql+N'TRUNCATE TABLE NYCTaxi_Staging.'+QUOTENAME(S.name)+N'.'+QUOTENAME(T.name)+N';'
 FROM NYCTaxi_Staging.sys.tables T JOIN NYCTaxi_Staging.sys.schemas S ON S.schema_id=T.schema_id
 WHERE S.name IN ('wrk','stg','clean','etl');
 EXEC sys.sp_executesql @sql;
 TRUNCATE TABLE etl.PipelineStep;
 DELETE etl.PipelineRun;
 SET @sql=N'';
 SELECT @sql=@sql+N'TRUNCATE TABLE etl.'+QUOTENAME(T.name)+N';'
 FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
 WHERE S.name='etl' AND T.name NOT IN ('PipelineRun','PipelineStep','AggregateWatermark');
 EXEC sys.sp_executesql @sql;
 UPDATE etl.AggregateWatermark SET LastTripKey=0,UpdatedAt=SYSDATETIME();
 COMMIT TRANSACTION;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
'@
 $null=Exec $sql
 foreach($t in $seedTables){if([long](Exec "SELECT COUNT_BIG(*) FROM dbo.[$t]") -ne $seedBefore[$t]){throw ('Seed reference count changed: '+$t)}}
 foreach($root in $resolved){
  $count=0
  if(Test-Path -LiteralPath $root){
   foreach($child in Get-ChildItem -LiteralPath $root -Force){
    $target=[IO.Path]::GetFullPath($child.FullName)
    if(-not $target.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw ('Unsafe child path: '+$target)}
    Remove-Item -LiteralPath $target -Recurse -Force;$count++
   }
  }
  $null=New-Item -ItemType Directory -Path $root -Force
  $deletedFolders.Add([pscustomobject]@{Path=$root;RemovedTopLevelEntries=$count})
 }
 foreach($dataset in @('yellow','green','fhv','fhvhv','lookup')){$null=New-Item -ItemType Directory -Path (Join-Path $dataRoot ('csv/'+$dataset)) -Force}
 # Drop only databases created by our isolated incremental tests, never user databases.
 $q=$c.CreateCommand();$q.CommandText="SELECT name FROM sys.databases WHERE name LIKE 'NYCTaxi%IncTest%'";$r=$q.ExecuteReader();$testDbs=@();try{while($r.Read()){$testDbs+=$r.GetString(0)}}finally{$r.Close();$q.Dispose()}
 foreach($name in $testDbs){
  if($name -notmatch '^NYCTaxi_(DWH|Staging)_IncTest_[0-9]{14}$'){continue}
  if((Exec "SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE database_id=DB_ID(N'$name') AND session_id<>@@SPID") -ne 0){throw ('Test database is in use; not dropped: '+$name)}
  $null=Exec "DROP DATABASE [$name];";$dropped+=$name
 }
 $afterRaw=RawManifest
 $rawUnchanged=($beforeRaw.Count -eq $afterRaw.Count) -and ((ConvertTo-Json -InputObject $beforeRaw -Compress -Depth 4) -eq (ConvertTo-Json -InputObject $afterRaw -Compress -Depth 4))
 if(-not $rawUnchanged){throw 'Raw manifest changed during reset; inspect before retesting.'}
 $result=[pscustomobject]@{CompletedAt=(Get-Date).ToString('o');RawPreserved=$rawUnchanged;RawFiles=$afterRaw.Count;RawBytes=($afterRaw|Measure-Object Length -Sum).Sum;SsasState=$ssasState;ClearedFolders=@($deletedFolders.ToArray());DroppedFixtureDatabases=$dropped;ReferenceSeedsPreserved=$seedBefore;EtlStarted=$false}
 $result|ConvertTo-Json -Depth 6|Set-Content (Join-Path $reportRoot 'reset-result.json') -Encoding UTF8
 $result|ConvertTo-Json -Depth 6|Set-Content (Join-Path $PSScriptRoot 'reset-result.json') -Encoding UTF8
 Write-Output ('Reset completed. Raw preserved. ETL NOT started. Evidence: '+$reportRoot)
}finally{$c.Dispose()}
