from zipfile import ZipFile,ZIP_DEFLATED
from lxml import etree as E
p='BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx';n={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(p) as z:parts=[(i,z.read(i.filename)) for i in z.infolist()];x=E.fromstring(z.read('word/document.xml'))
paras=x.findall('.//w:p',n);s=lambda el:''.join(el.xpath('.//w:t/text()',namespaces=n))
para=next(z for z in paras if s(z).startswith('Operational của Zone Traffic'))
anchor=next(z for z in paras if s(z).startswith('Các cấu hình dưới đây lấy từ tệp partitions'))
para.getparent().remove(para);anchor.addnext(para)
with ZipFile(p,'w',ZIP_DEFLATED) as z:
 for i,b in parts:z.writestr(i,E.tostring(x,encoding='UTF-8',xml_declaration=True,standalone=True) if i.filename=='word/document.xml' else b)
