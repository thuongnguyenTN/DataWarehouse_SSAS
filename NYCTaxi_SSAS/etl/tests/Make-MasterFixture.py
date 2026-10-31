from pathlib import Path
from lxml import etree as E
import uuid
R=Path(__file__).resolve().parents[2];D='www.microsoft.com/SqlServer/Dts';d=lambda n:'{'+D+'}'+n
tree=E.parse(str(R/'etl/packages/PKG_00_Master.dtsx'));root=tree.getroot()
for node in root.findall(d('EventHandlers')):root.remove(node)
connections=E.SubElement(root,d('ConnectionManagers'))
connections.append(E.parse('E:/NYCTaxi/NYCTaxi_DW/NYCTaxi_ETL/NYCTaxi_DWH.conmgr').getroot())
for p in root.find(d('PackageParameters')):
 name=p.get(d('ObjectName'));v=p.find(d('Property'))
 if name=='pRunnerPath':v.text=str(R/'etl/tests/Fake-StageRunner.ps1')
 if name=='pShowMonitor':v.text='0'
run=str(uuid.uuid4())
for data in root.xpath('//*[local-name()="SqlTaskData"]'):
 ns=data.tag.split('}')[0]+'}'
 data.set(ns+'SqlStatementSource',"DECLARE @r nvarchar(64)=?, @e nvarchar(4000)=?; DECLARE @m nvarchar(2047)=LEFT(CONCAT(N'FIXTURE_FAILURE_BRANCH RunId=',@r,N' ',@e),2000); RAISERROR(N'%s',16,1,@m);")
for p in root.find(d('PackageParameters')):
 if p.get(d('ObjectName'))=='pResumeRunId':p.find(d('Property')).text=run
tree.write(str(R/'etl/tests/MasterFailureFixture.dtsx'),encoding='utf-8',xml_declaration=True)
print(run)
