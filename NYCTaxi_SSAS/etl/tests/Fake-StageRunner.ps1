param($Stage,$StartMonth,$EndMonth,$MaxRows,[guid]$RunId,[guid]$InvocationId,$ResumeFrom)
$folder=Join-Path $env:NYCTAXI_TEST_LOG_ROOT $RunId
$null=New-Item -ItemType Directory -Path $folder -Force
Add-Content (Join-Path $folder 'calls.txt') "$Stage $InvocationId"
if($Stage -eq 'ResumeCheck'){if($env:NYCTAXI_TEST_MODE -eq 'skipfail'){[Console]::Error.WriteLine('checkpoint missing');exit 1};exit 0}
Write-Output 'stream started'
if($env:NYCTAXI_TEST_MODE -eq 'stream'){Start-Sleep -Seconds 4;exit 0}
$calls=@(Get-Content (Join-Path $folder 'calls.txt')).Count
if($env:NYCTAXI_TEST_MODE -eq 'success' -or ($env:NYCTAXI_TEST_MODE -eq 'transient' -and $calls -gt 1)){exit 0}
if($env:NYCTAXI_TEST_MODE -ne 'stale'){
 @{InvocationId="$InvocationId";Task='FixtureSql';Message='fixture original SQL error';Retryable=($env:NYCTAXI_TEST_MODE -in @('transient','exhaust'));SqlNumber=1205}|ConvertTo-Json|Set-Content (Join-Path $folder ('failure-'+$Stage+'.json')) -Encoding UTF8
}
[Console]::Error.WriteLine('fixture stderr');exit 1
