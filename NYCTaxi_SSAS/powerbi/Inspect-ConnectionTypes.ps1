$ErrorActionPreference='Stop'
$bin='C:\Program Files\WindowsApps\Microsoft.MicrosoftPowerBIDesktop_2.159.883.0_x64__8wekyb3d8bbwe\bin'
[AppDomain]::CurrentDomain.add_ReflectionOnlyAssemblyResolve({param($sender,$event)
 $name=(New-Object Reflection.AssemblyName $event.Name).Name+'.dll'
 $path=Join-Path $bin $name
 if(Test-Path -LiteralPath $path){return [Reflection.Assembly]::ReflectionOnlyLoadFrom($path)}
 try{return [Reflection.Assembly]::ReflectionOnlyLoad($event.Name)}catch{return $null}
})
foreach($name in @('Microsoft.PowerBI.Packaging.dll','Microsoft.PowerBI.ASCommon.dll','Microsoft.PowerBI.ClientCommon.dll','Microsoft.PowerBI.Modeling.Common.dll','Microsoft.PowerBI.Modeling.Engine.dll','Microsoft.PowerBI.Client.Windows.dll','Microsoft.PowerBI.ExplorationContracts.dll')){
 $a=[Reflection.Assembly]::ReflectionOnlyLoadFrom((Join-Path $bin $name))
 try{$types=$a.GetTypes()}catch [Reflection.ReflectionTypeLoadException]{$types=$_.Exception.Types}
 foreach($t in $types){if($t -and $t.Name -match 'ModelReference|ConnectionType|LiveConnection|RemoteModelReference'){
  $t.FullName
  $t.GetFields([Reflection.BindingFlags]'Public,NonPublic,Static,Instance')|ForEach-Object {if($_.IsLiteral){$_.Name+': '+$_.GetRawConstantValue()}else{$_.Name+': '+$_.FieldType.FullName}}
  if($t.Name -match '^ASLiveConnectionProperties$|^DatasetModelReference$|^LiveConnectionPropertiesValidator$'){
   foreach($m in $t.GetMethods([Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly')){
    try{$body=$m.GetMethodBody();if(-not $body){continue};$il=$body.GetILAsByteArray()
     for($i=0;$i -lt $il.Length-4;$i++){if($il[$i] -eq 0x72 -and $il[$i+4] -eq 0x70){try{$m.Name+': '+$m.Module.ResolveString([BitConverter]::ToInt32($il,$i+1))}catch{}}}
    }catch{}
   }
  }
 }}
}
