param([Parameter(Mandatory=$true)][guid]$RunId)
$ErrorActionPreference='Stop'
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10';$c.Open()
try{
 [xml]$package=Get-Content 'E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_03_Load_DWH.dtsx' -Raw
 $task=$package.SelectSingleNode('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"][@*[local-name()="ObjectName"]="EST_05_Validate_DWH"]/*[local-name()="ObjectData"]/*[local-name()="SqlTaskData"]')
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=300;$cmd.CommandText=$task.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask');$null=$cmd.ExecuteNonQuery()
 $cmd.CommandText="SELECT RunId,StartMonth,EndMonth,RowLimit,Status,StartedAt,CompletedAt,ErrorMessage FROM etl.PipelineRun WHERE RunId='$RunId'; SELECT StepId,Stage,TaskName,Status,StartedAt,CompletedAt,ErrorNumber,ErrorMessage,Detail FROM etl.PipelineStep WHERE RunId='$RunId' ORDER BY StepId; SELECT 'YellowGreen' AS Fact,COUNT_BIG(*) AS Rows,COUNT_BIG(CASE WHEN SourceKey IS NULL THEN 1 END) AS MissingLineage FROM dbo.Fact_YellowGreen_Trips UNION ALL SELECT 'FHV',COUNT_BIG(*),COUNT_BIG(CASE WHEN SourceKey IS NULL THEN 1 END) FROM dbo.Fact_FHV_Trips UNION ALL SELECT 'HVFHV',COUNT_BIG(*),COUNT_BIG(CASE WHEN SourceKey IS NULL THEN 1 END) FROM dbo.Fact_HVFHV_Trips; SELECT TaxiType,IsCoreValid,COUNT_BIG(*) AS Rows FROM NYCTaxi_Staging.clean.Trip GROUP BY TaxiType,IsCoreValid;"
 $adapter=New-Object Data.SqlClient.SqlDataAdapter $cmd;$ds=New-Object Data.DataSet;$null=$adapter.Fill($ds)
 $names=@('run','steps','facts','quality')
 for($i=0;$i -lt $ds.Tables.Count;$i++){
  $rows=@(foreach($row in $ds.Tables[$i].Rows){$entry=[ordered]@{};foreach($col in $ds.Tables[$i].Columns){$entry[$col.ColumnName]=if($row[$col] -is [DBNull]){$null}else{$row[$col]}};[pscustomobject]$entry})
  $rows|ConvertTo-Json -Depth 5|Set-Content (Join-Path $PSScriptRoot ('verification-'+$names[$i]+'.json')) -Encoding UTF8
  if($i -in @(0,2)){$rows|Format-Table -AutoSize}
 }
 'PASS: exact clean-to-fact row reconciliation; evidence saved.'
}finally{$c.Dispose()}
