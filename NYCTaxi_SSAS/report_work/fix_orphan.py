from zipfile import ZipFile,ZIP_DEFLATED
from lxml import etree as E
from pathlib import Path
p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');n={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(p) as z:parts=[(i,z.read(i.filename)) for i in z.infolist()];x=E.fromstring(z.read('word/document.xml'))
for pp in x.findall('.//w:p',n):
 ts=pp.findall('.//w:t',n);s=''.join(t.text or '' for t in ts)
 if s.startswith('Aggregation design Operational của Zone_Traffic:'):
  ts[0].text='Operational của Zone Traffic có hai aggregation: Month Service theo tháng và dịch vụ; Date Borough theo ngày và Borough của Snapshot Location. Khóa tháng giữ năm theo dimension.'
  for t in ts[1:]:t.text=''
with ZipFile(p,'w',ZIP_DEFLATED) as z:
 for i,b in parts:z.writestr(i,E.tostring(x,encoding='UTF-8',xml_declaration=True,standalone=True) if i.filename=='word/document.xml' else b)
