param([ValidateSet('TestMonth','Full')][string]$Scope='TestMonth')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$null=[Reflection.Assembly]::LoadFrom('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll')
$sql=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
$olap=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection 'Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS'
$sql.Open();$olap.Open(); $olap.GetSchemaDataSet("MDSCHEMA_CUBES",$null).Tables[0] | Select-Object CUBE_NAME,CUBE_CAPTION | Format-Table
$checks=New-Object 'System.Collections.Generic.List[object]'
$sqlText=New-Object 'System.Collections.Generic.List[string]'
$mdxText=New-Object 'System.Collections.Generic.List[string]'
function Check($name,$query,$measure,$slice='') {
 $cmd=$sql.CreateCommand();$cmd.CommandText=$query;$cmd.CommandTimeout=180
 $expected=$cmd.ExecuteScalar()
 $where=if($slice){" WHERE ($slice)"}else{''}
 $mdx="SELECT {[Measures].[$measure]} ON COLUMNS FROM [NYC Taxi Analysis]$where"
 $cmd=$olap.CreateCommand();$cmd.CommandText=$mdx;$cmd.CommandTimeout=180
 $actual=$cmd.ExecuteCellSet().Cells[0].Value
 $eNull=($null -eq $expected -or $expected -is [DBNull]);$aNull=($null -eq $actual -or $actual -is [DBNull])
 $pass=if($eNull -or $aNull){$eNull -eq $aNull}else{[Math]::Abs([double]$expected-[double]$actual) -le [Math]::Max(0.00001,[Math]::Abs([double]$expected)*0.000000001)}
 $checks.Add([pscustomobject]@{Check=$name;SQLValue=if($eNull){'NULL'}else{$expected};CubeValue=if($aNull){'NULL'}else{$actual};Passed=$pass})
 $sqlText.Add("-- $name`n$query;");$mdxText.Add("-- $name`n$mdx;")
 if(-not $pass){Write-Output "FAIL: $name SQL=$expected Cube=$actual"}
}
$period=if($Scope -eq 'TestMonth'){' AND PickupDateKey>=20250101 AND PickupDateKey<20250201'}else{''}
try {
 $sources=@(
  @('Fact_FHV_Trips','Trip Count','FHV'),
  @('Fact_HVFHV_Trips','Trip Count - Fact HVFHV Trips','HVFHV'),
  @('Fact_YellowGreen_Trips','Trip Count - Fact Yellow Green Trips','YellowGreen')
 )
 foreach($src in $sources) {
  $table=$src[0];$measure=$src[1];$label=$src[2]
  Check "$label trips" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE 1=1$period" $measure
  foreach($date in @(20250101,20250115)) {
   Check "$label date $date" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE PickupDateKey=$date$period" $measure "[Pickup Date].[Date Key].&[$date]"
  }
  foreach($location in @(0,1,132,138)) {
   Check "$label pickup location $location" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE PickupLocationKey=$location$period" $measure "[Pickup Location].[Location Key].&[$location]"
  }
  foreach($borough in @('Manhattan','Queens')) {
   Check "$label borough $borough" "SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.$table f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'$borough'$period" $measure "[Pickup Location].[Borough].&[$borough]"
  }
  Check "$label avg duration" "SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.$table WHERE 1=1$period" "$label Average Trip Duration Minutes"
  if($label -ne 'FHV') {
   Check "$label avg distance" "SELECT SUM(TripDistanceMiles)/NULLIF(SUM(CASE WHEN TripDistanceMiles IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.$table WHERE 1=1$period" "$label Average Trip Distance"
   Check "$label speed" "SELECT SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDistanceMiles AS float) END)/NULLIF(SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDurationSeconds AS float) END),0)*3600 FROM dbo.$table WHERE 1=1$period" "$label Average Speed MPH"
   $fare=if($label -eq 'YellowGreen'){'FareAmount'}else{'BasePassengerFare'}
   Check "$label avg fare" "SELECT SUM($fare)/NULLIF(SUM(CASE WHEN $fare IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.$table WHERE 1=1$period" "$label Average Fare Per Trip"
   Check "$label avg tip" "SELECT SUM(TipAmount)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.$table WHERE 1=1$period" "$label Average Tip Per Trip"
   Check "$label tip percentage" "SELECT SUM(CASE WHEN TipAmount IS NOT NULL AND $fare IS NOT NULL THEN TipAmount END)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL AND $fare IS NOT NULL THEN $fare END),0) FROM dbo.$table WHERE 1=1$period" "$label Tip Percentage"
  }
 }
 foreach($service in @(@(1,'YELLOW'),@(2,'GREEN'),@(3,'FHV'),@(4,'FHVHV'))) {
  $key=$service[0];$table=if($key -le 2){'Fact_YellowGreen_Trips'}elseif($key -eq 3){'Fact_FHV_Trips'}else{'Fact_HVFHV_Trips'}
  Check "Service $($service[1])" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE ServiceTypeKey=$key$period" 'Total Trips All Services' "[Dim Service Type].[Service Type Key].&[$key]"
 }
 Check 'YellowGreen revenue' "SELECT SUM(TotalAmount) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1$period" 'Total Amount'
 Check 'HVFHV driver pay' "SELECT SUM(DriverPayAmount) FROM dbo.Fact_HVFHV_Trips WHERE 1=1$period" 'Driver Pay Amount'
 Check 'HVFHV avg waiting' "SELECT SUM(CAST(WaitingTimeSeconds AS float))/NULLIF(SUM(CASE WHEN WaitingTimeSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_HVFHV_Trips WHERE 1=1$period" 'HVFHV Average Waiting Minutes'
 if($Scope -eq 'Full') {
  foreach($snapshot in @(
    @('Fact_Daily_Financial_Snapshot','Daily Financial Snapshot',@('TotalTrips','TotalDistanceMiles','TotalPassengerCharges','TotalTips','TotalTaxesAndFees','TotalDriverPay')),
    @('Fact_Zone_Traffic_Snapshot','Zone Traffic Snapshot',@('TotalPickups','TotalDropoffs')),
    @('Fact_Base_Performance_Snapshot','Base Performance Snapshot',@('TotalTrips','TotalTripDurationSeconds','DurationTripCount','TotalWaitingTimeSeconds','WaitingTripCount','TotalSharedRequests','TotalSharedMatches','TotalWAVRequests','TotalWAVMatches','TotalDriverPay'))
   )) {
   foreach($col in $snapshot[2]) {Check "$($snapshot[1]) $col" "SELECT SUM($col) FROM dbo.$($snapshot[0])" "$($snapshot[1]) $col"}
  }
  Check 'Shared request rate' 'SELECT SUM(CAST(TotalSharedRequests AS float))/NULLIF(SUM(TotalTrips),0) FROM dbo.Fact_Base_Performance_Snapshot WHERE ServiceTypeKey=4' 'Shared Request Rate'
  Check 'WAV match rate' 'SELECT SUM(CAST(TotalWAVMatches AS float))/NULLIF(SUM(TotalWAVRequests),0) FROM dbo.Fact_Base_Performance_Snapshot' 'WAV Match Rate'
  foreach($base in @(0,1,2,3)) {Check "Dispatch base $base" "SELECT SUM(TotalTrips) FROM dbo.Fact_Base_Performance_Snapshot WHERE DispatchBaseKey=$base" 'Base Performance Snapshot TotalTrips' "[Dispatch Base].[Base Key].&[$base]"}
  Check 'Base avg duration' 'SELECT SUM(CAST(TotalTripDurationSeconds AS float))/NULLIF(SUM(DurationTripCount),0)/60.0 FROM dbo.Fact_Base_Performance_Snapshot' 'Base Average Duration Minutes'
  Check 'Base avg waiting' 'SELECT SUM(CAST(TotalWaitingTimeSeconds AS float))/NULLIF(SUM(WaitingTripCount),0)/60.0 FROM dbo.Fact_Base_Performance_Snapshot' 'Base Average Waiting Minutes'
  foreach($date in @(20250101,20250115)) {
   Check "Snapshot pickups date $date" "SELECT SUM(TotalPickups) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE DateKey=$date" 'Zone Traffic Snapshot TotalPickups' "[Snapshot Date].[Date Key].&[$date]"
  }
  foreach($location in @(0,1,132)) {
   Check "Snapshot dropoffs location $location" "SELECT SUM(TotalDropoffs) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE LocationKey=$location" 'Zone Traffic Snapshot TotalDropoffs' "[Snapshot Location].[Location Key].&[$location]"
  }
  foreach($source in $sources) {
   $table=$source[0];$measure=$source[1]
   Check "$table Unknown batch" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE LoadBatchKey=0" $measure '[Dim Load Batch].[Load Batch Key].&[0]'
   Check "$table Unknown time" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE PickupTimeKey=0" $measure '[Pickup Time].[Time Key].&[0]'
   Check "$table Unknown date" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE PickupDateKey=0" $measure '[Pickup Date].[Date Key].&[0]'
   foreach($hour in @(0,8,17)) {
    $cmd=$sql.CreateCommand();$cmd.CommandText="SELECT TOP(1) TimeBand FROM dbo.Dim_Time WHERE HourNumber=$hour AND TimeKey>0"
    $band=([string]$cmd.ExecuteScalar()).Replace(']',']]')
    Check "$table hour $hour" "SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.$table f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=$hour AND t.TimeKey>0" $measure "[Pickup Time].[Hour Number].&[$band]&[$hour]"
   }
   Check "$table calendar Jan2025" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE PickupDateKey>=20250101 AND PickupDateKey<20250201" $measure '[Pickup Date].[Month Number].&[2025]&[1]'
   Check "$table calendar Q12025" "SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.$table WHERE PickupDateKey>=20250101 AND PickupDateKey<20250401" $measure '[Pickup Date].[Quarter Number].&[2025]&[1]'
  }
 }
} finally {
 $checks | Export-Csv (Join-Path $root "evidence/reconciliation-$Scope.csv") -NoTypeInformation -Encoding UTF8
 $sqlText | Set-Content (Join-Path $root "queries/reconcile-$Scope.sql") -Encoding UTF8
 $mdxText | Set-Content (Join-Path $root "queries/reconcile-$Scope.mdx") -Encoding UTF8
 $sql.Close();$olap.Close()
}
$failed=@($checks | Where-Object {-not $_.Passed})
Write-Output "Reconciliation $Scope : $($checks.Count) checks, $($failed.Count) failures."
if($failed.Count){throw 'Reconciliation mismatch; see evidence CSV.'}

