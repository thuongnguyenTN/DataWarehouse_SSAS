param([Parameter(Mandatory=$true)][string]$Config,[switch]$Apply)
$ErrorActionPreference='Stop';$m=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
foreach($key in @('Server','RepoRoot','SsisRoot','DataRoot','PythonExe','AmoRoot','AdomdDll')){if(-not $m.$key){throw "Missing $key"}}
foreach($root in @($m.RepoRoot,$m.SsisRoot)){if(-not(Test-Path -LiteralPath $root)){throw "Clone project first: $root"}}
$pairs=@(
 @('THUONGNGUYEN\MSSQLSV',$m.Server),@('E:\NYCTaxi\NYCTaxi_SSAS',$m.RepoRoot),@('E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL',$m.SsisRoot),
 @('D:\Kho_Du_lieu\NYCTaxi\script',(Join-Path $m.DataRoot 'script')),@('D:\Kho_Du_lieu\NYCTaxi',$m.DataRoot),
 @('C:\Users\ADMIN\AppData\Local\Programs\Python\Python310\python.exe',$m.PythonExe),
 @('C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0',$m.AmoRoot),
 @('C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll',$m.AdomdDll))
$backup=Join-Path $m.RepoRoot ('handover/config-backup-'+(Get-Date -Format yyyyMMddHHmmss));$changed=0
$scan=@('etl','scripts','NYCTaxi_SSAS','deployment','powerbi')|ForEach-Object {Join-Path $m.RepoRoot $_};$scan+=$m.SsisRoot
foreach($root in $scan){foreach($file in Get-ChildItem -LiteralPath $root -File -Recurse){
 if($file.FullName -match '\\(backups|logs|monthly-logs|tests|schemas|metadata|bin|obj|\.vs)\\' -or $file.Extension -notin @('.ps1','.py','.cs','.json','.dtsx','.conmgr','.dtproj','.ds','.cube','.partitions','.xmla','.asdatabase')){continue}
 $old=[IO.File]::ReadAllText($file.FullName);$new=$old
 foreach($pair in $pairs){$new=$new.Replace($pair[0].Replace('\','\\'),$pair[1].Replace('\','\\')).Replace($pair[0],$pair[1]).Replace($pair[0].Replace('\','/'),$pair[1].Replace('\','/'))}
 if($new -ne $old){$changed++;Write-Host $file.FullName;if($Apply){$null=New-Item -ItemType Directory $backup -Force;Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $backup ($changed.ToString()+'-'+$file.Name));[IO.File]::WriteAllText($file.FullName,$new,(New-Object Text.UTF8Encoding($true)))}}
}}
if($Apply){
 foreach($dir in @('script','raw','csv','quarantine')){$null=New-Item -ItemType Directory (Join-Path $m.DataRoot $dir) -Force}
 Copy-Item (Join-Path $m.RepoRoot 'etl/python/*.py') (Join-Path $m.DataRoot 'script') -Force
}
Write-Host "Files changed/planned: $changed; Apply=$Apply"
