$ErrorActionPreference = 'Stop'
$root=Split-Path $PSScriptRoot
$cn=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
$cn.Open()
function Save-Query($name,$sql) {
 $cmd=$cn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=180
 $dt=New-Object System.Data.DataTable;$dt.Load($cmd.ExecuteReader())
 $dt | Export-Csv (Join-Path $root "evidence/$name.csv") -NoTypeInformation -Encoding UTF8
}
try {
 Save-Query 'months' @"
SELECT 'Fact_FHV_Trips' AS FactTable,PickupDateKey/100 AS YearMonth,COUNT_BIG(*) AS RowsInMonth FROM dbo.Fact_FHV_Trips GROUP BY PickupDateKey/100
UNION ALL SELECT 'Fact_HVFHV_Trips',PickupDateKey/100,COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips GROUP BY PickupDateKey/100
UNION ALL SELECT 'Fact_YellowGreen_Trips',PickupDateKey/100,COUNT_BIG(*) FROM dbo.Fact_YellowGreen_Trips GROUP BY PickupDateKey/100
ORDER BY FactTable,YearMonth
"@
 Save-Query 'service-totals' @"
SELECT s.ServiceCode,f.* FROM (
 SELECT ServiceTypeKey,SUM(CAST(TripCount AS bigint)) AS Trips,SUM(TotalAmount) AS PassengerCharges,CAST(NULL AS decimal(28,2)) AS DriverPay FROM dbo.Fact_YellowGreen_Trips GROUP BY ServiceTypeKey
 UNION ALL SELECT ServiceTypeKey,SUM(CAST(TripCount AS bigint)),NULL,NULL FROM dbo.Fact_FHV_Trips GROUP BY ServiceTypeKey
 UNION ALL SELECT ServiceTypeKey,SUM(CAST(TripCount AS bigint)),SUM(GrossPassengerAmount),SUM(DriverPayAmount) FROM dbo.Fact_HVFHV_Trips GROUP BY ServiceTypeKey
) f JOIN dbo.Dim_ServiceType s ON f.ServiceTypeKey=s.ServiceTypeKey
"@
 Save-Query 'unknown-dimensions' @"
SELECT 'Dim_Date' AS DimensionName,COUNT_BIG(*) AS UnknownRows FROM dbo.Dim_Date WHERE DateKey=0
UNION ALL SELECT 'Dim_Time',COUNT_BIG(*) FROM dbo.Dim_Time WHERE TimeKey=0
UNION ALL SELECT 'Dim_Location',COUNT_BIG(*) FROM dbo.Dim_Location WHERE LocationKey=0
UNION ALL SELECT 'Dim_LoadBatch',COUNT_BIG(*) FROM dbo.Dim_LoadBatch WHERE LoadBatchKey=0
"@
 Save-Query 'time-check' 'SELECT MIN(TimeKey) AS MinimumKey,MAX(TimeKey) AS MaximumKey,COUNT_BIG(*) AS TimeRows FROM dbo.Dim_Time;'
} finally {$cn.Close()}
Write-Output 'Saved data profiles.'
