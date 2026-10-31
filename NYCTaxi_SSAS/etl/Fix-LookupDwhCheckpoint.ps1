$ErrorActionPreference='Stop'
$live='E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_03_Load_DWH.dtsx'
if(-not (Get-Content $live -Raw).Contains('FILE_V1_20261031')){throw 'Unexpected loader version; inspect package first.'}
$backup=Join-Path $PSScriptRoot ('backups/lookup-checkpoint-fix-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $backup -Force
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15';$c.Open()
function Exec($sql){$q=$c.CreateCommand();$q.CommandText=$sql;$q.CommandTimeout=60;try{return $q.ExecuteScalar()}finally{$q.Dispose()}}
try{
 $r=Exec "DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;SELECT @r;"
 if([int]$r -lt 0){throw 'ETL active; fix not applied'}
 if((Exec "SELECT COUNT(*) FROM etl.PipelineRun WHERE Status='RUNNING'") -ne 0){throw 'RUNNING run exists; fix not applied'}
 Copy-Item -LiteralPath $live -Destination $backup
 Exec "SELECT OBJECT_DEFINITION(OBJECT_ID('etl.DwhSourceState'))"|Set-Content (Join-Path $backup 'DwhSourceState.before.sql') -Encoding UTF8
 $before=Exec "SELECT SUM(row_count) FROM sys.dm_db_partition_stats WHERE index_id IN(0,1) AND OBJECT_NAME(object_id) IN('Fact_YellowGreen_Trips','Fact_FHV_Trips','Fact_HVFHV_Trips')"
 $null=Exec 'BEGIN TRANSACTION;'
 try{
  $null=Exec (Get-Content (Join-Path $PSScriptRoot 'incremental/002-file-checkpoints.sql') -Raw)
  & 'C:\Users\ADMIN\AppData\Local\Programs\Python\Python310\python.exe' (Join-Path $PSScriptRoot 'Apply-IncrementalDwh.py') $live
  if($LASTEXITCODE -ne 0){throw 'Package patch failed'}
  $null=Exec 'COMMIT TRANSACTION;'
 }catch{
  $null=Exec 'IF @@TRANCOUNT>0 ROLLBACK;'
  Copy-Item -LiteralPath (Join-Path $backup 'PKG_03_Load_DWH.dtsx') -Destination $live -Force
  throw
 }
 [xml]$doc=Get-Content $live -Raw
 $node=$doc.SelectSingleNode('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"][@*[local-name()="ObjectName"]="EST_05_Validate_DWH"]//*[local-name()="SqlTaskData"]')
 $sql=$node.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')
 # Run only the read-only validation part. Do not advance a run or change batch statuses.
 $readOnly=$sql.Substring(0,$sql.IndexOf('UPDATE dbo.Dim_LoadBatch'))
 $null=Exec $readOnly
 $after=Exec "SELECT SUM(row_count) FROM sys.dm_db_partition_stats WHERE index_id IN(0,1) AND OBJECT_NAME(object_id) IN('Fact_YellowGreen_Trips','Fact_FHV_Trips','Fact_HVFHV_Trips')"
 if($before -ne $after){throw 'Fact count changed unexpectedly'}
 [pscustomobject]@{Passed=$true;Backup=$backup;ValidationPassed=$true;FactRowsBefore=$before;FactRowsAfter=$after;LookupInFactPlan=(Exec "SELECT COUNT(*) FROM etl.DwhSourceState WHERE DatasetCode='lookup'");CompletedFileCheckpoints=(Exec "SELECT COUNT(*) FROM etl.DwhFileLog WHERE Status='SUCCEEDED'");EtlStarted=$false;PipelineStatusModified=$false}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'lookup-checkpoint-fix.json') -Encoding UTF8
 'Fixed lookup checkpoint selection; read-only DWH validation passed; no ETL run was started.'
}finally{$c.Dispose()}
