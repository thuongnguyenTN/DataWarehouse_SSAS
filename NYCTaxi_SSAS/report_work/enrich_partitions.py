from pathlib import Path
from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, Inches
from lxml import etree as E
import re,zipfile,copy
p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');d=Document(p);ns={'a':'http://schemas.microsoft.com/analysisservices/2003/engine'}
def val(e,n):
 z=e.find('a:'+n,ns);return '' if z is None else z.text or ''
anchor=next(x._p for x in d.paragraphs if x.text.startswith('CHƯƠNG 4'))
seq=max(int(re.match(r'Bảng 3\.(\d+)',x.text).group(1)) for x in d.paragraphs if re.match(r'Bảng 3\.(\d+)',x.text))
section=d.add_paragraph('3.7 Cấu hình partition và aggregation design chi tiết','Heading 2');anchor.addprevious(section._p)
body=d.add_paragraph('Các cấu hình dưới đây lấy từ tệp partitions đi kèm cube. QueryDefinition xác định chính xác phạm vi vật lý; partition Other Dates phải loại các tháng đã tách để không cộng trùng. Trạng thái Unprocessed trong source thiết kế không phải trạng thái của server sau Process.');anchor.addprevious(body._p)
for path in sorted(Path('NYCTaxi_SSAS').glob('*.partitions')):
 root=E.parse(str(path)).getroot();rows=[]
 for x in root.findall('.//a:Partition',ns):
  rows.append([val(x,'Name'),val(x,'StorageMode')+'; '+val(x,'AggregationDesignID'),val(x.find('a:Source',ns),'QueryDefinition')])
 seq+=1;cap=d.add_paragraph(f'Bảng 3.{seq} Partition và truy vấn nguồn {path.stem}','Caption');anchor.addprevious(cap._p)
 t=d.add_table(rows=1,cols=3);t.autofit=False; t._tbl.tblPr.append(copy.deepcopy(d.tables[0]._tbl.tblPr.find(qn('w:tblBorders'))))
 for c,txt in zip(t.rows[0].cells,['Partition','Lưu trữ và design','QueryDefinition']):c.text=txt
 for row in rows:
  for c,txt in zip(t.add_row().cells,row):c.text=txt
 for i,row in enumerate(t.rows):
  row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
  for j,c in enumerate(row.cells):
   c.width=Inches([1.65,1.1,3.75][j])
   for pp in c.paragraphs:
    pp.paragraph_format.line_spacing=1.15
    for r in pp.runs:r.font.name='Times New Roman';r.font.size=Pt(12);r.bold=i==0
 t.rows[0]._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'));anchor.addprevious(t._tbl)
 for ad in root.findall('.//a:AggregationDesign',ns):
  text='Aggregation design '+val(ad,'Name')+' của '+path.stem+': '
  ag=[]
  for a in ad.findall('./a:Aggregations/a:Aggregation',ns):
   parts=[]
   for dd in a.findall('./a:Dimensions/a:Dimension',ns):parts.append(val(dd,'CubeDimensionID')+' ('+', '.join(z.text for z in dd.findall('.//a:AttributeID',ns))+')')
   ag.append(val(a,'Name')+' = '+'; '.join(parts))
  pp=d.add_paragraph(text+' | '.join(ag)+'.');anchor.addprevious(pp._p)
# Correct granularity labels where represented inside Attributes rather than direct child.
for para in d.paragraphs:
 if 'Dimension Usage ' in para.text and para.text.startswith('Bảng') and para._p.getnext().tag==qn('w:tbl'):
  cube=para.text.split('Dimension Usage ',1)[1]
  path=next((f for f in Path('NYCTaxi_SSAS').glob('*.cube') if val(E.parse(str(f)).getroot(),'Name')==cube),None)
  if path:
   root=E.parse(str(path)).getroot();m={}
   for el in root.findall('.//a:MeasureGroups/a:MeasureGroup/a:Dimensions/*',ns):
    m[val(el,'CubeDimensionID')]=', '.join(val(a,'AttributeID') for a in el.findall('./a:Attributes/a:Attribute',ns) if val(a,'Type')=='Granularity')
   from docx.table import Table
   t=Table(para._p.getnext(),d._body)
   for row in t.rows[1:]:
    if row.cells[0].text in m:row.cells[1].text=m[row.cells[0].text] or 'Theo khóa dimension'
# Precisely documented lineage migration types.
for t in d.tables:
 for row in t.rows:
  if len(row.cells)==4 and row.cells[2].text=='Bổ sung sau bản chụp':
   row.cells[1].text='varchar(20)' if row.cells[0].text=='SourceDataset' else 'nvarchar(260)';row.cells[2].text='Có theo DDL migration'
# Append supplementary captions to table list before chapter one.
listanchor=next(x._p for x in d.paragraphs if x.text.startswith('CHƯƠNG 1'))
for para in list(d.paragraphs):
 if re.match(r'Bảng 3\.',para.text) and 'Partition và truy vấn nguồn' in para.text:
  cp=copy.deepcopy(para._p);listanchor.addprevious(cp)
tmp=Path('report_work/enriched.docx');d.save(tmp)
with zipfile.ZipFile(p) as z:items=[(i,z.read(i.filename)) for i in z.infolist()]
with zipfile.ZipFile(tmp) as z:new=z.read('word/document.xml');styles=z.read('word/styles.xml')
with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED) as z:
 for i,b in items:z.writestr(i,new if i.filename=='word/document.xml' else styles if i.filename=='word/styles.xml' else b)
print('supplemented partitions',seq)


