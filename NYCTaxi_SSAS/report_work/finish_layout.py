from pathlib import Path
from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt
import zipfile
p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');d=Document(p)
for t in d.tables:
 for row in t.rows:
  trpr=row._tr.get_or_add_trPr()
  if trpr.find(qn('w:cantSplit')) is None:trpr.append(OxmlElement('w:cantSplit'))
# Add late lineage fields to the three physical fact dictionaries.
for para in d.paragraphs:
 if para.text.startswith('Bảng 1.') and any('Cấu trúc '+x in para.text for x in ['Fact_FHV_Trips','Fact_HVFHV_Trips','Fact_YellowGreen_Trips']):
  el=para._p.getnext()
  if el is not None and el.tag==qn('w:tbl'):
   from docx.table import Table
   t=Table(el,d._body)
   for vals in [('SourceDataset','varchar','Bổ sung sau bản chụp','Mã dataset nguồn để định phạm vi đồng bộ file; kết hợp SourceKey. Chiều dài và NULL cần đối chiếu DDL migration trên môi trường triển khai.'),('SourceKey','nvarchar','Bổ sung sau bản chụp','Khóa tên file nguồn để truy vết, chọn file hiệu chỉnh và checkpoint. Không phải mã chuyến và không thay thế RecordHash.')]:
    row=t.add_row()
    row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
    for c,v in zip(row.cells,vals):
     c.text=v
     for pp in c.paragraphs:
      pp.paragraph_format.line_spacing=1.15
      for r in pp.runs:r.font.name='Times New Roman';r.font.size=Pt(12)
# Correct statements about a now materialized list.
for para in d.paragraphs:
 if para.text.startswith('Mục lục và danh mục bảng là trường tự động'):
  para.text='Mục lục là trường tự động của Word. Danh mục bảng liệt kê các bảng theo số chương và số thứ tự để tra cứu. Các bảng được trình bày không tô màu theo mẫu tham chiếu.'
tmp=Path('report_work/final-layout.docx');d.save(tmp)
with zipfile.ZipFile(p) as z,zipfile.ZipFile(tmp) as n:
 contents={i.filename:z.read(i.filename) for i in z.infolist()};infos=z.infolist()
for name in ['word/document.xml','word/settings.xml']:contents[name]=zipfile.ZipFile(tmp).read(name)
with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED) as z:
 for i in infos:z.writestr(i,contents[i.filename])
print('layout and lineage updated')
