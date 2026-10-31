$ErrorActionPreference='Stop'
if((Get-Content 'E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_03_Load_DWH.dtsx' -Raw).Contains('FILE_V1_20261031')){
 throw 'This legacy production-rollback test predates file checkpoints. Run etl/Test-IncrementalDwh.ps1 instead; it tests historical correction in isolated databases.'
}
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10';$c.Open()
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=1800;try{return $cmd.ExecuteScalar()}finally{$cmd.Dispose()}}
try {
 $lock=Scalar "DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;SELECT @r;"
 if([int]$lock -lt 0){throw 'An ETL process is active; retry after it completes.'}
 $signature="SELECT CONCAT(COUNT_BIG(*),'|',SUM(CONVERT(bigint,TripDurationSeconds))) FROM dbo.Fact_FHV_Trips;"
 $before=Scalar $signature
 $null=Scalar @'
SET XACT_ABORT ON; BEGIN TRANSACTION;
SELECT TOP(2) TripCleanID,TripDurationSeconds,ROW_NUMBER() OVER(ORDER BY TripCleanID) AS rn
INTO #CorrectionFixture FROM NYCTaxi_Staging.clean.ValidTrip
WHERE TaxiType='FHV' AND TripDurationSeconds>0 ORDER BY TripCleanID;
IF (SELECT COUNT(*) FROM #CorrectionFixture)<>2 THROW 55930,'Need two FHV fixture rows.',1;
SELECT COUNT_BIG(*) AS N,SUM(CONVERT(bigint,TripDurationSeconds)) AS D INTO #FactBefore FROM dbo.Fact_FHV_Trips;
UPDATE C SET TripDurationSeconds=C.TripDurationSeconds+1
FROM NYCTaxi_Staging.clean.Trip C JOIN #CorrectionFixture F ON F.TripCleanID=C.TripCleanID WHERE F.rn=1;
UPDATE C SET IsCoreValid=0
FROM NYCTaxi_Staging.clean.Trip C JOIN #CorrectionFixture F ON F.TripCleanID=C.TripCleanID WHERE F.rn=2;
'@
 [xml]$package=Get-Content 'E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_03_Load_DWH.dtsx' -Raw
 $task=$package.SelectSingleNode('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"][@*[local-name()="ObjectName"]="EST_03_Load_FactFHV"]/*[local-name()="ObjectData"]/*[local-name()="SqlTaskData"]')
 $null=Scalar $task.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')
 $null=Scalar @'
IF (SELECT COUNT_BIG(*) FROM dbo.Fact_FHV_Trips)<>(SELECT N-1 FROM #FactBefore)
 THROW 55931,'Historical deletion not reconciled.',1;
IF (SELECT SUM(CONVERT(bigint,TripDurationSeconds)) FROM dbo.Fact_FHV_Trips)
 <> (SELECT D+1-(SELECT TripDurationSeconds FROM #CorrectionFixture WHERE rn=2) FROM #FactBefore)
 THROW 55932,'Historical correction not reconciled.',1;
ROLLBACK TRANSACTION;
'@
 $after=Scalar $signature
 if($before -ne $after){throw 'Test rollback failed to restore FHV facts'}
 [pscustomobject]@{Test='Production Fact SQL reconciles a historical correction and a removed/rejected row; outer rollback restores business data';Passed=$true;Before=$before;After=$after}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'history-test.json') -Encoding UTF8
 'PASS: history correction and deletion reconciled; all fixture changes rolled back.'
}finally{
 try{$null=Scalar 'IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;'}finally{$c.Dispose()}
}
