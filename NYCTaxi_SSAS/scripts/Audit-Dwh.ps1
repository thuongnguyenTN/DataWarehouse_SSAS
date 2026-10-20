$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$cn=New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
$cn.Open()
$fk=Get-Content (Join-Path $root 'evidence/foreign-keys.json') -Raw | ConvertFrom-Json
$pk=Get-Content (Join-Path $root 'evidence/primary-keys.json') -Raw | ConvertFrom-Json
$statements=New-Object 'System.Collections.Generic.List[string]'
$results=New-Object 'System.Collections.Generic.List[object]'
try {
 foreach($f in $fk) {
  $q="SELECT COUNT_BIG(*) FROM dbo.[$($f.FactTable)] f LEFT JOIN dbo.[$($f.DimTable)] d ON f.[$($f.FactColumn)]=d.[$($f.DimColumn)] WHERE d.[$($f.DimColumn)] IS NULL"
  $cmd=$cn.CreateCommand();$cmd.CommandText=$q;$cmd.CommandTimeout=180
  $missing=$cmd.ExecuteScalar()
  $q2="SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [$($f.FactColumn)]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[$($f.FactTable)]"
  $cmd.CommandText=$q2;$dt=New-Object System.Data.DataTable;$dt.Load($cmd.ExecuteReader())
  $results.Add([pscustomobject]@{ForeignKey=$f.FKName;Fact=$f.FactTable;Column=$f.FactColumn;Orphans=$missing;FactRows=$dt.Rows[0].FactRows;UnknownRows=$dt.Rows[0].UnknownRows;UnknownPercent=100.0*[double]$dt.Rows[0].UnknownRows/[Math]::Max(1,[double]$dt.Rows[0].FactRows);Enabled=(-not $f.IsDisabled);Trusted=(-not $f.IsNotTrusted)})
  $statements.Add("-- $($f.FKName)`n$q;`n$q2;")
 }
 foreach($k in $pk | Where-Object {$_.TableName -like 'Dim_*'}) {
  $cmd=$cn.CreateCommand();$cmd.CommandText="SELECT COUNT_BIG(*) FROM dbo.[$($k.TableName)] WHERE [$($k.ColumnName)]=0"
  if($cmd.ExecuteScalar() -ne 1){throw "Missing or duplicate key=0 row in $($k.TableName)"}
 }
} finally {
 $results | Export-Csv (Join-Path $root 'evidence/foreign-key-audit.csv') -NoTypeInformation -Encoding UTF8
 $statements | Set-Content (Join-Path $root 'queries/dwh-integrity.sql') -Encoding UTF8
 $cn.Close()
}
$bad=@($results | Where-Object {$_.Orphans -ne 0 -or -not $_.Enabled -or -not $_.Trusted})
Write-Output "Audited $($results.Count) foreign keys; $($bad.Count) failing constraints. All 15 dimensions contain key=0."
if($bad.Count){throw 'DWH integrity failed; see audit CSV.'}
