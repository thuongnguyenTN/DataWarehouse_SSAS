from pypdf import PdfReader
from pathlib import Path
import json
r=PdfReader('report_work/revision/report.pdf');ts=[p.extract_text() or '' for p in r.pages];print('pages',len(ts));print('errors',[i+1 for i,t in enumerate(ts) if 'Error!' in t or 'No table of contents' in t]);print('blank',[i+1 for i,t in enumerate(ts) if not t.strip()]);print('first',ts[0][:700]);print('lists',[(i+1,t[:110]) for i,t in enumerate(ts) if t.startswith('DANH MỤC')]);print('figurepages',[(i+1,t[-160:]) for i,t in enumerate(ts) if 'Hình 1.1 Các nhóm' in t]);Path('report_work/revision/text.json').write_text(json.dumps(ts,ensure_ascii=False),encoding='utf-8')
