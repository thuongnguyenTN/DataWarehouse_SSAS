from pathlib import Path
from copy import deepcopy
import json, re, sys, hashlib, zipfile, importlib.util
from collections import defaultdict
from lxml import etree as E
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
R=Path(r'E:\NYCTaxi\NYCTaxi_SSAS'); W=R/'report_work'; REF=Path(r'C:\Users\ADMIN\Downloads\Nhom04_ThietKeMucLogic_DACK.docx')
D=Document(REF); original_table=deepcopy(D.tables[0]._tbl)
if 'Caption' not in D.styles: D.styles.add_style('Caption',1)
ns={'d':'www.microsoft.com/SqlServer/Dts','a':'http://schemas.microsoft.com/analysisservices/2003/engine'}
for el in list(D._element.body):
 if el.tag!=qn('w:sectPr'): D._element.body.remove(el)
for name in ['normal','Normal','Heading 1','Heading 2','Heading 3','Title','Caption']:
 try:
  s=D.styles[name]; s.font.name='Times New Roman'; s.font.size=Pt(14); s.font.color.rgb=RGBColor(0,0,0)
  s.paragraph_format.line_spacing=1.5
 except KeyError: pass
chapter=0; counts=defaultdict(int); captions=[]; outline=[]
def p(t='',style=None):
 x=D.add_paragraph(t,style=style or 'normal'); x.paragraph_format.widow_control=True
 for r in x.runs: r.font.name='Times New Roman'; r.font.size=Pt(14); r.font.color.rgb=RGBColor(0,0,0)
 return x
def h(t,level=2):
 x=p(t,'Heading '+str(level)); x.paragraph_format.keep_with_next=True; outline.append(t); return x
def ch(n,t):
 global chapter
 chapter=n; x=h('CHƯƠNG '+str(n)+' '+t.upper(),1); x.paragraph_format.page_break_before=True
def table(title,heads,rows,widths=None):
 counts[chapter]+=1; cap=f'Bảng {chapter}.{counts[chapter]} {title}'; captions.append(cap)
 x=p(cap); x.paragraph_format.keep_with_next=True
 t=D.add_table(rows=1,cols=len(heads)); t.autofit=False
 pr=t._tbl.tblPr
 src=original_table.find(qn('w:tblPr'))
 for tag in ['tblBorders','tblLook','tblCellMar']:
  v=src.find(qn('w:'+tag))
  if v is not None: pr.append(deepcopy(v))
 if widths is None: widths=[6.5/len(heads)]*len(heads)
 for c,wd in zip(t.columns,widths): c.width=Inches(wd)
 for i,v in enumerate(heads):t.rows[0].cells[i].text=str(v)
 hdr=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(hdr)
 for row in rows:
  cells=t.add_row().cells
  for c,v in zip(cells,row):c.text=str(v if v is not None else 'NULL')
 for ri,row in enumerate(t.rows):
  for i,c in enumerate(row.cells):
   c.width=Inches(widths[i]); c.vertical_alignment=1
   for para in c.paragraphs:
    para.paragraph_format.line_spacing=1.15; para.paragraph_format.space_after=Pt(3); para.paragraph_format.space_before=Pt(3)
    for run in para.runs:run.font.name='Times New Roman';run.font.size=Pt(12);run.font.color.rgb=RGBColor(0,0,0);run.bold=(ri==0)
   for sh in c._tc.xpath('.//w:shd'):sh.getparent().remove(sh)
 return t
def code(t):
 for line in t.strip().splitlines():
  x=p(line); x.paragraph_format.line_spacing=1; x.paragraph_format.space_after=Pt(0)
  for r in x.runs:r.font.name='Consolas';r.font.size=Pt(9)
def txt(el,name,default=''):
 if el is None:return default
 v=el.find('a:'+name,ns);return v.text if v is not None and v.text else default
def attrs(el):return [(E.QName(k).localname,v) for k,v in el.attrib.items() if E.QName(k).localname not in ['refId','DTSID','VersionGUID','CreationDate','CreatorComputerName','CreatorName','LastModifiedProductVersion','CreationName']]
def friendly(s):return re.sub(r'(?<=[a-z])(?=[A-Z])',' ',s).replace('_',' ')
spec=importlib.util.spec_from_file_location('contract',R/'etl/python/extract_contract.py'); contract=importlib.util.module_from_spec(spec);spec.loader.exec_module(contract)
cols=json.loads((R/'evidence/columns.json').read_text(encoding='utf-8-sig')); fks=json.loads((R/'evidence/foreign-keys.json').read_text(encoding='utf-8-sig')); pks=json.loads((R/'evidence/primary-keys.json').read_text(encoding='utf-8-sig'))
schema=defaultdict(list)
for c in cols:schema[c['TableName']].append(c)
desc={
'VendorID':'Mã nhà cung cấp hệ thống ghi nhận chuyến đi; không phải mã tài xế hay hãng taxi.',
'passenger_count':'Số hành khách do nguồn ghi nhận; có thể thiếu và không dùng thay số chuyến.',
'trip_distance':'Quãng đường chuyến đi theo mile.', 'trip_miles':'Quãng đường chuyến HVFHV theo mile.',
'trip_time':'Thời lượng chuyến HVFHV do nguồn cung cấp, đơn vị giây.',
'PULocationID':'Mã Taxi Zone nơi đón khách; tra LocationID của danh mục vùng.',
'DOLocationID':'Mã Taxi Zone nơi trả khách; dùng cùng danh mục với nơi đón.',
'LocationID':'Mã vùng taxi trong danh mục TLC.', 'Borough':'Quận hoặc nhóm địa lý do danh mục TLC cung cấp.', 'Zone':'Tên Taxi Zone.', 'service_zone':'Phân vùng phục vụ theo danh mục TLC.',
'RatecodeID':'Mã biểu giá áp dụng cho chuyến đi; giải mã theo phiên bản từ điển TLC.',
'payment_type':'Mã phương thức hoặc tình trạng thanh toán; không áp dụng chung cho FHV.',
'store_and_fwd_flag':'Cờ lưu dữ liệu tại thiết bị rồi truyền về máy chủ; chuẩn hóa Y, N hoặc chưa biết.',
'fare_amount':'Tiền cước cơ bản của taxi, USD; khác tổng tiền khách trả.',
'extra':'Khoản phụ thu bổ sung của taxi, USD.', 'mta_tax':'Thuế MTA được ghi riêng, USD.',
'tip_amount':'Tiền tip được hệ thống ghi nhận, USD; tip tiền mặt có thể không nằm trong dữ liệu.',
'tips':'Tiền tip HVFHV, USD.', 'tolls_amount':'Phí cầu đường taxi, USD.', 'tolls':'Phí cầu đường HVFHV, USD.',
'improvement_surcharge':'Phụ thu cải thiện dịch vụ taxi, USD.', 'total_amount':'Tổng tiền taxi được nguồn ghi nhận, USD; không diễn giải thành lợi nhuận.',
'congestion_surcharge':'Phụ thu ùn tắc, USD; tách với phí CBD.', 'Airport_fee':'Phí sân bay taxi, USD.', 'airport_fee':'Phí sân bay HVFHV, USD.',
'cbd_congestion_fee':'Phí ùn tắc khu trung tâm CBD; cột bổ sung cho dữ liệu từ năm 2025, USD.',
'ehail_fee':'Phí đặt xe điện tử của Green, USD; có thể thiếu theo phiên bản.',
'trip_type':'Loại chuyến Green, dùng phân biệt cách nhận chuyến theo mã nguồn.',
'dispatching_base_num':'Số giấy phép TLC của base điều phối chuyến.', 'originating_base_num':'Base nhận yêu cầu ban đầu của chuyến HVFHV.',
'Affiliated_base_number':'Base mà xe liên kết theo hồ sơ nguồn FHV.',
'hvfhs_license_num':'Số giấy phép nhà cung cấp dịch vụ HVFHS; ánh xạ Dim_HVFHSProvider.',
'SR_Flag':'Cờ chuỗi chuyến đi chung theo quy ước FHV; không đồng nhất trực tiếp với shared_request_flag.',
'base_passenger_fare':'Cước cơ bản hành khách HVFHV, USD, trước các khoản thuế và phí được tách riêng.',
'bcf':'Khoản đóng góp Black Car Fund trong bản ghi HVFHV, USD.', 'sales_tax':'Thuế bán hàng HVFHV, USD.',
'driver_pay':'Khoản tiền trả tài xế HVFHV do nguồn công bố, USD; không phải lợi nhuận ròng.',
'shared_request_flag':'Khách yêu cầu chuyến đi chung, cờ Y/N.', 'shared_match_flag':'Chuyến được ghép đi chung, cờ Y/N.',
'access_a_ride_flag':'Chuyến theo chương trình Access A Ride, cờ Y/N.',
'wav_request_flag':'Khách yêu cầu xe hỗ trợ xe lăn WAV.', 'wav_match_flag':'Chuyến thực hiện bằng xe WAV; không mặc nhiên là đáp ứng một yêu cầu WAV trong cùng tập.'}
def meaning(n,tab=''):
 if n in desc:return desc[n]
 if 'datetime' in n.lower():
  return ('Thời điểm '+('yêu cầu xe' if 'request' in n else 'xe đến điểm đón' if 'scene' in n else 'đón khách' if 'pickup' in n else 'trả khách')+' theo nguồn; giữ ngữ nghĩa giờ địa phương của dữ liệu, không tự chuyển thành giờ Việt Nam.')
 known={'RecordHash':'Hash nhận diện nội dung bản ghi phục vụ đồng bộ; không phải TripID TLC.', 'TripKey':'Khóa thay thế nội bộ cho dòng fact; có thể thay đổi khi nguồn được hiệu chỉnh.', 'TripCount':'Số chuyến của dòng giao dịch, dùng cộng tổng.', 'ETLSourceKey':'Tên hoặc khóa file nguồn để truy vết theo file.', 'SourceKey':'Khóa file nguồn dùng cùng SourceDataset.', 'SourceDataset':'Mã bộ dữ liệu nguồn yellow, green, fhv hoặc fhvhv.', 'SnapshotUpdatedAt':'Thời điểm cập nhật snapshot; không phải thời điểm chuyến đi.', 'IsHoliday':'Cờ ngày lễ; bản dữ liệu được rà soát chưa có lịch ngày lễ được xác nhận.', 'SourceFileName':'Tên file của lô nếu có; không thay lineage SourceKey của fact.', 'LoadBatchKey':'Khóa nhóm nạp; không mặc nhiên đại diện duy nhất cho file nguồn.'}
 if n in known:return known[n]
 rel=[f for f in fks if f['FactTable']==tab and f['FactColumn']==n]
 if rel:return 'Khóa ngoại đến '+', '.join(f["DimTable"]+'.'+f['DimColumn'] for f in rel)+'. Vai trò '+friendly(n.replace('Key',''))+'. Khóa 0 biểu diễn Unknown theo quy ước kho.'
 if n.endswith('Key'):return 'Khóa định danh '+friendly(n[:-3])+'. Kiểm tra vai trò khóa chính hoặc khóa thay thế trong mô hình.'
 if 'Seconds' in n:return 'Giá trị '+friendly(n)+' theo giây; NULL thể hiện thiếu dữ liệu. Khi tính trung bình phải dùng số chuyến có giá trị hợp lệ.'
 if 'Miles' in n:return 'Quãng đường '+friendly(n)+' theo mile; khi cộng hoặc tính tốc độ cần giữ cùng tập dòng hợp lệ.'
 if any(x in n for x in ['Amount','Fare','Pay','Tips','Charges','Fees','Surcharge','Tax','Fee']):return 'Giá trị tiền '+friendly(n)+' theo USD. NULL khác 0; áp dụng phạm vi nguồn của fact.'
 if n.startswith('Total') or n.endswith('Count'):return 'Số đếm hoặc tổng '+friendly(n)+' tại grain của bảng; không cộng trùng với fact nguồn.'
 if n.startswith('Is') or n.endswith('Flag'):return 'Thuộc tính cờ '+friendly(n)+'; giữ trạng thái chưa biết nếu nguồn không cung cấp.'
 return 'Thuộc tính '+friendly(n)+' của '+tab+'. Kiểu và khả năng NULL được trích từ metadata SQL; dùng đúng ngữ cảnh dimension hoặc fact của bảng.'

title=p('BÁO CÁO XÂY DỰNG KHO DỮ LIỆU VÀ PHÂN TÍCH NYC TAXI','Title');title.alignment=1
p('Dự án NYC Taxi Data Warehouse');p('Mô hình áp dụng Galaxy Schema và SSAS Multidimensional');p('Phạm vi báo cáo Dữ liệu nguồn ETL SSAS và Dashboard Power BI')
p('Báo cáo trình bày thiết kế và cách xây dựng hệ thống phân tích chuyến đi NYC Taxi dựa trên mã nguồn, metadata và bằng chứng lưu trong dự án. Bốn chương lần lượt làm rõ nghiệp vụ, cấu trúc dữ liệu, quy trình xử lý và cách khai thác trên Power BI. Các số liệu kiểm thử được ghi theo thời điểm chụp bằng chứng ngày 31 tháng 10 năm 2026, không phải kết quả chạy lại hệ thống trong lần biên soạn này.')
p('File Nhom04 được sử dụng làm mẫu hình thức và cách giải thích mô hình. Các tên bảng logistics trong mẫu không phải yêu cầu nghiệp vụ của NYC Taxi. Báo cáo giữ cách trình bày theo mục tiêu, phân cấp, grain, fact, dimension và ma trận dùng chung, đồng thời bổ sung cấu hình kỹ thuật thực tế.')
h('MỤC LỤC',1)
toc=p(); fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'TOC \\o "1-2" \\h \\z');toc._p.append(fld)
p('Mục lục và danh mục bảng là trường tự động của Word. Khi mở tài liệu, cập nhật toàn bộ trường để hiển thị số trang theo máy đang sử dụng.')
lot_location=len(D.paragraphs);h('DANH MỤC BẢNG',1); lot=p()

ch(1,'Tổng quan dữ liệu và thiết kế kho dữ liệu')
h('1.1 Mục tiêu và bài toán nghiệp vụ')
p('NYC Taxi là bài toán vận tải hành khách tại thành phố New York. Một chuyến đi phát sinh khi khách lên xe hoặc khi yêu cầu đặt xe được phục vụ, kết thúc khi khách xuống xe. NYC Taxi and Limousine Commission, viết tắt TLC, quản lý và công bố các bộ dữ liệu chuyến đi. Dữ liệu phục vụ phân tích nhu cầu theo thời gian và địa bàn, cách sử dụng dịch vụ, chi phí hành khách, thu nhập tài xế được ghi nhận và hoạt động điều phối của base. Bộ dữ liệu công khai không phải một hệ thống kế toán đầy đủ của từng doanh nghiệp.')
p('Các nhóm câu hỏi trọng tâm gồm số chuyến theo ngày, tháng và giờ; phân bố điểm đón và điểm trả; khác biệt giữa các loại dịch vụ; hành vi thanh toán và tip; thời gian chờ HVFHV; tiền khách trả và tiền tài xế; khối lượng điều phối theo base. Mỗi câu hỏi phải gắn với nguồn có trường tương ứng. FHV không có đầy đủ tài chính nên không được bổ sung doanh thu giả định để so sánh.')
table('Các loại dịch vụ trong phạm vi dự án',['Nguồn','Loại dịch vụ và quy trình','Phạm vi phân tích'],[
['Yellow','Taxi màu vàng thuộc hệ thống medallion, nhận khách vẫy xe trên đường theo phạm vi TLC cho phép và có thể nhận đặt xe. Dữ liệu ghi đồng hồ, vị trí và tiền cước.','Nhu cầu, quãng đường, cước, thanh toán, tip.'],
['Green','Taxi màu xanh còn gọi Boro Taxi hoặc Street Hail Livery, phục vụ nhu cầu vẫy xe ở các khu vực được phép ngoài vùng hạn chế của Manhattan và sân bay. Không suy luận quyền đón khách chỉ từ màu xe.','Chuyến Green được lưu cùng fact Yellow nhưng phân biệt ServiceTypeKey.'],
['FHV','For Hire Vehicle là xe phục vụ chuyến đặt trước qua base; bao gồm các nhóm như livery, black car và limousine theo quy định TLC. File FHV không đồng nghĩa tất cả xe công nghệ.','Điều phối base, thời gian, địa lý và cờ SR theo nguồn.'],
['FHVHV','High Volume For Hire Vehicle là nhóm dịch vụ đặt xe có quy mô điều phối lớn, thuộc hệ sinh thái FHV; HVFHS là giấy phép của nhà cung cấp. Nguồn tách riêng từ 2019.','Yêu cầu, đến điểm đón, đón trả, tiền khách, tiền tài xế và cờ dịch vụ.']],[0.65,3.65,2.2])
p('Nguồn đối chiếu nghiệp vụ và metadata chính thức: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page và các từ điển dữ liệu được liệt kê cuối báo cáo. Quyền khai thác dịch vụ và cấu trúc trường có thể thay đổi theo kỳ; cấu hình dự án được ưu tiên khi mô tả phần đã triển khai.')
h('1.2 Nguồn dữ liệu và phạm vi bao phủ')
p('Dự án sử dụng Parquet theo bộ dữ liệu và tháng, cùng taxi_zone_lookup.csv. Hợp đồng extract đặt tháng đầu tương ứng Yellow 2009 01, Green 2013 08, FHV 2015 01 và FHVHV 2019 02. Đây là mốc lựa chọn file của chương trình; không phải cam kết mọi tháng trong các khoảng đó đã được nạp. File tháng không tạo ra khóa chuyến kinh doanh bền vững. Hai dòng có payload giống nhau vẫn có thể là hai lượt xuất hiện cần bảo toàn.')
p('Bằng chứng rà soát ghi nhận 56 file chuyến, mỗi file bị giới hạn 10.000 dòng đầu, tổng 560.000 dòng clean, 558.183 hợp lệ và 1.817 bị loại. Phạm vi này là dữ liệu demo, không phải toàn bộ hoạt động NYC. MaxRows bằng 0 đọc đầy đủ từng file đã chọn; MaxRows lớn hơn 0 lấy các dòng đầu chứ không lấy mẫu ngẫu nhiên. Không diễn giải tỷ trọng của tập demo thành thị phần thành phố hoặc dùng biểu đồ để khẳng định tác động nhân quả.')
h('1.3 Từ điển metadata dữ liệu nguồn')
p('Các bảng sau liệt kê toàn bộ trường trong extract_contract.py. CSV là lớp tiếp nhận chuỗi; trường chuyến có bề rộng 50 ký tự, trường danh mục vùng ngoài LocationID có bề rộng 255. Kiểu phân tích được chuyển trong Transform bằng TRY_CONVERT. Cột optional thiếu trong file được xử lý theo hợp đồng, không tự coi giá trị thiếu là 0. Bộ chuyển đổi chấp nhận biến thể hoa thường, từ chối tên cột trùng không phân biệt hoa thường, cột lạ và cột thiết yếu bị thiếu.')
for ds,profile in contract.DATASETS.items():
 h('1.3.'+str(list(contract.DATASETS).index(ds)+1)+' Nguồn '+ds,3)
 table('Metadata nguồn '+ds,['Trường','Ý nghĩa nghiệp vụ','Tiếp nhận và thiếu cột'],[(n,meaning(n),'Chuỗi '+str(contract.width(ds,n))+'; '+('optional' if n in contract.OPTIONAL[ds] else 'bắt buộc có cột')) for n in profile[3]],[1.65,3.4,1.45])
h('1.4 Kiến trúc Galaxy Schema')
p('Kho dữ liệu dùng Galaxy Schema với ba fact giao dịch và ba fact snapshot dùng chung các dimension. Lớp raw giữ file tải về; CSV ổn định hợp đồng; wrk tiếp nhận theo file; stg giữ dữ liệu nguồn kèm lineage; clean.Trip chuẩn hóa và phân loại chất lượng; clean.ValidTrip cung cấp tập được nạp; dbo của NYCTaxi_DWH lưu các bảng chiều và sự kiện. SSAS đọc DWH qua một Data Source và một DSV dùng chung; Power BI kết nối live đến từng cube nghiệp vụ.')
p('Dimension dùng chung bảo đảm cùng khóa ngày, giờ, địa lý và dịch vụ có cùng ý nghĩa giữa các fact. Dimension dùng riêng giữ đặc trưng của nguồn, tránh tạo cột không có nghĩa với FHV. Pickup và Dropoff cùng dùng Dim_Date, Dim_Time và Dim_Location nhưng ở vai trò khác nhau; Dispatch, Origin và Affiliated cùng dùng Dim_Base theo ngữ cảnh. Không join trực tiếp các fact giao dịch theo ngày hoặc vùng vì sẽ nhân số dòng.')
h('1.5 Mức chi tiết grain của từng fact')
grains={
'Fact_YellowGreen_Trips':'Một dòng là một lượt xuất hiện chuyến Yellow hoặc Green hợp lệ từ một file nguồn. Đây là transaction fact; ngày đón, ngày trả và các khoản tiền cùng nằm trên một dòng.',
'Fact_FHV_Trips':'Một dòng là một lượt xuất hiện chuyến FHV hợp lệ của file nguồn. Ghi vai trò base điều phối, base liên kết, thời gian và vị trí; không có cước như Yellow.',
'Fact_HVFHV_Trips':'Một dòng là một lượt xuất hiện chuyến HVFHV hợp lệ. Có nhiều mốc thời gian yêu cầu, đến nơi, đón và trả trên cùng dòng. Việc có nhiều mốc không làm nó thành accumulating snapshot cập nhật tiến trình; nguồn đang là bản ghi chuyến đã công bố.',
'Fact_Daily_Financial_Snapshot':'Một dòng cho tổ hợp DateKey và ServiceTypeKey. Tổng hợp tài chính theo ngày của các nguồn có tài chính; không có doanh thu FHV giả lập.',
'Fact_Zone_Traffic_Snapshot':'Một dòng cho DateKey, TimeKey, LocationKey và ServiceTypeKey. Ghi tổng lượt đón, tổng lượt trả theo ngày, phút, vùng và dịch vụ; giờ là mức tổng hợp qua dimension, không phải grain vật lý của bảng.',
'Fact_Base_Performance_Snapshot':'Một dòng cho DateKey, DispatchBaseKey, ServiceTypeKey và HVFHSProviderKey. Tổng hợp khối lượng và chỉ tiêu phục vụ theo ngày, base điều phối, dịch vụ và nhà cung cấp.'}
table('Grain và loại fact',['Fact','Loại','Grain'],[(n,'Transaction' if n.endswith('_Trips') else 'Periodic snapshot',v) for n,v in grains.items()],[1.85,1.0,3.65])
p('Ba snapshot là các fact tổng hợp nghiệp vụ được ETL dựng từ transaction fact. Chúng không phải SSAS aggregation design và không được cộng tiếp với transaction fact để tính tổng chuyến. Giá trị trung bình lưu trong snapshot không có tính cộng dồn: cần dùng tổng thời gian chia tổng số chuyến có thời gian hợp lệ ở phạm vi lọc mới.')
h('1.6 Dimension dùng chung phân cấp và quản lý thay đổi')
p('Dim_Date có phân cấp Năm → Quý → Tháng → Ngày. Khóa quý gồm YearNumber và QuarterNumber, khóa tháng gồm YearNumber và MonthNumber, tránh gộp tháng cùng tên của các năm. Dim_Time có TimeBand → Hour → Time, phút hợp lệ dùng khóa 1 đến 1440, khóa 0 dành Unknown; giờ phải giữ khóa phân biệt Unknown với 00 giờ. Dim_Location có Borough → Zone, Zone dùng LocationKey còn tên hiển thị dùng ZoneName.')
p('Các dimension chuyên biệt gồm Vendor, Rate Code, Payment Type, Passenger Group, Trip Type, HVFHS Provider, Base, Taxi Flags, FHV Flags và HVFHV Flags. Các junk dimension gom tổ hợp cờ thành khóa để giảm số cột cờ trong fact. Dim_LoadBatch hiện phản ánh nhóm xử lý suy từ tháng pickup, không thay cho lineage file. Dim_Location áp dụng SCD Type 1 để cập nhật thuộc tính hiện hành; Dim_Base chủ yếu bổ sung mã mới, chưa có cơ chế SCD Type 2 theo thời hạn hiệu lực.')
h('1.7 Thiết kế chi tiết từng bảng dimension và fact')
p('Metadata vật lý dưới đây lấy từ evidence/columns.json và các tệp khóa đã chụp; được đối chiếu vai trò với DSV và package. Độ dài của nvarchar trong bằng chứng là số byte nên được đổi sang số ký tự. Precision và scale không có trong bản chụp columns.json; không suy đoán chúng từ MaxLength. Khi cần tái tạo DDL chính xác phải dùng SQL tạo bảng trong package hoặc metadata sys.columns có precision và scale. Hai cột lineage SourceDataset và SourceKey được bổ sung sau lần chụp schema cũ và được nêu riêng tại mục ETL.')
for ti,(tab,cc) in enumerate(schema.items(),1):
 if not (tab.startswith('Dim_') or tab.startswith('Fact_')):continue
 h('1.7.'+str(ti)+' '+tab,3)
 if tab in grains:p(grains[tab])
 else:p('Bảng chiều '+tab+' lưu ngữ cảnh '+friendly(tab.replace('Dim_',''))+' để phân tích các sự kiện. Các khóa 0 được giữ làm thành viên Unknown; không loại dòng fact chỉ vì thuộc tính chiều chưa đầy đủ.')
 rows=[]
 for c in cc:
  dt=c['DataType']; ml=c['MaxLength']
  if dt in ['varchar','nvarchar','char','nchar']:dt+='('+('max' if ml<0 else str(ml//2 if dt.startswith('n') else ml))+')'
  pk=any(k['TableName']==tab and k['ColumnName']==c['ColumnName'] for k in pks)
  rows.append([c['ColumnName'],dt,('Có' if c['Nullable'] else 'Không')+('; PK' if pk else ''),meaning(c['ColumnName'],tab)])
 table('Cấu trúc '+tab,['Cột','Kiểu','NULL và khóa','Mô tả'],rows,[1.6,1.0,.8,3.1])
h('1.8 Ma trận nghiệp vụ và liên kết khóa ngoại')
dims=sorted(set(f['DimTable'] for f in fks))
table('Ma trận fact và dimension dùng chung',['Fact','Dimension liên quan và vai trò'],[(t,'; '.join(f["FactColumn"]+' → '+f['DimTable'] for f in fks if f['FactTable']==t)) for t in grains],[1.9,4.6])
table('Danh mục quan hệ khóa ngoại vật lý',['Fact và cột','Dimension và khóa','Ràng buộc'],[(f['FactTable']+'.'+f['FactColumn'],f['DimTable']+'.'+f['DimColumn'],f['FKName']) for f in fks],[2.35,2.0,2.15])
p('Quan hệ khóa ngoại bảo vệ toàn vẹn tham chiếu khi nạp. Các khóa không tra được được ánh xạ Unknown theo quy tắc có kiểm soát; NULL nguồn và mã nguồn có giá trị nhưng chưa có mapping là hai trường hợp khác nhau. Bằng chứng rà soát ghi nhận 15 dimension có khóa 0, 51 quan hệ được kiểm tra không có orphan và 52 FK vật lý enabled, trusted. Số lượng quan hệ được truy vấn kiểm tra không thay cho tổng số constraint vật lý.')

ch(2,'Xây dựng quy trình ETL')
h('2.1 Kiến trúc thực thi và các luồng chính')
p('Điểm vào dành cho vận hành là PKG_00_Master hoặc Invoke-NYCTaxiPipeline.ps1. Master gồm các Execute Process Task gọi Invoke-SsisStage.ps1; controller gọi runner theo từng stage với cùng RunId. Runner dùng Python để tải, chuyển đổi và kiểm tra file, SqlBulkCopy để đưa CSV vào wrk, và thực thi SQL nhúng trong PKG_01 đến PKG_04. Vì vậy tab Data Flow của package con không thể hiện tiến độ của các câu lệnh đang được runner thực thi. Chạy trực tiếp package con là một đường thực thi khác và không được coi mặc nhiên có cùng khóa toàn cục của runner.')
table('Các chặng của luồng chính',['Thứ tự','Stage','Đầu vào và đầu ra','Điều kiện chuyển bước'],[
[1,'Extract','Parquet và lookup → raw, CSV, wrk, stg và ExtractFileLog.','File, cấu trúc, hash và số dòng được xác nhận.'],[2,'Transform','stg → clean.Trip, tập hợp lệ, bị loại và cảnh báo.','Đủ lineage, phiên bản rule và số dòng khớp.'],[3,'Dwh','clean.ValidTrip → dimension, ba fact và DwhFileLog.','Commit từng file, validation coverage và số dòng.'],[4,'Aggregates','Ba fact → ba snapshot và watermark.','Toàn bộ rebuild và validation trong một transaction.'],[5,'Ssas','DWH ổn định → database SSAS được ProcessFull.','Xử lý thành công và đối soát SQL MDX đạt.']],[.45,.8,3.1,2.15])
h('2.2 Tham số đường dẫn kết nối và giới hạn dữ liệu')
p('Runner mặc định StartMonth 2025 01, EndMonth 2025 12, MaxRows 100000, còn Master trong bản package được đọc đang cấu hình tháng 2021 02 và 10000 dòng. Giá trị của package truyền vào controller có thể khác mặc định của script. Báo cáo giữ nguyên sự khác biệt này để người triển khai không nhầm cấu hình demo với mặc định thư viện. SQL và SSAS hiện trỏ THUONGNGUYEN\\MSSQLSV; runner mặc định đọc package từ E:\\NYCTaxi\\NYCTaxi_DW\\NYCTaxi_ETL, còn bản source được báo cáo ở etl/packages.')
runner=(R/'etl/Invoke-NYCTaxiPipeline.ps1').read_text(encoding='utf-8-sig')
code(runner[:runner.find("$ErrorActionPreference")])
p('Kết nối SQL sử dụng Integrated Security, Connect Timeout 15 giây, Application Name NYCTaxi Pipeline và CommandTimeout 1800 giây cho helper SQL. Tài khoản thực thi phải có quyền đọc ghi đúng database và thư mục; tài khoản dịch vụ SSAS phải đọc được DWH. Preflight kiểm tra đường dẫn, kết nối hai database và import pyarrow, lxml, nhưng không thay cho một ca ETL thành công.')
h('2.3 Chi tiết package các tác vụ và cấu hình')
task_purpose={
'Prepare_Staging':'Chuẩn bị schema và bảng tiếp nhận. Giữ lineage theo file để không thay toàn bộ lịch sử mỗi lượt.',
'Validate_Staging':'Đối chiếu số dòng và trạng thái nạp trước khi cho Transform sử dụng.',
'Setup_Clean':'Chuẩn bị các đối tượng chuẩn hóa và kiểm tra chất lượng.',
'Transform_TaxiZone':'Chuẩn hóa danh mục LocationID, Borough, Zone và ServiceZone trước các chuyến đi.',
'Transform_YELLOW':'Chuyển các cột tpep và tài chính Yellow sang cấu trúc clean chung; bảo toàn lineage và phân loại lỗi.',
'Transform_GREEN':'Chuyển các cột lpep, trip_type và phí Green; giữ khác biệt nghiệp vụ với Yellow.',
'Transform_FHVHV':'Chuyển các mốc request, on scene, pickup, dropoff, tiền và cờ HVFHV.',
'Transform_FHV':'Chuẩn hóa chuyến FHV, base điều phối, base liên kết và cờ nguồn SR_Flag.',
'Validate_Transform':'Kiểm tra coverage file, số dòng và chất lượng sau chuẩn hóa.',
'Precheck_DWH':'Kiểm tra cấu trúc, nguồn đã Transform và điều kiện checkpoint trước nạp.',
'Load_Dimensions':'Nạp dimension từ tập file cần xử lý và danh mục Taxi Zone; duy trì mapping và Unknown.',
'Load_FactYellowGreen':'Đồng bộ fact YellowGreen theo file, giữ ServiceTypeKey riêng cho hai dịch vụ.',
'Load_FactFHV':'Đồng bộ fact FHV theo file và các vai trò dimension đặc thù.',
'Load_FactHVFHV':'Đồng bộ fact HVFHV theo file cùng mốc thời gian và chỉ tiêu tài chính.',
'Validate_DWH':'Đối chiếu file cần xử lý, checkpoint và số dòng fact sau load.',
'Atomic_Rebuild_And_Validate':'Rebuild ba snapshot, kiểm tra tổng hợp và watermark trong một transaction.'}
packages=[]
for path in sorted((R/'etl/packages').glob('*.dtsx')):
 root=E.parse(str(path)).getroot();packages.append((path,root));h('2.3.'+str(len(packages))+' '+path.stem,3)
 table('Thuộc tính package '+path.stem,['Thuộc tính','Giá trị'],attrs(root),[2.0,4.5])
 params=[]
 for el in root.findall('.//d:PackageParameter',ns):params.append([el.get('{'+ns['d']+'}ObjectName'),'; '.join((x.text or '') for x in el)])
 if params:table('Tham số '+path.stem,['Tên','Mặc định'],params,[1.7,4.8])
 variables=[]
 for el in root.findall('.//d:Variable',ns):
  variables.append([el.get('{'+ns['d']+'}ObjectName'),el.get('{'+ns['d']+'}Expression') or '; '.join(el.itertext()).strip()])
 if variables:table('Biến '+path.stem,['Biến','Biểu thức hoặc giá trị'],variables,[1.5,5])
 for task in root.findall('.//d:Executable',ns):
  name=task.get('{'+ns['d']+'}ObjectName','');typ=task.get('{'+ns['d']+'}ExecutableType','')
  h(name,3)
  purpose=next((v for k,v in task_purpose.items() if name.endswith(k)),None)
  p(purpose or ('Tác vụ '+name+' thuộc '+path.stem+'. Loại thực thi '+typ+'. Cấu hình bên dưới là giá trị lưu trong package; biểu thức được đánh giá lại khi chạy.'))
  cfg=attrs(task)
  for obj in task.findall('d:ObjectData',ns):
   for el in obj.iter():
    if E.QName(el).localname in ['ExecuteProcessData','SqlTaskData']:cfg += [(k,v) for k,v in attrs(el) if k!='SqlStatementSource']
  for exp in task.findall('d:PropertyExpression',ns):cfg.append([exp.get('{'+ns['d']+'}Name','Expression'),exp.text or ''])
  if cfg:table('Cấu hình '+path.stem+' '+name,['Thuộc tính','Giá trị'],cfg,[1.65,4.85])
  for component in task.findall('.//component'):
   cname=component.get('name','');p('Data Flow component '+cname+' dùng lớp '+component.get('componentClassID','')+'.')
   cr=[]
   for prop in component.findall('./properties/property'):cr.append([prop.get('name'),''.join(prop.itertext())])
   if cr:table('Thuộc tính component '+cname,['Thuộc tính','Giá trị'],cr,[1.6,4.9])
   for io in component.findall('./outputs/output')+component.findall('./inputs/input'):
    io_cols=io.findall('.//outputColumn')+io.findall('.//inputColumn')
    if io_cols:table('Metadata cổng '+cname+' '+io.get('name',''),['Cột','Cấu hình dữ liệu'],[(c.get('name',c.get('cachedName','')),'; '.join(k+'='+v for k,v in c.attrib.items() if k not in ['refId','lineageId','name','externalMetadataColumnId','cachedName'])) for c in io_cols],[1.7,4.8])
 cons=[]
 for el in root.findall('.//d:PrecedenceConstraint',ns):cons.append([el.get('{'+ns['d']+'}From',''),el.get('{'+ns['d']+'}To',''),'; '.join(k+'='+v for k,v in attrs(el) if k in ['Value','Expression','EvalOp','LogicalAnd']) or 'Success theo mặc định SSIS'])
 if cons:table('Đường nối điều khiển '+path.stem,['Từ','Đến','Điều kiện'],cons,[2.25,2.25,2])
 cms=[]
 for el in root.findall('./d:ConnectionManagers/d:ConnectionManager',ns):
  cms.append([el.get('{'+ns['d']+'}ObjectName',''),E.tostring(el,encoding='unicode')])
 if cms:
  for name,xml in cms:
   p('Connection Manager '+name+'. Các giá trị kết nối, Flat File và biểu thức được lưu trong cấu hình package; dưới đây là cấu hình đầy đủ để đối chiếu.')
   code(E.tostring(E.fromstring(xml.encode()),encoding='unicode',pretty_print=True))
h('2.4 Luồng Extract theo file')
p('Runner gọi downloader theo khoảng tháng, bỏ qua các bộ dữ liệu chưa tồn tại ở mốc đầu trong hợp đồng. Offline chỉ bỏ bước download và vẫn yêu cầu đủ file raw. RefreshSource buộc nhận lại bản nguồn thay vì dùng cache. Converter đọc Parquet theo batch để hạn chế bộ nhớ, xuất CSV UTF 8, kết thúc dòng LF, theo đúng thứ tự cột của hợp đồng SSIS. File tạm được đổi tên khi hoàn tất để tránh dùng một CSV đang viết dở.')
p('Metadata CSV ghi signature file nguồn, dataset, danh sách cột, schema_mode, contract_version, encoding, line_ending, rows, source_rows, row_limit, kích thước, thời điểm sửa và SHA256. Điều kiện reuse kiểm tra cả cấu hình chuyển đổi và hash CSV. Inspector xác nhận header, số trường, độ rộng, số dòng và hash trước nạp. Dữ liệu được bulk copy vào bảng wrk rồi commit sang stg theo file. Nếu nạp một CSV lỗi, file và metadata được đưa vào quarantine theo RunId và dataset; không bỏ riêng dòng CSV sai cấu trúc rồi báo thành công.')
h('2.5 Luồng Transform và kiểm soát chất lượng')
p('Danh mục Taxi Zone phải được chuẩn hóa trước các dataset chuyến đi. Mỗi task tính ZoneHash, đọc các file Extract đã SUCCEEDED và đủ RowsLoaded, kiểm tra số dòng cùng hash clean hiện có, sau đó chọn #Todo khi file mới, file đổi hash, số dòng lệch, RuleVersion đổi hoặc ZoneHash đổi. Với các file cần làm lại, task kiểm tra staging đúng lineage trước khi xóa và dựng lại phần clean tương ứng; các file đã hoàn tất được giữ.')
p('Chuỗi rỗng được xử lý NULLIF sau LTRIM và RTRIM. Thời gian chuyển DATETIME2, số tiền chuyển DECIMAL và các mã số được chuyển có kiểm soát để không âm thầm cắt phần thập phân. Cờ Y, 1, TRUE được chuẩn hóa Y; N, 0, FALSE thành N, ngoài tập thành chưa biết. Hai mốc pickup và dropoff cho phép tính DurationSeconds; chênh lệch thời gian và ngưỡng tối đa 48 giờ được kiểm tra theo SQL của từng nguồn. Missing location không đồng nghĩa phải xóa chuyến: mapping có thể đi vào Unknown và sinh cảnh báo.')
p('clean.Trip giữ kết quả chuẩn hóa, clean.ValidTrip là tập được nạp DWH; clean.RejectedTrip và clean.WarningTrip cho phép truy nguyên lỗi nghiệp vụ và cảnh báo. Lỗi kiểu cấu trúc file thuộc Extract, còn lỗi nghiệp vụ thuộc Transform. Không biến tất cả lỗi thành NULL rồi cộng tổng mà không theo dõi. Cấu hình lỗi và toàn bộ nhánh phân loại thực tế được lưu trong đặc tả SQL ở phần cuối chương này.')
h('2.6 Luồng nạp dimension và fact theo checkpoint')
p('etl.DwhSourceState chỉ chọn yellow, green, fhv, fhvhv, yêu cầu Extract và Transform cùng phiên bản và đầy đủ số dòng. Lookup không phải file fact nên không tạo DwhFileLog giả cho taxi_zone_lookup.csv. Phiên bản nguồn kết hợp hash, rule, ZoneHash, số dòng và thời điểm Transform. etl.DwhFileLog giữ checkpoint theo DatasetCode và SourceKey, LoaderVersion, số dòng hợp lệ, số dòng fact, insert, update, delete, lỗi, UnknownMask và ForceReload.')
p('Dimension lấy danh mục từ #DeltaTrip của file cần nạp thay vì quét toàn lịch sử cho mỗi batch. Fact dựng #Desired riêng cho từng file; hash bao gồm dịch vụ và SourceKey, ordinal phân biệt các dòng trùng trong cùng file để bảo toàn multiplicity. Audit bản ghi cũ, delete các bản ghi không còn phù hợp, update các mapping cần đổi, insert dòng mới và ghi checkpoint thành công được đặt trong transaction theo file. File lỗi rollback toàn file; file đã commit trước đó vẫn giữ. File không còn dòng hợp lệ vẫn phải xóa phần fact cũ thuộc file đó và ghi checkpoint 0.')
p('Index fact theo SourceDataset, SourceKey và INCLUDE RecordHash hỗ trợ truy xuất đúng phạm vi. SourceDataset và SourceKey là lineage thực tế bổ sung sau lần chụp columns.json. TripKey là surrogate key, không phải mã chuyến được TLC bảo đảm; hiệu chỉnh nguồn có thể làm delete insert và đổi TripKey. Không mô tả mọi correction là update ổn định một mã chuyến.')
p('Fingerprint mapping chia nhóm Location, Base và các mã danh mục. Chỉ những mã nguồn khác NULL nhưng chưa tra được khóa mới là Unknown có khả năng sửa. Khi mapping đổi, các file có Unknown thuộc nhóm liên quan được chọn lại. Đổi tên vùng SCD1 không đổi khóa nên không tự nạp lại toàn fact. Sửa seed ngày, giờ, junk dimension hoặc sửa clean ngoài luồng cần ForceReload hoặc nâng LoaderVersion phù hợp. Không sửa trạng thái log sang SUCCEEDED để bỏ lỗi.')
h('2.7 Luồng tổng hợp ba snapshot')
p('PKG_04 rebuild cả ba snapshot trong một transaction cùng validation và watermark. Daily Financial nhóm ngày và dịch vụ cho nguồn có tài chính, tính số chuyến, quãng đường, tiền khách trả, tip, thuế phí và tiền tài xế theo khả năng của nguồn. Zone Traffic tách sự kiện pickup và dropoff, dùng ngày giờ vùng tương ứng của từng sự kiện rồi nhóm lại. Base Performance nhóm ngày, base điều phối, dịch vụ và provider; lưu tổng thời lượng cùng DurationTripCount, tổng thời gian chờ cùng WaitingTripCount để tính lại trung bình đúng ở mọi cấp.')
p('Nếu một phép kiểm tra không đạt, cả ba snapshot và watermark rollback. Thiết kế này phản ánh correction hoặc deletion lịch sử, nhưng chi phí tăng theo toàn kho. Đây chưa phải aggregate incremental theo ngày bị ảnh hưởng. Không cộng TotalPickups với TotalDropoffs để gọi là số chuyến vì đó là hai sự kiện khác nhau của một chuyến.')
h('2.8 Điều phối lỗi retry resume và nhật ký')
p('Mỗi run có RunId và ConfigHash gồm tháng, giới hạn dòng, server, đường dẫn và chế độ chạy. Khóa sp_getapplock độc quyền NYCTaxi Full Pipeline ngăn hai runner sửa dữ liệu đồng thời. Một run RUNNING chưa kết thúc cũng chặn RunId khác; cần kiểm tra tiến trình và log trước khi resume cùng RunId. ResumeCheck so ConfigHash, yêu cầu stage trước đã có StageComplete SUCCEEDED. Khi chạy lại stage trước, các StageComplete phía sau bị INVALIDATED để không dùng kết quả phụ thuộc cũ.')
p('PipelineRun ghi trạng thái cấp lượt; PipelineStep ghi tác vụ và từng file; events.jsonl, status.json, stdout và stderr giữ bằng chứng local, kể cả khi SQL lỗi. OnError của package ghi PackageError khi chạy native SSIS; không nhầm log đó là nguồn duy nhất của runner. Khi lỗi, runner trả exit code khác 0, giữ lỗi gốc, ghi failure JSON và alerts JSON. Các alert là file cho công cụ giám sát, chưa phải email đã gửi.')
p('Master controller có cơ chế retry theo cấu hình và phân loại lỗi. Retry không được đồng nhất với chạy tiếp bất chấp lỗi. Native checkpoint giữa component SSIS không phải cơ chế chính: checkpoint ở đây là nghiệp vụ theo SQL, file và stage. Mỗi file có commit riêng; aggregate và SSAS có transaction riêng. Không tồn tại một transaction phân tán bao phủ Python, SQL và SSAS. Nếu SSAS thất bại, DWH vẫn có thể đã cập nhật và được phép chạy lại bước cuối theo điều kiện resume.')
h('2.9 Đặc tả SQL đầy đủ của các tác vụ')
p('Phần này lưu nguyên văn SQL nhúng trong các package hiện có để thể hiện chính xác biểu thức chuyển đổi, điều kiện loại dữ liệu, mapping, DDL, checkpoint và validation. Đây là đặc tả bổ sung cho phần giải thích trên; các tên máy và đường dẫn là cấu hình của bản nguồn được đọc, cần cấu hình lại khi chuyển môi trường. Không có câu SQL nào trong phần này được thực thi trong lần viết báo cáo.')
for path,root in packages:
 for task in root.findall('.//d:Executable',ns):
  for el in task.iter():
   for k,v in el.attrib.items():
    if E.QName(k).localname=='SqlStatementSource' and v.strip():
     h(path.stem+' '+task.get('{'+ns['d']+'}ObjectName',''),3);code(v)

ch(3,'Xây dựng mô hình SSAS Multidimensional')
h('3.1 Mục tiêu và kiến trúc phân tích')
p('SSAS Multidimensional cung cấp tầng ngữ nghĩa dùng chung cho dashboard. Sáu cube theo nghiệp vụ giúp phân biệt nguồn, grain và chỉ tiêu thay vì đặt mọi phép đo vào một cube tổng hợp dễ cộng sai. Data Source DS_NYCTaxi_DWH dùng MSOLEDBSQL, Windows authentication và danh tính dịch vụ SSAS để truy cập NYCTaxi_DWH. DSV dùng 15 dimension, ba transaction fact và ba snapshot fact; tệp DSV_NYCTaxi.dsv tiếp tục tên cũ nhưng ID mô hình là DSV_NYCTaxi_DWH.')
h('3.2 Dimension thuộc tính khóa và hierarchy')
p('Dimension vật lý được định nghĩa một lần ở cấp database, sau đó cube tái sử dụng theo vai trò. KeyColumns quyết định tính duy nhất của member; NameColumn chỉ phục vụ hiển thị. Quan hệ thuộc tính phải phản ánh phân cấp tự nhiên trước khi tối ưu tổng hợp. Khóa ngày tháng ghép năm, giờ có TimeBand và Unknown tách riêng, vùng dùng LocationKey là các quyết định nhằm ngăn gộp nhầm member cùng caption.')
for dimpath in sorted((R/'NYCTaxi_SSAS').glob('*.dim')):
 root=E.parse(str(dimpath)).getroot();h(txt(root,'Name'),3)
 table('Thuộc tính dimension '+txt(root,'Name'),['Thuộc tính','Khóa cột','Tên hiển thị và quan hệ'],[(txt(a,'Name'),', '.join(x.text for x in a.findall('.//a:KeyColumns//a:ColumnID',ns)), 'NameColumn '+','.join(x.text for x in a.findall('./a:NameColumn//a:ColumnID',ns))+'; liên hệ '+', '.join(x.text for x in a.findall('.//a:AttributeRelationship/a:AttributeID',ns))) for a in root.findall('./a:Attributes/a:Attribute',ns)],[1.65,2,2.85])
 for hi in root.findall('./a:Hierarchies/a:Hierarchy',ns):p('Hierarchy '+txt(hi,'Name')+': '+' → '.join(txt(le,'SourceAttributeID') for le in hi.findall('./a:Levels/a:Level',ns))+'.')
 for k in ['UnknownMember','UnknownMemberName','ErrorConfiguration']: 
  e=root.find('a:'+k,ns)
  if e is not None:p(k+': '+'; '.join('='.join([E.QName(x).localname,x.text or '']) for x in e.iter() if len(x)==0))
h('3.3 Sáu cube measure group và phép đo')
p('Mỗi cube chứa một measure group theo một fact. Các measure cộng dồn phải dùng đúng đơn vị và trường nguồn. Tổng tiền khách trả của taxi khác cước cơ bản của HVFHV. Trung bình dùng tổng giá trị chia số dòng hợp lệ tương ứng, không lấy AVG các trung bình con. Tốc độ dùng tổng quãng đường chia tổng thời gian của cùng tập dòng có quãng đường không âm và thời gian dương. Mẫu số thiếu hoặc 0 trả NULL để phân biệt với kết quả bằng 0.')
for path in sorted((R/'NYCTaxi_SSAS').glob('*.cube')):
 root=E.parse(str(path)).getroot();h('Cube '+txt(root,'Name'),3)
 dimensions=root.findall('./a:Dimensions/a:Dimension',ns)
 table('Vai trò dimension cube '+txt(root,'Name'),['Vai trò','Database dimension'],[(txt(x,'Name'),txt(x,'DimensionID')) for x in dimensions],[2.5,4])
 for mg in root.findall('./a:MeasureGroups/a:MeasureGroup',ns):
  p('Measure group '+txt(mg,'Name')+'. StorageMode '+txt(mg,'StorageMode','theo partition')+'. IgnoreUnrelatedDimensions '+txt(mg,'IgnoreUnrelatedDimensions','xem cấu hình cube')+'.')
  table('Measure cube '+txt(root,'Name'),['Measure','Nguồn và tổng hợp','Định dạng và hiển thị'],[(txt(m,'Name'),','.join(x.text for x in m.findall('.//a:ColumnID',ns))+'; '+txt(m,'AggregateFunction','Sum'),txt(m,'FormatString')+'; Visible '+txt(m,'Visible','true')) for m in mg.findall('./a:Measures/a:Measure',ns)],[2,2.5,2])
  rel=[]
  for d in mg.findall('./a:Dimensions/*',ns):rel.append([txt(d,'CubeDimensionID'),txt(d,'GranularityAttributeID'),'; '.join(x.text for x in d.findall('.//a:ColumnID',ns))])
  if rel:table('Dimension Usage '+txt(root,'Name'),['Cube dimension','Grain attribute','Cột liên kết'],rel,[2,1.5,3])
  for ad in mg.findall('./a:AggregationDesigns/a:AggregationDesign',ns):
   p('Aggregation design '+txt(ad,'Name')+' lưu '+str(len(ad.findall('./a:Aggregations/a:Aggregation',ns)))+' tổ hợp tổng hợp. Đây là tối ưu vật lý trong measure group, không tạo fact nghiệp vụ mới.')
  partitions=mg.findall('./a:Partitions/a:Partition',ns)
  if partitions:table('Partition cube '+txt(root,'Name'),['Partition','Storage','Truy vấn nguồn'],[(txt(x,'Name'),txt(x,'StorageMode'),txt(x.find('a:Source',ns),'QueryDefinition')) for x in partitions],[1.45,.65,4.4])
 for script in root.findall('.//a:MdxScript',ns):
  for command in script.findall('./a:Commands/a:Command/a:Text',ns):h('Công thức MDX '+txt(root,'Name'),3);code(command.text or '')
h('3.4 Unknown lỗi khóa và phạm vi chỉ tiêu')
p('Khóa 0 của dimension là member dữ liệu thông thường, UnknownMember bổ sung dành cho khóa không phân giải. KeyNotFound, KeyDuplicate và NullKeyNotAllowed được cấu hình ReportAndStop để không bỏ fact lỗi. Nullable attribute có thể chuyển thành blank hoặc zero theo thiết kế thuộc tính; không diễn giải quy tắc đó thành tiền hoặc thời gian NULL bằng 0 ở mọi measure. IgnoreUnrelatedDimensions bằng false giúp tránh lặp số tổng trên các chiều không liên quan.')
p('Tip Percentage dùng TipAmount chia FareAmount cho taxi và TipAmount chia BasePassengerFare cho HVFHV trên cùng tập đủ dữ liệu. Không chia tip cho tổng tiền và không coi thiếu tip tiền mặt là khách không tip. Base Average Duration và Waiting dùng DurationTripCount và WaitingTripCount. Shared Request Rate của Base Performance chỉ xét dịch vụ phù hợp. Công thức WAV Match Rate có vấn đề ngữ nghĩa và đã được ẩn trong lần hardening: cờ xe thực hiện WAV và cờ yêu cầu WAV không bảo đảm tử số là tập con của mẫu số. Power BI không sử dụng chỉ số này; không ép tỷ lệ về 100 phần trăm để che sai nghĩa.')
h('3.5 Build deploy process và refresh')
p('Mở solution bằng Visual Studio có Analysis Services Projects. Hồ sơ triển khai ghi nhận lỗi Invalid license data ở bước build Visual Studio; mô hình đã được kiểm tra AMO, serialize XMLA và triển khai qua script. Không mô tả đây là một lần Build Visual Studio thành công. Invoke-Ssas.ps1 hỗ trợ Deploy lần đầu, Update mô hình, xử lý dimension và process theo XMLA. Update toàn mô hình có thể làm mất trạng thái Process; không cần thực hiện mỗi đợt ETL.')
p('Runner hiện ProcessFull toàn database bằng XMLA Batch Transaction true rồi chạy Verify-Results.ps1 Scope Full. Trước process, nó xác nhận Data Source trỏ đúng SQL server và database, đủ sáu cube theo cube-map.json. Sau process kiểm tra database Processed. Khi process lỗi, ứng dụng không được coi dữ liệu SQL mới đã xuất hiện trong cube. Power BI Refresh chỉ truy vấn lại cube, không thay thế bước process.')
p('Cấu hình có 45 partition MOLAP: FHV 13, HVFHV 13, YellowGreen 16 và ba snapshot. Transaction phân theo tháng và nguồn; Other Dates giữ Unknown hoặc tháng chưa tách. Plan-Refresh.py có khả năng sinh kế hoạch tháng mới, cập nhật catch all để tránh cộng trùng và process partition liên quan, nhưng runner hiện chưa tích hợp kế hoạch đó. Không gọi toàn bộ luồng là SSAS incremental chỉ vì có script planner.')
h('3.6 Kiểm chứng mô hình và đối soát')
p('Bằng chứng rà soát ngày 31 tháng 10 ghi nhận sáu cube, 15 dimension, sáu measure group và 45 partition đều Processed; sáu Browse MDX đạt; 102 phép so sánh SQL MDX không thất bại. Đây là bằng chứng trạng thái ở thời điểm chụp, không phải chứng minh mọi công thức đã đúng nghiệp vụ. Tài liệu Power BI còn lưu trạng thái Unprocessed ở một thời điểm reset khác trong cùng ngày; khi demo phải kiểm tra trạng thái hiện tại thay vì ghép các lần chụp thành một diễn biến không có timestamp xác nhận.')
rc=R/'evidence/reconciliation-Full.csv'
if rc.exists():
 import csv
 with rc.open(encoding='utf-8-sig',newline='') as fp: data=list(csv.reader(fp))
 if data:table('Kết quả đối soát SQL MDX lưu trong bằng chứng',data[0],data[1:])

ch(4,'Xây dựng Dashboard Power BI')
h('4.1 Mục tiêu và tổ chức bộ báo cáo')
p('Bộ dashboard được triển khai bằng sáu project PBIP kết nối live đến sáu cube. Mỗi project giữ cả thư mục Report và SemanticModel. Không chỉ sao chép tệp pbip vì định nghĩa trang, visual và model reference nằm ở các thư mục đi kèm. Các báo cáo không import DWH vào local model, không tự gộp các cube và không tự đồng bộ slicer giữa các cửa sổ. Zone Traffic là cube dùng cho các câu hỏi lưu lượng có chung các dịch vụ.')
h('4.2 Kết nối và thao tác mở báo cáo')
p('Trong Power BI Desktop chọn SQL Server Analysis Services, điền server THUONGNGUYEN\\MSSQLSV, chọn Connect live, database NYCTaxi_SSAS và đúng cube. Tài khoản Windows phải có quyền đọc cube. Cấu hình connectionType của modelReference là analysisServicesDatabaseLive; lỗi Invalid connection type từng xuất hiện với giá trị analysisServices và đã được sửa trong source. Nếu cube Unprocessed, việc AMO vẫn nhìn thấy tên cube không chứng minh Desktop đã có mô hình để truy vấn.')
p('Menu NYCTaxi Analytics.exe cung cấp sáu nút nghiệp vụ và kiểm tra nguồn chỉ đọc. Menu yêu cầu trạng thái Processed và probe truy vấn đạt trước khi coi nguồn sẵn sàng. Sau ETL thành công đến Ssas mới mở hoặc Refresh báo cáo. Tác vụ này không công bố lên Power BI Service; triển khai live SSAS trên Service cần thiết kế gateway và danh tính riêng. Không ghi rằng đã publish khi chỉ có project cục bộ.')
h('4.3 Đặc tả đầy đủ các trang và visual')
p('Các bảng dưới trích trực tiếp định nghĩa PBIR: tên trang, kích thước canvas, loại visual, vị trí, field binding, phép đo, cấu hình objects, filter và tương tác. Tên kỹ thuật được giữ để đối chiếu với source. Truy vấn SQL MDX và binding DAX kiểm tra dữ liệu không thay cho kiểm thử hiển thị và tương tác bằng Power BI Desktop.')
for project in sorted((R/'powerbi/reports').iterdir()):
 if not project.is_dir():continue
 report=next(project.glob('*.Report'),None)
 if report is None:continue
 h('Báo cáo '+project.name,3)
 ref=next(project.glob('*.SemanticModel/modelReference.json'),None)
 if ref:p('Cấu hình model reference');code(ref.read_text(encoding='utf-8-sig'))
 for pagefile in sorted(report.glob('definition/pages/*/page.json')):
  pg=json.loads(pagefile.read_text(encoding='utf-8-sig'));h('Trang '+pg.get('displayName',pagefile.parent.name),3)
  p('Canvas '+str(pg.get('width'))+' × '+str(pg.get('height'))+'. Chế độ '+str(pg.get('displayOption','mặc định'))+'.')
  extra={k:v for k,v in pg.items() if k not in ['$schema','name','displayName','width','height','displayOption']}
  if extra:p('Cấu hình trang và tương tác');code(json.dumps(extra,ensure_ascii=False,indent=2))
  for vf in sorted(pagefile.parent.glob('visuals/*/visual.json')):
   v=json.loads(vf.read_text(encoding='utf-8-sig'));vis=v.get('visual',{});name=v.get('name',vf.parent.name);typ=vis.get('visualType','visualContainer')
   p('Visual '+name+' loại '+typ+'.')
   pos=v.get('position',{});p('Vị trí '+', '.join(str(k)+'='+str(z) for k,z in pos.items())+'.')
   query=vis.get('query',{});bindings=[]
   def walk(x):
    if isinstance(x,dict):
     if 'Column' in x or 'Measure' in x:
      b=x.get('Column',x.get('Measure'));bindings.append(json.dumps(b,ensure_ascii=False))
     for a in x.values():walk(a)
    elif isinstance(x,list):
     for a in x:walk(a)
   walk(query)
   if bindings:p('Trường dữ liệu: '+'; '.join(dict.fromkeys(bindings))+'.')
   else:p('Đây là thành phần bố cục hoặc điều hướng không có field binding dữ liệu trong query.')
   settings={k:val for k,val in vis.items() if k!='query'}
   for key in ['filterConfig','visualContainerObjects','howCreated']:
    if key in v:settings[key]=v[key]
   if query:settings['query']=query
   # Keep complete object configuration compact rather than printing deeply nested JSON.
   def flatten(value,prefix=''):
    if isinstance(value,dict):
     for k,z in value.items():yield from flatten(z,prefix+'.'+k if prefix else k)
    elif isinstance(value,list):
     for i,z in enumerate(value):yield from flatten(z,prefix+'['+str(i)+']')
    else:yield prefix+' = '+str(value)
   settings.pop('visualType',None)
   settings.pop('query',None)
   lines=list(flatten(settings))
   for line in lines:
    x=p(line);x.paragraph_format.line_spacing=1.0;x.paragraph_format.space_after=Pt(0)
    for run in x.runs:run.font.size=Pt(10)
h('4.4 Quy trình khai thác nghiệp vụ từng nhóm dashboard')
for title,body in [
('Taxi truyền thống và hành vi tiền tip','Mở YellowGreen, chọn năm trước rồi tháng có dữ liệu; chọn dịch vụ để tách Yellow và Green. Theo dõi số chuyến, tiền khách trả, phân bố giờ và quận. Trang hành vi thanh toán và tip dùng payment type, quận, cuối tuần và giờ để khảo sát khác biệt trong tập được ghi nhận. Tip percentage là tỷ lệ có mẫu số cước hợp lệ, không thay cho tỷ lệ khách có tip. Khi lọc phải xem Unknown và phạm vi ngày pickup thực tế để tránh kết luận từ đầu tháng cho cả tháng.'),
('Xe công nghệ phí và thu nhập','Mở HVFHV, chọn cùng phạm vi thời gian, dịch vụ và provider khi so sánh. Thời gian chờ dùng mốc yêu cầu và các mốc phục vụ theo công thức cube; không đổi đơn vị giữa giây và phút trong diễn giải. Trang tài chính tách tiền khách trả, tiền tài xế, tip và thuế phí; chênh lệch các khoản không tự động là lợi nhuận nền tảng. Biểu đồ biến động phí và lượng chuyến chỉ mô tả quan hệ trong dữ liệu, chưa chứng minh phí gây ra thay đổi nhu cầu.'),
('FHV truyền thống','Báo cáo FHV tập trung nhu cầu theo ngày, giờ, quận, base và thời lượng. Không có measure doanh thu nên không điền 0 để tạo biểu đồ tài chính. Nhiều vị trí thiếu hoặc Unknown có thể làm biểu đồ địa lý chưa đại diện. Card tổng thời lượng dùng giây trong cấu hình đã ghi nhận, còn trung bình có thể dùng phút; đọc tên và định dạng measure trước khi đối chiếu.'),
('Tài chính theo ngày','Daily Financial phân tích ngày và dịch vụ có tài chính. Dùng tổng tiền khách trả, tip, thuế phí và tiền tài xế đúng nguồn. FHV không nằm trong phạm vi tài chính. Giá trị rỗng là thiếu hoặc không áp dụng chứ không chứng minh giao dịch không phát sinh tiền. Không cộng số chuyến của cube này vào số chuyến transaction để lập một tổng mới.'),
('Nhu cầu theo khu vực và chi tiết không gian giờ','Zone Traffic dùng cùng bộ lọc ngày, dịch vụ, địa lý để so sánh các nguồn. Lượt đón theo thời gian và vùng pickup, lượt trả theo thời gian và vùng dropoff; hai loại sự kiện có thể khác ngày và khác quận. Ma trận quận và giờ thể hiện cường độ của tập đã nạp; không coi tổng đón cộng tổng trả là tổng chuyến. Khi drill từ Borough xuống Zone phải giữ đúng vai trò địa lý.'),
('Hiệu suất điều phối','Base Performance so khối lượng, chờ, thời lượng và yêu cầu đi chung theo base, provider và dịch vụ. Trung bình phải tính lại từ tổng và mẫu số hợp lệ của cube; không lấy trung bình các ô base. Shared request và shared match là hai cờ khác nhau. WAV Match Rate không được đưa vào dashboard vì chưa có tập tử và mẫu đáp ứng ý nghĩa tỷ lệ phục vụ yêu cầu.')]:h(title,3);p(body)
h('4.5 Kiểm thử dashboard và giới hạn nghiệm thu')
p('Hồ sơ lưu sáu cấu hình live, sáu probe, 70 binding duy nhất và 101 truy vấn visual đạt. Những kiểm tra này xác nhận tên trường và khả năng truy vấn trong thời điểm đó, chưa chứng nhận toàn bộ bố cục Desktop, slicer, drill, cross filter và trạng thái sau reset. Có chín trang theo lần rà soát; danh mục trang ở phần trên phản ánh các tệp hiện có để nhận diện thay đổi sau khi người dùng lưu bằng Desktop.')
p('Quy trình nghiệm thu giao diện cần mở từng project khi cube Processed; kiểm tra tất cả trang có dữ liệu; thay năm, tháng, dịch vụ và bộ lọc đặc thù; đối chiếu card với MDX cùng bộ lọc; thử Unknown và tập rỗng; kiểm tra đơn vị và định dạng; kiểm tra drill và tương tác; lưu ảnh có ngày giờ và phạm vi dữ liệu. Đây là quy trình cần thực hiện trong Desktop, không được ghi là đã hoàn tất chỉ từ schema validation.')
h('4.6 Các điểm cần hoàn thiện và điều kiện vận hành')
p('Bản rà soát ban đầu nêu các lỗi mapping FHV, WAV, lịch và điều phối. Hồ sơ hardening về sau ghi nhận đã sửa mapping, ẩn WAV, đăng ký lịch, bổ sung Job Object và truyền lỗi có cấu trúc. Các phần chưa hoàn tất còn gồm Transform kiểm tra lịch sử, aggregate và SSAS full, guard chưa thống nhất ở đường native package, thiếu manifest code cho resume, lịch ngày lễ chưa xác nhận, chưa có SCD2 và chưa có lineage file thật trong LoadBatch. Trạng thái trước và sau thay đổi cần được đọc theo thời điểm, không dùng nhận xét cũ như kết luận cho source mới.')
p('Điều kiện bảo vệ và bàn giao là xác định rõ tập dữ liệu demo, kiểm tra cấu hình máy, chạy từ điểm vào thống nhất, giữ nguyên log và checkpoint, hoàn tất các bước ETL, process và đối soát rồi mới khai thác dashboard. Hướng phát triển gồm lịch đã được kiểm thử theo tài khoản thực, hủy và phục hồi có kiểm soát, mapping cờ đúng phiên bản, đối soát nghiệp vụ của KPI và tối ưu các bước theo phạm vi thay đổi. Các đề xuất này phải được triển khai và có bằng chứng riêng trước khi tuyên bố đã hoàn thành.')
h('TÀI LIỆU THAM KHẢO VÀ NGUỒN ĐỐI CHIẾU',1)
for x in ['Nhom04_ThietKeMucLogic_DACK.docx Mẫu bố cục diễn giải logic và hình thức bảng do người dùng cung cấp.',
'NYC TLC Trip Record Data https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page',
'NYC TLC Yellow Dictionary https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf',
'NYC TLC Green Dictionary https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_green.pdf',
'NYC TLC FHV Dictionary https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_fhv.pdf',
'NYC TLC HVFHV Dictionary https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf',
'Source dự án etl/packages và etl/python, Invoke-NYCTaxiPipeline.ps1, Invoke-SsisStage.ps1.',
'Metadata SQL evidence/columns.json, primary-keys.json, foreign-keys.json. Đây là bản chụp có thời điểm, không bao phủ tự động mọi cột được thêm về sau.',
'Mô hình NYCTaxi_SSAS/*.dim, *.cube, DSV_NYCTaxi.dsv và DS_NYCTaxi_DWH.ds.',
'Định nghĩa báo cáo powerbi/reports, modelReference.json và visual.json từng project.',
'Bằng chứng evidence/review-20261031/REVIEW.md, evidence/final-status.json, evidence/reconciliation-Full.csv, etl/incremental/README.md và powerbi/README.md.']:p(x)
h('Cập nhật cấu hình sau rà soát và lịch vận hành',2)
p('Sau bản rà soát ban đầu, hồ sơ etl/hardening/STATUS.md ghi nhận đã sửa mapping FHV và bổ sung SourceSRFlag vào hash, nâng riêng loader FHV lên FILE_FHV_V2_20261031. Các ca fixture xác nhận 1 thành Y, 0 thành N và NULL thành U. Lần DWH kế tiếp phải xử lý lại file FHV một lần; chưa có bằng chứng chạy production sau thay đổi này trong hồ sơ hardening.')
p('Controller hiện dùng Windows Job Object với KILL_ON_JOB_CLOSE để quản lý runner và hậu duệ; attach thất bại thì dừng runner và báo lỗi. Recover-Run.ps1 cung cấp xem trạng thái và chỉ đóng run RUNNING thành FAILED khi lấy được exclusive applock. Chưa có trạng thái CANCELLED hoặc ABANDONED và chưa có nút hủy trên monitor. Vì vậy phát hiện cancel của bản rà soát cũ đã được xử lý một phần, không còn mô tả đúng toàn bộ source mới.')
p('Lịch NYCTaxi Monthly ETL đã được đăng ký theo hồ sơ hardening: ngày 15 mỗi tháng lúc 10 giờ Bangkok, chế độ tháng hiện tại trừ hai, MaxRows 100000. NextRunTime tại lần tạo là 15 tháng 11 năm 2026 lúc 10 giờ. Task dùng interactive token nên người dùng phải đăng nhập, IgnoreNew để tránh chồng lượt, StartWhenAvailable và giới hạn thực thi 24 giờ. Đây là thông tin lịch đã lưu, không phải lần kiểm tra Task Scheduler hiện tại; chưa có ca chạy thử lịch thật. Script đăng ký có mặc định MaxRows 0 nên phải phân biệt mặc định script với giá trị đã truyền lúc đăng ký.')
p('Verify đã bổ sung lỗi có cấu trúc và kiểm tra InvocationId để giữ SqlNumber qua tiến trình con, có thử lỗi giả lập 1205. Hồ sơ hardening ghi 12 trên 12 unit test, 22 trên 22 ca incremental cách ly, ba ca cờ FHV, bảy ca controller, thử job cha con và heartbeat. Không diễn giải fixture thành một lượt ETL production đã chạy. WAV Match Rate đã được ẩn bằng MDX script, không đổi dữ liệu nguồn và không process trong lần hardening.')
# Complete table list in source order; captions themselves have stable chapter numbering.
for caption in captions:
 x=OxmlElement('w:p');pr=OxmlElement('w:pPr');sp=OxmlElement('w:spacing');sp.set(qn('w:after'),'40');sp.set(qn('w:line'),'240');pr.append(sp);x.append(pr)
 r=OxmlElement('w:r');rp=OxmlElement('w:rPr');sz=OxmlElement('w:sz');sz.set(qn('w:val'),'24');rp.append(sz);r.append(rp);t=OxmlElement('w:t');t.text=caption;r.append(t);x.append(r);lot._p.addprevious(x)
# Caption style powers list of tables without adding shading.
for para in D.paragraphs:
 if re.match(r'^Bảng \d+\.\d+ ',para.text):para.style=D.styles['Caption'];para.paragraph_format.keep_with_next=True
settings=D.settings.element;up=OxmlElement('w:updateFields');up.set(qn('w:val'),'true');settings.append(up)
# preserve source package styles etc by replacing only document and settings parts
out=R/'BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx'; intermediate=W/'assembled.docx';D.save(intermediate)
with zipfile.ZipFile(REF) as zin,zipfile.ZipFile(intermediate) as new,zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as zout:
 for info in zin.infolist():
  name=info.filename.replace('\\','/')
  data=new.read(name) if name in ['word/document.xml','word/settings.xml','word/styles.xml'] else zin.read(info.filename)
  zout.writestr(info,data)
contract_text=f'''# Artifact contract\nReference {REF}\nSHA256 {hashlib.sha256(REF.read_bytes()).hexdigest()}\nPage Letter 21.59 x 27.94 cm; margins all 2.54 cm; one section preserved.\nBody Times New Roman 14 pt, 1.5 lines. Source heading styles preserved and direct black 14 pt.\nSource tables black 1 pt grid, no shading. New tables repeat header; 12 pt for technical metadata and 1.15 lines to support long cells.\nSlots: replace all logistics body paragraphs and two example tables with NYC title, TOC, list of tables and four requested chapters. Extend cloned source heading/body/table patterns for all inventories.\nPreserve-only all package parts except document.xml settings.xml and styles.xml. No images or source logistics content retained in body. Section geometry unchanged.\nTables {len(captions)}; all captioned with chapter sequence and Caption style. Fields TOC and list of tables request refresh on open.\nRenderer attempted but LibreOffice not installed on PATH. Native Word rendering fallback to be checked.\n'''
(W/'artifact.md').write_text(contract_text,encoding='utf-8')
(W/'inventory.json').write_text(json.dumps({'tables':captions,'outline':outline,'paragraphs':len(D.paragraphs),'source_sha256':hashlib.sha256(REF.read_bytes()).hexdigest()},ensure_ascii=False,indent=2),encoding='utf-8')
print(out);print('paragraphs',len(D.paragraphs),'tables',len(captions))
