from pathlib import Path
from datetime import datetime
from lxml import etree as E
import shutil
R=Path(__file__).resolve().parents[1];live=Path('E:/NYCTaxi/NYCTaxi_DW/NYCTaxi_ETL');out=R/'etl/packages'
backup=R/'etl/backups'/('package-load-fix-'+datetime.now().strftime('%Y%m%d-%H%M%S'));backup.mkdir(parents=True)
D='www.microsoft.com/SqlServer/Dts';q=lambda s:'{'+D+'}'+s
parser=E.XMLParser(remove_blank_text=True)
for path in sorted(live.glob('*.dtsx')):
 shutil.copy2(path,backup/path.name)
 tree=E.parse(str(path),parser);changes=[]
 for e in tree.xpath('//*[local-name()="PackageParameter" or local-name()="PrecedenceConstraint"]'):
  if q('CreationName') not in e.attrib:
   e.set(q('CreationName'),'');changes.append(E.QName(e).localname+':CreationName')
 for parameter in tree.findall('.//'+q('PackageParameter')):
  for prop in parameter.findall(q('Property')):
   if prop.get(q('Name'))=='ParameterValue' and prop.get(q('DataType')) is None:
    prop.set(q('DataType'),parameter.get(q('DataType')))
    changes.append(parameter.get(q('ObjectName'))+':ParameterValue.DataType')
 for handler in tree.findall('.//'+q('EventHandler')):
  if handler.find(q('LoggingOptions')) is None:
   opts=E.Element(q('LoggingOptions'));opts.set(q('LoggingMode'),'0')
   executables=handler.find(q('Executables'))
   handler.insert(list(handler).index(executables) if executables is not None else len(handler),opts)
   changes.append('OnError:LoggingOptions')
 tree.write(str(out/path.name),encoding='utf-8',xml_declaration=True,pretty_print=True)
 print(path.name,changes)
# Preserve current .dtproj for metadata backup; package IDs/parameters are unchanged.
shutil.copy2(live/'NYCTaxi_ETL.dtproj',backup/'NYCTaxi_ETL.dtproj')
print('Backup:',backup)
