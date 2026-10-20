$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
$null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
$server=New-Object Microsoft.AnalysisServices.Server;$server.Connect('THUONGNGUYEN\MSSQLSV')
try {
 $db=$server.Databases.Find('NYCTaxi_SSAS');$cube=$db.Cubes.Find('DSV_NYCTaxi')
 $partitions=@(foreach($g in $cube.MeasureGroups){foreach($p in $g.Partitions){[pscustomobject]@{Group=$g.ID;Partition=$p.ID;State=[string]$p.State;LastProcessed=$p.LastProcessed}}})
 $status=[pscustomobject]@{CapturedAt=(Get-Date -Format s);Server=$server.Name;ServerMode=[string]$server.ServerMode;Edition=[string]$server.Edition;Database=$db.ID;DatabaseState=[string]$db.State;Cube=$cube.Name;CubeState=[string]$cube.State;DimensionCount=$db.Dimensions.Count;MeasureGroups=$cube.MeasureGroups.Count;PartitionCount=$partitions.Count;Dimensions=@($db.Dimensions|Select-Object ID,@{n='State';e={[string]$_.State}});Partitions=$partitions}
 $status|ConvertTo-Json -Depth 8|Set-Content (Join-Path $root 'evidence/final-status.json') -Encoding UTF8
 if($db.State -ne 'Processed' -or @($partitions|Where-Object State -ne 'Processed').Count){throw 'Some SSAS objects are not fully processed.'}
 Write-Output "Confirmed: $($db.State); $($db.Dimensions.Count) dimensions, $($cube.MeasureGroups.Count) groups, $($partitions.Count) processed partitions. Edition=$($server.Edition)."
} finally {$server.Disconnect()}
$connection=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection 'Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS'
$connection.Open()
try {
 $text=Get-Content (Join-Path $root 'queries/smoke.mdx') -Raw
 $results=@(foreach($query in $text.Split(';')) {
  if([string]::IsNullOrWhiteSpace($query)){continue}
  $cmd=$connection.CreateCommand();$cmd.CommandText=$query;$cmd.CommandTimeout=120
  $cs=$cmd.ExecuteCellSet()
  [pscustomobject]@{Query=$query.Trim();Cells=$cs.Cells.Count;Passed=$true}
 })
 $results|Export-Csv (Join-Path $root 'evidence/browse-checks.csv') -NoTypeInformation -Encoding UTF8
 Write-Output "Browse MDX: $($results.Count) queries passed."
} finally {$connection.Close()}
