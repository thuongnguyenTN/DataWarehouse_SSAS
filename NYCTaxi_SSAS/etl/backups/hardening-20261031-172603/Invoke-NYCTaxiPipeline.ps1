param(
 [ValidateSet('All','Extract','Transform','Dwh','Aggregates','Ssas','Preflight','ResumeCheck')][string]$Stage='All',
 [ValidatePattern('^\d{4}-(0[1-9]|1[0-2])$')][string]$StartMonth='2025-01',
 [ValidatePattern('^\d{4}-(0[1-9]|1[0-2])$')][string]$EndMonth='2025-12',
 [ValidateRange(0,2147483647)][int]$MaxRows=100000,
 [string]$SqlServer='THUONGNGUYEN\MSSQLSV',
 [string]$SsasServer='THUONGNGUYEN\MSSQLSV',
 [string]$PackageRoot='E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL',
 [string]$ScriptsRoot='D:\Kho_Du_lieu\NYCTaxi\script',
 [string]$DataRoot='D:\Kho_Du_lieu\NYCTaxi',
 [string]$PythonExe='C:\Users\ADMIN\AppData\Local\Programs\Python\Python310\python.exe',
 [guid]$RunId=[guid]::NewGuid(),
 [guid]$InvocationId=[guid]::NewGuid(),
 [ValidateSet('Extract','Transform','Dwh','Aggregates','Ssas')][string]$ResumeFrom='Extract',
 [switch]$Offline,
 [switch]$RefreshSource,
 [ValidateSet('None','BeforeTransform','DuringDwh','DuringAggregates')][string]$InjectFailure='None'
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$runFolder=Join-Path $PSScriptRoot ('logs/'+$RunId)
$null=New-Item -ItemType Directory -Path $runFolder -Force
$journal=Join-Path $runFolder 'events.jsonl'
. (Join-Path $PSScriptRoot 'Pipeline.Progress.ps1')
$script:currentTask='Invocation';$script:taskStarted=[datetime]::UtcNow
$script:progressRows=0L;$script:progressTotal=0L;$script:childLabel=$null
$script:lastStatusWrite=[datetime]::MinValue;$script:lastPulse=[datetime]::UtcNow
function Publish-Progress($message='',$force=$false) {
 if(-not $force -and ([datetime]::UtcNow-$script:lastStatusWrite).TotalSeconds -lt 1){return}
 $script:lastStatusWrite=[datetime]::UtcNow
 try{Write-ETLJson (Join-Path $runFolder 'status.json') ([ordered]@{
  RunId="$RunId";InvocationId="$InvocationId";Stage=$script:currentStage;Task=$script:currentTask;
  Status=$script:currentStatus;Message=$message;HeartbeatUtc=[datetime]::UtcNow.ToString('o');
  TaskStartedUtc=$script:taskStarted.ToString('o');Rows=$script:progressRows;TotalRows=$script:progressTotal;
  ChildLabel=$script:childLabel;LogFolder=$runFolder
 })}catch{Write-Warning ('Progress status could not be written: '+$_.Exception.Message)}
}
function Wait-SqlTask($task) {
 while(-not $task.IsCompleted){
  Publish-Progress 'SQL đang thực thi; chưa có phần trăm hoàn tất.'
  if(([datetime]::UtcNow-$script:lastPulse).TotalSeconds -ge 15){Write-Host ("[$($script:currentStage)] $($script:currentTask): SQL vẫn đang xử lý; elapsed="+[int]([datetime]::UtcNow-$script:taskStarted).TotalSeconds+'s');$script:lastPulse=[datetime]::UtcNow}
  Start-Sleep -Milliseconds 300
 }
 return ,$task.GetAwaiter().GetResult()
}
function Get-RunConfigHash {
 $config="$StartMonth|$EndMonth|$MaxRows|$SqlServer|$SsasServer|$DataRoot|$PackageRoot|$ScriptsRoot|$PythonExe|$Offline"
 if($RefreshSource){$config+='|RefreshSource=true'}
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($config)))).Replace('-','')}finally{$sha.Dispose()}
}
function LocalEvent($status,$task,$detail) {
 if($status -eq 'RUNNING'){$script:currentTask=$task;$script:taskStarted=[datetime]::UtcNow;$script:progressRows=0L;$script:progressTotal=0L;$script:childLabel=$null}
 $script:currentStatus=$status
 Write-ETLJournal $runFolder $RunId $script:currentStage $task $status $detail
 Write-Host ("[{0}] [{1}] {2}: {3}" -f (Get-Date -Format 'HH:mm:ss'),$script:currentStage,$status,$task)
 Publish-Progress ([string]$detail) $true
}
function Connect($db) {
 $b=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
 $b['Data Source']=$SqlServer;$b['Initial Catalog']=$db;$b['Integrated Security']=$true;$b['Connect Timeout']=15;$b['Application Name']='NYCTaxi-Pipeline'
 $c=New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString;$c.Open();return $c
}
function Sql($connection,$text,$parameters=@{}) {
 $cmd=$connection.CreateCommand();$cmd.CommandText=$text;$cmd.CommandTimeout=1800
 foreach($key in $parameters.Keys) {
  $p=$cmd.Parameters.Add('@'+$key,[System.Data.SqlDbType]::NVarChar,-1)
  $p.Value=if($null -eq $parameters[$key]){[DBNull]::Value}else{[string]$parameters[$key]}
 }
 try {return Wait-SqlTask ($cmd.ExecuteScalarAsync())} finally {$cmd.Dispose()}
}
function Step($name,[scriptblock]$body) {
 $script:stepId=$null;$script:stepDetail=$null;LocalEvent 'RUNNING' $name ''
 try {
  $script:stepId=Sql $script:control "INSERT etl.PipelineStep(RunId,Stage,TaskName,Status) OUTPUT inserted.StepId VALUES(CONVERT(uniqueidentifier,@r),@s,@n,'RUNNING')" @{r=$RunId;s=$script:currentStage;n=$name}
  & $body
  $null=Sql $script:control "UPDATE etl.PipelineStep SET Status='SUCCEEDED',CompletedAt=SYSUTCDATETIME(),Detail=@detail WHERE StepId=CONVERT(bigint,@id)" @{id=$script:stepId;detail=$script:stepDetail}
  LocalEvent 'SUCCEEDED' $name $script:stepDetail
 } catch {
  $original=$_
  LocalEvent 'FAILED' $name $original.Exception.ToString()
  try {$null=Sql $script:control "UPDATE etl.PipelineStep SET Status='FAILED',CompletedAt=SYSUTCDATETIME(),ErrorMessage=@e,ErrorNumber=TRY_CONVERT(int,@num) WHERE StepId=CONVERT(bigint,@id)" @{id=$script:stepId;e=$original.Exception.ToString();num=$(if($original.Exception.InnerException -is [System.Data.SqlClient.SqlException]){$original.Exception.InnerException.Number}else{$null})}} catch {LocalEvent 'LOG_FAILED' $name $_.Exception.Message}
  throw $original
 }
}
function Native($file,[string[]]$arguments,$label) {
 $info=New-Object System.Diagnostics.ProcessStartInfo
 $info.FileName=$file
 # All arguments are supplied as separate values; escape Windows command-line quotes.
 $info.Arguments=($arguments | ForEach-Object {'"'+[regex]::Replace([regex]::Replace($_,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}) -join ' '
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $process=New-Object System.Diagnostics.Process;$process.StartInfo=$info
 $info.EnvironmentVariables['PYTHONUNBUFFERED']='1';$info.EnvironmentVariables['PYTHONIOENCODING']='utf-8'
 $outputStream=New-Object IO.FileStream((Join-Path $runFolder ($label+'.stdout.log')),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,[IO.FileOptions]::Asynchronous)
 $errorStream=New-Object IO.FileStream((Join-Path $runFolder ($label+'.stderr.log')),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,[IO.FileOptions]::Asynchronous)
 $script:childLabel=$label
 try {
  $null=$process.Start();$out=$process.StandardOutput.BaseStream.CopyToAsync($outputStream);$err=$process.StandardError.BaseStream.CopyToAsync($errorStream)
  while(-not $process.WaitForExit(500)){Publish-Progress ('Tiến trình đang chạy: '+$label)}
  $null=$out.GetAwaiter().GetResult();$null=$err.GetAwaiter().GetResult();$outputStream.Flush();$errorStream.Flush();$outputStream.Dispose();$errorStream.Dispose()
  $stdout=[IO.File]::ReadAllText((Join-Path $runFolder ($label+'.stdout.log')),[Text.Encoding]::UTF8)
  $stderr=[IO.File]::ReadAllText((Join-Path $runFolder ($label+'.stderr.log')),[Text.Encoding]::UTF8)
  if($process.ExitCode -ne 0){throw "Process $label exited $($process.ExitCode): $stderr $stdout"}
  return $stdout.Trim()
 } finally {$outputStream.Dispose();$errorStream.Dispose();$process.Dispose();$script:childLabel=$null}
}
function PackageSql($filename) {
 [xml]$doc=Get-Content (Join-Path $PackageRoot $filename) -Raw
 return ,@($doc.SelectNodes('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"]') | ForEach-Object {
  $data=$_.SelectSingleNode('./*[local-name()="ObjectData"]/*[local-name()="SqlTaskData"]')
  if(-not $data){throw "Unsupported non-SQL task in $filename"}
  [pscustomobject]@{Name=$_.GetAttribute('ObjectName','www.microsoft.com/SqlServer/Dts');Sql=$data.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')}
 })
}
function BulkCsv($connection,$path,$dataset,$table) {
 Add-Type -AssemblyName Microsoft.VisualBasic
 $parser=New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($path,[Text.Encoding]::UTF8)
 $parser.TextFieldType='Delimited';$parser.SetDelimiters(',');$parser.HasFieldsEnclosedInQuotes=$true;$parser.TrimWhiteSpace=$false
 $bulk=$null;$buffer=New-Object System.Data.DataTable
 try {
  $columns=$parser.ReadFields()
  foreach($column in $columns){$null=$buffer.Columns.Add($column,[string])}
  $bulk=New-Object System.Data.SqlClient.SqlBulkCopy $connection
  $bulk.DestinationTableName='wrk.['+$table+']';$bulk.BatchSize=10000;$bulk.BulkCopyTimeout=1800
  foreach($column in $columns){$null=$bulk.ColumnMappings.Add($column,$column)}
  $count=0L
  while(-not $parser.EndOfData){
   $fields=$parser.ReadFields();if($fields.Length -ne $columns.Length){throw "CSV column count mismatch: $path"}
   $row=$buffer.NewRow()
   for($i=0;$i -lt $fields.Length;$i++){$row[$i]=if($fields[$i] -eq ''){[DBNull]::Value}else{$fields[$i]}}
   $null=$buffer.Rows.Add($row);$count++
   if($buffer.Rows.Count -ge 10000){$bulk.WriteToServer($buffer);$buffer.Clear();$script:progressRows=$count;Publish-Progress ('Đã ghi vào wrk: '+$count+' dòng')}
   if($count%1000 -eq 0){Publish-Progress ('Đang đọc CSV: '+$count+' dòng')}
  }
  if($buffer.Rows.Count){$bulk.WriteToServer($buffer)}
  $script:progressRows=$count;Publish-Progress ('Nạp wrk xong; chờ kiểm tra/commit: '+$count+' dòng') $true
  return $count
 } finally {if($bulk){$bulk.Dispose()};$parser.Dispose();$buffer.Dispose()}
}
function Extract {
 if(-not $Offline){Step 'Download' {$downloadArgs=@((Join-Path $ScriptsRoot 'download_nyc_parquet.py'),'--start',$StartMonth,'--end',$EndMonth,'--output',(Join-Path $DataRoot 'raw'),'--lookup');if($RefreshSource){$downloadArgs+='--overwrite'};$null=Native $PythonExe $downloadArgs 'download'}}
 Step 'Convert' {$null=Native $PythonExe @((Join-Path $ScriptsRoot 'convert_nyc_parquet_to_csv.py'),'--input',(Join-Path $DataRoot 'raw'),'--output',(Join-Path $DataRoot 'csv'),'--start',$StartMonth,'--end',$EndMonth,'--max-rows',"$MaxRows",'--schema','ssis','--lookup') 'convert'}
 $c=Connect 'NYCTaxi_Staging'
 try {
  [xml]$doc=Get-Content (Join-Path $PackageRoot 'PKG_01_Extract_Stage.dtsx') -Raw
  $prepare=$doc.SelectSingleNode('//*[local-name()="SqlTaskData"]')
  Step 'PrepareStaging' {$null=Sql $c $prepare.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')}
  $datasets=@{yellow='YellowTrip';green='GreenTrip';fhv='FHVTrip';fhvhv='FHVHVTrip';lookup='TaxiZone'}
  foreach($dataset in @('yellow','green','fhv','fhvhv','lookup')){
   foreach($file in Get-ChildItem (Join-Path $DataRoot ('csv/'+$dataset)) -Filter '*.csv' -Recurse){
    Step ('File:'+ $dataset+':'+$file.Name) {
     try {
     $payload=Native $PythonExe @((Join-Path $ScriptsRoot 'inspect_extract_file.py'),'--dataset',$dataset,'--file',$file.FullName,'--value','ssis','--start',$StartMonth,'--end',$EndMonth,'--row-limit',"$MaxRows") ('inspect-'+$dataset+'-'+$file.BaseName)
     $meta=$payload.Split('|');if($meta[0] -eq '0'){$script:stepDetail='SKIPPED_OUT_OF_RANGE';return}
     if($meta.Count -ne 4){throw 'Invalid inspection output'}
     $params=@{d=$dataset;p=$file.FullName;h=$meta[3];n=$meta[1];l=$meta[2]}
      $already=Sql $c 'EXEC etl.usp_BeginExtractFile @DatasetCode=@d,@FilePath=@p,@FileHash=@h,@ExpectedRows=@n,@RowLimit=@l' $params
      if([int]$already -eq 1){$script:stepDetail='SKIPPED_ALREADY_LOADED'}
      if([int]$already -eq 0){
       $script:progressTotal=[long]$meta[1]
       $count=BulkCsv $c $file.FullName $dataset $datasets[$dataset];$params['r']=$count
       $null=Sql $c 'EXEC etl.usp_CommitExtractFile @DatasetCode=@d,@FilePath=@p,@FileHash=@h,@ExpectedRows=@n,@RowLimit=@l,@RowsLoaded=@r' $params
       $script:stepDetail="LOADED_ROWS=$count"
      }
     } catch {
      $failure=$_
      try {
       $quarantine=Join-Path $DataRoot ('quarantine/'+$RunId+'/'+$dataset)
       $null=New-Item -ItemType Directory -Path $quarantine -Force
       Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $quarantine $file.Name) -Force
       $sidecar=$file.FullName+'.meta.json'
       if(Test-Path -LiteralPath $sidecar){Copy-Item -LiteralPath $sidecar -Destination (Join-Path $quarantine ($file.Name+'.meta.json')) -Force}
       [pscustomobject]@{Source=$file.FullName;RunId="$RunId";Error=$failure.Exception.ToString();Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $quarantine ($file.Name+'.error.json')) -Encoding UTF8
       LocalEvent 'QUARANTINED' $file.Name $quarantine
      } catch {LocalEvent 'QUARANTINE_FAILED' $file.Name $_.Exception.Message}
      try {$null=Sql $c "UPDATE etl.ExtractFileLog SET LoadStatus='FAILED',CompletedAt=SYSDATETIME(),ErrorMessage=LEFT(@e,2000) WHERE DatasetCode=@d AND FilePath=@p AND LoadStatus='LOADING'" @{e=$failure.Exception.ToString();d=$dataset;p=$file.FullName}} catch {LocalEvent 'LOG_FAILED' $file.Name $_.Exception.Message}
      throw $failure
     }
    }
   }
  }
  $validate=$doc.SelectSingleNode('/*[local-name()="Executable"]/*[local-name()="Executables"]/*[local-name()="Executable"][@*[local-name()="ObjectName"]="EST_09_Validate_Staging"]/*[local-name()="ObjectData"]/*[local-name()="SqlTaskData"]')
  if(-not $validate){throw 'Staging validation task missing'}
  $text=$validate.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask')
  foreach($binding in @('@start','@end','@limit')){
   $position=$text.IndexOf('?');if($position -lt 0){throw 'Staging validation parameter mismatch'}
   $text=$text.Substring(0,$position)+$binding+$text.Substring($position+1)
  }
  if($text.Contains('?')){throw 'Unexpected staging validation parameters'}
  Step 'ValidateStaging' {$null=Sql $c $text @{start=$StartMonth;end=$EndMonth;limit=$MaxRows}}
 } finally {$c.Dispose()}
}
function SqlStage($filename,$database) {
 $c=Connect $database
 try {
  foreach($task in (PackageSql $filename)){
   Step $task.Name {
    if($InjectFailure -eq 'DuringDwh' -and $script:currentStage -eq 'Dwh' -and $task.Name -like '*FactFHV*'){throw 'Injected DWH failure'}
    if($filename -eq 'PKG_03_Load_DWH.dtsx'){
     $cmd=$c.CreateCommand();$cmd.CommandText=$task.Sql;$cmd.CommandTimeout=1800
     try{
      $reader=Wait-SqlTask ($cmd.ExecuteReaderAsync());$stats=@()
      try{do{while($reader.Read()){
       $row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}}
       $stats+=[pscustomobject]$row
      }}while($reader.NextResult())}finally{$reader.Close()}
      if($stats.Count){$script:stepDetail=ConvertTo-Json -InputObject @($stats) -Compress -Depth 4}
     }finally{$cmd.Dispose()}
    }else{$null=Sql $c $task.Sql}
   }
  }
 } finally {$c.Dispose()}
}
function Aggregates {
 $c=Connect 'NYCTaxi_DWH'
 try {
  $tasks=PackageSql 'PKG_04_Load_Aggregates.dtsx'
  Step 'AtomicRebuildAndValidateSnapshots' {
   $text=$tasks[0].Sql
   if($InjectFailure -eq 'DuringAggregates'){$text=$text.Replace('COMMIT TRANSACTION; END TRY',"THROW 55999,'Injected aggregate failure',1; COMMIT TRANSACTION; END TRY")}
   $null=Sql $c $text
  }
 } finally {$c.Dispose()}
}
function RefreshSsas {
 Step 'ProcessAndVerifySixCubes' {
  $amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
  $null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
  $null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
  $server=New-Object Microsoft.AnalysisServices.Server
  try {
   $server.Connect($SsasServer);$db=$server.Databases.Find('NYCTaxi_SSAS');if(-not $db){throw 'SSAS database missing; deploy reviewed six-cube model first.'}
   $ds=$db.DataSources.Find('DS_NYCTaxi_DWH');if(-not $ds){throw 'SSAS data source missing'}
   $dsBuilder=New-Object System.Data.OleDb.OleDbConnectionStringBuilder $ds.ConnectionString
   if([string]$dsBuilder['Data Source'] -ne $SqlServer -or [string]$dsBuilder['Initial Catalog'] -ne 'NYCTaxi_DWH'){throw 'SSAS data source does not match pipeline SQL server/database'}
   $expected=(Get-Content (Join-Path $root 'scripts/cube-map.json') -Raw | ConvertFrom-Json).cubes.id
   if($db.Cubes.Count -ne $expected.Count -or @($db.Cubes | Where-Object {$_.ID -notin $expected}).Count){throw 'SSAS is not the six-business-cube model; deploy it first.'}
   $xml='<Batch xmlns="http://schemas.microsoft.com/analysisservices/2003/engine" Transaction="true"><Process><Object><DatabaseID>NYCTaxi_SSAS</DatabaseID></Object><Type>ProcessFull</Type></Process></Batch>'
   $results=$server.Execute($xml)
   foreach($result in $results){foreach($message in $result.Messages){if($message -is [Microsoft.AnalysisServices.XmlaError]){throw $message.Description}}}
   $db.Refresh()
   if($db.State -ne 'Processed'){throw 'SSAS database not fully processed'}
  } finally {if($server.Connected){$server.Disconnect()};$server.Dispose()}
  $null=Native 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'scripts/Verify-Results.ps1'),'-Scope','Full','-SqlServer',$SqlServer,'-SsasServer',$SsasServer) 'sql-mdx-reconciliation'
 }
}
$script:control=$null;$script:ownsRun=$false;$script:currentStage='Preflight';$script:currentStatus='RUNNING'
try {
 if($StartMonth -gt $EndMonth -or [int]$StartMonth.Substring(0,4) -lt 2009){throw "Invalid month range: StartMonth=$StartMonth; EndMonth=$EndMonth. StartMonth must be <= EndMonth and year >= 2009."}
 foreach($path in @($PackageRoot,$ScriptsRoot,$PythonExe,(Join-Path $PSScriptRoot '001-pipeline-control.sql'))){if(-not(Test-Path -LiteralPath $path)){throw "Required path missing: $path"}}
 if($Stage -eq 'Preflight'){
  $c=Connect 'NYCTaxi_Staging';$c.Dispose();$c=Connect 'NYCTaxi_DWH';$c.Dispose()
  $null=Native $PythonExe @('-c','import pyarrow; import lxml') 'python-preflight'
  'Preflight passed (SQL connections, paths, Python dependencies).';exit 0
 }
 if($Stage -eq 'ResumeCheck'){
  $check=Connect 'NYCTaxi_DWH'
  try{
   $stored=Sql $check 'SELECT ConfigHash FROM etl.PipelineRun WHERE RunId=CONVERT(uniqueidentifier,@r)' @{r=$RunId}
   if([string]$stored -ne (Get-RunConfigHash)){throw 'Resume configuration does not match the original run. Keep the same months, row limit, server and paths.'}
   $ordered=@('Extract','Transform','Dwh','Aggregates','Ssas');$pos=[array]::IndexOf($ordered,$ResumeFrom)
   if($pos -gt 0){
    $previous=$ordered[$pos-1]
    $done=Sql $check "SELECT TOP(1) CASE WHEN TaskName='StageComplete' THEN Status ELSE 'INCOMPLETE' END FROM etl.PipelineStep WHERE RunId=CONVERT(uniqueidentifier,@r) AND Stage=@s ORDER BY StepId DESC" @{r=$RunId;s=$previous}
    if($done -ne 'SUCCEEDED'){throw "Cannot resume at $ResumeFrom. Previous stage $previous is not complete."}
   }
   Write-Host "Resume check passed. RunId=$RunId; start=$ResumeFrom";exit 0
  }finally{$check.Dispose()}
 }
 $script:control=Connect 'NYCTaxi_DWH'
 $lock=Sql $script:control "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; SELECT @r;"
 if([int]$lock -lt 0){throw 'Another ETL run holds the database lock'}
 $null=Sql $script:control (Get-Content (Join-Path $PSScriptRoot '001-pipeline-control.sql') -Raw)
 $hash=Get-RunConfigHash
 $null=Sql $script:control "IF EXISTS(SELECT 1 FROM etl.PipelineRun WHERE Status='RUNNING' AND RunId<>CONVERT(uniqueidentifier,@r)) THROW 55900,'Unfinished run exists. Inspect logs and resume the same RunId.',1; IF EXISTS(SELECT 1 FROM etl.PipelineRun WHERE RunId=CONVERT(uniqueidentifier,@r) AND ConfigHash<>@h) THROW 55901,'RunId parameters changed.',1; IF NOT EXISTS(SELECT 1 FROM etl.PipelineRun WHERE RunId=CONVERT(uniqueidentifier,@r)) INSERT etl.PipelineRun(RunId,ConfigHash,StartMonth,EndMonth,RowLimit,Status) VALUES(CONVERT(uniqueidentifier,@r),@h,@s,@e,CONVERT(int,@n),'RUNNING'); ELSE UPDATE etl.PipelineRun SET Status='RUNNING',CompletedAt=NULL,ErrorMessage=NULL WHERE RunId=CONVERT(uniqueidentifier,@r);" @{r=$RunId;h=$hash;s=$StartMonth;e=$EndMonth;n=$MaxRows}
 $script:ownsRun=$true
 $stages=@('Extract','Transform','Dwh','Aggregates','Ssas')
 foreach($next in $(if($Stage -eq 'All'){$stages}else{@($Stage)})){
  $script:currentStage=$next
  if($Stage -ne 'All' -and $next -ne 'Extract'){
   $previous=$stages[[array]::IndexOf($stages,$next)-1]
   $prior=Sql $script:control "SELECT TOP(1) CASE WHEN TaskName='StageComplete' THEN Status ELSE 'INCOMPLETE' END FROM etl.PipelineStep WHERE RunId=CONVERT(uniqueidentifier,@r) AND Stage=@s ORDER BY StepId DESC" @{r=$RunId;s=$previous}
   if($prior -ne 'SUCCEEDED'){throw "Previous stage $previous has not completed for this RunId"}
  }
  $position=[array]::IndexOf($stages,$next)
  for($later=$position+1;$later -lt $stages.Count;$later++){
   $null=Sql $script:control "UPDATE etl.PipelineStep SET Status='INVALIDATED' WHERE RunId=CONVERT(uniqueidentifier,@r) AND Stage=@s AND TaskName='StageComplete' AND Status='SUCCEEDED'" @{r=$RunId;s=$stages[$later]}
   Write-ETLJournal $runFolder $RunId $stages[$later] 'StageComplete' 'INVALIDATED' ('Rerunning '+$next)
  }
  $null=Sql $script:control "INSERT etl.PipelineStep(RunId,Stage,TaskName,Status) VALUES(CONVERT(uniqueidentifier,@r),@s,'StageStarted','RUNNING')" @{r=$RunId;s=$next}
  switch($next){
   Extract {Extract}
   Transform {if($InjectFailure -eq 'BeforeTransform'){throw 'Injected transform failure'};SqlStage 'PKG_02_Transform_Clean.dtsx' 'NYCTaxi_Staging'}
   Dwh {SqlStage 'PKG_03_Load_DWH.dtsx' 'NYCTaxi_DWH'}
   Aggregates {Aggregates}
   Ssas {RefreshSsas}
  }
  $null=Sql $script:control "UPDATE etl.PipelineStep SET Status='SUCCEEDED',CompletedAt=SYSUTCDATETIME() WHERE RunId=CONVERT(uniqueidentifier,@r) AND Stage=@s AND TaskName='StageStarted' AND Status='RUNNING'" @{r=$RunId;s=$next}
  Step 'StageComplete' {}
 }
 if($Stage -in @('All','Ssas')){$null=Sql $script:control "UPDATE etl.PipelineRun SET Status='SUCCEEDED',CompletedAt=SYSUTCDATETIME() WHERE RunId=CONVERT(uniqueidentifier,@r)" @{r=$RunId}}
 if($Stage -in @('All','Ssas')){$alert=Join-Path $PSScriptRoot ("alerts/$RunId.json");if(Test-Path $alert){[pscustomobject]@{RunId="$RunId";Status='RESOLVED';Utc=[datetime]::UtcNow.ToString('o');Logs=$runFolder}|ConvertTo-Json|Set-Content $alert -Encoding UTF8}}
 LocalEvent 'SUCCEEDED' 'Invocation' '';Write-Output "ETL $Stage completed. RunId=$RunId; logs=$runFolder"
} catch {
 $failure=$_;LocalEvent 'FAILED' 'Invocation' $failure.Exception.ToString()
 $rootError=Get-ETLRootError $failure
 Write-ETLJson (Join-Path $runFolder ('failure-'+$Stage+'.json')) ([ordered]@{InvocationId="$InvocationId";RunId="$RunId";Stage=$script:currentStage;Task=$script:currentTask;Message=$rootError.Message;SqlNumber=$rootError.SqlNumber;Retryable=$rootError.Retryable;Logs=$runFolder;Utc=[datetime]::UtcNow.ToString('o')})
 $alertFolder=Join-Path $PSScriptRoot 'alerts';$null=New-Item -ItemType Directory -Path $alertFolder -Force
 [pscustomobject]@{RunId="$RunId";Status='FAILED';Stage=$script:currentStage;Error=$failure.Exception.ToString();Logs=$runFolder;Utc=[datetime]::UtcNow.ToString('o')} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $alertFolder ("$RunId.json")) -Encoding UTF8
 if($script:ownsRun -and $script:control -and $script:control.State -eq 'Open'){
  try {$null=Sql $script:control "UPDATE etl.PipelineStep SET Status='FAILED',CompletedAt=SYSUTCDATETIME(),ErrorMessage=@e WHERE RunId=CONVERT(uniqueidentifier,@r) AND Status='RUNNING'; UPDATE etl.PipelineRun SET Status='FAILED',CompletedAt=SYSUTCDATETIME(),ErrorMessage=@e WHERE RunId=CONVERT(uniqueidentifier,@r)" @{r=$RunId;e=$failure.Exception.ToString()}} catch {LocalEvent 'LOG_FAILED' 'Invocation' $_.Exception.Message}
 }
 Write-Error -ErrorAction Continue "ETL FAILED. RunId=$RunId. $($failure.Exception.Message). Logs=$runFolder";exit 1
} finally {if($script:control){$script:control.Dispose()}}


