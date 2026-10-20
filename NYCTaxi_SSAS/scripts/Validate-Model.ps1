$ErrorActionPreference = 'Stop'
$modelPath = Join-Path $PSScriptRoot '../NYCTaxi_SSAS'
$files = Get-ChildItem $modelPath -File | Where-Object Extension -in '.cube','.dim','.dsv','.ds','.partitions','.database','.dwproj'
foreach ($file in $files) { $null = [xml](Get-Content -LiteralPath $file.FullName -Raw) }
$cube = [xml](Get-Content (Join-Path $modelPath 'DSV_NYCTaxi.cube') -Raw)
$dsv = [xml](Get-Content (Join-Path $modelPath 'DSV_NYCTaxi.dsv') -Raw)
$tables = @{}
foreach ($table in $dsv.SelectNodes('//*[local-name()="element"][@name]')) {
    $columns = @($table.SelectNodes('./*[local-name()="complexType"]/*[local-name()="sequence"]/*[local-name()="element"]') | ForEach-Object { $_.GetAttribute('name') })
    if ($columns.Count -gt 0) { $tables[$table.GetAttribute('name')] = $columns }
}
foreach ($file in @($files | Where-Object Extension -in '.cube','.dim')) {
    $doc = [xml](Get-Content -LiteralPath $file.FullName -Raw)
    foreach ($binding in $doc.SelectNodes('//*[local-name()="Source"][*[local-name()="TableID"] and *[local-name()="ColumnID"]]')) {
        $tableId = $binding.TableID
        $columnId = $binding.ColumnID
        if (-not $tables.ContainsKey($tableId) -or $columnId -notin $tables[$tableId]) {
            throw "Invalid binding in $($file.Name): $tableId.$columnId"
        }
    }
}
$dimensionIds = @($cube.Cube.Dimensions.Dimension | ForEach-Object { $_.ID })
foreach ($group in $cube.Cube.MeasureGroups.MeasureGroup) {
    foreach ($dimension in $group.Dimensions.Dimension) {
        if ($dimension.CubeDimensionID -notin $dimensionIds) { throw "Unknown cube dimension: $($dimension.CubeDimensionID)" }
    }
}
$measureNames = @($cube.Cube.MeasureGroups.MeasureGroup.Measures.Measure | ForEach-Object { $_.Name })
$mdx = $cube.Cube.MdxScripts.MdxScript.Commands.Command.Text
$calculatedNames = @([regex]::Matches($mdx, 'CREATE MEMBER CURRENTCUBE\.\[Measures\]\.\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
foreach ($match in [regex]::Matches($mdx, '\[Measures\]\.\[([^\]]+)\]')) {
    if ($match.Groups[1].Value -notin ($measureNames + $calculatedNames)) { throw "Unknown MDX measure: $($match.Groups[1].Value)" }
}
Write-Output "PASS: $($files.Count) XML files; source bindings, cube dimension references and MDX measure references."
Write-Output 'SSAS compilation and processing must still be checked on the target server.'
