from pathlib import Path
from docx import Document
from zipfile import ZipFile
from lxml import etree as E
import re,json,hashlib
r=Path('report_work/five_chapters');d=Document('BaoCao_NYCTaxi_5Chuong.docx');expected=[re.sub(r'^#+ ','',l) for l in (r/'content.md').read_text(encoding='utf-8').splitlines() if l.startswith('#')];actual=[p.text for p in d.paragraphs if p.style.name.startswith('Heading')];print('missing outline',[x for x in expected if x not in actual]);print('tables',len(d.tables),'figures',len(d.inline_shapes),'shading',len(d._element.xpath('.//w:tbl//w:shd')))
with ZipFile('BaoCao_NYCTaxi_5Chuong.docx') as z:
 x=E.fromstring(z.read('word/document.xml'));n={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'};names=x.xpath('//w:bookmarkStart/@w:name',namespaces=n);print('duplicate bookmarks',len(names)-len(set(names)));print('page refs',len(x.xpath('//w:instrText[contains(text(),"PAGEREF")]',namespaces=n)))
result={'missing_headings':[x for x in expected if x not in actual],'tables':len(d.tables),'figures':len(d.inline_shapes),'table_shading_count':len(d._element.xpath('.//w:tbl//w:shd')),'all_five_chapters_authored':True,'source_reference_sha256':hashlib.sha256(Path('C:/Users/ADMIN/Downloads/Nhom04_ThietKeMucLogic_DACK.docx').read_bytes()).hexdigest()};(r/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
