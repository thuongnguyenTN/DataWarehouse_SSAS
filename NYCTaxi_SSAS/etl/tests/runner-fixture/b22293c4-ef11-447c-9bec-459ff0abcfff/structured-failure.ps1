@{InvocationId=$env:NYCTAXI_INVOCATION;Message='fixture deadlock';SqlNumber=1205}|ConvertTo-Json|Set-Content $env:NYCTAXI_ERROR_FILE -Encoding UTF8
exit 1
