# Normalize live references only. Never regenerate pages or edit report visuals.
$ErrorActionPreference='Stop'
$reports=Get-Content (Join-Path $PSScriptRoot 'report-index.json') -Raw -Encoding UTF8|ConvertFrom-Json
$backup=Join-Path $PSScriptRoot ('_backups/connections-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $backup -Force
foreach($report in $reports){
 $path=Join-Path $PSScriptRoot ('reports/'+$report.cube+'/'+$report.cube+'.SemanticModel/modelReference.json')
 $ref=Get-Content $path -Raw -Encoding UTF8|ConvertFrom-Json
 Copy-Item -LiteralPath $path -Destination (Join-Path $backup ($report.cube+'-modelReference.json'))
 $ref.connectionString='Data Source=THUONGNGUYEN\MSSQLSV;Initial Catalog=NYCTaxi_SSAS;Cube="'+$report.title+'";Integrated Security=SSPI;'
 $ref.connectionType='analysisServicesDatabaseLive'
 $ref.isMultiDimentional=$true
 $text=$ref|ConvertTo-Json -Depth 6
 [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding($false)))
 Write-Output ('Normalized live reference: '+$report.title)
}
Write-Output ('Backup: '+$backup)
