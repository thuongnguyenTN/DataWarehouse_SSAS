from docx import Document
from pathlib import Path
import json,zipfile
from lxml import etree as E
p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');d=Document(p)
print('tables',len(d.tables),'paragraphs',len(d.paragraphs),'words',sum(len(p.text.split()) for p in d.paragraphs)+sum(len(c.text.split()) for t in d.tables for r in t.rows for c in r.cells))
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with zipfile.ZipFile(p) as z:
 x=E.fromstring(z.read('word/document.xml'));print('shading',len(x.findall('.//w:shd',ns)));print('sections',len(x.findall('.//w:sectPr',ns)))
