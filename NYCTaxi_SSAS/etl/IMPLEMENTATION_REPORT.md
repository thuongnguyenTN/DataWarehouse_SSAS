# Kết quả triển khai ETL — 29/10/2026

## Kết quả thực tế

Luồng Extract → Transform → DWH → Aggregates → SSAS đã chạy thành công bằng runner, theo từng stage với cùng RunId `365050fc-8e8f-4f07-839c-ed36b5278ee9`. Trạng thái cuối trong SQL: **SUCCEEDED**. Khoảng chạy chính 10:14–10:32 ngày 29/10/2026 (Asia/Bangkok), có chạy lại và kiểm thử lỗi trong quá trình xác minh.

Đợt Extract kiểm thử dùng tháng **2025-01**, `MaxRows=100000` cho mỗi file, giữ các tháng lịch sử đã có. Không khẳng định đã tải toàn bộ dòng của toàn năm. Transform/DWH đối soát toàn bộ clean history hiện có; Aggregates và SSAS xử lý toàn bộ DWH.

| Fact | Số dòng | Thiếu SourceKey |
|---|---:|---:|
| FHV | 1.199.560 | 0 |
| HVFHV | 1.200.000 | 0 |
| Yellow/Green | 1.772.699 | 0 |
| Tổng | 4.172.259 | 0 |

- Đối soát chính xác số dòng clean.ValidTrip ↔ fact: đạt.
- 102 phép đối soát SQL–MDX: **0 sai lệch**.
- SSAS: database Processed, 15 dimension và 45 partition của 6 cube đã process.
- 6 truy vấn Browse MDX: đạt.
- Clean giữ 19.116 dòng bị loại; không đưa các dòng đó vào fact.

## Đã bổ sung

1. Master có năm stage nối bằng nhánh Success. Runner kiểm tra bước trước, mã thoát khác 0 dừng luồng.
2. RunId và log bền vững: etl.PipelineRun, etl.PipelineStep; OnError trong năm package ghi etl.PackageError. Có journal và stdout/stderr cục bộ nếu SQL lỗi.
3. sp_getapplock và trạng thái run dang dở để ngăn chạy chồng. Khi chạy lại bước trước, trạng thái hoàn tất cũ của các bước sau bị vô hiệu hóa.
4. Quarantine nguyên CSV lỗi cùng metadata và thông báo lỗi trước khi công bố staging. Dữ liệu sai nghiệp vụ vẫn được giữ qua clean.RejectedTrip/WarningTrip.
5. SourceDataset/SourceKey trên fact. Sửa/xóa dữ liệu lịch sử được đối soát từ clean hiện tại, lưu JSON của fact bị thay thế trong etl.FactChangeAudit. Dòng legacy không gắn được nguồn làm luồng dừng thay vì bị xóa tự động.
6. Cả ba snapshot được rebuild và kiểm tra trong một transaction; watermark cùng commit/rollback. Cách này ưu tiên tính đúng khi lịch sử thay đổi, có chi phí cao hơn incremental thuần.
7. ProcessFull SSAS bằng XMLA transaction và đối soát SQL–MDX trước khi ghi run SUCCEEDED.
8. Đồng bộ profile Python/inspect qua extract_contract.py; cập nhật metadata .dtproj và hash manifest các tệp đã triển khai.
9. Script đăng ký Windows Task Scheduler theo giờ người vận hành chọn; chưa tạo lịch hoặc gửi email/tin nhắn tự động.

## Kiểm thử đã chạy

| Kiểm thử | Kết quả/bằng chứng |
|---|---|
| 6 kiểm thử converter/inspector: CSV quoted/multiline, cột optional, giới hạn dòng, hash sai, schema lạ, tái sử dụng file | Đạt, tests/test_file_contract.py |
| Nạp CSV có dấu phẩy, dấu nháy, xuống dòng và NULL bằng đường SqlBulkCopy thực tế | Đạt, bulk-tests.json |
| Chặn chạy sai thứ tự; chặn run đồng thời | Đạt, control-tests.json |
| Metadata sai dừng trước khi thay đổi staging, có đủ file quarantine | Đạt, quarantine-test.json; staging Yellow giữ 1.200.000 dòng |
| Chạy lại bước trước làm vô hiệu hóa các bước sau, không bỏ qua Transform bằng marker cũ | Đạt, resume-test.json |
| Sửa một dòng FHV và loại một dòng lịch sử bằng SQL fact production; sau đó rollback fixture | Đạt, history-test.json; count/sum thời gian FHV trước và sau test giống nhau |
| Gây lỗi SQL trước commit của aggregate | Đạt, rollback-test.json; checksum/count ba snapshot và watermark giữ nguyên |
| Chạy lại sau lỗi và hoàn tất SSAS | Đạt, verification-run.json và verification-steps.json |
| Đối soát SQL–MDX toàn kho và Browse | Đạt, ../evidence/reconciliation-Full.csv và ../evidence/browse-checks.csv |

Các bản ghi FAILED của kiểm thử âm và các lần chạy lại được giữ để truy vết; không xóa lịch sử lỗi. Đọc RunId chính và trạng thái cuối, không suy ra kết quả từ việc có bất kỳ dòng FAILED cũ nào.

## Sao lưu và triển khai

Source trước thay đổi: `backups/20261029-100420/packages` và `backups/20261029-100420/python` trong thư mục etl.

COPY_ONLY backup có COMPRESSION/CHECKSUM của hai database:

- `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSV\MSSQL\Backup\NYCTaxi_DWH_before_pipeline_20261029-100420.bak`
- `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSV\MSSQL\Backup\NYCTaxi_Staging_before_pipeline_20261029-100420.bak`

Các package đã cập nhật trực tiếp trong `E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL`. Python đã cập nhật trong `D:\Kho_Du_lieu\NYCTaxi\script`. Hash các tệp triển khai được xác nhận trong deployed-manifest.json.

## Giới hạn kiểm thử và vận hành

- Download được gọi trong lần chạy; cache hợp lệ được tái sử dụng. Chưa gây lỗi mạng chủ đích và chưa kiểm thử tải mới toàn bộ kho từ Internet.
- Runtime SSIS độc lập không khởi tạo được trên máy qua ManagedDTS, dù có SSDT. Chưa thực thi Master/OnError bằng SSIS Designer hay DTExec. XML, liên kết stage và metadata project đã kiểm tra; luồng thật đã chạy bằng runner không phụ thuộc runtime này. Không coi kiểm thử runner là bằng chứng đã kiểm thử giao diện/runtime SSIS.
- Chưa bật lịch vì chưa có yêu cầu giờ chạy/tài khoản chạy nền. Script mặc định dùng tài khoản tương tác, phải đang đăng nhập; lịch không tương tác cần tài khoản dịch vụ được cấu hình riêng.
- Cảnh báo hiện là exit code, log SQL và file alerts. Chưa kết nối email/Teams/Slack vì chưa có kênh nhận được chỉ định.
- Rebuild toàn snapshot và ProcessFull SSAS phù hợp quy mô đã kiểm thử; cần tối ưu theo partition khi mở rộng. Luồng không có transaction phân tán xuyên tải file, SQL và SSAS; phục hồi dựa trên từng ranh giới commit và chạy lại idempotent.

Hướng dẫn lệnh chạy, chạy lại và refresh nguồn: README.md trong cùng thư mục.
## Sửa lỗi tải Master trong Designer — 29/10/2026

Sau phản hồi lỗi CPackage::LoadFromXML (0xC0010014), đã bổ sung các metadata còn thiếu theo DTSX2 của Microsoft: CreationName cho bốn PackageParameter và bốn PrecedenceConstraint của PKG_00; LoggingOptions cho OnError ở cả năm package. Đã sửa Prepare-Packages.py để không tái sinh lỗi này.

- Nguồn tham chiếu: https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx2/066e404d-ddcb-438b-9588-ff67184234c8
- Kiểm tra required metadata và graph: Validate-PackageMetadata.py, đạt cả năm package.
- Ba regression test trong tests/test_package_metadata.py: đạt, gồm nhận diện bản cũ thiếu metadata và tạo mới trong thư mục thử độc lập.
- Đã đối chiếu SQL, expression và ExecuteProcessData trước/sau: không thay đổi. Không chạy lại ETL hay sửa dữ liệu để xử lý lỗi Designer.
- Backup trước sửa: backups/package-load-fix-20261029-105537.
- Chưa xác nhận lại bằng Designer: phiên Visual Studio đang giữ hộp lỗi của lần tải cũ, thao tác UI tự động không đóng được hộp thoại. Cần đóng/mở lại solution để đọc bản sửa. Kiểm tra metadata không thay thế kiểm thử runtime.

### Sửa tiếp ParameterValue và xác nhận Designer

Thông báo lỗi chi tiết mới chỉ ra ParameterValue thiếu thuộc tính DTS:DataType ở cả bốn default value của Master. Đã bổ sung kiểu 8 cho ba chuỗi và kiểu 3 cho pMaxRows, đồng thời sửa generator và validator. Backup trước sửa: backups/package-load-fix-20261029-110517.

Đã quan sát trực tiếp Designer tải Control Flow với đủ 5 task và 4 precedence constraint. Sau thao tác Build Solution, SSDT tạo mới bin/Development/NYCTaxi_ETL.ispac lúc 11:07:21 ngày 29/10/2026. Đã kiểm tra ZIP và Master trong artifact có 5 task, 4 default value có type đúng; kết quả trong master-designer-build-check.json. Bốn regression test đều đạt. Không chạy lại ETL để sửa lỗi tải package.
