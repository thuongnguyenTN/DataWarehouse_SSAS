"""Check the required SSIS metadata that plain XML parsing does not validate.

The SSIS specification permits UI-generated child ordering differences. This
checks required metadata, handler shape and graph references, not execution.
"""
from pathlib import Path
from lxml import etree as E
import json,sys
ROOT=Path(__file__).resolve().parents[1]
D='{www.microsoft.com/SqlServer/Dts}'
X='{http://www.w3.org/2001/XMLSchema}'
schema=E.parse(str(ROOT/'etl/dtsx2-2014-reference.xsd'))
def attrs(group):
 node=schema.xpath('//*[@name=$n]',n=group)[0]
 required=[x.get('name') for x in node.findall(X+'attribute') if x.get('use')=='required']
 for ref in node.findall(X+'attributeGroup'):required.extend(attrs(ref.get('ref').split(':')[-1]))
 return required

def check(path):
 r=E.parse(str(path));errors=[]
 for node in r.findall('.//'+D+'PackageParameter'):
  for name in attrs('PackageParameterType'):
   if D+name not in node.attrib:errors.append(f'PackageParameter {node.get(D+"ObjectName")}: missing {name}')
  values=[x for x in node.findall(D+'Property') if x.get(D+'Name')=='ParameterValue']
  if len(values)!=1:errors.append('PackageParameter '+node.get(D+'ObjectName')+': expected one ParameterValue')
  for value in values:
   if value.get(D+'DataType')!=node.get(D+'DataType'):
    errors.append('PackageParameter '+node.get(D+'ObjectName')+': ParameterValue DataType missing/mismatch')
 for node in r.findall('.//'+D+'PrecedenceConstraint'):
  for name in attrs('PrecedenceConstraintType'):
   if D+name not in node.attrib:errors.append(f'PrecedenceConstraint {node.get(D+"ObjectName")}: missing {name}')
 for handler in r.findall('.//'+D+'EventHandler'):
  if handler.find(D+'LoggingOptions') is None:errors.append('OnError missing LoggingOptions')
 for container in r.xpath('//*[local-name()="Executable" or local-name()="EventHandler"]'):
  refs={x.get(D+'refId') for x in container.findall('./'+D+'Executables/'+D+'Executable')}
  for edge in container.findall('./'+D+'PrecedenceConstraints/'+D+'PrecedenceConstraint'):
   if edge.get(D+'From') not in refs or edge.get(D+'To') not in refs:errors.append('Unknown precedence endpoint')
 return errors

if __name__=='__main__':
 target=Path(sys.argv[1]) if len(sys.argv)>1 else Path('E:/NYCTaxi/NYCTaxi_DW/NYCTaxi_ETL')
 records=[]
 for p in sorted(target.glob('*.dtsx')):
  errors=check(p);records.append({'file':str(p),'errors':errors});print(p.name, 'PASS' if not errors else errors)
 (ROOT/'etl/package-metadata-check.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
 if any(x['errors'] for x in records):raise SystemExit(1)
