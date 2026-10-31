$ErrorActionPreference='Stop'
$live='E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_03_Load_DWH.dtsx'
$expected=(Get-Content (Join-Path $PSScriptRoot 'incremental/prepared-source-hash.txt') -Raw).Trim()
if((Get-FileHash -LiteralPath $live -Algorithm SHA256).Hash -ne $expected){throw 'Live DWH package changed after preparation; inspect differences before deploying.'}
$proof=Get-Content (Join-Path $PSScriptRoot 'incremental-tests.json') -Raw|ConvertFrom-Json
if(-not $proof.Passed){throw 'Incremental SQL tests have not passed'}
$backup=Join-Path $PSScriptRoot ('backups/incremental-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $backup -Force
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15';$c.Open()
function Exec($text){$q=$c.CreateCommand();$q.CommandText=$text;$q.CommandTimeout=1800;try{return $q.ExecuteScalar()}finally{$q.Dispose()}}
try{
 $r=Exec "DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;SELECT @r;"
 if([int]$r -lt 0){throw 'ETL process is active; no deployment performed.'}
 if((Exec "SELECT COUNT(*) FROM etl.PipelineRun WHERE Status='RUNNING'") -ne 0){throw 'Unfinished pipeline run exists; inspect it before deployment.'}
 Copy-Item -LiteralPath $live -Destination $backup
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1') -Destination (Join-Path $backup 'runner-installed-version.ps1')
 # Apply schema and indexes only. No Fact/Dimension load is executed here.
 [xml]$pkg=Get-Content (Join-Path $PSScriptRoot 'packages/PKG_03_Load_DWH.dtsx') -Raw
 $task=$pkg.SelectSingleNode('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"][@*[local-name()="ObjectName"]="EST_00_Precheck_DWH"]//*[local-name()="SqlTaskData"]')
 $sql=$task.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')
 $null=Exec ("SET XACT_ABORT ON;BEGIN TRY BEGIN TRANSACTION;"+$sql+" COMMIT;END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;")
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'packages/PKG_03_Load_DWH.dtsx') -Destination $live -Force
 # SSDT sometimes omits default LoggingOptions; retain required error-handler metadata only.
 $py='C:\Users\ADMIN\AppData\Local\Programs\Python\Python310\python.exe'
 & $py (Join-Path $PSScriptRoot 'Repair-LoggingOptions.py') (Split-Path $live) $backup
 if($LASTEXITCODE -ne 0){throw 'Metadata repair failed'}
 [pscustomobject]@{InstalledAt=(Get-Date).ToString('o');Package=$live;Backup=$backup;FactLoadExecuted=$false;BaselineCheckpoints=(Exec 'SELECT COUNT(*) FROM etl.DwhFileLog');Sha256=(Get-FileHash -LiteralPath $live).Hash}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'incremental-install.json') -Encoding UTF8
 Write-Output ('Incremental DWH installed; ETL was NOT started. Backup: '+$backup)
}finally{$c.Dispose()}
