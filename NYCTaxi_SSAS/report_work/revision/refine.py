from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from lxml import etree as E
from PIL import Image,ImageDraw
import io
p=Path('BaoCao_NYCTaxi_HoanChinh_TheoMucLuc.docx');n={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'};w='{'+n['w']+'}'
with ZipFile(p) as z:parts=[(i,z.read(i.filename)) for i in z.infolist()];x=E.fromstring(z.read('word/document.xml'))
paras=x.findall('.//w:body/w:p',n)
for i,pp in enumerate(paras):
 tt=pp.findall('.//w:t',n);text=''.join(t.text or '' for t in tt)
 if text=='BÁO CÁO XÂY DỰNG KHO DỮ LIỆU NYC TAXI':pp.find('w:pPr/w:pStyle',n).set(w+'val','Title')
 if text.startswith('Bố cục tham khảo file MỤC LỤC'):
  tt[0].text='Báo cáo được tổ chức thành sáu chương: tổng quan dữ liệu, phân tích cấu trúc vật lý, thiết kế kho dữ liệu, xây dựng ETL, mô hình hóa bằng SSAS và xây dựng dashboard Power BI. Ba phụ lục lưu cấu hình package, SQL xử lý và định nghĩa visual để hỗ trợ tái lập và kiểm tra kỹ thuật.'
  for t in tt[1:]:t.text=''
 for t in tt:
  if t.text:t.text=t.text.replace('ở phần cuối chương này','tại Phụ lục B').replace('ở phần trên phản ánh các tệp hiện có','tại Phụ lục C phản ánh các tệp hiện có')
# First figure shows parallel source groups; remove connectors to avoid implying sequential datasets.
media={}
for info,b in parts:
 if info.filename.startswith('word/media/') and info.filename.endswith('.png'):
  im=Image.open(io.BytesIO(b))
  if im.size==(1400,620):
   dr=ImageDraw.Draw(im)
   for j in range(3):dr.rectangle((688,20+j*145+102,712,20+j*145+143),fill='white')
   out=io.BytesIO();im.save(out,format='PNG');media[info.filename]=out.getvalue()
with ZipFile(p,'w',ZIP_DEFLATED) as z:
 for info,b in parts:z.writestr(info,E.tostring(x,encoding='UTF-8',xml_declaration=True,standalone=True) if info.filename=='word/document.xml' else media.get(info.filename,b))
