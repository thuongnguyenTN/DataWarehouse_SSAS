"""Add monitored execution and a real failure branch without replacing user defaults."""
from pathlib import Path
from lxml import etree as E
import uuid
import argparse
D='www.microsoft.com/SqlServer/Dts'; S='www.microsoft.com/sqlserver/dts/tasks/sqltask'
def d(n): return '{'+D+'}'+n
def uid(): return '{'+str(uuid.uuid4()).upper()+'}'
def literal(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
def apply(path):
    tree=E.parse(str(path)); root=tree.getroot()
    root.set(d('MaxConcurrentExecutables'),'1'); root.set(d('MaxErrorCount'),'100')
    params=root.find(d('PackageParameters'))
    values=[('pControllerPath',str(Path(__file__).parent/'Invoke-SsisStage.ps1'),'8'),('pResumeRunId','','8'),('pStartStage','Extract','8'),('pMaxRetries','1','3'),('pShowMonitor','1','3')]
    for name,value,typ in values:
        if any(p.get(d('ObjectName'))==name for p in params): continue
        p=E.SubElement(params,d('PackageParameter'),{d('CreationName'):'',d('DataType'):typ,d('DTSID'):uid(),d('ObjectName'):name})
        E.SubElement(p,d('Property'),{d('Name'):'ParameterValue',d('DataType'):typ}).text=value
    variables=root.find(d('Variables'))
    if variables is None: variables=E.SubElement(root,d('Variables'))
    for name in ['vRunId','vStageStdOut','vStageStdErr']:
        for old in list(variables):
            if old.get(d('ObjectName'))==name: variables.remove(old)
        attrs={d('CreationName'):'',d('DTSID'):uid(),d('Namespace'):'User',d('ObjectName'):name,d('IncludeInDebugDump'):'2345'}
        if name=='vRunId': attrs.update({d('EvaluateAsExpression'):'True',d('Expression'):'(LEN(@[$Package::pResumeRunId]) == 0) ? (DT_WSTR,50)@[System::ExecutionInstanceGUID] : @[$Package::pResumeRunId]'})
        v=E.SubElement(variables,d('Variable'),attrs);E.SubElement(v,d('VariableValue'),{d('DataType'):'8'})
    for tag in ['Executables','PrecedenceConstraints','DesignTimeProperties']:
        for old in root.findall(d(tag)): root.remove(old)
    tasks=E.SubElement(root,d('Executables')); edges=E.SubElement(root,d('PrecedenceConstraints'))
    stages=['Extract','Transform','Dwh','Aggregates','Ssas']
    names=['EPT_00_Open_Monitor']+['EPT_%02d_%s'%(i+1,s) for i,s in enumerate(stages)]+['EPT_99_Complete']
    for i,name in enumerate(names):
        op='Monitor' if i==0 else 'Complete' if i==6 else 'Stage'
        stage=stages[i-1] if 1<=i<=5 else 'Extract'
        task=E.SubElement(tasks,d('Executable'),{d('refId'):'Package\\'+name,d('CreationName'):'Microsoft.ExecuteProcess',d('ExecutableType'):'Microsoft.ExecuteProcess',d('DTSID'):uid(),d('ObjectName'):name,d('DelayValidation'):'True',d('FailPackageOnFailure'):'False',d('FailParentOnFailure'):'False'})
        E.SubElement(task,d('Variables'))
        parts=[literal('-NoProfile -ExecutionPolicy Bypass -File "'),'@[$Package::pControllerPath]',literal('" -Operation '+op+' -Stage '+stage+' -RunnerPath "'),'@[$Package::pRunnerPath]',literal('" -RunId "'),'@[User::vRunId]',literal('" -StartAt "'),'@[$Package::pStartStage]',literal('" -StartMonth '),'@[$Package::pStartMonth]',literal(' -EndMonth '),'@[$Package::pEndMonth]',literal(' -MaxRows '),'(DT_WSTR,12)@[$Package::pMaxRows]',literal(' -MaxRetries '),'(DT_WSTR,12)@[$Package::pMaxRetries]',literal(' -ShowMonitor '),'(DT_WSTR,12)@[$Package::pShowMonitor]']
        E.SubElement(task,d('PropertyExpression'),{d('Name'):'Arguments'}).text=' + '.join(parts)
        E.SubElement(E.SubElement(task,d('ObjectData')),'ExecuteProcessData',Executable=r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',Arguments='-NoProfile',WorkingDirectory=str(Path(__file__).parent.parent),SuccessValue='0',FailTaskIfReturnCodeIsNotSuccessValue='True',RequireFullFileName='True',WindowStyle='Hidden',StandardOutputVariable='User::vStageStdOut',StandardErrorVariable='User::vStageStdErr')
    fail='EST_90_Report_Original_Error'
    task=E.SubElement(tasks,d('Executable'),{d('refId'):'Package\\'+fail,d('CreationName'):'Microsoft.ExecuteSQLTask',d('ExecutableType'):'Microsoft.ExecuteSQLTask',d('DTSID'):uid(),d('ObjectName'):fail,d('DelayValidation'):'True',d('DisableEventHandlers'):'True',d('FailPackageOnFailure'):'True'})
    E.SubElement(task,d('Variables'))
    sql="DECLARE @r nvarchar(64)=?, @e nvarchar(4000)=?; INSERT etl.PackageError(ExecutionId,PackageName,SourceName,ErrorCode,ErrorDescription) VALUES(@r,N'PKG_00_Master',N'Master failure branch',55990,@e); DECLARE @m nvarchar(2047)=LEFT(CONCAT(N'Master failed. RunId=',@r,N'. ',COALESCE(NULLIF(@e,N''),N'See local ETL monitor/logs.')),2000); RAISERROR(N'%s',16,1,@m);"
    data=E.SubElement(E.SubElement(task,d('ObjectData')),'{'+S+'}SqlTaskData',{'{'+S+'}Connection':'{4A829E7F-DE39-4A39-83D3-52CE94E192E2}','{'+S+'}SqlStatementSource':sql})
    for i,(var,size) in enumerate([('User::vRunId','64'),('User::vStageStdErr','4000')]):
        E.SubElement(data,'{'+S+'}ParameterBinding',{'{'+S+'}ParameterName':str(i),'{'+S+'}DtsVariableName':var,'{'+S+'}ParameterDirection':'Input','{'+S+'}DataType':'130','{'+S+'}ParameterSize':size})
    def edge(a,b,failed,n):
        E.SubElement(edges,d('PrecedenceConstraint'),{d('refId'):'Package.PrecedenceConstraints['+n+']',d('CreationName'):'',d('DTSID'):uid(),d('ObjectName'):n,d('From'):'Package\\'+a,d('To'):'Package\\'+b,d('Value'):'1' if failed else '0',d('LogicalAnd'):'False' if failed else 'True'})
    for i in range(len(names)-1): edge(names[i],names[i+1],False,'Success'+str(i))
    for i,name in enumerate(names): edge(name,fail,True,'Failure'+str(i))
    for h in root.findall('.//'+d('EventHandler')):
        if h.find(d('LoggingOptions')) is None: E.SubElement(h,d('LoggingOptions'),{d('LoggingMode'):'0'})
    root.set(d('VersionBuild'),str(int(root.get(d('VersionBuild'),'0'))+1));root.set(d('VersionGUID'),uid())
    tree.write(str(path),encoding='utf-8',xml_declaration=True)
def sync(project,package):
    ns='www.microsoft.com/SqlServer/SSIS'; s=lambda n:'{'+ns+'}'+n
    tree=E.parse(str(project)); root=E.parse(str(package)).getroot()
    meta=next(m for m in tree.findall('.//'+s('PackageMetaData')) if m.get(s('Name'))=='PKG_00_Master.dtsx')
    for p in meta.findall('./'+s('Properties')+'/'+s('Property')):
        key=p.get(s('Name')); attr={'Name':'ObjectName','ID':'DTSID','VersionBuild':'VersionBuild','VersionGUID':'VersionGUID'}.get(key)
        if attr: p.text=root.get(d(attr))
    bucket=meta.find(s('Parameters'));bucket.clear()
    for p in root.find(d('PackageParameters')):
        item=E.SubElement(bucket,s('Parameter'),{s('Name'):p.get(d('ObjectName'))});props=E.SubElement(item,s('Properties'))
        for key,value in [('ID',p.get(d('DTSID'))),('CreationName',''),('Description','ETL Master control'),('IncludeInDebugDump','0'),('Required','0'),('Sensitive','0'),('Value',p.findtext(d('Property'))),('DataType','9' if p.get(d('DataType'))=='3' else '18')]:
            E.SubElement(props,s('Property'),{s('Name'):key}).text=value
    tree.write(str(project),encoding='utf-8',xml_declaration=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('package',type=Path);p.add_argument('--project',type=Path);a=p.parse_args();apply(a.package)
    if a.project: sync(a.project,a.package)
