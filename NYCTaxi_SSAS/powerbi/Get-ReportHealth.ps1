param([switch]$Save)
$ErrorActionPreference='Stop'
$OutputEncoding=New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding=$OutputEncoding
$config=Get-Content (Join-Path $PSScriptRoot 'report-index.json') -Raw -Encoding UTF8|ConvertFrom-Json
$rows=New-Object 'System.Collections.Generic.List[object]'
$reachable=$false;$databaseState='Unknown';$errorText=$null;$server=$null
try{
 $amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
 $null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
 $null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
 $server=New-Object Microsoft.AnalysisServices.Server
 $server.Connect('THUONGNGUYEN\MSSQLSV');$reachable=$true
 $db=$server.Databases.Find('NYCTaxi_SSAS')
 if(-not $db){throw 'Database NYCTaxi_SSAS does not exist on this SSAS instance.'}
 $databaseState=[string]$db.State
 foreach($r in $config){
  $path=Join-Path $PSScriptRoot $r.path
  $ref=Join-Path (Split-Path $path) ($r.cube+'.SemanticModel/modelReference.json')
  $valid=$false;$configError=$null;$queryError=$null;$probePassed=$false
  try{
   $m=Get-Content $ref -Raw -Encoding UTF8|ConvertFrom-Json
   $b=New-Object Data.OleDb.OleDbConnectionStringBuilder $m.connectionString
   $valid=($m.connectionType -eq 'analysisServicesDatabaseLive' -and $m.isMultiDimentional -eq $true -and [string]$b['Data Source'] -eq 'THUONGNGUYEN\MSSQLSV' -and [string]$b['Initial Catalog'] -eq 'NYCTaxi_SSAS' -and [string]$b['Cube'] -eq $r.title)
   if(-not $valid){$configError='Live connection reference does not match the expected server/database/cube.'}
  }catch{$configError=$_.Exception.Message}
  $cube=$db.Cubes.Find($r.cube)
  $state=if($cube){[string]$cube.State}else{'Missing'}
  if($valid -and $state -eq 'Processed'){
   $olap=$null
   try{
    $null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
    $olap=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection $m.connectionString
    $olap.Open();$q=$olap.CreateCommand();$q.CommandTimeout=15
    $q.CommandText='EVALUATE ROW("ConnectionTest",1)';$reader=$q.ExecuteReader()
    try{$probePassed=$reader.Read() -and [Convert]::ToInt64($reader.GetValue(0)) -eq 1}finally{$reader.Close()}
   }catch{$queryError=$_.Exception.Message}finally{if($olap){$olap.Dispose()}}
  }
  $rows.Add([pscustomobject]@{Cube=$r.cube;Title=$r.title;State=$state;ConfigValid=$valid;ConfigError=$configError;ProbePassed=$probePassed;QueryError=$queryError;ReportExists=(Test-Path -LiteralPath $path)})
 }
}catch{$errorText=$_.Exception.Message}finally{if($server -and $server.Connected){$server.Disconnect()};if($server){$server.Dispose()}}
$result=[pscustomobject]@{CheckedAt=(Get-Date).ToString('o');Server='THUONGNGUYEN\MSSQLSV';Database='NYCTaxi_SSAS';ServerReachable=$reachable;DatabaseState=$databaseState;Error=$errorText;Reports=@($rows.ToArray())}
$json=$result|ConvertTo-Json -Depth 6
if($Save){$json|Set-Content (Join-Path $PSScriptRoot 'connection-health.json') -Encoding UTF8}
$json
