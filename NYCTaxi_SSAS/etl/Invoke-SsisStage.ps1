param(
 [ValidateSet('Monitor','Stage','Complete')][string]$Operation='Stage',
 [ValidateSet('Extract','Transform','Dwh','Aggregates','Ssas')][string]$Stage='Extract',
 [ValidateSet('Extract','Transform','Dwh','Aggregates','Ssas')][string]$StartAt='Extract',
 [Parameter(Mandatory=$true)][guid]$RunId,
 [string]$StartMonth='2025-01',[string]$EndMonth='2025-12',[int]$MaxRows=100000,
 [ValidateRange(0,3)][int]$MaxRetries=1,
 [ValidateRange(0,1)][int]$ShowMonitor=1,
 [string]$RunnerPath='',
 [string]$LogRoot=''
)
$ErrorActionPreference='Stop'
if(-not $PSScriptRoot){$PSScriptRoot=Split-Path -Parent $MyInvocation.MyCommand.Path}
if(-not $RunnerPath){$RunnerPath=Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1'}
if(-not $LogRoot){$LogRoot=Join-Path $PSScriptRoot 'logs'}
$OutputEncoding=New-Object Text.UTF8Encoding($false);[Console]::OutputEncoding=$OutputEncoding
. (Join-Path $PSScriptRoot 'Pipeline.Progress.ps1')
if(-not ('PipelineJob' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ProcessLifetime.cs')}
$folder=Join-Path $LogRoot $RunId.ToString();$null=New-Item -ItemType Directory -Path $folder -Force
$stages=@('Extract','Transform','Dwh','Aggregates','Ssas')
$displayStage=if($Operation -eq 'Complete'){'Master'}else{$Stage}
function Event($state,$task,$message){
 Write-ETLJournal $folder $RunId $displayStage $task $state $message
 Write-Host ("[$displayStage] $state - $task - $message")
}
function Status($state,$task,$message){
 Write-ETLJson (Join-Path $folder 'status.json') ([ordered]@{RunId="$RunId";Stage=$displayStage;Task=$task;Status=$state;Message=$message;HeartbeatUtc=[datetime]::UtcNow.ToString('o');TaskStartedUtc=[datetime]::UtcNow.ToString('o');Rows=0;TotalRows=0;LogFolder=$folder})
}
function Quote([string]$value){'"'+[regex]::Replace([regex]::Replace($value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Invoke-Runner([string]$requested,[guid]$invocation,[string]$label){
 $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$RunnerPath,'-Stage',$requested,'-StartMonth',$StartMonth,'-EndMonth',$EndMonth,'-MaxRows',"$MaxRows",'-RunId',"$RunId",'-InvocationId',"$invocation",'-ResumeFrom',$StartAt)
 $psi=New-Object Diagnostics.ProcessStartInfo
 $psi.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $psi.Arguments=($arguments|ForEach-Object {Quote $_}) -join ' '
 $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 $psi.EnvironmentVariables['PYTHONUNBUFFERED']='1';$psi.EnvironmentVariables['PYTHONIOENCODING']='utf-8'
 $o=New-Object IO.FileStream((Join-Path $folder ($label+'.stdout.log')),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,[IO.FileOptions]::Asynchronous)
 $e=New-Object IO.FileStream((Join-Path $folder ($label+'.stderr.log')),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,[IO.FileOptions]::Asynchronous)
 $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
 $job=New-Object PipelineJob
 try{
  $null=$p.Start();try{$job.Attach($p.Handle)}catch{if(-not $p.HasExited){$p.Kill()};throw};$ot=$p.StandardOutput.BaseStream.CopyToAsync($o);$et=$p.StandardError.BaseStream.CopyToAsync($e)
  $p.WaitForExit();$null=$ot.GetAwaiter().GetResult();$null=$et.GetAwaiter().GetResult();$o.Dispose();$e.Dispose()
  [pscustomobject]@{ExitCode=$p.ExitCode;Stderr=[IO.File]::ReadAllText((Join-Path $folder ($label+'.stderr.log')),[Text.Encoding]::UTF8)}
 }finally{$job.Dispose();$o.Dispose();$e.Dispose();$p.Dispose()}
}
try{
 if($Operation -eq 'Monitor'){
  if($ShowMonitor -eq 1){
   $exe=Join-Path $PSScriptRoot 'monitor/NYCTaxi ETL Monitor.exe'
   if(Test-Path -LiteralPath $exe){
    Start-Process -FilePath $exe -ArgumentList ('--run-id '+$RunId+' --log-root '+(Quote $LogRoot)) -WindowStyle Normal|Out-Null
    Event 'INFO' 'Monitor' 'Cửa sổ theo dõi đã mở; đóng cửa sổ này không dừng ETL.'
   }else{Event 'WARNING' 'Monitor' ('Không tìm thấy monitor: '+$exe+'; xem log trong '+$folder)}
  }
  exit 0
 }
 if($Operation -eq 'Complete'){
  $c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
  try{$c.Open();$q=$c.CreateCommand();$q.CommandTimeout=15;$q.CommandText='SELECT Status FROM etl.PipelineRun WHERE RunId=@r';$null=$q.Parameters.AddWithValue('@r',$RunId);$state=$q.ExecuteScalar();if($state -ne 'SUCCEEDED'){throw 'Master cannot finish: SSAS/verification has not marked this run SUCCEEDED.'}}finally{$c.Dispose()}
  Event 'SUCCEEDED' 'MasterComplete' 'Toàn luồng đã hoàn tất và đối soát thành công.';Status 'SUCCEEDED' 'MasterComplete' 'Toàn luồng hoàn tất.';exit 0
 }
 if([array]::IndexOf($stages,$Stage) -lt [array]::IndexOf($stages,$StartAt)){
  $resume=Invoke-Runner 'ResumeCheck' ([guid]::NewGuid()) ('resume-check-'+$Stage)
  if($resume.ExitCode -ne 0){throw ('Không thể bỏ qua stage trước: '+$resume.Stderr)}
  Event 'SKIPPED' 'ResumeCheckpoint' ('Đã xác nhận checkpoint/cấu hình. Tiếp tục từ '+$StartAt)
  exit 0
 }
 for($attempt=0;$attempt -le $MaxRetries;$attempt++){
  $invocation=[guid]::NewGuid();Event 'RUNNING' 'StageAttempt' ('Lần thử '+($attempt+1));Status 'RUNNING' 'StageAttempt' ('Lần thử '+($attempt+1))
  $result=Invoke-Runner $Stage $invocation ('controller-'+$Stage+'-attempt'+($attempt+1))
  if($result.ExitCode -eq 0){Event 'INFO' 'StageReturned' 'Runner hoàn tất stage.';exit 0}
  $failure=$null;$file=Join-Path $folder ('failure-'+$Stage+'.json')
  if(Test-Path -LiteralPath $file){try{$candidate=Get-Content $file -Raw -Encoding UTF8|ConvertFrom-Json;if($candidate.InvocationId -eq "$invocation"){$failure=$candidate}}catch{}}
  if($failure -and $failure.Retryable -and $attempt -lt $MaxRetries){
   Event 'RETRYING' $failure.Task ('SQL tạm thời '+$failure.SqlNumber+': '+$failure.Message+'; thử lại sau 5 giây.')
   Status 'RETRYING' $failure.Task $failure.Message
   Start-Sleep -Seconds 5;continue
  }
  $task=if($failure){$failure.Task}else{'StartRunner'}
  $message=if($failure){$failure.Message}else{$result.Stderr.Trim()}
  if($message -match 'Unfinished run exists'){
   $lookup=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
   try{
    $lookup.Open();$query=$lookup.CreateCommand();$query.CommandTimeout=10
    $query.CommandText="SELECT TOP(1) CONVERT(nvarchar(36),RunId)+'|'+StartMonth+'|'+EndMonth+'|'+CONVERT(nvarchar(12),RowLimit) FROM etl.PipelineRun WHERE Status='RUNNING' ORDER BY StartedAt"
    $blocking=[string]$query.ExecuteScalar()
    if($blocking){
     $parts=$blocking.Split('|');$resumeStage='Extract'
     foreach($s in $stages){
      $query.Parameters.Clear();$query.CommandText="SELECT TOP(1) CASE WHEN TaskName='StageComplete' THEN Status ELSE 'INCOMPLETE' END FROM etl.PipelineStep WHERE RunId=@r AND Stage=@s ORDER BY StepId DESC"
      $null=$query.Parameters.AddWithValue('@r',[guid]$parts[0]);$null=$query.Parameters.AddWithValue('@s',$s)
      if($query.ExecuteScalar() -ne 'SUCCEEDED'){$resumeStage=$s;break}
      $resumeStage=$s
     }
     $message+=' ResumeRunId='+$parts[0]+'; ResumeFrom='+$resumeStage+'; StartMonth='+$parts[1]+'; EndMonth='+$parts[2]+'; MaxRows='+$parts[3]+'.'
    }
   }catch{$message+=' Cannot read the blocking run; inspect PipelineRun before resuming.'}finally{$lookup.Dispose()}
  }
  if(-not $message){$message='Runner exited with code '+$result.ExitCode}
  $summary="Stage=$Stage; Task=$task; Error=$message; RunId=$RunId; Logs=$folder"
  if($summary.Length -gt 3400){$summary=$summary.Substring(0,3400)}
  Event 'FAILED' $task $message;Status 'FAILED' $task $message
  Write-ETLJson (Join-Path $folder 'master-error.json') ([ordered]@{RunId="$RunId";Stage=$Stage;Task=$task;Message=$message;Summary=$summary;Logs=$folder;ResumeFrom=$Stage;Retryable=($failure -and $failure.Retryable)})
  [Console]::Error.WriteLine($summary);exit 1
 }
}catch{
 $message=$_.Exception.Message;$summary="Stage=$displayStage; Error=$message; RunId=$RunId; Logs=$folder"
 if($summary.Length -gt 3400){$summary=$summary.Substring(0,3400)}
 Event 'FAILED' 'MasterController' $message;Status 'FAILED' 'MasterController' $message
 Write-ETLJson (Join-Path $folder 'master-error.json') ([ordered]@{RunId="$RunId";Stage=$displayStage;Task='MasterController';Message=$message;Summary=$summary;Logs=$folder;ResumeFrom=$StartAt;Retryable=$false})
 [Console]::Error.WriteLine($summary);exit 1
}
