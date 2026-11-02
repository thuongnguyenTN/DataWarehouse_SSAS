from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from lxml import etree as E
p=Path('BaoCao_NYCTaxi_DWH_ETL_SSAS_PowerBI.docx');ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'};w='{'+ns['w']+'}'
with ZipFile(p) as z:parts=[(i,z.read(i.filename)) for i in z.infolist()];x=E.fromstring(z.read('word/document.xml'))
def text(el):return ''.join(el.itertext()) if False else ''.join(el.xpath('.//w:t/text()',namespaces=ns))
def settext(el,t):
 nodes=el.findall('.//w:t',ns)
 if nodes:
  nodes[0].text=t
  for n in nodes[1:]:n.text=''
fix={
'PaymentTypeID':'Mã phương thức hoặc tình trạng thanh toán của taxi theo từ điển nguồn; là mã phân loại, không có đơn vị tiền.',
'PaymentTypeDescription':'Tên diễn giải phương thức hoặc tình trạng thanh toán tương ứng PaymentTypeID.',
'PaymentTypeGroup':'Nhóm thanh toán phục vụ phân tích, chẳng hạn tiền mặt, thẻ hoặc nhóm khác theo seed dimension.',
'FullDate':'Ngày dương lịch đầy đủ; dùng hiển thị và sắp xếp, khác surrogate DateKey.',
'DayOfWeekNumber':'Số thứ tự ngày trong tuần theo quy ước seed Dim_Date. Không giả định thứ Hai là 1 nếu chưa đối chiếu seed.',
'DayOfWeekName':'Tên ngày trong tuần tương ứng ngày dương lịch.',
'DayOfMonth':'Ngày trong tháng, từ 1 đến 31 tùy tháng.',
'MonthNumber':'Tháng trong năm từ 1 đến 12; hierarchy cần ghép YearNumber để không gộp các năm.',
'MonthName':'Tên tháng để hiển thị; phải sắp theo MonthNumber và giữ khóa năm tháng.',
'QuarterNumber':'Quý trong năm từ 1 đến 4; khóa hierarchy ghép YearNumber và QuarterNumber.',
'YearNumber':'Năm dương lịch của ngày tương ứng.',
'IsWeekend':'Cờ ngày cuối tuần theo lịch seed; không thay thế IsHoliday.',
'MinuteOfDay':'Số phút tính từ đầu ngày; quy tắc khóa TimeKey hợp lệ 1 đến 1440, khóa 0 là Unknown.',
'HourNumber':'Giờ trong ngày từ 0 đến 23 đối với thời gian hợp lệ; Unknown cần khóa riêng.',
'MinuteNumber':'Phút trong giờ từ 0 đến 59.',
'TimeLabel':'Nhãn giờ phút dùng hiển thị thành viên Dim_Time.',
'TimeBand':'Nhóm khung giờ dùng ở cấp trên của hierarchy TimeBand, Hour và Time.',
'IsPeakHour':'Cờ giờ cao điểm theo quy tắc seed dimension; là phân loại được thiết kế, không phải kết luận đo nhu cầu toàn NYC.',
'LicenseNumber':'Số giấy phép HVFHS do TLC cấp cho nhà cung cấp; business key dùng ánh xạ nguồn HVFHV.',
'ProviderName':'Tên nhà cung cấp dịch vụ HVFHS tương ứng giấy phép.',
'BaseNumber':'Số giấy phép TLC của base, dùng làm business key tra dimension cho các vai trò base.',
'BaseName':'Tên base nếu có trong danh mục; thiếu tên không đồng nghĩa mã base không tồn tại.',
'BaseCategory':'Nhóm nghiệp vụ base theo danh mục; không phải danh tính tài xế.',
'PassengerGroupCode':'Mã nhóm số hành khách dùng để phân tích các chuyến Yellow và Green.',
'MinCount':'Cận dưới số hành khách của nhóm theo bảng seed.',
'MaxCount':'Cận trên số hành khách của nhóm theo bảng seed.',
'GroupName':'Tên hiển thị của nhóm số hành khách.',
'ServiceCode':'Mã dịch vụ dùng phân biệt Yellow, Green, FHV và FHVHV.',
'ServiceName':'Tên dịch vụ dùng hiển thị trong slicer và tiêu đề phân tích.',
'RateCodeDescription':'Mô tả biểu giá taxi tương ứng RateCodeID theo danh mục seed.',
'VendorName':'Tên nhà cung cấp công nghệ TPEP hoặc LPEP, không phải tên tài xế.',
'SourceDataset':'Mã bộ dữ liệu nguồn để đồng bộ và truy vết file; dùng kết hợp SourceKey.',
'SourceKey':'Khóa file nguồn để truy vết, chọn phạm vi hiệu chỉnh và đối chiếu checkpoint; không phải TripID.',
'DurationTripCount':'Số chuyến có thời lượng hợp lệ trong nhóm snapshot, là mẫu số tính trung bình thời lượng.',
'WaitingTripCount':'Số chuyến có thời gian chờ hợp lệ trong nhóm snapshot, là mẫu số tính trung bình thời gian chờ.'}
for tbl in x.findall('.//w:tbl',ns):
 for row in tbl.findall('w:tr',ns):
  cells=row.findall('w:tc',ns)
  if len(cells)==4 and text(cells[0]) in fix and text(cells[1]).split('(')[0] in ['int','bigint','smallint','tinyint','bit','varchar','nvarchar','date','char']:
   settext(cells[3],fix[text(cells[0])])
body=x.find('w:body',ns);items=list(body)
start=next((i for i,e in enumerate(items) if e.tag==w+'p' and text(e)=='Cập nhật cấu hình sau rà soát và lịch vận hành'),None)
if start is not None:
 end=next((i for i in range(start+1,len(items)) if items[i].tag==w+'sectPr'),len(items))
 anchor=next(e for e in items if e.tag==w+'p' and text(e)=='2.9 Đặc tả SQL đầy đủ của các tác vụ')
 settext(items[start],'2.8.1 Cập nhật hardening và lịch vận hành')
 pr=items[start].find('w:pPr',ns)
 if pr is not None:
  st=pr.find('w:pStyle',ns)
  if st is not None:st.set(w+'val','Heading3')
 for el in items[start:end]:body.remove(el);anchor.addprevious(el)
# Keep short trailing aggregation descriptions with the preceding table by a small font fit.
for para in x.findall('.//w:p',ns):
 if text(para).startswith('Aggregation design Operational của'):
  for r in para.findall('w:r',ns):
   pr=r.find('w:rPr',ns)
   if pr is None:pr=E.SubElement(r,w+'rPr')
   sz=pr.find('w:sz',ns)
   if sz is None:sz=E.SubElement(pr,w+'sz')
   sz.set(w+'val','24')
  pr=para.find('w:pPr',ns)
  if pr is not None:
   sp=pr.find('w:spacing',ns)
   if sp is None:sp=E.SubElement(pr,w+'spacing')
   sp.set(w+'line','240');sp.set(w+'after','0');sp.set(w+'before','0')
with ZipFile(p,'w',ZIP_DEFLATED) as z:
 for i,b in parts:z.writestr(i,E.tostring(x,encoding='UTF-8',xml_declaration=True,standalone=True) if i.filename=='word/document.xml' else b)
print('Semantic metadata audit corrected payment codes and clarified dimensions')
