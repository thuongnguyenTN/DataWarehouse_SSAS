$ErrorActionPreference='Stop'
$project='E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL'
$backup=[string](Get-Content (Join-Path $PSScriptRoot 'master-backup-path.txt'))
foreach($name in @('PKG_00_Master.dtsx','NYCTaxi_ETL.dtproj')){
 if((Get-FileHash (Join-Path $project $name)).Hash -ne (Get-FileHash (Join-Path $backup $name)).Hash){throw "Live $name changed after backup; rebuild staging from the latest live file first."}
}
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
try{
 $c.Open();$q=$c.CreateCommand();$q.CommandText="DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; IF @r<0 THROW 55990,'ETL is active; installation refused.',1; IF EXISTS(SELECT 1 FROM etl.PipelineRun WHERE Status='RUNNING') THROW 55991,'Unfinished run exists; installation refused.',1;";$null=$q.ExecuteNonQuery()
 foreach($name in @('PKG_00_Master.dtsx','NYCTaxi_ETL.dtproj')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('packages/'+$name)) -Destination (Join-Path $project $name) -Force}
 [ordered]@{InstalledAt=(Get-Date).ToString('o');Backup=$backup;Project=$project;ProductionEtlExecuted=$false;Files=@('PKG_00_Master.dtsx','NYCTaxi_ETL.dtproj')}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'master-control-install.json') -Encoding UTF8
}finally{$c.Dispose()}
