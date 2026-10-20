# NYC Taxi Analysis — SSAS Multidimensional

Dự án tiếp tục solution hiện có tại `E:\NYCTaxi\NYCTaxi_SSAS`, sử dụng schema thực tế của `THUONGNGUYEN\MSSQLSV.NYCTaxi_DWH`. Không thay đổi bảng hoặc dữ liệu DWH.

## Mô hình đã triển khai

- Data Source `DS_NYCTaxi_DWH`: MSOLEDBSQL, Windows authentication, tài khoản dịch vụ SSAS.
- DSV `DSV_NYCTaxi_DWH`: 15 dimension, 3 transaction fact, 3 snapshot fact; quan hệ theo PK/FK thực tế. Tệp vẫn giữ tên `DSV_NYCTaxi.dsv` để tiếp tục dự án cũ.
- 15 database dimension, gồm Dim Load Batch; role-playing Pickup/Dropoff/Request/On Scene/Snapshot và Dispatch/Origin/Affiliated.
- Cube `NYC Taxi Analysis`, giữ ID nội bộ `DSV_NYCTaxi` để cập nhật cube cũ.
- 6 measure group, 49 measure nghiệp vụ cộng dồn, 18 measure ẩn hỗ trợ mẫu số hợp lệ và 19 calculated measure MDX.
- 45 partition MOLAP: FHV 13, HVFHV 13, YellowGreen 16, snapshot 3. Transaction chia theo tháng/bảng nguồn; Yellow/Green phân biệt qua ServiceTypeKey. `Other Dates` giữ khóa 0 và tháng chưa tách riêng.
- Aggregation design `Operational`: Month/Service, Date/Borough khi có khóa địa lý tương ứng. Snapshot là measure group độc lập, không phải SSAS aggregation của transaction.

`NYC Taxi DWH.dsv` cũ được giữ trên đĩa nhưng bỏ khỏi project để tránh dùng nhầm. Các bản sao tệp nằm trong `backups/`; metadata server trước cập nhật là `backups/server-before-update-*.xmla`.

## Chỉ tiêu và hierarchy

`Total Trips All Services` chỉ cộng ba transaction fact; không cộng TotalTrips từ snapshot. Tiền cước và tiền khách trả được giữ riêng theo nguồn, không gộp FareAmount với BasePassengerFare.

Trung bình dùng tổng giá trị chia tổng TripCount của các dòng có giá trị tương ứng, không coi NULL là 0. Speed dùng tổng khoảng cách chia tổng thời gian của cùng tập dòng có khoảng cách không âm và thời gian dương. Tip Percentage là TipAmount/FareAmount cho taxi, TipAmount/BasePassengerFare cho HVFHV, trên cùng tập dòng có đủ hai giá trị; không phải tip/tổng tiền.

Shared Request Rate dùng snapshot Base Performance, riêng FHVHV: TotalSharedRequests/TotalTrips. WAV Match Rate là TotalWAVMatches/TotalWAVRequests. Base Average Duration/Waiting dùng DurationTripCount/WaitingTripCount. Mẫu số trống hoặc bằng 0 trả NULL.

Dimension không liên quan có `IgnoreUnrelatedDimensions=false`. Khi so sánh liên nguồn, dùng dimension chung; Payment Type không mô tả FHV/HVFHV. Tổng chuyến dùng CoalesceEmpty nên ngữ cảnh trống có thể hiển thị 0.

- Calendar: Year → Quarter → Month → Date; khóa quý `(YearNumber,QuarterNumber)`, tháng `(YearNumber,MonthNumber)`, ngày DateKey.
- Time: TimeBand → Hour → Time; khóa giờ `(TimeBand,HourNumber)` phân biệt giờ Unknown với giờ 00; phút dùng TimeKey 1..1440, khóa 0 là Unknown.
- Geography: Borough → Zone; Borough dùng Borough làm key/caption; Zone dùng LocationKey và hiển thị ZoneName.
- Mọi dimension giữ dòng key=0 như thành viên thông thường. UnknownMember bổ sung cho khóa không phân giải. KeyNotFound, KeyDuplicate, NullKeyNotAllowed đặt ReportAndStop; không bỏ fact lỗi. NULL thuộc tính nullable chuyển thành blank/zero.

## Kiểm tra và triển khai

Mở `NYCTaxi_SSAS.sln` bằng Visual Studio + Analysis Services Projects. Target: SSAS Multidimensional `THUONGNGUYEN\MSSQLSV`, database `NYCTaxi_SSAS`.

Phiên triển khai không Build được qua Visual Studio vì **Invalid license data**. Mô hình đã được AMO validate, serialize thành XMLA, deploy và process thực tế. Kết quả chi tiết nằm trong `IMPLEMENTATION_REPORT.md`.

Chạy tại thư mục gốc với tài khoản SQL/SSAS đã có quyền. PowerShell sử dụng AMO/ADOMD.NET cài sẵn; Python dùng lxml:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Inspect-Environment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Profile-Data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Audit-Dwh.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-Model.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Xmla.ps1
```

`Complete-Model.py` tái tạo mô hình từ metadata đã chụp, không chạy mỗi lần ETL. Khi schema thay đổi cần chụp metadata mới và xem xét diff trước khi tái tạo.

Deploy lần đầu vào database chưa tồn tại dùng `Invoke-Ssas.ps1 -Action Deploy`. Cập nhật toàn mô hình dùng Action Update: sao lưu metadata, giữ Roles, có thể làm mất trạng thái Process. Sau khi xem xét XMLA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Update
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Dimensions
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Process -XmlaPath deployment/Process-Test-202501.xmla
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Process -XmlaPath deployment/Process-Snapshots.xmla
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Verify-Results.ps1 -Scope TestMonth
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Process -XmlaPath deployment/Process-All-Partitions.xmla
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Verify-Results.ps1 -Scope Full
```

Chỉ dùng TestMonth ngay sau khi transaction mới Process partition 202501. Sau khi Process toàn kho, dùng Full; TestMonth đọc tổng cube hiện có nên không tự lọc cube toàn kho về tháng thử nghiệm. Cube cần các measure group có partition sẵn sàng để Browse; xử lý snapshot trước lần truy vấn thử.

Script không tự cấp quyền SQL hoặc thay đổi bảo mật hệ thống. Nếu service account thiếu SELECT, DBA cần cấu hình quyền thích hợp; không tăng ErrorLimit để che lỗi.

## Cập nhật sau ETL

Hoàn tất ETL và giữ nguồn ổn định trong lúc refresh/đối soát. Không Deploy lại toàn database cho mỗi lô:

```powershell
python scripts/Plan-Refresh.py 202601
# Xem deployment/Refresh-202601.xmla trước khi thực thi.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Ssas.ps1 -Action Process -XmlaPath deployment/Refresh-202601.xmla
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Verify-Results.ps1 -Scope Full
```

Planner sao lưu và cập nhật partitions cục bộ, sinh XMLA; chưa thay đổi server. Tháng mới được tạo partition và loại khỏi catch-all trong cùng batch transaction. Batch ProcessUpdate dimension, ProcessFull tháng/catch-all và snapshot, rồi ProcessIndexes cube. Xử lý lại catch-all tránh chuyến của tháng mới bị cộng trùng. Nếu nhiều tháng thay đổi, lập và thực thi từng plan lần lượt; không bỏ qua plan đã cập nhật metadata cục bộ.

Refresh planner được cung cấp cho vận hành; xem báo cáo về mức kiểm thử. Snapshot hiện refresh toàn bảng; có thể chia theo thời gian khi lớn hơn. Monthly partition hiện nhỏ do dữ liệu mẫu, vì vậy AMO cảnh báo khuyến nghị hợp nhất partition nhỏ; cần đo hiệu năng trước khi tối ưu production.

## Bằng chứng

`evidence/` chứa schema, PK/FK, số dòng, tháng, audit Unknown/orphan, kết quả AMO, log SSAS và CSV SQL–MDX. `queries/reconcile-*.sql`/`.mdx` chứa truy vấn đã chạy; `queries/dwh-integrity.sql` kiểm tra khóa ngoại; `queries/smoke.mdx` dùng Browse nhanh trong SSMS hoặc kết nối live từ Power BI.
