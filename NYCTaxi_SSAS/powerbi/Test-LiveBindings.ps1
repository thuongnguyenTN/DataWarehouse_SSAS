$ErrorActionPreference='Stop'
$null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
$bindings=Get-Content (Join-Path $PSScriptRoot 'field-bindings.json') -Raw|ConvertFrom-Json
$results=New-Object 'System.Collections.Generic.List[object]'
$map=(Get-Content (Join-Path $PSScriptRoot '../scripts/cube-map.json') -Raw|ConvertFrom-Json).cubes
foreach($cube in $map){
 $c=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection ("Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS;Cube="+$cube.name)
 $c.Open()
 try{
  $group=$bindings|Where-Object cube -eq $cube.id|Sort-Object table,property,measure -Unique
  foreach($f in $group){
   $prop=$f.property.Replace(']',']]');$table=$f.table.Replace("'","''")
   $columns=@("'"+$table+"'"+'['+$prop+']')
   foreach($key in $f.groupBy){$columns+=("'"+$table+"'"+'['+$key.Replace(']',']]')+']')}
   $dax=if($f.measure){'EVALUATE ROW("Value",['+$prop+'])'}else{'EVALUATE TOPN(3,SUMMARIZECOLUMNS(' + ($columns -join ',')+'))'}
   try{
    $q=$c.CreateCommand();$q.CommandText=$dax;$q.CommandTimeout=120
    $reader=$q.ExecuteReader();$rows=0;$value=$null
    try{while($reader.Read()){$rows++;if($rows -eq 1){$value=if($reader.IsDBNull(0)){$null}else{$reader.GetValue(0)}}}}finally{$reader.Close()}
    $results.Add([pscustomobject]@{Cube=$cube.name;Table=$f.table;Field=$f.property;Passed=$true;Rows=$rows;FirstValue=$value;Error=$null})
   }catch{$results.Add([pscustomobject]@{Cube=$cube.name;Table=$f.table;Field=$f.property;Passed=$false;Rows=0;FirstValue=$null;Error=$_.Exception.Message})}
  }
 }finally{$c.Dispose()}
 Write-Output ($cube.name+': bindings tested')
}
$results|ConvertTo-Json -Depth 6|Set-Content (Join-Path $PSScriptRoot 'live-binding-results.json') -Encoding UTF8
$failed=@($results|Where-Object {-not $_.Passed})
Write-Output ("Checks="+$results.Count+"; failures="+$failed.Count)
if($failed.Count){$failed|Format-List;exit 1}
