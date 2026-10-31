# Rà soát toàn luồng NYC Taxi — 31/10/2026

## Kết luận

Hệ thống có luồng end-to-end hoạt động và dữ liệu hiện tại nhất quán giữa clean, DWH và SSAS. Chưa đủ điều kiện tuyên bố hoàn thiện toàn bộ nghiệp vụ và vận hành tự động ổn định. Cần xử lý các phát hiện bên dưới trước khi nghiệm thu. Không quy đổi kết quả thành điểm đồ án vì chưa có bản yêu cầu/báo cáo nộp mới nhất được đối chiếu trong lần này.

Lần rà soát chỉ đọc nguồn, truy vấn SQL/SSAS, kiểm tra lịch và chạy fixture local. Không chạy ETL thật, process cube, đăng ký lịch, sửa SQL/package hay sửa báo cáo Power BI. Có tạo/cập nhật các file bằng chứng và log kiểm thử trong workspace.

## Bằng chứng mới thu thập

| Kiểm tra | Kết quả |
|---|---|
| Lượt gần nhất tại thời điểm chụp | `42e00f86-e012-4f24-b330-515f83c49c40`, 2021-02, SUCCEEDED; đủ năm StageComplete |
| Run đang RUNNING / application lock | Không có tại thời điểm chụp |
| Extract / Transform | 57 checkpoint gồm 56 file chuyến và 1 lookup; Extract đều SUCCEEDED |
| Clean | 560.000 dòng; 558.183 hợp lệ, 1.817 bị loại theo rule core |
| Fact transaction | YellowGreen 278.213; FHV 139.970; HVFHV 140.000; tổng 558.183 |
| Clean–fact theo file | 56 file, 0 lệch số dòng |
| DwhFileLog | 56 SUCCEEDED, không file ForceReload |
| No-op DWH thực tế | Lượt gần nhất PendingFiles=0, DimensionInputRows=0; cả ba fact ProcessedFiles=0 |
| Khóa ngoại | 51 quan hệ đã kiểm tra, 0 orphan; toàn bộ 52 FK vật lý enabled/trusted; 15 dimension có key=0 |
| SSAS | Sáu cube riêng, 15 dimension, sáu measure group, 45 partition đều Processed; sáu Browse MDX đạt |
| Đối soát SQL–MDX | 102 kiểm tra, 0 thất bại |
| Power BI | Sáu cấu hình Live đúng, sáu probe đạt; 70 field binding và 101 truy vấn visual đạt; chín trang |
| Mô hình local | 32 XML hợp lệ; binding cột, tham chiếu dimension/measure đạt |
| Python triển khai | Bốn file ở D:\Kho_Du_lieu\NYCTaxi\script khớp byte với etl/python |
| Unit test Python/metadata | 12 test: 11 đạt, 1 lỗi metadata Master thiếu OnError.LoggingOptions |
| Controller Master fixture | Bảy ca đạt: success, permanent error, transient retry, hết lượt retry, stale failure, resume hợp lệ và resume bị từ chối |
| Lịch | Quét đệ quy Task Scheduler: 0 task tên chứa NYCTaxi, 0 thư mục bị từ chối truy cập |

Số dòng khớp không chứng minh mọi thuộc tính đều đúng nghiệp vụ. SQL và MDX có thể cùng trả một công thức sai ý nghĩa; không dùng 102 kiểm tra này làm chứng nhận toàn bộ nghiệp vụ.

## Phát hiện cần xử lý

### R01 — Cao: lịch tự động chưa được đăng ký

Có script `etl/Register-MonthlyPipelineTask.ps1` thiết kế ngày 15, 10:00 Bangkok, tháng hiện tại trừ hai. Nhưng máy hiện không có task NYCTaxi trong Task Scheduler. Vì vậy hiện chỉ có khả năng tạo lịch, chưa có lịch thực sự hoạt động.

Script mặc định MaxRows=0, khác yêu cầu demo 100.000 dòng/file trước đây. Khi đăng ký cần truyền rõ giới hạn mong muốn. Script dùng interactive token: người dùng phải đăng nhập; StartWhenAvailable không thay thế điều kiện đăng nhập. Chưa có bằng chứng chạy thành công bằng đúng tài khoản và ngữ cảnh của lịch.

Hướng xử lý: chốt chế độ demo/full, đăng ký task với tham số rõ ràng, xác minh XML/NextRunTime/quyền và thực hiện một ca chạy lịch có kiểm soát do người dùng chủ động. Chưa thực hiện trong lần rà soát này.

### R02 — Cao về phục hồi: cancel chưa hủy toàn cây tiến trình có kiểm soát

Master → controller PowerShell → runner → Python/PowerShell con. `WaitForExit` và `Dispose` không phải cơ chế hủy cả cây tiến trình. Stop Debugging có thể để lại tiến trình con hoặc PipelineRun RUNNING. Lịch mới tạo RunId mới nên cũng bị chặn khi có run cũ chưa kết thúc.

Đây là khoảng trống vận hành, không phải bằng chứng fact đã bị hỏng. Các checkpoint đã commit vẫn có ích và guard chặn chạy chồng là đúng. Cần bổ sung cancel có kiểm soát, trạng thái CANCELLED/ABANDONED và recovery xác nhận tiến trình/khóa trước khi đóng run; không tự coi thiếu heartbeat là đã chết.

Checkpoint hiện là checkpoint nghiệp vụ SQL/file, không phải native SSIS `.chk` tiếp tục giữa từng component. Resume chạy lại stage hoặc file chưa hoàn tất, không tiếp tục giữa một câu SQL.

### R03 — Cao về nghiệp vụ: mapping cờ FHV chưa dùng đúng trường nguồn

Transform FHV ghi `SR_Flag` vào `clean.Trip.SourceSRFlag`. Nhưng load dimension và fact FHV lại đọc `SharedRequestFlag` (trường dùng cho HVFHV); hash payload cũng không có SourceSRFlag. Vì vậy nguồn FHV có SR_Flag=1 sẽ không được ánh xạ đúng và thay đổi riêng SR_Flag không được nhận diện đầy đủ theo giá trị nghiệp vụ.

Hiện 140.000 dòng clean FHV đều có SourceSRFlag và SharedRequestFlag NULL; 139.970 fact FHV đều vào IsSharedRide=U. Chưa có bằng chứng mất cờ 1 trong tập dữ liệu hiện tại, nhưng nhánh code có lỗi với nguồn chứa cờ đó.

Theo [TLC FHV dictionary](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_fhv.pdf), SR_Flag có nghĩa và giới hạn riêng, khác shared_request_flag Y/N. Cần chuẩn hóa theo phiên bản/schema nguồn và lưu giới hạn diễn giải; không tự đổi toàn bộ U thành N. Sau sửa cần nâng RuleVersion/LoaderVersion, thử fixture cờ 1/NULL/thay đổi cờ rồi reprocess đúng file.

### R04 — Cao nếu dùng làm KPI: WAV Match Rate không phải tỷ lệ đáp ứng yêu cầu

Cube Base_Performance vẫn công bố measure visible `WAV Match Rate = TotalWAVMatches / TotalWAVRequests`. Dữ liệu có nhóm 559 chuyến WAV nhưng chỉ 6 yêu cầu WAV, nên tỷ lệ có thể vượt 100%.

[TLC HVFHV dictionary](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf) định nghĩa wav_request_flag là khách yêu cầu WAV, còn wav_match_flag là chuyến thực hiện bằng WAV. Hai tập không bắt buộc là quan hệ tử tập/mẫu tập của một tỷ lệ đáp ứng.

Power BI hiện không sử dụng measure này, là điểm tốt; nhưng người dùng Browse cube vẫn chọn được. Cần ẩn/đổi tên chỉ số hiện có; nếu cần tỷ lệ phục vụ yêu cầu thì phải xác định tử số trên chính tập yêu cầu và công bố giới hạn. Không clamp kết quả xuống 100% hoặc sửa dữ liệu nguồn để ép khớp.

### R05 — Trung bình: incremental mới tối ưu một phần

DWH dùng checkpoint theo file; bằng chứng lượt gần nhất không đọc lại các file vào tập fact khi không thay đổi. Tuy nhiên Transform vẫn aggregate `#CleanCounts` từ clean lịch sử theo dataset để kiểm tra count/hash lineage trước khi chọn #Todo. Việc này còn tăng theo lịch sử; không thể tuyên bố chỉ đụng tới 1.000 dòng mới ở toàn luồng.

Aggregate xóa và rebuild ba snapshot toàn bộ trong một transaction. SSAS ProcessFull toàn database trong XMLA transaction. Đây là lựa chọn có tính nhất quán, phản ánh correction/deletion đúng, nhưng chi phí tăng theo toàn kho.

Hướng tối ưu: chọn file thay đổi từ metadata/checkpoint trước, deep audit theo lịch; xác định ngày/tháng chịu ảnh hưởng để rebuild aggregate; process partition SSAS tương ứng. Planner partition đã có nhưng runner chưa dùng; không coi planner tồn tại là đã tích hợp incremental SSAS.

### R06 — Trung bình: timeout đối soát bị mất kiểu lỗi qua tiến trình con

Run `d8e8ef2f-58b5-482f-9f1e-79abd9f62f87` thất bại ở Ssas vì SQL ExecuteScalar trong `Verify-Results.ps1` timeout, không phải checkpoint DWH hoặc schema cube. Lượt sau và đối soát lần rà soát này đều đạt.

Verify chạy trong PowerShell con; runner bọc stderr thành RuntimeException nên SqlException.Number=-2 không còn đến được bộ phân loại transient. Log thực tế Retryable=false dù lỗi gốc là timeout. Không nên chỉ tăng timeout hoặc match chuỗi để retry bừa. Cần kết quả lỗi có cấu trúc giữa các process, thời gian từng query và tách ProcessSSAS khỏi Verify để lỗi Verify không buộc process lại toàn database.

### R07 — Trung bình: các đường chạy không chia sẻ đầy đủ cơ chế điều phối

Master không chạy native các package con bằng Execute Package Task. Nó dùng Execute Process Task gọi runner, runner đọc SQL từ package và nạp CSV bằng SqlBulkCopy. Vì vậy mở tab package con không hiển thị tiến trình thực thi của runner — đây là đúng với kiến trúc hiện tại.

Chạy trực tiếp package con đi theo đường thực thi khác, không được runner giữ global applock và cập nhật PipelineRun. Có nguy cơ chạy chồng khi người dùng mở package con chạy song song Master. Cần thống nhất entry point hoặc bổ sung cùng khóa/context vào đường native; trình bày đúng vai trò SSIS và Python/PowerShell khi bảo vệ.

### R08 — Trung bình: SCD, lịch ngày lễ và lineage cần giới hạn tuyên bố

- Dim_Location có SCD1; Dim_Base chủ yếu thêm mã mới, chưa có SCD2/lookup theo hiệu lực. SCD2 không tự động là yêu cầu bắt buộc; nếu báo cáo cam kết SCD2 thì sản phẩm hiện chưa đáp ứng.
- Toàn bộ 5.848 ngày khác Unknown có IsHoliday=0. Chưa có nguồn lịch ngày lễ đáng tin cậy; không dùng thuộc tính này để kết luận ngày lễ/không ngày lễ.
- 61 Dim_LoadBatch đều SourceFileName NULL; đây là nhóm xử lý suy từ tháng pickup, không phải lineage file thực. Fact.SourceDataset/SourceKey và checkpoint vẫn có lineage nguồn theo file.
- Nguồn không có stable TripID. File correction có thể DELETE/INSERT theo hash payload và làm đổi surrogate TripKey. Không mô tả mọi correction là UPDATE giữ nguyên mã chuyến.
- MaxRows=0 nghĩa đọc đầy đủ file được chọn; không có nghĩa xóa và tái tạo toàn DWH. File biến mất trên local không phải yêu cầu xóa fact; quy trình tombstone/removal nguồn chưa có.

### R09 — Trung bình: phạm vi dữ liệu demo không đại diện toàn tháng

56 file chuyến hiện giới hạn 10.000 dòng/file. Converter lấy N dòng đầu, không lấy mẫu ngẫu nhiên/phân tầng. Nhiều file chỉ bao phủ thời gian đầu tháng trong tập fact. Không suy luận giờ cao điểm toàn tháng, thị phần NYC hoặc tác động chính sách từ các mẫu này.

Dashboard cần giữ cảnh báo/phạm vi dữ liệu rõ: tháng/file, giới hạn dòng, ngày pickup thực sự có mặt, ngày process. Đánh giá phân tích toàn tháng cần nạp đầy đủ hoặc thiết kế sampling có căn cứ. Negative fare/refund, Unknown địa lý và missing finance cần giải thích theo dữ liệu, không tự loại tất cả để làm biểu đồ đẹp.

### R10 — Trung bình/thấp: metadata, schema validation và khả năng tái lập

- Unit test hiện lỗi vì Master được Visual Studio lưu thiếu OnError.LoggingOptions theo bộ quy tắc XSD đã ghim. Package đã có lượt chạy thành công; chưa đủ cơ sở gọi đây là lỗi runtime đang chặn ETL. Cần chuẩn hóa metadata hoặc điều chỉnh validator theo phiên bản thực sự hỗ trợ, rồi làm test đạt trở lại.
- Thử kiểm tra schema PBIR lần này bị chặn DNS trong môi trường sandbox. 51 JSON dùng schema 2.14.0; chưa xác nhận đầy đủ tất cả tài liệu theo schema chính thức. Các truy vấn visual đạt không thay thế việc kiểm tra toàn bộ bố cục/render bằng Desktop.
- Có nhiều đường dẫn/server/assembly cố định; ConfigHash chứa tham số và đường dẫn nhưng chưa ghim hash phiên bản code/package. Sửa code giữa hai lần resume có thể thay hành vi mà không đổi ConfigHash. Cần manifest version và cấu hình môi trường tập trung để tái lập trên máy chấm.
- Lịch sử backup được kiểm tra có full backup, chưa thấy log backup cho hai database trong msdb trong phạm vi truy vấn; cả hai đang FULL recovery. Chưa có ca restore thực tế hoặc chính sách retention log được chứng minh. Không kết luận đã có disaster recovery chỉ vì có file backup.

## Đánh giá từng chặng

| Chặng | Đánh giá |
|---|---|
| Download/convert/inspect | Có kiểm tra schema, hash CSV, số dòng, giới hạn, file tạm, phạm vi và missing source; đạt nền tảng, strict schema drift sẽ dừng có chủ đích |
| wrk → stg | Có replace theo file và checkpoint; wrk còn dữ liệu sau commit là buffer dùng lại, không tự là lỗi |
| Transform | Có rule, valid/rejected/warning, transaction và file checkpoint; còn quét kiểm tra lịch sử, mapping SR_Flag cần sửa |
| Dimension/fact | Mô hình star dùng chung dimension, Unknown, file incremental/correction, index, transaction/checkpoint phù hợp; cần công bố SCD/lineage/identity đúng phạm vi |
| Aggregate | Ba grain có PK rõ, rebuild atomic và phản ánh correction; chưa incremental theo vùng thay đổi |
| SSAS | Sáu cube đúng yêu cầu, dữ liệu truy vấn nhất quán; còn KPI WAV, lịch ngày lễ và full processing |
| Power BI | Live tách cube đúng, query/binding đạt; không chứng nhận render/tương tác tất cả trang chỉ bằng query test |
| Logging/recovery | Có SQL/local log, monitor, retry chọn lọc, resume; chưa hoàn chỉnh cancel, transient propagation qua child process, entry-point concurrency |
| Scheduling | Chưa đạt yêu cầu chạy tự động thực tế: chưa có task |

Đặt log điều phối trong schema etl của DWH và checkpoint tại Staging/DWH hiện hợp lệ; tách database log là lựa chọn kiến trúc, không phải điều kiện sửa một lỗi thiết kế. Chưa tách database log trong lần rà soát này.

## Thứ tự đề xuất trước nghiệm thu

1. Hoàn thiện cancel/recovery và đồng bộ khóa giữa các entry point; kiểm thử cancel giữa download, bulk copy, fact transaction và SSAS.
2. Sửa mapping FHV và định nghĩa/visibility KPI WAV; xác nhận lại bằng fixture và dữ liệu tương ứng, có nâng version.
3. Chốt tham số demo/full và đăng ký, xác minh lịch ngày 15 lúc 10:00 với đúng tài khoản. Không tự đăng ký trong tác vụ rà soát.
4. Làm bộ kiểm thử hiện tại đạt; bổ sung truyền lỗi có cấu trúc, tách Process/Verify và manifest version.
5. Đo rồi tối ưu Transform, Aggregate và partition SSAS; không bỏ kiểm tra tính đúng chỉ để tăng tốc.
6. Đối chiếu bản báo cáo cuối với schema/grain/SCD/mẫu dữ liệu thực; hoàn thành demo UI, diễn giải kết quả và bằng chứng phục hồi/restore.

## Giới hạn lần rà soát

Không chạy mới 22 ca incremental SQL cách ly vì chúng tạo thêm database fixture; bằng chứng `etl/incremental-tests.json` là lịch sử, không trình bày như vừa chạy lại. Không tạo lỗi trên dữ liệu thật, không thử restore, không benchmark full dataset, không mở và kiểm tra tương tác từng trang Desktop, không xác nhận quyền chạy dưới một tài khoản lịch chưa tồn tại.

Các file JSON/CSV/console cùng thư mục là bằng chứng thời điểm chụp, không phải giám sát liên tục. Các SQL được trích từ package đang cài giúp đối chiếu findings mà không phụ thuộc package tiếp tục bị chỉnh sửa sau này.
