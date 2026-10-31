# Master: theo dõi và xử lý lỗi

Mở project E:\NYCTaxi\NYCTaxi_DW\NYCTaxi_ETL\NYCTaxi_ETL.dtproj trong Visual Studio. Nếu đang mở, reload project/package khi Visual Studio hỏi do file thay đổi trên đĩa.

## Chạy mới

Trong Parameters của PKG_00_Master: đặt pStartMonth, pEndMonth, pMaxRows như trước; pResumeRunId để trống, pStartStage=Extract, pShowMonitor=1, pMaxRetries=1. Chạy Master. EPT_00_Open_Monitor mở cửa sổ riêng, không chặn ETL.

Monitor hiển thị năm stage, task/file hiện tại, heartbeat, thời gian, số dòng ghi wrk khi bulk copy, nhật ký và stdout/stderr Python. Dòng wrk chưa có nghĩa staging đã commit. SQL không cung cấp phần trăm hoàn tất nên chỉ hiển thị thời gian/heartbeat. BulkCopy, mở kết nối và xử lý SSAS đồng bộ có thể không phát heartbeat trong khi vẫn hoạt động; cảnh báo thiếu heartbeat không kết luận tiến trình bị treo.

## Đường nối

Nhánh xanh: Monitor → Extract → Transform → Dwh → Aggregates → Ssas → Complete. Phụ thuộc dữ liệu vẫn giữ thứ tự. Complete kiểm tra SQL đã đánh dấu toàn run SUCCEEDED sau SSAS/đối soát.

Nhánh đỏ từ mỗi EPT nối vào EST_90_Report_Original_Error bằng điều kiện OR. Khi một task thất bại: ghi lỗi đầy đủ vào etl.PackageError, phát thông báo stage/task/lỗi gốc/RunId/thư mục log, kết thúc Master với trạng thái lỗi. Không cho bước phụ thuộc chạy với dữ liệu chưa hợp lệ. Nếu SQL mất kết nối, bước ghi SQL có thể thất bại; lỗi gốc vẫn còn trong monitor và file local.

Retry nằm trong controller, tối đa pMaxRetries lần (0–3, mặc định 1), chỉ với SqlException thuộc danh sách lỗi tạm thời: timeout/deadlock và một số lỗi kết nối. Mỗi lần thử có InvocationId riêng, không dùng nhầm failure JSON cũ. Lỗi schema, dữ liệu, Python không tự retry. Retry chạy lại stage, sử dụng các checkpoint file hiện có; không tiếp tục giữa một câu SQL.

## Chạy tiếp sau lỗi

1. Đọc lỗi và sửa nguyên nhân. Copy RunId từ monitor.
2. Trong Parameters: pResumeRunId=RunId cũ; pStartStage=stage lỗi, ví dụ Dwh. Giữ nguyên tháng, giới hạn dòng, server và các đường dẫn.
3. Chạy Master. Các stage trước được bỏ qua chỉ khi cấu hình trùng và stage ngay trước điểm tiếp tục có checkpoint StageComplete SUCCEEDED. Nếu chưa hoàn thành, hệ thống từ chối và yêu cầu chạy từ stage sớm hơn.
4. Stage bị lỗi chạy lại theo checkpoint của chính nó. Các stage phía sau chạy lại/đối soát. Để chạy một lượt mới khác, trả pResumeRunId về trống và pStartStage=Extract.

Đóng monitor không dừng ETL. Stop Debugging/cancel đột ngột chưa phải cơ chế hủy tiến trình con có kiểm soát: phải xác nhận tiến trình cũ đã dừng và khóa SQL đã được giải phóng trước khi resume; không xóa log hoặc tự tạo RunId khác để vượt khóa. Resume sử dụng checkpoint nghiệp vụ SQL/file, không phải SSIS .chk trên từng EPT.

Log: E:\NYCTaxi\NYCTaxi_SSAS\etl\logs\<RunId>\ gồm events.jsonl, status.json, failure-<stage>.json, master-error.json và stdout/stderr. Dữ liệu cũ trước phiên bản này không có status.json nên không hiện đầy đủ trên monitor mới.

Mở lại monitor bằng cách chạy E:\NYCTaxi\NYCTaxi_SSAS\etl\monitor\NYCTaxi ETL Monitor.exe: mặc định chọn log có status.json cập nhật gần nhất. Có thể chỉ định phiên cũ bằng tham số --run-id GUID --log-root E:\NYCTaxi\NYCTaxi_SSAS\etl\logs.

## Kiểm thử

Test-MasterControl.ps1 chạy fake runner: thành công, lỗi vĩnh viễn giữ lỗi gốc, lỗi tạm thời retry thành công, hết lượt retry, lỗi cũ không bị retry nhầm, resume hợp lệ/từ chối. Test-RunnerProgress.ps1 chỉ chạy SELECT/WAITFOR và Python giả lập để kiểm tra async scalar/reader, heartbeat, stdout. MasterFailureFixture.dtsx là bản thử đã bỏ handler ghi SQL và thay nhánh lỗi bằng RAISERROR; không chạy ETL thật.
