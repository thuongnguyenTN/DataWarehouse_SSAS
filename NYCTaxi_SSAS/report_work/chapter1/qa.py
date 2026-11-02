from pathlib import Path
from pypdf import PdfReader
from PIL import Image,ImageDraw
from docx import Document
import subprocess,json
r=Path('report_work/chapter1');out=r/'pages';out.mkdir(exist_ok=True);binary=r'C:\Users\ADMIN\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\poppler\Library\bin\pdftoppm.exe'
subprocess.run([binary,'-scale-to','900','-png',str(r/'chapter1.pdf'),str(out/'page')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
files=sorted(out.glob('page-*.png'))
for start in range(0,len(files),9):
 im=Image.new('RGB',(1800,2700),'#bababa');dr=ImageDraw.Draw(im)
 for j,f in enumerate(files[start:start+9]):
  pg=Image.open(f);pg.thumbnail((580,850));xx=(j%3)*600;yy=(j//3)*900;im.paste(pg,(xx,yy+25));dr.text((xx+5,yy+5),str(start+j+1),fill='black')
 im.save(r/('contact-'+str(start//9+1)+'.jpg'))
d=Document('Chuong1_TongQuanDuLieu_NYCTaxi.docx');pdf=PdfReader(r/'chapter1.pdf');print('pages',len(pdf.pages),'blank',[i+1 for i,p in enumerate(pdf.pages) if not p.extract_text().strip()]);print('tables',len(d.tables),'shading',len(d._element.xpath('.//w:tbl//w:shd')))
