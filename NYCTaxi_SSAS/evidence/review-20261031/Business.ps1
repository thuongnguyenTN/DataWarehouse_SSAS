$ErrorActionPreference='Stop';$script:reviewFolder=$PSScriptRoot
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Collect.ps1'),[ref]$tokens,[ref]$errors)
foreach($s in $ast.EndBlock.Statements){if($s -is [Management.Automation.Language.FunctionDefinitionAst]){. ([scriptblock]::Create($s.Extent.Text.Replace('$PSScriptRoot','$script:reviewFolder')))}}
Capture 'NYCTaxi_DWH' 'business' @'
SELECT SourceSRFlag,SharedRequestFlag,COUNT_BIG(*) Rows FROM NYCTaxi_Staging.clean.Trip WHERE TaxiType='FHV' GROUP BY SourceSRFlag,SharedRequestFlag;
SELECT d.IsSharedRide,COUNT_BIG(*) Rows FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_FHVFlags d ON d.FHVFlagKey=f.FHVFlagKey GROUP BY d.IsSharedRide;
SELECT COUNT_BIG(*) DateRows,SUM(CONVERT(bigint,IsHoliday)) HolidayRows FROM dbo.Dim_Date WHERE DateKey<>0;
SELECT SourceDataset,SourceKey,COUNT_BIG(*) Rows,MIN(PickupDateKey) MinDate,MAX(PickupDateKey) MaxDate FROM dbo.Fact_FHV_Trips GROUP BY SourceDataset,SourceKey;
SELECT COUNT_BIG(*) Rows,COUNT_BIG(SourceFileName) WithFileName FROM dbo.Dim_LoadBatch WHERE LoadBatchKey<>0;
SELECT TOP(10) * FROM dbo.Fact_Base_Performance_Snapshot WHERE TotalWAVMatches>TotalWAVRequests ORDER BY TotalWAVMatches DESC;
SELECT t.name TableName,i.name IndexName,i.is_unique,STRING_AGG(CONVERT(nvarchar(max),c.name),',') WITHIN GROUP(ORDER BY ic.index_column_id) Columns FROM sys.tables t JOIN sys.indexes i ON i.object_id=t.object_id JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE t.name LIKE 'Fact[_]%' GROUP BY t.name,i.name,i.is_unique;
SELECT MAX(backup_finish_date) LastBackup,type FROM msdb.dbo.backupset WHERE database_name IN('NYCTaxi_DWH','NYCTaxi_Staging') GROUP BY type;
'@
