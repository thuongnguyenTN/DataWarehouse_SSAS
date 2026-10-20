# Báo cáo triển khai SSAS NYC Taxi

Ngày thực hiện: 19/10/2026, múi giờ Asia/Bangkok. Dự án được sửa trực tiếp trong `E:\NYCTaxi\NYCTaxi_SSAS`; dự án ETL `E:\NYCTaxi\NYCTaxi_DW` chỉ được khảo sát. Không thay đổi dữ liệu hoặc DDL DWH.

## Kết quả thực tế

| Hạng mục | Kết quả xác minh |
|---|---|
| SQL Server | Kết nối được `THUONGNGUYEN\MSSQLSV`, database `NYCTaxi_DWH` |
| Schema | Đọc trực tiếp sys.tables/sys.columns, PK/FK; đủ 15 dimension và 6 fact |
| SSAS | Multidimensional, Developer64, version 16.0.42.229 |
| Build Visual Studio | **Không thành công**: devenv.com trả exit code 1, `Invalid license data. Repair Visual Studio from the Control Panel.` |
| AMO | Deserialize, kiểm tra binding và Validate mô hình thành công; tạo `.asdatabase` và XMLA |
| Deploy | Alter database SSAS hiện có thành công; sao lưu metadata trước cập nhật, giữ Roles |
| Dimensions | 15/15 Processed |
| Cube | `NYC Taxi Analysis`: Processed, 6 measure group |
| Partition | 45/45 Processed, MOLAP, không chồng lấn điều kiện nguồn |
| Tháng thử nghiệm 202501 | 47 kiểm tra SQL–MDX, 0 sai lệch |
| Toàn kho | 102 kiểm tra SQL–MDX, 0 sai lệch |
| Browse | 5 truy vấn MDX trong smoke.mdx chạy thành công qua ADOMD.NET |
| DWH integrity | 51 FK được bật và trusted, không có orphan; cả 15 dimension có đúng một dòng key=0 |

Trạng thái cuối được đọc lại từ server lúc 20:40:42 trong `evidence/final-status.json`. Không dùng kết quả Build Visual Studio cũ trong bin/ để khẳng định bản thay đổi đã build thành công. Bộ triển khai mới nằm ở `deployment/`.

## Thành phần cấu hình

Data Source `DS_NYCTaxi_DWH` dùng MSOLEDBSQL đã có trên máy và Windows authentication, impersonation bằng tài khoản dịch vụ SSAS. DSV `DSV_NYCTaxi_DWH` chứa 21 bảng, PK/FK lấy từ catalog SQL; không nối fact trực tiếp với fact. DSV thêm named calculation trong metadata để đếm các chuyến có chỉ tiêu hợp lệ; không tạo cột mới trong SQL.

15 database dimension gồm các dimension cũ và Dim Load Batch mới. Calendar có khóa quý/năm và tháng/năm, ngày DateKey. Time dùng TimeKey ở mức phút, khóa giờ TimeBand/HourNumber. Geography dùng Borough làm khóa nhóm và LocationKey ở mức Zone. Attribute relationships đã sửa theo hướng thành viên chi tiết → cha. Unknown key=0 được giữ; các lỗi key bị thiếu hoặc trùng dừng Process.

Ba transaction measure group giữ 31 measure gốc theo schema. Ba snapshot measure group bổ sung 18 measure cộng dồn, bỏ các cột trung bình sẵn có và metadata kỹ thuật. Tổng cộng 49 measure nghiệp vụ, 18 measure hỗ trợ ẩn và 19 calculated measure. `Total Trips All Services` chỉ tổng hợp transaction; không cộng số chuyến snapshot vào tổng.

Dimension Usage được tái tạo theo 51 FK: LoadBatch chỉ ở transaction; Snapshot Date ở ba snapshot; Snapshot Time/Location chỉ Zone Traffic. Base Performance có Dispatch Base/Service Type/HVFHS Provider theo schema thật. Các vai trò Request/On Scene chỉ ở HVFHV; không tạo quan hệ khi fact không có FK tương ứng.

45 partition gồm FHV 12 tháng + catch-all, HVFHV 12 tháng + catch-all, YellowGreen 15 tháng + catch-all và ba snapshot toàn bảng. Điều kiện tháng là khoảng nửa mở DateKey; catch-all là phủ định hợp các khoảng, giữ khóa 0 và tháng mới. Các tháng bất thường 200812, 202412, 202601 của taxi được giữ. Aggregation design Operational gồm Month/Service và Date/Borough khi dimension usage cho phép.

## Đối soát số liệu

| Chỉ tiêu | SQL | Cube |
|---|---:|---:|
| Chuyến YELLOW | 1.183.234 | 1.183.234 |
| Chuyến GREEN | 589.465 | 589.465 |
| Chuyến FHV | 1.199.560 | 1.199.560 |
| Chuyến FHVHV | 1.200.000 | 1.200.000 |
| Tổng transaction | 4.172.259 | 4.172.259 |
| YellowGreen TotalAmount | 48.153.636,99 | 48.153.636,99 sau làm tròn cent |
| HVFHV DriverPayAmount | 26.716.595,00 | 26.716.595,00 |
| Zone Traffic pickups | 4.172.259 | 4.172.259 |
| Zone Traffic dropoffs | 4.172.259 | 4.172.259 |
| Daily Financial TotalTrips | 2.972.699 | 2.972.699 |
| Base Performance TotalTrips | 2.399.560 | 2.399.560 |

Daily Financial và Base Performance có phạm vi nguồn khác nhau, vì vậy không so bằng tổng transaction một cách máy móc. Mỗi measure group được đối chiếu với bảng nguồn tương ứng trên cùng bộ lọc.

102 kiểm tra toàn kho bao gồm tổng theo dịch vụ; ngày 01/01 và 15/01; một số Pickup Location/Borough; Calendar tháng/quý; giờ 00/08/17; khóa Unknown date/time/batch; doanh thu, tiền tài xế, trung bình, speed, tip; mọi measure snapshot; một số Dispatch Base và các tỷ lệ. Không khẳng định đã kiểm thử mọi tổ hợp bộ lọc hoặc benchmark production.

So sánh số thực có dung sai `max(0.00001, abs(SQL)*1e-9)` để xử lý sai số biểu diễn; không phải so sánh bit-for-bit. CSV giữ nguyên giá trị SQL/Cube để kiểm tra độc lập.

## Lỗi đã phát hiện và xử lý

1. Thiếu Dim_LoadBatch và ba snapshot measure group: bổ sung theo cột và FK thực tế.
2. Calendar có khóa tháng thiếu năm, NameColumn thiếu cho composite key: sửa khóa/caption và quan hệ lên quý/năm; mức ngày dùng DateKey.
3. Geography có quan hệ ngược Borough → Zone, gây vòng khi bổ sung hướng đúng: sửa thành Location Key → Zone → Borough.
4. Borough dùng LocationKey và caption ZoneName: sửa cả key/caption thành Borough. Lỗi Duplicate Attribute Key khi caption chưa đồng bộ được sửa, không bỏ qua lỗi.
5. Hour Number dùng TimeKey nên không nhóm theo giờ: sửa composite TimeBand/HourNumber, giữ TimeKey cho phút và key=0 riêng.
6. Process Dim_Base báo dữ liệu chuỗi quá lớn: đồng bộ DataSize và giới hạn chuỗi DSV theo schema, sau đó thay SQLOLEDB cũ bằng MSOLEDBSQL có sẵn. Process toàn bộ dimension thành công với driver mới.
7. Cube chưa xuất hiện trong schema truy vấn khi snapshot group chưa có partition sẵn sàng: xử lý snapshot rồi thực hiện Browse/đối soát.
8. Visual Studio lỗi license: ghi nhận nguyên văn và exit code; sử dụng AMO/XMLA để validate, deploy, process thật. Không sửa license hoặc cài thêm phần mềm.

Log Process giữ cả lỗi ban đầu và các lần chạy thành công sau sửa. `final-status.json` và CSV đối soát cuối là bằng chứng trạng thái bàn giao.

## Chất lượng dữ liệu cần diễn giải

- FHV PickupLocationKey=0: 990.575/1.199.560 dòng, khoảng **82,58%**. DropoffLocationKey=0 khoảng 16,69%. Những chuyến này vẫn nằm trong tổng và nhóm Unknown; không mất dữ liệu khi Process.
- HVFHV OnSceneDateKey/TimeKey=0: 79.509 dòng (6,62575%); OriginBaseKey=0: 363.448 dòng (30,2873%).
- FHVFlagKey=0 cho toàn bộ FHV; một số thuộc tính taxi không áp dụng cho mọi loại dịch vụ cũng có tỷ lệ Unknown cao. Xem audit đầy đủ trước khi diễn giải.
- Snapshot ghi TotalWAVRequests=1.232 và TotalWAVMatches=90.514. Measure WAV Match Rate được định nghĩa matches/requests nên trả **73,469155844...**, định dạng phần trăm khoảng **7.346,92%**. Cube khớp SQL nhưng đây chưa phải tỷ lệ chuyển đổi request→match hợp lệ nếu matches không thuộc cùng tập requests. Không clamp về 100%, không sửa dữ liệu; cần chủ dự án xác nhận lại định nghĩa nghiệp vụ/cách ETL tạo hai bộ đếm trước khi dùng như KPI đáp ứng.
- Dữ liệu taxi có 1 chuyến 200812, 27 chuyến 202412 và 14 chuyến 202601; giữ nguyên và phân vùng riêng, không tự lọc bỏ.

## File tạo hoặc sửa

**Sửa project:**

- `NYCTaxi_SSAS/NYCTaxi_SSAS.dwproj`
- `NYCTaxi_SSAS/DS_NYCTaxi_DWH.ds`
- `NYCTaxi_SSAS/DSV_NYCTaxi.dsv`
- `NYCTaxi_SSAS/DSV_NYCTaxi.cube`
- `NYCTaxi_SSAS/DSV_NYCTaxi.partitions`
- 14 dimension cũ: `Dim Base.dim`, `Dim Date.dim`, `Dim FHV Flags.dim`, `Dim HVFHS Provider.dim`, `Dim HVFHV Flags.dim`, `Dim Location.dim`, `Dim Passenger Group.dim`, `Dim Payment Type.dim`, `Dim Rate Code.dim`, `Dim Service Type.dim`, `Dim Taxi Flags.dim`, `Dim Time.dim`, `Dim Trip Type.dim`, `Dim Vendor.dim`.

**Tạo dimension:** `NYCTaxi_SSAS/Dim Load Batch.dim`.

**Script:** `Inspect-Environment.ps1`, `Profile-Data.ps1`, `Audit-Dwh.ps1`, `Complete-Model.py`, `Validate-Model.ps1`, `Build-Xmla.ps1`, `Invoke-Ssas.ps1`, `Verify-Results.ps1`, `Save-FinalStatus.ps1`, `Plan-Refresh.py`, `Trace-Processing.ps1` trong `scripts/`.

**Triển khai:** `NYCTaxi_SSAS.asdatabase`, `Create-Database.xmla`, `Alter-Database.xmla`, `Process-Test-202501.xmla`, `Process-Snapshots.xmla`, `Process-All-Partitions.xmla`, `Refresh-202501.xmla` trong `deployment/`.

**Truy vấn:** `smoke.mdx`, `reconcile-TestMonth.sql`, `reconcile-TestMonth.mdx`, `reconcile-Full.sql`, `reconcile-Full.mdx`, `dwh-integrity.sql` trong `queries/`.

**Tài liệu/bằng chứng:** `README.md`, báo cáo này, `evidence/*.json`, `*.csv`, `*.txt`, `*.log`; các backup nằm trong `backups/`.

## Phần chưa xác minh hoặc cần tiếp tục

1. Build chính thức bằng Visual Studio chưa đạt vì license của IDE; cần sửa Visual Studio rồi chạy lại Build Development. AMO Validate không được gọi là Visual Studio Build.
2. Refresh planner đã chạy sinh plan 202501, kiểm tra cú pháp Python/XML và validate metadata; **chưa thực thi batch refresh incremental đó trên server**. Lần nạp đầu đã dùng ProcessFull partition thực tế, toàn bộ dữ liệu đã Processed. Quy trình vận hành nằm trong README.
3. Các cảnh báo AMO mang tính thiết kế còn tồn tại: hierarchy cho dimension phẳng, visibility/type của thuộc tính thời gian, flexible relationship, EstimatedRows của aggregation, partition mẫu nhỏ; AMO còn cảnh báo provider theo bộ quy tắc thư viện dù MSOLEDBSQL đã Process thành công trên server. Không có lỗi AMO ngăn triển khai. Chưa benchmark aggregation/partition ở quy mô hàng triệu chuyến mỗi tháng.
4. WAV Match Rate cần xác nhận định nghĩa nghiệp vụ như trên. Không có thay đổi ETL hoặc dữ liệu DWH để làm đẹp KPI.
5. Browse được xác minh qua năm truy vấn MDX/ADOMD.NET, chưa tạo dashboard Power BI hoặc kiểm tra giao diện Cube Browser trong Visual Studio đang lỗi license; hai việc này không được tuyên bố đã thực hiện.
