$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$model = Join-Path $root 'NYCTaxi_SSAS'
$amo = 'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null = [Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
$null = [Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
function Read-Object($path, $target) {
    $reader = [Xml.XmlReader]::Create($path)
    try { return [Microsoft.AnalysisServices.Utils]::Deserialize($reader, $target) }
    finally { $reader.Close() }
}
$db = Read-Object (Join-Path $model 'NYCTaxi_SSAS.database') (New-Object Microsoft.AnalysisServices.Database)
$null = $db.DataSources.Add((Read-Object (Join-Path $model 'DS_NYCTaxi_DWH.ds') (New-Object Microsoft.AnalysisServices.RelationalDataSource)))
$null = $db.DataSourceViews.Add((Read-Object (Join-Path $model 'DSV_NYCTaxi.dsv') (New-Object Microsoft.AnalysisServices.DataSourceView)))
foreach ($file in Get-ChildItem $model -Filter '*.dim') {
    $null = $db.Dimensions.Add((Read-Object $file.FullName (New-Object Microsoft.AnalysisServices.Dimension)))
}
$cubeXml = [xml](Get-Content (Join-Path $model 'DSV_NYCTaxi.cube') -Raw)
$partitions = [xml](Get-Content (Join-Path $model 'DSV_NYCTaxi.partitions') -Raw)
foreach ($group in $partitions.Cube.MeasureGroups.MeasureGroup) {
    $targetGroup = $cubeXml.Cube.MeasureGroups.MeasureGroup | Where-Object ID -eq $group.ID
    $null = $targetGroup.AppendChild($cubeXml.ImportNode($group.Partitions,$true))
}
$reader = New-Object Xml.XmlNodeReader $cubeXml
try { $cube = [Microsoft.AnalysisServices.Utils]::Deserialize($reader,(New-Object Microsoft.AnalysisServices.Cube)) } finally { $reader.Close() }
$null = $db.Cubes.Add($cube)
$localServer = New-Object Microsoft.AnalysisServices.Server
$null = $localServer.Databases.Add($db)
$results = New-Object Microsoft.AnalysisServices.ValidationResultCollection
$valid = $db.Validate($results, [Microsoft.AnalysisServices.ValidationOptions]::AddWarnings, [Microsoft.AnalysisServices.ServerEdition]::Developer)
$results | ForEach-Object { "$($_.Rule.Type): $($_.SourcePath): $($_.Description)" } | Set-Content (Join-Path $root 'evidence/amo-validation.txt')
if (-not $valid) { throw "AMO validation failed; see evidence/amo-validation.txt" }
$out = Join-Path $root 'deployment'
$null = New-Item $out -ItemType Directory -Force
$settings = New-Object Xml.XmlWriterSettings
$settings.Indent = $true
$writer = [Xml.XmlWriter]::Create((Join-Path $out 'NYCTaxi_SSAS.asdatabase'),$settings)
try { [Microsoft.AnalysisServices.Utils]::Serialize($writer, $db, $false) } finally { $writer.Close() }
$definition = [xml](Get-Content (Join-Path $out 'NYCTaxi_SSAS.asdatabase') -Raw)
$ns = 'http://schemas.microsoft.com/analysisservices/2003/engine'
$deploy = New-Object Xml.XmlDocument
$create = $deploy.CreateElement('Create',$ns); $create.SetAttribute('AllowOverwrite','false');$null=$deploy.AppendChild($create)
$obj=$deploy.CreateElement('ObjectDefinition',$ns);$null=$create.AppendChild($obj)
$null=$obj.AppendChild($deploy.ImportNode($definition.DocumentElement,$true))
$deploy.Save((Join-Path $out 'Create-Database.xmla'))
Write-Output "AMO model validation passed. Database definition and create XMLA saved to $out."


