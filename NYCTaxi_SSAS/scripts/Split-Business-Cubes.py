from pathlib import Path
from copy import deepcopy
from datetime import datetime
import re, shutil, json
from lxml import etree as E
R=Path(__file__).resolve().parents[1]; M=R/'NYCTaxi_SSAS'
N='http://schemas.microsoft.com/analysisservices/2003/engine'
def q(s): return '{'+N+'}'+s
def val(e,s): return e.findtext(q(s))
def save(e,p): E.ElementTree(e).write(str(p),encoding='utf-8',pretty_print=True)
source=M/'DSV_NYCTaxi.cube'
if not source.exists(): raise SystemExit('Combined source is absent; split already applied. Regenerate with Complete-Model.py if needed.')
backup=R/'backups'/('before-business-split-'+datetime.now().strftime('%Y%m%d-%H%M%S')); backup.mkdir(parents=True)
for p in M.iterdir():
 if p.is_file(): shutil.copy2(p,backup/p.name)
cube=E.parse(str(source)).getroot(); parts=E.parse(str(M/'DSV_NYCTaxi.partitions')).getroot()
configs=[('FHV Trips','Fact FHV Trips'),('HVFHV Trips','Fact HVFHV Trips'),('YellowGreen Trips','Fact Yellow Green Trips'),('Daily Financial','Daily Financial Snapshot'),('Zone Traffic','Zone Traffic Snapshot'),('Base Performance','Base Performance Snapshot')]
owner={}; group_owner={}; manifest=[]
for name,gid in configs:
 cid=name.replace(' ','_'); c=deepcopy(cube); c.find(q('ID')).text=cid; c.find(q('Name')).text=name
 for tag in ('Annotations','CreatedTimestamp','LastSchemaUpdate','LastProcessed','State'):
  for e in c.findall(q(tag)): c.remove(e)
 groups=c.find(q('MeasureGroups'))
 for g in list(groups):
  if val(g,'ID')!=gid: groups.remove(g)
 g=groups[0]; dims={val(d,'CubeDimensionID') for d in g.find(q('Dimensions'))}
 for d in list(c.find(q('Dimensions'))):
  if val(d,'ID') not in dims: c.find(q('Dimensions')).remove(d)
 names={val(m,'Name') for m in g.find(q('Measures'))}
 text=c.find('.//'+q('Command')+'/'+q('Text'))
 kept=['CALCULATE;']
 for statement in text.text.split(';'):
  if 'CREATE MEMBER' not in statement: continue
  refs=re.findall(r'\[Measures\]\.\[([^\]]+)\]',statement)
  if refs[0]=='Total Trips All Services': continue
  if set(refs[1:]) <= names:
   kept.append(statement.strip()+';'); names.add(refs[0])
 text.text='\n'.join(kept)
 save(c,M/(cid+'.cube'))
 p=deepcopy(parts)
 if p.find(q('ID')) is not None: p.find(q('ID')).text=cid
 if p.find(q('Name')) is not None: p.find(q('Name')).text=name
 for pg in list(p.find(q('MeasureGroups'))):
  if val(pg,'ID')!=gid: p.find(q('MeasureGroups')).remove(pg)
 save(p,M/(cid+'.partitions'))
 for measure in names: owner[measure]=name
 group_owner[gid]=cid; manifest.append({'id':cid,'name':name,'group':gid})
proj=E.parse(str(M/'NYCTaxi_SSAS.dwproj')); cubes=proj.getroot().find('Cubes'); cubes.clear()
for item in manifest:
 pi=E.SubElement(cubes,'ProjectItem')
 for tag in ('Name','FullPath'): E.SubElement(pi,tag).text=item['id']+'.cube'
 dep=E.SubElement(E.SubElement(pi,'Dependencies'),'ProjectItem')
 for tag in ('Name','FullPath'): E.SubElement(dep,tag).text=item['id']+'.partitions'
proj.write(str(M/'NYCTaxi_SSAS.dwproj'),encoding='utf-8',pretty_print=True)
(R/'scripts/cube-map.json').write_text(json.dumps({'cubes':manifest,'measures':owner},indent=2),encoding='utf-8')
for p in (R/'deployment').glob('Process-*.xmla'):
 tree=E.parse(str(p))
 for obj in tree.findall('.//'+q('Object')):
  gid=val(obj,'MeasureGroupID')
  if gid in group_owner: obj.find(q('CubeID')).text=group_owner[gid]
 tree.write(str(p),encoding='utf-8',pretty_print=True)
# Old generated refresh plans target the retired cube; preserve only as history.
for p in (R/'deployment').glob('Refresh-*.xmla'): shutil.move(str(p),str(backup/p.name))
source.unlink(); (M/'DSV_NYCTaxi.partitions').unlink()
print('Split into six business cubes; backup:',backup)
