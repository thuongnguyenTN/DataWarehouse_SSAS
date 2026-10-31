$ErrorActionPreference='Stop'
$c=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=15'
$c.Open()
try{
 $q=$c.CreateCommand();$q.CommandTimeout=180
 $q.CommandText="SELECT COUNT_BIG(*) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey>=20130101 AND PickupDateKey<20130201"
 $sqlCount=[long]$q.ExecuteScalar()
 $q.CommandText="SELECT COUNT_BIG(*) FROM dbo.Fact_YellowGreen_Trips WHERE SourceKey=N'yellow_tripdata_2013-01.csv'"
 $sourceCount=[long]$q.ExecuteScalar()
 $q.CommandText="SELECT Status FROM etl.PipelineRun WHERE RunId='46a4dc75-fb0b-4e66-b979-c3d45db537b1'"
 $status=[string]$q.ExecuteScalar()
}finally{$c.Dispose()}
$null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
$olap=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection 'Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS'
$olap.Open()
try{
 $q=$olap.CreateCommand();$q.CommandTimeout=180
 $q.CommandText='SELECT {[Measures].[Trip Count - Fact Yellow Green Trips]} ON COLUMNS FROM [YellowGreen Trips] WHERE ([Pickup Date].[Month Number].&[2013]&[1])'
 $cubeCount=[long]$q.ExecuteCellSet().Cells[0].Value
}finally{$olap.Dispose()}
$result=[pscustomobject]@{RunId='46a4dc75-fb0b-4e66-b979-c3d45db537b1';BeforeMonthTrips=0;SQLMonthTrips=$sqlCount;SSASMonthTrips=$cubeCount;SourceFileFacts=$sourceCount;RowLimit=100000;Status=$status;Passed=($status -eq 'SUCCEEDED' -and $sqlCount -gt 0 -and $sqlCount -eq $cubeCount)}
$result | ConvertTo-Json | Tee-Object -FilePath (Join-Path $PSScriptRoot 'demo-201301-result.json')
if(-not $result.Passed){throw 'Demo has not passed SQL/SSAS verification'}
