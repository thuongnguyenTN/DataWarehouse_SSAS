# Đánh giá đồ án NYC Taxi theo Rubric

Ngày rà soát: 20/10/2026. Đây là điểm ước tính từ sản phẩm đã kiểm tra, không phải điểm giảng viên. Đã dừng thao tác dashboard; không sửa workbook Rubric, báo cáo Word, SSIS, SSAS hoặc dữ liệu DWH trong lần rà soát này.

## Kết luận về điểm

Ước tính khoảng **7,0/10** nếu phần làm việc nhóm đạt 6/10 và bảo vệ đạt 7,5/10. Hai điểm này là giả định minh họa, chưa phải kết quả quan sát.

| Tiêu chí gốc | Trọng số | Điểm ước tính /10 | Điểm quy đổi /10 | Căn cứ và phần còn thiếu |
|---|---:|---:|---:|---|
| Hình thức báo cáo | 10% | 4,0 | 0,40 | Nhom01.docx có phân tích nguồn và thiết kế, nhưng chưa là báo cáo hoàn chỉnh về triển khai, kiểm thử, kết quả và kết luận; mô tả có chỗ khác schema thực tế. Chưa đánh giá typography/layout qua bản render. |
| Kỹ năng làm việc nhóm | 10% | Chưa chấm | Chưa xác định | Chưa tìm thấy bảng thành viên–nhiệm vụ, tiến độ, kết quả và tự đánh giá trong các tài liệu đã khảo sát. Không đồng nhất thiếu bằng chứng với nhóm không làm việc. |
| Thiết kế kho dữ liệu | 30% | 7,5 | 2,25 | Mô hình constellation gồm các star dùng chung dimension, transaction/snapshot, FK, hierarchy và Unknown đã có. SCD Type 1 Dim_Location có code. Báo cáo cam kết SCD2 Dim_Base nhưng chưa triển khai; một số grain/tên dimension/mapping chưa đồng bộ. |
| Công cụ tích hợp dữ liệu | 20% | 8,0 | 1,60 | Có SSIS Extract/Transform/Load/Aggregate, staging, Data Flow, hash/log/watermark, transaction và chống nạp trùng. Master chỉ gọi Transform và Load; chưa có chứng minh đầy đủ xử lý correction/deletion, rerun và phục hồi end-to-end. |
| Trả lời phân tích bằng SQL/MDX | 15% | 7,0 | 1,05 | Có 102 đối soát SQL–MDX đạt và 5 Browse query. Phần lớn là kiểm tra tổng, chưa thấy bộ câu hỏi kinh doanh với kết quả, insight, khuyến nghị và phạm vi dữ liệu rõ ràng. |
| Trả lời về DW và giải pháp thiết kế | 15% | Chưa chấm | Chưa xác định | Cần xem bạn giải thích/bảo vệ trực tiếp; chạy được hệ thống chưa chứng minh được kỹ năng trả lời. |

Phần có căn cứ hiện tại: **5,30 điểm trên 7,50 điểm trọng số có thể đánh giá**. Đây không phải tổng điểm đồ án 5,30/10. Phần kỹ thuật riêng là 4,90/6,50, tương đương khoảng 7,54/10 khi chuẩn hóa nội bộ.

Công thức tổng dự kiến: **5,30 + 0,10 × điểm nhóm + 0,15 × điểm bảo vệ**.

Ví dụ nhóm 6 và bảo vệ 7,5: 5,30 + 0,60 + 1,125 = **7,025**, làm tròn **7,0/10**. Nếu hai mục chưa đánh giá đều đạt 8 thì tổng 7,30. Muốn vượt 8 ổn định cần cải thiện cả các mục đã chấm, đặc biệt báo cáo, thiết kế thống nhất và phân tích nghiệp vụ.

Rubric tại Sheet2!B4:H9 chia các mức A=9–10, B=7–8, C=5–6, D=0–4. Bản Rubric không có mục điểm Power BI/dashboard riêng. Dashboard hỗ trợ demo và insight, không thay thế báo cáo, kỹ năng nhóm hoặc bảo vệ.

## Bằng chứng đã kiểm tra

- Rubric: `C:\Users\ADMIN\Downloads\Rubric_DWH.xlsx`, Sheet2, B4:H9; trọng số D4:D9 là 10,10,30,20,15,15, tổng 100%.
- Báo cáo tìm được qua thư mục mà SSIS tham chiếu: `D:\Kho_Du_lieu\NYCTaxi\Nhom01.docx`, 395 paragraph, 17 table. Có phần nguồn dữ liệu, thiết kế dimension/fact, hierarchy, grain; kết thúc tại tiêu đề Ma trận nghiệp vụ. Không thấy phần phân công nhóm hoặc chương triển khai/kiểm thử hoàn chỉnh trong nội dung đã trích xuất.
- Đọc cấu trúc và SQL của cả 5 package `E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_00_Master.dtsx` đến `PKG_04_Load_Aggregates.dtsx`.
- Schema SQL đã chụp trong `evidence/columns.json`, `primary-keys.json`, `foreign-keys.json`; audit 51 FK không orphan và dòng Unknown trong 15 dimension.
- SSAS theo `evidence/final-status.json`: database/cube Processed, 15 dimension, 6 measure group, 45 partition. Kết quả 102/102 trong `evidence/reconciliation-Full.csv`, 5 Browse query trong `evidence/browse-checks.csv`.
- Trạng thái Power BI được quan sát trước khi dừng: kết nối live có dữ liệu, dải 4 KPI và một biểu đồ đang dựng; chưa hoàn chỉnh, chưa xác nhận có PBIX được lưu. Không thao tác tiếp Power BI trong lần audit này.
- Metadata CSV tháng 01/2025 trong `D:\Kho_Du_lieu\NYCTaxi\csv`: row_limit=100000; FHV/HVFHV/Yellow có 100000 dòng xuất, Green 48326. FHV nguồn có 1898108 dòng nhưng chỉ xuất 100000. Script lấy phần đầu tới giới hạn, không có cơ sở gọi đây là mẫu đại diện ngẫu nhiên.

Không chạy lại ETL hoặc tạo tình huống thay đổi nguồn trong lần audit này. Điểm ETL dựa trên đọc code, cấu trúc và bằng chứng dữ liệu hiện có, không phải chứng nhận toàn bộ phiên bản package mới đã chạy end-to-end thành công.

## Những chỗ báo cáo cần sửa trước khi nộp

### 1. SCD Type 2 Dim_Base chưa khớp sản phẩm

Mục 1.4 của Nhom01.docx mô tả Dim_BaseStation dùng SCD2 và bảng có EffectiveDate, ExpirationDate, IsCurrent. Schema thực tế của Dim_Base chỉ có BaseKey, BaseNumber, BaseName, BaseCategory. Task EST_01_Load_Dimensions hiện thêm BaseNumber mới, chưa có đóng phiên bản cũ/tạo phiên bản mới hoặc lookup theo hiệu lực thời gian.

Rubric không bắt buộc phải có mọi loại SCD hay bắt buộc Type 2. Có thể chọn một trong hai hướng có căn cứ: triển khai SCD2 nếu thực sự có dữ liệu thay đổi cần lưu lịch sử; hoặc sửa báo cáo, giới hạn phạm vi và giải thích vì sao chưa dùng SCD2. Không tuyên bố đã triển khai SCD2 khi chưa có code và ca kiểm thử. Dim_Location hiện đã có INSERT mới + UPDATE thay đổi, là bằng chứng SCD Type 1.

Vendor/RateCode/PaymentType/TripType trong báo cáo cũng mô tả Type 1; code hiện chủ yếu thêm mã mới. Cần phân biệt nạp bổ sung danh mục với phát hiện và cập nhật thuộc tính của mã đã tồn tại.

### 2. Phân loại Fact_FHV_Trips

Báo cáo gọi bảng này là Factless Fact, nhưng triển khai thực tế có TripCount và TripDurationSeconds. Nên mô tả là transaction fact ít measure, grain một chuyến FHV, thay vì định nghĩa là không có độ đo. Không đánh đồng thiếu doanh thu với factless.

### 3. Data dictionary và dimension usage chưa đồng bộ

Báo cáo dùng Dim_BaseStation, Dim_TripFlags chung, và Vendor cho HVFHV. Triển khai hiện dùng Dim_Base; ba junk dimension riêng Taxi/FHV/HVFHV; HVFHSProvider cho HVFHV; có thêm Dim_LoadBatch. Các ví dụ TimeKey 1830/1900 trong báo cáo không phù hợp quy ước thực tế 1..1440 theo phút, key 0 Unknown. Không diễn giải TimeKey là HHMM.

Cần xuất lại data dictionary theo schema thật, nêu rõ các role Pickup/Dropoff/Request/OnScene, và vẽ Galaxy/Bus Matrix đã triển khai. Mô hình Galaxy không tự động sai Rubric Star/Snowflake: giải thích đây là nhiều star dùng chung conformed dimensions.

### 4. Grain snapshot phải ghi đầy đủ khóa

- Daily Financial: DateKey × ServiceTypeKey.
- Zone Traffic: DateKey × TimeKey × LocationKey × ServiceTypeKey. Bản hiện tại ở mức phút theo Dim_Time, không mặc định là theo giờ.
- Base Performance: DateKey × DispatchBaseKey × ServiceTypeKey × HVFHSProviderKey.

Các diễn đạt chỉ gồm ngày/tổng đài hoặc zone/khung giờ bỏ sót chiều tham gia khóa, dễ gây giải thích sai số dòng hoặc cộng trùng.

### 5. Phạm vi dữ liệu và KPI phải có giới hạn rõ

Đang dùng dữ liệu bị giới hạn số dòng mỗi tệp. Không kết luận tỷ trọng toàn thị trường từ YELLOW/GREEN/FHV/FHVHV khi mỗi nguồn bị giới hạn khác nhau. Số liệu mô tả được là kết quả trên tập đã nạp. Nếu muốn insight đại diện, cần nạp đầy đủ phạm vi phù hợp hoặc thiết kế lấy mẫu có cơ sở và nêu giới hạn.

FHV PickupLocation Unknown khoảng 82,58% ảnh hưởng phân tích khu vực. Chỉ tiêu WAV Match Rate hiện matches/requests khoảng 7346,92% vì bộ đếm nguồn không thể mặc nhiên xem là cùng tập yêu cầu được đáp ứng. Không dùng tỷ lệ này làm KPI đáp ứng trước khi xác nhận lại định nghĩa; không clamp để che vấn đề.

## Điểm cần chứng minh ở ETL

1. **Master chưa bao trùm pipeline:** PKG_00_Master hiện chỉ gọi PKG_02_Transform_Clean và PKG_03_Load_DWH; chưa gọi Extract, Aggregates hay Process SSAS. Các package riêng vẫn tồn tại, nên đây là thiếu orchestration end-to-end, không phải thiếu toàn bộ Extract/Load.
2. **Idempotency khác correction:** RecordHash + NOT EXISTS giúp tránh chèn lại payload đã có. Khi một tệp nguồn thay đổi, payload mới có hash mới; chưa thấy cơ chế sửa/xóa fact cũ tương ứng và bù trừ aggregate. Cần kiểm thử hoặc công bố rõ pipeline hiện chỉ hỗ trợ append.
3. **Watermark aggregate theo TripKey:** hợp lý cho append, nhưng không tự xử lý fact đã cập nhật/xóa ở TripKey cũ. Cần có rebuild có kiểm soát hoặc cơ chế delta phù hợp nếu mở rộng phạm vi.
4. **Chứng cứ demo nên có:** lần nạp đầu; rerun không thêm dòng; thêm một tháng; đổi thuộc tính Location để chứng minh Type 1; nguồn bị lỗi rồi chạy lại; correction nếu tuyên bố hỗ trợ. Mỗi ca ghi trước/sau, số dòng, trạng thái log và kết quả aggregate.
5. **Tính di chuyển:** Python/script/raw/csv đang trỏ cố định D:\Kho_Du_lieu\NYCTaxi còn project ở E:\NYCTaxi. Đóng gói script và tham số hóa root path/connection để máy chấm có thể tái lập.
6. **Lineage:** Dim_LoadBatch đang suy từ TaxiType và tháng pickup, SourceFileName NULL; chính code ghi không phải actual file lineage. Phân biệt processing group này với log Extract/Transform có source key/hash.

Không trừ điểm chỉ vì không dùng component Lookup: SQL JOIN/set-based transformation trong SSIS vẫn có thể hợp lý. Tương tự, phát hiện thay đổi bằng hash/log là một cơ chế change detection; không tự yêu cầu bật tính năng SQL Server CDC nếu bài toán không cần.

## Thứ tự hoàn thiện có lợi nhất cho điểm

1. **Đồng bộ báo cáo:** sửa SCD, loại fact, tên bảng, TimeKey, grain và data dictionary; bổ sung sơ đồ kiến trúc, Galaxy/Bus Matrix đúng bản triển khai.
2. **Hoàn thiện báo cáo nộp:** theo cấu trúc chính thức của môn nếu có; thêm phạm vi, bài toán/câu hỏi, triển khai SSIS/SSAS, kiểm thử, kết quả, giới hạn và kết luận. Ảnh chụp/log minh họa phải là kết quả thật.
3. **Bổ sung minh chứng nhóm:** thành viên–nhiệm vụ–sản phẩm–thời hạn–trạng thái; bằng chứng tiến độ và tự đánh giá. Không bịa lịch sử hoặc phần trăm đóng góp.
4. **Viết 5–8 câu hỏi SQL/MDX có insight:** câu hỏi, bộ lọc/thời gian, định nghĩa metric, SQL, MDX, kết quả, giải thích, giới hạn và đề xuất. Tập trung xu hướng trong tập mẫu, giờ cao điểm, khu vực có dữ liệu hợp lệ, tiền khách trả/tài xế và thời gian chờ; tránh suy diễn thị phần.
5. **Chứng minh incremental end-to-end:** nối Master theo phạm vi đã công bố và chuẩn bị các ca trước/sau. Chưa cần thêm chức năng mới ngoài phạm vi chỉ để tăng số lượng thành phần.
6. **Luyện bảo vệ 15%:** giải thích grain, transaction vs snapshot, conformed/role-playing dimensions, SCD chọn đúng ngữ cảnh, hash vs CDC vs watermark, Unknown vs dữ liệu lỗi, weighted average, và vì sao tổng snapshot không cộng vào tổng transaction.
7. **Hoàn thiện Power BI sau:** lưu PBIX, bố trí 4 KPI cùng 2–3 biểu đồ có slicer, đơn vị và phạm vi rõ. Dashboard minh họa được câu hỏi nghiệp vụ là hữu ích hơn thêm nhiều biểu đồ không có kết luận.

Các ưu tiên trên có thể giúp hướng tới 8–8,5 nếu được thực hiện, kiểm chứng và bảo vệ tốt. Đây là mục tiêu có điều kiện, không phải điểm bảo đảm.
