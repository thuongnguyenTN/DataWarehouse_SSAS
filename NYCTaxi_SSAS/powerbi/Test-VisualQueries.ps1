$ErrorActionPreference='Stop'
$null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
$bindings=Get-Content (Join-Path $PSScriptRoot 'field-bindings.json') -Raw|ConvertFrom-Json
$reports=Get-Content (Join-Path $PSScriptRoot 'report-index.json') -Raw|ConvertFrom-Json
$results=New-Object 'System.Collections.Generic.List[object]'
$queryRoot=Join-Path $PSScriptRoot 'queries';$null=New-Item -ItemType Directory -Path $queryRoot -Force
function Field($table,$property){return "'"+$table.Replace("'","''")+"'["+$property.Replace(']',']]')+']'}
foreach($report in $reports){
 $c=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection ("Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS;Cube="+$report.title)
 $c.Open()
 try{
  foreach($path in Get-ChildItem (Join-Path $PSScriptRoot ('reports/'+$report.cube)) -Filter visual.json -Recurse){
   $v=Get-Content $path.FullName -Raw -Encoding UTF8|ConvertFrom-Json
   if(-not $v.visual.query){continue}
   $columns=@();$measures=@();$n=0
   foreach($role in $v.visual.query.queryState.PSObject.Properties){foreach($p in $role.Value.projections){
    if($p.field.Measure){$f=$p.field.Measure;$n++;$measures+='"M'+$n+'",['+$f.Property.Replace(']',']]')+']'}
    if($p.field.Column){
     $f=$p.field.Column;$table=$f.Expression.SourceRef.Entity;$property=$f.Property
     $columns+=Field $table $property
     $b=$bindings|Where-Object {$_.cube -eq $report.cube -and $_.table -eq $table -and $_.property -eq $property}|Select-Object -First 1
     foreach($key in $b.groupBy){$columns+=Field $table $key}
    }
   }}
   $columns=@($columns|Select-Object -Unique)
   $args=@($columns)+@($measures)
   $dax=if($columns.Count){'EVALUATE TOPN(20,SUMMARIZECOLUMNS('+($args -join ',')+'))'}else{'EVALUATE ROW('+($measures -join ',')+')'}
   $dax|Set-Content (Join-Path $queryRoot ($report.cube+'-'+$v.name+'.dax')) -Encoding UTF8
   $watch=[Diagnostics.Stopwatch]::StartNew()
   try{
    $q=$c.CreateCommand();$q.CommandText=$dax;$q.CommandTimeout=90;$r=$q.ExecuteReader();$count=0
    try{while($r.Read()){$count++}}finally{$r.Close()}
    $results.Add([pscustomobject]@{Cube=$report.title;Visual=$v.name;Type=$v.visual.visualType;Passed=$true;Rows=$count;Milliseconds=$watch.ElapsedMilliseconds;Error=$null})
   }catch{$results.Add([pscustomobject]@{Cube=$report.title;Visual=$v.name;Type=$v.visual.visualType;Passed=$false;Rows=0;Milliseconds=$watch.ElapsedMilliseconds;Error=$_.Exception.Message})}
  }
 }finally{$c.Dispose()}
 Write-Output ($report.title+': visual queries checked')
}
$results|ConvertTo-Json -Depth 5|Set-Content (Join-Path $PSScriptRoot 'visual-query-results.json') -Encoding UTF8
$failed=@($results|Where-Object {-not $_.Passed})
Write-Output ('Visual queries='+$results.Count+'; failures='+$failed.Count)
if($failed.Count){$failed|Format-List;exit 1}
