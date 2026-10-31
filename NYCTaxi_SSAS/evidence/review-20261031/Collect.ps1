$ErrorActionPreference='Stop'
function Capture($db,$name,$sql){
 $c=New-Object Data.SqlClient.SqlConnection ('Server=THUONGNGUYEN\MSSQLSV;Database='+$db+';Integrated Security=True;Connect Timeout=10')
 try{
  $c.Open();$q=$c.CreateCommand();$q.CommandText=$sql;$q.CommandTimeout=180
  $a=New-Object Data.SqlClient.SqlDataAdapter $q;$ds=New-Object Data.DataSet;$null=$a.Fill($ds)
  $sets=@();foreach($t in $ds.Tables){$rows=@();foreach($row in $t.Rows){$item=[ordered]@{};foreach($col in $t.Columns){$item[$col.ColumnName]=if($row[$col] -is [DBNull]){$null}else{$row[$col]}};$rows+=[pscustomobject]$item};$sets+=,[object[]]$rows}
  ConvertTo-Json -InputObject $sets -Depth 8|Set-Content (Join-Path $PSScriptRoot ($name+'.json')) -Encoding UTF8
  Write-Host ($name+': '+(($sets|ForEach-Object {$_.Count}) -join ',')+' rows')
 }finally{$c.Dispose()}
}
Capture 'NYCTaxi_DWH' 'dwh' @'
SELECT TOP(15) * FROM etl.PipelineRun ORDER BY StartedAt DESC;
SELECT r.RunId,s.Stage,s.TaskName,s.Status,s.ErrorNumber,s.ErrorMessage,s.StartedAt,s.CompletedAt,s.Detail FROM etl.PipelineStep s JOIN etl.PipelineRun r ON r.RunId=s.RunId WHERE r.StartedAt>DATEADD(day,-1,SYSUTCDATETIME()) ORDER BY s.StepId;
SELECT s.name SchemaName,t.name TableName,SUM(p.rows) Rows FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN(0,1) GROUP BY s.name,t.name;
SELECT * FROM etl.DwhFileLog;
SELECT * FROM etl.DwhSourceState;
SELECT name,is_disabled,is_not_trusted FROM sys.foreign_keys;
SELECT s.name SchemaName,t.name TableName,c.name ColumnName,ty.name TypeName,c.max_length,c.precision,c.scale,c.is_nullable FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.columns c ON c.object_id=t.object_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id WHERE t.name LIKE 'Dim[_]%' OR t.name LIKE 'Fact[_]%';
SELECT request_session_id,resource_description,request_mode,request_status FROM sys.dm_tran_locks WHERE resource_type='APPLICATION';
SELECT name,state_desc,recovery_model_desc FROM sys.databases WHERE name LIKE 'NYCTaxi%';
'@
Capture 'NYCTaxi_Staging' 'staging' @'
SELECT * FROM etl.ExtractFileLog;
SELECT * FROM etl.TransformFileLog;
SELECT s.name SchemaName,t.name TableName,SUM(p.rows) Rows FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN(0,1) GROUP BY s.name,t.name;
SELECT TaxiType,COUNT_BIG(*) CleanRows,SUM(CONVERT(bigint,IsCoreValid)) ValidRows,MIN(PickupDateTime) MinPickup,MAX(PickupDateTime) MaxPickup FROM clean.Trip GROUP BY TaxiType;
'@
$scheduler=New-Object -ComObject 'Schedule.Service';$scheduler.Connect();$tasks=@()
foreach($t in $scheduler.GetFolder('\').GetTasks(0)){
 if($t.Name -like '*NYCTaxi*'){
  $tasks += [pscustomobject]@{Name=$t.Name;State=$t.State;Enabled=$t.Enabled;LastRunTime=$t.LastRunTime;LastTaskResult=$t.LastTaskResult;NextRunTime=$t.NextRunTime;Xml=$t.Xml}
 }
}
ConvertTo-Json -InputObject $tasks -Depth 5|Set-Content (Join-Path $PSScriptRoot 'tasks.json') -Encoding UTF8
Write-Host ('Scheduled NYCTaxi tasks: '+$tasks.Count)
