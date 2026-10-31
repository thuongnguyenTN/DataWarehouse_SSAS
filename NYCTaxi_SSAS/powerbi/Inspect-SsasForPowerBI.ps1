$ErrorActionPreference='Stop'
$null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
$out=Join-Path $PSScriptRoot 'metadata';$null=New-Item -ItemType Directory -Path $out -Force
$c=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection 'Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS'
$c.Open()
try{
 foreach($cube in (Get-Content (Join-Path $PSScriptRoot '../scripts/cube-map.json') -Raw|ConvertFrom-Json).cubes){
  $r=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdRestrictionCollection
  $r.Add('CATALOG_NAME','NYCTaxi_SSAS');$r.Add('PERSPECTIVE_NAME',$cube.name);$r.Add('VERSION','2.0')
  $ds=$c.GetSchemaDataSet('DISCOVER_CSDL_METADATA',$r)
  [string]$ds.Tables[0].Rows[0]['METADATA'] | Set-Content (Join-Path $out ($cube.id+'.csdl.xml')) -Encoding UTF8
  Write-Output ($cube.name+': metadata captured')
 }
}finally{$c.Dispose()}
