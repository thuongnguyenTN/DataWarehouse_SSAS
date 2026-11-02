from pypdf import PdfReader
r=PdfReader('report_work/five_chapters/report.pdf')
for i,p in enumerate(r.pages):
 t=p.extract_text() or ''
 if (t.count('CHƯƠNG')==1 and ('CHƯƠNG' in t[:150])) or ('PHỤ LỤC' in t[:100]) or ('DANH MỤC HÌNH' in t[:100]):print(i+1,t[:120].replace('\n',' '))
