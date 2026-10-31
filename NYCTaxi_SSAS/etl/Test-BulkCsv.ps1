$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Invoke-NYCTaxiPipeline.ps1'),[ref]$tokens,[ref]$errors)
foreach($node in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Connect','Sql','BulkCsv')},$false)){Invoke-Expression $node.Extent.Text}
$SqlServer='THUONGNGUYEN\MSSQLSV';$c=Connect 'NYCTaxi_Staging'
$table='PipelineCsvTest_'+[guid]::NewGuid().ToString('N')
$path=Join-Path $PSScriptRoot ($table+'.csv')
try {
 $null=Sql $c ('CREATE TABLE wrk.['+$table+'] (A varchar(100),B varchar(100));')
 [IO.File]::WriteAllText($path,"A,B`n`"a,`"`"b`nnext`",`"`"`nsecond,value`n",(New-Object Text.UTF8Encoding $false))
 $n=BulkCsv $c $path 'test' $table
 if($n -ne 2){throw "Unexpected bulk count: $n"}
 $actual=Sql $c ('SELECT A FROM wrk.['+$table+'] WHERE B IS NULL;')
 if($actual -ne "a,`"b`nnext"){throw "Quoted multiline CSV did not round-trip: $actual"}
 [pscustomobject]@{Test='Production SqlBulkCopy path: quoted comma, quote, multiline, NULL and row count';Passed=$true;Rows=$n}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'bulk-tests.json') -Encoding UTF8
 'PASS: SQL CSV boundary (quoted/multiline/NULL and count).'
}finally{
 try{$null=Sql $c ('DROP TABLE IF EXISTS wrk.['+$table+'];')}finally{$c.Dispose()}
 if(Test-Path $path){Remove-Item -LiteralPath $path}
}
