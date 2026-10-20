"""Complete the existing multidimensional project from captured SQL metadata.

Run only after Inspect-Environment.ps1. A timestamped backup precedes every write.
"""
from pathlib import Path
from collections import defaultdict
from copy import deepcopy
from datetime import datetime
import json, re, shutil, csv, calendar
from lxml import etree as E

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / 'NYCTaxi_SSAS'
BACKUP = ROOT / 'backups' / datetime.now().strftime('%Y%m%d-%H%M%S')
BACKUP.mkdir(parents=True)
for p in MODEL.iterdir():
    if p.is_file(): shutil.copy2(p, BACKUP / p.name)
for p in (ROOT / 'README.md', ROOT / 'queries/smoke.mdx'):
    if p.exists(): shutil.copy2(p, BACKUP / p.name)

A='http://schemas.microsoft.com/analysisservices/2003/engine'
X='http://www.w3.org/2001/XMLSchema'
I='http://www.w3.org/2001/XMLSchema-instance'
D='urn:schemas-microsoft-com:xml-msdata'
P='urn:schemas-microsoft-com:xml-msprop'
def q(n): return '{'+A+'}'+n
def add(p,n,t=None,**kw):
    e=E.SubElement(p,q(n),**kw)
    if t is not None: e.text=str(t)
    return e
def child(p,n): return p.find(q(n))
def val(p,n): return p.findtext(q(n))
def put(p,n,t):
    e=child(p,n)
    if e is None: e=add(p,n)
    e.text=str(t)
    return e
def load(n): return E.parse(str(MODEL/n),E.XMLParser(remove_blank_text=True))
def save(tree,n): tree.write(str(MODEL/n),encoding='utf-8',xml_declaration=False,pretty_print=True)
def read(n): return json.loads((ROOT/'evidence'/n).read_text(encoding='utf-8-sig'))
ds=load('DS_NYCTaxi_DWH.ds')
put(ds.getroot(),'ConnectionString',val(ds.getroot(),'ConnectionString').replace('Provider=SQLOLEDB.1','Provider=MSOLEDBSQL'))
save(ds,'DS_NYCTaxi_DWH.ds')
cols=defaultdict(list)
for c in read('columns.json'): cols[c['TableName']].append(c)
fks=read('foreign-keys.json'); pks=defaultdict(list)
for k in read('primary-keys.json'): pks[k['TableName']].append(k['ColumnName'])
types={'int':('int','Integer'),'smallint':('short','SmallInt'),'tinyint':('unsignedByte','UnsignedTinyInt'),
       'bigint':('long','BigInt'),'bit':('boolean','Boolean'),'decimal':('decimal','Decimal'),
       'date':('dateTime','Date'),'datetime2':('dateTime','Date'),'varchar':('string','WChar'),
       'nvarchar':('string','WChar'),'char':('string','WChar'),'binary':('base64Binary','Binary')}
def info(table,col): return next(c for c in cols[table] if c['ColumnName']==col)
def binding(parent, table,col, dtype=None):
    c=info(table,col) if col in [c['ColumnName'] for c in cols[table]] else None
    add(parent,'DataType',dtype or types[c['DataType']][1])
    if c and types[c['DataType']][1]=='WChar': add(parent,'DataSize',c['MaxLength']//(2 if c['DataType']=='nvarchar' else 1))
    s=add(parent,'Source',**{'{'+I+'}type':'ColumnBinding'})
    add(s,'TableID','dbo_'+table);add(s,'ColumnID',col)

# Extra counts retain the correct population for nullable metrics. SQL expressions
# are named calculations in the DSV only; no DWH object or data is changed.
computed={}
for table in ['Fact_FHV_Trips','Fact_HVFHV_Trips','Fact_YellowGreen_Trips']:
    expr={}
    for col in ['TripDurationSeconds','TripDistanceMiles','WaitingTimeSeconds','FareAmount','BasePassengerFare','TipAmount']:
        if any(c['ColumnName']==col for c in cols[table]):
            expr[col+'ValidTrips']=f'CASE WHEN [{col}] IS NOT NULL THEN [TripCount] ELSE 0 END'
    if table!='Fact_FHV_Trips':
        expr['SpeedDistanceMiles']='CASE WHEN TripDurationSeconds > 0 AND TripDistanceMiles >= 0 THEN TripDistanceMiles ELSE NULL END'
        expr['SpeedDurationSeconds']='CASE WHEN TripDurationSeconds > 0 AND TripDistanceMiles >= 0 THEN TripDurationSeconds ELSE NULL END'
        fare='FareAmount' if table=='Fact_YellowGreen_Trips' else 'BasePassengerFare'
        expr['TipPairAmount']=f'CASE WHEN TipAmount IS NOT NULL AND {fare} IS NOT NULL THEN TipAmount ELSE NULL END'
        expr['TipPairFare']=f'CASE WHEN TipAmount IS NOT NULL AND {fare} IS NOT NULL THEN {fare} ELSE NULL END'
    computed[table]=expr

# Rebuild just the DSV schema from actual catalog columns and actual PK/FKs.
dsv=load('DSV_NYCTaxi.dsv'); r=dsv.getroot()
put(r,'ID','DSV_NYCTaxi_DWH');put(r,'Name','DSV_NYCTaxi_DWH')
old=child(r,'Schema'); old.clear()
schema=E.SubElement(old,'{'+X+'}schema',nsmap={None:'','xs':X,'msdata':D,'msprop':P},id='DSV_NYCTaxi_DWH')
dataset=E.SubElement(schema,'{'+X+'}element',name='DSV_NYCTaxi_DWH',**{'{'+D+'}IsDataSet':'true','{'+D+'}UseCurrentLocale':'true'})
choice=E.SubElement(E.SubElement(dataset,'{'+X+'}complexType'),'{'+X+'}choice',minOccurs='0',maxOccurs='unbounded')
for table,cc in cols.items():
    el=E.SubElement(choice,'{'+X+'}element',name='dbo_'+table,**{'{'+P+'}FriendlyName':table,'{'+P+'}TableType':'Table','{'+P+'}DbSchemaName':'dbo','{'+P+'}DbTableName':table})
    seq=E.SubElement(E.SubElement(el,'{'+X+'}complexType'),'{'+X+'}sequence')
    for c in cc:
        attrs={'name':c['ColumnName'],'type':'xs:'+types[c['DataType']][0],'{'+P+'}DbColumnName':c['ColumnName']}
        if c['Nullable']:attrs['minOccurs']='0'
        ce=E.SubElement(seq,'{'+X+'}element',**attrs)
        if c['DataType'] in ('varchar','nvarchar','char'):
            del ce.attrib['type']
            restriction=E.SubElement(E.SubElement(ce,'{'+X+'}simpleType'),'{'+X+'}restriction',base='xs:string')
            E.SubElement(restriction,'{'+X+'}maxLength',value=str(c['MaxLength']//(2 if c['DataType']=='nvarchar' else 1)))
    for col,expr in computed.get(table,{}).items():
        typ='decimal' if col in ('SpeedDistanceMiles','TipPairAmount','TipPairFare') else 'long'
        E.SubElement(seq,'{'+X+'}element',name=col,type='xs:'+typ,minOccurs='0',**{'{'+P+'}ComputedColumnExpression':expr})
for table,keys in pks.items():
    if table not in cols:continue
    unique=E.SubElement(dataset,'{'+X+'}unique',name='PK_'+table,**{'{'+D+'}PrimaryKey':'true'})
    E.SubElement(unique,'{'+X+'}selector',xpath='.//dbo_'+table)
    for col in keys:E.SubElement(unique,'{'+X+'}field',xpath=col)
for fk in fks:
    if fk['FactTable'] not in cols or fk['DimTable'] not in cols:continue
    keyref=E.SubElement(dataset,'{'+X+'}keyref',name=fk['FKName'],refer='PK_'+fk['DimTable'],**{'{'+D+'}RelationName':fk['FKName']})
    E.SubElement(keyref,'{'+X+'}selector',xpath='.//dbo_'+fk['FactTable'])
    E.SubElement(keyref,'{'+X+'}field',xpath=fk['FactColumn'])
save(dsv,'DSV_NYCTaxi.dsv')

dimensions={}
for path in MODEL.glob('*.dim'):
    t=load(path.name); root=t.getroot(); put(child(root,'Source'),'DataSourceViewID','DSV_NYCTaxi_DWH')
    dimensions[val(root,'ID')]=t

# Create the missing ETL lineage dimension.
t=E.ElementTree(E.Element(q('Dimension'),nsmap={None:A,'xsi':I}))
r=t.getroot();add(r,'ID','Dim Load Batch');add(r,'Name','Dim Load Batch')
s=add(r,'Source',**{'{'+I+'}type':'DataSourceViewBinding'});add(s,'DataSourceViewID','DSV_NYCTaxi_DWH')
attrs=add(r,'Attributes')
for c in cols['Dim_LoadBatch']:
    if c['ColumnName']=='LoadedAt':continue
    name=re.sub(r'(?<!^)(?=[A-Z][a-z])',' ',c['ColumnName'])
    if c['ColumnName']=='LoadBatchKey':name='Load Batch Key'
    a=add(attrs,'Attribute');add(a,'ID',name);add(a,'Name',name)
    if c['ColumnName']=='LoadBatchKey':add(a,'Usage','Key')
    binding(add(add(a,'KeyColumns'),'KeyColumn'),'Dim_LoadBatch',c['ColumnName'])
    if c['ColumnName']=='LoadBatchKey':binding(add(a,'NameColumn'),'Dim_LoadBatch','BatchID')
key=child(attrs,'Attribute'); rels=add(key,'AttributeRelationships')
for a in list(attrs)[1:]:add(add(rels,'AttributeRelationship'),'AttributeID',val(a,'ID'))
dimensions['Dim Load Batch']=t

def attr(root,name):return next(a for a in child(root,'Attributes') if val(a,'ID')==name)
def relation(root,src,dst):
    a=attr(root,src); rels=child(a,'AttributeRelationships')
    if rels is None:rels=add(a,'AttributeRelationships')
    if not any(val(rel,'AttributeID')==dst for rel in rels):add(add(rels,'AttributeRelationship'),'AttributeID',dst)
def keycol(root,attribute,table,column):
    kc=child(attr(root,attribute),'KeyColumns');kc.clear();binding(add(kc,'KeyColumn'),table,column)

date=dimensions['Dim Date'].getroot()
keycol(date,'Full Date','Dim_Date','DateKey')
keycol(date,'Month Number','Dim_Date','YearNumber')
binding(add(child(attr(date,'Month Number'),'KeyColumns'),'KeyColumn'),'Dim_Date','MonthNumber')
if child(attr(date,'Month Number'),'NameColumn') is None:binding(add(attr(date,'Month Number'),'NameColumn'),'Dim_Date','MonthName')
if child(attr(date,'Full Date'),'NameColumn') is None:binding(add(attr(date,'Full Date'),'NameColumn'),'Dim_Date','FullDate')
put(child(attr(date,'Full Date'),'NameColumn'),'DataType','WChar')
put(child(attr(date,'Full Date'),'NameColumn'),'DataSize','10')
put(date,'Type','Time')
relation(date,'Full Date','Month Number');relation(date,'Month Number','Quarter Number');relation(date,'Quarter Number','Year Number')
tm=dimensions['Dim Time'].getroot();keycol(tm,'Time Label','Dim_Time','TimeKey')
keycol(tm,'Hour Number','Dim_Time','TimeBand')
binding(add(child(attr(tm,'Hour Number'),'KeyColumns'),'KeyColumn'),'Dim_Time','HourNumber')
nc=child(attr(tm,'Hour Number'),'NameColumn')
if nc is not None:attr(tm,'Hour Number').remove(nc)
binding(add(attr(tm,'Hour Number'),'NameColumn'),'Dim_Time','HourNumber','WChar')
relation(tm,'Time Label','Hour Number');relation(tm,'Hour Number','Time Band')
loc=dimensions['Dim Location'].getroot()
keycol(loc,'Borough','Dim_Location','Borough')
nc=child(attr(loc,'Borough'),'NameColumn')
if nc is not None:attr(loc,'Borough').remove(nc)
binding(add(attr(loc,'Borough'),'NameColumn'),'Dim_Location','Borough')
rels=child(attr(loc,'Borough'),'AttributeRelationships')
if rels is not None:rels.clear()
relation(loc,'Location Key','Zone Name');relation(loc,'Zone Name','Borough')
for root,key,targets in [(date,'Date Key',['Month Number','Quarter Number','Year Number']),(tm,'Time Key',['Hour Number','Time Band']),(loc,'Location Key',['Borough'])]:
    rels=child(attr(root,key),'AttributeRelationships')
    for rel in list(rels):
        if val(rel,'AttributeID') in targets:rels.remove(rel)
for dimid,t in dimensions.items():
    r=t.getroot();put(r,'UnknownMember','Visible');put(r,'UnknownMemberName','Unknown (unresolved key)')
    err=child(r,'ErrorConfiguration')
    if err is None:err=add(r,'ErrorConfiguration')
    for field in ['KeyNotFound','KeyDuplicate','NullKeyNotAllowed']:put(err,field,'ReportAndStop')
    # Explicit key=0 rows remain ordinary dimension members. NULL attributes map
    # to blank/zero, never silently discard fact rows with absent keys.
    for a in child(r,'Attributes'):
        for kc in child(a,'KeyColumns'):put(kc,'NullProcessing','ZeroOrBlank')
    for source in r.findall('.//'+q('Source')):
        table=val(source,'TableID');col=val(source,'ColumnID')
        if not table or not col:continue
        c=info(table.removeprefix('dbo_'),col);parent=source.getparent()
        if c['DataType'] in ('varchar','nvarchar','char'):
            # AMO DataItem.DataSize is a byte count; WChar needs two bytes.
            put(parent,'DataType','WChar');put(parent,'DataSize',c['MaxLength'] if c['DataType']=='nvarchar' else c['MaxLength']*2)
        elif val(parent,'DataType')=='WChar':put(parent,'DataSize','50')
    save(t,dimid+'.dim')

cube=load('DSV_NYCTaxi.cube');r=cube.getroot();put(r,'Name','NYC Taxi Analysis')
put(child(r,'Source'),'DataSourceViewID','DSV_NYCTaxi_DWH')
cdims=child(r,'Dimensions')
def cube_dim(dimid,role):
    for d in cdims:
        if val(d,'ID')==role:return d
    dbdim=dimensions[dimid].getroot()
    d=add(cdims,'Dimension');add(d,'ID',role);add(d,'Name',role);add(d,'DimensionID',dimid)
    aa=add(d,'Attributes')
    for a in child(dbdim,'Attributes'):add(add(aa,'Attribute'),'AttributeID',val(a,'ID'))
    hh=child(dbdim,'Hierarchies')
    if hh is not None:
        ch=add(d,'Hierarchies')
        for h in hh:add(add(ch,'Hierarchy'),'HierarchyID',val(h,'ID'))
    return d
cube_dim('Dim Load Batch','Dim Load Batch')
for dim,role in [('Dim Date','Snapshot Date'),('Dim Time','Snapshot Time'),('Dim Location','Snapshot Location')]:cube_dim(dim,role)
def role_for(fk):
    col=fk['FactColumn']; dim=fk['DimTable']
    if dim=='Dim_Date':return 'Snapshot Date' if col=='DateKey' else col.replace('DateKey',' Date').replace('OnScene','On Scene')
    if dim=='Dim_Time':return 'Snapshot Time' if col=='TimeKey' else col.replace('TimeKey',' Time').replace('OnScene','On Scene')
    if dim=='Dim_Location':return 'Snapshot Location' if col=='LocationKey' else col.replace('LocationKey',' Location')
    if dim=='Dim_Base':return col.replace('BaseKey',' Base')
    return {'Dim_HVFHSProvider':'Dim HVFHS Provider','Dim_ServiceType':'Dim Service Type',
      'Dim_LoadBatch':'Dim Load Batch','Dim_HVFHVFlags':'Dim HVFHV Flags','Dim_FHVFlags':'Dim FHV Flags',
      'Dim_TaxiFlags':'Dim Taxi Flags','Dim_PassengerGroup':'Dim Passenger Group','Dim_RateCode':'Dim Rate Code',
      'Dim_PaymentType':'Dim Payment Type','Dim_TripType':'Dim Trip Type'}.get(dim,dim.replace('_',' '))

groups=child(r,'MeasureGroups'); measuremap={}
for g in list(groups):
    if 'Snapshot' in val(g,'ID'): groups.remove(g); continue
    for m in list(child(g,'Measures')):
        col=val(child(child(m,'Source'),'Source'),'ColumnID')
        if col.endswith('ValidTrips') or col in ('SpeedDistanceMiles','SpeedDurationSeconds','TipPairAmount','TipPairFare'):child(g,'Measures').remove(m)
snapshot={
 'Fact_Daily_Financial_Snapshot':('Daily Financial Snapshot',['TotalTrips','TotalDistanceMiles','TotalPassengerCharges','TotalTips','TotalTaxesAndFees','TotalDriverPay']),
 'Fact_Zone_Traffic_Snapshot':('Zone Traffic Snapshot',['TotalPickups','TotalDropoffs']),
 'Fact_Base_Performance_Snapshot':('Base Performance Snapshot',['TotalTrips','TotalTripDurationSeconds','DurationTripCount','TotalWaitingTimeSeconds','WaitingTripCount','TotalSharedRequests','TotalSharedMatches','TotalWAVRequests','TotalWAVMatches','TotalDriverPay'])}
for table,(name,measures) in snapshot.items():
    g=add(groups,'MeasureGroup');add(g,'ID',name);add(g,'Name',name);mm=add(g,'Measures')
    for col in measures:
        info(table,col)
        m=add(mm,'Measure');add(m,'ID',name+' '+col);add(m,'Name',name+' '+col);add(m,'AggregateFunction','Sum')
        binding(add(m,'Source'),table,col)
    add(g,'StorageMode','Molap');add(g,'ProcessingMode','Regular');add(g,'Dimensions')

for g in groups:
    gid=val(g,'ID'); mm=child(g,'Measures')
    table=val(child(child(mm[0],'Source'),'Source'),'TableID').removeprefix('dbo_')
    for m in mm:
        put(m,'AggregateFunction','Sum');put(m,'DisplayFolder',gid)
        col=val(child(child(m,'Source'),'Source'),'ColumnID')
        if col=='TripCount': put(child(m,'Source'),'DataType','BigInt')
        measuremap[(table,col)]=val(m,'Name')
    for col in computed.get(table,{}):
        m=add(mm,'Measure');name=gid+' '+col;add(m,'ID',name);add(m,'Name',name);add(m,'AggregateFunction','Sum')
        binding(add(m,'Source'),table,col,'Double' if col in ('SpeedDistanceMiles','TipPairAmount','TipPairFare') else 'BigInt')
        add(m,'Visible','false');measuremap[(table,col)]=name
    dd=child(g,'Dimensions');dd.clear()
    for fk in fks:
        if fk['FactTable']!=table:continue
        role=role_for(fk)
        cd=next(d for d in cdims if val(d,'ID')==role)
        dbdim=dimensions[val(cd,'DimensionID')].getroot()
        key=next(a for a in child(dbdim,'Attributes') if val(a,'Usage')=='Key')
        d=add(dd,'Dimension',**{'{'+I+'}type':'RegularMeasureGroupDimension'});add(d,'CubeDimensionID',role)
        aa=add(add(d,'Attributes'),'Attribute');add(aa,'AttributeID',val(key,'ID'))
        binding(add(add(aa,'KeyColumns'),'KeyColumn'),table,fk['FactColumn']);add(aa,'Type','Granularity')
    put(g,'IgnoreUnrelatedDimensions','false')

# Replace the provisional MDX with explicit, source-scoped metrics.
def ref(table,col):return '[Measures].['+measuremap[(table,col)]+']'
mdx=['CALCULATE;']
def calc(name,expr,folder='Analysis',fmt='#,##0.00'):
    mdx.append(f"CREATE MEMBER CURRENTCUBE.[Measures].[{name}] AS {expr}, FORMAT_STRING = '{fmt}', DISPLAY_FOLDER = '{folder}', VISIBLE = 1;")
def ratio(name,num,den,folder,scale=1,fmt='#,##0.00'):
    calc(name,f'IIF(IsEmpty({den}) OR {den} = 0, NULL, ({num}) / ({den}) * {scale})',folder,fmt)
trans=['Fact_FHV_Trips','Fact_HVFHV_Trips','Fact_YellowGreen_Trips']
calc('Total Trips All Services',' + '.join('CoalesceEmpty('+ref(t,'TripCount')+',0)' for t in trans),'Overview','#,##0')
for table in trans:
    label={'Fact_FHV_Trips':'FHV','Fact_HVFHV_Trips':'HVFHV','Fact_YellowGreen_Trips':'YellowGreen'}[table]
    ratio(label+' Average Trip Duration Minutes',ref(table,'TripDurationSeconds'),ref(table,'TripDurationSecondsValidTrips'),label,1/60)
    if table=='Fact_FHV_Trips':continue
    ratio(label+' Average Trip Distance',ref(table,'TripDistanceMiles'),ref(table,'TripDistanceMilesValidTrips'),label)
    ratio(label+' Average Speed MPH',ref(table,'SpeedDistanceMiles'),ref(table,'SpeedDurationSeconds'),label,3600)
    fare='FareAmount' if label=='YellowGreen' else 'BasePassengerFare'
    ratio(label+' Average Fare Per Trip',ref(table,fare),ref(table,fare+'ValidTrips'),label)
    ratio(label+' Average Tip Per Trip',ref(table,'TipAmount'),ref(table,'TipAmountValidTrips'),label)
    ratio(label+' Tip Percentage',ref(table,'TipPairAmount'),ref(table,'TipPairFare'),label,1,'0.00%')
    if label=='HVFHV':ratio('HVFHV Average Waiting Minutes',ref(table,'WaitingTimeSeconds'),ref(table,'WaitingTimeSecondsValidTrips'),label,1/60)
base='Fact_Base_Performance_Snapshot'
ratio('Base Average Duration Minutes',ref(base,'TotalTripDurationSeconds'),ref(base,'DurationTripCount'),'Base Performance',1/60)
ratio('Base Average Waiting Minutes',ref(base,'TotalWaitingTimeSeconds'),ref(base,'WaitingTripCount'),'Base Performance',1/60)
# Rates are scoped to HVFHV, whose flags and waiting/request data are available.
hv='([Dim Service Type].[Service Code].&[FHVHV])'
den='('+ref(base,'TotalTrips')+', '+hv[1:-1]+')'
num='('+ref(base,'TotalSharedRequests')+', '+hv[1:-1]+')'
ratio('Shared Request Rate',num,den,'Base Performance',1,'0.00%')
ratio('WAV Match Rate',ref(base,'TotalWAVMatches'),ref(base,'TotalWAVRequests'),'Base Performance',1,'0.00%')
child(child(child(child(r,'MdxScripts'),'MdxScript'),'Commands'),'Command').find(q('Text')).text='\n'.join(mdx)
save(cube,'DSV_NYCTaxi.cube')

# SQL-profiled monthly partitions plus a disjoint catch-all retain unknown dates
# and future ETL months until the partition plan is regenerated.
parts=load('DSV_NYCTaxi.partitions');pr=parts.getroot();pg=child(pr,'MeasureGroups');pg.clear()
months=defaultdict(list)
with (ROOT/'evidence/months.csv').open(encoding='utf-8-sig',newline='') as f:
    for row in csv.DictReader(f):
        ym=int(row['YearMonth'])
        if ym>0:months[row['FactTable']].append(ym)
process=[]
for g in groups:
    table=val(child(child(child(g,'Measures')[0],'Source'),'Source'),'TableID').removeprefix('dbo_')
    mg=add(pg,'MeasureGroup');add(mg,'ID',val(g,'ID'));pp=add(mg,'Partitions')
    # Explicit aggregation design: calendar month/service and date/borough.
    designs=child(g,'AggregationDesigns')
    if designs is not None:g.remove(designs)
    designs=add(g,'AggregationDesigns');design=add(designs,'AggregationDesign');add(design,'ID','Operational');add(design,'Name','Operational')
    da=add(design,'Dimensions')
    for d in child(g,'Dimensions'):
        di=add(da,'Dimension');add(di,'CubeDimensionID',val(d,'CubeDimensionID'))
    aggs=add(design,'Aggregations')
    roles={val(d,'CubeDimensionID'):d for d in child(g,'Dimensions')}
    date_role='Pickup Date' if table in computed else 'Snapshot Date'
    for aid,settings in [('Month Service',[(date_role,'Month Number'),('Dim Service Type','Service Type Key')]),('Date Borough',[(date_role,'Date Key'),('Pickup Location' if table in computed else 'Snapshot Location','Borough')])]:
        if any(role not in roles for role,_ in settings):continue
        ag=add(aggs,'Aggregation');add(ag,'ID',aid);add(ag,'Name',aid);ds=add(ag,'Dimensions')
        for role,attribute in settings:
            d=add(ds,'Dimension');add(d,'CubeDimensionID',role);add(add(add(d,'Attributes'),'Attribute'),'AttributeID',attribute)
    if table in computed:
        plan=[(str(ym),f'PickupDateKey >= {ym*100+1} AND PickupDateKey < {(ym+1)*100+1 if ym%100<12 else (ym//100+1)*10000+101}') for ym in sorted(months[table])]
        covered=' OR '.join('('+where+')' for _,where in plan)
        plan.append(('Other Dates','NOT ('+covered+')'))
    else:plan=[('All',None)]
    for suffix,where in plan:
        pid=val(g,'ID')+' '+suffix
        p=add(pp,'Partition');add(p,'ID',pid);add(p,'Name',pid)
        if where:
            s=add(p,'Source',**{'{'+I+'}type':'QueryBinding'});add(s,'DataSourceID','DS_NYCTaxi_DWH')
            add(s,'QueryDefinition','SELECT * FROM dbo.['+table+'] WHERE '+where)
        else:
            s=add(p,'Source',**{'{'+I+'}type':'DsvTableBinding'});add(s,'DataSourceViewID','DSV_NYCTaxi_DWH');add(s,'TableID','dbo_'+table)
        add(p,'StorageMode','Molap');add(p,'ProcessingMode','Regular');add(p,'AggregationDesignID','Operational')
        process.append((val(g,'ID'),pid))
save(parts,'DSV_NYCTaxi.partitions')
save(cube,'DSV_NYCTaxi.cube')
dep=ROOT/'deployment';dep.mkdir(exist_ok=True)
def process_xml(name,selected):
    batch=E.Element(q('Batch'),nsmap={None:A},Transaction='true');parallel=add(batch,'Parallel',**{'MaxParallel':'2'})
    for gid,pid in selected:
        proc=add(parallel,'Process');obj=add(proc,'Object');add(obj,'DatabaseID','NYCTaxi_SSAS');add(obj,'CubeID',val(r,'ID'));add(obj,'MeasureGroupID',gid);add(obj,'PartitionID',pid);add(proc,'Type','ProcessFull')
    E.ElementTree(batch).write(str(dep/name),encoding='utf-8',pretty_print=True)
process_xml('Process-All-Partitions.xmla',process)
process_xml('Process-Test-202501.xmla',[(g,p) for g,p in process if p.endswith('202501')])
process_xml('Process-Snapshots.xmla',[(g,p) for g,p in process if 'Snapshot' in g])
proj=load('NYCTaxi_SSAS.dwproj');root=proj.getroot()
def plain(p,n,t=None):
    e=E.SubElement(p,n)
    if t is not None:e.text=t
    return e
if not any(i.findtext('FullPath')=='Dim Load Batch.dim' for i in root.find('Dimensions')):
    pi=plain(root.find('Dimensions'),'ProjectItem');plain(pi,'Name','Dim Load Batch.dim');plain(pi,'FullPath','Dim Load Batch.dim')
dsvs=root.find('DataSourceViews')
for pi in list(dsvs):
    if pi.findtext('FullPath')!='DSV_NYCTaxi.dsv':dsvs.remove(pi)
opts=root.find('./Configurations/Configuration/Options')
for v in opts.findall('./ConnectionMappings/ConfigurationSetting/Value'):
    v.text=v.text.replace('Provider=SQLOLEDB.1','Provider=MSOLEDBSQL')
for name,value in [('DeploymentServerName','THUONGNGUYEN\\MSSQLSV'),('DeploymentServerDatabase','NYCTaxi_SSAS')]:
    e=opts.find(name)
    if e is None:e=plain(opts,name)
    e.text=value
save(proj,'NYCTaxi_SSAS.dwproj')
print('Backup:',BACKUP)
print('Updated: 15 dimensions, 21 DSV tables, 6 measure groups; SQL-derived PK/FK usage.')
