from pathlib import Path
from lxml import etree as E
import re
D='{www.microsoft.com/SqlServer/Dts}';S='{www.microsoft.com/sqlserver/dts/tasks/sqltask}'
def apply(path):
 tree=E.parse(str(path))
 for task in tree.findall('./'+D+'Executables/'+D+'Executable'):
  node=task.find('.//'+S+'SqlTaskData')
  if node is None:continue
  sql=node.get(S+'SqlStatementSource');name=task.get(D+'ObjectName')
  sql=sql.replace("L.LoaderVersion<>'FILE_V1_20261031'","L.LoaderVersion<>CASE WHEN S.DatasetCode='fhv' THEN 'FILE_FHV_V2_20261031' ELSE 'FILE_V1_20261031' END")
  if 'Dimensions' in name:
   a=sql.index(' INSERT dbo.Dim_FHVFlags');b=sql.index(' ;WITH F AS',a)
   sql=sql[:a]+sql[a:b].replace("CASE WHEN UPPER(C.SharedRequestFlag) IN('Y','N') THEN UPPER(C.SharedRequestFlag) ELSE 'U' END","CASE C.SourceSRFlag WHEN '1' THEN 'Y' WHEN '0' THEN 'N' ELSE 'U' END")+sql[b:]
  if name=='EST_03_Load_FactFHV':
   if 'C.SourceSRFlag AS SourceSRFlag' not in sql:sql=sql.replace('C.SharedRequestFlag AS SharedRequestFlag,','C.SharedRequestFlag AS SharedRequestFlag, C.SourceSRFlag AS SourceSRFlag,')
   sql=re.sub(r"CASE\s+WHEN UPPER\(C.SharedRequestFlag\) IN \('Y', 'N'\)\s+THEN UPPER\(C.SharedRequestFlag\)\s+ELSE 'U'\s+END","CASE C.SourceSRFlag WHEN '1' THEN 'Y' WHEN '0' THEN 'N' ELSE 'U' END",sql)
   sql=sql.replace("@Token,'FILE_V1_20261031'","@Token,'FILE_FHV_V2_20261031'")
  node.set(S+'SqlStatementSource',sql)
 for h in tree.findall('.//'+D+'EventHandler'):
  if h.find(D+'LoggingOptions') is None:h.insert(0,E.Element(D+'LoggingOptions',{D+'LoggingMode':'0'}))
 tree.write(str(path),encoding='utf-8',xml_declaration=True)
if __name__=='__main__':
 import sys
 apply(Path(sys.argv[1]))
