$ErrorActionPreference='Stop';$etl=Split-Path $PSScriptRoot
$fixture=Get-Content (Join-Path $etl 'incremental-tests.json') -Raw|ConvertFrom-Json
$dw=$fixture.DwhDatabase;$stg=$fixture.StagingDatabase
if($dw -notmatch '^NYCTaxi_DWH_IncTest_\d+$' -or $stg -notmatch '^NYCTaxi_Staging_IncTest_\d+$'){throw 'Fixture databases required'}
$c=New-Object Data.SqlClient.SqlConnection ('Server=THUONGNGUYEN\MSSQLSV;Database='+$dw+';Integrated Security=True');$c.Open()
function Exec($text){$q=$c.CreateCommand();$q.CommandText=$text;$q.CommandTimeout=120;try{$q.ExecuteScalar()}finally{$q.Dispose()}}
try{
 [xml]$doc=Get-Content (Join-Path $PSScriptRoot 'PKG_03_Load_DWH.dtsx') -Raw;$sql=@{}
 foreach($t in $doc.SelectNodes('/*/*[local-name()="Executables"]/*')){$name=$t.GetAttribute('ObjectName','www.microsoft.com/SqlServer/Dts');$node=$t.SelectSingleNode('.//*[local-name()="SqlTaskData"]');$sql[$name]=$node.GetAttribute('SqlStatementSource','www.microsoft.com/sqlserver/dts/tasks/sqltask').Replace('NYCTaxi_Staging',$stg).Replace('NYCTaxi_DWH',$dw)}
 foreach($case in @(@{Value="'1'";Expected='Y'},@{Value="'0'";Expected='N'},@{Value='NULL';Expected='U'})){
  $null=Exec "UPDATE [$stg].clean.Trip SET SourceSRFlag=$($case.Value) WHERE TaxiType='FHV'; UPDATE etl.DwhFileLog SET ForceReload=1 WHERE DatasetCode='fhv';"
  $null=Exec $sql['EST_01_Load_Dimensions'];$null=Exec $sql['EST_03_Load_FactFHV']
  $bad=Exec "SELECT COUNT(*) FROM dbo.Fact_FHV_Trips F JOIN dbo.Dim_FHVFlags D ON D.FHVFlagKey=F.FHVFlagKey WHERE D.IsSharedRide<>'$($case.Expected)'"
  if($bad -ne 0){throw 'FHV flag mapping failed'}
  Write-Host ('PASS FHV SourceSRFlag='+$case.Value+' -> '+$case.Expected)
 }
}finally{$c.Dispose()}
