from pathlib import Path
from lxml import etree as E
import json, hashlib
out=Path(__file__).parent
project=Path('E:/NYCTaxi/NYCTaxi_DW/NYCTaxi_ETL')
records=[]
for p in project.glob('*.dtsx'):
 r=E.parse(str(p)); tasks=[]; folder=out/p.stem;folder.mkdir(exist_ok=True)
 for t in r.xpath('/*/*[local-name()="Executables"]/*'):
  name=t.get('{www.microsoft.com/SqlServer/Dts}ObjectName')
  sql=t.xpath('./*[local-name()="ObjectData"]/*[local-name()="SqlTaskData"]');tasks.append(name)
  if sql:(folder/(name+'.sql')).write_text(sql[0].get('{www.microsoft.com/sqlserver/dts/tasks/sqltask}SqlStatementSource'),encoding='utf-8')
 records.append({'package':p.name,'tasks':tasks,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'packages.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps(records,indent=2))
