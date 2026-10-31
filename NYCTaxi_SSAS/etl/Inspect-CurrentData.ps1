$ErrorActionPreference='Stop'
$c=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
$c.Open()
try {
 $cmd=$c.CreateCommand();$cmd.CommandTimeout=120
 $cmd.CommandText="SELECT 'Fact_YellowGreen_Trips' AS T, COUNT_BIG(*) AS N FROM dbo.Fact_YellowGreen_Trips UNION ALL SELECT 'Fact_FHV_Trips',COUNT_BIG(*) FROM dbo.Fact_FHV_Trips UNION ALL SELECT 'Fact_HVFHV_Trips',COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips; SELECT TOP(8) DatasetCode,SourceKey,ExpectedRows,RowLimit,LoadStatus FROM NYCTaxi_Staging.etl.ExtractFileLog ORDER BY DatasetCode,SourceKey; SELECT TaxiType,COUNT_BIG(*) AS N FROM NYCTaxi_Staging.clean.ValidTrip GROUP BY TaxiType;"
 $a=New-Object System.Data.SqlClient.SqlDataAdapter $cmd;$ds=New-Object System.Data.DataSet;$null=$a.Fill($ds)
 foreach($t in $ds.Tables){$t | Format-Table -AutoSize}
} finally {$c.Dispose()}
