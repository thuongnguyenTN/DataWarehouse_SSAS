from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E
import hashlib,json,re
r=Path('C:/Users/ADMIN/Downloads/Nhom04_ThietKeMucLogic_DACK.docx');p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');n={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(r) as a,ZipFile(p) as b:
 changes=[x for x in a.namelist() if a.read(x)!=b.read(x)]
 x=E.fromstring(b.read('word/document.xml'));tables=x.findall('.//w:tbl',n)
 cap=[]
 for t in tables:
  prev=t.getprevious();s=''.join(prev.xpath('.//w:t/text()',namespaces=n)) if prev is not None else ''
  assert re.match(r'Bảng \d+\.\d+ ',s),s
  cap.append(s)
 print('changed parts',changes);print('tables',len(tables),'captioned',len(cap),'shaded',len(x.findall('.//w:tbl//w:shd',n)))
 assert len(x.findall('.//w:tbl//w:shd',n))==0
 assert set(changes)<=set(['word/document.xml','word/settings.xml','word/styles.xml'])
 print('reference hash',hashlib.sha256(r.read_bytes()).hexdigest())
 Path('report_work/final-audit.json').write_text(json.dumps({'tables':len(tables),'captioned':len(cap),'changed_parts':changes,'reference_sha256':hashlib.sha256(r.read_bytes()).hexdigest(),'render_engine':'Microsoft Word','page_count':371,'no_table_shading':True},ensure_ascii=False,indent=2),encoding='utf-8')
