from pathlib import Path
from collections import defaultdict
from copy import deepcopy
import ast, json, re, csv, hashlib, importlib.util
from lxml import etree as E
from docx import Document
from docx.shared import Cm, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_TAB_ALIGNMENT, WD_TAB_LEADER
from PIL import Image, ImageDraw, ImageFont
R=Path(r'E:/NYCTaxi/NYCTaxi_SSAS');W=R/'report_work/five_chapters';REF=Path(r'C:/Users/ADMIN/Downloads/Nhom04_ThietKeMucLogic_DACK.docx')
d=Document(REF);sample=deepcopy(d.tables[0]._tbl.tblPr)
for e in list(d._element.body):
 if e.tag!=qn('w:sectPr'):d._element.body.remove(e)
geo=Document(r'C:/Users/ADMIN/Downloads/MỤC LỤC (1).docx').sections[0];s=d.sections[0]
for k in ['page_width','page_height','top_margin','bottom_margin','left_margin','right_margin']:setattr(s,k,getattr(geo,k))
for name in ['Caption','FrontHeading','AppendixTopic']:
 if name not in d.styles:d.styles.add_style(name,1)
for name in ['normal','Heading 1','Heading 2','Heading 3','Title','Caption','FrontHeading','AppendixTopic']:
 st=d.styles[name];st.font.name='Times New Roman';st.font.size=Pt(14);st.font.color.rgb=RGBColor(0,0,0);st.paragraph_format.line_spacing=1.5
 if name not in ['normal','Caption']:st.font.bold=True;st.paragraph_format.keep_with_next=True
 if name in ['FrontHeading','AppendixTopic']:
  ol=OxmlElement('w:outlineLvl');ol.set(qn('w:val'),'9');st.element.get_or_add_pPr().append(ol)
chapter='0';nt=defaultdict(int);nf=defaultdict(int);caps=[];figs=[];bid=10000;heading_inventory=[]
ns={'a':'http://schemas.microsoft.com/analysisservices/2003/engine','d':'www.microsoft.com/SqlServer/Dts'}
def p(t='',style='normal'):
 x=d.add_paragraph(t,style);x.paragraph_format.widow_control=True;return x
def h(t,level):
 global chapter
 if level==1:
  m=re.match(r'CHƯƠNG (\d+)',t);ap=re.match(r'PHỤ LỤC ([ABC])',t)
  chapter=m.group(1) if m else ap.group(1) if ap else '0'
 x=p(t,'Heading '+str(level));x.paragraph_format.keep_with_next=True
 if level==1:x.paragraph_format.page_break_before=True
 heading_inventory.append(t);return x
def fld(para,instr,result=''):
 x=OxmlElement('w:fldSimple');x.set(qn('w:instr'),instr)
 if result:
  r=OxmlElement('w:r');t=OxmlElement('w:t');t.text=result;r.append(t);x.append(r)
 para._p.append(x)
def caption(title,figure=False):
 global bid
 counter=nf if figure else nt;counter[chapter]+=1;label=f'{"Hình" if figure else "Bảng"} {chapter}.{counter[chapter]} {title}'
 x=p(label,'Caption');x.paragraph_format.keep_with_next=not figure
 bid+=1;name=('fig' if figure else 'tbl')+str(bid)
 start=OxmlElement('w:bookmarkStart');start.set(qn('w:id'),str(bid));start.set(qn('w:name'),name);x._p.insert(0,start)
 end=OxmlElement('w:bookmarkEnd');end.set(qn('w:id'),str(bid));x._p.append(end)
 (figs if figure else caps).append((label,name));return x
def table(title,headers,rows,widths=None):
 caption(title);t=d.add_table(rows=1,cols=len(headers));t.autofit=False
 widths=widths or [16/len(headers)]*len(headers)
 border=sample.find(qn('w:tblBorders'));t._tbl.tblPr.append(deepcopy(border))
 for col,wd in zip(t.columns,widths):col.width=Cm(wd)
 for c,txt in zip(t.rows[0].cells,headers):c.text=str(txt)
 for row in rows:
  for c,txt in zip(t.add_row().cells,row):c.text=str(txt if txt is not None else 'NULL')
 for i,row in enumerate(t.rows):
  row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
  if i==0:row._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
  for j,c in enumerate(row.cells):
   c.width=Cm(widths[j]);c.vertical_alignment=1
   for pp in c.paragraphs:
    pp.paragraph_format.line_spacing=1.1;pp.paragraph_format.space_before=Pt(3);pp.paragraph_format.space_after=Pt(3)
    for rr in pp.runs:rr.font.name='Times New Roman';rr.font.size=Pt(12);rr.font.color.rgb=RGBColor(0,0,0);rr.bold=i==0
 return t
def code(text):
 for line in text.strip().splitlines():
  x=p(line);x.paragraph_format.line_spacing=1;x.paragraph_format.space_before=Pt(0);x.paragraph_format.space_after=Pt(0)
  for rr in x.runs:rr.font.name='Consolas';rr.font.size=Pt(9)
def val(e,n,default=''):
 if e is None:return default
 x=e.find('a:'+n,ns);return x.text if x is not None and x.text else default
columns=json.loads((R/'evidence/columns.json').read_text(encoding='utf-8-sig'));fks=json.loads((R/'evidence/foreign-keys.json').read_text(encoding='utf-8-sig'));pks=json.loads((R/'evidence/primary-keys.json').read_text(encoding='utf-8-sig'));schema=defaultdict(list)
for c in columns:schema[c['TableName']].append(c)
spec=importlib.util.spec_from_file_location('contract',R/'etl/python/extract_contract.py');contract=importlib.util.module_from_spec(spec);spec.loader.exec_module(contract)
# Source-field definitions are data dictionary content, independent of prior report prose.
tree=ast.parse((R/'report_work/build_report.py').read_text(encoding='utf-8'))
desc=next(ast.literal_eval(a.value) for a in tree.body if isinstance(a,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='desc' for t in a.targets))
desc['on_scene_datetime']='Mốc xe đến nơi đón do nguồn cung cấp; từ điển TLC giới hạn độ bao phủ ở xe tiếp cận. Dùng tính OnSceneToPickup khi hợp lệ.'
defs={
'BaseNumber':'Số giấy phép base của TLC, là mã nghiệp vụ tra cứu cho các vai trò base.', 'BaseName':'Tên base theo danh mục, có thể thiếu khi chưa có thông tin mô tả.', 'BaseCategory':'Nhóm phân loại base theo danh mục.',
'FullDate':'Ngày dương lịch đầy đủ để hiển thị và sắp xếp.', 'DayOfWeekNumber':'Số thứ tự ngày trong tuần theo seed lịch của dự án.', 'DayOfWeekName':'Tên ngày trong tuần.', 'DayOfMonth':'Ngày trong tháng từ 1 đến 31.', 'MonthNumber':'Số tháng 1 đến 12; khóa hierarchy ghép cùng năm.', 'MonthName':'Tên tháng hiển thị, sắp theo MonthNumber.', 'QuarterNumber':'Số quý 1 đến 4; khóa hierarchy ghép cùng năm.', 'YearNumber':'Năm dương lịch.', 'IsWeekend':'Cờ cuối tuần theo seed lịch.', 'IsHoliday':'Cờ ngày lễ; lịch ngày lễ chưa được xác nhận trong dữ liệu đang rà soát.',
'IsSharedRide':'Cờ đi chung FHV chuẩn hóa từ SourceSRFlag, Y N U.', 'LicenseNumber':'Số giấy phép HVFHS dùng nhận diện nhà cung cấp.', 'ProviderName':'Tên nhà cung cấp tương ứng giấy phép nguồn.', 'IsSharedRequest':'Cờ khách đồng ý hoặc yêu cầu chuyến đi chung, Y N U.', 'IsSharedMatch':'Cờ chuyến có hành khách đặt riêng được ghép cùng xe, Y N U.', 'IsAccessARide':'Cờ chuyến thuộc chương trình Access A Ride, Y N U.', 'IsWAVRequest':'Cờ hành khách yêu cầu xe tiếp cận xe lăn, Y N U.', 'IsWAVMatch':'Cờ chuyến thực hiện bằng xe tiếp cận xe lăn; không mặc nhiên là đáp ứng yêu cầu WAV cùng tập.',
'BatchID':'Mã nhận diện nhóm lô xử lý trong bảng chiều, không phải TripID.', 'DatasetName':'Tên dataset của nhóm lô.', 'SourceFileName':'Tên file nếu được cung cấp; bằng chứng hiện có có giá trị NULL, không dùng thay lineage file fact.', 'SourceYear':'Năm của nhóm nạp suy theo thiết kế lô.', 'SourceMonth':'Tháng của nhóm nạp suy theo thiết kế lô.', 'LoadedAt':'Thời điểm dữ liệu được ghi vào đối tượng trong kho, không phải thời điểm chuyến đi.', 'BatchStatus':'Trạng thái của nhóm lô theo ETL.',
'LocationID':'Mã Taxi Zone nghiệp vụ của TLC.', 'Borough':'Quận hoặc nhóm địa lý của Taxi Zone.', 'ZoneName':'Tên vùng hiển thị; LocationKey xác định tính duy nhất.', 'ServiceZone':'Nhóm vùng phục vụ theo danh mục TLC.',
'PassengerGroupCode':'Mã nhóm số hành khách theo seed.', 'MinCount':'Cận dưới số hành khách của nhóm.', 'MaxCount':'Cận trên số hành khách của nhóm.', 'GroupName':'Tên nhóm số hành khách.',
'PaymentTypeID':'Mã phương thức hoặc tình trạng thanh toán, không có đơn vị tiền.', 'PaymentTypeDescription':'Tên diễn giải mã thanh toán.', 'RateCodeID':'Mã biểu giá taxi cuối chuyến theo nguồn.', 'RateCodeDescription':'Tên diễn giải biểu giá.', 'ServiceCode':'Mã Yellow Green FHV hoặc HVFHV.', 'ServiceName':'Tên dịch vụ hiển thị.', 'StoreAndFwd':'Cờ dữ liệu được lưu trên xe rồi truyền về, Y N U.',
'MinuteOfDay':'Phút trong ngày; khóa TimeKey hợp lệ 1 đến 1440, 0 dành Unknown.', 'HourNumber':'Giờ 0 đến 23 với dữ liệu hợp lệ; phân biệt Unknown trong key.', 'MinuteNumber':'Phút trong giờ 0 đến 59.', 'TimeLabel':'Nhãn giờ phút của thành viên.', 'TimeBand':'Nhóm khung giờ theo seed để phân cấp.', 'IsPeakHour':'Cờ khung giờ cao điểm theo quy tắc seed, không phải kết luận từ toàn bộ nguồn NYC.', 'TripTypeID':'Mã cách nhận chuyến Green theo nguồn.', 'TripTypeDescription':'Tên diễn giải loại chuyến.', 'VendorID':'Mã nhà cung cấp công nghệ TPEP hoặc LPEP.', 'VendorName':'Tên nhà cung cấp công nghệ tương ứng mã nguồn.',
'TripKey':'Khóa thay thế dòng fact; có thể đổi khi nguồn hiệu chỉnh, không phải TripID TLC.', 'TripCount':'Số chuyến của dòng giao dịch, dùng cộng tổng.', 'PassengerCount':'Số hành khách nguồn ghi nhận; thiếu dữ liệu được giữ theo quy tắc.', 'TripDistanceMiles':'Quãng đường chuyến, đơn vị mile.', 'TripDurationSeconds':'Thời lượng pickup đến dropoff, giây.', 'AverageSpeedMPH':'Tốc độ riêng dòng tính theo mile mỗi giờ; không cộng trực tiếp.', 'WaitingTimeSeconds':'Thời gian request đến pickup hợp lệ, giây.', 'OnSceneToPickupSeconds':'Chênh lệch on scene đến pickup hợp lệ, giây; độ bao phủ phụ thuộc nguồn.',
'FareAmount':'Cước cơ bản taxi, USD; khác tổng tiền.', 'ExtraAmount':'Phụ thu bổ sung taxi, USD.', 'MTATaxAmount':'Thuế MTA nguồn ghi riêng, USD.', 'TipAmount':'Tip ghi nhận, USD; taxi không bao gồm tip tiền mặt.', 'TollsAmount':'Phí cầu đường, USD.', 'ImprovementSurcharge':'Phụ thu cải thiện taxi, USD.', 'CongestionSurcharge':'Phụ thu ùn tắc, USD; tách phí CBD.', 'AirportFee':'Phí sân bay theo nguồn, USD.', 'CBDCongestionFee':'Phí vùng trung tâm CBD theo nguồn và thời kỳ, USD.', 'TotalAmount':'Tổng tiền khách taxi nguồn ghi nhận, USD.', 'BasePassengerFare':'Cước cơ bản HVFHV trước các khoản tách riêng, USD.', 'BCFAmount':'Khoản Black Car Fund, USD.', 'SalesTaxAmount':'Thuế bán hàng HVFHV, USD.', 'DriverPayAmount':'Tiền tài xế HVFHV được nguồn ghi nhận, USD, giữ riêng tip và phí theo định nghĩa nguồn.', 'GrossPassengerAmount':'Tổng tiền khách HVFHV theo công thức loader, USD.', 'RecordHash':'Hash payload cùng ngữ cảnh file và ordinal trùng, phục vụ đồng bộ; không là mã chuyến TLC.',
'TotalTrips':'Tổng số chuyến ở grain snapshot.', 'TotalTripDurationSeconds':'Tổng thời lượng hợp lệ, giây.', 'DurationTripCount':'Số chuyến có thời lượng hợp lệ, mẫu số trung bình.', 'AverageTripDurationSeconds':'Trung bình thời lượng tại grain dòng, giây; roll up cần tính lại từ tổng và count.', 'TotalWaitingTimeSeconds':'Tổng thời gian chờ hợp lệ, giây.', 'WaitingTripCount':'Số chuyến có thời gian chờ hợp lệ.', 'AverageWaitingTimeSeconds':'Trung bình chờ tại grain dòng, giây; không cộng trực tiếp.', 'TotalSharedRequests':'Tổng chuyến có cờ yêu cầu đi chung phù hợp nguồn.', 'TotalSharedMatches':'Tổng chuyến có cờ đã ghép đi chung.', 'TotalWAVRequests':'Tổng chuyến có cờ yêu cầu WAV.', 'TotalWAVMatches':'Tổng chuyến thực hiện bằng WAV; không bảo đảm là tập con các yêu cầu.', 'TotalDriverPay':'Tổng tiền tài xế ghi nhận theo nguồn có dữ liệu, USD.', 'SnapshotUpdatedAt':'Thời điểm cập nhật snapshot, khác ngày nghiệp vụ.',
'TotalDistanceMiles':'Tổng quãng đường của tập được tổng hợp, mile.', 'TotalPassengerCharges':'Tổng tiền khách theo nguồn tài chính, USD.', 'TotalTips':'Tổng tip được ghi nhận, USD.', 'TotalTaxesAndFees':'Tổng thuế và phí theo công thức aggregate, USD.', 'TotalPickups':'Tổng sự kiện đón ở ngày phút vùng dịch vụ của dòng.', 'TotalDropoffs':'Tổng sự kiện trả ở ngày phút vùng dịch vụ của dòng.', 'SourceDataset':'Mã dataset nguồn dùng cùng SourceKey để truy vết và đồng bộ.', 'SourceKey':'Khóa tên file nguồn, không phải mã chuyến.'}
def meaning(name,tab):
 if name in defs:return defs[name]
 rel=[x for x in fks if x['FactTable']==tab and x['FactColumn']==name]
 if rel:return 'Khóa ngoại '+rel[0]['DimTable']+'.'+rel[0]['DimColumn']+'; vai trò '+name.replace('Key','')+'. Khóa 0 giữ Unknown.'
 if name.endswith('Key'):return 'Khóa thay thế của '+tab+'; thành viên 0 là Unknown theo thiết kế.'
 raise ValueError('Missing field description '+tab+'.'+name)
def schema_table(tab):
 p(tab,'AppendixTopic');rows=[]
 cc=list(schema[tab])
 if tab.endswith('_Trips'):
  cc += [dict(ColumnName='SourceDataset',DataType='varchar',MaxLength=20,Nullable=True),dict(ColumnName='SourceKey',DataType='nvarchar',MaxLength=520,Nullable=True)]
 for c in cc:
  name=c['ColumnName'];dt=c['DataType'];ml=c['MaxLength']
  if dt in ['varchar','nvarchar','char','nchar']:dt+='('+str(ml//2 if dt.startswith('n') else ml)+')'
  role='PK' if any(x['TableName']==tab and x['ColumnName']==name for x in pks) else 'FK' if any(x['FactTable']==tab and x['FactColumn']==name for x in fks) else 'Thuộc tính'
  rows.append([name,dt,('Có' if c['Nullable'] else 'Không')+'; '+role,meaning(name,tab)])
 table('Cấu trúc và ý nghĩa các cột '+tab,['Cột','Kiểu SQL','NULL và khóa','Ý nghĩa'],rows,[4.2,2.2,2,7.6])
def source(ds):
 rows=[]
 for name in contract.DATASETS[ds][3]:
  description=desc.get(name)
  if description is None and 'datetime' in name.lower():description='Thời điểm '+('yêu cầu xe' if 'request' in name else 'xe đến điểm đón' if 'scene' in name else 'đón khách' if 'pickup' in name else 'trả khách')+' theo bản ghi nguồn; chuyển DATETIME2 tại Transform.'
  if description is None:raise ValueError(name)
  rows.append([name,description,'Chuỗi '+str(contract.width(ds,name))+'; '+('optional' if name in contract.OPTIONAL[ds] else 'thiết yếu')])
 table('Metadata nguồn '+ds,['Tên trường','Mô tả và đơn vị','Hợp đồng CSV'],rows,[4.4,8.1,3.5])
def figure(kind):
 sets={
 'architecture':('Kiến trúc từ nguồn dữ liệu đến báo cáo',['Nguồn TLC|Yellow Green FHV HVFHV và Taxi Zone','Raw và CSV|File gốc hợp đồng cột metadata và hash','Staging và Clean|wrk → stg → clean Valid Rejected Warning','NYCTaxi DWH|Dimension transaction fact và snapshot','SSAS → Power BI|Sáu cube và các báo cáo Live Connection']),
 'galaxy':('Dimension dùng chung và các nhóm fact',['Dimension dùng chung và theo nghiệp vụ|Date Time Location Service Base Provider và các chiều phân loại','Ba transaction fact|YellowGreen Trips     FHV Trips     HVFHV Trips','Luồng ETL tổng hợp theo grain riêng|Không join trực tiếp các fact theo ngày hoặc vùng','Ba snapshot fact|Daily Financial     Zone Traffic     Base Performance']),
 'etl':('Luồng điều phối và các điểm kiểm tra ETL',['Master SSIS → Controller → Runner|RunId chung InvocationId riêng cho lần gọi','Extract|Download Convert Inspect BulkCopy và commit staging','Transform|Chuẩn hóa kiểu kiểm tra chất lượng và checkpoint file','Dwh|Nạp dimension và đồng bộ fact theo file','Aggregates|Rebuild ba snapshot cùng validation trong transaction','Ssas|ProcessFull sáu cube và đối soát SQL MDX']),
 'ssas':('Tổ chức tầng phân tích SSAS',['NYCTaxi DWH|Dimension và fact có grain và khóa rõ ràng','Data Source và Data Source View|Kết nối SQL và mô tả quan hệ mô hình','Database dimension và role trong cube|Thuộc tính hierarchy và Dimension Usage','Sáu cube nghiệp vụ|Measure group calculated measure partition MOLAP','Deploy → Process → Verify|Trạng thái xử lý và truy vấn đối soát']),
 'powerbi':('Khai thác Power BI qua kết nối live',['ETL hoàn tất và DWH nhất quán','SSAS Processed và probe truy vấn thành công','Sáu project PBIP kết nối live|YellowGreen FHV HVFHV Financial Traffic Base','Bộ lọc theo từng project|Năm tháng dịch vụ và chiều nghiệp vụ','Visual sử dụng measure của cube|Refresh truy vấn lại SSAS không tự chạy ETL'])}
 title,boxes=sets[kind];im=Image.new('RGB',(1500,len(boxes)*145+30),'white');dr=ImageDraw.Draw(im);font=ImageFont.truetype('C:/Windows/Fonts/times.ttf',31)
 for i,box in enumerate(boxes):
  y=15+i*145;dr.rectangle((45,y,1455,y+105),outline='black',width=3)
  for j,line in enumerate(box.split('|')):dr.text((750,y+16+j*38),line,font=font,fill='black',anchor='mt')
  if i<len(boxes)-1:dr.line((750,y+108,750,y+139),fill='black',width=3);dr.polygon([(742,y+129),(758,y+129),(750,y+140)],fill='black')
 path=W/(kind+'.png');im.save(path);x=p();x.paragraph_format.keep_with_next=True;x.add_run().add_picture(str(path),width=Cm(16));caption(title,True)
 if kind=='galaxy':p('Khối dimension biểu thị ngữ cảnh tham chiếu dùng chung; mũi tên xuống snapshot biểu thị luồng tổng hợp ETL. Các quan hệ khóa ngoại cụ thể được liệt kê trong từ điển và bảng khóa ngoại, không phải mọi dimension trong khối đều nối tới mọi fact.')
def cube(id):
 root=E.parse(str(R/'NYCTaxi_SSAS'/f'{id}.cube')).getroot();name=val(root,'Name')
 table('Measure và nguồn dữ liệu cube '+name,['Measure','Cột nguồn và hàm','Hiển thị'],[(val(m,'Name'),', '.join(x.text for x in m.findall('.//a:ColumnID',ns))+'; '+val(m,'AggregateFunction','Sum'),'Ẩn' if val(m,'Visible','true')=='false' else 'Hiện') for m in root.findall('./a:MeasureGroups/a:MeasureGroup/a:Measures/a:Measure',ns)],[6.2,7.6,2.2])
 dimmap={val(x,'ID'):val(x,'DimensionID') for x in root.findall('./a:Dimensions/a:Dimension',ns)}
 rows=[]
 for x in root.findall('./a:MeasureGroups/a:MeasureGroup/a:Dimensions/*',ns):
  role=val(x,'CubeDimensionID');grain=', '.join(val(a,'AttributeID') for a in x.findall('./a:Attributes/a:Attribute',ns) if val(a,'Type')=='Granularity')
  rows.append([role,dimmap.get(role,''),grain,', '.join(c.text for c in x.findall('.//a:ColumnID',ns))])
 table('Dimension Usage cube '+name,['Role trong cube','Database dimension','Grain attribute','Cột nguồn'],rows,[4.4,3.9,3.4,4.3])
def literals(x):
 found=[]
 if isinstance(x,dict):
  if 'Literal' in x and isinstance(x['Literal'],dict):found.append(x['Literal'].get('Value',''))
  for v in x.values():found.extend(literals(v))
 elif isinstance(x,list):
  for v in x:found.extend(literals(v))
 return found
def page(project,name):
 root=R/'powerbi/reports'/project/(project+'.Report')/'definition/pages';files=sorted(root.glob('*/page.json')) if name=='*' else [root/name/'page.json']
 for f in files:
  info=json.loads(f.read_text(encoding='utf-8-sig'));p('Trang '+info['displayName']+'; canvas '+str(info['width'])+' × '+str(info['height'])+'.','AppendixTopic');rows=[]
  for vf in sorted(f.parent.glob('visuals/*/visual.json')):
   v=json.loads(vf.read_text(encoding='utf-8-sig'));visual=v.get('visual',{});typ=visual.get('visualType','container');obj=visual.get('visualContainerObjects',v.get('visualContainerObjects',{}));title='; '.join(z.get('properties',{}).get('text',{}).get('expr',{}).get('Literal',{}).get('Value','').strip("'") for z in obj.get('title',[]) if isinstance(z,dict))
   fields=[]
   def walk(x,role=''):
    if isinstance(x,dict):
     if 'Column' in x or 'Measure' in x:
      z=x.get('Column',x.get('Measure'));entity=z.get('Expression',{}).get('SourceRef',{}).get('Entity','');fields.append(entity+'.'+z.get('Property',''))
     for k,valx in x.items():walk(valx,k)
    elif isinstance(x,list):
     for z in x:walk(z,role)
   walk(visual.get('query',{}));fields=list(dict.fromkeys(fields));position=v.get('position',{});filters=v.get('filterConfig',{})
   cfg='; '.join(k+'='+str(round(z,2) if isinstance(z,float) else z) for k,z in position.items())
   if filters:cfg+='; filter '+json.dumps(filters,ensure_ascii=False,separators=(',',':'))
   if not fields and typ in ['textbox','shape']:fields=['Thành phần tiêu đề hoặc bố cục, không có field dữ liệu.']
   rows.append([title or v.get('name',''),typ,'; '.join(fields) or 'Không có field trong query',cfg])
  table('Visual và binding trang '+info['displayName'],['Tiêu đề hoặc ID','Loại visual','Field và measure','Vị trí và filter'],rows,[3.4,2.4,6,4.2])
def dispatch(line):
 args=line[1:].split();cmd=args.pop(0)
 if cmd=='source':source(args[0])
 elif cmd in ['dims','fact']:
  for tab in args:schema_table(tab)
 elif cmd=='figure':figure(args[0])
 elif cmd=='cube':cube(args[0])
 elif cmd=='page':page(*args)
 elif cmd=='questions':table('Câu hỏi nghiệp vụ và nguồn trả lời',['Nhóm','Câu hỏi','Nguồn phân tích'],[
  ['Nhu cầu','Số chuyến biến động ra sao theo ngày tháng giờ và dịch vụ?','Transaction cube theo nguồn; Zone Traffic cho sự kiện liên nguồn.'],['Địa lý','Vùng và Borough nào có nhiều lượt đón hoặc lượt trả?','Zone Traffic, tách TotalPickups và TotalDropoffs.'],['Taxi','Cước và tip khác nhau theo thanh toán quận và giờ như thế nào?','YellowGreen Trips.'],['HVFHV','Thời gian chờ và tiền tài xế khác nhau theo provider ra sao?','HVFHV Trips và Base Performance.'],['Tài chính','Tổng tiền khách tip thuế phí thay đổi theo ngày dịch vụ thế nào?','Daily Financial; không bổ sung FHV giả lập.'],['Điều phối','Base nào có nhiều chuyến, chờ và yêu cầu đi chung?','Base Performance theo dispatch base và provider.']],[2.4,7.2,6.4])
 elif cmd=='bus':
  dims=['Dim_Date','Dim_Time','Dim_Location','Dim_ServiceType'];rows=[]
  for tab in [x for x in schema if x.startswith('Fact_')]:
   related=[x for x in fks if x['FactTable']==tab];rows.append([tab]+['X' if any(z['DimTable']==dim for z in related) else '' for dim in dims]+['; '.join(sorted(set(z['DimTable'] for z in related if z['DimTable'] not in dims)))])
  table('Ma trận nghiệp vụ và dimension dùng chung',['Fact','Date','Time','Location','Service','Chiều đặc thù'],rows,[4.5,1,1,1.3,1.2,7])
 elif cmd=='hierarchies':table('Hierarchy và quy tắc khóa',['Chiều','Hierarchy','Quy tắc'],[['Date','Year → Quarter → Month → Date','Quý và tháng có năm trong khóa.'],['Time','TimeBand → Hour → Time','Unknown khác giờ 00; TimeKey 1..1440 cho phút hợp lệ.'],['Location','Borough → Zone','Zone dùng LocationKey; caption ZoneName.']],[2.5,6,7.5])
 elif cmd=='foreignkeys':table('Danh mục khóa ngoại và vai trò',['Fact và cột','Dimension và cột','Ràng buộc'],[(x['FactTable']+'.'+x['FactColumn'],x['DimTable']+'.'+x['DimColumn'],x['FKName']) for x in fks],[6.2,5.2,4.6])
 elif cmd=='parameters':
  root=E.parse(str(R/'etl/packages/PKG_00_Master.dtsx')).getroot();rows=[]
  for x in root.findall('./d:PackageParameters/d:PackageParameter',ns):rows.append([x.get('{'+ns['d']+'}ObjectName'),'; '.join((z.text or '') for z in x)])
  table('Tham số Master lưu trong source',['Tham số','Giá trị'],rows,[5,11])
 elif cmd=='master':
  root=E.parse(str(R/'etl/packages/PKG_00_Master.dtsx')).getroot();rows=[]
  for x in root.findall('./d:Executables/d:Executable',ns):
   name=x.get('{'+ns['d']+'}ObjectName');rows.append([name,x.get('{'+ns['d']+'}ExecutableType',''), 'Mở monitor' if 'Monitor' in name else 'Báo lỗi gốc' if 'Error' in name else 'Xác nhận cuối run' if 'Complete' in name else 'Gọi controller thực hiện stage tương ứng'])
  table('Các tác vụ điều phối Master',['Task','Loại thực thi','Trách nhiệm'],rows,[5.4,5.4,5.2])
 elif cmd=='taskmap':
  purposes={'PKG_01_Extract_Stage':'Chuẩn bị staging, xử lý từng file, kiểm tra và cập nhật trạng thái tiếp nhận.','PKG_02_Transform_Clean':'Chuẩn bị clean, chuẩn hóa lookup và bốn nguồn chuyến, kiểm tra đầu ra.','PKG_03_Load_DWH':'Precheck, nạp dimension và ba fact, kiểm tra coverage cùng số dòng.','PKG_04_Load_Aggregates':'Rebuild và kiểm tra ba snapshot trong cùng transaction.'}
  for path in sorted((R/'etl/packages').glob('PKG_0[1-4]*.dtsx')):
   root=E.parse(str(path)).getroot();rows=[]
   for x in root.findall('./d:Executables/d:Executable',ns):rows.append([x.get('{'+ns['d']+'}ObjectName',''),x.get('{'+ns['d']+'}ExecutableType','')])
   p(path.stem+': '+purposes[path.stem]);table('Các task cấp chính '+path.stem,['Tên task theo thứ tự source','Kiểu thực thi'],rows,[9.5,6.5])
 elif cmd=='quality':table('Điều kiện chất lượng và cách diễn giải',['Điều kiện','Xử lý','Ảnh hưởng'],[
  ['Pickup hoặc dropoff không hợp lệ','Không qua điều kiện core','Không nạp transaction fact.'],['Dropoff không sau pickup; thời lượng quá 48 giờ','Không qua điều kiện core','Bảo vệ thời lượng và tập chuyến hợp lệ.'],['Khoảng cách thiếu hoặc âm ở nguồn khác FHV','Không qua điều kiện core','Không áp thiếu khoảng cách để loại mọi FHV.'],['Khoảng cách 0 hoặc hành khách không hợp lý ở taxi','Ghi QualityIssue theo SQL','Có thể còn hợp lệ, cần phân biệt warning với rejected.'],['Vùng không tra được','Ghi cảnh báo và lookup Unknown','Giữ chuyến trong tổng, hạn chế diễn giải địa lý.'],['Request thiếu hoặc sau pickup; on scene sau pickup','Ghi QualityIssue; chỉ tính thời gian khi phù hợp','Mẫu số chờ khác tổng chuyến.'],['Lệch trip_time nguồn và duration quá 60 giây','SOURCE_DURATION_MISMATCH','Giữ cả thời lượng tính và thông tin kiểm tra nguồn.']],[6.3,4.1,5.6])
 elif cmd=='testsummary':table('Bằng chứng kiểm thử ETL đã lưu',['Nhóm','Kết quả lịch sử','Phạm vi chứng minh'],[
  ['Clean và fact','558183 dòng hợp lệ; 56 file không lệch count','Nhất quán số dòng tại thời điểm rà soát.'],['Incremental SQL fixture','22 trên 22 ca đạt theo hồ sơ hardening','File mới no-op duplicates correction rollback mapping và ForceReload trong DB cách ly.'],['FHV flag fixture','1 → Y; 0 → N; NULL → U','Logic mapping source cờ theo phiên bản mới.'],['Controller fixture','7 ca đạt','Success lỗi vĩnh viễn transient retry stale failure và resume.'],['Python metadata','12 trên 12 theo hồ sơ hardening','Các điều kiện được kiểm thử của converter và metadata.'],['Lịch production restore UI','Chưa có đủ bằng chứng nghiệm thu','Không suy ra hoàn tất từ unit test và truy vấn dữ liệu.']],[4,5,7])
 elif cmd=='dimensionattributes':
  for path in sorted((R/'NYCTaxi_SSAS').glob('*.dim')):
   root=E.parse(str(path)).getroot();rows=[]
   for x in root.findall('./a:Attributes/a:Attribute',ns):rows.append([val(x,'Name'),', '.join(z.text for z in x.findall('./a:KeyColumns//a:ColumnID',ns)),', '.join(z.text for z in x.findall('./a:NameColumn//a:ColumnID',ns)) or 'Dùng key theo cấu hình',', '.join(z.text for z in x.findall('./a:AttributeRelationships/a:AttributeRelationship/a:AttributeID',ns)) or 'Không khai báo thêm'])
   table('Attribute key và quan hệ '+val(root,'Name'),['Attribute','KeyColumns','NameColumn','Attribute relationship'],rows,[4.4,4.1,3.5,4])
 elif cmd=='formulas':table('Quy tắc calculated measure',['Chỉ tiêu','Công thức nghiệp vụ','Điều kiện'],[
  ['Trung bình giá trị','Tổng giá trị / số dòng có giá trị hợp lệ','Không dùng tổng chuyến nếu measure có NULL.'],['Thời lượng hoặc chờ phút','Tổng giây / tổng số chuyến hợp lệ / 60','Mẫu số tương ứng từng measure.'],['Tốc độ MPH','Tổng mile cùng tập × 3600 / tổng giây cùng tập','Khoảng cách không âm và thời gian dương.'],['Tip Percentage taxi','Tổng tip của cặp hợp lệ / tổng FareAmount của cặp hợp lệ','Không chia cho TotalAmount.'],['Tip Percentage HVFHV','Tổng tip của cặp hợp lệ / tổng BasePassengerFare của cặp hợp lệ','Không dùng hai tập dòng khác nhau.'],['Shared Request Rate','TotalSharedRequests / TotalTrips thuộc nguồn áp dụng','Giữ cùng phạm vi nguồn và bộ lọc.'],['WAV Match Rate','Đã ẩn; hai cờ chưa đủ nghĩa tỷ lệ đáp ứng','Không clamp để ép kết quả dưới 100 phần trăm.']],[4.3,6.4,5.3])
 elif cmd=='partitions':
  for path in sorted((R/'NYCTaxi_SSAS').glob('*.partitions')):
   root=E.parse(str(path)).getroot();rows=[]
   for x in root.findall('.//a:Partition',ns):
    src=x.find('a:Source',ns);query=val(src,'QueryDefinition') or 'TableBinding '+val(src,'TableID')
    rows.append([val(x,'Name'),val(x,'StorageMode')+'; '+val(x,'AggregationDesignID'),query])
   table('Partition và phạm vi nguồn '+path.stem,['Partition','Lưu trữ và design','Nguồn hoặc QueryDefinition'],rows,[4.3,3,8.7])
 elif cmd=='reportindex':
  index=json.loads((R/'powerbi/report-index.json').read_text(encoding='utf-8-sig'));table('Project Power BI và trang nghiệp vụ',['Project','Các trang','Nguồn cube'],[(x['title'],'; '.join(z['label'] for z in x['pages']),x['cube']) for x in index],[4.3,7.4,4.3])
 elif cmd=='dashboardtests':table('Phân biệt kiểm thử dữ liệu và giao diện',['Kiểm tra','Bằng chứng đã có','Giới hạn'],[
  ['Field binding','70 binding duy nhất trong hồ sơ','Tên field và grouping key hợp lệ tại thời điểm thử.'],['Truy vấn visual','101 truy vấn đạt trong hồ sơ','Không chứng minh render và tương tác Desktop.'],['Kết nối live','Sáu cấu hình và health probe được lưu','Phải kiểm tra lại sau reset hoặc process mới.'],['Slicer drill cross filter','Cần nghiệm thu bằng Desktop từng trang','Không gắn nhãn đã đạt nếu chưa có bằng chứng UI.'],['Publish Service','Không nằm trong triển khai được mô tả','Cần gateway và danh tính khi triển khai thêm.']],[4.1,5.8,6.1])
 elif cmd=='appendixsource':
  for path in sorted((R/'etl/packages').glob('*.dtsx')):
   p(path.stem,'AppendixTopic');root=E.parse(str(path)).getroot()
   for task in root.findall('.//d:Executable',ns):
    name=task.get('{'+ns['d']+'}ObjectName','');p(name,'AppendixTopic');config=[]
    for e in task.findall('d:ObjectData',ns):
     for node in e.iter():
      if E.QName(node).localname not in ['SqlTaskData','ExecuteProcessData']:continue
      for k,v in node.attrib.items():
       key=E.QName(k).localname
       if key=='SqlStatementSource':code(v)
       elif key not in ['refId','DTSID','VersionGUID','CreationName']:config.append([key,v])
    for exp in task.findall('d:PropertyExpression',ns):config.append(['Expression '+exp.get('{'+ns['d']+'}Name',''),exp.text or ''])
    if config:table('Cấu hình tác vụ '+name,['Thuộc tính','Giá trị source'],config,[4.2,11.8])
    for comp in task.findall('./d:ObjectData/pipeline/components/component',ns):
     props=[(z.get('name'),''.join(z.itertext())) for z in comp.findall('./properties/property')]
     if props:table('Cấu hình component '+comp.get('name',''),['Thuộc tính','Giá trị'],props,[4.2,11.8])
     metadata=[]
     for z in comp.findall('./outputs/output/outputColumns/outputColumn'):
      config='; '.join(k+'='+v for k,v in z.attrib.items() if k in ['dataType','length','codePage','precision','scale','errorRowDisposition','truncationRowDisposition'])
      metadata.append([z.get('name',''),config])
     if metadata:table('Metadata cột đầu ra '+comp.get('name',''),['Cột','Kiểu bề rộng và xử lý lỗi'],metadata,[5.4,10.6])
   constraints=[]
   for x in root.findall('.//d:PrecedenceConstraint',ns):constraints.append([x.get('{'+ns['d']+'}From',''),x.get('{'+ns['d']+'}To',''),'; '.join(E.QName(k).localname+'='+v for k,v in x.attrib.items() if E.QName(k).localname in ['Value','EvalOp','Expression','LogicalAnd'])])
   if constraints:table('Precedence constraint '+path.stem,['Từ','Đến','Điều kiện'],constraints,[5.2,5.2,5.6])
  for path in sorted((R/'NYCTaxi_SSAS').glob('*.cube')):
   root=E.parse(str(path)).getroot();p('MDX script '+val(root,'Name'),'AppendixTopic')
   for x in root.findall('.//a:MdxScript/a:Commands/a:Command/a:Text',ns):code(x.text or '')
 elif cmd=='evidence':
  for filename in ['row-counts.csv','foreign-key-audit.csv','browse-checks.csv','reconciliation-Full.csv']:
   path=R/'evidence'/filename
   if path.exists():
    with path.open(encoding='utf-8-sig',newline='') as fp:rows=list(csv.reader(fp))
    if rows:table('Bằng chứng lưu trong '+filename,rows[0],rows[1:])
  for filename in ['dwh-integrity.sql','reconcile-Full.sql']:
   p('Truy vấn '+filename,'AppendixTopic');code((R/'queries'/filename).read_text(encoding='utf-8-sig'))
 else:raise ValueError(cmd)
# Front matter is newly written for the approved scope. No invented personal metadata.
x=p('BÁO CÁO XÂY DỰNG KHO DỮ LIỆU VÀ PHÂN TÍCH NYC TAXI','Title');x.alignment=1
p('Thiết kế kho dữ liệu ETL SSAS Multidimensional và Power BI').alignment=1
p('Báo cáo đồ án').alignment=1
p('Thời điểm biên soạn ngày 01 tháng 11 năm 2026').alignment=1
p('Phạm vi bằng chứng kỹ thuật được trích dẫn theo từng lần chụp trong dự án, chủ yếu ngày 31 tháng 10 năm 2026. Các sơ đồ được dựng để giải thích thiết kế; trạng thái kiểm thử dữ liệu và kiểm thử giao diện được phân biệt trong nội dung.')
x=p('LỜI MỞ ĐẦU','FrontHeading');x.paragraph_format.page_break_before=True
p('Dữ liệu chuyến đi NYC Taxi cung cấp cơ hội phân tích nhu cầu vận tải, đặc điểm phục vụ và các khoản tiền ghi nhận ở quy mô lớn. Tuy nhiên, dữ liệu phân tán theo nguồn, theo tháng và khác biệt cấu trúc đòi hỏi một quy trình tổ chức, chuẩn hóa và kiểm chứng trước khi khai thác. Đồ án xây dựng kho dữ liệu nhằm giải quyết nhu cầu đó và tạo nền tảng phân tích đa chiều nhất quán.')
p('Báo cáo gồm năm chương. Chương 1 giới thiệu nghiệp vụ và từ điển dữ liệu. Chương 2 thiết kế Galaxy Schema, các dimension, fact và grain. Chương 3 giải thích quy trình ETL cùng cấu hình, chất lượng và phục hồi. Chương 4 trình bày mô hình SSAS, measure và đối soát. Chương 5 mô tả các dashboard, cách khai thác và giới hạn diễn giải. Ba phụ lục cung cấp đặc tả kỹ thuật, bằng chứng và hướng dẫn vận hành.')
x=p('MỤC LỤC','FrontHeading');x.paragraph_format.page_break_before=True;fld(p(),'TOC \\o "1-3" \\h \\z')
lt=p('DANH MỤC BẢNG','FrontHeading');lt.paragraph_format.page_break_before=True
lf=p('DANH MỤC HÌNH','FrontHeading');lf.paragraph_format.page_break_before=True
x=p('DANH MỤC TỪ VIẾT TẮT','FrontHeading');x.paragraph_format.page_break_before=True
for ab,full in [('TLC','Taxi and Limousine Commission'),('FHV','For Hire Vehicle'),('HVFHV','High Volume For Hire Vehicle'),('HVFHS','High Volume For Hire Services'),('DWH','Data Warehouse'),('ETL','Extract Transform Load'),('SSIS','SQL Server Integration Services'),('SSAS','SQL Server Analysis Services'),('DSV','Data Source View'),('MDX','Multidimensional Expressions'),('MOLAP','Multidimensional Online Analytical Processing'),('SCD','Slowly Changing Dimension'),('WAV','Wheelchair Accessible Vehicle'),('PBIP','Power BI Project')]:p(ab+' — '+full)
content=(W/'content.md').read_text(encoding='utf-8');paragraph=[]
def flush():
 if paragraph:p(' '.join(paragraph));paragraph.clear()
for line in content.splitlines():
 if not line.strip():flush();continue
 if line.startswith('#'):
  flush();level=len(line)-len(line.lstrip('#'));h(line[level:].strip(),level)
 elif line.startswith('@'):flush();dispatch(line)
 else:paragraph.append(line)
flush()
for anchor,items in [(lt,caps),(lf,figs)]:
 prev=anchor._p
 for label,name in items:
  x=p(label+'\t');x.paragraph_format.line_spacing=1.1;x.paragraph_format.space_after=Pt(4);x.paragraph_format.tab_stops.add_tab_stop(Cm(16),WD_TAB_ALIGNMENT.RIGHT,WD_TAB_LEADER.DOTS)
  for r in x.runs:r.font.size=Pt(12)
  fld(x,'PAGEREF '+name+' \\h','0');prev.addnext(x._p);prev=x._p
footer=s.footer.paragraphs[0];footer.alignment=1;fld(footer,'PAGE','1')
up=OxmlElement('w:updateFields');up.set(qn('w:val'),'true');d.settings.element.append(up)
out=R/'BaoCao_NYCTaxi_5Chuong.docx';d.save(out)
(W/'inventory.json').write_text(json.dumps({'tables':len(caps),'figures':len(figs),'headings':heading_inventory,'reference_sha256':hashlib.sha256(REF.read_bytes()).hexdigest()},ensure_ascii=False,indent=2),encoding='utf-8')
print(out);print('tables',len(caps),'figures',len(figs),'headings',len(heading_inventory))
