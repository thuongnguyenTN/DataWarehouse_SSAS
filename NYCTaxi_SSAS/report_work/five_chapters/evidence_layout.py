from pathlib import Path
from copy import deepcopy
from docx import Document
from docx.shared import Cm,Pt
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
import csv
p=Path('BaoCao_NYCTaxi_5Chuong.docx');d=Document(p)
for para in d.paragraphs:
 if para.text.startswith('Bảng B.') and 'row-counts.csv' in para.text and para._p.getnext().tag==qn('w:tbl'):
  note=d.add_paragraph('Bảng row-counts.csv là ảnh chụp metadata ngày 19 tháng 10 năm 2026, trước lần rà soát ngày 31 tháng 10. Số dòng trong bảng này được giữ như bằng chứng lịch sử; không dùng thay tổng 558.183 chuyến hợp lệ của lần rà soát về sau. Các bảng kiểm tra khác cần được đọc theo thời điểm bằng chứng tương ứng.');para._p.addprevious(note._p)
for old in list(d.tables):
 if len(old.columns)==9 and old.cell(0,0).text=='ForeignKey':
  with open('evidence/foreign-key-audit.csv',encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
  t=d.add_table(rows=1,cols=5);t.autofit=False
  border=old._tbl.tblPr.find(qn('w:tblBorders'))
  if border is not None:t._tbl.tblPr.append(deepcopy(border))
  widths=[6.2,2.4,1.4,3.5,2.5]
  for c,width in zip(t.columns,widths):c.width=Cm(width)
  for c,txt in zip(t.rows[0].cells,['Fact cột và FK','FactRows','Orphan','Unknown dòng và %','Enabled và Trusted']):c.text=txt
  for x in rows:
   vals=[x['Fact']+'.'+x['Column']+'\n'+x['ForeignKey'],x['FactRows'],x['Orphans'],x['UnknownRows']+'; '+x['UnknownPercent']+'%',x['Enabled']+' / '+x['Trusted']]
   for c,txt in zip(t.add_row().cells,vals):c.text=txt
  for i,row in enumerate(t.rows):
   row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
   if i==0:row._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
   for j,c in enumerate(row.cells):
    c.width=Cm(widths[j])
    for pp in c.paragraphs:
     pp.paragraph_format.line_spacing=1.1;pp.paragraph_format.space_after=Pt(3);pp.paragraph_format.space_before=Pt(3)
     for rr in pp.runs:rr.font.name='Times New Roman';rr.font.size=Pt(12);rr.bold=i==0
  old._tbl.addprevious(t._tbl);old._tbl.getparent().remove(old._tbl)
d.save(p)
print('Evidence chronology clarified and FK audit table reformatted')
