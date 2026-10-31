from pathlib import Path
from copy import deepcopy
from lxml import etree as E
import uuid,json
R=Path.cwd(); P=R/'etl/original-packages'; O=R/'etl/packages';O.mkdir(exist_ok=True)
D='www.microsoft.com/SqlServer/Dts';S='www.microsoft.com/sqlserver/dts/tasks/sqltask'
def d(x):return '{'+D+'}'+x
def uid():return '{'+str(uuid.uuid4()).upper()+'}'
parser=E.XMLParser(remove_blank_text=False)
# Add provenance and exact reconciliation while preserving unmanaged legacy rows.
r=E.parse(str(P/'PKG_03_Load_DWH.dtsx'),parser)
tasks=r.xpath('/*/*[local-name()="Executables"]/*')
pre=tasks[0].find('.//{'+S+'}SqlTaskData');sql=pre.get('{'+S+'}SqlStatementSource')
sql+='''\nIF OBJECT_ID('etl.FactChangeAudit','U') IS NULL CREATE TABLE etl.FactChangeAudit(
 AuditId bigint IDENTITY PRIMARY KEY,TableName sysname NOT NULL,RowJson nvarchar(max) NOT NULL,
 DeletedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME());\n'''
for table in ['Fact_YellowGreen_Trips','Fact_FHV_Trips','Fact_HVFHV_Trips']:
 for col,typ in [('SourceDataset','varchar(20)'),('SourceKey','nvarchar(260)')]:
  sql+=f"IF COL_LENGTH('dbo.{table}','{col}') IS NULL ALTER TABLE dbo.{table} ADD {col} {typ} NULL;\n"
pre.set('{'+S+'}SqlStatementSource',sql)
for task in tasks[2:5]:
 data=task.find('.//{'+S+'}SqlTaskData');sql=data.get('{'+S+'}SqlStatementSource')
 import re
 table=re.search(r'INSERT INTO dbo\.(Fact_\w+)',sql)[1]
 sql=sql.replace('C.RecordHash AS RecordHash','C.RecordHash AS RecordHash, LOWER(C.TaxiType) AS SourceDataset, C.ETLSourceKey AS SourceKey')
 # fhvhv corresponds to FHVHV; lowercase maps exactly to ExtractFileLog code.
 insert=sql.index('    INSERT INTO dbo.'+table)
 prefix=sql[:insert];tail=sql[insert:]
 # Materialize CTE so update/delete/insert share exactly the same desired rows.
 prefix+='    SELECT * INTO #Desired FROM FactValues;\n    CREATE UNIQUE CLUSTERED INDEX IX_Desired_Hash ON #Desired(RecordHash);\n'
 prefix+=f'''    IF EXISTS(SELECT 1 FROM #Desired WHERE SourceKey IS NULL)
        THROW 55910,'Clean source lineage is missing; refusing fact reconciliation.',1;
    UPDATE F SET SourceDataset=V.SourceDataset,SourceKey=V.SourceKey
      FROM dbo.{table} F JOIN #Desired V ON V.RecordHash=F.RecordHash
      WHERE F.SourceKey IS NULL OR F.SourceKey<>V.SourceKey OR F.SourceDataset<>V.SourceDataset;
    IF EXISTS(SELECT 1 FROM dbo.{table} WHERE SourceKey IS NULL)
        THROW 55911,'Unmapped legacy facts exist. Restore clean history or perform reviewed migration; no automatic deletion.',1;
    INSERT etl.FactChangeAudit(TableName,RowJson)
      SELECT N'{table}',(SELECT F.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
      FROM dbo.{table} F
      WHERE NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash)
        AND EXISTS(SELECT 1 FROM NYCTaxi_Staging.etl.ExtractFileLog L
          WHERE L.DatasetCode=F.SourceDataset AND L.SourceKey=F.SourceKey AND L.LoadStatus='SUCCEEDED');
    DELETE F FROM dbo.{table} F
      WHERE NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash)
        AND EXISTS(SELECT 1 FROM NYCTaxi_Staging.etl.ExtractFileLog L
          WHERE L.DatasetCode=F.SourceDataset AND L.SourceKey=F.SourceKey AND L.LoadStatus='SUCCEEDED');
'''
 tail=tail.replace('RecordHash)\n','RecordHash, SourceDataset, SourceKey)\n').replace('V.RecordHash\n','V.RecordHash, V.SourceDataset, V.SourceKey\n').replace('FROM FactValues V','FROM #Desired V')
 # Refresh dimension keys as well, e.g. previously unknown codes now resolved.
 cols=re.search(r'INSERT INTO dbo\.\w+\s*\(([^)]+)\)',tail)[1].split(',')
 cols=[x.strip() for x in cols]
 prefix+=f"    UPDATE F SET "+','.join(f'{c}=V.{c}' for c in cols if c!='RecordHash')+f' FROM dbo.{table} F JOIN #Desired V ON V.RecordHash=F.RecordHash WHERE EXISTS (SELECT '+','.join('F.'+c for c in cols if c!='RecordHash')+' EXCEPT SELECT '+','.join('V.'+c for c in cols if c!='RecordHash')+');\n'
 sql=prefix+tail
 sql=sql.replace(' COMMIT TRAN;',' DROP TABLE #Desired;\n COMMIT TRAN;')
 data.set('{'+S+'}SqlStatementSource',sql)
validation=tasks[-1].find('.//{'+S+'}SqlTaskData')
validation_sql=validation.get('{'+S+'}SqlStatementSource')
validation_sql+='''
IF (SELECT COUNT_BIG(*) FROM dbo.Fact_YellowGreen_Trips)<>(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType IN('YELLOW','GREEN'))
 OR (SELECT COUNT_BIG(*) FROM dbo.Fact_FHV_Trips)<>(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHV')
 OR (SELECT COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips)<>(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHVHV')
 THROW 55912,'Exact clean-to-fact row reconciliation failed.',1;
'''
validation.set('{'+S+'}SqlStatementSource',validation_sql)
r.write(str(O/'PKG_03_Load_DWH.dtsx'),encoding='utf-8',xml_declaration=True)
# Native SSIS package aggregate path also reconciles historical changes atomically.
r=E.parse(str(P/'PKG_04_Load_Aggregates.dtsx'),parser)
tasks=r.xpath('/*/*[local-name()="Executables"]/*'); sqls=[t.find('.//{'+S+'}SqlTaskData').get('{'+S+'}SqlStatementSource') for t in tasks]
combined="SET XACT_ABORT ON; BEGIN TRY BEGIN TRANSACTION;\n"+sqls[0]+"\nDELETE FROM dbo.Fact_Daily_Financial_Snapshot; DELETE FROM dbo.Fact_Zone_Traffic_Snapshot; DELETE FROM dbo.Fact_Base_Performance_Snapshot; UPDATE etl.AggregateWatermark SET LastTripKey=0,UpdatedAt=SYSDATETIME();\n"
# Batches use local variables of repeated names: execute each task in its own dynamic batch.
for sql in sqls[1:]:combined+="EXEC sys.sp_executesql N'"+sql.replace("'","''")+"';\n"
combined+='COMMIT TRANSACTION; END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;'
# Keep standalone package task layout, route rebuilding through runner instead of duplicating SQL.
# Original SQL blocks remain available to the runner; native package uses one atomic rebuild task.
for idx,t in enumerate(tasks):
 if idx==0:t.find('.//{'+S+'}SqlTaskData').set('{'+S+'}SqlStatementSource',combined)
 else:t.find('.//{'+S+'}SqlTaskData').set('{'+S+'}SqlStatementSource',f"SELECT N'{t.get(d('ObjectName'))}: included in atomic rebuild' AS Result;")
# Expose a single atomic task rather than misleading independent commits.
first=tasks[0];first.set(d('ObjectName'),'EST_00_Atomic_Rebuild_And_Validate')
first.set(d('refId'),'Package\\EST_00_Atomic_Rebuild_And_Validate')
first.set(d('Description'),'Ensure schema, rebuild financial/traffic/base snapshots and validate in one transaction.')
container=first.getparent()
for t in list(container)[1:]:container.remove(t)
for tag in ('PrecedenceConstraints','DesignTimeProperties'):
 for node in r.getroot().findall(d(tag)):r.getroot().remove(node)
r.write(str(O/'PKG_04_Load_Aggregates.dtsx'),encoding='utf-8',xml_declaration=True)
# Master uses five visible stages; the runner executes existing SQL and bulk-copy without requiring DTExec.
master=E.parse(str(P/'PKG_00_Master.dtsx'),parser);root=master.getroot();root.set(d('ObjectName'),'PKG_00_Master');root.set(d('DelayValidation'),'True');root.set(d('MaxConcurrentExecutables'),'1')
for tag in ('Executables','PrecedenceConstraints','DesignTimeProperties','PackageParameters'):
 for e in root.findall(d(tag)):root.remove(e)
params=E.Element(d('PackageParameters'))
for name,value,typ in [('pStartMonth','2025-01','8'),('pEndMonth','2025-12','8'),('pMaxRows','100000','3'),('pRunnerPath',str(R/'etl/Invoke-NYCTaxiPipeline.ps1'),'8')]:
 e=E.SubElement(params,d('PackageParameter'),{d('CreationName'):'',d('DataType'):typ,d('DTSID'):uid(),d('ObjectName'):name})
 E.SubElement(e,d('Property'),{d('Name'):'ParameterValue',d('DataType'):typ}).text=value
root.insert(1,params)
ex=E.SubElement(root,d('Executables'));pc=E.SubElement(root,d('PrecedenceConstraints'))
for idx,stage in enumerate(['Extract','Transform','Dwh','Aggregates','Ssas']):
 name=f'EPT_{idx+1:02d}_{stage}';ref='Package\\'+name
 e=E.SubElement(ex,d('Executable'),{d('refId'):ref,d('CreationName'):'Microsoft.ExecuteProcess',d('ExecutableType'):'Microsoft.ExecuteProcess',d('DTSID'):uid(),d('ObjectName'):name,d('DelayValidation'):'True',d('FailPackageOnFailure'):'True'})
 E.SubElement(e,d('Variables'))
 expr=E.SubElement(e,d('PropertyExpression'),{d('Name'):'Arguments'})
 expr.text='"-NoProfile -ExecutionPolicy Bypass -File \\\"" + @[$Package::pRunnerPath] + "\\\" -Stage '+stage+' -StartMonth " + @[$Package::pStartMonth] + " -EndMonth " + @[$Package::pEndMonth] + " -MaxRows " + (DT_WSTR,12)@[$Package::pMaxRows] + " -RunId \\\"" + (DT_WSTR,50)@[System::ExecutionInstanceGUID] + "\\\""'
 E.SubElement(E.SubElement(e,d('ObjectData')),'ExecuteProcessData',Executable='C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',Arguments='-NoProfile',WorkingDirectory=str(R),SuccessValue='0',FailTaskIfReturnCodeIsNotSuccessValue='True',RequireFullFileName='True',WindowStyle='Hidden')
 if idx:
  E.SubElement(pc,d('PrecedenceConstraint'),{d('refId'):f'Package.PrecedenceConstraints[Stage{idx}]',d('CreationName'):'',d('DTSID'):uid(),d('ObjectName'):f'Stage{idx}',d('From'):'Package\\'+f'EPT_{idx:02d}_'+['Extract','Transform','Dwh','Aggregates','Ssas'][idx-1],d('To'):ref,d('Value'):'0',d('LogicalAnd'):'True'})
master.write(str(O/'PKG_00_Master.dtsx'),encoding='utf-8',xml_declaration=True)
# A package-level handler logs the original SSIS errors even for standalone package runs.
for filename in ['PKG_00_Master.dtsx','PKG_01_Extract_Stage.dtsx','PKG_02_Transform_Clean.dtsx','PKG_03_Load_DWH.dtsx','PKG_04_Load_Aggregates.dtsx']:
 path=O/filename;r=E.parse(str(path if filename in ('PKG_00_Master.dtsx','PKG_03_Load_DWH.dtsx','PKG_04_Load_Aggregates.dtsx') else P/filename),parser);root=r.getroot()
 for old_handler in root.findall(d('EventHandlers')):root.remove(old_handler)
 handlers=E.SubElement(root,d('EventHandlers'));h=E.SubElement(handlers,d('EventHandler'),{d('refId'):'Package.EventHandlers[OnError]',d('CreationName'):'OnError',d('DTSID'):uid(),d('EventID'):'9437328',d('EventName'):'OnError',d('LocaleID'):'1033',d('ObjectName'):'OnError'})
 E.SubElement(h,d('Variables'));E.SubElement(h,d('LoggingOptions'),{d('LoggingMode'):'0'});tasks=E.SubElement(h,d('Executables'))
 t=E.SubElement(tasks,d('Executable'),{d('refId'):'Package.EventHandlers[OnError]\\EST_LogOriginalError',d('CreationName'):'Microsoft.ExecuteSQLTask',d('ExecutableType'):'Microsoft.ExecuteSQLTask',d('DTSID'):uid(),d('ObjectName'):'EST_LogOriginalError',d('DelayValidation'):'True'})
 E.SubElement(t,d('Variables'));data=E.SubElement(E.SubElement(t,d('ObjectData')),'{'+S+'}SqlTaskData',{'{'+S+'}Connection':'{4A829E7F-DE39-4A39-83D3-52CE94E192E2}','{'+S+'}SqlStatementSource':'INSERT etl.PackageError(ExecutionId,PackageName,SourceName,ErrorCode,ErrorDescription) VALUES(?,?,?,?,?);'})
 for idx,(var,typ,size) in enumerate([('System::ExecutionInstanceGUID','130','64'),('System::PackageName','130','260'),('System::SourceName','130','260'),('System::ErrorCode','3','-1'),('System::ErrorDescription','130','4000')]):
  E.SubElement(data,'{'+S+'}ParameterBinding',{'{'+S+'}ParameterName':str(idx),'{'+S+'}DtsVariableName':var,'{'+S+'}ParameterDirection':'Input','{'+S+'}DataType':typ,'{'+S+'}ParameterSize':size})
 root.set(d('VersionBuild'),str(int(root.get(d('VersionBuild'),'0'))+1))
 root.set(d('VersionGUID'),uid())
 r.write(str(path),encoding='utf-8',xml_declaration=True)
from importlib.util import spec_from_file_location, module_from_spec
_spec=spec_from_file_location('historical_coverage',Path(__file__).parent/'Apply-HistoricalCoverage.py')
_coverage=module_from_spec(_spec);_spec.loader.exec_module(_coverage)
_coverage.apply(O/'PKG_01_Extract_Stage.dtsx')
_spec=spec_from_file_location('incremental_dwh',Path(__file__).parent/'Apply-IncrementalDwh.py')
_incremental=module_from_spec(_spec);_spec.loader.exec_module(_incremental)
_incremental.apply(O/'PKG_03_Load_DWH.dtsx')
_spec=spec_from_file_location('master_control',Path(__file__).parent/'Apply-MasterControl.py')
_master=module_from_spec(_spec);_spec.loader.exec_module(_master)
_master.apply(O/'PKG_00_Master.dtsx')
print('Prepared five packages:',O)
