# Load DWH incremental theo file — 31/10/2026

Đã cài vào `E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\PKG_03_Load_DWH.dtsx`. Runner vẫn đọc SQL trong package. Giữ nguyên thứ tự và tham số Master, Aggregate rebuild và SSAS ProcessFull. Không khởi chạy ETL production trong lần triển khai này.

## Cơ chế mới

- `etl.DwhSourceState` kiểm tra Extract/Transform cùng phiên bản và đủ dòng. SourceVersion chứa hash file, rule, ZoneHash, số dòng và thời điểm hoàn tất Transform.
- `etl.DwhFileLog` ghi checkpoint theo `(DatasetCode,SourceKey)`, phiên bản loader, số dòng fact, insert/update/delete, lỗi và ForceReload.
- Dimension lấy danh mục từ `#DeltaTrip` của file cần xử lý; không quét toàn lịch sử chuyến đi mỗi lần. TaxiZone SCD1 vẫn đọc danh mục nhỏ.
- Fact dựng `#Desired` cho một file. Hash chứa dịch vụ và SourceKey; ordinal của dòng trùng được đánh trong từng file, không ảnh hưởng file khác.
- Audit/delete/update/insert và checkpoint thành công nằm trong một transaction theo file. Lỗi rollback file hiện tại; các file đã commit vẫn được giữ. FAILED được chọn lại ở lần sau.
- File 0 chuyến hợp lệ vẫn xóa fact cũ tương ứng và ghi checkpoint 0.
- Index fact `(SourceDataset,SourceKey) INCLUDE(RecordHash)`; tái sử dụng index clean `(TaxiType,ETLSourceKey)`.
- Validation mỗi lần chạy kiểm tra coverage log và số dòng của file vừa nạp. Đối soát toàn kho là thao tác riêng.
- `PipelineStep.Detail` và journal có PendingFiles/DimensionInputRows, ProcessedFiles/ValidInputRows từ kết quả SQL.

## Khởi tạo lần đầu

Khi cài có **0 checkpoint DWH**. Do đổi hash sang phạm vi file, lần DWH đầu tiên cần xử lý lại các file Transform thành công để xác lập checkpoint. Lần này có thể lâu, tạo audit và thay TripKey của bản ghi cũ. Aggregate rebuild và SSAS ProcessFull phía sau sẽ phản ánh thay đổi. TripKey không phải mã chuyến kinh doanh bền vững bên ngoài kho.

Sau lần đầu, file không đổi được bỏ qua. Thêm file 1.000 dòng chỉ xử lý file đó, trừ các trường hợp remapping/invalidation dưới đây. Không tự chạy installer mỗi lần ETL.

## Dimension và invalidation

- Fingerprint ánh xạ chia thành nhóm Location, Base và mã Service/Vendor/RateCode/Payment/TripType/Provider.
- Chỉ theo dõi Unknown có khả năng sửa: mã nguồn khác NULL nhưng chưa tra được khóa. Dữ liệu nguồn NULL không bị coi là mã chờ bổ sung.
- Khi mapping một nhóm đổi, các file có Unknown cần sửa trong nhóm đó được chọn lại. Đây là phạm vi bảo thủ theo nhóm/file.
- Đổi tên vùng SCD1 không đổi LocationID → LocationKey nên không tự làm lại fact.
- Sửa seed Date/Time/junk dimensions hoặc thay logic ánh xạ cần ForceReload file liên quan hoặc nâng LoaderVersion. Sửa clean trực tiếp ngoài Transform phải cập nhật checkpoint/yêu cầu ForceReload; không kỳ vọng DWH tự phát hiện mọi thay đổi ngoài luồng.
- Transform hiện vẫn có thể làm lại nhiều file khi rule hoặc ZoneHash đổi. Khi đó SourceVersion đổi và DWH sẽ xử lý những file đó; đây không phải cam kết mọi bước chỉ xử lý tháng hiện tại.

## Vận hành

Nếu Visual Studio đang mở package, Reload bản trên đĩa khi được hỏi; tránh Save bản SQL cũ đè lên bản mới. Chạy Master như trước, không Execute thêm PKG_03 đồng thời. Sau khởi tạo, rerun dữ liệu không đổi cần thấy ProcessedFiles=0 ở các task fact.

```sql
USE NYCTaxi_DWH;
SELECT DatasetCode,SourceKey,Status,ValidRows,FactRows,
       InsertedRows,UpdatedRows,DeletedRows,UnknownMask,ForceReload,
       CompletedAt,ErrorMessage
FROM etl.DwhFileLog ORDER BY CompletedAt DESC;

-- Chỉ khi không có ETL chạy; thay đúng file cần nạp lại.
UPDATE etl.DwhFileLog SET ForceReload=1
WHERE DatasetCode='fhv' AND SourceKey=N'fhv_tripdata_2021-03.csv';
```

ForceReload chỉ đánh dấu cho lần DWH kế tiếp, không chạy ETL. Không sửa Status=SUCCEEDED bằng tay để bỏ lỗi.

Đối soát toàn kho khi không có ETL chạy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\NYCTaxi\NYCTaxi_SSAS\etl\Test-DwhFullReconciliation.ps1
```

Nếu sửa/xóa fact trực tiếp, checkpoint có thể không còn đúng. Full audit giúp phát hiện; sau đó ForceReload file liên quan. Không chạy audit toàn kho cho mọi đợt nạp nhỏ.

## Bằng chứng

- `etl/incremental-tests.json`: 22 ca SQL trong hai database cách ly; gồm loại lookup khỏi checkpoint fact, file mới 1.000 dòng, no-op, duplicates trong/giữa file, correction/rejection, zero-valid, rollback/retry, Unknown mapping, SCD1, ForceReload và chuyển hash cũ.
- `etl/incremental-full-reconciliation.json`: trước cài kiểm tra 56 nguồn, 0 sai lệch số dòng clean–fact.
- `etl/incremental-install.json`: hash package, backup, FactLoadExecuted=false.
- 4 kiểm thử metadata/generator đạt. Bổ sung LoggingOptions bị thiếu trong OnError Master, giữ nguyên tham số/đường nối.
- Database fixture `NYCTaxi_*_IncTest_*` được giữ lại để đối chiếu, không tham gia ETL production.

Fixture không phải benchmark production. Chưa chạy end-to-end production bằng bản incremental; người vận hành chạy lần đầu có kiểm soát rồi rerun để xác nhận no-op.

### Sửa lỗi lookup checkpoint 31/10/2026

Run `cb0bf9d0-0dde-4540-b9ae-7bd4a265936e` đã nạp xong 48 file chuyến đi nhưng validation yêu cầu nhầm checkpoint Fact cho `lookup/taxi_zone_lookup.csv`. Đã lọc DwhSourceState chỉ còn yellow/green/fhv/fhvhv, sửa schema cài đặt, package đang dùng và nhánh cập nhật của generator. Không tạo checkpoint giả cho lookup. Kiểm tra chỉ đọc sau sửa đạt; 478.227 dòng fact được giữ nguyên. Run FAILED vẫn giữ làm lịch sử, không tự đánh dấu thành công. Bằng chứng: `etl/lookup-checkpoint-fix.json`.

## Khôi phục

Đường dẫn backup trong incremental-install.json. Khi không có run hoạt động, có thể phục hồi package cũ; bảng log/index mới có thể giữ nguyên. Sau khi đã dùng hash mới, quay về loader cũ cần đồng bộ lại lịch sử và rebuild aggregate/process cube. Không trộn hai phiên bản trong một run.
