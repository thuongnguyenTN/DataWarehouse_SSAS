from pathlib import Path
from PIL import Image,ImageDraw
import subprocess
from pypdf import PdfReader
root=Path('report_work');pdf=root/'verified.pdf';out=root/'pages-final';out.mkdir(exist_ok=True)
binary=r'C:\Users\ADMIN\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\poppler\Library\bin\pdftoppm.exe'
subprocess.run([binary,'-scale-to','500','-png',str(pdf),str(out/'page')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
files=sorted(out.glob('page-*.png'));print('pages',len(files))
for start in range(0,len(files),36):
 sheet=Image.new('RGB',(1800,2520),'#bcbcbc');draw=ImageDraw.Draw(sheet)
 for j,path in enumerate(files[start:start+36]):
  im=Image.open(path);im.thumbnail((290,395));x=(j%6)*300;y=(j//6)*420;sheet.paste(im,(x,y+20));draw.text((x+5,y+3),str(start+j+1),fill='black')
 sheet.save(root/('final-contact-'+str(start//36+1)+'.jpg'))
print('sheets',(len(files)+35)//36)
# Text sanity and page-level density evidence
reader=PdfReader(pdf);texts=[p.extract_text() or '' for p in reader.pages]
print('blank pages',[i+1 for i,t in enumerate(texts) if not t.strip()]);print('field errors',[(i+1,t[:150]) for i,t in enumerate(texts) if 'No table of contents entries found' in t or 'Error! Reference' in t]);print('very short pages',[(i+1,len(t)) for i,t in enumerate(texts) if len(t)<140]);
(root/'page-texts.json').write_text(__import__('json').dumps(texts,ensure_ascii=False),encoding='utf-8')

