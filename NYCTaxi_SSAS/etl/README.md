# Vận hành ETL NYC Taxi

**Cập nhật 31/10/2026:** Dimension/Fact đã chuyển sang checkpoint theo file. Xem [hướng dẫn incremental](incremental/README.md) về khởi tạo lần đầu, phạm vi xử lý, ForceReload và đối soát toàn kho. Mô tả đồng bộ fact toàn phạm vi bên dưới là thiết kế trước cập nhật; Aggregate và SSAS vẫn full.

Điểm chạy chính: `Invoke-NYCTaxiPipeline.ps1`. Master SSIS có năm khối Extract → Transform → Dwh → Aggregates → Ssas và gọi bộ chạy này với cùng ExecutionInstanceGUID.

Bộ chạy dùng Python hiện có để download/convert/inspect; dùng SqlBulkCopy để nạp CSV vào wrk; thực thi SQL nhúng trong các PKG_01–04. Không cần DTExec. Nguồn SQL nghiệp vụ vẫn ở package .dtsx. Khi sửa các SQL đó, bộ chạy nhận thay đổi ở lần chạy tiếp theo.

## Chạy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\NYCTaxi\NYCTaxi_SSAS\etl\Invoke-NYCTaxiPipeline.ps1 -Stage Preflight
powershell -NoProfile -ExecutionPolicy Bypass -File E:\NYCTaxi\NYCTaxi_SSAS\etl\Invoke-NYCTaxiPipeline.ps1 -StartMonth 2025-01 -EndMonth 2025-12 -MaxRows 100000
```

`MaxRows=100000` là 100.000 dòng đầu MỖI file, không phải toàn nguồn hoặc lấy mẫu ngẫu nhiên. `MaxRows=0` nạp toàn file và có thể thay thế phạm vi file đã lấy mẫu trước đó. `-RefreshSource` tải lại file dù đã có cache, dùng khi cần nhận bản hiệu chỉnh từ nguồn; không tự coi việc nguồn ngừng cung cấp file là yêu cầu xóa lịch sử. `-Offline` bỏ download, vẫn convert và xác minh đầy đủ các file raw có sẵn; thiếu file sẽ fail.

Python, thư mục dữ liệu, SQL/SSAS server và PackageRoot có tham số ở runner. Master dùng mặc định đã cấu hình trên máy; các tham số tháng và số dòng hiển thị trong package. Không tự tăng quyền service account hay tự sửa cấu hình máy.

## Khi lỗi và chạy lại

- Exit code khác 0; bước sau không chạy.
- Nếu inspect/nạp/commit một CSV thất bại, bản CSV và metadata được sao chép vào `DataRoot/quarantine/<RunId>/<dataset>` cùng lỗi gốc. File được xử lý nguyên khối: CSV sai cấu trúc dừng file, không nạp tiếp các dòng còn lại. Dữ liệu sai nghiệp vụ vẫn nằm trong clean.RejectedTrip/WarningTrip. Data Flow standalone giữ FailComponent; luồng Master dùng runner để quarantine theo file.
- SQL `NYCTaxi_DWH.etl.PipelineRun` ghi lần chạy; `etl.PipelineStep` ghi từng task/file và lỗi gốc.
- `etl.PackageError` nhận lỗi gốc từ OnError khi chạy package bằng SSIS; khi chạy qua runner, PipelineStep và journal là nguồn log chính.
- `etl/logs/<RunId>/events.jsonl` và stdout/stderr Python lưu tại máy, kể cả khi SQL không kết nối được.
- `etl/alerts/<RunId>.json` được tạo khi thất bại để công cụ giám sát đọc. Không tự gửi email/tin nhắn.
- Khóa `sp_getapplock` ngăn hai runner thay đổi dữ liệu cùng lúc. Trạng thái RUNNING còn dang dở cũng chặn RunId khác; sau khi xác minh tiến trình cũ đã dừng, dùng lại cùng RunId.

```powershell
# Chạy lại đầy đủ bằng cùng RunId và cùng cấu hình. Các bước idempotent tự kiểm tra lại đầu vào.
powershell -NoProfile -ExecutionPolicy Bypass -File E:\NYCTaxi\NYCTaxi_SSAS\etl\Invoke-NYCTaxiPipeline.ps1 -StartMonth 2025-01 -EndMonth 2025-01 -MaxRows 100000 -RunId <GUID-trong-log>
```

Có thể gọi `-Stage Aggregates` rồi `-Stage Ssas` bằng RunId cũ khi Dwh đã hoàn tất và chưa có thay đổi đầu vào. Runner kiểm tra bước trước đã hoàn tất. Không đổi tháng, RowLimit hoặc các đường dẫn/server giữa cùng một RunId.

## Dữ liệu lịch sử thay đổi

Fact có SourceDataset/SourceKey. SQL materialize bộ fact mong đợi từ clean.ValidTrip, cập nhật khóa dimension, ghi bản JSON audit trước khi xóa các fact cũ không còn trong nguồn đã hoàn tất, rồi insert fact mới. RecordHash vẫn bảo toàn số lần xuất hiện của bản ghi giống nhau. Dòng legacy chưa gắn được nguồn sẽ làm luồng dừng; không tự xóa.

Trước triển khai lần đầu phải chạy Install-Pipeline.ps1 khi staging/clean cũ còn khớp fact. Installer sao lưu source và COPY_ONLY backup hai database, sau đó gắn nguồn cho fact. Không chạy installer lại cho mỗi ETL.

Aggregate được rebuild toàn bộ trong MỘT transaction, bao gồm validation. Đây là lựa chọn bảo đảm sửa/xóa lịch sử được phản ánh đúng; tốn tài nguyên hơn incremental thuần. Watermark và ba snapshot cùng rollback nếu lỗi. Khi dữ liệu lớn cần tối ưu rebuild theo phân vùng bị ảnh hưởng, vẫn giữ cơ chế đối soát.

## SSAS

Runner yêu cầu database NYCTaxi_SSAS đã chứa đúng sáu cube trong scripts/cube-map.json. ProcessFull toàn database bằng XMLA transaction; sau đó chạy Verify-Results.ps1 -Scope Full để đối soát SQL–MDX. Khi tháng mới xuất hiện, partition catch-all hiện có vẫn giữ dữ liệu; có thể dùng planner để tối ưu partition theo tháng sau đó.

## Lịch chạy và giám sát

Đã có script Register-PipelineTask.ps1 để tạo Windows Task Scheduler theo giờ do người vận hành chỉ định; không tự chọn lịch chạy. Tài khoản chạy phải có quyền SQL, SSAS, ghi file dữ liệu và truy cập Internet. Người vận hành cấu hình cảnh báo cho exit code khác 0 hoặc file alerts; không lưu password trong source.

## Khôi phục

Source cũ ở etl/backups/<timestamp>. Đường dẫn .bak của SQL nằm trong database-backups.txt cùng thư mục. Fact đã bị thay thế còn có JSON trong etl.FactChangeAudit. Khôi phục database từ .bak là thao tác riêng, cần chọn đúng phạm vi vì sẽ thay thế dữ liệu phát sinh sau backup.

Một run không phải transaction xuyên Python + SQL + SSAS. Mỗi file/task có ranh giới commit riêng; aggregate và SSAS có transaction riêng. Nếu SSAS thất bại, SQL vẫn giữ trạng thái đã hoàn tất và có thể chạy lại bước cuối. Các ứng dụng đọc trực tiếp DWH nên chỉ sử dụng kết quả sau khi run SUCCEEDED hoặc trong cửa sổ bảo trì.
