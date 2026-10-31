from pathlib import Path
from lxml import etree as E
from copy import deepcopy
import re
R=Path.cwd();P=Path('E:/NYCTaxi/NYCTaxi_DW/NYCTaxi_ETL');O=R/'etl/packages';D='www.microsoft.com/SqlServer/Dts';S='www.microsoft.com/SqlServer/SSIS'
# Update project metadata to expose new Master parameters in SSDT.
r=E.parse(str(P/'NYCTaxi_ETL.dtproj'));master=E.parse(str(O/'PKG_00_Master.dtsx'));params=master.findall('.//{'+D+'}PackageParameter')
for meta in r.xpath('//*[local-name()="PackageMetaData"]'):
 if meta.get('{'+S+'}Name')=='PKG_00_Master.dtsx':
  for prop in meta.findall('./{'+S+'}Properties/{'+S+'}Property'):
   if prop.get('{'+S+'}Name')=='Name':prop.text='PKG_00_Master'
  bucket=meta.find('{'+S+'}Parameters');bucket.clear()
  for param in params:
   e=E.SubElement(bucket,'{'+S+'}Parameter',{'{'+S+'}Name':param.get('{'+D+'}ObjectName')});props=E.SubElement(e,'{'+S+'}Properties')
   for key,value in [('ID',param.get('{'+D+'}DTSID')),('CreationName',''),('Description','Full ETL master parameter'),('IncludeInDebugDump','0'),('Required','0'),('Sensitive','0'),('Value',param.findtext('{'+D+'}Property')),('DataType','9' if param.get('{'+D+'}DataType')=='3' else '18')]:
    E.SubElement(props,'{'+S+'}Property',{'{'+S+'}Name':key}).text=value
for meta in r.xpath('//*[local-name()="PackageMetaData"]'):
 name=meta.get('{'+S+'}Name');path=O/name
 if not path.exists():continue
 package=E.parse(str(path)).getroot()
 names={'ID':'DTSID','Name':'ObjectName','VersionBuild':'VersionBuild','VersionGUID':'VersionGUID'}
 for prop in meta.findall('./{'+S+'}Properties/{'+S+'}Property'):
  key=prop.get('{'+S+'}Name')
  if key in names:prop.text=package.get('{'+D+'}'+names[key])
r.write(str(O/'NYCTaxi_ETL.dtproj'),encoding='utf-8',xml_declaration=True)
# Defensive handler settings.
for p in O.glob('*.dtsx'):
 r=E.parse(str(p))
 for task in r.xpath('//*[local-name()="EventHandler"]//*[local-name()="Executable"]'):task.set('{'+D+'}DisableEventHandlers','True')
 r.write(str(p),encoding='utf-8',xml_declaration=True)
# Install synchronized Python schema profiles.
out=R/'etl/python';out.mkdir(exist_ok=True)
for name in ['download_nyc_parquet.py','convert_nyc_parquet_to_csv.py','inspect_extract_file.py','extract_contract.py']:
 text=((R/'etl/original-python')/name).read_text(encoding='utf-8-sig')
 if name=='convert_nyc_parquet_to_csv.py':
  a=text.index('PROFILES = {');b=text.index('\n\ndef valid_month',a)
  text=text[:a]+'from extract_contract import DATASETS as CONTRACT_DATASETS, OPTIONAL\nPROFILES = {name: profile[3] for name, profile in CONTRACT_DATASETS.items()}\n'+text[b:]
 (out/name).write_text(text,encoding='utf-8')
