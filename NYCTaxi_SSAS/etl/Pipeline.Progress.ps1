function Write-ETLJson($Path,$Value) {
 $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
 try{
  [IO.File]::WriteAllText($temporary,($Value|ConvertTo-Json -Compress -Depth 8),(New-Object Text.UTF8Encoding($false)))
  if([IO.File]::Exists($Path)){[IO.File]::Replace($temporary,$Path,$temporary+'.bak')}else{[IO.File]::Move($temporary,$Path)}
 }finally{foreach($item in @($temporary,($temporary+'.bak'))){if([IO.File]::Exists($item)){[IO.File]::Delete($item)}}}
}
function Write-ETLJournal($Folder,$Run,$StageName,$TaskName,$State,$Message) {
 $event=[ordered]@{Utc=[datetime]::UtcNow.ToString('o');RunId="$Run";Stage=$StageName;Task=$TaskName;Status=$State;Detail=$Message}
 $bytes=[Text.Encoding]::UTF8.GetBytes(($event|ConvertTo-Json -Compress -Depth 5)+[Environment]::NewLine)
 $stream=New-Object IO.FileStream((Join-Path $Folder 'events.jsonl'),[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
 try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}
function Get-ETLRootError($ErrorRecord) {
 $e=$ErrorRecord.Exception
 while($e.InnerException){$e=$e.InnerException}
 $number=$null;if($e -is [Data.SqlClient.SqlException]){$number=$e.Number}
 if($e.Data.Contains('SqlNumber')){$number=[int]$e.Data['SqlNumber']}
 [pscustomobject]@{Message=$e.Message;SqlNumber=$number;Retryable=($null -ne $number -and $number -in @(-2,1205,53,64,233,10053,10054,10060))}
}
