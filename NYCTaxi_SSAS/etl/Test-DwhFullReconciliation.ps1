$ErrorActionPreference='Stop'
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15';$c.Open()
try{
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=1800
 $cmd.CommandText=@'
DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Shared',@LockOwner='Session',@LockTimeout=0;
IF @r<0 THROW 55980,'ETL is active; run full audit after completion.',1;
WITH C AS(
 SELECT LOWER(TaxiType) DatasetCode,ETLSourceKey SourceKey,COUNT_BIG(*) RowsInClean
 FROM NYCTaxi_Staging.clean.ValidTrip GROUP BY TaxiType,ETLSourceKey
),F AS(
 SELECT SourceDataset DatasetCode,SourceKey,COUNT_BIG(*) RowsInFact FROM dbo.Fact_YellowGreen_Trips GROUP BY SourceDataset,SourceKey
 UNION ALL SELECT SourceDataset,SourceKey,COUNT_BIG(*) FROM dbo.Fact_FHV_Trips GROUP BY SourceDataset,SourceKey
 UNION ALL SELECT SourceDataset,SourceKey,COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips GROUP BY SourceDataset,SourceKey
)
SELECT COALESCE(C.DatasetCode,F.DatasetCode) DatasetCode,COALESCE(C.SourceKey,F.SourceKey) SourceKey,
 COALESCE(C.RowsInClean,0) RowsInClean,COALESCE(F.RowsInFact,0) RowsInFact,
 CASE WHEN COALESCE(C.RowsInClean,0)=COALESCE(F.RowsInFact,0) THEN 1 ELSE 0 END Passed
FROM C FULL JOIN F ON F.DatasetCode=C.DatasetCode AND F.SourceKey=C.SourceKey;
'@
 $a=New-Object Data.SqlClient.SqlDataAdapter $cmd;$t=New-Object Data.DataTable;$null=$a.Fill($t)
 $rows=@($t|Select-Object DatasetCode,SourceKey,RowsInClean,RowsInFact,Passed)
 $rows|ConvertTo-Json -Depth 4|Set-Content (Join-Path $PSScriptRoot 'incremental-full-reconciliation.json') -Encoding UTF8
 $failed=@($rows|Where-Object Passed -ne 1)
 Write-Output ('Files checked='+$rows.Count+'; mismatches='+$failed.Count)
 if($failed.Count){$failed|Format-Table;exit 1}
}finally{$c.Dispose()}
