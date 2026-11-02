from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from lxml import etree as E
p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');ref=Path('report_work/word-refreshed-final.docx');ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(p) as z:parts=[(i,z.read(i.filename)) for i in z.infolist()];styles=E.fromstring(z.read('word/styles.xml'))
with ZipFile(ref) as z:body=z.read('word/document.xml');wstyles=E.fromstring(z.read('word/styles.xml'))
ids={a.get('{'+ns['w']+'}styleId') for a in styles};used={a.get('{'+ns['w']+'}val') for a in E.fromstring(body).findall('.//w:pStyle',ns)}
for st in wstyles:
 if st.get('{'+ns['w']+'}styleId') in used-ids:styles.append(st)
with ZipFile(p,'w',ZIP_DEFLATED) as z:
 for i,b in parts:z.writestr(i,body if i.filename=='word/document.xml' else E.tostring(styles,xml_declaration=True,encoding='UTF-8',standalone=True) if i.filename=='word/styles.xml' else b)
print('Cached TOC saved with required styles')
