# Câu hỏi phân tích phục vụ đồ án

Đối chiếu mục 1 Mục tiêu bài toán trong `D:\Kho_Du_lieu\NYCTaxi\Nhom01.docx`. Các báo cáo chỉ đọc các cube đã triển khai, không đổi schema SSAS hoặc DWH.

| Câu hỏi | Báo cáo/trang | Tương tác khi demo | Cách kết luận có căn cứ |
|---|---|---|---|
| 1. Nhu cầu taxi thay đổi theo ngày và giờ như thế nào? | YellowGreen / Taxi truyền thống | Lọc năm, tháng, dịch vụ, quận; chọn cột giờ để lọc các visual khác | Nêu ngày/giờ cao điểm trong phạm vi đã nạp, ghi rõ số chuyến và thời kỳ |
| 2. Khu vực nào có tỷ lệ tip cao? | YellowGreen / Hành vi & tiền tip | Lọc cùng tháng và thanh toán; đọc biểu đồ zone xếp giảm dần, xem số chuyến khi chọn zone | Phải xét độ lớn tập chuyến; zone có ít chuyến không đủ cơ sở kết luận thói quen chung |
| 3. Thanh toán, cuối tuần và giờ ảnh hưởng đồng thời với tip ra sao? | YellowGreen / Hành vi & tiền tip | Đổi slicer thanh toán, so sánh Is Weekend và đường theo giờ | Mô tả chênh lệch/đồng biến; không gọi là tác động nhân quả; tip tiền mặt có giới hạn ghi nhận |
| 4. Lưu lượng các dịch vụ phân bố theo quận và giờ ra sao? | Zone Traffic / hai trang | Chọn cùng năm/tháng/quận, xem legend dịch vụ và ma trận quận × giờ | Dùng lượt đón cùng phạm vi để so sánh; không gọi là thị phần toàn thị trường khi nguồn bị giới hạn khác nhau |
| 5. Nhà cung cấp/quận nào có thời gian chờ khác biệt? | HVFHV / Xe công nghệ | Lọc provider, xem chờ TB theo quận; chọn cùng tháng | Chờ TB dùng số chuyến có thời gian chờ hợp lệ; không thay mẫu số bằng mọi chuyến |
| 6. Phí ùn tắc/CBD biến động cùng số chuyến và thu nhập thế nào? | HVFHV / Phí & thu nhập; Daily Financial | Lọc khoảng thời gian, đối chiếu dòng phí, tiền khách trả, tiền tài xế với trang nhu cầu | Chưa đủ để kết luận tác động chính sách; cần kỳ trước/sau đầy đủ và kiểm soát biến khác |
| 7. Cơ cấu tiền khách trả, tip, thuế/phí theo dịch vụ/ngày ra sao? | Daily Financial | Chọn dịch vụ và tháng, đọc các card/biểu đồ | Chỉ các dịch vụ có tài chính; không gọi tiền khách trả là doanh thu thuần hoặc lợi nhuận |
| 8. Base điều phối nào có lưu lượng/chờ/thời lượng khác biệt? | Base Performance | Chọn base và thời gian, xem chờ và số chuyến | Không xếp hạng chất lượng chỉ từ chờ TB nếu phạm vi, địa bàn, số chuyến khác nhau |

Không dùng WAV Match Rate trong bảo vệ trước khi xác nhận định nghĩa; Unknown phải được công bố khi phân tích địa lý. Không có insight số liệu được viết cố định trong layout vì báo cáo Live thay đổi theo thời gian và bộ lọc. Khi chụp kết quả nộp bài, ghi: năm/tháng, dịch vụ, số dòng giới hạn hoặc full, thời điểm process cube, giá trị quan sát và giới hạn suy luận.

## Kiểm thử thủ công trước khi demo

1. Mở đủ sáu PBIP, xác nhận kết nối Live đúng server/database/cube.
2. Mỗi trang phải render không có lỗi; không chấp nhận chỉ có card mà các chart lỗi.
3. Lọc một năm/tháng đã process, xác nhận card và biểu đồ đổi tương ứng.
4. Chọn một quận/provider, kiểm tra cross-filter; xóa lựa chọn để trở về toàn phạm vi.
5. So sánh card tổng và một bộ lọc với MDX/SSMS trên cùng cube.
6. Lưu PBIX nếu cần nộp định dạng đó; giữ PBIP làm mã nguồn tái tạo.
7. Không publish hoặc thay quyền chia sẻ khi chưa có yêu cầu.
