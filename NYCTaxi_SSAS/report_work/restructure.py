from pathlib import Path
from copy import deepcopy
from collections import defaultdict
import re,json
from docx import Document
from docx.shared import Cm,Pt,Inches,RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from PIL import Image,ImageDraw,ImageFont
R=Path(r'E:/NYCTaxi/NYCTaxi_SSAS');W=R/'report_work/revision';W.mkdir(exist_ok=True)
src=Document(R/'BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');d=Document(R/'BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx')
w='{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
def text(el):return ''.join(el.itertext()) if False else ''.join(el.xpath('.//w:t/text()'))
def style(el):
 a=el.find(w+'pPr/'+w+'pStyle');return a.get(w+'val','') if a is not None else ''
sections={};key=None;refs=[];ref=False
for el in src._element.body:
 t=text(el)
 if el.tag==w+'p' and style(el)=='Heading1':
  key=None
  if t.startswith('TÀI LIỆU THAM KHẢO'):ref=True
  continue
 if el.tag==w+'p' and style(el)=='Heading2' and re.match(r'^\d+\.\d+ ',t):key=re.match(r'^(\d+\.\d+)',t).group(1);sections[key]=[];ref=False
 if key:sections[key].append(deepcopy(el))
 elif ref and el.tag!=w+'sectPr':refs.append(deepcopy(el))
for el in list(d._element.body):
 if el.tag!=w+'sectPr':d._element.body.remove(el)
refdoc=Document(r'C:/Users/ADMIN/Downloads/MỤC LỤC (1).docx');a=refdoc.sections[0];s=d.sections[0]
for name in ['page_width','page_height','top_margin','bottom_margin','left_margin','right_margin','header_distance','footer_distance']:setattr(s,name,getattr(a,name))
for name in ['Normal','normal','Heading 1','Heading 2','Heading 3','Title','Caption']:
 try:
  st=d.styles[name];st.font.name='Times New Roman';st.font.color.rgb=RGBColor(0,0,0)
 except KeyError:pass
for name in ['Appendix Topic']:
 if name not in d.styles:
  st=d.styles.add_style(name,1);st.font.name='Times New Roman';st.font.size=Pt(14);st.font.bold=True;st.paragraph_format.keep_with_next=True
chapter='';sec=0;sub=0;tablecounts=defaultdict(int);figcounts=defaultdict(int);captions=[];figs=[];bookmark=10000
# Preserve A4 and 3/2cm margins from the new outline; black plain tables from original reference.
def p(t='',sty='normal'):
 x=d.add_paragraph(t,sty);return x
def heading(t,level):return p(t,'Heading '+str(level))
def field(para,instr,cache=''):
 f=OxmlElement('w:fldSimple');f.set(qn('w:instr'),instr)
 if cache:
  r=OxmlElement('w:r');t=OxmlElement('w:t');t.text=cache;r.append(t);f.append(r)
 para._p.append(f)
def mark(para,label,kind):
 global bookmark
 bookmark+=1;name=kind+str(bookmark);b=OxmlElement('w:bookmarkStart');b.set(qn('w:id'),str(bookmark));b.set(qn('w:name'),name);para.insert(0,b);e=OxmlElement('w:bookmarkEnd');e.set(qn('w:id'),str(bookmark));para.append(e);return name
heading('BÁO CÁO XÂY DỰNG KHO DỮ LIỆU NYC TAXI',1)
p('Dữ liệu nguồn Thiết kế kho ETL SSAS và Power BI')
p('Báo cáo trình bày nghiệp vụ vận tải hành khách NYC Taxi, cấu trúc dữ liệu nguồn, thiết kế kho dữ liệu, quy trình ETL và tầng phân tích phục vụ Power BI. Nội dung dựa trên mã nguồn và bằng chứng của dự án; các kết quả chạy lịch sử được phân biệt với phần cấu hình và các nội dung chưa được kiểm chứng thực tế.')
p('Bố cục tham khảo file MỤC LỤC (1).docx, áp dụng cho nghiệp vụ NYC Taxi. Các ví dụ AdventureWorks, nhân sự và sản xuất trong tài liệu tham khảo không thuộc phạm vi hệ thống này. Những đặc tả nguyên văn được chuyển xuống phụ lục để phần chính tập trung trình bày phân tích và thiết kế mà vẫn giữ nội dung đối chiếu kỹ thuật.')
x=heading('MỤC LỤC',1);x.paragraph_format.page_break_before=True
field(p(),'TOC \\o "1-3" \\h \\z')
listtable=heading('DANH MỤC BẢNG',1);listtable.paragraph_format.page_break_before=True
listfigure=heading('DANH MỤC HÌNH',1);listfigure.paragraph_format.page_break_before=True

def ch(n,title):
 global chapter,sec,sub
 chapter=str(n);sec=0;sub=0;x=heading(('CHƯƠNG '+chapter+' '+title).upper() if str(n).isdigit() else 'PHỤ LỤC '+chapter+' '+title,1);x.paragraph_format.page_break_before=True

def emit(key):
 global sec,sub
 elems=sections[key];sec+=1;sub=0
 for i,el in enumerate(elems):
  if el.tag==w+'p':
   t=text(el);st=style(el)
   if st=='Heading2':
    t=re.sub(r'^\d+\.\d+\s*','',t);new=f'{chapter}.{sec} {t}' if chapter.isdigit() else f'{chapter}.{sec} {t}';replace(el,new)
    if not chapter.isdigit():setstyle(el,'AppendixTopic')
   elif st=='Heading3':
    sub+=1;t=re.sub(r'^\d+(?:\.\d+)+\s*','',t);replace(el,f'{chapter}.{sec}.{sub} {t}' if chapter.isdigit() else t)
    if not chapter.isdigit():setstyle(el,'AppendixTopic')
   if re.match(r'^Bảng \d+\.\d+ ',t):
    tablecounts[chapter]+=1;title=re.sub(r'^Bảng \d+\.\d+ ','',t);label=f'Bảng {chapter}.{tablecounts[chapter]} {title}';replace(el,label);setstyle(el,'Caption');name=mark(el,label,'tbl');captions.append((label,name))
  d._element.body.insert(-1,el)
def replace(el,t):
 nodes=el.findall('.//'+w+'t')
 if nodes:
  nodes[0].text=t
  for node in nodes[1:]:node.text=''
def setstyle(el,s):
 pr=el.find(w+'pPr')
 if pr is None:pr=OxmlElement('w:pPr');el.insert(0,pr)
 st=pr.find(w+'pStyle')
 if st is None:st=OxmlElement('w:pStyle');pr.append(st)
 st.set(qn('w:val'),s)
def figure(title,boxes):
 figcounts[chapter]+=1
 im=Image.new('RGB',(1400,len(boxes)*145+40),'white');dr=ImageDraw.Draw(im)
 font=ImageFont.truetype('C:/Windows/Fonts/times.ttf',30)
 for i,lines in enumerate(boxes):
  y=20+i*145;dr.rectangle((90,y,1310,y+100),outline='black',width=3)
  for j,line in enumerate(lines.split('|')):dr.text((700,y+20+j*34),line,font=font,fill='black',anchor='mt')
  if i<len(boxes)-1:dr.line((700,y+103,700,y+140),fill='black',width=3);dr.polygon([(692,y+130),(708,y+130),(700,y+140)],fill='black')
 path=W/f'figure-{chapter}-{figcounts[chapter]}.png';im.save(path)
 x=p();x.paragraph_format.keep_with_next=True;x.add_run().add_picture(str(path),width=Cm(15))
 label=f'Hình {chapter}.{figcounts[chapter]} {title}';x=p(label,'Caption');name=mark(x._p,label,'fig');figs.append((label,name))
ch(1,'Tổng quan về dữ liệu NYC Taxi')
for k in ['1.1','1.2','1.3']:emit(k)
figure('Các nhóm dữ liệu nguồn trong hệ thống','Yellow và Green|Chuyến taxi và tài chính; phân biệt loại dịch vụ,FHV|Chuyến đặt trước qua base; không có đầy đủ tài chính,FHVHV|Yêu cầu xe thời gian phục vụ tiền và cờ nghiệp vụ,Taxi Zone Lookup|Danh mục vùng dùng chung cho điểm đón và trả'.split(','))
ch(2,'Phân tích cấu trúc dữ liệu và mô hình vật lý')
p('Chương này mô tả cấu trúc các bảng hiện có trong kho và ràng buộc tham chiếu. Metadata nguồn đã trình bày ở Chương 1; grain và lý do phân chia các fact được phân tích ở Chương 3. Không sao chép các schema Person hoặc Production từ mẫu tham khảo sang hệ thống NYC Taxi.')
emit('1.7')
# Separate detailed FK inventory from business bus matrix.
bus=sections['1.8'];fkidx=next(i for i,e in enumerate(bus) if 'Danh mục quan hệ khóa ngoại vật lý' in text(e));first=bus[:fkidx];second=bus[fkidx:]
sections['physicalfk']=[deepcopy(bus[0])]+second;replace(sections['physicalfk'][0],'Quan hệ khóa ngoại và toàn vẹn tham chiếu');emit('physicalfk')
ch(3,'Thiết kế kho dữ liệu')
sections['bus']=[deepcopy(bus[0])]+first[1:];replace(sections['bus'][0],'Ma trận nghiệp vụ Data Warehouse Bus Matrix');emit('bus')
for k in ['1.5','1.6','1.4']:emit(k)
figure('Mô hình Galaxy Schema và dimension dùng chung',['Dimension dùng chung|Date Time Location ServiceType và các chiều theo nghiệp vụ','Ba fact giao dịch|YellowGreen Trips   FHV Trips   HVFHV Trips','Ba fact snapshot tổng hợp|Daily Financial   Zone Traffic   Base Performance'])
p('Sơ đồ thể hiện mức khái quát của mô hình dùng chung chiều; danh mục khóa ngoại ở Chương 2 xác định chính xác chiều và vai trò mà từng fact tham chiếu. Mũi tên từ fact giao dịch đến snapshot biểu thị luồng tổng hợp ETL, không phải liên kết khóa ngoại trực tiếp giữa các fact.')
ch(4,'Xây dựng quy trình ETL')
for k in ['2.1','2.2','2.4','2.5','2.6','2.7','2.8']:emit(k)
figure('Luồng điều phối ETL và điểm kiểm tra',['Master SSIS → Controller PowerShell → Runner|Cùng RunId và cấu hình chạy','Extract|Download Convert Inspect BulkCopy wrk → stg','Transform|Chuẩn hóa Valid Rejected Warning và checkpoint','Load DWH|Dimension và fact theo file; commit và đối soát','Aggregates → SSAS|Rebuild snapshot ProcessFull và đối soát SQL MDX'])
p('Cấu hình từng task và từng component được giữ đầy đủ tại Phụ lục A. SQL của các tác vụ được giữ tại Phụ lục B. Các phụ lục là đặc tả đối chiếu của những luồng đã giải thích trong chương này, không được xem là kết quả thực thi mới.')
ch(5,'Phân tích và mô hình hóa dữ liệu bằng SSAS')
for k in ['3.1','3.2','3.3','3.4','3.5','3.6','3.7']:emit(k)
figure('Tầng phân tích SSAS Multidimensional',['NYCTaxi DWH|15 dimension 3 transaction fact và 3 snapshot fact','Data Source và Data Source View|DS NYCTaxi DWH và DSV dùng chung','Sáu cube theo nghiệp vụ|Dimension Usage Measure Group MDX Partition MOLAP','Process và kiểm chứng|ProcessFull Browse MDX và đối soát SQL MDX'])
ch(6,'Xây dựng dashboard Power BI')
for k in ['4.1','4.2','4.4','4.5','4.6']:emit(k)
figure('Kết nối live và điều kiện khai thác Power BI',['ETL hoàn tất và DWH nhất quán','SSAS process thành công|Kiểm tra trạng thái và truy vấn cube','Sáu project Power BI kết nối live|Mỗi project sử dụng cube nghiệp vụ tương ứng','Slicer và visual|Bộ lọc độc lập giữa các project; Refresh truy vấn lại cube'])
p('Các hình là sơ đồ thiết kế được dựng từ cấu hình dự án, không phải ảnh chụp dashboard đã được kiểm thử giao diện. Định nghĩa chi tiết từng trang, field binding và thuộc tính visual được lưu tại Phụ lục C; trạng thái kiểm chứng Desktop được trình bày riêng trong chương này.')
ch('A','Cấu hình chi tiết package ETL');emit('2.3')
ch('B','Đặc tả SQL của các tác vụ ETL');emit('2.9')
ch('C','Cấu hình chi tiết trang và visual Power BI');emit('4.3')
x=heading('TÀI LIỆU THAM KHẢO',1);x.paragraph_format.page_break_before=True
for el in refs:d._element.body.insert(-1,el)
# Lists with bookmark page references updated by Word, independent of caption language.
for anchor,items in [(listtable,captions),(listfigure,figs)]:
 prev=anchor._p
 for label,name in items:
  x=p(label+'\t');x.paragraph_format.line_spacing=1.0;x.paragraph_format.space_after=Pt(4)
  field(x,'PAGEREF '+name+' \\h','0');prev.addnext(x._p);prev=x._p
# Page numbers and heading consistency.
f=s.footer.paragraphs[0];f.alignment=1;field(f,'PAGE','1')
for para in d.paragraphs:
 if para.style.name.startswith('Heading'):
  para.paragraph_format.keep_with_next=True
  for r in para.runs:r.font.color.rgb=RGBColor(0,0,0)
# Geometry: source tables had 6.5in width; refit proportionately to new A4 body.
bodywidth=s.page_width-s.left_margin-s.right_margin
for t in d.tables:
 grids=list(t._tbl.tblGrid)
 total=sum(int(g.get(qn('w:w'))) for g in grids)
 if total:
  ratio=(bodywidth/635)/total
  for g in grids:g.set(qn('w:w'),str(round(int(g.get(qn('w:w')))*ratio)))
  for row in t.rows:
   for c in row.cells:
    tcw=c._tc.get_or_add_tcPr().find(qn('w:tcW'))
    if tcw is not None:tcw.set(qn('w:w'),str(round(int(tcw.get(qn('w:w')))*ratio)))
out=R/'BaoCao_NYCTaxi_HoanChinh_TheoMucLuc.docx';d.save(out)
(W/'contract.md').write_text('Reference MỤC LỤC (1).docx controls A4 geometry and analytical chapter organization. Original no-shading table requirement preserved. Six chapters adapt reference to NYC Taxi, retaining ETL and Power BI. All prior detail retained in body or three appendices. Five actual schematic figures captioned and bookmarked. Table and figure lists use PAGEREF. Source content remains NYC Taxi, not AdventureWorks. Native Word export and QA required.',encoding='utf-8')
(W/'inventory.json').write_text(json.dumps({'tables':len(captions),'figures':len(figs),'sections':list(sections)},ensure_ascii=False),encoding='utf-8')
print(out,len(captions),len(figs))
