$ErrorActionPreference='Stop'
$amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
$s=New-Object Microsoft.AnalysisServices.Server
try {$s.Connect('THUONGNGUYEN\MSSQLSV');$db=$s.Databases.Find('NYCTaxi_SSAS');$db.Cubes|Select-Object ID,Name,State|Format-Table;$db.DataSources|Select-Object Name,ConnectionString|Format-List}finally{$s.Disconnect()}
