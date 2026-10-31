$ErrorActionPreference='Stop'
$etl=Split-Path $PSScriptRoot;$live='E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL';$backup=[string](Get-Content (Join-Path $PSScriptRoot 'backup.txt'))
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
try{
 $c.Open();$q=$c.CreateCommand();$q.CommandText="DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;IF @r<0 THROW 55990,'ETL active',1; IF EXISTS(SELECT 1 FROM etl.PipelineRun WHERE Status='RUNNING') THROW 55991,'Unfinished run',1;";$null=$q.ExecuteNonQuery()
 foreach($name in @('PKG_00_Master.dtsx','PKG_03_Load_DWH.dtsx')){
  if((Get-FileHash (Join-Path $backup $name)).Hash -ne (Get-FileHash (Join-Path $live $name)).Hash){throw "Live package changed: $name"}
  Copy-Item (Join-Path $PSScriptRoot $name) (Join-Path $live $name) -Force
  Copy-Item (Join-Path $PSScriptRoot $name) (Join-Path $etl ('packages/'+$name)) -Force
 }
}finally{$c.Dispose()}
$amo='C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Business Intelligence Semantic Model\1.0'
$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.Core.dll'));$null=[Reflection.Assembly]::LoadFrom((Join-Path $amo 'Microsoft.AnalysisServices.dll'))
$s=New-Object Microsoft.AnalysisServices.Server
try{
 $s.Connect('THUONGNGUYEN\MSSQLSV');$db=$s.Databases.Find('NYCTaxi_SSAS');$cube=$db.Cubes.Find('Base_Performance');$script=$cube.MdxScripts[0];$old=$script.Commands[0].Text
 $old|Set-Content (Join-Path $backup 'base-mdx-before.txt') -Encoding UTF8
 $new=[regex]::Replace($old,'(?s)(CREATE MEMBER CURRENTCUBE\.\[Measures\]\.\[WAV Match Rate\].*?VISIBLE = )1;','${1}0;')
 if($old -eq $new -and $old -notmatch 'WAV Match Rate.*'){throw 'WAV measure not found'}
 if($old -ne $new){$script.Commands[0].Text=$new;$script.Update()}
 $local=Join-Path (Split-Path $etl) 'NYCTaxi_SSAS/Base_Performance.cube';$text=[IO.File]::ReadAllText($local);Copy-Item $local (Join-Path $backup 'Base_Performance.cube');$text=[regex]::Replace($text,'(?s)(CREATE MEMBER CURRENTCUBE\.\[Measures\]\.\[WAV Match Rate\].*?VISIBLE = )1;','${1}0;');[IO.File]::WriteAllText($local,$text,(New-Object Text.UTF8Encoding($false)))
 'Installed package corrections and hid WAV Match Rate; no ETL or Process executed.'
}finally{if($s.Connected){$s.Disconnect()};$s.Dispose()}
