# Bộ báo cáo nghiệp vụ Power BI — NYC Taxi

Nguồn: SSAS Multidimensional `THUONGNGUYEN\MSSQLSV`, database `NYCTaxi_SSAS`.
Sáu project **Live Connection**, không Import, không kết nối trực tiếp SQL, không gộp cube.

## Menu mở nhanh trên máy

Mở `NYCTaxi Analytics.exe` trong thư mục này hoặc shortcut `Mo Dashboard Power BI.lnk` ở thư mục gốc dự án. Có sáu nút nghiệp vụ, kiểm tra kết nối, thư mục báo cáo và hướng dẫn. Báo cáo mở trong các cửa sổ Power BI riêng, không tự đồng bộ bộ lọc.

Menu kiểm tra SSAS chỉ đọc. Nếu cube chưa process, menu giải thích và chặn mở vào nguồn chưa sẵn sàng; không tự chạy ETL hoặc process để che lỗi. Sau khi tự chạy Master đến EPT_05_Ssas thành công, chọn Kiểm tra kết nối rồi mở báo cáo. Chỉ khi cube Processed và truy vấn kiểm tra thành công mới hiện Sẵn sàng.

Ngày 31/10/2026 đã quan sát lỗi Desktop "server ... doesn't have any models" sau reset. AMO vẫn thấy đủ sáu cube nhưng tất cả Unprocessed; đây không phải bằng chứng sai tên server hay thiếu cube. Cấu hình sáu báo cáo được chuẩn hóa về Windows SSPI, Cube được đặt trong dấu nháy, và connectionType=analysisServicesDatabaseLive. Các bản cũ được lưu trong `_backups/connections-*`. Không sửa các trang/visual mà người dùng đã lưu bằng Desktop.

Nguồn vẫn Unprocessed tại thời điểm bàn giao menu; chưa kiểm chứng render có dữ liệu sau reset. Các visual được Desktop lưu lại với schema 2.14.0 hiện chưa tải được schema công khai, được ghi vào unavailableSchemas thay vì tự hạ phiên bản hoặc ghi đè layout.

`Get-ReportHealth.ps1 -Save` tạo connection-health.json; `launcher-verification.json` ghi kết quả kiểm tra menu. `Build-Launcher.ps1` biên dịch lại ứng dụng từ ReportLauncher.cs; đóng menu trước khi build. Giữ executable cạnh report-index.json, Get-ReportHealth.ps1 và thư mục reports.

## Mở báo cáo

Mở file `.pbip` bằng Power BI Desktop bản hỗ trợ PBIP/PBIR. Giữ nguyên cả thư mục project gồm `.Report` và `.SemanticModel`; không chỉ sao chép file `.pbip`.

| Project trong `reports/` | Trang | Câu hỏi nghiệp vụ |
|---|---|---|
| `YellowGreen_Trips/YellowGreen_Trips.pbip` | Taxi truyền thống; Hành vi & tiền tip | Xu hướng chuyến đi, giờ cao điểm; tip khác nhau theo thanh toán, cuối tuần, quận thế nào? |
| `HVFHV_Trips/HVFHV_Trips.pbip` | Xe công nghệ; Phí & thu nhập | Nhu cầu, thời gian chờ, nhà cung cấp; tiền khách trả, tiền tài xế và phí biến động thế nào? |
| `FHV_Trips/FHV_Trips.pbip` | FHV truyền thống | Nhu cầu theo ngày, giờ, quận và base; thời lượng chuyến đi? |
| `Daily_Financial/Daily_Financial.pbip` | Tài chính theo ngày | Tiền khách trả, tip, thuế/phí, tiền tài xế theo ngày và dịch vụ? |
| `Zone_Traffic/Zone_Traffic.pbip` | Nhu cầu theo khu vực; Chi tiết không gian & giờ | Phân bổ lượt đón/trả, ma trận quận × giờ, zone, so sánh lưu lượng các dịch vụ trong cùng phạm vi? |
| `Base_Performance/Base_Performance.pbip` | Hiệu suất điều phối | Khối lượng theo base, thời gian chờ, thời lượng và yêu cầu đi chung? |

Mỗi trang có bộ lọc Năm, Tháng, Dịch vụ. Một số trang thêm Quận, Nhà cung cấp hoặc Base. Chọn năm trước, rồi tháng; bộ lọc ở các báo cáo độc lập, không tự đồng bộ giữa sáu project.

Nếu Power BI yêu cầu chọn nguồn: SQL Server Analysis Services → server trên → **Connect live** → database → đúng cube theo tên file. Dùng tài khoản Windows có quyền đọc SSAS. Không chọn Import hay chuyển sang local model.

PBIP là project Power BI thật nhưng không phải PBIX nhị phân. Khi mở thành công, có thể Save As `.pbix` nếu phiên bản Desktop hỗ trợ cho project hiện tại. Nếu bản Desktop chưa hỗ trợ PBIR, cập nhật Power BI hoặc bật tính năng project/report format phù hợp trong Options; người dùng tự quyết định thay đổi tùy chọn ứng dụng.

## Dữ liệu và cách cập nhật

Visual truy vấn cube trực tiếp. Sau ETL phải process cube thành công; sau đó dùng Refresh trong Power BI để yêu cầu kết quả mới. Refresh Power BI không tự chạy ETL hoặc process SSAS. Không publish lên Power BI Service trong tác vụ này; muốn publish Live SSAS cần gateway và cấu hình danh tính/quyền phù hợp.

Không có filter cố định năm 2021, vì phạm vi tháng đã process thay đổi theo quá trình demo. Chọn tháng có dữ liệu trên cube. Nếu đang nạp DWH mà chưa process SSAS, Power BI vẫn hiển thị dữ liệu của lần process trước.

## Cách demo đồ án

1. Mở YellowGreen → chọn một năm/tháng đã process → trình bày số chuyến, tiền khách trả, giờ cao điểm và quận.
2. Chuyển trang Hành vi & tiền tip → chọn phương thức thanh toán → so sánh tỷ lệ tip theo quận, cuối tuần, giờ. Không coi tiền tip tiền mặt không ghi nhận là khách không tip.
3. Mở Zone Traffic, chọn cùng năm/tháng → so sánh các dịch vụ theo giờ/quận. Đây là lưu lượng của tập đã nạp, chưa phải thị phần NYC nếu các file bị giới hạn dòng khác nhau.
4. Mở HVFHV → so sánh thời gian chờ giữa quận/nhà cung cấp. Trang Phí & thu nhập chỉ mô tả biến động, không khẳng định phí gây ra biến động số chuyến.
5. Mở Daily Financial → diễn giải tiền khách trả, tip, thuế/phí và tiền tài xế riêng; không gọi chênh lệch là lợi nhuận.
6. Mở Base Performance → xem thời gian chờ và yêu cầu đi chung theo base/provider. Cuối cùng nêu giới hạn dữ liệu và cách kiểm chứng SQL–MDX.

## Quy tắc tính và giới hạn

- Trung bình/tỷ lệ dùng calculated measures SSAS đã có và mẫu số hợp lệ; không cộng các giá trị trung bình hoặc lấy trung bình các tỷ lệ con.
- Đơn vị tiền USD, khoảng cách measure gốc mile, thời lượng trung bình phút. Card tổng thời lượng FHV dùng giây, đã ghi đơn vị.
- Daily Financial chỉ bao phủ nguồn có tài chính, không có FHV. Tiền tài xế chủ yếu từ HVFHV; số trống không chứng minh số tiền bằng 0.
- Zone Traffic: lượt đón và lượt trả là hai sự kiện ở vị trí/thời điểm khác nhau; không cộng hai đại lượng để gọi là tổng số chuyến.
- Unknown được giữ, không âm thầm lọc để làm biểu đồ đẹp. Dữ liệu FHV thiếu nhiều vị trí có thể làm hạn chế kết luận địa lý.
- Không đưa `WAV Match Rate` lên báo cáo vì tử/mẫu chưa được xác nhận cùng tập. Không ép tỷ lệ về 100%.
- Không có so sánh chéo measure giữa hai cube trong cùng một visual. Dùng Zone Traffic (có các dịch vụ) cho lưu lượng liên nguồn; so sánh nhiều báo cáo phải giữ cùng bộ lọc và xác nhận độ bao phủ nguồn.
- Mục tiêu đánh giá tác động chính sách trong báo cáo đồ án cần thiết kế phân tích riêng với dữ liệu đầy đủ, thời kỳ trước/sau, biến kiểm soát. Các biểu đồ này chưa chứng minh tác động nhân quả.

## Bằng chứng và kiểm tra

- `metadata/*.csdl.xml`: metadata tabular-view mà SSAS cung cấp cho Power BI.
- `field-bindings.json`: các field/measure dùng trong visual, kèm grouping keys.
- `live-binding-results.json`: kiểm thử DAX chỉ đọc, 70 binding duy nhất.
- `visual-query-results.json`: 101 truy vấn cho visual đạt, có đầy đủ grouping key theo CSDL; không phải kiểm thử render của Power BI.
- `schema-validation.json`: kết quả kiểm tra JSON schema Microsoft cho cấu trúc PBIR và connection reference.
- `build_reports.py`: tái tạo sáu project, không sửa model/cube server.
- `Test-LiveBindings.ps1`: xác minh tên field, measure và truy vấn có grouping keys.

Kiểm tra schema và DAX không thay thế việc mở từng trang trong Power BI để kiểm tra render, kết nối client và tương tác slicer. Tình trạng kiểm chứng UI được ghi riêng trong báo cáo bàn giao; không coi project sinh ra là đã qua kiểm thử Desktop nếu chưa mở được.

Lỗi client đã sửa: `Invalid connection type` do `analysisServices` không phải mã Live Connection mà Desktop 2.159.883.0 yêu cầu. Đã đối chiếu metadata cài đặt và đổi cả sáu `modelReference.json` thành `analysisServicesDatabaseLive`; bộ sinh và validator cũng được sửa để không tái tạo lỗi. Chờ kiểm chứng lại bằng Desktop sau sửa.

Nguồn định dạng: https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report và JSON schemas chính thức của Microsoft tại https://github.com/microsoft/json-schemas.
