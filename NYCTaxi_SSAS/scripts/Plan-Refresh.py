"""Generate an atomic incremental refresh XMLA and update local partitions.

Usage: python scripts/Plan-Refresh.py 202601
Review deployment/Refresh-202601.xmla before executing with Invoke-Ssas.ps1.
"""
from pathlib import Path
from copy import deepcopy
from datetime import datetime
import argparse, shutil
from lxml import etree as E

ap=argparse.ArgumentParser()
ap.add_argument('month',type=int)
args=ap.parse_args()
year,month=divmod(args.month,100)
if not (1900<=year<=9998 and 1<=month<=12):ap.error('Use YYYYMM, with month 01..12.')
root=Path(__file__).resolve().parents[1]
model=root/'NYCTaxi_SSAS'
ns='http://schemas.microsoft.com/analysisservices/2003/engine'
xsi='http://www.w3.org/2001/XMLSchema-instance'
def q(n):return '{'+ns+'}'+n
def add(p,n,t=None,**kwargs):
 e=E.SubElement(p,q(n),**kwargs)
 if t is not None:e.text=str(t)
 return e
def value(p,n):return p.findtext(q(n))
parts=E.parse(str(model/'DSV_NYCTaxi.partitions'),E.XMLParser(remove_blank_text=True))
batch=E.Element(q('Batch'),nsmap={None:ns,'xsi':xsi},Transaction='true')
def obj(parent,gid=None,pid=None,dim=None):
 o=add(parent,'Object');add(o,'DatabaseID','NYCTaxi_SSAS')
 if dim:add(o,'DimensionID',dim)
 else:
  add(o,'CubeID','DSV_NYCTaxi')
  if gid:add(o,'MeasureGroupID',gid)
  if pid:add(o,'PartitionID',pid)
 return o
for p in sorted(model.glob('*.dim')):
 dim=value(E.parse(str(p)).getroot(),'ID')
 proc=add(batch,'Process');obj(proc,dim=dim);add(proc,'Type','ProcessUpdate')
lower=args.month*100+1
upper=((year*100+month+1)*100+1) if month<12 else (year+1)*10000+101
predicate=f'PickupDateKey >= {lower} AND PickupDateKey < {upper}'
selected=[]
for mg in parts.findall('.//'+q('MeasureGroup')):
 gid=value(mg,'ID');pp=mg.find(q('Partitions'))
 if 'Snapshot' in gid:
  selected.extend((gid,value(p,'ID')) for p in pp)
  continue
 other=next(p for p in pp if value(p,'ID').endswith('Other Dates'))
 pid=gid+' '+str(args.month)
 current=next((p for p in pp if value(p,'ID')==pid),None)
 if current is None:
  # Clone settings and retain the source table prefix from the catch-all.
  current=deepcopy(other)
  current.find(q('ID')).text=pid;current.find(q('Name')).text=pid
  query=current.find('./'+q('Source')+'/'+q('QueryDefinition'))
  query.text=query.text.split(' WHERE ',1)[0]+' WHERE '+predicate
  pp.insert(len(pp)-1,current)
  create=add(batch,'Create',AllowOverwrite='false')
  parent=add(create,'ParentObject');add(parent,'DatabaseID','NYCTaxi_SSAS');add(parent,'CubeID','DSV_NYCTaxi');add(parent,'MeasureGroupID',gid)
  add(create,'ObjectDefinition').append(deepcopy(current))
  catchall=other.find('./'+q('Source')+'/'+q('QueryDefinition'))
  catchall.text+=' AND NOT ('+predicate+')'
  alter=add(batch,'Alter',AllowCreate='false',ObjectExpansion='ExpandFull')
  obj(alter,gid,value(other,'ID'))
  add(alter,'ObjectDefinition').append(deepcopy(other))
 selected.extend([(gid,pid),(gid,value(other,'ID'))])
for gid,pid in selected:
 proc=add(batch,'Process');obj(proc,gid,pid);add(proc,'Type','ProcessFull')
# ProcessUpdate on flexible relationships can invalidate other aggregations.
proc=add(batch,'Process');obj(proc);add(proc,'Type','ProcessIndexes')
backup=root/'backups'/('partitions-before-refresh-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'.partitions')
shutil.copy2(model/'DSV_NYCTaxi.partitions',backup)
parts.write(str(model/'DSV_NYCTaxi.partitions'),encoding='utf-8',pretty_print=True)
output=root/'deployment'/f'Refresh-{args.month}.xmla'
E.ElementTree(batch).write(str(output),encoding='utf-8',pretty_print=True)
print('Plan generated; no server changes:',output)
print('Includes dimension updates, selected month + catch-all, snapshots and index rebuild.')
print('Run: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Process -XmlaPath',output)
