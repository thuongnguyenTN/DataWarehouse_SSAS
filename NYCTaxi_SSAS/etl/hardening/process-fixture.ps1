param($PidFile)
$p=Start-Process powershell.exe -ArgumentList '-NoProfile -Command Start-Sleep -Seconds 60' -WindowStyle Hidden -PassThru
$p.Id|Set-Content $PidFile
Start-Sleep -Seconds 60
