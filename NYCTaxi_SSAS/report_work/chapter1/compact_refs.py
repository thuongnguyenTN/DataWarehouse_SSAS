from docx import Document
from docx.shared import Pt
p='Chuong1_TongQuanDuLieu_NYCTaxi.docx';d=Document(p)
for pp in d.paragraphs:
 if pp.text.startswith('['):
  pp.paragraph_format.line_spacing=1.0;pp.paragraph_format.space_after=Pt(5)
  for r in pp.runs:r.font.size=Pt(12)
d.save(p)
