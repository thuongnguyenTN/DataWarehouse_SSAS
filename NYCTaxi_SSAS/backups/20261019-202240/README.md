# NYC Taxi — SSAS Multidimensional

Mô hình phân tích trên kho SQL Server `NYCTaxi_DWH`, mở bằng `NYCTaxi_SSAS.sln` trong Visual Studio có extension Analysis Services Projects.

## Mô hình

| Measure group | Dữ liệu | Chỉ tiêu chính |
|---|---|---|
| Fact FHV Trips | FHV | Số chuyến, thời gian chuyến |
| Fact HVFHV Trips | Dịch vụ gọi xe quy mô lớn | Số chuyến, quãng đường, tiền khách trả, tiền tài xế, thời gian chờ |
| Fact Yellow Green Trips | Taxi vàng/xanh | Số chuyến, hành khách, quãng đường, cước, phụ phí, tổng tiền |

14 dimension dùng chung; Date, Time, Location và Base được sử dụng theo nhiều vai trò như Pickup/Dropoff và Dispatch/Affiliated/Origin. Calendar cho phép đi từ năm → quý → tháng → ngày. Khóa tháng gồm năm và tháng để phân biệt các năm.

Cube bổ sung `All Trips`, `Recorded Passenger Amount` và 9 chỉ tiêu trung bình theo nhóm dịch vụ. Trung bình được tính từ tổng chia tổng số chuyến, trả NULL nếu mẫu số trống hoặc bằng 0. `Recorded Passenger Amount` chỉ cộng HVFHV và Yellow/Green; FHV không có số tiền trong mô hình. Đơn vị quãng đường là mile, thời gian trung bình là phút, tiền theo đơn vị của nguồn dữ liệu.

Khi so sánh tổng giữa các nhóm, dùng dimension chung như Pickup Date, Pickup Location, Dim Service Type. Dimension chỉ thuộc một nhóm (ví dụ Payment Type) không lọc các nhóm khác; không dùng để diễn giải `All Trips` hay tổng tiền liên nhóm.

## Triển khai

1. Bảo đảm kho `NYCTaxi_DWH` đã được ETL và các bảng/khóa khớp với DSV. Dự án này là lớp OLAP, không bao gồm pipeline ETL tạo kho quan hệ.
2. Trong Data Source `DS_NYCTaxi_DWH`, đổi máy SQL Server theo môi trường. Hiện cấu hình là `THUONGNGUYEN\MSSQLSV`; cập nhật cả ConnectionMappings trong cấu hình Development nếu thay đổi kết nối.
3. Data Source dùng tài khoản dịch vụ SSAS (`ImpersonateServiceAccount`). Cấp tài khoản đó quyền SELECT trên bảng nguồn. Kiểm tra OLE DB provider trong chuỗi kết nối đã được cài trên máy SSAS.
4. Trong Project Properties → Deployment, đặt Target Server là instance SSAS chạy Multidimensional và Target Database là `NYCTaxi_SSAS` theo môi trường thực tế.
5. Build solution, xem toàn bộ lỗi/cảnh báo rồi Deploy. Process Full dimension trước và cube sau, hoặc Process Full database. Thực hiện lần đầu ở môi trường phát triển vì partition hiện đọc toàn bộ bảng fact.
6. Chạy `queries/smoke.mdx` trong SSMS kết nối Analysis Services; đối chiếu các tổng với truy vấn SQL bên dưới.

```sql
SELECT SUM(CAST(TripCount AS bigint)) AS Trips FROM dbo.Fact_FHV_Trips;
SELECT SUM(CAST(TripCount AS bigint)) AS Trips,
       SUM(GrossPassengerAmount) AS PassengerAmount FROM dbo.Fact_HVFHV_Trips;
SELECT SUM(CAST(TripCount AS bigint)) AS Trips,
       SUM(TotalAmount) AS PassengerAmount FROM dbo.Fact_YellowGreen_Trips;
```

Chạy kiểm tra tham chiếu XML cục bộ bằng `powershell -File scripts/Validate-Model.ps1`. Kiểm tra này không thay thế Build/Deploy/Process trên SSAS. Với dữ liệu lớn, cần thiết kế partition theo tháng và chỉ process kỳ thay đổi trước khi đưa vào vận hành; ba partition hiện tại là MOLAP toàn bảng.
