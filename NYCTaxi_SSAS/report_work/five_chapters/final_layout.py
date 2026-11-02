from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from lxml import etree as E
p=Path('BaoCao_NYCTaxi_5Chuong.docx');n={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(p) as z:parts=[(i,z.read(i.filename)) for i in z.infolist()];x=E.fromstring(z.read('word/document.xml'))
for el in x.findall('.//w:body/w:p',n):
 t=''.join(el.xpath('.//w:t/text()',namespaces=n))
 if t.startswith('Khối dimension biểu thị ngữ cảnh tham chiếu dùng chung;'):
  el.getparent().remove(el)
with ZipFile(p,'w',ZIP_DEFLATED) as z:
 for i,b in parts:z.writestr(i,E.tostring(x,encoding='UTF-8',xml_declaration=True,standalone=True) if i.filename=='word/document.xml' else b)
