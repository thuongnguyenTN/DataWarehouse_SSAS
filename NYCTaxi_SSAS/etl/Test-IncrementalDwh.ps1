param([string]$Suffix=(Get-Date -Format 'yyyyMMddHHmmss'))
$ErrorActionPreference='Stop'
if($Suffix -notmatch '^\d{8,14}$'){throw 'Numeric fixture suffix required'}
$dw='NYCTaxi_DWH_IncTest_'+$Suffix;$stage='NYCTaxi_Staging_IncTest_'+$Suffix
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=master;Integrated Security=True;Connect Timeout=15';$c.Open()
$checks=New-Object 'System.Collections.Generic.List[object]'
function Exec($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=1800;try{return $cmd.ExecuteScalar()}finally{$cmd.Dispose()}}
function Assert($name,$condition){if(-not $condition){throw ('FAIL: '+$name)};$checks.Add([pscustomobject]@{Test=$name;Passed=$true});Write-Output ('PASS: '+$name)}
function Clone($from,$schema,$table,$to,$empty){
 $top=if($empty){'TOP(0)'}else{''}
 $null=Exec "SELECT $top * INTO [$to].[$schema].[$table] FROM [$from].[$schema].[$table];"
 $sql="SELECT 'ALTER TABLE [$to].[$schema].[$table] ADD DEFAULT '+D.definition+' FOR '+QUOTENAME(C.name)+';' FROM [$from].sys.default_constraints D JOIN [$from].sys.columns C ON C.object_id=D.parent_object_id AND C.column_id=D.parent_column_id JOIN [$from].sys.tables T ON T.object_id=C.object_id JOIN [$from].sys.schemas S ON S.schema_id=T.schema_id WHERE S.name='$schema' AND T.name='$table';"
 $cmd=$c.CreateCommand();$cmd.CommandText=$sql;$reader=$cmd.ExecuteReader();$defs=@();try{while($reader.Read()){$defs+=$reader.GetString(0)}}finally{$reader.Close();$cmd.Dispose()}
 foreach($definition in $defs){$null=Exec $definition}
}
try{
 $null=Exec "IF DB_ID('$dw') IS NOT NULL OR DB_ID('$stage') IS NOT NULL THROW 55970,'Fixture DB already exists; choose a new suffix.',1; CREATE DATABASE [$dw]; CREATE DATABASE [$stage];"
 $null=Exec "EXEC [$stage].sys.sp_executesql N'CREATE SCHEMA clean'; EXEC [$stage].sys.sp_executesql N'CREATE SCHEMA etl'; EXEC [$dw].sys.sp_executesql N'CREATE SCHEMA etl';"
 $cmd=$c.CreateCommand();$cmd.CommandText="SELECT name FROM NYCTaxi_DWH.sys.tables WHERE name LIKE 'Dim[_]%'";$reader=$cmd.ExecuteReader();$dims=@();try{while($reader.Read()){$dims+=$reader.GetString(0)}}finally{$reader.Close();$cmd.Dispose()}
 foreach($table in $dims){Clone 'NYCTaxi_DWH' 'dbo' $table $dw $false}
 foreach($table in @('Fact_YellowGreen_Trips','Fact_FHV_Trips','Fact_HVFHV_Trips')){Clone 'NYCTaxi_DWH' 'dbo' $table $dw $true}
 Clone 'NYCTaxi_Staging' 'clean' 'Trip' $stage $true
 Clone 'NYCTaxi_Staging' 'clean' 'TaxiZone' $stage $false
 foreach($table in @('ExtractFileLog','TransformFileLog')){Clone 'NYCTaxi_Staging' 'etl' $table $stage $true}
 $c.ChangeDatabase($stage);$null=Exec 'CREATE VIEW clean.ValidTrip AS SELECT * FROM clean.Trip WHERE IsCoreValid=1;'
 # Make three identical FHV business rows: two in file A and one in file B.
 $cols=Exec "SELECT STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),',') WITHIN GROUP(ORDER BY column_id) FROM sys.columns WHERE object_id=OBJECT_ID('clean.Trip') AND is_identity=0;"
 foreach($type in @('YELLOW','GREEN','FHV','FHVHV')){
  $copies=if($type -eq 'FHV'){3}else{1}
  for($i=0;$i -lt $copies;$i++){
   $source=if($type -eq 'FHV' -and $i -eq 2){'fhv_B.csv'}else{$type.ToLower()+'_A.csv'}
   $null=Exec "INSERT clean.Trip($cols) SELECT TOP(1) $cols FROM NYCTaxi_Staging.clean.Trip WHERE TaxiType='$type' AND IsCoreValid=1 ORDER BY TripCleanID; UPDATE clean.Trip SET ETLSourceKey=N'$source',ETLFileHash=REPLICATE('A',64) WHERE TripCleanID=SCOPE_IDENTITY();"
  }
 }
 $null=Exec @'
INSERT etl.ExtractFileLog(DatasetCode,SourceKey,FilePath,FileHash,RowLimit,ExpectedRows,RowsLoaded,LoadStatus,StartedAt,CompletedAt)
 SELECT LOWER(TaxiType),ETLSourceKey,ETLSourceKey,REPLICATE('A',64),0,COUNT_BIG(*),COUNT_BIG(*),'SUCCEEDED',SYSUTCDATETIME(),SYSUTCDATETIME()
 FROM clean.Trip GROUP BY TaxiType,ETLSourceKey;
INSERT etl.TransformFileLog(DatasetCode,SourceKey,FileHash,RuleVersion,ZoneHash,SourceRows,CleanRows,ValidRows,RejectedRows,WarningRows,CompletedAt)
 SELECT DatasetCode,SourceKey,FileHash,'fixture_v1',REPLICATE('B',64),ExpectedRows,ExpectedRows,ExpectedRows,0,0,SYSUTCDATETIME() FROM etl.ExtractFileLog;
CREATE INDEX IX_CleanTrip_Source ON clean.Trip(TaxiType,ETLSourceKey) INCLUDE(ETLFileHash,IsCoreValid);
INSERT etl.ExtractFileLog(DatasetCode,SourceKey,FilePath,FileHash,RowLimit,ExpectedRows,RowsLoaded,LoadStatus,StartedAt,CompletedAt)
 VALUES('lookup','taxi_zone_lookup.csv','taxi_zone_lookup.csv',REPLICATE('C',64),0,265,265,'SUCCEEDED',SYSUTCDATETIME(),SYSUTCDATETIME());
INSERT etl.TransformFileLog(DatasetCode,SourceKey,FileHash,RuleVersion,ZoneHash,SourceRows,CleanRows,ValidRows,RejectedRows,WarningRows,CompletedAt)
 VALUES('lookup','taxi_zone_lookup.csv',REPLICATE('C',64),'fixture_v1',REPLICATE('B',64),265,265,265,0,0,SYSUTCDATETIME());
'@
 $c.ChangeDatabase($dw)
 [xml]$package=Get-Content (Join-Path $PSScriptRoot 'packages/PKG_03_Load_DWH.dtsx') -Raw
 $tasks=@{}
 foreach($task in $package.SelectNodes('/*[local-name()="Executable"]/*[local-name()="Executables"]/*')){
  $name=$task.GetAttribute('ObjectName','www.microsoft.com/SqlServer/Dts')
  $node=$task.SelectSingleNode('.//*[local-name()="SqlTaskData"]')
  $tasks[$name]=$node.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask').Replace('NYCTaxi_Staging',$stage).Replace('NYCTaxi_DWH',$dw)
 }
 $null=Exec $tasks['EST_00_Precheck_DWH']
 Assert 'Taxi zone lookup is excluded from Fact checkpoint planning' ((Exec "SELECT COUNT(*) FROM etl.DwhSourceState WHERE DatasetCode='lookup'") -eq 0)
 $null=Exec $tasks['EST_01_Load_Dimensions']
 foreach($name in @('EST_02_Load_FactYellowGreen','EST_03_Load_FactFHV','EST_04_Load_FactHVFHV')){$null=Exec $tasks[$name]}
 $null=Exec $tasks['EST_05_Validate_DWH']
 Assert 'Initial load creates five file checkpoints across all services' ((Exec 'SELECT COUNT(*) FROM etl.DwhFileLog WHERE Status=''SUCCEEDED''') -eq 5)
 Assert 'Duplicate payload within and across files is preserved' ((Exec 'SELECT COUNT(*) FROM dbo.Fact_FHV_Trips') -eq 3)
 $null=Exec "DECLARE @LastId bigint=(SELECT MAX(TripCleanID) FROM [$stage].clean.Trip); WITH N AS(SELECT TOP(1000) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM sys.all_objects A CROSS JOIN sys.all_objects B) INSERT [$stage].clean.Trip($cols) SELECT $cols FROM [$stage].clean.Trip C CROSS JOIN N WHERE C.TripCleanID=(SELECT MIN(TripCleanID) FROM [$stage].clean.Trip WHERE TaxiType='FHV'); UPDATE [$stage].clean.Trip SET ETLSourceKey='fhv_C.csv' WHERE TripCleanID>@LastId; INSERT [$stage].etl.ExtractFileLog SELECT 'fhv','fhv_C.csv','fhv_C.csv',FileHash,0,1000,1000,'SUCCEEDED',SYSUTCDATETIME(),SYSUTCDATETIME(),NULL FROM [$stage].etl.ExtractFileLog WHERE SourceKey='fhv_B.csv'; INSERT [$stage].etl.TransformFileLog SELECT 'fhv','fhv_C.csv',FileHash,RuleVersion,ZoneHash,1000,1000,1000,0,0,SYSUTCDATETIME() FROM [$stage].etl.TransformFileLog WHERE SourceKey='fhv_B.csv';"
 Assert 'New 1000-row file scopes dimension input to one pending file' ((Exec $tasks['EST_01_Load_Dimensions']) -eq 1)
 $timer=[Diagnostics.Stopwatch]::StartNew()
 Assert 'New 1000-row file processes one file only' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 1)
 $timer.Stop();$newFileMs=$timer.ElapsedMilliseconds
 Assert 'New file preserves 1000 identical business rows' ((Exec "SELECT COUNT(*) FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_C.csv'") -eq 1000)
 $bKey=Exec "SELECT TripKey FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_B.csv'"
 Assert 'Unchanged rerun processes zero files' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 0)
 $null=Exec "UPDATE [$stage].clean.Trip SET TripDurationSeconds=TripDurationSeconds+1 WHERE TaxiType='FHV' AND ETLSourceKey='fhv_A.csv'; UPDATE [$stage].clean.Trip SET IsCoreValid=0 WHERE TripCleanID=(SELECT MIN(TripCleanID) FROM [$stage].clean.Trip WHERE ETLSourceKey='fhv_A.csv'); UPDATE [$stage].etl.TransformFileLog SET ValidRows=1,RejectedRows=1,CompletedAt=DATEADD(second,1,CompletedAt) WHERE SourceKey='fhv_A.csv';"
 Assert 'Correction processes only the changed historical file' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 1)
 Assert 'Unrelated duplicate file retains its Fact key' ((Exec "SELECT TripKey FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_B.csv'") -eq $bKey)
 Assert 'Rejected historical row removed and audit retained' ((Exec "SELECT COUNT(*) FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_A.csv'") -eq 1 -and (Exec 'SELECT COUNT(*) FROM etl.FactChangeAudit') -ge 2)
 Assert 'Corrected duration matches valid Clean payload' ((Exec "SELECT SUM(TripDurationSeconds) FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_A.csv'") -eq (Exec "SELECT SUM(TripDurationSeconds) FROM [$stage].clean.ValidTrip WHERE ETLSourceKey='fhv_A.csv'"))
 $null=Exec "UPDATE [$stage].clean.Trip SET IsCoreValid=0 WHERE ETLSourceKey='fhv_A.csv'; UPDATE [$stage].etl.TransformFileLog SET ValidRows=0,RejectedRows=2,CompletedAt=DATEADD(second,1,CompletedAt) WHERE SourceKey='fhv_A.csv';"
 $null=Exec $tasks['EST_03_Load_FactFHV']
 Assert 'Zero-valid-row file removes old facts and checkpoints zero' ((Exec "SELECT FactRows FROM etl.DwhFileLog WHERE SourceKey='fhv_A.csv'") -eq 0)
 $null=Exec "UPDATE [$stage].clean.Trip SET TripDurationSeconds=TripDurationSeconds+5 WHERE ETLSourceKey='fhv_B.csv'; UPDATE [$stage].etl.TransformFileLog SET CompletedAt=DATEADD(second,1,CompletedAt) WHERE SourceKey='fhv_B.csv'; EXEC sys.sp_set_session_context @key=N'NYCTaxiFailAfterFactWrite',@value=1;"
 $failed=$false;try{$null=Exec $tasks['EST_03_Load_FactFHV']}catch{$failed=$true}
 $null=Exec "EXEC sys.sp_set_session_context @key=N'NYCTaxiFailAfterFactWrite',@value=NULL;"
 Assert 'Injected failure rolls back Fact writes' ($failed -and (Exec "SELECT TripKey FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_B.csv'") -eq $bKey)
 Assert 'Failed file is logged and retried' ((Exec "SELECT Status FROM etl.DwhFileLog WHERE SourceKey='fhv_B.csv'") -eq 'FAILED' -and (Exec $tasks['EST_03_Load_FactFHV']) -eq 1)
 Assert 'Retry completion becomes a no-op checkpoint' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 0)
 $null=Exec "UPDATE [$stage].clean.Trip SET PULocationID=909090 WHERE ETLSourceKey='fhv_B.csv'; UPDATE [$stage].etl.TransformFileLog SET CompletedAt=DATEADD(second,1,CompletedAt) WHERE SourceKey='fhv_B.csv';"
 $null=Exec $tasks['EST_03_Load_FactFHV']
 Assert 'Missing non-null location is tracked for remapping' (((Exec "SELECT UnknownMask FROM etl.DwhFileLog WHERE SourceKey='fhv_B.csv'") -band 1) -eq 1)
 $null=Exec "INSERT dbo.Dim_Location(LocationID,Borough,ZoneName,ServiceZone) VALUES(909090,N'Fixture',N'Fixture zone',N'Fixture');"
 Assert 'New dimension mapping reprocesses affected Unknown file' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 1 -and (Exec "SELECT PickupLocationKey FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_B.csv'") -ne 0)
 $null=Exec "UPDATE dbo.Dim_Location SET ZoneName=N'Renamed fixture' WHERE LocationID=909090;"
 Assert 'SCD1 label change does not reload Fact' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 0)
 $null=Exec "UPDATE etl.DwhFileLog SET ForceReload=1 WHERE SourceKey='fhv_B.csv';"
 Assert 'Explicit force request reloads one file' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 1)
 $bAfter=Exec "SELECT TripKey FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_B.csv'"
 $sumC=Exec "SELECT SUM(TripDurationSeconds) FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_C.csv'"
 $null=Exec "UPDATE dbo.Fact_FHV_Trips SET RecordHash=HASHBYTES('SHA2_256',CONCAT('legacy-fixture-',TripKey)) WHERE SourceKey='fhv_C.csv'; DELETE etl.DwhFileLog WHERE SourceKey='fhv_C.csv';"
 Assert 'Legacy hash adoption touches only uncheckpointed file' ((Exec $tasks['EST_03_Load_FactFHV']) -eq 1 -and (Exec "SELECT TripKey FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_B.csv'") -eq $bAfter)
 Assert 'Legacy hash adoption preserves counts and business total' ((Exec "SELECT COUNT(*) FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_C.csv'") -eq 1000 -and (Exec "SELECT SUM(TripDurationSeconds) FROM dbo.Fact_FHV_Trips WHERE SourceKey='fhv_C.csv'") -eq $sumC)
 $null=Exec $tasks['EST_05_Validate_DWH']
 Assert 'Final file coverage validation passes' $true
 [pscustomobject]@{Passed=$true;DwhDatabase=$dw;StagingDatabase=$stage;NewFile1000RowsMilliseconds=$newFileMs;Checks=@($checks.ToArray());ProductionDataModified=$false}|ConvertTo-Json -Depth 7|Set-Content (Join-Path $PSScriptRoot 'incremental-tests.json') -Encoding UTF8
}finally{$c.Dispose()}
