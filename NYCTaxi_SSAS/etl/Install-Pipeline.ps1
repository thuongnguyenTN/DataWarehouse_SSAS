$ErrorActionPreference='Stop'
$guard=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15'
$guard.Open()
try {
 $guardCommand=$guard.CreateCommand()
 $guardCommand.CommandText="DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;SELECT @r;"
 if([int]$guardCommand.ExecuteScalar() -lt 0){throw 'An ETL run is active; stop installation.'}
 $guardCommand.CommandText="IF OBJECT_ID('etl.PipelineRun','U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM etl.PipelineRun WHERE Status=''RUNNING'') THROW 55921,''An unfinished ETL run exists; resume or close it before installation.'',1;');"
 $null=$guardCommand.ExecuteNonQuery()
$source=Join-Path $PSScriptRoot 'packages'
$target='E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL'
$scripts='D:\Kho_Du_lieu\NYCTaxi\script'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backup=Join-Path $PSScriptRoot ('backups/'+$stamp)
$null=New-Item -ItemType Directory -Path (Join-Path $backup 'packages') -Force
$null=New-Item -ItemType Directory -Path (Join-Path $backup 'python') -Force
foreach($file in Get-ChildItem $source -File){Copy-Item -LiteralPath (Join-Path $target $file.Name) -Destination (Join-Path $backup ('packages/'+$file.Name))}
foreach($file in Get-ChildItem (Join-Path $PSScriptRoot 'python') -File){Copy-Item -LiteralPath (Join-Path $scripts $file.Name) -Destination (Join-Path $backup ('python/'+$file.Name))}
$c=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=master;Integrated Security=True;Connect Timeout=15'
$c.Open()
try {
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=1800
 $cmd.CommandText="DECLARE @dir nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath')); IF @dir IS NULL THROW 55920,'SQL backup directory unavailable.',1; DECLARE @p nvarchar(4000)=@dir+'\NYCTaxi_DWH_before_pipeline_$stamp.bak'; BACKUP DATABASE NYCTaxi_DWH TO DISK=@p WITH COPY_ONLY,COMPRESSION,CHECKSUM; SELECT @p;"
 $dwhBackup=$cmd.ExecuteScalar();$dwhBackup | Set-Content (Join-Path $backup 'database-backups.txt')
 $cmd.CommandText="DECLARE @dir nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath')); DECLARE @p nvarchar(4000)=@dir+'\NYCTaxi_Staging_before_pipeline_$stamp.bak'; BACKUP DATABASE NYCTaxi_Staging TO DISK=@p WITH COPY_ONLY,COMPRESSION,CHECKSUM; SELECT @p;"
 $cmd.ExecuteScalar() | Add-Content (Join-Path $backup 'database-backups.txt')
} finally {$c.Dispose()}
foreach($file in Get-ChildItem $source -File){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $target $file.Name) -Force}
foreach($file in Get-ChildItem (Join-Path $PSScriptRoot 'python') -File){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $scripts $file.Name) -Force}
$c=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15';$c.Open()
try {
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=1800
 $cmd.CommandText=Get-Content (Join-Path $PSScriptRoot '001-pipeline-control.sql') -Raw;$null=$cmd.ExecuteNonQuery()
 # Baseline lineage while the old clean history still matches existing facts.
 [xml]$doc=Get-Content (Join-Path $target 'PKG_03_Load_DWH.dtsx') -Raw
 foreach($task in $doc.SelectNodes('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"]')){
  $data=$task.SelectSingleNode('./*[local-name()="ObjectData"]/*[local-name()="SqlTaskData"]')
  $cmd.CommandText=$data.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')
  $null=$cmd.ExecuteNonQuery();'BASELINE '+$task.GetAttribute('ObjectName','www.microsoft.com/SqlServer/Dts')
 }
} finally {$c.Dispose()}
'Installed packages/Python and baseline provenance. Backup: '+$backup

} finally {$guard.Dispose()}
