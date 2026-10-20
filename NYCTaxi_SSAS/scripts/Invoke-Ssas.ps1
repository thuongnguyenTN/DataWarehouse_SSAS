param(
    [ValidateSet('Deploy','Update','Dimensions','Process','Status')][string]$Action = 'Status',
    [string]$XmlaPath
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$amo = 'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null = [Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'))
$null = [Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
$server = New-Object Microsoft.AnalysisServices.Server
$server.Connect('THUONGNGUYEN\MSSQLSV')
try {
    if ($server.ServerMode -ne 'Multidimensional') { throw 'Target is not Multidimensional.' }
    if ($Action -eq 'Status') {
        $server.Databases | Select-Object ID,Name,State | Format-Table
        $db = $server.Databases.Find('NYCTaxi_SSAS')
        if ($db) {
            $db.Dimensions | Select-Object ID,State | Format-Table
            foreach ($g in $db.Cubes[0].MeasureGroups) { $g.Partitions | Select-Object @{n='Group';e={$g.ID}},ID,State,LastProcessed | Format-Table }
        }
        return
    }
    if ($Action -eq 'Deploy') {
        if ($server.Databases.Find('NYCTaxi_SSAS')) { throw 'NYCTaxi_SSAS exists; refusing to overwrite. Use a reviewed Alter XMLA for subsequent deployments.' }
        $XmlaPath = Join-Path $root 'deployment/Create-Database.xmla'
    } elseif ($Action -eq 'Update') {
        $db=$server.Databases.Find('NYCTaxi_SSAS')
        if (-not $db -or -not $db.Cubes.Find('DSV_NYCTaxi')) {throw 'Expected existing NYC Taxi cube was not found.'}
        $settings=New-Object Xml.XmlWriterSettings;$settings.Indent=$true
        $backup=Join-Path $root ('backups/server-before-update-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.xmla')
        $writer=[Xml.XmlWriter]::Create($backup,$settings)
        try {[Microsoft.AnalysisServices.Utils]::Serialize($writer,$db,$true)} finally {$writer.Close()}
        $definition=[xml](Get-Content (Join-Path $root 'deployment/NYCTaxi_SSAS.asdatabase') -Raw)
        # Preserve existing role definitions and membership, if configured.
        $old=[xml](Get-Content $backup -Raw)
        if ($old.Database.Roles) {$null=$definition.DocumentElement.AppendChild($definition.ImportNode($old.Database.Roles,$true))}
        $ns='http://schemas.microsoft.com/analysisservices/2003/engine'
        $alter=New-Object Xml.XmlDocument
        $a=$alter.CreateElement('Alter',$ns);$a.SetAttribute('AllowCreate','false');$a.SetAttribute('ObjectExpansion','ExpandFull');$null=$alter.AppendChild($a)
        $o=$alter.CreateElement('Object',$ns);$null=$a.AppendChild($o)
        $id=$alter.CreateElement('DatabaseID',$ns);$id.InnerText='NYCTaxi_SSAS';$null=$o.AppendChild($id)
        $od=$alter.CreateElement('ObjectDefinition',$ns);$null=$a.AppendChild($od)
        $null=$od.AppendChild($alter.ImportNode($definition.DocumentElement,$true))
        $XmlaPath=Join-Path $root 'deployment/Alter-Database.xmla';$alter.Save($XmlaPath)
        Write-Output "Server metadata backed up to $backup"
    } elseif ($Action -eq 'Dimensions') {
        $db = $server.Databases.Find('NYCTaxi_SSAS')
        foreach ($d in $db.Dimensions) {
            $d.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)
            "Processed dimension: $($d.ID)" | Tee-Object (Join-Path $root 'evidence/ssas-Dimensions.log') -Append
        }
        return
    } elseif (-not $XmlaPath) { throw 'Process requires an explicit reviewed XMLA file.' }
    $results = $server.Execute((Get-Content -LiteralPath $XmlaPath -Raw))
    $messages = foreach ($r in $results) { foreach ($m in $r.Messages) { "$($m.GetType().Name): $($m.Description)" } }
    $messages | Tee-Object (Join-Path $root "evidence/ssas-$Action.log")
    foreach ($r in $results) { foreach ($m in $r.Messages) { if ($m -is [Microsoft.AnalysisServices.XmlaError]) { throw $m.Description } } }
    "$(Get-Date -Format s) $Action completed without XMLA errors. Input: $XmlaPath" | Tee-Object (Join-Path $root "evidence/ssas-$Action.log") -Append
} finally { $server.Disconnect() }
