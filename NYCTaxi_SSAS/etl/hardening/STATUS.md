# Triển khai hardening — 31/10/2026

Đã cài vào project thực: sửa mapping FHV, bổ sung SourceSRFlag vào payload hash, checkpoint phiên bản FILE_FHV_V2_20261031 chỉ cho FHV; chuẩn hóa metadata Master. Giữ nguyên tham số người dùng khi copy từ live. Generator incremental gọi cùng bản patch để không tái sinh lỗi cũ.

SSAS: ẩn WAV Match Rate qua cập nhật MDX script, không Process. Mô hình local và generator cũng giữ measure này hidden. Không đổi công thức dữ liệu nguồn. Sáu kết nối Power BI tiếp tục đạt kiểm tra health.

Controller: Job Object KILL_ON_JOB_CLOSE quản lý runner và hậu duệ; khi controller bị kết thúc, Windows đóng handle và dừng nhóm tiến trình đã attach. Nếu attach thất bại thì dừng runner và báo lỗi. Không tự sửa PipelineRun thành công sau cancel. Dùng Recover-Run.ps1 để xem run, thêm -Execute để đóng đúng run RUNNING thành FAILED khi đã lấy được exclusive applock. Checkpoint thành công được giữ.

Lịch đã đăng ký NYCTaxi Monthly ETL, ngày 15 lúc 10:00 Bangkok, tháng hiện tại trừ hai, MaxRows=100000. NextRunTime tại lúc tạo: 15/11/2026 10:00. Interactive user cần đăng nhập. Chưa kích hoạt chạy thử lịch/ETL.

Verify-Results ghi lỗi có cấu trúc khi runner cung cấp đường dẫn; Native chỉ nhận kết quả đúng InvocationId, bảo toàn SqlNumber qua child process cho retry classifier. Đã kiểm thử giả lập lỗi 1205.

Kiểm thử mới: 12/12 unit Python/metadata; 22/22 SQL incremental trong database IncTest mới; ba ca FHV 1→Y, 0→N, NULL→U; bảy ca controller; job đóng dừng cha/con giả lập; async scalar/reader/heartbeat/stdout và structured failure đạt. Bằng chứng ở các file *tests*.txt và ../incremental-tests.json. Database fixture mới có suffix 20261031173356, không tham gia production.

Không chạy ETL production. Lần DWH tiếp theo sẽ xử lý lại các file FHV một lần để chuyển checkpoint/hash. Các file dịch vụ khác không bị nâng LoaderVersion. Giữ Unknown cho SR_Flag NULL khi chưa xác định được semantic theo phiên bản nguồn.

## Chưa hoàn tất — không coi đây là nghiệm thu toàn bộ

- Transform vẫn quét kiểm tra clean lịch sử. Aggregate vẫn full rebuild. SSAS vẫn ProcessFull; chưa tích hợp refresh theo vùng dữ liệu thay đổi hoặc tách Process/Verify checkpoint.
- Chưa bổ sung khóa chung vào mọi đường chạy native package con. Vận hành qua Master; không chạy package con đồng thời.
- Chưa có schema CANCELLED/ABANDONED, nút cancel trên monitor, hoặc tự động quyết định đóng orphan run. Recovery hiện chủ động, có khóa bảo vệ.
- Chưa ghim manifest phiên bản cho resume; ConfigHash vẫn kiểm tra cấu hình và đường dẫn.
- Chưa có lịch ngày lễ đáng tin cậy, SCD2 Dim_Base, file lineage thật trong Dim_LoadBatch. Không tự bịa thuộc tính nguồn hoặc lịch sử thay đổi.
- Chưa kiểm tra restore backup, chạy lịch thực tế, UI tất cả trang Power BI, full dataset/benchmark hoặc cập nhật báo cáo đồ án. Chưa thay chính sách backup/log retention.

Backup được ghi trong backup.txt. Không chạy lại Install.ps1 sau khi người dùng thay đổi package; installer từ chối nếu hash live khác backup.
