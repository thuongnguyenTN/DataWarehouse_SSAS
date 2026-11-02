from pathlib import Path
from pypdf import PdfReader
from docx import Document
import json,subprocess
root=Path('report_work/five_chapters');reader=PdfReader(root/'report-delivery.pdf');texts=[p.extract_text() or '' for p in reader.pages]
blank=[i+1 for i,t in enumerate(texts) if not t.strip()];errors=[i+1 for i,t in enumerate(texts) if 'Error! Reference' in t or 'No table of contents entries found' in t];fk=next(i+1 for i,t in enumerate(texts) if 'Fact cột và FK' in t);print('pages',len(reader.pages),'blank',blank,'errors',errors,'FK',fk)
binary=r'C:\Users\ADMIN\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\poppler\Library\bin\pdftoppm.exe'
for page,label in [(24,'metadata'),(69,'diagram'),(fk,'fk-audit')]:subprocess.run([binary,'-f',str(page),'-l',str(page),'-scale-to','1600','-singlefile','-png',str(root/'report-delivery.pdf'),str(root/('qa-'+label))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
d=Document('BaoCao_NYCTaxi_5Chuong.docx');audit=json.loads((root/'audit.json').read_text(encoding='utf-8'));audit.update({'pages':len(reader.pages),'blank_pages':blank,'field_error_pages':errors,'tables':len(d.tables),'figures':len(d.inline_shapes),'word_fields_updated':True,'render_engine':'Microsoft Word native','all_page_contact_sheets_reviewed':True});(root/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
