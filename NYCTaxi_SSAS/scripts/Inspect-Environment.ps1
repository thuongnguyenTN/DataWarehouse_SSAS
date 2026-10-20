$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$out = Join-Path $root 'evidence'
$null = New-Item $out -ItemType Directory -Force
$cn = New-Object System.Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
$cn.Open()
function Query($sql) {
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $dt = New-Object System.Data.DataTable
    $dt.Load($cmd.ExecuteReader())
    return ,$dt
}
$tables = Query "SELECT s.name AS SchemaName,t.name AS TableName,c.name AS ColumnName,c.column_id AS Ordinal,ty.name AS DataType,c.max_length AS MaxLength,c.is_nullable AS Nullable FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id JOIN sys.columns c ON t.object_id=c.object_id JOIN sys.types ty ON c.user_type_id=ty.user_type_id WHERE t.name LIKE 'Dim[_]%' OR t.name LIKE 'Fact[_]%' ORDER BY t.name,c.column_id"
$tables | Select-Object SchemaName,TableName,ColumnName,Ordinal,DataType,MaxLength,Nullable | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'columns.json') -Encoding UTF8
$fk = Query "SELECT fk.name AS FKName,OBJECT_NAME(fkc.parent_object_id) AS FactTable,pc.name AS FactColumn,OBJECT_NAME(fkc.referenced_object_id) AS DimTable,rc.name AS DimColumn,fk.is_disabled AS IsDisabled,fk.is_not_trusted AS IsNotTrusted FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fkc.constraint_object_id=fk.object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id"
$fk | Select-Object FKName,FactTable,FactColumn,DimTable,DimColumn,IsDisabled,IsNotTrusted | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'foreign-keys.json') -Encoding UTF8
$pk = Query "SELECT OBJECT_NAME(i.object_id) AS TableName,c.name AS ColumnName,ic.key_ordinal AS Ordinal FROM sys.indexes i JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.is_primary_key=1 ORDER BY TableName,ic.key_ordinal"
$pk | Select-Object TableName,ColumnName,Ordinal | ConvertTo-Json | Set-Content (Join-Path $out 'primary-keys.json') -Encoding UTF8
$counts = Query "SELECT t.name AS TableName,SUM(p.rows) AS [RowCount] FROM sys.tables t JOIN sys.partitions p ON t.object_id=p.object_id AND p.index_id IN (0,1) WHERE t.name LIKE 'Dim[_]%' OR t.name LIKE 'Fact[_]%' GROUP BY t.name ORDER BY t.name"
$counts | Select-Object TableName,RowCount | Export-Csv (Join-Path $out 'row-counts.csv') -NoTypeInformation -Encoding UTF8
$sample = Query "SELECT TOP (1) PickupDateKey/100 AS YearMonth FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey>0 ORDER BY PickupDateKey"
$sample | Select-Object YearMonth | ConvertTo-Json | Set-Content (Join-Path $out 'sample-month.json') -Encoding UTF8
$cn.Close()
$amo = 'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null = [Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
$null = [Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
$server = New-Object Microsoft.AnalysisServices.Server
try {
    $server.Connect('THUONGNGUYEN\MSSQLSV')
    "Connected: $($server.Name); Mode=$($server.ServerMode); Version=$($server.Version)" | Tee-Object (Join-Path $out 'ssas-server.txt')
    $server.Databases | Select-Object ID,Name,State | Format-Table | Out-String | Add-Content (Join-Path $out 'ssas-server.txt')
} finally { if ($server.Connected) { $server.Disconnect() } }
Write-Output 'SQL metadata saved under evidence/.'


